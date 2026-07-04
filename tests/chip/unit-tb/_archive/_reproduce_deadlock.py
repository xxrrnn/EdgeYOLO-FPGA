"""
精确复现：VPU 计算完 → CDMA 立即 drain VPU_BUF
这才是 hbm 路径 case 里的真实场景。
检查是否在 VPU_BUF drain 时产生错误。
"""
import sys, time
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import (
    XDMAWin, ChipRunnerWin,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    HBM_BASE, HBM_OFF_OUTPUT, HBM_OFF_INPUT0, VPU_BUF_BASE,
    inst_words_to_bin, hex_to_bin,
)
from hbm_flow import (
    cdma_copy, _header, OP_NOP, OP_END,
    build_hbm_input_cdma, build_hbm_output_drain, patch_inst_for_hbm,
    _VPU_SETTLE_NOPS,
)
from gen_data import generate_case
from pathlib import Path

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

def cdma_health():
    pat = bytes([0xAB, 0xCD, 0xEF, 0x12] * 256)
    xdma.write(HBM_BASE + 0x300000, pat)
    xdma.write(HBM_BASE + HBM_OFF_OUTPUT, b'\x00' * 1024)
    ib = inst_words_to_bin(cdma_copy(HBM_BASE + 0x300000, HBM_BASE + HBM_OFF_OUTPUT, 1024) + [0xF0000000])
    xdma.write(INST_BASE, ib)
    xdma.write_u32(REGS_BASE + REG_INST_COUNT, len(ib) // 4)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 1)
    time.sleep(0.001)
    xdma.write_u32(REGS_BASE + REG_DECODER_CTRL, 0)
    t0 = time.time()
    while time.time() - t0 < 3:
        if xdma.read_u32(REGS_BASE + REG_DECODER_STATUS) & 2:
            break
        time.sleep(0.005)
    got = xdma.read(HBM_BASE + HBM_OFF_OUTPUT, 4)
    return got == pat[:4]  # True = healthy, False = stuck

print("=== 复现：VPU 计算 → CDMA drain VPU_BUF ===\n")

# dqa 是最简单的 VPU+drain case
cases = [
    ('dqa', 'dqa_c16_small'),
    ('dqa', 'dqa_c32_mid'),
    ('dqa', 'dqa_c128_sppf'),
    ('qa',  'qa_c128_dense'),
    ('add', 'add_residual_16'),
    ('add', 'add_pan_64'),
]

for kind, name in cases:
    rd = generate_case(kind, name)
    # 先 preload 跑确认正常
    rp = runner.run_case(rd, staging='preload', timeout_s=30.0)[0]
    # 再 hbm 路径
    rh = runner.run_case(rd, staging='hbm', timeout_s=30.0)[0]
    stuck = cdma_health()
    ps = "PASS" if rp["pass"] else f"FAIL {rp['passed']}/{rp['total_words']}"
    hs = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
    sk = "STUCK" if stuck else "OK"
    print(f"  {name:<24} preload={ps:<10} hbm={hs:<10} cdma_after={sk}")
    if stuck:
        print("  !! CDMA stuck after this case — error confirmed")
        break
