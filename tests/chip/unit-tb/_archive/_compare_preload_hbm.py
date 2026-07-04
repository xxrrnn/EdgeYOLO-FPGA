"""Compare key intermediate data between preload and hbm runs for mini_2conv_c16."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, VPU_BUF_BASE
from gen_data import generate_case

runner = ChipRunnerWin()
run_dir = generate_case('mini_network', 'mini_2conv_c16')

# Run preload and capture VPU_BUF state
print("=== PRELOAD RUN ===")
res = runner.run_case(run_dir, staging='preload', timeout_s=60.0)
r = res[0]
print(f"preload: {'PASS' if r['pass'] else 'FAIL'}")

preload_slot0 = runner.x.read(VPU_BUF_BASE + 0x0, 32)       # src0.hex input
preload_slot3 = runner.x.read(VPU_BUF_BASE + 0x300000, 32)   # IM2COL output / DQA dst
preload_slot2 = runner.x.read(VPU_BUF_BASE + 0x200000, 32)   # final output
preload_slot1 = runner.x.read(VPU_BUF_BASE + 0x100000, 32)   # QA intermediate

print(f"VPU_BUF+0x0       (src0 input):     {preload_slot0.hex()[:32]}")
print(f"VPU_BUF+0x100000  (QA inter 1):     {preload_slot1.hex()[:32]}")
print(f"VPU_BUF+0x200000  (final output):   {preload_slot2.hex()[:32]}")
print(f"VPU_BUF+0x300000  (im2col/DQA buf): {preload_slot3.hex()[:32]}")

# Pre-zero important slots for hbm run
print("\n=== HBM RUN ===")
runner.x.write(VPU_BUF_BASE + 0x200000, b"\x00" * 32)
runner.x.write(VPU_BUF_BASE + 0x300000, b"\x00" * 32)

res2 = runner.run_case(run_dir, staging='hbm', timeout_s=60.0)
r2 = res2[0]
print(f"hbm: {'PASS' if r2['pass'] else 'FAIL'}")

hbm_slot0 = runner.x.read(VPU_BUF_BASE + 0x0, 32)
hbm_slot3 = runner.x.read(VPU_BUF_BASE + 0x300000, 32)
hbm_slot2 = runner.x.read(VPU_BUF_BASE + 0x200000, 32)
hbm_slot1 = runner.x.read(VPU_BUF_BASE + 0x100000, 32)

print(f"VPU_BUF+0x0       (src0 input):     {hbm_slot0.hex()[:32]}")
print(f"VPU_BUF+0x100000  (QA inter 1):     {hbm_slot1.hex()[:32]}")
print(f"VPU_BUF+0x200000  (final output):   {hbm_slot2.hex()[:32]}")
print(f"VPU_BUF+0x300000  (im2col/DQA buf): {hbm_slot3.hex()[:32]}")

print()
print("DIFF:")
print(f"  src0 same:   {preload_slot0 == hbm_slot0}")
print(f"  QA inter same: {preload_slot1 == hbm_slot1}")
print(f"  output same: {preload_slot2 == hbm_slot2}")
print(f"  im2col buf same: {preload_slot3 == hbm_slot3}")
