#!/usr/bin/env python3
"""
使用硬件指令解码器 (INST_Decoder) 的端到端 VPU 测试流程：
1. 将指令序列写入 inst_bram
2. 将测试数据写入 global_bram
3. 启动 INST_Decoder 执行指令序列
4. 等待解码器完成
5. 从 global_bram 读取结果并验证

地址映射（新）：
  0x1000_0000  global_bram (1MB) - 数据区
  0x1020_0000  inst_bram (1MB) - 指令区
  0x1040_0000  VPU GB (128KB)
  0x1042_0000  VPU WB (128KB)
  0x1044_0000  VPU_AXI_Regs (4KB) - 配置 + 状态 + 解码器控制
"""

import sys
import time
import struct
import numpy as np
from pathlib import Path

parent_dir = Path(__file__).parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

from xdma_helpers import write_blob, read_blob, write_reg, read_reg

# ==============================================================================
# 地址映射（新）
# ==============================================================================
GLOBAL_BRAM_BASE = 0x10000000  # 1MB
INST_BRAM_BASE   = 0x10200000  # 1MB
VPU_GB_BASE      = 0x10400000  # 128KB
VPU_WB_BASE      = 0x10420000  # 128KB
VPU_REGS_BASE    = 0x10440000  # 4KB

# ==============================================================================
# VPU_AXI_Regs 寄存器偏移
# ==============================================================================
REG_CTRL         = 0x00
REG_STATUS       = 0x04
REG_UNIT_CHOOSE  = 0x08
REG_SRC_ADDR     = 0x0C
REG_SRC2_ADDR    = 0x10
REG_SRC_C        = 0x14
REG_SRC_H        = 0x18
REG_SRC_W        = 0x1C
REG_BIAS_ADDR    = 0x20
REG_SCALE_ADDR   = 0x24
REG_DST_ADDR     = 0x28
REG_ADDR_BREAK   = 0x2C
REG_ADDR_S       = 0x30
REG_ADDR_T       = 0x34
# INST_Decoder 控制寄存器
REG_DECODER_CTRL   = 0x38
REG_INST_COUNT     = 0x3C
REG_DECODER_STATUS = 0x40

# ==============================================================================
# 指令操作码定义（与 INST_Decoder.sv 一致）
# 指令头格式：[31:28] OPCODE | [27:24] FLAGS | [23:0] BODY_LENGTH (字节)
# ==============================================================================
OP_NOP       = 0x0
OP_CDMA_COPY = 0x1
OP_VPU_EXEC  = 0x2
OP_WAIT_CDMA = 0x3
OP_WAIT_VPU  = 0x4
OP_SYNC      = 0x5
OP_END       = 0xF


def print_sep(title: str = ""):
    if title:
        print(f"\n{'='*60}\n  {title}\n{'='*60}")
    else:
        print("="*60)


# ==============================================================================
# 指令编码函数
# 指令头格式：[31:28] OPCODE | [27:24] FLAGS | [23:0] BODY_LENGTH (字节)
# ==============================================================================
def _make_header(opcode: int, body_length: int, flags: int = 0) -> int:
    """构造指令头"""
    return ((opcode & 0xF) << 28) | ((flags & 0xF) << 24) | (body_length & 0xFFFFFF)


def encode_nop() -> bytes:
    """NOP 指令：1 word (header only, body_length=0)"""
    header = _make_header(OP_NOP, 0)
    return struct.pack('<I', header)


def encode_cdma_copy(src_addr: int, dst_addr: int, length: int) -> bytes:
    """
    CDMA_COPY 指令：4 words
    Word 0: header (opcode=0x1, body_length=12)
    Word 1: src_addr (低 32 位)
    Word 2: dst_addr (低 32 位)
    Word 3: length (字节数)
    """
    header = _make_header(OP_CDMA_COPY, 12)  # 3 words * 4 bytes = 12 bytes
    return struct.pack('<IIII', header, src_addr, dst_addr, length)


def encode_vpu_exec(unit_choose: int, src_addr: int, src2_addr: int,
                    src_c: int, src_h: int, src_w: int,
                    bias_addr: int, scale_addr: int, dst_addr: int,
                    addr_break: int, addr_s: int, addr_t: int) -> bytes:
    """
    VPU_EXEC 指令：13 words
    Word 0: header (opcode=0x2, body_length=48)
    Word 1-12: VPU 配置参数
    """
    header = _make_header(OP_VPU_EXEC, 48)  # 12 words * 4 bytes = 48 bytes
    return struct.pack('<IIIIIIIIIIIII',
                       header,
                       unit_choose, src_addr, src2_addr,
                       src_c, src_h, src_w,
                       bias_addr, scale_addr, dst_addr,
                       addr_break, addr_s, addr_t)


def encode_wait_cdma() -> bytes:
    """WAIT_CDMA 指令：1 word (header only)"""
    header = _make_header(OP_WAIT_CDMA, 0)
    return struct.pack('<I', header)


def encode_wait_vpu() -> bytes:
    """WAIT_VPU 指令：1 word (header only)"""
    header = _make_header(OP_WAIT_VPU, 0)
    return struct.pack('<I', header)


def encode_sync() -> bytes:
    """SYNC 指令：1 word (header only)"""
    header = _make_header(OP_SYNC, 0)
    return struct.pack('<I', header)


def encode_end() -> bytes:
    """END 指令：1 word (header only)"""
    header = _make_header(OP_END, 0)
    return struct.pack('<I', header)


def build_instruction_sequence(instructions: list) -> bytes:
    """将指令列表合并为字节序列"""
    return b''.join(instructions)


# ==============================================================================
# 解码器控制函数
# ==============================================================================
def decoder_start(inst_count: int):
    """启动解码器执行指令序列"""
    write_reg(VPU_REGS_BASE, REG_INST_COUNT, inst_count)
    write_reg(VPU_REGS_BASE, REG_DECODER_CTRL, 0x01)


def decoder_wait(timeout: float = 5.0) -> int:
    """等待解码器完成，返回状态"""
    deadline = time.time() + timeout
    while time.time() < deadline:
        status = read_reg(VPU_REGS_BASE, REG_DECODER_STATUS)
        busy = status & 0x01
        done = (status >> 1) & 0x01
        error = (status >> 31) & 0x01
        
        if error:
            raise RuntimeError(f"Decoder error: status=0x{status:08X}")
        if done and not busy:
            return status
        
        time.sleep(0.001)
    
    final_status = read_reg(VPU_REGS_BASE, REG_DECODER_STATUS)
    raise TimeoutError(f"Decoder timeout: status=0x{final_status:08X}")


def decoder_status() -> dict:
    """读取解码器状态"""
    status = read_reg(VPU_REGS_BASE, REG_DECODER_STATUS)
    return {
        'raw': status,
        'busy': bool(status & 0x01),
        'done': bool((status >> 1) & 0x01),
        'error': bool((status >> 31) & 0x01),
    }


# ==============================================================================
# 测试用例
# ==============================================================================
def test_inst_bram_rw():
    """测试 1: inst_bram 基本读写"""
    print_sep("测试 1: inst_bram 基本读写")
    
    test_data = np.arange(16, dtype=np.uint32)
    write_blob(INST_BRAM_BASE, test_data.tobytes())
    
    read_back = read_blob(INST_BRAM_BASE, len(test_data) * 4)
    read_data = np.frombuffer(read_back, dtype=np.uint32)
    
    assert np.array_equal(test_data, read_data), \
        f"Mismatch: expected {test_data[:8]}, got {read_data[:8]}"
    print(f"✓ inst_bram 读写一致, 前 8 值: {read_data[:8]}")


def test_global_bram_rw():
    """测试 2: global_bram 基本读写"""
    print_sep("测试 2: global_bram 基本读写")
    
    test_data = np.arange(64, dtype=np.uint32)
    write_blob(GLOBAL_BRAM_BASE, test_data.tobytes())
    
    read_back = read_blob(GLOBAL_BRAM_BASE, len(test_data) * 4)
    read_data = np.frombuffer(read_back, dtype=np.uint32)
    
    assert np.array_equal(test_data, read_data), \
        f"Mismatch: expected {test_data[:8]}, got {read_data[:8]}"
    print(f"✓ global_bram 读写一致, 前 8 值: {read_data[:8]}")


def test_decoder_status():
    """测试 3: 解码器状态读取"""
    print_sep("测试 3: 解码器状态读取")
    
    status = decoder_status()
    print(f"Decoder status: {status}")
    print("✓ 解码器状态读取成功")


def test_cdma_via_decoder():
    """测试 4: 通过解码器执行 CDMA 搬运"""
    print_sep("测试 4: 通过解码器执行 CDMA 搬运")
    
    src_off, dst_off, size = 0x0000, 0x1000, 256
    
    # 准备测试数据
    src_data = np.arange(size, dtype=np.uint8)
    dst_fill = np.full(size, 0xFF, dtype=np.uint8)
    
    write_blob(GLOBAL_BRAM_BASE + src_off, src_data.tobytes())
    write_blob(GLOBAL_BRAM_BASE + dst_off, dst_fill.tobytes())
    
    # 构建指令序列
    instructions = [
        encode_cdma_copy(GLOBAL_BRAM_BASE + src_off, GLOBAL_BRAM_BASE + dst_off, size),
        encode_wait_cdma(),
        encode_end(),
    ]
    inst_bytes = build_instruction_sequence(instructions)
    inst_count = len(inst_bytes) // 4
    
    print(f"指令序列: {inst_count} words ({len(inst_bytes)} bytes)")
    print(f"CDMA: 0x{GLOBAL_BRAM_BASE+src_off:08X} → 0x{GLOBAL_BRAM_BASE+dst_off:08X} ({size}B)")
    
    # 写入指令到 inst_bram
    write_blob(INST_BRAM_BASE, inst_bytes)
    
    # 启动解码器
    decoder_start(inst_count)
    
    # 等待完成
    status = decoder_wait(timeout=2.0)
    print(f"Decoder completed: status=0x{status:08X}")
    
    # 验证结果
    result = np.frombuffer(read_blob(GLOBAL_BRAM_BASE + dst_off, size), dtype=np.uint8)
    assert np.array_equal(src_data, result), \
        f"Mismatch: expected {src_data[:16]}, got {result[:16]}"
    print(f"✓ CDMA 搬运成功, 前 16 字节: {result[:16]}")


def test_cdma_to_vpu_gb():
    """测试 5: 通过解码器执行 CDMA global_bram → VPU GB"""
    print_sep("测试 5: 通过解码器执行 CDMA global_bram → VPU GB")
    
    size = 256
    src_off = 0x2000
    test_data = np.arange(size, dtype=np.uint8)
    
    write_blob(GLOBAL_BRAM_BASE + src_off, test_data.tobytes())
    
    # 构建指令序列
    instructions = [
        encode_cdma_copy(GLOBAL_BRAM_BASE + src_off, VPU_GB_BASE, size),
        encode_wait_cdma(),
        encode_end(),
    ]
    inst_bytes = build_instruction_sequence(instructions)
    inst_count = len(inst_bytes) // 4
    
    print(f"指令序列: {inst_count} words")
    print(f"CDMA: 0x{GLOBAL_BRAM_BASE+src_off:08X} → 0x{VPU_GB_BASE:08X} ({size}B)")
    
    write_blob(INST_BRAM_BASE, inst_bytes)
    decoder_start(inst_count)
    decoder_wait(timeout=2.0)
    
    # 验证 VPU GB 数据
    result = np.frombuffer(read_blob(VPU_GB_BASE, size), dtype=np.uint8)
    assert np.array_equal(test_data, result), \
        f"Mismatch: expected {test_data[:16]}, got {result[:16]}"
    print(f"✓ VPU GB 数据正确, 前 16 字节: {result[:16]}")


def test_cdma_roundtrip():
    """测试 6: 通过解码器执行完整 CDMA 往返"""
    print_sep("测试 6: 通过解码器执行完整 CDMA 往返")
    
    size = 256
    src_off = 0x4000
    dst_off = 0x5000
    test_data = np.arange(size, dtype=np.uint8)
    
    write_blob(GLOBAL_BRAM_BASE + src_off, test_data.tobytes())
    write_blob(GLOBAL_BRAM_BASE + dst_off, bytes([0xAA] * size))
    
    # 构建指令序列：global_bram → VPU GB → global_bram
    instructions = [
        encode_cdma_copy(GLOBAL_BRAM_BASE + src_off, VPU_GB_BASE, size),
        encode_wait_cdma(),
        encode_cdma_copy(VPU_GB_BASE, GLOBAL_BRAM_BASE + dst_off, size),
        encode_wait_cdma(),
        encode_end(),
    ]
    inst_bytes = build_instruction_sequence(instructions)
    inst_count = len(inst_bytes) // 4
    
    print(f"指令序列: {inst_count} words")
    print(f"Step 1: 0x{GLOBAL_BRAM_BASE+src_off:08X} → 0x{VPU_GB_BASE:08X}")
    print(f"Step 2: 0x{VPU_GB_BASE:08X} → 0x{GLOBAL_BRAM_BASE+dst_off:08X}")
    
    write_blob(INST_BRAM_BASE, inst_bytes)
    decoder_start(inst_count)
    decoder_wait(timeout=3.0)
    
    # 验证结果
    result = np.frombuffer(read_blob(GLOBAL_BRAM_BASE + dst_off, size), dtype=np.uint8)
    assert np.array_equal(test_data, result), \
        f"Mismatch: expected {test_data[:16]}, got {result[:16]}"
    print(f"✓ 往返搬运成功, 前 16 字节: {result[:16]}")


def main():
    print_sep("VPU 硬件指令解码器测试")
    
    print(f"地址映射:")
    print(f"  Global BRAM: 0x{GLOBAL_BRAM_BASE:08X}")
    print(f"  VPU GB:      0x{VPU_GB_BASE:08X}")
    print(f"  VPU WB:      0x{VPU_WB_BASE:08X}")
    print(f"  Inst BRAM:   0x{INST_BRAM_BASE:08X}")
    print(f"  VPU Regs:    0x{VPU_REGS_BASE:08X}")
    
    try:
        test_inst_bram_rw()
        test_global_bram_rw()
        test_decoder_status()
        test_cdma_via_decoder()
        test_cdma_to_vpu_gb()
        test_cdma_roundtrip()
        print_sep("所有测试通过 ✓")
        return 0
    except Exception as e:
        print_sep(f"测试失败: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
