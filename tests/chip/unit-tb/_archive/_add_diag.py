"""诊断 add hbm 路径：打印实际的 HBM patch inst 指令"""
import sys
sys.path.insert(0, 'tests/chip/unit-tb')

from pathlib import Path
from hbm_flow import patch_inst_for_hbm, build_hbm_output_drain, build_hbm_input_cdma, staging_writes_for_preload
from xdma_win import HBM_BASE, HBM_OFF_INPUT0, HBM_OFF_INPUT1, VPU_BUF_BASE

run_dir = Path("tests/chip/unit-tb/runs/add_add_residual_16_qint8")

print("=== preload.txt ===")
print((run_dir / "preload.txt").read_text())

print("=== staging_writes_for_preload ===")
for hbm_off, fname, nbytes in staging_writes_for_preload(run_dir):
    print(f"  {fname}: HBM+0x{hbm_off:x} ({nbytes} bytes)")

print("=== build_hbm_input_cdma ===")
insts = build_hbm_input_cdma(run_dir)
for i in range(0, len(insts), 7):
    seg = insts[i:i+7]
    print(f"  {[hex(x) for x in seg]}")

print("=== build_hbm_output_drain ===")
drain, off = build_hbm_output_drain(run_dir)
print(f"  drain_offset=0x{off:x}, {len(drain)} words")
for i in range(0, len(drain), 7):
    seg = drain[i:i+7]
    print(f"  {[hex(x) for x in seg]}")
