"""Run a single on-chip unit test case end-to-end."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from gen_data import generate_case
from xdma_win import ChipRunnerWin

print("=" * 60)
print("On-Chip Unit Test: dcim_matmul / dcim_tiny_1x1")
print("=" * 60)

# Step 1: Generate test data
run_dir = generate_case("dcim_matmul", "dcim_tiny_1x1", quant="int8")

# Step 2: Execute on FPGA
runner = ChipRunnerWin(verbose=True)
results = runner.run_case(run_dir, timeout_s=10.0)

# Step 3: Summary
print("\n" + "=" * 60)
print("FINAL RESULT")
print("=" * 60)
all_pass = all(r["pass"] for r in results)
for r in results:
    status = "PASS" if r["pass"] else "FAIL"
    print(f"  {r['name']:30s} {status} ({r['passed']}/{r['total_words']} words)")
    if not r["pass"] and r["first_mismatch"]:
        m = r["first_mismatch"]
        print(f"    word {m['word']}: exp={m['expected']} got={m['got']}")

sys.exit(0 if all_pass else 1)
