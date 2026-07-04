"""Debug mini_3conv_residual_c32 preload failure: check what's actually at SLOT_C after run."""
import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, VPU_BUF_BASE
from gen_data import generate_case

runner = ChipRunnerWin()

run_dir = generate_case('mini_network', 'mini_3conv_residual_c32')

# preload run
res = runner.run_case(run_dir, staging='preload', timeout_s=120.0)
r = res[0]
print(f"\nmini_3conv_residual_c32 preload: {'PASS' if r['pass'] else 'FAIL'} {r.get('passed','?')}/{r.get('n_words','?')}")

if not r['pass']:
    mm = r.get('mismatches', [])
    print(f"First 3 mismatches:")
    for m in mm[:3]:
        print(f"  word={m['word']}  exp={m['expected'][:32]}  got={m['got'][:32]}")

    # Also read intermediate slots to see where data is
    print("\nReading intermediate slots after execution:")
    for name, off, nbytes in [
        ('SLOT_A(input)', 0x000000, 256),
        ('SLOT_B(inter)', 0x100000, 256),
        ('SLOT_C(output)', 0x200000, 256),
        ('SLOT_D(scratch)', 0x300000, 256),
        ('SLOT_E(dqa0)', 0x400000, 256),
        ('SLOT_F(dqa1)', 0x500000, 256),
    ]:
        data = runner.x.read(VPU_BUF_BASE + off, nbytes)
        nonzero = sum(1 for b in data if b != 0)
        print(f"  {name}: {nonzero}/{nbytes} non-zero bytes, first 32B: {data[:32].hex()}")
