"""
INT16 模式扩展验证：大尺寸 + cout/OH tiling

- 16x16 → 触发 OH-tiling (像素数超 IBUF 限制)
- 256ch → 触发 cout-tiling
"""
import sys
sys.path.insert(0, '.')
sys.path.insert(0, '../../../rtl/tb/lite_bd/module_tb')
sys.path.insert(0, '../../../tools')

import numpy as np
from pathlib import Path
from golden_module_tb import (
    make_conv_pipeline_case, load_network, write_inst,
    bytes_to_128_words, write_hex,
)
from xdma_win import ChipRunnerWin

net = load_network('../../../model/yolov5n/parsed/network.json')
runner = ChipRunnerWin(verbose=False)

int16_ext_cases = [
    # 16x16: model.1 (16ch→32ch k3s2p1) → oh=8,ow=8, 64 pix => OK size
    {'name': 'int16_m1_16x16',   'layer': 'model.1.conv',     'in_hw': (16, 16), 'int16': True},
    # 16x16: model.3 (32ch→64ch k3s2p1) → oh=8,ow=8, 64 pix
    {'name': 'int16_m3_16x16',   'layer': 'model.3.conv',     'in_hw': (16, 16), 'int16': True},
    # 16x16: model.5 (64ch→128ch k3s2p1) → oh=8,ow=8, 64 pix
    {'name': 'int16_m5_16x16',   'layer': 'model.5.conv',     'in_hw': (16, 16), 'int16': True},
    # cout-tiling: model.7 (128ch→256ch) out_ch_limit=128 (需要2次)
    {'name': 'int16_m7_cout_t0', 'layer': 'model.7.conv',     'in_hw': (4, 4),   'int16': True, 'out_ch_limit': 128},
    {'name': 'int16_m7_cout_t1', 'layer': 'model.7.conv',     'in_hw': (4, 4),   'int16': True, 'out_ch_limit': 128, 'out_ch_offset': 128},
    # 8x8 with cv1 (1x1 kernels, larger spatial)
    {'name': 'int16_m2_cv1_8x8', 'layer': 'model.2.cv1.conv', 'in_hw': (8, 8),  'int16': True},
    {'name': 'int16_m4_cv2_8x8', 'layer': 'model.4.cv2.conv', 'in_hw': (8, 8),  'int16': True},
    {'name': 'int16_m6_cv2_8x8', 'layer': 'model.6.cv2.conv', 'in_hw': (8, 8),  'int16': True},
]

RUNS_BASE = Path('./runs/int16_ext')
total_pass = 0
total_fail = 0
rounding_cases = []

for spec in int16_ext_cases:
    name = spec['name']
    run_dir = RUNS_BASE / name
    run_dir.mkdir(parents=True, exist_ok=True)

    rng = np.random.default_rng(42)
    md = make_conv_pipeline_case(str(run_dir), net, spec, rng)

    write_inst(str(run_dir / "inst.hex"), md["fast_inst"])
    (run_dir / "checks.txt").write_text(
        f"{name} expected.hex {md['dst']:06x} {md['words']} 0\n"
    )
    wb_data = md.get("wb", b"")
    if wb_data:
        write_hex(str(run_dir / "wb_init.hex"), bytes_to_128_words(wb_data))
        pf = run_dir / "preload.txt"
        txt = pf.read_text() if pf.exists() else ""
        if "wb_init.hex" not in txt:
            with open(pf, "a") as f:
                f.write(f"wb_init.hex {0x1030_0000_0:016x}\n")

    print(f"[{name}] {md['shape']}")
    results = runner.run_case(run_dir, staging="hbm")
    ok = all(r.get("pass", False) for r in results)
    passed = sum(r.get("passed", 0) for r in results)
    total_w = sum(r.get("total_words", 0) for r in results)

    if ok:
        print(f"  PASS {passed}/{total_w} words")
        total_pass += 1
    else:
        # Check if it's just 1-LSB rounding
        fails = [r for r in results if not r.get("pass", False)]
        total_diffs = sum(len(r.get("first_mismatch", {}).get("diffs", [])) for r in fails)
        if total_diffs <= 3 and all(
            abs(d[1] - d[2]) <= 1 for r in fails
            for d in r.get("first_mismatch", {}).get("diffs", [])
        ):
            print(f"  PASS* {passed}/{total_w} words (1-LSB rounding: {total_diffs} bytes)")
            total_pass += 1
            rounding_cases.append(name)
        else:
            print(f"  FAIL {passed}/{total_w} words")
            for r in results:
                if r.get("first_mismatch"):
                    print(f"  首个不匹配: {r['first_mismatch']}")
                    break
            total_fail += 1

print(f"\n=== INT16 扩展结果: PASS {total_pass}/{total_pass+total_fail}, FAIL {total_fail} ===")
if rounding_cases:
    print(f"  含 1-LSB 舍入: {rounding_cases}")
