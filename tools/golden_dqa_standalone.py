#!/usr/bin/env python3
"""
golden_dqa_standalone.py - DQA unit standalone test golden generator.

Matches hardware:
  - INT32 input packed 4 values / 128-bit OBUF word (ch0 in [31:0], little-endian)
  - DQA: int32_to_fp32 → fp_mac(fp*scale + bias) → FP32 output
  - Output NHWC flatten → bytes_to_128_words (same as QA golden)

Usage:
  python3 tools/golden_dqa_standalone.py [--out rtl/vpu/tb/e2e/dqa_standalone_golden.svh]
"""
from __future__ import annotations

import argparse
import os
import struct
from dataclasses import dataclass
from typing import List, Sequence

import numpy as np

FP_CORE_NUM = 4
OBUF_WORD_BYTES = 16


def int32_to_bits(x: int) -> int:
    return struct.unpack(">I", struct.pack(">i", int(x)))[0]


def fp32_to_bits(x: float) -> int:
    return struct.unpack(">I", struct.pack(">f", float(x)))[0]


def pack_int32_obuf_words(int_values: Sequence[int]) -> List[int]:
    """Pack INT32 values into 128-bit words (4 INT32 per word, little-endian)."""
    vals = list(int_values)
    pad = (-len(vals)) % FP_CORE_NUM
    vals.extend([0] * pad)
    words = []
    for i in range(0, len(vals), FP_CORE_NUM):
        chunk = vals[i : i + FP_CORE_NUM]
        word = 0
        for j, v in enumerate(chunk):
            word |= int32_to_bits(v) << (32 * j)
        words.append(word)
    return words


def pack_fp32_obuf_words(fp_values: Sequence[float]) -> List[int]:
    """Pack FP32 values into 128-bit words (4 FP32 per word, little-endian)."""
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


def dqa_compute(int32_vals: Sequence[int], scale: Sequence[float], bias: Sequence[float]) -> np.ndarray:
    """DQA: int32 → fp32 → fp_mac(fp*scale + bias)."""
    arr = np.asarray(int32_vals, dtype=np.float32)
    sc = np.asarray(scale, dtype=np.float32)
    bi = np.asarray(bias, dtype=np.float32)
    return arr * sc + bi


def nhwc_flat(fp_nhwc: np.ndarray) -> List[float]:
    """fp_nhwc shape [H, W, C] → NHWC flat list."""
    h, w, c = fp_nhwc.shape
    out = []
    for y in range(h):
        for x in range(w):
            for ch in range(c):
                out.append(float(fp_nhwc[y, x, ch]))
    return out


@dataclass
class DqaCase:
    name: str
    h: int
    w: int
    c: int
    scale: List[float]
    bias: List[float]
    src_word_base: int
    dst_word_base: int
    int32_values: List[int]
    expect_fp32: List[float]
    expect_words: List[int]


def build_case(
    name: str,
    h: int,
    w: int,
    c: int,
    scale: Sequence[float],
    bias: Sequence[float],
    int32_values: Sequence[int],
    src_word_base: int = 0,
    dst_word_base: int = 16,
) -> DqaCase:
    assert len(int32_values) == h * w * c
    assert len(scale) == c
    assert len(bias) == c
    
    # Reshape to NHWC, apply per-channel scale/bias
    nhwc = np.asarray(int32_values, dtype=np.float32).reshape(h, w, c)
    sc = np.asarray(scale, dtype=np.float32)
    bi = np.asarray(bias, dtype=np.float32)
    dqa_out = nhwc * sc[None, None, :] + bi[None, None, :]
    
    fp32_flat = nhwc_flat(dqa_out)
    words = pack_fp32_obuf_words(fp32_flat)
    
    return DqaCase(
        name=name,
        h=h,
        w=w,
        c=c,
        scale=list(scale),
        bias=list(bias),
        src_word_base=src_word_base,
        dst_word_base=dst_word_base,
        int32_values=list(int32_values),
        expect_fp32=fp32_flat,
        expect_words=words,
    )


def default_cases() -> List[DqaCase]:
    cases = []

    # T1: 4ch, 1px — minimal case
    cases.append(
        build_case(
            "t1_min_4ch",
            h=1,
            w=1,
            c=4,
            scale=[0.1, 0.2, 0.3, 0.4],
            bias=[1.0, 2.0, 3.0, 4.0],
            int32_values=[100, 200, 300, 400],
            src_word_base=0,
            dst_word_base=16,
        )
    )

    # T2: 16ch, 1px — full 128-bit word
    int32_16 = [i * 10 - 50 for i in range(16)]
    scale_16 = [0.01 * (i + 1) for i in range(16)]
    bias_16 = [float(i - 8) for i in range(16)]
    cases.append(
        build_case(
            "t2_full_word_16ch",
            h=1,
            w=1,
            c=16,
            scale=scale_16,
            bias=bias_16,
            int32_values=int32_16,
            src_word_base=32,
            dst_word_base=48,
        )
    )

    # T3: 8ch × 2px
    int32_8x2 = []
    for pix in range(2):
        for ch in range(8):
            int32_8x2.append((pix + 1) * 100 + ch * 10)
    scale_8 = [0.05 * (i + 1) for i in range(8)]
    bias_8 = [float(i) for i in range(8)]
    cases.append(
        build_case(
            "t3_8ch_2px",
            h=2,
            w=1,
            c=8,
            scale=scale_8,
            bias=bias_8,
            int32_values=int32_8x2,
            src_word_base=64,
            dst_word_base=80,
        )
    )

    # T4: 2×2×4 spatial
    nhwc_int = np.zeros((2, 2, 4), dtype=np.int32)
    for y in range(2):
        for x in range(2):
            for ch in range(4):
                nhwc_int[y, x, ch] = (y * 2 + x) * 1000 + ch * 100
    cases.append(
        build_case(
            "t4_2x2x4",
            h=2,
            w=2,
            c=4,
            scale=[0.001, 0.002, 0.003, 0.004],
            bias=[0.5, 1.0, 1.5, 2.0],
            int32_values=nhwc_int.flatten().tolist(),
            src_word_base=96,
            dst_word_base=112,
        )
    )

    return cases


def emit_svh(cases: Sequence[DqaCase], path: str) -> None:
    lines = [
        "// Auto-generated by tools/golden_dqa_standalone.py — do not edit",
        "`ifndef DQA_STANDALONE_GOLDEN_SVH",
        "`define DQA_STANDALONE_GOLDEN_SVH",
        "",
        f"localparam int DQA_STANDALONE_NUM_CASES = {len(cases)};",
        "",
    ]

    for idx, tc in enumerate(cases):
        n_in_words = len(pack_int32_obuf_words(tc.int32_values))
        n_out = len(tc.expect_words)
        lines.append(f"// Case {idx}: {tc.name}")
        lines.append(f"localparam int DQA_CASE_{idx}_H = {tc.h};")
        lines.append(f"localparam int DQA_CASE_{idx}_W = {tc.w};")
        lines.append(f"localparam int DQA_CASE_{idx}_C = {tc.c};")
        lines.append(f"localparam int DQA_CASE_{idx}_SRC_BASE = {tc.src_word_base};")
        lines.append(f"localparam int DQA_CASE_{idx}_DST_BASE = {tc.dst_word_base};")
        lines.append(f"localparam int DQA_CASE_{idx}_N_IN_WORDS = {n_in_words};")
        lines.append(f"localparam int DQA_CASE_{idx}_N_OUT_WORDS = {n_out};")

        lines.append(f"localparam logic [127:0] DQA_CASE_{idx}_IN [{n_in_words}] = '{{")
        for wi, w in enumerate(pack_int32_obuf_words(tc.int32_values)):
            comma = "," if wi + 1 < n_in_words else ""
            lines.append(f"    128'h{w:032x}{comma}")
        lines.append("};")

        lines.append(f"localparam logic [127:0] DQA_CASE_{idx}_SCALE [{(tc.c + 3) // 4}] = '{{")
        scale_words = pack_fp32_obuf_words(tc.scale)
        for wi, w in enumerate(scale_words):
            comma = "," if wi + 1 < len(scale_words) else ""
            lines.append(f"    128'h{w:032x}{comma}")
        lines.append("};")

        lines.append(f"localparam logic [127:0] DQA_CASE_{idx}_BIAS [{(tc.c + 3) // 4}] = '{{")
        bias_words = pack_fp32_obuf_words(tc.bias)
        for wi, w in enumerate(bias_words):
            comma = "," if wi + 1 < len(bias_words) else ""
            lines.append(f"    128'h{w:032x}{comma}")
        lines.append("};")

        lines.append(f"localparam logic [127:0] DQA_CASE_{idx}_OUT [{n_out}] = '{{")
        for wi, w in enumerate(tc.expect_words):
            comma = "," if wi + 1 < n_out else ""
            lines.append(f"    128'h{w:032x}{comma}")
        lines.append("};")
        lines.append("")

    lines.append("`endif // DQA_STANDALONE_GOLDEN_SVH")
    lines.append("")

    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def self_check(cases: Sequence[DqaCase]) -> None:
    for tc in cases:
        nhwc = np.asarray(tc.int32_values, dtype=np.float32).reshape(tc.h, tc.w, tc.c)
        sc = np.asarray(tc.scale, dtype=np.float32)
        bi = np.asarray(tc.bias, dtype=np.float32)
        got = (nhwc * sc[None, None, :] + bi[None, None, :]).flatten()
        exp = np.asarray(tc.expect_fp32, dtype=np.float32)
        if not np.allclose(got.reshape(tc.h, tc.w, tc.c), np.asarray(tc.expect_fp32).reshape(tc.h, tc.w, tc.c), rtol=1e-5):
            raise SystemExit(f"self-check failed: {tc.name}")


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
            "dqa_standalone_golden.svh",
        ),
    )
    args = ap.parse_args()
    cases = default_cases()
    self_check(cases)
    emit_svh(cases, args.out)
    print(f"Wrote {len(cases)} DQA standalone cases -> {args.out}")
    for tc in cases:
        print(
            f"  {tc.name}: {tc.h}x{tc.w}x{tc.c} "
            f"in_words={len(pack_int32_obuf_words(tc.int32_values))} "
            f"out_words={len(tc.expect_words)}"
        )


if __name__ == "__main__":
    main()
