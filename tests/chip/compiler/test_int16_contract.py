#!/usr/bin/env python3
"""Focused checks for the native W16A16 accumulator memory contract."""
from __future__ import annotations

import struct
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools"))
sys.path.insert(0, str(REPO / "tests" / "chip"))
sys.path.insert(0, str(REPO / "rtl" / "tb" / "lite_bd" / "module_tb"))

from chip_config import (  # noqa: E402
    DCIM_INT16_OUT_CH_PER_TILE,
    DCIM_INT16_OUT_WORDS_PER_TILE,
    DCIM_INT16_RESULTS_PER_WORD,
    DCIM_NUM_TILES,
    require_consistent,
)
from compiler.lowering.lower import emit_conv  # noqa: E402
from golden_module_tb import dcim_accum_words_int16, int64_accum_to_words  # noqa: E402


def _decode_i64_word(word: str) -> tuple[int, int]:
    return struct.unpack("<qq", bytes.fromhex(word)[::-1])


def main() -> None:
    require_consistent()
    assert DCIM_INT16_OUT_CH_PER_TILE == 8
    assert DCIM_INT16_RESULTS_PER_WORD == 2
    assert DCIM_INT16_OUT_WORDS_PER_TILE == 4

    values = np.arange(-4, 4, dtype=np.int64).reshape(1, 8)
    packed = dcim_accum_words_int16(values, num_tiles=1)
    assert len(packed) == DCIM_NUM_TILES * DCIM_INT16_OUT_WORDS_PER_TILE
    assert sum((_decode_i64_word(word) for word in packed[:4]), ()) == tuple(values[0])
    assert all(_decode_i64_word(word) == (0, 0) for word in packed[4:])

    dqa_packed = int64_accum_to_words(values[:, :4], c=4)
    assert len(dqa_packed) == 2
    assert sum((_decode_i64_word(word) for word in dqa_packed), ()) == tuple(values[0, :4])

    layer = {
        "name": "native_int16_contract",
        "in_channels": 3,
        "out_channels": 8,
        "kernel_h": 1,
        "kernel_w": 1,
        "stride": [1, 1],
        "padding": [0, 0, 0, 0],
        "has_activation": True,
    }
    hw = {"address_map": {"ibuf_size": 0x80000, "tile_obuf_size": 0x40000}}
    ops, *_ = emit_conv(
        layer,
        in_obuf_off=0,
        out_obuf_off=0x180000,
        im2col_obuf_off=0x300000,
        wb_off=0,
        wei_ibuf_word_addr=0,
        in_h=1,
        in_w=1,
        is_first_layer=True,
        hw=hw,
        mode="int16",
        skip_qa=True,
        use_dcim_layer=True,
    )
    dcim = next(op for op in ops if op.get("kind") == "dcim_layer")
    dqa = next(op for op in ops if op.get("unit") == "dqa")
    assert dcim["out_stride_words"] == DCIM_INT16_OUT_WORDS_PER_TILE
    assert dqa["flags"] & 0x2, "native INT16 DQA must select the INT64 accumulator path"
    print("native INT16 contract: PASS")


if __name__ == "__main__":
    main()
