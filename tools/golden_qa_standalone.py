#!/usr/bin/env python3
"""
golden_qa_standalone.py - QA unit standalone test golden generator.

Matches hardware:
  - FP32 input packed 4 values / 128-bit OBUF word (ch0 in [31:0], little-endian bytes)
  - Symmetric INT8: clamp(round(fp * qscale), -128, 127)
  - Output NHWC flatten -> bytes_to_128_words (same as golden_e2e_inst.py)

Usage:
  python3 tools/golden_qa_standalone.py [--out rtl/vpu/tb/e2e/qa_standalone_golden.svh]
"""
from __future__ import annotations

import argparse
import os
import struct
import sys
from dataclasses import dataclass
from typing import List, Sequence, Tuple

import numpy as np

FP_CORE_NUM = 4
OBUF_WORD_BYTES = 16


def fp32_to_bits(x: float) -> int:
    return struct.unpack(">I", struct.pack(">f", float(x)))[0]


def bits_to_fp32_hex(bits: int) -> str:
    return f"32'h{bits:08x}"


def pack_fp32_obuf_words(fp_values: Sequence[float]) -> List[int]:
    """Return list of 128-bit integers (SV {fp3,fp2,fp1,fp0} style)."""
    vals = list(fp_values)
    pad = (-len(vals)) % FP_CORE_NUM
    vals.extend([0.0] * pad)
    words = []
    for i in range(0, len(vals), FP_CORE_NUM):
        chunk = vals[i : i + FP_CORE_NUM]
        word = 0
        for j, v in enumerate(chunk):
            word |= fp32_to_bits(v) << (32 * j)
        words.append(word)
    return words


def bytes_to_128_words(byte_blob: bytes) -> List[int]:
    pad = (-len(byte_blob)) % OBUF_WORD_BYTES
    blob = byte_blob + b"\x00" * pad
    words = []
    for i in range(0, len(blob), OBUF_WORD_BYTES):
        chunk = blob[i : i + OBUF_WORD_BYTES]
        w = 0
        for j, b in enumerate(chunk):
            w |= int(b) << (8 * j)
        words.append(w)
    return words


def qa_quantize(fp_values: Sequence[float], qscale: float) -> np.ndarray:
    arr = np.asarray(fp_values, dtype=np.float64)
    return np.clip(np.round(arr * qscale), -128, 127).astype(np.int8)


def nhwc_flat(fp_nhwc: np.ndarray) -> List[float]:
    """fp_nhwc shape [H, W, C] -> NHWC flat list."""
    h, w, c = fp_nhwc.shape
    out = []
    for y in range(h):
        for x in range(w):
            for ch in range(c):
                out.append(float(fp_nhwc[y, x, ch]))
    return out


@dataclass
class QaCase:
    name: str
    h: int
    w: int
    c: int
    qscale: float
    src_word_base: int
    dst_word_base: int
    fp_values: List[float]
    expect_int8: List[int]
    expect_words: List[int]
    expect_save_count: int
    check_upper_zero: bool


def build_case(
    name: str,
    h: int,
    w: int,
    c: int,
    qscale: float,
    fp_values: Sequence[float],
    src_word_base: int = 0,
    dst_word_base: int = 16,
    check_upper_zero: bool = False,
) -> QaCase:
    assert len(fp_values) == h * w * c
    int8 = qa_quantize(fp_values, qscale)
    words = bytes_to_128_words(int8.tobytes())
    total_fp = h * w * c
    save_count = (total_fp + FP_CORE_NUM - 1) // FP_CORE_NUM
    return QaCase(
        name=name,
        h=h,
        w=w,
        c=c,
        qscale=qscale,
        src_word_base=src_word_base,
        dst_word_base=dst_word_base,
        fp_values=list(fp_values),
        expect_int8=[int(x) for x in int8.tolist()],
        expect_words=words,
        expect_save_count=save_count,
        check_upper_zero=check_upper_zero or (total_fp <= FP_CORE_NUM),
    )


def default_cases() -> List[QaCase]:
    cases = []

    # T1: original minimal — 4ch, 1 slot, upper 96 bits must stay zero
    cases.append(
        build_case(
            "t1_min_4ch",
            h=1,
            w=1,
            c=4,
            qscale=0.5,
            fp_values=[2.5, 5.7, 100.3, -3.0],
            src_word_base=0,
            dst_word_base=16,
            check_upper_zero=True,
        )
    )

    # T2: full 128-bit word — 16 distinct channels, 4 slots must differ
    fp16 = [float(i * 3.7 - 5.2) for i in range(16)]
    cases.append(
        build_case(
            "t2_full_word_16ch",
            h=1,
            w=1,
            c=16,
            qscale=0.25,
            fp_values=fp16,
            src_word_base=32,
            dst_word_base=48,
        )
    )

    # T3: 8ch × 2 pixels — 4 saves, 1 output word
    fp_8x2 = []
    for pix in range(2):
        for ch in range(8):
            fp_8x2.append((pix + 1) * 10.0 + ch * 0.3)
    cases.append(
        build_case(
            "t3_8ch_2px",
            h=2,
            w=1,
            c=8,
            qscale=0.1,
            fp_values=fp_8x2,
            src_word_base=64,
            dst_word_base=80,
        )
    )

    # T4: 32ch — 2 output words (8 saves)
    fp32 = [float(np.sin(i * 0.7) * 40.0) for i in range(32)]
    cases.append(
        build_case(
            "t4_32ch_2words",
            h=1,
            w=1,
            c=32,
            qscale=0.2,
            fp_values=fp32,
            src_word_base=96,
            dst_word_base=112,
        )
    )

    # T5: 2×2 spatial, 4ch — distinct per-pixel values
    nhwc = np.zeros((2, 2, 4), dtype=np.float64)
    for y in range(2):
        for x in range(2):
            for ch in range(4):
                nhwc[y, x, ch] = (y * 2 + x) * 20.0 + ch * 1.1 - 3.0
    cases.append(
        build_case(
            "t5_2x2x4",
            h=2,
            w=2,
            c=4,
            qscale=0.5,
            fp_values=nhwc_flat(nhwc),
            src_word_base=128,
            dst_word_base=144,
            check_upper_zero=False,
        )
    )

    return cases


def emit_svh(cases: Sequence[QaCase], path: str) -> None:
    lines = [
        "// Auto-generated by tools/golden_qa_standalone.py — do not edit",
        "`ifndef QA_STANDALONE_GOLDEN_SVH",
        "`define QA_STANDALONE_GOLDEN_SVH",
        "",
        f"localparam int QA_STANDALONE_NUM_CASES = {len(cases)};",
        "",
    ]

    for idx, tc in enumerate(cases):
        n_words = len(pack_fp32_obuf_words(tc.fp_values))
        n_out = len(tc.expect_words)
        lines.append(f"// Case {idx}: {tc.name}")
        lines.append(f"localparam int QA_CASE_{idx}_H = {tc.h};")
        lines.append(f"localparam int QA_CASE_{idx}_W = {tc.w};")
        lines.append(f"localparam int QA_CASE_{idx}_C = {tc.c};")
        lines.append(f"localparam int QA_CASE_{idx}_SRC_BASE = {tc.src_word_base};")
        lines.append(f"localparam int QA_CASE_{idx}_DST_BASE = {tc.dst_word_base};")
        lines.append(f"localparam int QA_CASE_{idx}_N_IN_WORDS = {n_words};")
        lines.append(f"localparam int QA_CASE_{idx}_N_OUT_WORDS = {n_out};")
        lines.append(f"localparam int QA_CASE_{idx}_SAVE_COUNT = {tc.expect_save_count};")
        lines.append(f"localparam bit QA_CASE_{idx}_CHECK_UPPER_ZERO = {1 if tc.check_upper_zero else 0};")
        qbits = fp32_to_bits(tc.qscale)
        lines.append(f"localparam logic [31:0] QA_CASE_{idx}_QSCALE_BITS = 32'h{qbits:08x};")

        lines.append(f"localparam logic [127:0] QA_CASE_{idx}_IN [{n_words}] = '{{")
        for wi, w in enumerate(pack_fp32_obuf_words(tc.fp_values)):
            comma = "," if wi + 1 < n_words else ""
            lines.append(f"    128'h{w:032x}{comma}")
        lines.append("};")

        lines.append(f"localparam logic [127:0] QA_CASE_{idx}_OUT [{n_out}] = '{{")
        for wi, w in enumerate(tc.expect_words):
            comma = "," if wi + 1 < n_out else ""
            lines.append(f"    128'h{w:032x}{comma}")
        lines.append("};")
        lines.append("")

    lines.append("`endif // QA_STANDALONE_GOLDEN_SVH")
    lines.append("")

    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def self_check(cases: Sequence[QaCase]) -> None:
    for tc in cases:
        got = qa_quantize(tc.fp_values, tc.qscale)
        exp = np.asarray(tc.expect_int8, dtype=np.int8)
        if not np.array_equal(got, exp):
            raise SystemExit(f"self-check failed: {tc.name}")
        # T1 reference
        if tc.name == "t1_min_4ch":
            ref = np.array([1, 3, 50, -2], dtype=np.int8)
            if not np.array_equal(got, ref):
                raise SystemExit("t1 reference mismatch")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--out",
        default=os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "rtl",
            "vpu",
            "tb",
            "e2e",
            "qa_standalone_golden.svh",
        ),
    )
    args = ap.parse_args()
    cases = default_cases()
    self_check(cases)
    emit_svh(cases, args.out)
    print(f"Wrote {len(cases)} QA standalone cases -> {args.out}")
    for tc in cases:
        print(
            f"  {tc.name}: {tc.h}x{tc.w}x{tc.c} qscale={tc.qscale} "
            f"saves={tc.expect_save_count} out_words={len(tc.expect_words)}"
        )


if __name__ == "__main__":
    main()
