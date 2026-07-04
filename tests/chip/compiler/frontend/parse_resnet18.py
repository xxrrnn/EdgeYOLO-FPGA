#!/usr/bin/env python3
"""
ResNet-18 ONNX 前端（FP32 + BN 融合）

输入: model/resnet18/resnet18-v1-7.onnx（ONNX Model Zoo 原版 FP32）

输出: model/resnet18/parsed/
        - network.json     拓扑 + 每层属性
        - weights/<safe_name>.npz   每层 FP32 weight / fused_bias
        - input_mean_std.json       预处理参数

无量化路径；用于 sim_runner FP32 oracle 验证编译器对 ResNet-18 的 lowering。
量化路径见 parse_onnx_resnet_qdq.py（torchvision QDQ ONNX）。

用法:
    python tools/compiler/frontend/parse_resnet18.py
    python tools/compiler/frontend/parse_resnet18.py --onnx <path> --output <dir>
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import OrderedDict
from pathlib import Path

import numpy as np
import onnx
from onnx import TensorProto

DTYPE_MAP = {
    TensorProto.FLOAT: np.float32,
    TensorProto.INT8: np.int8,
    TensorProto.INT32: np.int32,
    TensorProto.INT64: np.int64,
    TensorProto.UINT8: np.uint8,
}


def tensor_to_numpy(tp):
    dtype = DTYPE_MAP.get(tp.data_type)
    if dtype is None:
        raise ValueError(f"unsupported dtype {tp.data_type} for tensor {tp.name!r}")
    if tp.raw_data:
        arr = np.frombuffer(tp.raw_data, dtype=dtype)
    elif tp.float_data:
        arr = np.array(tp.float_data, dtype=np.float32)
    elif tp.int32_data:
        arr = np.array(tp.int32_data, dtype=np.int32)
    elif tp.int64_data:
        arr = np.array(tp.int64_data, dtype=np.int64)
    else:
        arr = np.array([], dtype=dtype)
    if list(tp.dims):
        arr = arr.reshape(list(tp.dims))
    return arr.copy()


def build_initializer_map(model):
    return {init.name: tensor_to_numpy(init) for init in model.graph.initializer}


def _attr(node, name, default=None):
    for a in node.attribute:
        if a.name == name:
            if a.ints:
                return list(a.ints)
            if a.floats:
                return list(a.floats)
            if a.s:
                return a.s.decode()
            return a.i if a.i is not None else default
    return default


def parse_resnet18(onnx_path):
    model = onnx.load(onnx_path)
    inits = build_initializer_map(model)

    # Pre-scan for Conv-BN pairs to fuse.
    bn_by_in = {}
    for node in model.graph.node:
        if node.op_type == "BatchNormalization":
            bn_by_in[node.input[0]] = node

    fused_weights = OrderedDict()  # name → dict
    topology = []
    layer_schedule = []

    for node in model.graph.node:
        op = node.op_type
        if op == "Conv":
            name = node.name.strip("/").replace("/", ".")
            w_name = node.input[1]
            b_name = node.input[2] if len(node.input) > 2 else None

            w = inits[w_name]  # [Cout, Cin, kH, kW]
            b = inits[b_name].copy() if b_name and b_name in inits else np.zeros(w.shape[0], dtype=np.float32)

            kernel = _attr(node, "kernel_shape", [w.shape[2], w.shape[3]])
            stride = _attr(node, "strides", [1, 1])
            pads = _attr(node, "pads", [0, 0, 0, 0])
            group = _attr(node, "group", 1) or 1

            # Try to fuse the immediately-following BN.
            fused_bn_name = None
            if len(node.output) == 1 and node.output[0] in bn_by_in:
                bn = bn_by_in[node.output[0]]
                fused_bn_name = bn.name
                gamma = inits[bn.input[1]]
                beta = inits[bn.input[2]]
                mean = inits[bn.input[3]]
                var = inits[bn.input[4]]
                eps = 1e-5
                for a in bn.attribute:
                    if a.name == "epsilon":
                        eps = a.f or eps
                std = np.sqrt(var + eps)
                scale = gamma / std
                # Folded conv weight: w[c,*] *= scale[c]
                w = w * scale[:, None, None, None]
                b = beta + (b - mean) * scale

            entry = {
                "name": name,
                "type": "conv",
                "out_channels": int(w.shape[0]),
                "in_channels": int(w.shape[1]),
                "kernel_h": int(kernel[0]),
                "kernel_w": int(kernel[1]),
                "stride": list(stride),
                "padding": list(pads),
                "group": int(group),
                "has_bn": fused_bn_name is not None,
                "fused_bn": fused_bn_name,
                "weight_shape": list(w.shape),
                "input_tensor": node.input[0],
                "output_tensor": (bn_by_in[node.output[0]].output[0] if fused_bn_name else node.output[0]),
            }
            layer_schedule.append(entry)
            fused_weights[name] = {
                "weight_fp32": w.astype(np.float32),
                "bias_fp32": b.astype(np.float32),
                "fused_bn": fused_bn_name or "",
            }

        # Track topology regardless (lowering will pick up Conv/Add/etc.)
        if op in {"Conv", "BatchNormalization", "Relu", "MaxPool", "Add",
                  "GlobalAveragePool", "AveragePool", "Flatten", "Gemm",
                  "Reshape"}:
            entry = {
                "name": node.name.strip("/").replace("/", "."),
                "op": op,
                "inputs": list(node.input),
                "outputs": list(node.output),
            }
            if op == "MaxPool":
                entry["kernel_shape"] = _attr(node, "kernel_shape", [1, 1])
                entry["strides"] = _attr(node, "strides", [1, 1])
                entry["pads"] = _attr(node, "pads", [0, 0, 0, 0])
            elif op == "AveragePool":
                entry["kernel_shape"] = _attr(node, "kernel_shape", [1, 1])
                entry["strides"] = _attr(node, "strides", [1, 1])
                entry["pads"] = _attr(node, "pads", [0, 0, 0, 0])
            topology.append(entry)

    # I/O shape
    inp = model.graph.input[0]
    out = model.graph.output[0]

    def _shape(vi, default):
        d = [d.dim_value for d in vi.type.tensor_type.shape.dim]
        # ONNX Model Zoo ResNet-18 leaves the batch dim 0; pin it to 1.
        if d and d[0] == 0:
            d[0] = 1
        return d or default

    input_shape = _shape(inp, [1, 3, 224, 224])
    output_shape = _shape(out, [1, 1000])

    network = {
        "model_info": {
            "name": "resnet18",
            "source": "onnx-model-zoo resnet18-v1-7 (FP32, BN-fused)",
            "input_shape": input_shape,
            "output_shape": output_shape,
            "num_conv_layers": len(layer_schedule),
            "data_layout": "NHWC",
            "quantization": None,
        },
        "preprocess": {
            "mean": [0.485, 0.456, 0.406],
            "std":  [0.229, 0.224, 0.225],
            "resize": 256,
            "crop": 224,
        },
        "layers": layer_schedule,
        "topology": topology,
    }

    return network, fused_weights


def save(output_dir, network, fused_weights):
    output_dir = Path(output_dir)
    weights_dir = output_dir / "weights"
    weights_dir.mkdir(parents=True, exist_ok=True)

    for name, w in fused_weights.items():
        safe = name.replace(".", "_").replace("/", "_")
        np.savez_compressed(weights_dir / f"{safe}.npz",
                            weight_fp32=w["weight_fp32"],
                            bias_fp32=w["bias_fp32"],
                            fused_bn=np.array(w["fused_bn"]))

    with open(output_dir / "network.json", "w") as f:
        json.dump(network, f, indent=2, default=_json_default)

    with open(output_dir / "input_mean_std.json", "w") as f:
        json.dump(network["preprocess"], f, indent=2)


def _json_default(obj):
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    raise TypeError(f"unserializable {type(obj)}")


def main():
    p = argparse.ArgumentParser(description="ResNet-18 ONNX 前端 (FP32 + BN 融合)")
    p.add_argument("--onnx", default=None,
                   help="FP32 ONNX 路径 (default: model/resnet18/resnet18-v1-7.onnx)")
    p.add_argument("--output", default=None,
                   help="输出目录 (default: model/resnet18/parsed)")
    args = p.parse_args()

    repo = Path(__file__).resolve().parents[3]
    onnx_path = args.onnx or str(repo / "model" / "resnet18" / "resnet18-v1-7.onnx")
    output_dir = args.output or str(repo / "model" / "resnet18" / "parsed")

    if not os.path.exists(onnx_path):
        print(f"ERROR: ONNX 不存在: {onnx_path}")
        sys.exit(1)

    print(f"[1/2] 解析 {onnx_path}")
    network, fused_weights = parse_resnet18(onnx_path)
    print(f"      conv 层数: {len(network['layers'])}")
    print(f"      topology 节点数: {len(network['topology'])}")

    print(f"[2/2] 保存到 {output_dir}")
    save(output_dir, network, fused_weights)

    print("OK")


if __name__ == "__main__":
    main()
