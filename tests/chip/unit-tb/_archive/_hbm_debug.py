"""Show ALL failing words in hbm staging, not just first_mismatch."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, HBM_BASE, HBM_OFF_OUTPUT
import struct

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")
runner = ChipRunnerWin(verbose=True)

# Run hbm staging
results = runner.run_case(run_dir, timeout_s=60.0, staging="hbm")

# Also read tile_obuf[0] directly for comparison
from xdma_win import TILE_OBUF_BASE, TILE_OBUF_SIZE
print("\n=== Direct tile_obuf[0] read (first 16 words = 256 bytes) ===")
obuf0 = runner.x.read(TILE_OBUF_BASE + 0 * TILE_OBUF_SIZE, 16 * 16)
for i in range(16):
    w = obuf0[i*16:(i+1)*16]
    print(f"  tile_obuf[0][word {i:2d}] = {w.hex()}")

# Also read HBM output region
print("\n=== HBM output region (words 60-70) ===")
hbm_out = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, 128 * 16)
for i in range(60, min(75, 128)):
    w = hbm_out[i*16:(i+1)*16]
    print(f"  HBM[{i:3d}] = {w.hex()}")

# Show all failures
print("\n=== All failures ===")
exp_raw = hex_to_bin(run_dir / "expected.hex")[:128*16]
for i in range(128):
    exp = exp_raw[i*16:(i+1)*16]
    got = hbm_out[i*16:(i+1)*16]
    if exp != got:
        print(f"  word {i:3d}: exp={exp.hex()} got={got.hex()}")
