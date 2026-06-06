#!/usr/bin/env python3
"""
step1_resnet18_w8a8/run.py - ResNet18 W8A8 full network board test.

Usage:
    python tests/chip/step1_resnet18_w8a8/run.py --dry-run    # offline flow test
    python tests/chip/step1_resnet18_w8a8/run.py              # real hardware
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tests" / "chip"))

from runtime.xdma_driver import XDMA, DryXDMA, ChipRunner, OBUF_BASE


def compile_resnet18(build_dir: Path, mode: str = "int8"):
    """Run the compiler for ResNet18 full network."""
    cmd = [
        sys.executable,
        str(REPO / "tests/chip/compiler/compile.py"),
        "--network", "resnet18",
        "--out", str(build_dir),
        "--full",
        "--mode", mode,
        "--hw-caps", str(REPO / "tests/chip/compiler/lowering/hw_caps.yaml"),
    ]
    print(f"[compile] {' '.join(cmd)}")
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr, file=sys.stderr)
        raise RuntimeError("Compilation failed")
    print(r.stdout)


def make_test_input(h=224, w=224, c=3, seed=42) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.integers(0, 256, size=(h, w, c), dtype=np.uint8)


def golden_resnet18_features(input_nhwc: np.ndarray, weights_dir: Path) -> np.ndarray:
    """Compute golden ResNet18 feature output (7x7x512 FP32) using PyTorch.

    This computes the forward pass up to the last conv layer output (before AvgPool/FC).
    """
    try:
        import torch
        import torch.nn as nn
        from torchvision.models import resnet18 as tv_resnet18
    except ImportError:
        print("[golden] PyTorch/torchvision not available, skipping golden comparison")
        return None

    # Load quantized parameters from parsed weights
    # For now, return None as full golden computation requires the exact
    # quantization parameters from the ONNX model
    print("[golden] NOTE: Full golden comparison requires matching quantization parameters.")
    print("[golden] Returning None - verify output against PyTorch quantized model separately.")
    return None


def host_postprocess(features: np.ndarray) -> np.ndarray:
    """Host-side post-processing: GlobalAvgPool → FC → softmax.

    Args:
        features: [7, 7, 512] FP32 tensor from FPGA

    Returns:
        [1000] class probabilities
    """
    # GlobalAvgPool: average over H, W
    pooled = features.mean(axis=(0, 1))  # [512]
    # FC and softmax would need the FC weights from the model
    # For now just return the pooled features
    return pooled


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--build-dir", default=str(REPO / "tests" / "chip" / "dist" / "resnet18_w8a8"))
    ap.add_argument("--device", default="/dev/xdma0")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--skip-compile", action="store_true")
    args = ap.parse_args()

    build_dir = Path(args.build_dir)

    # Step 1: Compile
    if not args.skip_compile:
        compile_resnet18(build_dir, mode="int8")

    # Step 2: Load plan
    plan = json.loads((build_dir / "plan.json").read_text())
    print(f"[test] Plan: {plan['compile_meta']['num_conv_layers_compiled']} conv layers")
    print(f"[test] Output: {plan['host_io']['output_hw']}x{plan['host_io']['output_c']} "
          f"@ OBUF[0x{plan['host_io']['output_obuf_off']:x}]")

    # Step 3: Prepare input
    input_nhwc = make_test_input(seed=args.seed)
    input_bin = input_nhwc.tobytes()
    print(f"[test] Input: {input_nhwc.shape} UINT8, {len(input_bin)} bytes")

    # Step 4: Run on hardware
    XClass = DryXDMA if args.dry_run else XDMA
    with XClass(args.device) as xdma:
        runner = ChipRunner(xdma)
        result_bytes = runner.run_plan(build_dir, input_bin, timeout_s=60.0)

    # Step 5: Parse output
    oh, ow = plan["host_io"]["output_hw"]
    oc = plan["host_io"]["output_c"]
    result = np.frombuffer(result_bytes, dtype=np.float32).reshape(oh, ow, oc)
    print(f"[test] Result: shape={result.shape}, dtype={result.dtype}")
    print(f"[test]   range: [{result.min():.4f}, {result.max():.4f}]")
    print(f"[test]   mean:  {result.mean():.4f}")
    print(f"[test]   std:   {result.std():.4f}")

    if args.dry_run:
        print("[test] DRY RUN PASS (flow verification only)")
        return

    # Step 6: Basic sanity checks
    assert result.shape == (oh, ow, oc), f"Shape mismatch: {result.shape}"
    assert not np.all(result == 0), "All-zero output (likely hardware error)"
    assert not np.any(np.isnan(result)), "NaN in output"
    assert not np.any(np.isinf(result)), "Inf in output"

    # Step 7: Host post-processing
    pooled = host_postprocess(result)
    print(f"[test] After AvgPool: shape={pooled.shape}")
    print(f"[test] Top-5 channel activations: {np.argsort(pooled)[-5:][::-1]}")

    # Step 8: Save outputs for inspection
    np.save(build_dir / "output_features.npy", result)
    np.save(build_dir / "pooled_features.npy", pooled)
    print(f"[test] Saved output to {build_dir}/output_features.npy")
    print("[test] PASS (sanity checks)")


if __name__ == "__main__":
    main()
