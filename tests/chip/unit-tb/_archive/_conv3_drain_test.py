"""Isolate conv3 hbm drain: preload+exec, then test 1-CDMA vs 8-CDMA drain."""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, hex_to_bin, inst_words_to_bin,
    HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE, INST_BASE,
    DCIM_NUM_TILES,
)
from hbm_flow import cdma_copy, _header, OP_WAIT_CDMA, OP_END

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_conv3_s2_c32_to64_qint8")

runner = ChipRunnerWin(verbose=False)

# ------- Step 1: preload + exec (core only, no drain) -------
runner.upload_preload(run_dir)
n_words = runner.upload_inst_raw(run_dir)
runner.start_decoder(n_words)
runner.poll_done(60.0)
print("[DONE] preload+exec completed")

# ------- Step 2: read all 8 tile_obufs directly -------
# conv3: wpt=4, each tile output = 4 words = 64 bytes per pixel
# n_words=256, stride=DCIM_NUM_TILES*wpt=8*4=32, n_pixels=256/32=8 → 8 pixels × 4 words = 32 words per tile
WPT = 4
N_PIXELS = 8
N_TILE_WORDS = N_PIXELS * WPT  # 32 words per tile = 512 bytes
obuf_direct = {}
for t in range(8):
    obuf_direct[t] = runner.x.read(TILE_OBUF_BASE + t * TILE_OBUF_SIZE, N_TILE_WORDS * 16)

print(f"Direct tile_obuf reads done (each tile: {N_TILE_WORDS} words = {N_TILE_WORDS*16} bytes)")

# ------- Step 3: test SINGLE tile drain (tile 0 only) -------
runner.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * N_TILE_WORDS * 16)
insts = cdma_copy(TILE_OBUF_BASE, HBM_BASE + HBM_OFF_OUTPUT, N_TILE_WORDS * 16)
insts += [_header(OP_END, 0, 0)]
runner.x.write(INST_BASE, inst_words_to_bin(insts))
runner.start_decoder(len(insts))
runner.poll_done(30.0)

hbm_t0 = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, N_TILE_WORDS * 16)
single_ok = hbm_t0 == obuf_direct[0]
print(f"Single CDMA (tile 0 only): {'OK' if single_ok else 'FAIL'}")
if not single_ok:
    for i in range(N_TILE_WORDS):
        e = obuf_direct[0][i*16:(i+1)*16]
        g = hbm_t0[i*16:(i+1)*16]
        if e != g:
            print(f"  word {i}: exp={e.hex()} got={g.hex()}")

# ------- Step 4: test ALL 8 tiles drain (back-to-back CDMAs) -------
total_drain_bytes = 8 * N_TILE_WORDS * 16
runner.x.write(HBM_BASE + HBM_OFF_OUTPUT, b"\x00" * total_drain_bytes)

insts = []
for t in range(8):
    src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
    dst = HBM_BASE + HBM_OFF_OUTPUT + t * N_TILE_WORDS * 16
    insts += cdma_copy(src, dst, N_TILE_WORDS * 16)
insts += [_header(OP_END, 0, 0)]
runner.x.write(INST_BASE, inst_words_to_bin(insts))
runner.start_decoder(len(insts))
runner.poll_done(30.0)

print("\nAll-8-tile CDMA drain vs direct reads:")
total_fail = 0
for t in range(8):
    hbm_t = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT + t * N_TILE_WORDS * 16, N_TILE_WORDS * 16)
    if hbm_t == obuf_direct[t]:
        print(f"  tile {t}: OK")
    else:
        fails = [(i, obuf_direct[t][i*16:(i+1)*16].hex(), hbm_t[i*16:(i+1)*16].hex())
                 for i in range(N_TILE_WORDS)
                 if obuf_direct[t][i*16:(i+1)*16] != hbm_t[i*16:(i+1)*16]]
        total_fail += len(fails)
        print(f"  tile {t}: FAIL ({len(fails)} words wrong)")
        for wi, e, g in fails[:2]:
            print(f"    word {wi}: exp={e} got={g}")

print(f"\nSummary: single-CDMA={'OK' if single_ok else 'FAIL'}  8-CDMA-total={'FAIL' if total_fail else 'OK'} ({total_fail} words wrong)")
