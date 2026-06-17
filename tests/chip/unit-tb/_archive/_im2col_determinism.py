"""Verify im2col error is DETERMINISTIC (same word positions every run).
If yes → confirms it's a systematic pipeline timing bug, not random noise."""
from pathlib import Path
from xdma_win import ChipRunnerWin

runner = ChipRunnerWin(verbose=False)
base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
im_dir = base / "im2col_im2col_6x6_s2_c3_qint8"

N_RUNS = 5
all_mismatch_words = []

for i in range(N_RUNS):
    # Sanity check first
    r = runner.run_case(base / "dcim_matmul_dcim_tiny_1x1_qint8", staging="preload")[0]
    if not r['pass']:
        print(f"Run {i+1}: FPGA hung after previous im2col, aborting.")
        break
    
    r = runner.run_case(im_dir, staging="preload")[0]
    if r['pass']:
        print(f"Run {i+1}: PASS (unexpected!)")
        all_mismatch_words.append(set())
    else:
        mismatches = r.get("mismatches", [])
        words = set(m["word"] for m in mismatches)
        passed = r["passed"]
        total = r["total_words"]
        print(f"Run {i+1}: FAIL ({passed}/{total}), {len(words)} bad words: {sorted(words)[:10]}...")
        all_mismatch_words.append(words)

# Analysis
if len(all_mismatch_words) >= 2:
    print(f"\n=== Determinism analysis ({len(all_mismatch_words)} successful runs) ===")
    
    # Check if all runs have the same error positions
    non_empty = [w for w in all_mismatch_words if w]
    if len(non_empty) >= 2:
        intersection = non_empty[0]
        union = non_empty[0].copy()
        for s in non_empty[1:]:
            intersection = intersection & s
            union = union | s
        
        print(f"  Intersection (common to ALL runs): {len(intersection)} words")
        print(f"  Union (appeared in ANY run): {len(union)} words")
        print(f"  Intersection / Union ratio: {len(intersection)/len(union)*100:.1f}%")
        print(f"  Common error words: {sorted(intersection)}")
        
        if len(intersection) == len(union):
            print("\n  *** 100% DETERMINISTIC: exact same words fail every time ***")
            print("  → Confirms systematic RTL pipeline timing bug (not noise)")
        elif len(intersection) / len(union) > 0.8:
            print("\n  *** Mostly deterministic (>80% overlap) ***")
            print("  → Core errors are systematic, some variation at boundaries")
        else:
            print("\n  Significant variation between runs → may have random component")
    elif len(non_empty) == 1:
        print(f"  Only 1 failed run, cannot compare")
    else:
        print(f"  All runs passed (?)")
