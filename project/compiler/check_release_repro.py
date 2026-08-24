#!/usr/bin/env python3
"""Compile every maintained workload twice and verify deterministic binaries."""
from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
COMPILER = REPO / "project" / "compiler" / "compile.py"

CASES = (
    ("yolo_coco_int8", "yolov5n", "int8", "project/model/yolov5n_coco50k_qat/parsed_int8"),
    ("yolo_coco_int16_native", "yolov5n", "int16", "project/model/yolov5n_coco50k_qat/parsed_int16"),
    ("resnet18_int8", "resnet18", "int8", "project/model/resnet18/parsed_vai"),
    ("resnet18_int16_widened", "resnet18", "int16", "project/model/resnet18/parsed_vai_int16_widened"),
)
FILES = ("program.bin", "weights.bin", "wb.bin")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def compile_case(out_dir: Path, network: str, mode: str, parsed: str) -> None:
    cmd = [
        sys.executable,
        str(COMPILER),
        "--network", network,
        "--mode", mode,
        "--full",
        "--parsed", str(REPO / parsed),
        "--out", str(out_dir),
    ]
    if "widened" in parsed:
        cmd.append("--allow-widened-int16")
    subprocess.run(
        cmd,
        cwd=REPO,
        check=True,
    )


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="edgeyolo-compile-repro-") as temp:
        temp_root = Path(temp)
        for name, network, mode, parsed in CASES:
            first = temp_root / name / "first"
            second = temp_root / name / "second"
            compile_case(first, network, mode, parsed)
            compile_case(second, network, mode, parsed)
            mismatches = [item for item in FILES if sha256(first / item) != sha256(second / item)]
            if mismatches:
                print(f"FAIL {name}: non-deterministic {', '.join(mismatches)}", file=sys.stderr)
                return 1
            print(f"PASS {name}: program/weights/wb compiled twice byte-identically")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
