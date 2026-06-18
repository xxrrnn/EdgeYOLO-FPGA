"""Batch test all cases with staging=preload."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from xdma_win import ChipRunnerWin, case_timeout_s
from gen_data import generate_case

BATCH = [
    ("dcim_matmul", "dcim_tiny_1x1",      "int8"),
    ("dcim_matmul", "conv6_s2_c3_to16",   "int8"),
    ("dcim_matmul", "conv3_s2_c32_to64",  "int8"),
    ("qa",          "qa_c16_signed",       "int8"),
    ("dqa",         "dqa_c16_small",       "int8"),
    ("im2col",      "im2col_6x6_s2_c3",   "int8"),
]
STAGING = "preload"
STOP_ON_FAIL = False

runner = ChipRunnerWin(verbose=True)
results_summary = []

for module, variant, quant in BATCH:
    run_dir = generate_case(module, variant, quant)
    timeout = case_timeout_s(module, variant)
    print(f"\n{'='*60}")
    print(f"Case: {module}/{variant}  staging={STAGING}  timeout={timeout}s")
    print(f"{'='*60}")
    try:
        results = runner.run_case(run_dir, timeout_s=timeout, staging=STAGING)
        ok = all(r["pass"] for r in results)
        label = "PASS" if ok else "FAIL"
        detail = f"({results[0]['passed']}/{results[0]['total_words']} words)" if results else ""
        results_summary.append((module, variant, label, detail))
        if not ok and STOP_ON_FAIL:
            break
    except Exception as e:
        results_summary.append((module, variant, "ERROR", str(e)))
        print(f"ERROR: {e}")
        if STOP_ON_FAIL:
            break

print(f"\n{'='*60}")
print("BATCH RESULTS")
print(f"{'='*60}")
for module, variant, label, detail in results_summary:
    tag = f"{module}/{variant}"
    print(f"  {label:5s}  {tag:40s} {detail}")
