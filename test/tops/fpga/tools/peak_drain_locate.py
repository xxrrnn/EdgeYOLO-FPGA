#!/usr/bin/env python3
"""Pin the peak HBM drain 256/2048 failure.

The isolated CDMA direction probe (no DCIM) already showed 8x BRAM->HBM 4KB
PASS. This script uses the real peak case to decide among:

  A) software remap bug
  B) first HBM-dest CDMA after DCIM only (settle / WAIT_DCIM)
  C) HBM dest slot 0x100000 specifically
  D) CDMA cannot read DCIM-written OBUF (but XDMA can)
  E) drain order: first CDMA wins vs tile0-only
"""
from __future__ import annotations

import struct
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]
UNIT = REPO / "test" / "network" / "host"
sys.path.insert(0, str(UNIT))

from hbm_flow import (  # noqa: E402
    OP_END,
    OP_NOP,
    OP_WAIT_DCIM,
    _header,
    build_hbm_input_cdma,
    build_hbm_output_drain,
    cdma_copy,
    hbm_drain_remap,
    parse_inst_words,
    patch_inst_for_hbm,
)
from xdma_win import (  # noqa: E402
    DCIM_INT8_OUT_WORDS_PER_TILE,
    DCIM_NUM_TILES,
    HBM_BASE,
    HBM_OFF_OUTPUT,
    INST_BASE,
    REGS_BASE,
    REG_DECODER_CTRL,
    REG_INST_COUNT,
    TILE_OBUF_BASE,
    TILE_OBUF_SIZE,
    ChipRunnerWin,
    hex_to_bin,
    inst_words_to_bin,
)

RUN_DIR = REPO / "test" / "tops" / "output" / "fpga_peak_int8"
N_WORDS = 2048
WPT = DCIM_INT8_OUT_WORDS_PER_TILE  # 4
STRIDE = DCIM_NUM_TILES * WPT  # 32
N_PIXELS = (N_WORDS + STRIDE - 1) // STRIDE  # 64
N_TILE_WORDS = N_PIXELS * WPT  # 256
TILE_BYTES = N_TILE_WORDS * 16  # 4096
FLAT_BYTES = DCIM_NUM_TILES * TILE_BYTES  # 32768
HBM_OUT = HBM_BASE + HBM_OFF_OUTPUT
HBM_ALT = HBM_BASE + 0x300000


def nops(n: int) -> list[int]:
    return [_header(OP_NOP, 0, 0)] * n


def match_words(a: bytes, b: bytes) -> tuple[int, int]:
    n = min(len(a), len(b)) // 16
    ok = sum(1 for i in range(n) if a[i * 16 : (i + 1) * 16] == b[i * 16 : (i + 1) * 16])
    return ok, n


def classify_blob(got: bytes, self_b: bytes, tile0: bytes, zeros: bytes) -> str:
    if got == self_b:
        return "MATCH_SELF"
    if got == zeros:
        return "ZEROS"
    if got == tile0:
        return "COPY_TILE0"
    ok_self, n = match_words(got, self_b)
    ok_t0, _ = match_words(got, tile0)
    ok_z, _ = match_words(got, zeros)
    return f"MIX self={ok_self}/{n} tile0={ok_t0}/{n} zero={ok_z}/{n} head={got[:8].hex()}"


class Loc:
    def __init__(self) -> None:
        self.r = ChipRunnerWin(verbose=False)
        self.x = self.r.x

    def soft_reset(self) -> None:
        self.x.write_u32(REGS_BASE + REG_INST_COUNT, 0)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
        time.sleep(0.001)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
        time.sleep(0.005)

    def run_words(self, words: list[int], timeout_s: float = 15.0) -> None:
        data = inst_words_to_bin(list(words) + [_header(OP_END, 0, 0)])
        self.soft_reset()
        self.x.write(INST_BASE, data)
        self.r.start_decoder(len(data) // 4)
        self.r.poll_done(timeout_s)

    def core_no_end(self) -> list[int]:
        core = parse_inst_words(RUN_DIR / "inst.hex")
        while core and (core[-1] >> 28) & 0xF == OP_END:
            core.pop()
        return core

    def peak_inst(self, drain: bool, nop_after_wait: int = 0, reverse: bool = False,
                  hbm_out: int = HBM_OUT) -> list[int]:
        words = build_hbm_input_cdma(RUN_DIR) + self.core_no_end()
        if drain:
            words += [_header(OP_WAIT_DCIM, 0, 0)]
            words += nops(nop_after_wait)
            tiles = list(range(DCIM_NUM_TILES))
            if reverse:
                tiles = list(reversed(tiles))
            for t in tiles:
                src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
                dst = hbm_out + t * TILE_BYTES
                words += cdma_copy(src, dst, TILE_BYTES)
        return words

    def drain_only(self, reverse: bool = False, hbm_out: int = HBM_OUT) -> list[int]:
        tiles = list(range(DCIM_NUM_TILES))
        if reverse:
            tiles = list(reversed(tiles))
        words: list[int] = []
        for t in tiles:
            src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
            dst = hbm_out + t * TILE_BYTES
            words += cdma_copy(src, dst, TILE_BYTES)
        return words

    def upload_inputs(self) -> None:
        self.r.upload_hbm(RUN_DIR)
        self.x.write(HBM_OUT, b"\x00" * FLAT_BYTES)
        self.x.write(HBM_ALT, b"\x00" * FLAT_BYTES)

    def read_obufs(self) -> list[bytes]:
        return [
            self.x.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, TILE_BYTES)
            for t in range(DCIM_NUM_TILES)
        ]

    def read_flat(self, addr: int = HBM_OUT) -> bytes:
        return self.x.read(addr, FLAT_BYTES)

    def report(self, title: str, obufs: list[bytes], flat: bytes, expected: bytes) -> dict:
        zeros = b"\x00" * TILE_BYTES
        print(f"\n=== {title} ===", flush=True)
        slots = []
        for t in range(DCIM_NUM_TILES):
            got = flat[t * TILE_BYTES : (t + 1) * TILE_BYTES]
            kind = classify_blob(got, obufs[t], obufs[0], zeros)
            print(f"  HBM slot t{t}: {kind}", flush=True)
            slots.append(kind)
        remapped = hbm_drain_remap(RUN_DIR, flat)
        scatter = bytearray()
        # rebuild scatter from live obufs the same way read_obuf_check_region does
        # expected.hex is scatter order; live scatter from XDMA:
        live_scatter = self.x.read_obuf_check_region(0x800000, N_WORDS, wpt=WPT)
        ok_sc, n_sc = match_words(live_scatter, expected)
        ok_rm, n_rm = match_words(remapped, expected)
        ok_fl, n_fl = match_words(flat, expected)
        print(f"  XDMA scatter vs expected: {ok_sc}/{n_sc}", flush=True)
        print(f"  remapped HBM vs expected: {ok_rm}/{n_rm}", flush=True)
        print(f"  raw flat  HBM vs expected: {ok_fl}/{n_fl} (identity; expect ~256 if only t0)", flush=True)
        print(f"  remapped vs live scatter: {match_words(remapped, live_scatter)[0]}/{n_sc}", flush=True)
        return {
            "title": title,
            "slots": slots,
            "scatter_vs_exp": (ok_sc, n_sc),
            "remap_vs_exp": (ok_rm, n_rm),
        }


def remap_selftest(expected: bytes) -> None:
    """If remap is invertible, software is not the 256/2048 cause."""
    print("\n=== software remap round-trip ===", flush=True)
    flat = bytearray(FLAT_BYTES)
    base_word = 0
    for i in range(N_WORDS):
        word_addr = base_word + i
        px = word_addr // STRIDE
        tile = (word_addr % STRIDE) // WPT
        intra = word_addr % WPT
        tile_word = px * WPT + intra
        flat_off = (tile * N_TILE_WORDS + tile_word) * 16
        flat[flat_off : flat_off + 16] = expected[i * 16 : (i + 1) * 16]
    got = hbm_drain_remap(RUN_DIR, bytes(flat))
    ok, n = match_words(got, expected)
    print(f"  synthetic flat -> remap vs expected: {ok}/{n}", flush=True)
    if ok != n:
        raise SystemExit("remap self-test FAILED — stop, this is a host bug")


def unique(tag: int, n: int) -> bytes:
    buf = bytearray(n)
    for i in range(0, n, 4):
        struct.pack_into("<I", buf, i, ((tag & 0xFF) << 24) | (i & 0xFFFFFF))
    return bytes(buf)


def main() -> int:
    if not (RUN_DIR / "expected.hex").is_file():
        print(f"missing peak case at {RUN_DIR}; generate with test/tops/fpga/run.py first")
        return 2
    expected = hex_to_bin(RUN_DIR / "expected.hex")[: N_WORDS * 16]
    print(f"[loc] peak dir={RUN_DIR}")
    print(f"[loc] wpt={WPT} stride={STRIDE} n_tile_words={N_TILE_WORDS} tile_bytes={TILE_BYTES}")
    print(f"[loc] expected first word={expected[:4].hex()} (le)")

    remap_selftest(expected)

    loc = Loc()
    st = loc.x.read_u32(REGS_BASE + 0x40)
    print(f"[loc] DECODER_STATUS=0x{st:08x}", flush=True)

    # 0) unique host fill -> official HBM_OFF_OUTPUT, no DCIM
    print("\n=== unique BRAM->HBM @ HBM_OFF_OUTPUT 8x 4KB (no DCIM) ===", flush=True)
    loc.x.write(HBM_OUT, b"\x00" * FLAT_BYTES)
    insts: list[int] = []
    exps = []
    for t in range(8):
        src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        dst = HBM_OUT + t * TILE_BYTES
        blob = unique(0x50 + t, TILE_BYTES)
        loc.x.write(src, blob)
        insts += cdma_copy(src, dst, TILE_BYTES)
        exps.append(blob)
    loc.run_words(insts)
    for t in range(8):
        got = loc.x.read(HBM_OUT + t * TILE_BYTES, TILE_BYTES)
        kind = "MATCH" if got == exps[t] else classify_blob(got, exps[t], exps[0], b"\x00" * TILE_BYTES)
        print(f"  unique->0x100000 t{t}: {kind}", flush=True)

    # A) official same-program drain
    loc.upload_inputs()
    loc.run_words(loc.peak_inst(drain=True, nop_after_wait=0))
    obufs = loc.read_obufs()
    flat = loc.read_flat()
    loc.report("A  same-program drain (WAIT_DCIM + 8 CDMA, dest 0x100000)", obufs, flat, expected)

    # B) delayed two-program: compute, then drain
    loc.upload_inputs()
    loc.run_words(loc.peak_inst(drain=False))
    loc.x.write(HBM_OUT, b"\x00" * FLAT_BYTES)
    loc.run_words(loc.drain_only())
    obufs = loc.read_obufs()
    flat = loc.read_flat()
    loc.report("B  two-program: compute DONE, then drain-only (Python gap)", obufs, flat, expected)

    # C) same-program with 4096 NOPs after WAIT_DCIM
    loc.upload_inputs()
    loc.run_words(loc.peak_inst(drain=True, nop_after_wait=4096), timeout_s=20.0)
    obufs = loc.read_obufs()
    flat = loc.read_flat()
    loc.report("C  same-program drain after 4096 NOPs", obufs, flat, expected)

    # D) reverse drain order, same-program
    loc.upload_inputs()
    loc.run_words(loc.peak_inst(drain=True, reverse=True))
    obufs = loc.read_obufs()
    flat = loc.read_flat()
    loc.report("D  same-program drain REVERSE tile order 7..0", obufs, flat, expected)

    # E) delayed reverse drain
    loc.upload_inputs()
    loc.run_words(loc.peak_inst(drain=False))
    loc.x.write(HBM_OUT, b"\x00" * FLAT_BYTES)
    loc.run_words(loc.drain_only(reverse=True))
    obufs = loc.read_obufs()
    flat = loc.read_flat()
    loc.report("E  two-program reverse drain 7..0", obufs, flat, expected)

    # F) drain to alternate HBM address after compute (two-program)
    loc.upload_inputs()
    loc.run_words(loc.peak_inst(drain=False))
    loc.x.write(HBM_ALT, b"\x00" * FLAT_BYTES)
    loc.run_words(loc.drain_only(hbm_out=HBM_ALT))
    obufs = loc.read_obufs()
    flat = loc.read_flat(HBM_ALT)
    loc.report("F  two-program drain to 0x300000", obufs, flat, expected)

    # G) official patch_inst_for_hbm drain_output=True (sanity vs our builder)
    loc.upload_inputs()
    data = patch_inst_for_hbm(RUN_DIR, drain_output=True)
    loc.soft_reset()
    loc.x.write(INST_BASE, data)
    loc.r.start_decoder(len(data) // 4)
    loc.r.poll_done(15.0)
    obufs = loc.read_obufs()
    flat = loc.read_flat()
    loc.report("G  official patch_inst_for_hbm(drain=True)", obufs, flat, expected)

    print("\n======== HOW TO READ ========", flush=True)
    print("A FAIL + B PASS  => WAIT_DCIM/same-program race, not HBM write outstanding")
    print("A FAIL + B FAIL, slots MATCH_SELF vs XDMA scatter PASS => CDMA read of DCIM OBUF")
    print("slots COPY_TILE0 => AW/W reuse (true HBM write-path bug)")
    print("slots ZEROS after first => 2nd+ HBM write dropped")
    print("D first-good tile follows drain order => first CDMA wins, not tile0 hardware")
    print("remap self-test PASS + remap_vs_exp FAIL with MATCH_SELF slots => host remap vs live layout")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
