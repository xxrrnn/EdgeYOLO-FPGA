"""
Pinpoint:
1. Can CDMA read from VPU_BUF_BASE (0x102000000)?
2. Which tiles fail in 4-tile drain?
3. What is the correct VPU_BUF address in CDMA space?
"""
import sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE,
    TILE_OBUF_BASE, TILE_OBUF_SIZE,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    inst_words_to_bin,
)
from hbm_flow import cdma_copy, build_hbm_output_drain, OP_END, OP_WAIT_CDMA
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

N_BYTES = 512
PATTERN = bytes(range(16)) * 32  # 512 bytes distinct pattern
SCRATCH_HBM = HBM_BASE + 0x500000

def cdma_read_test(src_addr, label):
    """Write PATTERN to src via XDMA, then CDMA copy to scratch HBM, check match."""
    xdma.write(src_addr, PATTERN)
    rb = xdma.read(src_addr, N_BYTES)
    if rb != PATTERN:
        print(f"  {label}: XDMA write/read FAILED!")
        return False
    xdma.write(SCRATCH_HBM, b"\x00" * N_BYTES)
    insts = cdma_copy(src_addr, SCRATCH_HBM, N_BYTES) + [OP_END]
    ib = inst_words_to_bin(insts)
    nw = len(ib) // 4
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, nw)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 5.0:
        st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
        if st & 0x2:
            break
        time.sleep(0.002)
    result = xdma.read(SCRATCH_HBM, N_BYTES)
    ok = result == PATTERN
    print(f"  {label}  src=0x{src_addr:011x}  CDMA_readable={ok}")
    return ok

print("=" * 65)
print("Section 1: CDMA read from VPU_BUF region")
print("=" * 65)
# Probe various offsets in VPU_BUF
for offset in [0x0, 0x780, 0xf00, 0x2000]:
    cdma_read_test(VPU_BUF_BASE + offset, f"VPU_BUF+0x{offset:x}")

# Also probe alternate addresses
print()
VPU_GB_ALT = 0x1_0040_0000  # chip/address.tcl VPU GB address
VPU_GB_ALT2 = 0x1_0060_0000  # VPU regs? 
for addr, label in [
    (0x1_0040_0000, "chip/tcl VPU_GB  @ 0x100400000"),
    (0x1_0048_0000, "chip/tcl VPU_WB  @ 0x100480000"),
    (0x1_0200_0000, "xdma_win VPU_BUF @ 0x102000000"),
    (0x1_0220_0000, "VPU_BUF+0x20000  @ 0x102200000"),
]:
    cdma_read_test(addr, label)

print()
print("=" * 65)
print("Section 2: Which tiles fail in 4-tile dcim drain?")
print("=" * 65)
WPT = 4
rd4 = generate_case("dcim_matmul", "conv3_s2_c32_to64")
n_tile_words = 32

# Preload to fill tile_obuf with known data
runner.upload_preload(rd4)
n_inst = runner.upload_inst_raw(rd4)
runner.start_decoder(n_inst)
runner.poll_done(timeout_s=60.0)

# Read tile_obuf contents
tile_data = [xdma.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, n_tile_words * 16) for t in range(4)]
for t, d in enumerate(tile_data):
    nz = sum(1 for i in range(0, len(d), 16) if any(d[i:i+16]))
    print(f"  tile_obuf[{t}]: {nz}/{n_tile_words} non-zero")

# Do drain (full hbm run to fire the patched inst including barrier+drain)
r = runner.run_case(rd4, staging="hbm", timeout_s=60.0)[0]
hbm_s = "PASS" if r["pass"] else f"FAIL {r['passed']}/{r['total_words']}"
print(f"  full hbm run: {hbm_s}")

# Read HBM per-slot and compare
for t in range(4):
    addr = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
    d = xdma.read(addr, n_tile_words * 16)
    nz = sum(1 for i in range(0, len(d), 16) if any(d[i:i+16]))
    match = d == tile_data[t]
    print(f"  HBM drain[{t}] @ 0x{addr:011x}: {nz}/{n_tile_words} non-zero  match={match}")

print("\nDone.")
