"""
State-isolation test: verify if inter-case FPGA state causes failures.
Hypothesis: CDMA controller or AXI path has residual state after each run.
Fix candidate: add an explicit FPGA reset / CDMA idle flush between cases.
"""
import sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import XDMAWin, ChipRunnerWin, REGS_BASE, REG_DECODER_STATUS
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

def status():
    return xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)

def wait_idle(timeout=5.0):
    """Wait until decoder is not busy."""
    t0 = time.time()
    while time.time() - t0 < timeout:
        st = status()
        if not (st & 0x1):  # bit0=busy
            return st
        time.sleep(0.01)
    return status()

def run_with_gap(rd, staging, gap_s=0.0, label=""):
    if gap_s > 0:
        time.sleep(gap_s)
    r = runner.run_case(rd, staging=staging, timeout_s=120.0)[0]
    tag = "PASS" if r["pass"] else f"FAIL {r['passed']}/{r['total_words']}"
    print(f"  {label:40s} {tag}")
    return r["pass"]

# Test cases
rd_pass = generate_case("dcim_matmul", "conv3_s2_c32_to64")   # known PASS when alone
rd_fail = generate_case("dcim_matmul", "conv1_c64_to32")       # known FAIL in sequence

print("=" * 65)
print("Experiment 1: conv3_s2_c32_to64 ALONE (no prior case)")
print("=" * 65)
run_with_gap(rd_pass, "hbm", 0.0, "conv3_s2 alone run1")
run_with_gap(rd_pass, "hbm", 0.0, "conv3_s2 alone run2")

print()
print("=" * 65)
print("Experiment 2: conv3_s2 after conv1 (state contamination?)")
print("=" * 65)
run_with_gap(rd_fail, "hbm", 0.0, "conv1 run (sets bad state)")
run_with_gap(rd_pass, "hbm", 0.0, "conv3_s2 after conv1 (no gap)")
run_with_gap(rd_pass, "hbm", 1.0, "conv3_s2 after conv1 (1s gap)")
run_with_gap(rd_pass, "hbm", 3.0, "conv3_s2 after conv1 (3s gap)")

print()
print("=" * 65)
print("Experiment 3: conv1 ALONE vs after conv3_s2")
print("=" * 65)
# First run conv1 cold (after a long pause to let AXI settle)
time.sleep(2.0)
run_with_gap(rd_fail, "hbm", 0.0, "conv1 cold (after 2s idle)")
run_with_gap(rd_fail, "hbm", 0.0, "conv1 after itself (no gap)")
run_with_gap(rd_fail, "hbm", 1.0, "conv1 after itself (1s gap)")

print()
print("=" * 65)
print("Experiment 4: does DECODER_STATUS show healthy between runs?")
print("=" * 65)
run_with_gap(rd_fail, "hbm", 0.0, "conv1 run")
st_after = status()
print(f"  DECODER_STATUS after conv1 hbm = 0x{st_after:08x}  "
      f"(busy={bool(st_after&1)} done={bool(st_after&2)} err={bool(st_after&0x80000000)})")
time.sleep(0.5)
st_after2 = status()
print(f"  DECODER_STATUS +0.5s            = 0x{st_after2:08x}")
run_with_gap(rd_pass, "hbm", 0.0, "conv3_s2 immediately after")
st_final = status()
print(f"  DECODER_STATUS after conv3_s2   = 0x{st_final:08x}")

print("\nDone.")
