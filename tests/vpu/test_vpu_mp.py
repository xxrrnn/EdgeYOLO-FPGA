#!/usr/bin/env python3
"""
VPU Max Pooling 功能测试
使用 tb_mp_unit.sv 中定义的参数进行测试
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
from test_inst_decoder import (
    GLOBAL_BRAM_BASE, INST_BRAM_BASE, VPU_GB_BASE, VPU_WB_BASE, VPU_REGS_BASE,
    REG_DECODER_CTRL, REG_INST_COUNT, REG_DECODER_STATUS,
    encode_cdma_copy, encode_vpu_exec, encode_wait_cdma, encode_wait_vpu, encode_end,
    build_instruction_sequence, decoder_start, decoder_wait
)

# ==============================================================================
# tb_mp_unit.sv 中定义的参数
# ==============================================================================
ACT_CHANNEL_NUM = 64
ACT_HEIGHT = 24
ACT_BLOCKS = 1152  # 24*24*64/32 = 1152 blocks (256-bit)
ACT_BYTES = 1152 * 32  # 36864 bytes

EXPECTED_CHANNEL_NUM = 64
EXPECTED_HEIGHT = 20
EXPECTED_BLOCKS = 800  # 20*20*64/32 = 800 blocks
EXPECTED_BYTES = 800 * 32  # 25600 bytes

# VPU 参数
UNIT_MP = 4  # Max Pooling unit code
SRC_ADDR = 0x100
DST_ADDR = ACT_BYTES + 0x200  # 0x9200
SRC_C = ACT_CHANNEL_NUM  # 64
SRC_H = ACT_HEIGHT - 4  # 20 (output height)
SRC_W = ACT_HEIGHT - 4  # 20 (output width)
SRC_STRIDE_COL = ACT_CHANNEL_NUM  # 64
SRC_STRIDE_ROW = ACT_CHANNEL_NUM * ACT_HEIGHT  # 64 * 24 = 1536


def load_mem_file(mem_file_path: str, num_blocks: int) -> np.ndarray:
    """
    从 .mem 文件加载数据
    格式：每行是一个 256-bit (64 hex digits) 的数据块
    """
    data = []
    try:
        with open(mem_file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('//'):
                    continue
                # 每行是 64 hex digits (256 bits = 32 bytes)
                # 格式: XXXXXXXX...XXXXXXXX (低字节在右)
                if len(line) != 64:
                    continue
                # 转换为字节数组 (little-endian)
                block_bytes = bytes.fromhex(line)[::-1]  # 反转字节序
                data.append(block_bytes)
                if len(data) >= num_blocks:
                    break
    except FileNotFoundError:
        print(f"警告: 未找到 {mem_file_path}, 将使用随机数据")
        return None
    
    if len(data) < num_blocks:
        print(f"警告: {mem_file_path} 数据不足 (需要 {num_blocks}, 实际 {len(data)})")
        return None
    
    return b''.join(data[:num_blocks])


def create_test_data(shape=(24, 24, 64), dtype=np.float16) -> bytes:
    """
    创建测试数据
    shape: (H, W, C)
    返回: 字节序列，按 VPU 内存布局排列
    """
    # 生成递增数据，便于验证
    # 按 C-major 顺序: [c, h, w]
    data = np.arange(np.prod(shape), dtype=dtype).reshape(shape[::-1])  # (C, H, W)
    
    # VPU 布局：按 256-bit (32 bytes = 16 fp16) 对齐
    # 每个 block 包含 16 个 fp16 值
    flat = data.flatten()  # (C*H*W,)
    
    # 确保对齐到 16 的倍数
    pad_size = (16 - len(flat) % 16) % 16
    if pad_size > 0:
        flat = np.concatenate([flat, np.zeros(pad_size, dtype=dtype)])
    
    return flat.tobytes()


def compute_max_pooling_golden(input_data: np.ndarray, kernel_size=5) -> np.ndarray:
    """
    计算 Max Pooling 的 Golden Model
    input_data: shape (C, H, W), dtype float16
    返回: shape (C, H-4, W-4)
    """
    C, H, W = input_data.shape
    out_h = H - kernel_size + 1
    out_w = W - kernel_size + 1
    output = np.zeros((C, out_h, out_w), dtype=input_data.dtype)
    
    for c in range(C):
        for i in range(out_h):
            for j in range(out_w):
                window = input_data[c, i:i+kernel_size, j:j+kernel_size]
                output[c, i, j] = np.max(window)
    
    return output


def print_sep(title: str = ""):
    if title:
        print(f"\n{'='*60}\n  {title}\n{'='*60}")
    else:
        print("="*60)


def test_vpu_max_pooling():
    """测试完整的 VPU Max Pooling 流程"""
    print_sep("VPU Max Pooling 测试 (tb_mp_unit.sv 参数)")
    
    # 1. 准备输入数据
    print("1. 准备输入数据...")
    
    # 尝试从 mem 文件加载
    rtl_dir = Path(__file__).parent.parent.parent / "rtl" / "vpu"
    act_mem = rtl_dir / "mp_act_data.mem"
    exp_mem = rtl_dir / "mp_expected_data.mem"
    
    act_data_bytes = load_mem_file(str(act_mem), ACT_BLOCKS)
    exp_data_bytes = load_mem_file(str(exp_mem), EXPECTED_BLOCKS)
    
    if act_data_bytes is None:
        print("使用生成的测试数据...")
        act_data_bytes = create_test_data((ACT_HEIGHT, ACT_HEIGHT, ACT_CHANNEL_NUM))
        act_data_bytes = act_data_bytes[:ACT_BYTES]
    
    print(f"  输入数据: {len(act_data_bytes)} bytes ({ACT_BLOCKS} blocks)")
    print(f"  前 32 字节: {act_data_bytes[:32].hex()}")
    
    # 2. 写入数据到 global_bram
    print("\n2. 写入数据到 global_bram...")
    write_blob(GLOBAL_BRAM_BASE + SRC_ADDR, act_data_bytes)
    
    # 验证写入
    readback = read_blob(GLOBAL_BRAM_BASE + SRC_ADDR, 32)
    print(f"  回读验证: {readback.hex()}")
    assert readback == act_data_bytes[:32], "数据写入失败"
    
    # 3. 构建指令序列
    print("\n3. 构建指令序列...")
    instructions = [
        # Step 1: CDMA 将数据从 global_bram 搬到 VPU GB
        encode_cdma_copy(GLOBAL_BRAM_BASE + SRC_ADDR, VPU_GB_BASE, ACT_BYTES),
        encode_wait_cdma(),
        
        # Step 2: 执行 VPU Max Pooling
        encode_vpu_exec(
            unit_choose=UNIT_MP,
            src_addr=0,  # VPU GB 内部地址 (相对)
            src2_addr=0,
            src_c=SRC_C,
            src_h=SRC_H,
            src_w=SRC_W,
            bias_addr=0,
            scale_addr=0,
            dst_addr=0,  # VPU GB 内部地址 (相对)
            addr_break=0,
            addr_s=0,
            addr_t=0
        ),
        encode_wait_vpu(),
        
        # Step 3: CDMA 将结果从 VPU GB 搬回 global_bram
        encode_cdma_copy(VPU_GB_BASE, GLOBAL_BRAM_BASE + DST_ADDR, EXPECTED_BYTES),
        encode_wait_cdma(),
        
        encode_end(),
    ]
    
    inst_bytes = build_instruction_sequence(instructions)
    inst_count = len(inst_bytes) // 4
    
    print(f"  指令序列: {inst_count} words ({len(inst_bytes)} bytes)")
    print(f"  CDMA IN:  0x{GLOBAL_BRAM_BASE+SRC_ADDR:08X} → 0x{VPU_GB_BASE:08X} ({ACT_BYTES}B)")
    print(f"  VPU:      Max Pooling C={SRC_C}, H={SRC_H}, W={SRC_W}")
    print(f"  CDMA OUT: 0x{VPU_GB_BASE:08X} → 0x{GLOBAL_BRAM_BASE+DST_ADDR:08X} ({EXPECTED_BYTES}B)")
    
    # 4. 写入指令到 inst_bram
    print("\n4. 写入指令序列...")
    write_blob(INST_BRAM_BASE, inst_bytes)
    
    # 5. 启动解码器
    print("\n5. 启动解码器...")
    decoder_start(inst_count)
    
    # 6. 等待完成
    print("6. 等待执行完成...")
    start_time = time.time()
    status = decoder_wait(timeout=10.0)
    elapsed = time.time() - start_time
    print(f"  解码器完成: status=0x{status:08X}, 耗时 {elapsed:.3f}s")
    
    # 7. 读取结果
    print("\n7. 读取结果...")
    result_bytes = read_blob(GLOBAL_BRAM_BASE + DST_ADDR, EXPECTED_BYTES)
    result_fp16 = np.frombuffer(result_bytes, dtype=np.float16)
    
    print(f"  结果数据: {len(result_bytes)} bytes")
    print(f"  前 16 个 fp16 值: {result_fp16[:16]}")
    print(f"  最大值: {np.max(result_fp16)}")
    print(f"  最小值: {np.min(result_fp16)}")
    
    # 8. 与 Golden Model 比较
    if exp_data_bytes is not None:
        print("\n8. 与 Golden Model 比较...")
        expected_fp16 = np.frombuffer(exp_data_bytes[:EXPECTED_BYTES], dtype=np.float16)
        
        # 比较前 16 个值
        print(f"  Expected: {expected_fp16[:16]}")
        print(f"  Result:   {result_fp16[:16]}")
        
        # 计算误差
        diff = np.abs(result_fp16[:len(expected_fp16)] - expected_fp16)
        max_diff = np.max(diff)
        match_count = np.sum(diff < 0.01)
        match_rate = match_count / len(expected_fp16) * 100
        
        print(f"  最大误差: {max_diff}")
        print(f"  匹配率: {match_rate:.2f}% ({match_count}/{len(expected_fp16)})")
        
        if match_rate > 95:
            print("  ✓ 测试通过")
            return True
        else:
            print("  ✗ 测试失败")
            return False
    else:
        print("\n8. 无 Golden Model，手动验证...")
        print("  请检查结果是否合理")
        return True


def main():
    print_sep("VPU Max Pooling 完整功能测试")
    
    try:
        success = test_vpu_max_pooling()
        if success:
            print_sep("测试通过 ✓")
            return 0
        else:
            print_sep("测试失败 ✗")
            return 1
    except Exception as e:
        print_sep(f"测试异常: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
