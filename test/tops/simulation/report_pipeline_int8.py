#!/usr/bin/env python3
"""Create an auditable sustained-pipeline TOPS report from the VCS log."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


CLOCK_MHZ = 250.0
CLOCK_PERIOD_NS = 1000.0 / CLOCK_MHZ


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=Path, required=True)
    args = parser.parse_args()
    run_dir = args.run_dir.resolve()
    manifest = json.loads((run_dir / "data/pipeline_manifest.json").read_text(encoding="utf-8"))
    log = (run_dir / "sim.log").read_text(encoding="utf-8", errors="replace")
    match = re.search(
        r"PIPELINE_METRIC batch_jobs=(\d+) issue_phases=(\d+) result_jobs=(\d+) "
        r"first_issue_cycle=(-?\d+) last_issue_cycle=(-?\d+) first_result_cycle=(-?\d+) "
        r"last_result_cycle=(-?\d+) mismatches=(\d+)",
        log,
    )
    if not match:
        raise SystemExit("missing PIPELINE_METRIC in sim.log")
    (
        batch_jobs,
        issue_phases,
        result_jobs,
        first_issue,
        last_issue,
        first_result,
        last_result,
        mismatches,
    ) = map(int, match.groups())

    operations_per_job = int(manifest["operations_mul_plus_add_per_job"])
    issue_span_cycles = last_issue - first_issue + 1
    result_span_cycles = last_result - first_result
    measured_ii = result_span_cycles / (result_jobs - 1) if result_jobs > 1 else float("inf")
    pipeline_latency_cycles = first_result - first_issue
    steady_tops = operations_per_job * CLOCK_MHZ * 1e6 / measured_ii / 1e12
    batch_cycles = last_result - first_issue + 1
    batch_tops = batch_jobs * operations_per_job / (batch_cycles * CLOCK_PERIOD_NS * 1e-9) / 1e12
    check_passed = "PIPELINE CHECK PASSED" in log
    passed = all(
        (
            check_passed,
            batch_jobs == int(manifest["batch_jobs"]),
            issue_phases == batch_jobs * int(manifest["phases_per_job"]),
            result_jobs == batch_jobs,
            mismatches == 0,
            issue_span_cycles == issue_phases,
            abs(measured_ii - float(manifest["expected_job_ii_cycles"])) < 1e-9,
            steady_tops >= 2.0,
        )
    )
    report = {
        "schema": "edgeyolo.dcim_pipeline_int8_report.v1",
        "status": "PASS" if passed else "FAIL",
        "clock_mhz": CLOCK_MHZ,
        "matrix_per_job": manifest["matrix_per_job"],
        "batch_jobs": batch_jobs,
        "operations_mul_plus_add_per_job": operations_per_job,
        "issue_phases": issue_phases,
        "issue_span_cycles": issue_span_cycles,
        "result_jobs": result_jobs,
        "result_span_cycles": result_span_cycles,
        "measured_result_ii_cycles": measured_ii,
        "pipeline_fill_latency_cycles": pipeline_latency_cycles,
        "steady_state_int8_tops": steady_tops,
        "fill_and_drain_batch_cycles": batch_cycles,
        "fill_and_drain_batch_tops": batch_tops,
        "mismatches": mismatches,
        "all_tiles_lockstep": "PIPELINE_ISSUE_SKEW" not in log and "PIPELINE_RESULT_SKEW" not in log,
        "no_input_bubbles": issue_span_cycles == issue_phases,
        "method_note": (
            "Steady-state TOPS is derived from the measured interval between distinct, "
            "numerically checked result jobs after pipeline fill. Transfer and weight-load "
            "time are excluded; all arithmetic pipeline stages remain included."
        ),
        "waveform_fsdb": str(run_dir / "tb_dcim_pipeline_peak.fsdb"),
        "simulation_log": str(run_dir / "sim.log"),
    }
    (run_dir / "pipeline_int8_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (run_dir / "pipeline_int8_report.md").write_text(
        "\n".join(
            [
                "# DCIM INT8 sustained-pipeline VCS report",
                "",
                f"- Status: **{report['status']}**",
                "- Exact-fit job: M=1, K=64, N=128; 8192 MAC = 16384 OP",
                f"- Batch: {batch_jobs} distinct activation vectors, all 8 tiles lock-step",
                f"- Input issue: {issue_phases} consecutive phase cycles, no bubbles={report['no_input_bubbles']}",
                f"- Pipeline fill latency: {pipeline_latency_cycles} cycles",
                f"- Measured steady-state result II: **{measured_ii:.3f} cycles/job**",
                f"- Steady-state peak: **{steady_tops:.3f} TOPS @ INT8**",
                f"- Fill+drain batch: {batch_cycles} cycles, {batch_tops:.3f} TOPS",
                f"- Numeric comparison: {result_jobs} jobs, mismatches={mismatches}",
                "- Evidence: `tb_dcim_pipeline_peak.fsdb`, `pipeline_signals.csv`, `sim.log`",
                "",
                report["method_note"],
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(
        f"PIPELINE INT8 {report['status']}: II={measured_ii:.3f} cycles/job, "
        f"steady={steady_tops:.3f} TOPS, latency={pipeline_latency_cycles} cycles"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
