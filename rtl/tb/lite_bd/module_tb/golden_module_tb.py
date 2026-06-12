#!/usr/bin/env python3
from __future__ import annotations

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
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

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

# vpu_buf read pipeline depth（与 chip_defines.vh `VPU_BUF_RD_LATENCY` 保持一致）
# 在两个连续 vpu_exec 之间插入这么多 NOP，避免上一个 unit 的 douta_valid 残留污染下一个 unit
VPU_BUF_RD_LATENCY = 10

NETWORK_JSON = os.path.join(REPO_ROOT, 'model', 'yolov5n', 'parsed', 'network.json')
WEIGHT_DIR = os.path.join(REPO_ROOT, 'model', 'yolov5n', 'parsed', 'weights')
RESNET18_NETWORK_JSON = os.path.join(REPO_ROOT, 'model', 'resnet18', 'parsed_qdq', 'network.json')
RESNET18_WEIGHT_DIR = os.path.join(REPO_ROOT, 'model', 'resnet18', 'parsed_qdq', 'weights')

OBUF_WORD_BYTES = BYTES_PER_WORD
IBUF_WORD_BYTES = BYTES_PER_WORD
WB_SIZE_BYTES = 0x8000
NUM_TILES = DCIM_NUM_TILES
DCIM_CH_IN_INT16 = DCIM_CH_IN // 2


def dcim_effective_out_ch(meta: 'ConvMeta', int16: bool = False) -> int:
    """Actual number of channels DCIM writes per pixel (rounded UP to tile boundary).

    DCIM_Tile always writes INT8_OUT_CH_PER_TILE (=32) channels per tile regardless
    of meta.out_ch.  When meta.out_ch < num_tiles * INT8_OUT_CH_PER_TILE (e.g. CH_OUT=16
    with 1 tile = 32 effective channels), DQA/QA must use this larger count for correct
    per-pixel addressing; the extra channels (out_ch:eff_ch) receive zero weight/bias from
    WB (zero-initialised) so produce exactly INT8(0) after QA — safe to pass to next layer.
    """
    if int16:
        return meta.num_tiles * DCIM_INT16_OUT_CH_PER_TILE
    return meta.num_tiles * DCIM_INT8_OUT_CH_PER_TILE

HBM_PHY_BASE = 0x0
OBUF_PHY_BASE = 0x1020_0000_0   # chip-v3 XPM: VPU_BUF 8MB @ 0x1_0200_0000

# Per-tile IBUF architecture: 4 tile_ibufs, 512KB each
NUM_TILE_IBUFS = 4
TILE_IBUF_SIZE_BYTES = 0x80_000   # 512KB per tile
TILE_IBUF_PHY_BASES = [
    0x1_0000_0000,  # tile_ibuf[0]
    0x1_0008_0000,  # tile_ibuf[1]
    0x1_0010_0000,  # tile_ibuf[2]
    0x1_0018_0000,  # tile_ibuf[3]
]
IBUF_PHY_BASE = TILE_IBUF_PHY_BASES[0]  # backward compat (tile 0 base)
IBUF_SIZE_BYTES = TILE_IBUF_SIZE_BYTES   # per-tile capacity (not total!)

# Per-tile OBUF architecture: 4 tile_obufs, 256KB each
# DCIM 把 INT32 accumulator 结果写到各自的 tile_obuf（与 VPU_BUF 物理独立）
NUM_TILE_OBUFS = 4
TILE_OBUF_SIZE_BYTES = 0x40_000  # 256KB per tile
TILE_OBUF_PHY_BASES = [
    0x1_0100_0000,  # tile_obuf[0]
    0x1_0104_0000,  # tile_obuf[1]
    0x1_0108_0000,  # tile_obuf[2]
    0x1_010C_0000,  # tile_obuf[3]
]

# Activation and weight offsets WITHIN each tile_ibuf (512KB split: 256KB act + 256KB wei)
IBUF_ACT = 0x000000            # activation start within each tile_ibuf
IBUF_WEI = 0x040000            # weight start (256KB offset within 512KB)

HBM_OFF_INPUT0 = 0x00000
HBM_OFF_INPUT1 = 0x40000
HBM_OFF_WEIGHT = 0x80000

# ---------------------------------------------------------------------------
# VPU_BUF flat-scratchpad 地址分配
# ---------------------------------------------------------------------------
# 旧版固定 slot 常量保留作为向后兼容别名（mini_network/concat 等仍使用）。
# 新的单算子 make_*_case 函数使用 alloc_flat() 动态计算 src/dst 地址，
# 任意时刻只有一个算子在处理（serial execution），所以全 8MB 都可自由使用。
VPU_BUF_SIZE_BYTES = 1 << 23          # 8MB
OBUF_WORD_ALIGN    = BYTES_PER_WORD   # 16-byte 对齐


def align_up(n: int, align: int = OBUF_WORD_ALIGN) -> int:
    """将 n 向上对齐到 align 字节。"""
    return (n + align - 1) & ~(align - 1)


def alloc_flat(*sizes: int) -> List[int]:
    """在 VPU_BUF 内连续分配多个区域，每个 16-byte 对齐。
    返回各区域起始字节偏移列表（不含 OBUF_PHY_BASE）。

    用法示例：
      src, dst = alloc_flat(src_bytes, dst_bytes)
    """
    offsets: List[int] = []
    cur = 0
    for sz in sizes:
        offsets.append(cur)
        cur += align_up(sz)
    assert cur <= VPU_BUF_SIZE_BYTES, \
        f'alloc_flat overflow: {cur//1024}KB needed > 8MB VPU_BUF'
    return offsets


# 旧版固定 slot（向后兼容，mini_network/concat_by_cdma 仍引用）
OBUF_SRC0 = 0x000000
OBUF_SRC1 = 0x080000    # 512KB apart (enough for unit tests)
OBUF_DST  = 0x100000
OBUF_AUX  = 0x180000
WB_SCALE  = 0x0000
WB_BIAS = 0x1000
WB_QSCALE = 0x2000

# chip-v2: DCIM 输出写 tile_obuf (per-tile, 从 0 开始)，验证时从 tile_obuf 读
# checks.txt 里 dst >= TILE_OBUF_CHK_SENTINEL 时 testbench 路由到 tile_obuf
DCIM_OUT_BASE = 0x0           # tile_obuf 内字节偏移 (从 0 写)
TILE_OBUF_CHK_SENTINEL = 0x800000  # bit23, above all VPU_BUF slot offsets (max ~0x400000)
TILE_OBUF_DST = TILE_OBUF_CHK_SENTINEL + 0x0  # dcim_matmul checks.txt 用此值

# Extra OBUF slots for multi-source tests (concat)
OBUF_SRC2 = 0x200000
OBUF_SRC3 = 0x280000

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
        {'name': 'pipe_conv1_c16_to16',      'layer': 'model.2.m.0.cv1.conv', 'in_hw': (4, 4)},  # CH_OUT=16 → eff_ch=32
        {'name': 'pipe_conv3_s2_c32_to64',   'layer': 'model.3.conv',         'in_hw': (8, 8)},
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
    # ---------------------------------------------------------------------------
    # cdma_memtest：专项验证 IBUF / OBUF controller 读写延迟配置
    #   每个 case 包含：
    #     Step-1  OBUF→IBUF  （验 OBUF 读延迟 + IBUF 写）
    #     Step-2  IBUF→OBUF  （验 IBUF 读延迟 + OBUF 写）
    #     Step-3  OBUF→OBUF  （片内同一 ctrl 不同槽搬运，baseline）
    #   最终 expected 读出 OBUF DST 槽与原始数据比对。
    #   no_layer=True 跳过 npz 依赖；不需要 WB；仅发 CDMA_COPY+WAIT_CDMA 指令。
    # ---------------------------------------------------------------------------
    'cdma_memtest': [
        {'name': 'cdma_obuf_ibuf_obuf_c128',
         'desc': 'OBUF→IBUF→OBUF roundtrip, 128-channel block (2KB), '
                 'verifies ibuf/obuf controller pipeline delay configs',
         'nbytes': 2048,   # 128 words × 16B = 2KB；覆盖 URAM 多-bank 寻址
         'obuf_src': 0x000000, 'ibuf_mid': 0x000000, 'obuf_dst': 0x200000},
        {'name': 'cdma_obuf_ibuf_obuf_1k',
         'desc': 'OBUF→IBUF→OBUF roundtrip, 1K words (16KB), '
                 'intermediate size to detect mid-burst truncation',
         'nbytes': 16384,  # 1024 words × 16B = 16KB
         'obuf_src': 0x000000, 'ibuf_mid': 0x000000, 'obuf_dst': 0x200000,
         'chunked': True},
        {'name': 'cdma_ibuf_read_4k',
         'desc': 'IBUF backdoor preload → CDMA IBUF→OBUF, 4K words (64KB), '
                 'isolates IBUF read latency from OBUF write path',
         'nbytes': 65536,  # 4096 words × 16B = 64KB；穿越 CDMA sub-burst 边界
         'ibuf_preload': True, 'ibuf_mid': 0x000000, 'obuf_dst': 0x200000,
         'chunked': True},
        {'name': 'cdma_obuf_ibuf_obuf_large',
         'desc': 'OBUF→IBUF→OBUF roundtrip, 64KB block, '
                 'stresses ibuf/obuf multi-bank latency boundary',
         'nbytes': 65536,  # 4K words × 16B = 64KB；穿越 bank 边界
         'obuf_src': 0x000000, 'ibuf_mid': 0x000000, 'obuf_dst': 0x200000,
         'chunked': True},
    ],
    'mini_network': [
        {'name': 'mini_2conv_c16',
         'desc': '2-layer Conv1x1 16→16 back-to-back, tests multi-layer OBUF management.'
                 ' Both layers use genuine 1×1 convs (model.2.m.0.cv1.conv for both).'
                 ' NOTE: 3×3 second layer (cv2) is intentionally excluded here because'
                 ' eff_ch propagation with kH*kW > 1 requires CDMA channel-compaction,'
                 ' which is a separate unimplemented feature.',
         'layers': [
             {'layer': 'model.2.m.0.cv1.conv', 'in_hw': (4, 4), 'in_ch': 16, 'out_ch': 16},
             {'layer': 'model.2.m.0.cv1.conv', 'in_hw': (4, 4), 'in_ch': 16, 'out_ch': 16},
         ]},
        {'name': 'mini_3conv_residual_c32',
         'desc': '3-layer: Conv1x1 32→32, Conv1x1 32→32, Add + QA (CSP residual pattern)',
         'layers': [
             {'layer': 'model.4.m.0.cv1.conv', 'in_hw': (4, 4), 'in_ch': 32, 'out_ch': 32},
             {'layer': 'model.4.m.0.cv2.conv', 'in_hw': (4, 4), 'in_ch': 32, 'out_ch': 32},
         ],
         'residual_add': True},
    ],
    # ResNet18 分段（STEP-3）：ResnetSegmentBuilder + 多 checkpoint checks.txt
    # 可选 spec 字段：checkpoint_policy, output_format, num_blocks, weight_dir
    'resnet_partial': [
        {'name': 'resnet_stem_tiny',
         'desc': 'conv1+MP；32×32 输入，module_tb 快速冒烟（约 1–2 分钟）',
         'preset': 'stem', 'in_hw': (32, 32)},
        {'name': 'resnet_stem_smoke',
         'desc': 'conv1+MP；112×112（完整 BD 上 im2col 很慢，可跑数小时，勿与 tiny 并行双开 simv）',
         'preset': 'stem', 'in_hw': (112, 112)},
        {'name': 'resnet_stem_full',
         'desc': 'conv1 + MaxPool，输入 224×224（压力测试，仿真极慢）',
         'preset': 'stem', 'in_hw': (224, 224)},
        {'name': 'resnet_stage1',
         'desc': 'MaxPool 后 56×56×64 输入，layer1 两个 basic block（conv 1–4）+ 残差',
         'preset': 'stage1', 'input_hw': (56, 56), 'input_ch': 64},
        {'name': 'resnet_stage1_2',
         'desc': '56×56×64 输入，layer1+layer2（conv 1–9，含 downsample），最终 28×28×128',
         'preset': 'stage1_2', 'input_hw': (56, 56), 'input_ch': 64},
    ],
}

# ResNet18 conv[] 下标 → basic block（与 lower_full.py 一致）
RESNET_BLOCK_SCHEDULE = [
    ([1, 2], None),
    ([3, 4], None),
    ([5, 6], 7),
    ([8, 9], None),
    ([10, 11], 12),
    ([13, 14], None),
    ([15, 16], 17),
    ([18, 19], None),
]


def write_checks_list(path: str, entries: Sequence[Tuple[str, str, int, int, int]]) -> None:
    """Write checks.txt lines: name fname dst_obuf_hex words is_fp32."""
    with open(path, 'w') as f:
        for name, fname, dst, words, is_fp32 in entries:
            f.write(f'{name} {fname} {dst:06x} {words} {is_fp32}\n')


# ---------------------------------------------------------------------------
# ResNet / 多段网络：通用 OBUF 槽位 + numpy golden + 指令发射
# ---------------------------------------------------------------------------
class ObufSlots:
    """VPU_BUF 多层网络段 ping-pong 槽位（chip-v3: VPU_BUF 8MB）。

    适用于 SegmentBuilder（多层链式网络），需要同时保留多个中间张量。
    单算子 case (make_*_case) 不使用此类，改用 alloc_flat() 动态分配。
    总占用约 3MB，VPU_BUF 8MB 足够容纳。
    """
    FEAT0 = 0x000000
    FEAT1 = 0x080000   # ping-pong 特征
    OUT   = 0x100000   # DCIM 累加输出
    IM2COL= 0x180000   # im2col scratch
    DQA   = 0x200000   # DQA output
    SHORT = 0x280000   # shortcut / residual save


@dataclass
class FeatureTensor:
    """段内逻辑张量；storage 表示 OBUF 上 im2col 前的数据类型。"""
    data: np.ndarray
    storage: str  # 'int8' | 'fp32'
    slot: int

    @property
    def h(self) -> int:
        return int(self.data.shape[0])

    @property
    def w(self) -> int:
        return int(self.data.shape[1])

    @property
    def c(self) -> int:
        return int(self.data.shape[2])

    def nbytes_obuf(self) -> int:
        bpe = 4 if self.storage == 'fp32' else 1
        return self.h * self.w * self.c * bpe

    def fp32_hwc(self) -> np.ndarray:
        return self.data.astype(np.float32, copy=False)

    def with_slot(self, slot: int) -> 'FeatureTensor':
        return FeatureTensor(self.data, self.storage, slot)


def golden_conv_forward(
    feat_hwc: np.ndarray,
    meta: 'ConvMeta',
    npz: np.lib.npyio.NpzFile,
    *,
    im2col_in_ch: Optional[int] = None,
    acc_eff: Optional[int] = None,
) -> Tuple[np.ndarray, np.ndarray]:
    """INT8 im2col → matmul → DQA(ReLU) → QA；返回 (qa_int8_hwc, dqa_fp32_hwc)。"""
    h, w = feat_hwc.shape[0], feat_hwc.shape[1]
    ic = im2col_in_ch if im2col_in_ch is not None else feat_hwc.shape[2]
    feat_i8 = feat_hwc.reshape(h, w, ic).astype(np.int8)
    if acc_eff is None:
        acc_eff = (meta.kh * meta.kw * ic + DCIM_CH_IN - 1) // DCIM_CH_IN

    cols = im2col(feat_i8, meta)
    wflat = npz['weight_int8'].reshape(meta.out_ch, -1).astype(np.int32)
    k_size = acc_eff * DCIM_CH_IN
    if wflat.shape[1] < k_size:
        wflat = np.pad(wflat, ((0, 0), (0, k_size - wflat.shape[1])), constant_values=0)
    accum = cols.astype(np.int32) @ wflat.T

    eff_ch = dcim_effective_out_ch(meta, False)
    scale = np.resize(npz['dqa_scale'].astype(np.float32), eff_ch)
    bias = np.resize(npz['dqa_bias'].astype(np.float32), eff_ch)
    qscale = np.float32(1.0 / float(npz['act_scale']))
    oh, ow = out_hw(h, w, meta)

    dqa_flat = np.maximum(
        accum.astype(np.float32) * scale[None, :eff_ch] + bias[None, :eff_ch], 0.0)
    dqa_hwc = dqa_flat.reshape(oh, ow, eff_ch)

    qa = np.clip(np.round(dqa_flat * qscale), -128, 127).astype(np.int8).reshape(oh, ow, meta.out_ch)
    if eff_ch > meta.out_ch:
        qa_pad = np.zeros((oh, ow, eff_ch), dtype=np.int8)
        qa_pad[:, :, :meta.out_ch] = qa
        qa = qa_pad
    return qa, dqa_hwc


def golden_basic_block(
    x_hwc: np.ndarray,
    metas: Sequence['ConvMeta'],
    npzs: Sequence[np.lib.npyio.NpzFile],
    ds_meta: Optional['ConvMeta'] = None,
    ds_npz: Optional[np.lib.npyio.NpzFile] = None,
) -> Tuple[np.ndarray, Dict[str, np.ndarray]]:
    """ResNet basic block 参考：conv1→conv2 [→ downsample(shortcut)] → FP32 add → INT8 QA。

    残差在 FP32 域相加（与 lower_full emit_add 一致）；INT8 段入口 shortcut 用 fp32(x) 提升。
    """
    skip = x_hwc.copy()
    cur = x_hwc
    ckpt: Dict[str, np.ndarray] = {}
    dqa_main = None

    for i, (meta, npz) in enumerate(zip(metas, npzs)):
        ic = cur.shape[2]
        acc_eff = (meta.kh * meta.kw * ic + DCIM_CH_IN - 1) // DCIM_CH_IN
        cur, dqa = golden_conv_forward(cur, meta, npz, im2col_in_ch=ic, acc_eff=acc_eff)
        ckpt[f'conv{i}_dqa'] = dqa
        dqa_main = dqa

    if ds_meta is not None and ds_npz is not None:
        sic = skip.shape[2]
        acc_ds = (ds_meta.kh * ds_meta.kw * sic + DCIM_CH_IN - 1) // DCIM_CH_IN
        _, dqa_ds = golden_conv_forward(skip, ds_meta, ds_npz, im2col_in_ch=sic, acc_eff=acc_ds)
        ckpt['downsample_dqa'] = dqa_ds
        if dqa_main.shape != dqa_ds.shape:
            raise ValueError(
                f'basic block add shape mismatch main{dqa_main.shape} vs ds{dqa_ds.shape}')
        sum_fp32 = (dqa_main + dqa_ds).astype(np.float32)
    else:
        skip_fp32 = skip.astype(np.float32)
        if dqa_main.shape != skip_fp32.shape:
            raise ValueError(
                f'basic block add shape mismatch main{dqa_main.shape} vs skip{skip_fp32.shape}')
        sum_fp32 = (dqa_main + skip_fp32).astype(np.float32)

    ckpt['block_sum_fp32'] = sum_fp32
    return sum_fp32.astype(np.float32), ckpt


def golden_qa_int8_from_fp32(fp32_hwc: np.ndarray, act_scale: float) -> np.ndarray:
    qscale = np.float32(1.0 / float(act_scale))
    eff_ch = fp32_hwc.shape[2]
    flat = np.clip(np.round(fp32_hwc.reshape(-1, eff_ch) * qscale), -128, 127).astype(np.int8)
    return flat.reshape(fp32_hwc.shape[0], fp32_hwc.shape[1], eff_ch)


@dataclass
class ResnetSegmentBuilder:
    """从 network.json + block 调度生成 inst / preload / 多 checkpoint。"""
    net: Dict[str, dict]
    conv_names: List[str]
    weight_dir: str
    rng: np.random.Generator
    out_dir: str

    fast_inst: List[int] = field(default_factory=list)
    wb_data: bytearray = field(default_factory=lambda: bytearray(WB_SIZE_BYTES))
    all_weight_words_per_tile: List[List[str]] = field(
        default_factory=lambda: [[] for _ in range(NUM_TILES)])
    ibuf_weight_offsets: List[int] = field(default_factory=list)
    ibuf_byte_cursor: int = 0
    wb_layer_i: int = 0
    checks: List[Tuple[str, str, int, int, int]] = field(default_factory=list)
    fast_preloads: List[Tuple[str, int]] = field(default_factory=list)
    checkpoint_policy: str = 'per_conv_dqa'  # 'final_only' | 'per_conv_dqa' | 'all'

    WB_LAYER_STRIDE: int = 0x100
    WB_BIAS_BASE: int = 0x1000
    WB_QSCALE_BASE: int = 0x2000
    _dqa_flags: int = 0x1
    _qa_flags: int = 0x0
    _im2col_flags: int = 0x0

    def meta_for(self, conv_idx: int) -> ConvMeta:
        return conv_meta(self.net, self.conv_names[conv_idx], weight_dir=self.weight_dir)

    def _pack_weights(self, meta: ConvMeta, weights: np.ndarray, acc_eff: int) -> int:
        off = self.ibuf_byte_cursor
        self.ibuf_weight_offsets.append(off)
        tile_word_count = 0
        for t in range(meta.num_tiles):
            tw = [f'{e:032x}' for e in pack_weight_tile(meta, weights, t, acc_override=acc_eff)]
            self.all_weight_words_per_tile[t].extend(tw)
            tile_word_count = len(tw)
        self.ibuf_byte_cursor += tile_word_count * IBUF_WORD_BYTES
        return len(self.ibuf_weight_offsets) - 1

    def _pack_wb(self, npz: np.lib.npyio.NpzFile, meta: ConvMeta) -> int:
        idx = self.wb_layer_i
        s_off = self.WB_LAYER_STRIDE * idx
        b_off = self.WB_BIAS_BASE + self.WB_LAYER_STRIDE * idx
        q_off = self.WB_QSCALE_BASE + 4 * idx
        scale = np.resize(npz['dqa_scale'].astype(np.float32), meta.out_ch)
        bias = np.resize(npz['dqa_bias'].astype(np.float32), meta.out_ch)
        qscale = np.float32(1.0 / float(npz['act_scale']))
        self.wb_data[s_off:s_off + len(scale.tobytes())] = scale.tobytes()
        self.wb_data[b_off:b_off + len(bias.tobytes())] = bias.tobytes()
        self.wb_data[q_off:q_off + 4] = qscale.tobytes()
        self.wb_layer_i += 1
        return idx

    def append_check(self, tag: str, arr: np.ndarray, dst_slot: int, is_fp32: bool) -> None:
        words = fp32_hwc_words(arr) if is_fp32 else int8_hwc_words(arr)
        fname = f'expected_{tag}.hex'
        write_hex(os.path.join(self.out_dir, fname), words)
        self.checks.append((tag, fname, dst_slot, len(words), int(is_fp32)))

    def emit_qa_int8(self, feat: FeatureTensor, wb_i: int, meta: ConvMeta) -> FeatureTensor:
        """FP32 feature → in-place INT8（下一段 conv 的 im2col 输入）。"""
        ch = feat.c
        self.fast_inst += vpu_exec(
            UNIT_QA, feat.slot, 0, ch, feat.h, feat.w,
            0, self.WB_QSCALE_BASE + 4 * wb_i, feat.slot, flags=self._qa_flags)
        qscale = np.float32(1.0 / float(load_layer_npz_checked(meta, self.net)['act_scale']))
        out = np.clip(np.round(feat.fp32_hwc() * qscale), -128, 127).astype(np.int8)
        return FeatureTensor(out, 'int8', feat.slot)

    def emit_save_shortcut_fp32(self, feat: FeatureTensor) -> None:
        """CDMA 保存 FP32 shortcut（lower_full：elem_bytes=4）。"""
        if feat.storage != 'fp32':
            raise ValueError('emit_save_shortcut_fp32 requires fp32 feature tensor')
        self.fast_inst += cdma_copy(
            OBUF_PHY_BASE + feat.slot, OBUF_PHY_BASE + ObufSlots.SHORT, feat.nbytes_obuf())

    def emit_preload_shortcut_fp32(self, feat: FeatureTensor, tag: str = 'skip_fp32') -> None:
        """段入口 INT8 特征：预加载 fp32(x) 到 SHORT，供块末 AD 使用。"""
        fname = f'{tag}.hex'
        write_hex(os.path.join(self.out_dir, fname), fp32_hwc_words(feat.fp32_hwc()))
        self.fast_preloads.append((fname, OBUF_PHY_BASE + ObufSlots.SHORT))

    def emit_conv(
        self,
        meta: ConvMeta,
        feat: FeatureTensor,
        *,
        skip_input_qa: bool,
        dqa_slot: int = ObufSlots.DQA,
        qa_dst_slot: Optional[int] = ObufSlots.FEAT1,
        checkpoint_tag: Optional[str] = None,
    ) -> Tuple[FeatureTensor, np.ndarray]:
        """im2col(FEAT*) → DCIM(FEAT1) → DQA → [QA]；返回更新后的特征与 dqa HWC。"""
        wb_i = self._pack_wb(load_layer_npz_checked(meta, self.net, require_activation=True), meta)
        npz = load_layer_npz_checked(meta, self.net, require_activation=True)
        acc_eff = (meta.kh * meta.kw * feat.c + DCIM_CH_IN - 1) // DCIM_CH_IN
        widx = self._pack_weights(meta, npz['weight_int8'], acc_eff)

        if not skip_input_qa and feat.storage == 'fp32':
            self.fast_inst += vpu_exec(
                UNIT_QA, feat.slot, 0, feat.c, feat.h, feat.w,
                0, self.WB_QSCALE_BASE + 4 * wb_i, feat.slot, flags=self._qa_flags)
            qscale = np.float32(1.0 / float(npz['act_scale']))
            feat = FeatureTensor(
                np.clip(np.round(feat.fp32_hwc() * qscale), -128, 127).astype(np.int8),
                'int8', feat.slot)
            self.fast_inst += vpu_pipe_nop()  # 排空 QA 残留（后续 im2col 读同一块内存）

        oh, ow = out_hw(feat.h, feat.w, meta)
        eff_ch = dcim_effective_out_ch(meta, False)
        self.fast_inst += vpu_exec(
            UNIT_IM2COL, feat.slot, 0, feat.c, feat.h, feat.w,
            0, 0, ObufSlots.IM2COL, encode_addr_break(meta), oh, ow, flags=self._im2col_flags)
        self.fast_inst += dcim_layer_inst(
            meta, oh * ow, ObufSlots.IM2COL, ObufSlots.FEAT1,
            IBUF_ACT, IBUF_WEI + self.ibuf_weight_offsets[widx], int16=False, acc_override=acc_eff,
            collect_to_vpubuf=True)
        self.fast_inst += vpu_pipe_nop()  # 排空 im2col 残留
        self.fast_inst += vpu_exec(
            UNIT_DQA, ObufSlots.FEAT1, 0, eff_ch, oh, ow,
            self.WB_BIAS_BASE + self.WB_LAYER_STRIDE * wb_i,
            self.WB_LAYER_STRIDE * wb_i, dqa_slot, flags=self._dqa_flags)

        qa_out, dqa_hwc = golden_conv_forward(
            feat.data, meta, npz, im2col_in_ch=feat.c, acc_eff=acc_eff)

        if checkpoint_tag and self.checkpoint_policy != 'final_only':
            self.append_check(checkpoint_tag, dqa_hwc, dqa_slot, is_fp32=True)

        if qa_dst_slot is not None:
            self.fast_inst += vpu_pipe_nop()  # 排空 DQA 残留
            self.fast_inst += vpu_exec(
                UNIT_QA, dqa_slot, 0, eff_ch, oh, ow,
                0, self.WB_QSCALE_BASE + 4 * wb_i, qa_dst_slot, flags=self._qa_flags)
            return FeatureTensor(qa_out, 'int8', qa_dst_slot), dqa_hwc

        return FeatureTensor(dqa_hwc, 'fp32', dqa_slot), dqa_hwc

    def emit_add_fp32(self, main_slot: int, skip_slot: int, dst_slot: int,
                      h: int, w: int, c: int) -> None:
        self.fast_inst += vpu_exec(
            UNIT_AD, main_slot, skip_slot, c, h, w, 0, 0, dst_slot)

    def emit_basic_block(
        self,
        conv_ids: Sequence[int],
        ds_idx: Optional[int],
        cur: FeatureTensor,
        *,
        block_entry_preloaded_shortcut: bool = False,
    ) -> FeatureTensor:
        """一个 ResNet basic block；块末 FP32 落在 FEAT1（与 compiler 一致，下一块再 QA）。"""
        metas = [self.meta_for(i) for i in conv_ids]
        npzs = [load_layer_npz_checked(m, self.net, require_activation=True) for m in metas]
        block_in = cur.data.copy()

        if block_entry_preloaded_shortcut:
            pass
        elif cur.storage == 'fp32':
            self.emit_save_shortcut_fp32(cur)
        else:
            raise ValueError(
                'INT8 block input requires preload fp32 shortcut on ObufSlots.SHORT')

        skip_input_qa = (cur.storage == 'fp32')
        for ci, cidx in enumerate(conv_ids):
            meta = metas[ci]
            is_last_conv = (ci == len(conv_ids) - 1)
            qa_slot = ObufSlots.FEAT1 if not is_last_conv else None
            cur, _ = self.emit_conv(
                meta, cur,
                skip_input_qa=skip_input_qa and ci == 0,
                dqa_slot=ObufSlots.DQA,
                qa_dst_slot=qa_slot,
                checkpoint_tag=(
                    f'conv{cidx}_dqa' if self.checkpoint_policy != 'final_only' else None),
            )
            skip_input_qa = False

        meta_ds = self.meta_for(ds_idx) if ds_idx is not None else None
        npz_ds = (load_layer_npz_checked(meta_ds, self.net, require_activation=True)
                  if meta_ds is not None else None)
        sum_fp32, ckpt = golden_basic_block(block_in, metas, npzs, meta_ds, npz_ds)
        oh, ow, oc = sum_fp32.shape[0], sum_fp32.shape[1], sum_fp32.shape[2]

        if ds_idx is not None:
            skip_feat = FeatureTensor(
                block_in.astype(np.float32), 'fp32', ObufSlots.SHORT)
            self.emit_conv(
                meta_ds, skip_feat,
                skip_input_qa=False,
                dqa_slot=ObufSlots.SHORT,
                qa_dst_slot=None,
                checkpoint_tag=(
                    'downsample_dqa' if self.checkpoint_policy != 'final_only' else None),
            )
            self.emit_add_fp32(ObufSlots.DQA, ObufSlots.SHORT, ObufSlots.FEAT1, oh, ow, oc)
        else:
            self.emit_add_fp32(ObufSlots.DQA, ObufSlots.SHORT, ObufSlots.FEAT1, oh, ow, oc)

        if self.checkpoint_policy == 'all':
            self.append_check('block_sum_fp32', sum_fp32, ObufSlots.FEAT1, is_fp32=True)
        return FeatureTensor(sum_fp32, 'fp32', ObufSlots.FEAT1)

    def finalize_case(
        self,
        *,
        name: str,
        layer: str,
        shape: str,
        input_feat: FeatureTensor,
        output_feat: FeatureTensor,
        primary_check_tag: str = 'final',
    ) -> dict:
        if output_feat.storage == 'int8':
            exp = output_feat.data
            self.append_check(primary_check_tag, exp, output_feat.slot, is_fp32=False)
            exp_words = int8_hwc_words(exp)
        else:
            exp = output_feat.fp32_hwc()
            self.append_check(primary_check_tag, exp, output_feat.slot, is_fp32=True)
            exp_words = fp32_hwc_words(exp)

        src_words = (int8_hwc_words(input_feat.data) if input_feat.storage == 'int8'
                     else fp32_hwc_words(input_feat.fp32_hwc()))
        write_hex(os.path.join(self.out_dir, 'expected.hex'),
                  fp32_hwc_words(exp) if output_feat.storage == 'fp32' else int8_hwc_words(exp))
        write_hex(os.path.join(self.out_dir, 'src0.hex'), src_words)
        loads = [('src0.hex', OBUF_PHY_BASE + input_feat.slot)]
        for t in range(NUM_TILES):
            fname = f'weight_tile{t}.hex'
            write_hex(os.path.join(self.out_dir, fname), self.all_weight_words_per_tile[t])
            loads.append((fname, TILE_IBUF_PHY_BASES[t] + IBUF_WEI))
        loads.extend(self.fast_preloads)
        make_fast_svh(loads, self.out_dir)
        write_checks_list(os.path.join(self.out_dir, 'checks.txt'), self.checks)
        self.fast_inst += [header(OP_END, 0, 0)]
        all_weight_words = [w for tw in self.all_weight_words_per_tile for w in tw]
        return {
            'module': 'resnet_partial',
            'name': name,
            'layer': layer,
            'dst': output_feat.slot,
            'words': len(exp_words),
            'fast_inst': self.fast_inst,
            'hbm': hbm_blob([
                (HBM_OFF_INPUT0, words_to_blob(src_words)),
                (HBM_OFF_WEIGHT, words_to_blob(all_weight_words)),
            ]),
            'wb': bytes(self.wb_data),
            'shape': shape,
            'checks': self.checks,
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
        """acc_depth = ceil(kH*kW*CH_IN / DCIM_CH_IN) = ceil(K / 64).
        每个 acc step 从 IBUF 读 INT8_ACT_WORDS=4 个 128-bit 字 = 64 INT8 通道。
        注意：此处除数是 DCIM_CH_IN=64，不是 16（16 是每个 128-bit 字的 INT8 容量）。"""
        return (self.in_ch * self.kh * self.kw + DCIM_CH_IN - 1) // DCIM_CH_IN

    @property
    def acc_depth_int16(self) -> int:
        """INT16 模式 acc_depth = ceil(K / DCIM_CH_IN) = ceil(K / 64).
        INT16 时每步读 INT16_ACT_WORDS=8 个 128-bit 字（每字 8 个 INT16），
        仍对应 DCIM_CH_IN=64 个逻辑通道（每通道 2 bytes）。"""
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


def conv_meta(net: Dict[str, dict], name: str, weight_dir: str = None) -> ConvMeta:
    ly = net[name]
    if isinstance(ly['stride'], list):
        stride_h, stride_w = ly['stride'][0], ly['stride'][1]
    else:
        stride_h, stride_w = int(ly['stride'])
    pad = ly['padding']
    if isinstance(pad, list):
        pad_h0, pad_w0, pad_h1, pad_w1 = pad[0], pad[1], pad[2], pad[3]
    else:
        pad_h0 = pad_w0 = pad_h1 = pad_w1 = int(pad)
    wd = weight_dir if weight_dir is not None else WEIGHT_DIR
    npz_path = os.path.join(wd, name.replace('.', '_') + '.npz')
    return ConvMeta(
        name, ly['in_channels'], ly['out_channels'],
        ly['kernel_h'], ly['kernel_w'],
        stride_h, stride_w, pad_h0, pad_w0, pad_h1, pad_w1,
        npz_path,
    )


def resnet_conv_layer_names(network: dict) -> List[str]:
    return [ly['name'] for ly in network['layers'] if ly.get('type') == 'conv']


def resnet_maxpool_hw(h: int, w: int) -> Tuple[int, int]:
    """ResNet stem MaxPool 3×3 stride 2 pad 1."""
    return (h + 2 - 3) // 2 + 1, (w + 2 - 3) // 2 + 1


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
    """Weight bytes per tile (each tile_ibuf holds its own weight partition)."""
    return meta.acc_depth * DCIM_CYCLE * OBUF_WORD_BYTES


def dcim_ibuf_act_bytes(meta: ConvMeta, matmul_m: int) -> int:
    return matmul_m * meta.acc_depth * OBUF_WORD_BYTES


def max_matmul_m_for_ibuf(meta: ConvMeta) -> int:
    """Largest im2col row count M=OH*OW that fits activation + weight in one tile_ibuf."""
    weight = dcim_ibuf_weight_bytes(meta)
    if weight >= TILE_IBUF_SIZE_BYTES:
        return 1
    per_row = meta.acc_depth * OBUF_WORD_BYTES
    if per_row == 0:
        return 1
    return max(1, (TILE_IBUF_SIZE_BYTES - weight) // per_row)


def ibuf_fits_dcim_matmul(meta: ConvMeta, matmul_m: int) -> bool:
    return dcim_ibuf_act_bytes(meta, matmul_m) + dcim_ibuf_weight_bytes(meta) <= TILE_IBUF_SIZE_BYTES


def scale_in_hw_to_fit_ibuf(meta: ConvMeta, in_h: int, in_w: int) -> Tuple[int, int, int, int, str]:
    """Shrink input H/W until M=OH*OW fits one tile_ibuf; return (h,w,oh,ow,note)."""
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
            f'{meta.name}: cannot fit DCIM matmul in tile_ibuf (512KB) even at 1x1 input '
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


def im2col(feat: np.ndarray, meta: ConvMeta, acc_override: int = None) -> np.ndarray:
    """INT8 im2col：每行 acc_depth×DCIM_CH_IN 字节。
    acc_override: im2col_in_ch > meta.in_ch 时用 ceil(kH*kW*im2col_in_ch/DCIM_CH_IN)。"""
    h, w, c = feat.shape
    oh, ow = out_hw(h, w, meta)
    acc = acc_override if acc_override is not None else meta.acc_depth
    cols = acc * DCIM_CH_IN
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


def im2col_int16(feat: np.ndarray, meta: ConvMeta, acc_override: int = None) -> np.ndarray:
    """INT16 im2col：每行 acc×DCIM_CH_IN 个 INT16 元素（每 acc step 64 逻辑通道）。
    布局与 INT8 im2col 同构，dtype int16；输入可为 INT8/INT16（经 int() sign-extend）。"""
    h, w, c = feat.shape
    oh, ow = out_hw(h, w, meta)
    if acc_override is not None:
        acc = acc_override
    else:
        acc = (c * meta.kh * meta.kw + DCIM_CH_IN - 1) // DCIM_CH_IN
    cols = acc * DCIM_CH_IN
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
                     int16: bool = False, acc_override: int = None) -> List[int]:
    """打包单个 Tile 的 INT8 权重到 IBUF SRAM word 格式。

    acc_override: 如果非 None，用此值代替 meta.acc_depth 计算 K（DCIM acc steps 数）。
    当 im2col_in_ch > meta.in_ch 时，acc_depth_eff = ceil(kH*kW*im2col_in_ch / DCIM_CH_IN)
    可能大于 meta.acc_depth。额外 acc steps 对应的权重补零。
    """
    ch_base = tile * DCIM_INT8_OUT_CH_PER_TILE
    flat = weight_int8.reshape(meta.out_ch, -1)
    if acc_override is not None:
        acc = acc_override
    else:
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
    """INT8 模式：固定按 NUM_TILES(4) 个 tile 输出，不足的 tile 补零。
    格式与 tile_obuf 物理布局一致：px 外循环，每 px 内按 tile0..3 顺序各 DCIM_INT8_OUT_WORDS_PER_TILE 个 word。"""
    lines = []
    for px in range(accum.shape[0]):
        for tile in range(NUM_TILES):
            base = tile * DCIM_INT8_OUT_CH_PER_TILE
            for word_idx in range(DCIM_INT8_OUT_WORDS_PER_TILE):
                blob = b''
                for c in range(4):
                    oc = base + word_idx * 4 + c
                    v = int(accum[px, oc]) if (tile < num_tiles and oc < accum.shape[1]) else 0
                    blob += struct.pack('<i', v)
                lines.append(''.join(f'{b:02x}' for b in reversed(blob)))
    return lines


def dcim_accum_words_int16(accum: np.ndarray, num_tiles: int) -> List[str]:
    """INT16 模式：固定按 NUM_TILES(4) 个 tile 输出，不足的 tile 补零。
    accum shape: (M, num_tiles * DCIM_LOGICAL_OUT_PER_TILE)，每 tile 4 个逻辑输出通道。"""
    lines = []
    for px in range(accum.shape[0]):
        for tile in range(NUM_TILES):
            base = tile * DCIM_LOGICAL_OUT_PER_TILE   # 每 tile 4 个逻辑 oc
            for word_idx in range(DCIM_INT16_OUT_WORDS_PER_TILE):
                blob = b''
                for c in range(4):
                    oc = base + word_idx * 4 + c
                    v = int(accum[px, oc]) if (tile < num_tiles and oc < accum.shape[1]) else 0
                    blob += struct.pack('<i', v)
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


def vpu_pipe_nop(n: int = None) -> List[int]:
    """插入 n 条 NOP 指令，让 vpu_buf 读有效 pipeline（深度=VPU_BUF_AXI_BRAM_READ_LATENCY=10）
    在两个 vpu_exec 之间完全排空，避免跨 unit 的 douta_valid 残留污染。
    n 默认取 READ_LATENCY（从 chip_config 导入），不在乎性能时直接调用无参数版本。"""
    if n is None:
        n = VPU_BUF_RD_LATENCY
    return [header(OP_NOP, 0, 0)] * n


def split64(addr: int) -> Tuple[int, int]:
    return (addr >> 32) & 0xFFFFFFFF, addr & 0xFFFFFFFF


def cdma_copy(src: int, dst: int, nbytes: int) -> List[int]:
    sm, sl = split64(src)
    dm, dl = split64(dst)
    return [header(OP_CDMA_COPY, 0, 20), sm, sl, dm, dl, nbytes & 0xFFFFFFFF, header(OP_WAIT_CDMA, 0, 0)]


# AXI BRAM Controller fmodel 行为模型在 READ_LATENCY 较大时，单次大 burst 内部
# outstanding 缓冲区会溢出（仿真模型限制，硬件无此问题）。
# 拆分阈值：474 words × 16B = 7584B，保守取 400 words（6400B）以留裕量。
_CDMA_FMODEL_CHUNK_WORDS = 400

def cdma_copy_chunked(src: int, dst: int, nbytes: int) -> List[int]:
    """将大 CDMA 传输拆成多条 ≤ _CDMA_FMODEL_CHUNK_WORDS×16B 的指令序列。

    每条指令后都附 WAIT_CDMA，确保顺序执行。拆分仅影响指令流，
    硬件行为与单条大指令完全等效（CDMA 按指令顺序执行，地址连续）。
    """
    assert nbytes % OBUF_WORD_BYTES == 0
    chunk_bytes = _CDMA_FMODEL_CHUNK_WORDS * OBUF_WORD_BYTES  # 6400 B
    insts: List[int] = []
    offset = 0
    while offset < nbytes:
        size = min(chunk_bytes, nbytes - offset)
        insts += cdma_copy(src + offset, dst + offset, size)
        offset += size
    return insts


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
    max_entries = max(16, len(fast_loads))
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


def ibuf_preload_per_tile(
    out_dir: str,
    act_words: List[str],
    weight_words_per_tile: List[List[str]],
    num_tiles: int,
    ibuf_wei_offset: int = IBUF_WEI,
) -> List[Tuple[str, int]]:
    """Generate per-tile IBUF preload files and return (fname, addr) pairs.

    - Activation: same data broadcast to all active tile_ibufs at IBUF_ACT offset.
    - Weight: per-tile data, each written to its own tile_ibuf at ibuf_wei_offset.

    Returns a list suitable for make_fast_svh().
    """
    fast_loads: List[Tuple[str, int]] = []
    write_hex(os.path.join(out_dir, 'act.hex'), act_words)
    for t in range(num_tiles):
        fast_loads.append(('act.hex', TILE_IBUF_PHY_BASES[t] + IBUF_ACT))
    for t in range(num_tiles):
        fname = f'weight_tile{t}.hex'
        write_hex(os.path.join(out_dir, fname), weight_words_per_tile[t])
        fast_loads.append((fname, TILE_IBUF_PHY_BASES[t] + ibuf_wei_offset))
    return fast_loads


def dcim_layer_inst(meta: ConvMeta, num_pixels: int, im2col_obuf: int, dcim_out_obuf: int,
                    ibuf_act: int, ibuf_wei: int, skip_cdma: bool = False,
                    int16: bool = False, acc_override: int = None,
                    collect_to_vpubuf: bool = False) -> List[int]:
    """生成 DCIM 指令序列。

    Per-tile IBUF: CDMA broadcasts activation to all active tile_ibufs.
    Each tile reads activation from the same offset within its own tile_ibuf.

    int16=True 时：
      - mode = MODE_INT16，acc_depth = acc_depth_int16
      - 每像素 ACT_BASE 步进 acc_depth_int16 * INT16_ACT_WORDS
      - 每像素每 tile 输出 DCIM_INT16_OUT_WORDS_PER_TILE 个 128-bit word

    acc_override: 当 im2col_in_ch > meta.in_ch 时，有效 acc_depth =
      ceil(kH*kW*im2col_in_ch / DCIM_CH_IN)，需通过此参数传入。
      额外 acc steps 对应的权重补零（zero-padded in pack_weight_tile）。

    collect_to_vpubuf=True: DCIM 完成后，通过 pixel-interleaved CDMA 把
      各 tile_obuf 的 INT32 结果搬运到 VPU_BUF[dcim_out_obuf]，供 DQA 读取。
      VPU_BUF 布局：[px0_tile0..tileN, px1_tile0..tileN, ...]（pixel-interleaved）。
    """
    inst = []
    if acc_override is not None:
        acc = acc_override
    else:
        acc = meta.acc_depth_int16 if int16 else meta.acc_depth
    act_words_per_row = DCIM_INT16_ACT_WORDS if int16 else DCIM_INT8_ACT_WORDS
    im2col_bytes = num_pixels * acc * OBUF_WORD_BYTES * act_words_per_row
    if not skip_cdma:
        for t in range(meta.num_tiles):
            inst += cdma_copy(OBUF_PHY_BASE + im2col_obuf, TILE_IBUF_PHY_BASES[t] + ibuf_act, im2col_bytes)
    mode_val = MODE_INT16 if int16 else MODE_INT8
    mode_reg = ((acc & 0xFF) << 8) | mode_val
    tiles_out = meta.num_tiles
    words_per_tile_per_px = DCIM_INT16_OUT_WORDS_PER_TILE if int16 else DCIM_INT8_OUT_WORDS_PER_TILE
    wpt_bytes = words_per_tile_per_px * OBUF_WORD_BYTES  # 8*16=128 B per tile per pixel (INT8)
    wei_base_words = [
        ibuf_wei // IBUF_WORD_BYTES
        for t in range(NUM_TILES)
    ]
    # 当 collect_to_vpubuf=True 时，DCIM 输出固定写到 tile_obuf 起始（word 0），
    # 避免 dcim_out_obuf（可能 >= 256KB tile_obuf 容量）溢出 tile_obuf。
    tile_obuf_write_base = 0 if collect_to_vpubuf else (dcim_out_obuf // OBUF_WORD_BYTES)
    out_base_words = [
        tile_obuf_write_base if t < tiles_out else 0
        for t in range(NUM_TILES)
    ]
    inst += dcim_layer_op(
        num_pixels=num_pixels,
        mode_reg=mode_reg,
        tile_mask=(1 << tiles_out) - 1,
        act_base_word=ibuf_act // IBUF_WORD_BYTES,
        act_stride_words=acc * act_words_per_row,
        out_stride_words=words_per_tile_per_px,
        wei_base_words=wei_base_words,
        out_base_words=out_base_words,
    )
    inst += [header(OP_NOP, 0, 0)] * 16
    if collect_to_vpubuf:
        # Pixel-interleaved CDMA: tile_obuf_t[px*wpt] → VPU_BUF[dcim_out_obuf + (px*tiles+t)*wpt]
        # DCIM 把结果写到 tile_obuf_t[out_base_words + px*wpt]（相对 tile_obuf 起始）。
        # 当 collect_to_vpubuf=True 时，out_base_words 已被固定为 0（见下方 tile_obuf_write_off），
        # 所以 pixel px 的 tile t 数据在 tile_obuf_t[px*wpt_bytes]。
        # 结果：VPU_BUF[dcim_out_obuf] = [px0_t0[wpt], px0_t1[wpt], ..., px1_t0[wpt], ...]
        # 与 int32_to_words(accum_padded) 格式一致（pixel-major, channel-minor）。
        for px in range(num_pixels):
            for t in range(tiles_out):
                src_phy = TILE_OBUF_PHY_BASES[t] + px * wpt_bytes
                dst_phy = OBUF_PHY_BASE + dcim_out_obuf + (px * tiles_out + t) * wpt_bytes
                inst += cdma_copy(src_phy, dst_phy, wpt_bytes)
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
        fast_inst = dcim_layer_inst(meta, matmul_m, 0, DCIM_OUT_BASE, IBUF_ACT, IBUF_WEI,
                                    skip_cdma=True, int16=True)
        mode_tag = 'int16'
        acc_info = acc

        # 权重打包：每个 tile 独立的 INT16 权重
        weight_words_per_tile: List[List[str]] = []
        for t in range(meta.num_tiles):
            tile_w16 = w16[t * DCIM_LOGICAL_OUT_PER_TILE:(t + 1) * DCIM_LOGICAL_OUT_PER_TILE]
            weight_words_per_tile.append([f'{e:032x}' for e in pack_weight_tile_int16(tile_w16, t, acc)])
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
        fast_inst = dcim_layer_inst(meta, matmul_m, 0, DCIM_OUT_BASE, IBUF_ACT, IBUF_WEI, skip_cdma=True)
        mode_tag = 'int8'
        acc_info = acc
        weight_words_per_tile: List[List[str]] = []
        for t in range(meta.num_tiles):
            weight_words_per_tile.append([f'{e:032x}' for e in pack_weight_tile(meta, weights, t)])

    fast_inst += [header(OP_END, 0, 0)]

    fast_loads = ibuf_preload_per_tile(out_dir, act_words, weight_words_per_tile, meta.num_tiles)
    make_fast_svh(fast_loads, out_dir)

    all_weight_words = [w for tw in weight_words_per_tile for w in tw]
    hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(act_words)), (HBM_OFF_WEIGHT, words_to_blob(all_weight_words))])
    net_shape = shapes.get(spec['layer'])
    matmul_n = num_logical_oc if use_int16 else meta.out_ch
    return {
        'module': 'dcim_matmul', 'name': spec['name'], 'layer': meta.name, 'dst': TILE_OBUF_DST,
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
        'wpt': DCIM_INT16_OUT_WORDS_PER_TILE if use_int16 else DCIM_INT8_OUT_WORDS_PER_TILE,
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
    # 动态地址：src=0，dst=src+align(src_size)
    # src 以 16B 对齐槽存放（in_col_stride=16），实际占 h*w*ceil(in_ch/16)*16 字节
    src_bytes_aligned = h * w * (((meta.in_ch + 15) // 16) * 16)
    src_off, dst_off = alloc_flat(src_bytes_aligned, len(exp_words) * OBUF_WORD_ALIGN)
    fast_inst = vpu_exec(UNIT_IM2COL, src_off, 0, meta.in_ch, h, w, 0, 0, dst_off,
                         encode_addr_break(meta), oh, ow)
    fast_inst += [header(OP_END, 0, 0)]
    fast_loads = [('src0.hex', OBUF_PHY_BASE + src_off)]
    make_fast_svh(fast_loads, out_dir)
    return {'module': 'im2col', 'name': spec['name'], 'layer': meta.name, 'dst': dst_off, 'words': len(exp_words),
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
        weight_words_per_tile: List[List[str]] = []
        for t in range(meta.num_tiles):
            tile_w16 = w16[t * DCIM_LOGICAL_OUT_PER_TILE:(t + 1) * DCIM_LOGICAL_OUT_PER_TILE]
            weight_words_per_tile.append([f'{e:032x}' for e in pack_weight_tile_int16(tile_w16, t, acc)])
        src_words = bytes_to_128_words(feat.astype(np.int16).tobytes())
        # INT16 im2col 需要 2× INT8 的 OBUF_AUX 空间；在 suite 中前 case 可能只写了一半，
        # 须用全零清空整个 AUX 区，避免残留数据影响后半段激活搬运结果
        im2col_aux_bytes = oh * ow * acc * DCIM_CH_IN * 2
        write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
        write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
        # 动态地址（INT16 路径的 fast_inst 在 weight_loads 块中统一生成）
        fast_inst = []  # placeholder，实际在 weight_loads 块中覆盖
        weight_loads: List[Tuple[str, int]] = []
        for t in range(meta.num_tiles):
            fname = f'weight_tile{t}.hex'
            write_hex(os.path.join(out_dir, fname), weight_words_per_tile[t])
            weight_loads.append((fname, TILE_IBUF_PHY_BASES[t] + IBUF_WEI))
        # 动态地址：src(INT16 feat) → im2col_aux → dcim_out → qa_out
        src16_bytes  = h * w * meta.in_ch * 2
        im2col_bytes = im2col_aux_bytes
        dcim_bytes   = oh * ow * meta.num_tiles * DCIM_INT16_OUT_WORDS_PER_TILE * OBUF_WORD_ALIGN
        qa_bytes     = oh * ow * num_logical_oc * 2  # INT16 out
        src_off, im2col_off, dcim_off, qa_off = alloc_flat(
            src16_bytes, im2col_bytes, dcim_bytes, len(exp_words) * OBUF_WORD_ALIGN)
        fast_inst = vpu_exec(UNIT_IM2COL, src_off, 0, meta.in_ch, h, w, 0, 0, im2col_off,
                             encode_addr_break(meta), oh, ow, flags=0x2)
        fast_inst += dcim_layer_inst(meta, oh * ow, im2col_off, dcim_off, IBUF_ACT, IBUF_WEI,
                                     int16=True, collect_to_vpubuf=True)
        fast_inst += vpu_pipe_nop()  # 排空 im2col/DCIM 残留
        fast_inst += vpu_exec(UNIT_DQA, dcim_off, 0, num_logical_oc, oh, ow, WB_BIAS, WB_SCALE, im2col_off, flags=0x1)
        fast_inst += vpu_pipe_nop()  # 排空 DQA 残留
        fast_inst += vpu_exec(UNIT_QA, im2col_off, 0, num_logical_oc, oh, ow, 0, WB_QSCALE, qa_off, flags=0x2)
        fast_inst += [header(OP_END, 0, 0)]
        # aux_zero：清空 im2col_off 区域（INT16 残留保护）
        aux_zero_words = bytes_to_128_words(bytes(im2col_aux_bytes))
        write_hex(os.path.join(out_dir, 'aux_zero.hex'), aux_zero_words)
        make_fast_svh([('src0.hex', OBUF_PHY_BASE + src_off),
                       ('aux_zero.hex', OBUF_PHY_BASE + im2col_off)] + weight_loads, out_dir)
        all_weight_words = [w for tw in weight_words_per_tile for w in tw]
        wb = wb_blob([(WB_SCALE, fp32_blob(scale[:num_logical_oc])), (WB_BIAS, fp32_blob(bias[:num_logical_oc])),
                      (WB_QSCALE, fp32_blob(np.array([qscale], dtype=np.float32)))])
        hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words)), (HBM_OFF_WEIGHT, words_to_blob(all_weight_words))])
        return {'module': 'conv_pipeline', 'name': spec['name'], 'layer': meta.name, 'dst': qa_off, 'words': len(exp_words),
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
    # Pad to effective DCIM output channels: DCIM tile always writes
    # INT8_OUT_CH_PER_TILE (=32) channels per pixel regardless of meta.out_ch.
    # Extra channels receive zero weight/bias from WB → QA output = 0.
    eff_ch = dcim_effective_out_ch(meta)
    if eff_ch > meta.out_ch:
        qa_padded = np.zeros((oh, ow, eff_ch), dtype=np.int8)
        qa_padded[:, :, :meta.out_ch] = qa
    else:
        qa_padded = qa
    src_words = int8_hwc_words(feat)
    exp_words = int8_hwc_words(qa_padded)
    weight_words_per_tile: List[List[str]] = []
    for t in range(meta.num_tiles):
        weight_words_per_tile.append([f'{e:032x}' for e in pack_weight_tile(meta, weights, t)])
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    # 动态地址：src(INT8) → im2col scratch → dcim_out → qa_out
    src_bytes    = h * w * meta.in_ch
    im2col_bytes = oh * ow * meta.acc_depth * DCIM_CH_IN
    dcim_bytes   = oh * ow * meta.num_tiles * DCIM_INT8_OUT_WORDS_PER_TILE * OBUF_WORD_ALIGN
    src_off, im2col_off, dcim_off, dst_off = alloc_flat(
        src_bytes, im2col_bytes, dcim_bytes, len(exp_words) * OBUF_WORD_ALIGN)
    fast_inst = vpu_exec(UNIT_IM2COL, src_off, 0, meta.in_ch, h, w, 0, 0, im2col_off,
                         encode_addr_break(meta), oh, ow)
    fast_inst += dcim_layer_inst(meta, oh * ow, im2col_off, dcim_off, IBUF_ACT, IBUF_WEI,
                                 collect_to_vpubuf=True)
    fast_inst += vpu_pipe_nop()  # 排空 im2col 最后几拍留在 douta_valid pipeline 中的残留
    fast_inst += vpu_exec(UNIT_DQA, dcim_off, 0, eff_ch, oh, ow, WB_BIAS, WB_SCALE, im2col_off, flags=0x1)
    fast_inst += vpu_pipe_nop()  # 排空 DQA 残留，避免污染 QA 的 douta_valid
    fast_inst += vpu_exec(UNIT_QA, im2col_off, 0, eff_ch, oh, ow, 0, WB_QSCALE, dst_off)
    fast_inst += [header(OP_END, 0, 0)]
    weight_loads: List[Tuple[str, int]] = []
    for t in range(meta.num_tiles):
        fname = f'weight_tile{t}.hex'
        write_hex(os.path.join(out_dir, fname), weight_words_per_tile[t])
        weight_loads.append((fname, TILE_IBUF_PHY_BASES[t] + IBUF_WEI))
    fast_loads = [
        ('src0.hex', OBUF_PHY_BASE + src_off),
    ] + weight_loads
    make_fast_svh(fast_loads, out_dir)
    all_weight_words = [w for tw in weight_words_per_tile for w in tw]
    hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words)), (HBM_OFF_WEIGHT, words_to_blob(all_weight_words))])
    wb = wb_blob([(WB_SCALE, fp32_blob(scale)), (WB_BIAS, fp32_blob(bias)), (WB_QSCALE, fp32_blob(np.array([qscale], dtype=np.float32)))])
    return {'module': 'conv_pipeline', 'name': spec['name'], 'layer': meta.name, 'dst': dst_off, 'words': len(exp_words),
            'fast_inst': fast_inst, 'hbm': hbm, 'wb': wb,
            'shape': f'{h}x{w}x{meta.in_ch} -> {oh}x{ow}x{meta.out_ch}(eff={eff_ch}) acc={meta.acc_depth} tiles={meta.num_tiles}'}


def make_cdma_memtest_case(out_dir: str, spec: dict, rng: np.random.Generator) -> dict:
    """CDMA 延迟配置验证：支持两种模式。

    模式 A（ibuf_preload=False，默认）：OBUF→IBUF→OBUF roundtrip
      1. CDMA_COPY  OBUF_src → IBUF_mid  (nbytes)   -- 验 OBUF 读延迟 + IBUF 写
      2. CDMA_COPY  IBUF_mid → OBUF_dst  (nbytes)   -- 验 IBUF 读延迟 + OBUF 写

    模式 B（ibuf_preload=True）：IBUF backdoor preload → CDMA IBUF→OBUF
      backdoor 写 IBUF_mid，只做 Step-2：IBUF→OBUF
      隔离 IBUF 读延迟，排除 OBUF→IBUF 写路径干扰

    Expected：OBUF_dst 内容 == src 原始随机数据。
    无需 WB；layer='cdma_memtest' 跳过 npz 指纹。
    """
    nbytes      = spec['nbytes']
    obuf_src    = spec.get('obuf_src', 0)   # OBUF 内字节偏移（模式 A 用）
    ibuf_mid    = spec['ibuf_mid']           # IBUF 内字节偏移
    obuf_dst    = spec['obuf_dst']           # OBUF 内字节偏移（结果读回处）
    ibuf_preload = spec.get('ibuf_preload', False)  # True=只测 IBUF 读，backdoor 写 IBUF
    # chunked=True：把大 CDMA 拆成多条小指令，绕开 AXI BRAM fmodel 474-word 仿真限制
    chunked      = spec.get('chunked', False)
    _copy = cdma_copy_chunked if chunked else cdma_copy

    assert nbytes % OBUF_WORD_BYTES == 0, 'nbytes must be 128-bit aligned'
    nwords = nbytes // OBUF_WORD_BYTES
    assert obuf_dst + nbytes <= 0x100_0000, 'OBUF dst overflow'
    assert ibuf_mid + nbytes <= TILE_IBUF_SIZE_BYTES, f'IBUF overflow (512KB per tile)'
    if not ibuf_preload:
        assert obuf_src + nbytes <= 0x100_0000, 'OBUF src overflow'
        assert obuf_src + nbytes <= obuf_dst or obuf_dst + nbytes <= obuf_src, \
            'OBUF src/dst must not overlap'

    # 生成随机数据（INT8 字节，打包成 128-bit words）
    raw = rng.integers(0, 256, size=nbytes, dtype=np.uint8).tobytes()
    src_words = bytes_to_128_words(raw)
    exp_words = src_words  # roundtrip 应精确还原

    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)

    ibuf_phys = IBUF_PHY_BASE + ibuf_mid
    dst_phys  = OBUF_PHY_BASE + obuf_dst

    if ibuf_preload:
        # 模式 B：backdoor 直接写 IBUF，只做 IBUF→OBUF
        fast_inst  = _copy(ibuf_phys, dst_phys, nbytes)   # IBUF→OBUF only
        fast_inst += [header(OP_END, 0, 0)]
        make_fast_svh([('src0.hex', IBUF_PHY_BASE + ibuf_mid)], out_dir)
        shape_str = (f'IBUF_preload[0x{ibuf_mid:06x}]→OBUF[0x{obuf_dst:06x}]'
                     f' nbytes={nbytes} ({nwords} words)'
                     + (' [chunked]' if chunked else ''))
    else:
        # 模式 A：OBUF→IBUF→OBUF roundtrip
        src_phys  = OBUF_PHY_BASE + obuf_src
        fast_inst  = _copy(src_phys, ibuf_phys, nbytes)   # Step-1: OBUF→IBUF
        fast_inst += _copy(ibuf_phys, dst_phys,  nbytes)  # Step-2: IBUF→OBUF
        fast_inst += [header(OP_END, 0, 0)]
        make_fast_svh([('src0.hex', OBUF_PHY_BASE + obuf_src)], out_dir)
        shape_str = (f'OBUF[0x{obuf_src:06x}]→IBUF[0x{ibuf_mid:06x}]→OBUF[0x{obuf_dst:06x}]'
                     f' nbytes={nbytes} ({nwords} words)'
                     + (' [chunked]' if chunked else ''))

    return {
        'module': 'cdma_memtest',
        'name': spec['name'],
        'layer': 'cdma_memtest',
        'dst': obuf_dst,
        'words': nwords,
        'fast_inst': fast_inst,
        'hbm': hbm_blob([]),
        'wb': bytes(WB_SIZE_BYTES),
        'shape': shape_str,
    }


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
    # 动态地址：src → dst
    src_bytes = len(src_words) * OBUF_WORD_ALIGN
    dst_bytes = len(fp32_to_words(y)) * OBUF_WORD_ALIGN
    src_off, dst_off = alloc_flat(src_bytes, dst_bytes)
    fast_inst = vpu_exec(UNIT_DQA, src_off, 0, c, h, w, WB_BIAS, WB_SCALE, dst_off, flags=flags)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + src_off)], out_dir)
    wb = wb_blob([(WB_SCALE, fp32_blob(scale)), (WB_BIAS, fp32_blob(bias))])
    return {'module': 'dqa', 'name': spec['name'], 'layer': meta.name, 'dst': dst_off,
            'words': len(fp32_to_words(y)), 'fast_inst': fast_inst,
            'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words))]),
            'wb': wb, 'shape': f'hwc={h}x{w}x{c} relu_en={relu_en} int16={use_int16}',
            'relu_en': relu_en}


def int16_accum_to_words(arr_int16: np.ndarray, c: int) -> List[str]:
    """INT16 accumulator → OBUF words for dqa_relu_unit int16_mode.

    RTL (FP_CORE_NUM=4) loads one 128b word per channel-quad and takes four INT16 lanes
    from gb_doutb[i*16 +: 16] (i=0..3).  Upper 64b of the word are unused.
    Address stride is c/4 words per pixel — NOT 8×int16 per word like QA output packing.
    arr_int16: shape (h*w, c), dtype int16
    """
    n, cols = arr_int16.shape
    assert cols == c
    lanes = 4  # matches FP_CORE_NUM / dqa_relu_unit int16 lane map
    align_c = ((c + lanes - 1) // lanes) * lanes
    padded = np.zeros((n, align_c), dtype=np.int16)
    padded[:, :c] = arr_int16
    blob = bytearray()
    for row in range(n):
        for ch_base in range(0, align_c, lanes):
            word = bytearray(OBUF_WORD_BYTES)
            for i in range(lanes):
                struct.pack_into('<h', word, i * 2, int(padded[row, ch_base + i]))
            blob.extend(word)
    return bytes_to_128_words(bytes(blob))


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
    # 动态地址：src(FP32) → dst(INT8 or INT16)
    # 先估算 dst 字节数，再分配
    dst_elem_bytes = 2 if use_int16 else 1
    dst_bytes = align_up(h * w * c * dst_elem_bytes)
    src_off, dst_off = alloc_flat(
        len(src_words) * OBUF_WORD_ALIGN, dst_bytes)
    fast_inst = vpu_exec(UNIT_QA, src_off, 0, c, h, w, 0, WB_QSCALE, dst_off, flags=flags)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + src_off)], out_dir)
    wb = wb_blob([(WB_QSCALE, fp32_blob(np.array([qscale], dtype=np.float32)))])
    if use_int16:
        y = np.clip(np.round(x * qscale), -32768, 32767).astype(np.int16).reshape(h * w, c)
        exp_words = int16_hwc_words(y.reshape(1, 1, h * w * c))
    else:
        y = np.clip(np.round(x * qscale), -128, 127).astype(np.int8).reshape(h, w, c)
        exp_words = int8_hwc_words(y)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    return {'module': 'qa', 'name': spec['name'], 'layer': meta.name, 'dst': dst_off,
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
    # 动态地址：src(FP32) → dst(FP32 2×H 2×W)
    src_off, dst_off = alloc_flat(
        len(src_words) * OBUF_WORD_ALIGN,
        len(exp_words) * OBUF_WORD_ALIGN)
    fast_inst = vpu_exec(UNIT_US, src_off, 0, c, h, w, 0, 0, dst_off)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + src_off)], out_dir)
    return {'module': 'us', 'name': spec['name'], 'layer': spec['source'], 'dst': dst_off,
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
    # 动态地址：src → dst（FP32 in/out，maxpool/GAP）
    src_off, dst_off = alloc_flat(
        len(src_words) * OBUF_WORD_ALIGN,
        len(exp_words) * OBUF_WORD_ALIGN)
    fast_inst = vpu_exec(UNIT_MP, src_off, 0, c, h, w, 0, 0, dst_off, addr_break_cfg)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + src_off)], out_dir)
    return {'module': 'mp', 'name': spec['name'], 'layer': spec['source'], 'dst': dst_off,
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
    # 动态地址：src0, src1 → dst（FP32 element-wise add）
    elem_bytes = len(a_words) * OBUF_WORD_ALIGN
    src0_off, src1_off, dst_off = alloc_flat(elem_bytes, elem_bytes, len(exp_words) * OBUF_WORD_ALIGN)
    fast_inst = vpu_exec(UNIT_AD, src0_off, src1_off, c, h, w, 0, 0, dst_off)
    fast_inst += [header(OP_END, 0, 0)]
    make_fast_svh([('src0.hex', OBUF_PHY_BASE + src0_off), ('src1.hex', OBUF_PHY_BASE + src1_off)], out_dir)
    return {'module': 'add', 'name': spec['name'], 'layer': spec['source'], 'dst': dst_off,
            'words': len(exp_words), 'fast_inst': fast_inst,
            'hbm': hbm_blob([(HBM_OFF_INPUT0, words_to_blob(a_words)), (HBM_OFF_INPUT1, words_to_blob(b_words))]),
            'wb': bytes(WB_SIZE_BYTES), 'shape': f'hwc={h}x{w}x{c}'}


def mini_int16_im2col_bytes(h: int, w: int, acc_eff: int) -> int:
    return h * w * acc_eff * DCIM_CH_IN * 2


def make_mini_network_case(out_dir: str, net: Dict[str, dict], spec: dict, rng: np.random.Generator) -> dict:
    """Multi-layer conv chain (+ optional residual add). QUANT=int8 or int16.

    OBUF slots (INT8/INT16 multi-layer share inter-layer layout):
      A/0x000000  input   B/0x100000  DCIM out + inter-layer feature
      C/0x200000  final output (INT16) / DCIM out (INT8 single-path)
      D/0x300000  im2col + DQA FP32 scratch   E/F  residual FP32   F  zero pool (INT16 CDMA)
    """
    layer_specs = spec['layers']
    has_residual = spec.get('residual_add', False)
    num_layers = len(layer_specs)
    use_int16: bool = spec.get('int16', False)
    _dqa_flags = 0x1
    _qa_flags = 0x2 if use_int16 else 0x0
    _im2col_flags = 0x2 if use_int16 else 0x0

    WB_LAYER_STRIDE = 0x100
    WB_BIAS_BASE = 0x1000
    WB_QSCALE_BASE = 0x2000

    SLOT_A, SLOT_B, SLOT_C, SLOT_D = 0x000000, 0x100000, 0x200000, 0x300000
    SLOT_E, SLOT_F = 0x400000, 0x500000
    SLOT_DCIM_OUT = SLOT_B if use_int16 else SLOT_C
    SLOT_ZERO = SLOT_F

    # --- Load per-layer conv metadata ---
    metas = []
    for ls in layer_specs:
        m = conv_meta(net, ls['layer'])
        m = ConvMeta(m.name, ls['in_ch'], ls['out_ch'],
                     m.kh, m.kw, m.stride_h, m.stride_w,
                     m.pad_h0, m.pad_w0, m.pad_h1, m.pad_w1, m.npz_path)
        metas.append(m)

    h0, w0 = layer_specs[0]['in_hw']

    # Per-layer effective DCIM output channel counts (computed early; used in both
    # expected-output generation and instruction-stream building).
    layer_eff_ch = [dcim_effective_out_ch(m, use_int16) for m in metas]

    # Per-layer effective acc_depth for DCIM, accounting for eff_ch propagation.
    # When im2col_in_ch > meta.in_ch (from prev layer's eff_ch), the im2col produces
    # more acc steps: acc_eff = ceil(kH*kW*im2col_in_ch / DCIM_CH_IN).
    # The extra acc steps have zero activations + zero-padded weights → contribute 0.
    _im2col_ins = [metas[0].in_ch] + [layer_eff_ch[i - 1] for i in range(1, len(metas))]
    layer_acc_eff = [
        (m.kh * m.kw * ic + DCIM_CH_IN - 1) // DCIM_CH_IN
        for m, ic in zip(metas, _im2col_ins)
    ]

    # --- Golden computation + WB/weight packing ---
    feat = random_int8(rng, (h0, w0, metas[0].in_ch))
    current_int8 = feat.copy()
    wb_data = bytearray(WB_SIZE_BYTES)
    all_weight_words_per_tile: List[List[str]] = [[] for _ in range(NUM_TILES)]
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

        acc_eff_i = layer_acc_eff[i]

        eff_ch_i = layer_eff_ch[i]
        im2col_in_ch = meta.in_ch if i == 0 else layer_eff_ch[i - 1]

        if use_int16:
            # INT16 golden: im2col_in_ch may exceed meta.in_ch when eff_ch padding propagates.
            feat_i = current_int8.reshape(cur_h, cur_w, im2col_in_ch)
            cols = im2col_int16(feat_i, meta, acc_override=acc_eff_i)

            # INT16 DCIM: 4 nibbles = 1 INT16 weight — cannot sign-extend INT8 model weights.
            # Same as conv_pipeline / dcim_matmul INT16 cases: random w16 + model DQA scale/bias.
            num_logical_oc = meta.num_tiles * DCIM_LOGICAL_OUT_PER_TILE
            K_eff = acc_eff_i * DCIM_CH_IN
            w16 = rng.integers(-2048, 2048, size=(num_logical_oc, K_eff), dtype=np.int32).astype(np.int16)
            scale_ext = np.resize(scale, num_logical_oc)
            bias_ext = np.resize(bias, num_logical_oc)
            accum = (cols.astype(np.int64) @ w16.astype(np.int64).T).astype(np.int32)
        else:
            # im2col_in_ch may exceed meta.in_ch when prev layer DCIM eff_ch pads OBUF (e.g. 16→32).
            feat_i = current_int8.reshape(cur_h, cur_w, im2col_in_ch).astype(np.int8)
            cols = im2col(feat_i, meta, acc_override=acc_eff_i)
            wflat = weights.reshape(meta.out_ch, -1).astype(np.int32)
            k_size = acc_eff_i * DCIM_CH_IN
            if wflat.shape[1] < k_size:
                wflat = np.pad(wflat, ((0, 0), (0, k_size - wflat.shape[1])), constant_values=0)
            accum = cols.astype(np.int32) @ wflat.T

        if use_int16:
            dqa = np.maximum(accum.astype(np.float32) * scale_ext[None, :] + bias_ext[None, :], 0.0)
            qa_ch = num_logical_oc
        else:
            dqa = np.maximum(accum.astype(np.float32) * scale[None, :] + bias[None, :], 0.0)
            qa_ch = meta.out_ch
        layer_dqa_fp32.append(dqa)
        qa_out_dtype = np.int16 if use_int16 else np.int8
        qa_clip = (-32768, 32767) if use_int16 else (-128, 127)
        qa = np.clip(np.round(dqa * qscale), qa_clip[0], qa_clip[1]).astype(qa_out_dtype).reshape(oh, ow, qa_ch)
        # Pad to eff_ch so golden im2col matches hardware OBUF layout for the next layer.
        if eff_ch_i > meta.out_ch:
            qa_padded = np.zeros((oh, ow, eff_ch_i), dtype=qa_out_dtype)
            qa_padded[:, :, :meta.out_ch] = qa
            current_int8 = qa_padded
        else:
            current_int8 = qa
        layer_oh_ow.append((oh, ow))
        cur_h, cur_w = oh, ow

        # Weight packing for IBUF (use acc_eff_i so DCIM reads the correct
        # number of acc steps including zero-padded extra steps from eff_ch propagation).
        ibuf_weight_offsets.append(ibuf_byte_cursor)
        tile_word_count = 0
        for t in range(meta.num_tiles):
            if use_int16:
                w16_tile = w16[t * DCIM_LOGICAL_OUT_PER_TILE:(t + 1) * DCIM_LOGICAL_OUT_PER_TILE, :]
                tw = [f'{e:032x}' for e in pack_weight_tile_int16(w16_tile, t, acc_eff_i)]
            else:
                tw = [f'{e:032x}' for e in pack_weight_tile(meta, weights, t, acc_override=acc_eff_i)]
            all_weight_words_per_tile[t] += tw
            tile_word_count = len(tw)
        ibuf_byte_cursor += tile_word_count * IBUF_WORD_BYTES

    # --- Compute final expected output ---
    # The DCIM tile always writes eff_ch channels per pixel (rounded up to tile boundary).
    # DQA/QA instructions use eff_ch; extra channels produce INT8(0) from zero WB.
    # Expected output must match this eff_ch-wide layout.
    eff_ch_final = layer_eff_ch[-1]
    if has_residual and num_layers >= 2:
        fp32_sum = (layer_dqa_fp32[0] + layer_dqa_fp32[1]).astype(np.float32)
        qscale_final = layer_qscales[-1]
        oh_f, ow_f = layer_oh_ow[1]
        qa_clip = (-32768, 32767) if use_int16 else (-128, 127)
        qa_out_dtype = np.int16 if use_int16 else np.int8
        logic_out = metas[-1].num_tiles * DCIM_LOGICAL_OUT_PER_TILE if use_int16 else metas[-1].out_ch
        final = np.clip(np.round(fp32_sum * qscale_final), qa_clip[0], qa_clip[1]).astype(qa_out_dtype)
        final = final.reshape(oh_f, ow_f, logic_out)
        if eff_ch_final > logic_out:
            final_padded = np.zeros((oh_f, ow_f, eff_ch_final), dtype=qa_out_dtype)
            final_padded[:, :, :logic_out] = final
            final = final_padded
        if use_int16:
            exp_words = int16_hwc_words(final)
        else:
            exp_words = int8_hwc_words(final)
        final_dst = SLOT_C
    else:
        oh_f, ow_f = layer_oh_ow[-1]
        qa_out_dtype = np.int16 if use_int16 else np.int8
        final = current_int8.reshape(oh_f, ow_f, eff_ch_final).astype(qa_out_dtype)
        if use_int16:
            exp_words = int16_hwc_words(final)
        else:
            exp_words = int8_hwc_words(final)
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
        eff_ch = layer_eff_ch[i]
        im2col_in_ch = meta.in_ch if i == 0 else layer_eff_ch[i - 1]
        acc_eff = layer_acc_eff[i]
        dqa_ch = (meta.num_tiles * DCIM_LOGICAL_OUT_PER_TILE) if use_int16 else eff_ch

        fast_inst += vpu_exec(UNIT_IM2COL, src_slot, 0, im2col_in_ch, lh, lw,
                              0, 0, SLOT_D, encode_addr_break(meta), oh_i, ow_i, flags=_im2col_flags)
        fast_inst += dcim_layer_inst(meta, oh_i * ow_i, SLOT_D, SLOT_DCIM_OUT,
                                     IBUF_ACT, ibuf_wei_off, int16=use_int16, acc_override=acc_eff,
                                     collect_to_vpubuf=True)
        fast_inst += vpu_pipe_nop()  # 排空 im2col 残留

        if has_residual:
            dqa_dst = SLOT_E if i == 0 else SLOT_F
            fast_inst += vpu_exec(UNIT_DQA, SLOT_DCIM_OUT, 0, dqa_ch, oh_i, ow_i,
                                  wb_b, wb_s, dqa_dst, flags=_dqa_flags)
            if i < num_layers - 1:
                fast_inst += vpu_pipe_nop()  # 排空 DQA 残留
                fast_inst += vpu_exec(UNIT_QA, dqa_dst, 0, dqa_ch, oh_i, ow_i,
                                      0, wb_q, SLOT_B, flags=_qa_flags)
        else:
            # INT16 multi-layer: keep SLOT_D for im2col only; DQA FP32 → SLOT_E between layers.
            # OBUF CDMA F→D before 2nd im2col hangs simv; do not use cdma_copy to clear SLOT_D.
            dqa_dst = SLOT_E if (use_int16 and i < num_layers - 1) else SLOT_D
            fast_inst += vpu_exec(UNIT_DQA, SLOT_DCIM_OUT, 0, dqa_ch, oh_i, ow_i,
                                  wb_b, wb_s, dqa_dst, flags=_dqa_flags)
            if i < num_layers - 1:
                qa_dst = SLOT_B
            else:
                qa_dst = final_dst
            fast_inst += vpu_pipe_nop()  # 排空 DQA 残留
            fast_inst += vpu_exec(UNIT_QA, dqa_dst, 0, dqa_ch, oh_i, ow_i,
                                  0, wb_q, qa_dst, flags=_qa_flags)

    if has_residual:
        # ADD: SLOT_E + SLOT_F → SLOT_D
        oh_f, ow_f = layer_oh_ow[-1]
        out_ch = metas[-1].out_ch
        ad_ch = (metas[-1].num_tiles * DCIM_LOGICAL_OUT_PER_TILE) if use_int16 else out_ch
        fast_inst += vpu_exec(UNIT_AD, SLOT_E, SLOT_F, ad_ch, oh_f, ow_f,
                              0, 0, SLOT_D)
        # Final QA: SLOT_D → SLOT_C
        wb_q_final = WB_QSCALE_BASE + 4 * (num_layers - 1)
        qa_ch_final = ad_ch
        fast_inst += vpu_pipe_nop()  # 排空 AD 残留
        fast_inst += vpu_exec(UNIT_QA, SLOT_D, 0, qa_ch_final, oh_f, ow_f,
                              0, wb_q_final, final_dst, flags=_qa_flags)

    fast_inst += [header(OP_END, 0, 0)]

    # --- Write output files ---
    # INT16 im2col reads 2 B/element; src0 must be INT16-packed (same as conv_pipeline).
    if use_int16:
        src_words = bytes_to_128_words(feat.astype(np.int16).tobytes())
    else:
        src_words = int8_hwc_words(feat)
    write_hex(os.path.join(out_dir, 'expected.hex'), exp_words)
    write_hex(os.path.join(out_dir, 'src0.hex'), src_words)
    fast_loads = [
        ('src0.hex', OBUF_PHY_BASE + SLOT_A),
    ]
    for t in range(NUM_TILES):
        fname = f'weight_tile{t}.hex'
        write_hex(os.path.join(out_dir, fname), all_weight_words_per_tile[t])
        fast_loads.append((fname, TILE_IBUF_PHY_BASES[t] + IBUF_WEI))
    if use_int16:
        max_aux_bytes = max(
            mini_int16_im2col_bytes(layer_oh_ow[i][0], layer_oh_ow[i][1], layer_acc_eff[i])
            for i in range(len(metas))
        )
        aux_zero_words = bytes_to_128_words(bytes(max_aux_bytes))
        write_hex(os.path.join(out_dir, 'aux_zero.hex'), aux_zero_words)
        fast_loads.append(('aux_zero.hex', OBUF_PHY_BASE + SLOT_D))
    make_fast_svh(fast_loads, out_dir)
    all_weight_words = [w for tw in all_weight_words_per_tile for w in tw]
    hbm = hbm_blob([(HBM_OFF_INPUT0, words_to_blob(src_words)),
                     (HBM_OFF_WEIGHT, words_to_blob(all_weight_words))])

    total_shape = ' → '.join(f'{ls["in_ch"]}→{ls["out_ch"]}' for ls in layer_specs)
    return {'module': 'mini_network', 'name': spec['name'],
            'layer': metas[0].name, 'dst': final_dst,
            'words': len(exp_words), 'fast_inst': fast_inst,
            'hbm': hbm, 'wb': bytes(wb_data),
            'shape': f'{num_layers}-layer {total_shape} residual={has_residual} int16={use_int16}'}


def make_resnet_partial_case(out_dir: str, net: Dict[str, dict], network: dict, spec: dict,
                             rng: np.random.Generator) -> dict:
    """ResNet18 分段（通用 ResnetSegmentBuilder）。

    preset:
      stem       — conv[0] + MaxPool3×3（DQA FP32 → MP → OUT，比对 FP32）
      stage1     — 从 INT8 输入跑 block 0–1（conv 1–4）
      stage1_2   — block 0–3（conv 1–9，含 downsample）

    spec 可选:
      checkpoint_policy: final_only | per_conv_dqa | all
      output_format: fp32 | int8  （段末是否 QA 并比对 INT8）
      num_blocks: 覆盖默认 block 数
    """
    preset = spec['preset']
    weight_dir = spec.get('weight_dir', RESNET18_WEIGHT_DIR)
    conv_names = resnet_conv_layer_names(network)
    ckpt_policy = spec.get('checkpoint_policy', 'per_conv_dqa')
    output_format = spec.get('output_format', 'int8')

    bld = ResnetSegmentBuilder(
        net=net, conv_names=conv_names, weight_dir=weight_dir,
        rng=rng, out_dir=out_dir,
    )
    bld.checkpoint_policy = ckpt_policy

    if preset == 'stem':
        h0, w0 = spec['in_hw']
        meta0 = bld.meta_for(0)
        feat = random_int8(rng, (h0, w0, meta0.in_ch))
        inp = FeatureTensor(feat, 'int8', ObufSlots.FEAT0)
        cur, dqa_hwc = bld.emit_conv(
            meta0, inp, skip_input_qa=True, dqa_slot=ObufSlots.FEAT1, qa_dst_slot=None,
            checkpoint_tag='conv0_dqa')
        mp_out = maxpool_generic(dqa_hwc.astype(np.float32), kernel=3, stride=2, pad=1)
        eff_ch = dqa_hwc.shape[2]
        bld.fast_inst += vpu_pipe_nop()  # 排空 DQA 残留（emit_conv 内部已加 im2col→DQA NOP，这里是 DQA→MP）
        bld.fast_inst += vpu_exec(
            UNIT_MP, ObufSlots.FEAT1, 0, eff_ch, cur.h, cur.w,
            0, 0, ObufSlots.OUT, addr_break=1)
        out = FeatureTensor(mp_out, 'fp32', ObufSlots.OUT)
        meta = bld.finalize_case(
            name=spec['name'], layer=meta0.name,
            shape=f'resnet stem in_hw={h0}x{w0} conv0+mp3x3',
            input_feat=inp, output_feat=out, primary_check_tag='stem_mp',
        )
        meta['checks'] = bld.checks
        return meta

    if preset not in ('stage1', 'stage1_2'):
        raise ValueError(f'unknown resnet_partial preset {preset!r}')

    ih, iw = spec['input_hw']
    ic = spec['input_ch']
    num_blocks = spec.get('num_blocks', 2 if preset == 'stage1' else 4)

    feat_i8 = random_int8(rng, (ih, iw, ic))
    cur = FeatureTensor(feat_i8, 'int8', ObufSlots.FEAT0)
    bld.emit_preload_shortcut_fp32(cur, tag='skip_entry_fp32')

    for bi in range(num_blocks):
        conv_ids, ds_idx = RESNET_BLOCK_SCHEDULE[bi]
        cur = bld.emit_basic_block(
            conv_ids, ds_idx, cur,
            block_entry_preloaded_shortcut=(bi == 0),
        )

    if output_format == 'int8':
        last_conv_idx = RESNET_BLOCK_SCHEDULE[num_blocks - 1][0][-1]
        last_meta = bld.meta_for(last_conv_idx)
        npz_last = load_layer_npz_checked(last_meta, net, require_activation=True)
        out_i8 = golden_qa_int8_from_fp32(cur.fp32_hwc(), float(npz_last['act_scale']))
        wb_i = max(0, bld.wb_layer_i - 1)
        bld.fast_inst += vpu_pipe_nop()  # 排空上一个 unit 残留
        bld.fast_inst += vpu_exec(
            UNIT_QA, cur.slot, 0, out_i8.shape[2], out_i8.shape[0], out_i8.shape[1],
            0, bld.WB_QSCALE_BASE + 4 * wb_i, cur.slot, flags=bld._qa_flags)
        cur = FeatureTensor(out_i8, 'int8', cur.slot)

    meta = bld.finalize_case(
        name=spec['name'],
        layer=conv_names[RESNET_BLOCK_SCHEDULE[0][0][0]],
        shape=(f'resnet {preset} blocks={num_blocks} in={ih}x{iw}x{ic} '
               f'out={cur.h}x{cur.w}x{cur.c} fmt={output_format}'),
        input_feat=FeatureTensor(feat_i8, 'int8', ObufSlots.FEAT0),
        output_feat=cur,
        primary_check_tag='final',
    )
    meta['checks'] = bld.checks
    return meta



def module_needs_wb(module: str) -> bool:
    """Only DQA/QA/conv_pipeline/mini_network/resnet_partial read scale/bias from WB."""
    return module in ('dqa', 'qa', 'conv_pipeline', 'mini_network', 'resnet_partial')


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
        if meta.get('checks'):
            for name, fname, dst, words, fp32_flag in meta['checks']:
                cw = words if verify_words == 0 else min(words, verify_words)
                f.write(f'{name} {fname} {dst:06x} {cw} {fp32_flag}\n')
        else:
            wpt = meta.get('wpt', 0)
            f.write(f'{meta["name"]} expected.hex {meta["dst"]:06x} {check_words} {is_fp32} {wpt}\n')
    with open(os.path.join(out_dir, 'manifest.txt'), 'w') as f:
        for k in ('module', 'name', 'layer', 'shape', 'words'):
            f.write(f'{k}: {meta[k]}\n')
        if meta['module'] == 'dcim_matmul':
            for k in ('matmul_m', 'matmul_k', 'matmul_n', 'acc_depth', 'in_hw', 'in_hw_note', 'network_in_hw'):
                f.write(f'{k}: {meta[k]}\n')
        if meta.get('layer') not in ('cdma_concat', 'cdma_memtest', ''):
            f.write(f'weight_npz_sha256_16: {meta.get("npz_sha256_16", "unknown")}\n')
            f.write('golden_numeric_semantics: network.json + parsed/weights npz; DQA_RELU=max(accum*scale+bias,0); QA=round(x/act_scale) clamp int8\n')
        f.write(f'check_words: {check_words}\n')
        f.write('runtime_files: inst.hex preload.txt checks.txt\n')


def case_native_int16(spec: dict) -> bool:
    """Case 是否定义为 INT16 数据路径（与 --quant 无关，由 spec/命名决定）。"""
    if spec.get('int16', False):
        return True
    name = spec.get('name', '')
    return 'accum16' in name or 'int16' in name


def quant_compatible(module: str, spec: dict, quant: str) -> bool:
    """--quant 是否与该 case 的固有精度匹配（避免 dqa_c16_small+qint16 这类误跑）。"""
    # dcim_matmul：INT8/INT16 由 case 名/spec 决定；run_module_sim 不传 --quant，此处勿用默认 int8 筛掉 int16 case
    if module == 'dcim_matmul':
        return True
    # cdma_memtest 与精度无关，--quant int8 即可
    if module == 'cdma_memtest':
        return quant == 'int8'
    native = case_native_int16(spec)
    if quant == 'int16':
        return native
    return not native


def _apply_dim_overrides(spec: dict, args: argparse.Namespace, module: str) -> dict:
    """Apply --quant and --dim overrides to a case spec (returns modified copy)."""
    spec = dict(spec)

    # dcim_matmul：精度由 case 名/spec 决定；其它模块：int16 由 case 定义，--quant 只用于筛选跑哪类 case。
    if module != 'dcim_matmul':
        spec['int16'] = case_native_int16(spec)

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
    module = args.module
    network_json = (RESNET18_NETWORK_JSON if module == 'resnet_partial'
                    else args.network_json)
    net = load_network(network_json)
    network = load_network_file(network_json)
    im2col_shapes = propagate_conv_im2col_shapes(network)
    cases = module_cases(module, network_json)
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
    effective_module = spec.get('module', module)

    out_dir = args.out_dir
    os.makedirs(out_dir, exist_ok=True)
    skip_path = os.path.join(out_dir, 'skipped.txt')
    if os.path.exists(skip_path):
        os.remove(skip_path)

    if not quant_compatible(effective_module, spec, args.quant):
        with open(skip_path, 'w') as f:
            f.write(f'quant={args.quant} incompatible with case={spec["name"]} '
                    f'(native_int16={case_native_int16(spec)})\n')
        print(f'SKIP: case {spec["name"]!r} does not support --quant {args.quant}')
        return

    rng = np.random.default_rng(args.seed)
    if effective_module == 'dcim_matmul':
        meta = make_dcim_case(out_dir, net, spec, rng, im2col_shapes)
    elif effective_module == 'im2col':
        meta = make_im2col_case(out_dir, net, spec, rng)
    elif effective_module == 'conv_pipeline':
        meta = make_conv_pipeline_case(out_dir, net, spec, rng)
    elif effective_module == 'concat_by_cdma':
        meta = make_concat_by_cdma_case(out_dir, spec, rng)
    elif effective_module == 'cdma_memtest':
        meta = make_cdma_memtest_case(out_dir, spec, rng)
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
    elif effective_module == 'resnet_partial':
        meta = make_resnet_partial_case(out_dir, net, network, spec, rng)
    else:
        raise AssertionError(effective_module)

    if meta['layer'] != 'cdma_concat' and meta['layer'] != 'cdma_memtest':
        if effective_module == 'resnet_partial':
            meta['npz_sha256_16'] = layer_fingerprint(
                conv_meta(net, meta['layer'], weight_dir=RESNET18_WEIGHT_DIR))
        else:
            meta['npz_sha256_16'] = layer_fingerprint(conv_meta(net, meta['layer']))
    write_hex(os.path.join(out_dir, 'hbm_image.hex'), bytes_to_128_words(meta['hbm']))
    write_hex(os.path.join(out_dir, 'wb_init.hex'), bytes_to_128_words(meta['wb']))
    if module_needs_wb(meta['module']):
        with open(os.path.join(out_dir, 'preload.txt'), 'a') as f:
            f.write(f'wb_init.hex {0x1030_0000_0:016x}\n')
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
                   help='筛选精度：int8=INT32 累加器等；int16=accum16/int16 命名或 spec 用例；不匹配则写 skipped.txt')
    p.add_argument('--dim', default='',
                   help='维度覆盖，格式：C=N 或 H=N,W=N,C=N 或 HW=HxW,C=N；不指定则用 case 默认值')
    args = p.parse_args()
    generate(args)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
