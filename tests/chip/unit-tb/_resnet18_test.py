"""
ResNet18 FPGA 逐层验证

使用与 YOLOv5n 相同的 FPGA 测试框架，验证 ResNet18 所有 20 个 Conv 层。
ResNet18 特点：
- 无 Concat，有 Residual Add
- 有 downsample (1×1 conv stride=2)
- 最大 out_ch=512 → 需 cout-tiling (4 pass)
- 最大 acc_depth=72 (< 80 OK)
- 部分层无 ReLU (residual 分支的第二个 conv)
"""
import sys
sys.path.insert(0, '.')
sys.path.insert(0, '../../../rtl/tb/lite_bd/module_tb')
sys.path.insert(0, '../../../tools')

import numpy as np
import json
import math
from pathlib import Path
from golden_module_tb import (
    load_network, conv_meta, out_hw, im2col, write_hex, write_inst,
    bytes_to_128_words, make_conv_pipeline_case,
)
from xdma_win import ChipRunnerWin

# Load ResNet18 network config - adapt to golden_module_tb format
WEIGHTS_DIR = Path('../../../model/resnet18/parsed/weights')
NET_JSON = Path('../../../model/resnet18/parsed/network.json')

with open(NET_JSON) as f:
    net_raw = json.load(f)

# Build a network dict compatible with golden_module_tb's load_network format
# golden_module_tb expects: net[layer_name] = {...} with specific fields
# For now, do a direct numpy golden test without relying on golden_module_tb's ConvMeta

def load_resnet_layer(layer_name):
    """Load a ResNet18 layer's quantized params."""
    npz_name = layer_name.replace('.', '_') + '.npz'
    npz = np.load(WEIGHTS_DIR / npz_name)
    return {
        'weight_int8': npz['weight_int8'],
        'dqa_scale': npz['dqa_scale'],
        'dqa_bias': npz['dqa_bias'],
        'act_scale': float(npz['act_scale']),
    }


def conv_golden(feat_int8, layer_name, has_relu=True):
    """Pure numpy golden: INT8 conv + DQA + optional ReLU + QA."""
    params = load_resnet_layer(layer_name)
    w = params['weight_int8']  # (cout, cin, kh, kw)
    dqa_s = params['dqa_scale']
    dqa_b = params['dqa_bias']
    act_s = params['act_scale']
    qscale = np.float32(1.0 / act_s)

    cout, cin, kh, kw = w.shape
    h, w_dim, c = feat_int8.shape

    # Get conv attributes from network.json
    layer_cfg = None
    for lyr in net_raw['layers']:
        if lyr['name'] == layer_name or layer_name in lyr.get('name', ''):
            layer_cfg = lyr
            break

    if layer_cfg is None:
        # Try matching by our naming convention
        for lyr in net_raw['layers']:
            # resnetv15_stage1_conv0_fwd → layer1.0.conv1 mapping needed
            pass
        # fallback: infer from weight shape
        stride_h = 2 if 'downsample' in layer_name or (kh > 1 and h > 7 and cout > cin) else 1
        # Actually use the layer_info from parse
        stride_h = 1
        pad_h = kh // 2 if kh > 1 else 0
    else:
        stride_h = layer_cfg['stride'][0]
        pad_h = layer_cfg['padding'][0]

    # Get stride and padding from the parsed info
    with open(WEIGHTS_DIR.parent / 'activation_scales.json') as f:
        act_info = json.load(f)

    # Re-read from parse output for proper stride/pad info
    # Actually we saved these in layer_info during parsing. For now use heuristics:
    # - 7×7 s2: conv1
    # - 3×3 s2: first conv of each stage downsample
    # - 1×1 s2: downsample projections
    # - all others: 3×3 s1 p1
    if kh == 7:
        stride, pad = 2, 3
    elif kh == 1 and 'downsample' in layer_name:
        stride, pad = 2, 0
    elif kh == 3 and '.0.conv1' in layer_name and any(
        s in layer_name for s in ['layer2.0', 'layer3.0', 'layer4.0']
    ):
        stride, pad = 2, 1
    elif kh == 3:
        stride, pad = 1, 1
    else:
        stride, pad = 1, 0

    oh = (h + 2 * pad - kh) // stride + 1
    ow = (w_dim + 2 * pad - kh) // stride + 1

    # im2col
    padded = np.pad(feat_int8, [(pad, pad), (pad, pad), (0, 0)],
                    mode='constant', constant_values=0)
    cols = np.zeros((oh * ow, cin * kh * kw), dtype=np.int8)
    for oy in range(oh):
        for ox in range(ow):
            patch = padded[oy*stride:oy*stride+kh, ox*stride:ox*stride+kw, :]
            cols[oy * ow + ox] = patch.flatten()

    # Matmul
    wflat = w.reshape(cout, -1).astype(np.int32)
    accum = cols.astype(np.int32) @ wflat.T  # (oh*ow, cout)

    # DQA
    dqa = accum.astype(np.float32) * dqa_s[None, :] + dqa_b[None, :]
    if has_relu:
        dqa = np.maximum(dqa, 0.0)

    # QA
    qa = np.clip(np.round(dqa * qscale), -128, 127).astype(np.int8)
    return qa.reshape(oh, ow, cout)


# ResNet18 layer list with attributes
RESNET18_LAYERS = [
    # (name, has_relu, stride, notes)
    ('conv1', True, 2, 'stem 7x7'),
    # BasicBlock layer1.0
    ('layer1.0.conv1', True, 1, ''),
    ('layer1.0.conv2', False, 1, 'pre-add'),
    # BasicBlock layer1.1
    ('layer1.1.conv1', True, 1, ''),
    ('layer1.1.conv2', False, 1, 'pre-add'),
    # BasicBlock layer2.0 (downsample)
    ('layer2.0.conv1', True, 2, 'stride-2'),
    ('layer2.0.conv2', False, 1, 'pre-add'),
    ('layer2.0.downsample.0', False, 2, '1x1 proj'),
    # BasicBlock layer2.1
    ('layer2.1.conv1', True, 1, ''),
    ('layer2.1.conv2', False, 1, 'pre-add'),
    # BasicBlock layer3.0 (downsample)
    ('layer3.0.conv1', True, 2, 'stride-2'),
    ('layer3.0.conv2', False, 1, 'pre-add'),
    ('layer3.0.downsample.0', False, 2, '1x1 proj'),
    # BasicBlock layer3.1
    ('layer3.1.conv1', True, 1, ''),
    ('layer3.1.conv2', False, 1, 'pre-add'),
    # BasicBlock layer4.0 (downsample)
    ('layer4.0.conv1', True, 2, 'stride-2'),
    ('layer4.0.conv2', False, 1, 'pre-add'),
    ('layer4.0.downsample.0', False, 2, '1x1 proj'),
    # BasicBlock layer4.1
    ('layer4.1.conv1', True, 1, ''),
    ('layer4.1.conv2', False, 1, 'pre-add'),
]

# Run golden net (numpy only, dry-run)
print("=" * 60)
print("ResNet18 Numpy Golden 逐层验证 (dry-run)")
print("=" * 60)

rng = np.random.default_rng(42)
# Simulate quantized input: 224×224×3 INT8
input_img = rng.integers(-128, 128, size=(224, 224, 3), dtype=np.int8)

x = input_img
acts = {}

# conv1 → relu → maxpool(3×3 s2 p1)
x = conv_golden(x, 'conv1', has_relu=True)
acts['conv1'] = x
print(f"  conv1: (224,224,3) → {x.shape}")

# MaxPool 3×3 stride=2 pad=1
def maxpool_3x3(feat, stride=2, pad=1):
    h, w, c = feat.shape
    padded = np.pad(feat.astype(np.int16), [(pad, pad), (pad, pad), (0, 0)],
                    mode='constant', constant_values=-128)
    oh = (h + 2 * pad - 3) // stride + 1
    ow = (w + 2 * pad - 3) // stride + 1
    out = np.empty((oh, ow, c), dtype=np.int16)
    for i in range(oh):
        for j in range(ow):
            out[i, j] = padded[i*stride:i*stride+3, j*stride:j*stride+3, :].max(axis=(0, 1))
    return out.astype(np.int8)

x = maxpool_3x3(x)
acts['maxpool'] = x
print(f"  maxpool: → {x.shape}")

# Residual add (INT8 saturating)
def residual_add(a, b):
    return np.clip(a.astype(np.int16) + b.astype(np.int16), -128, 127).astype(np.int8)

def relu_int8(x):
    return np.maximum(x, np.int8(0))

# Layer1
identity = x
x = conv_golden(x, 'layer1.0.conv1', has_relu=True)
x = conv_golden(x, 'layer1.0.conv2', has_relu=False)
x = relu_int8(residual_add(x, identity))
acts['layer1.0'] = x
print(f"  layer1.0: → {x.shape}")

identity = x
x = conv_golden(x, 'layer1.1.conv1', has_relu=True)
x = conv_golden(x, 'layer1.1.conv2', has_relu=False)
x = relu_int8(residual_add(x, identity))
acts['layer1.1'] = x
print(f"  layer1.1: → {x.shape}")

# Layer2 (downsample)
identity = conv_golden(x, 'layer2.0.downsample.0', has_relu=False)
x2 = conv_golden(x, 'layer2.0.conv1', has_relu=True)
x2 = conv_golden(x2, 'layer2.0.conv2', has_relu=False)
x = relu_int8(residual_add(x2, identity))
acts['layer2.0'] = x
print(f"  layer2.0: → {x.shape}")

identity = x
x = conv_golden(x, 'layer2.1.conv1', has_relu=True)
x = conv_golden(x, 'layer2.1.conv2', has_relu=False)
x = relu_int8(residual_add(x, identity))
acts['layer2.1'] = x
print(f"  layer2.1: → {x.shape}")

# Layer3 (downsample)
identity = conv_golden(x, 'layer3.0.downsample.0', has_relu=False)
x2 = conv_golden(x, 'layer3.0.conv1', has_relu=True)
x2 = conv_golden(x2, 'layer3.0.conv2', has_relu=False)
x = relu_int8(residual_add(x2, identity))
acts['layer3.0'] = x
print(f"  layer3.0: → {x.shape}")

identity = x
x = conv_golden(x, 'layer3.1.conv1', has_relu=True)
x = conv_golden(x, 'layer3.1.conv2', has_relu=False)
x = relu_int8(residual_add(x, identity))
acts['layer3.1'] = x
print(f"  layer3.1: → {x.shape}")

# Layer4 (downsample)
identity = conv_golden(x, 'layer4.0.downsample.0', has_relu=False)
x2 = conv_golden(x, 'layer4.0.conv1', has_relu=True)
x2 = conv_golden(x2, 'layer4.0.conv2', has_relu=False)
x = relu_int8(residual_add(x2, identity))
acts['layer4.0'] = x
print(f"  layer4.0: → {x.shape}")

identity = x
x = conv_golden(x, 'layer4.1.conv1', has_relu=True)
x = conv_golden(x, 'layer4.1.conv2', has_relu=False)
x = relu_int8(residual_add(x, identity))
acts['layer4.1'] = x
print(f"  layer4.1: → {x.shape}")

# Global Average Pool + FC (host)
gap = x.mean(axis=(0, 1))  # (512,) FP32
print(f"  GlobalAvgPool: → {gap.shape}")

print(f"\n✅ ResNet18 numpy golden 全网络 dry-run 成功！")
print(f"   最终特征: {x.shape} → GAP → {gap.shape} → FC(1000)")
print(f"\n各层输出统计:")
for name, act in acts.items():
    print(f"  {name:20s}: shape={act.shape}, range=[{act.min()}, {act.max()}]")
