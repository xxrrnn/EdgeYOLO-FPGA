"""Run host-side network heads from one-shot FPGA output features.

Allowed host boundaries:
  * YOLO: detect head + decode/NMS/postprocess.
  * ResNet: final FC/FFN + softmax/top-k.

The one-shot compiler exposes FP32 YOLO DQA features.  ResNet full-backbone
plans may expose the final activation after an FPGA QA step (INT8/INT16),
matching the older E2E host FC boundary.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np


REPO = Path(__file__).resolve().parents[2]
UNIT_TB = REPO / "test" / "network" / "host"
if str(UNIT_TB) not in sys.path:
    sys.path.insert(0, str(UNIT_TB))

from detect_head import DetectHead  # noqa: E402

COCO80_NAMES = [
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck",
    "boat", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench",
    "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra",
    "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
    "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove",
    "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup",
    "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange",
    "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
    "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse",
    "remote", "keyboard", "cell phone", "microwave", "oven", "toaster", "sink",
    "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
    "hair drier", "toothbrush",
]


def _load_unit_tb_run():
    path = UNIT_TB / "run.py"
    spec = importlib.util.spec_from_file_location("unit_tb_run", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def _read_tensor(path: Path, shape: tuple[int, int, int], dtype: str = "float32") -> np.ndarray:
    np_dtype = {"float32": np.float32, "int16": np.int16, "int8": np.int8, "uint8": np.uint8}.get(dtype)
    if np_dtype is None:
        raise ValueError(f"unsupported output dtype {dtype!r}")
    arr = np.fromfile(path, dtype=np_dtype)
    expected = int(np.prod(shape))
    if arr.size != expected:
        raise ValueError(f"{path}: got {arr.size} {dtype} values, expected {expected} for {shape}")
    return arr.reshape(shape)


def _read_fp32(path: Path, shape: tuple[int, int, int]) -> np.ndarray:
    return _read_tensor(path, shape, "float32").astype(np.float32, copy=False)


def _output_specs(plan: dict) -> list[dict]:
    host = plan["host_io"]
    return host.get("outputs") or [{
        "name": "output",
        "obuf_off": host["output_obuf_off"],
        "dtype": host.get("output_dtype", "float32"),
        "hw": host["output_hw"],
        "c": host["output_c"],
    }]


def _safe_output_name(name: str) -> str:
    return name.replace("/", "_").replace("\\", "_")


def _run_yolo(plan: dict, image_path: Path, output_dir: Path, parsed_dir: Path,
              conf: float, iou: float, expect_detections: int | None) -> dict:
    specs = {str(s["name"]): s for s in _output_specs(plan)}
    required = ["PAN_P3", "PAN_P4", "PAN_P5"]
    missing = [name for name in required if name not in specs]
    if missing:
        raise ValueError(f"YOLO host head needs {required}, missing {missing} in plan host_io.outputs")

    feats = []
    for name in required:
        spec = specs[name]
        h, w = [int(x) for x in spec["hw"]]
        c = int(spec["c"])
        feats.append(_read_fp32(output_dir / f"{_safe_output_name(name)}.bin", (h, w, c)))

    unit_run = _load_unit_tb_run()
    img_rgb = unit_run.load_image(str(image_path))
    _q, ratio, (dw, dh), orig_shape = unit_run.preprocess_yolov5n(img_rgb)

    head = DetectHead(str(parsed_dir / "weights"))
    # The trained host detect head expects quantized PAN features.  The one-shot
    # compiler exposes FP32 DQA features, so round them back to the per-scale
    # activation grids before running model.24 on host.  Native W16A16 plans
    # must retain the full INT16 grid here; clipping them to INT8 changes the
    # model inputs and invalidates the host-side detect result.
    mode = str(plan.get("mode", plan.get("compile_meta", {}).get("mode", "int8")))
    quant_dtype = np.int16 if mode == "int16" else np.int8
    quant_limit = 32767 if mode == "int16" else 127
    feats_q = []
    for i, feat in enumerate(feats):
        scale = float(head.convs[i]["act_scale"])
        feats_q.append(np.clip(np.round(feat / scale), -quant_limit, quant_limit).astype(quant_dtype))
    raw_preds = head.forward(feats_q[0], feats_q[1], feats_q[2])
    results = head.postprocess(raw_preds, conf_thres=conf, iou_thres=iou, img_size=320)

    if len(results) > 0:
        results[:, [0, 2]] = (results[:, [0, 2]] - dw) / ratio
        results[:, [1, 3]] = (results[:, [1, 3]] - dh) / ratio
        results[:, [0, 2]] = np.clip(results[:, [0, 2]], 0, orig_shape[1])
        results[:, [1, 3]] = np.clip(results[:, [1, 3]], 0, orig_shape[0])

    detections = []
    for row in results:
        detections.append({
            "bbox": [float(x) for x in row[:4]],
            "conf": float(row[4]),
            "class_score": float(row[5]),
            "class_id": int(row[6]),
            "class_name": _yolo_class_name(int(row[6]), parsed_dir),
        })
    result = {
        "network": "yolov5n",
        "image": str(image_path),
        "num_detections": len(detections),
        "detections": detections,
    }
    if expect_detections is not None:
        result["expect_detections"] = int(expect_detections)
        result["detections_match"] = len(detections) == int(expect_detections)
    return result


def _yolo_class_name(class_id: int, parsed_dir: Path) -> str:
    if class_id < 0:
        return f"class_{class_id}"
    try:
        net = json.loads((parsed_dir / "network.json").read_text())
    except Exception:
        net = {}
    names = net.get("class_names")
    if isinstance(names, list) and class_id < len(names):
        return str(names[class_id])
    if names == "coco" and class_id < len(COCO80_NAMES):
        return COCO80_NAMES[class_id]
    infrared = ["person", "car", "bicycle"]
    if class_id < len(infrared):
        return infrared[class_id]
    return f"class_{class_id}"


def _resnet_parsed_dir(mode: str, override: str | None) -> Path:
    if override:
        return Path(override)
    if mode == "int16":
        return REPO / "project" / "project" / "model" / "resnet18" / "parsed_int16"
    return REPO / "project" / "project" / "model" / "resnet18" / "parsed_vai"


def _run_resnet(plan: dict, image_path: Path, output: Path | None,
                parsed_dir: Path, topk: int, expect_top1: int | None) -> dict:
    import resnet_e2e

    specs = _output_specs(plan)
    spec = specs[-1]
    h, w = [int(x) for x in spec["hw"]]
    c = int(spec["c"])
    if output is None:
        raise ValueError("ResNet host head needs --output feature blob")
    feature = _read_tensor(output, (h, w, c), str(spec.get("dtype", "float32")))

    fc = resnet_e2e.load_fc_from_parsed(parsed_dir) or resnet_e2e.load_fc_from_onnx()
    last_scale_fn = getattr(resnet_e2e, "_last_act_scale", None)
    last_scale = float(last_scale_fn(parsed_dir)) if last_scale_fn else 1.0
    gap = feature.astype(np.float32).mean(axis=(0, 1)) * last_scale
    if fc is None:
        logits = gap
    else:
        weight, bias = fc
        logits = gap @ weight + bias if weight.shape[0] == gap.shape[0] else gap @ weight.T + bias
    logits = logits.astype(np.float32)
    order = np.argsort(logits)[-topk:][::-1]
    labels = resnet_e2e.CLASS_NAMES
    top = [
        {
            "class_id": int(i),
            "class_name": labels[int(i)] if int(i) < len(labels) else f"class_{int(i)}",
            "score": float(logits[int(i)]),
        }
        for i in order
    ]
    result = {
        "network": "resnet18",
        "image": str(image_path),
        "topk": top,
    }
    if expect_top1 is not None:
        result["expect_top1"] = int(expect_top1)
        result["top1_match"] = bool(top and top[0]["class_id"] == int(expect_top1))
    return result


def run_head(
    build_dir: Path,
    image: Path,
    *,
    network: str = "auto",
    output: str | Path | None = None,
    output_dir: str | Path | None = None,
    json_out: str | Path | None = None,
    conf: float = 0.25,
    iou: float = 0.45,
    topk: int = 5,
    expect_detections: int | None = None,
    expect_top1: int | None = None,
    parsed_dir: str | Path | None = None,
    yolo_parsed_dir: str | Path | None = None,
) -> dict:
    build_dir = Path(build_dir)
    plan = json.loads((build_dir / "plan.json").read_text())
    network_name = str(plan.get("network", "")).lower()
    if network != "auto":
        network_name = network
    mode = plan.get("mode", plan.get("compile_meta", {}).get("mode", "int8"))

    if "yolo" in network_name:
        if not output_dir:
            raise RuntimeError("YOLO host head needs output_dir with PAN_P3/PAN_P4/PAN_P5 blobs")
        result = _run_yolo(
            plan, Path(image), Path(output_dir),
            Path(yolo_parsed_dir) if yolo_parsed_dir else REPO / "project" / "project" / "model" / "yolov5n" / "parsed",
            conf, iou, expect_detections,
        )
    elif "resnet" in network_name:
        result = _run_resnet(
            plan, Path(image), Path(output) if output else None,
            _resnet_parsed_dir(mode, parsed_dir), topk, expect_top1,
        )
    else:
        raise RuntimeError(f"cannot infer network from plan: {plan.get('network')!r}")

    text = json.dumps(result, indent=2)
    print(text)
    if json_out:
        out = Path(json_out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(text + "\n")
    if result.get("top1_match") is False:
        raise RuntimeError("ResNet Top-1 did not match expected class")
    if result.get("detections_match") is False:
        raise RuntimeError("YOLO detection count did not match expected")
    return result


def main() -> None:
    ap = argparse.ArgumentParser(description="Run allowed host head from one-shot FPGA features")
    ap.add_argument("--build-dir", required=True)
    ap.add_argument("--image", required=True)
    ap.add_argument("--network", choices=["auto", "yolov5n", "resnet18"], default="auto")
    ap.add_argument("--output", default=None, help="primary output feature blob")
    ap.add_argument("--output-dir", default=None, help="named output feature directory")
    ap.add_argument("--json-out", default=None)
    ap.add_argument("--conf", type=float, default=0.25)
    ap.add_argument("--iou", type=float, default=0.45)
    ap.add_argument("--topk", type=int, default=5)
    ap.add_argument("--expect-detections", type=int, default=None,
                    help="optional YOLO detection-count gate")
    ap.add_argument("--expect-top1", type=int, default=None,
                    help="optional class id gate for ResNet Top-1")
    ap.add_argument("--parsed-dir", default=None, help="optional ResNet parsed dir")
    ap.add_argument("--yolo-parsed-dir", default=None,
                    help="optional YOLO parsed dir; run.py supplies the current COCO parsed directory")
    args = ap.parse_args()
    try:
        run_head(
            Path(args.build_dir),
            Path(args.image),
            network=args.network,
            output=args.output,
            output_dir=args.output_dir,
            json_out=args.json_out,
            conf=args.conf,
            iou=args.iou,
            topk=args.topk,
            expect_detections=args.expect_detections,
            expect_top1=args.expect_top1,
            parsed_dir=args.parsed_dir,
            yolo_parsed_dir=args.yolo_parsed_dir,
        )
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc


if __name__ == "__main__":
    main()
