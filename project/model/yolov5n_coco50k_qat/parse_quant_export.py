"""Parse the bundled COCO YOLOv5n quantized ONNX into FPGA format.

The checked-in COCO INT8 network description is used as the structural
template.  The PT and ONNX inputs are retained under ``int8/`` so this parser
works after a fresh clone without a separate model download.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import onnx
from onnx import numpy_helper


REPO = Path(__file__).resolve().parents[3]
NETWORK_TEMPLATE = REPO / "project" / "model" / "yolov5n_coco50k_qat" / "parsed_int8" / "network.json"
INPUT_ACT_SCALE_INT8 = 1.0 / 127.0
INPUT_ACT_SCALE_INT16 = 1.0 / 32767.0
HARD_QUANT_SCALE = 1.0 / 127.0
INT16_WIDENED_MODE = "int16_widened"


def _const_map(model: onnx.ModelProto) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for node in model.graph.node:
        if node.op_type != "Constant" or not node.output:
            continue
        value = next((a for a in node.attribute if a.name == "value"), None)
        if value is None:
            continue
        out[node.output[0]] = numpy_helper.to_array(value.t)
    return out


def _manifest(consts: dict[str, np.ndarray]) -> list[list[str]]:
    raw = consts["quant_manifest_ascii"].astype(np.uint8).flatten().tolist()
    text = bytes(raw).decode("utf-8")
    return [line.split("\t") for line in text.splitlines() if line.strip()]


def _safe(name: str) -> str:
    return name.replace(".", "_").replace("/", "_")


def _conv_layer_name(node_name: str) -> str:
    parts = [p for p in node_name.strip("/").split("/") if p]
    if parts and parts[-1] == "Conv":
        parts = parts[:-1]
    if parts and parts[-1] == "conv":
        parts = parts[:-1]
    fixed: list[str] = []
    for i, part in enumerate(parts):
        if part == "m" and i + 1 < len(parts) and parts[i + 1].startswith("m."):
            continue
        fixed.append(part)
    return ".".join(fixed + ["conv"]).replace(".conv.conv", ".conv").lower()


def _bn_params(fp_model: onnx.ModelProto) -> dict[str, tuple[np.ndarray, np.ndarray]]:
    initializers = {x.name: numpy_helper.to_array(x) for x in fp_model.graph.initializer}
    consumers: dict[str, list[onnx.NodeProto]] = {}
    for node in fp_model.graph.node:
        for inp in node.input:
            consumers.setdefault(inp, []).append(node)

    params: dict[str, tuple[np.ndarray, np.ndarray]] = {}
    for conv in fp_model.graph.node:
        if conv.op_type != "Conv":
            continue
        layer = _conv_layer_name(conv.name)
        outs = consumers.get(conv.output[0], [])
        if not outs or outs[0].op_type != "BatchNormalization":
            continue
        bn = outs[0]
        gamma = initializers[bn.input[1]].astype(np.float32)
        beta = initializers[bn.input[2]].astype(np.float32)
        mean = initializers[bn.input[3]].astype(np.float32)
        var = initializers[bn.input[4]].astype(np.float32)
        eps = 1e-5
        for attr in bn.attribute:
            if attr.name == "epsilon":
                eps = float(attr.f)
        scale = gamma / np.sqrt(var + eps)
        bias = beta - mean * scale
        params[layer] = (scale.astype(np.float32), bias.astype(np.float32))
    return params


def _tensor_specs(quant_model: onnx.ModelProto) -> dict[str, dict[str, str]]:
    specs: dict[str, dict[str, str]] = {}
    for cols in _manifest(_const_map(quant_model)):
        if len(cols) < 4:
            continue
        layer, kind = cols[0], cols[1]
        if kind == "weight" and len(cols) >= 5:
            specs.setdefault(layer, {})["weight"] = cols[2]
            specs[layer]["scale"] = cols[3]
            specs[layer]["zero_point"] = cols[4]
        elif kind.startswith("act") and len(cols) >= 4:
            specs.setdefault(layer, {})["act_scale"] = cols[2]
            specs[layer]["act_zero_point"] = cols[3]
    return specs


def _act_key_for_conv(layer: str) -> str:
    if not layer.endswith(".conv"):
        return layer
    return layer[:-5] + ".act"


def parse_export(quant_onnx: Path, fp_onnx: Path, out_dir: Path, *, mode: str) -> None:
    qmodel = onnx.load(str(quant_onnx))
    fpmodel = onnx.load(str(fp_onnx))
    consts = _const_map(qmodel)
    specs = _tensor_specs(qmodel)
    bn = _bn_params(fpmodel)

    template = json.loads(NETWORK_TEMPLATE.read_text())
    net = json.loads(json.dumps(template))
    widened_int16 = mode == INT16_WIDENED_MODE
    int16_storage = mode in {"int16", INT16_WIDENED_MODE}
    net["model"] = f"yolov5n-coco50k-qat-{mode.replace('_', '-')}"
    net["dataset"] = "coco"
    net["num_classes"] = 80
    net["class_names"] = "coco"
    # Widened INT16 deliberately keeps the INT8 quantization grid. Only the
    # transport/compute dtype changes, matching the known-good FPGA path.
    input_act_scale = INPUT_ACT_SCALE_INT16 if mode == "int16" else INPUT_ACT_SCALE_INT8
    net["input_act_scale"] = input_act_scale
    net["hard_quant_scale"] = HARD_QUANT_SCALE
    net["hardware_mode"] = "int16" if int16_storage else "int8"
    net["quantization_semantics"] = (
        "int8_values_widened_to_int16" if widened_int16 else mode
    )
    net["source_quant_onnx"] = str(quant_onnx)
    net["source_onnx"] = str(fp_onnx)

    out_w = out_dir / "weights"
    out_w.mkdir(parents=True, exist_ok=True)

    act_scales: dict[str, float] = {}
    missing: list[str] = []
    prev_scale = input_act_scale
    for layer in net["layers"]:
        name = layer["name"]
        spec = specs.get(name)
        if not spec:
            missing.append(name)
            continue
        w = consts[spec["weight"]]
        if widened_int16 and (np.min(w) < -128 or np.max(w) > 127):
            raise ValueError(
                f"{name}: int16_widened requires an INT8 quantized export; "
                f"weight range is [{int(np.min(w))}, {int(np.max(w))}]"
            )
        w_scale = consts[spec["scale"]].astype(np.float32).reshape(-1)
        w_zp = consts[spec["zero_point"]].astype(np.float32).reshape(-1)
        if w.ndim != 4:
            raise ValueError(f"{name}: expected OIHW weight, got {w.shape}")

        act_spec = specs.get(_act_key_for_conv(name), {})
        act_scale = float(consts[act_spec["act_scale"]].reshape(-1)[0]) if "act_scale" in act_spec else prev_scale
        act_zp = float(consts[act_spec["act_zero_point"]].reshape(-1)[0]) if "act_zero_point" in act_spec else 0.0

        bn_scale, bn_bias = bn.get(name, (np.ones(w.shape[0], dtype=np.float32), np.zeros(w.shape[0], dtype=np.float32)))
        dqa_scale = prev_scale * w_scale[:w.shape[0]] * bn_scale
        dqa_bias = bn_bias

        layer["act_scale"] = act_scale
        layer["act_zero_point"] = act_zp
        layer["in_act_scale"] = prev_scale
        layer["out_channels"] = int(w.shape[0])
        layer["in_channels"] = int(w.shape[1] * int(layer.get("group", 1)))
        layer["weight_shape"] = [int(w.shape[0]), int(w.shape[2]), int(w.shape[3]), int(w.shape[1])]

        # The compiler packer expects OHWI layout under the historical key.
        w_ohwi = w.transpose(0, 2, 3, 1)
        np.savez(
            out_w / f"{_safe(name)}.npz",
            weight_int8=w_ohwi.astype(np.int16 if int16_storage else np.int8),
            weight_scale=w_scale.astype(np.float32),
            weight_zero_point=w_zp.astype(np.float32),
            dqa_scale=dqa_scale.astype(np.float32),
            dqa_bias=dqa_bias.astype(np.float32),
            act_scale=np.array(act_scale, dtype=np.float32),
            act_zero_point=np.array(act_zp, dtype=np.float32),
        )
        act_scales[name] = act_scale
        prev_scale = act_scale

    # Host detect head weights: 3 convs, no BN/ReLU after them.
    for i in range(3):
        name = f"model.24.m.{i}.conv"
        spec = specs.get(name) or specs.get(f"model.24.m.{i}")
        if not spec:
            missing.append(name)
            continue
        w = consts[spec["weight"]]
        w_scale = consts[spec["scale"]].astype(np.float32).reshape(-1)
        weight_fp32 = w.astype(np.float32) * w_scale.reshape(-1, 1, 1, 1)
        np.savez(
            out_w / f"model_24_m_{i}.npz",
            weight_fp32=weight_fp32.astype(np.float16),
            bias=np.zeros((w.shape[0],), dtype=np.float32),
            act_scale=np.array(HARD_QUANT_SCALE, dtype=np.float32),
            weight_int8=w.astype(np.int16 if int16_storage else np.int8),
            dqa_scale=np.zeros((w.shape[0],), dtype=np.float32),
            dqa_bias=np.zeros((w.shape[0],), dtype=np.float32),
            num_classes=np.array(80, dtype=np.int32),
        )

    if missing:
        raise ValueError(f"missing tensors for {len(missing)} layers: {missing[:8]}")

    (out_dir / "network.json").write_text(json.dumps(net, indent=2) + "\n")
    (out_dir / "activation_scales.json").write_text(json.dumps(act_scales, indent=2) + "\n")
    print(f"wrote {out_dir}")
    print(f"layers={len(net['layers'])}, detect_classes=80")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--quant-onnx", required=True)
    ap.add_argument("--onnx", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument(
        "--mode",
        choices=["int8", "int16", INT16_WIDENED_MODE],
        required=True,
        help=(
            "int16 uses true INT16 quantized tensors; int16_widened reads the "
            "INT8 export and only widens values/storage for the stable FPGA path"
        ),
    )
    args = ap.parse_args()
    parse_export(Path(args.quant_onnx), Path(args.onnx), Path(args.out), mode=args.mode)


if __name__ == "__main__":
    main()
