"""Compatibility shim; the shared implementation lives in TEST.utils."""
from __future__ import annotations

import importlib
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

_impl = importlib.import_module("TEST.utils.hbm_flow")
globals().update(
    {name: value for name, value in vars(_impl).items() if not name.startswith("__")}
)
