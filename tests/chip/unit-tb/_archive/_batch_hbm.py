"""Batch hbm test: dcim + qa + dqa."""
from pathlib import Path
from xdma_win import ChipRunnerWin

runner = ChipRunnerWin(verbose=False)
CASES = [
    "dcim_matmul_dcim_tiny_1x1_qint8",
    "qa_qa_c16_signed_qint8",
    "dqa_dqa_c16_small_qint8",
]

for case in CASES:
    run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs") / case
    results = runner.run_case(run_dir, staging="hbm")
    for r in results:
        ok = "PASS" if r["pass"] else "FAIL"
        passed = r["passed"]
        total = r["total_words"]
        name = r["name"]
        print(f"{name}: {ok} ({passed}/{total})")
        if r["first_mismatch"]:
            m = r["first_mismatch"]
            print(f"  first mismatch word {m['word']}: exp={m['expected']} got={m['got']}")
