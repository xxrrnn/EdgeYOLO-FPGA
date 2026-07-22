"""Encode plan.ops → 32-bit instruction word stream for INST_BRAM.

The format mirrors `rtl/vpu/INST_Decoder.sv` 1:1.  The host writes the resulting
words into INST_BRAM and pokes `INST_COUNT` then `DECODER_CTRL = 1`.

CDMA instructions carry full 64-bit source/destination byte addresses as
MSB/LSB words.  We use the physical segment bases from hw_caps.address_map and
add the local byte offset emitted by lowering.
"""

from __future__ import annotations

import os
import sys
from typing import Any, Dict, List, Tuple

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))

from ..ir_schema import (
    OP_CDMA_COPY, OP_CDMA_STRIDE, OP_DCIM_CFG, OP_DCIM_EXEC, OP_DCIM_LAYER,
    OP_END, OP_NOP, OP_SYNC,
    OP_VPU_EXEC, OP_WAIT_CDMA, OP_WAIT_DCIM, OP_WAIT_VPU,
    VPU_UNIT_ID,
)
from chip_config import DCIM_NUM_TILES


def header(opcode: int, length: int, flags: int = 0) -> int:
    return ((opcode & 0xF) << 28) | ((flags & 0xF) << 24) | (length & 0xFFFFFF)


def _resolve_cdma_addr(addr_spec, plan, segment_base_lsb: Dict[str, int]) -> int:
    """Resolve an op's address spec to the 32-bit LSB used by CDMA.

    Supported spec forms (produced by lower.py):
      - int                              → absolute byte offset within the same
                                           segment (already an LSB)
      - ("obuf", off)                    → OBUF byte offset
      - ("ibuf", off)                    → IBUF byte offset
      - ("hbm", off)                     → HBM byte offset
      - ("wb", off) / ("wb_off", off)    → WB byte offset
      - ("obuf_wb_scratch_off_for_layer", name) →
                                           OBUF byte offset of that layer's WB-shadow
                                           region (added by codegen)
    """
    if isinstance(addr_spec, int):
        return addr_spec
    if isinstance(addr_spec, (list, tuple)) and len(addr_spec) == 2:
        kind, off = addr_spec
        if kind == "obuf":
            return segment_base_lsb["obuf"] + int(off)
        if kind == "ibuf":
            return segment_base_lsb["ibuf"] + int(off)
        if kind == "tile_obuf":
            return segment_base_lsb["tile_obuf"] + int(off)
        if kind == "hbm":
            return segment_base_lsb["hbm"] + int(off)
        if kind in ("wb", "wb_off"):
            return segment_base_lsb["wb"] + int(off)
        if kind == "obuf_wb_scratch_off_for_layer":
            # Codegen resolves this against memory_plan.obuf_wb_scratch by
            # name; we expect plan.wb_layout to have been augmented earlier.
            return segment_base_lsb["obuf"] + plan["wb_layout"]["scratch_off_by_layer"][off]
    raise ValueError(f"unrecognized address spec: {addr_spec!r}")


# ---- VPU_EXEC body (12 words, in INST_Decoder.sv order) ----
VPU_EXEC_FIELDS = (
    "unit_choose", "src_addr", "src2_addr", "src_c", "src_h", "src_w",
    "bias_addr", "scale_addr", "dst_addr", "addr_break", "addr_s", "addr_t",
)


def encode_vpu_exec(args: Dict[str, int], flags: int = 0) -> List[int]:
    body = [header(OP_VPU_EXEC, 12 * 4, flags=flags)]
    for f in VPU_EXEC_FIELDS:
        body.append(int(args.get(f, 0)) & 0xFFFFFFFF)
    return body


def _split64(addr: int) -> Tuple[int, int]:
    return (int(addr) >> 32) & 0xFFFFFFFF, int(addr) & 0xFFFFFFFF


def encode_cdma_copy(src_lsb: int, dst_lsb: int, length: int) -> List[int]:
    src_msb, src_lsb = _split64(src_lsb)
    dst_msb, dst_lsb = _split64(dst_lsb)
    return [
        header(OP_CDMA_COPY, 5 * 4),
        src_msb,
        src_lsb,
        dst_msb,
        dst_lsb,
        int(length) & 0xFFFFFFFF,
    ]


def encode_cdma_stride(src_addr: int, dst_addr: int, copy_bytes: int,
                       src_stride: int, dst_stride: int, count: int) -> List[int]:
    src_msb, src_lsb = _split64(src_addr)
    dst_msb, dst_lsb = _split64(dst_addr)
    return [
        header(OP_CDMA_STRIDE, 8 * 4),
        src_msb,
        src_lsb,
        dst_msb,
        dst_lsb,
        int(copy_bytes) & 0xFFFFFFFF,
        int(src_stride) & 0xFFFFFFFF,
        int(dst_stride) & 0xFFFFFFFF,
        int(count) & 0xFFFFFFFF,
    ]


def encode_dcim_cfg(pairs: List[List[int]]) -> List[int]:
    out = [header(OP_DCIM_CFG, len(pairs))]   # LENGTH = pair count
    for addr, data in pairs:
        out.append(int(addr) & 0xFFFFFFFF)
        out.append(int(data) & 0xFFFFFFFF)
    return out


def encode_dcim_layer(op: Dict[str, Any]) -> List[int]:
    """Encode OP_DCIM_LAYER, matching INST_Decoder.sv DCIM_LAYER_BODY_WORDS.

    Body layout:
      num_pixels, mode_reg, tile_mask_lo, tile_mask_hi,
      act_base_word, act_stride_words, out_stride_words, reserved,
      wei_base_words[DCIM_NUM_TILES], out_base_words[DCIM_NUM_TILES]
    """
    wei = list(op["wei_base_words"])
    out = list(op["out_base_words"])
    if len(wei) != DCIM_NUM_TILES or len(out) != DCIM_NUM_TILES:
        raise ValueError(
            f"dcim_layer requires {DCIM_NUM_TILES} wei/out bases, got {len(wei)}/{len(out)}"
        )
    tile_mask = int(op["tile_mask"])
    body = [
        int(op["num_pixels"]),
        int(op["mode_reg"]),
        tile_mask & 0xFFFFFFFF,
        (tile_mask >> 32) & 0xFFFFFFFF,
        int(op["act_base_word"]),
        int(op["act_stride_words"]),
        int(op["out_stride_words"]),
        int(op.get("reserved", 0)),
    ] + [int(x) for x in wei] + [int(x) for x in out]
    return [header(OP_DCIM_LAYER, len(body) * 4)] + [w & 0xFFFFFFFF for w in body]


# Op kind → encoder shortcut
def encode_op(op: Dict[str, Any], plan, segment_base_lsb: Dict[str, int]) -> List[int]:
    kind = op["kind"]
    if kind == "nop":
        return [header(OP_NOP, 0)]
    if kind == "end":
        return [header(OP_END, 0)]
    if kind == "wait_vpu":
        return [header(OP_WAIT_VPU, 0)]
    if kind == "wait_cdma":
        return [header(OP_WAIT_CDMA, 0)]
    if kind == "wait_dcim":
        return [header(OP_WAIT_DCIM, 0)]
    if kind == "sync":
        return [header(OP_SYNC, 0)]
    if kind == "dcim_exec":
        return [header(OP_DCIM_EXEC, 0)]
    if kind == "dcim_cfg":
        return encode_dcim_cfg(op["pairs"])
    if kind == "dcim_layer":
        return encode_dcim_layer(op)
    if kind == "cdma_copy":
        src_lsb = _resolve_cdma_addr(op["src"], plan, segment_base_lsb)
        dst_lsb = _resolve_cdma_addr(op["dst"], plan, segment_base_lsb)
        return encode_cdma_copy(src_lsb, dst_lsb, op["length"])
    if kind == "cdma_stride":
        src_lsb = _resolve_cdma_addr(op["src"], plan, segment_base_lsb)
        dst_lsb = _resolve_cdma_addr(op["dst"], plan, segment_base_lsb)
        return encode_cdma_stride(src_lsb, dst_lsb, op["copy_bytes"],
                                  op["src_stride"], op["dst_stride"], op["count"])
    if kind == "vpu_exec":
        a = dict(op["args"])
        if "unit" in op and op["unit"] in VPU_UNIT_ID:
            a["unit_choose"] = VPU_UNIT_ID[op["unit"]]
        flags = op.get("flags", 0)
        return encode_vpu_exec(a, flags=flags)
    raise ValueError(f"unknown op kind {kind!r}")


def encode_plan(plan: Dict[str, Any]) -> List[int]:
    """Encode the full plan.ops into a list of 32-bit words.

    The address_map in plan["address_map"] is used to convert local OBUF/IBUF/WB
    byte offsets into full physical byte addresses for CDMA.  The encoder then
    splits those addresses into MSB/LSB words for OP_CDMA_COPY and
    OP_CDMA_STRIDE.
    """
    return encode_ops(plan, plan["ops"])


def encode_ops(plan: Dict[str, Any], ops: List[Dict[str, Any]]) -> List[int]:
    """Encode a supplied op list using `plan` for address-map/layout context."""
    seg = {
        "ibuf": int(plan["address_map"]["ibuf_base"]),
        "tile_obuf": int(plan["address_map"].get("tile_obuf_base", 0x1_0100_0000)),
        "obuf": int(plan["address_map"]["obuf_base"]),
        "hbm": int(plan["address_map"].get("hbm_base", 0)),
        "wb": int(plan["address_map"]["wb_base"]),
    }
    words: List[int] = []
    for op in ops:
        words.extend(encode_op(op, plan, seg))
    return words


def write_program_hex(words: List[int], path: str) -> None:
    with open(path, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")


def write_program_bin(words: List[int], path: str) -> None:
    with open(path, "wb") as f:
        for w in words:
            f.write(int(w & 0xFFFFFFFF).to_bytes(4, "little"))
