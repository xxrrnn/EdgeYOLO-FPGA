"""Check conv3 hbm: after hbm run, is tile_obuf correct? Pinpoint where corruption happens."""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, hex_to_bin, inst_words_to_bin,
    HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE, INST_BASE,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
)
from hbm_flow import (
    patch_inst_for_hbm, build_hbm_output_drain, hbm_drain_remap, cdma_copy, _header, OP_END,
    DCIM_INT8_OUT_CH_PER_TILE, _matmul_n_from_manifest,
    HBM_OFF_WB,
)

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_conv3_s2_c32_to64_qint8")
runner = ChipRunnerWin(verbose=False)

WPT = 4
matmul_n = _matmul_n_from_manifest(run_dir)
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
N_PIXELS = 8
N_TILE_WORDS = N_PIXELS * WPT  # 32 words per tile

# --- Step 1: preload+exec to get ground truth tile_obuf ---
runner.upload_preload(run_dir)
n_inst = runner.upload_inst_raw(run_dir)
runner.start_decoder(n_inst)
runner.poll_done(60.0)
obuf_gt = {}
for t in range(active_tiles):
    obuf_gt[t] = runner.x.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, N_TILE_WORDS * 16)
print("[GT] preload+exec done, tile_obuf captured")

# --- Step 2: run hbm path (upload_hbm + patched inst with drain) ---
runner.upload_hbm(run_dir)
data = patch_inst_for_hbm(run_dir)
runner.x.write(INST_BASE, data)
runner.start_decoder(len(data) // 4)
runner.poll_done(60.0)
print("[HBM] hbm run done")

# Read tile_obuf AFTER hbm run
obuf_hbm = {}
for t in range(active_tiles):
    obuf_hbm[t] = runner.x.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, N_TILE_WORDS * 16)

# Compare tile_obuf: gt vs hbm
print("\nTile_obuf comparison (preload-gt vs after-hbm-run):")
obuf_all_ok = True
for t in range(active_tiles):
    if obuf_hbm[t] == obuf_gt[t]:
        print(f"  tile {t}: OK")
    else:
        obuf_all_ok = False
        for i in range(N_TILE_WORDS):
            e = obuf_gt[t][i*16:(i+1)*16]
            g = obuf_hbm[t][i*16:(i+1)*16]
            if e != g:
                print(f"  tile {t} word {i}: exp={e.hex()} got={g.hex()}")
                break
        print(f"  tile {t}: FAIL")

print(f"\ntile_obuf after hbm run: {'OK (same as preload)' if obuf_all_ok else 'DIFFERENT from preload'}")

# Read HBM output and remap
flat_bytes = active_tiles * N_TILE_WORDS * 16
hbm_flat = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, flat_bytes)
remapped = hbm_drain_remap(run_dir, hbm_flat)
exp_raw = hex_to_bin(run_dir / "expected.hex")[:256*16]

fail_hbm = 0
for i in range(256):
    e = exp_raw[i*16:(i+1)*16]
    g = remapped[i*16:(i+1)*16]
    if e != g:
        fail_hbm += 1
        if fail_hbm <= 3:
            print(f"\nHBM remap word {i}: exp={e.hex()} got={g.hex()}")

print(f"\nHBM drain result: {256-fail_hbm}/256 match")
print(f"\nConclusion: tile_obuf {'CORRECT' if obuf_all_ok else 'WRONG'} after hbm run → corruption is in {'CDMA DRAIN (HBM write path)' if obuf_all_ok else 'DCIM COMPUTE (CDMA input staging)'}")
