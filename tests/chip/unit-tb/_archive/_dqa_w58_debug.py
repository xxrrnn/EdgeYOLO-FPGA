"""Debug dqa word 58 failure: check VPU_BUF src0 content at word 58 after failing run."""
import struct
from pathlib import Path
from xdma_win import ChipRunnerWin, hex_to_bin, HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE

run_base = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs")
dcim_dir = run_base / "dcim_matmul_dcim_tiny_1x1_qint8"
qa_dir   = run_base / "qa_qa_c16_signed_qint8"
dqa_dir  = run_base / "dqa_dqa_c16_small_qint8"

runner = ChipRunnerWin(verbose=False)

# Load expected src0 for dqa at word 58
dqa_src0 = hex_to_bin(dqa_dir / "src0.hex")
exp_w58 = dqa_src0[928:944]
exp_ints = struct.unpack_from("<4i", exp_w58)
print(f"Expected src0 word 58 (INT32 x4): {exp_ints}")

# Load WB scale at 0x2000
dqa_wb = hex_to_bin(dqa_dir / "wb_init.hex")
wb_at_2000 = dqa_wb[0x2000:0x2010]
wb_floats = struct.unpack_from("<4f", wb_at_2000)
print(f"Expected WB[0x2000] (scale, FP32 x4): {wb_floats}")

for trial in range(10):
    runner.run_case(dcim_dir, staging="hbm")
    runner.run_case(qa_dir, staging="hbm")
    r = runner.run_case(dqa_dir, staging="hbm")[0]

    # Read VPU_BUF word 58 area (src0 region) AFTER dqa run
    vpu_w58 = runner.x.read(VPU_BUF_BASE + 928, 16)
    got_ints = struct.unpack_from("<4i", vpu_w58)
    # Read VPU_BUF[0x400] output word 58
    vpu_out_w58 = runner.x.read(VPU_BUF_BASE + 0x400 + 928, 16)
    got_fp32 = struct.unpack_from("<4f", vpu_out_w58)

    ok = "PASS" if r["pass"] else "FAIL"
    src_ok = "src_ok" if vpu_w58 == exp_w58 else "src_WRONG"
    print(f"Trial {trial+1:2d}: {ok}  {src_ok}  src={got_ints}  out_fp32={got_fp32}")
