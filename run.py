"""EdgeYOLO-FPGA E2E Inference 入口

概述
----
本脚本是端到端 (E2E) 推理的统一入口，支持两种网络：
  - YOLOv5n INT8 目标检测（红外图像，3 类：person/car/bicycle）
  - ResNet18 INT8 图像分类（ImageNet 1000 类，推荐用 Vitis AI 量化权重）

两种运行模式：
  dry-run : 用 numpy 模拟 FPGA 算子（无需 FPGA 硬件），结果与 FPGA 对齐
  fpga    : 通过 PCIe / XDMA 在 FPGA 上真实执行（需连接 FPGA 板卡）

快速开始
--------
  # 1. 测试环境（无 FPGA）：全网络 dry-run（YOLO int8+int16，ResNet vai）
  python run.py --dry-run

  # 2. FPGA 推理（需 FPGA 连接）：
  python run.py

  # 3. 只运行 YOLO INT8，dry-run：
  python run.py --network yolo --yolo-precision int8 --dry-run

  # 4. 只运行 YOLO INT8 + INT16，dry-run：
  python run.py --network yolo --yolo-precision both --dry-run

  # 5. 只运行 ResNet，Vitis AI 权重，dry-run：
  python run.py --network resnet --resnet-precision vai --dry-run

  # 6. ResNet VAI + INT16 都跑，dry-run：
  python run.py --network resnet --resnet-precision both --dry-run

  # 7. 同时跑 ONNX baseline 对比（需 onnxruntime）：
  python run.py --network resnet --resnet-precision vai --onnx --dry-run

  # 8. 自定义输入图片：
  python run.py --yolo-img path/to/infrared.jpg --resnet-img path/to/imagenet.jpg --dry-run

  # 9. FPGA 推理 + 跳过逐层验证（更快，不打印 FAIL/PASS）：
  python run.py --no-verify

  # 10. FPGA 推理 + 禁用批量权重预上传（退回逐层上传模式）：
  python run.py --no-preload

  # 11. FPGA 推理 + 最快模式（跳过验证 + 批量权重预上传）：
  python run.py --no-verify

命令行参数详解
--------------
  --network {yolo,resnet,all}
      选择运行哪个网络，默认 all（同时运行 YOLO + ResNet）。

  --yolo-precision {int8,int16,both}
      YOLOv5n 量化精度，默认 both（同时运行 int8 + int16）：
        int8  : INT8 量化（速度最快，推荐日常使用）
        int16 : INT8 升位 INT16（权重数值不变，dtype 扩为 int16，用于验证 FPGA INT16 数据通路，结果应与 int8 bit-exact 一致）
        both  : 同时运行 int8 + int16，输出两份结果

  --resnet-precision {vai,int16,both}
      ResNet18 量化精度，默认 both（同时运行 vai + int16）：
        vai   : Vitis AI PTQ INT8（ResNet_int.onnx），精度最高，推荐使用
        int16 : VAI 权重升位 INT16（数值等价于 vai，用于验证 FPGA INT16 数据通路）
        both  : 同时运行 vai + int16，输出两份结果（两者结果应 bit-exact 一致）

  --precision {vai,int8,int16,both}
      （兼容旧版）同时设置 YOLO 和 ResNet 的精度；
      建议改用 --yolo-precision / --resnet-precision 分别控制。
      vai → YOLO 使用 int8，ResNet 使用 vai。

  --dry-run
      使用 numpy golden 模拟 FPGA，无需 FPGA 硬件。
      输出与 FPGA 模式数值对齐（±1 LSB 以内）。

  --onnx
      （仅 ResNet）额外运行 onnxruntime baseline 进行对比。
      需要安装 onnxruntime，模型文件 ResNet_int.onnx 需存在。

  --yolo-img PATH
      YOLO 输入图片路径（默认 test_yolo.jpg，红外人员检测图）。

  --resnet-img PATH
      ResNet 输入图片路径（默认 test_resnet_2.JPEG，ImageNet 金鱼图）。

  --conf FLOAT
      YOLO 检测置信度阈值，默认 0.15。降低可检测更多目标，升高可减少误检。

  --iou FLOAT
      YOLO NMS IoU 阈值，默认 0.45。

  --out-dir PATH
      输出目录根路径；one-shot 默认 ./output/inference/，legacy E2E/dry-run 默认 ./output/。
      YOLO 结果存 {out-dir}/yolo/，ResNet 结果存 {out-dir}/resnet/。

  --no-verify
      跳过逐层 expected.hex 对比验证，加速 FPGA 推理。
      推荐在确认模型对齐后正式推理时使用（约节省 30% 时间）。
      对 dry-run 无效（dry-run 始终跳过 FPGA 验证）。

  --no-preload
      禁用批量权重预上传到 HBM 池（回退到逐层 content-hash 缓存模式）。
      默认开启批量预上传（推荐），可显著减少 PCIe 权重传输次数。

输入文件
--------
  test_yolo.jpg        : 红外图像（推荐 640×480，对应 YOLOv5n 输入 640×640 letterbox）
  test_resnet_2.JPEG   : 自然图像（推荐 ≥224×224，ResNet18 输入 224×224 center-crop）

输出文件结构
------------
  output/
    yolo/
      {stem}_{precision}_dry-run.jpg   # 带检测框的图片（dry-run）
      {stem}_{precision}_dry-run.json  # 检测结果 JSON
      {stem}_{precision}_fpga.jpg      # 带检测框的图片（FPGA）
      {stem}_{precision}_fpga.json     # 检测结果 JSON
    resnet/
      {stem}_{precision}_dry-run.jpg   # 带 Top-5 分类结果的图片
      {stem}_{precision}_dry-run.json  # Top-5 JSON（含类名 + 分数）
      {stem}_{precision}_fpga.jpg
      {stem}_{precision}_fpga.json
      {stem}_vai_onnx.jpg              # ONNX baseline（需 --onnx）
      {stem}_vai_onnx.json

JSON 格式
---------
  YOLO JSON：
    [{"bbox": [x1, y1, x2, y2], "confidence": 0.85, "class": 0}, ...]
    class: 0=person, 1=car, 2=bicycle

  ResNet JSON：
    {"top5": [{"class": 1, "name": "goldfish", "score": 12.34}, ...],
     "precision": "vai", "mode": "fpga"}

FPGA 推理加速选项（性能调优）
-----------------------------
  默认推理流程（--no-verify 关闭时）每层会：
    1. 上传 src0.hex（输入特征图） → PCIe
    2. 上传权重（weight_tile*.hex + wb_init.hex）→ PCIe（有 content-hash 缓存）
    3. 上传 inst.hex（指令）→ PCIe
    4. 启动 decoder，等待完成
    5. 读回输出，与 expected.hex 对比 → PCIe

  开启 --no-verify（跳过步骤 5）：
    减少一次 PCIe 读操作，推理加速约 10-15%。

  默认开启批量预上传（preload_weights=True）：
    推理前一次性将全部层权重（~1.7 MB）上传到 HBM 专用池（HBM+0x200000），
    推理时每层跳过权重上传，只上传 src0.hex + inst.hex。
    预期再减少约 40-60% 的 PCIe 传输量。

  组合使用 --no-verify 可达最快推理速度。

依赖安装
--------
  conda activate chip_test_env
  # 或
  pip install numpy pillow onnxruntime

  # 量化工具（仅需重新量化时）：
  pip install torch torchvision vai-q-pytorch

  # FPGA 驱动（仅需 FPGA 硬件时）：
  # 确认 tests/xdma_exe/xdma_rw.exe 存在且 FPGA 已通过 PCIe 连接

网络结构简介
------------
  YOLOv5n backbone + neck（57 conv 层）在 FPGA DCIM 上执行：
    - backbone: model.0 ~ model.10（stem + C3 block × 4 + SPPF）
    - neck: model.13/14/17/18/20/21/23（FPN + PAN，含 C3 block）
    - detect head: model.24 在 host CPU 执行（FP32 矩阵乘）

  ResNet18 全部卷积层在 FPGA DCIM 上执行：
    - conv1 + maxpool + 4 stages × 2 BasicBlocks（共 16 conv）
    - Global Average Pool + FC 在 host CPU 执行

  DCIM 硬件算子：im2col → DCIM INT8 矩阵乘 → DQA → QA
  VPU 硬件算子：element-wise add INT8（Bottleneck shortcut）

故障排除
--------
  Q: FileNotFoundError: xdma_rw.exe not found
  A: 确认 tests/xdma_exe/xdma_rw.exe 存在，或通过 --dry-run 运行。

  Q: TimeoutError: Decoder timeout
  A: FPGA 可能卡住，重新插拔 PCIe 或重启 FPGA 驱动。

  Q: ResNet 分类结果不对（不是 goldfish）
  A: 确认使用 --precision vai（Vitis AI 权重），legacy int8 精度较低。

  Q: YOLO 检测不到目标
  A: 降低 --conf（如 0.05），或确认输入是红外图像（非可见光）。

  Q: [FAIL] xxx 1234/5678 words
  A: 正常现象，±1 LSB 舍入误差，不影响推理结果。用 --no-verify 可关闭输出。
"""
from __future__ import annotations

import argparse
import importlib.util
import importlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import numpy as np

REPO_ROOT = Path(__file__).resolve().parent
UNIT_TB = REPO_ROOT / "tests" / "chip" / "unit-tb"
OUT_DIR = REPO_ROOT / "output"
INFERENCE_OUT_DIR = OUT_DIR / "inference"
WORK_DIR_ENV = "EDGEYOLO_RUNS_BASE"

DEFAULT_YOLO_IMG = REPO_ROOT / "test_yolo.jpg"
DEFAULT_RESNET_IMG = REPO_ROOT / "test_resnet_2.JPEG"

ONE_SHOT_DEFAULT_BUILDS = {
    ("yolo", "int8"): OUT_DIR / "compile_yolo_int8_full_eff",
    ("yolo", "int16"): OUT_DIR / "compile_yolo_int16_full_eff",
    ("resnet", "vai"): OUT_DIR / "compile_resnet_vai_full_qdq_fixscale",
    ("resnet", "int16"): OUT_DIR / "compile_resnet_int16_full_qdq_fixscale",
}

ONE_SHOT_COMPILE_PARSED = {
    ("resnet", "vai"): REPO_ROOT / "model" / "resnet18" / "parsed_vai",
    ("resnet", "int16"): REPO_ROOT / "model" / "resnet18" / "parsed_vai_int16_widened",
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


def make_runner(dry_run: bool):
    if dry_run:
        return None
    ChipRunnerWin = importlib.import_module("xdma_win").ChipRunnerWin
    return ChipRunnerWin(verbose=False)


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


def _compile_one_shot_artifact(network: str, precision: str, build_dir: Path,
                               parsed_override: Path | None = None) -> None:
    compile_network = "yolov5n" if network == "yolo" else "resnet18"
    mode = _one_shot_tag(network, precision)
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
    compare_atol: float,
    quiet_xdma: bool,
    soft_reset: bool,
    recompile: bool,
    yolo_parsed_dir: Path | None = None,
    yolo_expect_detections: int | None = 1,
) -> Path:
    """Run a full one-shot FPGA workload, compare features, and run the host boundary."""
    runtime = REPO_ROOT / "tests" / "chip" / "runtime"
    tag = _one_shot_tag(network, precision)
    net_dir = "yolo" if network == "yolo" else "resnet"
    label = f"{'YOLO' if network == 'yolo' else 'ResNet'} {tag.upper()}"
    out_dir = out_root / net_dir / f"one_shot_{tag}"
    feat_dir = out_dir / "features"
    out_dir.mkdir(parents=True, exist_ok=True)

    if recompile or not (build_dir / "plan.json").exists():
        reason = "requested" if recompile else f"missing {build_dir / 'plan.json'}"
        print(f"  [compile] {reason}, compiling {label} full one-shot", flush=True)
        _compile_one_shot_artifact(network, precision, build_dir, yolo_parsed_dir if network == "yolo" else None)

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
        head_cmd.extend(["--expect-top1", "1"])
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


def run_yolo_int8_one_shot_fpga(
    img_path: Path,
    out_root: Path,
    *,
    build_dir: Path,
    conf: float,
    iou: float,
    poll_timeout_s: float,
    quiet_xdma: bool,
    soft_reset: bool,
    recompile: bool,
    yolo_parsed_dir: Path | None = None,
    yolo_expect_detections: int | None = 1,
) -> Path:
    """Compatibility wrapper for the old YOLO INT8-only one-shot CLI."""
    return run_one_shot_fpga(
        "yolo", "int8", img_path, out_root,
        build_dir=build_dir,
        conf=conf,
        iou=iou,
        poll_timeout_s=poll_timeout_s,
        read_chunk_bytes=65536,
        compare_atol=1e-3,
        quiet_xdma=quiet_xdma,
        soft_reset=soft_reset,
        recompile=recompile,
        yolo_parsed_dir=yolo_parsed_dir,
        yolo_expect_detections=yolo_expect_detections,
    )


# ─── YOLO ────────────────────────────────────────────────────────────────────

def run_yolo(img_path: Path, precision: str, runner, mode: str,
             out_dir: Path, conf: float, iou: float,
             verify: bool = True, preload_weights: bool = True) -> Path:
    verify_e2e = importlib.import_module("verify_e2e")
    dry_run = mode in ("dry-run", "onnx")

    img_out, dets = verify_e2e.run_image(
        str(img_path), runner, dry_run, precision=precision,
        conf=conf, iou=iou, verify=verify, preload_weights=preload_weights,
    )

    stem = img_path.stem
    img_name = f"{stem}_{precision}_{mode}.jpg"
    json_name = f"{stem}_{precision}_{mode}.json"
    out_img = out_dir / img_name
    out_json = out_dir / json_name

    save_image(img_out, out_img)

    det_list = []
    for d in dets:
        det_list.append({
            "bbox": [float(d[0]), float(d[1]), float(d[2]), float(d[3])],
            "confidence": float(d[4]),
            "class": int(d[5]),
        })
    out_json.write_text(json.dumps(det_list, indent=2))

    n = len(dets)
    confs = ", ".join(f"{d['confidence']:.2f}" for d in det_list[:5]) or "none"
    print(f"  [{mode:7s}] YOLO {precision.upper():5s}: {n} det [{confs}]")
    print(f"            -> {_display_path(out_img)}")
    return out_img


# ─── ResNet ──────────────────────────────────────────────────────────────────

def run_resnet(img_path: Path, precision: str, runner, mode: str,
               out_dir: Path, verify: bool = True, preload_weights: bool = True) -> Path:
    resnet_e2e = importlib.import_module("resnet_e2e")
    dry_run = mode in ("dry-run", "onnx")

    runs_root = Path(os.environ.get(WORK_DIR_ENV, str(OUT_DIR / "work" / "e2e")))
    runs_base = runs_root / f"resnet18_{precision}"
    img_out, top5, logits = resnet_e2e.run_single_image(
        str(img_path), runner, dry_run, precision=precision,
        runs_base=runs_base, verify=verify, preload_weights=preload_weights,
    )

    class_names = resnet_e2e.CLASS_NAMES

    stem = img_path.stem
    img_name = f"{stem}_{precision}_{mode}.jpg"
    json_name = f"{stem}_{precision}_{mode}.json"
    out_img = out_dir / img_name
    out_json = out_dir / json_name

    save_image(img_out, out_img)

    result = {
        "top5": [{"class": idx, "name": class_names[idx], "score": round(score, 4)}
                 for idx, score in top5],
        "precision": precision,
        "mode": mode,
    }
    out_json.write_text(json.dumps(result, indent=2, ensure_ascii=False))

    top_str = ", ".join(f"{t['name']}({t['class']}):{t['score']:.3f}" for t in result["top5"][:3])
    print(f"  [{mode:7s}] ResNet18 {precision.upper():5s}: [{top_str}]")
    print(f"            -> {_display_path(out_img)}")
    return out_img


def run_resnet_onnx(img_path: Path, out_dir: Path) -> Path:
    """Run ResNet via onnxruntime (Vitis AI ResNet_int.onnx) as ONNX baseline."""
    import onnxruntime as ort
    from PIL import Image

    # Prefer Vitis AI model; fall back to legacy QDQ
    vai_onnx = (REPO_ROOT / "model" / "algorithm" / "Resnet18-quantization"
                / "resnet18" / "quantize_result" / "ResNet_int.onnx")
    legacy_onnx = REPO_ROOT / "model" / "resnet18" / "resnet18_w8a8.onnx"
    onnx_path = vai_onnx if vai_onnx.exists() else legacy_onnx
    model_tag = "Vitis-AI" if onnx_path == vai_onnx else "QDQ(legacy)"

    if not onnx_path.exists():
        print("  [onnx   ] ResNet18: SKIP (model not found)")
        return out_dir

    img = Image.open(str(img_path)).convert("RGB").resize((256, 256), Image.BILINEAR)
    left = top = (256 - 224) // 2
    img = img.crop((left, top, left + 224, top + 224))
    arr = np.array(img).astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    img_chw = ((arr - mean) / std).transpose(2, 0, 1)

    sess = ort.InferenceSession(str(onnx_path))
    inp_name = sess.get_inputs()[0].name
    logits = sess.run(None, {inp_name: img_chw[None].astype(np.float32)})[0][0]
    top5_idx = np.argsort(logits)[-5:][::-1]
    top5 = [(int(i), round(float(logits[i]), 4)) for i in top5_idx]

    label_path = REPO_ROOT / "model" / "resnet18" / "imagenet_labels.json"
    class_names = json.loads(label_path.read_text()) if label_path.exists() \
        else [f"class_{i}" for i in range(1000)]

    stem = img_path.stem
    out_json = out_dir / f"{stem}_vai_onnx.json"
    result = {
        "top5": [{"class": idx, "name": class_names[idx], "score": score}
                 for idx, score in top5],
        "precision": f"int8 ({model_tag})",
        "mode": "onnx",
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    out_json.write_text(json.dumps(result, indent=2, ensure_ascii=False))

    top_str = ", ".join(f"{t['name']}({t['class']}):{t['score']:.3f}" for t in result["top5"][:3])
    print(f"  [onnx   ] ResNet18 {model_tag:12s}: [{top_str}]")
    print(f"            -> {_display_path(out_json)}")
    return out_json


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
    ap.add_argument("--resnet-precision", choices=["vai", "int16", "both"], default="both",
                    help="ResNet18 precision: vai=Vitis AI INT8 / int16=VAI widened to INT16 / both (default: both)")
    # Legacy alias kept for compatibility
    ap.add_argument("--precision", choices=["vai", "int8", "int16", "both"], default=None,
                    help="(deprecated) 同时设置 YOLO 和 ResNet 精度；建议用 --yolo-precision / --resnet-precision")
    ap.add_argument("--dry-run", action="store_true", help="numpy golden (no FPGA)")
    ap.add_argument("--onnx", action="store_true", help="also run ONNX baseline (ResNet)")
    ap.add_argument("--yolo-img", default=str(DEFAULT_YOLO_IMG))
    ap.add_argument("--resnet-img", default=str(DEFAULT_RESNET_IMG))
    ap.add_argument("--conf", type=float, default=0.15)
    ap.add_argument("--iou", type=float, default=0.45)
    ap.add_argument("--out-dir", default=None,
                    help="output root; default is output/inference for --one-shot, output for legacy E2E/dry-run")
    ap.add_argument("--no-verify", action="store_true",
                    help="skip per-layer expected.hex comparison (faster inference, no FAIL reports)")
    ap.add_argument("--no-preload", action="store_true",
                    help="disable batch weight preload to HBM (use per-layer upload with content-hash cache)")
    ap.add_argument("--reuse-cases", action="store_true",
                    help="reuse existing output/work/e2e case files and skip online dry-run case generation")
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
    ap.add_argument("--one-shot-compare-atol", type=float, default=1e-3,
                    help="absolute tolerance for FPGA versus compiler-feature comparison (default: 1e-3)")
    ap.add_argument("--one-shot-no-soft-reset", action="store_true",
                    help="do not issue decoder soft reset before one-shot execution")
    ap.add_argument("--one-shot-recompile", action="store_true",
                    help="recompile selected full one-shot artifacts before running FPGA")
    ap.add_argument("--one-shot-yolo-parsed-dir", default=None,
                    help="override YOLO parsed dir for one-shot compile/input/host head")
    ap.add_argument("--one-shot-yolo-expect-detections", type=int, default=1,
                    help="YOLO detection-count gate in one-shot mode; use -1 to disable")
    ap.add_argument("--verbose-xdma", action="store_true",
                    help="show verbose xdma_rw.exe commands in one-shot mode")
    return ap.parse_args()


def main() -> int:
    args = parse_args()
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

    if args.one_shot:
        if args.dry_run:
            print("  [ERROR] --one-shot requires FPGA; remove --dry-run")
            return 1
        yolo_img = Path(args.yolo_img)
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
        yolo_parsed_dir = Path(args.one_shot_yolo_parsed_dir) if args.one_shot_yolo_parsed_dir else None
        yolo_expect = None if args.one_shot_yolo_expect_detections < 0 else args.one_shot_yolo_expect_detections

        print("=" * 60)
        print("EdgeYOLO-FPGA Full One-Shot Inference")
        print(f"  Workloads     : {', '.join(f'{n}:{_one_shot_tag(n, p)}' for n, p, _ in workloads)}")
        one_shot_out_root = Path(args.out_dir) if args.out_dir else INFERENCE_OUT_DIR
        print(f"  Output        : {one_shot_out_root.resolve()}")
        print("=" * 60)
        t0 = time.time()
        total_timing = 0.0
        for network, precision, image in workloads:
            build_dir = Path(args.one_shot_build_dir) if args.one_shot_build_dir else ONE_SHOT_DEFAULT_BUILDS[(network, precision)]
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
                yolo_expect_detections=yolo_expect if network == "yolo" else None,
            )
            tag = _one_shot_tag(network, precision)
            timing_path = one_shot_out_root / ("yolo" if network == "yolo" else "resnet") / f"one_shot_{tag}" / f"{image.stem}_{network}_{tag}_fpga_oneshot_timing.json"
            if timing_path.exists():
                total_timing += float(json.loads(timing_path.read_text()).get("total_s", 0.0))
        print(f"\nDone in {time.time() - t0:.1f}s")
        if total_timing:
            print(f"FPGA runner total across workloads: {total_timing:.3f}s")
        return 0

    mode = "dry-run" if args.dry_run else "fpga"
    verify = not args.no_verify
    preload_weights = not getattr(args, 'no_preload', False)
    runner = make_runner(args.dry_run)

    yolo_img = Path(args.yolo_img)
    resnet_img = Path(args.resnet_img)
    out_root = Path(args.out_dir) if args.out_dir else OUT_DIR
    yolo_out = out_root / "yolo"
    resnet_out = out_root / "resnet"
    work_root = out_root / "work" / "e2e"

    # Clear result directories before generating new outputs, but keep
    # output/work/e2e so generated case files can be reused across runs.
    import shutil
    for result_dir in (yolo_out, resnet_out):
        if result_dir.exists():
            shutil.rmtree(result_dir)
    yolo_out.mkdir(parents=True, exist_ok=True)
    resnet_out.mkdir(parents=True, exist_ok=True)
    work_root.mkdir(parents=True, exist_ok=True)
    os.environ[WORK_DIR_ENV] = str(work_root)
    os.environ["EDGEYOLO_REUSE_CASES"] = "1" if args.reuse_cases else "0"

    print("=" * 60)
    print("EdgeYOLO-FPGA E2E Inference")
    print(f"  Mode          : {mode.upper()}")
    print(f"  Networks      : {', '.join(networks)}")
    if "yolo" in networks:
        print(f"  YOLO prec     : {', '.join(yolo_precisions)}")
    if "resnet" in networks:
        print(f"  ResNet prec   : {', '.join(resnet_precisions)}")
    print(f"  Verify        : {'YES' if verify else 'NO (--no-verify)'}")
    print(f"  Preload       : {'YES' if preload_weights else 'NO (--no-preload)'}")
    if "yolo" in networks:
        print(f"  YOLO input    : {yolo_img}")
    if "resnet" in networks:
        print(f"  ResNet input  : {resnet_img}")
    print(f"  Output        : {Path(args.out_dir).resolve()}")
    print("=" * 60)

    t0 = time.time()

    if "yolo" in networks:
        print(f"\n--- YOLO Detection [{yolo_img.name}] ---")
        if not yolo_img.exists():
            print(f"  [ERROR] image not found: {yolo_img}")
            return 1
        for prec in yolo_precisions:
            run_yolo(yolo_img, prec, runner, mode, yolo_out, args.conf, args.iou,
                     verify=verify, preload_weights=preload_weights)

    if "resnet" in networks:
        print(f"\n--- ResNet Classification [{resnet_img.name}] ---")
        if not resnet_img.exists():
            print(f"  [ERROR] image not found: {resnet_img}")
            return 1
        for prec in resnet_precisions:
            run_resnet(resnet_img, prec, runner, mode, resnet_out,
                       verify=verify, preload_weights=preload_weights)
        if args.onnx:
            run_resnet_onnx(resnet_img, resnet_out)

    print(f"\nDone in {time.time() - t0:.1f}s")
    print(f"Results: {Path(args.out_dir).resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
