# VPU测试和Python API

本目录包含VPU（Vector Processing Unit）的测试代码和Python API，用于将神经网络操作（MaxPooling、Upsampling等）转换为XDMA硬件指令。

---

## 📁 文件结构

```
tests/vpu/
├── README.md                      # ⭐ 本文档（一站式指南）
├── vpu_operations.py              # ⭐ VPU操作Python API（核心模块）
├── xdma_vpu.py                    # XDMA底层驱动接口
├── examples/                      # 示例代码
│   ├── test_vpu_ops_example.py   #   - VPU操作测试示例
│   ├── test_vpu_units.ipynb      #   - Jupyter交互测试
│   └── im2col.py                  #   - Im2col卷积参考实现
└── docs/                          # 附加文档（可选）
```

**核心文件**（只需关注这3个）:
- `vpu_operations.py` - VPU Python API
- `xdma_vpu.py` - XDMA驱动
- `README.md` - 本文档

---

## 🚀 快速开始

### 1. Mock模式（仅CPU，无需硬件）

适用于算法验证、功能测试：

```bash
cd tests/vpu
./run_test.sh                    # 运行所有测试
./run_test.sh --test maxpool     # 仅测试MaxPooling
```

或者：

```bash
cd tests/vpu/examples
PYTHONPATH=.. python test_vpu_ops_example.py
```

**预期输出**:
```
💻 Mock模式: 仅运行CPU Golden Model

============================================================
测试 Max Pooling 2x2
============================================================
输入形状: (16, 8, 8)
...
✅ ALL 5 TESTS PASSED
```

### 2. 硬件模式（需要FPGA）

适用于实际硬件验证：

```bash
# 使用包装脚本
./run_test.sh --device /dev/xdma0
./run_test.sh --device /dev/xdma0 --test maxpool

# 或直接运行
cd examples
PYTHONPATH=.. python test_vpu_ops_example.py --device /dev/xdma0
```

---

## 💻 Python API使用

### 基础示例

```python
from vpu_operations import create_vpu_operators
import numpy as np

# 创建VPU操作符（Mock模式或硬件模式）
ops = create_vpu_operators("/dev/xdma0")  # 硬件模式
# ops = create_vpu_operators()            # Mock模式

# 1. Max Pooling 2x2
input_data = np.random.randint(-128, 127, size=(32, 64, 64), dtype=np.int8)
output = ops['maxpool'](input_data)
print(f"MaxPool: {input_data.shape} → {output.shape}")
# 输出: MaxPool: (32, 64, 64) → (32, 32, 32)

# 2. Upsampling 2x（最近邻）
input_data = np.random.randint(0, 255, size=(16, 32, 32), dtype=np.uint8)
output = ops['upsample'](input_data)
print(f"Upsample: {input_data.shape} → {output.shape}")
# 输出: Upsample: (16, 32, 32) → (16, 64, 64)

# 3. Element-wise Add (FP32)
a = np.random.randn(16, 32, 32).astype(np.float32)
b = np.random.randn(16, 32, 32).astype(np.float32)
output = ops['add'](a, b)
print(f"Add: {a.shape} + {b.shape} → {output.shape}")

# 4. Quantization (FP32 → INT8)
fp_data = np.random.randn(64, 16, 16).astype(np.float32) * 10.0
output = ops['quantize'](fp_data, scale=12.7)
print(f"Quantize: FP32 → INT8")

# 5. Dequantization (INT32 → FP32)
int_data = np.random.randint(-1000, 1000, size=(64, 16, 16), dtype=np.int32)
scale = np.ones(64, dtype=np.float32) * 0.1
bias = np.zeros(64, dtype=np.float32)
output = ops['dequantize'](int_data, scale, bias)
print(f"Dequantize: INT32 → FP32")

# 清理
ops['device'].close()
```

### 神经网络流水线示例

```python
from vpu_operations import create_vpu_operators
import numpy as np

ops = create_vpu_operators("/dev/xdma0")

# 模拟YOLO特征金字塔网络(FPN)
# P4 (低分辨率) 上采样到 P3 尺度
p4_feature = np.random.randint(0, 255, size=(128, 16, 16), dtype=np.uint8)
p4_upsampled = ops['upsample'](p4_feature)  # → (128, 32, 32)

# 与P3（高分辨率）融合
p3_feature = np.random.randn(128, 32, 32).astype(np.float32) * 50.0
fused = ops['add'](p4_upsampled.astype(np.float32), p3_feature)

# 池化降采样
fused_int8 = np.clip(fused, -128, 127).astype(np.int8)
pooled = ops['maxpool'](fused_int8)  # → (128, 16, 16)

# 量化准备下一层
quantized = ops['quantize'](pooled.astype(np.float32), scale=1.0)

print(f"流水线: {p4_feature.shape} → {quantized.shape}")

ops['device'].close()
```

---

## 🔧 支持的VPU操作

### 1. MaxPooling2D - 最大池化
- **功能**: 2x2最大池化
- **输入**: INT8/UINT8 `[C, H, W]`
- **输出**: INT8/UINT8 `[C, H/2, W/2]`
- **限制**: H和W必须是2的倍数
- **RTL单元**: `UNIT_MP` (4)
- **硬件地址**: `mp_unit.sv`

```python
output = ops['maxpool'](input_data)
```

### 2. Upsampling2D - 上采样
- **功能**: 2x最近邻上采样
- **输入**: INT8/UINT8 `[C, H, W]`
- **输出**: INT8/UINT8 `[C, H*2, W*2]`
- **RTL单元**: `UNIT_US` (5)
- **硬件地址**: `us_unit.sv`

```python
output = ops['upsample'](input_data)
```

### 3. ElementwiseAdd - 逐元素加法
- **功能**: FP32逐元素加法（特征融合）
- **输入**: FP32 `a[N]`, FP32 `b[N]`
- **输出**: FP32 `[N]`
- **RTL单元**: `UNIT_AD` (6)
- **硬件**: 使用fp32_add_array (32个并行加法器)

```python
output = ops['add'](feature_a, feature_b)
```

### 4. Quantization - 量化
- **功能**: FP32 → INT8量化
- **输入**: FP32 `[N]`
- **Scale**: FP32标量
- **输出**: INT8 `[N]`
- **公式**: `output = clip(round(input * scale), -128, 127)`
- **RTL单元**: `UNIT_QA` (3)

```python
output = ops['quantize'](fp_data, scale=12.7)
```

### 5. Dequantization - 反量化
- **功能**: INT32 → FP32反量化
- **输入**: INT32 `[N]`
- **Scale/Bias**: FP32向量
- **输出**: FP32 `[N]`
- **公式**: `output = input * scale + bias`
- **RTL单元**: `UNIT_DQA` (1)

```python
output = ops['dequantize'](int_data, scale, bias)
```

---

## 🎯 典型应用场景

### 场景1: YOLO特征金字塔网络

```python
# P4上采样到P3尺度
p4_upsampled = ops['upsample'](p4_feature)  # 16x16 → 32x32

# 与P3融合
p3_fused = ops['add'](p3_feature, p4_upsampled)

# P3下采样到P5
p5_pooled = ops['maxpool'](p3_fused)  # 32x32 → 16x16
p5_pooled = ops['maxpool'](p5_pooled)  # 16x16 → 8x8
```

### 场景2: 量化感知训练

```python
# 训练时模拟量化过程
fp_activations = model_forward(input)
quantized = ops['quantize'](fp_activations, scale=127.0/max_val)
dequantized = ops['dequantize'](quantized.astype(np.int32), 
                                scale=max_val/127.0, bias=0)
```

### 场景3: 多尺度特征融合

```python
features = []
for scale_factor in [1, 2, 4]:
    if scale_factor == 1:
        features.append(base_feature)
    else:
        # 下采样到不同尺度
        scaled = base_feature
        for _ in range(int(np.log2(scale_factor))):
            scaled = ops['maxpool'](scaled)
        features.append(scaled)
```

---

## 🔍 Golden Model验证

每个操作都包含CPU参考实现（Golden Model），用于验证硬件正确性：

```python
# CPU Golden Model
golden_output = ops['maxpool'].golden(input_data)

# 硬件执行（如果有FPGA）
hw_output = ops['maxpool'](input_data)

# 验证
assert np.array_equal(golden_output, hw_output), "硬件结果不一致!"
print("✅ 硬件验证通过!")
```

---

## 📊 性能预期

### 理论性能（基于250MHz时钟）

| 操作 | 数据规模 | 理论周期数 | 预计延迟 |
|------|---------|-----------|---------|
| MaxPool 2x2 | 32×64×64 | ~16K | ~64μs |
| Upsample 2x | 32×32×32 | ~32K | ~128μs |
| Add (FP32) | 32×32×32 | ~1K | ~4μs |
| Quantize | 64×16×16 | ~512 | ~2μs |

**注**: 实际性能包含PCIe/DMA数据传输开销，需硬件实测。

---

## 🔧 硬件配置

### 地址映射

**地址空间定义** (定义于 `scripts/ip/bd/vpu/address.tcl`)

| 地址 | 大小 | 名称 | 说明 |
|------|------|------|------|
| `0x1000_0000` | 64KB | `GLOBAL_BRAM_BASE` | 主机暂存缓冲区 (staging buffer) |
| `0x1001_0000` | 64KB | `VPU_GB_BASE` | VPU Global Buffer (输入/输出数据) |
| `0x1002_0000` | 64KB | `VPU_WB_BASE` | VPU Weight Buffer (权重/参数/Scale) |
| `0x1003_0000` | 64KB | `CDMA_BASE` | CDMA 寄存器 |
| `0x1004_0000` | 4KB | `VPU_REGS_BASE` | VPU 控制寄存器 |

**注意**: 
- 这些地址在以下文件中保持一致：
  - `scripts/ip/bd/vpu/address.tcl` (Vivado Block Design地址配置)
  - `tests/vpu/xdma_helpers.py` (Python API常量定义)
  - `tests/vpu/README.md` (本文档)
- **修改地址映射的步骤**：
  1. 修改 `scripts/ip/bd/vpu/address.tcl` 中的地址偏移
  2. 同步更新 `tests/vpu/xdma_helpers.py` 中的常量定义
  3. 重新生成 bitstream (`make vpu` 或 `vivado -source scripts/vpu/run.tcl`)
  4. 更新本文档中的地址表
- **当前地址分配说明**：
  - 所有外设统一映射在 `0x1000_0000` ~ `0x1004_1000` 地址空间
  - XDMA 和 CDMA 都可以访问这些地址
  - VPU_GB 和 VPU_WB 的地址需要与 RTL 中的 AXI 接口匹配

### VPU控制寄存器

```
偏移   寄存器         说明
0x00   CTRL          [0] start (写1启动，写0停止)
0x04   STATUS        [0] ready (只读，1=就绪)
0x08   UNIT_CHOOSE   功能单元选择 (1-6)
0x0C   SRC_ADDR      源数据地址
0x10   SRC2_ADDR     源数据地址2 (ADD单元用)
0x14   SRC_C         通道数/元素总数
0x18   SRC_H         高度
0x1C   SRC_W         宽度
0x20   BIAS_ADDR     Bias地址 (DQA单元用)
0x24   SCALE_ADDR    Scale地址
0x28   DST_ADDR      目标数据地址
```

### VPU单元编号

```
1  UNIT_DQA  - 反量化 (INT32 → FP32)
2  UNIT_NN   - NN_LUT (未启用)
3  UNIT_QA   - 量化 (FP32 → INT8)
4  UNIT_MP   - 最大池化 2x2
5  UNIT_US   - 上采样 2x
6  UNIT_AD   - 逐元素加法 (FP32)
```

详细配置请参考: `README_VPU_Test.md`

---

## ⚙️ 硬件前置条件

### 需要的硬件
1. **FPGA板卡**: 已烧录VPU Bitstream
2. **PCIe连接**: FPGA通过PCIe连接到主机
3. **XDMA驱动**: 已加载Xilinx XDMA驱动

### 验证硬件
```bash
# 检查PCIe设备
lspci | grep Xilinx

# 检查XDMA设备
ls -l /dev/xdma*

# 预期输出
/dev/xdma0_h2c_0  # Host-to-Card
/dev/xdma0_c2h_0  # Card-to-Host
```

### 生成Bitstream
```bash
cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-vpu
vivado -mode batch -source scripts/vpu/run.tcl
# Bitstream: build/vpu/vpu.bit
```

---

## 🧪 测试选项

### 测试所有操作
```bash
python test_vpu_ops_example.py
# 或
python test_vpu_ops_example.py --device /dev/xdma0
```

### 测试单个操作
```bash
python test_vpu_ops_example.py --test maxpool     # MaxPooling
python test_vpu_ops_example.py --test upsample    # Upsampling
python test_vpu_ops_example.py --test add         # Add
python test_vpu_ops_example.py --test quantize    # Quantization
python test_vpu_ops_example.py --test pipeline    # 完整流水线
```

### 交互式测试
```bash
cd examples
jupyter notebook test_vpu_units.ipynb
```

---

## ⚠️ 注意事项

### 1. 数据格式
- **INT8**: 有符号8位整数 (-128~127)
- **UINT8**: 无符号8位整数 (0~255)
- **INT32**: 有符号32位整数
- **FP32**: IEEE 754单精度浮点

### 2. 内存限制
- GB/WB各64KB
- 单次操作最大数据量 < 64KB
- 建议数据256位对齐（32字节）

### 3. 数据布局
- NumPy数组使用C顺序（行优先）
- 形状: `[C, H, W]` (Channel, Height, Width)

### 4. 启动流程
```python
# 标准VPU操作流程
1. 写入数据到 GB/WB BRAM
2. 配置VPU寄存器（unit_choose, src_addr, dst_addr等）
3. 启动（CTRL写1→写0）
4. 轮询STATUS直到ready=1
5. 读取结果从 GB BRAM
```

---

## 🐛 故障排除

### 问题1: 设备找不到
```
FileNotFoundError: /dev/xdma0_h2c_0
```
**解决**:
- 确认FPGA已烧录Bitstream
- 检查XDMA驱动: `lspci | grep Xilinx`
- 重新加载驱动: `modprobe xdma`

### 问题2: 操作超时
```
TimeoutError: VPU operation timeout
```
**解决**:
- 检查VPU时钟 (250MHz)
- 查看STATUS寄存器
- 验证数据地址是否正确

### 问题3: 结果不一致
**解决**:
- 使用Golden Model逐步对比
- 检查数据类型（INT8 vs UINT8）
- 验证地址对齐

### 问题4: Mock模式导入错误
**解决**:
```bash
cd tests/vpu
export PYTHONPATH=$PWD:$PYTHONPATH
python test_vpu_ops_example.py
```

---

## 📚 相关文档

- `README_VPU_Test.md` - VPU硬件详细配置
- `../../rtl/vpu/Global_VPU.v` - VPU RTL实现
- `../../FUNCTIONAL_VERIFICATION_STATUS.md` - 功能验证报告
- `../../VPU_PYTHON_API_SUMMARY.md` - API实现总结

---

## 🔄 版本历史

### v1.0 (2026-05-14)
- ✅ 实现MaxPooling, Upsampling, Add, Quantize, Dequantize
- ✅ Mock模式测试通过
- ✅ Golden Model验证
- ✅ 完整文档

### 待实现功能
- [ ] Convolution (通过GEMM)
- [ ] Batch Normalization
- [ ] ReLU/Leaky ReLU
- [ ] Concat (特征拼接)
- [ ] 性能优化（Pipeline, DMA批量传输）

---

## 📧 支持

如有问题或建议，请查看：
1. 本目录下的详细文档
2. RTL源码 (`../../rtl/vpu/`)
3. 功能验证报告

---

**最后更新**: 2026-05-14  
**状态**: Mock模式✅ | 硬件验证⚠️(需FPGA板卡)  
**作者**: VPU开发团队
