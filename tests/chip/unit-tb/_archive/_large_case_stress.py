"""
用大 case 触发 stuck，同时记录 decoder status
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

# 大 case：dcim_model_3_conv M=1600 K=288 N=64 acc=5，8 个 tile 每个 drain 6400 words=100KB
# 和 dcim_model_7_conv M=100 K=1152 N=256 acc=18（8 tiles full）
CASES = [
    ('dcim_matmul', 'dcim_model_7_conv'),      # M=100  中等
    ('dcim_matmul', 'dcim_model_3_conv'),      # M=1600 大
    ('dcim_matmul', 'dcim_model_1_conv'),      # M=6400 超大
]

run_dirs = {}
for k, n in CASES:
    run_dirs[(k,n)] = generate_case(k, n)
    print(f"Generated: {n}")

print("\n循环跑大 case，检测 CDMA stuck...\n")

total = 0
for iteration in range(20):
    for kind, name in CASES:
        rd = run_dirs[(kind, name)]
        t0 = time.time()
        try:
            rh = runner.run_case(rd, staging='hbm', timeout_s=60.0)[0]
            elapsed = time.time() - t0
            hs = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
        except TimeoutError as e:
            hs = f"TIMEOUT"
            elapsed = time.time() - t0
        total += 1
        ok = cdma_ok()
        print(f"  [iter {iteration+1:2d}] {name:<32} hbm={hs:<18} t={elapsed:.1f}s  cdma={'OK' if ok else 'STUCK'}")
        if not ok:
            print(f"\n!! CDMA stuck after {total} total runs")
            print(f"!! Triggered by: {name} (hbm={hs})")
            sys.exit(0)

print(f"\n{total} 次大 case 运行后 CDMA 仍然正常")
