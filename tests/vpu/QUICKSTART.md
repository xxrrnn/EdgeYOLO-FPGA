# VPU测试快速开始

## 🚀 5分钟上手

### 方式1: 使用便捷脚本（推荐）
```bash
cd tests/vpu
./run_test.sh                    # Mock模式，所有测试
./run_test.sh --test maxpool     # 仅测试MaxPooling
./run_test.sh --device /dev/xdma0  # 硬件模式
```

### 方式2: 直接运行
```bash
cd tests/vpu/examples
PYTHONPATH=.. python test_vpu_ops_example.py
```

---

## 📦 使用Python API

```python
from vpu_operations import create_vpu_operators
import numpy as np

# 创建操作符
ops = create_vpu_operators("/dev/xdma0")  # 或留空用Mock模式

# MaxPooling 2x2
input_data = np.random.randint(-128, 127, (32, 64, 64), dtype=np.int8)
output = ops['maxpool'](input_data)  # → (32, 32, 32)

# Upsampling 2x  
output = ops['upsample'](input_data)  # → (32, 128, 128)

# Element-wise Add
a = np.random.randn(16, 32, 32).astype(np.float32)
b = np.random.randn(16, 32, 32).astype(np.float32)
output = ops['add'](a, b)

# Quantization
fp_data = np.random.randn(64, 16, 16).astype(np.float32) * 10
output = ops['quantize'](fp_data, scale=12.7)  # FP32→INT8

ops['device'].close()
```

---

## 📖 完整文档

详见 `README.md` 的完整说明。

---

## 🎯 支持的操作

| 操作 | 输入 | 输出 |
|------|------|------|
| MaxPooling 2x2 | INT8 [C,H,W] | INT8 [C,H/2,W/2] |
| Upsampling 2x | UINT8 [C,H,W] | UINT8 [C,H*2,W*2] |
| Add | FP32 [N] + FP32 [N] | FP32 [N] |
| Quantize | FP32 [N] | INT8 [N] |
| Dequantize | INT32 [N] | FP32 [N] |
