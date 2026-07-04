"""
直接跑 hbm，立刻看 mismatches 的 tile/word 分布
"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import ChipRunnerWin, XDMAWin, DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

run_dir = generate_case('dcim_matmul', 'dcim_model_7_conv')

# 先 preload 确认硬件正常
rp = runner.run_case(run_dir, staging='preload', timeout_s=60.0)[0]
print(f"preload: {'PASS' if rp['pass'] else 'FAIL'}")

# 跑 hbm
rh = runner.run_case(run_dir, staging='hbm', timeout_s=60.0)[0]
passed = rh['passed']; total = rh['total_words']
print(f"hbm:     {'PASS' if rh['pass'] else 'FAIL ' + str(passed) + '/' + str(total)}")

if not rh['pass']:
    wpt    = 4
    stride = DCIM_NUM_TILES * wpt
    bad_tiles = {}
    for mm in rh['mismatches']:
        tile = (mm['word'] % stride) // wpt
        bad_tiles[tile] = bad_tiles.get(tile, 0) + 1
    print(f"  bad_tiles: {dict(sorted(bad_tiles.items()))}")
    print(f"\n  前 3 个失败:")
    for mm in rh['mismatches'][:3]:
        w = mm['word']
        print(f"  word[{w}] tile={(w%stride)//wpt} px={w//stride}  exp={mm['expected'][:16]}...  got={mm['got'][:16]}...")
