# DCIM_Macro Testbench

验证 DCIM_Macro 模块的 INT8×INT8 和 INT16×INT16 矩阵乘法功能（CH_OUT=64）。

## 测试场景

本 testbench 包含 6 个测试用例：

### INT8 测试
1. **小矩阵** [8, 16] × [16, 64] - 需要补 0 对齐到 tile 大小
2. **正好 tile** [32, 16] × [16, 64] - 单个 tile 完成
3. **大矩阵** [32, 64] × [64, 64] - 需要 4 个 tile 累加（K 维度切分）

### INT16 测试
4. **小矩阵** [4, 16] × [16, 64] - 需要补 0 对齐
5. **正好 tile** [16, 16] × [16, 64] - 单个 tile 完成
6. **大矩阵** [16, 64] × [64, 64] - 需要 4 个 tile 累加

## 快速开始

### 编译
```bash
make compile
```

### 运行仿真（命令行模式）
```bash
make run
```

### 运行仿真（带 Verdi GUI）
```bash
make run_gui
```

### 仅查看波形
```bash
make verdi
```

### 清理
```bash
make clean
```

## 预期输出

所有测试通过时会显示：
```
========================================
ALL TESTS PASSED!
========================================
```

每个测试用例会显示类似信息：
```
[Test 1] INT8 Small Matrix [8, 16] x [16, 64]
[Test 1] PASS
```

## 文件说明

- `DCIM_Macro_tb.sv` - Testbench 源文件
- `Makefile` - 编译和仿真脚本
- `README.md` - 本文件

## 依赖

- VCS 编译器
- Verdi 波形查看器
- DCIM 核心模块（`../../DCIM/src`）
- DCIM_Macro 模块（`..`）

## 注意事项

1. CH_OUT 已设置为 64（在 `dcim_defs.vh` 中）
2. 每行输出需要 8 个 256bit 字（64 × 32bit / 256bit = 8）
3. 权重加载需要 16 个 256bit 字（16 × 64 × 4bit / 256bit = 16）
4. psum 累加机制会在 `save_to_obuf=0` 时累加，`save_to_obuf=1` 时写出并清零

## Troubleshooting

如果遇到编译错误：
1. 检查 VCS 环境变量是否设置正确
2. 确认 DCIM 源文件路径是否正确
3. 查看编译日志获取详细错误信息

如果仿真失败：
1. 检查是否有 ERROR 或 FATAL 消息
2. 使用 Verdi 查看波形定位问题
3. 检查 `dcim_error_code` 输出
