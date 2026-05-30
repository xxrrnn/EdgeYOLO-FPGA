#!/usr/bin/env python3
"""
step0_single_layer/run_test.py - Single conv layer board test for ResNet18 layer1.

Usage:
    # Dry run (no hardware):
    python tests/chip/step0_single_layer/run_test.py --dry-run

    # Real hardware:
    python tests/chip/step0_single_layer/run_test.py
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tests" / "chip"))

from runtime.xdma_driver import XDMA, DryXDMA, ChipRunner


def make_test_input(h: int, w: int, c: int, seed: int = 42) -> np.ndarray:
    """Generate a deterministic UINT8 test input in NHWC layout."""
    rng = np.random.default_rng(seed)
    return rng.integers(0, 256, size=(h, w, c), dtype=np.uint8)


def golden_conv_layer(input_nhwc: np.ndarray, weights_dir: Path, layer_name: str) -> np.ndarray:
    """Compute golden output for a single conv layer using numpy.

    Returns FP32 output (after DQA: int32_accum * dqa_scale + dqa_bias).
    """
    npz_name = layer_name.replace(".", "_").replace("/", "_") + ".npz"
    npz_path = weights_dir / npz_name
    z = np.load(npz_path)

    weight_int8 = z["weight_int8"]      # [OC, IC, KH, KW]
    dqa_scale = z["dqa_scale"]           # [OC]
    dqa_bias = z["dqa_bias"]             # [OC]

    oc, ic, kh, kw = weight_int8.shape
    h, w, c_in = input_nhwc.shape
    assert c_in == ic

    # Read layer params from network.json
    network_json = weights_dir.parent / "network.json"
    network = json.loads(network_json.read_text())
    layer = None
    for L in network["layers"]:
        if L["name"] == layer_name:
            layer = L
            break
    assert layer is not None, f"Layer {layer_name} not found"

    stride_h, stride_w = layer["stride"]
    pad_top, pad_left, pad_bottom, pad_right = layer["padding"]

    # Pad input
    padded = np.pad(
        input_nhwc.astype(np.int32),
        ((pad_top, pad_bottom), (pad_left, pad_right), (0, 0)),
        mode="constant", constant_values=0,
    )

    oh = (h + pad_top + pad_bottom - kh) // stride_h + 1
    ow = (w + pad_left + pad_right - kw) // stride_w + 1

    # INT8 convolution (accumulator = INT32)
    output_int32 = np.zeros((oh, ow, oc), dtype=np.int32)
    input_int8 = input_nhwc.astype(np.int8) if input_nhwc.dtype == np.int8 else input_nhwc.view(np.uint8).astype(np.int32)

    # Use padded int32 for accumulation
    for ohi in range(oh):
        for owi in range(ow):
            ih_start = ohi * stride_h
            iw_start = owi * stride_w
            patch = padded[ih_start:ih_start+kh, iw_start:iw_start+kw, :]  # [kh, kw, ic]
            for oci in range(oc):
                w_oc = weight_int8[oci].astype(np.int32)  # [ic, kh, kw]
                # weight is [IC, KH, KW], patch is [KH, KW, IC]
                w_oc_hwc = w_oc.transpose(1, 2, 0)  # [KH, KW, IC]
                output_int32[ohi, owi, oci] = np.sum(patch * w_oc_hwc)

    # DQA: output_fp32 = int32_accum * dqa_scale + dqa_bias, then ReLU
    output_fp32 = output_int32.astype(np.float32) * dqa_scale[None, None, :] + dqa_bias[None, None, :]
    output_fp32 = np.maximum(output_fp32, 0.0)  # ReLU
    return output_fp32


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="No hardware, just verify flow")
    ap.add_argument("--build-dir", default=str(REPO / "build" / "resnet18_l1"))
    ap.add_argument("--device", default="/dev/xdma0")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--tolerance", type=float, default=1e-3,
                    help="Relative tolerance for FP32 comparison")
    args = ap.parse_args()

    build_dir = Path(args.build_dir)
    plan = json.loads((build_dir / "plan.json").read_text())
    layer_info = plan["memory_plan"]["layers"][0]

    # Generate test input
    h, w = layer_info["input_hw"]
    c_in = layer_info["input_c"]
    print(f"[test] Generating input: {h}x{w}x{c_in} UINT8 (seed={args.seed})")
    input_nhwc = make_test_input(h, w, c_in, seed=args.seed)
    input_bin = input_nhwc.tobytes()

    # Compute golden
    weights_dir = REPO / "model" / "resnet18" / "parsed_qdq" / "weights"
    layer_name = layer_info["name"]
    print(f"[test] Computing golden for layer: {layer_name}")
    golden = golden_conv_layer(input_nhwc, weights_dir, layer_name)
    print(f"[test] Golden output shape: {golden.shape}, range: [{golden.min():.2f}, {golden.max():.2f}]")

    # Run on hardware (or dry-run)
    XClass = DryXDMA if args.dry_run else XDMA
    with XClass(args.device) as xdma:
        runner = ChipRunner(xdma)
        result_bytes = runner.run_plan(build_dir, input_bin)

    # Parse result
    oh, ow = plan["host_io"]["output_hw"]
    oc = plan["host_io"]["output_c"]
    result = np.frombuffer(result_bytes, dtype=np.float32).reshape(oh, ow, oc)
    print(f"[test] Result shape: {result.shape}, range: [{result.min():.2f}, {result.max():.2f}]")

    if args.dry_run:
        print("[test] DRY RUN - skipping numerical comparison (all zeros from DryXDMA)")
        print("[test] PASS (flow verification)")
        return

    # Compare
    abs_diff = np.abs(result - golden)
    max_diff = abs_diff.max()
    mean_diff = abs_diff.mean()
    rel_diff = abs_diff / (np.abs(golden) + 1e-8)
    max_rel = rel_diff.max()

    print(f"[test] max_abs_diff = {max_diff:.6f}")
    print(f"[test] mean_abs_diff = {mean_diff:.6f}")
    print(f"[test] max_rel_diff = {max_rel:.6f}")

    if max_rel < args.tolerance:
        print(f"[test] PASS (max_rel_diff={max_rel:.6f} < tol={args.tolerance})")
    else:
        print(f"[test] FAIL (max_rel_diff={max_rel:.6f} >= tol={args.tolerance})")
        # Show first few mismatches
        flat_diff = abs_diff.flatten()
        worst_idx = np.argsort(flat_diff)[-10:]
        for idx in worst_idx:
            coords = np.unravel_index(idx, (oh, ow, oc))
            print(f"  [{coords}] got={result[coords]:.6f} expected={golden[coords]:.6f} diff={flat_diff[idx]:.6f}")
        sys.exit(1)


if __name__ == "__main__":
    main()
