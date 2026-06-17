"""Run dqa standalone 3 times with hbm staging."""
from pathlib import Path
from xdma_win import ChipRunnerWin

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dqa_dqa_c16_small_qint8")
runner = ChipRunnerWin(verbose=False)

for trial in range(3):
    r = runner.run_case(run_dir, staging="hbm")[0]
    passed = r["passed"]
    total = r["total_words"]
    ok = "PASS" if r["pass"] else f"FAIL ({passed}/{total})"
    print(f"Trial {trial+1}: {ok}")
    if r["first_mismatch"]:
        m = r["first_mismatch"]
        print(f"  word {m['word']}: exp={m['expected']} got={m['got']}")
