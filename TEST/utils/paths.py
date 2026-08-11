"""Canonical repository paths shared by all test branches.

Test scripts should import these constants instead of relying on a fixed number
of ``Path.parents`` hops.  That keeps TOPS, TOPS/W, and end-to-end scripts
portable when their own subdirectories change.
"""
from __future__ import annotations

from pathlib import Path


UTILS_ROOT = Path(__file__).resolve().parent
TEST_ROOT = UTILS_ROOT.parent
REPO_ROOT = TEST_ROOT.parent
END2END_ROOT = TEST_ROOT / "end2end"
END2END_COMMON_ROOT = END2END_ROOT / "common"
UNIT_TB_ROOT = END2END_COMMON_ROOT / "unit_tb"
COMPILER_ROOT = END2END_COMMON_ROOT / "compiler"
RUNTIME_ROOT = END2END_COMMON_ROOT / "runtime"
BITSTREAM_ROOT = UTILS_ROOT / "bitstream"
BIN_ROOT = UTILS_ROOT / "bin"
RTL_CASE_GENERATOR = (
    REPO_ROOT / "rtl" / "tb" / "lite_bd" / "module_tb" / "golden_module_tb.py"
)
OUTPUT_ROOT = REPO_ROOT / "output"


def repo_path(*parts: str) -> Path:
    """Return an absolute path below the repository root."""
    return REPO_ROOT.joinpath(*parts)
