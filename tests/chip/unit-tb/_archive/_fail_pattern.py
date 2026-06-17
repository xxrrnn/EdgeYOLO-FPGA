"""
分析 dcim_model_7_conv hbm=FAIL 160/256 的失败模式
"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from xdma_win import ChipRunnerWin, XDMAWin, DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

run_dir = generate_case('dcim_matmul', 'dcim_model_7_conv')

r = runner.run_case(run_dir, staging='hbm', timeout_s=60.0)[0]
print(f"hbm: {'PASS' if r['pass'] else 'FAIL'} {r['passed']}/{r['total_words']}")

wpt = 4   # DCIM_INT8_OUT_WORDS_PER_TILE for N=256 INT8
stride = DCIM_NUM_TILES * wpt  # 8*4 = 32

print(f"\nstride={stride}, wpt={wpt}, NUM_TILES={DCIM_NUM_TILES}")
print(f"Total mismatches: {r['failed']}")
print(f"\n失败 word 分布（word_idx -> pixel, tile, intra）:")

bad_tiles  = {}
bad_pixels = {}
for mm in r['mismatches']:
    w     = mm['word']
    px    = w // stride
    tile  = (w % stride) // wpt
    intra = w % wpt
    bad_tiles[tile]   = bad_tiles.get(tile, 0) + 1
    bad_pixels[px]    = bad_pixels.get(px, 0) + 1

print(f"  bad_tiles:   {dict(sorted(bad_tiles.items()))}")
print(f"  bad_pixels:  {dict(sorted(bad_pixels.items()))}")

# 打印前几个失败 word 的具体内容
print(f"\n前 5 个失败 word:")
for mm in r['mismatches'][:5]:
    w  = mm['word']
    px = w // stride
    tile = (w % stride) // wpt
    print(f"  word[{w:4d}] px={px} tile={tile}  exp={mm['expected']}  got={mm['got']}")

# 检查：got 是全零吗？
all_zero_got = all(mm['got'] == '0' * 32 for mm in r['mismatches'])
print(f"\n所有失败 word 的 got 全是零: {all_zero_got}")
