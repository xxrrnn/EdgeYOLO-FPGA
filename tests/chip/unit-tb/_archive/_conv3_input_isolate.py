"""Critical isolation: INPUT CDMAs only (no exec, no drain) → does drain then fail?"""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, hex_to_bin, inst_words_to_bin,
    HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE, INST_BASE,
)
from hbm_flow import (
    build_hbm_input_cdma, hbm_drain_remap, cdma_copy, _header, OP_END,
    DCIM_INT8_OUT_CH_PER_TILE, _matmul_n_from_manifest, inst_words_to_bin as ibins,
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

# ---- Baseline: preload+exec → drain (should PASS) ----
print("=== Baseline: preload+exec → drain ===")
runner.upload_preload(run_dir)
n_inst = runner.upload_inst_raw(run_dir)
runner.start_decoder(n_inst)
runner.poll_done(60.0)
run_drain_check("after preload+exec")

# ---- Test: INPUT CDMAs only (no exec, no drain), then drain ----
print("\n=== Test: INPUT CDMAs only (no exec, no drain) → drain ===")
runner.upload_hbm(run_dir)  # stage HBM data

# Build instruction: ONLY input CDMAs + END (no DCIM exec)
input_only = build_hbm_input_cdma(run_dir) + [_header(OP_END, 0, 0)]
runner.x.write(INST_BASE, inst_words_to_bin(input_only))
runner.start_decoder(len(input_only))
runner.poll_done(30.0)
print("  Input-only CDMAs done")

run_drain_check("after INPUT-CDMAs-ONLY")

# ---- After preload again → drain ----
print("\n=== Recovery: preload+exec → drain again ===")
runner.upload_preload(run_dir)
n_inst = runner.upload_inst_raw(run_dir)
runner.start_decoder(n_inst)
runner.poll_done(60.0)
run_drain_check("after preload+exec (recovery)")
