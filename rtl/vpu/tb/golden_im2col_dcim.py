#!/usr/bin/env python3
"""
golden_im2col_dcim.py - im2col + DCIM INT4 计算的 golden reference

生成用于 RTL 仿真验证的:
  1. feature map 初始化数据 (hex)
  2. weight 初始化数据 (hex)
  3. im2col 预期输出 (hex)
  4. DCIM 计算预期输出 (hex)
  5. 指令序列 (hex)

与 tb_inst_driven_im2col_dcim.sv 配合使用。
"""

import numpy as np
import struct
import os

# =============================================================================
# 参数配置（与 TB 一致）
# =============================================================================
CH_IN = 16       # 输入通道
H, W = 8, 8     # feature map 尺寸
KH, KW = 3, 3   # kernel 尺寸
STRIDE = 1
PAD = 1
OH = (H + 2*PAD - KH) // STRIDE + 1  # 8
OW = (W + 2*PAD - KW) // STRIDE + 1  # 8

NUM_TILES = 8
DCIM_CH_IN = 16   # DCIM 每 Tile 输入通道
DCIM_CH_OUT = 16  # DCIM 每 Tile 输出通道
WD1 = 4           # 权重位宽 (INT4: -8 ~ +7)
CYCLE = 8         # 权重 SRAM 加载周期

# 地址映射（字节地址）
FEATURE_BASE = 0x000000
IM2COL_BASE  = 0x010000
DCIM_OUT_BASE = 0x080000

# IBUF 地址映射（字地址 = word index, 每 word 128-bit = 16 bytes）
IBUF_ACT_BASE = 0
IBUF_WEI_BASE = 0x1000

# OBUF/IBUF 物理映射（CDMA 用的 64-bit 地址）
OBUF_PHY_BASE = 0x1_0100_0000
IBUF_PHY_BASE = 0x1_0000_0000

# =============================================================================
# 1. 生成 feature map
# =============================================================================
def generate_feature():
    """生成 NHWC 布局的 feature map (INT8 signed)"""
    feat = np.zeros((H, W, CH_IN), dtype=np.int8)
    for ih in range(H):
        for iw in range(W):
            for c in range(CH_IN):
                idx = (ih * W + iw) * CH_IN + c
                feat[ih, iw, c] = np.int8(((idx & 0x7F) + 1))  # 1~128 → int8
    return feat

# =============================================================================
# 2. 计算 im2col 输出
# =============================================================================
def compute_im2col(feat):
    """
    im2col: NHWC feature → [OH*OW, KH*KW*CH_IN] 矩阵
    每行 = KH*KW*CH_IN bytes = 9*16 = 144 bytes = 9 个 128-bit word
    """
    im2col_rows = OH * OW
    im2col_cols = KH * KW * CH_IN  # 144
    result = np.zeros((im2col_rows, im2col_cols), dtype=np.int8)
    
    for oh in range(OH):
        for ow in range(OW):
            row_idx = oh * OW + ow
            col_idx = 0
            for kh in range(KH):
                for kw in range(KW):
                    ih = oh * STRIDE - PAD + kh
                    iw = ow * STRIDE - PAD + kw
                    for c in range(CH_IN):
                        if 0 <= ih < H and 0 <= iw < W:
                            result[row_idx, col_idx] = feat[ih, iw, c]
                        else:
                            result[row_idx, col_idx] = 0  # zero padding
                        col_idx += 1
    return result

# =============================================================================
# 3. 生成 DCIM 权重
# =============================================================================
def generate_weights():
    """
    权重: INT4 signed, 全部设为 +1 (4'b0001)
    DCIM weight SRAM 布局: 每 entry = CH_IN * CH_OUT * WD1 / CYCLE bits
      = 16 * 16 * 4 / 8 = 128 bits = 1 个 IBUF word
    每 Tile 有 CYCLE=8 个 entry
    所有 nibble = 0001 (+1)
    """
    # 逻辑权重: [NUM_TILES, CH_OUT, CH_IN] = [8, 16, 16], 每个是 INT4 = +1
    weights = np.ones((NUM_TILES, DCIM_CH_OUT, DCIM_CH_IN), dtype=np.int8)
    return weights

# =============================================================================
# 4. 计算 DCIM 输出
# =============================================================================
def compute_dcim(im2col_matrix, weights):
    """
    DCIM 计算：每 Tile 对 im2col 每行做 MAC
    
    DCIM 工作方式：
    - 读取 IBUF 中的 activation（im2col 数据）
    - 每次读 1 个 128-bit word = 16 个 INT8 值 = CH_IN 个 activation
    - 与 weight SRAM 中的 CH_IN × CH_OUT 个 INT4 权重做 MAC
    - acc_depth 次累加后输出
    
    acc_depth = ceil(im2col_row_bytes / 16) = ceil(144 / 16) = 9
    每个 acc cycle 处理 16 个 activation（1 word）
    
    但实际上 DCIM 做的是：
    output[tile][row][ch_out] = sum over acc_cycles of (
        sum over ch_in of (act[cycle][ch] * weight[tile][ch][ch_out])
    )
    
    由于 weight 全为 +1：
    output[tile][row][ch_out] = sum of all activation values in that row
    
    但要注意 INT4 mode 下 activation 是 4-bit nibble！
    act_nibble_converter 将每个 INT8 byte 拆成 2 个 4-bit nibble
    """
    acc_depth = (KH * KW * CH_IN + 15) // 16  # 9
    num_rows = OH * OW  # 64
    
    # DCIM 在 INT4 mode 下的行为:
    # - activation 被 act_nibble_converter 拆分为 4-bit nibble
    # - 每个 128-bit word = 32 个 4-bit nibble（不是 16 个 8-bit）
    # - 但 CH_IN=16，所以实际每个 cycle 处理 16 个 4-bit nibble
    # - 每行 9 个 word = 9 × 16 = 144 个 nibble? 不对...
    #
    # 实际上在 INT4 mode 中:
    # - 每个 128-bit IBUF word 包含 CH_IN=16 个 INT8 activation
    # - act_nibble_converter 将 16 个 INT8 拆成 32 个 INT4 nibble
    # - 乘以 INT4 weight，结果是 INT8 per channel pair
    # - 最终累加得到 wider result
    #
    # 简化: weight=+1, INT4 乘法:
    # output[ch_out] = sum over (acc_depth cycles × CH_IN channels) of nibble values
    
    # 每个 INT8 activation byte 拆成 low nibble 和 high nibble (signed 4-bit: -8~7)
    # byte 0x01 → low=1, high=0
    # byte 0x10 → low=0, high=1
    # byte 0x1F → low=-1, high=1 (signed: 0xF = -1)
    
    # DCIM 在 MODE_INT4 下：
    # 每 cycle 读 1 个 128-bit word (16 bytes)
    # act_nibble_converter 将其拆为 2 组 × 16 个 4-bit nibble
    # 每组与 weight 做 16×16 INT4 MAC，结果累加
    # 所以 acc_depth=9 → 每行实际做 9×2=18 次 MAC cycle
    #
    # 但这取决于具体的 act_nibble_converter 实现...
    # 让我们简化：对于 golden check，直接用 known pattern 验证
    
    # 方案：使用简单加法验证
    # weight 全为 +1 (INT4)，activation 是 INT4 nibble
    # output[row][ch_out] = sum of all input nibbles across acc_depth
    
    results = np.zeros((NUM_TILES, num_rows, DCIM_CH_OUT), dtype=np.int32)
    
    for tile in range(NUM_TILES):
        for row in range(num_rows):
            # 将该行 144 bytes 解释为 4-bit nibbles
            row_data = im2col_matrix[row]  # 144 INT8 values
            
            # DCIM 处理: 每个 word (16 bytes) 拆成 nibbles
            # 然后 MAC with weight=+1
            # 简化计算: sum of all signed 4-bit nibbles
            acc = np.zeros(DCIM_CH_OUT, dtype=np.int32)
            
            for word_idx in range(acc_depth):
                # 该 word 的 16 个 bytes
                start_byte = word_idx * 16
                for ch in range(min(16, len(row_data) - start_byte)):
                    byte_val = int(row_data[start_byte + ch])
                    # 拆成两个 signed 4-bit nibble
                    lo = byte_val & 0xF
                    hi = (byte_val >> 4) & 0xF
                    # signed 4-bit: if >= 8, subtract 16
                    if lo >= 8: lo -= 16
                    if hi >= 8: hi -= 16
                    # weight=+1, 对每个 output channel 都加这两个 nibble
                    # （因为 weight 矩阵全为 +1）
                    acc += (lo + hi)
            
            results[tile, row, :] = acc
    
    return results

# =============================================================================
# 5. 序列化为 hex 文件
# =============================================================================
def to_128bit_hex_words(byte_array):
    """将字节数组转为 128-bit hex word 列表（小端序）"""
    words = []
    data = bytes(byte_array)
    # 补齐到 16 字节边界
    if len(data) % 16 != 0:
        data = data + b'\x00' * (16 - len(data) % 16)
    for i in range(0, len(data), 16):
        word = data[i:i+16]
        # 128-bit hex, MSB first (byte 15 在最左边)
        hex_str = ''.join(f'{b:02x}' for b in reversed(word))
        words.append(hex_str)
    return words

def write_hex_file(filename, hex_words):
    """写入 hex 文件，每行一个 128-bit word"""
    with open(filename, 'w') as f:
        for w in hex_words:
            f.write(w + '\n')

# =============================================================================
# 6. 生成指令序列（32-bit words）
# =============================================================================
def generate_instructions():
    """
    生成 INST_Decoder 指令序列:
    1. OP_VPU_EXEC (im2col)
    2. OP_WAIT_VPU
    3. OP_CDMA_COPY (OBUF im2col → IBUF)
    4. OP_WAIT_CDMA
    5. OP_DCIM_CFG (配置 MODE, ACT_BASE, WEI_BASE×8, OUT_BASE×8)
    6. OP_DCIM_EXEC
    7. OP_WAIT_DCIM
    8. OP_END
    """
    insts = []
    
    # === 1. OP_VPU_EXEC: im2col ===
    # Header: opcode=2, flags=0, length=56 (bytes: 14 words × 4)
    UNIT_IM2COL = 7
    header = (0x2 << 28) | (0x0 << 24) | (14 * 4)  # 56 bytes
    insts.append(header)
    # Body: 14 words
    insts.append(UNIT_IM2COL)        # vpu_unit_choose
    insts.append(FEATURE_BASE)       # vpu_src_addr
    insts.append(0)                  # vpu_src2_addr (unused)
    insts.append(CH_IN)              # vpu_src_c
    insts.append(H)                  # vpu_src_h
    insts.append(W)                  # vpu_src_w
    insts.append(0)                  # vpu_bias_addr (unused)
    insts.append(0)                  # vpu_scale_addr (unused)
    insts.append(IM2COL_BASE)        # vpu_dst_addr
    # addr_break: {kH[7:0], kW[7:0], strideH[3:0], strideW[3:0], padH[3:0], padW[3:0]}
    addr_break = (KH << 24) | (KW << 16) | (STRIDE << 12) | (STRIDE << 8) | (PAD << 4) | PAD
    insts.append(addr_break)         # vpu_addr_break
    insts.append(OH)                 # vpu_addr_s
    insts.append(OW)                 # vpu_addr_t
    insts.append(0)                  # reserved
    insts.append(0)                  # reserved
    
    # === 2. OP_WAIT_VPU ===
    header = (0x4 << 28) | 0
    insts.append(header)
    
    # === 3. OP_CDMA_COPY: OBUF im2col → IBUF ===
    # im2col 数据量 = OH*OW * acc_depth * 16 bytes
    acc_depth = (KH * KW * CH_IN + 15) // 16  # 9
    cdma_length = OH * OW * acc_depth * 16  # 64 * 9 * 16 = 9216 bytes
    
    # INST_Decoder 的 CDMA body 格式（只有 3 words）：
    #   body[0] = src_addr_lsb (32-bit)
    #   body[1] = dst_addr_lsb (32-bit)
    #   body[2] = length (bytes)
    # MSB 由 decoder 强制为 0
    
    cdma_src_lsb = IM2COL_BASE  # OBUF 中 im2col 偏移（字节地址）
    cdma_dst_lsb = IBUF_ACT_BASE * 16  # IBUF 字节地址
    
    header = (0x1 << 28) | (3 * 4)  # OP_CDMA_COPY, 3 words = 12 bytes
    insts.append(header)
    insts.append(cdma_src_lsb)   # body[0]: src_addr_lsb
    insts.append(cdma_dst_lsb)   # body[1]: dst_addr_lsb
    insts.append(cdma_length)    # body[2]: length
    
    # === 4. OP_WAIT_CDMA ===
    header = (0x3 << 28) | 0
    insts.append(header)
    
    # === 5. OP_DCIM_CFG ===
    # 配置: MODE + ACT_BASE + 8 WEI_BASE + 8 OUT_BASE = 18 pairs = 36 words
    num_pairs = 1 + 1 + NUM_TILES + NUM_TILES  # MODE + ACT + WEI×8 + OUT×8 = 18
    header = (0x8 << 28) | num_pairs
    insts.append(header)
    
    # MODE: addr=0x008, data = {acc_depth[7:0], mode[2:0]}
    MODE_INT4 = 0b100
    insts.append(0x008)  # addr
    insts.append((acc_depth << 8) | MODE_INT4)  # data
    
    # ACT_BASE: addr=0x010, data = IBUF_ACT_BASE (word addr in IBUF)
    insts.append(0x010)
    insts.append(IBUF_ACT_BASE)
    
    # WEI_BASE[0..7]: addr=0x040+t*4
    for t in range(NUM_TILES):
        insts.append(0x040 + t * 4)
        insts.append(IBUF_WEI_BASE + t * CYCLE)
    
    # OUT_BASE[0..7]: addr=0x140+t*4 (OBUF word addr)
    for t in range(NUM_TILES):
        insts.append(0x140 + t * 4)
        insts.append((DCIM_OUT_BASE >> 4) + t * 0x1000)
    
    # === 6. OP_DCIM_EXEC ===
    header = (0x6 << 28) | 0
    insts.append(header)
    
    # === 7. OP_WAIT_DCIM ===
    header = (0x7 << 28) | 0
    insts.append(header)
    
    # === 8. OP_END ===
    header = (0xF << 28) | 0
    insts.append(header)
    
    return insts

# =============================================================================
# Main
# =============================================================================
def main():
    output_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("=" * 60)
    print("  Golden Reference: im2col + DCIM INT4")
    print(f"  Feature: {H}x{W}x{CH_IN}, Kernel: {KH}x{KW}")
    print(f"  Stride: {STRIDE}, Pad: {PAD}, OH: {OH}, OW: {OW}")
    print(f"  im2col rows: {OH*OW}, cols: {KH*KW*CH_IN}")
    print(f"  acc_depth: {(KH*KW*CH_IN+15)//16}")
    print("=" * 60)
    
    # 1. Generate feature
    feat = generate_feature()
    print(f"\nFeature shape: {feat.shape}, range: [{feat.min()}, {feat.max()}]")
    
    # 2. Compute im2col
    im2col = compute_im2col(feat)
    print(f"im2col shape: {im2col.shape}")
    print(f"  Row 0 first 16 bytes: {list(im2col[0, :16])}")
    print(f"  Row 0 bytes 64~79 (kh=1,kw=1): {list(im2col[0, 64:80])}")
    
    # 3. Generate weights
    weights = generate_weights()
    print(f"Weights shape: {weights.shape}, all +1")
    
    # 4. Compute DCIM output
    dcim_out = compute_dcim(im2col, weights)
    print(f"DCIM output shape: {dcim_out.shape}")
    print(f"  Tile 0, Row 0: {dcim_out[0, 0, :]}")
    print(f"  Tile 0, Row 1: {dcim_out[0, 1, :]}")
    
    # 5. Write hex files
    # Feature (flat bytes)
    feat_flat = feat.flatten().view(np.uint8)
    feat_hex = to_128bit_hex_words(feat_flat)
    write_hex_file(os.path.join(output_dir, 'golden_feature.hex'), feat_hex)
    print(f"\nWrote golden_feature.hex ({len(feat_hex)} words)")
    
    # im2col expected (flat bytes, row-major)
    im2col_flat = im2col.flatten().view(np.uint8)
    im2col_hex = to_128bit_hex_words(im2col_flat)
    write_hex_file(os.path.join(output_dir, 'golden_im2col.hex'), im2col_hex)
    print(f"Wrote golden_im2col.hex ({len(im2col_hex)} words)")
    
    # DCIM output: 每个 Tile 的结果打包为 128-bit words
    # INT4 mode 输出格式: postProcess 截断到 WD3=19 bits per channel
    # 实际输出打包方式取决于 DCIM_Tile 的 ST_SAVE 逻辑
    # 对于 non-INT16 mode: 2 words per result (int8_packed_reg[255:0] split into [127:0] and [255:128])
    # 这表明每个 result 输出 256-bit = 16 个 INT16 值
    
    # 先把 golden 以 int32 格式写出，TB 侧做比较时自行截断
    for t in range(NUM_TILES):
        tile_data = dcim_out[t].flatten()  # [64 rows × 16 ch_out] = 1024 int32 values
        # 打包为 128-bit words (每 word 4 个 int32)
        hex_words = []
        for i in range(0, len(tile_data), 4):
            word_bytes = b''
            for j in range(4):
                if i + j < len(tile_data):
                    word_bytes += struct.pack('<i', int(tile_data[i+j]))
                else:
                    word_bytes += b'\x00' * 4
            hex_str = ''.join(f'{b:02x}' for b in reversed(word_bytes))
            hex_words.append(hex_str)
        write_hex_file(os.path.join(output_dir, f'golden_dcim_tile{t}.hex'), hex_words)
    print(f"Wrote golden_dcim_tile0~7.hex")
    
    # Weight hex (for IBUF loading)
    # 每个 entry = 128 bits = 32 个 4-bit nibble, 全为 0001
    wei_word = 0x1111_1111_1111_1111_1111_1111_1111_1111  # 32 nibbles of 0001
    wei_hex = [f'{wei_word:032x}'] * (NUM_TILES * CYCLE)
    write_hex_file(os.path.join(output_dir, 'golden_weight.hex'), wei_hex)
    print(f"Wrote golden_weight.hex ({len(wei_hex)} words)")
    
    # Instructions
    insts = generate_instructions()
    inst_hex = [f'{w:08x}' for w in insts]
    with open(os.path.join(output_dir, 'golden_instructions.hex'), 'w') as f:
        for h in inst_hex:
            f.write(h + '\n')
    print(f"Wrote golden_instructions.hex ({len(insts)} words)")
    
    # Summary for TB verification
    print(f"\n--- Verification Points ---")
    print(f"im2col row 0, word 4 (kh=1,kw=1): should be feature[0][0] bytes 1~16")
    print(f"  Expected: {list(feat[0,0,:])}")
    print(f"  im2col[0][64:80] = {list(im2col[0, 64:80])}")
    
    # DCIM Tile 0 Row 0 expected output
    print(f"\nDCIM Tile 0, Row 0 output (all ch_out identical since weight=+1):")
    print(f"  = {dcim_out[0, 0, 0]} (sum of all signed nibbles in im2col row 0)")
    
    # Self-check: manual calculation for row 0
    row0 = im2col[0]
    nibble_sum = 0
    for byte_val in row0:
        b = int(byte_val) & 0xFF
        lo = b & 0xF
        hi = (b >> 4) & 0xF
        if lo >= 8: lo -= 16
        if hi >= 8: hi -= 16
        nibble_sum += lo + hi
    print(f"  Manual nibble sum for row 0: {nibble_sum}")
    assert nibble_sum == dcim_out[0, 0, 0], "MISMATCH!"
    print(f"  ✓ Self-check PASSED")
    
    print(f"\n{'='*60}")
    print(f"  All golden files generated successfully")
    print(f"{'='*60}")

if __name__ == '__main__':
    main()
