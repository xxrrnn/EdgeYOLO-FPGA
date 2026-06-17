"""Run dcim_tiny hbm staging 5 times to characterize the failure rate."""
from pathlib import Path
from xdma_win import ChipRunnerWin

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")

RUNS = 5
runner = ChipRunnerWin(verbose=False)

for trial in range(RUNS):
    results = runner.run_case(run_dir, timeout_s=60.0, staging="hbm")
    fails = []
    for r in results:
        if not r["pass"]:
            for m in r.get("mismatches", []):
                fails.append((m["word"], m["diffs"]))

    status = "PASS" if not fails else f"FAIL ({len(fails)} words)"
    print(f"Trial {trial+1}: {status}")
    for wi, diffs in fails:
        diff_str = " ".join(f"[{b}]:{e:02x}->{g:02x}" for b, e, g in diffs)
        print(f"  word {wi:3d}: {diff_str}")
