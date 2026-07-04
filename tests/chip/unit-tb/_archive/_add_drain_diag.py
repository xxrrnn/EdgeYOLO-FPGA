"""
诊断 add hbm 路径：手动执行一步步看问题在哪
1. 用 preload 方式写 src0/src1 到 VPU_BUF
2. 跑 preload inst，确认 VPU_BUF+0x800 有正确结果
3. 手动执行 drain CDMA，看 HBM 里是否有数据
"""
import sys, time
sys.path.insert(0, 'tests/chip/unit-tb')

from pathlib import Path
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    HBM_BASE, HBM_OFF_INPUT0, HBM_OFF_INPUT1, HBM_OFF_OUTPUT,
    VPU_BUF_BASE,
    inst_words_to_bin, hex_to_bin,
)
from hbm_flow import cdma_copy, OP_END, OP_NOP, _header, _VPU_SETTLE_NOPS

run_dir = Path("tests/chip/unit-tb/runs/add_add_residual_16_qint8")

xdma = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

# Step 1: preload run to get correct result in VPU_BUF+0x800
print("Step1: preload run...")
rd = runner.run_case(run_dir, staging='preload', timeout_s=30.0)
print(f"  preload: {'PASS' if rd[0]['pass'] else 'FAIL'}")

# Step 2: read VPU_BUF+0x800 directly
vpu_out = xdma.read(VPU_BUF_BASE + 0x800, 64)
print(f"  VPU_BUF+0x800 first 16 bytes: {vpu_out[:16].hex()}")

# Step 3: manual drain only -- CDMA VPU_BUF+0x800 -> HBM+OUTPUT
print("Step3: manual drain CDMA...")
drain_insts = cdma_copy(VPU_BUF_BASE + 0x800, HBM_BASE + HBM_OFF_OUTPUT, 1024)
drain_insts += [_header(OP_NOP, 0, 0)] * 4
drain_insts += [0xF0000000]  # OP_END
ib = inst_words_to_bin(drain_insts)
xdma.write(INST_BASE, ib)
xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
time.sleep(0.001)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)

t0 = time.time()
while time.time() - t0 < 5:
    st = xdma.read_u32(REGS_BASE + REG_DECODER_STATUS)
    if st & 2:
        break
    time.sleep(0.01)

# Step 4: read HBM output
hbm_out = xdma.read(HBM_BASE + HBM_OFF_OUTPUT, 64)
print(f"  HBM+OUTPUT first 16 bytes: {hbm_out[:16].hex()}")
print(f"  Match: {vpu_out[:64] == hbm_out}")
