# DCIM_Macro - 基于 DCIM 核心的矩阵乘法加速器

## 概述

`DCIM_Macro` 是一个封装了 DCIM (Digital Compute-in-Memory) 核心的矩阵乘法加速器模块。它提供简单的 BRAM 接口，用于在 FPGA 上高效执行矩阵乘法运算。

**计算功能**：`Y = X × W`
- `X`：激活矩阵（INT8 或 INT16）
- `W`：权重矩阵（4-bit nibble）
- `Y`：输出矩阵（16-bit 或 32-bit）

## 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                         DCIM_Macro                              │
│  ┌─────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │  IBUF   │───▶│ act_nibble_conv  │───▶│                  │   │
│  │ (BRAM)  │    │ (INT8/16→nibble) │    │                  │   │
│  │         │    └──────────────────┘    │      DCIM        │   │
│  │         │───────────────────────────▶│      Core        │   │
│  │         │    (权重 128-bit)          │                  │   │
│  └─────────┘                            │                  │   │
│                                         └────────┬─────────┘   │
│  ┌─────────┐                                     │             │
│  │  OBUF   │◀────────────────────────────────────┘             │
│  │ (BRAM)  │    (结果 256-bit → 2×128-bit)                     │
│  └─────────┘                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## 接口说明

### 控制接口

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| `clk` | input | 1 | 时钟 |
| `rst_n` | input | 1 | 异步复位（低有效） |
| `start` | input | 1 | 启动信号（单周期脉冲） |
| `done` | output | 1 | 完成信号 |
| `ready` | output | 1 | 就绪信号（可接收新任务） |

### 配置接口

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| `mode` | input | 3 | 计算模式：`MODE_INT8=3'b110`, `MODE_INT16=3'b111` |
| `acc_depth` | input | 5 | 累加深度：0=不累加，N=每N行累加输出一次 |
| `num_rows` | input | 16 | 激活矩阵总行数 |
| `wei_base_addr` | input | 12 | 权重在 IBUF 中的起始地址 |
| `act_base_addr` | input | 12 | 激活在 IBUF 中的起始地址 |
| `out_base_addr` | input | 12 | 输出在 OBUF 中的起始地址 |

### IBUF 外部接口（用于加载数据）

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| `ibuf_ena` | input | 1 | 端口 A 使能 |
| `ibuf_wea` | input | 16 | 端口 A 字节写使能 |
| `ibuf_addra` | input | 12 | 端口 A 地址 |
| `ibuf_dina` | input | 128 | 端口 A 写数据 |
| `ibuf_douta` | output | 128 | 端口 A 读数据 |

### OBUF 外部接口（用于读取结果）

| 信号 | 方向 | 位宽 | 描述 |
|------|------|------|------|
| `obuf_ena` | input | 1 | 端口 A 使能 |
| `obuf_wea` | input | 16 | 端口 A 字节写使能 |
| `obuf_addra` | input | 12 | 端口 A 地址 |
| `obuf_dina` | input | 128 | 端口 A 写数据 |
| `obuf_douta` | output | 128 | 端口 A 读数据 |

## 数据格式

### 权重格式（IBUF 地址 0-7）

权重矩阵为 16×16 个 4-bit nibble，共 1024 bit，分 8 次存储：

```
IBUF[0]: 128-bit = 32 个 nibble (out_ch 0-1 的所有 in_ch)
IBUF[1]: 128-bit = 32 个 nibble (out_ch 2-3 的所有 in_ch)
...
IBUF[7]: 128-bit = 32 个 nibble (out_ch 14-15 的所有 in_ch)
```

**nibble 排布**：`nibble_idx = out_ch * CH_IN + in_ch`

### 激活格式

**INT8 模式**：每行 16 个 8-bit 值 = 128-bit，1 次 IBUF 读取
```
IBUF[act_base + row]: [ch15:8-bit][ch14:8-bit]...[ch1:8-bit][ch0:8-bit]
```

**INT16 模式**：每行 16 个 16-bit 值 = 256-bit，2 次 IBUF 读取
```
IBUF[act_base + row*2]:     [ch7:16-bit][ch6:16-bit]...[ch0:16-bit]  (低 128-bit)
IBUF[act_base + row*2 + 1]: [ch15:16-bit][ch14:16-bit]...[ch8:16-bit] (高 128-bit)
```

### 输出格式

DCIM 输出 16 个 16-bit 物理通道 = 256-bit，分 2 次写入 OBUF：

```
OBUF[out_base + result*2]:     物理通道 0-7  (低 128-bit)
OBUF[out_base + result*2 + 1]: 物理通道 8-15 (高 128-bit)
```

### 物理通道到逻辑通道映射

**INT8 模式**（8 个逻辑通道）：
| 逻辑通道 | 物理通道 | 说明 |
|----------|----------|------|
| 0 | 2 | 16-bit 有符号结果 |
| 1 | 4 | 16-bit 有符号结果 |
| 2 | 6 | 16-bit 有符号结果 |
| 3 | 8 | 16-bit 有符号结果 |
| 4 | 10 | 16-bit 有符号结果 |
| 5 | 12 | 16-bit 有符号结果 |
| 6 | 14 | 16-bit 有符号结果 |
| 7 | 14 | 16-bit 有符号结果（与通道6相同） |

**INT16 模式**（4 个逻辑通道）：
| 逻辑通道 | 物理通道 | 说明 |
|----------|----------|------|
| 0 | 0, 1 | 32-bit = {phys[1], phys[0]} |
| 1 | 4, 5 | 32-bit = {phys[5], phys[4]} |
| 2 | 8, 9 | 32-bit = {phys[9], phys[8]} |
| 3 | 12, 13 | 32-bit = {phys[13], phys[12]} |

## 使用流程

### 1. 加载权重到 IBUF

```verilog
// 将权重写入 IBUF 地址 0-7
for (addr = 0; addr < 8; addr++) begin
    @(posedge clk);
    ibuf_ena <= 1; ibuf_wea <= 16'hFFFF;
    ibuf_addra <= addr;
    ibuf_dina <= weight_data[addr];  // 128-bit
    @(posedge clk);
    ibuf_ena <= 0; ibuf_wea <= 0;
end
```

### 2. 加载激活到 IBUF

```verilog
// INT8: 每行 1 次写入
for (row = 0; row < num_rows; row++) begin
    ibuf_addra <= 8 + row;  // 权重占用 0-7
    ibuf_dina <= activation_int8[row];  // 128-bit
    ...
end

// INT16: 每行 2 次写入
for (row = 0; row < num_rows; row++) begin
    ibuf_addra <= 8 + row*2;
    ibuf_dina <= activation_int16_lo[row];  // 低 128-bit
    ...
    ibuf_addra <= 8 + row*2 + 1;
    ibuf_dina <= activation_int16_hi[row];  // 高 128-bit
    ...
end
```

### 3. 配置并启动计算

```verilog
mode <= `MODE_INT8;      // 或 `MODE_INT16
acc_depth <= 0;          // 0=不累加，2=每2行累加
num_rows <= 8;           // 激活行数
wei_base_addr <= 0;      // 权重起始地址
act_base_addr <= 8;      // 激活起始地址
out_base_addr <= 0;      // 输出起始地址

@(posedge clk);
start <= 1;
@(posedge clk);
start <= 0;

wait(done);
```

### 4. 读取结果

```verilog
// 每个输出占用 2 个 OBUF 地址
for (result = 0; result < expected_outputs; result++) begin
    obuf_addra <= result * 2;
    @(posedge clk); repeat(3) @(posedge clk);
    result_lo = obuf_douta;  // 物理通道 0-7
    
    obuf_addra <= result * 2 + 1;
    @(posedge clk); repeat(3) @(posedge clk);
    result_hi = obuf_douta;  // 物理通道 8-15
end
```

## 累加功能

当 `acc_depth > 0` 时，DCIM 会自动累加多行的计算结果：

- `acc_depth = 0`：每行输出一个结果，共 `num_rows` 个输出
- `acc_depth = 2`：每 2 行累加输出一个结果，共 `num_rows/2` 个输出
- `acc_depth = 4`：每 4 行累加输出一个结果，共 `num_rows/4` 个输出

**注意**：`num_rows` 必须是 `acc_depth` 的整数倍。

## 编译和测试

```bash
cd rtl/DCIM_Macro

# 编译
make compile

# 运行仿真
make sim

# 生成波形
make fsdb

# 查看波形
make verdi

# 清理
make clean
```

## 测试覆盖

当前测试平台 (`tb_DCIM_Macro.sv`) 包含 **49 个测试用例**，覆盖以下场景：

### 测试分类

| 分类 | 测试数量 | 描述 |
|------|----------|------|
| 基本功能 | 2 | INT8/INT16 基本矩阵乘法 |
| 累加功能 | 5 | ACC=2,4,8 不同累加深度 |
| 边界值 | 6 | 最大/最小权重和激活值 |
| 特殊模式 | 5 | 全零、单位矩阵、交替正负 |
| 随机数据 | 5 | 不同随机种子 |
| 不同行数 | 4 | 4/8/16 行测试 |
| 不同基地址 | 2 | 非零基地址测试 |
| 连续计算 | 3 | 多次连续计算 |
| 极端值组合 | 6 | Max*Max, Min*Min 等 |
| 累加边界 | 3 | ACC=1,8,16 边界测试 |
| 更多随机 | 4 | 额外随机测试 |
| 混合模式 | 4 | INT8/INT16 交替切换 |

### 详细测试列表

| # | 测试名称 | 模式 | ACC | 行数 | 权重模式 | 激活模式 |
|---|----------|------|-----|------|----------|----------|
| 1 | INT8 Basic | INT8 | 0 | 8 | 全1 | 递增 |
| 2 | INT16 Basic | INT16 | 0 | 8 | 全1 | 递增 |
| 3-5 | INT8 ACC | INT8 | 2,4,8 | 8 | 递增 | 固定 |
| 6-7 | INT16 ACC | INT16 | 2,4 | 8 | 递增 | 固定 |
| 8-9 | Weight Boundary | INT8 | 0 | 8 | +7/-8 | 递增 |
| 10-13 | Act Boundary | 混合 | 0 | 8 | 全1 | 极端值 |
| 14-18 | Special Pattern | 混合 | 0 | 8 | 特殊 | 特殊 |
| 19-23 | Random Tests | 混合 | 混合 | 8 | 随机 | 随机 |
| 24-27 | Variable Rows | 混合 | 混合 | 4/16 | 递增 | 固定 |
| 28-29 | Different Base | 混合 | 0 | 8 | 递增 | 固定 |
| 30-32 | Consecutive | INT8 | 混合 | 8 | 混合 | 混合 |
| 33-38 | Extreme Values | 混合 | 0 | 8 | 极端 | 极端 |
| 39-41 | ACC Boundary | 混合 | 1,8,16 | 8/16 | 递增 | 固定 |
| 42-45 | More Random | 混合 | 混合 | 8 | 随机 | 随机 |
| 46-49 | Mixed Mode | 混合 | 混合 | 8 | 递增 | 固定 |

### 运行测试

```bash
cd rtl/DCIM_Macro
make clean && make sim
```

预期输出：
```
═══════════════════════════════════════════════════════════════
                      TEST SUMMARY
═══════════════════════════════════════════════════════════════
  Total Tests:  49
  Passed:       49
  Failed:       0
  Total Errors: 0
═══════════════════════════════════════════════════════════════

  ╔═══════════════════════════════════════╗
  ║     ✓ ALL 49 TESTS PASSED            ║
  ╚═══════════════════════════════════════╝
```

## FPGA 集成注意事项

1. **BRAM 推断**：`ibuf.v` 和 `obuf.v` 使用 Vivado 推荐的 BRAM 推断模板
2. **SRAM 模型**：仿真使用 `model_rf.sv`，综合时需替换为 `model_rf_bram.sv` 或 Vivado BRAM IP
3. **时序约束**：需要添加适当的 XDC 约束文件
4. **复位**：使用异步低有效复位

## 文件结构

```
rtl/DCIM_Macro/
├── DCIM_Macro.sv      # 主模块
├── tb_DCIM_Macro.sv   # 测试平台
├── ibuf.v             # 输入缓冲 BRAM
├── obuf.v             # 输出缓冲 BRAM
├── filelist.f         # 编译文件列表
├── Makefile           # 编译脚本
└── README.md          # 本文档
```

## 依赖

- `ref/DCIM/src/dcim/` - DCIM 核心模块
- `ref/DCIM/src/inc/` - 参数定义和公共模块
- `ref/DCIM/src/model/` - SRAM 行为模型
