"""Debug mini_2conv_c16 hbm path:
1. Pre-zero VPU_BUF result area
2. Run hbm
3. Check VPU_BUF result area
4. Check HBM output
"""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE
from gen_data import generate_case

runner = ChipRunnerWin()
run_dir = generate_case('mini_network', 'mini_2conv_c16')

# Step 1: zero the VPU_BUF result area before running
vpu_out_addr = VPU_BUF_BASE + 0x200000
print(f"Pre-zeroing VPU_BUF result area @ 0x{vpu_out_addr:011x} (256 bytes)...")
runner.x.write(vpu_out_addr, b"\x00" * 256)
before = runner.x.read(vpu_out_addr, 32)
print(f"  Pre-run VPU_BUF+0x200000: {before.hex()}")

# Also zero HBM output
runner.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * 256)

# Step 2: Run hbm
print("\nRunning hbm...")
res = runner.run_case(run_dir, staging='hbm', timeout_s=120.0)
r = res[0]
result_str = 'PASS' if r['pass'] else 'FAIL'
print(f"mini_2conv_c16 hbm: {result_str} {r.get('passed', '?')}/{r.get('n_words', '?')}")

# Step 3: Check VPU_BUF result area after run
after = runner.x.read(vpu_out_addr, 256)
nz = sum(1 for b in after if b != 0)
print(f"\nAfter run - VPU_BUF+0x200000 ({nz}/256 non-zero): {after[:64].hex()}")

# Step 4: Check HBM output
hbm_out = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, 256)
nz2 = sum(1 for b in hbm_out if b != 0)
print(f"After run - HBM+0x{HBM_OFF_OUTPUT:x} ({nz2}/256 non-zero): {hbm_out[:64].hex()}")

if r['pass']:
    print("\nPASS: correct result!")
else:
    mm = r.get('mismatches', [])
    print(f"\nFIRST 3 MISMATCHES:")
    for m in mm[:3]:
        print(f"  word={m['word']}  exp={m['expected'][:32]}  got={m['got'][:32]}")
