"""
_l4_full_network_test.py  ——  YOLOv5n 完整网络渐进测试

基于 ops.py 中的算子库（FPGAOps / HostOps / C3Block）构建完整 Backbone + Neck。

用法
----
    # dry-run (仅 numpy golden，不上 FPGA)
    python _l4_full_network_test.py --dry-run --stop-at model.5.conv

    # FPGA 执行（stop-at 控制层数）
    python _l4_full_network_test.py --stop-at model.5.conv

    # 完整 Backbone + Neck
    python _l4_full_network_test.py

    # 详细输出
    python _l4_full_network_test.py -v
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Optional

import numpy as np

_THIS = Path(__file__).resolve()
sys.path.insert(0, str(_THIS.parent))

from ops import FPGAOps, HostOps, C3Block, conv_meta, _net

RUNS_BASE = _THIS.parent / "runs" / "l4_network"


# ──────────────────────────────────────────────────────────────────────────
#  完整 YOLOv5n Backbone + Neck
# ──────────────────────────────────────────────────────────────────────────

def run_yolov5n_backbone_neck(
    runner,
    input_img_int8: np.ndarray,   # INT8 (320, 320, 3)
    dry_run: bool = False,
    stop_at: str = "",
    verbose: bool = False,
) -> dict:
    """运行 YOLOv5n Backbone + Neck，返回各层输出字典。

    input_img_int8 : INT8 (H, W, 3)，外部做 QA 量化后传入
    stop_at        : 提前停止的层名（""=跑完所有）
    """
    acts: dict[str, Optional[np.ndarray]] = {}
    log:  list[str] = []

    fpga = FPGAOps(
        runner=None if dry_run else runner,
        runs_base=str(RUNS_BASE),
        verbose=verbose,
    )
    host = HostOps()

    def _conv(name: str, feat: np.ndarray, case: str) -> Optional[np.ndarray]:
        if stop_at and name == stop_at:
            print(f"  [stop] 在 {name} 停止")
            return None
        print(f"  [{name}]")
        m = conv_meta(_net(), name)
        h, w, _ = feat.shape
        from golden_module_tb import out_hw as _out_hw
        oh, ow = _out_hw(h, w, m)
        ibuf_act = 4 * 512 * 16  # 32KB
        max_pix = max(1, ibuf_act // (m.acc_depth * 16))
        if m.out_ch > 128:
            out = fpga.conv_tiled(feat, name, case_name=case)
        elif oh * ow > max_pix:
            out = fpga.conv_oh_tiled(feat, name, case_name=case, max_pixels=max_pix)
        else:
            out = fpga.conv(feat, name, case_name=case)
        log.append(name)
        return out

    def _c3(mid: str, feat: np.ndarray, n: int) -> np.ndarray:
        block = C3Block(fpga, host, mid, n_bottleneck=n)
        out = block(feat)
        log.append(f"model.{mid} (C3)")
        return out

    # ── Backbone ──────────────────────────────────────────────────────────
    x = input_img_int8
    acts["model.0.conv"] = _conv("model.0.conv", x,    "net_0")
    if acts["model.0.conv"] is None: return acts
    x = acts["model.0.conv"]

    acts["model.1.conv"] = _conv("model.1.conv", x,    "net_1")
    if acts["model.1.conv"] is None: return acts
    x = acts["model.1.conv"]

    acts["model.2"] = _c3("2", x, n=1)
    x = acts["model.2"]

    acts["model.3.conv"] = _conv("model.3.conv", x,    "net_3")
    if acts["model.3.conv"] is None: return acts
    x = acts["model.3.conv"]

    acts["model.4"] = _c3("4", x, n=2)
    x = acts["model.4"]

    acts["model.5.conv"] = _conv("model.5.conv", x,    "net_5")
    if acts["model.5.conv"] is None: return acts
    x = acts["model.5.conv"]

    acts["model.6"] = _c3("6", x, n=3)
    x = acts["model.6"]

    acts["model.7.conv"] = _conv("model.7.conv", x,    "net_7")  # 256ch auto-tiled
    if acts["model.7.conv"] is None: return acts
    x7 = acts["model.7.conv"]

    acts["model.8"] = _c3("8", x7, n=1)        # cv3 256ch auto-tiled
    x8 = acts["model.8"]

    # SPPF: cv1 → MaxPool×3 → concat(4×) → cv2
    acts["model.9.cv1.conv"] = _conv("model.9.cv1.conv", x8, "net_9cv1")
    if acts["model.9.cv1.conv"] is None: return acts
    cv1_out = acts["model.9.cv1.conv"]
    mp1 = host.maxpool(cv1_out, k=5)
    mp2 = host.maxpool(mp1, k=5)
    mp3 = host.maxpool(mp2, k=5)
    sppf_cat = host.concat([cv1_out, mp1, mp2, mp3])   # 512ch (4 × 128)
    acts["model.9.cv2.conv"] = _conv("model.9.cv2.conv", sppf_cat, "net_9cv2")  # 256ch tiled
    if acts["model.9.cv2.conv"] is None: return acts
    x9 = acts["model.9.cv2.conv"]

    acts["model.10.conv"] = _conv("model.10.conv", x9, "net_10")  # 256→128
    if acts["model.10.conv"] is None: return acts
    x10 = acts["model.10.conv"]

    # ── Neck（FPN + PAN）────────────────────────────────────────────────
    x_up1 = host.upsample(x10, scale=2)
    cat_6  = host.concat([x_up1, acts["model.6"]])     # 256ch
    acts["model.13"] = _c3("13", cat_6, n=1)
    x13 = acts["model.13"]

    acts["model.14.conv"] = _conv("model.14.conv", x13, "net_14")  # 128→64
    if acts["model.14.conv"] is None: return acts
    x14 = acts["model.14.conv"]

    x_up2 = host.upsample(x14, scale=2)
    cat_4  = host.concat([x_up2, acts["model.4"]])
    acts["model.17"] = _c3("17", cat_4, n=1)
    x17 = acts["model.17"]

    acts["model.18.conv"] = _conv("model.18.conv", x17, "net_18")
    if acts["model.18.conv"] is None: return acts
    x18 = acts["model.18.conv"]
    cat_13 = host.concat([x18, x13])
    acts["model.20"] = _c3("20", cat_13, n=1)
    x20 = acts["model.20"]

    acts["model.21.conv"] = _conv("model.21.conv", x20, "net_21")  # 128→128
    if acts["model.21.conv"] is None: return acts
    x21 = acts["model.21.conv"]
    cat_8  = host.concat([x21, x8])
    acts["model.23"] = _c3("23", cat_8, n=1)   # cv3 256ch auto-tiled

    print(f"\n  执行完成：共 {len(log)} 层")
    return acts


# ──────────────────────────────────────────────────────────────────────────
#  主函数
# ──────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="YOLOv5n 完整网络渐进测试")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--stop-at", default="")
    ap.add_argument("--verbose", "-v", action="store_true")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    RUNS_BASE.mkdir(parents=True, exist_ok=True)

    runner = None
    if not args.dry_run:
        from xdma_win import ChipRunnerWin
        runner = ChipRunnerWin()

    print(f"\n{'='*60}")
    mode = "dry-run" if args.dry_run else "FPGA"
    print(f"YOLOv5n Backbone+Neck [{mode}]  stop_at='{args.stop_at}'")
    print(f"{'='*60}")

    rng = np.random.default_rng(args.seed)
    img = rng.integers(-128, 128, (320, 320, 3), dtype=np.int16).astype(np.int8)

    acts = run_yolov5n_backbone_neck(
        runner, img,
        dry_run=args.dry_run,
        stop_at=args.stop_at,
        verbose=args.verbose,
    )

    print(f"\n{'='*60}")
    print("各层输出形状：")
    for k, v in acts.items():
        if v is not None:
            print(f"  {k:38s}: {v.shape}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
