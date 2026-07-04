"""检查 dcim_model_7_conv 的 drain CDMA 地址计算"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from pathlib import Path
from hbm_flow import (
    build_hbm_output_drain, _matmul_n_from_manifest,
    DCIM_INT8_OUT_CH_PER_TILE, DCIM_NUM_TILES,
)
from xdma_win import (
    TILE_OBUF_BASE, TILE_OBUF_SIZE, WB_BASE, VPU_BUF_BASE,
    HBM_BASE, HBM_OFF_OUTPUT,
    DCIM_INT8_OUT_WORDS_PER_TILE,
)
from gen_data import generate_case

run_dir = generate_case('dcim_matmul', 'dcim_model_7_conv')

# 读 manifest
matmul_n = _matmul_n_from_manifest(run_dir)
checks = (run_dir / "checks.txt").read_text().splitlines()
print(f"manifest matmul_n = {matmul_n}")
print(f"checks.txt: {[l for l in checks if l.strip() and not l.startswith('#')]}")

# 计算 active_tiles
active_tiles = (matmul_n + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE
print(f"\nDCIM_INT8_OUT_CH_PER_TILE = {DCIM_INT8_OUT_CH_PER_TILE}")
print(f"DCIM_NUM_TILES            = {DCIM_NUM_TILES}")
print(f"active_tiles              = {active_tiles}  <-- {'!!超过 NUM_TILES!!' if active_tiles > DCIM_NUM_TILES else 'OK'}")

# 打印每个 tile drain 的 src 地址
print(f"\n== drain CDMA 地址 ==")
n_words = int([l for l in checks if l.strip() and not l.startswith('#')][0].split()[3])
wpt = DCIM_INT8_OUT_WORDS_PER_TILE
import math
n_pixels = math.ceil(n_words / (DCIM_NUM_TILES * wpt))
n_tile_words = n_pixels * wpt
print(f"n_words={n_words}, wpt={wpt}, n_pixels={n_pixels}, n_tile_words={n_tile_words}")

for t in range(active_tiles):
    src = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
    dst = HBM_BASE + HBM_OFF_OUTPUT + t * n_tile_words * 16
    region = "tile_obuf OK" if t < DCIM_NUM_TILES else \
             ("WB_BASE!"    if src == WB_BASE else \
             ("VPU_BUF!"   if src == VPU_BUF_BASE else "UNMAPPED!"))
    flag = " <-- ERROR" if t >= DCIM_NUM_TILES else ""
    print(f"  tile {t:2d}: src=0x{src:011x}  dst=0x{dst:011x}  [{region}]{flag}")
