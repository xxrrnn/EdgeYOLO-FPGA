"""Final sanity: qa + dqa hbm path."""
from pathlib import Path
from xdma_win import ChipRunnerWin

runner = ChipRunnerWin(verbose=False)
base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
cases = [
    ("qa_qa_c16_signed_qint8",   "preload"),
    ("qa_qa_c16_signed_qint8",   "hbm"),
    ("dqa_dqa_c16_small_qint8",  "preload"),
    ("dqa_dqa_c16_small_qint8",  "hbm"),
]
for case, staging in cases:
    r = runner.run_case(base / case, staging=staging)[0]
    n_pass = r["passed"]
    n_total = r["total_words"]
    ok = "PASS" if r["pass"] else f"FAIL ({n_pass}/{n_total})"
    info = ""
    if r["first_mismatch"]:
        m = r["first_mismatch"]
        info = f"  word{m['word']}"
    print(f"[{staging:7s}] {case}: {ok}{info}")
