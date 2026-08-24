#!/usr/bin/env python3
"""Generate deterministic, exact-fit INT8 vectors for the DCIM pipeline test.

The files use the hardware's native mapping:

* 8 tiles;
* 64 input channels per tile;
* 16 logical INT8 output channels per tile (32 physical INT4 lanes);
* high activation nibble first, low activation nibble second.

No model/runtime transfer is involved in this test.  The generated weight bus is
connected to the same calculate_core + postProcess RTL used inside ``dcim``.
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path


NUM_TILES = 8
CH_IN = 64
CH_OUT = 32
LOGICAL_OUT_PER_TILE = CH_OUT // 2
WEIGHT_WORD_BITS = 128
WEIGHT_NIBBLES_PER_WORD = WEIGHT_WORD_BITS // 4
WEIGHT_WORDS_PER_TILE = CH_IN * CH_OUT // WEIGHT_NIBBLES_PER_WORD
OPS_PER_JOB = NUM_TILES * CH_IN * LOGICAL_OUT_PER_TILE * 2


def signed8(value: int) -> int:
    return value if value < 0x80 else value - 0x100


def pack_nibbles(values: list[int]) -> int:
    word = 0
    for index, value in enumerate(values):
        word |= (value & 0xF) << (index * 4)
    return word


def pack_int32x4(values: list[int]) -> int:
    assert len(values) == 4
    word = 0
    for lane, value in enumerate(values):
        word |= (value & 0xFFFF_FFFF) << (lane * 32)
    return word


def write_hex(path: Path, values: list[int], width_bits: int) -> None:
    digits = (width_bits + 3) // 4
    path.write_text(
        "".join(f"{value & ((1 << width_bits) - 1):0{digits}x}\n" for value in values),
        encoding="ascii",
    )


def generate(out_dir: Path, batch_jobs: int, seed: int) -> dict:
    rng = random.Random(seed)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Keep values non-trivial while leaving a large margin to signed INT32.
    weights = [
        [
            [rng.randint(-8, 7) for _ in range(CH_IN)]
            for _ in range(LOGICAL_OUT_PER_TILE)
        ]
        for _ in range(NUM_TILES)
    ]
    activations = [
        [rng.randint(-64, 63) for _ in range(CH_IN)]
        for _ in range(batch_jobs)
    ]

    # Physical lane 2*n is the low weight nibble and lane 2*n+1 is high.
    # ppCache presents words in ascending address order at increasing bit index.
    all_weight_words: list[int] = []
    for tile in range(NUM_TILES):
        nibble_stream: list[int] = []
        for physical_out in range(CH_OUT):
            logical_out = physical_out // 2
            shift = 4 if physical_out & 1 else 0
            for in_ch in range(CH_IN):
                nibble_stream.append((weights[tile][logical_out][in_ch] >> shift) & 0xF)
        words = [
            pack_nibbles(nibble_stream[index:index + WEIGHT_NIBBLES_PER_WORD])
            for index in range(0, len(nibble_stream), WEIGHT_NIBBLES_PER_WORD)
        ]
        assert len(words) == WEIGHT_WORDS_PER_TILE
        all_weight_words.extend(words)
        write_hex(out_dir / f"weight_tile{tile}.hex", words, WEIGHT_WORD_BITS)
    write_hex(out_dir / "weight_all_tiles.hex", all_weight_words, WEIGHT_WORD_BITS)

    # The RTL's signed INT8 convention sends the sign/high nibble first.
    phases: list[int] = []
    raw_activations: list[int] = []
    for vector in activations:
        raw_word = 0
        for in_ch, value in enumerate(vector):
            raw_word |= (value & 0xFF) << (in_ch * 8)
        raw_activations.append(raw_word)
        phases.append(pack_nibbles([((value & 0xFF) >> 4) & 0xF for value in vector]))
        phases.append(pack_nibbles([(value & 0xF) for value in vector]))
    write_hex(out_dir / "activation_int8.hex", raw_activations, CH_IN * 8)
    write_hex(out_dir / "activation_phase.hex", phases, CH_IN * 4)

    # One file per tile, four 128-bit words per job, matching Tile OBUF packing.
    result_preview: list[list[int]] = []
    all_expected_words: list[int] = []
    for tile in range(NUM_TILES):
        expected_words: list[int] = []
        tile_preview: list[int] = []
        for vector in activations:
            results = [
                sum(vector[k] * weights[tile][out_ch][k] for k in range(CH_IN))
                for out_ch in range(LOGICAL_OUT_PER_TILE)
            ]
            tile_preview.append(results[0])
            for word_index in range(LOGICAL_OUT_PER_TILE // 4):
                begin = word_index * 4
                expected_words.append(pack_int32x4(results[begin:begin + 4]))
        result_preview.append(tile_preview[:4])
        all_expected_words.extend(expected_words)
        write_hex(out_dir / f"expected_tile{tile}.hex", expected_words, 128)
    write_hex(out_dir / "expected_all_tiles.hex", all_expected_words, 128)

    manifest = {
        "schema": "edgeyolo.dcim_pipeline_int8.v1",
        "seed": seed,
        "batch_jobs": batch_jobs,
        "num_tiles": NUM_TILES,
        "ch_in": CH_IN,
        "physical_ch_out_per_tile": CH_OUT,
        "logical_int8_ch_out_per_tile": LOGICAL_OUT_PER_TILE,
        "matrix_per_job": {"m": 1, "k": 64, "n": 128},
        "logical_macs_per_job": NUM_TILES * CH_IN * LOGICAL_OUT_PER_TILE,
        "operations_mul_plus_add_per_job": OPS_PER_JOB,
        "phases_per_job": 2,
        "expected_job_ii_cycles": 2,
        "expected_peak_tops_at_250mhz": 2.048,
        "first_four_tile0_channel0_results": result_preview[0],
    }
    (out_dir / "pipeline_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate DCIM INT8 pipeline vectors")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--batch-jobs", type=int, default=32)
    parser.add_argument("--seed", type=lambda value: int(value, 0), default=0x20260811)
    args = parser.parse_args()
    if args.batch_jobs < 4:
        parser.error("--batch-jobs must be at least 4")
    manifest = generate(args.out_dir.resolve(), args.batch_jobs, args.seed)
    print(json.dumps(manifest, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
