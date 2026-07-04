"""
Probe CDMA address mapping: find the actual address where CDMA can read tile_obuf.
Method:
  1. Write known pattern to tile_obuf via XDMA (direct write to TILE_OBUF_BASE)
  2. Issue CDMA copy from candidate addresses to HBM scratch
  3. Check which candidate address brings correct data
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
from hbm_flow import cdma_copy, OP_WAIT_CDMA, OP_END, parse_inst_words

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

SCRATCH_HBM = HBM_BASE + 0x200000  # 0x200000 = 2MB offset in HBM, safe scratch
N_BYTES = 512  # 32 * 16

def run_cdma_read(src_addr, dst_addr=SCRATCH_HBM, n_bytes=N_BYTES, label=""):
    """Issue a single CDMA copy instruction and return bytes read from dst."""
    # Zero dst
    xdma.write(dst_addr, b"\x00" * n_bytes)

    # Build instruction: CDMA_COPY src -> dst, then END
    insts = cdma_copy(src_addr, dst_addr, n_bytes) + [OP_WAIT_CDMA, OP_END]
    inst_bytes = inst_words_to_bin(insts)
    n_words = len(inst_bytes) // 4

    xdma.write(INST_BASE, inst_bytes)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, n_words)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

    t0 = time.time()
    while time.time() - t0 < 5.0:
        st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
        if st & 0x2:
            break
        time.sleep(0.002)

    data = xdma.read(dst_addr, n_bytes)
    nz = sum(1 for i in range(0, len(data), 16) if any(data[i:i+16]))
    return nz, data

# Write known pattern to tile_obuf[0] via XDMA
PATTERN = bytes(range(16)) * 32  # 512 bytes
xdma.write(TILE_OBUF_BASE, PATTERN)
readback = xdma.read(TILE_OBUF_BASE, N_BYTES)
assert readback == PATTERN, f"XDMA write/read tile_obuf failed!"
print(f"[OK] XDMA write+read tile_obuf[0] @ 0x{TILE_OBUF_BASE:011x} passed")

print("\nProbing CDMA src addresses (trying to read tile_obuf[0]):")
candidates = [
    (0x1_0100_0000, "xdma_win.py TILE_OBUF_BASE"),
    (0x1_0020_0000, "chip/address.tcl DCIM OBUF"),
    (0x1_0000_0000, "DCIM IBUF"),
    (0x1_0040_0000, "VPU GB"),
    (0x0_0200_0000, "HBM @ 2MB"),
]

for addr, label in candidates:
    nz, data = run_cdma_read(addr, label=label)
    match = (data == PATTERN)
    print(f"  src=0x{addr:011x}  ({label:35s})  nz={nz:3d}/32  match={match}")

print("\nDone.")
