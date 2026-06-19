"""
parse_qonnx.py - 从 QONNX 格式 (brevitas 0.10+ export) 解析 YOLOv5n 量化参数

输入:
  - best.quant.onnx (QONNX 格式, Quant 节点)
  - best.onnx (FP32 拓扑参考)

输出:
  - parsed/network.json
  - parsed/activation_scales.json
  - parsed/weights/*.npz (weight_int8, dqa_scale, dqa_bias, act_scale)
"""
from __future__ import annotations
import argparse, json, os, sys
from collections import OrderedDict
import numpy as np
import onnx
from onnx import numpy_helper


def parse_qonnx(quant_onnx_path: str, output_dir: str):
    model = onnx.load(quant_onnx_path)
    inits = {i.name: numpy_helper.to_array(i) for i in model.graph.initializer}

    # Build output->node map
    output_to_node = {}
    for node in model.graph.node:
        for out in node.output:
            output_to_node[out] = node

    # Build input->consumers map
    input_to_consumers: dict = {}
    for node in model.graph.node:
        for inp in node.input:
            if inp not in input_to_consumers:
                input_to_consumers[inp] = []
            input_to_consumers[inp].append(node)

    convs = [n for n in model.graph.node if n.op_type == 'Conv']
    print(f"Found {len(convs)} Conv nodes")

    layers = []
    for idx, conv in enumerate(convs):
        weight_input = conv.input[1]
        weight_quant_node = output_to_node.get(weight_input)

        # Extract layer name from weight Quant path
        # e.g. '/model.2/m/m.0/cv1/conv/weight_quant/export_handler/Quant_output_0'
        # Target format (compatible with run.py/ops.py):
        #   model.0.conv, model.2.cv1.conv, model.2.m.0.cv1.conv
        name_parts = weight_input.split('/')
        name_segments = []
        for p in name_parts[1:]:  # skip leading empty
            if 'weight_quant' in p or 'export_handler' in p or 'Quant' in p:
                break
            name_segments.append(p)
        # Keep trailing 'conv' for compatibility with run.py/ops.py
        # If no 'conv' at end, add it (all conv layers should end with .conv)
        if name_segments and name_segments[-1] != 'conv':
            name_segments.append('conv')
        # Fix C3 bottleneck: ONNX uses /m/m.0/ but legacy uses /m.0/
        # e.g. ['model.2', 'm', 'm.0', 'cv1', 'conv'] -> ['model.2', 'm.0', 'cv1', 'conv']
        fixed = []
        i = 0
        while i < len(name_segments):
            if name_segments[i] == 'm' and i + 1 < len(name_segments) and name_segments[i+1].startswith('m.'):
                # 'm' followed by 'm.N' -> collapse to 'm.N'
                fixed.append(name_segments[i+1])  # e.g. 'm.0'
                i += 2
            else:
                fixed.append(name_segments[i])
                i += 1
        layer_name = '.'.join(fixed) if fixed else f'layer_{idx}'

        # Get weight from Quant node
        if not (weight_quant_node and weight_quant_node.op_type == 'Quant'):
            print(f"  SKIP {layer_name}: weight not from Quant node")
            continue

        w_data_name = weight_quant_node.input[0]
        w_scale_name = weight_quant_node.input[1]
        w_zp_name = weight_quant_node.input[2]

        w_data = inits.get(w_data_name)
        w_scale = inits.get(w_scale_name)
        w_zp = inits.get(w_zp_name)

        if w_data is None or w_scale is None:
            print(f"  SKIP {layer_name}: missing weight data/scale")
            continue

        # Conv attributes
        attrs = {a.name: a for a in conv.attribute}
        kernel = list(attrs['kernel_shape'].ints) if 'kernel_shape' in attrs else [w_data.shape[2], w_data.shape[3]]
        stride = list(attrs['strides'].ints) if 'strides' in attrs else [1, 1]
        pads = list(attrs['pads'].ints) if 'pads' in attrs else [0, 0, 0, 0]
        group = attrs['group'].i if 'group' in attrs else 1

        # Normalize pads: ONNX uses [top, left, bottom, right]
        if len(pads) == 4:
            pad_h, pad_w = pads[0], pads[1]  # top, left (assume symmetric)
        elif len(pads) == 2:
            pad_h, pad_w = pads[0], pads[1]
        else:
            pad_h, pad_w = 0, 0

        # Find activation quant: trace conv -> BN -> Relu -> Quant
        act_scale = None
        current = conv.output[0]
        for _ in range(5):
            consumers = input_to_consumers.get(current, [])
            if not consumers:
                break
            next_node = consumers[0]
            if next_node.op_type == 'Quant':
                act_scale_name = next_node.input[1]
                if act_scale_name in inits:
                    act_scale = float(inits[act_scale_name].flatten()[0])
                break
            current = next_node.output[0] if next_node.output else None
            if current is None:
                break

        # Quantize: w_int8 = round(w_fp / w_scale), clip to [-128, 127]
        w_int = np.clip(np.round(w_data / w_scale), -128, 127).astype(np.int8)

        # BN fusion: find BN node after conv (before Relu)
        # In QONNX, BN is explicit: Conv -> BN -> Relu -> Quant
        bn_scale = None
        bn_bias = None
        current = conv.output[0]
        consumers = input_to_consumers.get(current, [])
        if consumers and consumers[0].op_type == 'BatchNormalization':
            bn_node = consumers[0]
            # BN inputs: x, scale, bias, mean, var
            bn_s = inits.get(bn_node.input[1])  # gamma
            bn_b = inits.get(bn_node.input[2])  # beta
            bn_mean = inits.get(bn_node.input[3])
            bn_var = inits.get(bn_node.input[4])
            if bn_s is not None and bn_var is not None:
                eps = 1e-5
                for a in bn_node.attribute:
                    if a.name == 'epsilon':
                        eps = a.f
                std = np.sqrt(bn_var + eps)
                bn_scale = bn_s / std  # effective scale
                bn_bias = bn_b - bn_mean * bn_scale if bn_b is not None else -bn_mean * bn_scale

        # DQA parameters: dqa_scale = w_scale_per_ch * input_scale (folded with BN)
        # For hardware: accum_int32 * dqa_scale + dqa_bias = fp32_output
        # accum = sum(input_int8 * weight_int8), so dqa_scale = input_scale * weight_scale
        # With BN: dqa_scale = input_scale * weight_scale * bn_scale
        #          dqa_bias = bn_bias * ... (but we compute it differently)

        # For now, store raw weight scale per channel
        out_ch = w_int.shape[0]
        w_scale_flat = w_scale.flatten()
        if w_scale_flat.size == 1:
            w_scale_arr = np.full(out_ch, w_scale_flat[0], dtype=np.float32)
        else:
            w_scale_arr = w_scale_flat[:out_ch].astype(np.float32)

        layers.append({
            'name': layer_name,
            'conv_node_name': conv.name,
            'weight_int8': w_int,
            'weight_scale': w_scale_arr,
            'weight_zp': w_zp.flatten().astype(np.float32) if w_zp is not None else np.zeros(1, dtype=np.float32),
            'act_scale': act_scale,
            'kernel': kernel,
            'stride': stride,
            'pads': pads,
            'pad_h': pad_h,
            'pad_w': pad_w,
            'group': group,
            'out_channels': out_ch,
            'in_channels': w_int.shape[1] * group,
            'bn_scale': bn_scale,
            'bn_bias': bn_bias,
        })

    print(f"Parsed {len(layers)} layers successfully")

    # ─── Compute DQA parameters ───
    # For layer i: input is quantized with act_scale of layer (i-1)
    # First layer input scale: from the input Quant node
    # Find input quant scale
    input_quant_scale = None
    for node in model.graph.node:
        if node.op_type == 'Quant':
            # Check if this is the first quant (input quantization)
            is_input_quant = False
            inp0 = node.input[0]
            if inp0 in [i.name for i in model.graph.input]:
                is_input_quant = True
            elif inp0 in output_to_node:
                producer = output_to_node[inp0]
                if producer.op_type == 'Div':  # /255 then Quant
                    is_input_quant = True
            if is_input_quant:
                sc_name = node.input[1]
                if sc_name in inits:
                    input_quant_scale = float(inits[sc_name].flatten()[0])
                    break

    if input_quant_scale is None:
        input_quant_scale = 0.00787  # 1/127 fallback
    print(f"Input quant scale: {input_quant_scale}")

    # Determine actual input act_scale for each Conv by tracing backward in the graph.
    # Conv's input[0] should come from a Quant node; extract that Quant's scale.
    # If input comes from Concat (no Quant), trace Concat's first input.
    conv_input_scales = {}
    for conv in convs:
        inp = conv.input[0]
        producer = output_to_node.get(inp)
        if producer is None:
            # Graph input (first conv)
            conv_input_scales[conv.name] = input_quant_scale
        elif producer.op_type == 'Quant':
            sc_name = producer.input[1]
            if sc_name in inits:
                conv_input_scales[conv.name] = float(inits[sc_name].flatten()[0])
            else:
                conv_input_scales[conv.name] = None
        elif producer.op_type == 'Concat':
            # Concat: all inputs should have the same scale; trace first Quant input
            found = False
            for cinp in producer.input:
                cprod = output_to_node.get(cinp)
                if cprod and cprod.op_type == 'Quant':
                    sc_name = cprod.input[1]
                    if sc_name in inits:
                        conv_input_scales[conv.name] = float(inits[sc_name].flatten()[0])
                        found = True
                        break
                elif cprod and cprod.op_type in ('MaxPool', 'Resize'):
                    # Trace through MaxPool/Resize
                    cprod2 = output_to_node.get(cprod.input[0])
                    if cprod2 and cprod2.op_type == 'Quant':
                        sc_name = cprod2.input[1]
                        if sc_name in inits:
                            conv_input_scales[conv.name] = float(inits[sc_name].flatten()[0])
                            found = True
                            break
            if not found:
                conv_input_scales[conv.name] = None
        else:
            conv_input_scales[conv.name] = None

    # Also detect hard_quant: find Div + Quant pattern after C3 cv3 layers.
    # These produce outputs for model.18/21 and detect head.
    hard_quant_scale = None
    for node in model.graph.node:
        if 'hard_quant' in node.name and node.op_type == 'Quant':
            sc_name = node.input[1]
            if sc_name in inits:
                hard_quant_scale = float(inits[sc_name].flatten()[0])
                break
    if hard_quant_scale:
        print(f"Hard-quant scale (for neck downsamples): {hard_quant_scale}")

    # Build schedule
    schedule = []
    weights_dir = os.path.join(output_dir, 'weights')
    os.makedirs(weights_dir, exist_ok=True)

    for i, ly in enumerate(layers):
        # Input act_scale: use the graph-traced value
        conv_name = ly.get('conv_node_name', '')
        in_act_scale = conv_input_scales.get(conv_name)
        if in_act_scale is None:
            # Fallback: use previous layer's act_scale
            if i == 0:
                in_act_scale = input_quant_scale
            else:
                in_act_scale = layers[i-1]['act_scale'] or input_quant_scale

        # DQA: accum_fp32 = accum_int32 * (in_act_scale * w_scale_per_ch)
        # With BN: result = accum_fp32 * bn_scale + bn_bias
        # Combined: dqa_scale = in_act_scale * w_scale * bn_scale
        #           dqa_bias = bn_bias (or 0 if no BN)
        dqa_scale = in_act_scale * ly['weight_scale']
        dqa_bias = np.zeros(ly['out_channels'], dtype=np.float32)

        if ly['bn_scale'] is not None:
            dqa_scale = dqa_scale * ly['bn_scale'].astype(np.float32)
            dqa_bias = ly['bn_bias'].astype(np.float32) if ly['bn_bias'] is not None else dqa_bias

        # Determine if this layer needs rescaled input (hard_quant path)
        needs_rescale = (in_act_scale == hard_quant_scale and hard_quant_scale is not None
                         and in_act_scale != (layers[i-1]['act_scale'] if i > 0 else input_quant_scale))

        entry = {
            'name': ly['name'],
            'type': 'conv',
            'out_channels': ly['out_channels'],
            'in_channels': ly['in_channels'],
            'kernel': ly['kernel'],
            'kernel_h': ly['kernel'][0],
            'kernel_w': ly['kernel'][1],
            'stride': ly['stride'],
            'stride_h': ly['stride'][0],
            'stride_w': ly['stride'][1],
            'padding': [ly['pad_h'], ly['pad_w'], ly['pad_h'], ly['pad_w']],
            'pad_h': ly['pad_h'],
            'pad_w': ly['pad_w'],
            'group': ly['group'],
            'weight_shape': [ly['out_channels'], ly['kernel'][0], ly['kernel'][1], ly['in_channels'] // ly['group']],
            'act_scale': ly['act_scale'] or 0.0,
            'act_zero_point': 0.0,
            'in_act_scale': in_act_scale,
            'has_activation': ly['act_scale'] is not None and ly['act_scale'] > 0,
            'activation': 'relu' if (ly['act_scale'] is not None and ly['act_scale'] > 0) else 'none',
            'needs_rescale_input': needs_rescale,
        }
        schedule.append(entry)

        # Save weights - transpose from OIHW to OHWI to match im2col HWC layout
        safe_name = ly['name'].replace('.', '_').replace('/', '_')
        w_ohwi = ly['weight_int8'].transpose(0, 2, 3, 1)  # OIHW -> OHWI
        np.savez_compressed(
            os.path.join(weights_dir, f'{safe_name}.npz'),
            weight_int8=w_ohwi,
            weight_scale=ly['weight_scale'],
            weight_zero_point=ly['weight_zp'],
            dqa_scale=dqa_scale,
            dqa_bias=dqa_bias,
            act_scale=np.float32(ly['act_scale'] or 0.0),
            act_zero_point=np.float32(0.0),
        )

    # Save network.json
    network = {
        'model': 'yolov5n-int8-signed',
        'input_shape': [1, 3, 320, 320],
        'input_act_scale': input_quant_scale,
        'hard_quant_scale': hard_quant_scale,
        'num_layers': len(schedule),
        'layers': schedule,
    }
    net_path = os.path.join(output_dir, 'network.json')
    with open(net_path, 'w') as f:
        json.dump(network, f, indent=2)
    print(f"Saved {net_path}")

    # Save activation_scales.json
    act_scales = OrderedDict()
    for ly in layers:
        act_name = ly['name'].replace('.conv', '.act').replace('.weight_quant', '')
        act_scales[act_name] = {
            'scale': ly['act_scale'] or 0.0,
            'zero_point': 0.0,
            'signed': True,
        }
    act_path = os.path.join(output_dir, 'activation_scales.json')
    with open(act_path, 'w') as f:
        json.dump(act_scales, f, indent=2)
    print(f"Saved {act_path}")

    # Summary
    print(f"\n{'='*60}")
    print(f"  Layers: {len(layers)}")
    print(f"  Act scale (typical): {layers[0]['act_scale']}")
    print(f"  Input scale: {input_quant_scale}")
    print(f"  Weights dir: {weights_dir} ({len(os.listdir(weights_dir))} files)")
    print(f"{'='*60}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--quant-onnx', default='best.quant.onnx')
    parser.add_argument('--output-dir', default='parsed')
    args = parser.parse_args()
    parse_qonnx(args.quant_onnx, args.output_dir)
