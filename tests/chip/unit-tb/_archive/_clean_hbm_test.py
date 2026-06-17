"""
Clean test after re-flash: verify dqa/qa/im2col hbm path.
Run each case ONCE in isolation (no addr scan contamination).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from xdma_win import ChipRunnerWin, XDMAWin
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

cases = [
    ("dcim_matmul", "dcim_tiny_1x1",        "1-tile tiny"),
    ("dcim_matmul", "conv3_s2_c32_to64",    "4-tile model.3"),
    ("dcim_matmul", "conv3_c128_to128",     "4-tile model.6"),
    ("dcim_matmul", "dcim_model_7_conv",    "8-tile model.7"),
    ("dqa",         "dqa_c32_mid",          "DQA c=32"),
    ("dqa",         "dqa_c128_sppf",        "DQA c=128"),
    ("qa",          "qa_c64_clip",          "QA c=64"),
    ("im2col",      "im2col_6x6_s2_c3",     "im2col 6x6"),
    ("im2col",      "im2col_1x1_c512",      "im2col 1x1 c512"),
]

print(f"{'Case':35s} {'preload':12s} {'hbm':20s}")
print("-" * 70)

for mod, var, label in cases:
    rd = generate_case(mod, var)
    rp = runner.run_case(rd, staging="preload", timeout_s=120.0)[0]
    rh = runner.run_case(rd, staging="hbm",     timeout_s=120.0)[0]
    ps = "PASS" if rp["pass"] else f"FAIL {rp['passed']}/{rp['total_words']}"
    hs = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
    mark = "" if rh["pass"] else " <-- FAIL"
    print(f"  {label:33s} {ps:12s} {hs:20s}{mark}")

print("\nDone.")
