import sys
from pathlib import Path
sys.path.insert(0, 'tools')
sys.path.insert(0, 'tests/chip/unit-tb')
from hbm_flow import build_hbm_input_cdma, staging_writes_for_preload, _preload_dst, TILE_IBUF_BASE
from xdma_win import VPU_BUF_BASE, WB_BASE

run_dir = Path('tests/chip/unit-tb/runs/mini_network_mini_2conv_c16_qint8')

print("staging_writes_for_preload:")
for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir):
    dst = _preload_dst(run_dir, fname)
    skip = dst < TILE_IBUF_BASE
    print(f"  {fname}: hbm_off=0x{hbm_off:x} dst=0x{dst:011x} nbytes={nbytes} SKIP={skip}")
    print(f"    dst >= TILE_IBUF_BASE={dst >= TILE_IBUF_BASE} (TILE_IBUF_BASE=0x{TILE_IBUF_BASE:011x})")

print()
print("build_hbm_input_cdma result:")
insts = build_hbm_input_cdma(run_dir)
print(f"  {len(insts)} words generated")
for i in range(0, len(insts), 7):
    chunk = insts[i:i+7]
    if chunk and (chunk[0] >> 28) == 0x1:
        sm, sl = chunk[1], chunk[2]
        dm, dl = chunk[3], chunk[4]
        nb = chunk[5] if len(chunk) > 5 else 0
        src = (sm << 32) | sl
        dst = (dm << 32) | dl
        print(f"  CDMA src=0x{src:011x} dst=0x{dst:011x} len={nb}B")
