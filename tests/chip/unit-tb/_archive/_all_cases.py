"""Run im2col and larger dcim tests with preload and hbm staging."""
from pathlib import Path
from xdma_win import ChipRunnerWin

runner = ChipRunnerWin(verbose=False)

CASES = [
    ("im2col_im2col_6x6_s2_c3_qint8",         "preload", 120.0),
    ("im2col_im2col_6x6_s2_c3_qint8",         "hbm",     120.0),
    ("dcim_matmul_conv6_s2_c3_to16_qint8",    "preload",  60.0),
    ("dcim_matmul_conv6_s2_c3_to16_qint8",    "hbm",      60.0),
    ("dcim_matmul_conv3_s2_c32_to64_qint8",   "preload",  60.0),
    ("dcim_matmul_conv3_s2_c32_to64_qint8",   "hbm",      60.0),
]

base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
for case, staging, timeout in CASES:
    run_dir = base / case
    results = runner.run_case(run_dir, staging=staging, timeout_s=timeout)
    for r in results:
        ok = "PASS" if r["pass"] else "FAIL"
        passed = r["passed"]
        total = r["total_words"]
        print(f"[{staging}] {r['name']}: {ok} ({passed}/{total})")
        if r["first_mismatch"]:
            m = r["first_mismatch"]
            print(f"  word {m['word']}: exp={m['expected']} got={m['got']}")
