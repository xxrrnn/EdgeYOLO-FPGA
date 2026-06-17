"""验证 add 算子 hbm 路径修复 + int16 case"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import ChipRunnerWin, XDMAWin
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

CASES = [
    ('add',  'add_residual_16',     'int8'),
    ('add',  'add_residual_32',     'int8'),
    ('add',  'add_pan_64',          'int8'),
    ('qa',   'qa_int16_c32_signed', 'int16'),
    ('dqa',  'dqa_accum16_c32',     'int16'),
    ('dqa',  'dqa_accum16_c64',     'int16'),
]

passed = failed = 0
for kind, name, quant in CASES:
    try:
        rd = generate_case(kind, name, quant=quant)
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
