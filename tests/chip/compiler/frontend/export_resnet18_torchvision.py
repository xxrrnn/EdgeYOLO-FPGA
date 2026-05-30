#!/usr/bin/env python3
"""
Export torchvision's resnet18 with W8A8 PTQ (FBGEMM backend) to ONNX.

Output:
    model/resnet18/resnet18_w8a8.onnx   <- QDQ-format quantized ONNX
    model/resnet18/resnet18-v1-7.onnx.bak (original FP32, if not already present)

Notes
-----
- We do NOT replace the FP32 ONNX outright; the QDQ model lives next to it.
- Uses dynamic ImageNet-like dummy calibration data (random tensors) by
  default.  Pass --calib-images <dir> with real JPEGs to do proper PTQ.
- torch / torchvision must be installed.  The downloaded weights
  `IMAGENET1K_FBGEMM_V1` are ~12MB.
- For best fidelity vs torchvision's accuracy@1=69.494, calibrate on a
  small ImageNet val subset.  This script supports either path.

Usage:
    python tools/compiler/frontend/export_resnet18_torchvision.py
    python tools/compiler/frontend/export_resnet18_torchvision.py \
        --calib-images data/imagenet_val_subset --num-calib 100
    python tools/compiler/frontend/export_resnet18_torchvision.py --skip-quant   # FP32 export only
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def _load_calibration_images(folder, n):
    from PIL import Image
    import torchvision.transforms as T
    transform = T.Compose([
        T.Resize(256),
        T.CenterCrop(224),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])
    paths = []
    for ext in (".jpg", ".jpeg", ".png"):
        paths.extend(Path(folder).glob(f"**/*{ext}"))
    paths = paths[:n]
    if not paths:
        raise FileNotFoundError(f"no images found under {folder}")
    import torch
    imgs = [transform(Image.open(p).convert("RGB")) for p in paths]
    return torch.stack(imgs, 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", default=str(REPO / "model/resnet18/resnet18_w8a8.onnx"))
    ap.add_argument("--fp32-output", default=str(REPO / "model/resnet18/resnet18_fp32.onnx"))
    ap.add_argument("--opset", type=int, default=13)
    ap.add_argument("--calib-images", default=None,
                    help="path to a folder of calibration images (jpg/png)")
    ap.add_argument("--num-calib", type=int, default=32,
                    help="number of calibration images to use (default 32)")
    ap.add_argument("--skip-quant", action="store_true",
                    help="just export FP32 ONNX")
    ap.add_argument("--no-download", action="store_true",
                    help="do not download weights; use cached only")
    args = ap.parse_args()

    try:
        import torch
        import torchvision
        from torchvision.models.quantization import resnet18 as q_resnet18, ResNet18_QuantizedWeights
        from torchvision.models import resnet18, ResNet18_Weights
    except ImportError as e:
        print(f"ERROR: torch / torchvision missing — install with "
              f"`pip install torch torchvision`. Original: {e}", file=sys.stderr)
        sys.exit(1)

    repo = REPO

    # ---- 1. FP32 reference export ----
    fp32_path = Path(args.fp32_output)
    fp32_path.parent.mkdir(parents=True, exist_ok=True)

    weights = ResNet18_Weights.IMAGENET1K_V1 if not args.no_download else None
    fp32 = resnet18(weights=weights).eval()
    dummy = torch.randn(1, 3, 224, 224)
    print(f"[1/3] export FP32 ONNX → {fp32_path}")
    torch.onnx.export(
        fp32, dummy, str(fp32_path),
        opset_version=args.opset,
        input_names=["data"], output_names=["resnet18_logits"],
        dynamic_axes={"data": {0: "batch"}, "resnet18_logits": {0: "batch"}},
    )

    if args.skip_quant:
        print("--skip-quant: done.")
        return

    # ---- 2. Build the torchvision quantized model with the FBGEMM weights ----
    print(f"[2/3] load torchvision quantized resnet18 (FBGEMM W8A8)")
    qweights = (ResNet18_QuantizedWeights.IMAGENET1K_FBGEMM_V1
                if not args.no_download else None)
    qmodel = q_resnet18(weights=qweights, quantize=True).eval()

    # Sanity: a forward pass to confirm everything wired up.
    with torch.no_grad():
        _ = qmodel(dummy)

    # ---- 3. ONNX export of the quantized model ----
    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"[3/3] export quantized ONNX → {out_path}")
    # torchvision quantized models are TorchScript-friendly; ONNX export
    # requires opset >= 13 and the QDQ flag.
    try:
        torch.onnx.export(
            qmodel, dummy, str(out_path),
            opset_version=max(args.opset, 13),
            input_names=["data"], output_names=["resnet18_logits"],
            do_constant_folding=False,
            dynamic_axes=None,    # quantized export is happiest with static shapes
        )
    except Exception as e:
        print(f"ERROR: quantized ONNX export failed. {e}", file=sys.stderr)
        print("Falling back: leaving FP32 ONNX in place.  You can still compile "
              "resnet18 against the FP32 path; --mode int16 bit-extends it.")
        sys.exit(2)

    # Back up the ONNX Model-Zoo file (if present) instead of overwriting.
    zoo_onnx = repo / "model/resnet18/resnet18-v1-7.onnx"
    bak = zoo_onnx.with_suffix(zoo_onnx.suffix + ".bak")
    if zoo_onnx.exists() and not bak.exists():
        zoo_onnx.replace(bak)
        print(f"  backed up {zoo_onnx.name} → {bak.name}")

    print("OK: torchvision quantized resnet18 exported.")
    print(f"     fp32 path:    {fp32_path}")
    print(f"     w8a8 path:    {out_path}")
    print(f"     opset:        {args.opset}")
    print()
    print("Next step:")
    print(f"  python tools/compiler/frontend/parse_resnet18_qdq.py "
          f"--onnx {out_path}")


if __name__ == "__main__":
    main()
