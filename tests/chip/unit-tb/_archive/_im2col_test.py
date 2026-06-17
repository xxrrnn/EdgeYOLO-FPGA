import sys; sys.path.insert(0,'.')
from xdma_win import ChipRunnerWin
from gen_data import generate_case

runner = ChipRunnerWin()
for case in ['im2col_3x3_s2_c32', 'im2col_3x3_s1_c128', 'im2col_1x1_c512']:
    r = runner.run_case(generate_case('im2col', case), staging='hbm')
    status = 'PASS' if all(x['pass'] for x in r) else 'FAIL'
    print(f'{case}: {status}')
