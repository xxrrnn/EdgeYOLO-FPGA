"""L3 Full Re-run: conv_pipeline + mini_network (both staging modes).

Strategy:
  1. Run all cases with preload and hbm staging.
  2. For any failure, print intermediate slot diagnostics.
  3. Results are summarized at the end.
"""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from gen_data import generate_case
from xdma_win import ChipRunnerWin, VPU_BUF_BASE, HBM_BASE, HBM_OFF_OUTPUT

runner = ChipRunnerWin()

CONV_PIPELINE_CASES = [
    'pipe_conv1_c16_to16',
    'pipe_conv3_s2_c32_to64',
    'pipe_conv1_c512_to64_tilepass',
]

MINI_NETWORK_CASES = [
    'mini_2conv_c16',
    'mini_3conv_residual_c32',
]

results = []  # (case, staging, pass/fail, note)

def run_one(module, case, staging):
    run_dir = generate_case(module, case)
    res = runner.run_case(run_dir, staging=staging, timeout_s=120.0)
    r = res[0]
    ok = r['pass']
    note = ''
    if not ok:
        mm = r.get('mismatches', [])
        if mm:
            note = f"word0 exp={mm[0]['expected'][:16]} got={mm[0]['got'][:16]}"
        else:
            note = f"passed={r.get('passed','?')}/{r.get('n_words','?')}"
    return ok, note

print("=" * 70)
print("L3 TEST SUITE RE-RUN (post-reset)")
print("=" * 70)

# ── conv_pipeline ─────────────────────────────────────────────────────────
print("\n[conv_pipeline]")
for case in CONV_PIPELINE_CASES:
    for staging in ('preload', 'hbm'):
        try:
            ok, note = run_one('conv_pipeline', case, staging)
            tag = 'PASS' if ok else 'FAIL'
            line = f"  {case:40s} {staging:8s}  {tag}"
            if note:
                line += f"  ({note})"
            print(line)
            results.append((case, staging, ok, note))
        except Exception as e:
            print(f"  {case:40s} {staging:8s}  ERROR: {e}")
            results.append((case, staging, False, str(e)))

# ── mini_network ──────────────────────────────────────────────────────────
print("\n[mini_network]")
for case in MINI_NETWORK_CASES:
    for staging in ('preload', 'hbm'):
        try:
            ok, note = run_one('mini_network', case, staging)
            tag = 'PASS' if ok else 'FAIL'
            line = f"  {case:40s} {staging:8s}  {tag}"
            if note:
                line += f"  ({note})"
            print(line)
            results.append((case, staging, ok, note))
        except Exception as e:
            print(f"  {case:40s} {staging:8s}  ERROR: {e}")
            results.append((case, staging, False, str(e)))

# ── Summary ───────────────────────────────────────────────────────────────
passed = sum(1 for _, _, ok, _ in results if ok)
total  = len(results)
print()
print("=" * 70)
print(f"SUMMARY: {passed}/{total} PASS")
print("=" * 70)
for case, staging, ok, note in results:
    tag = 'PASS' if ok else 'FAIL'
    line = f"  {tag}  {case} [{staging}]"
    if note:
        line += f"  -- {note}"
    print(line)
