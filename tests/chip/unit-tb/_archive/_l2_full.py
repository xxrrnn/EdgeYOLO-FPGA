"""
L2 测试：网络真实层尺寸 dcim + 剩余算子 (add, us, qa_int16)
"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import ChipRunnerWin, XDMAWin
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

CASES = [
    # --- 剩余算子 (module, case, quant) ---
    ('add',         'add_residual_16',          'int8'),
    ('add',         'add_residual_32',          'int8'),
    ('add',         'add_pan_64',               'int8'),
    ('us',          'us_128_10_to20',           'int8'),
    ('us',          'us_64_20_to40',            'int8'),
    ('qa',          'qa_int16_c32_signed',      'int16'),
    ('dqa',         'dqa_accum16_c32',          'int16'),
    ('dqa',         'dqa_accum16_c64',          'int16'),
    ('dqa',         'dqa_nrelu_c24_in64',       'int8'),
    # --- L2 dcim 真实网络层（从小到大） ---
    ('dcim_matmul', 'dcim_model_24_m_0',        'int8'),
    ('dcim_matmul', 'dcim_model_24_m_1',        'int8'),
    ('dcim_matmul', 'dcim_model_18_conv',       'int8'),
    ('dcim_matmul', 'dcim_model_17_m_0_cv1_conv', 'int8'),
    ('dcim_matmul', 'dcim_model_7_conv',        'int8'),
    ('dcim_matmul', 'dcim_model_3_conv',        'int8'),
    ('dcim_matmul', 'dcim_model_1_conv',        'int8'),
    ('dcim_matmul', 'dcim_model_0_conv',        'int8'),
]

passed = failed = 0
for kind, name, quant in CASES:
    try:
        rd = generate_case(kind, name, quant=quant)
        rp = runner.run_case(rd, staging='preload', timeout_s=120.0)[0]
        rh = runner.run_case(rd, staging='hbm',     timeout_s=120.0)[0]
        ps = "PASS" if rp["pass"] else f"FAIL {rp['passed']}/{rp['total_words']}"
        hs = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
        ok = rp["pass"] and rh["pass"]
        if ok: passed += 1
        else:  failed += 1
        mark = " OK" if ok else " !!"
        print(f"[{mark}] {name:<40} preload={ps:<18} hbm={hs}")
    except Exception as e:
        failed += 1
        print(f"[!!] {name:<40} ERROR: {e}")
print(f"\nTotal: {passed} passed, {failed} failed out of {len(CASES)} cases")
