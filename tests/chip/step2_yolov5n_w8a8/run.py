#!/usr/bin/env python3
"""
step2_yolov5n_w8a8/run.py - YOLOv5n W8A8 full network board test (to model.23).

Usage:
    python tests/chip/step2_yolov5n_w8a8/run.py --dry-run
    python tests/chip/step2_yolov5n_w8a8/run.py
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


def compile_yolov5n(build_dir: Path, mode: str = "int8"):
    cmd = [
        sys.executable,
        str(REPO / "tests/chip/compiler/compile.py"),
        "--network", "yolov5n",
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


def make_test_input(h=640, w=640, c=3, seed=42) -> np.ndarray:
    rng = np.random.default_rng(seed)
    return rng.integers(0, 256, size=(h, w, c), dtype=np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--build-dir", default=str(REPO / "build" / "yolov5n_w8a8"))
    ap.add_argument("--device", default="/dev/xdma0")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--skip-compile", action="store_true")
    args = ap.parse_args()

    build_dir = Path(args.build_dir)

    if not args.skip_compile:
        compile_yolov5n(build_dir, mode="int8")

    plan = json.loads((build_dir / "plan.json").read_text())
    print(f"[test] Plan: {plan['compile_meta']['num_conv_layers_compiled']} conv layers")
    print(f"[test] Output: {plan['host_io']['output_hw']}x{plan['host_io']['output_c']} "
          f"@ OBUF[0x{plan['host_io']['output_obuf_off']:x}]")

    input_nhwc = make_test_input(seed=args.seed)
    input_bin = input_nhwc.tobytes()
    print(f"[test] Input: {input_nhwc.shape} UINT8, {len(input_bin)} bytes")

    XClass = DryXDMA if args.dry_run else XDMA
    with XClass(args.device) as xdma:
        runner = ChipRunner(xdma)
        result_bytes = runner.run_plan(build_dir, input_bin, timeout_s=120.0)

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

    # Sanity checks
    assert result.shape == (oh, ow, oc), f"Shape mismatch: {result.shape}"
    assert not np.all(result == 0), "All-zero output"
    assert not np.any(np.isnan(result)), "NaN in output"
    assert not np.any(np.isinf(result)), "Inf in output"

    # Save output (the 3 FPN/PAN feature maps would be at different OBUF offsets
    # but for the static schedule, the final output is model.23's output)
    np.save(build_dir / "output_features.npy", result)
    print(f"[test] Saved to {build_dir}/output_features.npy")
    print("[test] PASS (sanity checks)")
    print("[test] NOTE: detect head (model.24) processing should be done on host")


if __name__ == "__main__":
    main()
