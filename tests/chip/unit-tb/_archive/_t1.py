import sys; sys.path.insert(0,'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, XDMAWin
from gen_data import generate_case

xdma = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

rd = generate_case('dqa', 'dqa_c32_mid')
rp = runner.run_case(rd, staging='preload', timeout_s=60.0)[0]
rh = runner.run_case(rd, staging='hbm',     timeout_s=60.0)[0]

ps = "PASS" if rp["pass"] else f"FAIL {rp['passed']}/{rp['total_words']}"
hs = "PASS" if rh["pass"] else f"FAIL {rh['passed']}/{rh['total_words']}"
print(f"dqa_c32_mid  preload={ps}  hbm={hs}")
