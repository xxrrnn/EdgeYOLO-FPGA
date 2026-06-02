#!/usr/bin/env python3
"""
golden_e2e_inst.py - End-to-end golden + INST_Decoder instruction generator.

Generates everything needed by tb_e2e_inst_driven.sv:
  1) Scaled-down 3-layer real-YOLO conv golden (input_feat, im2col, accum, dqa, output)
  2) Weight SRAM hex per layer/tile (INT8 mode nibble-split)
  3) WB BRAM init hex (per-layer DQA scale/bias and QA scale)
  4) Instruction stream hex for INST_Decoder

Scaled spatial dims keep algorithm path identical to full-size, only fewer rows.

Note on ReLU:
  Hardware path is im2col -> DCIM -> DQA_RELU -> QA.  DQA clamps negative
  FP32 results to zero before QA, matching the network activation path used by
  module-level BD tests.

Address map (OBUF, byte addresses; OBUF is 16MB):
  L1 input feature        : 0x000000
  L1 im2col output        : 0x100000
  L1 DCIM accum (INT32)   : 0x200000
  L1 DQA output (FP32)    : 0x300000
  L1 QA output (INT8, symmetric)    : 0x400000
  L2 im2col output        : 0x500000
  L2 DCIM accum           : 0x600000
  L2 DQA output           : 0x700000
  L2 QA output            : 0x800000
  L3 im2col output        : 0x900000
  L3 DCIM accum           : 0xA00000
  L3 DQA output           : 0xB00000
  L3 QA output            : 0xC00000

IBUF (byte addresses, 2MB):
  L1 weights (2 tiles)    : 0x000000 (tile0 at 0x000000, tile1 at 0x000800)
  L2 weights (1 tile)     : 0x010000
  L3 weights (1 tile)     : 0x020000
  Activation scratch      : 0x040000 .. used by im2col->CDMA->IBUF

Per layer:
  IBUF activation base for DCIM = activation scratch (0x040000)
"""
import argparse
import json
import os
import struct
import sys

import numpy as np

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
WEIGHT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', '..', '..', '..', 'model', 'yolov5n', 'parsed', 'weights'
)

NUM_TILES = 4                     # DCIM_NUM_TILES (chip_defines.vh)
DCIM_CH_IN  = 16                   # ch per CIM op
TILE_CH_OUT = 16                   # CH_OUT per tile
OBUF_WORD_BYTES = 16               # 128-bit word
OBUF_ADDR_WIDTH = 20               # OBUF word addr bits (16MB / 16B = 1M words = 20 bits)
IBUF_WORD_BYTES = 16
IBUF_ADDR_WIDTH = 17               # 2MB / 16B = 128k words = 17 bits

# OBUF byte addresses (chunked 1MB each for easy reading)
OBUF_L1_INPUT  = 0x000000
OBUF_L1_IM2COL = 0x100000
OBUF_L1_ACCUM  = 0x200000
OBUF_L1_DQA    = 0x300000
OBUF_L1_OUTPUT = 0x400000
OBUF_L2_IM2COL = 0x500000
OBUF_L2_ACCUM  = 0x600000
OBUF_L2_DQA    = 0x700000
OBUF_L2_OUTPUT = 0x800000
OBUF_L3_IM2COL = 0x900000
OBUF_L3_ACCUM  = 0xA00000
OBUF_L3_DQA    = 0xB00000
OBUF_L3_OUTPUT = 0xC00000

# IBUF byte addresses
IBUF_L1_WEI = 0x000000
IBUF_L2_WEI = 0x010000
IBUF_L3_WEI = 0x020000
IBUF_ACT    = 0x040000

# Physical AXI map (lite BD / build/*/memory_map.md) — for CDMA inst when --hw-phy-addr
OBUF_PHY_BASE = 0x1010_0000_0
IBUF_PHY_BASE = 0x1000_0000_0
HBM_PHY_BASE  = 0x0

# HBM staging (byte offsets within 4GB HBM) — TB preloads hbm_image.hex
HBM_INPUT_OFF   = 0x000000
HBM_WEIGHT_BASE = 0x100000   # 1MB: L1 weights
HBM_WEIGHT_STRIDE = 0x10000  # 64KB per layer slot in HBM image

# WB BRAM byte addresses (32KB)
# Layout: per layer use 256 bytes
WB_L1_SCALE = 0x0000   # 32 FP32 = 128 B
WB_L1_BIAS  = 0x0100   # 32 FP32 = 128 B
WB_L1_QSCALE= 0x0200   # 1 FP32 (single act_scale per layer)
WB_L2_SCALE = 0x0300
WB_L2_BIAS  = 0x0400
WB_L2_QSCALE= 0x0500
WB_L3_SCALE = 0x0600
WB_L3_BIAS  = 0x0700
WB_L3_QSCALE= 0x0800

# Opcodes (matches rtl/vpu/INST_Decoder.sv)
OP_NOP       = 0x0
OP_CDMA_COPY = 0x1
OP_VPU_EXEC  = 0x2
OP_WAIT_CDMA = 0x3
OP_WAIT_VPU  = 0x4
OP_SYNC      = 0x5
OP_DCIM_EXEC = 0x6
OP_WAIT_DCIM = 0x7
OP_DCIM_CFG  = 0x8
OP_END       = 0xF

# VPU unit choose codes (matches Global_VPU.v)
UNIT_DQA    = 1
UNIT_NN     = 2
UNIT_QA     = 3
UNIT_MP     = 4
UNIT_AD     = 6
UNIT_IM2COL = 7

# DCIM register offsets (matches chip_defines.vh)
DCIM_REG_CTRL     = 0x000
DCIM_REG_MODE     = 0x008
DCIM_REG_ACT_BASE = 0x010
DCIM_REG_WEI_BASE = 0x040  # +4 per tile
DCIM_REG_OUT_BASE = 0x140  # +4 per tile
DCIM_REG_TILE_MASK= 0x240  # bit[t]=1 means Tile t enabled

MODE_INT8 = 0b110  # signed INT8 activation x INT8 weight (split nibble)

NETWORK_JSON = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    '..', '..', '..', '..', 'model', 'yolov5n', 'parsed', 'network.json'
)

# Connected 3-layer chains from network.json (L1->L2->L3 channel/spatial compatible).
# l1_full_hw: L1 input HxW at full 320x320 YOLOv5n resolution (before --scale).
E2E_CASES = {
    'default': {
        'layers': ['model.1.conv', 'model.2.cv1.conv', 'model.2.m.0.cv2.conv'],
        'l1_full_hw': (160, 160),
        'desc': '3x3 s2 + 1x1 + 3x3 bottleneck (original mini regression)',
    },
    'early': {
        'layers': ['model.1.conv', 'model.2.cv2.conv', 'model.2.cv3.conv'],
        'l1_full_hw': (160, 160),
        'desc': '3x3 s2 + 1x1 + 1x1 (32ch mid, from network.json)',
    },
    'downsample': {
        'layers': ['model.2.cv3.conv', 'model.3.conv', 'model.4.cv1.conv'],
        'l1_full_hw': (80, 80),
        'desc': '1x1 + 3x3 s2 + 1x1 (OC 32->64->32)',
    },
    'c3_deep': {
        'layers': ['model.3.conv', 'model.4.cv3.conv', 'model.4.cv2.conv'],
        'l1_full_hw': (40, 40),
        'desc': '3x3 s2 + 1x1(64ch) + 1x1(64->32) at 40x40',
    },
    'bottleneck3x3': {
        'layers': ['model.2.m.0.cv1.conv', 'model.2.m.0.cv2.conv', 'model.2.m.0.cv1.conv'],
        'l1_full_hw': (80, 80),
        'desc': '1x1 + 3x3 + 1x1 all 16ch (CSP bottleneck block)',
    },
}


def load_network_conv_index(path=None):
    """Parse network.json -> name -> conv layer dict."""
    path = path or NETWORK_JSON
    with open(path, 'r') as f:
        net = json.load(f)
    index = {}
    for ly in net['layers']:
        if ly.get('type') == 'conv':
            index[ly['name']] = ly
    return index


def npz_path_for_layer(name):
    """model.1.conv -> model/yolov5n/parsed/weights/model_1_conv.npz"""
    fname = name.replace('.', '_') + '.npz'
    return os.path.join(WEIGHT_DIR, fname)


def conv_layer_from_network(name, meta, in_h, in_w):
    """Build ConvLayer using kernel/stride/pad from network.json."""
    stride = meta['stride'][0] if isinstance(meta['stride'], list) else meta['stride']
    pad = meta['padding'][0] if isinstance(meta['padding'], list) else meta['padding']
    return ConvLayer(
        name,
        npz_path_for_layer(name),
        in_h=in_h, in_w=in_w,
        in_ch=meta['in_channels'],
        out_ch=meta['out_channels'],
        kh=meta['kernel_h'], kw=meta['kernel_w'],
        stride=stride, pad=pad,
    )


def build_case_layers(case_name, scale, net_index=None):
    """Instantiate 3 chained ConvLayers for an E2E case."""
    if case_name not in E2E_CASES:
        raise KeyError('Unknown case {!r}. Choose from: {}'.format(
            case_name, ', '.join(sorted(E2E_CASES))))
    spec = E2E_CASES[case_name]
    net_index = net_index or load_network_conv_index()

    def scale_hw(full_h, full_w):
        nh = max(8, int(round(full_h * scale)))
        nw = max(8, int(round(full_w * scale)))
        nh -= nh & 1
        nw -= nw & 1
        return nh, nw

    l1_h, l1_w = scale_hw(spec['l1_full_hw'][0], spec['l1_full_hw'][1])
    layers = []
    in_h, in_w = l1_h, l1_w
    for name in spec['layers']:
        if name not in net_index:
            raise KeyError('Layer {!r} not in network.json'.format(name))
        ly = conv_layer_from_network(name, net_index[name], in_h, in_w)
        layers.append(ly)
        in_h, in_w = ly.oh, ly.ow
    return layers, spec


def write_manifest_svh(path, case_name, scale, verify_words, layers):
    """SystemVerilog manifest consumed by tb_lite_bd_e2e.sv."""
    def chk_words(ly, kind):
        if kind == 'im2col':
            return ly.oh * ly.ow * ly.acc_depth
        if kind == 'accum':
            return ly.oh * ly.ow * ly.out_ch // 4
        return ly.oh * ly.ow * ly.out_ch // 16

    lines = [
        '// Auto-generated by golden_conv_inst.py — do not edit',
        '// case={} scale={} verify_words={}'.format(case_name, scale, verify_words),
        'localparam string E2E_CASE_NAME = "{}";'.format(case_name),
        'localparam integer E2E_VERIFY_WORDS = {};'.format(verify_words),
    ]
    for li, ly in enumerate(layers):
        p = li + 1
        lines += [
            'localparam integer L{}_IN_H = {};'.format(p, ly.in_h),
            'localparam integer L{}_IN_W = {};'.format(p, ly.in_w),
            'localparam integer L{}_IN_C = {};'.format(p, ly.in_ch),
            'localparam integer L{}_IN_WORDS = {};'.format(
                p, (ly.in_h * ly.in_w * ly.in_ch + OBUF_WORD_BYTES - 1) // OBUF_WORD_BYTES),
            'localparam integer L{}_OH = {};'.format(p, ly.oh),
            'localparam integer L{}_OW = {};'.format(p, ly.ow),
            'localparam integer L{}_OC = {};'.format(p, ly.out_ch),
            'localparam integer L{}_ACC_DEPTH = {};'.format(p, ly.acc_depth),
            'localparam integer L{}_NUM_TILES = {};'.format(p, ly.num_tiles),
            'localparam integer L{}_CHK_IM2COL = {};'.format(p, chk_words(ly, 'im2col')),
            'localparam integer L{}_CHK_ACCUM = {};'.format(p, chk_words(ly, 'accum')),
            'localparam integer L{}_CHK_DQA = {};'.format(p, chk_words(ly, 'accum')),
            'localparam integer L{}_CHK_OUTPUT = {};'.format(p, chk_words(ly, 'output')),
        ]
    with open(path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


# -----------------------------------------------------------------------------
# Convolution golden compute
# -----------------------------------------------------------------------------
class ConvLayer:
    """Single conv layer compute matching DCIM/VPU hardware semantics."""

    def __init__(self, name, npz_path, in_h, in_w, in_ch, out_ch, kh, kw, stride, pad):
        self.name = name
        self.in_h = in_h
        self.in_w = in_w
        self.in_ch = in_ch
        self.out_ch = out_ch
        self.kh = kh
        self.kw = kw
        self.stride = stride
        self.pad = pad

        self.oh = (in_h + 2 * pad - kh) // stride + 1
        self.ow = (in_w + 2 * pad - kw) // stride + 1
        self.acc_depth = (kh * kw * in_ch + DCIM_CH_IN - 1) // DCIM_CH_IN

        d = np.load(npz_path)
        self.weight_int8 = d['weight_int8']       # [OC, IC, KH, KW] int8
        self.dqa_scale = d['dqa_scale'].astype(np.float32)   # [OC]
        self.dqa_bias  = d['dqa_bias'].astype(np.float32)    # [OC]
        self.act_scale = float(d['act_scale'])
        assert self.weight_int8.shape == (out_ch, in_ch, kh, kw), \
            f"{name}: weight shape mismatch: got {self.weight_int8.shape}"

    @property
    def im2col_cols_padded(self):
        return self.acc_depth * DCIM_CH_IN

    @property
    def num_tiles(self):
        return (self.out_ch + DCIM_CYCLE - 1) // DCIM_CYCLE

    def compute_im2col(self, feat_int8):
        """feat_int8: [H, W, IC] int8 -> im2col [OH*OW, acc_depth*16] int8 (zero pad)."""
        rows = self.oh * self.ow
        cols = self.im2col_cols_padded
        out = np.zeros((rows, cols), dtype=np.int8)
        for oh in range(self.oh):
            for ow in range(self.ow):
                r = oh * self.ow + ow
                c = 0
                for ky in range(self.kh):
                    for kx in range(self.kw):
                        ih = oh * self.stride - self.pad + ky
                        iw = ow * self.stride - self.pad + kx
                        for ci in range(self.in_ch):
                            if 0 <= ih < self.in_h and 0 <= iw < self.in_w:
                                out[r, c] = feat_int8[ih, iw, ci]
                            c += 1
        return out

    def compute_accum(self, im2col):
        """Standard im2col matmul: im2col[OH*OW, acc_depth*16] × weight[OC, acc_depth*16]^T.

        DCIM RTL now loads a fresh set of 8 weight entries per acc_word,
        matching the standard matmul semantics.
        """
        w = self.weight_int8.reshape(self.out_ch, -1).astype(np.int32)
        if w.shape[1] < self.im2col_cols_padded:
            w = np.pad(w, ((0, 0), (0, self.im2col_cols_padded - w.shape[1])),
                       constant_values=0)
        return im2col.astype(np.int32) @ w.T  # [OH*OW, OC]

    def compute_dqa(self, accum):
        """accum [OH*OW, OC] INT32 -> dqa_relu [OH*OW, OC] FP32.

        Hardware path is DQA_RELU: fp32(accum) * scale + bias, then clamp negatives to 0.
        """
        x = accum.astype(np.float32) * self.dqa_scale[None, :] + self.dqa_bias[None, :]
        return np.maximum(x, 0.0)

    def compute_qa(self, dqa):
        """dqa FP32 -> INT8: clamp(round(x / act_scale), -128, 127). Symmetric quantization."""
        scaled = dqa / self.act_scale
        return np.clip(np.round(scaled), -128, 127).astype(np.int8)

    def forward(self, feat_int8):
        im2col = self.compute_im2col(feat_int8)
        accum  = self.compute_accum(im2col)
        dqa    = self.compute_dqa(accum)
        qa     = self.compute_qa(dqa)
        out    = qa.reshape(self.oh, self.ow, self.out_ch)
        return out, {'im2col': im2col, 'accum': accum, 'dqa': dqa}


# -----------------------------------------------------------------------------
# Weight SRAM pack (INT8 mode)
# -----------------------------------------------------------------------------
DCIM_CYCLE = 8   # SRAM entries loaded per ppCache swap

def pack_weight_to_sram(layer, tile_idx):
    """Pack INT8 weights into 128-bit SRAM entries for one DCIM tile.

    Hardware layout: ppCache loads CYCLE=8 entries per acc_word.
    In INT8 mode, each entry holds one ch_out's weights for 16 ch_in:
      entry[i] = {high_nibbles[63:0], low_nibbles[63:0]}
    8 entries → 8 ch_out per tile per acc_word.

    Total entries per tile = acc_depth * CYCLE (e.g. 9*8=72 for 3x3 IC=16).
    """
    ch_out_per_tile = DCIM_CYCLE  # INT8 mode: 8 effective ch_out per tile
    ch_out_start = tile_idx * ch_out_per_tile
    w_flat = layer.weight_int8.reshape(layer.out_ch, -1)
    if w_flat.shape[1] < layer.im2col_cols_padded:
        w_flat = np.pad(w_flat,
                        ((0, 0), (0, layer.im2col_cols_padded - w_flat.shape[1])),
                        constant_values=0)

    entries = []
    for acc_word in range(layer.acc_depth):
        for c_local in range(ch_out_per_tile):
            c_global = ch_out_start + c_local
            if c_global < layer.out_ch:
                wslice = w_flat[c_global, acc_word * DCIM_CH_IN:
                                          (acc_word + 1) * DCIM_CH_IN]
            else:
                wslice = np.zeros(DCIM_CH_IN, dtype=np.int8)
            entries.append(_pack_nibble_entry(wslice))
    return entries


def _pack_nibble_entry(weights_16ch):
    low = 0
    high = 0
    for c in range(DCIM_CH_IN):
        wb = int(weights_16ch[c]) & 0xFF
        low  |= (wb & 0xF)        << (c * 4)
        high |= ((wb >> 4) & 0xF) << (c * 4)
    return (high << 64) | low


# -----------------------------------------------------------------------------
# Hex writers
# -----------------------------------------------------------------------------
def write_hex(path, lines):
    with open(path, 'w') as f:
        for line in lines:
            f.write(line + '\n')


def bytes_to_128_words(byte_blob):
    """Pack a flat byte buffer into 128-bit words (little-endian)."""
    n = len(byte_blob)
    pad = (-n) % 16
    blob = bytes(byte_blob) + b'\x00' * pad
    words = []
    for i in range(0, len(blob), 16):
        chunk = blob[i:i+16]
        # MSB on the left, byte 15 first
        words.append(''.join(f'{b:02x}' for b in reversed(chunk)))
    return words


def write_feature_hex(path, feat_arr):
    """Flatten in NHWC byte order and write 128-bit words. Symmetric INT8: store as signed bytes."""
    flat = feat_arr.astype(np.int8).tobytes()
    write_hex(path, bytes_to_128_words(flat))


def write_im2col_hex(path, im2col):
    """im2col [rows, cols] int8 -> 128-bit words. Row-major; each row's
    `acc_depth * 16` bytes are placed contiguously so they hit `acc_depth`
    consecutive OBUF words.
    """
    flat = im2col.astype(np.int8).tobytes()
    write_hex(path, bytes_to_128_words(flat))


def write_accum_hex(path, accum, num_tiles):
    """Write accum in pixel-major OBUF layout matching DQA read order.

    Layout: for each pixel, all tiles' channels are contiguous:
      pixel 0: tile0_ch[0:3], tile0_ch[4:7], tile1_ch[0:3], tile1_ch[4:7], ...
      pixel 1: ...
    This gives [OH*OW, OC] row-major INT32 layout = what DQA reads sequentially.
    """
    num_pixels = accum.shape[0]
    lines = []
    for px in range(num_pixels):
        for tile in range(num_tiles):
            ch_base = tile * DCIM_CYCLE
            # word_lo: ch_base+0..3
            blob_lo = b''
            for c in range(4):
                ch = ch_base + c
                val = int(accum[px, ch]) if ch < accum.shape[1] else 0
                blob_lo += struct.pack('<i', val)
            lines.append(''.join(f'{b:02x}' for b in reversed(blob_lo)))
            # word_hi: ch_base+4..7
            blob_hi = b''
            for c in range(4, 8):
                ch = ch_base + c
                val = int(accum[px, ch]) if ch < accum.shape[1] else 0
                blob_hi += struct.pack('<i', val)
            lines.append(''.join(f'{b:02x}' for b in reversed(blob_hi)))
    write_hex(path, lines)


def write_fp32_hex(path, arr_fp32):
    blob = b''
    flat = arr_fp32.astype(np.float32).flatten()
    for v in flat:
        blob += struct.pack('<f', float(v))
    write_hex(path, bytes_to_128_words(blob))


def write_weight_entries_hex(path, entries_128):
    write_hex(path, [f'{e:032x}' for e in entries_128])


def write_inst_hex(path, inst_words_32):
    write_hex(path, [f'{w:08x}' for w in inst_words_32])


# -----------------------------------------------------------------------------
# WB BRAM init blob
# -----------------------------------------------------------------------------
def build_wb_blob(layers, qscale_addrs, scale_addrs, bias_addrs):
    """Build a 32KB byte blob representing WB BRAM contents.

    Each layer writes:
      [WB_Ln_SCALE : +OC*4]   = FP32 scale per OC
      [WB_Ln_BIAS  : +OC*4]   = FP32 bias  per OC
      [WB_Ln_QSCALE: +4]      = single FP32 act_scale
    """
    blob = bytearray(0x8000)  # 32 KB
    for ly, qaddr, saddr, baddr in zip(layers, qscale_addrs, scale_addrs, bias_addrs):
        for c in range(ly.out_ch):
            struct.pack_into('<f', blob, saddr + c * 4, float(ly.dqa_scale[c]))
            struct.pack_into('<f', blob, baddr + c * 4, float(ly.dqa_bias[c]))
        # QA hardware implements multiplication: q = round(dqa * qscale).
        # Python golden defines q = round(dqa / act_scale), so qscale is reciprocal.
        struct.pack_into('<f', blob, qaddr, float(1.0 / ly.act_scale))
    return bytes(blob)


def write_wb_hex(path, wb_blob):
    """WB BRAM is 128-bit word-addressed; same packing as OBUF."""
    write_hex(path, bytes_to_128_words(wb_blob))


def build_hbm_image_blob(input_feat, layers, ibuf_wei_offsets, weight_hex_paths):
    """Pack input feature + per-layer weight tiles into one HBM byte image."""
    l1 = layers[0]
    feat_flat = input_feat.reshape(l1.in_h, l1.in_w, l1.in_ch)
    row_bytes = ((l1.in_ch + 15) // 16) * 16
    feat_bytes = l1.in_h * l1.in_w * row_bytes

    max_used = HBM_INPUT_OFF + feat_bytes
    for li, ly in enumerate(layers):
        hbm_off = HBM_WEIGHT_BASE + li * HBM_WEIGHT_STRIDE
        for tpath in weight_hex_paths[li]:
            if not tpath or not os.path.isfile(tpath):
                continue
            with open(tpath, 'r') as f:
                nlines = sum(1 for ln in f if ln.strip())
            max_used = max(max_used, hbm_off + nlines * 16)
            hbm_off += nlines * 16

    blob = bytearray(max_used)
    for y in range(l1.in_h):
        for x in range(l1.in_w):
            base = HBM_INPUT_OFF + (y * l1.in_w + x) * row_bytes
            for c in range(l1.in_ch):
                blob[base + c] = int(feat_flat[y, x, c]) & 0xFF
    for li, ly in enumerate(layers):
        hbm_off = HBM_WEIGHT_BASE + li * HBM_WEIGHT_STRIDE
        for tpath in weight_hex_paths[li]:
            if not tpath or not os.path.isfile(tpath):
                continue
            with open(tpath, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    w128 = int(line, 16)
                    for b in range(16):
                        blob[hbm_off] = (w128 >> (8 * (15 - b))) & 0xFF
                        hbm_off += 1
    return bytes(blob)


def write_hbm_hex(path, blob):
    write_hex(path, bytes_to_128_words(blob))


# -----------------------------------------------------------------------------
# Instruction encoder
# -----------------------------------------------------------------------------
def make_header(opcode, flags, length):
    """Header: [31:28]=opcode, [27:24]=flags, [23:0]=length.

    INST_Decoder convention for `length`:
      - VPU_EXEC / CDMA_COPY : length is body byte count
      - DCIM_CFG             : length is pair count (each pair = addr_word + data_word)
      - WAIT_* / SYNC / NOP / DCIM_EXEC / END : length is 0
    """
    return ((opcode & 0xF) << 28) | ((flags & 0xF) << 24) | (length & 0xFFFFFF)


def encode_vpu_exec(unit, src_addr, src2_addr, src_c, src_h, src_w,
                    bias_addr, scale_addr, dst_addr,
                    addr_break, addr_s, addr_t):
    """OP_VPU_EXEC body is 12 x 32-bit (48 bytes) per INST_Decoder.sv."""
    body = [unit, src_addr, src2_addr, src_c, src_h, src_w,
            bias_addr, scale_addr, dst_addr, addr_break, addr_s, addr_t]
    assert len(body) == 12
    return [make_header(OP_VPU_EXEC, 0, 12 * 4)] + body


def _split_axi64(addr):
    return (addr >> 32) & 0xFFFFFFFF, addr & 0xFFFFFFFF


def encode_cdma_copy(src_byte_addr, dst_byte_addr, length_bytes, hw_phy_addr=False):
    """OP_CDMA_COPY body.

    Legacy (12 B): src_lsb, dst_lsb, length — TB CDMA uses local OBUF/IBUF offsets.
    HW phy (20 B): src_msb, src_lsb, dst_msb, dst_lsb, length — matches CDMA_Controller.
    """
    if hw_phy_addr:
        s_msb, s_lsb = _split_axi64(src_byte_addr)
        d_msb, d_lsb = _split_axi64(dst_byte_addr)
        return [make_header(OP_CDMA_COPY, 0, 5 * 4),
                s_msb, s_lsb, d_msb, d_lsb, length_bytes & 0xFFFFFFFF]
    return [make_header(OP_CDMA_COPY, 0, 3 * 4),
            src_byte_addr & 0xFFFFFFFF,
            dst_byte_addr & 0xFFFFFFFF,
            length_bytes & 0xFFFFFFFF]


def encode_dcim_cfg(pairs):
    """OP_DCIM_CFG: length = pair count, body = N x (addr_word, data_word).

    `pairs` is a list of (reg_offset, value) tuples.
    """
    body = []
    for a, d in pairs:
        body.append(a & 0xFFFFFFFF)
        body.append(d & 0xFFFFFFFF)
    return [make_header(OP_DCIM_CFG, 0, len(pairs))] + body


def encode_wait_vpu():
    return [make_header(OP_WAIT_VPU, 0, 0)]


def encode_wait_cdma():
    return [make_header(OP_WAIT_CDMA, 0, 0)]


def encode_dcim_exec():
    return [make_header(OP_DCIM_EXEC, 0, 0)]


def encode_wait_dcim():
    return [make_header(OP_WAIT_DCIM, 0, 0)]


def encode_end():
    return [make_header(OP_END, 0, 0)]


def encode_nop():
    return [make_header(OP_NOP, 0, 0)]


def encode_addr_break(kh, kw, stride_h, stride_w, pad_h, pad_w):
    """im2col_unit addr_break encoding:
       {kH[7:0], kW[7:0], strideH[3:0], strideW[3:0], padH[3:0], padW[3:0]}.
    """
    return ((kh & 0xFF) << 24) | ((kw & 0xFF) << 16) \
         | ((stride_h & 0xF) << 12) | ((stride_w & 0xF) << 8) \
         | ((pad_h & 0xF) << 4)     | (pad_w & 0xF)


def build_layer_instructions(layer,
                             feat_obuf_byte, im2col_obuf_byte, dcim_out_obuf_byte,
                             dqa_obuf_byte, qa_obuf_byte,
                             ibuf_act_byte, ibuf_wei_byte_per_tile,
                             wb_scale_byte, wb_bias_byte, wb_qscale_byte,
                             mode=MODE_INT8, hw_phy_addr=False,
                             hbm_first=False, hbm_feat_byte=None, hbm_wei_byte=None):
    """Build the instruction sequence for one conv layer.

    Stages:
      1. im2col (VPU_EXEC unit=IM2COL)
      2. CDMA copy OBUF im2col -> IBUF activation scratch
      3. DCIM_CFG mode/act_base/wei_base*8/out_base*8
      4. DCIM_EXEC + WAIT_DCIM
      5. DQA (VPU_EXEC unit=DQA)
      6. QA  (VPU_EXEC unit=QA)
    """
    insts = []

    def _cdma_src_dst(src_b, dst_b):
        if hw_phy_addr:
            return src_b, dst_b
        return src_b, dst_b

    # --- HBM-first: CDMA staging -> on-chip buffers (real axi_cdma in BD sim) ---
    if hbm_first and hw_phy_addr:
        if hbm_feat_byte is not None:
            src, dst = _cdma_src_dst(HBM_PHY_BASE + hbm_feat_byte,
                                     OBUF_PHY_BASE + feat_obuf_byte)
            feat_bytes = layer.in_h * layer.in_w * layer.in_ch
            feat_bytes = ((feat_bytes + 15) // 16) * 16
            insts += encode_cdma_copy(src, dst, feat_bytes, hw_phy_addr=True)
            insts += encode_wait_cdma()
        if hbm_wei_byte is not None:
            wei_bytes = layer.num_tiles * 256 * IBUF_WORD_BYTES
            src, dst = _cdma_src_dst(HBM_PHY_BASE + hbm_wei_byte,
                                     IBUF_PHY_BASE + ibuf_wei_byte_per_tile[0])
            insts += encode_cdma_copy(src, dst, wei_bytes, hw_phy_addr=True)
            insts += encode_wait_cdma()

    # --- im2col ---
    insts += encode_vpu_exec(
        UNIT_IM2COL,
        src_addr=feat_obuf_byte,
        src2_addr=0,
        src_c=layer.in_ch,
        src_h=layer.in_h,
        src_w=layer.in_w,
        bias_addr=0,
        scale_addr=0,
        dst_addr=im2col_obuf_byte,
        addr_break=encode_addr_break(layer.kh, layer.kw,
                                     layer.stride, layer.stride,
                                     layer.pad, layer.pad),
        addr_s=layer.oh,
        addr_t=layer.ow,
    )
    insts += encode_wait_vpu()

    # --- CDMA: copy im2col bytes from OBUF to IBUF activation scratch ---
    im2col_bytes = layer.oh * layer.ow * layer.acc_depth * OBUF_WORD_BYTES
    if hw_phy_addr:
        cdma_src = OBUF_PHY_BASE + im2col_obuf_byte
        cdma_dst = IBUF_PHY_BASE + ibuf_act_byte
    else:
        cdma_src = im2col_obuf_byte
        cdma_dst = ibuf_act_byte
    insts += encode_cdma_copy(cdma_src, cdma_dst, im2col_bytes, hw_phy_addr=hw_phy_addr)
    insts += encode_wait_cdma()

    # --- DCIM config + exec (looped per output pixel) ---
    # DCIM Tile processes acc_depth words per start → 1 output pixel.
    # We must loop OH*OW times, updating ACT_BASE and OUT_BASE each iteration.
    mode_reg = ((layer.acc_depth & 0xFF) << 8) | (mode & 0x7)
    dcim_out_word = dcim_out_obuf_byte // OBUF_WORD_BYTES
    ibuf_act_word = ibuf_act_byte // IBUF_WORD_BYTES

    # One-time config: MODE + WEI_BASE + TILE_MASK (constant across pixels)
    init_pairs = [(DCIM_REG_MODE, mode_reg)]
    for t in range(NUM_TILES):
        wei_word = (ibuf_wei_byte_per_tile[t] if t < len(ibuf_wei_byte_per_tile)
                    else 0) // IBUF_WORD_BYTES
        init_pairs.append((DCIM_REG_WEI_BASE + t * 4, wei_word))
    # NEW: TILE_MASK tells hardware which Tiles are active for this layer.
    # Tiles with mask=0 stay IDLE and never write OBUF.
    tile_mask = (1 << layer.num_tiles) - 1  # e.g. num_tiles=4 -> 0b00001111
    init_pairs.append((DCIM_REG_TILE_MASK, tile_mask))
    insts += encode_dcim_cfg(init_pairs)

    # Per-pixel loop
    num_pixels = layer.oh * layer.ow
    # INT8 mode: each result writes 2 words per tile (256-bit packed as 2x128b)
    words_per_pixel_per_tile = 2
    for px in range(num_pixels):
        # ACT_BASE for this pixel: ibuf_act_word + px * acc_depth
        px_act = ibuf_act_word + px * layer.acc_depth
        # OUT_BASE for this pixel: each active tile writes at its own offset.
        # Unused tiles (t >= layer.num_tiles) are gated off by
        # DCIM_REG_TILE_MASK below, so their OUT_BASE is don't-care.
        px_pairs = [(DCIM_REG_ACT_BASE, px_act)]
        for t in range(NUM_TILES):
            if t < layer.num_tiles:
                # Pixel-major layout: all tiles' channels contiguous per pixel
                # pixel px occupies num_tiles * 2 words, tile t at offset t*2 within that
                base = dcim_out_word + px * layer.num_tiles * words_per_pixel_per_tile + t * words_per_pixel_per_tile
            else:
                base = 0  # don't care: Tile disabled by TILE_MASK
            px_pairs.append((DCIM_REG_OUT_BASE + t * 4, base))
        insts += encode_dcim_cfg(px_pairs)
        insts += encode_dcim_exec()
        insts += encode_wait_dcim()

    # Flush delay: all Tiles finish OBUF writes (8 tiles may need extra cycles).
    for _ in range(16):
        insts += encode_nop()

    # --- DQA ---
    # src = dcim_out (INT32 in OBUF, byte addr), dst = dqa output area
    # WB scale/bias addresses are byte offsets within WB
    insts += encode_vpu_exec(
        UNIT_DQA,
        src_addr=dcim_out_obuf_byte,
        src2_addr=0,
        src_c=layer.out_ch,
        src_h=layer.oh,
        src_w=layer.ow,
        bias_addr=wb_bias_byte,
        scale_addr=wb_scale_byte,
        dst_addr=dqa_obuf_byte,
        addr_break=0, addr_s=0, addr_t=0,
    )
    insts += encode_wait_vpu()

    # --- QA ---
    insts += encode_vpu_exec(
        UNIT_QA,
        src_addr=dqa_obuf_byte,
        src2_addr=0,
        src_c=layer.out_ch,
        src_h=layer.oh,
        src_w=layer.ow,
        bias_addr=0,
        scale_addr=wb_qscale_byte,
        dst_addr=qa_obuf_byte,
        addr_break=0, addr_s=0, addr_t=0,
    )
    insts += encode_wait_vpu()

    return insts


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser()
    p.add_argument('--case', default='default',
                   help='Conv-chain case name (see E2E_CASES in this file). '
                        'Use "list" to print cases and exit.')
    p.add_argument('--scale', type=float, default=0.2,
                   help='Spatial scale factor for L1 input dims (default 0.2)')
    p.add_argument('--verify-words', type=int, default=32,
                   help='Max 128-bit words per checkpoint (0 = full tensor for layer)')
    p.add_argument('--seed', type=int, default=42)
    p.add_argument('--network-json', default=None,
                   help='Override path to network.json')
    p.add_argument('--out-dir', default=None,
                   help='Output dir for hex files (default: rtl/tb/lite_bd/data)')
    p.add_argument('--hw-phy-addr', action='store_true',
                   help='CDMA_COPY uses physical AXI addresses (OBUF/IBUF base from BD)')
    p.add_argument('--bd-sim', action='store_true',
                   help='lite BD VCS sim: --hw-phy-addr + HBM-first CDMA inst + hbm_image.hex')
    p.add_argument('--bd-sim-fast', action='store_true',
                   help='lite BD fast sim: --hw-phy-addr, preload OBUF/IBUF directly, skip HBM-first copies')
    p.add_argument('--bd-e2e', action='store_true',
                   help=argparse.SUPPRESS)  # deprecated alias for --bd-sim
    args = p.parse_args()

    if args.bd_sim or args.bd_e2e or args.bd_sim_fast:
        args.hw_phy_addr = True
    if args.bd_sim or args.bd_e2e:
        args.bd_sim = True
    bd_mode = 'hbm-first' if args.bd_sim else ('fast-onchip' if args.bd_sim_fast else 'standalone')

    if args.case == 'list':
        print('Conv-chain cases (3-layer chains from network.json):')
        for k, v in sorted(E2E_CASES.items()):
            print('  {:16s}  {}  layers={}'.format(k, v['desc'], v['layers']))
        return 0

    out_dir = args.out_dir or os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out_dir, exist_ok=True)

    s = args.scale
    net_index = load_network_conv_index(args.network_json)
    layers, spec = build_case_layers(args.case, s, net_index)
    verify_words = max(0, args.verify_words)

    print('Case: {} ({})'.format(args.case, spec['desc']))
    print('Scale factor: {:.3f}'.format(s))
    print('Verify words per checkpoint: {} (0=all)'.format(verify_words))
    print('HW physical CDMA addresses: {}'.format(args.hw_phy_addr))
    print('HBM-first (BD sim): {}'.format(args.bd_sim))
    print('Fast on-chip preload (BD sim): {}'.format(args.bd_sim_fast))
    print('  L1 input HxW : {}x{}'.format(layers[0].in_h, layers[0].in_w))
    if len(layers) > 1:
        print('  L2 input HxW : {}x{}'.format(layers[1].in_h, layers[1].in_w))
    if len(layers) > 2:
        print('  L3 input HxW : {}x{}'.format(layers[2].in_h, layers[2].in_w))

    print('\nLayer summary:')
    for ly in layers:
        print('  {}: in={}x{}x{} ker={}x{} s={} p={} -> out={}x{}x{}  acc_depth={} num_tiles={}'
              .format(ly.name, ly.in_h, ly.in_w, ly.in_ch,
                      ly.kh, ly.kw, ly.stride, ly.pad,
                      ly.oh, ly.ow, ly.out_ch,
                      ly.acc_depth, ly.num_tiles))

    # ---- Random input feature (symmetric INT8, range [-128, 127]) ----
    np.random.seed(args.seed)
    l1 = layers[0]
    input_feat = np.random.randint(
        -128, 128, size=(l1.in_h, l1.in_w, l1.in_ch), dtype=np.int8)

    # ---- Forward all 3 layers ----
    feats = [input_feat]
    intermediates_all = []
    for ly in layers:
        cur_feat = feats[-1]
        # Channel count consistency check
        assert cur_feat.shape[2] == ly.in_ch, \
            'Layer {} expects in_ch={} but got {}'.format(ly.name, ly.in_ch, cur_feat.shape[2])
        out_int8, mid = ly.forward(cur_feat)
        intermediates_all.append(mid)
        feats.append(out_int8)
        print('  {} accum range=[{}, {}]  dqa range=[{:.3f}, {:.3f}]  out nonzero={:.1%}'.format(
            ly.name,
            int(mid['accum'].min()), int(mid['accum'].max()),
            float(mid['dqa'].min()), float(mid['dqa'].max()),
            (out_int8 != 0).mean()))

    # ---- Address map for OBUF (per layer triplet) ----
    obuf_in    = [OBUF_L1_INPUT,  OBUF_L1_OUTPUT, OBUF_L2_OUTPUT]
    obuf_im2c  = [OBUF_L1_IM2COL, OBUF_L2_IM2COL, OBUF_L3_IM2COL]
    obuf_accm  = [OBUF_L1_ACCUM,  OBUF_L2_ACCUM,  OBUF_L3_ACCUM]
    obuf_dqa   = [OBUF_L1_DQA,    OBUF_L2_DQA,    OBUF_L3_DQA]
    obuf_out   = [OBUF_L1_OUTPUT, OBUF_L2_OUTPUT, OBUF_L3_OUTPUT]

    ibuf_act = IBUF_ACT  # shared activation scratch (reused per layer)
    ibuf_wei = [IBUF_L1_WEI, IBUF_L2_WEI, IBUF_L3_WEI]

    wb_scale = [WB_L1_SCALE,  WB_L2_SCALE,  WB_L3_SCALE]
    wb_bias  = [WB_L1_BIAS,   WB_L2_BIAS,   WB_L3_BIAS]
    wb_qscl  = [WB_L1_QSCALE, WB_L2_QSCALE, WB_L3_QSCALE]

    # ---- Write input feature hex ----
    write_feature_hex(os.path.join(out_dir, 'input_feat.hex'),
                      input_feat.reshape(l1.in_h, l1.in_w, l1.in_ch))

    # ---- Write goldens + weights per layer ----
    n_inst = 0
    inst_words = []
    weight_hex_paths = [[] for _ in layers]
    for li, ly in enumerate(layers):
        mid = intermediates_all[li]
        prefix = 'L{}'.format(li + 1)

        write_im2col_hex(os.path.join(out_dir, prefix + '_im2col.hex'), mid['im2col'])
        write_accum_hex (os.path.join(out_dir, prefix + '_accum.hex'),  mid['accum'], ly.num_tiles)
        write_fp32_hex  (os.path.join(out_dir, prefix + '_dqa.hex'),    mid['dqa'])
        # qa output reshaped to NHWC; flatten in same order as hardware
        qa_out = ly.compute_qa(mid['dqa'])
        write_feature_hex(os.path.join(out_dir, prefix + '_output.hex'),
                          qa_out.reshape(ly.oh, ly.ow, ly.out_ch))

        # Weights per tile
        wei_byte_per_tile = []
        for t in range(NUM_TILES):
            if t < ly.num_tiles:
                entries = pack_weight_to_sram(ly, t)
            else:
                entries = []
            # Per-tile IBUF byte offset (tile entries stored contiguously)
            tile_off = ibuf_wei[li] + t * (256 * IBUF_WORD_BYTES)  # 256 words reserved per tile
            wei_byte_per_tile.append(tile_off)
            if entries:
                wh = os.path.join(out_dir, '{}_weight_tile{}.hex'.format(prefix, t))
                write_weight_entries_hex(wh, entries)
                weight_hex_paths[li].append(wh)

        # Layer instructions
        hbm_feat = HBM_INPUT_OFF if (args.bd_sim and li == 0) else None
        hbm_wei = (HBM_WEIGHT_BASE + li * HBM_WEIGHT_STRIDE) if args.bd_sim else None
        layer_insts = build_layer_instructions(
            ly,
            feat_obuf_byte=obuf_in[li],
            im2col_obuf_byte=obuf_im2c[li],
            dcim_out_obuf_byte=obuf_accm[li],
            dqa_obuf_byte=obuf_dqa[li],
            qa_obuf_byte=obuf_out[li],
            ibuf_act_byte=ibuf_act,
            ibuf_wei_byte_per_tile=wei_byte_per_tile,
            wb_scale_byte=wb_scale[li],
            wb_bias_byte=wb_bias[li],
            wb_qscale_byte=wb_qscl[li],
            hw_phy_addr=args.hw_phy_addr,
            hbm_first=args.bd_sim,
            hbm_feat_byte=hbm_feat,
            hbm_wei_byte=hbm_wei,
        )
        inst_words += layer_insts

    inst_words += encode_end()
    write_inst_hex(os.path.join(out_dir, 'inst.hex'), inst_words)

    # ---- WB BRAM init ----
    wb_blob = build_wb_blob(layers, wb_qscl, wb_scale, wb_bias)
    write_wb_hex(os.path.join(out_dir, 'wb_init.hex'), wb_blob)

    if args.bd_sim:
        hbm_blob = build_hbm_image_blob(input_feat, layers, ibuf_wei, weight_hex_paths)
        write_hbm_hex(os.path.join(out_dir, 'hbm_image.hex'), hbm_blob)
        print('Wrote hbm_image.hex ({} bytes)'.format(len(hbm_blob)))

    write_manifest_svh(
        os.path.join(out_dir, 'conv_manifest.svh'),
        args.case, s, verify_words, layers)

    manifest = os.path.join(out_dir, 'manifest.txt')
    with open(manifest, 'w') as f:
        f.write('# Auto-generated. case={} scale={} mode={}\n'.format(args.case, s, bd_mode))
        f.write('CASE={}\n'.format(args.case))
        f.write('BD_MODE={}\n'.format(bd_mode))
        f.write('VERIFY_WORDS={}\n'.format(verify_words))
        f.write('NUM_LAYERS=3\n')
        for li, ly in enumerate(layers):
            f.write('\n# Layer {}\n'.format(li + 1))
            f.write('L{}_NAME={}\n'.format(li + 1, ly.name))
            f.write('L{}_IN_H={} L{}_IN_W={} L{}_IN_C={}\n'.format(
                li + 1, ly.in_h, li + 1, ly.in_w, li + 1, ly.in_ch))
            f.write('L{}_OUT_H={} L{}_OUT_W={} L{}_OUT_C={}\n'.format(
                li + 1, ly.oh, li + 1, ly.ow, li + 1, ly.out_ch))
            f.write('L{}_KH={} L{}_KW={} L{}_STRIDE={} L{}_PAD={}\n'.format(
                li + 1, ly.kh, li + 1, ly.kw, li + 1, ly.stride, li + 1, ly.pad))
            f.write('L{}_ACC_DEPTH={} L{}_NUM_TILES={}\n'.format(
                li + 1, ly.acc_depth, li + 1, ly.num_tiles))
            f.write('L{}_OBUF_IN={:08x}\n'.format(li + 1, obuf_in[li]))
            f.write('L{}_OBUF_IM2COL={:08x}\n'.format(li + 1, obuf_im2c[li]))
            f.write('L{}_OBUF_ACCUM={:08x}\n'.format(li + 1, obuf_accm[li]))
            f.write('L{}_OBUF_DQA={:08x}\n'.format(li + 1, obuf_dqa[li]))
            f.write('L{}_OBUF_OUTPUT={:08x}\n'.format(li + 1, obuf_out[li]))
        f.write('INST_WORD_COUNT={}\n'.format(len(inst_words)))

    print('\nWrote {} files to {}'.format(len(os.listdir(out_dir)), out_dir))
    print('Total instruction words: {}'.format(len(inst_words)))


if __name__ == '__main__':
    main()
