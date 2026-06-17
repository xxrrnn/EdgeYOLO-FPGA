import sys; sys.path.insert(0,'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, XDMAWin
from gen_data import generate_case

xdma = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

for mod, var in [
    ('dcim_matmul', 'dcim_tiny_1x1'),
    ('dcim_matmul', 'conv3_s2_c32_to64'),
    ('dcim_matmul', 'conv3_c128_to128'),
]:
    rd = generate_case(mod, var)
    rh = runner.run_case(rd, staging='hbm', timeout_s=60.0)[0]
    rp = runner.run_case(rd, staging='preload', timeout_s=60.0)[0]
    ph = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
    pp = "PASS" if rp["pass"] else f"FAIL {rp['passed']}/{rp['total_words']}"
    print(f"{var:30s}  preload={pp}  hbm={ph}")
