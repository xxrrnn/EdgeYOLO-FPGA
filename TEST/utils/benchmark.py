"""Small, hardware-independent helpers shared by TOPS and TOPS/W tests."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def utc_now() -> str:
    """Return an ISO-8601 UTC timestamp suitable for test reports."""
    return datetime.now(timezone.utc).isoformat()


def calculate_tops(active_cycles: int, frequency_mhz: float, operations: int) -> float:
    """Calculate TOPS when multiply and add are counted as separate operations."""
    if operations <= 0:
        raise ValueError("operations must be positive")
    if active_cycles <= 0:
        raise ValueError("active_cycles must be positive")
    if frequency_mhz <= 0:
        raise ValueError("frequency_mhz must be positive")
    return operations * frequency_mhz * 1e6 / active_cycles / 1e12


def calculate_tops_per_watt(tops: float, power_w: float) -> float:
    """Calculate TOPS/W from a matched compute window and measured power."""
    if tops < 0:
        raise ValueError("tops must be non-negative")
    if power_w <= 0:
        raise ValueError("power_w must be positive")
    return tops / power_w


def write_json_report(path: Path, report: dict[str, Any]) -> Path:
    """Write a stable UTF-8 JSON report and return the resolved output path."""
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return path
