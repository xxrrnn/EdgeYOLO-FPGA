# VPU神经网络操作API使用指南

本目录包含将Python神经网络操作（MaxPooling, Upsampling等）转换为XDMA指令的API。

## 📁 文件结构

```
tests/module/
├── vpu_operations.py         # VPU操作API（核心）
├── test_vpu_ops_example.py   # 使用示例和测试
├── xdma_vpu.py               # XDMA底层驱动（已有）
└── README_VPU_Operations.md  # 本文档
```

## 🚀 快速开始

### 1. Mock模式（仅CPU Golden Model）

适用于：
- 没有FPGA硬件
- 算法验证
- 功能测试

```bash
cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-vpu/tests/module
python test_vpu_ops_example.py
```

### 2. 硬件模式（需要FPGA）

适用于：
- 实际硬件验证
- 性能测试
- 调试FPGA实现

```bash
# 测试所有操作
python test_vpu_ops_example.py --device /dev/xdma0

# 仅测试MaxPooling
python test_vpu_ops_example.py --device /dev/xdma0 --test maxpool

# 测试完整流水线
python test_vpu_ops_example.py --device /dev/xdma0 --test pipeline
```

## 💡 API使用示例

### 基本用法

```python
from vpu_operations import create_vpu_operators
import numpy as np

# 创建VPU操作符
ops = create_vpu_operators("/dev/xdma0")

# 1. Max Pooling 2x2
input_data = np.random.randint(-128, 127, size=(32, 64, 64), dtype=np.int8)
output = ops['maxpool'](input_data)
print(f"MaxPool: {input_data.shape} → {output.shape}")

# 2. Upsampling 2x
input_data = np.random.randint(0, 255, size=(16, 32, 32), dtype=np.uint8)
output = ops['upsample'](input_data)
print(f"Upsample: {input_data.shape} → {output.shape}")

# 3. Element-wise Add (FP32)
a = np.random.randn(16, 32, 32).astype(np.float32)
b = np.random.randn(16, 32, 32).astype(np.float32)
output = ops['add'](a, b)
print(f"Add: {a.shape} + {b.shape} → {output.shape}")

# 4. Quantization (FP32 → INT8)
fp_data = np.random.randn(64, 16, 16).astype(np.float32) * 10.0
output = ops['quantize'](fp_data, scale=12.7)
print(f"Quantize: {fp_data.shape} (FP32) → {output.shape} (INT8)")

# 5. Dequantization (INT32 → FP32)
int_data = np.random.randint(-1000, 1000, size=(64, 16, 16), dtype=np.int32)
scale = np.ones(64, dtype=np.float32) * 0.1
bias = np.zeros(64, dtype=np.float32)
output = ops['dequantize'](int_data, scale, bias)
print(f"Dequantize: {int_data.shape} (INT32) → {output.shape} (FP32)")

# 清理
ops['device'].close()
```

### 神经网络流水线示例

```python
from vpu_operations import create_vpu_operators
import numpy as np

ops = create_vpu_operators("/dev/xdma0")

# 模拟YOLO特征融合路径
# Stage 1: 低分辨率特征上采样
low_res_feature = np.random.randint(0, 255, size=(128, 16, 16), dtype=np.uint8)
upsampled = ops['upsample'](low_res_feature)  # → (128, 32, 32)

# Stage 2: 与高分辨率特征融合
high_res_feature = np.random.randn(128, 32, 32).astype(np.float32) * 50.0
fused = ops['add'](upsampled.astype(np.float32), high_res_feature)

# Stage 3: 池化降采样
pooled_int8 = np.clip(fused, -128, 127).astype(np.int8)
pooled = ops['maxpool'](pooled_int8)  # → (128, 16, 16)

# Stage 4: 量化准备下一层
quantized = ops['quantize'](pooled.astype(np.float32), scale=1.0)

print(f"流水线: {low_res_feature.shape} → {quantized.shape}")

ops['device'].close()
```

## 📚 支持的操作

### 1. MaxPooling2D
- **功能**: 2x2最大池化
- **输入**: INT8/UINT8 `[C, H, W]`
- **输出**: INT8/UINT8 `[C, H/2, W/2]`
- **限制**: H和W必须是2的倍数
- **RTL单元**: `UNIT_MP` (4)

### 2. Upsampling2D
- **功能**: 2x最近邻上采样
- **输入**: INT8/UINT8 `[C, H, W]`
- **输出**: INT8/UINT8 `[C, H*2, W*2]`
- **RTL单元**: `UNIT_US` (5)

### 3. ElementwiseAdd
- **功能**: FP32逐元素加法
- **输入**: FP32 `a[N]`, FP32 `b[N]`
- **输出**: FP32 `[N]`
- **限制**: 使用fp32_add_array (32个并行加法器)
- **RTL单元**: `UNIT_AD` (6)

### 4. Quantization
- **功能**: FP32 → INT8量化
- **输入**: FP32 `[N]`
- **Scale**: FP32 标量
- **输出**: INT8 `[N]`
- **公式**: `output = clip(round(input * scale), -128, 127)`
- **RTL单元**: `UNIT_QA` (3)

### 5. Dequantization
- **功能**: INT32 → FP32反量化
- **输入**: INT32 `[N]`
- **Scale/Bias**: FP32向量
- **输出**: FP32 `[N]`
- **公式**: `output = input * scale + bias`
- **RTL单元**: `UNIT_DQA` (1)

## 🔧 地址映射

```
0x1000_0000  GLOBAL_BRAM (64KB)  - 主机暂存缓冲区
0x1001_0000  VPU_GB (64KB)       - Global Buffer (输入/输出)
0x1002_0000  VPU_WB (64KB)       - Weight Buffer (权重/参数)
0x1003_0000  CDMA (64KB)         - CDMA寄存器
0x1004_0000  VPU_REGS (4KB)      - VPU控制寄存器
```

### VPU寄存器偏移

```
0x00  CTRL         - [0] start (写1启动)
0x04  STATUS       - [0] ready (只读)
0x08  UNIT_CHOOSE  - 功能单元选择
0x0C  SRC_ADDR     - 源地址
0x10  SRC2_ADDR    - 源地址2 (AD单元用)
0x14  SRC_C        - 通道数/元素数
0x18  SRC_H        - 高度
0x1C  SRC_W        - 宽度
0x20  BIAS_ADDR    - Bias地址 (DQA用)
0x24  SCALE_ADDR   - Scale地址
0x28  DST_ADDR     - 目标地址
```

## 🎯 典型应用场景

### 1. YOLO特征金字塔网络(FPN)

```python
# P3 (高分辨率) + P4 (上采样)
p4_upsampled = ops['upsample'](p4_feature)  # 16x16 → 32x32
p3_fused = ops['add'](p3_feature, p4_upsampled)
```

### 2. 目标检测后处理

```python
# 多尺度特征融合
for scale in [8, 16, 32]:
    feature = ops['maxpool'](raw_feature, pool_size=scale//8)
    features.append(feature)
```

### 3. 量化感知训练(QAT)

```python
# 训练时模拟量化
fp_activations = model_forward(input)
quantized = ops['quantize'](fp_activations, scale=127.0/max_val)
dequantized = ops['dequantize'](quantized.astype(np.int32), 
                                scale=max_val/127.0, bias=0)
```

## ⚠️ 注意事项

### 1. 数据对齐
- BRAM地址建议256位对齐（32字节）
- 大批量数据传输性能更好

### 2. 数据格式
- INT8/UINT8: 1 byte per element
- INT32: 4 bytes per element
- FP32: 4 bytes per element (IEEE 754)

### 3. 内存限制
- GB/WB各64KB
- 单次操作最大数据量 < 64KB

### 4. 启动流程
```python
# 1. 写入数据到 GB/WB BRAM
device.write_bram(VPU_GB_BASE, 0, input_data.tobytes())

# 2. 配置寄存器
device.write_u32(VPU_REGS_BASE + VPU_REG_UNIT_CHOOSE, UNIT_MP)
device.write_u32(VPU_REGS_BASE + VPU_REG_SRC_ADDR, 0x0)
# ... 其他配置

# 3. 启动
device.write_u32(VPU_REGS_BASE + VPU_REG_CTRL, 1)
time.sleep(0.001)
device.write_u32(VPU_REGS_BASE + VPU_REG_CTRL, 0)

# 4. 等待完成
while not (device.read_u32(VPU_REGS_BASE + VPU_REG_STATUS) & 0x1):
    time.sleep(0.001)

# 5. 读取结果
output_data = device.read_bram(VPU_GB_BASE, 0x8000, output_size)
```

## 🧪 测试和验证

### 运行所有测试
```bash
python test_vpu_ops_example.py --device /dev/xdma0 --test all
```

### 单独测试每个操作
```bash
# MaxPooling
python test_vpu_ops_example.py --device /dev/xdma0 --test maxpool

# Upsampling
python test_vpu_ops_example.py --device /dev/xdma0 --test upsample

# Element-wise Add
python test_vpu_ops_example.py --device /dev/xdma0 --test add

# Quantization
python test_vpu_ops_example.py --device /dev/xdma0 --test quantize

# 完整流水线
python test_vpu_ops_example.py --device /dev/xdma0 --test pipeline
```

### Golden Model验证
每个操作都包含CPU参考实现，用于验证硬件正确性：
```python
# 使用Golden Model
golden_output = ops['maxpool'].golden(input_data)

# 硬件执行
hw_output = ops['maxpool'](input_data)

# 比对
assert np.array_equal(golden_output, hw_output), "结果不一致!"
```

## 📖 相关文档

- `tests/vpu/README_VPU_Test.md` - VPU硬件配置说明
- `rtl/vpu/Global_VPU.v` - VPU RTL实现
- `FUNCTIONAL_VERIFICATION_STATUS.md` - 功能验证状态

## 🐛 故障排除

### 问题1: 设备找不到
```
FileNotFoundError: [Errno 2] No such file or directory: '/dev/xdma0_h2c_0'
```
**解决**: 
- 确认FPGA已烧录Bitstream
- 检查XDMA驱动是否加载: `lspci | grep Xilinx`

### 问题2: 操作超时
```
TimeoutError: VPU operation timeout
```
**解决**:
- 检查VPU时钟是否正常
- 查看VPU_REG_STATUS寄存器状态
- 确认数据地址配置正确

### 问题3: 结果不一致
**解决**:
- 使用Golden Model对比每一步
- 检查数据格式(INT8/FP32)
- 验证地址对齐

## 🔄 后续扩展

### 计划支持的操作
- [ ] Convolution (使用GEMM)
- [ ] Batch Normalization
- [ ] ReLU/Leaky ReLU
- [ ] Concat (特征拼接)
- [ ] Reshape/Permute

### 性能优化
- [ ] Pipeline多个操作
- [ ] DMA批量传输
- [ ] 异步执行
- [ ] 多VPU并行

---

**更新时间**: 2026-05-14  
**作者**: VPU开发团队
