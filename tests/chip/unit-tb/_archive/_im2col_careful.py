"""im2col: check if decoder finishes, poll done status, then try read."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, VPU_BUF_BASE
import time

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")
runner = ChipRunnerWin(verbose=True)

# Preload src0 to VPU_BUF
print("=== Step 1: upload_preload ===")
runner.upload_preload(run_dir)

# Upload inst and start
print("\n=== Step 2: upload inst + start ===")
n_inst = runner.upload_inst_raw(run_dir)
print(f"  inst words: {n_inst}")
runner.start_decoder(n_inst)

# Poll decoder status with timeout
print("\n=== Step 3: poll done (120s timeout) ===")
try:
    runner.poll_done(120.0)
    print("  Decoder: DONE")
except TimeoutError as e:
    print(f"  Decoder: TIMEOUT! {e}")
    print("  im2col likely hung - VPU never signaled ready")
    exit(1)

# Small delay then try reading a SAFE address first (INST_BRAM, known good)
print("\n=== Step 4: test read from INST_BRAM (safe) ===")
from xdma_win import INST_BASE
try:
    test = runner.x.read(INST_BASE, 16)
    print(f"  INST_BRAM read OK: {test.hex()}")
except Exception as e:
    print(f"  INST_BRAM read FAILED: {e}")
    print("  AXI bus is wedged!")
    exit(1)

# Now try reading VPU_BUF at offset 0 (src area, should still have input data)
print("\n=== Step 5: read VPU_BUF src area (offset 0, 16 bytes) ===")
try:
    src_test = runner.x.read(VPU_BUF_BASE, 16)
    print(f"  VPU_BUF[0] read OK: {src_test.hex()}")
except Exception as e:
    print(f"  VPU_BUF[0] read FAILED: {e}")
    print("  VPU_BUF AXI port is locked!")
    exit(1)

# Now try reading the actual output area
print("\n=== Step 6: read VPU_BUF dst area (offset 0x900, 256 words) ===")
DST_OFF = 0x000900
N_WORDS = 256
try:
    got = runner.x.read(VPU_BUF_BASE + DST_OFF, N_WORDS * 16)
    print(f"  VPU_BUF[0x900] read OK ({len(got)} bytes)")
except Exception as e:
    print(f"  VPU_BUF[0x900] read FAILED: {e}")
    exit(1)

# Compare
exp = hex_to_bin(run_dir / "expected.hex")[:N_WORDS * 16]
mismatches = [(i, exp[i*16:(i+1)*16], got[i*16:(i+1)*16])
              for i in range(N_WORDS) if exp[i*16:(i+1)*16] != got[i*16:(i+1)*16]]
print(f"\n=== Result: {N_WORDS - len(mismatches)}/{N_WORDS} match ===")
if mismatches:
    for i, e, g in mismatches[:10]:
        e_z = all(b == 0 for b in e)
        g_z = all(b == 0 for b in g)
        tag = " [exp=0,got!=0]" if e_z else (" [got=0,exp!=0]" if g_z else "")
        print(f"  word {i:3d}: exp={e.hex()} got={g.hex()}{tag}")
    if len(mismatches) > 10:
        print(f"  ... ({len(mismatches)-10} more)")
