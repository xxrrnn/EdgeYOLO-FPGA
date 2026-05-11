# 单元测试 (Unit Tests)

## 测试文件

- `tb_DCIM_Macro.sv` - DCIM_Macro 模块单元测试

## 测试范围

**单个 DCIM_Macro Tile 的基础功能验证**

### 测试内容

| 测试类别 | 测试项 | 数量 |
|----------|--------|------|
| 基本功能 | INT8/INT16 模式 | 2 |
| 累加功能 | ACC=0,2,4,8 | 5 |
| 边界值 | 最大/最小权重和激活 | 6 |
| 特殊模式 | 全零、单位矩阵、交替符号 | 5 |
| 随机数据 | 不同种子的随机测试 | 9 |
| 行数变化 | 4/8/16 行 | 4 |
| 地址测试 | 不同基地址 | 2 |
| 连续计算 | 多次连续运算 | 3 |
| 极端值组合 | Max×Max, Min×Min 等 | 6 |
| 累加边界 | ACC=1,16 | 3 |
| 混合模式 | INT8/INT16 交替 | 4 |
| 大 ACC | ACC=18,36,72 | 5 |
| **总计** | | **54** |

### 计算模型

每个测试验证的计算：

```
对于 INT8 模式：
  output[i] = Σ(activation[row][ch] × weight[ch][i]) for ch in 0..15
  
  其中：
  - activation: 8-bit 有符号整数
  - weight: 4-bit nibble 组成的 8-bit 有符号整数
  - output: WD3-bit 累加结果，符号扩展到 32-bit

对于 INT16 模式：
  output[i] = Σ(activation[row][ch] × weight[ch][i]) for ch in 0..15
  
  其中：
  - activation: 16-bit 有符号整数
  - weight: 4-bit nibble 组成的 16-bit 有符号整数
  - output: 32-bit 结果
```

### 累加（ACC）功能

当 ACC > 0 时，多行激活的结果会累加：

```
final_output = Σ output[row] for row in 0..(ACC-1)
```

这模拟了 im2col 后更大的内积维度 K：
- ACC=1: K=16（无累加）
- ACC=72: K=1152（最大，对应 Conv 128×128×3×3）

## 运行测试

```bash
cd rtl/DCIM_Macro/tb
make unit
```

## 测试输出示例

```
╔═══════════════════════════════════════════════════════════════╗
║         DCIM_Macro Comprehensive Test Suite v2.0             ║
╚═══════════════════════════════════════════════════════════════╝

▶ SECTION 1: Basic Functionality Tests
─────────────────────────────────────────────────────────────
  Test 1: INT8 Basic (all-1 weights)
  Mode= INT8, ACC=0, Rows=8, WeiPat=0, ActPat=0
─────────────────────────────────────────────────────────────
  >>> PASSED <<<
...

═══════════════════════════════════════════════════════════════
                      TEST SUMMARY
═══════════════════════════════════════════════════════════════
  Total Tests:  54
  Passed:       54
  Failed:       0
  Total Errors: 0
═══════════════════════════════════════════════════════════════
```

## 注意事项

1. **这是单 Tile 测试**：只验证单个 16×16 计算单元
2. **不是完整 GEMM 测试**：不涉及多 Tile 协作
3. **Golden Model**：使用 SystemVerilog 实现的参考模型进行比对
