"""
对比同一 case preload vs hbm 的 tile_obuf 原始内容，
确认 drain 数据写对了没有，remap 是否正确
"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from pathlib import Path
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    TILE_OBUF_BASE, TILE_OBUF_SIZE,
    HBM_BASE, HBM_OFF_OUTPUT,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    hex_to_bin,
)
from hbm_flow import hbm_drain_remap, _matmul_n_from_manifest
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

run_dir = generate_case('dcim_matmul', 'dcim_model_7_conv')

# Step1: preload 跑，然后直读 tile_obuf 每个 tile 的前 16 字节
print("=== Step1: 跑 preload，读 tile_obuf 原始数据 ===")
runner.run_case(run_dir, staging='preload', timeout_s=60.0)

wpt = 4
n_pixels = 8  # M=100 n_pixels = ceil(100/(8*4)) = ceil(100/32) = 4, wait...

# 重新算
chk = runner._parse_checks_meta(run_dir)[0]
n_words = chk['n_words']   # 256
wpt2    = chk['wpt'] or DCIM_INT8_OUT_WORDS_PER_TILE
stride  = DCIM_NUM_TILES * wpt2
n_pixels2 = (n_words + stride - 1) // stride
n_tile_words = n_pixels2 * wpt2
print(f"n_words={n_words}, wpt={wpt2}, stride={stride}, n_pixels={n_pixels2}, n_tile_words={n_tile_words}")

# 读每个 tile 的头 4 个 word (1 pixel)
for t in range(DCIM_NUM_TILES):
    addr = TILE_OBUF_BASE + t * TILE_OBUF_SIZE
    data = xdma.read(addr, wpt2 * 16)
    print(f"  tile {t}: {data.hex()}")

# Step2: 跑 hbm，读 HBM 里 drain 的数据（flat，未 remap）
print("\n=== Step2: 跑 hbm，读 HBM drain raw（flat） ===")
runner.run_case(run_dir, staging='hbm', timeout_s=60.0)
flat_nbytes = DCIM_NUM_TILES * n_tile_words * 16
flat_raw = xdma.read(HBM_BASE + HBM_OFF_OUTPUT, flat_nbytes)
print(f"flat_raw 前 {DCIM_NUM_TILES} tiles 各首 word:")
for t in range(DCIM_NUM_TILES):
    off = t * n_tile_words * 16
    print(f"  flat_tile {t}: {flat_raw[off:off+wpt2*16].hex()}")

# Step3: remap 后与 expected 对比
print("\n=== Step3: remap 后对比 expected ===")
remapped = hbm_drain_remap(run_dir, flat_raw)
expected = hex_to_bin(run_dir / chk['exp_hex_fname'])[:n_words*16]

# 逐 tile 看第一个 pixel 是否匹配
for t in range(DCIM_NUM_TILES):
    # word index of tile t, pixel 0
    w_idx = t * wpt2   # pixel 0 of tile t in scatter order
    exp_w = expected[w_idx*16:(w_idx+1)*16]
    got_w = remapped[w_idx*16:(w_idx+1)*16]
    ok    = exp_w == got_w
    print(f"  tile {t} px0: {'OK' if ok else 'FAIL'}  exp={exp_w.hex()}  got={got_w.hex()}")
