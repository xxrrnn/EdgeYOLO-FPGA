"""Verify conv3 hbm: check if hbm_drain_remap produces correct result."""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, hex_to_bin, inst_words_to_bin,
    HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE, INST_BASE,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    TILE_OBUF_CHK_SENTINEL,
)
from hbm_flow import (
    build_hbm_output_drain, hbm_drain_remap, cdma_copy, _header, OP_END,
    DCIM_INT8_OUT_CH_PER_TILE, _matmul_n_from_manifest,
)

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_conv3_s2_c32_to64_qint8")
runner = ChipRunnerWin(verbose=False)

# Load expected
exp_raw = hex_to_bin(run_dir / "expected.hex")[:256*16]
chk_line = next(l for l in (run_dir/"checks.txt").read_text().splitlines() if l.strip() and not l.startswith("#"))
parts = chk_line.split()
dst_off = int(parts[2], 16)
n_words = int(parts[3])
wpt = int(parts[5]) if len(parts) > 5 else DCIM_INT8_OUT_WORDS_PER_TILE

matmul_n = _matmul_n_from_manifest(run_dir)
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
stride = DCIM_NUM_TILES * wpt
n_pixels = (n_words + stride - 1) // stride
n_tile_words = n_pixels * wpt
flat_bytes = active_tiles * n_tile_words * 16

print(f"conv3: matmul_n={matmul_n}, active_tiles={active_tiles}, wpt={wpt}")
print(f"  n_words={n_words}, stride={stride}, n_pixels={n_pixels}, n_tile_words={n_tile_words}")
print(f"  flat_bytes={flat_bytes}")

# --- Preload + exec to get correct tile_obuf contents ---
runner.upload_preload(run_dir)
n_inst = runner.upload_inst_raw(run_dir)
runner.start_decoder(n_inst)
runner.poll_done(60.0)
print("[DONE] preload+exec")

# Read all tiles directly
obuf_flat = b""
for t in range(active_tiles):
    obuf_flat += runner.x.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, n_tile_words * 16)

print(f"Direct tile_obuf flat ({len(obuf_flat)} bytes)")

# Apply remap to direct reads → should match expected
remapped = hbm_drain_remap(run_dir, obuf_flat)

fail_direct = 0
for i in range(n_words):
    e = exp_raw[i*16:(i+1)*16]
    g = remapped[i*16:(i+1)*16]
    if e != g:
        fail_direct += 1
        if fail_direct <= 3:
            print(f"  Remap(direct) word {i}: exp={e.hex()} got={g.hex()}")

print(f"hbm_drain_remap(direct_obuf) vs expected: {n_words-fail_direct}/{n_words} match  {'OK - remap logic correct' if not fail_direct else 'FAIL - remap bug'}")

# --- Now run actual hbm test ---
results = runner.run_case(run_dir, staging="hbm")
r = results[0]
print(f"\nhbm run_case: {'PASS' if r['pass'] else 'FAIL'} ({r['passed']}/{r['total_words']})")
if r["first_mismatch"]:
    m = r["first_mismatch"]
    print(f"  first mismatch word {m['word']}: exp={m['expected']} got={m['got']}")
