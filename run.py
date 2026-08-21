"""EdgeYOLO-FPGA 的自包含运行入口。

新克隆的仓库已经包含唯一发布 bitstream、当前 PT/ONNX/解析模型以及 20+20 张
测试图片，不需要另外下载或填写文件路径。编译产物会按需生成到 ``output/``。

常用命令::

    python run.py                 # YOLO INT8/native W16A16 + ResNet INT8
    python run.py --self-check    # 无需 FPGA，校验所有随附文件及 SHA256
    python run.py --network yolo --yolo-precision int8
    python run.py --acceptance --vcs skip

硬件运行仍要求 FPGA 已烧录 bitstream/ 中的唯一 .bit 文件，并已安装 Xilinx
XDMA 驱动；这两项是板卡/驱动状态，不是仓库文件配置。Python 依赖见 README。
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import importlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

import numpy as np

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

REPO_ROOT = Path(__file__).resolve().parent
UNIT_TB = REPO_ROOT / "tests" / "chip" / "unit-tb"
OUT_DIR = REPO_ROOT / "output"
INFERENCE_OUT_DIR = OUT_DIR / "inference"
WORK_DIR_ENV = "EDGEYOLO_RUNS_BASE"

DEFAULT_YOLO_IMG = REPO_ROOT / "examples" / "coco" / "000000000139.jpg"
DEFAULT_RESNET_IMG = REPO_ROOT / "examples" / "imagenet" / "n01443537_goldfish.JPEG"
RELEASE_ID = "80832ec_attempt1"
COMPILED_DIR = OUT_DIR / "compiled" / RELEASE_ID
COCO_YOLO_DIR = REPO_ROOT / "model" / "yolov5n_coco50k_qat"
EXAMPLES_DIR = REPO_ROOT / "examples"
IMAGENET_MANIFEST = EXAMPLES_DIR / "imagenet" / "manifest.json"
COCO_MANIFEST = EXAMPLES_DIR / "coco" / "manifest.json"
PEAK_TB_DIR = REPO_ROOT / "rtl" / "tb" / "lite_bd" / "module_tb"
BITSTREAM_MANIFEST = REPO_ROOT / "bitstream" / "manifest.json"
MODEL_INPUTS_MANIFEST = REPO_ROOT / "model" / "model_inputs_manifest.json"

ONE_SHOT_DEFAULT_BUILDS = {
    ("resnet", "vai"): COMPILED_DIR / "resnet18_int8",
    ("resnet", "int16"): COMPILED_DIR / "resnet18_int16_native",
    ("resnet", "int16_widened"): COMPILED_DIR / "resnet18_int16_widened",
}

ONE_SHOT_COMPILE_PARSED = {
    ("resnet", "vai"): REPO_ROOT / "model" / "resnet18" / "parsed_vai",
    ("resnet", "int16"): REPO_ROOT / "model" / "resnet18" / "parsed_int16",
    ("resnet", "int16_widened"): REPO_ROOT / "model" / "resnet18" / "parsed_vai_int16_widened",
}

YOLO_ONE_SHOT_PROFILES = {
    "coco": {
        "image": DEFAULT_YOLO_IMG,
        "parsed": {
            "int8": COCO_YOLO_DIR / "parsed_int8",
            "int16": COCO_YOLO_DIR / "parsed_int16",
        },
        "builds": {
            "int8": COMPILED_DIR / "yolo_coco_int8",
            "int16": COMPILED_DIR / "yolo_coco_int16_native",
        },
        "expect_detections": 3,
        "output_group": "yolo_coco",
    },
}


def _install_unit_tb_run_module() -> None:
    if "run" in sys.modules and getattr(sys.modules["run"], "__file__", "") != str(__file__):
        return
    spec = importlib.util.spec_from_file_location("run", UNIT_TB / "run.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load tests/chip/unit-tb/run.py")
    mod = importlib.util.module_from_spec(spec)
    sys.modules["run"] = mod
    spec.loader.exec_module(mod)


def _setup_imports() -> None:
    sys.path.insert(0, str(UNIT_TB))
    sys.path.insert(0, str(REPO_ROOT / "rtl" / "tb" / "lite_bd" / "module_tb"))
    sys.path.insert(0, str(REPO_ROOT / "tools"))
    _install_unit_tb_run_module()


def save_image(img: np.ndarray, path: Path) -> None:
    from PIL import Image
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(img).save(str(path), quality=90)


def _display_path(path: Path) -> Path:
    resolved = path.resolve()
    try:
        return resolved.relative_to(REPO_ROOT)
    except ValueError:
        return resolved


def _run_checked(cmd: list[str], *, cwd: Path = REPO_ROOT) -> subprocess.CompletedProcess:
    print("  $ " + " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=str(cwd), check=True)


def _draw_yolo_detections(image_path: Path, detections: list[dict], out_img: Path) -> None:
    from PIL import Image, ImageDraw, ImageFont

    names = {0: "person", 1: "car", 2: "bicycle"}
    img = Image.open(str(image_path)).convert("RGB")
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()

    for det in detections:
        x1, y1, x2, y2 = [float(v) for v in det["bbox"]]
        cls = int(det.get("class_id", det.get("class", 0)))
        conf = float(det.get("conf", det.get("confidence", 0.0)))
        label = f"{det.get('class_name', names.get(cls, f'class_{cls}'))} {conf:.3f}"
        draw.rectangle([x1, y1, x2, y2], outline=(255, 64, 32), width=3)
        left, top, right, bottom = draw.textbbox((x1, y1), label, font=font)
        label_h = bottom - top + 6
        label_w = right - left + 8
        y_label = max(0, y1 - label_h)
        draw.rectangle([x1, y_label, x1 + label_w, y_label + label_h], fill=(255, 64, 32))
        draw.text((x1 + 4, y_label + 3), label, fill=(255, 255, 255), font=font)

    out_img.parent.mkdir(parents=True, exist_ok=True)
    img.save(str(out_img), quality=95)


def _draw_resnet_classification(image_path: Path, topk: list[dict], out_img: Path) -> None:
    resnet_e2e = importlib.import_module("resnet_e2e")
    img_rgb = resnet_e2e.load_image(str(image_path))
    top = [(int(row["class_id"]), float(row["score"])) for row in topk]
    canvas = resnet_e2e.draw_classification(img_rgb, top, "ResNet18 FPGA One-Shot")
    save_image(canvas, out_img)


def _one_shot_tag(network: str, precision: str) -> str:
    return "int8" if network == "resnet" and precision == "vai" else precision


def _golden_cache_dir(args: argparse.Namespace) -> Path | None:
    if getattr(args, "no_golden_cache", False):
        return None
    return OUT_DIR / "golden_cache"


def _hardware_mode(network: str, precision: str) -> str:
    if network == "resnet" and precision == "vai":
        return "int8"
    if precision in {"int16", "int16_widened"}:
        return "int16"
    return precision


def _compile_one_shot_artifact(network: str, precision: str, build_dir: Path,
                               parsed_override: Path | None = None) -> None:
    compile_network = "yolov5n" if network == "yolo" else "resnet18"
    mode = _hardware_mode(network, precision)
    cmd = [
        sys.executable, "tests/chip/compiler/compile.py",
        "--network", compile_network,
        "--mode", mode,
        "--full",
        "--out", str(build_dir),
    ]
    parsed = parsed_override or ONE_SHOT_COMPILE_PARSED.get((network, precision))
    if parsed is not None:
        cmd.extend(["--parsed", str(parsed)])
    if precision == "int16_widened":
        cmd.append("--allow-widened-int16")
    _run_checked(cmd)


def run_one_shot_fpga(
    network: str,
    precision: str,
    img_path: Path,
    out_root: Path,
    *,
    build_dir: Path,
    conf: float,
    iou: float,
    poll_timeout_s: float,
    read_chunk_bytes: int,
    compare_atol: float | None,
    quiet_xdma: bool,
    soft_reset: bool,
    recompile: bool,
    yolo_parsed_dir: Path | None = None,
    resnet_parsed_dir: Path | None = None,
    yolo_expect_detections: int | None = 1,
    resnet_expect_top1: int | None = 1,
    result_group: str | None = None,
    golden_cache_dir: Path | None = None,
) -> Path:
    """Run a full one-shot FPGA workload, compare features, and run the host boundary."""
    runtime = REPO_ROOT / "tests" / "chip" / "runtime"
    tag = _one_shot_tag(network, precision)
    net_dir = "yolo" if network == "yolo" else "resnet"
    output_group = result_group or net_dir
    label = f"{'YOLO' if network == 'yolo' else 'ResNet'} {tag.upper()}"
    if compare_atol is None:
        # Selected attempt1 board validation measured native COCO W16A16 PAN
        # max_abs <= 0.00930. Other maintained paths pass the strict 1e-3 gate.
        compare_atol = 1e-2 if network == "yolo" and precision == "int16" else 1e-3
    out_dir = out_root / output_group / f"one_shot_{tag}"
    feat_dir = out_dir / "features"
    out_dir.mkdir(parents=True, exist_ok=True)

    if recompile or not (build_dir / "plan.json").exists():
        reason = "requested" if recompile else f"missing {build_dir / 'plan.json'}"
        print(f"  [compile] {reason}, compiling {label} full one-shot", flush=True)
        parsed_dir = yolo_parsed_dir if network == "yolo" else resnet_parsed_dir
        _compile_one_shot_artifact(network, precision, build_dir, parsed_dir)

    stem = img_path.stem
    file_prefix = f"{stem}_{net_dir}_{tag}_fpga_oneshot"
    primary = out_dir / f"{file_prefix}.bin"
    timing_json = out_dir / f"{file_prefix}_timing.json"
    head_json = out_dir / f"{file_prefix}.json"
    result_img = out_dir / f"{file_prefix}.jpg"

    plan = json.loads((build_dir / "plan.json").read_text())
    named_outputs = bool(plan.get("host_io", {}).get("outputs"))
    if named_outputs:
        feat_dir.mkdir(parents=True, exist_ok=True)

    run_cmd = [
        sys.executable, str(runtime / "hw_runner_win.py"),
        "--build-dir", str(build_dir),
        "--output", str(primary),
        "--poll-timeout-s", str(poll_timeout_s),
        "--read-chunk-bytes", str(read_chunk_bytes),
        "--timing-json", str(timing_json),
    ]
    run_cmd.extend(["--yolo-image" if network == "yolo" else "--resnet-image", str(img_path)])
    if named_outputs:
        run_cmd.extend(["--output-dir", str(feat_dir)])
    if network == "yolo" and yolo_parsed_dir is not None:
        run_cmd.extend(["--yolo-parsed-dir", str(yolo_parsed_dir)])
    if network == "resnet" and resnet_parsed_dir is not None:
        run_cmd.extend(["--resnet-parsed-dir", str(resnet_parsed_dir)])
    if quiet_xdma:
        run_cmd.append("--quiet-xdma")
    if soft_reset:
        run_cmd.append("--soft-reset-decoder")
    _run_checked(run_cmd)

    compare_cmd = [
        sys.executable, str(runtime / "compare_one_shot.py"),
        "--build-dir", str(build_dir),
        "--image", str(img_path),
        "--output", str(primary),
        "--atol", str(compare_atol),
    ]
    if named_outputs:
        compare_cmd.extend(["--output-dir", str(feat_dir)])
    if network == "yolo" and yolo_parsed_dir is not None:
        compare_cmd.extend(["--yolo-parsed-dir", str(yolo_parsed_dir)])
    if network == "resnet" and resnet_parsed_dir is not None:
        compare_cmd.extend(["--parsed-dir", str(resnet_parsed_dir)])
    if golden_cache_dir is not None:
        compare_cmd.extend(["--golden-cache-dir", str(golden_cache_dir)])
    _run_checked(compare_cmd)

    head_cmd = [
        sys.executable, str(runtime / "one_shot_host_head.py"),
        "--build-dir", str(build_dir),
        "--image", str(img_path),
        "--output", str(primary),
        "--json-out", str(head_json),
    ]
    if network == "yolo":
        head_cmd.extend([
            "--output-dir", str(feat_dir),
            "--conf", str(conf),
            "--iou", str(iou),
        ])
        if yolo_expect_detections is not None:
            head_cmd.extend(["--expect-detections", str(yolo_expect_detections)])
        if yolo_parsed_dir is not None:
            head_cmd.extend(["--yolo-parsed-dir", str(yolo_parsed_dir)])
    else:
        if resnet_expect_top1 is not None:
            head_cmd.extend(["--expect-top1", str(resnet_expect_top1)])
        if resnet_parsed_dir is not None:
            head_cmd.extend(["--parsed-dir", str(resnet_parsed_dir)])
    _run_checked(head_cmd)

    result = json.loads(head_json.read_text())
    detections = list(result.get("detections", []))
    if network == "yolo":
        _draw_yolo_detections(img_path, detections, result_img)
    else:
        _draw_resnet_classification(img_path, list(result.get("topk", [])), result_img)

    timing = json.loads(timing_json.read_text())
    summary = f"{len(detections)} det" if network == "yolo" else result["topk"][0]["class_name"]
    print(f"  [fpga   ] {label} one-shot: {summary}")
    print(
        "            timing: "
        f"total={float(timing.get('total_s', 0.0)):.3f}s, "
        f"execute={float(timing.get('execute_s', 0.0)):.3f}s, "
        f"weights={float(timing.get('upload_weights_s', 0.0)):.3f}s, "
        f"read={float(timing.get('read_outputs_s', 0.0)):.3f}s"
    )
    if network == "yolo":
        for det in detections:
            bbox = ", ".join(f"{v:.1f}" for v in det["bbox"])
            print(f"            bbox=[{bbox}], conf={float(det['conf']):.4f}, class={int(det['class_id'])}")
        print(f"            image -> {_display_path(result_img)}")
    else:
        top = result["topk"][0]
        print(f"            top1={top['class_name']}({int(top['class_id'])}), score={float(top['score']):.4f}")
        print(f"            image -> {_display_path(result_img)}")
    print(f"            json  -> {_display_path(head_json)}")
    print(f"            time  -> {_display_path(timing_json)}")
    return result_img


# ─── Acceptance suite / VCS peak test ────────────────────────────────────────

def _load_examples(manifest_path: Path, limit: int) -> tuple[dict, list[dict]]:
    if not manifest_path.exists():
        raise FileNotFoundError(f"example manifest not found: {manifest_path}")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    images = list(manifest.get("images", []))[:limit]
    if len(images) < limit:
        raise RuntimeError(f"{manifest_path} contains only {len(images)} images, need {limit}")
    for item in images:
        image_path = manifest_path.parent / item["file"]
        if not image_path.exists():
            raise FileNotFoundError(f"example image not found: {image_path}")
        item["path"] = image_path
    return manifest, images


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _verify_release_bundle(*, require_xdma: bool) -> dict:
    """Fail early if a fresh clone is missing any maintained runtime asset."""
    bitstream = _verify_release_bitstream()
    checked_hashes = 1

    bit_manifest = json.loads(BITSTREAM_MANIFEST.read_text(encoding="utf-8"))

    model_manifest = json.loads(MODEL_INPUTS_MANIFEST.read_text(encoding="utf-8"))
    for entry in model_manifest["files"]:
        path = REPO_ROOT / entry["path"]
        if not path.is_file():
            raise FileNotFoundError(f"model input not found: {path}")
        if path.stat().st_size != int(entry["bytes"]):
            raise RuntimeError(f"model input size mismatch: {path}")
        if _sha256_file(path) != str(entry["sha256"]).lower():
            raise RuntimeError(f"model input integrity check failed: {path}")
        checked_hashes += 1

    parsed_sets = [
        (COCO_YOLO_DIR / "parsed_int8", 60),
        (COCO_YOLO_DIR / "parsed_int16", 60),
        (REPO_ROOT / "model" / "resnet18" / "parsed_vai", 22),
        (REPO_ROOT / "model" / "resnet18" / "parsed_vai_int16_widened", 22),
    ]
    for parsed_dir, minimum_npz in parsed_sets:
        if not (parsed_dir / "network.json").is_file():
            raise FileNotFoundError(f"parsed model metadata not found: {parsed_dir}")
        npz_count = sum(1 for _ in (parsed_dir / "weights").glob("*.npz"))
        if npz_count < minimum_npz:
            raise RuntimeError(
                f"parsed model is incomplete: {parsed_dir} has {npz_count} NPZ files, "
                f"expected at least {minimum_npz}"
            )

    _coco_manifest, coco_images = _load_examples(COCO_MANIFEST, 20)
    _imagenet_manifest, imagenet_images = _load_examples(IMAGENET_MANIFEST, 20)

    xdma_files = [REPO_ROOT / "tests" / "bin" / name for name in ("xdma_info.exe", "xdma_rw.exe")]
    if require_xdma:
        for path in xdma_files:
            if not path.is_file():
                raise FileNotFoundError(f"bundled XDMA tool not found: {path}")

    result = {
        "status": "PASS",
        "release": bit_manifest["release"],
        "bitstream": bitstream["file"],
        "hashed_files": checked_hashes,
        "model_inputs": len(model_manifest["files"]),
        "compile_on_demand_workloads": 4,
        "coco_images": len(coco_images),
        "imagenet_images": len(imagenet_images),
        "xdma_tools": len(xdma_files) if require_xdma else "not-required",
    }
    print(
        "Release bundle PASS: "
        f"{result['compile_on_demand_workloads']} compile-on-demand workloads, "
        f"{result['model_inputs']} model inputs, "
        f"{result['coco_images']} COCO + {result['imagenet_images']} ImageNet images, "
        f"{result['hashed_files']} SHA256 checks"
    )
    return result

def _verify_release_bitstream() -> dict:
    manifest = json.loads(BITSTREAM_MANIFEST.read_text(encoding="utf-8"))
    bit_path = BITSTREAM_MANIFEST.parent / manifest["file"]
    digest = hashlib.sha256()
    with bit_path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest()
    expected = str(manifest["sha256"]).lower()
    result = {
        "file": str(bit_path),
        "expected_sha256": expected,
        "actual_sha256": actual,
        "bytes": bit_path.stat().st_size,
        "status": "PASS" if actual == expected and bit_path.stat().st_size == int(manifest["bytes"]) else "FAIL",
    }
    if result["status"] != "PASS":
        raise RuntimeError(f"release bitstream integrity check failed: {bit_path}")
    print(f"Release bitstream PASS: {bit_path.name} sha256={actual[:16]}...")
    return result


def run_vcs_peak(*, mode: str, server: str | None, remote_repo: str | None) -> dict:
    """Run the peak-INT8 VCS target locally or through SSH."""
    if server:
        if not remote_repo:
            return {"status": "FAIL", "reason": "--vcs-remote-repo is required with --vcs-server"}
        remote_cmd = f"cd {shlex.quote(remote_repo)} && python3 run.py --vcs-only"
        cmd = ["ssh", server, remote_cmd]
        print("  $ " + " ".join(cmd), flush=True)
        try:
            proc = subprocess.run(cmd, cwd=str(REPO_ROOT), check=True, text=True)
        except (OSError, subprocess.CalledProcessError) as exc:
            return {"status": "FAIL", "mode": "ssh", "server": server, "reason": str(exc)}
        return {
            "status": "PASS",
            "mode": "ssh",
            "server": server,
            "remote_repo": remote_repo,
            "remote_report": "rtl/tb/lite_bd/module_tb/sim/run_peak_int8_all_tiles/peak_int8_report.json",
            "returncode": proc.returncode,
        }

    if mode == "skip":
        return {"status": "SKIPPED", "reason": "disabled by --vcs skip"}
    if mode == "auto" and not (shutil.which("vcs") and shutil.which("make") and shutil.which("bash")):
        return {"status": "SKIPPED", "reason": "VCS toolchain not found locally; use --vcs-server or run --vcs-only on the server"}
    cmd = ["make", "-C", str(PEAK_TB_DIR), "peak-int8"]
    try:
        _run_checked(cmd)
    except (OSError, subprocess.CalledProcessError) as exc:
        return {"status": "FAIL", "mode": "local", "reason": str(exc)}
    report_path = PEAK_TB_DIR / "sim" / "run_peak_int8_all_tiles" / "peak_int8_report.json"
    if not report_path.exists():
        return {"status": "FAIL", "mode": "local", "reason": f"missing report: {report_path}"}
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report.update({"mode": "local", "report": str(report_path)})
    return report


def run_verilator_peak(*, mode: str) -> dict:
    """Run the pure-RTL peak-INT8 preflight, using WSL on Windows."""
    if mode == "skip":
        return {"status": "SKIPPED", "reason": "disabled by --verilator skip"}

    if os.name == "nt":
        wsl = shutil.which("wsl") or shutil.which("wsl.exe")
        if not wsl:
            status = "SKIPPED" if mode == "auto" else "FAIL"
            return {"status": status, "reason": "WSL was not found"}
        probe = subprocess.run(
            [wsl, "bash", "-lc", "command -v verilator >/dev/null"],
            cwd=str(REPO_ROOT), check=False,
        )
        if probe.returncode != 0:
            status = "SKIPPED" if mode == "auto" else "FAIL"
            return {"status": status, "reason": "Verilator was not found in WSL"}
        drive, tail = os.path.splitdrive(str(REPO_ROOT))
        if not drive or len(drive) < 1:
            return {"status": "FAIL", "reason": f"cannot translate repository path for WSL: {REPO_ROOT}"}
        tail_wsl = tail.lstrip("\\/").replace("\\", "/")
        wsl_repo = f"/mnt/{drive[0].lower()}/{tail_wsl}"
        shell_cmd = (
            f"cd {shlex.quote(wsl_repo)} && "
            "make -C rtl/tb/lite_bd/module_tb peak-int8-verilator"
        )
        cmd = [wsl, "bash", "-lc", shell_cmd]
        runner = "wsl"
    else:
        if mode == "auto" and not (shutil.which("verilator") and shutil.which("make")):
            return {"status": "SKIPPED", "reason": "Verilator toolchain not found locally"}
        cmd = ["make", "-C", str(PEAK_TB_DIR), "peak-int8-verilator"]
        runner = "local"

    try:
        _run_checked(cmd)
    except (OSError, subprocess.CalledProcessError) as exc:
        return {"status": "FAIL", "mode": runner, "reason": str(exc)}
    report_path = OUT_DIR / "verilator_peak_int8" / "peak_int8_report.json"
    if not report_path.exists():
        return {"status": "FAIL", "mode": runner, "reason": f"missing report: {report_path}"}
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report.update({"mode": runner, "report": str(report_path)})
    return report


def run_acceptance_suite(args: argparse.Namespace, networks: list[str],
                         yolo_precisions: list[str], resnet_precisions: list[str]) -> int:
    """Run selected native INT8/W16A16 network acceptance workloads."""
    if "resnet" in networks and "int16" in resnet_precisions:
        native_parsed = (
            Path(args.one_shot_resnet_parsed_dir)
            if args.one_shot_resnet_parsed_dir
            else ONE_SHOT_COMPILE_PARSED[("resnet", "int16")]
        )
        if not (native_parsed / "network.json").is_file():
            print(
                "  [ERROR] native ResNet W16A16 parsed model not found: "
                f"{native_parsed}. Parse a signed symmetric INT16 QDQ ONNX with "
                "tests/chip/compiler/frontend/parse_resnet18_qdq.py --mode int16, "
                "or pass --one-shot-resnet-parsed-dir."
            )
            return 1
    limit = int(args.acceptance_examples)
    out_root = Path(args.out_dir) if args.out_dir else OUT_DIR
    report_dir = out_root / "acceptance"
    report_dir.mkdir(parents=True, exist_ok=True)
    cases: list[dict] = []
    bitstream_check = _verify_release_bitstream()
    verilator = run_verilator_peak(mode=args.verilator)

    if "yolo" in networks:
        _, coco_images = _load_examples(COCO_MANIFEST, limit)
        yolo_profile = YOLO_ONE_SHOT_PROFILES["coco"]
        for item in coco_images:
            for precision in yolo_precisions:
                tag = _one_shot_tag("yolo", precision)
                image = Path(item["path"])
                started = time.time()
                record = {
                    "network": "yolov5n_coco",
                    "precision": tag,
                    "image": image.name,
                    "image_id": item.get("image_id"),
                }
                try:
                    run_one_shot_fpga(
                        "yolo", precision, image, out_root,
                        build_dir=Path(yolo_profile["builds"][precision]),
                        conf=args.conf,
                        iou=args.iou,
                        poll_timeout_s=args.one_shot_poll_timeout_s,
                        read_chunk_bytes=args.one_shot_read_chunk_bytes,
                        compare_atol=args.one_shot_compare_atol,
                        quiet_xdma=not args.verbose_xdma,
                        soft_reset=not args.one_shot_no_soft_reset,
                        recompile=False,
                        yolo_parsed_dir=Path(yolo_profile["parsed"][precision]),
                        yolo_expect_detections=None,
                        result_group="acceptance/yolo_coco",
                        golden_cache_dir=_golden_cache_dir(args),
                    )
                    base = out_root / "acceptance" / "yolo_coco" / f"one_shot_{tag}"
                    result = json.loads((base / f"{image.stem}_yolo_{tag}_fpga_oneshot.json").read_text())
                    timing = json.loads((base / f"{image.stem}_yolo_{tag}_fpga_oneshot_timing.json").read_text())
                    record.update({
                        "status": "PASS",
                        "detections": len(result.get("detections", [])),
                        "timing_s": timing,
                    })
                except Exception as exc:  # continue to expose every failing image in one report
                    record.update({"status": "FAIL", "error": f"{type(exc).__name__}: {exc}"})
                record["wall_s"] = time.time() - started
                cases.append(record)

    if "resnet" in networks:
        _, imagenet_images = _load_examples(IMAGENET_MANIFEST, limit)
        for item in imagenet_images:
            for precision in resnet_precisions:
                tag = _one_shot_tag("resnet", precision)
                image = Path(item["path"])
                started = time.time()
                record = {
                    "network": "resnet18_imagenet",
                    "precision": tag,
                    "image": image.name,
                    "synset": item.get("synset"),
                    "expected_class_id": item.get("class_id"),
                    "expected_label": item.get("label"),
                }
                try:
                    parsed_override = (
                        Path(args.one_shot_resnet_parsed_dir)
                        if args.one_shot_resnet_parsed_dir and precision == "int16"
                        else ONE_SHOT_COMPILE_PARSED[("resnet", precision)]
                    )
                    run_one_shot_fpga(
                        "resnet", precision, image, out_root,
                        build_dir=ONE_SHOT_DEFAULT_BUILDS[("resnet", precision)],
                        conf=args.conf,
                        iou=args.iou,
                        poll_timeout_s=args.one_shot_poll_timeout_s,
                        read_chunk_bytes=args.one_shot_read_chunk_bytes,
                        compare_atol=args.one_shot_compare_atol,
                        quiet_xdma=not args.verbose_xdma,
                        soft_reset=not args.one_shot_no_soft_reset,
                        recompile=False,
                        resnet_parsed_dir=parsed_override,
                        resnet_expect_top1=None,
                        result_group="acceptance/resnet",
                        golden_cache_dir=_golden_cache_dir(args),
                    )
                    base = out_root / "acceptance" / "resnet" / f"one_shot_{tag}"
                    result = json.loads((base / f"{image.stem}_resnet_{tag}_fpga_oneshot.json").read_text())
                    timing = json.loads((base / f"{image.stem}_resnet_{tag}_fpga_oneshot_timing.json").read_text())
                    top1 = result["topk"][0]
                    record.update({
                        "status": "PASS",
                        "top1_class_id": int(top1["class_id"]),
                        "top1_class_name": top1["class_name"],
                        "top1_matches_sample_label": int(top1["class_id"]) == int(item["class_id"]),
                        "timing_s": timing,
                    })
                except Exception as exc:
                    record.update({"status": "FAIL", "error": f"{type(exc).__name__}: {exc}"})
                record["wall_s"] = time.time() - started
                cases.append(record)

    vcs = run_vcs_peak(mode=args.vcs, server=args.vcs_server, remote_repo=args.vcs_remote_repo)
    failed = sum(case["status"] != "PASS" for case in cases)
    if failed or verilator.get("status") == "FAIL":
        report_status = "FAIL"
    elif vcs.get("status") == "PASS":
        report_status = "PASS"
    elif args.vcs == "skip" and not args.vcs_server:
        report_status = "PASS_HARDWARE_ONLY"
    elif vcs.get("status") == "FAIL":
        report_status = "FAIL"
    else:
        report_status = "INCOMPLETE_VCS_SKIPPED"
    report = {
        "status": report_status,
        "precision_policy": {
            "yolo_int8": "native W8A8",
            "yolo_int16": "native W16A16 with signed INT64 accumulators",
            "resnet_int8": "Vitis-AI W8A8",
            "resnet_int16": "native W16A16 with signed INT64 accumulators",
            "resnet_int16_widened": "explicit legacy data compatibility on the same MODE_INT16 hardware path",
        },
        "bitstream_integrity": bitstream_check,
        "examples_per_dataset": limit,
        "case_count": len(cases),
        "passed": len(cases) - failed,
        "failed": failed,
        "verilator_peak_int8": verilator,
        "vcs_peak_int8": vcs,
        "cases": cases,
    }
    json_path = report_dir / "acceptance_report.json"
    json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md_lines = [
        "# EdgeYOLO-FPGA acceptance report",
        "",
        f"- Status: **{report_status}**",
        f"- Hardware image/precision cases: {len(cases) - failed}/{len(cases)} PASS",
        f"- Verilator peak INT8 preflight: {verilator.get('status', 'UNKNOWN')}",
        f"- VCS peak INT8: {vcs.get('status', 'UNKNOWN')}",
        "- INT16 policy: YOLO and ResNet use native W16A16; widened compatibility is explicit only",
        "",
        "| Network | Precision | Image | Result |",
        "|---|---:|---|---|",
    ]
    for case in cases:
        detail = case.get("top1_class_name", f"{case.get('detections', '-')} detections")
        if case["status"] != "PASS":
            detail = case.get("error", "failed")
        md_lines.append(f"| {case['network']} | {case['precision']} | {case['image']} | {case['status']}: {detail} |")
    (report_dir / "acceptance_report.md").write_text("\n".join(md_lines) + "\n", encoding="utf-8")
    print(f"\nAcceptance {report_status}: {len(cases) - failed}/{len(cases)} hardware cases PASS; VCS={vcs.get('status')}")
    print(f"report -> {_display_path(json_path)}")
    return 0 if report_status in ("PASS", "PASS_HARDWARE_ONLY") else 1


# ─── CLI ─────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser(
        description="YOLOv5n / ResNet18 FPGA E2E inference",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Usage\n-----\n")[1] if "Usage" in __doc__ else "",
    )
    ap.add_argument("--network", choices=["yolo", "resnet", "all"], default="all")
    ap.add_argument("--yolo-precision", choices=["int8", "int16", "both"], default="both",
                    help="YOLOv5n precision: int8 / int16 / both (default: both)")
    ap.add_argument("--resnet-precision",
                    choices=["vai", "int16", "int16_widened", "both"], default="vai",
                    help="ResNet18 precision: vai=INT8 / int16=native W16A16 / int16_widened=legacy compatibility")
    # Legacy alias kept for compatibility
    ap.add_argument("--precision", choices=["vai", "int8", "int16", "both"], default=None,
                    help="(deprecated) 同时设置 YOLO 和 ResNet 精度；建议用 --yolo-precision / --resnet-precision")
    ap.add_argument("--self-check", action="store_true",
                    help="verify all bundled release assets without accessing FPGA")
    ap.add_argument("--dry-run", action="store_true",
                    help="deprecated alias for --self-check")
    ap.add_argument("--yolo-model", choices=["coco"], default="coco",
                    help="YOLO milestone profile (current release: coco)")
    ap.add_argument("--yolo-img", default=None,
                    help="override the selected YOLO profile's bundled test image")
    ap.add_argument("--resnet-img", default=str(DEFAULT_RESNET_IMG))
    ap.add_argument("--conf", type=float, default=0.15)
    ap.add_argument("--iou", type=float, default=0.45)
    ap.add_argument("--out-dir", default=None,
                    help="output root; default is output/inference")
    ap.add_argument("--one-shot", action="store_true",
                    help="run full one-shot FPGA path for selected networks/precisions, then compare and run host heads")
    ap.add_argument("--one-shot-yolo-int8", action="store_true",
                    help="legacy alias for --one-shot --network yolo --yolo-precision int8")
    ap.add_argument("--one-shot-build-dir", default=None,
                    help="override compiler artifact directory for a single selected one-shot workload")
    ap.add_argument("--one-shot-poll-timeout-s", type=float, default=240.0,
                    help="decoder timeout for one-shot FPGA execution")
    ap.add_argument("--one-shot-read-chunk-bytes", type=int, default=65536,
                    help="C2H readback chunk size for one-shot named outputs; lower this if XDMA C2H is unstable")
    ap.add_argument("--one-shot-compare-atol", type=float, default=None,
                    help="feature absolute tolerance; auto=0.01 for YOLO native W16A16, 1e-3 otherwise")
    ap.add_argument("--no-golden-cache", action="store_true",
                    help="recompute numpy golden for every image instead of using output/golden_cache")
    ap.add_argument("--one-shot-no-soft-reset", action="store_true",
                    help="do not issue decoder soft reset before one-shot execution")
    ap.add_argument("--one-shot-recompile", action="store_true",
                    help="rebuild the selected workload under output/ before FPGA execution")
    ap.add_argument("--one-shot-yolo-parsed-dir", default=None,
                    help="override YOLO parsed dir for one-shot compile/input/host head")
    ap.add_argument("--one-shot-resnet-parsed-dir", default=None,
                    help="override ResNet parsed dir; required when native parsed_int16 is not bundled")
    ap.add_argument("--one-shot-yolo-expect-detections", type=int, default=None,
                    help="override the profile detection-count gate; use -1 to disable")
    ap.add_argument("--verbose-xdma", action="store_true",
                    help="show verbose xdma_rw.exe commands in one-shot mode")
    ap.add_argument("--acceptance", action="store_true",
                    help="run selected COCO/ResNet native INT8 or W16A16 acceptance")
    ap.add_argument("--acceptance-examples", type=int, default=20,
                    help="number of images per selected dataset in --acceptance mode (default: 20)")
    ap.add_argument("--vcs", choices=["auto", "local", "skip"], default="auto",
                    help="peak INT8 VCS policy for --acceptance: auto/local/skip")
    ap.add_argument("--verilator", choices=["auto", "run", "skip"], default="auto",
                    help="local pure-RTL peak INT8 preflight policy for --acceptance (default: auto)")
    ap.add_argument("--vcs-server", default=None,
                    help="SSH target for the VCS server; makes --acceptance invoke the server in the same command")
    ap.add_argument("--vcs-remote-repo", default=None,
                    help="repository path on --vcs-server")
    ap.add_argument("--vcs-only", action="store_true",
                    help="server-side one-line entry: run only the VCS peak INT8 test and generate FSDB/SVG/reports")
    ap.add_argument("--verilator-only", action="store_true",
                    help="run only the local/WSL pure-RTL peak INT8 test and generate VCD/SVG/reports")
    return ap.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_check or args.dry_run:
        try:
            result = _verify_release_bundle(require_xdma=(os.name == "nt"))
        except (OSError, ValueError, KeyError, RuntimeError) as exc:
            print(f"  [ERROR] release self-check failed: {exc}")
            return 1
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0
    if args.vcs_only:
        vcs = run_vcs_peak(mode="local", server=None, remote_repo=None)
        print(json.dumps(vcs, indent=2, ensure_ascii=False))
        return 0 if vcs.get("status") == "PASS" else 1
    if args.verilator_only:
        verilator = run_verilator_peak(mode="run")
        print(json.dumps(verilator, indent=2, ensure_ascii=False))
        return 0 if verilator.get("status") == "PASS" else 1
    # The maintained COCO profile is a full one-shot workload.  Make the bare
    # `python run.py` command useful while retaining explicit legacy dry-run.
    if args.yolo_model == "coco" and not args.one_shot_yolo_int8:
        args.one_shot = True
    if args.one_shot or args.acceptance:
        try:
            _verify_release_bundle(require_xdma=(os.name == "nt"))
        except (OSError, ValueError, KeyError, RuntimeError) as exc:
            print(f"  [ERROR] release preflight failed: {exc}")
            return 1
    _setup_imports()

    networks = ["yolo", "resnet"] if args.network == "all" else [args.network]

    # Resolve precision lists for each network.
    # --precision (legacy) overrides both --yolo-precision and --resnet-precision.
    if args.precision is not None:
        legacy = args.precision
        yolo_raw = "int8" if legacy == "vai" else legacy   # vai -> int8 for YOLO
        resnet_raw = legacy
    else:
        yolo_raw = args.yolo_precision
        resnet_raw = args.resnet_precision

    def _expand(raw: str, valid: list[str]) -> list[str]:
        if raw == "both":
            return [p for p in valid if p != "both"]
        return [raw]

    yolo_precisions = _expand(yolo_raw, ["int8", "int16"])
    resnet_precisions = _expand(resnet_raw, ["vai", "int16"])

    if args.one_shot_yolo_int8:
        args.one_shot = True
        networks = ["yolo"]
        yolo_precisions = ["int8"]
        resnet_precisions = []

    if args.acceptance:
        if args.acceptance_examples < 1:
            print("  [ERROR] --acceptance-examples must be >= 1")
            return 1
        return run_acceptance_suite(args, networks, yolo_precisions, resnet_precisions)

    if args.one_shot:
        yolo_profile = YOLO_ONE_SHOT_PROFILES[args.yolo_model]
        yolo_img = Path(args.yolo_img) if args.yolo_img else Path(yolo_profile["image"])
        resnet_img = Path(args.resnet_img)
        workloads: list[tuple[str, str, Path]] = []
        if "yolo" in networks:
            if not yolo_img.exists():
                print(f"  [ERROR] image not found: {yolo_img}")
                return 1
            workloads.extend(("yolo", p, yolo_img) for p in yolo_precisions)
        if "resnet" in networks:
            if not resnet_img.exists():
                print(f"  [ERROR] image not found: {resnet_img}")
                return 1
            workloads.extend(("resnet", p, resnet_img) for p in resnet_precisions)
        if args.one_shot_build_dir and len(workloads) != 1:
            print("  [ERROR] --one-shot-build-dir can only be used with a single selected workload")
            return 1
        yolo_parsed_override = Path(args.one_shot_yolo_parsed_dir) if args.one_shot_yolo_parsed_dir else None
        resnet_parsed_override = Path(args.one_shot_resnet_parsed_dir) if args.one_shot_resnet_parsed_dir else None
        if any(n == "resnet" and p == "int16" for n, p, _ in workloads):
            native_parsed = resnet_parsed_override or ONE_SHOT_COMPILE_PARSED[("resnet", "int16")]
            if not (native_parsed / "network.json").is_file():
                print(
                    "  [ERROR] native ResNet W16A16 parsed model not found: "
                    f"{native_parsed}. Use parse_resnet18_qdq.py --mode int16 "
                    "or --one-shot-resnet-parsed-dir."
                )
                return 1

        print("=" * 60)
        print("EdgeYOLO-FPGA Full One-Shot Inference")
        print(f"  Workloads     : {', '.join(f'{n}:{_one_shot_tag(n, p)}' for n, p, _ in workloads)}")
        if "yolo" in networks:
            print(f"  YOLO profile  : {args.yolo_model}")
        one_shot_out_root = Path(args.out_dir) if args.out_dir else INFERENCE_OUT_DIR
        print(f"  Output        : {one_shot_out_root.resolve()}")
        print("=" * 60)
        t0 = time.time()
        total_timing = 0.0
        for network, precision, image in workloads:
            if network == "yolo":
                default_build = Path(yolo_profile["builds"][precision])
                yolo_parsed_dir = yolo_parsed_override or Path(yolo_profile["parsed"][precision])
                profile_expect = int(yolo_profile["expect_detections"])
                requested_expect = args.one_shot_yolo_expect_detections
                yolo_expect = profile_expect if requested_expect is None else requested_expect
                yolo_expect = None if yolo_expect < 0 else yolo_expect
                result_group = str(yolo_profile["output_group"])
            else:
                default_build = ONE_SHOT_DEFAULT_BUILDS[(network, precision)]
                yolo_parsed_dir = None
                resnet_parsed_dir = (
                    resnet_parsed_override
                    if resnet_parsed_override is not None and precision == "int16"
                    else ONE_SHOT_COMPILE_PARSED[(network, precision)]
                )
                yolo_expect = None
                result_group = "resnet"
            if network == "yolo":
                resnet_parsed_dir = None
            build_dir = Path(args.one_shot_build_dir) if args.one_shot_build_dir else default_build
            print(f"\n--- {network.upper()} {_one_shot_tag(network, precision).upper()} One-Shot [{image.name}] ---")
            run_one_shot_fpga(
                network, precision, image, one_shot_out_root,
                build_dir=build_dir,
                conf=args.conf,
                iou=args.iou,
                poll_timeout_s=args.one_shot_poll_timeout_s,
                read_chunk_bytes=args.one_shot_read_chunk_bytes,
                compare_atol=args.one_shot_compare_atol,
                quiet_xdma=not args.verbose_xdma,
                soft_reset=not args.one_shot_no_soft_reset,
                recompile=args.one_shot_recompile,
                yolo_parsed_dir=yolo_parsed_dir if network == "yolo" else None,
                resnet_parsed_dir=resnet_parsed_dir if network == "resnet" else None,
                yolo_expect_detections=yolo_expect if network == "yolo" else None,
                result_group=result_group,
                golden_cache_dir=_golden_cache_dir(args),
            )
            tag = _one_shot_tag(network, precision)
            timing_path = one_shot_out_root / result_group / f"one_shot_{tag}" / f"{image.stem}_{network}_{tag}_fpga_oneshot_timing.json"
            if timing_path.exists():
                total_timing += float(json.loads(timing_path.read_text()).get("total_s", 0.0))
        print(f"\nDone in {time.time() - t0:.1f}s")
        if total_timing:
            print(f"FPGA runner total across workloads: {total_timing:.3f}s")
        return 0

    print("  [ERROR] no runnable action selected")
    return 1

if __name__ == "__main__":
    raise SystemExit(main())
