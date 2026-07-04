"""Verify HBM output region: read before and after decoder run."""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, HBM_BASE, HBM_OFF_OUTPUT, TILE_OBUF_BASE, TILE_OBUF_SIZE,
    hex_to_bin, INST_BASE,
)
from hbm_flow import staging_writes_for_preload, build_hbm_output_drain, patch_inst_for_hbm

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_dcim_tiny_1x1_qint8")
runner = ChipRunnerWin(verbose=True)

# ── Step 1: upload HBM data and instructions
runner.upload_hbm(run_dir)
n_words = runner.upload_inst(run_dir, drain_output=True)

# ── Step 2: read HBM output region BEFORE decoder
print("\n=== HBM output region BEFORE decoder ===")
hbm_before = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, 2048)
nonzero_before = [(i, hbm_before[i*16:(i+1)*16]) for i in range(128)
                  if any(b != 0 for b in hbm_before[i*16:(i+1)*16])]
if nonzero_before:
    for wi, data in nonzero_before:
        print(f"  word {wi:3d} NON-ZERO: {data.hex()}")
else:
    print("  All zeros ✓")

# ── Step 3: run decoder
runner.start_decoder(n_words)
runner.poll_done(timeout_s=60.0)

# ── Step 4: read HBM output region AFTER decoder
print("\n=== HBM output region AFTER decoder ===")
hbm_after = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, 2048)

exp_raw = hex_to_bin(run_dir / "expected.hex")[:2048]
fails = []
for i in range(128):
    exp = exp_raw[i*16:(i+1)*16]
    got = hbm_after[i*16:(i+1)*16]
    if exp != got:
        diffs = [(b, exp[b], got[b]) for b in range(16) if exp[b] != got[b]]
        fails.append((i, exp, got, diffs))

print(f"Failures: {len(fails)}/128")
for wi, exp, got, diffs in fails:
    diff_str = " ".join(f"[{b}]:exp={e:02x}->got={g:02x}" for b,e,g in diffs)
    exp_is_zero = all(x == 0 for x in exp)
    print(f"  word {wi:3d} (exp_zero={exp_is_zero}): {diff_str}")
    print(f"    exp: {exp.hex()}")
    print(f"    got: {got.hex()}")
