"""
精确定位 dqa_c16_small hbm 路径的哪一个 CDMA 操作触发死锁：
- Input CDMA (HBM -> VPU_BUF)
- Drain CDMA (VPU_BUF -> HBM)
"""
import sys, time
sys.path.insert(0, 'tests/chip/unit-tb')

from pathlib import Path
from xdma_win import (
    XDMAWin,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    HBM_BASE, HBM_OFF_OUTPUT, HBM_OFF_INPUT0, VPU_BUF_BASE, WB_BASE,
    inst_words_to_bin, hex_to_bin,
)
from hbm_flow import (
    cdma_copy, _header, OP_NOP, OP_END,
    build_hbm_input_cdma, build_hbm_output_drain,
    staging_writes_for_preload, parse_inst_words,
    patch_inst_for_hbm,
)
from gen_data import generate_case

xdma = XDMAWin(verbose=False)

def cdma_ok():
    pat = bytes([0xAB, 0xCD, 0xEF, 0x12] * 256)
    xdma.write(HBM_BASE + 0x300000, pat)
    xdma.write(HBM_BASE + HBM_OFF_OUTPUT, b'\x00' * 1024)
    ib = inst_words_to_bin(cdma_copy(HBM_BASE + 0x300000, HBM_BASE + HBM_OFF_OUTPUT, 1024) + [0xF0000000])
    xdma.write(INST_BASE, ib); xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1); time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 3:
        if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2: break
        time.sleep(0.005)
    return xdma.read(HBM_BASE + HBM_OFF_OUTPUT, 4) == pat[:4]

def run_and_check(label, insts, timeout=10.0):
    ib = inst_words_to_bin(insts + [0xF0000000])
    xdma.write(INST_BASE, ib); xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1); time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    done = False
    while time.time() - t0 < timeout:
        if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2: done = True; break
        time.sleep(0.005)
    ok = cdma_ok()
    print(f"  {label}: done={done}, cdma_after={'OK' if ok else 'STUCK'}")
    return ok

run_dir = generate_case('dqa', 'dqa_c16_small')

print("=== dqa_c16_small hbm 路径逐步分解 ===\n")

# Step 1: 只跑 HBM input staging CDMAs
print("[Step1] 只跑 HBM staging (input CDMA: HBM->WB + HBM->VPU_BUF)")
# 先写 HBM 数据
for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir):
    data = hex_to_bin(run_dir / fname)
    xdma.write(HBM_BASE + hbm_off, data)
input_insts = build_hbm_input_cdma(run_dir)
if not run_and_check("input CDMA only", input_insts):
    print("  !! 触发点：input CDMA (HBM -> on-chip)")
    sys.exit(0)

# Step 2: 重做 input staging，然后跑 VPU 计算（无 drain）
print("\n[Step2] 跑 VPU 计算（无 drain CDMA）")
# 重新做 HBM staging
for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir):
    data = hex_to_bin(run_dir / fname)
    xdma.write(HBM_BASE + hbm_off, data)
xdma.write(HBM_BASE + HBM_OFF_INPUT0, hex_to_bin(run_dir / "src0.hex") if (run_dir / "src0.hex").exists() else b'')
# 用 preload + 原始 inst（不含 drain）
core_words = parse_inst_words(run_dir / "inst.hex")
# 去掉 OP_END
while core_words and (core_words[-1] >> 28) & 0xF == 0xF: core_words.pop()
full = input_insts + core_words
if not run_and_check("input CDMA + VPU compute (no drain)", full):
    print("  !! 触发点：VPU 计算本身（或 input CDMA + compute 组合）")
    sys.exit(0)

# Step 3: 完整 patch（input + compute + drain）
print("\n[Step3] 完整 hbm patch（input + compute + drain）")
for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir):
    data = hex_to_bin(run_dir / fname)
    xdma.write(HBM_BASE + hbm_off, data)
patched = patch_inst_for_hbm(run_dir)
words = [int.from_bytes(patched[i:i+4], 'little') for i in range(0, len(patched), 4)]
ib = patched
xdma.write(INST_BASE, ib); xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1); time.sleep(0.001)
xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
t0 = time.time(); done = False
while time.time() - t0 < 10:
    if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2: done = True; break
    time.sleep(0.005)
ok = cdma_ok()
print(f"  完整 patch: done={done}, cdma_after={'OK' if ok else 'STUCK'}")
if not ok:
    print("  !! 触发点：drain CDMA (VPU_BUF -> HBM)")
    # 读 VPU_BUF 输出是否有数据
    out = xdma.read(VPU_BUF_BASE + 0x400, 16)
    print(f"  VPU_BUF+0x400 = {out.hex()}")
