#!/usr/bin/env python3
"""
VPU 单元测试脚本 - 独立运行，不依赖 Jupyter

测试 US、QA、DQA 单元的功能
"""

import sys
import time
import struct
import numpy as np
from pathlib import Path

# 添加测试模块路径
parent_dir = Path(__file__).parent.resolve()
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

import importlib
import xdma_helpers
importlib.reload(xdma_helpers)

from xdma_helpers import (
    write_blob, read_blob, write_reg, read_reg,
    GLOBAL_BRAM_BASE, INST_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE, VPU_REGS_BASE
)

# 寄存器偏移
REG_STATUS = 0x04
REG_DECODER_CTRL = 0x38
REG_INST_COUNT = 0x3C
REG_DECODER_STATUS = 0x40

# 指令操作码
OP_CDMA_COPY = 0x1
OP_VPU_EXEC = 0x2
OP_WAIT_CDMA = 0x3
OP_WAIT_VPU = 0x4
OP_END = 0xF

# VPU 单元代码
UNIT_DQA = 1
UNIT_NN = 2
UNIT_QA = 3
UNIT_MP = 4
UNIT_US = 5
UNIT_AD = 6


def _make_header(opcode, body_length, flags=0):
    return ((opcode & 0xF) << 28) | ((flags & 0xF) << 24) | (body_length & 0xFFFFFF)


def encode_cdma_copy(src_addr, dst_addr, length):
    header = _make_header(OP_CDMA_COPY, 12)
    return struct.pack('<IIII', header, src_addr, dst_addr, length)


def encode_wait_cdma():
    return struct.pack('<I', _make_header(OP_WAIT_CDMA, 0))


def encode_wait_vpu():
    return struct.pack('<I', _make_header(OP_WAIT_VPU, 0))


def encode_vpu_exec(unit_choose, src_addr, src2_addr, src_c, src_h, src_w,
                    bias_addr, scale_addr, dst_addr, addr_break, addr_s, addr_t):
    header = _make_header(OP_VPU_EXEC, 48)
    return struct.pack('<IIIIIIIIIIIII', header, unit_choose, src_addr, src2_addr,
                       src_c, src_h, src_w, bias_addr, scale_addr, dst_addr,
                       addr_break, addr_s, addr_t)


def encode_end():
    return struct.pack('<I', _make_header(OP_END, 0))


def decoder_start(inst_count):
    write_reg(VPU_REGS_BASE, REG_DECODER_CTRL, 0x00)
    time.sleep(0.001)
    write_reg(VPU_REGS_BASE, REG_INST_COUNT, inst_count)
    write_reg(VPU_REGS_BASE, REG_DECODER_CTRL, 0x01)


def decoder_wait(timeout=10.0):
    deadline = time.time() + timeout
    seen_busy = False
    while time.time() < deadline:
        status = read_reg(VPU_REGS_BASE, REG_DECODER_STATUS)
        busy = status & 0x01
        done = (status >> 1) & 0x01
        error = (status >> 31) & 0x01
        if error:
            raise RuntimeError(f"Decoder error: status=0x{status:08X}")
        if busy:
            seen_busy = True
        if done and not busy:
            return status
        if seen_busy and status == 0:
            return status
        time.sleep(0.001)
    raise TimeoutError(f"Decoder timeout: status=0x{read_reg(VPU_REGS_BASE, REG_DECODER_STATUS):08X}")


def test_us_unit():
    """测试 Upsample 单元"""
    print("=" * 60)
    print("测试 US 单元 (Upsample ×2)")
    print("=" * 60)
    
    # 使用较小的测试尺寸以便快速验证
    US_C, US_H, US_W = 64, 4, 4
    US_OUT_H, US_OUT_W = US_H * 2, US_W * 2
    US_IN_BYTES = US_C * US_H * US_W * 4
    US_OUT_BYTES = US_C * US_OUT_H * US_OUT_W * 4
    
    US_SRC = 0x0000
    US_DST = US_IN_BYTES  # 输出紧跟输入
    GLOBAL_IN = 0x0000
    GLOBAL_OUT = 0x10000
    
    print(f"  输入: C={US_C}, H={US_H}, W={US_W} ({US_IN_BYTES} bytes)")
    print(f"  输出: C={US_C}, H={US_OUT_H}, W={US_OUT_W} ({US_OUT_BYTES} bytes)")
    print(f"  VPU GB: SRC=0x{US_SRC:04X}, DST=0x{US_DST:04X}")
    
    # 生成测试数据 (HWC 格式)
    us_input = np.arange(US_C * US_H * US_W, dtype=np.float32).reshape(US_H, US_W, US_C) / 100.0
    print(f"  输入[0,0,:4] = {us_input[0,0,:4]}")
    
    # 写入数据
    write_blob(GLOBAL_BRAM_BASE + GLOBAL_IN, us_input.tobytes())
    write_blob(GLOBAL_BRAM_BASE + GLOBAL_OUT, np.zeros(US_OUT_BYTES, dtype=np.uint8).tobytes())
    
    # 构建指令
    insts = [
        encode_cdma_copy(GLOBAL_BRAM_BASE + GLOBAL_IN, VPU_GB_BASE + US_SRC, US_IN_BYTES),
        encode_wait_cdma(),
        encode_vpu_exec(UNIT_US, US_SRC, 0, US_C, US_H, US_W, 0, 0, US_DST, 0, 0, 0),
        encode_wait_vpu(),
        encode_cdma_copy(VPU_GB_BASE + US_DST, GLOBAL_BRAM_BASE + GLOBAL_OUT, US_OUT_BYTES),
        encode_wait_cdma(),
        encode_end(),
    ]
    inst_data = b''.join(insts)
    
    # 执行
    write_blob(INST_BRAM_BASE, inst_data)
    decoder_start(len(inst_data) // 4)
    status = decoder_wait(timeout=30.0)
    print(f"  解码器完成: status=0x{status:08X}")
    
    # 读取结果
    result = np.frombuffer(read_blob(GLOBAL_BRAM_BASE + GLOBAL_OUT, US_OUT_BYTES), dtype=np.float32)
    result = result.reshape(US_OUT_H, US_OUT_W, US_C)
    
    # 计算 golden
    golden = np.zeros((US_OUT_H, US_OUT_W, US_C), dtype=np.float32)
    for oh in range(US_OUT_H):
        for ow in range(US_OUT_W):
            golden[oh, ow, :] = us_input[oh // 2, ow // 2, :]
    
    # 比较
    diff = np.abs(result - golden)
    match_rate = np.mean(diff < 1e-5) * 100
    print(f"  匹配率: {match_rate:.2f}%  max_err={diff.max():.4g}")
    print(f"  [0,0] out={result[0,0,:4]} gold={golden[0,0,:4]}")
    print(f"  [0,1] out={result[0,1,:4]} gold={golden[0,1,:4]}")
    print(f"  [1,0] out={result[1,0,:4]} gold={golden[1,0,:4]}")
    
    if match_rate > 99.9:
        print("  ✓ US 测试通过!")
        return True
    else:
        print(f"  ✗ US 测试失败 ({np.sum(diff >= 1e-5)} 元素超差)")
        return False


def test_us_unit_pcie_direct():
    """测试 US 单元 - PCIe 直写 VPU GB（绕过 CDMA）"""
    print("=" * 60)
    print("测试 US 单元 (PCIe 直写 VPU GB)")
    print("=" * 60)
    
    US_C, US_H, US_W = 64, 4, 4
    US_OUT_H, US_OUT_W = US_H * 2, US_W * 2
    US_IN_BYTES = US_C * US_H * US_W * 4
    US_OUT_BYTES = US_C * US_OUT_H * US_OUT_W * 4
    
    US_SRC = 0x0000
    US_DST = US_IN_BYTES
    
    print(f"  输入: C={US_C}, H={US_H}, W={US_W}")
    print(f"  输出: C={US_C}, H={US_OUT_H}, W={US_OUT_W}")
    
    # 生成测试数据
    us_input = np.arange(US_C * US_H * US_W, dtype=np.float32).reshape(US_H, US_W, US_C) / 100.0
    
    # 直接写入 VPU GB
    write_blob(VPU_GB_BASE + US_SRC, us_input.tobytes())
    write_blob(VPU_GB_BASE + US_DST, np.zeros(US_OUT_BYTES, dtype=np.uint8).tobytes())
    
    # 验证写入
    readback = np.frombuffer(read_blob(VPU_GB_BASE + US_SRC, 32), dtype=np.float32)
    print(f"  VPU GB SRC 前8: {readback}")
    
    # 只执行 VPU，不用 CDMA
    insts = [
        encode_vpu_exec(UNIT_US, US_SRC, 0, US_C, US_H, US_W, 0, 0, US_DST, 0, 0, 0),
        encode_wait_vpu(),
        encode_end(),
    ]
    inst_data = b''.join(insts)
    
    write_blob(INST_BRAM_BASE, inst_data)
    decoder_start(len(inst_data) // 4)
    status = decoder_wait(timeout=30.0)
    print(f"  解码器完成: status=0x{status:08X}")
    
    # 直接从 VPU GB 读取结果
    result = np.frombuffer(read_blob(VPU_GB_BASE + US_DST, US_OUT_BYTES), dtype=np.float32)
    result = result.reshape(US_OUT_H, US_OUT_W, US_C)
    
    # 计算 golden
    golden = np.zeros((US_OUT_H, US_OUT_W, US_C), dtype=np.float32)
    for oh in range(US_OUT_H):
        for ow in range(US_OUT_W):
            golden[oh, ow, :] = us_input[oh // 2, ow // 2, :]
    
    diff = np.abs(result - golden)
    match_rate = np.mean(diff < 1e-5) * 100
    print(f"  匹配率: {match_rate:.2f}%  max_err={diff.max():.4g}")
    print(f"  [0,0] out={result[0,0,:4]} gold={golden[0,0,:4]}")
    
    if match_rate > 99.9:
        print("  ✓ US (PCIe直写) 测试通过!")
        return True
    else:
        print(f"  ✗ US (PCIe直写) 测试失败")
        return False


def test_cdma_to_vpu_gb():
    """测试 CDMA 搬运到 VPU GB"""
    print("=" * 60)
    print("测试 CDMA → VPU GB")
    print("=" * 60)
    
    SIZE = 1024  # 1KB
    SRC_OFF = 0x0000
    DST_OFF = 0x0000
    
    # 生成测试数据
    test_data = np.arange(SIZE // 4, dtype=np.float32)
    write_blob(GLOBAL_BRAM_BASE + SRC_OFF, test_data.tobytes())
    write_blob(VPU_GB_BASE + DST_OFF, np.zeros(SIZE, dtype=np.uint8).tobytes())
    
    print(f"  源: global_bram+0x{SRC_OFF:04X}")
    print(f"  目标: VPU_GB+0x{DST_OFF:04X}")
    print(f"  大小: {SIZE} bytes")
    
    # CDMA 搬运
    insts = [
        encode_cdma_copy(GLOBAL_BRAM_BASE + SRC_OFF, VPU_GB_BASE + DST_OFF, SIZE),
        encode_wait_cdma(),
        encode_end(),
    ]
    inst_data = b''.join(insts)
    
    write_blob(INST_BRAM_BASE, inst_data)
    decoder_start(len(inst_data) // 4)
    status = decoder_wait(timeout=10.0)
    print(f"  解码器完成: status=0x{status:08X}")
    
    # 验证
    result = np.frombuffer(read_blob(VPU_GB_BASE + DST_OFF, SIZE), dtype=np.float32)
    
    if np.array_equal(test_data, result):
        print(f"  ✓ CDMA → VPU GB 成功")
        print(f"    前8: {result[:8]}")
        return True
    else:
        diff_idx = np.where(test_data != result)[0]
        print(f"  ✗ CDMA → VPU GB 失败")
        print(f"    不一致: {len(diff_idx)}/{len(test_data)}")
        print(f"    期望前8: {test_data[:8]}")
        print(f"    实际前8: {result[:8]}")
        return False


def main():
    print("\n" + "=" * 60)
    print("VPU 单元测试")
    print("=" * 60)
    print(f"地址映射:")
    print(f"  GLOBAL_BRAM: 0x{GLOBAL_BRAM_BASE:08X}")
    print(f"  INST_BRAM:   0x{INST_BRAM_BASE:08X}")
    print(f"  VPU_GB:      0x{VPU_GB_BASE:08X}")
    print(f"  VPU_WB:      0x{VPU_WB_BASE:08X}")
    print(f"  VPU_REGS:    0x{VPU_REGS_BASE:08X}")
    
    # 检查 VPU 状态
    status = read_reg(VPU_REGS_BASE, REG_STATUS)
    print(f"\nVPU Status: 0x{status:08X} (ready={status & 1})")
    
    results = {}
    
    # 测试 CDMA → VPU GB
    results['cdma_to_gb'] = test_cdma_to_vpu_gb()
    
    # 测试 US (PCIe 直写)
    results['us_pcie'] = test_us_unit_pcie_direct()
    
    # 测试 US (完整流程)
    results['us_full'] = test_us_unit()
    
    # 汇总
    print("\n" + "=" * 60)
    print("测试汇总")
    print("=" * 60)
    for name, passed in results.items():
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"  {name}: {status}")
    
    all_passed = all(results.values())
    print(f"\n总体: {'✓ 全部通过' if all_passed else '✗ 有失败'}")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
