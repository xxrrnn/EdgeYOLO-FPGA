#!/usr/bin/env python3
"""
Parse a signed, symmetric QDQ-quantized ResNet18 ONNX and produce the schema
consumed by lower.py + compile.py.  Both W8A8 and native W16A16 models are
accepted; INT16 tensors are preserved and are never narrowed to INT8.

Output:
    project/model/resnet18/parsed_qdq/
      network.json           topology + per-layer attrs
      weights/<safe>.npz     quantized weight + dqa_scale + dqa_bias + act_scale
      input_mean_std.json    preprocess

Approach
--------
For each Conv node in the QDQ ONNX we walk one DequantizeLinear backwards
from each of its 3 inputs (act, weight, bias) and recover the raw INT8/INT32
tensors and FP32 scales/zero-points.  We then BN-fuse on the fly (PTQ models
typically have BN already folded in by torchvision before export, so this is
mostly a passthrough).

  - x_scale, x_zero_point     ← QuantizeLinear of the activation feeding Conv
  - w_int8, w_scale, w_zp     ← Constant tensors behind DequantizeLinear 2
  - b_int32, b_scale, b_zp    ← Constant tensors behind DequantizeLinear 3
  - y_scale, y_zero_point     ← next QuantizeLinear after Conv (or Conv+Relu)

The mapping into the hardware compiler is:
  - weight_int8 (legacy key; dtype is int8 or int16)       → weights_packer
  - dqa_scale[c] = w_scale[c] * x_scale                    → DQA per-channel
  - dqa_bias[c]  = b_int32[c] * b_scale[c]                 → DQA bias (FP32)
  - act_scale    = y_scale                                 → QA for next layer
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import OrderedDict
from pathlib import Path
from typing import Any, Dict, Optional

import numpy as np
import onnx
from onnx import TensorProto

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

DTYPE_MAP = {
    TensorProto.FLOAT: np.float32,
    TensorProto.DOUBLE: np.float64,
    TensorProto.INT8: np.int8,
    TensorProto.INT16: np.int16,
    TensorProto.INT32: np.int32,
    TensorProto.INT64: np.int64,
    TensorProto.UINT8: np.uint8,
    TensorProto.UINT16: np.uint16,
}


def tensor_to_numpy(tp):
    dtype = DTYPE_MAP.get(tp.data_type)
    if dtype is None:
        raise ValueError(f"unsupported dtype {tp.data_type}")
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


def _const_value(model, name):
    """Walk back constants / casts from `name` to find the original Constant
    tensor.  Handles `Cast` chains (PyTorch QDQ export likes to insert these).
    """
    for n in model.graph.node:
        if name in n.output:
            if n.op_type == "Constant":
                # value is in attribute
                for a in n.attribute:
                    if a.name == "value":
                        return tensor_to_numpy(a.t)
                return None
            if n.op_type == "Cast":
                # follow the source
                if not n.input:
                    return None
                return _const_value(model, n.input[0])
            # any other op upstream → bail (this is not a constant chain)
            return None
    # not produced by a node — look in initializers
    for init in model.graph.initializer:
        if init.name == name:
            return tensor_to_numpy(init)
    return None


def _producer(model, name):
    """Return the node that produces tensor `name`, or None."""
    for n in model.graph.node:
        if name in n.output:
            return n
    return None


def _consumers(model, name):
    return [n for n in model.graph.node if name in n.input]


def _find_output_quant(model, tensor_name, depth=0, saw_relu=False):
    """Find the first output QuantizeLinear after a Conv output.

    Torchvision QDQ export commonly emits:
      Conv -> Relu -> QuantizeLinear -> Cast -> DequantizeLinear -> ...
    Residual branch convs may emit Conv -> QuantizeLinear -> ... -> Add.
    """
    if depth > 8:
        return 1.0, 0, saw_relu
    for node in _consumers(model, tensor_name):
        if node.op_type == "QuantizeLinear":
            sc = _const_value(model, node.input[1])
            zp = _const_value(model, node.input[2]) if len(node.input) > 2 else None
            zp_i = int(np.array(zp).flatten()[0]) if zp is not None and np.array(zp).size else 0
            if sc is not None:
                return float(np.array(sc).flatten()[0]), zp_i, saw_relu
            return 1.0, zp_i, saw_relu
        if node.op_type in {"Relu", "Cast", "DequantizeLinear", "Identity"}:
            scale, zero_point, relu = _find_output_quant(
                model,
                node.output[0],
                depth + 1,
                saw_relu or node.op_type == "Relu",
            )
            if scale != 1.0 or relu:
                return scale, zero_point, relu
    return 1.0, 0, saw_relu


def _back_to_dq_inputs(model, dq_node):
    """For a DequantizeLinear node, recover (int_tensor, scale, zero_point)."""
    assert dq_node.op_type == "DequantizeLinear"
    ti, si, zi = dq_node.input[0], dq_node.input[1], dq_node.input[2] if len(dq_node.input) > 2 else None
    int_tensor = _const_value(model, ti)
    scale = _const_value(model, si)
    zp = _const_value(model, zi) if zi else np.zeros_like(scale)
    return int_tensor, scale.astype(np.float32) if scale is not None else None, (
        zp.astype(np.int32) if zp is not None else None
    )


def parse_resnet18_qdq(onnx_path, mode: str = "auto"):
    if mode not in {"auto", "int8", "int16"}:
        raise ValueError(f"unsupported quantization mode {mode!r}")
    model = onnx.load(onnx_path)

    layers = []
    fused_weights = OrderedDict()
    topology = []
    add_output_scales: Dict[str, float] = {}
    detected_modes = set()

    # Track which Relu nodes are fused into a Conv → Relu sequence.
    relu_after = {}
    for n in model.graph.node:
        if n.op_type == "Relu" and len(n.input) == 1:
            prev = _producer(model, n.input[0])
            if prev is not None:
                # Conv → (DQ) → Relu  - but in QDQ export the DQ sits between
                # Conv output and the next Relu / QuantizeLinear.  We need to
                # walk through a possible DQ-then-QDQ chain.
                cur = prev
                if cur.op_type == "DequantizeLinear":
                    cur = _producer(model, cur.input[0])
                if cur is not None and cur.op_type == "Conv":
                    relu_after[cur.name] = n.name

    for node in model.graph.node:
        if node.op_type == "Conv":
            name = node.name.strip("/").replace("/", ".")
            b_fp32_direct = None

            # ----- Decode the three DQ inputs (act, weight, bias) -----
            dq_act = _producer(model, node.input[0])
            dq_w = _producer(model, node.input[1])
            dq_b = _producer(model, node.input[2]) if len(node.input) > 2 else None

            if dq_act is None or dq_act.op_type != "DequantizeLinear":
                print(f"  WARN: {name}: act not behind DequantizeLinear ({dq_act and dq_act.op_type})")
                continue

            act_int, act_scale, act_zp = _back_to_dq_inputs(model, dq_act)
            w_int, w_scale, w_zp = _back_to_dq_inputs(model, dq_w)
            if dq_b is not None and dq_b.op_type == "DequantizeLinear":
                b_int, b_scale, b_zp = _back_to_dq_inputs(model, dq_b)
            else:
                # bias may be a plain FP32 constant (no QDQ).
                b_fp = _const_value(model, node.input[2]) if len(node.input) > 2 else None
                if b_fp is not None:
                    b_int = b_fp.astype(np.int32) if b_fp.dtype.kind == "i" else None
                    b_scale = None
                    b_zp = None
                    b_fp32_direct = b_fp.astype(np.float32) if b_fp.dtype.kind == "f" else None
                else:
                    b_int = np.zeros(w_int.shape[0], dtype=np.int32) if w_int is not None else None
                    b_scale = np.ones(w_int.shape[0], dtype=np.float32) if w_int is not None else None
                    b_zp = np.zeros(w_int.shape[0], dtype=np.int32) if w_int is not None else None
                    b_fp32_direct = None

            # b_fp32_direct overrides
            if b_fp32_direct is not None:
                dqa_bias_fp32 = b_fp32_direct.astype(np.float32)
            elif b_int is not None and b_scale is not None:
                dqa_bias_fp32 = (b_int.astype(np.float64) *
                                 np.array(b_scale).reshape(-1).astype(np.float64)).astype(np.float32)
            else:
                dqa_bias_fp32 = np.zeros(w_int.shape[0], dtype=np.float32)

            if w_int is None:
                print(f"  WARN: {name}: quantized weight not found; skipping.")
                continue

            if w_int.dtype == np.int16:
                layer_mode = "int16"
            elif w_int.dtype == np.int8:
                layer_mode = "int8"
            else:
                raise TypeError(f"{name}: expected signed INT8/INT16 weights, got {w_int.dtype}")
            detected_modes.add(layer_mode)
            if mode != "auto" and layer_mode != mode:
                raise TypeError(f"{name}: --mode {mode} requires {mode} weights, got {w_int.dtype}")
            if layer_mode == "int16":
                if act_zp is not None and np.any(np.asarray(act_zp) != 0):
                    raise ValueError(f"{name}: native INT16 activations require zero_point=0")
                if w_zp is not None and np.any(np.asarray(w_zp) != 0):
                    raise ValueError(f"{name}: native INT16 weights require zero_point=0")

            # ----- Find the output QuantizeLinear (next QDQ) to get y_scale -----
            y_scale, y_zero_point, has_activation = _find_output_quant(model, node.output[0])
            if layer_mode == "int16" and y_zero_point != 0:
                raise ValueError(f"{name}: native INT16 output requires zero_point=0")

            # Per-channel scale handling.
            w_scale_arr = np.array(w_scale).reshape(-1)
            if w_scale_arr.size == 1:
                w_scale_arr = np.full(w_int.shape[0], float(w_scale_arr[0]), dtype=np.float32)

            # DQA scale and bias (FP32 → DQA per-channel scale/bias)
            act_scale_f = float(np.array(act_scale).flatten()[0])
            dqa_scale = (w_scale_arr * act_scale_f).astype(np.float32)
            dqa_bias = dqa_bias_fp32

            # ONNX Conv stores OIHW.  The compiler's im2col order is HWIC, so
            # deployment NPZ files must be OHWI before their flat packing.
            weight_ohwi = np.transpose(w_int, (0, 2, 3, 1)).copy()

            kernel = [w_int.shape[2], w_int.shape[3]]
            stride = [1, 1]
            pads = [0, 0, 0, 0]
            group = 1
            for a in node.attribute:
                if a.name == "kernel_shape":
                    kernel = list(a.ints)
                elif a.name == "strides":
                    stride = list(a.ints)
                elif a.name == "pads":
                    pads = list(a.ints)
                elif a.name == "group":
                    group = a.i

            entry = {
                "name": name,
                "type": "conv",
                "out_channels": int(w_int.shape[0]),
                "in_channels": int(w_int.shape[1]),
                "kernel_h": int(kernel[0]),
                "kernel_w": int(kernel[1]),
                "stride": stride,
                "padding": pads,
                "group": int(group),
                "has_bn": False,             # already folded in by torchvision PTQ
                "has_activation": bool(has_activation),
                "weight_shape": list(weight_ohwi.shape),
                "act_scale": float(y_scale),
                "act_zero_point": float(y_zero_point),
            }
            layers.append(entry)
            fused_weights[name] = {
                # Keep the legacy key for compatibility; dtype is the W8/W16
                # storage contract used by the compiler.
                "weight_int8": weight_ohwi,
                "weight_scale": w_scale_arr,
                "weight_zero_point": np.array(w_zp).astype(np.int32).flatten(),
                "dqa_scale": dqa_scale,
                "dqa_bias": dqa_bias,
                "act_scale": np.float32(y_scale),
                "act_zero_point": np.float32(y_zero_point),
                "has_bn": True,
            }

        if node.op_type == "Add":
            add_name = node.name.strip("/").replace("/", ".")
            add_scale, add_zp, _ = _find_output_quant(model, node.output[0])
            if add_scale != 1.0:
                if (mode == "int16" or "int16" in detected_modes) and add_zp != 0:
                    raise ValueError(f"{add_name}: native INT16 Add output requires zero_point=0")
                add_output_scales[add_name] = float(add_scale)

        # Track topology
        if node.op_type in {"Conv", "Add", "MaxPool", "AveragePool", "GlobalAveragePool",
                            "Flatten", "Gemm", "Relu", "Reshape"}:
            te = {
                "name": node.name.strip("/").replace("/", "."),
                "op": node.op_type,
                "inputs": list(node.input),
                "outputs": list(node.output),
            }
            for a in node.attribute:
                if a.name in {"kernel_shape", "strides", "pads"}:
                    te[a.name] = list(a.ints)
            topology.append(te)

    if not detected_modes:
        raise ValueError("no quantized Conv weights were found in the QDQ model")
    if len(detected_modes) != 1:
        raise ValueError(f"mixed Conv weight precisions are unsupported: {sorted(detected_modes)}")
    resolved_mode = next(iter(detected_modes))
    return layers, fused_weights, topology, model, add_output_scales, resolved_mode


def save(output_dir, layers, fused_weights, topology, model, add_output_scales, mode):
    output_dir = Path(output_dir)
    weights_dir = output_dir / "weights"
    weights_dir.mkdir(parents=True, exist_ok=True)

    for name, w in fused_weights.items():
        safe = name.replace(".", "_").replace("/", "_")
        np.savez_compressed(weights_dir / f"{safe}.npz", **w)

    # Pull input/output shape from graph if present, else default to 1x3x224x224.
    def _shape(vi, default):
        d = [d.dim_value for d in vi.type.tensor_type.shape.dim]
        if d and d[0] == 0:
            d[0] = 1
        return d or default

    input_shape = _shape(model.graph.input[0], [1, 3, 224, 224])
    output_shape = _shape(model.graph.output[0], [1, 1000])

    network = {
        "model_info": {
            "name": "resnet18",
            "source": "torchvision FBGEMM IMAGENET1K_FBGEMM_V1, exported with torch.onnx.export QDQ",
            "input_shape": input_shape,
            "output_shape": output_shape,
            "num_conv_layers": len(layers),
            "data_layout": "NHWC",
            "quantization": {
                "weight_bits": 16 if mode == "int16" else 8,
                "activation_bits": 16 if mode == "int16" else 8,
                "accumulator_bits": 64 if mode == "int16" else 32,
                "scheme": "symmetric",
                "semantics": "native_w16a16" if mode == "int16" else "native_w8a8",
            },
        },
        "preprocess": {
            "mean": [0.485, 0.456, 0.406],
            "std":  [0.229, 0.224, 0.225],
            "resize": 256, "crop": 224,
        },
        "layers": layers,
        "topology": topology,
        "hardware_mode": mode,
        "quantization_semantics": "native_w16a16" if mode == "int16" else "native_w8a8",
    }
    if add_output_scales:
        network["add_output_scales_file"] = "add_output_scales.json"
    (output_dir / "network.json").write_text(json.dumps(network, indent=2, default=_json_default))
    (output_dir / "input_mean_std.json").write_text(json.dumps(network["preprocess"], indent=2))
    if add_output_scales:
        (output_dir / "add_output_scales.json").write_text(
            json.dumps(add_output_scales, indent=2, sort_keys=True)
        )


def _json_default(obj):
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    raise TypeError(f"unserializable {type(obj)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--onnx", default=None,
                    help="QDQ resnet18 ONNX (default: project/model/resnet18/resnet18_w8a8.onnx)")
    ap.add_argument("--mode", choices=["auto", "int8", "int16"], default="auto",
                    help="required QDQ weight precision; auto detects from ONNX tensors")
    ap.add_argument("--output", default=None,
                    help="output dir (default: project/model/resnet18/parsed_qdq)")
    args = ap.parse_args()

    repo = Path(__file__).resolve().parents[3]
    onnx_path = args.onnx or str(repo / "project" / "project" / "model" / "resnet18" / "resnet18_w8a8.onnx")

    if not os.path.exists(onnx_path):
        print(f"ERROR: ONNX 不存在: {onnx_path}", file=sys.stderr)
        print("       run tools/compiler/frontend/export_resnet18_torchvision.py first", file=sys.stderr)
        sys.exit(1)

    print(f"[1/2] 解析 {onnx_path}")
    layers, fused, topology, model, add_scales, resolved_mode = parse_resnet18_qdq(
        onnx_path, mode=args.mode
    )
    print(f"      Conv layers: {len(layers)}")
    print(f"      topology nodes: {len(topology)}")
    bits = 16 if resolved_mode == "int16" else 8
    print(f"      quantization: native W{bits}A{bits}")

    out_dir = args.output or str(
        repo / "project" / "project" / "model" / "resnet18" /
        ("parsed_int16" if resolved_mode == "int16" else "parsed_qdq")
    )
    print(f"[2/2] 保存到 {out_dir}")
    save(out_dir, layers, fused, topology, model, add_scales, resolved_mode)
    print("OK")


if __name__ == "__main__":
    main()
