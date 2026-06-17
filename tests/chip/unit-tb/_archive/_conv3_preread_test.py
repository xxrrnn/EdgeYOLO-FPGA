"""Test: does XDMA pre-read of tile_obuf fix subsequent CDMA drain?"""
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
N_TILE_WORDS = 8 * WPT
exp_raw = hex_to_bin(run_dir / "expected.hex")[:256*16]

def run_drain_check(label: str) -> bool:
    total = active_tiles * N_TILE_WORDS * 16
    runner.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * total)
    insts = []
    for t in range(active_tiles):
        insts += cdma_copy(TILE_OBUF_BASE + t * TILE_OBUF_SIZE,
                           HBM_BASE + HBM_OFF_OUTPUT + t * N_TILE_WORDS * 16,
                           N_TILE_WORDS * 16)
    insts += [_header(OP_END, 0, 0)]
    runner.x.write(INST_BASE, inst_words_to_bin(insts))
    runner.start_decoder(len(insts))
    runner.poll_done(30.0)
    flat = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, total)
    remapped = hbm_drain_remap(run_dir, flat)
    fails = sum(1 for i in range(256) if exp_raw[i*16:(i+1)*16] != remapped[i*16:(i+1)*16])
    ok = fails == 0
    print(f"  [{label}] drain: {'PASS' if ok else f'FAIL ({fails} wrong)'}")
    return ok

for trial in range(3):
    print(f"\n=== Trial {trial+1} ===")
    runner.upload_preload(run_dir)
    n_inst = runner.upload_inst_raw(run_dir)
    runner.start_decoder(n_inst)
    runner.poll_done(60.0)
    print("  exec done")

    # Method A: NO XDMA pre-read
    run_drain_check("NO pre-read")

    # Re-exec
    runner.upload_preload(run_dir)
    n_inst = runner.upload_inst_raw(run_dir)
    runner.start_decoder(n_inst)
    runner.poll_done(60.0)

    # Method B: WITH XDMA pre-read of tile_obuf
    for t in range(active_tiles):
        _ = runner.x.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, N_TILE_WORDS * 16)
    print("  XDMA pre-read done")
    run_drain_check("WITH XDMA pre-read")
