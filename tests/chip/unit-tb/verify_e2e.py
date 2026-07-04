"""verify_e2e.py - 同时验证 INT8 和 INT16 FPGA 推理，输出对比报告

用法：
    # 验证单张图（快速验证）
    python verify_e2e.py --images 1.jpg

    # 验证一批图
    python verify_e2e.py --images <val_dir> --max 5

    # 仅 dry-run（不需要 FPGA 硬件）
    python verify_e2e.py --images <val_dir> --max 5 --dry-run

    # 只验证其中一种精度
    python verify_e2e.py --images <val_dir> --mode int8
    python verify_e2e.py --images <val_dir> --mode int16

输出：
    runs/e2e/verify/  下：
      - <stem>_int8.jpg    INT8 检测结果
      - <stem>_int16.jpg   INT16 检测结果
      - <stem>_compare.jpg 左右对比图
      - summary.txt        文字报告
"""
from __future__ import annotations

import sys, argparse, time, json
from pathlib import Path
from glob import glob
from typing import List, Tuple

import numpy as np

_THIS = Path(__file__).resolve().parent
sys.path.insert(0, str(_THIS))
sys.path.insert(0, str(_THIS.parents[2] / "rtl" / "tb" / "lite_bd" / "module_tb"))
sys.path.insert(0, str(_THIS.parents[2] / "tools"))

REPO_ROOT = _THIS.parents[2]
OUTPUT_DIR = _THIS / "runs" / "e2e" / "verify"

# ─── 运行单张图（指定 precision='int8' 或 'int16'）─────────────────────────

def run_image(img_path: str, runner, dry_run: bool, precision: str,
              conf: float = 0.2, iou: float = 0.45,
              verify: bool = True, preload_weights: bool = True) -> Tuple[np.ndarray, np.ndarray]:
    """返回 (带框图片 RGB, detections (N,6) [x1,y1,x2,y2,conf,cls])"""
    import e2e_detect as _e2e
    from ops import set_network_json
    from run import RUNS_BASE

    # 切换精度配置
    if precision == 'int16':
        _e2e.INT16_MODE = True
        # INT16 = INT8 widened: weight_int8 arrays stored as int16 dtype.
        # Numerically identical to INT8; exercises FPGA INT16 datapath correctly.
        _e2e.WEIGHTS_DIR = str(REPO_ROOT / "model" / "yolov5n" / "parsed_int16_widened" / "weights")
        set_network_json(str(REPO_ROOT / "model" / "yolov5n" / "parsed_int16_widened" / "network.json"))
    else:
        _e2e.INT16_MODE = False
        _e2e.WEIGHTS_DIR = str(REPO_ROOT / "model" / "yolov5n" / "parsed" / "weights")
        set_network_json(str(REPO_ROOT / "model" / "yolov5n" / "parsed" / "network.json"))

    # Clear FPGA HBM weight cache and on-chip TILE_IBUF before each run.
    # This prevents stale INT8/INT16 data in IBUF from contaminating the next run
    # when switching precision within the same session.
    if runner is not None and not dry_run:
        if hasattr(runner, 'clear_weight_cache'):
            runner.clear_weight_cache()
        if hasattr(runner, 'x'):
            from xdma_win import TILE_IBUF_BASE, TILE_IBUF_SIZE
            NTILES = 8
            runner.x.write(TILE_IBUF_BASE, b'\x00' * (NTILES * TILE_IBUF_SIZE))

    # INT8 和 INT16 各用独立的 runs_base，避免 case 文件互相覆盖
    runs_base = str(RUNS_BASE / f"yolov5n_{precision}")

    img_out, dets = _e2e.run_single_image(
        img_path, runner, dry_run,
        conf_thres=conf, iou_thres=iou,
        runs_base=runs_base,
        verify=verify,
        preload_weights=preload_weights,
    )
    return img_out, dets


def make_compare_image(img8: np.ndarray, img16: np.ndarray,
                       dets8: np.ndarray, dets16: np.ndarray,
                       name: str) -> np.ndarray:
    """将 INT8 和 INT16 检测结果左右拼接，加标题栏"""
    from PIL import Image, ImageDraw, ImageFont

    h, w = img8.shape[:2]
    banner = 32  # 标题栏高度
    canvas = np.zeros((h + banner, w * 2, 3), dtype=np.uint8)

    # 填充图像
    canvas[banner:, :w] = img8
    canvas[banner:, w:] = img16

    # 分隔线
    canvas[:, w - 1:w + 1] = [200, 200, 200]

    pil = Image.fromarray(canvas)
    draw = ImageDraw.Draw(pil)
    try:
        font = ImageFont.truetype("arial.ttf", 14)
    except (OSError, IOError):
        font = ImageFont.load_default()

    left_label  = f"INT8  ({len(dets8)} det)"
    right_label = f"INT16 ({len(dets16)} det)"
    match = "[MATCH]" if len(dets8) == len(dets16) else "[DIFF]"
    title = f"{name}   {left_label}  |  {right_label}   {match}"

    draw.rectangle([0, 0, w * 2, banner], fill=(40, 40, 40))
    draw.text((8, 8), title, fill=(255, 255, 200), font=font)

    return np.array(pil)


# ─── 主流程 ────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description="INT8 vs INT16 FPGA E2E 验证")
    ap.add_argument("--images", required=True,
                    help="图片目录或单张图片路径")
    ap.add_argument("--max", type=int, default=5,
                    help="最多处理图片数（默认 5）")
    ap.add_argument("--conf", type=float, default=0.2,
                    help="检测置信度阈值（默认 0.2）")
    ap.add_argument("--iou", type=float, default=0.45,
                    help="NMS IoU 阈值（默认 0.45）")
    ap.add_argument("--dry-run", action="store_true",
                    help="使用 numpy golden 模拟（无需 FPGA 硬件）")
    ap.add_argument("--mode", choices=["both", "int8", "int16"], default="both",
                    help="验证模式（默认 both）")
    args = ap.parse_args()

    # ── 收集图片列表 ─────────────────────────────────────────────────────
    img_dir = Path(args.images)
    if img_dir.is_file():
        img_paths = [img_dir]
    else:
        exts = ("*.jpg", "*.jpeg", "*.png", "*.bmp")
        img_paths = []
        for ext in exts:
            img_paths += [Path(p) for p in sorted(glob(str(img_dir / ext)))]
    img_paths = img_paths[: args.max]

    if not img_paths:
        print(f"[ERROR] 未找到图片: {args.images}")
        return

    # ── 初始化 FPGA runner ───────────────────────────────────────────────
    mode_str = "DRY-RUN" if args.dry_run else "FPGA"
    runner = None
    if not args.dry_run:
        try:
            from xdma_win import ChipRunnerWin
            runner = ChipRunnerWin(verbose=False)
            print("[INFO] FPGA runner 初始化成功")
        except Exception as e:
            print(f"[WARN] 无法连接 FPGA（{e}），切换到 dry-run 模式")
            args.dry_run = True
            mode_str = "DRY-RUN"

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # ── 逐图验证 ─────────────────────────────────────────────────────────
    run_int8  = args.mode in ("both", "int8")
    run_int16 = args.mode in ("both", "int16")

    print(f"\n{'='*68}")
    print(f"  YOLOv5n FPGA 验证  [{mode_str}]  模式: {args.mode.upper()}")
    print(f"  图片: {len(img_paths)} 张  conf>{args.conf}  iou>{args.iou}")
    print(f"  输出: {OUTPUT_DIR}")
    print(f"{'='*68}\n")

    records = []
    from PIL import Image

    for idx, img_path in enumerate(img_paths):
        name = img_path.stem
        t0 = time.time()
        print(f"[{idx+1}/{len(img_paths)}] {img_path.name}")

        row: dict = {"name": img_path.name, "int8_det": -1, "int16_det": -1}

        # ── INT8 ────────────────────────────────────────────────────────
        img_out8 = dets8 = None
        if run_int8:
            t1 = time.time()
            try:
                img_out8, dets8 = run_image(str(img_path), runner, args.dry_run,
                                            precision='int8', conf=args.conf, iou=args.iou)
                row["int8_det"] = len(dets8)
                det_strs = [f"{['person','car','bicycle'][int(d[5])%3]} {d[4]:.2f}" for d in dets8]
                print(f"  INT8 : {len(dets8)} det  [{', '.join(det_strs) or 'none'}]  "
                      f"({time.time()-t1:.1f}s)")
                Image.fromarray(img_out8).save(str(OUTPUT_DIR / f"{name}_int8.jpg"), quality=90)
            except Exception as e:
                print(f"  INT8 : ERROR → {e}")
                import traceback; traceback.print_exc()

        # ── INT16 ───────────────────────────────────────────────────────
        img_out16 = dets16 = None
        if run_int16:
            t1 = time.time()
            try:
                img_out16, dets16 = run_image(str(img_path), runner, args.dry_run,
                                              precision='int16', conf=args.conf, iou=args.iou)
                row["int16_det"] = len(dets16)
                det_strs = [f"{['person','car','bicycle'][int(d[5])%3]} {d[4]:.2f}" for d in dets16]
                print(f"  INT16: {len(dets16)} det  [{', '.join(det_strs) or 'none'}]  "
                      f"({time.time()-t1:.1f}s)")
                Image.fromarray(img_out16).save(str(OUTPUT_DIR / f"{name}_int16.jpg"), quality=90)
            except Exception as e:
                print(f"  INT16: ERROR → {e}")
                import traceback; traceback.print_exc()

        # ── 对比图 ──────────────────────────────────────────────────────
        if img_out8 is not None and img_out16 is not None:
            cmp = make_compare_image(img_out8, img_out16, dets8, dets16, img_path.name)
            Image.fromarray(cmp).save(str(OUTPUT_DIR / f"{name}_compare.jpg"), quality=90)
            match = (len(dets8) == len(dets16))
            row["match"] = match
            status = "MATCH" if match else "DIFF"
            print(f"  对比  : [{status}]  INT8={len(dets8)} det  INT16={len(dets16)} det")

        row["time_s"] = round(time.time() - t0, 1)
        records.append(row)
        print()

    # ── 汇总报告 ─────────────────────────────────────────────────────────
    total8  = sum(r["int8_det"]  for r in records if r["int8_det"]  >= 0)
    total16 = sum(r["int16_det"] for r in records if r["int16_det"] >= 0)
    n_match = sum(1 for r in records if r.get("match", False))
    n_both  = sum(1 for r in records if r.get("match") is not None)

    lines = [
        f"{'='*68}",
        f"  验证汇总  [{mode_str}]  {time.strftime('%Y-%m-%d %H:%M:%S')}",
        f"{'='*68}",
        f"  图片数：{len(records)}",
    ]
    if run_int8:
        lines.append(f"  INT8  总检测数：{total8}")
    if run_int16:
        lines.append(f"  INT16 总检测数：{total16}")
    if n_both > 0:
        lines.append(f"  INT8==INT16 一致：{n_match}/{n_both} 张")
    lines.append(f"{'='*68}")
    lines.append("  图片明细：")

    col_w = max(len(r["name"]) for r in records) + 2
    for r in records:
        s8  = f"INT8={r['int8_det']:2d}"  if r["int8_det"]  >= 0 else "      "
        s16 = f"INT16={r['int16_det']:2d}" if r["int16_det"] >= 0 else "       "
        m   = ("[MATCH]" if r.get("match") else ("[DIFF]" if r.get("match") is False else "      "))
        lines.append(f"    {r['name']:<{col_w}} {s8}  {s16}  {m}  ({r['time_s']}s)")
    lines.append(f"{'='*68}")

    report = "\n".join(lines)
    print(report)
    (OUTPUT_DIR / "summary.txt").write_text(report, encoding="utf-8")

    # 生成对比网格图
    compare_files = sorted(OUTPUT_DIR.glob("*_compare.jpg"))
    if compare_files:
        _make_grid(compare_files, OUTPUT_DIR / "summary_grid.jpg")
        print(f"\n  对比网格图: {OUTPUT_DIR / 'summary_grid.jpg'}")

    print(f"  输出目录  : {OUTPUT_DIR}\n")


def _make_grid(img_files: list, out_path: Path, cell_w: int = 640):
    """将多张对比图纵向排列成网格"""
    from PIL import Image
    imgs = [Image.open(str(f)) for f in img_files]
    if not imgs:
        return
    # 统一宽度
    resized = []
    for im in imgs:
        ratio = cell_w / im.width
        resized.append(im.resize((cell_w, int(im.height * ratio)), Image.BILINEAR))
    total_h = sum(im.height for im in resized)
    grid = Image.new("RGB", (cell_w, total_h), (30, 30, 30))
    y = 0
    for im in resized:
        grid.paste(im, (0, y))
        y += im.height
    grid.save(str(out_path), quality=85)


if __name__ == "__main__":
    main()
