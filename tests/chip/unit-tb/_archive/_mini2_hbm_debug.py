"""Debug mini_2conv_c16 hbm=FAIL 0/? - check what comes back from HBM."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, HBM_BASE, HBM_OFF_OUTPUT, VPU_BUF_BASE
from gen_data import generate_case

runner = ChipRunnerWin()
run_dir = generate_case('mini_network', 'mini_2conv_c16')

# HBM run
res = runner.run_case(run_dir, staging='hbm', timeout_s=120.0)
r = res[0]
print(f"\nmini_2conv_c16 hbm: {'PASS' if r['pass'] else 'FAIL'} {r.get('passed','?')}/{r.get('n_words','?')}")

if not r['pass']:
    mm = r.get('mismatches', [])
    print(f"First 3 mismatches:")
    for m in mm[:3]:
        print(f"  word={m['word']}  exp={m['expected'][:32]}  got={m['got'][:32]}")

    # Read HBM output directly
    print(f"\nRaw HBM output at HBM+0x{HBM_OFF_OUTPUT:x} (256 bytes):")
    data = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, 256)
    nonzero = sum(1 for b in data if b != 0)
    print(f"  {nonzero}/256 non-zero, first 64B: {data[:64].hex()}")

    # Check VPU_BUF output slot (should also have result since drain CDMA copies it)
    print(f"\nVPU_BUF SLOT_C (0x102200000) = result area (256 bytes):")
    data2 = runner.x.read(VPU_BUF_BASE + 0x200000, 256)
    nonzero2 = sum(1 for b in data2 if b != 0)
    print(f"  {nonzero2}/256 non-zero, first 64B: {data2[:64].hex()}")
