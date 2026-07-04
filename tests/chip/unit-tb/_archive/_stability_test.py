import sys
from pathlib import Path
sys.path.insert(0, 'tests/chip/unit-tb')
sys.path.insert(0, 'tools')
from gen_data import generate_case
from xdma_win import ChipRunnerWin

runner = ChipRunnerWin()

run_dir = generate_case('conv_pipeline', 'pipe_conv1_c16_to16')
print("Testing pipe_conv1_c16_to16...")
res = runner.run_case(run_dir, staging='preload', timeout_s=60.0)
r = res[0]
print("  preload:", "PASS" if r['pass'] else "FAIL")
res2 = runner.run_case(run_dir, staging='hbm', timeout_s=60.0)
r2 = res2[0]
print("  hbm:", "PASS" if r2['pass'] else "FAIL")

# Also run mini_2conv with fixed seed to see if preload is stable
run_dir2 = generate_case('mini_network', 'mini_2conv_c16')
print("\nTesting mini_2conv_c16 preload (twice to check stability)...")
res3 = runner.run_case(run_dir2, staging='preload', timeout_s=60.0)
r3 = res3[0]
print("  run1 preload:", "PASS" if r3['pass'] else "FAIL")
res4 = runner.run_case(run_dir2, staging='preload', timeout_s=60.0)
r4 = res4[0]
print("  run2 preload:", "PASS" if r4['pass'] else "FAIL")
if not r3['pass']:
    mm = r3.get('mismatches', [])
    if mm:
        print(f"  run1 word0: exp={mm[0]['expected'][:32]} got={mm[0]['got'][:32]}")
if not r4['pass']:
    mm = r4.get('mismatches', [])
    if mm:
        print(f"  run2 word0: exp={mm[0]['expected'][:32]} got={mm[0]['got'][:32]}")
