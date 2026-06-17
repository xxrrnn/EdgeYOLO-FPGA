"""
循环跑同一 hbm case，统计多少次后 CDMA stuck
"""
import sys, time
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import (
    XDMAWin, ChipRunnerWin,
    INST_BASE, REGS_BASE, REG_DECODER_STATUS, REG_INST_COUNT, REG_DECODER_CTRL,
    HBM_BASE, HBM_OFF_OUTPUT,
    inst_words_to_bin,
)
from hbm_flow import cdma_copy
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

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

CASES = [
    ('dqa', 'dqa_c16_small'),
    ('dqa', 'dqa_c32_mid'),
    ('dqa', 'dqa_c128_sppf'),
]

run_dirs = [generate_case(k, n) for k, n in CASES]
print(f"循环跑 {len(CASES)} 个 case，每轮检查 CDMA 健康...\n")

for iteration in range(50):
    for i, (rd, (kind, name)) in enumerate(zip(run_dirs, CASES)):
        rh = runner.run_case(rd, staging='hbm', timeout_s=30.0)[0]
        hs = "PASS" if rh["pass"] else f"FAIL"
        if not cdma_ok():
            print(f"[iter {iteration+1}, case {i+1}={name}] hbm={hs} -> CDMA STUCK after {iteration*len(CASES)+i+1} total runs")
            sys.exit(0)
    print(f"  iter {iteration+1:2d}: all OK")

print("\n50 轮 150 次运行后 CDMA 仍然正常")
