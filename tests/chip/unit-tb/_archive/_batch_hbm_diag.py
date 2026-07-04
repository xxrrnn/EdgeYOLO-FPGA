"""Batch hbm with mid-test diagnostics: verify VPU_BUF after each case."""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, hex_to_bin,
    HBM_BASE, HBM_OFF_OUTPUT, HBM_OFF_INPUT0,
    VPU_BUF_BASE, WB_BASE,
)
from hbm_flow import HBM_OFF_WB

run_base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
CASES = [
    "dcim_matmul_dcim_tiny_1x1_qint8",
    "qa_qa_c16_signed_qint8",
    "dqa_dqa_c16_small_qint8",
]

runner = ChipRunnerWin(verbose=False)

for case in CASES:
    run_dir = run_base / case

    # Before run: snapshot VPU_BUF[0x400] and HBM[0]
    vpu_before = runner.x.read(VPU_BUF_BASE + 0x400, 16)
    hbm0_before = runner.x.read(HBM_BASE, 16)
    print(f"\n--- {case} ---")
    print(f"  VPU_BUF[0x400] before: {vpu_before.hex()}")
    print(f"  HBM[0] before:         {hbm0_before.hex()}")

    # Run case
    results = runner.run_case(run_dir, staging="hbm")

    # After run: snapshot
    vpu_after = runner.x.read(VPU_BUF_BASE + 0x400, 16)
    vpu_input = runner.x.read(VPU_BUF_BASE, 16)
    hbm_out = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, 16)

    for r in results:
        ok = "PASS" if r["pass"] else "FAIL"
        passed = r["passed"]
        total = r["total_words"]
        print(f"  result: {ok} ({passed}/{total})")

    print(f"  VPU_BUF[0:16]  (input):  {vpu_input.hex()}")
    print(f"  VPU_BUF[0x400] (output): {vpu_after.hex()}")
    print(f"  HBM out after:           {hbm_out.hex()}")
