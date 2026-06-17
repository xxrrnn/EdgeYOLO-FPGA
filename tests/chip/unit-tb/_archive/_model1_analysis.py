"""分析 dcim_model_1_conv preload 失败模式"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, XDMAWin, DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE, TILE_OBUF_SIZE
from gen_data import generate_case
import math

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

# 对比两个相似 case
for kind, name in [('dcim_matmul', 'dcim_model_0_conv'), ('dcim_matmul', 'dcim_model_1_conv')]:
    rd = generate_case(kind, name)
    r  = runner.run_case(rd, staging='preload', timeout_s=120.0)[0]

    chk    = runner._parse_checks_meta(rd)[0]
    n_words = chk['n_words']
    wpt     = chk['wpt'] or DCIM_INT8_OUT_WORDS_PER_TILE
    stride  = DCIM_NUM_TILES * wpt
    n_pixels = math.ceil(n_words / stride)
    n_tile_words = n_pixels * wpt
    tile_obuf_capacity = TILE_OBUF_SIZE // 16   # words

    status = "PASS" if r['pass'] else f"FAIL {r['passed']}/{n_words}"
    print(f"\n{name}  [{status}]")
    print(f"  n_words={n_words}  wpt={wpt}  n_pixels={n_pixels}")
    print(f"  n_tile_words={n_tile_words}  tile_obuf_capacity={tile_obuf_capacity}  {'OVERFLOW!' if n_tile_words > tile_obuf_capacity else 'OK'}")

    if not r['pass']:
        bad_px = {}
        for mm in r['mismatches']:
            px = mm['word'] // stride
            bad_px[px] = bad_px.get(px, 0) + 1
        px_sorted = sorted(bad_px.keys())
        print(f"  fail pixels ({len(px_sorted)}): {px_sorted[:10]} ...")
        print(f"  pixel range: {px_sorted[0]} ~ {px_sorted[-1]}  (total={n_pixels})")
        print(f"  tile_obuf wraps at pixel: {tile_obuf_capacity // wpt}")
