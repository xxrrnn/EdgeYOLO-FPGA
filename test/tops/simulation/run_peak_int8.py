#!/usr/bin/env python3
"""Run the peak-INT8 VCS/FSDB test on a remote EDA server."""

from __future__ import annotations

import argparse
import io
import json
import shlex
import subprocess
import sys
import tarfile
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
LOCAL_TB = REPO_ROOT / "project" / "rtl" / "tb" / "lite_bd" / "module_tb" / "tb_lite_bd_module.sv"
LOCAL_VERDI_TCL = Path(__file__).resolve().parent / "verdi_peak.tcl"
LOCAL_FSDB_CFG = Path(__file__).resolve().parent / "fsdb_peak_signals.cfg"
LOCAL_CAPTURE_SH = Path(__file__).resolve().parent / "capture_verdi_peak.sh"
DEFAULT_REMOTE_REPO = "/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila"
REMOTE_RUN_REL = "rtl/tb/lite_bd/module_tb/sim/run_peak_int8_all_tiles"
LOCAL_OUTPUT = REPO_ROOT / "test" / "tops" / "output" / "simulation" / "vcs"

SYNC_ASSETS = (
    (REPO_ROOT / "rtl/tb/lite_bd/module_tb/Makefile", "rtl/tb/lite_bd/module_tb/Makefile"),
    (
        REPO_ROOT / "rtl/tb/lite_bd/module_tb/sim/run_module_sim.sh",
        "rtl/tb/lite_bd/module_tb/sim/run_module_sim.sh",
    ),
    (LOCAL_TB, "rtl/tb/lite_bd/module_tb/tb_lite_bd_module.sv"),
    (
        REPO_ROOT / "rtl/tb/lite_bd/sim/gen_bd_rtl_extra.sh",
        "rtl/tb/lite_bd/sim/gen_bd_rtl_extra.sh",
    ),
    (REPO_ROOT / "rtl/tb/lite_bd/lite_addrmap.svh", "rtl/tb/lite_bd/lite_addrmap.svh"),
    (REPO_ROOT / "rtl/tb/lite_bd/lite_bd_hier.svh", "rtl/tb/lite_bd/lite_bd_hier.svh"),
    (REPO_ROOT / "scripts/chip-lite/export_sim.tcl", "scripts/chip-lite/export_sim.tcl"),
    (LOCAL_VERDI_TCL, "test/tops/simulation/verdi_peak.tcl"),
    (LOCAL_FSDB_CFG, "test/tops/simulation/fsdb_peak_signals.cfg"),
    (LOCAL_CAPTURE_SH, "test/tops/simulation/capture_verdi_peak.sh"),
)

SMALL_ARTIFACTS = (
    "peak_int8_report.json",
    "peak_int8_report.md",
    "peak_int8_waveform.svg",
    "sim.log",
    "manifest.txt",
    "expected.hex",
    "act.hex",
    "peak_signals.csv",
    "peak_verdi.png",
    "verdi_peak.log",
)


def run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess:
    print("  $ " + " ".join(shlex.quote(part) for part in cmd), flush=True)
    return subprocess.run(cmd, cwd=REPO_ROOT, check=check)


def remote(server: str, shell_command: str) -> None:
    run(["ssh", server, "bash", "-lc", shlex.quote(shell_command)])


def sync_test_assets(server: str, remote_repo: str) -> None:
    missing = [str(path) for path, _ in SYNC_ASSETS if not path.is_file()]
    if missing:
        raise FileNotFoundError("missing VCS sync asset(s): " + ", ".join(missing))

    archive_buffer = io.BytesIO()
    with tarfile.open(fileobj=archive_buffer, mode="w:gz") as archive:
        for local_path, remote_rel in SYNC_ASSETS:
            archive.add(local_path, arcname=remote_rel)

    normalize = " ".join(
        shlex.quote(remote_rel)
        for _, remote_rel in SYNC_ASSETS
        if Path(remote_rel).suffix in {".sh", ".tcl", ".cfg"}
    )
    shell_command = (
        f"set -euo pipefail; mkdir -p {shlex.quote(remote_repo)}; "
        f"tar -xzf - -C {shlex.quote(remote_repo)}; "
        f"cd {shlex.quote(remote_repo)}; sed -i 's/\\r$//' {normalize}"
    )
    cmd = ["ssh", server, "bash", "-lc", shlex.quote(shell_command)]
    print("  $ ssh ... tar -xzf - [VCS/FSDB test assets]", flush=True)
    subprocess.run(cmd, cwd=REPO_ROOT, input=archive_buffer.getvalue(), check=True)


def run_vcs(server: str, remote_repo: str, build_tag: str, export: bool) -> None:
    commands = [
        "set -euo pipefail",
        f"cd {shlex.quote(remote_repo)}",
        "export PATH=/data/home/rn_xu29/miniconda3/envs/rtl/bin:$PATH",
        "export XILINX_VCS_LIB=${XILINX_VCS_LIB:-/data/home/rn_xu29/Tools/vcs_lib}",
        f"export BUILD_TAG={shlex.quote(build_tag)}",
    ]
    if export:
        commands.append(
            "SIMULATOR=vcs make -C rtl/tb/lite_bd/module_tb export"
        )
    commands.append("make -C rtl/tb/lite_bd/module_tb peak-int8")
    fsdb = f"{remote_repo}/{REMOTE_RUN_REL}/tb_lite_bd_module.fsdb"
    csv = f"{remote_repo}/{REMOTE_RUN_REL}/peak_signals.csv"
    cfg = f"{remote_repo}/test/tops/simulation/fsdb_peak_signals.cfg"
    commands.append(
        f"fsdbreport {shlex.quote(fsdb)} -f {shlex.quote(cfg)} "
        f"-csv -o {shlex.quote(csv)}"
    )
    remote(server, "; ".join(commands))


def capture_verdi(server: str, remote_repo: str) -> None:
    run_dir = f"{remote_repo}/{REMOTE_RUN_REL}"
    script = f"{remote_repo}/test/tops/simulation/capture_verdi_peak.sh"
    command = (
        "set -euo pipefail; "
        f"cd {shlex.quote(remote_repo)}; "
        f"bash {shlex.quote(script)} {shlex.quote(run_dir)}"
    )
    remote(server, command)


def fetch_artifacts(
    server: str, remote_repo: str, local_output: Path, download_fsdb: bool
) -> None:
    local_output.mkdir(parents=True, exist_ok=True)
    remote_run = f"{remote_repo}/{REMOTE_RUN_REL}"
    archive_path = local_output / "vcs_peak_artifacts.tar.gz"
    names = " ".join(shlex.quote(name) for name in SMALL_ARTIFACTS)
    shell_command = f"cd {shlex.quote(remote_run)} && tar -czf - {names}"
    cmd = ["ssh", server, "bash", "-lc", shlex.quote(shell_command)]
    print("  $ ssh ... tar -czf - [VCS peak artifacts]", flush=True)
    with archive_path.open("wb") as archive_file:
        subprocess.run(cmd, cwd=REPO_ROOT, check=True, stdout=archive_file)
    with tarfile.open(archive_path, "r:gz") as archive:
        archive.extractall(local_output, filter="data")
    if download_fsdb:
        run(
            [
                "scp",
                f"{server}:{remote_run}/tb_lite_bd_module.fsdb",
                str(local_output / "tb_lite_bd_module.fsdb"),
            ]
        )


def open_verdi(server: str, remote_repo: str) -> int:
    fsdb = f"{remote_repo}/{REMOTE_RUN_REL}/tb_lite_bd_module.fsdb"
    play = f"{remote_repo}/test/tops/simulation/verdi_peak.tcl"
    command = f"verdi -ssf {shlex.quote(fsdb)} -play {shlex.quote(play)} -nologo"
    print("Close Verdi to return to this script.")
    return run(["ssh", "-Y", server, "bash", "-lc", shlex.quote(command)], check=False).returncode


def summarize(local_output: Path, server: str, remote_repo: str) -> dict:
    source_path = local_output / "peak_int8_report.json"
    if not source_path.is_file():
        raise FileNotFoundError(f"missing fetched VCS report: {source_path}")
    source = json.loads(source_path.read_text(encoding="utf-8"))
    summary = {
        "schema": "edgeyolo.vcs_peak_int8.v1",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "status": source.get("status", "UNKNOWN"),
        "server": server,
        "remote_repo": remote_repo,
        "remote_fsdb": f"{remote_repo}/{REMOTE_RUN_REL}/tb_lite_bd_module.fsdb",
        "local_report": str(source_path),
        "local_fsdb_signal_csv": str(local_output / "peak_signals.csv"),
        "matrix": {
            "m": source.get("matmul_m"),
            "k": source.get("matmul_k"),
            "n": source.get("matmul_n"),
        },
        "active_cycles": source.get("active_cycles"),
        "frequency_mhz": source.get("clock_mhz", 250.0),
        "peak_tops": source.get("peak_tops"),
        "all_tiles_simultaneous": source.get("all_tiles_simultaneous"),
        "module_check_passed": source.get("module_check_passed"),
        "verdi_signal_set": [
            "tb_aclk",
            "peak_int8_array_start",
            "peak_int8_array_done",
            "peak_int8_compute_fire[7:0]",
            "peak_int8_tile0_state[3:0]",
            "peak_int8_tile0_phase[1:0]",
            "peak_int8_tile0_input[31:0]",
            "peak_int8_result_valid",
            "peak_int8_result_data[31:0]",
        ],
        "full_source": source,
    }
    out_path = local_output / "vcs_peak_int8_summary.json"
    out_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"\nSummary: {out_path}")
    return summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Remote VCS + FSDB peak-INT8 verification")
    parser.add_argument("--server", default="eda02", help="OpenSSH host alias")
    parser.add_argument("--remote-repo", default=DEFAULT_REMOTE_REPO)
    parser.add_argument("--build-tag", default="tops_ila_native16_3b9bb06")
    parser.add_argument("--export", action="store_true", help="run Vivado VCS export first")
    parser.add_argument("--reuse", action="store_true", help="skip VCS and fetch existing results")
    parser.add_argument("--no-sync", action="store_true", help="do not upload TB/Verdi assets")
    parser.add_argument("--no-fetch", action="store_true")
    parser.add_argument("--download-fsdb", action="store_true")
    parser.add_argument("--open-verdi", action="store_true", help="open remote Verdi over X11")
    parser.add_argument("--local-output", type=Path, default=LOCAL_OUTPUT)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.no_sync:
        sync_test_assets(args.server, args.remote_repo)
    if not args.reuse:
        run_vcs(args.server, args.remote_repo, args.build_tag, args.export)
    capture_verdi(args.server, args.remote_repo)
    if not args.no_fetch:
        fetch_artifacts(
            args.server,
            args.remote_repo,
            args.local_output.resolve(),
            args.download_fsdb,
        )
        summary = summarize(args.local_output.resolve(), args.server, args.remote_repo)
        if summary["status"] != "PASS":
            return 1
    if args.open_verdi:
        return open_verdi(args.server, args.remote_repo)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
