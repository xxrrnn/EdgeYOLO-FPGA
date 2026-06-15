"""
gen_data.py - Generate on-chip test data by invoking module_tb's golden_module_tb.py

This module provides a Python interface to generate test vectors for any
module_tb case/variant, producing the same inst.hex / preload.txt / checks.txt /
expected.hex that VCS simulation uses — but for on-chip execution via XDMA.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Optional

_THIS_DIR = Path(__file__).resolve().parent
REPO_ROOT = _THIS_DIR.parent.parent.parent
MODULE_TB_DIR = REPO_ROOT / "rtl" / "tb" / "lite_bd" / "module_tb"
GOLDEN_PY = MODULE_TB_DIR / "golden_module_tb.py"
OUTPUT_BASE = _THIS_DIR / "runs"


def generate_case(
    module_case: str,
    module_variant: str,
    quant: str = "int8",
    output_dir: Optional[Path] = None,
    dim: Optional[str] = None,
) -> Path:
    """Generate golden test data for one case.

    Calls golden_module_tb.py with the specified parameters and writes output
    to a run directory.

    Returns:
        Path to the run directory containing inst.hex, preload.txt, checks.txt, etc.
    """
    if output_dir is None:
        slug = f"{module_case}_{module_variant}_q{quant}"
        if dim:
            slug += f"_{dim.replace(',', '_').replace('=', '')}"
        output_dir = OUTPUT_BASE / slug
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        sys.executable, str(GOLDEN_PY),
        "--module", module_case,
        "--case", module_variant,
        "--quant", quant,
        "--out-dir", str(output_dir),
    ]
    if dim:
        cmd.extend(["--dim", dim])

    env = os.environ.copy()
    env["PYTHONPATH"] = str(REPO_ROOT / "tools") + os.pathsep + env.get("PYTHONPATH", "")

    print(f"[gen] Generating: {module_case}/{module_variant} (quant={quant})")
    print(f"[gen] Output dir: {output_dir}")
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)

    if result.returncode != 0:
        print(f"[gen] STDERR:\n{result.stderr}")
        raise RuntimeError(
            f"golden_module_tb.py failed (rc={result.returncode}): {result.stderr[:500]}"
        )
    if result.stdout:
        print(f"[gen] {result.stdout.rstrip()}")

    # Verify essential outputs exist
    for required in ["inst.hex", "preload.txt", "checks.txt"]:
        if not (output_dir / required).exists():
            raise FileNotFoundError(
                f"Expected output {required} not found in {output_dir}. "
                f"Stdout: {result.stdout[:200]}"
            )

    print(f"[gen] Done. Files: {[f.name for f in output_dir.iterdir()]}")
    return output_dir


def list_cases(module_case: str) -> list[str]:
    """List available variants for a given module case."""
    cmd = [sys.executable, str(GOLDEN_PY), "--module", module_case, "--case", "list"]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(REPO_ROOT / "tools") + os.pathsep + env.get("PYTHONPATH", "")
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        raise RuntimeError(f"list_cases failed: {result.stderr[:300]}")
    return [l.strip() for l in result.stdout.splitlines() if l.strip()]


def list_modules() -> list[str]:
    """Return known module case names."""
    return [
        "dcim_matmul", "dqa", "qa", "im2col", "mp", "us", "add",
        "conv_pipeline", "mini_network", "concat_by_cdma", "cdma_memtest",
    ]
