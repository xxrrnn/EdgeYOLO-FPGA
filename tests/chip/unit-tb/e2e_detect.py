"""
e2e_detect.py - YOLOv5n E2E 目标检测（FPGA 真实执行）

流程：
  1. Host: 前处理（letterbox + /255 + QA → INT8）
  2. FPGA: backbone + neck (57 conv layers)
  3. Host: detect head (1x1 conv FP32)
  4. Host: 后处理 (decode + NMS + 画框)

输出：
  tests/chip/unit-tb/runs/e2e/detect/  下的检测结果图片

用法：
  # FPGA 执行
  python e2e_detect.py --images ../../../model/algorithm/Infrared-Object-Detection/datasets/infrared/images/val/ --max 8

  # dry-run（numpy golden 模拟 FPGA）
  python e2e_detect.py --images ../../../model/algorithm/Infrared-Object-Detection/datasets/infrared/images/val/ --max 8 --dry-run
"""
from __future__ import annotations
import os
import sys, time, argparse
from pathlib import Path
import numpy as np

_THIS = Path(__file__).resolve().parent
sys.path.insert(0, str(_THIS))
sys.path.insert(0, str(_THIS.parents[2] / "rtl" / "tb" / "lite_bd" / "module_tb"))
sys.path.insert(0, str(_THIS.parents[2] / "tools"))

from run import (
    load_image, letterbox, preprocess_yolov5n,
    postprocess_yolov5n, IMG_SIZE_YOLO, RUNS_BASE,
)
from ops import FPGAOps, HostOps, C3Block, conv_meta, _net, set_network_json
from detect_head import DetectHead


def _can_reuse_cases(runs_base: str) -> bool:
    root = Path(runs_base)
    return root.exists() and any(
        d.is_dir() and (d / "inst.hex").exists() and (d / "preload.txt").exists()
        for d in root.iterdir()
    )
from golden_module_tb import out_hw as _out_hw

REPO_ROOT = _THIS.parents[2]
OUTPUT_DIR = _THIS / "runs" / "e2e" / "detect"
WEIGHTS_DIR = str(REPO_ROOT / "model" / "yolov5n" / "parsed" / "weights")
RESULTS_NPZ_DIR = _THIS / "runs" / "e2e" / "npz"
CLASS_NAMES = ['person', 'car', 'bicycle']
COLORS = [(0, 255, 0), (255, 0, 0), (0, 0, 255)]
INT16_MODE = False


def _build_weight_hbm_map(runner, runs_base: str, dry_run: bool) -> "dict | None":
    """Pre-upload all weights to HBM pool before inference.

    Scans runs_base for case dirs containing preload.txt and uploads weight files
    to a dedicated non-overlapping pool in HBM.  Returns the map passed to FPGAOps
    so each run_case call can skip weight PCIe transfers.

    Returns None if dry_run or runner is None (no FPGA, nothing to preload).
    """
    if dry_run or runner is None:
        return None
    if not hasattr(runner, 'preload_all_weights'):
        return None
    from pathlib import Path as _Path
    rb = _Path(runs_base)
    if not rb.exists():
        return None
    run_dirs = [d for d in sorted(rb.iterdir()) if d.is_dir() and (d / "preload.txt").exists()]
    if not run_dirs:
        return None
    return runner.preload_all_weights(run_dirs)


def run_fpga_backbone_neck(int8_input: np.ndarray, runner, dry_run: bool,
                           runs_base: str = None, verify: bool = True,
                           weight_hbm_map: "dict | None" = None):
    """执行 backbone + neck 在 FPGA 上

    runs_base      : 可选，指定 case 文件存放目录（默认 RUNS_BASE/yolov5n）。
                     验证脚本中用来区分 INT8 / INT16 的 case 文件目录。
    verify         : 若 False，跳过逐层 expected.hex 对比验证（加速推理）。
    weight_hbm_map : 由 runner.preload_all_weights() 返回的预上传权重地址映射。
                     若提供，每层跳过权重 PCIe 上传（权重已在 HBM 池中）。
    """
    _runs_base = runs_base if runs_base is not None else str(RUNS_BASE / "yolov5n")
    fpga = FPGAOps(
        runner=None if dry_run else runner,
        runs_base=_runs_base,
        verbose=False,
        verify=verify,
        weight_hbm_map=weight_hbm_map,
    )
    host = HostOps()

    def _conv(name, feat, case):
        m = conv_meta(_net(), name)
        h, w, _ = feat.shape
        oh, ow = _out_hw(h, w, m)
        ibuf_act = 4 * 512 * 16
        max_pix = max(1, ibuf_act // (m.acc_depth * 16))
        # INT16 模式：每 pass 最多 64 ch（8 tiles × 8 ch）；INT8：128 ch（8 tiles × 16 ch）
        tile_limit = 64 if INT16_MODE else 128
        if m.out_ch > tile_limit:
            return fpga.conv_tiled(feat, name, case_name=case, tile_size=tile_limit)
        elif oh * ow > max_pix:
            return fpga.conv_oh_tiled(feat, name, case_name=case, max_pixels=max_pix)
        else:
            return fpga.conv(feat, name, case_name=case)

    def _c3(mid, feat, n):
        return C3Block(fpga, host, mid, n_bottleneck=n)(feat)

    x = int8_input
    x = _conv("model.0.conv", x, "e2e_0")
    x = _conv("model.1.conv", x, "e2e_1")
    x = _c3("2", x, 1)
    x = _conv("model.3.conv", x, "e2e_3")
    x = _c3("4", x, 2)
    x4 = x
    x = _conv("model.5.conv", x, "e2e_5")
    x = _c3("6", x, 3)
    x6 = x
    x = _conv("model.7.conv", x, "e2e_7")
    x = _c3("8", x, 1)
    x8 = x

    cv1 = _conv("model.9.cv1.conv", x8, "e2e_9cv1")
    mp1 = host.maxpool(cv1, k=5)
    mp2 = host.maxpool(mp1, k=5)
    mp3 = host.maxpool(mp2, k=5)
    sppf_cat = host.concat([cv1, mp1, mp2, mp3])
    x9 = _conv("model.9.cv2.conv", sppf_cat, "e2e_9cv2")
    x10 = _conv("model.10.conv", x9, "e2e_10")

    cat_6 = host.concat([host.upsample(x10, 2), x6])
    x13 = _c3("13", cat_6, 1)
    x14 = _conv("model.14.conv", x13, "e2e_14")
    cat_4 = host.concat([host.upsample(x14, 2), x4])
    x17 = _c3("17", cat_4, 1)

    # Neck downsamples - NO hard_quant needed anymore.
    # model.18/21 DQA scales have been corrected to accept in_act_scale=0.07814 directly.
    x18 = _conv("model.18.conv", x17, "e2e_18")
    # model.19: concat([model.18_out, model.14_out]) — NOT x13!
    x20 = _c3("20", host.concat([x18, x14]), 1)
    x21 = _conv("model.21.conv", x20, "e2e_21")
    # model.22: concat([model.21_out, model.10_out]) — NOT x8!
    x23 = _c3("23", host.concat([x21, x10]), 1)

    # Detect head uses these features with act_scale=0.07814 dequant
    return x17, x20, x23


def draw_boxes(img: np.ndarray, detections: np.ndarray, class_names=CLASS_NAMES) -> np.ndarray:
    """在图像上画检测框"""
    from PIL import Image, ImageDraw, ImageFont
    pil_img = Image.fromarray(img.copy())
    draw = ImageDraw.Draw(pil_img)

    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except (OSError, IOError):
        font = ImageFont.load_default()

    for det in detections:
        x1, y1, x2, y2, conf, cls_id = det[:6]
        cls_id = int(cls_id)
        color = COLORS[cls_id % len(COLORS)]
        label = f"{class_names[cls_id]} {conf:.2f}"

        draw.rectangle([x1, y1, x2, y2], outline=color, width=2)
        # Label background
        tw = draw.textlength(label, font=font) if hasattr(draw, 'textlength') else len(label) * 7
        draw.rectangle([x1, y1 - 14, x1 + tw + 4, y1], fill=color)
        draw.text((x1 + 2, y1 - 13), label, fill=(255, 255, 255), font=font)

    return np.array(pil_img)


def run_single_image(img_path: str, runner, dry_run: bool, conf_thres: float = 0.15,
                     iou_thres: float = 0.45, save_npz: str = None,
                     runs_base: str = None, verify: bool = True,
                     preload_weights: bool = True):
    """单张图片 FPGA E2E 检测

    preload_weights: 若 True（默认），在正式推理前先 dry-run 生成 case 文件，
                     然后批量上传全部权重到 HBM 池，推理时跳过逐层权重 PCIe 传输。
                     若 False，退回到逐层权重上传（带 content-hash 缓存）。
    """
    from run import IMG_SIZE_YOLO  # ensure always available
    import json
    img_rgb = load_image(img_path)

    if INT16_MODE:
        # INT16 widened from INT8: send uint8 pixel values as int16 dtype.
        # Numerically identical to INT8; used to exercise the FPGA INT16 datapath.
        uint8_q, ratio, (dw, dh), orig_shape = preprocess_yolov5n(img_rgb)
        quant_input = uint8_q.astype(np.int16)
    else:
        quant_input, ratio, (dw, dh), orig_shape = preprocess_yolov5n(img_rgb)

    _runs_base = runs_base or str(RUNS_BASE / "yolov5n")

    # Phase 1: dry-run to generate all case files (weight hex, preload.txt, inst.hex).
    # Always regenerate to ensure case files match the current weight config (INT8 vs INT16).
    weight_hbm_map = None
    if preload_weights and not dry_run and runner is not None:
        if os.environ.get("EDGEYOLO_REUSE_CASES") == "1" and _can_reuse_cases(_runs_base):
            print("[preload] Reusing existing case files", flush=True)
        else:
            print("[preload] Generating case files (dry-run)...", flush=True)
            run_fpga_backbone_neck(quant_input, runner=None, dry_run=True,
                                   runs_base=_runs_base, verify=False)
        # Phase 2: upload all weights to HBM pool
        print("[preload] Uploading all weights to HBM pool...", flush=True)
        t_pre = time.time()
        weight_hbm_map = _build_weight_hbm_map(runner, _runs_base, dry_run=False)
        print(f"[preload] Done in {time.time()-t_pre:.1f}s", flush=True)

    # Phase 3: FPGA backbone + neck (weight PCIe uploads skipped if map available)
    x17, x20, x23 = run_fpga_backbone_neck(quant_input, runner, dry_run,
                                            runs_base=_runs_base, verify=verify,
                                            weight_hbm_map=weight_hbm_map)

    # Host detect head
    head = DetectHead(WEIGHTS_DIR)
    raw_preds = head.forward(x17, x20, x23)

    # Save intermediate features for comparison
    if save_npz:
        np.savez_compressed(save_npz,
            int8_input=quant_input,
            x17=x17, x20=x20, x23=x23,
            pred_s=raw_preds[0], pred_m=raw_preds[1], pred_l=raw_preds[2],
        )

    # Decode + NMS (use DetectHead's postprocess for cleaner implementation)
    results = head.postprocess(raw_preds, conf_thres=conf_thres, iou_thres=iou_thres, img_size=IMG_SIZE_YOLO)

    # Scale coordinates back to original image
    if len(results) > 0:
        # results: (M, 7) [x1, y1, x2, y2, conf, cls_score, cls_id]
        results[:, [0, 2]] = (results[:, [0, 2]] - dw) / ratio
        results[:, [1, 3]] = (results[:, [1, 3]] - dh) / ratio
        results[:, [0, 2]] = np.clip(results[:, [0, 2]], 0, orig_shape[1])
        results[:, [1, 3]] = np.clip(results[:, [1, 3]], 0, orig_shape[0])

    # Convert to (M, 6) format: [x1, y1, x2, y2, conf, cls_id]
    if len(results) > 0:
        detections = np.column_stack([results[:, :4], results[:, 4], results[:, 6]])
    else:
        detections = np.zeros((0, 6))

    # Draw boxes
    img_out = draw_boxes(img_rgb, detections)

    return img_out, detections


def main():
    ap = argparse.ArgumentParser(description="YOLOv5n FPGA E2E Detection")
    ap.add_argument("--images", type=str, required=True, help="Image directory or single image")
    ap.add_argument("--max", type=int, default=8, help="Max images to process")
    ap.add_argument("--dry-run", action="store_true", help="Use numpy golden instead of FPGA")
    ap.add_argument("--conf", type=float, default=0.15, help="Confidence threshold")
    ap.add_argument("--iou", type=float, default=0.45, help="IoU threshold for NMS")
    ap.add_argument("--save-npz", action="store_true", help="Save intermediate feature maps as NPZ")
    ap.add_argument("--int16", action="store_true", help="Use INT16 quantized model")
    args = ap.parse_args()

    # Configure model paths based on precision
    global WEIGHTS_DIR, INT16_MODE
    if args.int16:
        INT16_MODE = True
        # INT16 = INT8 widened: same INT8 weight values cast to int16 dtype.
        # Exercises the FPGA INT16 datapath with numerically identical values.
        # parsed_int16_widened/ has weight_int8 arrays stored as int16 dtype,
        # which triggers all int16-path logic in ops.py (tile_size, alignment, etc.)
        WEIGHTS_DIR = str(REPO_ROOT / "model" / "yolov5n" / "parsed_int16_widened" / "weights")
        set_network_json(str(REPO_ROOT / "model" / "yolov5n" / "parsed_int16_widened" / "network.json"))

    # Setup FPGA runner
    runner = None
    if not args.dry_run:
        from xdma_win import ChipRunnerWin
        runner = ChipRunnerWin(verbose=False)
        mode_str = "FPGA"
    else:
        mode_str = "DRY-RUN"

    out_dir = _THIS / "runs" / "e2e" / mode_str.lower().replace("-", "_")
    out_dir.mkdir(parents=True, exist_ok=True)

    npz_dir = _THIS / "runs" / "e2e" / "npz" / mode_str.lower().replace("-", "_")
    if args.save_npz:
        npz_dir.mkdir(parents=True, exist_ok=True)

    # Collect images
    img_dir = Path(args.images)
    if img_dir.is_file():
        img_paths = [img_dir]
    else:
        img_paths = sorted(img_dir.glob("*.jpg"))[:args.max]
        img_paths += sorted(img_dir.glob("*.png"))[:max(0, args.max - len(img_paths))]
        img_paths = img_paths[:args.max]

    print(f"\n{'='*70}")
    print(f"  YOLOv5n FPGA E2E Detection [{mode_str}]")
    print(f"  Images: {len(img_paths)}, conf>{args.conf}, iou>{args.iou}")
    print(f"  Output: {out_dir}")
    print(f"{'='*70}\n")

    t0 = time.time()
    all_results = []

    for idx, img_path in enumerate(img_paths):
        print(f"[{idx+1}/{len(img_paths)}] {img_path.name}...", end=" ", flush=True)
        t1 = time.time()

        npz_path = str(npz_dir / f"{img_path.stem}.npz") if args.save_npz else None
        img_out, detections = run_single_image(
            str(img_path), runner, args.dry_run,
            conf_thres=args.conf, iou_thres=args.iou,
            save_npz=npz_path,
        )

        # Save output image
        from PIL import Image
        det_path = out_dir / f"{img_path.stem}_det.jpg"
        Image.fromarray(img_out).save(str(det_path), quality=90)

        dt = time.time() - t1
        print(f"{len(detections)} detections, {dt:.1f}s")
        all_results.append((img_path.name, len(detections), detections))

    # Summary
    total_time = time.time() - t0
    total_dets = sum(r[1] for r in all_results)
    print(f"\n{'='*70}")
    print(f"  Total: {len(img_paths)} images, {total_dets} detections")
    if len(img_paths) > 0:
        print(f"  Time: {total_time:.1f}s ({total_time/len(img_paths):.1f}s/image)")
    print(f"  Output: {out_dir}")
    print(f"{'='*70}")

    # Create a grid summary image
    if len(img_paths) > 1:
        create_summary_grid(img_paths, all_results, out_dir)


def create_summary_grid(img_paths, all_results, out_dir):
    """Create a summary grid of all detection results."""
    from PIL import Image

    cell_size = 320
    n = len(img_paths)
    cols = min(4, n)
    rows = (n + cols - 1) // cols
    grid = Image.new('RGB', (cols * cell_size, rows * cell_size), (50, 50, 50))

    for idx, img_path in enumerate(img_paths):
        det_path = out_dir / f"{img_path.stem}_det.jpg"
        if det_path.exists():
            img = Image.open(str(det_path))
            img = img.resize((cell_size, cell_size), Image.BILINEAR)
            r, c = idx // cols, idx % cols
            grid.paste(img, (c * cell_size, r * cell_size))

    grid_path = out_dir / "summary_grid.jpg"
    grid.save(str(grid_path), quality=85)
    print(f"  Grid: {grid_path}")


if __name__ == "__main__":
    main()
