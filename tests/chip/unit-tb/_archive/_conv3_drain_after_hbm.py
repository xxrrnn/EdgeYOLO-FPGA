"""Conv3: after hbm run fails, immediately run drain-only in new decoder run - does it pass?"""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, hex_to_bin, inst_words_to_bin,
    HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE, INST_BASE,
)
from hbm_flow import (
    hbm_drain_remap, cdma_copy, _header, OP_END,
    DCIM_INT8_OUT_CH_PER_TILE, _matmul_n_from_manifest,
)

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_conv3_s2_c32_to64_qint8")
runner = ChipRunnerWin(verbose=False)

WPT = 4
matmul_n = _matmul_n_from_manifest(run_dir)
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
N_TILE_WORDS = 8 * WPT  # n_pixels=8, wpt=4
exp_raw = hex_to_bin(run_dir / "expected.hex")[:256*16]

def run_drain_and_check(label: str):
    total_drain = active_tiles * N_TILE_WORDS * 16
    runner.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * total_drain)
    insts = []
    for t in range(active_tiles):
        src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
        dst = HBM_BASE + HBM_OFF_OUTPUT + t * N_TILE_WORDS * 16
        insts += cdma_copy(src, dst, N_TILE_WORDS * 16)
    insts += [_header(OP_END, 0, 0)]
    runner.x.write(INST_BASE, inst_words_to_bin(insts))
    runner.start_decoder(len(insts))
    runner.poll_done(30.0)

    flat = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, total_drain)
    remapped = hbm_drain_remap(run_dir, flat)
    fails = [(i, exp_raw[i*16:(i+1)*16].hex(), remapped[i*16:(i+1)*16].hex())
             for i in range(256) if exp_raw[i*16:(i+1)*16] != remapped[i*16:(i+1)*16]]
    ok = "PASS" if not fails else f"FAIL ({len(fails)} words)"
    print(f"  [{label}] drain-only run: {ok}")
    for wi, e, g in fails[:2]:
        print(f"    word {wi}: exp={e} got={g}")

for trial in range(3):
    print(f"\n=== Trial {trial+1} ===")
    # Step 1: full hbm run (input CDMAs + exec + drain)
    r = runner.run_case(run_dir, staging="hbm")[0]
    print(f"  [hbm full run] {'PASS' if r['pass'] else 'FAIL'} ({r['passed']}/256)")

    # Step 2: immediately after, re-run drain only (SEPARATE decoder run)
    run_drain_and_check("drain-only AFTER hbm")
