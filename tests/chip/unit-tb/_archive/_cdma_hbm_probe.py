"""
Direct probe: read CDMA status register (SR) at address CDMA_BASE + 0x4.
Also probe CDMA config registers after a known drain sequence to check
if addresses are being written correctly.
"""
import sys, struct, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, TILE_OBUF_BASE, TILE_OBUF_SIZE,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    inst_words_to_bin,
)
from hbm_flow import cdma_copy, OP_WAIT_CDMA, OP_END

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

# CDMA IP is accessible via XDMA:
# xdma_win.py does not expose CDMA address,
# but chip/address.tcl says CDMA S_AXI_LITE is at xdma M_AXI 0x200020000 (xdma_dcim_hbm)
# For chip bd: CDMA is NOT mapped to XDMA! cdma_ctrl has point-to-point.
# Let's look for CDMA regs in xdma address space.

# chip/address.tcl has NO "map_seg $xdma_as ... axi_cdma_0" line,
# so XDMA cannot read CDMA registers directly.
# But we can read the CDMA indirectly via observing behavior.

print("=" * 65)
print("Test 1: Check if CDMA single copy HBM->HBM works")
print("=" * 65)

# Write pattern to HBM source
SRC_ADDR = HBM_BASE + 0x300000  # 3MB in HBM (safe scratch)
DST_ADDR = HBM_BASE + 0x400000  # 4MB in HBM (safe scratch)
PATTERN = bytes(range(16)) * 32  # 512 bytes

xdma.write(SRC_ADDR, PATTERN)
rb = xdma.read(SRC_ADDR, len(PATTERN))
assert rb == PATTERN, "Host write/read HBM src failed"
print(f"[OK] Written {len(PATTERN)}B pattern to HBM SRC @ 0x{SRC_ADDR:x}")

xdma.write(DST_ADDR, b"\x00" * len(PATTERN))
print(f"[OK] Zeroed HBM DST @ 0x{DST_ADDR:x}")

# Issue CDMA copy HBM SRC -> HBM DST
insts = cdma_copy(SRC_ADDR, DST_ADDR, len(PATTERN)) + [OP_END]
inst_bytes = inst_words_to_bin(insts)
n_words = len(inst_bytes) // 4
xdma.write(INST_BASE, inst_bytes)
xdma.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
time.sleep(0.001)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

t0 = time.time()
while time.time() - t0 < 10.0:
    st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
    if st & 0x2:
        break
    time.sleep(0.005)

print(f"DECODER_STATUS = 0x{st:08x} (done={bool(st&2)})")

dst_data = xdma.read(DST_ADDR, len(PATTERN))
nz = sum(1 for i in range(0, len(dst_data), 16) if any(dst_data[i:i+16]))
match = dst_data == PATTERN
print(f"HBM->HBM copy: nz={nz}/{len(PATTERN)//16} match={match}")
if not match:
    print("  First 32 bytes of dst: " + dst_data[:32].hex())

print()
print("=" * 65)
print("Test 2: CDMA TILE_OBUF[0]->HBM copy")
print("=" * 65)

# Write pattern to tile_obuf[0] via XDMA
xdma.write(TILE_OBUF_BASE, PATTERN)
rb_obuf = xdma.read(TILE_OBUF_BASE, len(PATTERN))
assert rb_obuf == PATTERN, f"XDMA write tile_obuf failed: got {rb_obuf[:8].hex()}"
print(f"[OK] XDMA write tile_obuf[0] @ 0x{TILE_OBUF_BASE:x}")

# Zero DST
xdma.write(DST_ADDR, b"\x00" * len(PATTERN))

# CDMA copy TILE_OBUF[0] -> HBM DST
insts2 = cdma_copy(TILE_OBUF_BASE, DST_ADDR, len(PATTERN)) + [OP_END]
inst_bytes2 = inst_words_to_bin(insts2)
n_words2 = len(inst_bytes2) // 4
xdma.write(INST_BASE, inst_bytes2)
xdma.write_u32(REGS_BASE + REG_INST_COUNT, n_words2)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
time.sleep(0.001)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

t0 = time.time()
while time.time() - t0 < 10.0:
    st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
    if st & 0x2:
        break
    time.sleep(0.005)

print(f"DECODER_STATUS = 0x{st:08x} (done={bool(st&2)})")
dst_data2 = xdma.read(DST_ADDR, len(PATTERN))
nz2 = sum(1 for i in range(0, len(dst_data2), 16) if any(dst_data2[i:i+16]))
match2 = dst_data2 == PATTERN
print(f"TILE_OBUF->HBM copy: nz={nz2}/{len(PATTERN)//16} match={match2}")
if not match2:
    print("  First 32 bytes of dst: " + dst_data2[:32].hex())
    # Maybe wrong address? Try DCIM OBUF address from chip/address.tcl
    print()
    print("  Trying alternate tile_obuf addr (chip/address.tcl OBUF = 0x100200000)...")
    OBUF_ALT = 0x1_0020_0000  # chip/address.tcl DCIM OBUF
    xdma.write(OBUF_ALT, PATTERN)
    rb_alt = xdma.read(OBUF_ALT, len(PATTERN))
    same_as_main = rb_alt == xdma.read(TILE_OBUF_BASE, len(PATTERN))
    print(f"  XDMA write OBUF_ALT @ 0x{OBUF_ALT:x}: readback matches TILE_OBUF_BASE={same_as_main}")

print("\nDone.")
