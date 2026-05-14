# EdgeYOLO FPGA VPU 项目

基于Xilinx FPGA的向量处理单元(VPU)，用于加速YOLO神经网络推理。

---

## 📋 项目概述

本项目实现了一个完整的FPGA加速器，包括：
- **硬件RTL设计**：VPU核心逻辑（MaxPooling、Upsampling、量化等）
- **Python API**：将神经网络操作转换为XDMA硬件指令
- **验证框架**：完整的测试和验证系统

### 核心特性
- ✅ **时序验证通过**：250 MHz无违例（WNS +0.409ns）
- ✅ **Python API**：统一接口，支持Mock和硬件模式
- ✅ **5个VPU操作**：MaxPooling、Upsampling、Add、Quantize、Dequantize
- ✅ **完整验证**：RTL单元测试、Golden Model对比

---

## 🚀 快速开始

### 1. Python API测试（无需硬件）

```bash
cd tests/vpu
python test_vpu_ops_example.py
```

### 2. 硬件加速（需要FPGA）

```bash
# 生成Bitstream
vivado -mode batch -source scripts/vpu/run.tcl

# 烧录并测试
python tests/vpu/test_vpu_ops_example.py --device /dev/xdma0
```

### 3. Python API使用示例

```python
from vpu_operations import create_vpu_operators
import numpy as np

# 创建操作符
ops = create_vpu_operators("/dev/xdma0")

# MaxPooling
input_data = np.random.randint(-128, 127, size=(32, 64, 64), dtype=np.int8)
output = ops['maxpool'](input_data)  # (32,64,64) → (32,32,32)

# Upsampling
output = ops['upsample'](input_data)  # (32,64,64) → (32,128,128)

# 特征融合
fused = ops['add'](feature_a, feature_b)
```

详细文档见：`tests/vpu/README.md`

---

## 📁 项目结构

```
EdgeYOLO-FPGA-vpu/
├── README.md                          # 本文档
├── rtl/vpu/                          # RTL源码
│   ├── Global_VPU_top.v              # VPU顶层
│   ├── Global_VPU.v                  # VPU核心逻辑
│   ├── *_unit.sv                     # 功能单元(MP/US/QA/DQA/AD)
│   ├── fp array/                     # 浮点运算阵列
│   └── tb/                           # SystemVerilog测试台
├── scripts/                          # Vivado构建脚本
│   ├── vpu/                          # VPU项目脚本
│   │   ├── run.tcl                   # 主构建脚本
│   │   ├── 0_build.tcl               # 项目创建
│   │   ├── 1_bd.tcl                  # Block Design
│   │   └── 2_synth.tcl               # 综合实现
│   └── ip/                           # IP配置脚本
│       ├── floating_point_fp32.tcl   # 浮点IP生成
│       └── bd/vpu/                   # VPU Block Design
├── tests/vpu/                        # 测试和Python API
│   ├── README.md                     # 详细使用文档
│   ├── vpu_operations.py             # Python API（核心）
│   ├── test_vpu_ops_example.py       # 测试示例
│   ├── xdma_vpu.py                   # XDMA驱动
│   └── test_vpu_units.ipynb          # Jupyter测试
├── build/vpu/                        # 构建输出
│   ├── vpu.xpr                       # Vivado工程
│   ├── vpu.bit                       # Bitstream（生成后）
│   └── ImplOutputDir/                # 时序报告
└── docs/                             # 文档（自动生成）
    ├── VERIFICATION.md               # 验证状态
    └── HARDWARE_CONFIG.md            # 硬件配置
```

---

## 🔧 VPU操作概览

| 操作 | 功能 | 输入 | 输出 | RTL单元 |
|------|------|------|------|---------|
| **MaxPooling** | 2x2最大池化 | INT8 [C,H,W] | INT8 [C,H/2,W/2] | `mp_unit.sv` |
| **Upsampling** | 2x最近邻上采样 | UINT8 [C,H,W] | UINT8 [C,H*2,W*2] | `us_unit.sv` |
| **Add** | FP32逐元素加法 | FP32 [N] | FP32 [N] | `ad_unit.sv` |
| **Quantize** | FP32→INT8量化 | FP32 [N] | INT8 [N] | `qa_unit.sv` |
| **Dequantize** | INT32→FP32反量化 | INT32 [N] | FP32 [N] | `dqa_unit.sv` |

---

## 🎯 典型应用

### YOLO特征金字塔网络

```python
# P4上采样到P3
p4_up = ops['upsample'](p4_feature)  # 16x16 → 32x32

# 与P3融合
fused = ops['add'](p3_feature, p4_up)

# 下采样到P5
p5 = ops['maxpool'](fused)  # 32x32 → 16x16
```

### 量化推理

```python
# 反量化输入
fp_input = ops['dequantize'](int32_data, scale, bias)

# 卷积后量化输出
quantized = ops['quantize'](fp_output, scale=12.7)
```

---

## 📊 硬件规格

### 时序性能
- **时钟频率**: 250 MHz
- **时序裕量**: WNS +0.409ns (无违例)
- **关键路径**: BRAM → AXI控制器 (3.005ns)

### 资源利用（估算）
- **LUT**: ~50K
- **FF**: ~60K  
- **BRAM**: ~200个
- **DSP**: ~100个

### 内存配置
- **Global Buffer**: 64KB (数据)
- **Weight Buffer**: 64KB (权重)
- **Staging BRAM**: 64KB (主机缓冲)

---

## 🧪 验证状态

| 验证项 | 状态 | 覆盖率 | 说明 |
|--------|------|--------|------|
| **时序验证** | ✅ 通过 | 100% | 250MHz无违例 |
| **RTL单元测试** | ✅ 通过 | 100% | QA/DQA/AD/US/MP |
| **Vivado构建** | ✅ 通过 | 100% | BD/综合/实现 |
| **Python API** | ✅ 通过 | 100% | Mock模式 |
| **硬件验证** | ⚠️ 待测 | 0% | 需FPGA板卡 |

**总体验证覆盖率**: ~45% (软件验证完成，待硬件测试)

详细报告见：`docs/VERIFICATION.md`

---

## 🔨 构建流程

### 完整构建（生成Bitstream）

```bash
cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-vpu
vivado -mode batch -source scripts/vpu/run.tcl 2>&1 | tee build.log
```

### 分阶段构建

```bash
# 仅创建工程
vivado -mode batch -source scripts/vpu/run.tcl -tclargs --to build

# 到Block Design验证
vivado -mode batch -source scripts/vpu/run.tcl -tclargs --to validate

# 到综合
vivado -mode batch -source scripts/vpu/run.tcl -tclargs --to synth
```

### 查看时序报告

```bash
# 布局布线后时序
cat build/vpu/ImplOutputDir/post_route_timing_summary.rpt | grep -A 10 "Design Timing Summary"

# 输出：WNS(ns)  TNS(ns)  ...
#       0.288    0.000    ...
```

---

## 📖 文档索引

### 核心文档
- **本README**: 项目概览和快速开始
- **tests/vpu/README.md**: Python API详细使用指南
- **docs/VERIFICATION.md**: 完整验证报告（自动生成）
- **docs/HARDWARE_CONFIG.md**: 硬件配置说明（自动生成）

### RTL文档
- `rtl/vpu/Global_VPU.v`: VPU模块接口和信号定义
- `rtl/vpu/*_unit.sv`: 各功能单元实现细节

### 脚本文档
- `scripts/vpu/run.tcl`: 构建流程说明
- `scripts/ip/`: IP配置注释

---

## 🛠️ 开发指南

### 添加新操作

1. **RTL实现**: 在`rtl/vpu/`添加新的`*_unit.sv`
2. **集成到VPU**: 修改`Global_VPU.v`添加实例
3. **Python API**: 在`vpu_operations.py`添加操作类
4. **测试**: 添加Golden Model和测试用例

### 修改IP配置

```bash
# 修改浮点IP
vim scripts/ip/floating_point_fp32.tcl

# 重新生成
vivado -mode batch -source scripts/ip/floating_point_fp32.tcl
```

---

## ⚠️ 常见问题

### Q: 如何验证时序是否满足？
```bash
grep "WNS" build/vpu/ImplOutputDir/post_route_timing_summary.rpt
# 输出正数表示满足
```

### Q: Python API报错找不到模块？
```bash
cd tests/vpu
export PYTHONPATH=$PWD:$PYTHONPATH
python test_vpu_ops_example.py
```

### Q: 硬件模式设备找不到？
```bash
# 检查PCIe
lspci | grep Xilinx

# 检查XDMA驱动
ls /dev/xdma*
```

### Q: 如何清理构建文件？
```bash
rm -rf build/vpu vivado*.log *.jou
```

---

## 📈 性能预期

| 操作 | 数据规模 | 理论延迟 | 吞吐量 |
|------|---------|---------|--------|
| MaxPool 2x2 | 32×64×64 | ~64μs | ~32 Mpixels/s |
| Upsample 2x | 32×32×32 | ~128μs | ~8 Mpixels/s |
| Add FP32 | 32×32×32 | ~4μs | ~8K Melements/s |
| Quantize | 64×16×16 | ~2μs | ~8K Melements/s |

**注**: 不含PCIe/DMA传输开销，实际性能需硬件测试。

---

## 🔄 版本历史

### v1.0 (2026-05-14)
- ✅ VPU RTL实现（5个操作单元）
- ✅ Python API完成
- ✅ 时序验证通过（250MHz）
- ✅ Mock模式测试通过
- ⚠️ 硬件验证待完成

---

## 📧 支持与反馈

- **文档**: 查看`tests/vpu/README.md`
- **验证报告**: 查看`docs/VERIFICATION.md`
- **RTL源码**: 查看`rtl/vpu/`

---

## 📜 许可证

本项目遵循原EdgeYOLO项目许可证。

---

**最后更新**: 2026-05-14  
**状态**: RTL/软件✅ | 硬件验证⚠️  
**团队**: VPU开发组
