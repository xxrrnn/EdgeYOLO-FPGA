"""Compare one-shot FPGA output blobs with numpy golden tensors.

This script mirrors the compiler's current YOLO execution semantics:
conv produces FP32 DQA output, later conv inputs are quantized at the conv
entry, and VPU ops consume/produce FP32 tensors.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[3]
UNIT_TB = REPO / "tests" / "chip" / "unit-tb"
GMT = REPO / "rtl" / "tb" / "lite_bd" / "module_tb"
LOWERING = REPO / "tests" / "chip" / "compiler" / "lowering"
for p in (UNIT_TB, GMT, LOWERING):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

from golden_module_tb import (  # noqa: E402
    im2col,
    im2col_int16,
    load_layer_npz_checked,
    load_network,
    maxpool_generic,
    conv_meta,
    out_hw,
)
from yolov5n_schedule import YOLOV5N_SCHEDULE  # noqa: E402


def _load_unit_tb_run():
    path = UNIT_TB / "run.py"
    spec = importlib.util.spec_from_file_location("unit_tb_run", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def _quantize_fp32(x: np.ndarray, act_scale: float, mode: str) -> np.ndarray:
    if mode == "int16":
        return np.clip(np.round(x / act_scale), -32768, 32767).astype(np.int16)
    return np.clip(np.round(x / act_scale), -128, 127).astype(np.int8)


def _safe_name(name: str) -> str:
    return name.replace(".", "_").replace("/", "_")


def _upsample_fp32(x: np.ndarray) -> np.ndarray:
    return np.repeat(np.repeat(x, 2, axis=0), 2, axis=1).astype(np.float32)


def _conv_dqa_fp32(feat: np.ndarray, meta, npz, mode: str, *, relu: bool = True) -> np.ndarray:
    h, w, _c = feat.shape
    if mode == "int16":
        feat_q = feat.astype(np.int16, copy=False)
        cols = im2col_int16(feat_q, meta)
        matmul_dtype = np.float32
    else:
        feat_q = feat.astype(np.int8, copy=False)
        cols = im2col(feat_q, meta)
        matmul_dtype = np.int32

    weights = npz["weight_int8"].reshape(meta.out_ch, -1).astype(matmul_dtype)
    if weights.shape[1] < cols.shape[1]:
        weights = np.pad(weights, ((0, 0), (0, cols.shape[1] - weights.shape[1])))
    accum = cols.astype(matmul_dtype) @ weights[:, :cols.shape[1]].T
    scale = npz["dqa_scale"].astype(np.float32)[:meta.out_ch]
    bias = npz["dqa_bias"].astype(np.float32)[:meta.out_ch]
    dqa = accum.astype(np.float32) * scale[None, :] + bias[None, :]
    if relu:
        dqa = np.maximum(dqa, 0.0)
    oh, ow = out_hw(h, w, meta)
    return dqa.reshape(oh, ow, meta.out_ch).astype(np.float32)


def run_yolo_compiler_golden(image_path: Path, mode: str, max_layers: int | None,
                             parsed_override: str | None = None) -> tuple[np.ndarray, dict[str, np.ndarray]]:
    unit_run = _load_unit_tb_run()
    parsed_dir = Path(parsed_override) if parsed_override else REPO / "model" / "yolov5n" / ("parsed_int16_widened" if mode == "int16" else "parsed")
    network_json = parsed_dir / "network.json"
    parsed = json.loads(network_json.read_text())
    unit_run.ACT_SCALE = float(parsed.get("input_act_scale", unit_run.ACT_SCALE))
    img = unit_run.load_image(str(image_path))
    if mode == "int16":
        padded, _ratio, _pad = unit_run.letterbox(img, unit_run.IMG_SIZE_YOLO)
        fp32 = padded.astype(np.float32) / 255.0
        cur = np.clip(np.round(fp32 / float(unit_run.ACT_SCALE)), -32768, 32767).astype(np.int16)
    else:
        q, _ratio, _pad, _orig = unit_run.preprocess_yolov5n(img)
        cur = q

    layer_names = [layer["name"] for layer in parsed["layers"]]
    net = load_network(str(network_json))
    named: dict[str, np.ndarray] = {}
    outputs: dict[str, np.ndarray] = {}
    conv_count = 0

    for step in YOLOV5N_SCHEDULE:
        action = step[0]
        if action == "conv":
            if max_layers is not None and conv_count >= max_layers:
                break
            layer_idx = int(step[1])
            layer_name = layer_names[layer_idx]
            meta = conv_meta(net, layer_name)
            npz = np.load(parsed_dir / "weights" / f"{_safe_name(layer_name)}.npz")
            if np.issubdtype(cur.dtype, np.floating):
                cur_q = _quantize_fp32(cur, float(npz["act_scale"]), mode)
            else:
                cur_q = cur
            cur = _conv_dqa_fp32(
                cur_q, meta, npz, mode,
                relu=bool(parsed["layers"][layer_idx].get("has_activation", True)),
            )
            conv_count += 1
            if max_layers is not None and conv_count >= max_layers:
                break
        elif action == "save":
            named[str(step[1])] = cur.copy()
            if str(step[1]).startswith("PAN_P"):
                outputs[str(step[1])] = named[str(step[1])]
        elif action == "load":
            cur = named[str(step[1])].copy()
        elif action == "concat":
            cur = np.concatenate([named[str(n)] for n in step[1]], axis=-1).astype(np.float32)
        elif action == "upsample":
            cur = _upsample_fp32(named[str(step[1])])
        elif action == "maxpool":
            cur = maxpool_generic(named[str(step[1])].astype(np.float32), kernel=5, stride=1, pad=2)
        elif action == "add":
            cur = (cur.astype(np.float32) + named[str(step[1])].astype(np.float32)).astype(np.float32)
        else:
            raise ValueError(f"unknown schedule action {action!r}")

    return cur.astype(np.float32), outputs


RESNET_BLOCK_SCHEDULE = [
    ("layer1.0.Add", [1, 2], None),
    ("layer1.1.Add", [3, 4], None),
    ("layer2.0.Add", [5, 6], 7),
    ("layer2.1.Add", [8, 9], None),
    ("layer3.0.Add", [10, 11], 12),
    ("layer3.1.Add", [13, 14], None),
    ("layer4.0.Add", [15, 16], 17),
    ("layer4.1.Add", [18, 19], None),
]


def _resnet_parsed_dir(mode: str, override: str | None) -> Path:
    if override:
        return Path(override)
    if mode == "int16":
        return REPO / "model" / "resnet18" / "parsed_vai_int16_widened"
    return REPO / "model" / "resnet18" / "parsed_vai"


def _load_resnet_input(image_path: Path, parsed_dir: Path) -> np.ndarray:
    import resnet_e2e

    img = resnet_e2e.load_image(str(image_path))
    return resnet_e2e.preprocess_resnet18(img, parsed_dir)


def _act_qdq_fp32(feat: np.ndarray, scale: float, mode: str) -> np.ndarray:
    q = _quantize_fp32(feat.astype(np.float32), float(scale), mode)
    return q.astype(np.float32) * float(scale)


def _maxpool_3x3_s2_fp32(feat: np.ndarray, scale: float | None = None,
                         mode: str = "int8") -> np.ndarray:
    out = maxpool_generic(feat.astype(np.float32), kernel=3, stride=2, pad=1).astype(np.float32)
    if scale is not None:
        out = _act_qdq_fp32(out, float(scale), mode)
    return out


def _resnet_layer_npz(parsed_dir: Path, layer_name: str):
    return np.load(parsed_dir / "weights" / f"{_safe_name(layer_name)}.npz")


def _resnet_add_scales(parsed_dir: Path) -> dict[str, float]:
    path = parsed_dir / "add_output_scales.json"
    if not path.exists():
        fallback = parsed_dir.parent / "parsed_vai" / "add_output_scales.json"
        path = fallback if fallback.exists() else path
    if not path.exists():
        return {}
    return {str(k): float(v) for k, v in json.loads(path.read_text()).items()}


def _resnet_conv(cur: np.ndarray, net: dict, layer: dict, parsed_dir: Path, mode: str,
                 *, skip_qa: bool = False, input_scale: float | None = None) -> np.ndarray:
    meta = conv_meta(net, layer["name"])
    npz = _resnet_layer_npz(parsed_dir, layer["name"])
    if skip_qa:
        cur_q = cur
    else:
        qa_scale = float(input_scale) if input_scale is not None else float(npz["act_scale"])
        cur_q = _quantize_fp32(cur.astype(np.float32), qa_scale, mode)
    out = _conv_dqa_fp32(
        cur_q, meta, npz, mode,
        relu=bool(layer.get("has_activation", True)),
    )
    if "act_scale" in npz.files:
        out = _act_qdq_fp32(out, float(npz["act_scale"]), mode)
    return out


def run_resnet_compiler_golden(image_path: Path, mode: str, max_layers: int | None,
                               parsed_override: str | None = None,
                               quantize_residuals: bool = False,
                               output_dtype: str = "float32") -> np.ndarray:
    parsed_dir = _resnet_parsed_dir(mode, parsed_override)
    network_json = parsed_dir / "network.json"
    network = json.loads(network_json.read_text())
    layers = network["layers"]
    net = load_network(str(network_json))
    add_scales = _resnet_add_scales(parsed_dir)
    n_conv = min(len(layers), max_layers) if max_layers else len(layers)

    cur: np.ndarray = _load_resnet_input(image_path, parsed_dir)
    conv_count = 0
    cur_scale: float | None = None

    if conv_count < n_conv:
        cur = _resnet_conv(cur, net, layers[0], parsed_dir, mode, skip_qa=True)
        cur_scale = float(_resnet_layer_npz(parsed_dir, layers[0]["name"])["act_scale"])
        conv_count += 1

    # Full lowering always runs the stem maxpool once conv1 is present.
    if conv_count > 0:
        pool_scale = None
        network_pool_scale = network.get("maxpool_output_scale")
        if network_pool_scale is not None:
            pool_scale = float(network_pool_scale)
        elif cur_scale is not None:
            pool_scale = float(cur_scale)
        cur = _maxpool_3x3_s2_fp32(cur, pool_scale, mode)
        cur_scale = pool_scale

    for add_name, conv_ids, ds_idx in RESNET_BLOCK_SCHEDULE:
        if conv_ids[0] >= n_conv:
            break
        identity = cur.copy()
        identity_scale = cur_scale

        if conv_ids[0] < n_conv:
            cur = _resnet_conv(cur, net, layers[conv_ids[0]], parsed_dir, mode, input_scale=cur_scale)
            cur_scale = float(_resnet_layer_npz(parsed_dir, layers[conv_ids[0]]["name"])["act_scale"])
            conv_count += 1

        if len(conv_ids) > 1 and conv_ids[1] < n_conv:
            cur = _resnet_conv(cur, net, layers[conv_ids[1]], parsed_dir, mode, input_scale=cur_scale)
            cur_scale = float(_resnet_layer_npz(parsed_dir, layers[conv_ids[1]]["name"])["act_scale"])
            conv_count += 1
        else:
            break

        if ds_idx is not None and ds_idx < n_conv:
            identity = _resnet_conv(identity, net, layers[ds_idx], parsed_dir, mode, input_scale=identity_scale)
            conv_count += 1
        elif ds_idx is not None:
            break

        cur = np.maximum(cur.astype(np.float32) + identity.astype(np.float32), 0.0).astype(np.float32)
        if quantize_residuals:
            scale = add_scales.get(add_name)
            if scale is None:
                raise ValueError(f"missing ResNet add output scale for {add_name}")
            cur_q = _quantize_fp32(cur, scale, mode)
            cur = cur_q.astype(np.float32) * float(scale)
            cur_scale = float(scale)
        if conv_count >= n_conv:
            break

    if output_dtype in {"int8", "int16"} and n_conv == len(layers):
        scale = add_scales.get("layer4.1.Add")
        if scale is None:
            raise ValueError("missing ResNet final Add scale for integer output compare")
        return _quantize_fp32(cur, scale, "int16" if output_dtype == "int16" else "int8").astype(np.float32)
    return cur.astype(np.float32)


def _read_blob(path: Path, shape: tuple[int, int, int], dtype: str = "float32") -> np.ndarray:
    dtype_map = {
        "float32": np.float32,
        "int16": np.int16,
        "int8": np.int8,
        "uint8": np.uint8,
    }
    if dtype not in dtype_map:
        raise ValueError(f"unsupported output dtype {dtype!r}")
    arr = np.fromfile(path, dtype=dtype_map[dtype])
    expected = int(np.prod(shape))
    if arr.size != expected:
        raise ValueError(f"{path}: got {arr.size} {dtype} values, expected {expected} for shape {shape}")
    return arr.reshape(shape).astype(np.float32, copy=False)


def _stats(got: np.ndarray, ref: np.ndarray) -> dict[str, float]:
    diff = got.astype(np.float32) - ref.astype(np.float32)
    ad = np.abs(diff)
    return {
        "max_abs": float(ad.max()) if ad.size else 0.0,
        "mean_abs": float(ad.mean()) if ad.size else 0.0,
        "rmse": float(np.sqrt(np.mean(diff * diff))) if diff.size else 0.0,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="Compare one-shot FPGA output against numpy golden")
    ap.add_argument("--build-dir", required=True)
    ap.add_argument("--image", required=True)
    ap.add_argument("--network", choices=["auto", "yolov5n", "resnet18"], default="auto")
    ap.add_argument("--parsed-dir", default=None,
                    help="optional parsed model dir for ResNet golden")
    ap.add_argument("--yolo-parsed-dir", default=None,
                    help="optional parsed model dir for YOLO golden")
    ap.add_argument("--output", default=None, help="primary output blob")
    ap.add_argument("--output-dir", default=None, help="directory containing named output blobs")
    ap.add_argument("--atol", type=float, default=1e-3)
    args = ap.parse_args()

    build_dir = Path(args.build_dir)
    plan = json.loads((build_dir / "plan.json").read_text())
    mode = plan.get("mode", plan.get("compile_meta", {}).get("mode", "int8"))
    max_layers = int(plan.get("compile_meta", {}).get("num_conv_layers_compiled", 0)) or None
    total_layers = int(plan.get("compile_meta", {}).get("num_conv_layers_total", 0)) or max_layers
    if max_layers == total_layers:
        max_layers = None

    network_name = str(plan.get("network", "")).lower()
    if args.network != "auto":
        network_name = args.network

    host = plan["host_io"]
    outputs = host.get("outputs")
    if "resnet" in network_name:
        has_qdq = any(
            rec.get("kind") == "qdq"
            for rec in plan.get("wb_layout", {}).get("layers", [])
        )
        primary_ref = run_resnet_compiler_golden(
            Path(args.image), mode, max_layers, args.parsed_dir,
            quantize_residuals=has_qdq,
            output_dtype=str(host.get("output_dtype", "float32")),
        )
        named_refs: dict[str, np.ndarray] = {}
    else:
        primary_ref, named_refs = run_yolo_compiler_golden(
            Path(args.image), mode, max_layers, args.yolo_parsed_dir,
        )

    failed = False
    compared = False
    if args.output:
        h, w = [int(x) for x in host["output_hw"]]
        c = int(host["output_c"])
        dtype = str(host.get("output_dtype", "float32"))
        got = _read_blob(Path(args.output), (h, w, c), dtype)
        ref = named_refs.get(outputs[-1]["name"], primary_ref) if outputs else primary_ref
        s = _stats(got, ref)
        print(f"primary max_abs={s['max_abs']:.6g} mean_abs={s['mean_abs']:.6g} rmse={s['rmse']:.6g}")
        failed |= s["max_abs"] > args.atol
        compared = True

    if args.output_dir and outputs:
        out_dir = Path(args.output_dir)
        for spec in outputs:
            name = spec["name"]
            h, w = [int(x) for x in spec["hw"]]
            c = int(spec["c"])
            dtype = str(spec.get("dtype", host.get("output_dtype", "float32")))
            got = _read_blob(out_dir / f"{name}.bin", (h, w, c), dtype)
            ref = named_refs[name]
            s = _stats(got, ref)
            print(f"{name} max_abs={s['max_abs']:.6g} mean_abs={s['mean_abs']:.6g} rmse={s['rmse']:.6g}")
            failed |= s["max_abs"] > args.atol
            compared = True

    if not compared:
        print(f"golden shape={primary_ref.shape} dtype={primary_ref.dtype}")

    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
