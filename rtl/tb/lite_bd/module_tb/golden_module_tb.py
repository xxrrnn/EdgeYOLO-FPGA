#!/usr/bin/env python3
"""Generate focused module-level BD tests for the lite block design.

The generated data keeps the host/decoder/BD interface unchanged: the testbench still
loads `hbm_image.hex`, `wb_init.hex`, `inst.hex`, starts `INST_Decoder` through
`VPU_AXI_Regs`, and reads OBUF through the same XDMA-forced AXI path.  Only the
instruction sequence, memory contents, and checkpoints are changed per module case.

Covered module groups:
  * dcim_matmul: direct DCIM int8 matrix multiply after CDMA HBM->IBUF staging.
  * dqa / qa: VPU post-process units using WB scale/bias data.
  * us / mp / add: VPU feature-map units using FP32 tensors in OBUF.

Case shapes are selected from model/yolov5n/parsed/network.json to include 6x6/3x3/1x1
convs, stride-2 and stride-1 layers, 16/32/64/128 channels, SPPF maxpool, FPN/PAN
upsample, and residual/concat-like add workloads.
"""
import argparse
import hashlib
import json
import math
import os
import struct
from dataclasses import dataclass
from typing import Dict, Iterable, List, Sequence, Tuple

import numpy as np

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
import sys
sys.path.insert(0, os.path.join(REPO_ROOT, 'tools'))
from chip_config import (  # noqa: E402
    BYTES_PER_WORD,
    DCIM_CH_IN,
    DCIM_CH_OUT,
    DCIM_CYCLE,
    DCIM_INT8_OUT_CH_PER_TILE,
    DCIM_INT16_OUT_CH_PER_TILE,
    DCIM_INT8_OUT_WORDS_PER_TILE,
    DCIM_INT16_OUT_WORDS_PER_TILE,
    DCIM_INT8_ACT_WORDS,
    DCIM_INT16_ACT_WORDS,
    DCIM_NUM_TILES,
    MODE_INT8,
    MODE_INT16,
    require_consistent,
)
require_consistent()

NETWORK_JSON = os.path.join(REPO_ROOT, 'model', 'yolov5n', 'parsed', 'network.json')
WEIGHT_DIR = os.path.join(REPO_ROOT, 'model', 'yolov5n', 'parsed', 'weights')

OBUF_WORD_BYTES = BYTES_PER_WORD
IBUF_WORD_BYTES = BYTES_PER_WORD
WB_SIZE_BYTES = 0x8000
NUM_TILES = DCIM_NUM_TILES
DCIM_CH_IN_INT16 = DCIM_CH_IN // 2

HBM_PHY_BASE = 0x0
IBUF_PHY_BASE = 0x1000_0000_0
OBUF_PHY_BASE = 0x1010_0000_0

HBM_OFF_INPUT0 = 0x00000
HBM_OFF_INPUT1 = 0x40000
HBM_OFF_WEIGHT = 0x80000

OBUF_SRC0 = 0x000000
OBUF_SRC1 = 0x100000
OBUF_DST = 0x200000
OBUF_AUX = 0x300000
IBUF_ACT = 0x000000
IBUF_WEI = 0x080000
WB_SCALE = 0x0000
WB_BIAS = 0x1000
WB_QSCALE = 0x2000

# Fast-preload extra OBUF slots (concat src3/src4 beyond OBUF_AUX)
OBUF_SRC2 = 0x400000
OBUF_SRC3 = 0x500000

IBUF_SIZE_BYTES = 0x200_000  # chip_defines: 2 MB DCIM IBUF

OP_NOP = 0x0
OP_CDMA_COPY = 0x1
OP_VPU_EXEC = 0x2
OP_WAIT_CDMA = 0x3
OP_WAIT_VPU = 0x4
OP_DCIM_EXEC = 0x6
OP_WAIT_DCIM = 0x7
OP_DCIM_CFG = 0x8
OP_DCIM_LAYER = 0x9
OP_END = 0xF

UNIT_DQA = 1
UNIT_QA = 3
UNIT_MP = 4
UNIT_US = 5
UNIT_AD = 6
UNIT_IM2COL = 7

DCIM_REG_MODE = 0x008
DCIM_REG_ACT_BASE = 0x010
DCIM_REG_WEI_BASE = 0x040
DCIM_REG_OUT_BASE = 0x140
DCIM_REG_TILE_MASK = 0x240
DCIM_REG_TILE_MASK_HI = 0x244

# Curated dcim_matmul cases (optional in_hw override for fast smoke tests).
DCIM_MATMUL_CURATED = [
    # INT8 smoke（各 kernel/stride/channel 覆盖）
    {'name': 'dcim_tiny_1x1',       'layer': 'model.2.cv1.conv',      'in_hw': (2, 2)},
    {'name': 'conv6_s2_c3_to16',    'layer': 'model.0.conv',           'in_hw': (12, 12)},
    {'name': 'conv3_s2_c32_to64',   'layer': 'model.3.conv',           'in_hw': (8, 8)},
    {'name': 'conv1_c64_to32',      'layer': 'model.4.cv1.conv',       'in_hw': (6, 6)},
    {'name': 'conv3_c128_to128',    'layer': 'model.6.m.0.cv2.conv',   'in_hw': (5, 5)},
    # INT16 smoke（sign-extend INT8 act → INT16，覆盖 1×1 / 3×3）
    {'name': 'int16_tiny_1x1',      'layer': 'model.2.cv1.conv',      'in_hw': (2, 2),  'int16': True},
    {'name': 'int16_conv3_c32_c64', 'layer': 'model.3.conv',           'in_hw': (4, 4),  'int16': True},
    {'name': 'int16_conv1_c128',    'layer': 'model.6.cv1.conv',       'in_hw': (4, 4),  'int16': True},
    # 当前 4 Tile/64×64 极限维度小规模 RTL 用例：覆盖配置路径与 acc_depth 边界，避免跑完整网络尺寸
    {'name': 'extreme_int8_1x1_c512_to512', 'layer': 'model.9.cv2.conv',       'in_hw': (1, 1),  'synthetic_out_ch': 512},
    {'name': 'extreme_int8_3x3_c128_to512', 'layer': 'model.10.conv',          'in_hw': (3, 3),  'synthetic_out_ch': 512},
    {'name': 'extreme_int8_6x6_c3_to64',    'layer': 'model.0.conv',           'in_hw': (8, 8),  'out_ch_limit': 64},
    {'name': 'extreme_int16_3x3_c128',      'layer': 'model.10.conv',          'in_hw': (3, 3),  'synthetic_out_ch': 256, 'int16': True},
]

MODULE_CASES = {
    'dcim_matmul': DCIM_MATMUL_CURATED,  # extended at runtime via build_dcim_matmul_cases()
    # DQA (dqa_relu_unit)：relu_en 由 OP_VPU_EXEC header flags[0] 控制。
    # 带 ReLU 用例（has_activation=True，flags=0x1）：覆盖 out_ch 16/32/64/128/256 全部五档。
    # 无 ReLU 用例（has_activation=False，flags=0x0）：head 输出层 model.24.m.* ch=24，in_ch 64/128/256。
    'dqa': [
        {'name': 'dqa_c16_small',       'layer': 'model.0.conv',         'hwc': (4, 4, 16),  'relu_en': True},   # ch=16
        {'name': 'dqa_c32_mid',         'layer': 'model.2.m.0.cv1.conv', 'hwc': (3, 5, 32),  'relu_en': True},   # ch=32
        {'name': 'dqa_c64_mid',         'layer': 'model.3.conv',         'hwc': (3, 5, 64),  'relu_en': True},   # ch=64
        {'name': 'dqa_c128_sppf',       'layer': 'model.9.cv1.conv',     'hwc': (2, 5, 128), 'relu_en': True},   # ch=128
        {'name': 'dqa_c256_head',       'layer': 'model.7.conv',         'hwc': (2, 3, 256), 'relu_en': True},   # ch=256
        {'name': 'dqa_nrelu_c24_in64',  'layer': 'model.24.m.0',         'hwc': (4, 4, 24),  'relu_en': False},  # head, no-relu, in_ch=64
        {'name': 'dqa_nrelu_c24_in128', 'layer': 'model.24.m.1',         'hwc': (3, 3, 24),  'relu_en': False},  # head, no-relu, in_ch=128
        {'name': 'dqa_nrelu_c24_in256', 'layer': 'model.24.m.2',         'hwc': (2, 2, 24),  'relu_en': False},  # head, no-relu, in_ch=256
        # INT16 accumulator 输入（DCIM INT16 模式下 accum16→fp32，降低 DCIM 输出带宽）
        {'name': 'dqa_accum16_c32',     'layer': 'model.2.m.0.cv1.conv', 'hwc': (3, 5, 32),  'relu_en': True,  'int16': True},
        {'name': 'dqa_accum16_c64',     'layer': 'model.3.conv',         'hwc': (3, 5, 64),  'relu_en': True,  'int16': True},
    ],
    'qa': [
        {'name': 'qa_c16_signed', 'layer': 'model.0.conv', 'hwc': (4, 4, 16)},
        {'name': 'qa_c64_clip', 'layer': 'model.3.conv', 'hwc': (3, 5, 64)},
        {'name': 'qa_c128_dense', 'layer': 'model.9.cv1.conv', 'hwc': (2, 5, 128)},
        {'name': 'qa_int16_c32_signed', 'layer': 'model.2.m.0.cv1.conv', 'hwc': (3, 5, 32), 'int16': True},  # fp32→int16
    ],
    'us': [
        {'name': 'us_128_10_to20', 'source': 'model.10.conv', 'hwc': (10, 10, 128)},
        {'name': 'us_64_20_to40', 'source': 'model.14.conv', 'hwc': (20, 20, 64)},
    ],
    'mp': [
        {'name': 'mp_sppf_128_10',    'source': 'model.9.cv1.conv',  'hwc': (10, 10, 128), 'cfg': 0},  # SPPF 5x5 s1 p2
        {'name': 'mp_resnet_stem',     'source': 'model.0.conv',       'hwc': (8,  8,  64),  'cfg': 1},  # 3x3 s2 p1
        {'name': 'mp_gap_7x7_c512',    'source': 'model.6.m.0.cv2.conv', 'hwc': (7,  7,  128), 'cfg': 2},  # GAP (小规模验证)
    ],
    'add': [
        {'name': 'add_residual_16', 'source': 'model.2.m.0.cv2.conv', 'hwc': (4, 4, 16)},
        {'name': 'add_residual_32', 'source': 'model.4.m.0.cv2.conv', 'hwc': (4, 5, 32)},
        {'name': 'add_pan_64', 'source': 'model.17.m.0.cv2.conv', 'hwc': (3, 5, 64)},
    ],
    'im2col': [
        {'name': 'im2col_6x6_s2_c3', 'layer': 'model.0.conv', 'in_hw': (12, 12)},
        {'name': 'im2col_3x3_s2_c32', 'layer': 'model.3.conv', 'in_hw': (8, 8)},
        {'name': 'im2col_3x3_s1_c128', 'layer': 'model.6.m.0.cv2.conv', 'in_hw': (5, 5)},
        {'name': 'im2col_1x1_c512', 'layer': 'model.9.cv2.conv', 'in_hw': (4, 4)},
    ],
    'conv_pipeline': [
        {'name': 'pipe_conv3_s2_c32_to64', 'layer': 'model.3.conv', 'in_hw': (8, 8)},
        {'name': 'pipe_conv1_c512_to64_tilepass', 'layer': 'model.9.cv2.conv', 'in_hw': (4, 4), 'out_ch_limit': 64},
    ],
    'concat_by_cdma': [
        {'name': 'concat_2src_c64_c64_hw8x8', 'hw': (8, 8), 'channels': [64, 64]},
        {'name': 'concat_2src_c128_c128_hw10x10', 'hw': (10, 10), 'channels': [128, 128]},
        {'name': 'concat_4src_sppf_c128_hw10x10', 'hw': (10, 10), 'channels': [128, 128, 128, 128]},
    ],
    'large_channel_pressure': [
        {'name': 'dcim_conv1_c512_to64_tilepass', 'module': 'dcim_matmul', 'layer': 'model.9.cv2.conv', 'in_hw': (4, 4), 'out_ch_limit': 64},
        {'name': 'pipe_conv1_c512_to64_tilepass', 'module': 'conv_pipeline', 'layer': 'model.9.cv2.conv', 'in_hw': (4, 4), 'out_ch_limit': 64},
        {'name': 'dqa_c256_pressure', 'module': 'dqa', 'layer': 'model.9.cv2.conv', 'hwc': (2, 4, 256)},
        {'name': 'qa_c256_pressure', 'module': 'qa', 'layer': 'model.9.cv2.conv', 'hwc': (2, 4, 256)},
        {'name': 'concat_c128_c128_to256', 'module': 'concat_by_cdma', 'hw': (10, 10), 'channels': [128, 128]},
    ],
    'mini_network': [
        {'name': 'mini_2conv_c16',
         'desc': '2-layer Conv1x1 16→16 back-to-back, tests multi-layer OBUF management',
         'layers': [
             {'layer': 'model.2.m.0.cv1.conv', 'in_hw': (4, 4), 'in_ch': 16, 'out_ch': 16},
             {'layer': 'model.2.m.0.cv2.conv', 'in_hw': (4, 4), 'in_ch': 16, 'out_ch': 16},
         ]},
        {'name': 'mini_3conv_residual_c32',
         'desc': '3-layer: Conv1x1 32→32, Conv1x1 32→32, Add + QA (CSP residual pattern)',
         'layers': [
             {'layer': 'model.4.m.0.cv1.conv', 'in_hw': (4, 4), 'in_ch': 32, 'out_ch': 32},
             {'layer': 'model.4.m.0.cv2.conv', 'in_hw': (4, 4), 'in_ch': 32, 'out_ch': 32},
         ],
         'residual_add': True},
    ],
}

@dataclass
class ConvMeta:
    name: str
    in_ch: int
    out_ch: int
    kh: int
    kw: int
    stride_h: int
    stride_w: int
    pad_h0: int
    pad_w0: int
    pad_h1: int
    pad_w1: int
    npz_path: str

    @property
    def stride(self) -> int:
        return self.stride_h

    @property
    def pad(self) -> int:
        return self.pad_h0

    @property
    def acc_depth(self) -> int:
        """acc_depth 对应 INT8 模式（ceil(K/16)）"""
        return (self.in_ch * self.kh * self.kw + DCIM_CH_IN - 1) // DCIM_CH_IN

    @property
    def acc_depth_int16(self) -> int:
        """INT16 模式 acc_depth = ceil(K/16)
        每步读 2 IBUF word（lo: ch0..7 INT16，hi: ch8..15 INT16）= 16 个 INT16。"""
        return (self.in_ch * self.kh * self.kw + DCIM_CH_IN - 1) // DCIM_CH_IN

    @property
    def matmul_k(self) -> int:
        return self.in_ch * self.kh * self.kw

    @property
    def num_tiles(self) -> int:
        return min(NUM_TILES, (self.out_ch + DCIM_INT8_OUT_CH_PER_TILE - 1) // DCIM_INT8_OUT_CH_PER_TILE)


@dataclass
class ConvIm2colShape:
    """Per-conv im2col / DCIM matmul shape propagated from network.json."""
    layer: str
    in_h: int
    in_w: int
    oh: int
    ow: int
    matmul_m: int
    matmul_k: int
    matmul_n: int
    acc_depth: int


def load_network_file(path: str) -> dict:
    with open(path, 'r') as f:
        return json.load(f)


def load_network(path: str) -> Dict[str, dict]:
    net = load_network_file(path)
    return {ly['name']: ly for ly in net['layers'] if ly.get('type') == 'conv'}


def layer_npz(name: str) -> str:
    return os.path.join(WEIGHT_DIR, name.replace('.', '_') + '.npz')


def conv_meta(net: Dict[str, dict], name: str) -> ConvMeta:
    ly = net[name]
    if isinstance(ly['stride'], list):
        stride_h, stride_w = ly['stride'][0], ly['stride'][1]
    else:
        stride_h = stride_w = int(ly['stride'])
    pad = ly['padding']
    if isinstance(pad, list):
        pad_h0, pad_w0, pad_h1, pad_w1 = pad[0], pad[1], pad[2], pad[3]
    else:
        pad_h0 = pad_w0 = pad_h1 = pad_w1 = int(pad)
    return ConvMeta(
        name, ly['in_channels'], ly['out_channels'],
        ly['kernel_h'], ly['kernel_w'],
        stride_h, stride_w, pad_h0, pad_w0, pad_h1, pad_w1,
        layer_npz(name),
    )


def propagate_conv_im2col_shapes(network: dict) -> Dict[str, ConvIm2colShape]:
    """Walk conv layers in network.json order; derive im2col matmul (M,K,N) per layer."""
    input_shape = network['model_info']['input_shape']
    cur_h, cur_w = int(input_shape[2]), int(input_shape[3])
    net = {ly['name']: ly for ly in network['layers'] if ly.get('type') == 'conv'}
    shapes: Dict[str, ConvIm2colShape] = {}
    for ly in network['layers']:
        if ly.get('type') != 'conv':
            continue
        meta = conv_meta(net, ly['name'])
        oh, ow = out_hw(cur_h, cur_w, meta)
        shapes[ly['name']] = ConvIm2colShape(
            layer=ly['name'],
            in_h=cur_h, in_w=cur_w,
            oh=oh, ow=ow,
            matmul_m=oh * ow,
            matmul_k=meta.matmul_k,
            matmul_n=meta.out_ch,
            acc_depth=meta.acc_depth,
        )
        cur_h, cur_w = oh, ow
    return shapes


def dcim_ibuf_weight_bytes(meta: ConvMeta) -> int:
    return meta.num_tiles * meta.acc_depth * DCIM_CYCLE * OBUF_WORD_BYTES


def dcim_ibuf_act_bytes(meta: ConvMeta, matmul_m: int) -> int:
    return matmul_m * meta.acc_depth * OBUF_WORD_BYTES


def max_matmul_m_for_ibuf(meta: ConvMeta) -> int:
    """Largest im2col row count M=OH*OW that fits activation + weight in IBUF."""
    weight = dcim_ibuf_weight_bytes(meta)
    if weight >= IBUF_SIZE_BYTES:
        return 1
    per_row = meta.acc_depth * OBUF_WORD_BYTES
    if per_row == 0:
        return 1
    return max(1, (IBUF_SIZE_BYTES - weight) // per_row)


def ibuf_fits_dcim_matmul(meta: ConvMeta, matmul_m: int) -> bool:
    return dcim_ibuf_act_bytes(meta, matmul_m) + dcim_ibuf_weight_bytes(meta) <= IBUF_SIZE_BYTES


def scale_in_hw_to_fit_ibuf(meta: ConvMeta, in_h: int, in_w: int) -> Tuple[int, int, int, int, str]:
    """Shrink input H/W until M=OH*OW fits IBUF; return (h,w,oh,ow,note)."""
    h, w = in_h, in_w
    oh, ow = out_hw(h, w, meta)
    m = oh * ow
    if ibuf_fits_dcim_matmul(meta, m):
        return h, w, oh, ow, 'network'
    max_m = max_matmul_m_for_ibuf(meta)
    while m > max_m and (h > 1 or w > 1):
        h = max(1, (h + 1) // 2)
        w = max(1, (w + 1) // 2)
        oh, ow = out_hw(h, w, meta)
        m = oh * ow
    if not ibuf_fits_dcim_matmul(meta, m):
        raise AssertionError(
            f'{meta.name}: cannot fit DCIM matmul in IBUF even at 1x1 input '
            f'(M={m} acc_depth={meta.acc_depth} weight_bytes={dcim_ibuf_weight_bytes(meta)})'
        )
    return h, w, oh, ow, 'scaled'


def build_dcim_matmul_cases(network: dict) -> List[dict]:
    """All dcim_matmul variants: curated smoke tests + one per conv from network.json."""
    shapes = propagate_conv_im2col_shapes(network)
    cases: List[dict] = []
    seen_names: set = set()
    for spec in DCIM_MATMUL_CURATED:
        cases.append(spec)
        seen_names.add(spec['name'])
    for layer_name in shapes:
        auto_name = f'dcim_{layer_name.replace(".", "_")}'
        if auto_name in seen_names:
            continue
        cases.append({'name': auto_name, 'layer': layer_name, 'from_network': True})
        seen_names.add(auto_name)
    return cases


def module_cases(module: str, network_path: str) -> List[dict]:
    if module == 'dcim_matmul':
        return build_dcim_matmul_cases(load_network_file(network_path))
    return MODULE_CASES[module]


def file_sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def load_layer_npz_checked(meta: ConvMeta, net: Dict[str, dict], require_activation: bool = False) -> np.lib.npyio.NpzFile:
    if meta.name not in net:
        raise AssertionError(f'{meta.name}: missing from network.json')
    ly = net[meta.name]
    if not os.path.isfile(meta.npz_path):
        raise AssertionError(f'{meta.name}: missing weight npz {meta.npz_path}')
    d = np.load(meta.npz_path)
    # act_scale / act_zero_point 只在 has_activation=True 的层（即非 head 输出层）有保证
    always_required = {'weight_int8', 'dqa_scale', 'dqa_bias'}
    activation_keys = {'act_scale', 'act_zero_point'}
    required = always_required | (activation_keys if require_activation else set())
    missing = required.difference(d.files)
    if missing:
        raise AssertionError(f'{meta.name}: missing npz keys {sorted(missing)}')
    expected_weight_shape = tuple(ly['weight_shape'])
    if tuple(d['weight_int8'].shape) != expected_weight_shape:
        raise AssertionError(f'{meta.name}: weight_int8 shape {d["weight_int8"].shape} != network {expected_weight_shape}')
    if expected_weight_shape != (ly['out_channels'], ly['in_channels'], ly['kernel_h'], ly['kernel_w']):
        raise AssertionError(f'{meta.name}: inconsistent network weight_shape {expected_weight_shape}')
    if d['weight_int8'].dtype != np.int8:
        raise AssertionError(f'{meta.name}: weight_int8 dtype {d["weight_int8"].dtype} != int8')
    if d['dqa_scale'].shape[0] != ly['out_channels'] or d['dqa_bias'].shape[0] != ly['out_channels']:
        raise AssertionError(f'{meta.name}: dqa scale/bias length must equal out_channels={ly["out_channels"]}')
    if 'act_zero_point' in d.files and float(d['act_zero_point']) != float(ly.get('act_zero_point', 0.0)):
        raise AssertionError(f'{meta.name}: act_zero_point npz={float(d["act_zero_point"])} network={ly.get("act_zero_point")}')
    if 'act_scale' in ly and 'act_scale' in d.files and not np.isclose(float(d['act_scale']), float(ly['act_scale']), rtol=1e-6, atol=1e-9):
        raise AssertionError(f'{meta.name}: act_scale npz={float(d["act_scale"])} network={ly["act_scale"]}')
    if require_activation and not ly.get('has_activation', False):
        raise AssertionError(f'{meta.name}: DQA_RELU requested but network has_activation=false')
    return d


def layer_fingerprint(meta: ConvMeta) -> str:
    return file_sha256(meta.npz_path)[:16]


def ceil_div(a: int, b: int) -> int:
    return (a + b - 1) // b


def out_hw(h: int, w: int, meta: ConvMeta) -> Tuple[int, int]:
    oh = (h + meta.pad_h0 + meta.pad_h1 - meta.kh) // meta.stride_h + 1
    ow = (w + meta.pad_w0 + meta.pad_w1 - meta.kw) // meta.stride_w + 1
    return oh, ow


def write_hex(path: str, lines: Iterable[str]) -> None:
    with open(path, 'w') as f:
        for line in lines:
            f.write(line + '\n')


def bytes_to_128_words(blob: bytes) -> List[str]:
    blob = blob + b'\x00' * ((-len(blob)) % OBUF_WORD_BYTES)
    return [''.join(f'{b:02x}' for b in reversed(blob[i:i + OBUF_WORD_BYTES])) for i in range(0, len(blob), OBUF_WORD_BYTES)]


def int32_to_words(arr: np.ndarray) -> List[str]:
    blob = b''.join(struct.pack('<i', int(v)) for v in arr.astype(np.int32).flatten())
    return bytes_to_128_words(blob)


def pack_128b_nibbles_to_int(nibbles: np.ndarray) -> int:
    assert nibbles.shape == (BYTES_PER_WORD * 2,), nibbles.shape
    entry = 0
    for idx, n in enumerate(nibbles):
        entry |= (int(n) & 0xF) << (idx * 4)
    return entry


def fp32_to_words(arr: np.ndarray) -> List[str]:
    blob = b''.join(struct.pack('<f', float(v)) for v in arr.astype(np.float32).flatten())
    return bytes_to_128_words(blob)


def int8_hwc_words(arr: np.ndarray, align_ch: int = 16) -> List[str]:
    h, w, c = arr.shape
    c_aligned = ceil_div(c, align_ch) * align_ch
    blob = bytearray(h * w * c_aligned)
    for y in range(h):
        for x in range(w):
            base = (y * w + x) * c_aligned
            for ch in range(c):
                blob[base + ch] = int(arr[y, x, ch]) & 0xFF
    return bytes_to_128_words(bytes(blob))


def int8_hwc_words_packed(arr: np.ndarray) -> List[str]:
    """NHWC 紧凑布局（每像素 CH_IN 字节），与 im2col_unit 输入寻址一致。"""
    return bytes_to_128_words(arr.astype(np.int8).tobytes())


def fp32_hwc_words(arr: np.ndarray) -> List[str]:
    h, w, c = arr.shape
    assert c % 4 == 0, 'FP32 HWC channel count must align to 4 lanes for 128-bit OBUF words'
    blob = b''.join(struct.pack('<f', float(v)) for v in arr.astype(np.float32).flatten())
    return bytes_to_128_words(blob)


def int16_hwc_words(arr: np.ndarray) -> List[str]:
    h, w, c = arr.shape
    assert c % 4 == 0, 'INT16 HWC channel count should align to 4 lanes for VPU QA'
    blob = arr.astype(np.int16).tobytes()
    return bytes_to_128_words(blob)


def im2col(feat: np.ndarray, meta: ConvMeta) -> np.ndarray:
    """INT8 im2col：每行 acc_depth×16 字节"""
    h, w, c = feat.shape
    oh, ow = out_hw(h, w, meta)
    cols = meta.acc_depth * DCIM_CH_IN
    out = np.zeros((oh * ow, cols), dtype=np.int8)
    for oy in range(oh):
        for ox in range(ow):
            dst = oy * ow + ox
            k = 0
            for ky in range(meta.kh):
                iy = oy * meta.stride + ky - meta.pad
                for kx in range(meta.kw):
                    ix = ox * meta.stride + kx - meta.pad
                    for ch in range(c):
                        if 0 <= iy < h and 0 <= ix < w:
                            out[dst, k] = feat[iy, ix, ch]
                        k += 1
    return out


def im2col_int16(feat: np.ndarray, meta: ConvMeta) -> np.ndarray:
    """INT16 im2col：每行 acc_depth_int16×16 个 INT16 元素（每步 CH_IN=16 个 INT16）
    每 acc step = 2 IBUF words（lo: ch0..7 INT16，hi: ch8..15 INT16）= 16 个 INT16。
    布局：连续行 K=acc_depth×16 列，dtype int16，激活值 sign-extend INT8→INT16。"""
    h, w, c = feat.shape
    oh, ow = out_hw(h, w, meta)
    acc = meta.acc_depth_int16          # = ceil(K / 16)
    cols = acc * DCIM_CH_IN             # = acc * 16（每步 16 个 INT16）
    out = np.zeros((oh * ow, cols), dtype=np.int16)
    for oy in range(oh):
        for ox in range(ow):
            dst = oy * ow + ox
            k = 0
            for ky in range(meta.kh):
                iy = oy * meta.stride + ky - meta.pad
                for kx in range(meta.kw):
                    ix = ox * meta.stride + kx - meta.pad
                    for ch in range(c):
                        if 0 <= iy < h and 0 <= ix < w:
                            out[dst, k] = int(feat[iy, ix, ch])  # sign-extend int8→int16
                        k += 1
    return out


# ============================================================================
# INT16 权重打包辅助
# ============================================================================
DCIM_LOGICAL_OUT_PER_TILE = DCIM_INT16_OUT_CH_PER_TILE  # INT16 每 tile 的逻辑输出通道数 = CH_OUT/4


def pack_weight_tile_int16(w16: np.ndarray, tile: int, acc_depth: int) -> List[int]:
    """将 INT16 权重打包为 SRAM nibble 格式（INT16 模式专用）。

    每个逻辑 INT16 输出通道由 4 个 physical output lane 的 nibble 拼成：
    lane 4i+0/1/2/3 分别保存 bits[3:0]/[7:4]/[11:8]/[15:12]。
    每个 acc step 覆盖 DCIM_CH_IN 个 K 维，输出 acc_depth * DCIM_CYCLE 个 128-bit word。
    """
    K = w16.shape[1]
    assert K == acc_depth * DCIM_CH_IN, f"w16 K={K} != acc_depth*DCIM_CH_IN={acc_depth * DCIM_CH_IN}"
    assert w16.shape[0] == DCIM_LOGICAL_OUT_PER_TILE, (
        f"w16 rows={w16.shape[0]} != DCIM_LOGICAL_OUT_PER_TILE={DCIM_LOGICAL_OUT_PER_TILE}"
    )

    entries = []
    for ad in range(acc_depth):
        nibble = np.zeros((DCIM_CH_IN, DCIM_CH_OUT), dtype=np.int32)
        for k_rel in range(DCIM_CH_IN):
            k_abs = ad * DCIM_CH_IN + k_rel
            for log_oc in range(DCIM_LOGICAL_OUT_PER_TILE):
                w_val = int(w16[log_oc, k_abs])
                nibble[k_rel][log_oc * 4 + 0] = (w_val >> 0) & 0xF
                nibble[k_rel][log_oc * 4 + 1] = (w_val >> 4) & 0xF
                nibble[k_rel][log_oc * 4 + 2] = (w_val >> 8) & 0xF
                nibble[k_rel][log_oc * 4 + 3] = (w_val >> 12) & 0xF
        for word_idx in range(DCIM_CYCLE):
            flat_start = word_idx * BYTES_PER_WORD * 2
            word_nibbles = []
            for flat_idx in range(flat_start, flat_start + BYTES_PER_WORD * 2):
                phys_out = flat_idx // DCIM_CH_IN
                in_ch = flat_idx % DCIM_CH_IN
                word_nibbles.append(nibble[in_ch][phys_out])
            entries.append(pack_128b_nibbles_to_int(np.array(word_nibbles, dtype=np.uint8)))
    return entries


def pack_weight_entry(weights_16: np.ndarray) -> int:
    low = 0
    high = 0
    for c in range(DCIM_CH_IN):
        wb = int(weights_16[c]) & 0xFF
        low |= (wb & 0xF) << (c * 4)
        high |= ((wb >> 4) & 0xF) << (c * 4)
    return (high << 64) | low


def pack_weight_tile(meta: ConvMeta, weight_int8: np.ndarray, tile: int,
                     int16: bool = False) -> List[int]:
    """打包单个 Tile 的 INT8 权重到 IBUF SRAM word 格式。"""
    ch_base = tile * DCIM_INT8_OUT_CH_PER_TILE
    flat = weight_int8.reshape(meta.out_ch, -1)
    acc = meta.acc_depth_int16 if int16 else meta.acc_depth
    pad_to = acc * DCIM_CH_IN
    if flat.shape[1] < pad_to:
        flat = np.pad(flat, ((0, 0), (0, pad_to - flat.shape[1])), constant_values=0)
    entries = []
    nibbles_per_word = BYTES_PER_WORD * 2
    for ad in range(acc):
        nibble_stream = np.zeros(DCIM_CH_IN * DCIM_CH_OUT, dtype=np.uint8)
        for phys_out in range(DCIM_CH_OUT):
            oc = ch_base + (phys_out // 2)
            if oc < meta.out_ch:
                row = flat[oc, ad * DCIM_CH_IN:(ad + 1) * DCIM_CH_IN]
            else:
                row = np.zeros(DCIM_CH_IN, dtype=np.int8)
            if phys_out & 1:
                vals = (row.astype(np.int16) >> 4) & 0xF
            else:
                vals = row.astype(np.int16) & 0xF
            base = phys_out * DCIM_CH_IN
            nibble_stream[base:base + DCIM_CH_IN] = vals.astype(np.uint8)
        for word_idx in range(0, len(nibble_stream), nibbles_per_word):
            entries.append(pack_128b_nibbles_to_int(nibble_stream[word_idx:word_idx + nibbles_per_word]))
    return entries



def dcim_accum_words(accum: np.ndarray, num_tiles: int) -> List[str]:
    """INT8 模式：每 tile 输出 DCIM_INT8_OUT_WORDS_PER_TILE 个 128-bit word。"""
    lines = []
    for px in range(accum.shape[0]):
        for tile in range(num_tiles):
            base = tile * DCIM_INT8_OUT_CH_PER_TILE
            for word_idx in range(DCIM_INT8_OUT_WORDS_PER_TILE):
                blob = b''
                for c in range(4):
                    oc = base + word_idx * 4 + c
                    blob += struct.pack('<i', int(accum[px, oc]) if oc < accum.shape[1] else 0)
                lines.append(''.join(f'{b:02x}' for b in reversed(blob)))
    return lines


def dcim_accum_words_int16(accum: np.ndarray, num_tiles: int) -> List[str]:
    """INT16 模式：每 tile 输出 DCIM_INT16_OUT_WORDS_PER_TILE 个 128-bit word。
    accum shape: (M, num_tiles * DCIM_LOGICAL_OUT_PER_TILE)，每 tile 4 个逻辑输出通道。"""
    lines = []
    for px in range(accum.shape[0]):
        for tile in range(num_tiles):
            base = tile * DCIM_LOGICAL_OUT_PER_TILE   # 每 tile 4 个逻辑 oc
            for word_idx in range(DCIM_INT16_OUT_WORDS_PER_TILE):
                blob = b''
                for c in range(4):
                    oc = base + word_idx * 4 + c
                    blob += struct.pack('<i', int(accum[px, oc]) if oc < accum.shape[1] else 0)
                lines.append(''.join(f'{b:02x}' for b in reversed(blob)))
    return lines


def hbm_blob(regions: Sequence[Tuple[int, bytes]]) -> bytes:
    size = max((off + len(data) for off, data in regions), default=0)
    blob = bytearray(size)
    for off, data in regions:
        blob[off:off + len(data)] = data
    return bytes(blob)


def words_to_blob(words: Sequence[str]) -> bytes:
    data = bytearray()
    for word in words:
        val = int(word, 16)
        for b in range(OBUF_WORD_BYTES):
            data.append((val >> (8 * b)) & 0xFF)
    return bytes(data)


def wb_blob(regions: Sequence[Tuple[int, bytes]]) -> bytes:
    blob = bytearray(WB_SIZE_BYTES)
    for off, data in regions:
        blob[off:off + len(data)] = data
    return bytes(blob)


def fp32_blob(arr: np.ndarray) -> bytes:
    return b''.join(struct.pack('<f', float(v)) for v in arr.astype(np.float32).flatten())


def header(op: int, flags: int, length: int) -> int:
    return ((op & 0xF) << 28) | ((flags & 0xF) << 24) | (length & 0xFFFFFF)


def split64(addr: int) -> Tuple[int, int]:
    return (addr >> 32) & 0xFFFFFFFF, addr & 0xFFFFFFFF


def cdma_copy(src: int, dst: int, nbytes: int) -> List[int]:
    sm, sl = split64(src)
    dm, dl = split64(dst)
    return [header(OP_CDMA_COPY, 0, 20), sm, sl, dm, dl, nbytes & 0xFFFFFFFF, header(OP_WAIT_CDMA, 0, 0)]


def vpu_exec(unit: int, src: int, src2: int, c: int, h: int, w: int, bias: int, scale: int, dst: int,
             addr_break: int = 0, addr_s: int = 0, addr_t: int = 0, flags: int = 0) -> List[int]:
    body = [unit, src, src2, c, h, w, bias, scale, dst, addr_break, addr_s, addr_t]
    return [header(OP_VPU_EXEC, flags, 48)] + body + [header(OP_WAIT_VPU, 0, 0)]


def dcim_cfg(pairs: Sequence[Tuple[int, int]]) -> List[int]:
    body = []
    for a, d in pairs:
        body += [a & 0xFFFFFFFF, d & 0xFFFFFFFF]
    return [header(OP_DCIM_CFG, 0, len(pairs))] + body


def dcim_layer_op(num_pixels: int, mode_reg: int, tile_mask: int, act_base_word: int,
                  act_stride_words: int, out_stride_words: int,
                  wei_base_words: Sequence[int], out_base_words: Sequence[int]) -> List[int]:
    assert len(wei_base_words) == NUM_TILES
    assert len(out_base_words) == NUM_TILES
    tile_mask_lo = tile_mask & 0xFFFFFFFF
    tile_mask_hi = (tile_mask >> 32) & 0xFFFFFFFF
    body = [
        num_pixels,
        mode_reg,
        tile_mask_lo,
        tile_mask_hi,
        act_base_word,
        act_stride_words,
        out_stride_words,
        0,
    ] + list(wei_base_words) + list(out_base_words)
    return [header(OP_DCIM_LAYER, 0, len(body) * 4)] + [w & 0xFFFFFFFF for w in body]


def write_inst(path: str, words: Sequence[int]) -> None:
    write_hex(path, [f'{w & 0xFFFFFFFF:08x}' for w in words])


def make_fast_svh(fast_loads: List[Tuple[str, int]], out_dir: str) -> None:
    """Write legacy SVH plus runtime preload list.

    The current testbench consumes preload.txt at simulation runtime so the same
    compiled simv can run different generated cases.  The SVH is kept as a
    compatibility artifact for old build directories and manual inspection.
    """
    max_entries = 4
    lines = ['// Auto-generated fast preload — do not edit',
             f'localparam integer NUM_FAST_LOADS = {len(fast_loads)};']
    for i in range(max_entries):
        if i < len(fast_loads):
            fname, addr = fast_loads[i]
            lines.append(f'localparam string FAST_FNAME_{i} = "{fname}";')
            lines.append(f'localparam logic [63:0] FAST_BASE_{i} = 64\'h{addr:013x};')
        else:
            lines.append(f'localparam string FAST_FNAME_{i} = "";')
            lines.append(f'localparam logic [63:0] FAST_BASE_{i} = 64\'h0;')
    with open(os.path.join(out_dir, 'fast_preload.svh'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    with open(os.path.join(out_dir, 'preload.txt'), 'w') as f:
        for fname, addr in fast_loads:
            f.write(f'{fname} {addr:016x}\n')



def dcim_layer_inst(meta: ConvMeta, num_pixels: int, im2col_obuf: int, dcim_out_obuf: int,
                    ibuf_act: int, ibuf_wei: int, skip_cdma: bool = False,
                    int16: bool = False) -> List[int]:
    """生成 DCIM 指令序列。
    int16=True 时：
      - mode = MODE_INT16，acc_depth = acc_depth_int16
      - 每像素 ACT_BASE 步进 acc_depth_int16 * INT16_ACT_WORDS
      - 每像素每 tile 输出 DCIM_INT16_OUT_WORDS_PER_TILE 个 128-bit word
    """
    inst = []
    acc = meta.acc_depth_int16 if int16 else meta.acc_depth
    act_words_per_row = DCIM_INT16_ACT_WORDS if int16 else DCIM_INT8_ACT_WORDS
    im2col_bytes = num_pixels * acc * OBUF_WORD_BYTES * act_words_per_row
    if not skip_cdma:
        inst += cdma_copy(OBUF_PHY_BASE + im2col_obuf, IBUF_PHY_BASE + ibuf_act, im2col_bytes)
    mode_val = MODE_INT16 if int16 else MODE_INT8
    mode_reg = ((acc & 0xFF) << 8) | mode_val
    tiles_out = meta.num_tiles
    words_per_tile_per_px = DCIM_INT16_OUT_WORDS_PER_TILE if int16 else DCIM_INT8_OUT_WORDS_PER_TILE
    wei_base_words = [
        (ibuf_wei // IBUF_WORD_BYTES) + t * acc * DCIM_CYCLE
        for t in range(NUM_TILES)
    ]
    out_base_words = [
        (dcim_out_obuf // OBUF_WORD_BYTES) + t * words_per_tile_per_px if t < tiles_out else 0
        for t in range(NUM_TILES)
    ]
    inst += dcim_layer_op(
        num_pixels=num_pixels,
        mode_reg=mode_reg,
        tile_mask=(1 << tiles_out) - 1,
        act_base_word=ibuf_act // IBUF_WORD_BYTES,
        act_stride_words=acc * act_words_per_row,
        out_stride_words=tiles_out * words_per_tile_per_px,
        wei_base_words=wei_base_words,
        out_base_words=out_base_words,
    )
    inst += [header(OP_NOP, 0, 0)] * 16
    return inst


def encode_addr_break(meta: ConvMeta) -> int:
    return (
        ((meta.kh & 0xFF) << 24) | ((meta.kw & 0xFF) << 16)
        | ((meta.stride_h & 0xF) << 12) | ((meta.stride_w & 0xF) << 8)
        | ((meta.pad_h0 & 0xF) << 4) | (meta.pad_w0 & 0xF)
    )


def random_int8(rng: np.random.Generator, shape: Tuple[int, ...]) -> np.ndarray:
    return rng.integers(-128, 128, size=shape, dtype=np.int16).astype(np.int8)


def random_fp32(rng: np.random.Generator, shape: Tuple[int, ...], scale: float = 3.0) -> np.ndarray:
    return rng.normal(0.0, scale, size=shape).astype(np.float32)


def maxpool_generic(x: np.ndarray, kernel: int, stride: int, pad: int) -> np.ndarray:
    """通用 MaxPool (same-like padding)，支持 kernel/stride/pad。"""
    h, w, c = x.shape
    oh = (h + 2 * pad - kernel) // stride + 1
    ow = (w + 2 * pad - kernel) // stride + 1
    y = np.full((oh, ow, c), -np.inf, dtype=np.float32)
    for oy in range(oh):
        for ox in range(ow):
            vals = []
            for ky in range(kernel):
                iy = oy * stride + ky - pad
                for kx in range(kernel):
                    ix = ox * stride + kx - pad
                    if 0 <= iy < h and 0 <= ix < w:
                        vals.append(x[iy, ix, :])
            if vals:
                y[oy, ox, :] = np.maximum.reduce(vals)
    return y


def maxpool5_same(x: np.ndarray) -> np.ndarray:
    h, w, c = x.shape
    y = np.empty_like(x)
    for oy in range(h):
        for ox in range(w):
            vals = []
            for ky in range(-2, 3):
                iy = oy + ky
                for kx in range(-2, 3):
                    ix = ox + kx
                    if 0 <= iy < h and 0 <= ix < w:
                        vals.append(x[iy, ix, :])
            y[oy, ox, :] = np.maximum.reduce(vals)
    return y


def upsample2(x: np.ndarray) -> np.ndarray:
    return np.repeat(np.repeat(x, 2, axis=0), 2, axis=1).astype(np.float32)


def resolve_dcim_in_hw(spec: dict, shapes: Dict[str, ConvIm2colShape], meta: ConvMeta) -> Tuple[int, int, int, int, str]:
    if 'in_hw' in spec:
        h, w = spec['in_hw']
        oh, ow = out_hw(h, w, meta)
        note = 'manual'
        if not ibuf_fits_dcim_matmul(meta, oh * ow):
            h, w, oh, ow, note = scale_in_hw_to_fit_ibuf(meta, h, w)
        return h, w, oh, ow, note
    if spec.get('from_network') or 'in_hw' not in spec:
        shape = shapes[spec['layer']]
        return scale_in_hw_to_fit_ibuf(meta, shape.in_h, shape.in_w)
    raise AssertionError(f'{spec["name"]}: missing in_hw or from_network')


def make_dcim_case(out_dir: str, net: Dict[str, dict], spec: dict, rng: np.random.Generator,
                   shapes: Dict[str, ConvIm2colShape]) -> dict:
    use_int16 = spec.get('int16', False)
    meta = conv_meta(net, spec['layer'])
    if 'synthetic_out_ch' in spec:
        meta.out_ch = min(NUM_TILES * DCIM_INT8_OUT_CH_PER_TILE, int(spec['synthetic_out_ch']))
    h, w, oh, ow, hw_note = resolve_dcim_in_hw(spec, shapes, meta)
    matmul_m = oh * ow
    weights = load_layer_npz_checked(meta, net)['weight_int8']
    if 'synthetic_out_ch' in spec:
        weights = rng.integers(-8, 8, size=(meta.out_ch, meta.in_ch, meta.kh, meta.kw), dtype=np.int16).astype(np.int8)
    elif 'out_ch_limit' in spec:
        meta.out_ch = min(meta.out_ch, int(spec['out_ch_limit']))
        weights = weights[:meta.out_ch]

    feat = random_int8(rng, (h, w, meta.in_ch))

    if use_int16:
        acc = meta.acc_depth_int16
        cols16 = im2col_int16(feat, meta)   # shape (M, acc*8), dtype int16
        assert cols16.shape == (matmul_m, acc * DCIM_CH_IN), \
            f"cols16 shape {cols16.shape} != ({matmul_m}, {acc * DCIM_CH_IN})"
        # 逻辑输出通道数 = num_tiles × 4（INT16 每 tile 4 个逻辑 ch）
        num_logical_oc = meta.num_tiles * DCIM_LOGICAL_OUT_PER_TILE
        K = acc * DCIM_CH_IN  # = acc_depth_int16 * 16

        # 生成随机 INT16 权重（不用网络真实权重，因为 INT16 模式 4 nibble = 1 INT16 weight）
        # 范围限制在 -2048..2047（12-bit），避免 INT32 累加溢出（256 k_dim × 32767² 不溢出）
        w16 = rng.integers(-2048, 2048, size=(num_logical_oc, K), dtype=np.int32).astype(np.int16)

        # golden matmul: int16 act × int16 weight → int32（截取低 32 bit）
        # accum[px, oc_logical] = sum_k cols16[px, k] * w16[oc_logical, k]  (INT32 trunc)
        accum = (cols16.astype(np.int64) @ w16.astype(np.int64).T).astype(np.int32)
        assert accum.shape == (matmul_m, num_logical_oc)

        # INT16 act IBUF 打包：每 word 8 个 int16（little-endian）
        act_words = bytes_to_128_words(cols16.astype(np.int16).tobytes())
        exp_words = dcim_accum_words_int16(accum, meta.num_tiles)
        write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
        fast_inst = dcim_layer_inst(meta, matmul_m, 0, OBUF_DST, IBUF_ACT, IBUF_WEI,
                                    skip_cdma=True, int16=True)
        mode_tag = 'int16'
        acc_info = acc

        # 权重打包：每个 tile 独立的 INT16 权重
        weight_words = []
        for t in range(meta.num_tiles):
            tile_w16 = w16[t * DCIM_LOGICAL_OUT_PER_TILE:(t + 1) * DCIM_LOGICAL_OUT_PER_TILE]
            weight_words += [f'{e:032x}' for e in pack_weight_tile_int16(tile_w16, t, acc)]
    else:
        acc = meta.acc_depth
        num_logical_oc = meta.out_ch  # INT8 模式：实际物理输出通道数
        cols = im2col(feat, meta)
        assert cols.shape == (matmul_m, acc * DCIM_CH_IN)
        wflat = weights.reshape(meta.out_ch, -1).astype(np.int32)
        if wflat.shape[1] < acc * DCIM_CH_IN:
            wflat = np.pad(wflat, ((0, 0), (0, acc * DCIM_CH_IN - wflat.shape[1])), constant_values=0)
        accum = cols.astype(np.int32) @ wflat.T
        assert accum.shape == (matmul_m, meta.out_ch)
        act_words = bytes_to_128_words(cols.astype(np.int8).tobytes())
        exp_words = dcim_accum_words(accum, meta.num_tiles)
        write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
        fast_inst = dcim_layer_inst(meta, matmul_m, 0, OBUF_DST, IBUF_ACT, IBUF_WEI, skip_cdma=True)
        mode_tag = 'int8'
        acc_info = acc
        weight_words = []
        for t in range(meta.num_tiles):
            weight_words += [f'{e:032x}' for e in pack_weight_tile(meta, weights, t)]

    fast_inst += [header(OP_END, 0, 0)]

    write_hex(os.path.join(out_dir, 'act.hex'), act_words)
    write_hex(os.path.join(out_dir, 'weight.hex'), weight_words)
    fast_loads = [
        ('act.hex', IBUF_PHY_BASE + IBUF_ACT),
        ('weight.hex', IBUF_PHY_BASE + IBUF_WEI),
    ]
    make_fast_svh(fast_loads, out_dir)

    hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(act_words)), (HBM_OFF_WEIGHT, words_to_blob(weight_words))])
    net_shape = shapes.get(spec['layer'])
    matmul_n = num_logical_oc if use_int16 else meta.out_ch
    return {
        'module': 'dcim_matmul', 'name': spec['name'], 'layer': meta.name, 'dst': OBUF_DST,
        'words': len(exp_words), 'fast_inst': fast_inst,
        'hbm': hbm, 'wb': bytes(WB_SIZE_BYTES),
        'matmul_m': matmul_m, 'matmul_k': meta.matmul_k, 'matmul_n': matmul_n,
        'acc_depth': acc_info, 'in_hw': f'{h}x{w}', 'in_hw_note': hw_note,
        'network_in_hw': (
            f'{net_shape.in_h}x{net_shape.in_w}' if net_shape is not None else 'n/a'
        ),
        'shape': (
            f'[{mode_tag}] M={matmul_m} K={meta.matmul_k} N={matmul_n} acc_depth={acc_info} '
            f'in_hw={h}x{w}({hw_note})'
        ),
    }


def make_im2col_case(out_dir: str, net: Dict[str, dict], spec: dict, rng: np.random.Generator) -> dict:
    meta = conv_meta(net, spec['layer'])
    h, w = spec['in_hw']
    oh, ow = out_hw(h, w, meta)
    feat = random_int8(rng, (h, w, meta.in_ch))
    cols = im2col(feat, meta)
    src_words = int8_hwc_words(feat)
    exp_words = bytes_to_128_words(cols.astype(np.int8).tobytes())
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    fast_inst = vpu_exec(UNIT_IM2COL, OBUF_SRC0, 0, meta.in_ch, h, w, 0, 0, OBUF_DST,
                         encode_addr_break(meta), oh, ow)
    fast_inst += [header(OP_END, 0, 0)]
    fast_loads = [('src0.hex', OBUF_PHY_BASE + OBUF_SRC0)]
    make_fast_svh(fast_loads, out_dir)
    return {'module': 'im2col', 'name': spec['name'], 'layer': meta.name, 'dst': OBUF_DST, 'words': len(exp_words),
            'fast_inst': fast_inst, 'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words))]),
            'wb': bytes(WB_SIZE_BYTES),
            'shape': f'{h}x{w}x{meta.in_ch} k={meta.kh} s={meta.stride} p={meta.pad} -> rows={oh * ow} acc_depth={meta.acc_depth}'}


def make_conv_pipeline_case(out_dir: str, net: Dict[str, dict], spec: dict, rng: np.random.Generator) -> dict:
    meta = conv_meta(net, spec['layer'])
    h, w = spec['in_hw']
    oh, ow = out_hw(h, w, meta)
    use_int16: bool = spec.get('int16', False)
    npz = load_layer_npz_checked(meta, net, require_activation=True)
    weights = npz['weight_int8']
    scale = npz['dqa_scale'].astype(np.float32)
    bias = npz['dqa_bias'].astype(np.float32)
    if 'out_ch_limit' in spec:
        meta.out_ch = min(meta.out_ch, int(spec['out_ch_limit']))
        weights = weights[:meta.out_ch]
        scale = scale[:meta.out_ch]
        bias = bias[:meta.out_ch]
    qscale = np.float32(1.0 / float(npz['act_scale']))
    feat = random_int8(rng, (h, w, meta.in_ch))
    if use_int16:
        # DCIM INT16 mode: im2col output is INT16 layout
        cols16 = im2col_int16(feat, meta)
        acc = meta.acc_depth_int16
        K = acc * DCIM_CH_IN
        num_logical_oc = meta.num_tiles * DCIM_LOGICAL_OUT_PER_TILE
        w16 = rng.integers(-2048, 2048, size=(num_logical_oc, K), dtype=np.int32).astype(np.int16)
        # Golden: int16 act × int16 weight → int32 → DQA(fp32) → QA(int16)
        accum16 = (cols16.astype(np.int64) @ w16.astype(np.int64).T).astype(np.int32)
        dqa = np.maximum(accum16.astype(np.float32) * scale[:num_logical_oc][None, :] + bias[:num_logical_oc][None, :], 0.0)
        qa = np.clip(np.round(dqa * qscale), -32768, 32767).astype(np.int16).reshape(oh, ow, num_logical_oc)
        exp_words = int16_hwc_words(qa.reshape(1, 1, oh * ow * num_logical_oc))
        weight_words = []
        for t in range(meta.num_tiles):
            tile_w16 = w16[t * DCIM_LOGICAL_OUT_PER_TILE:(t + 1) * DCIM_LOGICAL_OUT_PER_TILE]
            weight_words += [f'{e:032x}' for e in pack_weight_tile_int16(tile_w16, t, acc)]
        src_words = bytes_to_128_words(feat.astype(np.int16).tobytes())
        # INT16 im2col 需要 2× INT8 的 OBUF_AUX 空间；在 suite 中前 case 可能只写了一半，
        # 须用全零清空整个 AUX 区，避免残留数据影响后半段激活搬运结果
        im2col_aux_bytes = oh * ow * acc * DCIM_CH_IN * 2
        aux_zero_words = bytes_to_128_words(bytes(im2col_aux_bytes))
        write_hex(os.path.join(out_dir, 'aux_zero.hex'), aux_zero_words)
        write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
        write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
        write_hex(os.path.join(out_dir, 'weight.hex'), weight_words)
        # Instructions: im2col(INT16) → DCIM(INT16) → DQA(INT32 accum→fp32) → QA(fp32→int16)
        # DCIM MODE_INT16 still writes 32-bit logical-channel accumulators; DQA int16 mode is only for synthetic INT16 accumulator inputs.
        fast_inst = vpu_exec(UNIT_IM2COL, OBUF_SRC0, 0, meta.in_ch, h, w, 0, 0, OBUF_AUX,
                             encode_addr_break(meta), oh, ow, flags=0x2)
        fast_inst += dcim_layer_inst(meta, oh * ow, OBUF_AUX, OBUF_SRC1, IBUF_ACT, IBUF_WEI, int16=True)
        fast_inst += vpu_exec(UNIT_DQA, OBUF_SRC1, 0, num_logical_oc, oh, ow, WB_BIAS, WB_SCALE, OBUF_AUX, flags=0x1)
        fast_inst += vpu_exec(UNIT_QA, OBUF_AUX, 0, num_logical_oc, oh, ow, 0, WB_QSCALE, OBUF_DST, flags=0x2)
        fast_inst += [header(OP_END, 0, 0)]
        make_fast_svh([('src0.hex', OBUF_PHY_BASE + OBUF_SRC0),
                       ('aux_zero.hex', OBUF_PHY_BASE + OBUF_AUX),
                       ('weight.hex', IBUF_PHY_BASE + IBUF_WEI)], out_dir)
        wb = wb_blob([(WB_SCALE, fp32_blob(scale[:num_logical_oc])), (WB_BIAS, fp32_blob(bias[:num_logical_oc])),
                      (WB_QSCALE, fp32_blob(np.array([qscale], dtype=np.float32)))])
        hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words)), (HBM_OFF_WEIGHT, words_to_blob(weight_words))])
        return {'module': 'conv_pipeline', 'name': spec['name'], 'layer': meta.name, 'dst': OBUF_DST, 'words': len(exp_words),
                'fast_inst': fast_inst, 'hbm': hbm, 'wb': wb,
                'shape': f'{h}x{w}x{meta.in_ch} -> {oh}x{ow}x{num_logical_oc} INT16 acc={acc} tiles={meta.num_tiles}'}
    # INT8 path (original)
    cols = im2col(feat, meta)
    wflat = weights.reshape(meta.out_ch, -1).astype(np.int32)
    if wflat.shape[1] < meta.acc_depth * DCIM_CH_IN:
        wflat = np.pad(wflat, ((0, 0), (0, meta.acc_depth * DCIM_CH_IN - wflat.shape[1])), constant_values=0)
    accum = cols.astype(np.int32) @ wflat.T
    dqa = np.maximum(accum.astype(np.float32) * scale[None, :] + bias[None, :], 0.0)
    qa = np.clip(np.round(dqa * qscale), -128, 127).astype(np.int8).reshape(oh, ow, meta.out_ch)
    src_words = int8_hwc_words(feat)
    exp_words = int8_hwc_words(qa)
    weight_words = []
    for t in range(meta.num_tiles):
        weight_words += [f'{e:032x}' for e in pack_weight_tile(meta, weights, t)]
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    write_hex(os.path.join(out_dir, 'weight.hex'), weight_words)
    fast_inst = vpu_exec(UNIT_IM2COL, OBUF_SRC0, 0, meta.in_ch, h, w, 0, 0, OBUF_AUX,
                         encode_addr_break(meta), oh, ow)
    fast_inst += dcim_layer_inst(meta, oh * ow, OBUF_AUX, OBUF_SRC1, IBUF_ACT, IBUF_WEI)
    fast_inst += vpu_exec(UNIT_DQA, OBUF_SRC1, 0, meta.out_ch, oh, ow, WB_BIAS, WB_SCALE, OBUF_AUX, flags=0x1)
    fast_inst += vpu_exec(UNIT_QA, OBUF_AUX, 0, meta.out_ch, oh, ow, 0, WB_QSCALE, OBUF_DST)
    fast_inst += [header(OP_END, 0, 0)]
    fast_loads = [
        ('src0.hex', OBUF_PHY_BASE + OBUF_SRC0),
        ('weight.hex', IBUF_PHY_BASE + IBUF_WEI),
    ]
    make_fast_svh(fast_loads, out_dir)
    hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words)), (HBM_OFF_WEIGHT, words_to_blob(weight_words))])
    wb = wb_blob([(WB_SCALE, fp32_blob(scale)), (WB_BIAS, fp32_blob(bias)), (WB_QSCALE, fp32_blob(np.array([qscale], dtype=np.float32)))])
    return {'module': 'conv_pipeline', 'name': spec['name'], 'layer': meta.name, 'dst': OBUF_DST, 'words': len(exp_words),
            'fast_inst': fast_inst, 'hbm': hbm, 'wb': wb,
            'shape': f'{h}x{w}x{meta.in_ch} -> {oh}x{ow}x{meta.out_ch} acc_depth={meta.acc_depth} tiles={meta.num_tiles}'}


def make_concat_by_cdma_case(out_dir: str, spec: dict, rng: np.random.Generator) -> dict:
    h, w = spec['hw']
    channels = spec['channels']
    src_offsets = [OBUF_SRC0, OBUF_SRC1, OBUF_AUX, 0x400000]
    hbm_offsets = [HBM_OFF_INPUT0, HBM_OFF_INPUT1, HBM_OFF_WEIGHT, 0xC0000]
    arrays = [random_int8(rng, (h, w, c)) for c in channels]
    out = np.concatenate(arrays, axis=2)
    exp_words = int8_hwc_words(out)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    for i, arr in enumerate(arrays):
        write_hex(os.path.join(out_dir, f'src{i}.hex'), int8_hwc_words(arr))
    fast_inst = []
    dst_c = sum(channels)
    dst_pixel_stride = ceil_div(dst_c, 16) * 16
    for px in range(h * w):
        ch_base = 0
        for i, c in enumerate(channels):
            src_pixel_stride = ceil_div(c, 16) * 16
            src = OBUF_PHY_BASE + src_offsets[i] + px * src_pixel_stride
            dst = OBUF_PHY_BASE + OBUF_DST + px * dst_pixel_stride + ch_base
            fast_inst += cdma_copy(src, dst, c)
            ch_base += c
    fast_inst += [header(OP_END, 0, 0)]
    fast_loads = [(f'src{i}.hex', OBUF_PHY_BASE + src_offsets[i]) for i in range(len(arrays))]
    make_fast_svh(fast_loads, out_dir)
    hbm_regions = []
    for i, arr in enumerate(arrays):
        words = int8_hwc_words(arr)
        hbm_regions.append((hbm_offsets[i], words_to_blob(words)))
    return {'module': 'concat_by_cdma', 'name': spec['name'], 'layer': 'cdma_concat', 'dst': OBUF_DST, 'words': len(exp_words),
            'fast_inst': fast_inst, 'hbm': hbm_blob(hbm_regions), 'wb': bytes(WB_SIZE_BYTES),
            'shape': f'hw={h}x{w} channels={channels} -> {dst_c}'}


def make_dqa_case(out_dir: str, net: Dict[str, dict], spec: dict, rng: np.random.Generator) -> dict:
    meta = conv_meta(net, spec['layer'])
    h, w, c = spec['hwc']
    relu_en: bool = spec.get('relu_en', True)
    use_int16: bool = spec.get('int16', False)
    npz = load_layer_npz_checked(meta, net, require_activation=relu_en)
    scale = np.resize(npz['dqa_scale'].astype(np.float32), c)
    bias = np.resize(npz['dqa_bias'].astype(np.float32), c)
    if use_int16:
        # INT16 accumulator: DQA 读 INT16 word 并 sign-extend → INT32 → FP32
        x_int16 = rng.integers(-8192, 8192, size=(h * w, c), dtype=np.int32).astype(np.int16)
        x = x_int16.astype(np.int32)
        src_words = int16_accum_to_words(x_int16, c)
    else:
        x = rng.integers(-5000, 5001, size=(h * w, c), dtype=np.int32)
        src_words = int32_to_words(x)
    acc = x.astype(np.float32) * scale[None, :] + bias[None, :]
    y = np.maximum(acc, 0.0) if relu_en else acc
    write_hex(os.path.join(out_dir, 'expected.hex'), fp32_to_words(y))
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    relu_flag = 0x1 if relu_en else 0x0
    int16_flag = 0x2 if use_int16 else 0x0
    flags = relu_flag | int16_flag
    fast_inst = vpu_exec(UNIT_DQA, OBUF_SRC0, 0, c, h, w, WB_BIAS, WB_SCALE, OBUF_DST, flags=flags)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + OBUF_SRC0)], out_dir)
    wb = wb_blob([(WB_SCALE, fp32_blob(scale)), (WB_BIAS, fp32_blob(bias))])
    return {'module': 'dqa', 'name': spec['name'], 'layer': meta.name, 'dst': OBUF_DST,
            'words': len(fp32_to_words(y)), 'fast_inst': fast_inst,
            'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words))]),
            'wb': wb, 'shape': f'hwc={h}x{w}x{c} relu_en={relu_en} int16={use_int16}',
            'relu_en': relu_en}


def int16_accum_to_words(arr_int16: np.ndarray, c: int) -> List[str]:
    """将 INT16 accumulator 数组打包为 128-bit OBUF words（HWC 排列，每 word 8 个 INT16）。
    arr_int16: shape (h*w, c), dtype int16
    INT16 模式 DQA 从 OBUF 读 INT16，布局与 int8_hwc_words 同构，但步长为 2B。
    对齐到 8 个 INT16 / word（= 128-bit）。
    """
    n, cols = arr_int16.shape
    assert cols == c
    align8 = ((c + 7) // 8) * 8
    padded = np.zeros((n, align8), dtype=np.int16)
    padded[:, :c] = arr_int16
    return bytes_to_128_words(padded.tobytes())


def make_qa_case(out_dir: str, net: Dict[str, dict], spec: dict, rng: np.random.Generator) -> dict:
    meta = conv_meta(net, spec['layer'])
    h, w, c = spec['hwc']
    use_int16 = spec.get('int16', False)
    act_scale = float(load_layer_npz_checked(meta, net)['act_scale'])
    qscale = np.float32(1.0 / act_scale)
    x = random_fp32(rng, (h * w, c), scale=2.0 / max(qscale, 1.0))
    x.flat[::7] *= 40.0
    src_words = fp32_to_words(x)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    flags = 0x2 if use_int16 else 0x0
    fast_inst = vpu_exec(UNIT_QA, OBUF_SRC0, 0, c, h, w, 0, WB_QSCALE, OBUF_DST, flags=flags)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + OBUF_SRC0)], out_dir)
    wb = wb_blob([(WB_QSCALE, fp32_blob(np.array([qscale], dtype=np.float32)))])
    if use_int16:
        y = np.clip(np.round(x * qscale), -32768, 32767).astype(np.int16).reshape(h * w, c)
        exp_words = int16_hwc_words(y.reshape(1, 1, h * w * c))
    else:
        y = np.clip(np.round(x * qscale), -128, 127).astype(np.int8).reshape(h, w, c)
        exp_words = int8_hwc_words(y)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    return {'module': 'qa', 'name': spec['name'], 'layer': meta.name, 'dst': OBUF_DST,
            'words': len(exp_words), 'fast_inst': fast_inst,
            'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words))]),
            'wb': wb, 'shape': f'hwc={h}x{w}x{c} out_int16={use_int16}'}


def make_us_case(out_dir: str, spec: dict, rng: np.random.Generator) -> dict:
    h, w, c = spec['hwc']
    x = random_fp32(rng, (h, w, c))
    y = upsample2(x)
    src_words = fp32_hwc_words(x)
    exp_words = fp32_hwc_words(y)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    fast_inst = vpu_exec(UNIT_US, OBUF_SRC0, 0, c, h, w, 0, 0, OBUF_DST)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + OBUF_SRC0)], out_dir)
    return {'module': 'us', 'name': spec['name'], 'layer': spec['source'], 'dst': OBUF_DST,
            'words': len(exp_words), 'fast_inst': fast_inst,
            'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words))]),
            'wb': bytes(WB_SIZE_BYTES), 'shape': f'{h}x{w}x{c}-> {h*2}x{w*2}x{c}'}


def make_mp_case(out_dir: str, spec: dict, rng: np.random.Generator) -> dict:
    h, w, c = spec['hwc']
    cfg = spec.get('cfg', 0)
    x = random_fp32(rng, (h, w, c))
    if cfg == 0:
        y = maxpool_generic(x, kernel=5, stride=1, pad=2)   # SPPF 5×5 s1 p2
        mode_name = 'maxpool5x5s1p2'
    elif cfg == 1:
        y = maxpool_generic(x, kernel=3, stride=2, pad=1)   # ResNet stem 3×3 s2 p1
        mode_name = 'maxpool3x3s2p1'
    elif cfg == 2:
        # GAP: output SUM (hardware outputs sum, host divides by H*W)
        y_sum = x.sum(axis=(0, 1), keepdims=True).astype(np.float32)
        y = y_sum  # shape (1, 1, C)
        mode_name = 'gap_sum'
    else:
        y = maxpool_generic(x, kernel=5, stride=1, pad=2)
        mode_name = 'maxpool5x5s1p2'
    # encode addr_break[1:0] = cfg into instruction
    addr_break_cfg = int(cfg) & 0x3
    src_words = fp32_hwc_words(x) if cfg in (0, 1) else fp32_hwc_words(x)
    exp_words = fp32_hwc_words(y)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    fast_inst = vpu_exec(UNIT_MP, OBUF_SRC0, 0, c, h, w, 0, 0, OBUF_DST, addr_break_cfg)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + OBUF_SRC0)], out_dir)
    return {'module': 'mp', 'name': spec['name'], 'layer': spec['source'], 'dst': OBUF_DST,
            'words': len(exp_words), 'fast_inst': fast_inst,
            'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words))]),
            'wb': bytes(WB_SIZE_BYTES),
            'shape': f'{mode_name} hwc={h}x{w}x{c}->{y.shape[0]}x{y.shape[1]}x{c}'}


def make_add_case(out_dir: str, spec: dict, rng: np.random.Generator) -> dict:
    h, w, c = spec['hwc']
    a = random_fp32(rng, (h, w, c))
    b = random_fp32(rng, (h, w, c))
    y = (a + b).astype(np.float32)
    a_words = fp32_hwc_words(a)
    b_words = fp32_hwc_words(b)
    exp_words = fp32_hwc_words(y)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), a_words)
    write_hex(os.path.join(out_dir, 'src1.hex'), b_words)
    fast_inst = vpu_exec(UNIT_AD, OBUF_SRC0, OBUF_SRC1, c, h, w, 0, 0, OBUF_DST)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + OBUF_SRC0), ('src1.hex', OBUF_PHY_BASE + OBUF_SRC1)], out_dir)
    return {'module': 'add', 'name': spec['name'], 'layer': spec['source'], 'dst': OBUF_DST,
            'words': len(exp_words), 'fast_inst': fast_inst,
            'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(a_words)), (HBM_OFF_INPUT1, words_to_blob(b_words))]),
            'wb': bytes(WB_SIZE_BYTES), 'shape': f'hwc={h}x{w}x{c}'}


def make_mini_network_case(out_dir: str, net: Dict[str, dict], spec: dict, rng: np.random.Generator) -> dict:
    """Multi-layer network test: chain conv layers with optional residual add.
    Supports QUANT=int8 (default) and QUANT=int16 via spec['int16'].
    INT16: DCIM INT16, DQA accum16→fp32, QA fp32→int16.
    All layers use the same quant mode within one mini_network test.

    OBUF slot plan (each 1MB region, OBUF total 16MB):
      SLOT_A = 0x000000  input feature (INT8)
      SLOT_B = 0x100000  layer 0 QA output / layer 1 input (INT8 or INT16)
      SLOT_C = 0x200000  DCIM accumulator scratch / final output
      SLOT_D = 0x300000  im2col scratch / DQA scratch
      SLOT_E = 0x400000  layer 0 DQA output (FP32, saved for residual add)
      SLOT_F = 0x500000  layer 1 DQA output (FP32, saved for residual add)
    """
    layer_specs = spec['layers']
    has_residual = spec.get('residual_add', False)
    num_layers = len(layer_specs)
    use_int16: bool = spec.get('int16', False)
    # flags for instructions
    _dqa_flags = 0x3 if use_int16 else 0x1  # bit0=relu, bit1=int16_mode
    _qa_flags  = 0x2 if use_int16 else 0x0   # bit1=int16_mode
    _im2col_flags = 0x2 if use_int16 else 0x0  # bit1=int16_mode

    WB_LAYER_STRIDE = 0x100   # 256 bytes per layer (fits up to 64 channels × 4B)
    WB_BIAS_BASE = 0x1000
    WB_QSCALE_BASE = 0x2000

    SLOT_A = 0x000000
    SLOT_B = 0x100000
    SLOT_C = 0x200000
    SLOT_D = 0x300000
    SLOT_E = 0x400000
    SLOT_F = 0x500000

    # --- Load per-layer conv metadata ---
    metas = []
    for ls in layer_specs:
        m = conv_meta(net, ls['layer'])
        m = ConvMeta(m.name, ls['in_ch'], ls['out_ch'],
                     m.kh, m.kw, m.stride_h, m.stride_w,
                     m.pad_h0, m.pad_w0, m.pad_h1, m.pad_w1, m.npz_path)
        metas.append(m)

    h0, w0 = layer_specs[0]['in_hw']

    # --- Golden computation + WB/weight packing ---
    feat = random_int8(rng, (h0, w0, metas[0].in_ch))
    current_int8 = feat.copy()
    wb_data = bytearray(WB_SIZE_BYTES)
    all_weight_words: List[str] = []
    ibuf_weight_offsets: List[int] = []
    layer_dqa_fp32 = []   # FP32 DQA outputs (for residual)
    layer_oh_ow = []      # output h,w per layer
    ibuf_byte_cursor = 0

    cur_h, cur_w = h0, w0
    layer_qscales: List[np.float32] = []
    for i, meta in enumerate(metas):
        npz = load_layer_npz_checked(meta, net, require_activation=True)
        weights = npz['weight_int8'].astype(np.int8)
        scale = np.resize(npz['dqa_scale'].astype(np.float32), meta.out_ch)
        bias = np.resize(npz['dqa_bias'].astype(np.float32), meta.out_ch)
        qscale = np.float32(1.0 / float(npz['act_scale']))
        layer_qscales.append(qscale)

        # WB packing
        s_off = WB_LAYER_STRIDE * i
        b_off = WB_BIAS_BASE + WB_LAYER_STRIDE * i
        q_off = WB_QSCALE_BASE + 4 * i
        wb_data[s_off:s_off + len(scale.tobytes())] = scale.tobytes()
        wb_data[b_off:b_off + len(bias.tobytes())] = bias.tobytes()
        wb_data[q_off:q_off + 4] = qscale.tobytes()

        # Golden: im2col → matmul → DQA/ReLU
        oh = (cur_h + meta.pad_h0 + meta.pad_h1 - meta.kh) // meta.stride_h + 1
        ow = (cur_w + meta.pad_w0 + meta.pad_w1 - meta.kw) // meta.stride_w + 1
        cols = im2col(current_int8.reshape(cur_h, cur_w, meta.in_ch), meta)
        wflat = weights.reshape(meta.out_ch, -1).astype(np.int32)
        k_size = meta.acc_depth * DCIM_CH_IN
        if wflat.shape[1] < k_size:
            wflat = np.pad(wflat, ((0, 0), (0, k_size - wflat.shape[1])), constant_values=0)
        accum = cols.astype(np.int32) @ wflat.T
        dqa = np.maximum(accum.astype(np.float32) * scale[None, :] + bias[None, :], 0.0)
        layer_dqa_fp32.append(dqa)
        qa_out_dtype = np.int16 if use_int16 else np.int8
        qa_clip = (-32768, 32767) if use_int16 else (-128, 127)
        qa = np.clip(np.round(dqa * qscale), qa_clip[0], qa_clip[1]).astype(qa_out_dtype).reshape(oh, ow, meta.out_ch)
        current_int8 = qa.astype(np.int8)  # next layer still reads INT8 feature (re-quant)
        layer_oh_ow.append((oh, ow))
        cur_h, cur_w = oh, ow

        # Weight packing for IBUF
        ibuf_weight_offsets.append(ibuf_byte_cursor)
        tile_words = []
        for t in range(meta.num_tiles):
            tile_words += [f'{e:032x}' for e in pack_weight_tile(meta, weights, t)]
        all_weight_words += tile_words
        ibuf_byte_cursor += len(tile_words) * IBUF_WORD_BYTES

    # --- Compute final expected output ---
    if has_residual and num_layers >= 2:
        fp32_sum = (layer_dqa_fp32[0] + layer_dqa_fp32[1]).astype(np.float32)
        qscale_final = layer_qscales[-1]
        oh_f, ow_f = layer_oh_ow[1]
        qa_clip = (-32768, 32767) if use_int16 else (-128, 127)
        qa_out_dtype = np.int16 if use_int16 else np.int8
        final = np.clip(np.round(fp32_sum * qscale_final), qa_clip[0], qa_clip[1]).astype(qa_out_dtype)
        final = final.reshape(oh_f, ow_f, metas[1].out_ch)
        if use_int16:
            exp_words = int16_hwc_words(final.reshape(1, 1, oh_f * ow_f * metas[1].out_ch))
        else:
            exp_words = int8_hwc_words(final)
        final_dst = SLOT_C
    else:
        if use_int16:
            exp_words = int16_hwc_words(current_int8.astype(np.int16).reshape(1, 1, -1))
        else:
            exp_words = int8_hwc_words(current_int8)
        final_dst = SLOT_C

    # --- Build instruction stream ---
    fast_inst: List[int] = []

    for i, meta in enumerate(metas):
        oh_i, ow_i = layer_oh_ow[i]
        lh = h0 if i == 0 else layer_oh_ow[i - 1][0]
        lw = w0 if i == 0 else layer_oh_ow[i - 1][1]

        src_slot = SLOT_A if i == 0 else SLOT_B
        ibuf_wei_off = IBUF_WEI + ibuf_weight_offsets[i]
        wb_s = WB_LAYER_STRIDE * i
        wb_b = WB_BIAS_BASE + WB_LAYER_STRIDE * i
        wb_q = WB_QSCALE_BASE + 4 * i

        # im2col: src → SLOT_D
        fast_inst += vpu_exec(UNIT_IM2COL, src_slot, 0, meta.in_ch, lh, lw,
                              0, 0, SLOT_D, encode_addr_break(meta), oh_i, ow_i, flags=_im2col_flags)
        # DCIM: SLOT_D(→IBUF via CDMA) × weight → SLOT_C
        fast_inst += dcim_layer_inst(meta, oh_i * ow_i, SLOT_D, SLOT_C,
                                     IBUF_ACT, ibuf_wei_off, int16=use_int16)

        if has_residual:
            # DQA/ReLU: SLOT_C → SLOT_E (layer 0) or SLOT_F (layer 1)
            dqa_dst = SLOT_E if i == 0 else SLOT_F
            fast_inst += vpu_exec(UNIT_DQA, SLOT_C, 0, meta.out_ch, oh_i, ow_i,
                                  wb_b, wb_s, dqa_dst, flags=_dqa_flags)
            if i < num_layers - 1:
                # QA: dqa_dst → SLOT_B (feed next layer)
                fast_inst += vpu_exec(UNIT_QA, dqa_dst, 0, meta.out_ch, oh_i, ow_i,
                                      0, wb_q, SLOT_B, flags=_qa_flags)
        else:
            # DQA/ReLU: SLOT_C → SLOT_D
            fast_inst += vpu_exec(UNIT_DQA, SLOT_C, 0, meta.out_ch, oh_i, ow_i,
                                  wb_b, wb_s, SLOT_D, flags=_dqa_flags)
            if i < num_layers - 1:
                # QA: SLOT_D → SLOT_B (feed next layer)
                fast_inst += vpu_exec(UNIT_QA, SLOT_D, 0, meta.out_ch, oh_i, ow_i,
                                      0, wb_q, SLOT_B, flags=_qa_flags)
            else:
                # Last layer QA: SLOT_D → final_dst
                fast_inst += vpu_exec(UNIT_QA, SLOT_D, 0, meta.out_ch, oh_i, ow_i,
                                      0, wb_q, final_dst, flags=_qa_flags)

    if has_residual:
        # ADD: SLOT_E + SLOT_F → SLOT_D
        oh_f, ow_f = layer_oh_ow[-1]
        out_ch = metas[-1].out_ch
        fast_inst += vpu_exec(UNIT_AD, SLOT_E, SLOT_F, out_ch, oh_f, ow_f,
                              0, 0, SLOT_D)
        # Final QA: SLOT_D → SLOT_C
        wb_q_final = WB_QSCALE_BASE + 4 * (num_layers - 1)
        fast_inst += vpu_exec(UNIT_QA, SLOT_D, 0, out_ch, oh_f, ow_f,
                              0, wb_q_final, final_dst, flags=_qa_flags)

    fast_inst += [header(OP_END, 0, 0)]

    # --- Write output files ---
    src_words = int8_hwc_words(feat)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    write_hex(os.path.join(out_dir, 'weight.hex'), all_weight_words)
    fast_loads = [
        ('src0.hex', OBUF_PHY_BASE + SLOT_A),
        ('weight.hex', IBUF_PHY_BASE + IBUF_WEI),
    ]
    make_fast_svh(fast_loads, out_dir)
    hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words)),
                     (HBM_OFF_WEIGHT, words_to_blob(all_weight_words))])

    total_shape = ' → '.join(f'{ls["in_ch"]}→{ls["out_ch"]}' for ls in layer_specs)
    return {'module': 'mini_network', 'name': spec['name'],
            'layer': metas[0].name, 'dst': final_dst,
            'words': len(exp_words), 'fast_inst': fast_inst,
            'hbm': hbm, 'wb': bytes(wb_data),
            'shape': f'{num_layers}-layer {total_shape} residual={has_residual} int16={use_int16}'}



def module_needs_wb(module: str) -> bool:
    """Only DQA/QA/conv_pipeline/mini_network read scale/bias from WB."""
    return module in ('dqa', 'qa', 'conv_pipeline', 'mini_network')


def write_manifest(out_dir: str, meta: dict, verify_words: int) -> None:
    check_words = meta['words'] if verify_words == 0 else min(meta['words'], verify_words)
    is_fp32 = 1 if meta['module'] in ('dqa', 'us', 'mp', 'add') else 0
    lines = [
        '// Auto-generated by golden_module_tb.py — do not edit',
        f'localparam string MODULE_TB_MODULE = "{meta["module"]}";',
        f'localparam string MODULE_TB_CASE = "{meta["name"]}";',
        f'localparam string MODULE_TB_LAYER = "{meta["layer"]}";',
        f'localparam integer MODULE_TB_EXPECT_WORDS = {meta["words"]};',
        f'localparam integer MODULE_TB_CHECK_WORDS = {check_words};',
        f'localparam logic [23:0] MODULE_TB_DST_OBUF = 24\'h{meta["dst"]:06x};',
        f'localparam integer MODULE_TB_IS_FP32 = {is_fp32};',
        f'localparam integer MODULE_TB_IS_DQA_RELU = {1 if (meta["module"] == "conv_pipeline" or (meta["module"] == "dqa" and meta.get("relu_en", True))) else 0};',
        f'localparam integer MODULE_TB_LOAD_WB = {1 if module_needs_wb(meta["module"]) else 0};',
    ]
    if meta['module'] == 'dcim_matmul':
        lines += [
            f'localparam integer MODULE_TB_MATMUL_M = {meta["matmul_m"]};',
            f'localparam integer MODULE_TB_MATMUL_K = {meta["matmul_k"]};',
            f'localparam integer MODULE_TB_MATMUL_N = {meta["matmul_n"]};',
            f'localparam integer MODULE_TB_ACC_DEPTH = {meta["acc_depth"]};',
        ]
    with open(os.path.join(out_dir, 'module_manifest.svh'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    with open(os.path.join(out_dir, 'checks.txt'), 'w') as f:
        f.write(f'{meta["name"]} expected.hex {meta["dst"]:06x} {check_words} {is_fp32}\n')
    with open(os.path.join(out_dir, 'manifest.txt'), 'w') as f:
        for k in ('module', 'name', 'layer', 'shape', 'words'):
            f.write(f'{k}: {meta[k]}\n')
        if meta['module'] == 'dcim_matmul':
            for k in ('matmul_m', 'matmul_k', 'matmul_n', 'acc_depth', 'in_hw', 'in_hw_note', 'network_in_hw'):
                f.write(f'{k}: {meta[k]}\n')
        if meta.get('layer') not in ('cdma_concat', ''):
            f.write(f'weight_npz_sha256_16: {meta.get("npz_sha256_16", "unknown")}\n')
            f.write('golden_numeric_semantics: network.json + parsed/weights npz; DQA_RELU=max(accum*scale+bias,0); QA=round(x/act_scale) clamp int8\n')
        f.write(f'check_words: {check_words}\n')
        f.write('runtime_files: inst.hex preload.txt checks.txt\n')


def _apply_dim_overrides(spec: dict, args: argparse.Namespace, module: str) -> dict:
    """Apply --quant and --dim overrides to a case spec (returns modified copy)."""
    spec = dict(spec)

    # dcim_matmul 的精度由 case 名/spec 决定，避免出现 extreme_int16..._qint8 这类矛盾命名。
    if module != 'dcim_matmul':
        if args.quant == 'int16':
            spec['int16'] = True
        elif args.quant == 'int8':
            spec.pop('int16', None)
            spec['int16'] = False

    # dim override: format "C=N" or "H=N,W=N,C=N" or "HW=HxW"
    if args.dim:
        for part in args.dim.split(','):
            part = part.strip()
            if not part:
                continue
            key, _, val = part.partition('=')
            key = key.strip().upper()
            val = val.strip()
            if key == 'C':
                if 'hwc' in spec:
                    h, w, _ = spec['hwc']
                    spec['hwc'] = (h, w, int(val))
                elif 'channels' in spec:
                    spec['channels'] = [int(val)] * len(spec['channels'])
            elif key == 'H':
                if 'hwc' in spec:
                    _, w, c = spec['hwc']
                    spec['hwc'] = (int(val), w, c)
                elif 'in_hw' in spec:
                    _, w = spec['in_hw']
                    spec['in_hw'] = (int(val), w)
                elif 'hw' in spec:
                    _, w = spec['hw']
                    spec['hw'] = (int(val), w)
            elif key == 'W':
                if 'hwc' in spec:
                    h, _, c = spec['hwc']
                    spec['hwc'] = (h, int(val), c)
                elif 'in_hw' in spec:
                    h, _ = spec['in_hw']
                    spec['in_hw'] = (h, int(val))
                elif 'hw' in spec:
                    h, _ = spec['hw']
                    spec['hw'] = (h, int(val))
            elif key == 'HW':
                hw_h, hw_w = (int(v) for v in val.lower().split('x'))
                if 'hwc' in spec:
                    _, _, c = spec['hwc']
                    spec['hwc'] = (hw_h, hw_w, c)
                elif 'in_hw' in spec:
                    spec['in_hw'] = (hw_h, hw_w)
                elif 'hw' in spec:
                    spec['hw'] = (hw_h, hw_w)
    return spec


def generate(args: argparse.Namespace) -> None:
    net = load_network(args.network_json)
    network = load_network_file(args.network_json)
    im2col_shapes = propagate_conv_im2col_shapes(network)
    module = args.module
    cases = module_cases(module, args.network_json)
    if args.case == 'list':
        for c in cases:
            extra = ''
            if module == 'dcim_matmul' and c.get('from_network'):
                s = im2col_shapes[c['layer']]
                extra = f'  M={s.matmul_m} K={s.matmul_k} N={s.matmul_n} acc={s.acc_depth} in={s.in_h}x{s.in_w}'
            print(f"{c['name']}{extra}")
        return
    spec = next((c for c in cases if c['name'] == args.case), cases[0] if args.case == 'default' else None)
    if spec is None:
        raise SystemExit(f'Unknown case {args.case!r} for module {module}; use --case list')

    # apply --quant and --dim overrides
    spec = _apply_dim_overrides(spec, args, module)

    out_dir = args.out_dir
    os.makedirs(out_dir, exist_ok=True)
    rng = np.random.default_rng(args.seed)
    effective_module = spec.get('module', module)
    if effective_module == 'dcim_matmul':
        meta = make_dcim_case(out_dir, net, spec, rng, im2col_shapes)
    elif effective_module == 'im2col':
        meta = make_im2col_case(out_dir, net, spec, rng)
    elif effective_module == 'conv_pipeline':
        meta = make_conv_pipeline_case(out_dir, net, spec, rng)
    elif effective_module == 'concat_by_cdma':
        meta = make_concat_by_cdma_case(out_dir, spec, rng)
    elif effective_module == 'dqa':
        meta = make_dqa_case(out_dir, net, spec, rng)
    elif effective_module == 'qa':
        meta = make_qa_case(out_dir, net, spec, rng)
    elif effective_module == 'us':
        meta = make_us_case(out_dir, spec, rng)
    elif effective_module == 'mp':
        meta = make_mp_case(out_dir, spec, rng)
    elif effective_module == 'add':
        meta = make_add_case(out_dir, spec, rng)
    elif effective_module == 'mini_network':
        meta = make_mini_network_case(out_dir, net, spec, rng)
    else:
        raise AssertionError(effective_module)

    if meta['layer'] != 'cdma_concat':
        meta['npz_sha256_16'] = layer_fingerprint(conv_meta(net, meta['layer']))
    write_hex(os.path.join(out_dir, 'hbm_image.hex'), bytes_to_128_words(meta['hbm']))
    write_hex(os.path.join(out_dir, 'wb_init.hex'), bytes_to_128_words(meta['wb']))
    if module_needs_wb(meta['module']):
        with open(os.path.join(out_dir, 'preload.txt'), 'a') as f:
            f.write(f'wb_init.hex {0x1020_0000_0:016x}\n')
    write_inst(os.path.join(out_dir, 'inst.hex'), meta['fast_inst'])
    write_manifest(out_dir, meta, args.verify_words)
    print(f'Generated module_tb: module={meta["module"]} case={meta["name"]} layer={meta["layer"]}')
    print(f'  shape={meta["shape"]} words={meta["words"]} out_dir={out_dir}')


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument('--module', choices=sorted(MODULE_CASES.keys()), required=True)
    p.add_argument('--case', default='default', help='case name, "default", or "list"')
    p.add_argument('--seed', type=int, default=123)
    p.add_argument('--verify-words', type=int, default=256, help='0 means compare all expected words')
    p.add_argument('--network-json', default=NETWORK_JSON)
    p.add_argument('--out-dir', default=os.path.join(os.path.dirname(__file__), 'build'))
    p.add_argument('--quant', choices=['int8', 'int16'], default='int8',
                   help='int8（默认）或 int16；覆盖 case spec 中的 int16 标志')
    p.add_argument('--dim', default='',
                   help='维度覆盖，格式：C=N 或 H=N,W=N,C=N 或 HW=HxW,C=N；不指定则用 case 默认值')
    args = p.parse_args()
    generate(args)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
