"""Check which tile's drain CDMA is corrupting HBM for conv3."""
from pathlib import Path
from xdma_win import (
    ChipRunnerWin, hex_to_bin,
    HBM_BASE, HBM_OFF_OUTPUT,
    TILE_OBUF_BASE, TILE_OBUF_SIZE,
    DCIM_NUM_TILES,
)
from hbm_flow import (
    hbm_drain_remap, DCIM_INT8_OUT_CH_PER_TILE, _matmul_n_from_manifest,
)

run_dir = Path(r"E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\tests\chip\unit-tb\runs\dcim_matmul_conv3_s2_c32_to64_qint8")
runner = ChipRunnerWin(verbose=False)

WPT = 4
matmul_n = _matmul_n_from_manifest(run_dir)
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
N_PIXELS = 8
N_TILE_WORDS = N_PIXELS * WPT  # 32 words
stride = DCIM_NUM_TILES * WPT  # 32

exp_raw = hex_to_bin(run_dir / "expected.hex")[:256*16]

# Run hbm test 5 times, analyze which tile's words fail
from collections import defaultdict
tile_fail_counts = defaultdict(int)
tile_fail_word_counts = defaultdict(lambda: defaultdict(int))

for trial in range(5):
    r = runner.run_case(run_dir, staging="hbm")[0]
    flat_bytes_off = active_tiles * N_TILE_WORDS * 16
    # Get raw HBM flat
    flat = runner.x.read(HBM_BASE + HBM_OFF_OUTPUT, flat_bytes_off)
    remapped = hbm_drain_remap(run_dir, flat)
    for i in range(256):
        e = exp_raw[i*16:(i+1)*16]
        g = remapped[i*16:(i+1)*16]
        if e != g:
            # Determine tile
            word_addr = i  # base_word = 0
            tile = (word_addr % stride) // WPT
            px = word_addr // stride
            intra = word_addr % WPT
            tile_word = px * WPT + intra
            tile_fail_counts[tile] += 1
            tile_fail_word_counts[tile][tile_word] += 1

print(f"Failure analysis over 5 runs (per tile):")
for t in sorted(tile_fail_counts):
    print(f"  tile {t}: {tile_fail_counts[t]} word-errors total")
    for tw in sorted(tile_fail_word_counts[t]):
        print(f"    tile_word {tw}: {tile_fail_word_counts[t][tw]} times")
