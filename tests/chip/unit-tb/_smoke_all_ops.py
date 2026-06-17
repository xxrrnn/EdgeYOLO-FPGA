"""
L1 全算子冒烟测试 — preload + hbm 双路径
覆盖：dqa / qa / dcim_matmul / im2col / mp
每个算子选最小 case，确认两路均 PASS 后再继续大 case
"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import ChipRunnerWin, XDMAWin
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

CASES = [
    # (module,           case_name)
    ('dqa',         'dqa_c16_small'),
    ('dqa',         'dqa_c32_mid'),
    ('dqa',         'dqa_c128_sppf'),
    ('qa',          'qa_c16_signed'),
    ('qa',          'qa_c64_clip'),
    ('qa',          'qa_c128_dense'),
    ('dcim_matmul', 'dcim_tiny_1x1'),
    ('dcim_matmul', 'conv3_s2_c32_to64'),
    ('dcim_matmul', 'conv1_c64_to32'),
    ('im2col',      'im2col_6x6_s2_c3'),
    ('im2col',      'im2col_3x3_s2_c32'),
    ('im2col',      'im2col_1x1_c512'),
    ('mp',          'mp_sppf_128_10'),
    ('mp',          'mp_resnet_stem'),
]

passed = failed = 0
for kind, name in CASES:
    try:
        rd = generate_case(kind, name)
        rp = runner.run_case(rd, staging='preload', timeout_s=60.0)[0]
        rh = runner.run_case(rd, staging='hbm',     timeout_s=60.0)[0]
        ps = "PASS" if rp["pass"] else f"FAIL {rp['passed']}/{rp['total_words']}"
        hs = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
        ok = rp["pass"] and rh["pass"]
        if ok: passed += 1
        else:  failed += 1
        mark = " OK" if ok else " !!"
        print(f"[{mark}] {name:<32} preload={ps:<18} hbm={hs}")
    except Exception as e:
        failed += 1
        print(f"[!!] {name:<32} ERROR: {e}")

print(f"\nTotal: {passed} passed, {failed} failed out of {len(CASES)} cases")
