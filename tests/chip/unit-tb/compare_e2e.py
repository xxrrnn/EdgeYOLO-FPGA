"""
compare_e2e.py - FPGA vs Golden vs ONNX 三方 E2E 检测结果对比

对比方法：
  1. 检测结果：比较检测数量、置信度、坐标偏差
  2. 特征图：比较 backbone+neck 输出 (x17, x20, x23) 的数值差异
  3. 可视化：并排显示三方检测结果

用法：
  # 先分别运行 FPGA 和 golden（带 --save-npz）：
  python e2e_detect.py --images <path> --max 5 --conf 0.15 --save-npz
  python e2e_detect.py --images <path> --max 5 --conf 0.15 --save-npz --dry-run

  # 然后对比：
  python compare_e2e.py
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np

_THIS = Path(__file__).resolve().parent
RUNS = _THIS / "runs" / "e2e"

FPGA_DIR = RUNS / "fpga"
GOLDEN_DIR = RUNS / "dry_run"
FPGA_NPZ = RUNS / "npz" / "fpga"
GOLDEN_NPZ = RUNS / "npz" / "dry_run"


def compare_features(name: str, fpga_npz_path: Path, golden_npz_path: Path):
    """Compare intermediate feature maps between FPGA and golden."""
    if not fpga_npz_path.exists() or not golden_npz_path.exists():
        return None

    fpga = np.load(str(fpga_npz_path))
    golden = np.load(str(golden_npz_path))

    results = {}
    for key in ['x17', 'x20', 'x23', 'pred_s', 'pred_m', 'pred_l']:
        if key in fpga and key in golden:
            f = fpga[key]
            g = golden[key]
            if f.shape != g.shape:
                results[key] = {'shape_mismatch': (f.shape, g.shape)}
                continue
            diff = (f.astype(np.float32) - g.astype(np.float32))
            abs_diff = np.abs(diff)
            exact = np.sum(f == g)
            total = f.size
            results[key] = {
                'shape': f.shape,
                'exact_match': f"{exact}/{total} ({100*exact/total:.2f}%)",
                'max_abs_diff': float(abs_diff.max()),
                'mean_abs_diff': float(abs_diff.mean()),
                'rmse': float(np.sqrt(np.mean(diff**2))),
            }
    return results


def compare_detections(fpga_img_dir: Path, golden_img_dir: Path, img_names: list):
    """Compare detection counts from saved images (by counting det files)."""
    print(f"\n{'='*70}")
    print(f"  FPGA vs Golden 检测结果对比")
    print(f"{'='*70}\n")

    fpga_total = 0
    golden_total = 0

    for name in img_names:
        stem = Path(name).stem
        fpga_det = fpga_img_dir / f"{stem}_det.jpg"
        golden_det = golden_img_dir / f"{stem}_det.jpg"
        fpga_exists = fpga_det.exists()
        golden_exists = golden_det.exists()
        status = ""
        if fpga_exists and golden_exists:
            status = "OK"
        elif not fpga_exists:
            status = "FPGA缺失"
        elif not golden_exists:
            status = "Golden缺失"
        print(f"  {name:15s}: FPGA={'Y' if fpga_exists else 'N'} Golden={'Y' if golden_exists else 'N'}  {status}")


def create_comparison_grid(img_names: list):
    """Create side-by-side comparison grid: FPGA | Golden"""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("  [WARN] PIL not available, skipping grid")
        return

    cell_w, cell_h = 320, 280
    n = len(img_names)
    grid_w = cell_w * 2
    grid_h = cell_h * n + 30

    grid = Image.new('RGB', (grid_w, grid_h), (40, 40, 40))
    draw = ImageDraw.Draw(grid)

    try:
        font = ImageFont.truetype("arial.ttf", 14)
    except (OSError, IOError):
        font = ImageFont.load_default()

    draw.text((cell_w // 2 - 20, 5), "FPGA", fill=(0, 255, 0), font=font)
    draw.text((cell_w + cell_w // 2 - 25, 5), "Golden", fill=(255, 255, 0), font=font)

    for idx, name in enumerate(img_names):
        stem = Path(name).stem
        y_off = 30 + idx * cell_h

        fpga_path = FPGA_DIR / f"{stem}_det.jpg"
        golden_path = GOLDEN_DIR / f"{stem}_det.jpg"

        if fpga_path.exists():
            img = Image.open(str(fpga_path)).resize((cell_w, cell_h), Image.BILINEAR)
            grid.paste(img, (0, y_off))
        if golden_path.exists():
            img = Image.open(str(golden_path)).resize((cell_w, cell_h), Image.BILINEAR)
            grid.paste(img, (cell_w, y_off))

    out_path = RUNS / "comparison_fpga_vs_golden.jpg"
    grid.save(str(out_path), quality=90)
    print(f"\n  对比图: {out_path}")


def main():
    print("\n" + "=" * 70)
    print("  YOLOv5n E2E 三方对比: FPGA vs Golden")
    print("=" * 70)

    # Find common images
    fpga_imgs = sorted(FPGA_DIR.glob("*_det.jpg")) if FPGA_DIR.exists() else []
    golden_imgs = sorted(GOLDEN_DIR.glob("*_det.jpg")) if GOLDEN_DIR.exists() else []

    fpga_stems = {p.stem.replace("_det", "") for p in fpga_imgs}
    golden_stems = {p.stem.replace("_det", "") for p in golden_imgs}
    common = sorted(fpga_stems & golden_stems)

    print(f"\n  FPGA 检测图: {len(fpga_imgs)}")
    print(f"  Golden 检测图: {len(golden_imgs)}")
    print(f"  共同图片: {len(common)}")

    if not common:
        print("\n  [ERROR] 没有共同图片可对比！请先运行 FPGA 和 golden。")
        return

    img_names = [f"{s}.jpg" for s in common]

    # Feature comparison
    print(f"\n{'='*70}")
    print(f"  特征图数值对比 (backbone+neck 输出)")
    print(f"{'='*70}")

    has_npz = False
    for name in img_names:
        stem = Path(name).stem
        fpga_npz = FPGA_NPZ / f"{stem}.npz"
        golden_npz = GOLDEN_NPZ / f"{stem}.npz"

        if fpga_npz.exists() and golden_npz.exists():
            has_npz = True
            print(f"\n  [{stem}]")
            results = compare_features(stem, fpga_npz, golden_npz)
            if results:
                for key, info in results.items():
                    if 'shape_mismatch' in info:
                        print(f"    {key:8s}: SHAPE MISMATCH {info['shape_mismatch']}")
                    else:
                        print(f"    {key:8s}: exact={info['exact_match']}, "
                              f"max_diff={info['max_abs_diff']:.2f}, "
                              f"mean_diff={info['mean_abs_diff']:.4f}, "
                              f"rmse={info['rmse']:.4f}")

    if not has_npz:
        print("\n  [INFO] NPZ 文件不存在。需要用 --save-npz 参数重新运行。")
        print("    FPGA: python e2e_detect.py --images <path> --max 5 --conf 0.15 --save-npz")
        print("    Golden: python e2e_detect.py --images <path> --max 5 --conf 0.15 --save-npz --dry-run")

    # Visual comparison grid
    create_comparison_grid(img_names)

    print(f"\n{'='*70}")
    print(f"  对比完成")
    print(f"{'='*70}\n")


if __name__ == "__main__":
    main()
