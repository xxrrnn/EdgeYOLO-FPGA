"""
L2 failure analysis: compare hbm vs preload for the failing cases,
and check if failures are consistent or randomized across runs.
"""
import sys, time
from pathlib import Path
from collections import defaultdict

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import XDMAWin, ChipRunnerWin
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

# Failed cases from L2 run — pick representative ones
CASES = [
    # (module, variant, quant, tmo)
    ("dcim_matmul", "conv1_c64_to32",              "int8",  90),  # N=32 2-tile
    ("dcim_matmul", "conv3_c128_to128",             "int8",  90),  # N=128 8-tile
    ("dcim_matmul", "extreme_int8_1x1_c512_to512",  "int8", 120),  # N=512 multi-tilepass
    ("dqa",         "dqa_c32_mid",                  "int8",  60),  # DQA c=32
    ("qa",          "qa_c64_clip",                  "int8",  60),  # QA c=64
    ("im2col",      "im2col_3x3_s2_c32",            "int8", 180),  # im2col c32
]

WIDTH = 70
print("=" * WIDTH)
print("L2 Failure Analysis: hbm vs preload + repeat stability")
print("=" * WIDTH)

for module, variant, quant, tmo in CASES:
    rd = generate_case(module, variant, quant=quant)
    print(f"\n--- {module}/{variant} ---")

    # Run preload (ground truth: on-chip data correct?)
    r_pre = runner.run_case(rd, staging="preload", timeout_s=tmo)
    pre_ok = all(r["pass"] for r in r_pre)
    pre_pw = r_pre[0]["passed"] if r_pre else 0
    pre_tw = r_pre[0]["total_words"] if r_pre else 0
    print(f"  preload: {'PASS' if pre_ok else f'FAIL ({pre_pw}/{pre_tw})'}")
    if not pre_ok and r_pre[0]["first_mismatch"]:
        m = r_pre[0]["first_mismatch"]
        print(f"    word {m['word']}: exp={str(m['expected'])[:40]}.. got={str(m['got'])[:40]}..")

    # Run hbm 3 times to check stability
    hbm_results = []
    for run_i in range(3):
        r_hbm = runner.run_case(rd, staging="hbm", timeout_s=tmo)
        pw = r_hbm[0]["passed"] if r_hbm else 0
        tw = r_hbm[0]["total_words"] if r_hbm else 0
        hbm_results.append((pw, tw))
        status = "PASS" if pw == tw else f"FAIL ({pw}/{tw})"
        first_fail_word = None
        if pw < tw and r_hbm[0]["first_mismatch"]:
            first_fail_word = r_hbm[0]["first_mismatch"]["word"]
        print(f"  hbm run{run_i+1}: {status}"
              + (f"  first_fail=word{first_fail_word}" if first_fail_word is not None else ""))

    # Verdict
    all_hbm_pass = all(pw == tw for pw, tw in hbm_results)
    hbm_consistent = len(set(pw for pw, tw in hbm_results)) == 1
    if pre_ok and not all_hbm_pass:
        # preload OK but hbm FAIL → HBM drain path bug
        fail_words = [tw - pw for pw, tw in hbm_results]
        consistent = "consistent" if hbm_consistent else "variable"
        print(f"  --> DIAGNOSIS: on-chip compute OK, HBM drain FAIL ({consistent} failure)")
        # Check if first failing word is always the same
        if hbm_consistent:
            print(f"  --> deterministic: always {hbm_results[0][0]}/{hbm_results[0][1]} pass")
        else:
            print(f"  --> non-deterministic: pass counts = {[pw for pw,tw in hbm_results]}")
    elif not pre_ok:
        print(f"  --> DIAGNOSIS: on-chip compute itself FAIL (preload also fails)")
    else:
        print(f"  --> OK: both preload and hbm pass")

print("\n" + "=" * WIDTH)
print("Done.")
