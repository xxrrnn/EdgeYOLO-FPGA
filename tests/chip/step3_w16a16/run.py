#!/usr/bin/env python3
"""
step3_w16a16/run.py - W16A16 verification for both ResNet18 and YOLOv5n.

Usage:
    python tests/chip/step3_w16a16/run.py --dry-run
    python tests/chip/step3_w16a16/run.py --network resnet18
    python tests/chip/step3_w16a16/run.py --network yolov5n
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

from runtime.xdma_driver import XDMA, DryXDMA, ChipRunner


def compile_network(network: str, build_dir: Path):
    cmd = [
        sys.executable,
        str(REPO / "tests/chip/compiler/compile.py"),
        "--network", network,
        "--out", str(build_dir),
        "--full",
        "--mode", "int16",
        "--hw-caps", str(REPO / "tests/chip/compiler/lowering/hw_caps.yaml"),
    ]
    print(f"[compile] {' '.join(cmd)}")
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr, file=sys.stderr)
        raise RuntimeError(f"Compilation failed for {network}")
    print(r.stdout)


def make_test_input(network: str, seed: int = 42) -> np.ndarray:
    rng = np.random.default_rng(seed)
    if network == "resnet18":
        return rng.integers(0, 256, size=(224, 224, 3), dtype=np.uint8)
    else:
        return rng.integers(0, 256, size=(640, 640, 3), dtype=np.uint8)


def run_single(network: str, dry_run: bool, device: str, seed: int):
    build_dir = REPO / "build" / f"{network}_w16a16"
    compile_network(network, build_dir)

    plan = json.loads((build_dir / "plan.json").read_text())
    print(f"[{network}] W16A16 compiled: {plan['compile_meta']['num_conv_layers_compiled']} layers")
    print(f"[{network}] Output: {plan['host_io']['output_hw']}x{plan['host_io']['output_c']}")

    input_nhwc = make_test_input(network, seed)
    input_bin = input_nhwc.tobytes()

    XClass = DryXDMA if dry_run else XDMA
    with XClass(device) as xdma:
        runner = ChipRunner(xdma)
        result_bytes = runner.run_plan(build_dir, input_bin, timeout_s=120.0)

    oh, ow = plan["host_io"]["output_hw"]
    oc = plan["host_io"]["output_c"]
    result = np.frombuffer(result_bytes, dtype=np.float32).reshape(oh, ow, oc)
    print(f"[{network}] W16A16 result: {result.shape}, range=[{result.min():.4f}, {result.max():.4f}]")

    if dry_run:
        print(f"[{network}] W16A16 DRY RUN PASS")
        return True

    # Sanity
    assert not np.all(result == 0), "All-zero output"
    assert not np.any(np.isnan(result)), "NaN"
    assert not np.any(np.isinf(result)), "Inf"

    # Compare with W8A8 result if available
    w8_path = REPO / "build" / f"{network}_w8a8" / "output_features.npy"
    if w8_path.exists():
        w8_result = np.load(w8_path)
        if w8_result.shape == result.shape:
            diff = np.abs(result - w8_result)
            print(f"[{network}] W16 vs W8 max_diff={diff.max():.6f}, mean_diff={diff.mean():.6f}")
            # W16A16 should produce very similar results to W8A8
            # (same weights just sign-extended, higher precision accumulation)

    np.save(build_dir / "output_features.npy", result)
    print(f"[{network}] W16A16 PASS")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--network", default="both", choices=["resnet18", "yolov5n", "both"])
    ap.add_argument("--device", default="/dev/xdma0")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    networks = ["resnet18", "yolov5n"] if args.network == "both" else [args.network]
    all_pass = True
    for net in networks:
        ok = run_single(net, args.dry_run, args.device, args.seed)
        all_pass = all_pass and ok

    if all_pass:
        print("\n[W16A16] ALL PASS")
    else:
        print("\n[W16A16] SOME FAILED")
        sys.exit(1)


if __name__ == "__main__":
    main()
