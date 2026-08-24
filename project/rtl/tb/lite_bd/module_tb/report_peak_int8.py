#!/usr/bin/env python3
"""Build an auditable peak-INT8 report from a simulator log and case manifest."""

from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path


CLOCK_MHZ = 250.0
CLOCK_PERIOD_NS = 1000.0 / CLOCK_MHZ
INT8_PHASES_PER_MAC = 2


def read_manifest(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        key, sep, value = raw.partition(":")
        if sep:
            result[key.strip()] = value.strip()
    return result


def parse_log(path: Path) -> tuple[dict[str, int], list[dict[str, int]], bool]:
    text = path.read_text(encoding="utf-8", errors="replace")
    metric_match = re.search(
        r"PEAK_INT8_METRIC tiles=(\d+) any_cycles=(\d+) all_cycles=(\d+) "
        r"skew_cycles=(\d+) transaction_cycles=(\d+) first_time_ns=(\d+) last_time_ns=(\d+)",
        text,
    )
    if metric_match is None:
        raise SystemExit(f"missing PEAK_INT8_METRIC in {path}")
    keys = (
        "tiles",
        "any_cycles",
        "all_cycles",
        "skew_cycles",
        "transaction_cycles",
        "first_time_ns",
        "last_time_ns",
    )
    metric = {key: int(value) for key, value in zip(keys, metric_match.groups())}
    events = [
        {"cycle": int(cycle), "time_ns": int(time_ns), "mask": int(mask, 16)}
        for cycle, time_ns, mask in re.findall(
            r"PEAK_INT8_EVENT cycle=(\d+) time_ns=(\d+) mask=0x([0-9a-fA-F]+)", text
        )
    ]
    return metric, events, "MODULE CHECK PASSED" in text


def write_waveform_svg(path: Path, report: dict, events: list[dict[str, int]]) -> None:
    width, left, right = 1280, 150, 35
    row_h, top, bottom = 42, 90, 80
    tiles = int(report["tiles"])
    height = top + tiles * row_h + bottom
    transaction_cycles = max(int(report["transaction_cycles"]), 1)
    plot_w = width - left - right

    def xpos(cycle: int) -> float:
        return left + min(max(cycle, 0), transaction_cycles) * plot_w / transaction_cycles

    rows = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<style>text{font-family:Consolas,monospace;fill:#18212f}.label{font-size:15px}.small{font-size:12px;fill:#52606d}.title{font-size:20px;font-weight:bold}</style>',
        '<text x="24" y="32" class="title">Peak INT8: all Tile/DCIM compute_phase_fire</text>',
        f'<text x="24" y="58" class="small">250 MHz; M={report["matmul_m"]}, K={report["matmul_k"]}, N={report["matmul_n"]}; active={report["active_cycles"]} cycles; peak={report["peak_tops"]:.3f} TOPS</text>',
    ]
    for tile in range(tiles):
        y = top + tile * row_h
        rows.append(f'<text x="24" y="{y + 21}" class="label">tile[{tile}]</text>')
        rows.append(f'<line x1="{left}" y1="{y + 26}" x2="{width-right}" y2="{y + 26}" stroke="#9aa5b1" stroke-width="1"/>')
        for event in events:
            if event["mask"] & (1 << tile):
                x = xpos(event["cycle"])
                rows.append(f'<rect x="{x:.2f}" y="{y + 4}" width="3" height="22" fill="#e5484d"/>')
    rows.extend(
        [
            f'<line x1="{left}" y1="{top-12}" x2="{left}" y2="{top + tiles*row_h}" stroke="#52606d"/>',
            f'<line x1="{width-right}" y1="{top-12}" x2="{width-right}" y2="{top + tiles*row_h}" stroke="#52606d"/>',
            f'<text x="{left}" y="{height-36}" class="small">DCIM start: cycle 0</text>',
            f'<text x="{width-right-210}" y="{height-36}" class="small">done: cycle {transaction_cycles}</text>',
            f'<text x="24" y="{height-12}" class="small">Red pulses are actual VCS events; identical vertical alignment across all rows proves simultaneous tile activity.</text>',
            "</svg>",
        ]
    )
    path.write_text("\n".join(rows), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--simulator", choices=("vcs", "verilator"), default="vcs")
    args = parser.parse_args()
    run_dir = args.run_dir.resolve()
    manifest = read_manifest(run_dir / "manifest.txt")
    metric, events, module_pass = parse_log(run_dir / "sim.log")

    matmul_m = int(manifest["matmul_m"])
    matmul_k = int(manifest["matmul_k"])
    matmul_n = int(manifest["matmul_n"])
    acc_depth = int(manifest["acc_depth"])
    logical_macs = matmul_m * matmul_k * matmul_n
    operations = logical_macs * 2
    expected_active_cycles = matmul_m * acc_depth * INT8_PHASES_PER_MAC
    active_cycles = metric["all_cycles"]
    active_time_ns = active_cycles * CLOCK_PERIOD_NS
    transaction_time_ns = metric["transaction_cycles"] * CLOCK_PERIOD_NS
    peak_tops = operations / (active_time_ns * 1e-9) / 1e12 if active_time_ns else 0.0
    transaction_tops = operations / (transaction_time_ns * 1e-9) / 1e12 if transaction_time_ns else 0.0
    full_mask = (1 << metric["tiles"]) - 1
    events_full_mask = bool(events) and all(event["mask"] == full_mask for event in events)
    passed = all(
        (
            module_pass,
            manifest.get("peak_int8") == "1",
            metric["tiles"] == 8,
            metric["skew_cycles"] == 0,
            metric["any_cycles"] == metric["all_cycles"],
            metric["transaction_cycles"] > 0,
            metric["last_time_ns"] >= metric["first_time_ns"] > 0,
            active_cycles == expected_active_cycles,
            len(events) == active_cycles,
            events_full_mask,
            peak_tops >= 2.0,
        )
    )
    waveform_name = "tb_lite_bd_module.fsdb" if args.simulator == "vcs" else "peak_int8_verilator.vcd"
    report = {
        "status": "PASS" if passed else "FAIL",
        "case": manifest.get("name", "unknown"),
        "clock_mhz": CLOCK_MHZ,
        "tiles": metric["tiles"],
        "matmul_m": matmul_m,
        "matmul_k": matmul_k,
        "matmul_n": matmul_n,
        "acc_depth": acc_depth,
        "logical_macs": logical_macs,
        "operations_mul_plus_add": operations,
        "active_cycles": active_cycles,
        "expected_active_cycles": expected_active_cycles,
        "active_time_ns": active_time_ns,
        "transaction_cycles": metric["transaction_cycles"],
        "transaction_time_ns": transaction_time_ns,
        "peak_tops": peak_tops,
        "transaction_effective_tops": transaction_tops,
        "all_tiles_simultaneous": events_full_mask and metric["skew_cycles"] == 0,
        "module_check_passed": module_pass,
        "simulator": args.simulator,
        "waveform": str(run_dir / waveform_name),
        "waveform_fsdb": str(run_dir / "tb_lite_bd_module.fsdb") if args.simulator == "vcs" else None,
        "waveform_vcd": str(run_dir / "peak_int8_verilator.vcd") if args.simulator == "verilator" else None,
        "waveform_svg": str(run_dir / "peak_int8_waveform.svg"),
        "simulation_log": str(run_dir / "sim.log"),
        "method_note": (
            "Peak TOPS uses only cycles where every tile asserts compute_phase_fire. "
            "Transaction-effective TOPS includes weight/activation load and writeback and is reported separately."
        ),
    }
    json_path = run_dir / "peak_int8_report.json"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_waveform_svg(run_dir / "peak_int8_waveform.svg", report, events)
    md_path = run_dir / "peak_int8_report.md"
    md_path.write_text(
        "\n".join(
            [
                f"# Peak INT8 {args.simulator.capitalize()} report",
                "",
                f"- Status: **{report['status']}**",
                f"- Matrix: M={matmul_m}, K={matmul_k}, N={matmul_n}",
                f"- Parallel hardware: {metric['tiles']} tiles, all simultaneous={report['all_tiles_simultaneous']}",
                f"- Compute-active window: {active_cycles} cycles = {active_time_ns:.1f} ns @ {CLOCK_MHZ:.0f} MHz",
                f"- Operations: {operations} (multiply and add counted separately)",
                f"- Peak compute: **{peak_tops:.3f} TOPS @ INT8**",
                f"- Whole DCIM transaction: {metric['transaction_cycles']} cycles = {transaction_time_ns:.1f} ns; {transaction_tops:.6f} TOPS",
                f"- Evidence: `{waveform_name}`, `peak_int8_waveform.svg`, `sim.log`",
                "",
                html.escape(report["method_note"]),
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(f"PEAK INT8 {report['status']}: {peak_tops:.3f} TOPS, active={active_cycles} cycles")
    print(f"report: {json_path}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
