"""Read back VPU_BUF source region after im2col to verify source integrity.
Also read back the output region to confirm the errors are in the output."""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, VPU_BUF_BASE
import subprocess

runner = ChipRunnerWin(verbose=False)
im_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")
exe = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\xdma_exe\xdma_rw.exe")

# First sanity check
print("=== Sanity check ===")
base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
r = runner.run_case(base / "dcim_matmul_dcim_tiny_1x1_qint8", staging="preload")[0]
print(f"  dcim_tiny: {'PASS' if r['pass'] else 'FAIL'}")

# Run im2col
print("\n=== Running im2col preload ===")
r = runner.run_case(im_dir, staging="preload")[0]
passed = r["passed"]
total = r["total_words"]
print(f"  Result: {'PASS' if r['pass'] else f'FAIL ({passed}/{total})'}")

# Now read back the source region from VPU_BUF
# VPU_BUF is accessible via AXI at VPU_BUF_BASE (from xdma_win)
# src_addr=0 means offset 0 within VPU_BUF. Physical = VPU_BUF_BASE + 0
# Source is 2304 bytes (12x12 pixels * 16 bytes each)
SRC_SIZE = 2304
print(f"\n=== Reading back VPU_BUF source region ({SRC_SIZE} bytes) ===")

src_readback_file = im_dir / "_src_readback.bin"
cmd = [str(exe), "read", hex(VPU_BUF_BASE), str(SRC_SIZE), str(src_readback_file)]
result = subprocess.run(cmd, capture_output=True, timeout=30)
if result.returncode != 0:
    print(f"  XDMA read failed: {result.stderr.decode()}")
    exit(1)

# Compare with original source
src_original = hex_to_bin(im_dir / "src0.hex")[:SRC_SIZE]
src_readback = src_readback_file.read_bytes()

if len(src_readback) < SRC_SIZE:
    print(f"  WARNING: only got {len(src_readback)} bytes")
    SRC_SIZE = len(src_readback)

n_diff = 0
diff_positions = []
for i in range(SRC_SIZE):
    if src_original[i] != src_readback[i]:
        n_diff += 1
        if len(diff_positions) < 20:
            diff_positions.append((i, src_original[i], src_readback[i]))

print(f"  Source region differences: {n_diff} / {SRC_SIZE} bytes")
if n_diff > 0:
    print("  SOURCE DATA WAS CORRUPTED!")
    for pos, exp, got in diff_positions:
        pixel = pos // 16
        ih = pixel // 12
        iw = pixel % 12
        c = pos % 16
        print(f"    byte {pos}: pixel({ih},{iw}) c={c} exp=0x{exp:02x} got=0x{got:02x} XOR=0x{exp^got:02x}")
else:
    print("  Source region is INTACT after im2col execution.")
    print("  → The errors are in the OUTPUT path (write corruption), not input path.")
