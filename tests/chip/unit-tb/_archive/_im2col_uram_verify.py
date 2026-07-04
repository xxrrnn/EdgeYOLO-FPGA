"""Verify URAM pipeline corruption hypothesis.

Strategy: Run im2col twice with DIFFERENT source data but same parameters.
If the second run's output contains traces of the FIRST run's data,
that proves the URAM pipeline is carrying stale data across write→read transitions.

Test:
1. Run im2col with original random source data → capture output
2. Overwrite source region with 0xAA pattern (easy to distinguish)
3. Run im2col again → check if output contains bits from run #1's output
"""
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, VPU_BUF_BASE, INST_BRAM_BASE
import subprocess, struct, time

runner = ChipRunnerWin(verbose=False)
im_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\im2col_im2col_6x6_s2_c3_qint8")
exe = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\xdma_exe\xdma_rw.exe")

# Parameters
SRC_SIZE = 2304  # 12x12*16
DST_OFFSET = 2304
DST_SIZE = 36 * 128  # OH*OW * row_stride = 4608
CH_IN = 3
KH, KW = 6, 6
ROW_STRIDE = 128
VALID_PER_ROW = KH * KW * CH_IN  # = 108

print("=== Sanity check ===")
base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
r = runner.run_case(base / "dcim_matmul_dcim_tiny_1x1_qint8", staging="preload")[0]
print(f"  dcim_tiny: {'PASS' if r['pass'] else 'FAIL'}")
if not r['pass']:
    print("  FPGA not healthy, abort.")
    exit(1)

# === RUN 1: standard im2col with random data ===
print("\n=== Run 1: im2col with original random source ===")
r1 = runner.run_case(im_dir, staging="preload")[0]
passed1 = r1["passed"]
total1 = r1["total_words"]
print(f"  Result: {'PASS' if r1['pass'] else f'FAIL ({passed1}/{total1})'}")

# Read back the im2col output from VPU_BUF
import tempfile
out1_file = Path(tempfile.mktemp(suffix='.bin'))
cmd = [str(exe), "c2h_0", "read", hex(VPU_BUF_BASE + DST_OFFSET), "-b",
       "-f", str(out1_file), "-l", str(DST_SIZE)]
result = subprocess.run(cmd, capture_output=True, timeout=30)
if result.returncode != 0:
    print(f"  Failed to read back output: {result.stderr.decode()}")
    exit(1)
out1_data = out1_file.read_bytes()
print(f"  Read back {len(out1_data)} bytes of output")

# === Now overwrite source with 0xAA pattern ===
print("\n=== Overwriting source with 0xAA pattern ===")
aa_data = bytes([0xAA] * SRC_SIZE)
import tempfile as tf
aa_file = Path(tf.mktemp(suffix='.bin'))
aa_file.write_bytes(aa_data)
cmd = [str(exe), "h2c_0", "write", hex(VPU_BUF_BASE), "-b",
       "-f", str(aa_file), "-l", str(SRC_SIZE)]
result = subprocess.run(cmd, capture_output=True, timeout=30)
if result.returncode != 0:
    print(f"  Failed to write source: {result.stderr.decode()}")
    exit(1)
print("  Source overwritten with 0xAA")

# Also zero the output region to start fresh
zero_data = bytes(DST_SIZE)
zero_file = Path(tf.mktemp(suffix='.bin'))
zero_file.write_bytes(zero_data)
cmd = [str(exe), "h2c_0", "write", hex(VPU_BUF_BASE + DST_OFFSET), "-b",
       "-f", str(zero_file), "-l", str(DST_SIZE)]
result = subprocess.run(cmd, capture_output=True, timeout=30)
print("  Output region zeroed")

# === RUN 2: re-run im2col (instructions still in INST_BRAM) ===
# Need to re-trigger execution by writing instructions again
print("\n=== Run 2: im2col with 0xAA source ===")
# Use run_case again which will preload src (0xAA) and run
# But we need to modify the flow: manually write 0xAA to src, then just trigger ISA

# Actually easier: just run_case again - it will re-preload everything
# But I want different source data. Let me create a temp src file.

# Create a modified src0.hex with 0xAA
mod_src_file = im_dir / "_src0_aa.hex"
# Each line in src0.hex is 32 hex chars (16 bytes)
lines = []
for i in range(SRC_SIZE // 16):
    lines.append("AA" * 16)
mod_src_file.write_text("\n".join(lines) + "\n")

# Preload using runner's write method
runner.x.write(VPU_BUF_BASE, hex_to_bin(mod_src_file))
print("  Preloaded 0xAA source via XDMA")

# Zero destination again
runner.x.write(VPU_BUF_BASE + DST_OFFSET, bytes(DST_SIZE))
print("  Zeroed destination")

# Re-load instructions (same as before)
inst_data = hex_to_bin(im_dir / "inst.hex")
runner.x.write(INST_BRAM_BASE, inst_data)
print("  Loaded instructions")

# Trigger execution
runner.x.trigger_and_wait()
print("  Execution triggered")

# Read back output
out2_file = Path(tf.mktemp(suffix='.bin'))
cmd = [str(exe), "c2h_0", "read", hex(VPU_BUF_BASE + DST_OFFSET), "-b",
       "-f", str(out2_file), "-l", str(DST_SIZE)]
result = subprocess.run(cmd, capture_output=True, timeout=30)
if result.returncode != 0:
    print(f"  XDMA read timed out (im2col may have hung)")
    exit(1)
out2_data = out2_file.read_bytes()
print(f"  Read back {len(out2_data)} bytes")

# === ANALYSIS ===
print("\n=== Analysis: comparing Run 2 output with expected ===")
# With source = 0xAA, im2col should produce:
#   - Valid positions (in-bound): all bytes should be 0xAA
#   - Padding positions (out-of-bound): all bytes should be 0x00

n_errors = 0
n_stale = 0  # bytes that match Run 1's output (stale data from pipeline)
n_checked = 0

for row in range(36):  # 36 output pixels
    row_start = row * ROW_STRIDE
    for b in range(VALID_PER_ROW):  # only check valid bytes
        n_checked += 1
        pos = row_start + b
        if pos >= len(out2_data):
            break
        got = out2_data[pos]
        
        # Determine if this is padding or valid
        kh_kw_idx = b // CH_IN
        kh = kh_kw_idx // KW
        kw = kh_kw_idx % KW
        c = b % CH_IN
        oh = row // 6
        ow = row % 6
        ih = oh * 2 - 2 + kh
        iw = ow * 2 - 2 + kw
        
        if 0 <= ih < 12 and 0 <= iw < 12:
            expected = 0xAA
        else:
            expected = 0x00
        
        if got != expected:
            n_errors += 1
            # Check if it matches Run 1's data at same position
            if pos < len(out1_data) and got == out1_data[pos]:
                n_stale += 1
            if n_errors <= 15:
                run1_val = out1_data[pos] if pos < len(out1_data) else -1
                print(f"  byte {pos:4d} (oh={oh},ow={ow},kh={kh},kw={kw},c={c}): "
                      f"exp=0x{expected:02x} got=0x{got:02x} run1=0x{run1_val:02x}"
                      f"{' ← STALE!' if got == run1_val else ''}")

print(f"\nTotal checked: {n_checked}")
print(f"Total errors: {n_errors}")
print(f"Stale data matches (from Run 1): {n_stale}")
if n_stale > 0:
    print("*** CONFIRMED: URAM pipeline carries stale data across write→read! ***")
elif n_errors > 0:
    print("Errors present but not matching Run 1 → may be different corruption mechanism")
else:
    print("No errors → hypothesis may be wrong for this specific test pattern")

# Cleanup
for f in [out1_file, out2_file, aa_file, zero_file, mod_src_file]:
    try:
        f.unlink()
    except:
        pass
