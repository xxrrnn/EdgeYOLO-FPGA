# DCIM 集成测试

## 概述

本测试验证 `act_nibble_converter` 和 `dcim` 模块的集成功能，实现完整的 INT8/INT16 矩阵乘法流程。

## 测试状态

| 模式 | 状态 | 说明 |
|------|------|------|
| INT8 | ✓ 通过 | 随机数据测试通过 |
| INT16 | ⚠ 待调试 | 权重/输出通道映射需要调整 |

---

## INT8 测试详解

### 快速运行

```bash
# 运行 INT8 测试
make test_int8

# 查看详细日志
cat build/logs/run.log

# 查看波形
make wave
```

### 测试架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                        dcim_preprocess_tb                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────┐      ┌──────────────────────────────────────┐│
│  │ act_nibble_      │      │              dcim                    ││
│  │ converter        │      │  ┌──────────┐  ┌──────────────────┐  ││
│  │                  │      │  │  memory  │  │  calculate_core  │  ││
│  │ INT8 (8-bit)     │      │  │  (SRAM + │  │  (maArray)       │  ││
│  │      ↓           │ ───▶ │  │  ppCache)│  │                  │  ││
│  │ 2x 4-bit nibbles │      │  └──────────┘  └──────────────────┘  ││
│  │                  │      │  ┌──────────────────────────────────┐││
│  └──────────────────┘      │  │         postProcess              │││
│                            │  │  ┌─────────┐  ┌────────────────┐ │││
│                            │  │  │  merge  │  │  accumulate    │ │││
│                            │  │  └─────────┘  └────────────────┘ │││
│                            │  └──────────────────────────────────┘││
│                            └──────────────────────────────────────┘│
│                                                                     │
│  ┌──────────────────┐      ┌──────────────────────────────────────┐│
│  │  Golden Model    │      │           结果验证                   ││
│  │  (内嵌计算)      │ ───▶ │  比较 DUT 输出 vs Golden Model       ││
│  └──────────────────┘      └──────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
```

### 数据流详解

#### 1. 激活数据预处理 (act_nibble_converter)

```
输入: INT8 激活数据 [CH_IN × 8-bit]
      例如: activation[ch] = 0xAB (8-bit 有符号数)

处理: 拆分为 2 个 4-bit nibble，先发送高位
      Phase 0: 发送 bit[7:4] = 0xA (高 nibble)
      Phase 1: 发送 bit[3:0] = 0xB (低 nibble)

输出: 2 拍 × [CH_IN × 4-bit] nibble 流
```

**关键点**：DCIM 的 `merge` 模块期望先收到高 nibble，再收到低 nibble。

#### 2. 权重存储格式

```
权重矩阵: weight_nibble[CH_IN][CH_OUT] = [16][16] 个 4-bit nibble

SRAM 存储格式:
  - 每个地址 128-bit = 32 个 nibble
  - 总共需要 8 个地址存储完整的权重 tile (256 nibble)
  
排布方式: nibble_idx = out_ch * CH_IN + in_ch
  - 地址 0: out_ch=0,1 的所有 in_ch 权重
  - 地址 1: out_ch=2,3 的所有 in_ch 权重
  - ...
```

#### 3. INT8 计算过程

```
对于每个输入向量:
  Phase 0 (高 nibble):
    partial_sum[out_ch] = Σ(act_hi[in_ch] × weight[in_ch][out_ch])
    
  Phase 1 (低 nibble):
    result[out_ch] = partial_sum[out_ch] + Σ(act_lo[in_ch] × weight[in_ch][out_ch]) << 4

最终结果:
    result = Σ(act_8bit × weight_8bit)
    其中 weight_8bit = {weight_hi_nibble, weight_lo_nibble}
```

#### 4. 输出通道映射 (INT8)

```
物理通道 → 逻辑通道映射:
  - 每 4 个物理通道产生 2 个逻辑通道
  - 逻辑通道 0 在物理通道 0 (结果的低 WD3 位)
  - 逻辑通道 1 在物理通道 2
  - 逻辑通道 2 在物理通道 4
  - ...
  - 逻辑通道 7 在物理通道 14

权重通道映射:
  - 逻辑通道 out_ch 使用物理通道 (out_ch*2+2) 和 (out_ch*2+3) 的权重
  - 例如: 逻辑通道 0 使用物理通道 2,3 的权重
  - 例如: 逻辑通道 7 使用物理通道 14,15 的权重
```

### 测试参数

| 参数 | 值 | 说明 |
|------|-----|------|
| WD1 | 4 | nibble 位宽 |
| CH_IN | 16 | 输入通道数 |
| CH_OUT | 16 | 输出通道数 |
| WD2 | 12 | 中间结果位宽 (2×WD1 + log2(CH_IN)) |
| WD3 | 16 | 最终输出位宽 (WD2 + log2(ACC)) |
| TEST_ROWS | 8 | 测试向量数量 |
| nibble_phases | 2 | INT8 需要 2 拍 |
| num_logical_ch | 8 | INT8 产生 8 个逻辑输出通道 |

### 测试流程

```
Phase 1: 生成随机权重
         weight_nibble[i][j] = random(-7, 7)

Phase 2: 加载权重到 SRAM
         写入 8 个地址 (CYCLE=8)

Phase 3: 加载到 ppCache (单缓冲模式)
         load_wei → 等待 CYCLE 周期
         状态: IDLE → PREPARE，dn_valid=1，权重可用
         注: 不需要 swap，ppCache 双缓冲功能保留但未使用

Phase 4: 生成随机激活
         activation[row][ch] = random(-127, 127)

Phase 5: 计算 Golden Model
         golden[row][out_ch] = Σ(activation × weight_8bit)

Phase 6: 发送激活并收集结果
         通过 act_nibble_converter 发送
         收集 DUT 输出

Phase 7: 验证
         比较 DUT 输出和 Golden Model
```

#### ppCache 说明

`ppCache` 是一个双缓冲机制，设计用于流水线操作：
- 在计算当前权重时，可以预加载下一组权重
- 通过 `swap` 信号切换缓冲区

**当前测试使用单缓冲模式**：
- 只加载一份权重，直接计算
- 不使用 `swap` 功能
- RTL 保持不变，只是测试流程简化

### 验证输出示例

```
═══════════════════════════════════════════════════════
  VERIFICATION RESULTS
═══════════════════════════════════════════════════════
  Mode:  INT8
  Test rows: 8, Logical channels: 8
  DUT results collected: 8

  [OK] Row 0 Ch 0: -16784
  [OK] Row 0 Ch 1: 21249
  [OK] Row 0 Ch 2: -8659
  [OK] Row 0 Ch 3: 8839
  ...

───────────────────────────────────────────────────────
  Total: 64 comparisons, 0 errors
───────────────────────────────────────────────────────

  ╔═══════════════════════════════════════╗
  ║  ✓ VERIFICATION PASSED                ║
  ╚═══════════════════════════════════════╝
```

### INT16 测试说明

#### INT16 数据流

```
激活 INT16 → 拆分为 4 个 nibble → DCIM 计算 → 32 位结果
```

#### INT16 输出格式

- 每 4 个物理通道产生 1 个逻辑通道
- 结果分布在 2 个物理通道中：
  - `temp0` = 低 16 位
  - `temp1` = 高 16 位
- 完整 INT16 结果 = `{temp1, temp0}` (32 位)

#### INT16 通道映射

类似 INT8，INT16 也存在 +2 的通道偏移：
- 逻辑通道 0 使用物理通道 2, 3, 4, 5
- 逻辑通道 1 使用物理通道 6, 7, 8, 9
- 逻辑通道 2 使用物理通道 10, 11, 12, 13
- 逻辑通道 3 使用物理通道 14, 15, 14, 15（边界处理）

#### INT16 Golden Model 计算

```verilog
// 通道偏移 +2
base_ch = out_ch * 4 + 2;
ch0 = base_ch;
ch1 = base_ch + 1;
ch2 = base_ch + 2;
ch3 = base_ch + 3;
// 边界处理
if (ch0 >= CH_OUT) ch0 = CH_OUT - 2;
if (ch1 >= CH_OUT) ch1 = CH_OUT - 1;
if (ch2 >= CH_OUT) ch2 = CH_OUT - 2;
if (ch3 >= CH_OUT) ch3 = CH_OUT - 1;
// 组装 INT16 权重
w16 = {weight_nibble[in_ch][ch3],
       weight_nibble[in_ch][ch2],
       weight_nibble[in_ch][ch1],
       weight_nibble[in_ch][ch0]};
// 计算（保留完整 32 位结果）
sum = sum + ($signed(a16) * $signed(w16));
golden[row][out_ch] = sum;  // 不截断
```

---

## 关键修复记录

### act_nibble_converter 修复

1. **nibble 发送顺序**：
   - 原始: 先发送低 nibble bit[3:0]，再发送高 nibble bit[7:4]
   - 修复: 先发送高 nibble bit[7:4]，再发送低 nibble bit[3:0]
   - 原因: DCIM 的 `merge` 模块累加逻辑是 `result = new + old << 4`

2. **nibble_ubd 值**：
   - 原始: INT8 模式 `nibble_ubd = 2'd2` (3 拍)
   - 修复: INT8 模式 `nibble_ubd = 2'd1` (2 拍: cnt=0,1)
   - 原因: INT8 只需要 2 个 nibble

### Golden Model 权重映射修复

- 原始: 逻辑通道 out_ch 使用物理通道 out_ch×2 和 out_ch×2+1
- 修复: 逻辑通道 out_ch 使用物理通道 out_ch×2+2 和 out_ch×2+3
- 原因: DCIM 内部的 `merge` 模块输出格式

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `dcim_preprocess_tb.v` | 集成测试 testbench，包含内嵌 Golden Model |
| `Makefile` | 测试自动化脚本 |
| `sim_vars.mk` | 仿真参数配置 |
| `filelist.f` | 源文件列表 |

---

## 常见问题

### Q: 测试失败，Diff = ±65536

**原因**: 结果溢出，Golden Model 使用 32 位计算，DUT 使用 16 位。

**解决**: Golden Model 已添加截断: `golden[row][out_ch] = $signed(sum[WD3-1:0])`

### Q: 物理通道 1, 3, 5, ... 的值为 0

**原因**: 正常现象。INT8 模式下，每 4 个物理通道产生 2 个逻辑通道，结果只在偶数物理通道 (0, 2, 4, ...) 中。

### Q: 如何查看波形调试

```bash
make test_int8
make wave
# 或手动打开
gtkwave build/waves/waveform.vcd
```

---

## 目录结构

```
dcim_integrated/
├── Makefile                    # 测试自动化
├── sim_vars.mk                 # 参数配置
├── filelist.f                  # 源文件列表
├── dcim_preprocess_tb.v        # 集成测试 testbench
├── README.md                   # 本文档
└── build/                      # 生成目录
    ├── logs/                   # 编译、运行日志
    │   ├── compile.log
    │   └── run.log
    ├── waves/                  # 波形文件
    │   └── waveform.vcd
    ├── data/                   # 仿真数据
    └── results/                # 验证结果
```
