"""Atomic test: CDMA to different on-chip addresses to find which ones work."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import (ChipRunnerWin, VPU_BUF_BASE, WB_BASE, TILE_IBUF_BASE,
                      inst_words_to_bin, INST_BASE)
from hbm_flow import cdma_copy, _header, OP_END

runner = ChipRunnerWin()

PATTERN = bytes([0xAB, 0xCD] * 8)  # 16-byte test pattern

def test_cdma_to(addr_name, dst_addr, nbytes=16):
    """Write pattern to HBM+0, CDMA to dst_addr, read back and check."""
    runner.x.write(0x0, PATTERN)           # HBM+0 = pattern
    runner.x.write(dst_addr, b'\x00' * nbytes)  # zero dst

    words = cdma_copy(0x0, dst_addr, nbytes)
    words.append(_header(OP_END, 0, 0))
    inst_bin = inst_words_to_bin(words)
    runner.x.write(INST_BASE, inst_bin)
    runner.start_decoder(len(words))
    runner.poll_done(timeout_s=10.0)

    got = runner.x.read(dst_addr, nbytes)
    ok = got[:nbytes] == PATTERN[:nbytes]
    print(f"  CDMA HBM+0 -> {addr_name} (0x{dst_addr:011x}): {'OK' if ok else 'FAIL'} got={got.hex()}")
    return ok

print("=== CDMA atomic address test ===")
print()

# VPU_BUF range
test_cdma_to("VPU_BUF+0x000000 (src0 slot)", VPU_BUF_BASE + 0x000000)
test_cdma_to("VPU_BUF+0x100000",             VPU_BUF_BASE + 0x100000)
test_cdma_to("VPU_BUF+0x200000 (dst slot)",  VPU_BUF_BASE + 0x200000)
test_cdma_to("VPU_BUF+0x300000",             VPU_BUF_BASE + 0x300000)

print()
# WB
test_cdma_to("WB_BASE        ",              WB_BASE)

print()
# TILE_IBUF
test_cdma_to("TILE_IBUF[0]+0x040000",        TILE_IBUF_BASE + 0x040000)
test_cdma_to("TILE_IBUF[1]+0x0c0000",        TILE_IBUF_BASE + 0x0c0000)
