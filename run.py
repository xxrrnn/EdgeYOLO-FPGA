"""EdgeYOLO-FPGA E2E inference entrypoint.

Usage
-----
  # Dry-run (numpy golden, no FPGA needed):
  python run.py --dry-run

  # FPGA inference:
  python run.py

  # Only YOLO INT8:
  python run.py --network yolo --precision int8 --dry-run

  # Only ResNet with Vitis AI weights (recommended, correct model):
  python run.py --network resnet --precision vai --dry-run

  # Also run ONNX baseline (ResNet, Vitis AI model via onnxruntime):
  python run.py --network resnet --precision vai --onnx --dry-run

  # Custom images:
  python run.py --yolo-img path/to/img.jpg --resnet-img path/to/img.jpg --dry-run

Input
-----
  YOLO   : test_yolo.jpg        (infrared person detection)
  ResNet : test_resnet_2.JPEG   (ImageNet goldfish classification)

Output
------
  output/yolo/    detection images + JSON with bounding boxes
  output/resnet/  classification images + JSON with top-5 scores + class names

  File naming: {stem}_{precision}_{mode}.{ext}
    mode = dry-run | fpga | onnx

ResNet Precision Options
------------------------
  vai    : Vitis AI PTQ INT8 weights (ResNet_int.onnx) - RECOMMENDED
  int8   : legacy torchvision FBGEMM INT8 (requires parse_resnet18_qdq.py)
  int16  : INT8 weights widened to INT16 datapath (same numbers as int8)
"""
from __future__ import annotations

import argparse
import importlib.util
import importlib
import json
import sys
import time
from pathlib import Path

import numpy as np

REPO_ROOT = Path(__file__).resolve().parent
UNIT_TB = REPO_ROOT / "tests" / "chip" / "unit-tb"
OUT_DIR = REPO_ROOT / "output"

DEFAULT_YOLO_IMG = REPO_ROOT / "test_yolo.jpg"
DEFAULT_RESNET_IMG = REPO_ROOT / "test_resnet_2.JPEG"


def _install_unit_tb_run_module() -> None:
    if "run" in sys.modules and getattr(sys.modules["run"], "__file__", "") != str(__file__):
        return
    spec = importlib.util.spec_from_file_location("run", UNIT_TB / "run.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load tests/chip/unit-tb/run.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules["run"] = mod
    spec.loader.exec_module(mod)


def _setup_imports() -> None:
    sys.path.insert(0, str(UNIT_TB))
    sys.path.insert(0, str(REPO_ROOT / "rtl" / "tb" / "lite_bd" / "module_tb"))
    sys.path.insert(0, str(REPO_ROOT / "tools"))
    _install_unit_tb_run_module()


def make_runner(dry_run: bool):
    if dry_run:
        return None
    ChipRunnerWin = importlib.import_module("xdma_win").ChipRunnerWin
    return ChipRunnerWin(verbose=False)


def save_image(img: np.ndarray, path: Path) -> None:
    from PIL import Image
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(str(path), quality=90)


# ─── YOLO ────────────────────────────────────────────────────────────────────

def run_yolo(img_path: Path, precision: str, runner, mode: str,
             out_dir: Path, conf: float, iou: float,
             verify: bool = True, preload_weights: bool = True) -> Path:
    verify_e2e = importlib.import_module("verify_e2e")
    dry_run = mode in ("dry-run", "onnx")

    img_out, dets = verify_e2e.run_image(
        str(img_path), runner, dry_run, precision=precision,
        conf=conf, iou=iou, verify=verify, preload_weights=preload_weights,
    )

    stem = img_path.stem
    img_name = f"{stem}_{precision}_{mode}.jpg"
    json_name = f"{stem}_{precision}_{mode}.json"
    out_img = out_dir / img_name
    out_json = out_dir / json_name

    save_image(img_out, out_img)

    det_list = []
    for d in dets:
        det_list.append({
            "bbox": [float(d[0]), float(d[1]), float(d[2]), float(d[3])],
            "confidence": float(d[4]),
            "class": int(d[5]),
        })
    out_json.write_text(json.dumps(det_list, indent=2))

    n = len(dets)
    confs = ", ".join(f"{d['confidence']:.2f}" for d in det_list[:5]) or "none"
    print(f"  [{mode:7s}] YOLO {precision.upper():5s}: {n} det [{confs}]")
    print(f"            -> {out_img.relative_to(REPO_ROOT)}")
    return out_img


# ─── ResNet ──────────────────────────────────────────────────────────────────

def run_resnet(img_path: Path, precision: str, runner, mode: str,
               out_dir: Path, verify: bool = True, preload_weights: bool = True) -> Path:
    resnet_e2e = importlib.import_module("resnet_e2e")
    dry_run = mode in ("dry-run", "onnx")

    runs_base = UNIT_TB / "runs" / "e2e" / f"resnet18_{precision}"
    img_out, top5, logits = resnet_e2e.run_single_image(
        str(img_path), runner, dry_run, precision=precision,
        runs_base=runs_base, verify=verify, preload_weights=preload_weights,
    )

    class_names = resnet_e2e.CLASS_NAMES

    stem = img_path.stem
    img_name = f"{stem}_{precision}_{mode}.jpg"
    json_name = f"{stem}_{precision}_{mode}.json"
    out_img = out_dir / img_name
    out_json = out_dir / json_name

    save_image(img_out, out_img)

    result = {
        "top5": [{"class": idx, "name": class_names[idx], "score": round(score, 4)}
                 for idx, score in top5],
        "precision": precision,
        "mode": mode,
    }
    out_json.write_text(json.dumps(result, indent=2, ensure_ascii=False))

    top_str = ", ".join(f"{t['name']}({t['class']}):{t['score']:.3f}" for t in result["top5"][:3])
    print(f"  [{mode:7s}] ResNet18 {precision.upper():5s}: [{top_str}]")
    print(f"            -> {out_img.relative_to(REPO_ROOT)}")
    return out_img


def run_resnet_onnx(img_path: Path, out_dir: Path) -> Path:
    """Run ResNet via onnxruntime (Vitis AI ResNet_int.onnx) as ONNX baseline."""
    import onnxruntime as ort
    from PIL import Image

    # Prefer Vitis AI model; fall back to legacy QDQ
    vai_onnx = (REPO_ROOT / "model" / "algorithm" / "Resnet18-quantization"
                / "resnet18" / "quantize_result" / "ResNet_int.onnx")
    legacy_onnx = REPO_ROOT / "model" / "resnet18" / "resnet18_w8a8.onnx"
    onnx_path = vai_onnx if vai_onnx.exists() else legacy_onnx
    model_tag = "Vitis-AI" if onnx_path == vai_onnx else "QDQ(legacy)"

    if not onnx_path.exists():
        print("  [onnx   ] ResNet18: SKIP (model not found)")
        return out_dir

    img = Image.open(str(img_path)).convert("RGB").resize((256, 256), Image.BILINEAR)
    left = top = (256 - 224) // 2
    img = img.crop((left, top, left + 224, top + 224))
    arr = np.array(img).astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    img_chw = ((arr - mean) / std).transpose(2, 0, 1)

    sess = ort.InferenceSession(str(onnx_path))
    inp_name = sess.get_inputs()[0].name
    logits = sess.run(None, {inp_name: img_chw[None].astype(np.float32)})[0][0]
    top5_idx = np.argsort(logits)[-5:][::-1]
    top5 = [(int(i), round(float(logits[i]), 4)) for i in top5_idx]

    label_path = REPO_ROOT / "model" / "resnet18" / "imagenet_labels.json"
    class_names = json.loads(label_path.read_text()) if label_path.exists() \
        else [f"class_{i}" for i in range(1000)]

    stem = img_path.stem
    out_json = out_dir / f"{stem}_vai_onnx.json"
    result = {
        "top5": [{"class": idx, "name": class_names[idx], "score": score}
                 for idx, score in top5],
        "precision": f"int8 ({model_tag})",
        "mode": "onnx",
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(result, indent=2, ensure_ascii=False))

    top_str = ", ".join(f"{t['name']}({t['class']}):{t['score']:.3f}" for t in result["top5"][:3])
    print(f"  [onnx   ] ResNet18 {model_tag:12s}: [{top_str}]")
    print(f"            -> {out_json.relative_to(REPO_ROOT)}")
    return out_json


# ─── CLI ─────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        description="YOLOv5n / ResNet18 FPGA E2E inference",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage\n-----\n")[1] if "Usage" in __doc__ else "",
    )
    ap.add_argument("--network", choices=["yolo", "resnet", "all"], default="all")
    ap.add_argument("--precision", choices=["vai", "int8", "int16", "both"], default="vai",
                    help="ResNet precision: vai=Vitis AI (recommended), int8=legacy FBGEMM, int16=int8 widened")
    ap.add_argument("--dry-run", action="store_true", help="numpy golden (no FPGA)")
    ap.add_argument("--onnx", action="store_true", help="also run ONNX baseline (ResNet)")
    ap.add_argument("--yolo-img", default=str(DEFAULT_YOLO_IMG))
    ap.add_argument("--resnet-img", default=str(DEFAULT_RESNET_IMG))
    ap.add_argument("--conf", type=float, default=0.15)
    ap.add_argument("--iou", type=float, default=0.45)
    ap.add_argument("--out-dir", default=str(OUT_DIR))
    ap.add_argument("--no-verify", action="store_true",
                    help="skip per-layer expected.hex comparison (faster inference, no FAIL reports)")
    ap.add_argument("--no-preload", action="store_true",
                    help="disable batch weight preload to HBM (use per-layer upload with content-hash cache)")
    return ap.parse_args()


def main() -> int:
    args = parse_args()
    _setup_imports()

    networks = ["yolo", "resnet"] if args.network == "all" else [args.network]
    precisions = ["int8", "int16"] if args.precision == "both" else [args.precision]
    # YOLO only supports int8/int16; for 'vai', use int8 for YOLO
    yolo_precisions = [p if p in ("int8", "int16") else "int8" for p in precisions]
    mode = "dry-run" if args.dry_run else "fpga"
    verify = not args.no_verify
    preload_weights = not getattr(args, 'no_preload', False)
    runner = make_runner(args.dry_run)

    yolo_img = Path(args.yolo_img)
    resnet_img = Path(args.resnet_img)
    yolo_out = Path(args.out_dir) / "yolo"
    resnet_out = Path(args.out_dir) / "resnet"

    print("=" * 60)
    print("EdgeYOLO-FPGA E2E Inference")
    print(f"  Mode       : {mode.upper()}")
    print(f"  Networks   : {', '.join(networks)}")
    print(f"  Precisions : {', '.join(precisions)}")
    print(f"  Verify     : {'YES' if verify else 'NO (--no-verify)'}")
    print(f"  Preload    : {'YES' if preload_weights else 'NO (--no-preload)'}")
    if "yolo" in networks:
        print(f"  YOLO input : {yolo_img}")
    if "resnet" in networks:
        print(f"  ResNet input: {resnet_img}")
    print(f"  Output     : {Path(args.out_dir).resolve()}")
    print("=" * 60)

    t0 = time.time()

    if "yolo" in networks:
        print(f"\n--- YOLO Detection [{yolo_img.name}] ---")
        if not yolo_img.exists():
            print(f"  [ERROR] image not found: {yolo_img}")
            return 1
        for prec in yolo_precisions:
            run_yolo(yolo_img, prec, runner, mode, yolo_out, args.conf, args.iou,
                     verify=verify, preload_weights=preload_weights)

    if "resnet" in networks:
        print(f"\n--- ResNet Classification [{resnet_img.name}] ---")
        if not resnet_img.exists():
            print(f"  [ERROR] image not found: {resnet_img}")
            return 1
        for prec in precisions:
            run_resnet(resnet_img, prec, runner, mode, resnet_out,
                       verify=verify, preload_weights=preload_weights)
        if args.onnx:
            run_resnet_onnx(resnet_img, resnet_out)

    print(f"\nDone in {time.time() - t0:.1f}s")
    print(f"Results: {Path(args.out_dir).resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
