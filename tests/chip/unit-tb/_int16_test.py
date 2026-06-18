"""
INT16 模式 FPGA 验证

测试 INT16 accumulation 路径：
  INT8 输入 sign-extend → INT16 激活 × INT16 权重 → INT32 → DQA(FP32) → QA(INT16)

通过 `make_conv_pipeline_case` 的 `int16=True` 参数使用 INT16 路径。
"""
import sys
sys.path.insert(0, '.')
sys.path.insert(0, '../../../rtl/tb/lite_bd/module_tb')
sys.path.insert(0, '../../../tools')

import numpy as np
from pathlib import Path
from golden_module_tb import (
    make_conv_pipeline_case, load_network, write_inst,
    bytes_to_128_words, write_hex, conv_meta,
)
from xdma_win import ChipRunnerWin

net = load_network('../../../model/yolov5n/parsed/network.json')
runner = ChipRunnerWin(verbose=False)

# INT16 测试 cases（从 MODULE_CASES 提取）
int16_cases = [
    {'name': 'int16_tiny_1x1',       'layer': 'model.2.cv1.conv',  'in_hw': (2, 2),  'int16': True},
    {'name': 'int16_conv3_c32_c64',  'layer': 'model.3.conv',      'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_conv1_c128',     'layer': 'model.6.cv1.conv',  'in_hw': (4, 4),  'int16': True},
    # model.0 has in_ch=3 (non-multiples-of-8), skip for now
    # {'name': 'int16_m0_4x4',       'layer': 'model.0.conv',      'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_m1_4x4',         'layer': 'model.1.conv',      'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_m5_4x4',         'layer': 'model.5.conv',      'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_m7_4x4',         'layer': 'model.7.conv',      'in_hw': (4, 4),  'int16': True},
    # 更大尺寸验证
    {'name': 'int16_m1_8x8',         'layer': 'model.1.conv',      'in_hw': (8, 8),  'int16': True},
    {'name': 'int16_m3_8x8',         'layer': 'model.3.conv',      'in_hw': (8, 8),  'int16': True},
    {'name': 'int16_m5_8x8',         'layer': 'model.5.conv',      'in_hw': (8, 8),  'int16': True},
    {'name': 'int16_m7_8x8',         'layer': 'model.7.conv',      'in_hw': (8, 8),  'int16': True},
    # 1x1 卷积更多通道
    {'name': 'int16_cv1_c64_4x4',    'layer': 'model.2.cv2.conv',  'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_cv1_c128_4x4',   'layer': 'model.4.cv1.conv',  'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_cv1_c128_8x8',   'layer': 'model.4.cv1.conv',  'in_hw': (8, 8),  'int16': True},
    # 网络深层
    {'name': 'int16_m9_cv1_4x4',     'layer': 'model.9.cv1.conv',  'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_m13_cv1_4x4',    'layer': 'model.13.cv1.conv', 'in_hw': (4, 4),  'int16': True},
]

RUNS_BASE = Path('./runs/int16_test')
total_pass = 0
total_fail = 0

for spec in int16_cases:
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
        print(f"  FAIL {passed}/{total_w} words")
        for r in results:
            if r.get("first_mismatch"):
                print(f"  首个不匹配: {r['first_mismatch']}")
                break
        total_fail += 1

print(f"\n=== INT16 结果: PASS {total_pass}/{total_pass+total_fail}, FAIL {total_fail} ===")
