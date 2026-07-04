"""Run previously-failing test cases to verify RTL fixes."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from xdma_win import ChipRunnerWin

runner = ChipRunnerWin(verbose=True)
base = Path(__file__).resolve().parent / "runs"

cases = [
    # (dir_name, staging, description)
    ("im2col_im2col_6x6_s2_c3_qint8", "hbm", "im2col 6x6 [hbm] - prev FAIL (URAM pipeline)"),
    ("im2col_im2col_6x6_s2_c3_qint8", "preload", "im2col 6x6 [preload] - prev FAIL"),
    ("dcim_matmul_conv3_s2_c32_to64_qint8", "hbm", "conv3 3-Tile [hbm] - prev FAIL (CDMA_COOLDOWN)"),
    ("dcim_matmul_conv3_s2_c32_to64_qint8", "preload", "conv3 3-Tile [preload] - prev PASS"),
    ("dqa_dqa_c16_small_qint8", "hbm", "dqa [hbm] - prev sporadic FAIL (VPU ready)"),
    ("qa_qa_c16_signed_qint8", "hbm", "qa [hbm] - prev sporadic FAIL"),
    ("dcim_matmul_conv6_s2_c3_to16_qint8", "hbm", "conv6 1-Tile [hbm] - prev PASS"),
]

results_summary = []

for dir_name, staging, desc in cases:
    run_dir = base / dir_name
    if not run_dir.exists():
        print(f"\n[SKIP] {desc} - directory not found")
        results_summary.append((desc, "SKIP"))
        continue

    print(f"\n{'='*60}")
    print(f"TEST: {desc}")
    print(f"{'='*60}")

    try:
        timeout = 180.0 if "im2col" in dir_name else 90.0
        results = runner.run_case(run_dir, staging=staging, timeout_s=timeout)
        all_pass = all(r["pass"] for r in results)
        for r in results:
            status = "PASS" if r["pass"] else f"FAIL ({r['passed']}/{r['total_words']})"
            print(f"  {r['name']:30s} {status}")
            if not r["pass"] and r["first_mismatch"]:
                m = r["first_mismatch"]
                print(f"    word {m['word']}: exp={m['expected'][:16]}.. got={m['got'][:16]}..")
        results_summary.append((desc, "PASS" if all_pass else "FAIL"))
    except Exception as e:
        print(f"  ERROR: {e}")
        results_summary.append((desc, f"ERROR: {e}"))

print(f"\n\n{'='*60}")
print("SUMMARY")
print(f"{'='*60}")
for desc, status in results_summary:
    marker = "PASS" if status == "PASS" else status
    print(f"  [{marker:6s}] {desc}")

n_pass = sum(1 for _, s in results_summary if s == "PASS")
n_total = len(results_summary)
print(f"\n  Total: {n_pass}/{n_total} PASSED")
sys.exit(0 if n_pass == n_total else 1)
