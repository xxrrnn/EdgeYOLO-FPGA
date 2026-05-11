# PE Array - 多 Tile 并行 GEMM 加速器

## 概述

PE Array 是一个参数化的多 Tile 并行计算阵列，用于加速矩阵乘法（GEMM）运算。它基于 DCIM（Digital Compute-In-Memory）核心，采用 Weight Stationary 数据流模式。

## 当前状态

**✅ 多 Tile 并行测试通过，CNN im2col 矩阵乘法测试通过，Golden Model 验证通过**

已完成的模块：
- `GEMM_Top.sv` - 顶层模块
- `PE_Array.sv` - PE 阵列（含 IBUF 轮询仲裁、done 信号锁存）
- `DCIM_Tile.sv` - 单个 Tile（支持 IBUF 授权握手）
- `OBUF_Arbiter.sv` - OBUF 仲裁器
- `AXI_Lite_Regs.sv` - AXI-Lite 寄存器

测试结果：
- 18 个测试用例全部通过
- 支持 NUM_TILES=8 并行计算（128 输出通道）
- 支持 ACC=72（K=1152）的 im2col 场景
- Golden Model 数值验证通过

---

## 硬件架构

### 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              GEMM_Top                                    │
│  ┌─────────────────┐    ┌─────────────────────────────────────────────┐ │
│  │  AXI_Lite_Regs  │───▶│                 PE_Array                    │ │
│  │  (配置寄存器)    │    │                                             │ │
│  └─────────────────┘    │  ┌─────────────────────────────────────────┐│ │
│         ▲               │  │           IBUF 轮询仲裁器                 ││ │
│         │               │  │  (Round-Robin, 每周期授权一个 Tile)       ││ │
│    AXI-Lite             │  └──────────────────┬──────────────────────┘│ │
│                         │                     │ ibuf_rd_grant[N-1:0]  │ │
│                         │  ┌──────────────────┼──────────────────────┐│ │
│                         │  │ ┌────────┐ ┌────────┐       ┌────────┐ ││ │
│                         │  │ │ Tile 0 │ │ Tile 1 │  ...  │ Tile N │ ││ │
│                         │  │ │ (优先) │ │        │       │        │ ││ │
│                         │  │ └───┬────┘ └───┬────┘       └───┬────┘ ││ │
│                         │  │     │ obuf_wr  │                │      ││ │
│                         │  └─────┼──────────┼────────────────┼──────┘│ │
│                         │        ▼          ▼                ▼       │ │
│                         │  ┌─────────────────────────────────────────┐│ │
│                         │  │           OBUF_Arbiter                  ││ │
│                         │  │    (固定优先级: Tile 0 > 1 > ... > N)    ││ │
│                         │  └──────────────────┬──────────────────────┘│ │
│                         │                     │                       │ │
│                         │  ┌────────┐    ┌────┴────┐                  │ │
│                         │  │  IBUF  │    │  OBUF   │                  │ │
│                         │  │ (共享) │    │ (共享)  │                  │ │
│                         │  │ 双端口 │    │ 双端口  │                  │ │
│                         │  └───┬────┘    └────┬────┘                  │ │
│                         └──────┼──────────────┼───────────────────────┘ │
│                                │              │                         │
└────────────────────────────────┼──────────────┼─────────────────────────┘
                                 ▼              ▼
                            IBUF Port A    OBUF Port A
                            (外部写入)      (外部读取)
```

### 数据流（Weight Stationary）

```
时间轴 ──────────────────────────────────────────────────────────────────▶

Phase 1: 权重加载（每个 Tile 轮询读取 IBUF）
┌─────────────────────────────────────────────────────────────────────────┐
│  Tile 0: 读 wei[0] → 读 wei[1] → ... → 读 wei[7]                        │
│  Tile 1:            读 wei[0] → 读 wei[1] → ... → 读 wei[7]             │
│  ...                                                                    │
│  Tile N:                                    读 wei[0] → ... → 读 wei[7] │
└─────────────────────────────────────────────────────────────────────────┘

Phase 2: ppCache 加载 + 交换

Phase 3: 激活读取 + 计算（每个 Tile 轮询读取相同激活地址）
┌─────────────────────────────────────────────────────────────────────────┐
│  for each row in num_rows:                                              │
│    Tile 0: 读 act[row] → 计算 → (累加)                                  │
│    Tile 1:              读 act[row] → 计算 → (累加)                     │
│    ...                                                                  │
│    Tile N:                                   读 act[row] → 计算         │
└─────────────────────────────────────────────────────────────────────────┘

Phase 4: 结果写回（优先级仲裁写入 OBUF）
┌─────────────────────────────────────────────────────────────────────────┐
│  Tile 0: 写 result → (等待)                                             │
│  Tile 1:            写 result → (等待)                                  │
│  ...                                                                    │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 模块详细说明

### 1. PE_Array.sv

**功能**：PE 阵列核心，管理多个 DCIM_Tile 的并行计算。

**关键逻辑**：

1. **IBUF 轮询仲裁**：
   ```verilog
   // 轮询仲裁逻辑 - 从 rr_ptr 开始，找到第一个请求的 Tile
   for (i = 0; i < NUM_TILES; i++) begin
       j = (rr_ptr + i) % NUM_TILES;
       if (tile_ibuf_rd_en[j] && !ibuf_any_grant) begin
           ibuf_rd_grant[j] = 1'b1;
           ibuf_granted_idx = j;
           ibuf_any_grant = 1'b1;
       end
   end
   ```

2. **Done 信号锁存**：
   ```verilog
   // 锁存每个 Tile 的 done 信号，确保所有 Tile 完成后才输出全局 done
   always_ff @(posedge clk) begin
       if (ready && !start)
           tile_done_latch <= 0;  // 清除锁存
       else
           tile_done_latch <= tile_done_latch | tile_done;  // 锁存
   end
   assign done = &tile_done_latch;
   ```

**参数**：
| 参数 | 默认值 | 说明 |
|------|--------|------|
| NUM_TILES | 8 | Tile 数量 |
| ACC | 80 | 最大累加深度 |
| BUF_ADDR_WIDTH | 14 | 缓冲区地址位宽 |
| BUF_DATA_WIDTH | 128 | 缓冲区数据位宽 |
| WEIGHT_TILE_SIZE | 8 | 每个 Tile 的权重占用地址数 |

### 2. DCIM_Tile.sv

**功能**：单个计算 Tile，封装 DCIM 核心。

**状态机**：
```
ST_IDLE → ST_LOAD_WEI_ADDR → ST_LOAD_WEI_WAIT → ST_LOAD_WEI → (循环8次)
       → ST_PREP_PPCACHE → ST_LOAD_PPCACHE → ST_SWAP_PPCACHE
       → ST_LOAD_ACT_ADDR → ST_LOAD_ACT_WAIT → ST_LOAD_ACT
       → [INT16: ST_LOAD_ACT2_ADDR → ST_LOAD_ACT2_WAIT → ST_LOAD_ACT2]
       → ST_COMPUTE → (循环 num_rows 次)
       → ST_WAIT_RESULT → ST_DONE → ST_IDLE
```

**关键信号**：
| 信号 | 方向 | 说明 |
|------|------|------|
| ibuf_rd_addr | 输出 | IBUF 读地址 |
| ibuf_rd_en | 输出 | IBUF 读使能 |
| ibuf_rd_data | 输入 | IBUF 读数据（广播） |
| ibuf_rd_grant | 输入 | IBUF 读授权（来自仲裁器） |
| obuf_wr_req | 输出 | OBUF 写请求 |
| obuf_wr_grant | 输入 | OBUF 写授权 |

**授权等待逻辑**：
```verilog
ST_LOAD_WEI_WAIT: begin
    ibuf_enb <= 1'b1;
    if (ibuf_rd_grant)
        grant_received <= 1'b1;  // 收到授权
    if (grant_received)
        wait_cnt <= wait_cnt + 1;  // 开始计数等待数据
end
```

### 3. OBUF_Arbiter.sv

**功能**：OBUF 写入仲裁器，采用固定优先级。

**仲裁逻辑**：
```verilog
// 固定优先级：Tile 0 > Tile 1 > ... > Tile N
for (i = 0; i < NUM_TILES; i++) begin
    if (tile_wr_req[i] && !any_grant) begin
        grant[i] = 1'b1;
        any_grant = 1'b1;
    end
end
```

### 4. AXI_Lite_Regs.sv

**功能**：AXI-Lite 配置寄存器模块。

---

## 输入输出接口

### PE_Array 接口

```verilog
module PE_Array #(
    parameter NUM_TILES = 8,
    parameter ACC = 80,
    ...
)(
    // 时钟复位
    input  wire        clk,
    input  wire        rst_n,
    
    // 控制接口
    input  wire        start,           // 启动信号（电平）
    output wire        done,            // 完成信号（所有 Tile 完成）
    output wire        ready,           // 就绪信号（所有 Tile 空闲）
    output wire [N-1:0] tile_done,      // 各 Tile 完成状态
    output wire [N-1:0] tile_ready,     // 各 Tile 就绪状态
    
    // 配置接口
    input  wire [2:0]  mode,            // 计算模式
    input  wire [6:0]  acc_depth,       // 累加深度
    input  wire [15:0] num_rows,        // 激活行数
    input  wire [13:0] wei_base_addr,   // 权重基地址
    input  wire [13:0] act_base_addr,   // 激活基地址
    input  wire [13:0] out_base_addr,   // 输出基地址
    input  wire [N*14-1:0] tile_out_offset, // 各 Tile 输出偏移
    
    // IBUF 外部接口（端口 A）
    input  wire [15:0] ibuf_wea,        // 写使能（字节）
    input  wire [13:0] ibuf_addra,      // 地址
    input  wire [127:0] ibuf_dina,      // 写数据
    input  wire        ibuf_ena,        // 使能
    output wire [127:0] ibuf_douta,     // 读数据
    
    // OBUF 外部接口（端口 A）
    input  wire [15:0] obuf_wea,
    input  wire [13:0] obuf_addra,
    input  wire [127:0] obuf_dina,
    input  wire        obuf_ena,
    output wire [127:0] obuf_douta
);
```

---

## 寄存器映射（AXI-Lite）

| 地址 | 名称 | 位域 | 描述 |
|------|------|------|------|
| 0x00 | CTRL | [0]=start, [1]=soft_reset | 控制寄存器 |
| 0x04 | STATUS | [0]=ready, [1]=done, [15:8]=tile_ready, [23:16]=tile_done | 状态寄存器 |
| 0x08 | MODE | [2:0]=mode | 计算模式 (0x6=INT8, 0x7=INT16) |
| 0x0C | ACC_DEPTH | [6:0]=acc_depth | 累加深度 |
| 0x10 | NUM_ROWS | [15:0]=num_rows | 激活行数 |
| 0x14 | WEI_BASE | [13:0]=wei_base_addr | 权重基地址 |
| 0x18 | ACT_BASE | [13:0]=act_base_addr | 激活基地址 |
| 0x1C | OUT_BASE | [13:0]=out_base_addr | 输出基地址 |
| 0x20-0x3C | TILE_OUT_OFFSET[0-7] | [13:0] | 各 Tile 输出偏移 |

---

## 内存布局

### IBUF 布局

```
地址范围                    内容
─────────────────────────────────────────────────
0x0000 - 0x0007            Tile 0 权重 (8 × 128-bit)
0x0008 - 0x000F            Tile 1 权重
0x0010 - 0x0017            Tile 2 权重
0x0018 - 0x001F            Tile 3 权重
...
0x0038 - 0x003F            Tile 7 权重
─────────────────────────────────────────────────
0x0100 - ...               激活数据（所有 Tile 共享）
                           INT8:  每行 1 × 128-bit
                           INT16: 每行 2 × 128-bit
```

### OBUF 布局

```
地址范围                    内容
─────────────────────────────────────────────────
OUT_BASE + OFFSET[0]       Tile 0 输出
OUT_BASE + OFFSET[1]       Tile 1 输出
...
OUT_BASE + OFFSET[N-1]     Tile N-1 输出
─────────────────────────────────────────────────
每个输出：
  INT8:  2 × 128-bit = 8 × INT32
  INT16: 1 × 128-bit = 4 × INT32
```

---

## 使用方法

### 1. 初始化

```c
// 软复位
write_reg(CTRL, 0x2);
write_reg(CTRL, 0x0);

// 等待就绪
while (!(read_reg(STATUS) & 0x1));
```

### 2. 配置参数

```c
write_reg(MODE, 0x6);           // INT8 模式
write_reg(ACC_DEPTH, 4);        // 累加深度 4
write_reg(NUM_ROWS, 16);        // 16 行激活
write_reg(WEI_BASE, 0x0000);    // 权重基地址
write_reg(ACT_BASE, 0x0100);    // 激活基地址
write_reg(OUT_BASE, 0x0400);    // 输出基地址

// 设置各 Tile 输出偏移
for (int i = 0; i < NUM_TILES; i++) {
    write_reg(TILE_OUT_OFFSET[i], i * 4);  // INT8: 每个 Tile 2 地址
}
```

### 3. 加载数据

```c
// 加载权重到 IBUF（每个 Tile 8 × 128-bit）
for (int tile = 0; tile < NUM_TILES; tile++) {
    for (int cycle = 0; cycle < 8; cycle++) {
        write_ibuf(WEI_BASE + tile * 8 + cycle, weights[tile][cycle]);
    }
}

// 加载激活到 IBUF
for (int row = 0; row < NUM_ROWS; row++) {
    write_ibuf(ACT_BASE + row, activations[row]);
}
```

### 4. 启动计算

```c
write_reg(CTRL, 0x1);  // 设置 start = 1
```

### 5. 等待完成

```c
while (!(read_reg(STATUS) & 0x2));  // 等待 done = 1
write_reg(CTRL, 0x0);               // 清除 start
```

### 6. 读取结果

```c
for (int tile = 0; tile < NUM_TILES; tile++) {
    int offset = read_reg(TILE_OUT_OFFSET[tile]);
    for (int i = 0; i < num_outputs_per_tile; i++) {
        results[tile][i] = read_obuf(OUT_BASE + offset + i);
    }
}
```

---

## 测试方法

### 编译和仿真

```bash
cd rtl/PE

# 编译
make compile

# 运行仿真
make sim

# 生成 FSDB 波形
make compile_fsdb
make fsdb

# 使用 Verdi 查看波形
make verdi

# 清理
make clean
```

### 测试用例

当前测试平台 `tb/tb_PE_Array.sv` 包含 18 个测试用例：

| 测试组 | 测试内容 | 测试数量 |
|--------|----------|----------|
| Section 1 | 多 Tile 基本功能 | 5 |
| Section 2 | 大 ACC 值（im2col 模拟） | 3 |
| Section 3 | CNN im2col 矩阵乘法 | 7 |
| Section 4 | 连续多次计算 | 3 |

### 测试结果

```
═══════════════════════════════════════════════════════════════
                      TEST SUMMARY
═══════════════════════════════════════════════════════════════
  Total Tests:  18
  Passed:       18
  Failed:       0
═══════════════════════════════════════════════════════════════
  *** ALL TESTS PASSED! ***
═══════════════════════════════════════════════════════════════
```

---

## 进一步测试建议

### 1. 数值正确性验证

当前测试只验证了状态机流程，建议添加：

```systemverilog
// 在 tb_PE_Array.sv 中添加 golden model 验证
task verify_results(input int tile_id, input int num_outputs);
    int errors = 0;
    for (int i = 0; i < num_outputs; i++) begin
        read_obuf(out_base_addr + tile_out_offset[tile_id] + i, dut_result);
        if (dut_result !== golden_results[tile_id][i]) begin
            $display("ERROR: Tile %0d, Output %0d: DUT=%h, Golden=%h",
                     tile_id, i, dut_result, golden_results[tile_id][i]);
            errors++;
        end
    end
    return errors;
endtask
```

### 2. 边界条件测试

```bash
# 建议添加的测试用例
- ACC = 1（最小累加）
- ACC = 80（最大累加）
- num_rows = 1（单行）
- num_rows = 1024（大量行）
- NUM_TILES = 1（单 Tile）
- NUM_TILES = 8（最大 Tile）
```

### 3. 压力测试

```systemverilog
// 连续多次计算，验证状态机复位
for (int batch = 0; batch < 100; batch++) begin
    run_test($sformatf("Stress Test %0d", batch), 16, 4, batch, passed);
end
```

### 4. 时序分析

```bash
# 使用 Vivado 进行综合和时序分析
vivado -mode batch -source synth.tcl

# 检查关键路径
- IBUF 仲裁器 → Tile 授权
- DCIM 核心 → 结果输出
- OBUF 仲裁器 → 写入
```

### 5. 资源利用率分析

```bash
# 综合后检查资源使用
- LUT 使用量
- FF 使用量
- BRAM 使用量
- DSP 使用量
```

---

## 与 ONNX 模型的关系

对于 `best.onnx` 中的卷积层（经过 im2col 转换后）：

| 维度 | 当前支持 | 说明 |
|------|----------|------|
| K（内积） | ✅ ACC=80，最大 K=1280 | 满足 K=1152 (128×3×3) |
| N（输出通道） | ✅ 8 Tile × 16 = 128 | 需要 2 次处理 256 通道 |
| M（输出像素） | 软件控制 | 逐行触发 |

### im2col 映射示例

```
Conv Layer: C_in=128, K=3×3, C_out=256

im2col 后的矩阵乘法:
  A: [M × K] = [H_out×W_out × 1152]  (激活)
  B: [K × N] = [1152 × 256]          (权重)
  C: [M × N] = [H_out×W_out × 256]   (输出)

PE Array 处理:
  - K 维度: ACC = 72 (1152 / 16 = 72)
  - N 维度: 4 次处理 (256 / 64 = 4)
  - M 维度: 逐行处理
```

---

## 文件结构

```
rtl/PE/
├── GEMM_Top.sv         # 顶层模块
├── PE_Array.sv         # PE 阵列（含仲裁器）
├── DCIM_Tile.sv        # 单个 Tile
├── OBUF_Arbiter.sv     # OBUF 仲裁器
├── AXI_Lite_Regs.sv    # AXI-Lite 寄存器
├── filelist.f          # RTL 文件列表
├── Makefile            # 构建脚本
├── README.md           # 本文档
└── tb/
    └── tb_PE_Array.sv  # 测试平台
```

---

## 后续工作

1. **数值正确性验证**：添加 golden model 对比
2. **增加 Tile 数量**：将 NUM_TILES 增加到 16，支持 N=256 单次处理
3. **DMA 集成**：添加 AXI DMA 接口，自动搬运数据
4. **流水线优化**：权重预加载，隐藏加载延迟
5. **Vivado 综合**：验证时序和资源使用
