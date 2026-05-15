#!/usr/bin/env python3
"""
端到端 VPU 测试流程（新架构版本）：
1. 测试 global_bram 基本读写
2. 测试 VPU GB/WB 直接读写
3. 测试 VPU 基本操作（通过 VPU_REGS）

注意：新架构中，数据搬运通过以下方式：
- 方式1: 软件直接访问 VPU GB/WB（通过 XDMA）
- 方式2: 使用 INST_BRAM + INST_Decoder 控制 CDMA（推荐）

本测试使用方式1（直接访问），适用于基础功能验证
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
    GLOBAL_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE, VPU_REGS_BASE
)

# VPU寄存器偏移
VPU_REG_CTRL = 0x00         # [0] start
VPU_REG_STATUS = 0x04       # [0] ready
VPU_REG_UNIT_CHOOSE = 0x08
VPU_REG_SRC_ADDR = 0x0C
VPU_REG_SRC2_ADDR = 0x10
VPU_REG_SRC_C = 0x14
VPU_REG_SRC_H = 0x18
VPU_REG_SRC_W = 0x1C
VPU_REG_BIAS_ADDR = 0x20
VPU_REG_SCALE_ADDR = 0x24
VPU_REG_DST_ADDR = 0x28
VPU_REG_ADDR_BREAK = 0x2C
VPU_REG_ADDR_S = 0x30
VPU_REG_ADDR_T = 0x34


def print_sep(title: str = ""):
    if title:
        print(f"\n{'='*60}\n  {title}\n{'='*60}")
    else:
        print("="*60)


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


def test_vpu_gb_direct():
    """测试 2: VPU GB 直接读写（通过 XDMA）"""
    print_sep("测试 2: VPU GB 直接读写")

    size = 256
    test_data = np.arange(size, dtype=np.uint8)

    # 直接写入 VPU GB
    write_blob(VPU_GB_BASE, test_data.tobytes())

    # 直接读取 VPU GB
    result = np.frombuffer(read_blob(VPU_GB_BASE, size), dtype=np.uint8)
    assert np.array_equal(test_data, result), \
        f"Mismatch: expected {test_data[:16]}, got {result[:16]}"
    print(f"✓ VPU GB 读写成功, 前 16 字节: {result[:16]}")


def test_vpu_wb_direct():
    """测试 3: VPU WB 直接读写（通过 XDMA）"""
    print_sep("测试 3: VPU WB 直接读写")

    size = 256
    test_data = np.arange(size, dtype=np.uint8)

    # 直接写入 VPU WB
    write_blob(VPU_WB_BASE, test_data.tobytes())

    # 直接读取 VPU WB
    result = np.frombuffer(read_blob(VPU_WB_BASE, size), dtype=np.uint8)
    assert np.array_equal(test_data, result), \
        f"Mismatch: expected {test_data[:16]}, got {result[:16]}"
    print(f"✓ VPU WB 读写成功, 前 16 字节: {result[:16]}")


def test_vpu_regs():
    """测试 4: VPU 寄存器读写"""
    print_sep("测试 4: VPU 寄存器访问")

    # 读取状态寄存器
    status = read_reg(VPU_REGS_BASE, VPU_REG_STATUS)
    print(f"VPU Status = 0x{status:08X}")
    print(f"✓ VPU 寄存器读取成功")

    # 写入测试配置
    write_reg(VPU_REGS_BASE, VPU_REG_UNIT_CHOOSE, 4)  # MaxPooling
    unit_choose = read_reg(VPU_REGS_BASE, VPU_REG_UNIT_CHOOSE)
    assert unit_choose == 4, f"Unit choose mismatch: expected 4, got {unit_choose}"
    print(f"✓ VPU 寄存器写入成功, UNIT_CHOOSE = {unit_choose}")


def test_data_path():
    """测试 5: 数据路径（global_bram ↔ VPU GB）"""
    print_sep("测试 5: 数据路径测试")

    size = 128
    test_data = np.arange(size, dtype=np.uint8)

    # 写入 global_bram
    write_blob(GLOBAL_BRAM_BASE, test_data.tobytes())
    print(f"✓ 写入 global_bram: {size} 字节")

    # 读取并写入 VPU GB（模拟数据搬运）
    data_from_global = read_blob(GLOBAL_BRAM_BASE, size)
    write_blob(VPU_GB_BASE, data_from_global)
    print(f"✓ 搬运到 VPU GB: {size} 字节")

    # 从 VPU GB 读回
    data_from_vpu = read_blob(VPU_GB_BASE, size)
    result = np.frombuffer(data_from_vpu, dtype=np.uint8)
    
    assert np.array_equal(test_data, result), \
        f"Mismatch: expected {test_data[:16]}, got {result[:16]}"
    print(f"✓ 数据路径验证成功, 前 16 字节: {result[:16]}")


def main():
    print_sep("VPU 端到端测试（新架构）")
    print(f"地址映射:")
    print(f"  Global BRAM: 0x{GLOBAL_BRAM_BASE:08X} (1MB)")
    print(f"  VPU GB:      0x{VPU_GB_BASE:08X} (128KB)")
    print(f"  VPU WB:      0x{VPU_WB_BASE:08X} (128KB)")
    print(f"  VPU Regs:    0x{VPU_REGS_BASE:08X} (4KB)")
    print()
    print("注意：新架构中，CDMA 由 INST_Decoder 控制")
    print("      本测试通过 XDMA 直接访问 VPU GB/WB")

    try:
        test_global_bram()
        test_vpu_gb_direct()
        test_vpu_wb_direct()
        test_vpu_regs()
        test_data_path()
        print_sep("所有测试通过 ✓")
        return 0
    except Exception as e:
        print_sep(f"测试失败: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
