"""Parse INT16 quantized ONNX (Brevitas QDQ format without manifest).

Extracts INT16 weights, scales, BN params and generates network.json + NPZ files
compatible with golden_module_tb / e2e_detect.py.
"""
import os, sys, json
import numpy as np
import onnx
from pathlib import Path
from collections import OrderedDict
from onnx import numpy_helper

def get_initializer(model, name):
    for init in model.graph.initializer:
        if init.name == name:
            return numpy_helper.to_array(init)
    return None

def find_constant_value(model, output_name):
    """Find the constant value that produces output_name."""
    for node in model.graph.node:
        if output_name in node.output:
            if node.op_type == 'Constant':
                for attr in node.attribute:
                    if attr.name == 'value':
                        return numpy_helper.to_array(attr.t)
            # Could be a reshape of an initializer
            if node.op_type == 'Reshape':
                return find_constant_value(model, node.input[0])
    return get_initializer(model, output_name)

def main():
    INT16_ONNX = Path(r'e:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\model\algorithm\quantized-yolov5\runs\train\infrared_qat_int16\weights\best.quant.onnx')
    FP32_ONNX = Path(r'e:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\model\algorithm\quantized-yolov5\runs\train\infrared_qat_int16\weights\best.onnx')
    OUTPUT_DIR = Path(r'e:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA\model\yolov5n\parsed_int16')
    WEIGHT_DIR = OUTPUT_DIR / 'weights'
    WEIGHT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Loading quantized model: {INT16_ONNX}")
    qmodel = onnx.load(str(INT16_ONNX))
    print(f"Loading FP32 model: {FP32_ONNX}")
    fp32_model = onnx.load(str(FP32_ONNX))

    # Build name->initializer map for FP32 model (for BN params)
    fp32_inits = {i.name: numpy_helper.to_array(i) for i in fp32_model.graph.initializer}

    # Parse all Quant→Conv→BN→Relu chains
    layers = []
    node_output_to_node = {out: n for n in qmodel.graph.node for out in n.output}

    # Find all Conv nodes
    conv_nodes = [n for n in qmodel.graph.node if n.op_type == 'Conv']
    print(f"Found {len(conv_nodes)} Conv nodes")

    for conv_node in conv_nodes:
        name = conv_node.name.replace('/Conv', '').lstrip('/')
        # Clean up name: /model.0/conv/Conv -> model.0.conv
        name = name.replace('/', '.')
        # Fix QuantC3 bottleneck: model.2.m.m.0.cv1 → model.2.m.0.cv1
        name = name.replace('.m.m.', '.m.')

        # Get weight from Quant node input
        weight_input = conv_node.input[1]  # Quant output
        quant_node = node_output_to_node.get(weight_input)
        if quant_node is None or quant_node.op_type != 'Quant':
            print(f"  SKIP {name}: no Quant for weight")
            continue

        # Quant node inputs: [data, scale, zero_point]
        w_int = find_constant_value(qmodel, quant_node.input[0])
        w_scale = find_constant_value(qmodel, quant_node.input[1])
        w_zp = find_constant_value(qmodel, quant_node.input[2])

        if w_int is None:
            print(f"  SKIP {name}: cannot find weight data")
            continue

        # Get activation quant (output of the chain: Conv→BN→Relu→Quant)
        # Trace: conv_output → BN → Relu → act_quant
        conv_out = conv_node.output[0]
        # Find BN
        bn_node = None
        for n in qmodel.graph.node:
            if n.op_type == 'BatchNormalization' and conv_out in n.input:
                bn_node = n
                break

        act_scale_val = None
        act_zp_val = None
        if bn_node:
            bn_out = bn_node.output[0]
            # Find Relu
            relu_node = None
            for n in qmodel.graph.node:
                if n.op_type == 'Relu' and bn_out in n.input:
                    relu_node = n
                    break
            if relu_node:
                relu_out = relu_node.output[0]
                # Find act Quant
                for n in qmodel.graph.node:
                    if n.op_type == 'Quant' and relu_out in n.input:
                        act_scale_val = find_constant_value(qmodel, n.input[1])
                        act_zp_val = find_constant_value(qmodel, n.input[2])
                        break

        # Get conv attributes
        stride = [1, 1]
        pads = [0, 0, 0, 0]
        group = 1
        for attr in conv_node.attribute:
            if attr.name == 'strides':
                stride = list(attr.ints)
            elif attr.name == 'pads':
                pads = list(attr.ints)
            elif attr.name == 'group':
                group = attr.i

        # Get BN params from FP32 model
        bn_key = name.replace('.conv', '.bn')
        bn_gamma = fp32_inits.get(f'{bn_key}.weight')
        # Fallback: try removing extra '.m' from QuantC3 bottleneck path
        # ONNX export: model.2.m.m.0.cv1 → FP32: model.2.m.0.cv1
        if bn_gamma is None and '.m.m.' in bn_key:
            bn_key = bn_key.replace('.m.m.', '.m.', 1)
            bn_gamma = fp32_inits.get(f'{bn_key}.weight')
        bn_beta = fp32_inits.get(f'{bn_key}.bias')
        bn_mean = fp32_inits.get(f'{bn_key}.running_mean')
        bn_var = fp32_inits.get(f'{bn_key}.running_var')

        if bn_gamma is None:
            print(f"  SKIP {name}: no BN params ({bn_key})")
            continue

        # Compute DQA parameters
        # dqa_scale = in_act_scale * w_scale * bn_scale
        # dqa_bias = bn_beta - bn_mean * bn_scale
        eps = 1e-5
        bn_scale = bn_gamma / np.sqrt(bn_var + eps)
        dqa_bias = bn_beta - bn_mean * bn_scale

        # Determine in_act_scale: for first layer use input_act_scale (1/32767),
        # for all others use the previous layer's act_scale (= 0.000305 shared)
        out_act_scale = float(act_scale_val.flatten()[0]) if act_scale_val is not None else 0.000305
        if len(layers) == 0:
            input_act_scale = 1.0 / 32767.0
            in_act_scale = input_act_scale
        else:
            in_act_scale = out_act_scale
        w_scale_flat = w_scale.flatten()
        dqa_scale = in_act_scale * w_scale_flat * bn_scale

        # Weight: ONNX Brevitas QDQ stores weights as float32 (dequantized form: val = int × scale)
        # Must recover integer values by: int16 = round(float / scale)
        w_int_float = w_int  # float32, range ~[-0.55, 0.55]
        oc, ic, kh, kw = w_int_float.shape
        # Recover int16 values: divide by per-channel scale, round to nearest integer
        w_arr = np.round(w_int_float / w_scale_flat.reshape(-1, 1, 1, 1)).astype(np.int16)
        w_ohwi = w_arr.transpose(0, 2, 3, 1)  # OIHW → OHWI

        # FP32 weight for detect head (reconstructed from int16 × scale for accuracy)
        w_fp32 = w_arr.astype(np.float32) * w_scale_flat[:, None, None, None]

        layer_info = {
            'name': name,
            'type': 'conv',
            'out_channels': oc,
            'in_channels': ic * group,
            'kernel_h': kh,
            'kernel_w': kw,
            'stride_h': stride[0],
            'stride_w': stride[1],
            'stride': stride,
            'padding': pads,
            'pad_h': pads[0],
            'pad_w': pads[1],
            'group': group,
            'weight_shape': list(w_ohwi.shape),
            'act_scale': out_act_scale,
            'act_zero_point': int(act_zp_val.flatten()[0]) if act_zp_val is not None else 0,
            'in_act_scale': in_act_scale,
            'has_activation': True,
            'activation': 'relu',
            'bit_width': 16,
        }
        layers.append(layer_info)

        # Save NPZ
        npz_name = name.replace('.', '_')
        npz_path = WEIGHT_DIR / f'{npz_name}.npz'
        np.savez_compressed(str(npz_path),
            weight_int8=w_ohwi,  # actually INT16 but same field name for compat
            weight_scale=w_scale_flat.astype(np.float32),
            weight_zero_point=w_zp.flatten().astype(np.int32),
            dqa_scale=dqa_scale.astype(np.float32),
            dqa_bias=dqa_bias.astype(np.float32),
            act_scale=np.float32(out_act_scale),
            act_zero_point=np.int32(0),
            weight_fp32=w_fp32.astype(np.float32),
            bias=dqa_bias.astype(np.float32),
        )
        print(f"  {name}: w={w_arr.shape} act_scale={out_act_scale:.6f}")

    # Find hard_quant scale (Div nodes)
    hq_scale = None
    for n in qmodel.graph.node:
        if n.op_type == 'Div':
            divisor = find_constant_value(qmodel, n.input[1])
            if divisor is not None:
                hq_scale = 1.0 / float(divisor.flatten()[0]) * float(act_scale_val.flatten()[0]) if act_scale_val is not None else None

    # Build network.json
    network = {
        'model': 'yolov5n-int16',
        'bit_width': 16,
        'input_act_scale': 1.0 / 32767.0,
        'layers': layers,
    }
    if hq_scale:
        network['hard_quant_scale'] = hq_scale

    net_path = OUTPUT_DIR / 'network.json'
    with open(net_path, 'w') as f:
        json.dump(network, f, indent=2)

    print(f"\n[OK] Parsed {len(layers)} layers to {OUTPUT_DIR}")
    print(f"   network.json: {net_path}")
    print(f"   weights: {WEIGHT_DIR}")

    # Print first layer summary
    if layers:
        l0 = layers[0]
        print(f"\n   First layer: {l0['name']} ({l0['in_channels']}→{l0['out_channels']}, {l0['kernel_h']}×{l0['kernel_w']}, s={l0['stride_h']})")
        print(f"   act_scale = {l0['act_scale']}")

if __name__ == '__main__':
    main()
