# DCIM_Macro 测试套件

## 目录结构

```
tb/
├── Makefile              # 主 Makefile
├── filelist.f            # RTL 文件列表
├── README.md             # 本文档
├── unit/                 # 模块单元测试
│   ├── tb_DCIM_Macro.sv
│   └── README.md
└── onnx/                 # ONNX 模型卷积层测试
    ├── tb_onnx_conv_layers.sv
    └── README.md
```

## 快速开始

```bash
# 运行单元测试
make unit

# 运行 ONNX 卷积层测试
make onnx

# 查看帮助
make help

# 清理构建文件
make clean
```

## 测试范围说明

### 当前测试的是什么？

**单个 DCIM_Macro Tile 的内积计算能力**

- DCIM_Macro 是一个 16×16 的计算 tile
- 每次计算：`Y[1×16] = X[1×16] × W[16×16]`（单行激活 × 权重矩阵）
- 支持累加（ACC）：多行激活累加到同一输出，模拟更大的内积维度 K

### 当前测试不包括什么？

**完整的矩阵乘法（GEMM）**

完整的矩阵乘法 `C[M×N] = A[M×K] × B[K×N]` 需要：

1. **M 维度分块**：多行激活依次处理
2. **K 维度分块**：通过 ACC 累加实现（当前已测试）
3. **N 维度分块**：需要多个 DCIM_Macro 实例并行（未测试）

### 与 ONNX 模型的关系

对于 `best.onnx` 中的卷积层（经过 im2col 转换后）：

| 卷积层 | im2col 后维度 | 当前测试覆盖 |
|--------|---------------|--------------|
| Conv [256, 128, 3×3] | M×1152×256 | K=1152 ✓（ACC=72）|
| | | N=256 需要 16 个 tile 并行 ✗ |

## 后续工作

要支持完整的 ONNX 模型推理，还需要：

1. **多 Tile 并行架构**：实例化多个 DCIM_Macro 处理 N 维度
2. **Tile 调度器**：协调多个 tile 的权重加载和激活广播
3. **完整 GEMM 测试**：验证多 tile 协作的正确性
