#!/usr/bin/env python3
"""Launch the two-job Verilator sim from Windows/WSL without CRLF or PowerShell $ expansion."""
import os
import pathlib
import subprocess
import sys

repo = pathlib.Path("/mnt/e/work2026/runnan_xu/FPGA/EdgeYOLO-FPGA")
src = repo / "TEST/tops/simulation/run_dcim_two_job_verilator.sh"
text = src.read_text(encoding="utf-8").replace("\r", "")
dst = pathlib.Path("/tmp/run_dcim_two_job_verilator.sh")
dst.write_text(text, encoding="utf-8")
dst.chmod(0o755)

env = os.environ.copy()
env["REPO_ROOT"] = str(repo)
if len(sys.argv) >= 2:
    env["TWO_JOB_PIXELS"] = sys.argv[1]
else:
    env.setdefault("TWO_JOB_PIXELS", "70")
if len(sys.argv) >= 3:
    env["TWO_JOB_ACC"] = sys.argv[2]
else:
    env.setdefault("TWO_JOB_ACC", "3")
if len(sys.argv) >= 4:
    env["RUN_DIR"] = sys.argv[3]
else:
    env.setdefault("RUN_DIR", "/tmp/two_job_verilator")
if len(sys.argv) >= 5:
    env["CASE_DIR"] = sys.argv[4]
print(
    "launch TWO_JOB_PIXELS=%s TWO_JOB_ACC=%s RUN_DIR=%s CASE_DIR=%s"
    % (
        env["TWO_JOB_PIXELS"],
        env["TWO_JOB_ACC"],
        env.get("RUN_DIR", ""),
        env.get("CASE_DIR", ""),
    ),
    flush=True,
)
sys.exit(subprocess.call(["bash", str(dst)], env=env))
