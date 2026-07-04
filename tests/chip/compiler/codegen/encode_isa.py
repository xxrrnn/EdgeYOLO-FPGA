"""Encode plan.ops → 32-bit instruction word stream for INST_BRAM.

The format mirrors `rtl/vpu/INST_Decoder.sv` 1:1.  The host writes the resulting
words into INST_BRAM and pokes `INST_COUNT` then `DECODER_CTRL = 1`.

The CDMA source/destination LSB fields are byte addresses within the local AXI
segment (the decoder forces MSB = 0; smartconnect routes by segment).  We use
the segment bases from hw_caps.address_map and compute LSB by adding the local
byte offset.
"""

from __future__ import annotations

from typing import Any, Dict, List, Tuple

from ..ir_schema import (
    OP_CDMA_COPY, OP_CDMA_STRIDE, OP_DCIM_CFG, OP_DCIM_EXEC, OP_END, OP_NOP, OP_SYNC,
    OP_VPU_EXEC, OP_WAIT_CDMA, OP_WAIT_DCIM, OP_WAIT_VPU,
    VPU_UNIT_ID,
)


def header(opcode: int, length: int, flags: int = 0) -> int:
    return ((opcode & 0xF) << 28) | ((flags & 0xF) << 24) | (length & 0xFFFFFF)


def _resolve_cdma_addr(addr_spec, plan, segment_base_lsb: Dict[str, int]) -> int:
    """Resolve an op's address spec to the 32-bit LSB used by CDMA.

    Supported spec forms (produced by lower.py):
      - int                              → absolute byte offset within the same
                                           segment (already an LSB)
      - ("obuf", off)                    → OBUF byte offset
      - ("ibuf", off)                    → IBUF byte offset
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


def encode_cdma_copy(src_lsb: int, dst_lsb: int, length: int) -> List[int]:
    return [
        header(OP_CDMA_COPY, 3 * 4),
        int(src_lsb) & 0xFFFFFFFF,
        int(dst_lsb) & 0xFFFFFFFF,
        int(length) & 0xFFFFFFFF,
    ]


def encode_cdma_stride(src_addr: int, dst_addr: int, copy_bytes: int,
                       src_stride: int, dst_stride: int, count: int) -> List[int]:
    return [
        header(OP_CDMA_STRIDE, 6 * 4),
        int(src_addr) & 0xFFFFFFFF,
        int(dst_addr) & 0xFFFFFFFF,
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
    byte offsets into the LSB values that the CDMA controller expects.  All MSBs
    are forced to 0 by the decoder (see INST_Decoder.sv:553-558), so we encode
    only the low 32 bits.

    For the EdgeYOLO-FPGA-lite address map, the four DMA-able segments live at
        IBUF  = 0x1_0000_0000
        OBUF  = 0x1_0100_0000
        WB    = 0x1_0200_0000
    so the LSB is simply the low 32 bits of (base + local_offset).
    """
    seg = {
        "ibuf": int(plan["address_map"]["ibuf_base"]) & 0xFFFFFFFF,
        "obuf": int(plan["address_map"]["obuf_base"]) & 0xFFFFFFFF,
        "wb":   int(plan["address_map"]["wb_base"]) & 0xFFFFFFFF,
    }
    words: List[int] = []
    for op in plan["ops"]:
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
