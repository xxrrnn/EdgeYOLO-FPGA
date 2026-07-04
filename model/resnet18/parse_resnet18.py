"""
ResNet18 W8A8 ONNX 解析器

从 resnet18_w8a8.onnx (QDQ format with Cast chains) 提取:
- INT8 量化权重
- Per-channel weight scale
- Activation scale (per-tensor)
- DQA 参数 (scale, bias)

输出到 model/resnet18/parsed/weights/ 目录
"""
import os
import json
import numpy as np
import onnx
from onnx import numpy_helper
from collections import OrderedDict
from pathlib import Path

MODEL_DIR = Path('model/resnet18')
ONNX_PATH = MODEL_DIR / 'resnet18_w8a8.onnx'
OUTPUT_DIR = MODEL_DIR / 'parsed' / 'weights'
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

print(f"Loading {ONNX_PATH}...")
model = onnx.load(str(ONNX_PATH))

# Build: output_name → producing node
output_to_node = {}
for node in model.graph.node:
    for out in node.output:
        output_to_node[out] = node

# Build: initializer lookup
initializers = {}
for init in model.graph.initializer:
    initializers[init.name] = numpy_helper.to_array(init)


def resolve_value(tensor_name, depth=0):
    """Recursively resolve a tensor's value through Cast/Constant chains."""
    if depth > 10:
        return None
    # Check initializer
    if tensor_name in initializers:
        return initializers[tensor_name]
    # Check producing node
    node = output_to_node.get(tensor_name)
    if node is None:
        return None
    if node.op_type == 'Constant':
        return numpy_helper.to_array(node.attribute[0].t)
    if node.op_type == 'Cast':
        return resolve_value(node.input[0], depth + 1)
    return None


# Find all Conv nodes
conv_nodes = [n for n in model.graph.node if n.op_type == 'Conv']
print(f"Found {len(conv_nodes)} Conv layers\n")

# Also find Gemm (FC layer)
gemm_nodes = [n for n in model.graph.node if n.op_type == 'Gemm']

# Find QuantizeLinear nodes consuming a tensor
def find_ql_consumers(tensor_name):
    """Find QuantizeLinear nodes taking tensor_name as input."""
    results = []
    for node in model.graph.node:
        if node.op_type == 'QuantizeLinear' and tensor_name == node.input[0]:
            results.append(node)
    return results


def find_relu_then_ql(tensor_name):
    """Find Relu→QL chain after a tensor."""
    for node in model.graph.node:
        if node.op_type == 'Relu' and tensor_name == node.input[0]:
            relu_out = node.output[0]
            qls = find_ql_consumers(relu_out)
            if qls:
                return qls[0], True
    # Direct QL (no relu)
    qls = find_ql_consumers(tensor_name)
    return (qls[0], False) if qls else (None, False)


# Also find Add nodes (for residual connections)
def find_add_then_ql(tensor_name):
    """Find Add→Relu→QL after a tensor."""
    for node in model.graph.node:
        if node.op_type == 'Add' and tensor_name in node.input:
            add_out = node.output[0]
            # Relu after Add
            for node2 in model.graph.node:
                if node2.op_type == 'Relu' and add_out == node2.input[0]:
                    relu_out = node2.output[0]
                    qls = find_ql_consumers(relu_out)
                    if qls:
                        return qls[0], True
            qls = find_ql_consumers(add_out)
            if qls:
                return qls[0], False
    return None, False


layer_info = OrderedDict()
act_scales = OrderedDict()

for conv in conv_nodes:
    # Conv node name: "/conv1/Conv" → "conv1"
    raw_name = conv.name.strip('/')
    if raw_name.endswith('/Conv'):
        raw_name = raw_name[:-5]
    layer_name = raw_name.replace('/', '.')

    # Conv inputs: [input_dq, weight_dq, bias_dq(optional)]
    conv_input_name = conv.input[0]
    conv_weight_name = conv.input[1]
    conv_bias_name = conv.input[2] if len(conv.input) > 2 else None

    # Get attributes
    attrs = {}
    for attr in conv.attribute:
        if attr.ints:
            attrs[attr.name] = list(attr.ints)
        else:
            attrs[attr.name] = attr.i

    # Trace weight DQ: Conv weight input is DQ output
    weight_dq = output_to_node.get(conv_weight_name)
    if weight_dq is None or weight_dq.op_type != 'DequantizeLinear':
        print(f"  [{layer_name}] weight not from DQ, skip")
        continue

    # DQ inputs: [quantized_data, scale, zero_point]
    weight_int8 = resolve_value(weight_dq.input[0])
    w_scale = resolve_value(weight_dq.input[1])
    w_zp = resolve_value(weight_dq.input[2]) if len(weight_dq.input) > 2 else None

    if weight_int8 is None:
        print(f"  [{layer_name}] cannot resolve weight")
        continue

    # Trace input activation DQ
    input_dq = output_to_node.get(conv_input_name)
    if input_dq and input_dq.op_type == 'DequantizeLinear':
        input_act_scale = resolve_value(input_dq.input[1])
        input_act_scale_val = float(input_act_scale) if input_act_scale is not None else 1.0
    else:
        input_act_scale_val = 1.0  # first layer or unknown

    # Trace output: Conv → Relu → QL, or Conv → Add → Relu → QL
    conv_out = conv.output[0]
    ql_out, has_relu = find_relu_then_ql(conv_out)
    if ql_out is None:
        ql_out, has_relu = find_add_then_ql(conv_out)
    if ql_out:
        out_scale = resolve_value(ql_out.input[1])
        out_act_scale_val = float(out_scale) if out_scale is not None else 1.0
    else:
        out_act_scale_val = 1.0

    # Bias
    if conv_bias_name:
        bias_dq = output_to_node.get(conv_bias_name)
        if bias_dq and bias_dq.op_type == 'DequantizeLinear':
            bias_fp32_raw = resolve_value(bias_dq.input[0])
            bias_scale = resolve_value(bias_dq.input[1])
            if bias_fp32_raw is not None and bias_scale is not None:
                bias_fp32 = bias_fp32_raw.astype(np.float32) * bias_scale.flatten()
            else:
                bias_fp32 = np.zeros(weight_int8.shape[0], dtype=np.float32)
        else:
            bias_fp32 = resolve_value(conv_bias_name)
            if bias_fp32 is None:
                bias_fp32 = np.zeros(weight_int8.shape[0], dtype=np.float32)
    else:
        bias_fp32 = np.zeros(weight_int8.shape[0], dtype=np.float32)

    # Compute DQA parameters
    out_ch = weight_int8.shape[0]
    w_scale_flat = w_scale.flatten()[:out_ch]
    dqa_scale = w_scale_flat * input_act_scale_val
    dqa_bias = bias_fp32.flatten()[:out_ch]

    # Save
    npz_name = layer_name.replace('.', '_') + '.npz'
    npz_path = OUTPUT_DIR / npz_name

    np.savez(npz_path,
             weight_int8=weight_int8.astype(np.int8),
             weight_scale=w_scale_flat.reshape(out_ch, 1, 1, 1).astype(np.float32),
             weight_zero_point=w_zp.flatten().astype(np.float32) if w_zp is not None else np.zeros(1, dtype=np.float32),
             dqa_scale=dqa_scale.astype(np.float32),
             dqa_bias=dqa_bias.astype(np.float32),
             act_scale=np.float32(out_act_scale_val),
             act_zero_point=np.float32(0.0))

    kernel = attrs.get('kernel_shape', [1, 1])
    stride = attrs.get('strides', [1, 1])
    pad = attrs.get('pads', [0, 0, 0, 0])

    print(f"  [{layer_name}] {weight_int8.shape} k={kernel} s={stride} "
          f"relu={'Y' if has_relu else 'N'} act_out={out_act_scale_val:.6e}")

    layer_info[layer_name] = {
        'weight_shape': list(weight_int8.shape),
        'kernel': kernel,
        'stride': stride,
        'padding': pad,
        'has_relu': has_relu,
        'output_act_scale': out_act_scale_val,
    }
    act_scales[layer_name] = {
        'scale': out_act_scale_val,
        'zero_point': 0.0,
        'signed': True,
    }

# Save activation scales
act_scales_path = MODEL_DIR / 'parsed' / 'activation_scales.json'
with open(act_scales_path, 'w') as f:
    json.dump(act_scales, f, indent=2)

# Summary
print(f"\n{'='*60}")
print(f"Saved {len(layer_info)} layers to {OUTPUT_DIR}")
print(f"Saved activation_scales.json")

# acc_depth analysis
print(f"\n{'='*60}")
print(f"ResNet18 acc_depth analysis (DCIM_CH_IN=64, ACC_MAX=80):")
import math
for name, info in layer_info.items():
    in_ch = info['weight_shape'][1]
    k = info['kernel'][0]
    acc = math.ceil(in_ch * k * k / 64)
    flag = ' ⚠️ EXCEED' if acc > 80 else ''
    print(f"  {name:40s} cin={in_ch:3d} k={k} → acc={acc:3d}{flag}")
