# DCIM Tile 架构与 INT8/INT16 计算说明

本文档说明 `DCIM_Tile.sv` 当前实现的数据流、状态机、INT8/INT16 计算语义、输入输出布局，以及目前支持的计算类型和维度限制。

## 1. 当前 DCIM-lite 配置

参数来自 `rtl/chip/chip_defines.vh`：

| 参数 | 当前值 | 说明 |
|---|---:|---|
| `DCIM_NUM_GROUPS` | 1 | lite 版本仅 1 组 |
| `DCIM_TILES_PER_GROUP` | 8 | 每组 8 个 Tile |
| `DCIM_NUM_TILES` | 8 | 总 Tile 数 |
| `DCIM_WD1` | 4 | 底层乘法位宽，所有计算最终拆成 4-bit nibble 乘法 |
| `DCIM_CH_IN` | 16 | 每个 acc row 处理 16 个输入通道 |
| `DCIM_CH_OUT` | 16 | 每 Tile 内部 16 个 physical output lanes |
| `DCIM_CYCLE` | 8 | 每个 acc row 需要 8 个 128-bit weight word，覆盖 16 个 physical output lanes |
| `DCIM_ACC_MAX` | 80 | 最大 `acc_depth` |
| `DCIM_BUF_DATA_WIDTH` | 128 | IBUF/OBUF word 宽度 |
| `DCIM_IBUF_ADDR_WIDTH` | 17 | IBUF 为 2MB，128K 个 128-bit word |
| `DCIM_OBUF_ADDR_WIDTH` | 20 | OBUF 为 16MB，1M 个 128-bit word |

派生参数：

```text
WD2 = 2*WD1 + clog2(CH_IN) = 8 + 4 = 12
WD3 = WD2 + clog2(ACC_MAX) = 12 + 7 = 19
```

其中：

- `WD2` 是单个 acc row 内 `16` 个 `4-bit × 4-bit` 乘积求和后的宽度。
- `WD3` 是跨 `acc_depth` 累加后的每段结果宽度。

## 2. 顶层数据流

`DCIM_Tile` 每次 `DCIM_EXEC` 的数据流如下：

```text
IBUF weight words
    ↓
DCIM_Tile weight loader
    ↓
内部 weight SRAM / ppCache
    ↓
maArray: 4-bit activation nibble × 4-bit weight nibble，按 CH_IN=16 求和
    ↓
mergeArray: 多个 nibble phase 合成 INT8/INT16 partial sum
    ↓
accumulateArray: 跨 acc_depth 累加
    ↓
DCIM_Tile output extractor/packer
    ↓
OBUF
```

`dcim.v` 内部三级结构：

```text
memory
  → calculate_core
  → postProcess
```

其中：

- `memory`：接收 `wr_wei/load_wei/swap_wei`，提供当前 acc row 对应的 weight tile。
- `calculate_core`：包含 `maArray`，执行底层 4-bit 乘法和 adder tree。
- `postProcess`：包含 `mergeArray` 和 `accumulateArray`。

## 3. DCIM_Tile 状态机

`DCIM_Tile` 的状态机为：

```text
ST_IDLE
  → ST_LOAD_WEI_REQ
  → ST_LOAD_WEI_RESP
  → ST_LOAD_WEI_DONE      // 重复 acc_depth * CYCLE 次，加载本 Tile 所需全部 weight
  → ST_PREP_PPCACHE
  → ST_LOAD_PPCACHE
  → ST_SWAP_PPCACHE
  → ST_LOAD_ACT_REQ
  → ST_LOAD_ACT_RESP
  → [INT16 only] ST_LOAD_ACT2_REQ
  → [INT16 only] ST_LOAD_ACT2_RESP
  → ST_COMPUTE           // 等待当前 row 的所有 nibble phase 被 DCIM core 接收
  → 若 row_cnt 未到 acc_depth-1，回 ST_PREP_PPCACHE
  → ST_WAIT_RESULT
  → ST_DONE
  → ST_IDLE
```

### 3.1 Weight 加载阶段

每次 `DCIM_EXEC` 开始后，Tile 从 IBUF 加载权重：

```text
IBUF address = wei_base_addr + wei_load_cnt
wei_load_cnt = 0 .. acc_depth*CYCLE-1
```

因此每个 Tile 每次执行读取：

```text
acc_depth × CYCLE
```

个 128-bit weight word。

当前 `CYCLE=8`，每个 acc row 需要 8 个 weight word。每个 128-bit word 覆盖两个 physical output lanes：

```text
low  64 bit: 16 个 input channel 的某个 physical output lane 的 4-bit weight
high 64 bit: 16 个 input channel 的另一个 physical output lane 的 4-bit weight
```

因为：

```text
16 input channels × 4 bit = 64 bit
```

8 个 word 正好覆盖：

```text
8 × 2 = 16 physical output lanes
```

### 3.2 Activation 加载阶段

INT8 与 INT16 的最大状态差异在 activation 加载。

#### INT8

每个 acc row 读 1 个 IBUF word：

```text
IBUF address = act_base_addr + row_cnt
```

1 个 128-bit word 包含：

```text
16 channels × 8 bit = 128 bit
```

读出后，每个 INT8 会 sign-extend 到 16-bit，放入 `conv_data[ch*16 +: 16]`。

#### INT16

每个 acc row 读 2 个 IBUF word：

```text
IBUF address 0 = act_base_addr + row_cnt*2
IBUF address 1 = act_base_addr + row_cnt*2 + 1
```

两个 128-bit word 合成 256-bit：

```text
16 channels × 16 bit = 256 bit
```

因此 INT16 的 `acc_depth` 仍按每步 16 个输入元素计算：

```text
acc_depth_int16 = ceil(K / 16)
```

不是 `ceil(K / 8)`。

### 3.3 计算阶段完成条件

`ST_COMPUTE` 的完成条件不是 `raw_act_valid/raw_act_ready` 握手。该握手只表示 `act_nibble_converter` 已经接收了一整行 raw activation。

由于 DCIM core 实际接收的是 4-bit nibble 流：

```text
INT8  : 2 个 nibble phase
INT16 : 4 个 nibble phase
```

因此 `DCIM_Tile` 必须等待所有 nibble phase 都完成 `dcim_valid_act && dcim_ready_act` 后，才能：

1. 增加 `row_cnt`。
2. 进入下一轮 `ST_PREP_PPCACHE/ST_LOAD_PPCACHE/ST_SWAP_PPCACHE`。
3. 切换下一 acc row 的 weight。

如果只等待 raw activation 被 converter 接收就提前切换 ppCache，后续 nibble phase 可能乘到下一 acc row 的 weight，导致 INT8/INT16 在较大 `acc_depth` 或多 pixel 场景下出现隐蔽 mismatch。

## 4. act_nibble_converter：把 INT8/INT16 activation 拆成 INT4 流

底层 `maArray` 只接受 4-bit activation，因此 `act_nibble_converter` 会把 INT8/INT16 拆成多拍 nibble。

### INT8 activation

INT8 发 2 拍：

```text
phase 0: act[7:4]，高 nibble
phase 1: act[3:0]，低 nibble
```

高 nibble 先发，是为了配合后级 `mergeArray` 的左移累加逻辑：

```text
result = low_part + (high_part << 4)
```

### INT16 activation

INT16 发 4 拍：

```text
phase 0: act[15:12]
phase 1: act[11:8]
phase 2: act[7:4]
phase 3: act[3:0]
```

同样是高 nibble 先发。后级每拍执行：

```text
new = current_phase + (old << 4)
```

四拍后恢复完整 INT16 activation 的位权关系。

## 5. maArray：底层 4-bit 乘法阵列

`maArray` 的每个 `maSubcolumn` 执行：

```text
sum_{ic=0..15} activation_nibble[ic] × weight_nibble[ic]
```

每个乘法是 `4-bit × 4-bit`，然后经过 adder tree 对 16 个 input channels 求和。

输出宽度：

```text
WD2 = 2*WD1 + clog2(CH_IN) = 12 bit
```

### 5.1 activation 符号位处理

对于 signed mode：

```text
s1 = cnt_zero
```

也就是说，只有每个 INT8/INT16 的最高 nibble phase 会被当成 signed。因为最高 nibble 包含补码符号位。

- INT8：`act[7:4]` signed，`act[3:0]` unsigned。
- INT16：`act[15:12]` signed，其余 nibble unsigned。

### 5.2 weight 符号位处理

INT8：

```text
s2 = 4'b1010
```

INT16：

```text
s2 = 4'b1000
```

含义：

- INT8 下，physical subcolumns 按两组组合，组内高 nibble 作为 signed。
- INT16 下，4 个 physical subcolumns 组成 1 个 logical INT16 weight，只有最高 nibble 作为 signed。

## 6. mergeArray：用 INT4 部分积凑出 INT8/INT16

`mergeArray` 按模式决定需要多少个 activation nibble phase：

```text
INT4  : 1 phase
INT8  : 2 phases
INT16 : 4 phases
```

### 6.1 INT8 合成

INT8 activation：

```text
A = A_hi * 16 + A_lo
```

硬件先收到 `A_hi`，再收到 `A_lo`：

```text
phase 0: temp = partial(A_hi)
phase 1: temp = partial(A_lo) + (temp << 4)
```

因此恢复出 INT8 activation 的完整位权。

INT8 每个 accumulate column 产生 2 个 logical output channels。整个 Tile 有：

```text
CH_OUT/4 = 4 个 accumulate columns
```

所以 INT8 每 Tile 输出：

```text
4 columns × 2 channels = 8 logical output channels
```

### 6.2 INT16 合成

INT16 activation：

```text
A = A3*16^3 + A2*16^2 + A1*16 + A0
```

硬件收到顺序：

```text
A3 → A2 → A1 → A0
```

逐拍执行：

```text
new = current_phase + (old << 4)
```

最终得到完整 INT16 activation 贡献。

INT16 weight 也由 4 个 physical lanes 组合成 1 个 logical INT16 weight：

```text
W = W3*16^3 + W2*16^2 + W1*16 + W0
```

因此 INT16 模式下，每个 logical output channel 消耗 4 个 physical output lanes：

```text
logical channel 0 = physical lanes 0,1,2,3
logical channel 1 = physical lanes 4,5,6,7
logical channel 2 = physical lanes 8,9,10,11
logical channel 3 = physical lanes 12,13,14,15
```

所以 INT16 每 Tile 输出：

```text
4 logical output channels
```

## 7. accumulateArray：跨 acc_depth 累加

`mergeArray` 只计算一个 acc row，即 16 个输入元素的贡献。`accumulateArray` 负责对多个 acc row 累加。

计数范围：

```text
row_cnt = 0 .. acc_depth-1
```

第一拍 `cnt_zero=1` 时，`refresh=1`，用当前 partial sum 初始化累加寄存器。后续 acc row 执行加法累加。

### 7.1 INT8 accumulate 布局

INT8 将 4 个 `temp` 分成两组：

```text
{temp1,temp0} = lower logical result
{temp3,temp2} = upper logical result
```

每个 accumulate column 对应 2 个 INT8 logical outputs。

### 7.2 INT16 accumulate 布局

INT16 将 4 个 `temp` 当成一个大整数：

```text
{temp3,temp2,temp1,temp0}
```

每个 accumulate column 对应 1 个 INT16 logical output。

由于当前 `WD3=19`，一个 INT16 logical result 的低 32 bit 分布为：

```text
bits [18:0]  = temp0
bits [31:19] = temp1[12:0]
```

当前 `DCIM_Tile` 的 INT16 输出提取使用：

```text
raw_int16 = {temp2,temp1,temp0}
int16_result = raw_int16[31:0]
```

这是为了取完整累加结果的低 32 bit，而不是只取 `temp0`。

## 8. OBUF 输出布局

### 8.1 INT8 输出

INT8 每 Tile 输出 8 个 int32：

```text
8 × 32 bit = 256 bit
```

因此写 2 个 128-bit OBUF word：

```text
word 0: int8_result[0..3]
word 1: int8_result[4..7]
```

地址：

```text
out_base_addr + 0
out_base_addr + 1
```

### 8.2 INT16 输出

INT16 每 Tile 输出 4 个 int32：

```text
4 × 32 bit = 128 bit
```

因此只写 1 个 128-bit OBUF word：

```text
word 0: int16_result[0..3]
```

地址：

```text
out_base_addr
```

## 9. 支持的计算类型

当前 DCIM 设计底层支持以下 mode 定义：

```text
MODE_UINT4  = 3'b000
MODE_UINT8  = 3'b010
MODE_UINT16 = 3'b011
MODE_INT4   = 3'b100
MODE_INT8   = 3'b110
MODE_INT16  = 3'b111
```

但在本 lite 工程当前 module test 和主要数据流中，重点验证的是：

| 模式 | 当前用途 | 说明 |
|---|---|---|
| INT8 | 常规 DCIM matmul/conv 主路径 | 真实网络权重/激活的主要路径 |
| INT16 | 专用验证路径 | 用 4-bit 乘法阵列拼出 INT16 activation × INT16 weight，用于功能验证 |
| INT4/UINT4/UINT8/UINT16 | RTL 内部有模式定义 | 当前 lite module_tb 未作为主路径系统验证 |

## 10. 支持的算子与维度要求

DCIM 本质执行 im2col 后的矩阵乘：

```text
A[M, K] × W[N, K]^T → O[M, N]
```

其中每个 Tile 负责一部分输出通道。

### 10.1 K 维要求

每个 acc row 处理：

```text
DCIM_CH_IN = 16
```

个输入元素。因此：

```text
acc_depth = ceil(K / 16)
```

要求：

```text
acc_depth <= DCIM_ACC_MAX = 80
```

所以当前最大 K 为：

```text
K_max = 80 × 16 = 1280
```

若实际 K 不是 16 的整数倍，软件/golden 侧需要对 im2col 和 weight 的尾部补 0，使硬件仍按 `acc_depth × 16` 个元素计算。

### 10.2 M 维要求

M 是 im2col 后的输出像素数或矩阵行数。

硬件每次 `DCIM_EXEC` 处理一个 M 行，也就是一个 pixel / one im2col row。多个 M 由指令循环多次执行：

```text
for px in range(M):
    配置 ACT_BASE / OUT_BASE
    DCIM_EXEC
    WAIT_DCIM
```

因此 M 本身没有被单个 Tile 状态机固定限制，但受限于：

- IBUF 激活区域容量。
- OBUF 输出区域容量。
- 指令 BRAM 容量。
- 仿真/运行时间。

### 10.3 N 维 / 输出通道要求

当前 lite 配置有 8 个 Tile。

#### INT8

每 Tile 输出 8 个 logical output channels：

```text
N_per_tile_INT8 = 8
```

8 个 Tile 一次覆盖：

```text
N_INT8_per_exec_all_tiles = 8 tiles × 8 channels = 64 channels
```

如果 N 小于 64，可通过 `tile_mask` 只启用部分 Tile，或者在 golden/check 中忽略无效尾部通道。

如果 N 大于 64，需要软件分多轮 Tile/channel block 执行，或者扩展阵列规模。

#### INT16

每 Tile 输出 4 个 logical output channels：

```text
N_per_tile_INT16 = 4
```

8 个 Tile 一次覆盖：

```text
N_INT16_per_exec_all_tiles = 8 tiles × 4 channels = 32 channels
```

如果 N 大于 32，也需要分多轮执行。

### 10.4 卷积支持范围

卷积通过 im2col 转成 matmul。对于卷积：

```text
K = C_in × K_h × K_w
M = H_out × W_out
N = C_out
```

当前支持范围由 `acc_depth <= 80` 决定：

```text
ceil(C_in × K_h × K_w / 16) <= 80
```

等价于：

```text
C_in × K_h × K_w <= 1280
```

常见情况：

| 卷积 | K | 是否满足 |
|---|---:|---|
| 1×1, C_in <= 1280 | C_in | 满足 |
| 3×3, C_in <= 142 | 9*C_in | 满足到 1278 |
| 6×6, C_in <= 35 | 36*C_in | 满足到 1260 |

当前测试中已覆盖：

- 1×1 conv。
- 3×3 conv。
- 6×6 conv。
- acc_depth 从较小值到较大值的 smoke cases。

## 11. IBUF/OBUF 地址与数据布局要求

### 11.1 IBUF activation 布局

INT8：

```text
act.hex word index = px*acc_depth + row_cnt
每个 word: 16 个 int8 activation
```

INT16：

```text
act.hex word index = px*acc_depth*2 + row_cnt*2 + {0,1}
每两个 word: 16 个 int16 activation
```

因此 INT16 的 `ACT_BASE` 步进是：

```text
px_stride_words = acc_depth * 2
```

### 11.2 IBUF weight 布局

每个 Tile 的 weight 区域大小：

```text
acc_depth × CYCLE words
```

Tile `t` 的 weight base 通常为：

```text
wei_base[t] = wei_base_global + t * acc_depth * CYCLE
```

### 11.3 OBUF 输出布局

INT8：

```text
words_per_tile_per_px = 2
out_word = out_base + px * num_tiles * 2 + tile * 2 + {0,1}
```

INT16：

```text
words_per_tile_per_px = 1
out_word = out_base + px * num_tiles + tile
```

## 12. 调试建议

若 INT16 出现 mismatch，建议按以下链路逐级对齐：

```text
IBUF activation word
  → conv_data
  → act_nibble_converter phase0..3
  → maArray per-phase partial sum
  → mergeArray merged partial
  → accumulateArray after each row_cnt
  → DCIM_Tile int16_extract
  → OBUF write data/address
```

重点检查：

1. `acc_depth_int16` 是否为 `ceil(K/16)`。
2. INT16 activation 是否每 row 读两个 word。
3. activation nibble 顺序是否为 `[15:12] → [11:8] → [7:4] → [3:0]`。
4. INT16 weight packing 是否把 logical channel 的 4 个 nibble 放在 physical lanes `4i+0..4i+3`。
5. `mergeArray` 的 `w_s2=4'b1000` 是否和最高 weight nibble signed 对齐。
6. `DCIM_Tile` 输出是否从 `{temp2,temp1,temp0}[31:0]` 提取，而不是只取 `temp0`。
