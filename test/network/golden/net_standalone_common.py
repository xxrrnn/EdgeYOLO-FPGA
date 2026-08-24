#!/usr/bin/env python3
"""
Shared YOLOv5n conv layer definitions for standalone unit tests.

Standalone uses scale=1.0 (full 160x160 L1 input → 80x80 outputs).
E2E may use smaller spatial scale for speed (see golden_e2e_inst.py --scale).
"""
from __future__ import annotations

import importlib.util
import os
import struct
from typing import List, Sequence, Tuple

import numpy as np

FP_CORE_NUM = 4
OBUF_WORD_BYTES = 16

E2E_GOLDEN = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "rtl",
    "vpu",
    "tb",
    "e2e",
    "golden_e2e_inst.py",
)


def _load_e2e_golden():
    path = os.path.normpath(E2E_GOLDEN)
    spec = importlib.util.spec_from_file_location("golden_e2e_inst", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def scale_hw(full_h: int, full_w: int, s: float) -> Tuple[int, int]:
    nh = max(8, int(round(full_h * s)))
    nw = max(8, int(round(full_w * s)))
    nh -= nh & 1
    nw -= nw & 1
    return nh, nw


def build_yolo_layers(scale: float = 1.0):
    """Return (layers, L1_H, L1_W) for the 3 conv layers in E2E."""
    gem = _load_e2e_golden()
    weight_dir = gem.WEIGHT_DIR
    L1_H, L1_W = scale_hw(160, 160, scale)
    L2_H, L2_W = (L1_H // 2, L1_W // 2)
    L3_H, L3_W = (L2_H, L2_W)
    layers = [
        gem.ConvLayer(
            "L1_model.1.conv",
            os.path.join(weight_dir, "model_1_conv.npz"),
            in_h=L1_H,
            in_w=L1_W,
            in_ch=16,
            out_ch=32,
            kh=3,
            kw=3,
            stride=2,
            pad=1,
        ),
        gem.ConvLayer(
            "L2_model.2.cv1.conv",
            os.path.join(weight_dir, "model_2_cv1_conv.npz"),
            in_h=L2_H,
            in_w=L2_W,
            in_ch=32,
            out_ch=16,
            kh=1,
            kw=1,
            stride=1,
            pad=0,
        ),
        gem.ConvLayer(
            "L3_model.2.m.0.cv2.conv",
            os.path.join(weight_dir, "model_2_m_0_cv2_conv.npz"),
            in_h=L3_H,
            in_w=L3_W,
            in_ch=16,
            out_ch=16,
            kh=3,
            kw=3,
            stride=1,
            pad=1,
        ),
    ]
    return layers, L1_H, L1_W


def forward_all_layers(layers, seed: int = 42):
    """Run 3-layer chain; return per-layer intermediates keyed by layer index."""
    np.random.seed(seed)
    L1_H, L1_W = layers[0].in_h, layers[0].in_w
    feat = np.random.randint(-128, 128, size=(L1_H, L1_W, 16), dtype=np.int8)
    chain = [feat]
    mids = []
    for ly in layers:
        out, mid = ly.forward(chain[-1])
        mids.append(mid)
        chain.append(out)
    return mids


def fp32_to_bits(x: float) -> int:
    return struct.unpack(">I", struct.pack(">f", float(x)))[0]


def int32_to_bits(x: int) -> int:
    return struct.unpack(">I", struct.pack(">i", int(x)))[0]


def bytes_to_128_words(byte_blob: bytes) -> List[str]:
    pad = (-len(byte_blob)) % OBUF_WORD_BYTES
    blob = byte_blob + b"\x00" * pad
    lines = []
    for i in range(0, len(blob), OBUF_WORD_BYTES):
        chunk = blob[i : i + OBUF_WORD_BYTES]
        lines.append("".join(f"{b:02x}" for b in reversed(chunk)))
    return lines


def pack_int32_obuf_words(int_values: Sequence[int]) -> List[int]:
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


def nhwc_flat_int32(arr: np.ndarray) -> List[int]:
    h, w, c = arr.shape
    out = []
    for y in range(h):
        for x in range(w):
            for ch in range(c):
                out.append(int(arr[y, x, ch]))
    return out


def nhwc_flat_fp32(arr: np.ndarray) -> List[float]:
    h, w, c = arr.shape
    out = []
    for y in range(h):
        for x in range(w):
            for ch in range(c):
                out.append(float(arr[y, x, ch]))
    return out


def accum_to_nhwc(accum: np.ndarray, oh: int, ow: int, oc: int) -> np.ndarray:
    """[OH*OW, OC] row-major → [OH, OW, OC]."""
    return accum.reshape(oh, ow, oc)


def write_hex(path: str, lines: Sequence[str]) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")


def qa_hw_qscale(act_scale: float) -> float:
    """Hardware QA multiplies by qscale; golden uses divide by act_scale."""
    return 1.0 / float(act_scale)
