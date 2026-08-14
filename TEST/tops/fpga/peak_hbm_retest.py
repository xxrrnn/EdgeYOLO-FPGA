#!/usr/bin/env python3
"""After the duplicate-act.hex CDMA dest fix: zero IBUF, run peak hbm+drain."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
UNIT = REPO / "tests" / "chip" / "unit-tb"
sys.path.insert(0, str(UNIT))

from hbm_flow import _preload_rows  # noqa: E402
from xdma_win import (  # noqa: E402
    DCIM_NUM_TILES,
    TILE_IBUF_BASE,
    TILE_IBUF_SIZE,
    TILE_OBUF_BASE,
    TILE_OBUF_SIZE,
    ChipRunnerWin,
)

RUN_DIR = REPO / "output" / "tops" / "fpga_peak_int8"


def main() -> int:
    rows = _preload_rows(RUN_DIR)
    print("[cdma] HBM->onchip preload rows:")
    for hbm_off, fname, nbytes, dst in rows:
        print(f"  {fname:18s} HBM+0x{hbm_off:06x} -> 0x{dst:010x}  {nbytes} B")
    ibuf_dests = [dst for _h, _f, _n, dst in rows if TILE_IBUF_BASE <= dst < TILE_OBUF_BASE]
    print(f"[cdma] unique IBUF dests: {len(set(ibuf_dests))} / {len(ibuf_dests)}")
    if len(set(ibuf_dests)) < 8:
        print("ERROR: act/weight CDMA still collapsed")
        return 2

    r = ChipRunnerWin(verbose=False)
    zeros = b"\x00" * 8192
    print("[prep] zero 8 IBUF + 8 OBUF (8KB each)")
    for t in range(DCIM_NUM_TILES):
        r.x.write(TILE_IBUF_BASE + t * TILE_IBUF_SIZE, zeros)
        r.x.write(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, zeros)

    r.upload_hbm(RUN_DIR)
    n_words = r.upload_inst(RUN_DIR, drain_output=True)
    r.start_decoder(n_words)
    r.poll_done(15.0)

    scatter = r.read_check(RUN_DIR, from_hbm=False)[0]
    drain = r.read_check(RUN_DIR, from_hbm=True)[0]
    print(
        f"scatter tile_obuf vs expected: {scatter['passed']}/{scatter['total_words']} "
        f"{'PASS' if scatter['pass'] else 'FAIL'}"
    )
    print(
        f"official HBM drain vs expected: {drain['passed']}/{drain['total_words']} "
        f"{'PASS' if drain['pass'] else 'FAIL'}"
    )
    if scatter.get("first_mismatch"):
        print("  scatter first_mismatch", scatter["first_mismatch"])
    if drain.get("first_mismatch"):
        print("  drain first_mismatch", drain["first_mismatch"])
    return 0 if scatter["pass"] and drain["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
