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

  # 6. ResNet int8 + int16 都跑，dry-run：
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
        int16 : INT16 量化（精度略高，FPGA 通路宽度翻倍）
        both  : 同时运行 int8 + int16，输出两份结果

  --resnet-precision {vai,int8,int16,both}
      ResNet18 量化精度，默认 vai（推荐）：
        vai   : Vitis AI PTQ INT8 权重（ResNet_int.onnx），精度最高
        int8  : legacy torchvision FBGEMM INT8（需先运行 parse_resnet18_qdq.py）
        int16 : INT8 权重拓宽到 INT16 数据通路（数值等价于 int8，用于测试 INT16 通路）
        both  : 同时运行 int8 + int16

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
      输出目录根路径，默认 ./output/。
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
import sys
import time
from pathlib import Path

import numpy as np

REPO_ROOT = Path(__file__).resolve().parent
UNIT_TB = REPO_ROOT / "tests" / "chip" / "unit-tb"
OUT_DIR = REPO_ROOT / "output"

DEFAULT_YOLO_IMG = REPO_ROOT / "test_yolo.jpg"
DEFAULT_RESNET_IMG = REPO_ROOT / "test_resnet_2.JPEG"


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
    print(f"            -> {out_img.relative_to(REPO_ROOT)}")
    return out_img


# ─── ResNet ──────────────────────────────────────────────────────────────────

def run_resnet(img_path: Path, precision: str, runner, mode: str,
               out_dir: Path, verify: bool = True, preload_weights: bool = True) -> Path:
    resnet_e2e = importlib.import_module("resnet_e2e")
    dry_run = mode in ("dry-run", "onnx")

    runs_base = UNIT_TB / "runs" / "e2e" / f"resnet18_{precision}"
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
    print(f"            -> {out_img.relative_to(REPO_ROOT)}")
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
    print(f"            -> {out_json.relative_to(REPO_ROOT)}")
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
    ap.add_argument("--resnet-precision", choices=["vai", "int8", "int16", "both"], default="vai",
                    help="ResNet18 precision: vai=Vitis AI INT8 (推荐) / int8 / int16 / both (default: vai)")
    # Legacy alias kept for compatibility
    ap.add_argument("--precision", choices=["vai", "int8", "int16", "both"], default=None,
                    help="(deprecated) 同时设置 YOLO 和 ResNet 精度；建议用 --yolo-precision / --resnet-precision")
    ap.add_argument("--dry-run", action="store_true", help="numpy golden (no FPGA)")
    ap.add_argument("--onnx", action="store_true", help="also run ONNX baseline (ResNet)")
    ap.add_argument("--yolo-img", default=str(DEFAULT_YOLO_IMG))
    ap.add_argument("--resnet-img", default=str(DEFAULT_RESNET_IMG))
    ap.add_argument("--conf", type=float, default=0.15)
    ap.add_argument("--iou", type=float, default=0.45)
    ap.add_argument("--out-dir", default=str(OUT_DIR))
    ap.add_argument("--no-verify", action="store_true",
                    help="skip per-layer expected.hex comparison (faster inference, no FAIL reports)")
    ap.add_argument("--no-preload", action="store_true",
                    help="disable batch weight preload to HBM (use per-layer upload with content-hash cache)")
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
    resnet_precisions = _expand(resnet_raw, ["vai", "int8", "int16"])

    mode = "dry-run" if args.dry_run else "fpga"
    verify = not args.no_verify
    preload_weights = not getattr(args, 'no_preload', False)
    runner = make_runner(args.dry_run)

    yolo_img = Path(args.yolo_img)
    resnet_img = Path(args.resnet_img)
    yolo_out = Path(args.out_dir) / "yolo"
    resnet_out = Path(args.out_dir) / "resnet"

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
