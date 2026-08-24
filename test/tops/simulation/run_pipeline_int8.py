#!/usr/bin/env python3
"""One-command remote VCS/FSDB runner for the sustained DCIM pipeline proof."""

from __future__ import annotations

import argparse
import io
import shlex
import subprocess
import tarfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_REMOTE_REPO = "/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila"
LOCAL_OUTPUT = REPO_ROOT / "test" / "tops" / "output" / "simulation" / "pipeline_vcs"

TEST_ASSETS = (
    "gen_pipeline_int8.py",
    "report_pipeline_int8.py",
    "run_dcim_pipeline_vcs.sh",
    "tb_dcim_pipeline_peak.sv",
    "fsdb_pipeline_signals.cfg",
    "verdi_pipeline.tcl",
    "capture_verdi_pipeline.sh",
)
RTL_ASSETS = (
    "rtl/ref/DCIM/src/inc/para.v",
    "rtl/ref/DCIM/src/inc/counter.v",
    "rtl/ref/DCIM/src/inc/dff.v",
    "rtl/ref/DCIM/src/inc/pipe_stage.v",
    "rtl/ref/DCIM/src/dcim/multiplier.v",
    "rtl/ref/DCIM/src/dcim/multiplier_dsp.v",
    "rtl/ref/DCIM/src/dcim/adderTree.v",
    "rtl/ref/DCIM/src/dcim/maArray.v",
    "rtl/ref/DCIM/src/dcim/calculate_core.v",
    "rtl/ref/DCIM/src/dcim/mergeArray.v",
    "rtl/ref/DCIM/src/dcim/accumulateArray.v",
    "rtl/ref/DCIM/src/dcim/postProcess.v",
    "rtl/tb/lite_bd/sim/vcs_common.sh",
)
ARTIFACTS = (
    "pipeline_int8_report.json",
    "pipeline_int8_report.md",
    "pipeline_signals.csv",
    "pipeline_fill_verdi.png",
    "pipeline_steady_verdi.png",
    "sim.log",
    "compile.log",
    "vlogan.log",
    "tb_dcim_pipeline_peak.fsdb",
)


def run(command: list[str], *, input_bytes: bytes | None = None) -> None:
    print("  $ " + " ".join(shlex.quote(part) for part in command), flush=True)
    subprocess.run(command, cwd=REPO_ROOT, input=input_bytes, check=True)


def remote(server: str, command: str) -> None:
    run(["ssh", server, "bash", "-lc", shlex.quote(command)])


def sync_assets(server: str, remote_repo: str) -> None:
    assets = [
        (SCRIPT_DIR / name, f"test/tops/simulation/{name}") for name in TEST_ASSETS
    ] + [(REPO_ROOT / name, name) for name in RTL_ASSETS]
    missing = [str(path) for path, _ in assets if not path.is_file()]
    if missing:
        raise FileNotFoundError("missing pipeline asset(s): " + ", ".join(missing))
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
        for local_path, remote_path in assets:
            archive.add(local_path, arcname=remote_path)
    normalize = " ".join(
        shlex.quote(remote_path)
        for _, remote_path in assets
        if Path(remote_path).suffix in {".sh", ".tcl", ".cfg"}
    )
    command = (
        f"set -e; mkdir -p {shlex.quote(remote_repo)}; "
        f"tar -xzf - -C {shlex.quote(remote_repo)}; "
        f"cd {shlex.quote(remote_repo)}; sed -i 's/\\r$//' {normalize}"
    )
    run(
        ["ssh", server, "bash", "-lc", shlex.quote(command)],
        input_bytes=buffer.getvalue(),
    )


def capture(server: str, remote_repo: str) -> None:
    run_dir = "test/tops/output/simulation/pipeline_vcs"
    command = "; ".join(
        (
            "set -e",
            f"cd {shlex.quote(remote_repo)}",
            f"fsdbreport {run_dir}/tb_dcim_pipeline_peak.fsdb "
            f"-f test/tops/simulation/fsdb_pipeline_signals.cfg "
            f"-csv -o {run_dir}/pipeline_signals.csv",
            f"PIPELINE_WAVE_BEGIN_NS=44 PIPELINE_WAVE_END_NS=190 "
            f"bash test/tops/simulation/capture_verdi_pipeline.sh {run_dir} "
            f"{run_dir}/pipeline_fill_verdi.png",
            f"PIPELINE_WAVE_BEGIN_NS=105 PIPELINE_WAVE_END_NS=225 "
            f"bash test/tops/simulation/capture_verdi_pipeline.sh {run_dir} "
            f"{run_dir}/pipeline_steady_verdi.png",
        )
    )
    remote(server, command)


def fetch(server: str, remote_repo: str, local_output: Path) -> None:
    local_output.mkdir(parents=True, exist_ok=True)
    remote_run = f"{remote_repo}/test/tops/output/simulation/pipeline_vcs"
    names = " ".join(shlex.quote(name) for name in ARTIFACTS)
    command = f"cd {shlex.quote(remote_run)} && tar -czf - {names}"
    archive_bytes = subprocess.check_output(
        ["ssh", server, "bash", "-lc", shlex.quote(command)], cwd=REPO_ROOT
    )
    with tarfile.open(fileobj=io.BytesIO(archive_bytes), mode="r:gz") as archive:
        archive.extractall(local_output, filter="data")
    print(f"Artifacts: {local_output}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Remote DCIM pipeline VCS proof")
    parser.add_argument("--server", default="eda02")
    parser.add_argument("--remote-repo", default=DEFAULT_REMOTE_REPO)
    parser.add_argument("--reuse", action="store_true", help="reuse existing VCS/FSDB result")
    parser.add_argument("--no-sync", action="store_true")
    parser.add_argument("--no-capture", action="store_true")
    parser.add_argument("--local-output", type=Path, default=LOCAL_OUTPUT)
    args = parser.parse_args()
    if not args.no_sync:
        sync_assets(args.server, args.remote_repo)
    if not args.reuse:
        remote(
            args.server,
            f"cd {shlex.quote(args.remote_repo)} && "
            "bash test/tops/simulation/run_dcim_pipeline_vcs.sh",
        )
    if not args.no_capture:
        capture(args.server, args.remote_repo)
    fetch(args.server, args.remote_repo, args.local_output.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
