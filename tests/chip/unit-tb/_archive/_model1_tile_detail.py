"""深入分析 model_1_conv：失败的具体 tile 和数值"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')
from xdma_win import ChipRunnerWin, XDMAWin, DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

rd = generate_case('dcim_matmul', 'dcim_model_1_conv')
r  = runner.run_case(rd, staging='preload', timeout_s=120.0)[0]

chk    = runner._parse_checks_meta(rd)[0]
n_words = chk['n_words']  # 256
wpt     = chk['wpt'] or DCIM_INT8_OUT_WORDS_PER_TILE  # 4
stride  = DCIM_NUM_TILES * wpt  # 32

print(f"FAIL {r['passed']}/{n_words}  stride={stride}")
print(f"\nfail 分布 by tile:")
bad_tiles = {}
for mm in r['mismatches']:
    tile = (mm['word'] % stride) // wpt
    bad_tiles[tile] = bad_tiles.get(tile, 0) + 1
print(f"  bad_tiles: {dict(sorted(bad_tiles.items()))}")

print(f"\n前 8 个失败（每 tile 各一个）:")
seen = set()
for mm in r['mismatches']:
    tile = (mm['word'] % stride) // wpt
    if tile not in seen:
        seen.add(tile)
        px = mm['word'] // stride
        print(f"  tile={tile} px={px}  exp={mm['expected'][:16]}...  got={mm['got'][:16]}...")
    if len(seen) >= 4:
        break
