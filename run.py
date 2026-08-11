"""Compatibility entry point for the organized end-to-end test suite."""
from __future__ import annotations

import runpy
from pathlib import Path


if __name__ == "__main__":
    runpy.run_path(
        str(Path(__file__).resolve().parent / "TEST" / "end2end" / "run.py"),
        run_name="__main__",
    )
