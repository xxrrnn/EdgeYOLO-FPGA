#!/usr/bin/env python3
"""Direction/count/size probe for on-chip CDMA (no DCIM).

Fills sources with unique patterns, runs OP_CDMA_COPY(+WAIT) sequences, and
reports whether destinations match. Used to pin P1: HBM-as-destination, 2nd beat.
"""
from __future__ import annotations

import struct
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
UNIT = REPO / "tests" / "chip" / "unit-tb"
sys.path.insert(0, str(UNIT))

from hbm_flow import OP_END, OP_NOP, cdma_copy, _header  # noqa: E402
from xdma_win import (  # noqa: E402
    HBM_BASE,
    INST_BASE,
    REGS_BASE,
    REG_DECODER_CTRL,
    REG_INST_COUNT,
    TILE_IBUF_BASE,
    TILE_IBUF_SIZE,
    TILE_OBUF_BASE,
    TILE_OBUF_SIZE,
    VPU_BUF_BASE,
    ChipRunnerWin,
    inst_words_to_bin,
)

HBM_SCRATCH = HBM_BASE + 0x300000  # above peak weight pool
FILL = 0xA5


def unique(tag: int, n: int) -> bytes:
    buf = bytearray(n)
    for i in range(0, n, 4):
        struct.pack_into("<I", buf, i, ((tag & 0xFF) << 24) | (i & 0xFFFFFF))
    return bytes(buf)


def nops(n: int) -> list[int]:
    return [_header(OP_NOP, 0, 0)] * n


def classify(got: bytes, exp: bytes, fill: bytes) -> str:
    if got == exp:
        return "MATCH"
    if got == fill:
        return "UNTOUCHED"
    if got == exp[: len(got)][:0]:
        return "EMPTY"
    # copied previous slot?
    return f"CORRUPT first4={got[:4].hex()} exp={exp[:4].hex()} fill={fill[:4].hex()}"


class Probe:
    def __init__(self) -> None:
        self.r = ChipRunnerWin(verbose=False)
        self.x = self.r.x
        self.results: list[str] = []

    def soft_reset(self) -> None:
        self.x.write_u32(REGS_BASE + REG_INST_COUNT, 0)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
        time.sleep(0.001)
        self.x.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
        time.sleep(0.005)

    def run_inst(self, words: list[int], timeout_s: float = 8.0) -> None:
        words = list(words) + [_header(OP_END, 0, 0)]
        data = inst_words_to_bin(words)
        self.soft_reset()
        self.x.write(INST_BASE, data)
        self.r.start_decoder(len(data) // 4)
        self.r.poll_done(timeout_s)

    def check_slot(self, name: str, addr: int, exp: bytes, fill: bytes) -> bool:
        got = self.x.read(addr, len(exp))
        kind = "MATCH" if got == exp else (
            "UNTOUCHED" if got == fill else
            ("COPY_OF_FILL_PREFIX" if False else f"CORRUPT got={got[:8].hex()}")
        )
        if got == exp:
            kind = "MATCH"
        elif got == fill:
            kind = "UNTOUCHED"
        elif fill and got == bytes([FILL]) * len(exp):
            kind = "UNTOUCHED"
        else:
            # see if it equals some other well-known pattern later
            kind = f"CORRUPT got0={got[:8].hex()} exp0={exp[:8].hex()}"
        ok = kind == "MATCH"
        line = f"{'PASS' if ok else 'FAIL'}  {name:48s}  {kind}"
        print(line, flush=True)
        self.results.append(line)
        return ok

    def fill(self, addr: int, n: int, val: int = FILL) -> bytes:
        blob = bytes([val]) * n
        self.x.write(addr, blob)
        return blob


def main() -> int:
    p = Probe()
    st = p.x.read_u32(REGS_BASE + 0x40)
    print(f"[probe] DECODER_STATUS=0x{st:08x}", flush=True)

    def case(title: str) -> None:
        print(f"\n=== {title} ===", flush=True)

    # --- 1. BRAM -> BRAM, 1 then 8 ---
    case("BRAM->BRAM 1x 4KB  (obuf0 -> vpu)")
    n = 4096
    src, dst = TILE_OBUF_BASE, VPU_BUF_BASE + 0x1000
    exp = unique(0x10, n)
    fill = p.fill(dst, n)
    p.x.write(src, exp)
    p.run_inst(cdma_copy(src, dst, n))
    p.check_slot("bram_bram_1x", dst, exp, fill)

    case("BRAM->BRAM 8x 4KB  (obuf[t] -> vpu+t*4K)")
    insts: list[int] = []
    exps = []
    fills = []
    for t in range(8):
        s = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        d = VPU_BUF_BASE + 0x20000 + t * n
        e = unique(0x20 + t, n)
        f = p.fill(d, n)
        p.x.write(s, e)
        insts += cdma_copy(s, d, n)
        exps.append((d, e, f))
    p.run_inst(insts)
    for t, (d, e, f) in enumerate(exps):
        p.check_slot(f"bram_bram_8x_t{t}", d, e, f)

    # --- 2. HBM -> HBM ---
    case("HBM->HBM 1x 4KB")
    s, d = HBM_SCRATCH, HBM_SCRATCH + 0x10000
    e = unique(0x30, n)
    f = p.fill(d, n)
    p.x.write(s, e)
    p.run_inst(cdma_copy(s, d, n))
    p.check_slot("hbm_hbm_1x", d, e, f)

    case("HBM->HBM 8x 4KB sequential dest")
    insts = []
    exps = []
    src0 = HBM_SCRATCH + 0x20000
    for t in range(8):
        ss = src0 + t * n
        dd = src0 + 0x20000 + t * n
        ee = unique(0x40 + t, n)
        ff = p.fill(dd, n)
        p.x.write(ss, ee)
        insts += cdma_copy(ss, dd, n)
        exps.append((dd, ee, ff))
    p.run_inst(insts)
    for t, (dd, ee, ff) in enumerate(exps):
        p.check_slot(f"hbm_hbm_8x_t{t}", dd, ee, ff)

    # --- 3. HBM -> BRAM (load direction, unique data) ---
    case("HBM->BRAM 8x 4KB  (HBM -> ibuf[t])")
    insts = []
    exps = []
    for t in range(8):
        ss = HBM_SCRATCH + 0x80000 + t * n
        dd = TILE_IBUF_BASE + t * TILE_IBUF_SIZE
        ee = unique(0x50 + t, n)
        ff = p.fill(dd, n)
        p.x.write(ss, ee)
        insts += cdma_copy(ss, dd, n)
        exps.append((dd, ee, ff))
    p.run_inst(insts)
    for t, (dd, ee, ff) in enumerate(exps):
        p.check_slot(f"hbm_bram_8x_t{t}", dd, ee, ff)

    # --- 4. BRAM -> HBM : the P1 direction ---
    for ncopy, nbytes in [(1, 4096), (2, 4096), (8, 4096), (2, 256), (2, 1024), (2, 16384)]:
        case(f"BRAM->HBM {ncopy}x {nbytes}B  (obuf[t] -> HBM scratch)")
        insts = []
        exps = []
        for t in range(ncopy):
            ss = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
            dd = HBM_SCRATCH + 0x100000 + t * nbytes
            ee = unique(0x60 + t, nbytes)
            ff = p.fill(dd, nbytes)
            p.x.write(ss, ee)
            insts += cdma_copy(ss, dd, nbytes)
            exps.append((dd, ee, ff, t))
        p.run_inst(insts)
        slot0 = exps[0][1]
        for dd, ee, ff, t in exps:
            got = p.x.read(dd, nbytes)
            extra = ""
            if got != ee and got == slot0:
                extra = "  (==slot0)"
            elif got != ee and got == ff:
                extra = "  (untouched)"
            ok = got == ee
            kind = "MATCH" if ok else (
                "UNTOUCHED" if got == ff else
                ("COPY_SLOT0" if got == slot0 else f"CORRUPT got0={got[:8].hex()}")
            )
            line = f"{'PASS' if ok else 'FAIL'}  bram_hbm_{ncopy}x_{nbytes}B_t{t:d}{' '*max(0,18-len(str(nbytes)))}  {kind}{extra}"
            print(line, flush=True)
            p.results.append(line)

    # --- 5. Two separate decoder runs (not back-to-back in one program) ---
    case("BRAM->HBM 2x 4KB as TWO decoder programs")
    n = 4096
    slots = []
    for t in range(2):
        ss = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        dd = HBM_SCRATCH + 0x180000 + t * n
        ee = unique(0x70 + t, n)
        ff = p.fill(dd, n)
        p.x.write(ss, ee)
        p.run_inst(cdma_copy(ss, dd, n))
        slots.append((dd, ee, ff, t))
    slot0 = slots[0][1]
    for dd, ee, ff, t in slots:
        got = p.x.read(dd, n)
        ok = got == ee
        kind = "MATCH" if ok else ("UNTOUCHED" if got == ff else (
            "COPY_SLOT0" if got == slot0 else f"CORRUPT got0={got[:8].hex()}"))
        line = f"{'PASS' if ok else 'FAIL'}  bram_hbm_2prog_t{t}                          {kind}"
        print(line, flush=True)
        p.results.append(line)

    # --- 6. BRAM->HBM then HBM->BRAM (write then read) ---
    case("BRAM->HBM 4KB then HBM->IBUF 4KB (same HBM addr)")
    n = 4096
    ss = TILE_OBUF_BASE
    hbm = HBM_SCRATCH + 0x1C0000
    ib = TILE_IBUF_BASE
    ee = unique(0x80, n)
    p.fill(hbm, n)
    p.fill(ib, n)
    p.x.write(ss, ee)
    p.run_inst(cdma_copy(ss, hbm, n) + cdma_copy(hbm, ib, n))
    p.check_slot("write_then_read_hbm", ib, ee, bytes([FILL]) * n)
    p.check_slot("write_then_read_hbm_mem", hbm, ee, bytes([FILL]) * n)

    # --- 7. VPU_BUF -> HBM 2x ---
    case("VPU->HBM 2x 4KB")
    n = 4096
    insts = []
    exps = []
    for t in range(2):
        ss = VPU_BUF_BASE + 0x40000 + t * n
        dd = HBM_SCRATCH + 0x1E0000 + t * n
        ee = unique(0x90 + t, n)
        ff = p.fill(dd, n)
        p.x.write(ss, ee)
        insts += cdma_copy(ss, dd, n)
        exps.append((dd, ee, ff, t))
    p.run_inst(insts)
    slot0 = exps[0][1]
    for dd, ee, ff, t in exps:
        got = p.x.read(dd, n)
        ok = got == ee
        kind = "MATCH" if ok else ("UNTOUCHED" if got == ff else (
            "COPY_SLOT0" if got == slot0 else f"CORRUPT got0={got[:8].hex()}"))
        line = f"{'PASS' if ok else 'FAIL'}  vpu_hbm_2x_t{t}                               {kind}"
        print(line, flush=True)
        p.results.append(line)

    # --- 8. BRAM->HBM 8x with 512 NOPs between copies ---
    case("BRAM->HBM 8x 4KB with 512 NOPs between")
    n = 4096
    insts = []
    exps = []
    for t in range(8):
        ss = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        dd = HBM_SCRATCH + 0x240000 + t * n
        ee = unique(0xA0 + t, n)
        ff = p.fill(dd, n)
        p.x.write(ss, ee)
        insts += cdma_copy(ss, dd, n) + nops(512)
        exps.append((dd, ee, ff, t))
    p.run_inst(insts, timeout_s=15.0)
    slot0 = exps[0][1]
    for dd, ee, ff, t in exps:
        got = p.x.read(dd, n)
        ok = got == ee
        kind = "MATCH" if ok else ("UNTOUCHED" if got == ff else (
            "COPY_SLOT0" if got == slot0 else f"CORRUPT got0={got[:8].hex()}"))
        line = f"{'PASS' if ok else 'FAIL'}  bram_hbm_nop512_t{t}                          {kind}"
        print(line, flush=True)
        p.results.append(line)

    print("\n======== SUMMARY ========", flush=True)
    fails = [x for x in p.results if x.startswith("FAIL")]
    passes = [x for x in p.results if x.startswith("PASS")]
    print(f"PASS {len(passes)}  FAIL {len(fails)}  total {len(p.results)}")
    for x in fails:
        print(" ", x)
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
