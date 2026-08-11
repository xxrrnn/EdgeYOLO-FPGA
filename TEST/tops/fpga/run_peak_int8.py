#!/usr/bin/env python3
"""Run the 64-job streamed INT8 peak-compute case on a Windows XDMA FPGA.

The FPGA run proves numerical correctness.  The compute-active cycle count is
read manually from the Vivado ILA and supplied with --ila-active-cycles so the
TOPS calculation is performed and recorded by the host.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
GENERATOR = REPO_ROOT / "rtl" / "tb" / "lite_bd" / "module_tb" / "golden_module_tb.py"
UNIT_TB_DIR = REPO_ROOT / "tests" / "chip" / "unit-tb"
DEFAULT_RUN_DIR = REPO_ROOT / "output" / "tops" / "fpga_peak_int8"

MATRIX_M = 64
MATRIX_K = 64
MATRIX_N = 128
OPERATIONS_PER_ROUND = 2 * MATRIX_M * MATRIX_K * MATRIX_N
TOPS_REQUIREMENT = 2.0

EXPECTED_ILA_BASE = {
    "compute_mask": "0xff on every counted phase sample (64 jobs/round, II=2)",
    "input_phase0": "0xb92d4ab3",
    "input_phase1": "0xdb342919",
    "result_valid": "1 for the first Tile-0 output word",
    "result_data_when_valid": "0x00001778",
}

REQUIRED_CASE_FILES = (
    "inst.hex",
    "preload.txt",
    "checks.txt",
    "expected.hex",
    "act.hex",
    "weight_tile0.hex",
    "weight_tile7.hex",
    "manifest.txt",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def prepare_case(run_dir: Path, regenerate: bool, repeat_count: int) -> None:
    missing = [name for name in REQUIRED_CASE_FILES if not (run_dir / name).is_file()]
    if not regenerate and not missing:
        manifest = {}
        for line in (run_dir / "manifest.txt").read_text(encoding="utf-8").splitlines():
            key, sep, value = line.partition(":")
            if sep:
                manifest[key.strip()] = value.strip()
        if (int(manifest.get("matmul_m", 0)) == MATRIX_M and
                int(manifest.get("benchmark_repeat_count", 1)) == repeat_count):
            print(f"[prepare] Reusing {run_dir}")
            return
        print("[prepare] Existing vectors are from the obsolete single-job case; regenerating")

    run_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable,
        str(GENERATOR),
        "--module",
        "dcim_matmul",
        "--case",
        "peak_int8_all_tiles",
        "--seed",
        "123",
        "--verify-words",
        "0",
        "--out-dir",
        str(run_dir),
        "--benchmark-repeat",
        str(repeat_count),
    ]
    print("[prepare] Generating streamed M=64, K=64, N=128 INT8 case")
    subprocess.run(cmd, cwd=REPO_ROOT, check=True)

    missing = [name for name in REQUIRED_CASE_FILES if not (run_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(f"generated case is incomplete: {', '.join(missing)}")


def calculate_tops(active_cycles: int, frequency_mhz: float, operations: int) -> float:
    if active_cycles <= 0:
        raise ValueError("ILA active cycles must be positive")
    if frequency_mhz <= 0:
        raise ValueError("frequency must be positive")
    return operations * frequency_mhz * 1e6 / active_cycles / 1e12


def write_report(report_path: Path, report: dict) -> None:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    tops = report.get("calculated_peak_tops")
    cycles = report.get("ila_active_cycles")
    tops_text = "pending ILA cycle entry" if tops is None else f"{tops:.6f} TOPS"
    cycles_text = "pending" if cycles is None else str(cycles)
    host_results = report.get("host_results", [])
    verified = sum(int(item.get("passed", 0)) for item in host_results)
    total = sum(int(item.get("total_words", 0)) for item in host_results)

    md_path = report_path.with_suffix(".md")
    md_lines = [
        "# FPGA peak INT8 report",
        "",
        f"- Status: **{report['status']}**",
        f"- Matrix: M={MATRIX_M}, K={MATRIX_K}, N={MATRIX_N}",
        f"- Repeat rounds: {report['benchmark_repeat_count']}",
        f"- Operations: {report['operations']} (multiply and add counted separately)",
        f"- Host correctness: {verified}/{total} 128-bit words",
        f"- ILA all-Tile active cycles: {cycles_text}",
        f"- Clock: {report['frequency_mhz']:.6f} MHz",
        f"- Peak compute: **{tops_text}**",
        "",
        "TOPS is valid only when every counted sample has `peak_compute_mask == 0xff`.",
        "Data transfer, loading and writeback cycles are intentionally excluded.",
        "",
        "## Expected ILA evidence",
        "",
        "| Signal | Expected value |",
        "|---|---|",
    ]
    md_lines.extend(
        f"| `{name}` | `{value}` |"
        for name, value in report["expected_ila"].items()
    )
    md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    print(f"[report] {report_path}")
    print(f"[report] {md_path}")


def load_previous_report(report_path: Path) -> dict:
    if not report_path.is_file():
        raise FileNotFoundError(
            f"no previous FPGA report at {report_path}; run without --report-only first"
        )
    return json.loads(report_path.read_text(encoding="utf-8"))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run and report the exact-fit 2.048-TOPS INT8 FPGA case"
    )
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--regenerate", action="store_true", help="regenerate test vectors")
    parser.add_argument("--prepare-only", action="store_true", help="only generate test files")
    parser.add_argument(
        "--report-only",
        action="store_true",
        help="do not touch FPGA; add the observed ILA cycles to the previous report",
    )
    parser.add_argument(
        "--ila-active-cycles",
        type=int,
        default=None,
        help="number of ILA samples for which peak_compute_mask is exactly 0xff",
    )
    parser.add_argument("--frequency-mhz", type=float, default=250.0)
    parser.add_argument(
        "--repeat-count",
        type=int,
        default=None,
        help="seamless 64-job benchmark rounds; 1 selects normal one-shot mode",
    )
    parser.add_argument("--timeout-s", type=float, default=60.0)
    parser.add_argument("--quiet-xdma", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    run_dir = args.run_dir.resolve()
    report_path = run_dir / "fpga_peak_report.json"

    if args.prepare_only and args.report_only:
        raise SystemExit("--prepare-only and --report-only are mutually exclusive")

    if args.report_only:
        if args.ila_active_cycles is None:
            raise SystemExit("--report-only requires --ila-active-cycles from the ILA capture")
        report = load_previous_report(report_path)
        repeat_count = int(report.get("benchmark_repeat_count", 1))
        if args.repeat_count is not None and args.repeat_count != repeat_count:
            raise SystemExit("--repeat-count must match the previously generated FPGA run")
    else:
        repeat_count = 1 if args.repeat_count is None else args.repeat_count
        if repeat_count < 1:
            raise SystemExit("--repeat-count must be >= 1")
        prepare_case(run_dir, args.regenerate, repeat_count)
        if args.prepare_only:
            print(f"Prepared FPGA peak case: {run_dir}")
            return 0
        if os.name != "nt":
            raise SystemExit("the FPGA runner requires Windows and the XDMA driver")

        if str(UNIT_TB_DIR) not in sys.path:
            sys.path.insert(0, str(UNIT_TB_DIR))
        from xdma_win import ChipRunnerWin  # pylint: disable=import-outside-toplevel

        print("[fpga] ILA must be armed before this point (trigger: peak_compute_mask == 0xff)")
        try:
            results = ChipRunnerWin(verbose=not args.quiet_xdma).run_case(
                run_dir,
                timeout_s=args.timeout_s,
                staging="hbm",
                verify=True,
            )
            host_pass = all(bool(item.get("pass")) for item in results)
            error = None
        except Exception as exc:  # preserve a machine-readable failure report
            results = []
            host_pass = False
            error = f"{type(exc).__name__}: {exc}"

        report = {
            "schema": "edgeyolo.fpga_peak_int8.v1",
            "generated_at": utc_now(),
            "run_dir": str(run_dir),
            "matrix": {"m": MATRIX_M, "k": MATRIX_K, "n": MATRIX_N},
            "benchmark_repeat_count": repeat_count,
            "operations": OPERATIONS_PER_ROUND * repeat_count,
            "host_correctness_pass": host_pass,
            "host_results": results,
            "error": error,
            "expected_ila": {
                **EXPECTED_ILA_BASE,
                "active_span": f"{128 * repeat_count} consecutive cycles with no gap",
                "round_wrap": "job 63 phase 1 -> job 0 phase 0 on adjacent clocks",
            },
        }

    host_pass = bool(report.get("host_correctness_pass"))
    report["updated_at"] = utc_now()
    report["frequency_mhz"] = args.frequency_mhz
    report["ila_active_cycles"] = args.ila_active_cycles
    report["ila_cycle_qualification"] = "count only samples where peak_compute_mask == 0xff"

    if args.ila_active_cycles is None:
        report["calculated_peak_tops"] = None
        report["meets_2tops"] = None
        report["status"] = "PASS_HOST_PENDING_ILA" if host_pass else "FAIL_HOST"
    else:
        tops = calculate_tops(
            args.ila_active_cycles,
            args.frequency_mhz,
            int(report["operations"]),
        )
        report["calculated_peak_tops"] = tops
        report["meets_2tops"] = tops >= TOPS_REQUIREMENT
        if not host_pass:
            report["status"] = "FAIL_HOST"
        elif tops >= TOPS_REQUIREMENT:
            report["status"] = "PASS"
        else:
            report["status"] = "FAIL_TOPS"

    write_report(report_path, report)

    if report["status"] == "PASS_HOST_PENDING_ILA":
        print("\nHost result PASS. Export/check the ILA waveform, then run:")
        expected_cycles = 128 * int(report.get("benchmark_repeat_count", 1))
        print(
            f'  python "{Path(__file__).resolve()}" --report-only '
            f'--ila-active-cycles {expected_cycles}'
        )
    elif report.get("calculated_peak_tops") is not None:
        print(f"\nCalculated peak: {report['calculated_peak_tops']:.6f} TOPS")
    if report.get("error"):
        print(f"\nFPGA error: {report['error']}", file=sys.stderr)

    return 0 if report["status"] in ("PASS", "PASS_HOST_PENDING_ILA") else 1


if __name__ == "__main__":
    raise SystemExit(main())
