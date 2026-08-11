"""ResNet-only convenience entry point for the end-to-end suite."""
from __future__ import annotations

import runpy
import sys
from pathlib import Path


if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "run.py"
    sys.argv = [str(target), "--network", "resnet", *sys.argv[1:]]
    runpy.run_path(str(target), run_name="__main__")
