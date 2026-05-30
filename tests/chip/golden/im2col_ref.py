#!/usr/bin/env python3
"""
im2col_ref.py - im2col 硬件黄金参考模型

功能：
1. 读 network.json 中指定层的参数
2. 生成随机或可预测的 feature map (INT8, NHWC)
3. 计算 im2col 输出矩阵
4. 可选：计算 conv = im2col_matrix × weight_matrix 的结果
5. dump 为 hex 文件，供 RTL tb 对比

用法：
    python tools/im2col_ref.py --layer model.1.conv --h 8 --w 8
    python tools/im2col_ref.py --ch_in 16 --h 8 --w 8 --kh 3 --kw 3 --stride 2 --pad 1
"""

import numpy as np
import json
import argparse
import os

def im2col_nhwc(feature, kH, kW, strideH, strideW, padH, padW):
    """
    对 NHWC 排列的 feature map 做 im2col
    
    Args:
        feature: shape (H, W, CH_IN), dtype uint8
        kH, kW: kernel 尺寸
        strideH, strideW: stride
        padH, padW: padding (对称)
    
    Returns:
        im2col_matrix: shape (OH*OW, kH*kW*CH_IN), dtype uint8
    """
    H, W, CH_IN = feature.shape
    OH = (H + 2*padH - kH) // strideH + 1
    OW = (W + 2*padW - kW) // strideW + 1
    
    col = np.zeros((OH * OW, kH * kW * CH_IN), dtype=np.uint8)
    
    for oh in range(OH):
        for ow in range(OW):
            row_idx = oh * OW + ow
            col_idx = 0
            for kh in range(kH):
                for kw in range(kW):
                    ih = oh * strideH - padH + kh
                    iw = ow * strideW - padW + kw
                    if 0 <= ih < H and 0 <= iw < W:
                        col[row_idx, col_idx:col_idx+CH_IN] = feature[ih, iw, :]
                    # else: zero (already initialized)
                    col_idx += CH_IN
    
    return col


def dump_nhwc_to_hex(data, filepath, word_bytes=16):
    """
    把 NHWC 连续字节 dump 为 hex 文件（每行一个 word_bytes 字的 hex 字符串）
    """
    flat = data.flatten().astype(np.uint8)
    # 补齐到 word_bytes 对齐
    pad_len = (word_bytes - (len(flat) % word_bytes)) % word_bytes
    flat = np.concatenate([flat, np.zeros(pad_len, dtype=np.uint8)])
    
    with open(filepath, 'w') as f:
        for i in range(0, len(flat), word_bytes):
            word = flat[i:i+word_bytes]
            # 小端（低地址在右）：byte[0] 在最右
            hex_str = ''.join(f'{b:02x}' for b in reversed(word))
            f.write(hex_str + '\n')
    
    print(f"Dumped {filepath}: {len(flat)//word_bytes} words ({len(flat)} bytes)")


def load_network_layer(json_path, layer_name):
    """从 network.json 读取指定层参数"""
    with open(json_path, 'r') as f:
        network = json.load(f)
    
    for layer in network['layers']:
        if layer['name'] == layer_name:
            return layer
    
    raise ValueError(f"Layer '{layer_name}' not found in {json_path}")


def main():
    parser = argparse.ArgumentParser(description='im2col golden reference')
    parser.add_argument('--network', default='model/parsed/network.json')
    parser.add_argument('--layer', default=None, help='Layer name from network.json')
    parser.add_argument('--ch_in', type=int, default=16)
    parser.add_argument('--h', type=int, default=8)
    parser.add_argument('--w', type=int, default=8)
    parser.add_argument('--kh', type=int, default=3)
    parser.add_argument('--kw', type=int, default=3)
    parser.add_argument('--stride', type=int, default=2)
    parser.add_argument('--pad', type=int, default=1)
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--outdir', default='sim/im2col_golden')
    args = parser.parse_args()

    if args.layer:
        layer = load_network_layer(args.network, args.layer)
        ch_in = layer['in_channels']
        kh = layer['kernel_h']
        kw = layer['kernel_w']
        stride = layer['stride'][0]
        pad = layer['padding'][0]
        print(f"Layer: {args.layer}")
        print(f"  in_channels={ch_in}, kernel={kh}x{kw}, stride={stride}, pad={pad}")
    else:
        ch_in = args.ch_in
        kh = args.kh
        kw = args.kw
        stride = args.stride
        pad = args.pad

    H, W = args.h, args.w
    OH = (H + 2*pad - kh) // stride + 1
    OW = (W + 2*pad - kw) // stride + 1

    print(f"Input: H={H} W={W} CH_IN={ch_in}")
    print(f"Kernel: {kh}x{kw} stride={stride} pad={pad}")
    print(f"Output: OH={OH} OW={OW}")
    print(f"im2col matrix: ({OH*OW}, {kh*kw*ch_in})")

    np.random.seed(args.seed)

    # 生成可预测 feature map: feature[h][w][c] = ((h*W + w)*CH_IN + c) & 0xFF
    feature = np.zeros((H, W, ch_in), dtype=np.uint8)
    for ih in range(H):
        for iw in range(W):
            for c in range(ch_in):
                feature[ih, iw, c] = ((ih * W + iw) * ch_in + c) & 0xFF

    col = im2col_nhwc(feature, kh, kw, stride, stride, pad, pad)

    os.makedirs(args.outdir, exist_ok=True)

    dump_nhwc_to_hex(feature, os.path.join(args.outdir, 'feature_input.hex'))
    dump_nhwc_to_hex(col, os.path.join(args.outdir, 'im2col_expected.hex'))

    # 附加信息
    info = {
        'ch_in': ch_in, 'H': H, 'W': W,
        'kH': kh, 'kW': kw, 'strideH': stride, 'strideW': stride,
        'padH': pad, 'padW': pad,
        'OH': OH, 'OW': OW,
        'im2col_shape': [OH*OW, kh*kw*ch_in],
        'feature_bytes': H*W*ch_in,
        'im2col_bytes': OH*OW*kh*kw*ch_in,
    }
    with open(os.path.join(args.outdir, 'params.json'), 'w') as f:
        json.dump(info, f, indent=2)
    print(f"Params saved to {args.outdir}/params.json")

    # 验证 self-check
    # (oh=0, ow=0, kh=0, kw=0): ih=-pad, iw=-pad → padding → all 0
    assert np.all(col[0, 0:ch_in] == 0), "First kernel position should be zero (padding)"
    # (oh=0, ow=0, kh=1, kw=1): ih=0, iw=0 → feature[0,0,:]
    offset = (1 * kw + 1) * ch_in
    assert np.all(col[0, offset:offset+ch_in] == feature[0, 0, :]), \
        "kernel pos (1,1) should equal feature[0,0]"
    print("Self-check PASSED!")


if __name__ == '__main__':
    main()
