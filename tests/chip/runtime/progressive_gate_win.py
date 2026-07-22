"""Run staged one-shot FPGA gates on Windows XDMA.

This is a thin orchestrator around hw_runner_win.py and compare_one_shot.py.
It keeps the reset-after-failure workflow explicit: run the smallest artifact
first, stop on the first hardware or data mismatch failure, and preserve timing
JSON for the stages that complete.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
RUNTIME = REPO / "tests" / "chip" / "runtime"


SUITES = {
    "yolo-int8": [
        ("l4", "output/compile_yolo_int8_l4_eff"),
        ("l8", "output/compile_yolo_int8_l8_eff"),
        ("l16", "output/compile_yolo_int8_l16_eff"),
        ("l32", "output/compile_yolo_int8_l32_eff"),
        ("full", "output/compile_yolo_int8_full_eff"),
    ],
    "yolo-int16": [
        ("l4", "output/compile_yolo_int16_l4_eff"),
        ("full", "output/compile_yolo_int16_full_eff"),
    ],
    "resnet-vai": [
        ("l2", "output/compile_resnet_vai_l2_eff"),
        ("l7", "output/compile_resnet_vai_l7_eff"),
        ("full", "output/compile_resnet_vai_full_eff"),
    ],
    "resnet-int16": [
        ("full", "output/compile_resnet_int16_full_eff"),
    ],
}


def _run(cmd: list[str], *, dry_run: bool) -> tuple[int, float]:
    print(" ".join(cmd), flush=True)
    if dry_run:
        return 0, 0.0
    t0 = time.perf_counter()
    rc = subprocess.run(cmd, cwd=REPO).returncode
    return rc, time.perf_counter() - t0


def _load_json_if_exists(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError:
        return None


def _compact_timing(timing: dict | None) -> dict | None:
    if not timing:
        return None
    return {
        "total_s": timing.get("total_s"),
        "upload_weights_s": timing.get("upload_weights_s"),
        "upload_wb_s": timing.get("upload_wb_s"),
        "upload_input_s": timing.get("upload_input_s"),
        "program_upload_s": timing.get("program_upload_s"),
        "execute_s": timing.get("execute_s"),
        "read_outputs_s": timing.get("read_outputs_s"),
        "failed_segment": timing.get("failed_segment"),
        "error": timing.get("error"),
        "segments": [
            {
                "index": s.get("index"),
                "words": s.get("words"),
                "upload_s": s.get("upload_s"),
                "execute_s": s.get("execute_s"),
                "error": s.get("error"),
            }
            for s in timing.get("segments", [])
        ],
    }


def _plan_outputs(build_dir: str) -> list[dict]:
    plan_path = REPO / build_dir / "plan.json"
    try:
        plan = json.loads(plan_path.read_text())
    except FileNotFoundError:
        return []
    return list(plan.get("host_io", {}).get("outputs") or [])


def main() -> int:
    ap = argparse.ArgumentParser(description="Run staged one-shot Windows FPGA gates")
    ap.add_argument("--suite", choices=sorted(SUITES), required=True)
    ap.add_argument("--yolo-image", default="test_yolo.jpg")
    ap.add_argument("--resnet-image", default="test_resnet_2.JPEG")
    ap.add_argument("--out-dir", default="output/progressive_eff")
    ap.add_argument("--poll-timeout-s", type=float, default=240.0)
    ap.add_argument("--read-chunk-bytes", type=int, default=65536)
    ap.add_argument("--atol", type=float, default=1e-3)
    ap.add_argument("--quiet-xdma", action="store_true")
    ap.add_argument("--force-start-when-busy", action="store_true")
    ap.add_argument("--dry-run", action="store_true",
                    help="print commands without touching XDMA")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    is_resnet = args.suite.startswith("resnet")
    image_arg = "--resnet-image" if is_resnet else "--yolo-image"
    image = args.resnet_image if is_resnet else args.yolo_image

    summary = {
        "suite": args.suite,
        "stages": [],
        "stopped_on": None,
    }

    for stage, build in SUITES[args.suite]:
        output = out_dir / f"{args.suite}_{stage}.bin"
        named_out_dir = out_dir / f"{args.suite}_{stage}_outputs"
        timing = out_dir / f"{args.suite}_{stage}_timing.json"
        named_outputs = _plan_outputs(build)
        run_cmd = [
            sys.executable, str(RUNTIME / "hw_runner_win.py"),
            "--build-dir", build,
            image_arg, image,
            "--output", str(output),
            "--poll-timeout-s", str(args.poll_timeout_s),
            "--read-chunk-bytes", str(args.read_chunk_bytes),
            "--timing-json", str(timing),
        ]
        if named_outputs:
            run_cmd.extend(["--output-dir", str(named_out_dir)])
        if args.quiet_xdma:
            run_cmd.append("--quiet-xdma")
        if args.force_start_when_busy:
            run_cmd.append("--force-start-when-busy")

        rc, elapsed = _run(run_cmd, dry_run=args.dry_run)
        timing_data = _load_json_if_exists(timing)
        rec = {
            "stage": stage,
            "build_dir": build,
            "output": str(output),
            "output_dir": str(named_out_dir) if named_outputs else None,
            "named_outputs": [str(o.get("name")) for o in named_outputs],
            "timing_json": str(timing),
            "run_returncode": rc,
            "run_elapsed_s": elapsed,
            "timing": _compact_timing(timing_data),
        }
        if rc != 0:
            rec["compare_returncode"] = None
            summary["stopped_on"] = stage
            summary["stages"].append(rec)
            break

        cmp_cmd = [
            sys.executable, str(RUNTIME / "compare_one_shot.py"),
            "--build-dir", build,
            "--image", image,
            "--output", str(output),
            "--atol", str(args.atol),
        ]
        if named_outputs:
            cmp_cmd.extend(["--output-dir", str(named_out_dir)])
        rc, elapsed = _run(cmp_cmd, dry_run=args.dry_run)
        rec["compare_returncode"] = rc
        rec["compare_elapsed_s"] = elapsed
        if rc != 0:
            summary["stages"].append(rec)
            summary["stopped_on"] = stage
            break

        if stage == "full":
            head_json = out_dir / f"{args.suite}_{stage}_host_head.json"
            head_cmd = [
                sys.executable, str(RUNTIME / "one_shot_host_head.py"),
                "--build-dir", build,
                "--image", image,
                "--output", str(output),
                "--json-out", str(head_json),
            ]
            if named_outputs:
                head_cmd.extend(["--output-dir", str(named_out_dir)])
            if args.suite.startswith("resnet"):
                head_cmd.extend(["--expect-top1", "1"])
            if args.suite.startswith("yolo"):
                head_cmd.extend(["--expect-detections", "1"])
            rc, elapsed = _run(head_cmd, dry_run=args.dry_run)
            rec["host_head_returncode"] = rc
            rec["host_head_elapsed_s"] = elapsed
            rec["host_head_json"] = str(head_json)
            if rc != 0:
                summary["stages"].append(rec)
                summary["stopped_on"] = stage
                break

        summary["stages"].append(rec)

    summary_path = out_dir / f"{args.suite}_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2))
    print(f"wrote {summary_path}", flush=True)
    return 1 if summary["stopped_on"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
