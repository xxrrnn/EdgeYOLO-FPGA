"""
_l4_model0_test.py  —  YOLOv5n model.0 / model.1 / model.2 片上全链路测试

复用 conv_pipeline 基础设施（golden_module_tb.py + hbm_flow.py + xdma_win.py）。
硬件数据流：
  HBM(src0.hex) --CDMA--> VPU_BUF
  VPU_BUF --im2col_unit--> IBUF(act)
  tile_ibuf(weight, backdoor) --DCIM--> tile_obuf(INT32)
  tile_obuf --CDMA--> VPU_BUF(dcim_out)
  VPU_BUF(dcim_out) --DQA--> VPU_BUF(fp32)
  VPU_BUF(fp32) --QA--> VPU_BUF(dst)  ← 比对点

用法:
    cd tests/chip/unit-tb
    python _l4_model0_test.py                   # 小图快速验证（默认）
    python _l4_model0_test.py --full            # 全尺寸（model.0: 320×320）
    python _l4_model0_test.py --staging preload # preload 路径
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

_THIS = Path(__file__).resolve()
REPO  = _THIS.parents[3]
sys.path.insert(0, str(REPO / "tools"))
sys.path.insert(0, str(_THIS.parent))

from xdma_win import ChipRunnerWin
from gen_data import generate_case


# 小图快速验证（ms 级生成 + KB 级传输）
CASES_SMALL = [
    ("conv_pipeline", "pipe_model0_conv_32x32"),    # stem: 3→16, k=6 s=2, in=32×32
    ("conv_pipeline", "pipe_model1_conv_16x16"),    # 16→32, k=3 s=2, in=16×16
    ("conv_pipeline", "pipe_model2_cv1_16x16"),     # 32→16, k=1 s=1, in=16×16
    ("conv_pipeline", "pipe_model2_cv2_16x16"),     # 32→16, k=1 s=1, in=16×16
]

# 全尺寸（秒级生成 + 数 MB 传输）
CASES_FULL = [
    ("conv_pipeline", "pipe_model0_conv_full"),     # stem, in=320×320 → out=160×160×16
    ("conv_pipeline", "pipe_model1_conv_full"),     # in=160×160 → out=80×80×32
]


def main():
    ap = argparse.ArgumentParser(description="L4 YOLOv5n 逐层 FPGA 测试")
    ap.add_argument("--full", action="store_true",
                    help="全尺寸输入（model.0: 320×320，model.1: 160×160）")
    ap.add_argument("--staging", default="hbm", choices=["hbm", "preload"])
    ap.add_argument("--dry-run", action="store_true",
                    help="只生成 golden，不上 FPGA")
    args = ap.parse_args()

    cases = CASES_FULL if args.full else CASES_SMALL

    runner = None if args.dry_run else ChipRunnerWin()

    print(f"\n{'='*60}")
    mode = "全尺寸" if args.full else "小图"
    print(f"L4 conv 全链路测试 [{mode}]  staging={args.staging}")
    print(f"{'='*60}")

    results = []
    for mod, var in cases:
        print(f"\n  generating {mod}/{var} ...")
        try:
            run_dir = generate_case(mod, var)
        except Exception as e:
            print(f"  [ERROR] gen: {e}")
            results.append((var, "ERR_GEN"))
            continue

        if args.dry_run:
            print(f"  [dry-run] OK → {run_dir}")
            results.append((var, "DRY"))
            continue

        try:
            results_list = runner.run_case(run_dir, staging=args.staging)
            # run_case 返回 list，每项是一个 check 结果
            if isinstance(results_list, list):
                ok  = all(r.get("pass", False) for r in results_list)
                pw  = sum(r.get("pass_words", 0) for r in results_list)
                tw  = sum(r.get("total_words", 0) for r in results_list)
            else:
                ok  = results_list.get("pass", False)
                pw  = results_list.get("pass_words", 0)
                tw  = results_list.get("total_words", 0)
                results_list = [results_list]

            status = "PASS" if ok else f"FAIL {pw}/{tw}"
            results.append((var, status))
            print(f"  FPGA: {status}")

            if not ok:
                for r in results_list:
                    if not r.get("pass", True):
                        print(f"    check '{r.get('name','?')}': "
                              f"{r.get('pass_words',0)}/{r.get('total_words',0)} words pass")
        except Exception as e:
            print(f"  [ERROR] FPGA: {e}")
            import traceback; traceback.print_exc()
            results.append((var, "ERR_RUN"))

    print(f"\n{'='*60}")
    print("汇总:")
    for var, status in results:
        mark = "✅" if status == "PASS" else ("⬛" if status.startswith("DRY") else "❌")
        print(f"  {mark} {var:45s} {status}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
