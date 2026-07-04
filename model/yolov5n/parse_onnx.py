#!/usr/bin/env python3
"""
EdgeYOLO 量化 ONNX 模型解析器

从 best.quant.onnx 提取量化参数（INT8 权重、scale、zero_point、activation scale）
从 best.onnx 提取网络拓扑（Conv 属性、BN 参数、连接关系）

输出:
  - model/parsed/ 目录下的 .npz 文件（每层权重+参数）
  - model/parsed/network.json（完整网络拓扑描述）

用法:
    python model/parse_onnx.py
    python model/parse_onnx.py --output model/parsed
    python model/parse_onnx.py --summary  # 仅打印摘要
"""

import os
import sys
import json
import argparse
from pathlib import Path
from collections import OrderedDict

import numpy as np
import onnx
from onnx import TensorProto


# ============================================================================
# 工具函数
# ============================================================================

def tensor_to_numpy(tensor_proto):
    """将 ONNX TensorProto 转为 numpy array"""
    dtype_map = {
        TensorProto.FLOAT: np.float32,
        TensorProto.INT8: np.int8,
        TensorProto.INT16: np.int16,
        TensorProto.INT32: np.int32,
        TensorProto.INT64: np.int64,
        TensorProto.UINT8: np.uint8,
        TensorProto.DOUBLE: np.float64,
        TensorProto.FLOAT16: np.float16,
    }

    dtype = dtype_map.get(tensor_proto.data_type)
    if dtype is None:
        raise ValueError(f"Unsupported dtype: {tensor_proto.data_type}")

    if tensor_proto.raw_data:
        arr = np.frombuffer(tensor_proto.raw_data, dtype=dtype)
    elif tensor_proto.float_data:
        arr = np.array(tensor_proto.float_data, dtype=np.float32)
    elif tensor_proto.int32_data:
        arr = np.array(tensor_proto.int32_data, dtype=np.int32)
    elif tensor_proto.int64_data:
        arr = np.array(tensor_proto.int64_data, dtype=np.int64)
    else:
        arr = np.array([], dtype=dtype)

    shape = list(tensor_proto.dims)
    if shape:
        arr = arr.reshape(shape)
    return arr


def get_constant_tensor(model, output_name):
    """从 Constant 节点中按 output name 获取 TensorProto"""
    for node in model.graph.node:
        if node.op_type == 'Constant' and output_name in node.output:
            return node.attribute[0].t
    return None


def get_initializer(model, name):
    """从 initializer 中获取参数"""
    for init in model.graph.initializer:
        if init.name == name:
            return tensor_to_numpy(init)
    return None


# ============================================================================
# 量化模型解析（best.quant.onnx）
# ============================================================================

def parse_quant_model(quant_model_path):
    """
    解析量化模型，提取:
    - 每层 INT8 量化权重
    - 每层权重 scale (per-channel)
    - 每层权重 zero_point
    - 每层激活 scale
    - 每层激活 zero_point
    """
    print(f"[1/3] 加载量化模型: {quant_model_path}")
    model = onnx.load(quant_model_path)

    # 解析 manifest
    manifest_tensor = get_constant_tensor(model, 'quant_manifest_ascii')
    manifest_str = tensor_to_numpy(manifest_tensor).tobytes().decode('utf-8')
    manifest_lines = [l for l in manifest_str.strip().split('\n') if l.strip()]

    weight_params = OrderedDict()  # layer_name -> {int, scale, zp, shape}
    act_params = OrderedDict()     # layer_name -> {scale, zp}

    for line in manifest_lines:
        fields = line.split('\t')
        layer_name = fields[0]

        if fields[1] == 'weight':
            int_name = fields[2]
            scale_name = fields[3]
            zp_name = fields[4]

            int_tensor = get_constant_tensor(model, int_name)
            scale_tensor = get_constant_tensor(model, scale_name)
            zp_tensor = get_constant_tensor(model, zp_name)

            # 尝试获取 shape tensor
            shape_name = int_name.replace('__int', '__shape')
            shape_tensor = get_constant_tensor(model, shape_name)

            weight_int = tensor_to_numpy(int_tensor)
            weight_scale = tensor_to_numpy(scale_tensor)
            weight_zp = tensor_to_numpy(zp_tensor)
            orig_shape = tensor_to_numpy(shape_tensor).astype(int) if shape_tensor else None

            weight_params[layer_name] = {
                'int': weight_int,
                'scale': weight_scale,
                'zero_point': weight_zp,
                'orig_shape': orig_shape,
            }

        elif fields[1] == 'act_relu_output':
            scale_name = fields[2]
            zp_name = fields[3]

            scale_tensor = get_constant_tensor(model, scale_name)
            zp_tensor = get_constant_tensor(model, zp_name)

            # signed flag
            signed_name = scale_name.replace('__scale', '__signed_flag')
            signed_tensor = get_constant_tensor(model, signed_name)

            act_scale = tensor_to_numpy(scale_tensor)
            act_zp = tensor_to_numpy(zp_tensor)
            act_signed = tensor_to_numpy(signed_tensor) if signed_tensor else None

            act_params[layer_name] = {
                'scale': float(act_scale.item()) if act_scale.size == 1 else act_scale,
                'zero_point': float(act_zp.item()) if act_zp.size == 1 else act_zp,
                'signed': bool(act_signed.item()) if act_signed is not None else True,
            }

    print(f"       提取 {len(weight_params)} 组权重参数")
    print(f"       提取 {len(act_params)} 组激活量化参数")
    return weight_params, act_params


# ============================================================================
# FP32 模型拓扑解析（best.onnx）
# ============================================================================

def parse_fp32_topology(fp32_model_path):
    """
    解析 FP32 模型，提取:
    - Conv 层属性（kernel_size, stride, padding, groups）
    - BN 层参数（gamma, beta, running_mean, running_var）
    - 网络连接拓扑（用于调度器）
    """
    print(f"[2/3] 加载 FP32 模型: {fp32_model_path}")
    model = onnx.load(fp32_model_path)

    conv_attrs = OrderedDict()
    bn_params = OrderedDict()
    topology = []

    # 提取 Conv 属性
    for node in model.graph.node:
        if node.op_type != 'Conv':
            continue

        # 从 node name 提取层名 "/model.0/conv/Conv" -> "model.0.conv"
        name = node.name.strip('/').replace('/', '.')
        if name.endswith('.Conv'):
            name = name[:-5]

        attrs = {}
        for attr in node.attribute:
            if attr.ints:
                attrs[attr.name] = list(attr.ints)
            else:
                attrs[attr.name] = attr.i

        attr_dict = {
            'kernel_shape': attrs.get('kernel_shape', [1, 1]),
            'strides': attrs.get('strides', [1, 1]),
            'pads': attrs.get('pads', [0, 0, 0, 0]),
            'group': attrs.get('group', 1),
            'dilations': attrs.get('dilations', [1, 1]),
        }

        conv_attrs[name] = attr_dict

        # FP32 模型中 "/model.2/m/m.0/cv2/conv" -> "model.2.m.m.0.cv2.conv"
        # 量化模型中 "model.2.m.0.cv2.conv" (少一个 ".m")
        # 建立别名映射以便后续匹配
        alias = name.replace('.m.m.', '.m.')
        if alias != name:
            conv_attrs[alias] = attr_dict

    # 提取 BN 参数
    for node in model.graph.node:
        if node.op_type != 'BatchNormalization':
            continue

        name = node.name.strip('/').replace('/', '.')
        if name.endswith('.BatchNormalization'):
            name = name[:-18]
        name = name.rstrip('.')

        bn_weight_name = node.input[1]
        bn_bias_name = node.input[2]
        bn_mean_name = node.input[3]
        bn_var_name = node.input[4]

        bn_data = {
            'gamma': get_initializer(model, bn_weight_name),
            'beta': get_initializer(model, bn_bias_name),
            'running_mean': get_initializer(model, bn_mean_name),
            'running_var': get_initializer(model, bn_var_name),
        }

        bn_params[name] = bn_data

        # 建立别名: "model.2.m.m.0.cv2.bn" -> "model.2.m.0.cv2.bn"
        alias = name.replace('.m.m.', '.m.')
        if alias != name:
            bn_params[alias] = bn_data

    # 提取完整拓扑（有序操作列表）
    # 记录关键节点: Conv, BN, Relu, Concat, MaxPool, Resize, Add, Mul, Sigmoid, Split, Slice, Transpose, Reshape
    key_ops = {'Conv', 'BatchNormalization', 'Relu', 'Concat', 'MaxPool',
               'Resize', 'Add', 'Mul', 'Sigmoid', 'Split', 'Slice'}
    for node in model.graph.node:
        if node.op_type not in key_ops:
            continue

        name = node.name.strip('/').replace('/', '.')
        entry = {
            'name': name,
            'op': node.op_type,
            'inputs': list(node.input),
            'outputs': list(node.output),
        }

        if node.op_type == 'Conv':
            if name.endswith('.Conv'):
                name = name[:-5]
            entry['attrs'] = conv_attrs.get(name, {})
        elif node.op_type == 'MaxPool':
            for attr in node.attribute:
                if attr.name == 'kernel_shape':
                    entry['kernel_shape'] = list(attr.ints)
                elif attr.name == 'strides':
                    entry['strides'] = list(attr.ints)
                elif attr.name == 'pads':
                    entry['pads'] = list(attr.ints)
        elif node.op_type == 'Resize':
            for attr in node.attribute:
                if attr.name == 'mode':
                    entry['mode'] = attr.s.decode()
        elif node.op_type == 'Concat':
            for attr in node.attribute:
                if attr.name == 'axis':
                    entry['axis'] = attr.i

        topology.append(entry)

    print(f"       提取 {len(conv_attrs)} 个 Conv 属性")
    print(f"       提取 {len(bn_params)} 组 BN 参数")
    print(f"       拓扑节点: {len(topology)}")
    return conv_attrs, bn_params, topology


# ============================================================================
# BN 融合: 计算等效 bias（conv_weight * bn_scale + bn_bias 形式）
# ============================================================================

def fuse_bn_to_bias(weight_params, bn_params, conv_attrs):
    """
    将 BN 参数融合为等效的 DQA bias。

    对于量化推理流程:
        output_fp32 = (conv_int32_output) * (w_scale * a_scale) * (bn_gamma / sqrt(bn_var + eps)) + fused_bias

    fused_bias = bn_beta - bn_mean * bn_gamma / sqrt(bn_var + eps)

    DQA scale (per-channel):
        dqa_scale[c] = w_scale[c] * a_scale * bn_gamma[c] / sqrt(bn_var[c] + eps)

    DQA bias (per-channel):
        dqa_bias[c] = bn_beta[c] - bn_mean[c] * bn_gamma[c] / sqrt(bn_var[c] + eps)
    """
    eps = 1e-5
    fused_params = OrderedDict()

    for layer_name, wp in weight_params.items():
        # 匹配 BN 层: "model.0.conv" -> "model.0.bn"
        # 检测头 "model.24.m.0" 没有 BN
        if '.conv' in layer_name:
            bn_name = layer_name.replace('.conv', '.bn')
        else:
            bn_name = None

        if bn_name and bn_name in bn_params:
            bn = bn_params[bn_name]
            gamma = bn['gamma']
            beta = bn['beta']
            mean = bn['running_mean']
            var = bn['running_var']

            std = np.sqrt(var + eps)
            bn_scale = gamma / std  # per-channel multiplier
            fused_bias = beta - mean * bn_scale

            # DQA scale = w_scale (per-channel) * bn_scale (per-channel)
            w_scale = wp['scale'].flatten()
            dqa_scale = w_scale * bn_scale

            fused_params[layer_name] = {
                'dqa_scale': dqa_scale.astype(np.float32),
                'dqa_bias': fused_bias.astype(np.float32),
                'has_bn': True,
            }
        else:
            # 检测头层没有 BN
            w_scale = wp['scale'].flatten()
            fused_params[layer_name] = {
                'dqa_scale': w_scale.astype(np.float32),
                'dqa_bias': np.zeros(w_scale.shape[0], dtype=np.float32),
                'has_bn': False,
            }

    return fused_params


# ============================================================================
# 构建层级调度序列
# ============================================================================

def build_layer_schedule(weight_params, act_params, conv_attrs, fused_params):
    """
    构建端到端推理的层级调度序列。
    包含每层的完整信息：类型、参数、输入输出尺寸。
    """
    # 按 YOLO 网络层序号排列
    layer_order = []
    for name in weight_params.keys():
        layer_order.append(name)

    schedule = []
    for layer_name in layer_order:
        wp = weight_params[layer_name]
        fp = fused_params[layer_name]

        # 从 conv_attrs 匹配
        conv_key = layer_name
        attrs = conv_attrs.get(conv_key, {})

        w_shape = list(wp['int'].shape)
        out_channels = w_shape[0]
        in_channels = w_shape[1]
        kh = w_shape[2] if len(w_shape) > 2 else 1
        kw = w_shape[3] if len(w_shape) > 3 else 1

        # 获取激活量化参数
        act_key = layer_name.replace('.conv', '.act')
        act_info = act_params.get(act_key, None)

        entry = {
            'name': layer_name,
            'type': 'conv',
            'out_channels': out_channels,
            'in_channels': in_channels,
            'kernel_h': kh,
            'kernel_w': kw,
            'stride': attrs.get('strides', [1, 1]),
            'padding': attrs.get('pads', [0, 0, 0, 0]),
            'group': attrs.get('group', 1),
            'has_bn': fp['has_bn'],
            'has_activation': act_info is not None,
            'weight_shape': w_shape,
        }

        if act_info:
            entry['act_scale'] = act_info['scale']
            entry['act_zero_point'] = act_info['zero_point']

        schedule.append(entry)

    return schedule


# ============================================================================
# 输出保存
# ============================================================================

def save_parsed_output(output_dir, weight_params, act_params, fused_params,
                       conv_attrs, schedule, topology=None):
    """保存解析结果到文件"""
    os.makedirs(output_dir, exist_ok=True)
    weights_dir = os.path.join(output_dir, 'weights')
    os.makedirs(weights_dir, exist_ok=True)

    print(f"[3/3] 保存解析结果到: {output_dir}/")

    # 保存每层权重为 .npz
    for layer_name, wp in weight_params.items():
        fp = fused_params[layer_name]
        safe_name = layer_name.replace('.', '_').replace('/', '_')

        act_key = layer_name.replace('.conv', '.act')
        act_info = act_params.get(act_key, {})

        save_dict = {
            'weight_int8': wp['int'],
            'weight_scale': wp['scale'],
            'weight_zero_point': wp['zero_point'],
            'dqa_scale': fp['dqa_scale'],
            'dqa_bias': fp['dqa_bias'],
        }

        if act_info:
            save_dict['act_scale'] = np.array(act_info['scale'], dtype=np.float32)
            save_dict['act_zero_point'] = np.array(act_info['zero_point'], dtype=np.float32)

        np.savez_compressed(
            os.path.join(weights_dir, f'{safe_name}.npz'),
            **save_dict
        )

    # 保存网络拓扑 JSON
    network_info = {
        'model_info': {
            'input_shape': [1, 3, 320, 320],
            'output_shape': [1, 6300, 8],
            'num_conv_layers': len(weight_params),
            'quantization': {
                'weight_bits': 8,
                'activation_bits': 8,
                'accumulator_bits': 32,
            },
            'data_layout': 'NHWC',   # 硬件 OBUF 内部一律 NHWC
        },
        'layers': schedule,
        'topology': topology or [],
    }

    json_path = os.path.join(output_dir, 'network.json')
    with open(json_path, 'w') as f:
        json.dump(network_info, f, indent=2, default=_json_default)

    # 保存激活量化参数汇总
    act_summary = {}
    for name, info in act_params.items():
        act_summary[name] = {
            'scale': float(info['scale']) if np.isscalar(info['scale']) else info['scale'].tolist(),
            'zero_point': float(info['zero_point']) if np.isscalar(info['zero_point']) else info['zero_point'].tolist(),
            'signed': info.get('signed', True),
        }

    act_path = os.path.join(output_dir, 'activation_scales.json')
    with open(act_path, 'w') as f:
        json.dump(act_summary, f, indent=2)

    print(f"       权重文件: {weights_dir}/ ({len(weight_params)} 个 .npz)")
    print(f"       网络拓扑: {json_path}")
    print(f"       激活参数: {act_path}")


def _json_default(obj):
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


# ============================================================================
# 打印摘要
# ============================================================================

def print_summary(weight_params, act_params, fused_params, conv_attrs, schedule):
    """打印模型解析摘要"""
    print("\n" + "=" * 80)
    print(" EdgeYOLO 量化模型解析摘要")
    print("=" * 80)

    print(f"\n{'Layer':<35} {'Shape':<20} {'Kernel':<8} {'Stride':<8} {'Pad':<12} {'Act Scale':<10}")
    print("-" * 100)

    total_weight_bytes = 0
    total_mac_ops = 0

    for entry in schedule:
        name = entry['name']
        w_shape = entry['weight_shape']
        kernel = f"{entry['kernel_h']}x{entry['kernel_w']}"
        stride = f"{entry['stride'][0]}x{entry['stride'][1]}"
        pad = f"{entry['padding'][:2]}"

        act_scale_str = f"{entry['act_scale']:.6f}" if entry.get('act_scale') else "N/A"

        shape_str = f"{w_shape}"
        print(f"  {name:<33} {shape_str:<20} {kernel:<8} {stride:<8} {pad:<12} {act_scale_str:<10}")

        # 统计
        weight_size = np.prod(w_shape)
        total_weight_bytes += weight_size
        oc, ic, kh, kw = w_shape[0], w_shape[1], w_shape[2], w_shape[3]
        total_mac_ops += oc * ic * kh * kw

    print("-" * 100)
    print(f"\n  总权重参数量: {total_weight_bytes:,} (INT8 字节)")
    print(f"  总 MAC 操作 (per pixel): {total_mac_ops:,}")
    print(f"  总层数: {len(schedule)}")

    # 权重分布统计
    print(f"\n  权重值域统计:")
    all_weights = np.concatenate([wp['int'].flatten() for wp in weight_params.values()])
    print(f"    范围: [{all_weights.min()}, {all_weights.max()}]")
    print(f"    均值: {all_weights.mean():.4f}")
    print(f"    标准差: {all_weights.std():.4f}")

    # 检查是否可压缩为 INT4
    in_4bit_range = np.sum((all_weights >= -8) & (all_weights <= 7))
    print(f"    在 INT4 范围内 [-8, 7] 的比例: {in_4bit_range / len(all_weights) * 100:.1f}%")

    print()


# ============================================================================
# 主函数
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description='EdgeYOLO ONNX 模型解析器')
    parser.add_argument('--quant-model', type=str,
                        default=None,
                        help='量化模型路径 (default: model/best.quant.onnx)')
    parser.add_argument('--fp32-model', type=str,
                        default=None,
                        help='FP32 模型路径 (default: model/best.onnx)')
    parser.add_argument('--output', type=str,
                        default=None,
                        help='输出目录 (default: model/parsed)')
    parser.add_argument('--summary', action='store_true',
                        help='仅打印摘要，不保存文件')

    args = parser.parse_args()

    # 自动推断路径
    script_dir = Path(__file__).parent
    quant_path = args.quant_model or str(script_dir / 'best.quant.onnx')
    fp32_path = args.fp32_model or str(script_dir / 'best.onnx')
    output_dir = args.output or str(script_dir / 'parsed')

    if not os.path.exists(quant_path):
        print(f"错误: 找不到量化模型 {quant_path}")
        sys.exit(1)
    if not os.path.exists(fp32_path):
        print(f"错误: 找不到 FP32 模型 {fp32_path}")
        sys.exit(1)

    # Step 1: 解析量化模型
    weight_params, act_params = parse_quant_model(quant_path)

    # Step 2: 解析 FP32 模型拓扑
    conv_attrs, bn_params, topology = parse_fp32_topology(fp32_path)

    # Step 3: BN 融合
    fused_params = fuse_bn_to_bias(weight_params, bn_params, conv_attrs)

    # Step 4: 构建调度序列
    schedule = build_layer_schedule(weight_params, act_params, conv_attrs, fused_params)

    # 打印摘要
    print_summary(weight_params, act_params, fused_params, conv_attrs, schedule)

    # 保存
    if not args.summary:
        save_parsed_output(output_dir, weight_params, act_params, fused_params,
                          conv_attrs, schedule, topology=topology)
        print("\n✅ 解析完成！")
        print(f"   下一步: 使用 model/parsed/network.json 和 weights/*.npz 构建推理流水线")
    else:
        print("\n(--summary 模式: 仅打印摘要，未保存文件)")


if __name__ == '__main__':
    main()
