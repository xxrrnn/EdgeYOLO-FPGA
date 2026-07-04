"""Quick sanity check: dcim_tiny and conv3 state after multiple hbm runs."""
from pathlib import Path
from xdma_win import ChipRunnerWin

runner = ChipRunnerWin(verbose=False)
base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
cases = [
    ("dcim_matmul_dcim_tiny_1x1_qint8",      "hbm"),
    ("dcim_matmul_dcim_tiny_1x1_qint8",      "preload"),
    ("dcim_matmul_conv3_s2_c32_to64_qint8",  "preload"),
    ("dcim_matmul_conv3_s2_c32_to64_qint8",  "hbm"),
    ("dcim_matmul_conv6_s2_c3_to16_qint8",   "preload"),
    ("dcim_matmul_conv6_s2_c3_to16_qint8",   "hbm"),
]
for case, staging in cases:
    r = runner.run_case(base / case, staging=staging)[0]
    n_pass = r["passed"]
    n_total = r["total_words"]
    ok = "PASS" if r["pass"] else f"FAIL ({n_pass}/{n_total})"
    info = ""
    if r["first_mismatch"]:
        m = r["first_mismatch"]
        info = f"  first=word{m['word']} exp={m['expected'][:8]}.. got={m['got'][:8]}.."
    print(f"[{staging:7s}] {case}: {ok}{info}")
