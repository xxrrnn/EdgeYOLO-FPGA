"""Quick CDMA health check: test both directions (HBM->on-chip, on-chip->HBM)."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import (ChipRunnerWin, VPU_BUF_BASE, WB_BASE, HBM_BASE,
                      inst_words_to_bin, INST_BASE, TILE_OBUF_BASE)
from hbm_flow import cdma_copy, _header, OP_END

runner = ChipRunnerWin()

PATTERN_A = bytes(range(16))          # 00 01 02 ... 0F
PATTERN_B = bytes(range(0x80, 0x90))  # 80 81 ... 8F

def run_cdma(src, dst, nbytes, label):
    words = cdma_copy(src, dst, nbytes)
    words.append(_header(OP_END, 0, 0))
    runner.x.write(INST_BASE, inst_words_to_bin(words))
    runner.start_decoder(len(words))
    runner.poll_done(10.0)

print("=== CDMA bi-directional health check ===")
print()

# Test 1: HBM -> WB
runner.x.write(HBM_BASE + 0x500, PATTERN_A)
runner.x.write(WB_BASE, b'\x00' * 16)
run_cdma(HBM_BASE + 0x500, WB_BASE, 16, "HBM->WB")
got = runner.x.read(WB_BASE, 16)
ok1 = got == PATTERN_A
print(f"HBM+0x500 -> WB_BASE:     {'OK' if ok1 else 'FAIL'}  got={got.hex()}")

# Test 2: WB -> HBM
runner.x.write(WB_BASE, PATTERN_B)
runner.x.write(HBM_BASE + 0x600, b'\x00' * 16)
run_cdma(WB_BASE, HBM_BASE + 0x600, 16, "WB->HBM")
got2 = runner.x.read(HBM_BASE + 0x600, 16)
ok2 = got2 == PATTERN_B
print(f"WB_BASE   -> HBM+0x600:   {'OK' if ok2 else 'FAIL'}  got={got2.hex()}")

# Test 3: HBM -> VPU_BUF+0x300000 (im2col slot)
runner.x.write(HBM_BASE + 0x700, PATTERN_A)
runner.x.write(VPU_BUF_BASE + 0x300000, b'\x00' * 16)
run_cdma(HBM_BASE + 0x700, VPU_BUF_BASE + 0x300000, 16, "HBM->VPU_BUF+300000")
got3 = runner.x.read(VPU_BUF_BASE + 0x300000, 16)
ok3 = got3 == PATTERN_A
print(f"HBM+0x700 -> VPU_BUF+0x300000: {'OK' if ok3 else 'FAIL'}  got={got3.hex()}")

# Test 4: VPU_BUF -> HBM (drain direction, used by L2 tests)
runner.x.write(VPU_BUF_BASE + 0x300000, PATTERN_B)
runner.x.write(HBM_BASE + 0x800, b'\x00' * 16)
run_cdma(VPU_BUF_BASE + 0x300000, HBM_BASE + 0x800, 16, "VPU_BUF->HBM")
got4 = runner.x.read(HBM_BASE + 0x800, 16)
ok4 = got4 == PATTERN_B
print(f"VPU_BUF+0x300000 -> HBM+0x800: {'OK' if ok4 else 'FAIL'}  got={got4.hex()}")

# Test 5: TILE_OBUF -> HBM (used in L2 dcim drain tests)
runner.x.write(TILE_OBUF_BASE, PATTERN_A)
runner.x.write(HBM_BASE + 0x900, b'\x00' * 16)
run_cdma(TILE_OBUF_BASE, HBM_BASE + 0x900, 16, "TILE_OBUF->HBM")
got5 = runner.x.read(HBM_BASE + 0x900, 16)
ok5 = got5 == PATTERN_A
print(f"TILE_OBUF  -> HBM+0x900:  {'OK' if ok5 else 'FAIL'}  got={got5.hex()}")

print()
all_ok = ok1 and ok2 and ok3 and ok4 and ok5
print(f"Overall CDMA health: {'HEALTHY' if all_ok else 'DEGRADED'}")
