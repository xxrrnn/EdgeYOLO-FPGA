"""
分析 hbm FAIL 160/256 的失败模式：
- 哪些 word 是对的，哪些是错的
- 错的 word 有什么规律（tile、pixel 分布）
"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from pathlib import Path
from xdma_win import (
    XDMAWin, ChipRunnerWin,
    HBM_BASE, HBM_OFF_OUTPUT,
    DCIM_NUM_TILES, DCIM_INT8_OUT_WORDS_PER_TILE,
    hex_to_bin,
)
from hbm_flow import hbm_drain_remap, _matmul_n_from_manifest
from gen_data import generate_case

xdma   = XDMAWin(verbose=False)
runner = ChipRunnerWin(xdma=xdma, verbose=False)

def analyze_fail(run_dir, staging='hbm'):
    results = runner.run_case(run_dir, staging=staging, timeout_s=60.0)
    r = results[0]
    if r['pass']:
        print(f"  PASS")
        return
    # 读 expected vs got
    from xdma_win import _parse_checks_meta, hex_to_bin
    checks = runner._parse_checks_meta(run_dir)
    chk = checks[0]
    exp = hex_to_bin(run_dir / chk['exp_hex_fname'])[:chk['n_words']*16]
    got_bytes = bytes(r.get('got_raw', b''))
    if not got_bytes:
        print(f"  FAIL {r['passed']}/{r['total_words']} (no raw bytes)")
        return

    n_words = chk['n_words']
    wpt = chk['wpt'] or DCIM_INT8_OUT_WORDS_PER_TILE
    stride = DCIM_NUM_TILES * wpt

    print(f"  FAIL {r['passed']}/{n_words}  wpt={wpt}")
    # 逐 word 对比
    bad_tiles = set()
    bad_pixels = set()
    for i in range(n_words):
        eg = exp[i*16:(i+1)*16]
        gg = got_bytes[i*16:(i+1)*16]
        if eg != gg:
            px  = i // stride
            tile = (i % stride) // wpt
            bad_tiles.add(tile)
            bad_pixels.add(px)

    print(f"  bad tiles:  {sorted(bad_tiles)}")
    print(f"  bad pixels: {sorted(bad_pixels)[:20]} ...")

run_dir = generate_case('dcim_matmul', 'dcim_model_7_conv')

print("=== dcim_model_7_conv: preload vs hbm ===")
print("preload:", end=' ')
r = runner.run_case(run_dir, staging='preload', timeout_s=60.0)[0]
print("PASS" if r['pass'] else f"FAIL {r['passed']}/{r['total_words']}")

print("hbm:    ", end=' ')
analyze_fail(run_dir, staging='hbm')
