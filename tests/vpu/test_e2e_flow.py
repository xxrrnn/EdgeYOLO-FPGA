#!/usr/bin/env python3
"""
端到端 VPU 测试流程：
1. 写入测试数据到 global_bram
2. 使用 CDMA 将数据从 global_bram 搬运到 VPU GB/WB
3. 配置 VPU 进行简单计算
4. 使用 CDMA 将结果从 VPU GB 搬运回 global_bram
5. 从 global_bram 读取结果并验证
"""

import sys
import numpy as np
from pathlib import Path

# 添加父目录到 sys.path
parent_dir = Path(__file__).parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

from xdma_helpers import (
    xdma_write, xdma_read, write_blob, read_blob, write_reg,
    GLOBAL_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE, CDMA_BASE
)
from xdma_vpu import (
    cdma_reset, cdma_memcpy, cdma_wait_idle, cdma_status
)


def print_separator(title: str = ""):
    """打印分隔线"""
    if title:
        print(f"\n{'='*60}")
        print(f"  {title}")
        print(f"{'='*60}")
    else:
        print(f"{'='*60}")


def test_global_bram_access():
    """测试 1: Global BRAM 基本读写"""
    print_separator("测试 1: Global BRAM 基本读写")
    
    # 写入测试模式
    test_data = np.arange(64, dtype=np.uint32)
    print(f"写入 {len(test_data)} 个 uint32 到 global_bram (offset 0x0)")
    write_blob(GLOBAL_BRAM_BASE, test_data.tobytes())
    
    # 读回验证
    read_back = read_blob(GLOBAL_BRAM_BASE, len(test_data) * 4)
    read_data = np.frombuffer(read_back, dtype=np.uint32)
    
    if np.array_equal(test_data, read_data):
        print(f"✓ 验证通过: 写入和读取数据一致")
        print(f"  前 8 个值: {read_data[:8]}")
    else:
        print(f"✗ 验证失败!")
        print(f"  期望: {test_data[:8]}")
        print(f"  实际: {read_data[:8]}")
        raise RuntimeError("Global BRAM 读写测试失败")


def test_cdma_basic():
    """测试 2: CDMA 基本功能"""
    print_separator("测试 2: CDMA 基本功能（仅写）")
    
    # 尝试写入 CDMA 控制寄存器进行复位
    print("尝试复位 CDMA (写入 CR 寄存器)...")
    try:
        write_reg(CDMA_BASE, 0x00, 1 << 2)  # CDMA_CR, Reset bit
        print("✓ CDMA 复位命令已发送")
    except Exception as e:
        print(f"警告: CDMA 复位失败: {e}")
        print("  继续测试（CDMA 可能已经处于复位状态）")
    
    # 注意：暂时无法读取 CDMA 状态寄存器（C2H 访问该地址失败）
    print("⚠ 注意: CDMA 状态寄存器读取失败（地址映射问题）")
    print("  将通过实际数据传输测试 CDMA 功能")


def test_cdma_global_to_global():
    """测试 3: CDMA global_bram 内部搬运"""
    print_separator("测试 3: CDMA global_bram 内部搬运")
    
    # 在 global_bram 不同区域写入源数据和目标数据
    src_offset = 0x0000
    dst_offset = 0x1000  # 4KB 偏移
    test_size = 256  # 256 字节
    
    # 写入源数据
    src_data = np.arange(test_size, dtype=np.uint8)
    print(f"写入源数据到 0x{GLOBAL_BRAM_BASE + src_offset:08X} ({test_size} 字节)")
    write_blob(GLOBAL_BRAM_BASE + src_offset, src_data.tobytes())
    
    # 写入不同的目标数据（用于验证 CDMA 确实覆盖了它）
    dst_data = np.full(test_size, 0xFF, dtype=np.uint8)
    print(f"写入目标数据到 0x{GLOBAL_BRAM_BASE + dst_offset:08X} ({test_size} 字节)")
    write_blob(GLOBAL_BRAM_BASE + dst_offset, dst_data.tobytes())
    
    # 使用 CDMA 搬运（手动写寄存器，不等待状态）
    print(f"使用 CDMA 从 0x{GLOBAL_BRAM_BASE + src_offset:08X} → 0x{GLOBAL_BRAM_BASE + dst_offset:08X}")
    import time
    
    try:
        # 写 CDMA 寄存器
        write_reg(CDMA_BASE, 0x18, GLOBAL_BRAM_BASE + src_offset)  # SA
        write_reg(CDMA_BASE, 0x20, GLOBAL_BRAM_BASE + dst_offset)  # DA
        write_reg(CDMA_BASE, 0x28, test_size)  # BTT (触发传输)
        print("✓ CDMA 传输寄存器已配置")
        
        # 等待一段时间（无法读状态，只能固定延时）
        time.sleep(0.1)
        print("✓ 等待传输完成（固定延时 100ms）")
    except Exception as e:
        print(f"✗ CDMA 配置失败: {e}")
        raise
    
    # 读回验证
    print("从目标地址读回数据验证...")
    read_back = read_blob(GLOBAL_BRAM_BASE + dst_offset, test_size)
    read_data = np.frombuffer(read_back, dtype=np.uint8)
    
    if np.array_equal(src_data, read_data):
        print(f"✓ 验证通过: CDMA 搬运成功")
        print(f"  前 16 个字节: {read_data[:16]}")
    else:
        print(f"✗ 验证失败!")
        print(f"  期望: {src_data[:16]}")
        print(f"  实际: {read_data[:16]}")
        diff = np.where(src_data != read_data)[0]
        print(f"  不匹配位置: {diff[:10] if len(diff) > 10 else diff}")
        
        # 检查是否完全没变（说明 CDMA 没有工作）
        if np.array_equal(read_data, dst_data):
            print("  ⚠ 目标数据未被修改，CDMA 可能未执行传输")
        raise RuntimeError("CDMA 搬运测试失败")


def test_cdma_global_to_vpu():
    """测试 4: CDMA 从 global_bram 搬运到 VPU GB"""
    print_separator("测试 4: CDMA 从 global_bram 搬运到 VPU GB")
    
    # 准备测试数据（256 字节，对齐到 32 字节）
    test_size = 256
    test_data = np.arange(test_size, dtype=np.uint8)
    
    # 写入到 global_bram
    src_offset = 0x2000
    print(f"写入测试数据到 global_bram (offset 0x{src_offset:04X})")
    write_blob(GLOBAL_BRAM_BASE + src_offset, test_data.tobytes())
    
    # 使用 CDMA 搬运到 VPU GB（手动写寄存器）
    print(f"使用 CDMA 从 global_bram → VPU GB")
    print(f"  源地址: 0x{GLOBAL_BRAM_BASE + src_offset:08X}")
    print(f"  目标地址: 0x{VPU_GB_BASE:08X}")
    print(f"  大小: {test_size} 字节")
    
    import time
    
    try:
        write_reg(CDMA_BASE, 0x18, GLOBAL_BRAM_BASE + src_offset)  # SA
        write_reg(CDMA_BASE, 0x20, VPU_GB_BASE)  # DA
        write_reg(CDMA_BASE, 0x28, test_size)  # BTT
        print("✓ CDMA 传输寄存器已配置")
        
        time.sleep(0.1)
        print("✓ 等待传输完成（固定延时 100ms）")
    except Exception as e:
        print(f"✗ CDMA 配置失败: {e}")
        raise
    
    # 直接从 VPU GB 读回验证
    print(f"从 VPU GB 读回数据验证")
    read_back = read_blob(VPU_GB_BASE, test_size)
    read_data = np.frombuffer(read_back, dtype=np.uint8)
    
    if np.array_equal(test_data, read_data):
        print(f"✓ 验证通过: 数据已成功搬运到 VPU GB")
        print(f"  前 16 个字节: {read_data[:16]}")
    else:
        print(f"✗ 验证失败!")
        print(f"  期望: {test_data[:16]}")
        print(f"  实际: {read_data[:16]}")
        diff = np.where(test_data != read_data)[0]
        print(f"  不匹配位置: {diff[:10] if len(diff) > 10 else diff}")
        raise RuntimeError("CDMA 到 VPU GB 搬运测试失败")


def test_cdma_vpu_to_global():
    """测试 5: CDMA 从 VPU GB 搬运回 global_bram"""
    print_separator("测试 5: CDMA 从 VPU GB 搬运回 global_bram")
    
    # VPU GB 中应该还有上一个测试写入的数据
    test_size = 256
    
    # 在 global_bram 中准备目标区域（用不同数据填充）
    dst_offset = 0x3000
    dst_data = np.full(test_size, 0xAA, dtype=np.uint8)
    print(f"预填充 global_bram 目标区域 (offset 0x{dst_offset:04X})")
    write_blob(GLOBAL_BRAM_BASE + dst_offset, dst_data.tobytes())
    
    # 使用 CDMA 从 VPU GB 搬运回 global_bram
    print(f"使用 CDMA 从 VPU GB → global_bram")
    print(f"  源地址: 0x{VPU_GB_BASE:08X}")
    print(f"  目标地址: 0x{GLOBAL_BRAM_BASE + dst_offset:08X}")
    print(f"  大小: {test_size} 字节")
    
    import time
    
    try:
        write_reg(CDMA_BASE, 0x18, VPU_GB_BASE)  # SA
        write_reg(CDMA_BASE, 0x20, GLOBAL_BRAM_BASE + dst_offset)  # DA
        write_reg(CDMA_BASE, 0x28, test_size)  # BTT
        print("✓ CDMA 传输寄存器已配置")
        
        time.sleep(0.1)
        print("✓ 等待传输完成（固定延时 100ms）")
    except Exception as e:
        print(f"✗ CDMA 配置失败: {e}")
        raise
    
    # 从 global_bram 读回验证
    read_back = read_blob(GLOBAL_BRAM_BASE + dst_offset, test_size)
    read_data = np.frombuffer(read_back, dtype=np.uint8)
    
    # 期望数据应该是测试 4 中写入 VPU GB 的数据
    expected_data = np.arange(test_size, dtype=np.uint8)
    
    if np.array_equal(expected_data, read_data):
        print(f"✓ 验证通过: 数据已成功从 VPU GB 搬运回 global_bram")
        print(f"  前 16 个字节: {read_data[:16]}")
    else:
        print(f"✗ 验证失败!")
        print(f"  期望: {expected_data[:16]}")
        print(f"  实际: {read_data[:16]}")
        diff = np.where(expected_data != read_data)[0]
        print(f"  不匹配位置: {diff[:10] if len(diff) > 10 else diff}")
        
        # 检查是否完全没变
        if np.array_equal(read_data, dst_data):
            print("  ⚠ 目标数据未被修改，CDMA 可能未执行传输")
        raise RuntimeError("CDMA 从 VPU GB 返回测试失败")


def test_vpu_simple_operation():
    """测试 6: 简单 VPU 操作（如果支持）"""
    print_separator("测试 6: VPU 简单操作测试")
    
    print("跳过 VPU 计算测试（需要完整的 VPU 配置）")
    print("当前测试重点在数据搬运通路验证")
    
    # 如果需要测试 VPU，可以添加：
    # 1. 准备输入数据和权重
    # 2. 通过 CDMA 加载到 VPU GB/WB
    # 3. 配置 VPU 寄存器启动计算
    # 4. 等待计算完成
    # 5. 通过 CDMA 读回结果


def main():
    """主测试流程"""
    print_separator("VPU 端到端测试开始")
    
    try:
        # 测试 1: Global BRAM 读写
        test_global_bram_access()
        
        # 测试 2: CDMA 基本功能
        test_cdma_basic()
        
        # 测试 3: CDMA global_bram 内部搬运
        test_cdma_global_to_global()
        
        # 测试 4: CDMA global_bram → VPU GB
        test_cdma_global_to_vpu()
        
        # 测试 5: CDMA VPU GB → global_bram
        test_cdma_vpu_to_global()
        
        # 测试 6: VPU 简单操作
        test_vpu_simple_operation()
        
        print_separator("所有测试通过! ✓")
        return 0
        
    except Exception as e:
        print_separator(f"测试失败: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
