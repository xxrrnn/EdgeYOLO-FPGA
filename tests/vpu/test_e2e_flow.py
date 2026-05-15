#!/usr/bin/env python3
"""
端到端 VPU 测试流程：
1. 写入测试数据到 global_bram
2. 使用 CDMA 将数据从 global_bram 搬运到 VPU GB/WB
3. 使用 CDMA 将数据从 VPU GB 搬运回 global_bram
4. 从 global_bram 读取结果并验证
"""

import sys
import time
import numpy as np
from pathlib import Path

parent_dir = Path(__file__).parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

from xdma_helpers import (
    write_blob, read_blob, write_reg, read_reg,
    GLOBAL_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE, CDMA_BASE, VPU_REGS_BASE
)

# CDMA 寄存器偏移
CDMA_CR  = 0x00
CDMA_SR  = 0x04
CDMA_SA  = 0x18
CDMA_DA  = 0x20
CDMA_BTT = 0x28


def print_sep(title: str = ""):
    if title:
        print(f"\n{'='*60}\n  {title}\n{'='*60}")
    else:
        print("="*60)


def cdma_reset():
    """复位 CDMA 并等待就绪"""
    write_reg(CDMA_BASE, CDMA_CR, 0x04)  # Reset
    time.sleep(0.01)
    write_reg(CDMA_BASE, CDMA_CR, 0x01)  # Enable, no SG


def cdma_transfer(src: int, dst: int, nbytes: int, timeout: float = 1.0):
    """执行 CDMA 传输并等待完成"""
    write_reg(CDMA_BASE, CDMA_SA, src)
    write_reg(CDMA_BASE, CDMA_DA, dst)
    write_reg(CDMA_BASE, CDMA_BTT, nbytes)

    deadline = time.time() + timeout
    while time.time() < deadline:
        sr = read_reg(CDMA_BASE, CDMA_SR)
        if sr & 0x02:  # Idle bit
            return sr
        if sr & 0x4070:  # Error bits
            raise RuntimeError(f"CDMA error: SR=0x{sr:08X}")
        time.sleep(0.001)
    raise TimeoutError(f"CDMA transfer timeout (SR=0x{read_reg(CDMA_BASE, CDMA_SR):08X})")


def test_global_bram():
    """测试 1: Global BRAM 基本读写"""
    print_sep("测试 1: Global BRAM 基本读写")

    test_data = np.arange(64, dtype=np.uint32)
    write_blob(GLOBAL_BRAM_BASE, test_data.tobytes())

    read_back = read_blob(GLOBAL_BRAM_BASE, len(test_data) * 4)
    read_data = np.frombuffer(read_back, dtype=np.uint32)

    assert np.array_equal(test_data, read_data), \
        f"Mismatch: expected {test_data[:8]}, got {read_data[:8]}"
    print(f"✓ 读写一致, 前 8 值: {read_data[:8]}")


def test_cdma_status():
    """测试 2: CDMA 复位与状态读取"""
    print_sep("测试 2: CDMA 复位与状态")

    cdma_reset()
    sr = read_reg(CDMA_BASE, CDMA_SR)
    print(f"CDMA SR = 0x{sr:08X}")
    assert sr & 0x02, f"CDMA not idle after reset: SR=0x{sr:08X}"
    print("✓ CDMA 复位成功，处于 Idle 状态")


def test_cdma_bram_to_bram():
    """测试 3: CDMA 在 global_bram 内搬运"""
    print_sep("测试 3: CDMA global_bram 内部搬运")

    src_off, dst_off, size = 0x0000, 0x1000, 256

    src_data = np.arange(size, dtype=np.uint8)
    dst_fill = np.full(size, 0xFF, dtype=np.uint8)

    write_blob(GLOBAL_BRAM_BASE + src_off, src_data.tobytes())
    write_blob(GLOBAL_BRAM_BASE + dst_off, dst_fill.tobytes())

    print(f"CDMA: 0x{GLOBAL_BRAM_BASE+src_off:08X} → 0x{GLOBAL_BRAM_BASE+dst_off:08X} ({size}B)")
    cdma_transfer(GLOBAL_BRAM_BASE + src_off, GLOBAL_BRAM_BASE + dst_off, size)

    result = np.frombuffer(read_blob(GLOBAL_BRAM_BASE + dst_off, size), dtype=np.uint8)
    assert np.array_equal(src_data, result), \
        f"Mismatch: expected {src_data[:16]}, got {result[:16]}"
    print(f"✓ 搬运成功, 前 16 字节: {result[:16]}")


def test_cdma_to_vpu_gb():
    """测试 4: CDMA global_bram → VPU GB"""
    print_sep("测试 4: CDMA global_bram → VPU GB")

    size = 256
    src_off = 0x2000
    test_data = np.arange(size, dtype=np.uint8)

    write_blob(GLOBAL_BRAM_BASE + src_off, test_data.tobytes())

    print(f"CDMA: 0x{GLOBAL_BRAM_BASE+src_off:08X} → 0x{VPU_GB_BASE:08X} ({size}B)")
    cdma_transfer(GLOBAL_BRAM_BASE + src_off, VPU_GB_BASE, size)

    result = np.frombuffer(read_blob(VPU_GB_BASE, size), dtype=np.uint8)
    assert np.array_equal(test_data, result), \
        f"Mismatch: expected {test_data[:16]}, got {result[:16]}"
    print(f"✓ VPU GB 数据正确, 前 16 字节: {result[:16]}")


def test_cdma_from_vpu_gb():
    """测试 5: CDMA VPU GB → global_bram"""
    print_sep("测试 5: CDMA VPU GB → global_bram")

    size = 256
    dst_off = 0x3000
    expected = np.arange(size, dtype=np.uint8)  # 测试 4 写入的数据

    write_blob(GLOBAL_BRAM_BASE + dst_off, bytes([0xAA] * size))

    print(f"CDMA: 0x{VPU_GB_BASE:08X} → 0x{GLOBAL_BRAM_BASE+dst_off:08X} ({size}B)")
    cdma_transfer(VPU_GB_BASE, GLOBAL_BRAM_BASE + dst_off, size)

    result = np.frombuffer(read_blob(GLOBAL_BRAM_BASE + dst_off, size), dtype=np.uint8)
    assert np.array_equal(expected, result), \
        f"Mismatch: expected {expected[:16]}, got {result[:16]}"
    print(f"✓ VPU GB → global_bram 成功, 前 16 字节: {result[:16]}")


def main():
    print_sep("VPU 端到端测试")
    print(f"地址映射:")
    print(f"  Global BRAM: 0x{GLOBAL_BRAM_BASE:08X}")
    print(f"  VPU GB:      0x{VPU_GB_BASE:08X}")
    print(f"  VPU WB:      0x{VPU_WB_BASE:08X}")
    print(f"  CDMA:        0x{CDMA_BASE:08X}")
    print(f"  VPU Regs:    0x{VPU_REGS_BASE:08X}")

    try:
        test_global_bram()
        test_cdma_status()
        test_cdma_bram_to_bram()
        test_cdma_to_vpu_gb()
        test_cdma_from_vpu_gb()
        print_sep("所有测试通过 ✓")
        return 0
    except Exception as e:
        print_sep(f"测试失败: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
