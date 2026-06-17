"""
Systematic address scan: find all XDMA-accessible and CDMA-accessible regions.
Write pattern via XDMA, read back via XDMA (find accessible), then CDMA-read each to find CDMA-accessible.
"""
import sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, VPU_BUF_BASE, TILE_OBUF_BASE, TILE_IBUF_BASE,
    TILE_OBUF_SIZE, WB_BASE, INST_BASE, REGS_BASE,
    inst_words_to_bin,
    REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
)
from hbm_flow import cdma_copy, OP_END

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

PATTERN = bytes(range(16)) * 2   # 32 bytes
SCRATCH = HBM_BASE + 0x600000

def xdma_rw_ok(addr):
    try:
        xdma.write(addr, PATTERN)
        d = xdma.read(addr, len(PATTERN))
        return d == PATTERN
    except:
        return False

def cdma_read_ok(src_addr):
    xdma.write(SCRATCH, b"\x00" * len(PATTERN))
    insts = cdma_copy(src_addr, SCRATCH, len(PATTERN)) + [OP_END]
    ib = inst_words_to_bin(insts)
    nw = len(ib) // 4
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, nw)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 3.0:
        st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
        if st & 0x2:
            break
        time.sleep(0.002)
    try:
        result = xdma.read(SCRATCH, len(PATTERN))
        return result == PATTERN
    except:
        return False

# Candidate address ranges to probe (aligned to 64KB)
candidates = [
    (0x1_0000_0000, "TILE_IBUF_BASE"),
    (0x1_0040_0000, "tcl VPU_GB"),
    (0x1_0048_0000, "tcl VPU_WB"),
    (0x1_0050_0000, "tcl INST_BRAM"),
    (0x1_0060_0000, "tcl VPU_Regs"),
    (0x1_0080_0000, "+0x080000"),
    (0x1_0100_0000, "TILE_OBUF_BASE"),
    (0x1_0140_0000, "+0x140000"),
    (0x1_0180_0000, "+0x180000"),
    (0x1_01c0_0000, "+0x1c0000"),
    (0x1_0200_0000, "VPU_BUF_BASE"),
    (0x1_0240_0000, "+0x240000"),
    (0x1_0280_0000, "+0x280000"),
    (0x1_02c0_0000, "+0x2c0000"),
    (0x1_0300_0000, "WB_BASE"),
    (0x1_0340_0000, "+0x340000"),
    (0x1_0380_0000, "+0x380000"),
    (0x1_03c0_0000, "+0x3c0000"),
    (0x1_0400_0000, "INST_BASE"),
    (0x1_0440_0000, "+0x440000"),
    (0x1_0480_0000, "+0x480000"),
    (0x1_04c0_0000, "+0x4c0000"),
    (0x1_0500_0000, "REGS_BASE"),
    (0x1_0540_0000, "+0x540000"),
    (0x1_0580_0000, "+0x580000"),
    (0x1_05c0_0000, "+0x5c0000"),
]

print(f"{'Address':15s} {'Label':28s} {'XDMA':6s} {'CDMA':6s}")
print("-" * 60)
for addr, label in candidates:
    xw = xdma_rw_ok(addr)
    if xw:
        cw = cdma_read_ok(addr)
        xdma.write(addr, PATTERN)  # restore pattern for CDMA test
    else:
        cw = False
    marker = " <-- CDMA!" if cw else (" <-- XDMA-only" if xw else "")
    print(f"0x{addr:011x}  {label:28s}  {'YES' if xw else 'no ':6s}  {'YES' if cw else 'no ':6s}{marker}")

print("\nDone.")
