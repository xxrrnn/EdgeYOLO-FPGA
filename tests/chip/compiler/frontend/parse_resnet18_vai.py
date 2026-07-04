#!/usr/bin/env python3
"""
Parse Vitis AI quantized ResNet18 ONNX -> model/resnet18/parsed_vai/

Vitis AI (pytorch_nndct) ONNX structure per Conv:
  FP32_init → QuantizeLinear(scale, zp) → DequantizeLinear(scale, zp) → Conv

The weights are stored as FP32 in initializers; QL/DQL nodes simulate INT8.
We extract INT8 weights by: round(clip(fp32 / scale)).

Output files match the schema used by the FPGA compiler / resnet_e2e.py.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import onnx

REPO_ROOT = Path(__file__).resolve().parents[4]
VAI_DIR = REPO_ROOT / "model" / "algorithm" / "Resnet18-quantization" / "resnet18" / "quantize_result"
OUTPUT_DIR = REPO_ROOT / "model" / "resnet18" / "parsed_vai"
ONNX_PATH = VAI_DIR / "ResNet_int.onnx"

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
(OUTPUT_DIR / "weights").mkdir(parents=True, exist_ok=True)

print(f"Loading {ONNX_PATH} ...")
model = onnx.load(str(ONNX_PATH))

# ------------------------------------------------------------------
# Build lookup tables
# ------------------------------------------------------------------
output_to_node: dict[str, onnx.NodeProto] = {}
for n in model.graph.node:
    for out in n.output:
        output_to_node[out] = n

initializers: dict[str, np.ndarray] = {}
for init in model.graph.initializer:
    dtype_map = {1: np.float32, 2: np.uint8, 3: np.int8, 5: np.int16,
                 6: np.int32, 7: np.int64}
    dtype = dtype_map.get(init.data_type, np.float32)
    if init.raw_data:
        arr = np.frombuffer(init.raw_data, dtype=dtype).copy()
    elif init.float_data:
        arr = np.array(init.float_data, dtype=np.float32)
    elif init.int32_data:
        arr = np.array(init.int32_data, dtype=np.int32)
    else:
        arr = np.array([], dtype=dtype)
    if list(init.dims):
        arr = arr.reshape(list(init.dims))
    initializers[init.name] = arr


def resolve_const(name: str, depth: int = 0) -> np.ndarray | None:
    """Resolve a tensor name to its constant value."""
    if depth > 10:
        return None
    if name in initializers:
        return initializers[name]
    node = output_to_node.get(name)
    if node is None:
        return None
    if node.op_type == "Constant":
        from onnx import numpy_helper
        return numpy_helper.to_array(node.attribute[0].t)
    if node.op_type in ("Cast", "Identity"):
        return resolve_const(node.input[0], depth + 1)
    return None


def get_ql_info(ql_node: onnx.NodeProto) -> tuple[float, int]:
    """Get (scale, zero_point) from a QuantizeLinear node."""
    scale_arr = resolve_const(ql_node.input[1])
    scale = float(np.array(scale_arr).flatten()[0]) if scale_arr is not None else 1.0
    if len(ql_node.input) > 2:
        zp_arr = resolve_const(ql_node.input[2])
        zp = int(np.array(zp_arr).flatten()[0]) if zp_arr is not None else 0
    else:
        zp = 0
    return scale, zp


# ------------------------------------------------------------------
# Traverse the weight branch: FP32_init → QL → DQL → Conv
# DQL input[0] is QL output, QL input[0] is the FP32 init
# ------------------------------------------------------------------
def extract_weight_int8(dql_node: onnx.NodeProto) -> tuple[np.ndarray, float] | tuple[None, None]:
    """Return (int8_weight, weight_scale) from a DequantizeLinear node."""
    ql = output_to_node.get(dql_node.input[0])
    if ql is None or ql.op_type != "QuantizeLinear":
        return None, None
    fp32_arr = resolve_const(ql.input[0])
    if fp32_arr is None:
        return None, None
    w_scale, w_zp = get_ql_info(ql)
    # Quantize: INT8 = round(fp32 / scale) - zero_point, clipped to [-128, 127]
    int8_arr = np.clip(np.round(fp32_arr.astype(np.float64) / w_scale) - w_zp,
                       -128, 127).astype(np.int8)
    return int8_arr, w_scale


def extract_bias_fp32(dql_node: onnx.NodeProto) -> np.ndarray | None:
    """Return FP32 bias from DequantizeLinear. Bias is stored as FP32 init."""
    ql = output_to_node.get(dql_node.input[0])
    if ql is None or ql.op_type != "QuantizeLinear":
        fp32_arr = resolve_const(dql_node.input[0])
        return fp32_arr.astype(np.float32) if fp32_arr is not None else None
    # Bias is FP32 init, just pass through (already small)
    fp32_arr = resolve_const(ql.input[0])
    if fp32_arr is not None:
        return fp32_arr.astype(np.float32)
    return None


def get_conv_input_scale(conv_node: onnx.NodeProto) -> float:
    """Get input activation scale: Conv.input[0] ← DQL ← QL(scale=?)"""
    dql = output_to_node.get(conv_node.input[0])
    if dql and dql.op_type == "DequantizeLinear":
        sc = resolve_const(dql.input[1])
        if sc is not None:
            return float(np.array(sc).flatten()[0])
    return 1.0


def get_output_act_scale_has_relu(conv_node: onnx.NodeProto) -> tuple[float, bool]:
    """Find QL scale after Conv output (through Relu or directly)."""
    out = conv_node.output[0]
    for n in model.graph.node:
        if out in n.input:
            if n.op_type == "QuantizeLinear":
                sc = resolve_const(n.input[1])
                return (float(np.array(sc).flatten()[0]) if sc is not None else 1.0), False
            if n.op_type == "Relu":
                relu_out = n.output[0]
                for n2 in model.graph.node:
                    if relu_out in n2.input and n2.op_type == "QuantizeLinear":
                        sc = resolve_const(n2.input[1])
                        return (float(np.array(sc).flatten()[0]) if sc is not None else 1.0), True
    return 1.0, False


# ------------------------------------------------------------------
# Add and MaxPool output scales
# ------------------------------------------------------------------
add_output_scales: dict[str, float] = {}
for n in model.graph.node:
    if n.op_type == "Add":
        # try through Relu first
        sc = 1.0
        add_out = n.output[0]
        for n2 in model.graph.node:
            if add_out in n2.input:
                if n2.op_type == "QuantizeLinear":
                    v = resolve_const(n2.input[1])
                    if v is not None:
                        sc = float(np.array(v).flatten()[0])
                    break
                if n2.op_type == "Relu":
                    relu_out = n2.output[0]
                    for n3 in model.graph.node:
                        if relu_out in n3.input and n3.op_type == "QuantizeLinear":
                            v = resolve_const(n3.input[1])
                            if v is not None:
                                sc = float(np.array(v).flatten()[0])
                            break
                    break
        add_output_scales[n.name] = sc

maxpool_output_scale = 1.0
for n in model.graph.node:
    if n.op_type == "MaxPool":
        sc, _ = get_output_act_scale_has_relu(n)
        maxpool_output_scale = sc
        break

print(f"MaxPool output scale: {maxpool_output_scale}")
print(f"Add nodes found: {len(add_output_scales)}")
for k, v in add_output_scales.items():
    print(f"  {k}: scale={v}")

# ------------------------------------------------------------------
# Assign human-readable names to Conv nodes
# ResNet18 has 20 Conv layers (excluding final FC)
# VAI names them as Conv_18, Conv_45, ...
# We'll number them in order and map to ResNet structure
# ------------------------------------------------------------------
RESNET18_LAYER_NAMES = [
    "conv1.Conv",
    "layer1.0.conv1.Conv",
    "layer1.0.conv2.Conv",
    "layer1.1.conv1.Conv",
    "layer1.1.conv2.Conv",
    "layer2.0.conv1.Conv",
    "layer2.0.conv2.Conv",
    "layer2.0.downsample.0.Conv",
    "layer2.1.conv1.Conv",
    "layer2.1.conv2.Conv",
    "layer3.0.conv1.Conv",
    "layer3.0.conv2.Conv",
    "layer3.0.downsample.0.Conv",
    "layer3.1.conv1.Conv",
    "layer3.1.conv2.Conv",
    "layer4.0.conv1.Conv",
    "layer4.0.conv2.Conv",
    "layer4.0.downsample.0.Conv",
    "layer4.1.conv1.Conv",
    "layer4.1.conv2.Conv",
]

# Map from ONNX internal Add node name -> ResNet block Add name (in order)
RESNET_ADD_NAME_MAP = [
    "layer1.0.Add", "layer1.1.Add",
    "layer2.0.Add", "layer2.1.Add",
    "layer3.0.Add", "layer3.1.Add",
    "layer4.0.Add", "layer4.1.Add",
]

def safe_name(s: str) -> str:
    return s.replace(".", "_").replace("/", "_")


conv_nodes = [n for n in model.graph.node if n.op_type == "Conv"]
print(f"\nFound {len(conv_nodes)} Conv nodes, expected {len(RESNET18_LAYER_NAMES)}")

layers = []
for idx, (conv, layer_name) in enumerate(zip(conv_nodes, RESNET18_LAYER_NAMES)):
    # input[1] is weight DQL node
    dql_w = output_to_node.get(conv.input[1])
    dql_b = output_to_node.get(conv.input[2]) if len(conv.input) > 2 else None

    if dql_w is None or dql_w.op_type != "DequantizeLinear":
        print(f"  [SKIP] {layer_name}: weight input is not DQL (got {dql_w.op_type if dql_w else 'None'})")
        continue

    weight_int8, w_scale = extract_weight_int8(dql_w)
    if weight_int8 is None:
        print(f"  [SKIP] {layer_name}: cannot extract INT8 weight")
        continue

    x_scale = get_conv_input_scale(conv)

    bias_fp32 = None
    if dql_b and dql_b.op_type == "DequantizeLinear":
        bias_fp32 = extract_bias_fp32(dql_b)
    if bias_fp32 is None:
        bias_fp32 = np.zeros(weight_int8.shape[0], dtype=np.float32)

    out_act_scale, has_relu = get_output_act_scale_has_relu(conv)

    out_ch = weight_int8.shape[0]
    dqa_scale = np.full(out_ch, w_scale * x_scale, dtype=np.float32)
    dqa_bias = bias_fp32.flatten()[:out_ch].astype(np.float32)

    # Conv attributes
    attrs = {}
    for a in conv.attribute:
        if a.ints:
            attrs[a.name] = list(a.ints)
        elif a.i:
            attrs[a.name] = a.i
    kernel = attrs.get("kernel_shape", [1, 1])
    stride = attrs.get("strides", [1, 1])
    pad = attrs.get("pads", [0, 0, 0, 0])
    group = attrs.get("group", 1)

    npz_path = OUTPUT_DIR / "weights" / f"{safe_name(layer_name)}.npz"
    np.savez_compressed(npz_path,
                        weight_int8=weight_int8.transpose(0, 2, 3, 1).astype(np.int8),  # OIHW → OHWI
                        weight_scale=np.full(out_ch, w_scale, dtype=np.float32),
                        dqa_scale=dqa_scale,
                        dqa_bias=dqa_bias,
                        act_scale=np.float32(out_act_scale))

    print(f"  [{layer_name:40s}] {str(weight_int8.shape):20s} "
          f"k={kernel[0]} s={stride[0]} relu={'Y' if has_relu else 'N'} "
          f"x={x_scale:.5f} w={w_scale:.5f} y={out_act_scale:.5f}")

    layers.append({
        "name": layer_name,
        "type": "conv",
        "out_channels": out_ch,
        "in_channels": int(weight_int8.shape[1]),
        "kernel_h": int(kernel[0]),
        "kernel_w": int(kernel[1]),
        "stride": [int(s) for s in stride],
        "padding": [int(p) for p in pad],
        "group": int(group),
        "has_bn": False,
        "has_activation": bool(has_relu),
        "weight_shape": [out_ch, int(kernel[0]), int(kernel[1]), int(weight_int8.shape[1])],  # OHWI
        "act_scale": float(out_act_scale),
        "act_zero_point": 0.0,
        "input_act_scale": float(x_scale),
    })

# ------------------------------------------------------------------
# Save Add output scales with ResNet-block friendly names
# ------------------------------------------------------------------
add_nodes_ordered = [n for n in model.graph.node if n.op_type == "Add"]
named_add_scales: dict[str, float] = {}
for i, (n, rname) in enumerate(zip(add_nodes_ordered, RESNET_ADD_NAME_MAP)):
    named_add_scales[rname] = add_output_scales.get(n.name, 1.0)

add_sc_path = OUTPUT_DIR / "add_output_scales.json"
with open(add_sc_path, "w") as f:
    json.dump(named_add_scales, f, indent=2)

# ------------------------------------------------------------------
# Extract FC (Gemm/MatMul) weights
# ------------------------------------------------------------------
for node in model.graph.node:
    if node.op_type in ("Gemm", "MatMul"):
        dql_w = output_to_node.get(node.input[1])
        dql_b = output_to_node.get(node.input[2]) if len(node.input) > 2 else None

        w_fp32 = None
        b_fp32 = None

        if dql_w and dql_w.op_type == "DequantizeLinear":
            ql = output_to_node.get(dql_w.input[0])
            if ql and ql.op_type == "QuantizeLinear":
                fp32_arr = resolve_const(ql.input[0])
                w_s, w_zp = get_ql_info(ql)
                if fp32_arr is not None:
                    w_fp32 = fp32_arr.astype(np.float32)

        if dql_b and dql_b.op_type == "DequantizeLinear":
            ql_b = output_to_node.get(dql_b.input[0])
            if ql_b and ql_b.op_type == "QuantizeLinear":
                fp32_b = resolve_const(ql_b.input[0])
                if fp32_b is not None:
                    b_fp32 = fp32_b.astype(np.float32)

        if w_fp32 is not None:
            trans_b = 0
            for a in node.attribute:
                if a.name == "transB":
                    trans_b = int(a.i)
            if trans_b:
                w_fp32 = w_fp32.T
            fc_path = OUTPUT_DIR / "weights" / "fc.npz"
            np.savez_compressed(fc_path,
                                weight=w_fp32,
                                bias=(b_fp32 if b_fp32 is not None
                                      else np.zeros(w_fp32.shape[0], dtype=np.float32)))
            print(f"\nSaved FC: weight={w_fp32.shape} bias={b_fp32.shape if b_fp32 is not None else '(zeros)'}")
        break

# ------------------------------------------------------------------
# network.json
# ------------------------------------------------------------------
network = {
    "model_info": {
        "name": "resnet18-vai",
        "source": "Vitis AI pytorch_nndct PTQ INT8, ResNet_int.onnx",
        "input_shape": [1, 3, 224, 224],
        "output_shape": [1, 1000],
        "num_conv_layers": len(layers),
        "data_layout": "NHWC",
        "quantization": {
            "weight_bits": 8,
            "activation_bits": 8,
            "accumulator_bits": 32,
            "scheme": "power_of_2",
        },
    },
    "preprocess": {
        "mean": [0.485, 0.456, 0.406],
        "std": [0.229, 0.224, 0.225],
        "resize": 256,
        "crop": 224,
    },
    "maxpool_output_scale": float(maxpool_output_scale),
    "add_output_scales_file": "add_output_scales.json",
    "layers": layers,
}

net_path = OUTPUT_DIR / "network.json"
with open(net_path, "w") as f:
    json.dump(network, f, indent=2)

pre_path = OUTPUT_DIR / "input_mean_std.json"
with open(pre_path, "w") as f:
    json.dump(network["preprocess"], f, indent=2)

print(f"\n{'='*60}")
print(f"Done: {len(layers)}/{len(conv_nodes)} conv layers saved -> {OUTPUT_DIR}")
