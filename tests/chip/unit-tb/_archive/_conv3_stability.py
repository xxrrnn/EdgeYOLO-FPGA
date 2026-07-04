"""Run conv3 hbm 10 times to check stability."""
from pathlib import Path
from xdma_win import ChipRunnerWin

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_conv3_s2_c32_to64_qint8")
runner = ChipRunnerWin(verbose=False)

for i in range(10):
    r = runner.run_case(run_dir, staging="hbm")[0]
    ok = "PASS" if r["pass"] else "FAIL"
    info = ""
    if r["first_mismatch"]:
        m = r["first_mismatch"]
        exp_b = bytes.fromhex(m["expected"])
        got_b = bytes.fromhex(m["got"])
        diffs = [(j, hex(exp_b[j]), hex(got_b[j])) for j in range(16) if exp_b[j] != got_b[j]]
        word = m["word"]
        info = f"  word={word} diff_bytes={diffs}"
    print(f"Run {i+1:2d}: {ok}{info}")
