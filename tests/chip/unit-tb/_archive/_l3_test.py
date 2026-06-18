"""
L3 渐进测试 - conv_pipeline 和 mini_network 端到端

conv_pipeline: im2col -> DCIM -> DQA -> QA 完整流水线（单层 conv）
mini_network:  多层 conv 链（可含残差 add）完整端到端

先用 preload（直接写 IBUF/OBUF）验证 pipeline 逻辑；
通过后再用 hbm（host 写 HBM，FPGA 通过 CDMA 搬运）验证完整数据路径。
"""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
sys.path.insert(0, os.path.dirname(__file__))

from xdma_win import ChipRunnerWin
from gen_data import generate_case

runner = ChipRunnerWin()

# ─── conv_pipeline cases ──────────────────────────────────────────────────────
CONV_PIPELINE_CASES = [
    'pipe_conv1_c16_to16',          # 1x1 conv, c_in=16, c_out=16 (小规模)
    'pipe_conv3_s2_c32_to64',       # 3x3 conv stride=2, c_in=32, c_out=64
    'pipe_conv1_c512_to64_tilepass',# 1x1 conv, c_in=512, c_out=64 (多 tile)
]

# ─── mini_network cases ───────────────────────────────────────────────────────
MINI_NETWORK_CASES = [
    'mini_2conv_c16',               # 2 层 conv 链, c=16
    'mini_3conv_residual_c32',      # 3 层 conv + 残差 add, c=32
]

results = []

print("=" * 70)
print("L3 测试: conv_pipeline (im2col -> DCIM -> DQA/QA 完整流水线)")
print("=" * 70)

for case_name in CONV_PIPELINE_CASES:
    print(f"\n>>> conv_pipeline / {case_name}")
    run_dir = generate_case('conv_pipeline', case_name)

    for staging in ['preload', 'hbm']:
        res_list = runner.run_case(run_dir, staging=staging, timeout_s=180.0)
        r = res_list[0]
        n = r.get('n_words', '?')
        status = 'PASS' if r['pass'] else f"FAIL {r.get('passed', '?')}/{n}"
        print(f"  [{staging:7s}] {status}")
        results.append((f'conv_pipeline/{case_name}', staging, r['pass']))

print("\n" + "=" * 70)
print("L3 测试: mini_network (多层 conv 链路端到端)")
print("=" * 70)

for case_name in MINI_NETWORK_CASES:
    print(f"\n>>> mini_network / {case_name}")
    run_dir = generate_case('mini_network', case_name)

    for staging in ['preload', 'hbm']:
        res_list = runner.run_case(run_dir, staging=staging, timeout_s=180.0)
        r = res_list[0]
        n = r.get('n_words', '?')
        status = 'PASS' if r['pass'] else f"FAIL {r.get('passed', '?')}/{n}"
        print(f"  [{staging:7s}] {status}")
        results.append((f'mini_network/{case_name}', staging, r['pass']))

# ─── 汇总 ─────────────────────────────────────────────────────────────────────
print("\n" + "=" * 70)
print("L3 汇总")
print("=" * 70)
passes = sum(1 for _, _, p in results if p)
total  = len(results)
for case, stg, p in results:
    icon = "✓" if p else "✗"
    print(f"  {icon} {case} [{stg}]")
print(f"\n总计: {passes}/{total} PASS")
