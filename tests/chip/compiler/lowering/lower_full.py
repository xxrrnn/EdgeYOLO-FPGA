"""
lower_full.py - Full-network lowering for ResNet18 and YOLOv5n.

Supports: Conv, Add, Concat (OP_CDMA_STRIDE), Upsample 2x, MaxPool 5x5,
           and cout tiling (>128 output channels).
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

from ..errors import OutOfBuffer, UnsupportedOp
from ..ir_schema import (
    UNIT_AD, UNIT_DQA, UNIT_IM2COL, UNIT_MP, UNIT_NN, UNIT_QA, UNIT_US,
    SCHEMA_VERSION, empty_plan,
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
    DCIM_NUM_TILES,
)

# OBUF region constants (matching plan)
PING = 0x000000
PONG = 0x400000
IM2COL = 0x800000
SKIP_BASE = 0xC00000
WB_SHADOW = 0xFF0000


def emit_add(src1_off: int, src2_off: int, dst_off: int,
             h: int, w: int, c: int) -> List[Dict[str, Any]]:
    """AD unit: elementwise FP32 add."""
    return [
        {"kind": "vpu_exec", "unit": "ad", "args": {
            "unit_choose": UNIT_AD,
            "src_addr": src1_off, "src2_addr": src2_off,
            "src_c": c, "src_h": h, "src_w": w,
            "bias_addr": 0, "scale_addr": 0,
            "dst_addr": dst_off,
            "addr_break": 0, "addr_s": 0, "addr_t": 0,
        }},
        {"kind": "wait_vpu"},
    ]


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
                 h: int, w: int, c: int) -> List[Dict[str, Any]]:
    """MP unit: 5x5 stride=1 pad=2 maxpool (same spatial size)."""
    return [
        {"kind": "vpu_exec", "unit": "mp", "args": {
            "unit_choose": UNIT_MP,
            "src_addr": src_off, "src2_addr": 0,
            "src_c": c, "src_h": h, "src_w": w,
            "bias_addr": 0, "scale_addr": 0,
            "dst_addr": dst_off,
            "addr_break": 0, "addr_s": 0, "addr_t": 0,
        }},
        {"kind": "wait_vpu"},
    ]


def emit_concat_stride(sources: List[Dict], dst_off: int,
                       h: int, w: int, elem_bytes: int = 4) -> List[Dict[str, Any]]:
    """Concat via OP_CDMA_STRIDE. sources: [{"off": int, "c": int}, ...]."""
    total_c_bytes = sum(s["c"] * elem_bytes for s in sources)
    ops = []
    dst_ch_offset = 0
    for src in sources:
        c_bytes = src["c"] * elem_bytes
        ops.append({
            "kind": "cdma_stride",
            "src": ("obuf", src["off"]),
            "dst": ("obuf", dst_off + dst_ch_offset),
            "copy_bytes": c_bytes,
            "src_stride": c_bytes,
            "dst_stride": total_c_bytes,
            "count": h * w,
        })
        ops.append({"kind": "wait_cdma"})
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


# ===========================================================================
# ResNet18 lowering
# ===========================================================================
def _lower_resnet18(
    network: Dict[str, Any], hw: Dict[str, Any], *,
    mode: str = "int8", max_layers: Optional[int] = None,
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

    elem_bytes = 2 if mode == "int16" else 1
    elems_per_word = (DCIM_CH_IN // 2) if mode == "int16" else DCIM_CH_IN

    n_conv = min(len(layers), max_layers) if max_layers else len(layers)

    ops: List[Dict[str, Any]] = []
    layer_records, wb_records, weight_records = [], [], []
    unsupported: List[str] = []
    wb_scratch_cursor = WB_SHADOW
    skip_alloc = SkipAllocator()

    # Tracking current feature tensor
    cur_h, cur_w, cur_c = int(input_shape[2]), int(input_shape[3]), int(input_shape[1])
    cur_obuf = PING
    conv_idx = 0

    def _other(off):
        return PONG if off == PING else PING

    def _do_conv(layer_idx, in_off, out_off, skip_qa=False,
                 override_h=None, override_w=None, override_c=None):
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
        acc_depth = (kh * kw * cin + elems_per_word - 1) // elems_per_word
        tiles_needed = (cout + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE

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
        act_ibuf_word_addr = (wt_per_tile_bytes * min(tiles_needed, DCIM_NUM_TILES)) // BYTES_PER_WORD

        # Cout tiling: split into multiple DCIM passes of 8 tiles each
        num_passes = (tiles_needed + DCIM_NUM_TILES - 1) // DCIM_NUM_TILES
        if num_passes > 1:
            for pass_idx in range(num_passes):
                tile_start = pass_idx * DCIM_NUM_TILES
                tile_end = min(tile_start + DCIM_NUM_TILES, tiles_needed)
                pass_cout = (tile_end - tile_start) * DCIM_INT8_OUT_CH_PER_TILE
                if tile_end == tiles_needed:
                    pass_cout = cout - tile_start * DCIM_INT8_OUT_CH_PER_TILE

                pass_layer = dict(layer)
                pass_layer["out_channels"] = pass_cout
                # Keep original name so WB scratch lookup works
                pass_layer["name"] = layer["name"]

                pass_out_off = out_off + tile_start * DCIM_INT8_OUT_CH_PER_TILE * oh * ow * 4

                emitted, _, _, _, _ = emit_conv(
                    pass_layer,
                    in_obuf_off=in_off, out_obuf_off=pass_out_off,
                    im2col_obuf_off=IM2COL, wb_off=0,
                    wei_ibuf_word_addr=wei_ibuf_word_addr + tile_start * wt_per_tile_words,
                    in_h=h, in_w=w, is_first_layer=(conv_idx == 0 and pass_idx == 0),
                    hw=hw, mode=mode, skip_qa=(skip_qa if pass_idx == 0 else True),
                    act_ibuf_word_addr=act_ibuf_word_addr,
                )
                ops.extend(emitted)
        else:
            emitted, _, _, _, ws = emit_conv(
                layer,
                in_obuf_off=in_off, out_obuf_off=out_off,
                im2col_obuf_off=IM2COL, wb_off=0,
                wei_ibuf_word_addr=wei_ibuf_word_addr,
                in_h=h, in_w=w, is_first_layer=(conv_idx == 0),
                hw=hw, mode=mode, skip_qa=skip_qa,
                act_ibuf_word_addr=act_ibuf_word_addr,
            )
            ops.extend(emitted)

        layer_records.append({
            "name": layer["name"],
            "input_off": in_off, "output_off": out_off,
            "im2col_off": IM2COL, "wb_off": 0,
            "input_hw": [h, w], "output_hw": [oh, ow],
            "input_c": cin, "output_c": cout,
            "kernel": [kh, kw], "stride": [sh, sw],
            "padding": ph, "acc_depth": acc_depth,
            "tiles_needed": tiles_needed,
        })
        wb_records.append({
            "name": layer["name"],
            "wb_off": 0, "section_bytes": wb_section,
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

    # ===== conv1 =====
    if conv_idx < n_conv:
        oh, ow, cout = _do_conv(0, cur_obuf, _other(cur_obuf), skip_qa=True)
        cur_h, cur_w, cur_c = oh, ow, cout
        cur_obuf = _other(cur_obuf)

    # ===== MaxPool 3x3 s2 p1 (ResNet18 topology) =====
    # The parsed topology shows maxpool.MaxPool after conv1.
    # We implement this as a simple CDMA stride or host-side.
    # Actually, ResNet18's maxpool is 3x3 s2 p1 -- not 5x5 s1 p2.
    # The mp_unit_fixed only supports 5x5 s1 p2.
    # For now, we skip MaxPool and note it as unsupported.
    # The plan says "AvgPool和FNN如果好实现就在片上做" but MaxPool 3x3 s2 is tricky.
    # WORKAROUND: Include maxpool in host preprocessing (upload already-pooled input).
    unsupported.append(
        "maxpool 3x3 s2 p1: mp_unit_fixed only supports 5x5 s1 p2. "
        "Workaround: host pre-applies MaxPool to conv1 output before upload, "
        "OR skip maxpool (ResNet18 without maxpool still trains well)."
    )
    # Apply maxpool dimensions anyway for correct scheduling
    # MaxPool 3x3, stride=2, pad=1: oh = (h+2*1 - 3)/2 + 1
    mp_oh = (cur_h + 2 - 3) // 2 + 1
    mp_ow = (cur_w + 2 - 3) // 2 + 1
    # For actual hardware: we'll emit a note but continue with correct shapes
    cur_h, cur_w = mp_oh, mp_ow
    # cur_c stays 64, cur_obuf stays the same (maxpool is in-place spatially)

    # ===== Basic blocks =====
    # Schedule: [(conv_indices_for_block, has_downsample)]
    block_schedule = [
        # layer1.0: conv1(idx=1), conv2(idx=2), no downsample
        ([1, 2], None),
        # layer1.1: conv1(idx=3), conv2(idx=4), no downsample
        ([3, 4], None),
        # layer2.0: conv1(idx=5), conv2(idx=6), downsample(idx=7)
        ([5, 6], 7),
        # layer2.1: conv1(idx=8), conv2(idx=9)
        ([8, 9], None),
        # layer3.0: conv1(idx=10), conv2(idx=11), downsample(idx=12)
        ([10, 11], 12),
        # layer3.1: conv1(idx=13), conv2(idx=14)
        ([13, 14], None),
        # layer4.0: conv1(idx=15), conv2(idx=16), downsample(idx=17)
        ([15, 16], 17),
        # layer4.1: conv1(idx=18), conv2(idx=19)
        ([18, 19], None),
    ]

    for conv_ids, ds_idx in block_schedule:
        if conv_ids[0] >= n_conv:
            break

        # Save residual input to skip region
        skip_h, skip_w, skip_c = cur_h, cur_w, cur_c
        skip_bytes = _tensor_bytes_nhwc(skip_h, skip_w, skip_c, elem_bytes=4)
        skip_off = skip_alloc.alloc(skip_bytes)
        ops.append({
            "kind": "cdma_copy",
            "src": ("obuf", cur_obuf),
            "dst": ("obuf", skip_off),
            "length": skip_bytes,
        })
        ops.append({"kind": "wait_cdma"})

        # conv1 of block
        if conv_ids[0] < n_conv:
            out_off = _other(cur_obuf)
            oh, ow, cout = _do_conv(conv_ids[0], cur_obuf, out_off)
            cur_h, cur_w, cur_c = oh, ow, cout
            cur_obuf = out_off

        # conv2 of block
        if len(conv_ids) > 1 and conv_ids[1] < n_conv:
            out_off = _other(cur_obuf)
            oh, ow, cout = _do_conv(conv_ids[1], cur_obuf, out_off)
            cur_h, cur_w, cur_c = oh, ow, cout
            cur_obuf = out_off
            main_out = cur_obuf

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
                override_h=skip_h, override_w=skip_w
            )
            # Add: conv2_out + downsample_out
            ops.extend(emit_add(main_out, ds_out_off, cur_obuf,
                                cur_h, cur_w, cur_c))
        else:
            # Add: conv2_out + skip (same shape assumed)
            ops.extend(emit_add(main_out, skip_off, cur_obuf,
                                cur_h, cur_w, cur_c))

        skip_alloc.reset()

    # End
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

    plan["host_io"] = {
        "input_obuf_off": PING,
        "output_obuf_off": cur_obuf,
        "input_dtype": "uint8",
        "output_dtype": "float32",
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
    elems_per_word = (DCIM_CH_IN // 2) if mode == "int16" else DCIM_CH_IN

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

    def _other(off):
        return PONG if off == PING else PING

    def _do_conv_yolo(layer_idx, skip_qa=False):
        nonlocal cur_h, cur_w, cur_c, cur_obuf, conv_count, wb_scratch_cursor

        layer = layers[layer_idx]
        cin = int(layer["in_channels"])
        cout = int(layer["out_channels"])
        kh, kw = int(layer["kernel_h"]), int(layer["kernel_w"])
        sh, sw = layer["stride"]
        ph = [layer["padding"][i] for i in range(4)]

        oh = (cur_h + ph[0] + ph[2] - kh) // sh + 1
        ow = (cur_w + ph[1] + ph[3] - kw) // sw + 1
        acc_depth = (kh * kw * cin + elems_per_word - 1) // elems_per_word
        tiles_needed = (cout + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE

        wb_off = 0
        dqa_scale_off = 16
        dqa_bias_off = dqa_scale_off + _round_up(cout * 4, 16)
        wb_section = dqa_bias_off + _round_up(cout * 4, 16)
        wb_scratch_cursor += _round_up(wb_section, 16)

        wt_per_tile_words = acc_depth * DCIM_CYCLE
        wt_per_tile_bytes = wt_per_tile_words * BYTES_PER_WORD
        wei_ibuf_word_addr = 0
        act_ibuf_word_addr = (wt_per_tile_bytes * min(tiles_needed, DCIM_NUM_TILES)) // BYTES_PER_WORD

        in_off = cur_obuf
        out_off = _other(cur_obuf)

        num_passes = (tiles_needed + DCIM_NUM_TILES - 1) // DCIM_NUM_TILES
        if num_passes > 1:
            for pass_idx in range(num_passes):
                tile_start = pass_idx * DCIM_NUM_TILES
                tile_end = min(tile_start + DCIM_NUM_TILES, tiles_needed)
                pass_cout = cout - tile_start * DCIM_INT8_OUT_CH_PER_TILE if tile_end == tiles_needed else (tile_end - tile_start) * DCIM_INT8_OUT_CH_PER_TILE
                pass_layer = dict(layer)
                pass_layer["out_channels"] = pass_cout
                pass_layer["name"] = layer["name"]
                pass_out_off = out_off + tile_start * DCIM_INT8_OUT_CH_PER_TILE * oh * ow * 4
                emitted, _, _, _, _ = emit_conv(
                    pass_layer, in_obuf_off=in_off, out_obuf_off=pass_out_off,
                    im2col_obuf_off=IM2COL, wb_off=0,
                    wei_ibuf_word_addr=wei_ibuf_word_addr + tile_start * wt_per_tile_words,
                    in_h=cur_h, in_w=cur_w,
                    is_first_layer=(conv_count == 0 and pass_idx == 0),
                    hw=hw, mode=mode,
                    skip_qa=(skip_qa if pass_idx == 0 else True),
                    act_ibuf_word_addr=act_ibuf_word_addr,
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
            )
            ops.extend(emitted)

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

        if action == "conv":
            layer_idx = step[1]
            if max_layers and conv_count >= max_layers:
                break
            _do_conv_yolo(layer_idx, skip_qa=(conv_count == 0))

        elif action == "save":
            name = step[1]
            buf_bytes = _tensor_bytes_nhwc(cur_h, cur_w, cur_c, elem_bytes=4)
            off = skip_alloc.alloc(buf_bytes)
            ops.append({"kind": "cdma_copy", "src": ("obuf", cur_obuf),
                        "dst": ("obuf", off), "length": buf_bytes})
            ops.append({"kind": "wait_cdma"})
            named_buffers[name] = {"off": off, "h": cur_h, "w": cur_w, "c": cur_c,
                                   "size": buf_bytes}

        elif action == "load":
            name = step[1]
            buf = named_buffers[name]
            buf_bytes = _tensor_bytes_nhwc(buf["h"], buf["w"], buf["c"], elem_bytes=4)
            dst = _other(cur_obuf)
            ops.append({"kind": "cdma_copy", "src": ("obuf", buf["off"]),
                        "dst": ("obuf", dst), "length": buf_bytes})
            ops.append({"kind": "wait_cdma"})
            cur_h, cur_w, cur_c = buf["h"], buf["w"], buf["c"]
            cur_obuf = dst

        elif action == "concat":
            src_names = step[1]
            sources = []
            h0 = named_buffers[src_names[0]]["h"]
            w0 = named_buffers[src_names[0]]["w"]
            for sn in src_names:
                buf = named_buffers[sn]
                sources.append({"off": buf["off"], "c": buf["c"]})
            total_c = sum(s["c"] for s in sources)
            dst = _other(cur_obuf)
            ops.extend(emit_concat_stride(sources, dst, h0, w0, elem_bytes=4))
            cur_h, cur_w, cur_c = h0, w0, total_c
            cur_obuf = dst

        elif action == "upsample":
            name = step[1]
            buf = named_buffers[name]
            dst = _other(cur_obuf)
            ops.extend(emit_upsample(buf["off"], dst, buf["h"], buf["w"], buf["c"]))
            cur_h, cur_w, cur_c = buf["h"] * 2, buf["w"] * 2, buf["c"]
            cur_obuf = dst

        elif action == "maxpool":
            name = step[1]
            buf = named_buffers[name]
            dst = _other(cur_obuf)
            ops.extend(emit_maxpool(buf["off"], dst, buf["h"], buf["w"], buf["c"]))
            cur_h, cur_w, cur_c = buf["h"], buf["w"], buf["c"]
            cur_obuf = dst

        # Free buffers whose last use was this step
        to_free = [n for n, lu in last_use.items() if lu == step_idx and n in named_buffers]
        for n in to_free:
            buf = named_buffers[n]
            skip_alloc.free(buf["off"], buf["size"])
            del named_buffers[n]

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

    plan["host_io"] = {
        "input_obuf_off": PING,
        "output_obuf_off": cur_obuf,
        "input_dtype": "uint8",
        "output_dtype": "float32",
        "output_hw": [cur_h, cur_w],
        "output_c": cur_c,
    }
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
) -> Dict[str, Any]:
    """Dispatch to network-specific lowering."""
    name = network["model_info"].get("name", "unknown")
    if name == "resnet18":
        return _lower_resnet18(network, hw, mode=mode, max_layers=max_layers)
    elif name == "yolov5n":
        return _lower_yolov5n(network, hw, mode=mode, max_layers=max_layers)
    else:
        from .lower import lower
        return lower(network, hw, mode=mode, max_layers=max_layers)
