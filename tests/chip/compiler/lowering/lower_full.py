"""
lower_full.py - Full-network lowering for ResNet18 and YOLOv5n.

Supports: Conv, Add, Concat (OP_CDMA_STRIDE), Upsample 2x, MaxPool 5x5,
           and cout tiling (>128 output channels).
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from ..errors import OutOfBuffer, UnsupportedOp
from ..ir_schema import (
    UNIT_AD, UNIT_DQA, UNIT_IM2COL, UNIT_MP, UNIT_NN, UNIT_QA, UNIT_US,
    SCHEMA_VERSION, VPU_FLAG_DQA_ACT, VPU_FLAG_INT16, empty_plan,
)
from .lower import (
    _round_up, _tensor_bytes_nhwc, _im2col_bytes,
    pack_addr_break, pack_dcim_mode, emit_conv,
)
from .memory_plan import MemoryPlanner
from chip_config import (  # noqa: E402
    BYTES_PER_WORD,
    DCIM_CH_IN,
    DCIM_CYCLE,
    DCIM_INT8_OUT_CH_PER_TILE,
    DCIM_INT16_OUT_CH_PER_TILE,
    DCIM_NUM_TILES,
)

# VPU_BUF region constants for chip-v3 (8MB VPU buffer).
#
# YOLOv5n at 320x320 needs:
#   - largest FP32 feature: 160*160*16*4 = 0x190000 bytes
#   - largest INT8 im2col: 160*160*3*6*6 = 0x2a3000 bytes
# Keep ping/pong below the im2col scratch, then reserve the tail for long-lived
# skip/concat tensors and per-layer WB scratch uploaded by the host.
PING = 0x000000
PONG = 0x1A0000
IM2COL = 0x340000
SKIP_BASE = 0x5F0000
WB_SHADOW = 0x7C0000
VPU_BUF_END = 0x800000


def _active_tiles_per_pass() -> int:
    raw = os.environ.get("EDGEYOLO_MAX_ACTIVE_TILES")
    if not raw:
        return DCIM_NUM_TILES
    try:
        return max(1, min(DCIM_NUM_TILES, int(raw)))
    except ValueError:
        return DCIM_NUM_TILES


def emit_add(src1_off: int, src2_off: int, dst_off: int,
             h: int, w: int, c: int, *, relu: bool = False) -> List[Dict[str, Any]]:
    """AD unit: elementwise FP32 add, optionally followed by ReLU."""
    return [
        {"kind": "vpu_exec", "unit": "ad", "args": {
            "unit_choose": UNIT_AD,
            "src_addr": src1_off, "src2_addr": src2_off,
            "src_c": c, "src_h": h, "src_w": w,
            "bias_addr": 0, "scale_addr": 0,
            "dst_addr": dst_off,
            "addr_break": 1 if relu else 0, "addr_s": 0, "addr_t": 0,
        }},
        {"kind": "wait_vpu"},
    ]


def emit_qa(src_off: int, dst_off: int, scale_wb_off: int,
            h: int, w: int, c: int, *, mode: str = "int8",
            layer: str = "qa") -> List[Dict[str, Any]]:
    """QA unit: FP32 input -> INT8/INT16 quantized activation."""
    flags = (1 << 1) if mode == "int16" else 0
    return [
        {"kind": "vpu_exec", "unit": "qa", "layer": layer, "flags": flags, "args": {
            "unit_choose": UNIT_QA,
            "src_addr": src_off, "src2_addr": 0,
            "src_c": c, "src_h": h, "src_w": w,
            "bias_addr": 0, "scale_addr": scale_wb_off,
            "dst_addr": dst_off,
            "addr_break": 0, "addr_s": 0, "addr_t": 0,
        }},
        {"kind": "wait_vpu", "layer": layer},
    ]


def emit_dqa_activation(src_off: int, dst_off: int, scale_wb_off: int, bias_wb_off: int,
                        h: int, w: int, c: int, *, mode: str = "int8",
                        layer: str = "dqa_act") -> List[Dict[str, Any]]:
    """DQA unit in activation mode: QA-packed INT8/INT16 -> FP32."""
    flags = (1 << VPU_FLAG_DQA_ACT)
    if mode == "int16":
        flags |= (1 << VPU_FLAG_INT16)
    return [
        {"kind": "vpu_exec", "unit": "dqa", "layer": layer, "flags": flags, "args": {
            "unit_choose": UNIT_DQA,
            "src_addr": src_off, "src2_addr": 0,
            "src_c": c, "src_h": h, "src_w": w,
            "bias_addr": bias_wb_off, "scale_addr": scale_wb_off,
            "dst_addr": dst_off,
            "addr_break": 0, "addr_s": 0, "addr_t": 0,
        }},
        {"kind": "wait_vpu", "layer": layer},
    ]


def _resnet_add_output_scales(network: Dict[str, Any]) -> Dict[str, float]:
    parsed = network.get("_parsed_dir")
    scale_file = network.get("add_output_scales_file")
    if not parsed or not scale_file:
        return {}
    path = Path(parsed) / str(scale_file)
    if not path.exists():
        fallback = Path(parsed).parent / "parsed_vai" / str(scale_file)
        if fallback.exists():
            path = fallback
        else:
            return {}
    data = json.loads(path.read_text())
    return {str(k): float(v) for k, v in data.items()}


def emit_upsample(src_off: int, dst_off: int,
                  h: int, w: int, c: int) -> List[Dict[str, Any]]:
    """US unit: 2x nearest-neighbor upsample. Output is [2h, 2w, c]."""
    return [
        {"kind": "vpu_exec", "unit": "us", "args": {
            "unit_choose": UNIT_US,
            "src_addr": src_off, "src2_addr": 0,
            "src_c": c, "src_h": h, "src_w": w,
            "bias_addr": 0, "scale_addr": 0,
            "dst_addr": dst_off,
            "addr_break": 0, "addr_s": 0, "addr_t": 0,
        }},
        {"kind": "wait_vpu"},
    ]


def emit_maxpool(src_off: int, dst_off: int,
                 h: int, w: int, c: int, mode: int = 0) -> List[Dict[str, Any]]:
    """MP unit. RTL mode via addr_break[1:0]: 0=5x5s1p2, 1=3x3s2p1, 2=GAP."""
    return [
        {"kind": "vpu_exec", "unit": "mp", "args": {
            "unit_choose": UNIT_MP,
            "src_addr": src_off, "src2_addr": 0,
            "src_c": c, "src_h": h, "src_w": w,
            "bias_addr": 0, "scale_addr": 0,
            "dst_addr": dst_off,
            "addr_break": int(mode) & 0x3, "addr_s": 0, "addr_t": 0,
        }},
        {"kind": "wait_vpu"},
    ]


def emit_concat_stride(sources: List[Dict], dst_off: int,
                       h: int, w: int, elem_bytes: int = 4) -> List[Dict[str, Any]]:
    """Concat via OP_CDMA_STRIDE. sources: [{"off": int, "c": int}, ...]."""
    max_stride_bytes = 64
    total_c_bytes = sum(s["c"] * elem_bytes for s in sources)
    ops = []
    dst_ch_offset = 0
    for src in sources:
        c_bytes = src["c"] * elem_bytes
        chunk_off = 0
        while chunk_off < c_bytes:
            chunk = min(max_stride_bytes, c_bytes - chunk_off)
            ops.append({
                "kind": "cdma_stride",
                "src": ("obuf", src["off"] + chunk_off),
                "dst": ("obuf", dst_off + dst_ch_offset + chunk_off),
                "copy_bytes": chunk,
                "src_stride": c_bytes,
                "dst_stride": total_c_bytes,
                "count": h * w,
            })
            ops.append({"kind": "wait_cdma"})
            chunk_off += chunk
        dst_ch_offset += c_bytes
    return ops


class SkipAllocator:
    """Free-list allocator for OBUF skip region."""
    def __init__(self, lo=SKIP_BASE, hi=WB_SHADOW):
        self.lo, self.hi = lo, hi
        # Free list: sorted list of (start, size) free blocks
        self.free_list = [(lo, hi - lo)]

    def alloc(self, nbytes: int) -> int:
        nbytes = _round_up(nbytes, 16)
        # First-fit
        for i, (start, size) in enumerate(self.free_list):
            if size >= nbytes:
                self.free_list.pop(i)
                if size > nbytes:
                    self.free_list.append((start + nbytes, size - nbytes))
                    self.free_list.sort()
                return start
        raise OutOfBuffer(
            f"Skip region full: need {nbytes} bytes, "
            f"free blocks: {[(hex(s), sz) for s, sz in self.free_list]}"
        )

    def free(self, off: int, nbytes: int):
        nbytes = _round_up(nbytes, 16)
        self.free_list.append((off, nbytes))
        self.free_list.sort()
        # Merge adjacent blocks
        merged = []
        for start, size in self.free_list:
            if merged and merged[-1][0] + merged[-1][1] == start:
                merged[-1] = (merged[-1][0], merged[-1][1] + size)
            else:
                merged.append((start, size))
        self.free_list = merged

    def reset(self):
        self.free_list = [(self.lo, self.hi - self.lo)]

    def owns(self, off: int) -> bool:
        return self.lo <= int(off) < self.hi


# ===========================================================================
# ResNet18 lowering
# ===========================================================================
def _lower_resnet18(
    network: Dict[str, Any], hw: Dict[str, Any], *,
    mode: str = "int8", max_layers: Optional[int] = None,
    dcim_loop: str = "layer",
) -> Dict[str, Any]:
    """
    ResNet18 layer schedule (conv layers[] index):
      0: conv1 (7x7 s2, 3→64)
      -- MaxPool 3x3 s2 p1 (topology) --
      1: layer1.0.conv1,  2: layer1.0.conv2, Add
      3: layer1.1.conv1,  4: layer1.1.conv2, Add
      5: layer2.0.conv1,  6: layer2.0.conv2,  7: layer2.0.downsample, Add
      8: layer2.1.conv1,  9: layer2.1.conv2, Add
     10: layer3.0.conv1, 11: layer3.0.conv2, 12: layer3.0.downsample, Add
     13: layer3.1.conv1, 14: layer3.1.conv2, Add
     15: layer4.0.conv1, 16: layer4.0.conv2, 17: layer4.0.downsample, Add
     18: layer4.1.conv1, 19: layer4.1.conv2, Add
    """
    layers = network["layers"]
    input_shape = network["model_info"]["input_shape"]
    output_shape = network["model_info"]["output_shape"]

    plan = empty_plan("resnet18", input_shape, output_shape, mode=mode)
    plan["address_map"] = hw["address_map"]
    plan["network"] = "resnet18"
    add_output_scales = _resnet_add_output_scales(network)

    elem_bytes = 2 if mode == "int16" else 1
    out_ch_per_tile = DCIM_INT16_OUT_CH_PER_TILE if mode == "int16" else DCIM_INT8_OUT_CH_PER_TILE
    # ResNet stem produces a much larger FP32 feature (112*112*64*4) than
    # YOLO's first stage, so the YOLO-oriented global PONG/IM2COL regions
    # overlap.  Keep ResNet's im2col scratch above the full stem output; OH
    # tiling keeps the scratch footprint below this reserved window.
    R_PING = 0x000000
    R_PONG = 0x1A0000
    R_IM2COL = 0x4C0000
    R_SKIP_BASE = 0x5A0000
    R_WB_SHADOW = WB_SHADOW

    n_conv = min(len(layers), max_layers) if max_layers else len(layers)

    ops: List[Dict[str, Any]] = []
    layer_records, wb_records, weight_records = [], [], []
    unsupported: List[str] = []
    wb_scratch_cursor = R_WB_SHADOW
    skip_alloc = SkipAllocator(R_SKIP_BASE, R_WB_SHADOW)

    # Tracking current feature tensor
    cur_h, cur_w, cur_c = int(input_shape[2]), int(input_shape[3]), int(input_shape[1])
    cur_obuf = R_PING
    cur_scale: float | None = None
    conv_idx = 0

    def _other(off):
        return R_PONG if off == R_PING else R_PING

    def _emit_activation_qdq(qdq_name: str, src_dst_off: int,
                             h: int, w: int, c: int,
                             scale: float | None) -> None:
        """Quantize/dequantize an FP32 activation to match VAI INT8 boundaries."""
        nonlocal wb_scratch_cursor
        if scale is None or float(scale) == 0.0:
            unsupported.append(f"{qdq_name}: missing activation scale; skipped activation QDQ")
            return

        q_tmp = skip_alloc.alloc(_tensor_bytes_nhwc(h, w, c, elem_bytes=elem_bytes))
        dqa_scale_off = 16
        dqa_bias_off = dqa_scale_off + _round_up(c * 4, 16)
        wb_section = dqa_bias_off + _round_up(c * 4, 16)
        wb_scratch_cursor += _round_up(wb_section, 16)
        wb_records.append({
            "name": qdq_name,
            "kind": "qdq",
            "channels": c,
            "wb_off": 0,
            "qa_scale": 1.0 / float(scale),
            "dqa_scale": float(scale),
            "section_bytes": wb_section,
        })
        ops.append({
            "kind": "cdma_copy",
            "comment": f"refresh WB for {qdq_name}",
            "src": ("obuf_wb_scratch_off_for_layer", qdq_name),
            "dst": ("wb_off", 0),
            "length": wb_section,
        })
        ops.append({"kind": "wait_cdma", "layer": qdq_name})
        ops.extend(emit_qa(src_dst_off, q_tmp, 0, h, w, c, mode=mode, layer=f"{qdq_name}.qa"))
        ops.extend(emit_dqa_activation(q_tmp, src_dst_off, dqa_scale_off, dqa_bias_off,
                                       h, w, c, mode=mode, layer=f"{qdq_name}.dqa"))
        skip_alloc.free(q_tmp, _tensor_bytes_nhwc(h, w, c, elem_bytes=elem_bytes))

    def _do_conv(layer_idx, in_off, out_off, skip_qa=False,
                 override_h=None, override_w=None, override_c=None,
                 qa_obuf_off=None, qa_input_scale: float | None = None):
        """Emit one conv, return (oh, ow, cout). Supports cout tiling."""
        nonlocal conv_idx, wb_scratch_cursor
        layer = layers[layer_idx]
        cin = int(layer["in_channels"])
        cout = int(layer["out_channels"])
        kh, kw = int(layer["kernel_h"]), int(layer["kernel_w"])
        sh, sw = layer["stride"]
        ph = [layer["padding"][i] for i in range(4)]

        h = override_h if override_h else cur_h
        w = override_w if override_w else cur_w

        oh = (h + ph[0] + ph[2] - kh) // sh + 1
        ow = (w + ph[1] + ph[3] - kw) // sw + 1
        acc_depth = (kh * kw * cin + DCIM_CH_IN - 1) // DCIM_CH_IN
        tiles_needed = (cout + out_ch_per_tile - 1) // out_ch_per_tile

        # WB
        wb_off = 0
        dqa_scale_off = 16
        dqa_bias_off = dqa_scale_off + _round_up(cout * 4, 16)
        wb_section = dqa_bias_off + _round_up(cout * 4, 16)

        layer_wb_scratch = wb_scratch_cursor
        wb_scratch_cursor += _round_up(wb_section, 16)

        # IBUF
        wt_per_tile_words = acc_depth * DCIM_CYCLE
        wt_per_tile_bytes = wt_per_tile_words * BYTES_PER_WORD
        wei_ibuf_word_addr = 0
        tiles_per_pass = _active_tiles_per_pass()
        # IBUF is physically banked per DCIM tile.  Weights for tile N are
        # loaded at the same local offset inside tile N's IBUF bank, so the
        # activation region also starts after one tile's weights, not after all
        # active tiles' weights.  Multiplying by tiles_per_pass overruns the
        # local 512KB IBUF bank for large 512-channel ResNet layers.
        act_ibuf_word_addr = wei_ibuf_word_addr + (wt_per_tile_bytes // BYTES_PER_WORD)

        qa_tmp = None
        if (not skip_qa) and qa_obuf_off is not None and int(qa_obuf_off) == int(out_off):
            qa_bytes = _tensor_bytes_nhwc(h, w, cin, elem_bytes=elem_bytes)
            qa_tmp = (skip_alloc.alloc(qa_bytes), qa_bytes)
            qa_obuf_off = qa_tmp[0]

        # Cout tiling: split into multiple DCIM passes.  The default is all
        # hardware tiles; EDGEYOLO_MAX_ACTIVE_TILES can reduce the pass width
        # for bring-up or RTL limits without changing host boundaries.
        num_passes = (tiles_needed + tiles_per_pass - 1) // tiles_per_pass
        if num_passes > 1:
            for pass_idx in range(num_passes):
                tile_start = pass_idx * tiles_per_pass
                tile_end = min(tile_start + tiles_per_pass, tiles_needed)
                pass_cout = (tile_end - tile_start) * out_ch_per_tile
                if tile_end == tiles_needed:
                    pass_cout = cout - tile_start * out_ch_per_tile

                pass_layer = dict(layer)
                pass_layer["out_channels"] = pass_cout
                # Keep original name so WB scratch lookup works
                pass_layer["name"] = layer["name"]

                pass_out_off = out_off

                emitted, _, _, _, _ = emit_conv(
                    pass_layer,
                    in_obuf_off=in_off, out_obuf_off=pass_out_off,
                    im2col_obuf_off=R_IM2COL, wb_off=0,
                    wei_ibuf_word_addr=wei_ibuf_word_addr,
                    in_h=h, in_w=w, is_first_layer=(conv_idx == 0 and pass_idx == 0),
                    hw=hw, mode=mode, skip_qa=(skip_qa if pass_idx == 0 else True),
                    act_ibuf_word_addr=act_ibuf_word_addr,
                    use_dcim_layer=True,
                    dcim_loop=dcim_loop,
                    weight_tile_start=tile_start,
                    full_out_channels=cout,
                    dqa_channel_off=tile_start * out_ch_per_tile,
                    qa_obuf_off=qa_obuf_off,
                )
                ops.extend(emitted)
        else:
            emitted, _, _, _, ws = emit_conv(
                layer,
                in_obuf_off=in_off, out_obuf_off=out_off,
                im2col_obuf_off=R_IM2COL, wb_off=0,
                wei_ibuf_word_addr=wei_ibuf_word_addr,
                in_h=h, in_w=w, is_first_layer=(conv_idx == 0),
                hw=hw, mode=mode, skip_qa=skip_qa,
                act_ibuf_word_addr=act_ibuf_word_addr,
                use_dcim_layer=True,
                dcim_loop=dcim_loop,
                qa_obuf_off=qa_obuf_off,
            )
            ops.extend(emitted)

        if qa_tmp is not None:
            skip_alloc.free(qa_tmp[0], qa_tmp[1])

        _emit_activation_qdq(
            f"{layer['name']}.act_qdq",
            out_off, oh, ow, cout,
            float(layer["act_scale"]) if "act_scale" in layer else None,
        )

        layer_records.append({
            "name": layer["name"],
            "input_off": in_off, "output_off": out_off,
            "im2col_off": R_IM2COL, "wb_off": 0,
            "input_hw": [h, w], "output_hw": [oh, ow],
            "input_c": cin, "output_c": cout,
            "kernel": [kh, kw], "stride": [sh, sw],
            "padding": ph, "acc_depth": acc_depth,
            "tiles_needed": tiles_needed,
        })
        wb_records.append({
            "name": layer["name"],
            "wb_off": 0, "section_bytes": wb_section,
            "qa_scale": (1.0 / float(qa_input_scale)) if qa_input_scale else None,
        })
        weight_records.append({
            "name": layer["name"],
            "ibuf_byte_off": 0,
            "ibuf_word_addr": wei_ibuf_word_addr,
            "per_tile_words": wt_per_tile_words,
            "per_tile_bytes": wt_per_tile_bytes,
            "tiles_needed": tiles_needed,
        })
        conv_idx += 1
        return oh, ow, cout

    def _emit_residual_add(add_name: str, src1_off: int, src2_off: int, dst_off: int,
                           h: int, w: int, c: int) -> None:
        """Residual Add followed by QA+DQA so block output matches quantized E2E semantics."""
        nonlocal wb_scratch_cursor
        out_scale = add_output_scales.get(add_name)
        if out_scale is None or float(out_scale) == 0.0:
            ops.extend(emit_add(src1_off, src2_off, dst_off, h, w, c, relu=True))
            unsupported.append(f"{add_name}: missing add output scale; emitted FP32 AD without QDQ")
            return

        qdq_name = f"{add_name}.qdq"
        elem_bytes_q = 2 if mode == "int16" else 1
        q_tmp = skip_alloc.alloc(_tensor_bytes_nhwc(h, w, c, elem_bytes=elem_bytes_q))
        dqa_scale_off = 16
        dqa_bias_off = dqa_scale_off + _round_up(c * 4, 16)
        wb_section = dqa_bias_off + _round_up(c * 4, 16)
        wb_scratch_cursor += _round_up(wb_section, 16)
        wb_records.append({
            "name": qdq_name,
            "kind": "qdq",
            "channels": c,
            "wb_off": 0,
            "qa_scale": 1.0 / float(out_scale),
            "dqa_scale": float(out_scale),
            "section_bytes": wb_section,
        })
        ops.append({
            "kind": "cdma_copy",
            "comment": f"refresh WB for {qdq_name}",
            "src": ("obuf_wb_scratch_off_for_layer", qdq_name),
            "dst": ("wb_off", 0),
            "length": wb_section,
        })
        ops.append({"kind": "wait_cdma", "layer": qdq_name})
        ops.extend(emit_add(src1_off, src2_off, dst_off, h, w, c, relu=True))
        ops.extend(emit_qa(dst_off, q_tmp, 0, h, w, c, mode=mode, layer=f"{qdq_name}.qa"))
        ops.extend(emit_dqa_activation(q_tmp, dst_off, dqa_scale_off, dqa_bias_off,
                                       h, w, c, mode=mode, layer=f"{qdq_name}.dqa"))
        skip_alloc.free(q_tmp, _tensor_bytes_nhwc(h, w, c, elem_bytes=elem_bytes_q))

    # ===== conv1 =====
    if conv_idx < n_conv:
        oh, ow, cout = _do_conv(0, cur_obuf, _other(cur_obuf), skip_qa=True)
        cur_h, cur_w, cur_c = oh, ow, cout
        cur_obuf = _other(cur_obuf)
        cur_scale = float(layers[0]["act_scale"]) if "act_scale" in layers[0] else None

    # ===== MaxPool 3x3 s2 p1 (ResNet18 topology) =====
    # The plan says "AvgPool和FNN如果好实现就在片上做" but MaxPool 3x3 s2 is tricky.
    # mp_unit_fixed mode 1 implements ResNet's stem maxpool.
    mp_oh = (cur_h + 2 - 3) // 2 + 1
    mp_ow = (cur_w + 2 - 3) // 2 + 1
    mp_dst = _other(cur_obuf)
    ops.extend(emit_maxpool(cur_obuf, mp_dst, cur_h, cur_w, cur_c, mode=1))
    cur_h, cur_w = mp_oh, mp_ow
    cur_obuf = mp_dst
    pool_scale = float(network.get("maxpool_output_scale")) if network.get("maxpool_output_scale") is not None else cur_scale
    _emit_activation_qdq(
        "maxpool.MaxPool.act_qdq",
        cur_obuf, cur_h, cur_w, cur_c,
        pool_scale,
    )
    cur_scale = pool_scale

    # ===== Basic blocks =====
    # Schedule: [(conv_indices_for_block, has_downsample)]
    block_schedule = [
        # layer1.0: conv1(idx=1), conv2(idx=2), no downsample
        ("layer1.0.Add", [1, 2], None),
        # layer1.1: conv1(idx=3), conv2(idx=4), no downsample
        ("layer1.1.Add", [3, 4], None),
        # layer2.0: conv1(idx=5), conv2(idx=6), downsample(idx=7)
        ("layer2.0.Add", [5, 6], 7),
        # layer2.1: conv1(idx=8), conv2(idx=9)
        ("layer2.1.Add", [8, 9], None),
        # layer3.0: conv1(idx=10), conv2(idx=11), downsample(idx=12)
        ("layer3.0.Add", [10, 11], 12),
        # layer3.1: conv1(idx=13), conv2(idx=14)
        ("layer3.1.Add", [13, 14], None),
        # layer4.0: conv1(idx=15), conv2(idx=16), downsample(idx=17)
        ("layer4.0.Add", [15, 16], 17),
        # layer4.1: conv1(idx=18), conv2(idx=19)
        ("layer4.1.Add", [18, 19], None),
    ]

    for add_name, conv_ids, ds_idx in block_schedule:
        if conv_ids[0] >= n_conv:
            break

        # Keep residual input by pointer. Do not CDMA-copy within VPU_BUF.
        skip_h, skip_w, skip_c = cur_h, cur_w, cur_c
        skip_off = cur_obuf
        skip_scale = cur_scale

        # conv1 of block
        if conv_ids[0] < n_conv:
            out_off = _other(cur_obuf)
            oh, ow, cout = _do_conv(
                conv_ids[0], cur_obuf, out_off,
                qa_obuf_off=_other(skip_off),
                qa_input_scale=cur_scale,
            )
            cur_h, cur_w, cur_c = oh, ow, cout
            cur_obuf = out_off
            cur_scale = float(layers[conv_ids[0]]["act_scale"]) if "act_scale" in layers[conv_ids[0]] else cur_scale

        # conv2 of block
        main_out = None
        if len(conv_ids) > 1 and conv_ids[1] < n_conv:
            out_off = skip_alloc.alloc(
                _tensor_bytes_nhwc(cur_h, cur_w, int(layers[conv_ids[1]]["out_channels"]), elem_bytes=4)
            )
            oh, ow, cout = _do_conv(conv_ids[1], cur_obuf, out_off, qa_input_scale=cur_scale)
            cur_h, cur_w, cur_c = oh, ow, cout
            cur_obuf = out_off
            main_out = cur_obuf
            main_scale = float(layers[conv_ids[1]]["act_scale"]) if "act_scale" in layers[conv_ids[1]] else cur_scale
            cur_scale = main_scale
        else:
            # Partial compile stopped after conv1.  Leave the current feature as
            # host-visible output and do not emit a residual add for an
            # incomplete block.
            skip_alloc.reset()
            break

        # Downsample path
        if ds_idx is not None and ds_idx < n_conv:
            ds_layer = layers[ds_idx]
            ds_cin = int(ds_layer["in_channels"])
            ds_cout = int(ds_layer["out_channels"])
            # Downsample input is the saved skip (skip_h, skip_w, skip_c)
            ds_out_off = skip_alloc.alloc(
                _tensor_bytes_nhwc(cur_h, cur_w, ds_cout, elem_bytes=4)
            )
            oh_ds, ow_ds, cout_ds = _do_conv(
                ds_idx, skip_off, ds_out_off,
                override_h=skip_h, override_w=skip_w,
                qa_obuf_off=_other(skip_off),
                qa_input_scale=skip_scale,
            )
            # Add: conv2_out + downsample_out
            cur_obuf = _other(skip_off)
            _emit_residual_add(add_name, main_out, ds_out_off, cur_obuf,
                               cur_h, cur_w, cur_c)
        elif ds_idx is not None:
            # Downsample is required for this block but was not included by
            # max_layers.  Stop at conv2 output rather than adding mismatched
            # tensors.
            skip_alloc.reset()
            break
        else:
            # Add: conv2_out + skip (same shape assumed)
            cur_obuf = _other(skip_off)
            _emit_residual_add(add_name, main_out, skip_off, cur_obuf,
                               cur_h, cur_w, cur_c)

        skip_alloc.reset()
        cur_scale = add_output_scales.get(add_name, cur_scale)

    # Full ResNet host boundary is after the final residual Add.  The legacy E2E
    # classifier expects that tensor in quantized activation domain, so add one
    # final QA when all conv layers are present.  Intermediate Adds remain FP32;
    # the following Conv's QA already quantizes them with the same scale.
    host_output_dtype = "float32"
    if conv_idx == len(layers):
        final_scale = add_output_scales.get("layer4.1.Add")
        if final_scale is not None and final_scale != 0.0:
            final_name = "__resnet_final_qa"
            final_bytes = _tensor_bytes_nhwc(cur_h, cur_w, cur_c, elem_bytes=elem_bytes)
            final_off = skip_alloc.alloc(final_bytes)
            wb_records.append({
                "name": final_name,
                "kind": "qa_only",
                "wb_off": 0,
                "qa_scale": 1.0 / float(final_scale),
                "section_bytes": 16,
            })
            ops.append({
                "kind": "cdma_copy",
                "comment": "refresh WB for ResNet final QA",
                "src": ("obuf_wb_scratch_off_for_layer", final_name),
                "dst": ("wb_off", 0),
                "length": 16,
            })
            ops.append({"kind": "wait_cdma", "layer": final_name})
            ops.extend(emit_qa(cur_obuf, final_off, 0, cur_h, cur_w, cur_c,
                               mode=mode, layer=final_name))
            cur_obuf = final_off
            host_output_dtype = "int16" if mode == "int16" else "int8"

    # End
    ops.append({"kind": "end"})

    plan["ops"] = ops
    plan["memory_plan"]["layers"] = layer_records
    plan["weights_layout"]["layers"] = weight_records
    plan["wb_layout"]["layers"] = wb_records
    plan["unsupported"] = unsupported

    scratch_off_by_layer = {}
    cur_s = R_WB_SHADOW
    for w in wb_records:
        scratch_off_by_layer[w["name"]] = cur_s
        cur_s = (cur_s + w["section_bytes"] + 15) & ~15
    plan["wb_layout"]["scratch_off_by_layer"] = scratch_off_by_layer

    plan["host_io"] = {
        "input_obuf_off": R_PING,
        "output_obuf_off": cur_obuf,
        "input_dtype": "int16" if mode == "int16" else "uint8",
        "output_dtype": host_output_dtype,
        "output_hw": [cur_h, cur_w],
        "output_c": cur_c,
    }
    plan["compile_meta"] = {
        "schema_version": SCHEMA_VERSION, "mode": mode,
        "num_conv_layers_compiled": conv_idx,
        "num_conv_layers_total": len(layers),
        "stop_reason": "resnet18 full schedule",
    }
    return plan


# ===========================================================================
# YOLOv5n lowering
# ===========================================================================
def _lower_yolov5n(
    network: Dict[str, Any], hw: Dict[str, Any], *,
    mode: str = "int8", max_layers: Optional[int] = None,
    dcim_loop: str = "layer",
) -> Dict[str, Any]:
    """Lower YOLOv5n backbone + FPN/PAN using static schedule."""
    from .yolov5n_schedule import YOLOV5N_SCHEDULE

    layers = network["layers"]
    input_shape = network["model_info"]["input_shape"]
    output_shape = network["model_info"]["output_shape"]

    plan = empty_plan("yolov5n", input_shape, output_shape, mode=mode)
    plan["address_map"] = hw["address_map"]
    plan["network"] = "yolov5n"

    elem_bytes = 2 if mode == "int16" else 1
    out_ch_per_tile = DCIM_INT16_OUT_CH_PER_TILE if mode == "int16" else DCIM_INT8_OUT_CH_PER_TILE

    ops: List[Dict[str, Any]] = []
    layer_records, wb_records, weight_records = [], [], []
    unsupported: List[str] = []
    wb_scratch_cursor = WB_SHADOW
    skip_alloc = SkipAllocator()

    cur_h = int(input_shape[2])
    cur_w = int(input_shape[3])
    cur_c = int(input_shape[1])
    cur_obuf = PING
    conv_count = 0

    # Named tensor buffers: name → {"off": obuf_offset, "h": h, "w": w, "c": c}
    named_buffers: Dict[str, Dict] = {}
    # Pre-compute last use of each named buffer to auto-free
    last_use: Dict[str, int] = {}
    for i, step in enumerate(YOLOV5N_SCHEDULE):
        action = step[0]
        if action == "load":
            last_use[step[1]] = i
        elif action == "concat":
            for sn in step[1]:
                last_use[sn] = i
        elif action == "upsample":
            last_use[step[1]] = i
        elif action == "maxpool":
            last_use[step[1]] = i
        elif action == "add":
            last_use[step[1]] = i

    def _other(off):
        return PONG if off == PING else PING

    def _next_step_is_save(step_idx: int) -> bool:
        return (
            step_idx + 1 < len(YOLOV5N_SCHEDULE)
            and YOLOV5N_SCHEDULE[step_idx + 1][0] == "save"
        )

    loaded_current_name: Optional[str] = None
    current_named_name: Optional[str] = None

    def _release_named_buffer(name: str) -> None:
        buf = named_buffers.get(name)
        if not buf:
            return
        if buf.get("owned", False):
            skip_alloc.free(buf["off"], buf["size"])
        del named_buffers[name]

    def _do_conv_yolo(layer_idx, skip_qa=False, persist_output=False):
        nonlocal cur_h, cur_w, cur_c, cur_obuf, conv_count, wb_scratch_cursor

        layer = layers[layer_idx]
        cin = int(layer["in_channels"])
        cout = int(layer["out_channels"])
        kh, kw = int(layer["kernel_h"]), int(layer["kernel_w"])
        sh, sw = layer["stride"]
        ph = [layer["padding"][i] for i in range(4)]

        oh = (cur_h + ph[0] + ph[2] - kh) // sh + 1
        ow = (cur_w + ph[1] + ph[3] - kw) // sw + 1
        acc_depth = (kh * kw * cin + DCIM_CH_IN - 1) // DCIM_CH_IN
        tiles_needed = (cout + out_ch_per_tile - 1) // out_ch_per_tile

        wb_off = 0
        dqa_scale_off = 16
        dqa_bias_off = dqa_scale_off + _round_up(cout * 4, 16)
        wb_section = dqa_bias_off + _round_up(cout * 4, 16)
        wb_scratch_cursor += _round_up(wb_section, 16)

        wt_per_tile_words = acc_depth * DCIM_CYCLE
        wt_per_tile_bytes = wt_per_tile_words * BYTES_PER_WORD
        wei_ibuf_word_addr = 0
        tiles_per_pass = _active_tiles_per_pass()
        act_ibuf_word_addr = wei_ibuf_word_addr + (wt_per_tile_bytes // BYTES_PER_WORD)

        in_off = cur_obuf
        if persist_output:
            out_off = skip_alloc.alloc(_tensor_bytes_nhwc(oh, ow, cout, elem_bytes=4))
        else:
            out_off = _other(cur_obuf)
        qa_scratch_tmp = None
        qa_scratch_off = _other(cur_obuf) if current_named_name is not None else None
        if (not skip_qa) and qa_scratch_off is not None and int(qa_scratch_off) == int(out_off):
            qa_bytes = _tensor_bytes_nhwc(cur_h, cur_w, cin, elem_bytes=elem_bytes)
            qa_scratch_tmp = (skip_alloc.alloc(qa_bytes), qa_bytes)
            qa_scratch_off = qa_scratch_tmp[0]

        num_passes = (tiles_needed + tiles_per_pass - 1) // tiles_per_pass
        if num_passes > 1:
            for pass_idx in range(num_passes):
                tile_start = pass_idx * tiles_per_pass
                tile_end = min(tile_start + tiles_per_pass, tiles_needed)
                pass_cout = cout - tile_start * out_ch_per_tile if tile_end == tiles_needed else (tile_end - tile_start) * out_ch_per_tile
                pass_layer = dict(layer)
                pass_layer["out_channels"] = pass_cout
                pass_layer["name"] = layer["name"]
                pass_out_off = out_off
                emitted, _, _, _, _ = emit_conv(
                    pass_layer, in_obuf_off=in_off, out_obuf_off=pass_out_off,
                    im2col_obuf_off=IM2COL, wb_off=0,
                    wei_ibuf_word_addr=wei_ibuf_word_addr,
                    in_h=cur_h, in_w=cur_w,
                    is_first_layer=(conv_count == 0 and pass_idx == 0),
                    hw=hw, mode=mode,
                    skip_qa=(skip_qa if pass_idx == 0 else True),
                    act_ibuf_word_addr=act_ibuf_word_addr,
                    use_dcim_layer=True,
                    dcim_loop=dcim_loop,
                    weight_tile_start=tile_start,
                    full_out_channels=cout,
                    dqa_channel_off=tile_start * out_ch_per_tile,
                    qa_obuf_off=qa_scratch_off,
                )
                ops.extend(emitted)
        else:
            emitted, _, _, _, _ = emit_conv(
                layer, in_obuf_off=in_off, out_obuf_off=out_off,
                im2col_obuf_off=IM2COL, wb_off=0,
                wei_ibuf_word_addr=wei_ibuf_word_addr,
                in_h=cur_h, in_w=cur_w, is_first_layer=(conv_count == 0),
                hw=hw, mode=mode, skip_qa=skip_qa,
                act_ibuf_word_addr=act_ibuf_word_addr,
                use_dcim_layer=True,
                dcim_loop=dcim_loop,
                qa_obuf_off=qa_scratch_off,
            )
            ops.extend(emitted)

        if qa_scratch_tmp is not None:
            skip_alloc.free(qa_scratch_tmp[0], qa_scratch_tmp[1])

        layer_records.append({
            "name": layer["name"], "input_off": in_off, "output_off": out_off,
            "im2col_off": IM2COL, "wb_off": 0,
            "input_hw": [cur_h, cur_w], "output_hw": [oh, ow],
            "input_c": cin, "output_c": cout,
            "kernel": [kh, kw], "stride": [sh, sw],
            "padding": ph, "acc_depth": acc_depth, "tiles_needed": tiles_needed,
        })
        wb_records.append({"name": layer["name"], "wb_off": 0, "section_bytes": wb_section})
        weight_records.append({
            "name": layer["name"], "ibuf_byte_off": 0,
            "ibuf_word_addr": wei_ibuf_word_addr,
            "per_tile_words": wt_per_tile_words,
            "per_tile_bytes": wt_per_tile_bytes, "tiles_needed": tiles_needed,
        })

        cur_h, cur_w, cur_c = oh, ow, cout
        cur_obuf = out_off
        conv_count += 1

    # Execute schedule
    for step_idx, step in enumerate(YOLOV5N_SCHEDULE):
        action = step[0]
        consumed_loaded_name = loaded_current_name if action not in ("load", "save") else None

        if action == "conv":
            layer_idx = step[1]
            if max_layers and conv_count >= max_layers:
                break
            _do_conv_yolo(
                layer_idx,
                skip_qa=(conv_count == 0),
                persist_output=_next_step_is_save(step_idx),
            )
            if max_layers and conv_count >= max_layers:
                break
            current_named_name = None

        elif action == "save":
            name = step[1]
            buf_bytes = _tensor_bytes_nhwc(cur_h, cur_w, cur_c, elem_bytes=4)
            named_buffers[name] = {
                "off": cur_obuf, "h": cur_h, "w": cur_w, "c": cur_c,
                "size": buf_bytes, "owned": skip_alloc.owns(cur_obuf),
            }
            current_named_name = name

        elif action == "load":
            name = step[1]
            buf = named_buffers[name]
            cur_h, cur_w, cur_c = buf["h"], buf["w"], buf["c"]
            cur_obuf = buf["off"]
            loaded_current_name = name
            current_named_name = name

        elif action == "concat":
            src_names = step[1]
            sources = []
            h0 = named_buffers[src_names[0]]["h"]
            w0 = named_buffers[src_names[0]]["w"]
            for sn in src_names:
                buf = named_buffers[sn]
                sources.append({"off": buf["off"], "c": buf["c"]})
            total_c = sum(s["c"] for s in sources)
            if _next_step_is_save(step_idx):
                dst = skip_alloc.alloc(_tensor_bytes_nhwc(h0, w0, total_c, elem_bytes=4))
            else:
                dst = _other(cur_obuf)
            ops.extend(emit_concat_stride(sources, dst, h0, w0, elem_bytes=4))
            cur_h, cur_w, cur_c = h0, w0, total_c
            cur_obuf = dst
            current_named_name = None

        elif action == "upsample":
            name = step[1]
            buf = named_buffers[name]
            if _next_step_is_save(step_idx):
                dst = skip_alloc.alloc(
                    _tensor_bytes_nhwc(buf["h"] * 2, buf["w"] * 2, buf["c"], elem_bytes=4)
                )
            else:
                dst = _other(cur_obuf)
            ops.extend(emit_upsample(buf["off"], dst, buf["h"], buf["w"], buf["c"]))
            cur_h, cur_w, cur_c = buf["h"] * 2, buf["w"] * 2, buf["c"]
            cur_obuf = dst
            current_named_name = None

        elif action == "maxpool":
            name = step[1]
            buf = named_buffers[name]
            if _next_step_is_save(step_idx):
                dst = skip_alloc.alloc(
                    _tensor_bytes_nhwc(buf["h"], buf["w"], buf["c"], elem_bytes=4)
                )
            else:
                dst = _other(cur_obuf)
            ops.extend(emit_maxpool(buf["off"], dst, buf["h"], buf["w"], buf["c"]))
            cur_h, cur_w, cur_c = buf["h"], buf["w"], buf["c"]
            cur_obuf = dst
            current_named_name = None

        elif action == "add":
            name = step[1]
            buf = named_buffers[name]
            if (buf["h"], buf["w"], buf["c"]) != (cur_h, cur_w, cur_c):
                unsupported.append(
                    f"{name}: add shape mismatch shortcut "
                    f"{buf['h']}x{buf['w']}x{buf['c']} vs current {cur_h}x{cur_w}x{cur_c}"
                )
                break
            dst = _other(cur_obuf)
            ops.extend(emit_add(cur_obuf, buf["off"], dst, cur_h, cur_w, cur_c))
            cur_obuf = dst
            current_named_name = None

        # Free buffers whose last use was this step
        if consumed_loaded_name:
            _release_named_buffer(consumed_loaded_name)
            loaded_current_name = None

        to_free = [
            n for n, lu in last_use.items()
            if lu == step_idx and n in named_buffers and n != loaded_current_name
        ]
        for n in to_free:
            _release_named_buffer(n)

    ops.append({"kind": "end"})

    plan["ops"] = ops
    plan["memory_plan"]["layers"] = layer_records
    plan["weights_layout"]["layers"] = weight_records
    plan["wb_layout"]["layers"] = wb_records
    plan["unsupported"] = unsupported

    scratch_off_by_layer = {}
    cur_s = WB_SHADOW
    for w in wb_records:
        scratch_off_by_layer[w["name"]] = cur_s
        cur_s = (cur_s + w["section_bytes"] + 15) & ~15
    plan["wb_layout"]["scratch_off_by_layer"] = scratch_off_by_layer

    detect_outputs = []
    for name in ("PAN_P3", "PAN_P4", "PAN_P5"):
        if name in named_buffers:
            buf = named_buffers[name]
            detect_outputs.append({
                "name": name,
                "obuf_off": int(buf["off"]),
                "dtype": "float32",
                "hw": [int(buf["h"]), int(buf["w"])],
                "c": int(buf["c"]),
            })

    plan["host_io"] = {
        "input_obuf_off": PING,
        "output_obuf_off": detect_outputs[-1]["obuf_off"] if detect_outputs else cur_obuf,
        "input_dtype": "int16" if mode == "int16" else "uint8",
        "output_dtype": "float32",
        "output_hw": detect_outputs[-1]["hw"] if detect_outputs else [cur_h, cur_w],
        "output_c": detect_outputs[-1]["c"] if detect_outputs else cur_c,
    }
    if detect_outputs:
        plan["host_io"]["outputs"] = detect_outputs
    plan["compile_meta"] = {
        "schema_version": SCHEMA_VERSION, "mode": mode,
        "num_conv_layers_compiled": conv_count,
        "num_conv_layers_total": len(layers),
        "stop_reason": "yolov5n full schedule (to model.23)",
    }
    return plan


# ===========================================================================
# Public entry point
# ===========================================================================
def lower_full(
    network: Dict[str, Any], hw: Dict[str, Any], *,
    mode: str = "int8", max_layers: Optional[int] = None,
    dcim_loop: str = "layer",
) -> Dict[str, Any]:
    """Dispatch to network-specific lowering."""
    name = network["model_info"].get("name", "unknown").lower()
    if "resnet18" in name:
        return _lower_resnet18(network, hw, mode=mode, max_layers=max_layers, dcim_loop=dcim_loop)
    elif "yolov5n" in name:
        return _lower_yolov5n(network, hw, mode=mode, max_layers=max_layers, dcim_loop=dcim_loop)
    else:
        from .lower import lower
        return lower(network, hw, mode=mode, max_layers=max_layers)
