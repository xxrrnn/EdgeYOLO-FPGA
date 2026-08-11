"""Compatibility shim; the shared implementation lives in TEST.utils."""
from __future__ import annotations

import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from TEST.utils.xdma_win import *  # noqa: F401,F403,E402
