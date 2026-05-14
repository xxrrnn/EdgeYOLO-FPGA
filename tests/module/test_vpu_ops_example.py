#!/usr/bin/env python3
"""
VPU神经网络操作测试示例

演示如何将Python中的MaxPooling等操作转换为XDMA指令
可以在Mock模式（仅CPU）或硬件模式下运行
"""

import numpy as np
import argparse
from vpu_operations import create_vpu_operators


def test_maxpooling(ops, use_hardware=False):
    """测试Max Pooling 2x2"""
    print("\n" + "="*60)
    print("测试 Max Pooling 2x2")
    print("="*60)
    
    # 创建测试数据
    C, H, W = 16, 8, 8
    input_data = np.random.randint(-128, 127, size=(C, H, W), dtype=np.int8)
    
    print(f"输入形状: {input_data.shape}")
    print(f"输入数据类型: {input_data.dtype}")
    print(f"输入范围: [{input_data.min()}, {input_data.max()}]")
    
    # CPU Golden Model
    golden_output = ops['maxpool'].golden(input_data)
    print(f"\nGolden输出形状: {golden_output.shape}")
    
    if use_hardware:
        # 硬件执行
        print("\n执行硬件加速...")
        hw_output = ops['maxpool'](input_data)
        
        # 验证
        if np.array_equal(golden_output, hw_output):
            print("✅ 硬件结果与Golden Model一致!")
        else:
            diff = np.abs(golden_output.astype(np.int32) - hw_output.astype(np.int32))
            print(f"❌ 硬件结果不一致! 最大差异: {diff.max()}")
    else:
        print("\n(Mock模式 - 仅运行CPU Golden Model)")
    
    return golden_output


def test_upsampling(ops, use_hardware=False):
    """测试Upsampling 2x"""
    print("\n" + "="*60)
    print("测试 Upsampling 2x (最近邻)")
    print("="*60)
    
    # 创建测试数据
    C, H, W = 32, 4, 4
    input_data = np.random.randint(0, 255, size=(C, H, W), dtype=np.uint8)
    
    print(f"输入形状: {input_data.shape}")
    print(f"输入数据类型: {input_data.dtype}")
    
    # CPU Golden Model
    golden_output = ops['upsample'].golden(input_data)
    print(f"\nGolden输出形状: {golden_output.shape}")
    
    if use_hardware:
        # 硬件执行
        print("\n执行硬件加速...")
        hw_output = ops['upsample'](input_data)
        
        # 验证
        if np.array_equal(golden_output, hw_output):
            print("✅ 硬件结果与Golden Model一致!")
        else:
            print(f"❌ 硬件结果不一致!")
    else:
        print("\n(Mock模式 - 仅运行CPU Golden Model)")
    
    return golden_output


def test_elementwise_add(ops, use_hardware=False):
    """测试Element-wise Addition (FP32)"""
    print("\n" + "="*60)
    print("测试 Element-wise Add (FP32)")
    print("="*60)
    
    # 创建测试数据
    shape = (16, 32, 32)  # [C, H, W]
    input_a = np.random.randn(*shape).astype(np.float32)
    input_b = np.random.randn(*shape).astype(np.float32)
    
    print(f"输入A形状: {input_a.shape}, 范围: [{input_a.min():.3f}, {input_a.max():.3f}]")
    print(f"输入B形状: {input_b.shape}, 范围: [{input_b.min():.3f}, {input_b.max():.3f}]")
    
    # CPU Golden Model
    golden_output = ops['add'].golden(input_a, input_b)
    print(f"\nGolden输出范围: [{golden_output.min():.3f}, {golden_output.max():.3f}]")
    
    if use_hardware:
        # 硬件执行
        print("\n执行硬件加速...")
        hw_output = ops['add'](input_a, input_b)
        
        # 验证（FP32允许微小误差）
        diff = np.abs(golden_output - hw_output)
        max_diff = diff.max()
        print(f"最大差异: {max_diff}")
        
        if max_diff < 1e-5:
            print("✅ 硬件结果与Golden Model一致!")
        else:
            print(f"⚠️  硬件结果有微小差异（FP32精度）")
    else:
        print("\n(Mock模式 - 仅运行CPU Golden Model)")
    
    return golden_output


def test_quantization(ops, use_hardware=False):
    """测试Quantization (FP32 → INT8)"""
    print("\n" + "="*60)
    print("测试 Quantization (FP32 → INT8)")
    print("="*60)
    
    # 创建测试数据
    shape = (64, 16, 16)
    input_data = np.random.randn(*shape).astype(np.float32) * 10.0
    scale = 12.7  # INT8量化常用scale (127/10)
    
    print(f"输入形状: {input_data.shape}")
    print(f"输入范围: [{input_data.min():.3f}, {input_data.max():.3f}]")
    print(f"Scale: {scale}")
    
    # CPU Golden Model
    golden_output = ops['quantize'].golden(input_data, scale)
    print(f"\nGolden输出范围: [{golden_output.min()}, {golden_output.max()}]")
    print(f"Golden输出数据类型: {golden_output.dtype}")
    
    if use_hardware:
        # 硬件执行
        print("\n执行硬件加速...")
        hw_output = ops['quantize'](input_data, scale)
        
        # 验证
        diff = np.abs(golden_output.astype(np.int32) - hw_output.astype(np.int32))
        max_diff = diff.max()
        print(f"最大差异: {max_diff}")
        
        if max_diff <= 1:  # 允许±1的量化误差
            print("✅ 硬件结果与Golden Model一致!")
        else:
            print(f"❌ 硬件结果差异过大!")
    else:
        print("\n(Mock模式 - 仅运行CPU Golden Model)")
    
    return golden_output


def test_neural_network_pipeline(ops, use_hardware=False):
    """测试完整的神经网络流水线"""
    print("\n" + "="*60)
    print("测试神经网络流水线组合")
    print("="*60)
    print("流程: Upsampling → Add → MaxPooling → Quantization")
    
    # 1. Upsampling
    print("\n[1/4] Upsampling 2x...")
    C, H, W = 32, 8, 8
    feature_map = np.random.randint(0, 255, size=(C, H, W), dtype=np.uint8)
    upsampled = ops['upsample'].golden(feature_map)
    print(f"   {feature_map.shape} → {upsampled.shape}")
    
    # 转换为FP32用于后续操作
    upsampled_fp = upsampled.astype(np.float32)
    
    # 2. Element-wise Add (融合特征)
    print("\n[2/4] Element-wise Add (特征融合)...")
    feature_map2 = np.random.randn(*upsampled_fp.shape).astype(np.float32) * 50.0
    fused = ops['add'].golden(upsampled_fp, feature_map2)
    print(f"   {upsampled_fp.shape} + {feature_map2.shape} → {fused.shape}")
    print(f"   输出范围: [{fused.min():.2f}, {fused.max():.2f}]")
    
    # 3. Max Pooling (转回INT8)
    print("\n[3/4] Max Pooling 2x2...")
    fused_int8 = np.clip(fused, -128, 127).astype(np.int8)
    pooled = ops['maxpool'].golden(fused_int8)
    print(f"   {fused_int8.shape} → {pooled.shape}")
    
    # 4. Quantization (准备下一层)
    print("\n[4/4] Quantization (FP32 → INT8)...")
    final_fp = pooled.astype(np.float32)
    quantized = ops['quantize'].golden(final_fp, scale=1.0)
    print(f"   {final_fp.shape} → {quantized.shape}")
    print(f"   最终输出范围: [{quantized.min()}, {quantized.max()}]")
    
    print("\n✅ 流水线测试完成!")
    print(f"原始输入: {feature_map.shape} (UINT8)")
    print(f"最终输出: {quantized.shape} (INT8)")
    
    return quantized


def main():
    parser = argparse.ArgumentParser(description="VPU操作测试")
    parser.add_argument('--device', type=str, default=None,
                      help='XDMA设备路径，例如 /dev/xdma0 (留空则仅运行Mock)')
    parser.add_argument('--test', choices=['all', 'maxpool', 'upsample', 'add', 
                                          'quantize', 'pipeline'],
                      default='all', help='选择测试项')
    args = parser.parse_args()
    
    # 创建VPU操作符
    use_hardware = args.device is not None
    
    if use_hardware:
        print(f"🔧 硬件模式: {args.device}")
        ops = create_vpu_operators(args.device)
    else:
        print("💻 Mock模式: 仅运行CPU Golden Model")
        ops = {
            'maxpool': type('MaxPool', (), {'golden': lambda self, x: x})(),
            'upsample': type('Upsample', (), {'golden': lambda self, x: x})(),
            'add': type('Add', (), {'golden': lambda self, a, b: a+b})(),
            'quantize': type('Quantize', (), {
                'golden': lambda self, x, s: np.clip(np.round(x*s), -128, 127).astype(np.int8)
            })(),
        }
        # 使用实际实现的golden函数
        from vpu_operations import MaxPooling2D, Upsampling2D, ElementwiseAdd, Quantization
        ops['maxpool'] = type('MaxPool', (), {'golden': MaxPooling2D(None).golden})()
        ops['upsample'] = type('Upsample', (), {'golden': Upsampling2D(None).golden})()
        ops['add'] = type('Add', (), {'golden': ElementwiseAdd(None).golden})()
        ops['quantize'] = type('Quantize', (), {'golden': Quantization(None).golden})()
    
    # 运行测试
    tests = {
        'maxpool': test_maxpooling,
        'upsample': test_upsampling,
        'add': test_elementwise_add,
        'quantize': test_quantization,
        'pipeline': test_neural_network_pipeline,
    }
    
    if args.test == 'all':
        for name, test_fn in tests.items():
            try:
                test_fn(ops, use_hardware)
            except Exception as e:
                print(f"\n❌ 测试 {name} 失败: {e}")
    else:
        tests[args.test](ops, use_hardware)
    
    # 清理
    if use_hardware:
        ops['device'].close()
    
    print("\n" + "="*60)
    print("测试完成!")
    print("="*60)


if __name__ == "__main__":
    main()
