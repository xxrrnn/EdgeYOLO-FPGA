"""Quick one-shot comparison: run dcim_tiny with preload staging."""
from pathlib import Path
from xdma_win import ChipRunnerWin

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")
runner = ChipRunnerWin(verbose=True)
results = runner.run_case(run_dir, timeout_s=60.0, staging="preload")
for r in results:
    ok = "PASS" if r["pass"] else "FAIL"
    print(f"  {r['name']:40s} {ok} ({r['passed']}/{r['total_words']} words)")
    if r["first_mismatch"]:
        m = r["first_mismatch"]
        print(f"    word {m['word']}: exp={m['expected']} got={m['got']}")
