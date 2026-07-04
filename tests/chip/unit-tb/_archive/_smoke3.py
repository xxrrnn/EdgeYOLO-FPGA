"""
快速冒烟测试：先生成 golden，再分别用 preload 和 hbm 路径跑
用例：dqa 一个，qa 一个，dcim_tiny 一个
"""
import sys, os
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import ChipRunnerWin, XDMAWin
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

CASES = [
    ('dqa',  'dqa_c32_mid'),
    ('qa',   'qa_c32_mid'),
    ('dcim', 'dcim_tiny_1x1'),
]

for kind, name in CASES:
    rd = generate_case(kind, name)
    rp = runner.run_case(rd, staging='preload', timeout_s=60.0)[0]
    rh = runner.run_case(rd, staging='hbm',     timeout_s=60.0)[0]
    ps = "PASS" if rp["pass"] else f"FAIL {rp['passed']}/{rp['total_words']}"
    hs = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
    print(f"{name:<24} preload={ps:<16} hbm={hs}")
