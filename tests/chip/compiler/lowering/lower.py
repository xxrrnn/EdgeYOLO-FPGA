"""
Lowering pass.  Reads parsed/network.json + hw_caps.yaml → produces plan.json
(an ordered list of hardware primitives).

Public entry point:
    lower(network, hw_caps, mode='int8', max_layers=None) -> plan dict

The plan dict follows the schema documented in tools/compiler/ir_schema.py.
"""

from __future__ import annotations

import os
import sys
from typing import Any, Dict, List, Optional

from ..errors import OutOfBuffer, UnsupportedOp
from ..ir_schema import (
    UNIT_AD, UNIT_DQA, UNIT_IM2COL, UNIT_MP, UNIT_NN, UNIT_QA, UNIT_US,
    SCHEMA_VERSION, empty_plan,
)
from .memory_plan import MemoryPlanner
from .op_rules import conv_check, maxpool_check, resize_check

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
from chip_config import (  # noqa: E402
    BYTES_PER_WORD,
    DCIM_CH_IN,
    DCIM_CYCLE,
    DCIM_INT8_OUT_CH_PER_TILE,
    DCIM_INT16_OUT_CH_PER_TILE,
    DCIM_INT8_OUT_WORDS_PER_TILE,
    DCIM_INT16_OUT_WORDS_PER_TILE,
    DCIM_NUM_TILES,
    require_consistent,
)
require_consistent()


def _bytes_per_word():
    return BYTES_PER_WORD


def _round_up(x: int, m: int) -> int:
    return (x + m - 1) // m * m


def _tensor_bytes_nhwc(h: int, w: int, c: int, elem_bytes: int = 1) -> int:
    # Stored row-major NHWC.  Each row is C*elem_bytes; round to 16 for OBUF alignment.
    return _round_up(h * w * c * elem_bytes, 16)


def _im2col_bytes(oh: int, ow: int, kh: int, kw: int, cin: int) -> int:
    # acc_depth = ceil(kH*kW*Cin / DCIM_CH_IN); each row is acc_depth*DCIM_CH_IN bytes.
    acc_depth = (kh * kw * cin + DCIM_CH_IN - 1) // DCIM_CH_IN
    return oh * ow * acc_depth * DCIM_CH_IN


# Pack helper for OP_VPU_EXEC im2col addr_break field:
#   {kH[7:0], kW[7:0], strideH[3:0], strideW[3:0], padH[3:0], padW[3:0]}
def pack_addr_break(kh, kw, stride_h, stride_w, pad_h, pad_w) -> int:
    return (
        ((kh & 0xFF) << 24)
        | ((kw & 0xFF) << 16)
        | ((stride_h & 0xF) << 12)
        | ((stride_w & 0xF) << 8)
        | ((pad_h & 0xF) << 4)
        | (pad_w & 0xF)
    )


# Pack helper for DCIM MODE: [15:8]=acc_depth, [2:0]=mode
def pack_dcim_mode(acc_depth: int, mode: int) -> int:
    return ((acc_depth & 0xFF) << 8) | (mode & 0x7)


# -----------------------------------------------------------------------------
# Per-layer emitter: emit one Conv layer's primitive sequence.
# -----------------------------------------------------------------------------
def emit_conv(
    layer: Dict[str, Any],
    *,
    in_obuf_off: int,
    out_obuf_off: int,
    im2col_obuf_off: int,
    wb_off: int,
    wei_ibuf_word_addr: int,
    in_h: int,
    in_w: int,
    is_first_layer: bool,
    hw: Dict[str, Any],
    mode: str,
    skip_qa: bool = False,
    act_ibuf_word_addr: int = 0,
) -> List[Dict[str, Any]]:
    """Emit the primitive sequence for one Conv layer.

    Sequence: [qa?] → im2col → cdma_copy (OBUF→IBUF) → dcim_cfg → dcim_exec → dqa

    Address conventions:
      - in_obuf_off, out_obuf_off, im2col_obuf_off, wb_off are BYTE offsets
        within OBUF / WB.
      - wei_ibuf_word_addr is an IBUF WORD address (128-bit word index).
      - QA scale / DQA scale / DQA bias are kept in WB at fixed sub-offsets.
    """
    cin = int(layer["in_channels"])
    cout = int(layer["out_channels"])
    kh = int(layer["kernel_h"])
    kw = int(layer["kernel_w"])
    stride_h, stride_w = layer["stride"][0], layer["stride"][1]
    pad_h = layer["padding"][0]
    pad_w = layer["padding"][1]
    oh = (in_h + layer["padding"][0] + layer["padding"][2] - kh) // stride_h + 1
    ow = (in_w + layer["padding"][1] + layer["padding"][3] - kw) // stride_w + 1
    # acc_depth depends on data width: INT8 packs 16 per IBUF word; INT16 packs 8.
    elems_per_word = (DCIM_CH_IN // 2) if mode == "int16" else DCIM_CH_IN
    acc_depth = (kh * kw * cin + elems_per_word - 1) // elems_per_word

    # ---- WB sub-allocations (within wb_off) ----
    # qa_scale (1 fp32) | dqa_scale[cout] (cout fp32) | dqa_bias[cout] (cout fp32)
    qa_scale_wb_off = wb_off
    dqa_scale_wb_off = wb_off + 16        # 16-byte aligned
    dqa_bias_wb_off = dqa_scale_wb_off + _round_up(cout * 4, 16)
    wb_section_bytes = (dqa_bias_wb_off - wb_off) + _round_up(cout * 4, 16)

    ops: List[Dict[str, Any]] = []

    # 0) Refresh WB (CDMA from OBUF.wb_scratch → WB).
    #    Codegen will emit OP_CDMA_COPY with src in OBUF, dst in WB.
    ops.append({
        "kind": "cdma_copy",
        "comment": f"refresh WB for layer {layer['name']}",
        "src": ("obuf_wb_scratch_off_for_layer", layer["name"]),
        "dst": ("wb_off", wb_off),
        "length": wb_section_bytes,
    })
    ops.append({"kind": "wait_cdma"})

    # 1) QA (FP32 input → INT8).  Skip for first layer where host already wrote INT8 image
    #    bytes into OBUF; and skip when the previous DQA's output is already INT8.
    vpu_flags = (1 << 1) if mode == "int16" else 0  # VPU_FLAG_INT16
    if not skip_qa:
        ops.append({
            "kind": "vpu_exec", "unit": "qa", "layer": layer["name"],
            "flags": vpu_flags,
            "args": {
                "unit_choose": UNIT_QA,
                "src_addr": in_obuf_off,
                "src2_addr": 0,
                "src_c": cin, "src_h": in_h, "src_w": in_w,
                "bias_addr": 0,
                "scale_addr": qa_scale_wb_off,
                "dst_addr": in_obuf_off,    # in-place quantize
                "addr_break": 0, "addr_s": 0, "addr_t": 0,
            },
        })
        ops.append({"kind": "wait_vpu"})

    # 2) im2col: OBUF[in] → OBUF[im2col scratch]
    ops.append({
        "kind": "vpu_exec", "unit": "im2col", "layer": layer["name"],
        "args": {
            "unit_choose": UNIT_IM2COL,
            "src_addr": in_obuf_off,
            "src2_addr": 0,
            "src_c": cin, "src_h": in_h, "src_w": in_w,
            "bias_addr": 0, "scale_addr": 0,
            "dst_addr": im2col_obuf_off,
            "addr_break": pack_addr_break(kh, kw, stride_h, stride_w, pad_h, pad_w),
            "addr_s": oh, "addr_t": ow,
        },
    })
    ops.append({"kind": "wait_vpu"})

    # 3) CDMA OBUF[im2col] → IBUF[activation region]
    ibuf_act_word_addr = act_ibuf_word_addr   # post-weights region
    im2col_row_bytes = DCIM_CH_IN * (2 if mode == "int16" else 1)
    im2col_bytes = oh * ow * acc_depth * im2col_row_bytes
    ops.append({
        "kind": "cdma_copy",
        "src": ("obuf", im2col_obuf_off),
        "dst": ("ibuf", ibuf_act_word_addr * 16),
        "length": im2col_bytes,
    })
    ops.append({"kind": "wait_cdma"})

    out_ch_per_tile = DCIM_INT16_OUT_CH_PER_TILE if mode == "int16" else DCIM_INT8_OUT_CH_PER_TILE
    out_words_per_tile = DCIM_INT16_OUT_WORDS_PER_TILE if mode == "int16" else DCIM_INT8_OUT_WORDS_PER_TILE
    tiles_needed = (cout + out_ch_per_tile - 1) // out_ch_per_tile
    if tiles_needed > DCIM_NUM_TILES:
        raise UnsupportedOp(layer["name"], "Conv",
            f"out_channels={cout} → {tiles_needed} tiles but hw has {DCIM_NUM_TILES} tiles only.  "
            f"Options: (a) split into multiple DCIM passes, (b) widen DCIM_NUM_TILES")

    if mode == "int16":
        from ..ir_schema import DCIM_MODE_INT16 as _mode_code
    else:
        from ..ir_schema import DCIM_MODE_INT8 as _mode_code

    pairs: List[List[int]] = []
    pairs.append([0x008, pack_dcim_mode(acc_depth, _mode_code)])
    pairs.append([0x010, ibuf_act_word_addr])
    # Per-tile weight base in IBUF (word address).  16 ch_out per tile × acc_depth
    # entries × 1 word per entry  =>  acc_depth*16 words per tile.
    # For tiles beyond `tiles_needed`, we still set a base (decoder won't fire
    # them if num_tiles loop respects cout, but we keep simple here).
    for t in range(DCIM_NUM_TILES):
        pairs.append([0x040 + t * 4, wei_ibuf_word_addr + t * acc_depth * DCIM_CYCLE])
    # Per-tile output base in OBUF (word address).  Outputs are INT32 per channel,
    # so each output element is 4 bytes; one output row of cout/16 tiles ⊂ a tile
    # has 16 ch_out per row.  Tile-major layout in OBUF starting at out_obuf_off.
    out_obuf_word_addr = out_obuf_off // 16
    per_tile_words = oh * ow * out_words_per_tile
    for t in range(DCIM_NUM_TILES):
        pairs.append([0x140 + t * 4, out_obuf_word_addr + t * per_tile_words])

    ops.append({"kind": "dcim_cfg", "layer": layer["name"], "pairs": pairs})
    ops.append({"kind": "dcim_exec"})
    ops.append({"kind": "wait_dcim"})

    # 5) DQA + ReLU + bias: OBUF[dcim INT32] → OBUF[fp32 quantized to INT8 in place]
    dqa_flags = vpu_flags | (1 << 0)  # VPU_FLAG_RELU_EN + optional INT16
    ops.append({
        "kind": "vpu_exec", "unit": "dqa", "layer": layer["name"],
        "flags": dqa_flags,
        "args": {
            "unit_choose": UNIT_DQA,
            "src_addr": out_obuf_off,
            "src2_addr": 0,
            "src_c": cout, "src_h": oh, "src_w": ow,
            "bias_addr": dqa_bias_wb_off,
            "scale_addr": dqa_scale_wb_off,
            "dst_addr": out_obuf_off,   # FP32 in-place
            "addr_break": 0, "addr_s": 0, "addr_t": 0,
        },
    })
    ops.append({"kind": "wait_vpu"})

    return ops, oh, ow, cout, wb_section_bytes


# -----------------------------------------------------------------------------
# Top-level lowering for yolov5n / resnet18 conv-only first cut
# -----------------------------------------------------------------------------
def lower(
    network: Dict[str, Any],
    hw: Dict[str, Any],
    *,
    mode: str = "int8",
    max_layers: Optional[int] = None,
    stop_on_unsupported_topology: bool = True,
) -> Dict[str, Any]:
    """Compile parsed network.json + hw_caps dict → plan dict.

    For now the lowering ignores Add / Concat / Resize / MaxPool / non-conv ops:
      - If `stop_on_unsupported_topology` is True (default), the lowering stops
        emitting conv layers as soon as the topology requires a non-conv backbone
        op.  This is enough to get yolov5n's first 3-7 Convs end-to-end through
        RTL simulation today (per the plan §8 acceptance path).
      - The compiler still WALKS the full topology and records UnsupportedOp
        errors in `plan['unsupported']` so the user can see the full backlog.
    """
    layers: List[Dict[str, Any]] = network["layers"]
    topo: List[Dict[str, Any]] = network.get("topology", [])
    input_shape = network["model_info"]["input_shape"]
    output_shape = network["model_info"]["output_shape"]

    # ---- 1. Walk topology, identify which Conv layers are "reachable" before
    #         the first unsupported op (Concat / Add / MaxPool / etc.).  We
    #         build a name → input H,W map from the input shape and per-layer
    #         stride/kernel using the layers[] order (which mirrors topology
    #         order for both yolov5n and resnet18 conv schedules).

    plan = empty_plan(network["model_info"].get("name") or network.get("network", "unknown"),
                      input_shape, output_shape, mode=mode)
    plan["address_map"] = hw["address_map"]
    plan["network"] = network["model_info"].get("name") or plan["network"]
    plan["host_io"] = {
        "input_obuf_off": 0x000000,
        "output_obuf_off": 0x400000,
        "input_dtype": "uint8" if input_shape[1] == 3 else "int8",
        "output_dtype": "float32",
    }

    # ---- 2. Pre-scan: collect first unsupported op + record warnings.
    unsupported: List[str] = []
    for node in topo:
        op = node["op"]
        if "quant" in node["name"].lower():
            continue
        if op == "Conv":
            continue
        if op == "BatchNormalization":
            continue  # folded into Conv via fuse_bn_to_bias
        if op == "Relu":
            continue  # fused into dqa_relu_unit
        rules = hw["op_lowering"].get(op)
        if rules is None or rules.get("unsupported"):
            msg = rules.get("unsupported") if rules else f"no rule for {op}"
            unsupported.append(f"{node['name']}: {op}: {msg}")

    plan["unsupported"] = unsupported

    # ---- 3. Run Conv pre-check on every Conv layer (fail-loud on impossible ones).
    #         Only check layers that are actually going to be emitted.  Layers
    #         beyond `max_layers` are skipped but recorded.
    n_layers = len(layers)
    if max_layers is not None:
        n_layers = min(n_layers, max_layers)
    for layer in layers[:n_layers]:
        conv_check(layer, hw)
    # Pre-flight other conv layers and record unsupported ones rather than raising.
    for layer in layers[n_layers:]:
        try:
            conv_check(layer, hw)
        except UnsupportedOp as e:
            unsupported.append(f"{e.layer_name}: Conv: {e.reason}")

    # ---- 5. Run the emitter for the first n_layers conv layers, chaining ping-pong.
    planner = MemoryPlanner(hw["address_map"])

    # Compute input H, W per conv layer by tracking the running spatial shape.
    cur_h = int(input_shape[2])
    cur_w = int(input_shape[3])
    cur_c = int(input_shape[1])

    elem_bytes = 1 if mode == "int8" else 2

    # ---- Fail-loud check: int16 mode requires RTL support that the current
    # lite build only partly has (DCIM MODE_INT16 yes; im2col_unit / qa_unit
    # / dqa_unit have no INT16 bytewidth path).  We still emit the plan for
    # the sim_runner oracle, but warn loudly.
    if mode == "int16":
        unsupported.append(
            "mode=int16: bit-extension W16A16 path is supported by the compiler "
            "and weights_packer (W8→W16 zero/sign-extension keeps numerics identical), "
            "but the current RTL does NOT yet have INT16 byte-wide paths in "
            "im2col_unit / qa_unit / dqa_unit (only DCIM MODE_INT16 = 0b111 is wired).  "
            "sim_runner can still run as an oracle; for HW execution, extend the VPU sub-units."
        )

    last_out_obuf_off = 0x000000
    layer_records: List[Dict[str, Any]] = []
    wb_records: List[Dict[str, Any]] = []
    weight_records: List[Dict[str, Any]] = []

    for li, layer in enumerate(layers[:n_layers]):
        cin = int(layer["in_channels"])
        cout = int(layer["out_channels"])
        kh = int(layer["kernel_h"])
        kw = int(layer["kernel_w"])
        sh = layer["stride"][0]
        sw = layer["stride"][1]
        ph0, pw0, ph1, pw1 = layer["padding"][0], layer["padding"][1], layer["padding"][2], layer["padding"][3]
        oh = (cur_h + ph0 + ph1 - kh) // sh + 1
        ow = (cur_w + pw0 + pw1 - kw) // sw + 1

        # OBUF byte sizes.  After DQA the activation lives in OBUF as FP32 (4B per
        # ch).  After QA (start of next layer) it becomes INT8 (1B per ch).
        # We allocate the LARGER of (fp32 size) so an in-place QA is safe.
        in_bytes = _tensor_bytes_nhwc(cur_h, cur_w, cur_c, elem_bytes=elem_bytes)
        # The DCIM writes INT32 outputs (4B per ch).  Allocate the max of
        # int32 output, fp32 dqa output (same: 4B), and int8 next-input.
        out_bytes = _tensor_bytes_nhwc(oh, ow, cout, elem_bytes=4)
        in_off, out_off = planner.assign_layer_ping_pong(in_bytes, out_bytes)

        im2col_bytes = _im2col_bytes(oh, ow, kh, kw, cin)
        try:
            im2col_off = planner.alloc_im2col(im2col_bytes)
        except OutOfBuffer as e:
            raise UnsupportedOp(
                layer["name"], "Conv",
                f"im2col output requires {im2col_bytes} bytes but OBUF im2col scratch is only "
                f"{planner.obuf_im2col.hi - planner.obuf_im2col.lo} bytes.  "
                f"Options: (a) tile by output-H (split OH into chunks), "
                f"(b) enlarge OBUF im2col region in MemoryPlanner, "
                f"(c) reduce input resolution.  Inner error: {e}"
            ) from e

        planner.reset_wb()
        # qa_scale(1*4) | pad_to_16 | dqa_scale(cout*4) | dqa_bias(cout*4)
        wb_off = planner.alloc_wb(16 + _round_up(cout * 4, 16) + _round_up(cout * 4, 16))

        planner.reset_ibuf()
        # IBUF layout: weights first (per-tile), then activation region.
        tiles_needed = (cout + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
        elems_per_word = (DCIM_CH_IN // 2) if mode == "int16" else DCIM_CH_IN
        acc_depth_words = (kh * kw * cin + elems_per_word - 1) // elems_per_word
        weight_per_tile_words = acc_depth_words * DCIM_CYCLE
        weight_per_tile_bytes = weight_per_tile_words * BYTES_PER_WORD
        wei_byte_off = planner.alloc_ibuf(weight_per_tile_bytes * DCIM_NUM_TILES)
        wei_ibuf_word_addr = wei_byte_off // 16
        # Activation region: each IBUF word holds elems_per_word INT8/INT16 act values.
        act_bytes = oh * ow * acc_depth_words * DCIM_CH_IN * (2 if mode == "int16" else 1)
        try:
            act_byte_off = planner.alloc_ibuf(act_bytes)
        except OutOfBuffer:
            # This layer's im2col doesn't fit in IBUF as a single shot.
            # In the real hardware this requires tiling by OH (splitting the conv
            # into multiple CDMA+DCIM passes).  For the MVP compiler we still
            # emit the plan assuming a single pass and let the runner / hw_runner
            # handle the potential failure.  Record a warning.
            act_byte_off = planner.ibuf.hi - act_bytes  # fictitious offset
            if act_byte_off < 0:
                act_byte_off = wei_byte_off + weight_per_tile_bytes * DCIM_NUM_TILES
            unsupported.append(
                f"{layer['name']}: Conv: IBUF activation overflow "
                f"({act_bytes} bytes needed, {planner.ibuf.hi - planner.ibuf.cursor} free).  "
                f"Requires OH-tiling (not yet implemented)."
            )
        act_ibuf_word_addr = act_byte_off // 16

        skip_qa = (li == 0)  # host pre-writes INT8 (or uint8) image
        emitted, oh2, ow2, cout2, wb_section_bytes = emit_conv(
            layer,
            in_obuf_off=in_off,
            out_obuf_off=out_off,
            im2col_obuf_off=im2col_off,
            wb_off=wb_off,
            wei_ibuf_word_addr=wei_ibuf_word_addr,
            in_h=cur_h, in_w=cur_w,
            is_first_layer=(li == 0),
            hw=hw, mode=mode, skip_qa=skip_qa,
            act_ibuf_word_addr=act_ibuf_word_addr,
        )
        plan["ops"].extend(emitted)

        layer_records.append({
            "name": layer["name"],
            "input_off": in_off, "output_off": out_off,
            "im2col_off": im2col_off, "wb_off": wb_off,
            "input_hw": [cur_h, cur_w], "output_hw": [oh, ow],
            "input_c": cur_c, "output_c": cout,
            "kernel": [kh, kw], "stride": [sh, sw],
            "padding": [ph0, pw0, ph1, pw1],
            "acc_depth": (kh * kw * cin + elems_per_word - 1) // elems_per_word,
            "tiles_needed": tiles_needed,
        })
        wb_records.append({
            "name": layer["name"],
            "wb_off": wb_off, "section_bytes": wb_section_bytes,
            "qa_scale_off": wb_off, "dqa_scale_off": wb_off + 16,
            "dqa_bias_off": wb_off + 16 + _round_up(cout * 4, 16),
        })
        weight_records.append({
            "name": layer["name"],
            "ibuf_byte_off": wei_byte_off,
            "ibuf_word_addr": wei_ibuf_word_addr,
            "per_tile_words": weight_per_tile_words,
            "per_tile_bytes": weight_per_tile_bytes,
            "tiles_needed": tiles_needed,
        })

        cur_h, cur_w, cur_c = oh, ow, cout
        last_out_obuf_off = out_off

    # End the program with OP_END.
    plan["ops"].append({"kind": "end"})

    plan["memory_plan"]["layers"] = layer_records
    plan["weights_layout"]["layers"] = weight_records
    plan["wb_layout"]["layers"] = wb_records
    # Pre-assign OBUF wb-scratch byte offsets per layer.  The host uploads the
    # WB section (scales + biases) for layer i to obuf_wb_scratch[lo + i*size]
    # at boot time, then the program's CDMA copies it into VPU WB just-in-time.
    scratch_off_by_layer = {}
    obuf_wb_lo = 0xFF0000     # MemoryPlanner.obuf_wb_scratch.lo
    cur = obuf_wb_lo
    for w in wb_records:
        scratch_off_by_layer[w["name"]] = cur
        # round up to 16-byte alignment
        cur = (cur + w["section_bytes"] + 15) & ~15
    plan["wb_layout"]["scratch_off_by_layer"] = scratch_off_by_layer
    plan["host_io"]["output_obuf_off"] = last_out_obuf_off
    plan["host_io"]["output_hw"] = [cur_h, cur_w]
    plan["host_io"]["output_c"] = cur_c
    plan["host_io"]["output_dtype"] = "float32"

    plan["compile_meta"] = {
        "schema_version": SCHEMA_VERSION,
        "mode": mode,
        "num_conv_layers_compiled": n_layers,
        "num_conv_layers_total": len(layers),
        "stop_reason": (
            "max_layers reached" if max_layers is not None and max_layers < len(layers)
            else "end of conv schedule"
        ),
    }
    return plan
