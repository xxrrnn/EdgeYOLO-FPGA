# EdgeYOLO-FPGA-lite

DCIM + im2col 裁剪验证项目。详见 `.cursor/rules/project-context.mdc`。

---

## VPU_BUF 容量分析与算子 Tiling 约束（2026-06-12）

### 背景：VPU_BUF 与 DCIM buf 完全分离

chip-v3 架构中，VPU 算子（im2col/dqa/qa/mp/us/ad）与 DCIM 使用**完全独立**的存储资源：

| 存储 | 大小 | 访问者 | 用途 |
|------|------|--------|------|
| `VPU_BUF` | **8MB** (ADDR_WIDTH=19) | VPU only | 所有 VPU 算子的输入/输出 feature buffer |
| `tile_ibuf[0~3]` | 512KB × 4 = 2MB | CDMA + DCIM_Tile | DCIM 激活（im2col 结果）+ 权重 |
| `tile_obuf[0~3]` | 256KB × 4 = 1MB | DCIM_Tile + CDMA | DCIM INT32 输出，DQA 读入前暂存 |

> `Global_VPU.v` 端口名沿用了旧版的 `obuf_*` 信号名，但实际连接的是 `vpu_buf`（8MB），与 DCIM buf 无关。

---

### 设计前提：任意时刻 VPU 只处理一个算子

**软件保证顺序执行**：每个算子完成（HBM→VPU_BUF→算子→VPU_BUF→HBM）后才启动下一个，不存在并发。因此：

- **VPU_BUF 可作为 flat scratchpad**，不需要固定 slot 划分
- 任意时刻只有一个算子的 input+output 同时驻留 VPU_BUF
- 软件动态分配地址：`src = 0x000000`，`dst = src + src_size`，处理完后 DMA 回 HBM，下一算子复用同一空间

---

### 固定 slot 布局：不必要（纯软件惯例）

`golden_module_tb.py` 中的 `OBUF_SRC0/FEAT0/IM2COL/DQA/SHORT` 等常量是**软件测试惯例**，不是硬件约束：

- `im2col_unit` / `mp_unit` / `us_unit` / `ad_unit` RTL 接受任意 `src_addr`/`dst_addr`（32-bit，无固定偏移假设）
- `VPU_ADDR_WIDTH=24` 给出 16MB 字节寻址空间，完全覆盖 8MB VPU_BUF

---

### VPU_BUF 实际峰值需求（yolov5n @ 320×320）

每个算子的"峰值"= 其 input + output **同时**在 VPU_BUF 的最大尺寸：

| 算子 | 层 | 峰值（input+output） | 说明 |
|------|----|--------------------|------|
| **im2col** | model.0 (6×6, 320→160) | **3500 KB = 3.4MB** ★最大 | feat_in 300KB + im2col_out 3200KB |
| im2col | model.1 (3×3, 160→80) | 1600 KB | feat_in 400KB + im2col_out 1200KB |
| DQA FP32 | model.0 | 1600 KB | FP32 输出（输入在 tile_obuf，不占 VPU_BUF） |
| ad (residual) | 40×40×64 | 1200 KB | input_a + input_b + output FP32 |
| us (Upsample 2×) | 最大 20→40, 128ch | 1000 KB | 200KB in + 800KB out FP32 |
| mp (MaxPool, SPPF) | 256ch×10×10 | 200 KB | FP32 in + out |

**结论：**
```
全网络最大单次需求 = 3500KB = 3.4MB  (model.0 im2col 阶段)
VPU_BUF 最小合理配置 = 4MB（余量 600KB）
当前配置 8MB：余量充裕，无需调整
```

---

### im2col 分 H_tile：**不必要**

| 问题 | 答案 |
|------|------|
| 全量 im2col 放得进 VPU_BUF 吗？ | ✅ 3.4MB < 4MB（最小配置） |
| RTL 支持大尺寸吗？ | ✅ `oh/ow` 是 16-bit signed（上限 32767），支持 OH=OW=160 |
| 当前 RTL/testbench 有 H_tile 机制吗？ | ❌ 没有，也不需要加 |
| 软件需要分块循环吗？ | ❌ 一条 `OP_VPU_EXEC (UNIT_IM2COL)` 覆盖全部像素 |

### mp / us / ad 分 tile：**不必要**

yolov5n 中三个算子处理的是网络深层小尺寸 FP32 张量，峰值均远低于 4MB：
- **MaxPool**（SPPF）：200KB；**Upsample**：≤1MB；**Add**：≤1.2MB

---

### 各算子 tiling 机制最终总结

| 算子 | 分块需要？ | 控制层级 | 说明 |
|------|-----------|---------|------|
| `im2col`（H×W 维） | **不需要** | — | 一次指令处理全部 OH×OW 像素 |
| `im2col`（CH_IN 维 c_chunk） | RTL 内部自动 | RTL | ADDR_WIDTH=32，无软件感知 |
| `DCIM_Layer`（acc_depth chunk） | RTL 内部自动 | RTL | 软件只传 acc_depth 参数 |
| `DCIM_Layer`（pixel 外循环） | RTL 内部自动 | INST_Decoder | 软件传 num_pixels |
| `mp / us / ad` | **不需要** | — | 一次指令线性扫描 |

**关键：VPU_BUF 8MB 完全够用，固定 slot 布局不必要，所有分块逻辑在硬件内自动完成。软件（编译器/golden）使用固定 slot 只是当前测试框架的惯例，迁移到 flat 动态分配不需要改 RTL。**

---

## chip-v3 XPM 全面改造（2026-06-12）

### 核心变更

所有 URAM buffer (`tile_ibuf`, `tile_obuf`, `vpu_buf`) 从手动 multi-bank (`obuf_bank`) 实现替换为 Xilinx XPM `xpm_memory_tdpram`：

- `MEMORY_PRIMITIVE = "ultra"`, `CASCADE_HEIGHT = 2`, `READ_LATENCY = 10`
- 单个 XPM 实例替代 multi-bank + bank_sel_pipe + MUX 逻辑
- VPU_BUF 扩容：1MB → 8MB（ADDR_WIDTH=19）
- 彻底消除 URAM cascade timing 风险（READ_LATENCY=10，250MHz 下无 violation 可能）

### 架构

```
XDMA --> SmartConnect (NUM_MI=13)
 ├─→ tile_ibuf_ctrl_0~3 (512KB each, per-tile IBUF XPM)
 ├─→ tile_obuf_ctrl_0~3 (256KB each, per-tile OBUF XPM)
 ├─→ vpu_buf_ctrl (8MB, XPM)
 ├─→ vpu_wb_ctrl (32KB)
 ├─→ inst_bram (128KB)
 └─→ vpu_regs (4KB)
```

### 地址映射

| 地址 | 容量 | 说明 |
|------|------|------|
| 0x1_0000_0000 | 512KB | tile_ibuf[0] |
| 0x1_0008_0000 | 512KB | tile_ibuf[1] |
| 0x1_0010_0000 | 512KB | tile_ibuf[2] |
| 0x1_0018_0000 | 512KB | tile_ibuf[3] |
| 0x1_0100_0000 | 256KB×4 | tile_obuf[0~3] |
| 0x1_0200_0000 | 8MB | VPU_BUF |
| 0x1_0300_0000 | 32KB | VPU WB |
| 0x1_0400_0000 | 128KB | INST_BRAM |
| 0x1_0500_0000 | 4KB | VPU_AXI_Regs |

### 关键参数（chip_defines.vh）

```
DCIM_TILE_IBUF_ADDR_WIDTH      = 15  (512KB per tile)
DCIM_TILE_IBUF_RD_LATENCY     = 10  (XPM READ_LATENCY)
DCIM_TILE_OBUF_ADDR_WIDTH     = 14  (256KB per tile)
DCIM_TILE_OBUF_RD_LATENCY     = 10
VPU_BUF_ADDR_WIDTH            = 19  (8MB)
VPU_BUF_RD_LATENCY            = 10
*_AXI_BRAM_READ_LATENCY       = 10  (全部统一)
```

### 修改文件清单

| 文件 | 修改内容 |
|------|----------|
| `rtl/chip/tile_ibuf.v` | XPM xpm_memory_tdpram 512KB |
| `rtl/chip/tile_obuf.v` | XPM xpm_memory_tdpram 256KB |
| `rtl/vpu/vpu_buf.v` | XPM xpm_memory_tdpram 8MB |
| `rtl/chip/chip_defines.vh` | 删除 NUM_BANKS/NBPIPE, 统一 RD_LATENCY=10, VPU_BUF 8MB |
| `rtl/chip/DCIM_Array_bd.v` | 4 组 tile_ibuf*_ext_* + 4 组 tile_obuf*_ext_* 端口 |
| `rtl/vpu/Global_VPU_top.v` | MEM_SIZE=8MB, READ_LATENCY=10 |
| `scripts/ip/bd/lite/address.tcl` | VPU_BUF 1M→8M |
| `scripts/ip/bd/lite/hbm.tcl` | 注释更新 |
| `scripts/ip/bd/lite/connect.tcl` | 注释更新 |
| `xdc/chip/chip_timing.xdc` | 更新注释 (XPM 无需 MCP) |
| `scripts/chip-lite/3_synth_nonproj.tcl` | 删除 obuf_bank.v |
| `scripts/chip-lite/2_bd.tcl` | 删除 obuf_bank.v |
| `rtl/tb/lite_bd/sim/gen_bd_rtl_extra.sh` | 删除 ibuf.v/obuf_bank.v, 加 tile_ibuf.v |
| `rtl/chip/filelist.f` | 删除 obuf_bank.v/ibuf.v |
| `rtl/tb/lite_bd/module_tb/tb_lite_bd_module.sv` | backdoor 路径→XPM `u_xpm.xpm_memory_base_inst.mem[]` |
| `rtl/tb/lite_bd/module_tb/golden_module_tb.py` | 注释更新 (8MB) |

### 测试验证

改动后必须执行：

```bash
cd rtl/tb/lite_bd/module_tb
make export    # XPM 模块需重新生成仿真文件
make compile   # 重编 simv
make sim-smoke # 验证基本功能
```

验证 XPM 改造正确性的推荐命令：

```bash
# DCIM 全路径（验证 tile_ibuf XPM READ_LATENCY=10）
timeout 2h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all STOP_ON_FAIL=0 LOG=1

# conv_pipeline（验证 tile_obuf XPM 写入正确）
timeout 3h make rebuild-suite MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all QUANT=all STOP_ON_FAIL=0 LOG=1

# VPU 单元（验证 vpu_buf XPM 8MB 读写正确）
timeout 2h make rebuild-suite MODULE_CASE=im2col BATCH_SUITE=im2col_all STOP_ON_FAIL=0 LOG=1

# 全量回归
timeout 8h make sim-all STOP_ON_FAIL=0 LOG=1
```

详细测试文档见 `rtl/tb/lite_bd/module_tb/README.md`。

---

## 测试框架：VPU_BUF Flat Scratchpad 动态地址（2026-06-12）

### 变更说明

`golden_module_tb.py` 中所有单算子 `make_*_case` 函数由**固定 slot 常量**迁移为**动态地址分配**（`alloc_flat()`）。

**变更前**（固定常量）：
```python
# 固定偏移，所有 case 共享同一布局
OBUF_SRC0 = 0x000000
OBUF_DST  = 0x100000
OBUF_AUX  = 0x180000
# im2col 指令中硬编码：
fast_inst = vpu_exec(UNIT_IM2COL, OBUF_SRC0, 0, ..., OBUF_DST, ...)
```

**变更后**（动态分配）：
```python
# 按实际数据大小紧凑分配，充分利用 8MB VPU_BUF
src_bytes = h * w * meta.in_ch
im2col_bytes = oh * ow * meta.acc_depth * DCIM_CH_IN
src_off, dst_off = alloc_flat(src_bytes, im2col_bytes)
fast_inst = vpu_exec(UNIT_IM2COL, src_off, 0, ..., dst_off, ...)
```

### 影响范围

| 函数 | 变化 |
|------|------|
| `make_im2col_case` | `src=0`, `dst=align(feat_bytes)` |
| `make_dqa_case` | `src=0`, `dst=align(src_words*16)` |
| `make_qa_case` | `src=0`, `dst=align(src_words*16)` |
| `make_us_case` | `src=0`, `dst=align(src_words*16)` |
| `make_mp_case` | `src=0`, `dst=align(src_words*16)` |
| `make_add_case` | `src0=0`, `src1=align(a_bytes)`, `dst=align(src0+src1)` |
| `make_conv_pipeline_case` (INT8) | `src→im2col→dcim→dst` 紧凑链 |
| `make_conv_pipeline_case` (INT16) | 同上，各段按 INT16 宽度分配 |
| `ObufSlots` (SegmentBuilder) | **不变**，ping-pong 槽位保留用于多层网络链 |
| `make_concat_by_cdma_case` | **不变**，多源需要固定偏移布局 |
| `make_dcim_case` | **不变**，dst 使用 `TILE_OBUF_DST` sentinel |

### testbench 兼容性

`tb_lite_bd_module.sv` **无需修改**：它从 `checks.txt` 动态读取 `dst_obuf` 地址（`$fscanf`），
完全通用，支持任意合法 VPU_BUF 字节偏移（只要 `dst < TILE_OBUF_CHK_SENTINEL = 0x800000`）。

### 验证 golden 生成（Python 层，不需 RTL 仿真）

```bash
cd rtl/tb/lite_bd/module_tb
python3 golden_module_tb.py --module im2col --out-dir /tmp/test_im2col
cat /tmp/test_im2col/checks.txt     # dst 地址随输入形状变化
python3 golden_module_tb.py --module dqa --out-dir /tmp/test_dqa
python3 golden_module_tb.py --module conv_pipeline --out-dir /tmp/test_pipe
```

---

## Timing Closure: obuf_din_r → VPU_BUF URAM 路由违例分析与方案（2026-06-13）

### 问题描述

250MHz (4ns) 实现中，`obuf_din_r_reg` → `vpu_buf` URAM 路径出现 **-0.710ns setup violation**：

| 项目 | 数值 |
|------|------|
| Source | `u_global_vpu/obuf_din_r_reg[11]` @ SLICE_X79Y185 (CR **X2Y3**) |
| Dest | `u_vpu_buf/u_uram/mem_reg_uram_104/DIN_B[11]` @ URAM288_X4Y0 (CR **X6Y0**) |
| Logic Levels | 0 (pipeline 已消除组合逻辑) |
| Logic Delay | 0.079ns (2.16%) |
| Route Delay | **3.579ns (97.84%)** ← 纯布线距离 |
| Clock Skew | -0.670ns |

**根因**：Placer 将 VPU 逻辑放在 SLR0 中部偏左 (CRX2), 而 URAM 散布到最右列 (CRX6)，导致对角跨越 4+3=7 个 Clock Region。

### VU37P SLR0 URAM 物理布局（DCP 实测 2026-06-13）

```
设备: xcvu37p-fsvh2892-2L-e
SLR0 总 URAM: 5 列 × 64 = 320 sites (Y=0~63)
VPU_BUF 需要 256 个 URAM (80% 占用率)

URAM 列    Clock Region X    SLICE X 范围
────────   ──────────────    ─────────────
X=0        CRX=1             SLICE 31~56
X=1        CRX=3             SLICE 95~116
X=2        CRX=4             SLICE 117~145
X=3        CRX=5             SLICE 146~175
X=4        CRX=6             SLICE 176~205    ← 距 VPU 逻辑最远

SLR0 Clock Region 行: Y0~Y3, 每行 16 个 URAM Y 坐标
obuf_din_r_reg 分布: SLICE X=56~132 (CRX2~CRX3), Y=85~190 (CRY1~CRY3)
```

### 已选方案: 方案 B — URAM Pblock + VPU 逻辑 Pblock

**已写入 `xdc/chip/chip_timing.xdc` Section 6。**

策略：
1. **URAM Pblock (HARD)**：约束 256 个 URAM 到 `URAM288_X0Y0:X3Y63`（排除最远的 X=4 列/CRX6）
2. **VPU 逻辑 Pblock (SOFT)**：约束 `u_global_vpu` 到 `CLOCKREGION_X1Y0:X3Y3`（CRX1~CRX3）

效果预期：obuf_regs(CRX1~3) → URAM(CRX1/3/4/5) 最大水平距离从 4 CR 降到 ≤2 CR。

### 备选方案一览（如方案 B 不足时使用）

| 方案 | 描述 | 把握 | RTL 改动 | 代价 |
|------|------|------|---------|------|
| **A** | 仅 URAM Pblock X0~3 | 60% | 无 | 仅约束 URAM 位置，逻辑位置不管 |
| **B** ✓ | URAM Pblock + VPU 逻辑 Pblock | 85% | 无 | 逻辑被压缩到 3 个 CRX，可能拥挤 |
| **C** | 再加一级 Pipeline (obuf_din_rr) | 95% | 是 | 写延迟 +1 cycle (11→12), 需改 valid 链 |
| **D** | MCP 2 (set_multicycle_path) | 99%* | 无 | *前提: 证明 DIN 在 2 cycle 窗口内稳定 (很难) |
| **E** | 降频 200MHz | 100% | 无 | 性能降 20% |
| **F** | B + C 组合 | 99% | 是 | 延迟 +1 cycle + Pblock 约束 |

### 方案 C 实施要点（如需使用）

在 `Global_VPU.v` 或 `vpu_buf.v` 入口再加一级寄存器：

```verilog
// 方案 C: 在 vpu_buf 入口再打一拍（或在 Global_VPU 输出端再打一拍）
reg [DATA_WIDTH-1:0] dina_r;
reg [ADDR_WIDTH-1:0] addra_r;
reg [NUM_COL-1:0]    wea_r;
reg                   ena_r;

always @(posedge clk) begin
    dina_r  <= dina;
    addra_r <= addra;
    wea_r   <= wea;
    ena_r   <= mem_ena;
end
// 连接 XPM 用 *_r 信号
```

需同步修改：
- `rd_valid_pipe` 移位链延长 1 拍（RD_LATENCY 参数 +1 或单独处理）
- 所有依赖 `douta_valid` 的下游逻辑延迟对齐
- `chip_defines.vh` 中 `VPU_BUF_RD_LATENCY` 从 10 改为 11
- `address.tcl` 中 `READ_LATENCY` 参数同步

### 方案 D 实施要点（如需使用）

```tcl
# 仅当能证明 obuf_din_r → URAM DIN 路径有 2 cycle 稳定窗口时:
set _obuf_din_r [get_cells -hierarchical -filter {NAME =~ *u_global_vpu/obuf_din_r_reg*}]
set _uram_din   [get_pins -hierarchical -filter {NAME =~ *u_vpu_buf*uram*/DIN_*}]
if {[llength $_obuf_din_r] && [llength $_uram_din]} {
  set_multicycle_path 2 -setup -from $_obuf_din_r -to $_uram_din
  set_multicycle_path 1 -hold  -from $_obuf_din_r -to $_uram_din
}
```

**注意**：vpu_buf URAM 每周期都可能被写入（gb_enb 可连续拉高），MCP 2 大概率不成立，慎用。

### 260612_2213 Build 状态

该 build（无 Pblock 约束）经过 `phys_opt_design` 32 轮迭代后报告 **WNS=+0.009ns**（仅 9ps 余量），说明 Vivado 勉强通过物理优化修复了违例。但 9ps 余量极不稳定，post-route 可能再次变负。方案 B 的 Pblock 约束将在下次 build 中提供稳定余量。

---

## MCP 全部替换为 Pipeline Register（2026-06-13）

### 背景

原设计中 `chip_timing.xdc` Section 4 定义了多组 `set_multicycle_path`，用于放松以下路径的 timing 约束：
- 4.1: DCIM maArray 计算流水（mergeArray→accumulateArray 组合路径过长）
- 4.3a: `ready_r` → inst_decoder FSM（SLR 穿越握手信号）
- 4.3b: `cfg_*_reg` → Tile FSM（配置寄存器跨 SLR 到远端 Tile）

MCP 虽然功能正确，但它依赖 Vivado 理解路径语义，且在物理优化阶段可能产生次优布局。
**本次改造用 pipeline register 彻底替代所有 MCP，使所有路径均可在单周期内完成。**

### 改动清单

| 文件 | 改动内容 | 对应原 MCP |
|------|----------|-----------|
| `rtl/ref/DCIM/src/dcim/postProcess.v` | mergeArray→accumulateArray 之间插入 `pipe_stage` + data register | 4.1c/d |
| `rtl/chip/DCIM_Array_bd.v` | `ready_internal` → `ready_pipe` 寄存器，再输出 | 4.3a |
| `rtl/chip/DCIM_Array.sv` | 新增 `mode_r`/`acc_depth_r`/`*_base_addrs_r`/`tile_mask_r`，Tile 实例化使用 `_r` 版本 | 4.3b |
| `xdc/chip/chip_timing.xdc` | 删除所有 `set_multicycle_path` 语句，Section 4 仅保留注释 | — |

### 时序影响

| Pipeline | Latency 代价 | 性能影响 |
|----------|-------------|----------|
| merge→accumulate | +1 clk / matmul | < 1%（CYCLE=128 拍中的 1 拍） |
| ready_pipe | +1 clk / layer | 可忽略（每层 ~100μs 中多 4ns） |
| cfg_*_r | +0（与已有 start_r 对齐） | 零 |

### 验证

```bash
cd rtl/tb/lite_bd/module_tb
make compile                      # RTL 改动后重编 simv
# DCIM 全量验证（postProcess pipeline 影响）
make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all
# conv_pipeline 验证（含 postProcess + cfg pipeline 完整链路）
make sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all QUANT=all
# 冒烟
make sim-smoke
```

---

## Timing Closure: accumulateArray + VPU start pipeline（2026-06-13）

### 问题描述

移除 MCP 后重新跑实现（build `260613_1126`），`post_phys_opt_failing_paths.rpt` 出现 20 条 violation（WNS = **-0.780ns**），分为 4 类：

| 类别 | 数量 | 路径 | Slack |
|------|------|------|-------|
| accumulate_controller `r_cnt_reg` → `temp*_reg` | 11 | cnt→refresh(fo=1043)→wide_adder(11×CARRY8)→temp | -0.780~-0.743ns |
| maArray `b_reg_reg` → adderTree `r_sum_reg` | 6 | multiplier DSP→adder tree | -0.779~-0.748ns |
| inst_decoder `vpu_unit_choose_reg` → qa_unit `CE` | 2 | 跨模块控制信号 | -0.751ns |
| ppCacheController FSM → cacheMem `CE` | 1 | 内部 FSM fanout | -0.746ns |

### 根因分析

**类别 1**（主 critical path）：`accumulate_controller` 的 `cnt_zero` 信号（= `w_cnt==0`）用于选择"直接赋值"或"累加"，但该信号 fanout=1043（驱动 16 个 AccumulateColumn × 4 temp × 多 bit MUX），且路径包含 11 级 CARRY8 宽加法器。整条路径从 `r_cnt_reg` 出发，经过 2 级 LUT 比较、高扇出 `refresh` 分发、宽加法器、最后到 `temp_reg`，总延迟 4.2ns（其中 route 占 82%）。

**类别 3**：`vpu_unit_choose_reg[15]` 从 inst_decoder 输出，经过 Global_VPU 中的 `unit_active` MUX + 比较逻辑，组合路径到达 qa_unit 内部 FSM CE。

### 修复方案

#### 1. accumulateArray input pipeline（`accumulateArray.v`）

在 `accumulateArray` 模块中，将 `refresh` / `up_data` / `ena` 统一打一拍后再送入 `accumulate` 实例：

```verilog
reg                    refresh_r;
reg [CH_OUT*WD2-1: 0]  up_data_r;
reg                    ena_r;
always @(posedge clk or negedge rstn) begin
    ...
    refresh_r <= w_accu_cnt_zero;
    up_data_r <= up_data;
    ena_r     <= up_valid & up_ready;
end
// accumulate 实例使用 refresh_r / up_data_r / ena_r
```

**效果**：`r_cnt_reg` → `refresh_r` 变为纯寄存器输出（fanout 由工具自动复制），宽加法器的输入全部来自寄存器，timing 路径从 4.2ns 缩短到 <2ns。

对应 `accumulate_controller` 增加 1 级 `pipe_stage`（总共 2 级），bypass 路径也增加 1 级，确保 `dn_valid` 与数据对齐。

#### 2. VPU start pipeline（`Global_VPU.v`）

将 `start` 打一拍为 `start_d1`，所有 unit_start 信号使用 `start_d1`：

```verilog
reg start_d1;
always @(posedge clk or negedge rst_n_local) begin
    if (!rst_n_local) start_d1 <= 1'b0;
    else              start_d1 <= start;
end

assign qa_unit_start = (unit_active == UNIT_QA) ? start_d1 : 1'b0;
// active_* 信号全部使用 *_reg 版本（start 拍已锁存）
// config_ready 在 start/start_d1 期间强制为 0，防止 inst_decoder 误判完成
assign config_ready = ~start & ~start_d1 & (...unit_ready...);
```

**效果**：切断 `vpu_unit_choose_reg` → qa_unit 的组合路径，所有比较逻辑输入来自寄存器。

#### 3. 类别 2 & 4（maArray / ppCache）

这两类 violation 量级接近 timing boundary（-0.75ns），主要由 placement pressure 引起。修复类别 1（释放 CARRY8 链布局空间）和类别 3 后，placer 有更多自由度，预期这两类会自行收敛。如果新 build 仍 fail，再针对性处理。

### 时序影响

| Pipeline | Latency 代价 | 性能影响 |
|----------|-------------|----------|
| accumulateArray input | +1 clk / matmul | < 1%（CYCLE=128 中的 1 拍） |
| VPU start_d1 | +1 clk / VPU 调用 | 可忽略（60 层中每层 1 cycle） |

### 修改文件清单

| 文件 | 改动 |
|------|------|
| `rtl/ref/DCIM/src/dcim/accumulateArray.v` | accumulateArray 加 input pipeline；accumulate_controller 改为 2 级 pipe_stage + bypass pipe_stage |
| `rtl/vpu/Global_VPU.v` | 加 `start_d1`；`active_*` 全用 `*_reg`；`config_ready` 屏蔽 start 窗口 |

### 验证

```bash
cd rtl/tb/lite_bd/module_tb
make compile
# DCIM 验证（accumulateArray pipeline）
make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all
# conv_pipeline 验证（VPU start pipeline + accumulate pipeline 全链路）
make sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all QUANT=all
```

---

## Timing Closure: 删除 Tile Pblock 解除 SLR1 拥塞（2026-06-13）

### 问题描述

build `260613_1104`（post_route）出现 20 条 violation（WNS = **-0.410ns**），全部特征相同：
- **Logic Levels: 0~3**（组合逻辑极浅）
- **Route Delay 占 92~98%**（纯粹物理距离问题）
- **集中在 SLR1**（16/20 条）

### Violation 分类

| 类型 | 数量 | 路径 | Slack | 所在 SLR |
|------|------|------|-------|----------|
| A: `data1_reg_rep` → DSP `a_reg_reg` | 2 | maArray 内部 FF replica 到远端乘法器 | -0.410/-0.408 | SLR0, SLR2 |
| B: `ppCacheController/FSM` → `cacheMem/r_mem CE` | 14 | FSM 地址译码到 128 行寄存器使能 | -0.410~-0.409 | **SLR1** |
| C: `mid_data_q_reg` → `cacheMem/r_mem D` (fo=256) | 2 | 数据寄存器高扇出到全部 cacheMem bit | -0.410/-0.408 | **SLR1** |
| D: `maArray/result_reg` → `accumulate/temp_reg` | 2 | merge→accumulate 宽加法器 | -0.409 | SLR2 |

### 根因分析

**SLR1 CLB 利用率 99.4%**——两个 Tile 被 Pblock 约束到同一 SLR。

关键证据（`post_place_util.rpt` Section 14）：

| SLR | CLB 利用率 | 主要内容 | Violation 数 |
|-----|-----------|---------|-------------|
| SLR0 | 86.0% | Tile 0 + VPU + XDMA | 2 条 |
| **SLR1** | **99.4%** | **Tile 1 + Tile 2** | **16 条** |
| SLR2 | 57.6% | Tile 3 | 2 条 |

**4 Tiles + 3 SLRs 的数学约束**：每 Tile 约 27000 CLB（≈50% SLR），VPU+XDMA 约 20000 CLB。无论如何重新分配，必有 1 个 SLR 装 2 Tiles ≈ 99%：

| 方案 | SLR0 | SLR1 | SLR2 | 问题 |
|------|------|------|------|------|
| 原 (0/12/3) | 87% | **99%** | 58% | SLR1 爆 |
| 改 (0/1/23) | 87% | 50% | **~99%** | SLR2 爆 |
| 改 (0/13/2) | 87% | **~99%** | 50% | SLR1 换了内容但仍爆 |

**结论：纯靠重新分配 Pblock 只是把拥塞搬到另一个 SLR，不解决问题。**

### 解决方案：删除所有 Tile Pblock

**改动文件**：`xdc/chip/chip_timing.xdc` Section 6

**保留**：
- `pblock_axi_vpu`（VPU/XDMA/SmartConnect → SLR0，IS_SOFT=TRUE）
- `pblock_vpu_buf_uram`（256 URAM → X0~X3，IS_SOFT=FALSE）

**删除**：
- `pblock_tile_0`（Tile 0 → SLR0）
- `pblock_tile_12`（Tile 1+2 → SLR1）
- `pblock_tile_3`（Tile 3 → SLR2）
- 所有 `tile_ibuf_ctrl_*` / `tile_obuf_ctrl_*` 的 Pblock 附加

### 为什么可行

| 指标 | 值 | 说明 |
|------|-----|------|
| 整体 CLB 利用率 | 81% | 空间充裕，不需要挤在某一 SLR |
| SLR0↔SLR1 SLL 用量 | 8.75% | 23040 可用，当前 2016 条 |
| SLR1↔SLR2 SLL 用量 | 2.75% | 23040 可用，当前 633 条 |
| Vivado 自由度 | 全局 | 可跨 SLR 混合布局 4 Tile |

删除 Pblock 后，Vivado placer 可以：
1. 将每个 Tile 的逻辑分散到最近的可用 CLB，而不是挤在同一 SLR
2. 利用充裕的 SLL crossing 资源建立跨 SLR 信号路径
3. 在 phys_opt 阶段自由复制高扇出寄存器（data1_reg、mid_data_q）到就近位置

### RTL 改动

**无**。仅改 XDC。

### 性能影响

**无**。不改 RTL，不增加延迟。

### 验证

```bash
# 不需要重新仿真（RTL 未改动）
# 直接跑综合实现
make build  # 或手动 vivado flow
# 检查新 build 的 timing report
```

### 备选方案（如仍不满足 timing）

如果删除 Pblock 后 Vivado 仍无法自动收敛，可额外追加：

| 方案 | 改动 | 预期效果 |
|------|------|---------|
| ppCache 写端口 +1 reg | `ppCache.v` cacheMem 内 wr/addr/data 加 1 级寄存器 | 砍断类型 B/C 的 FSM→CE/data→D 长路径 |
| data1_reg MAX_FANOUT | XDC 加 `set_property MAX_FANOUT 64` | 强制复制到就近位置 |
| 加回 soft Pblock (1/1/2) | XDC 加 IS_SOFT=TRUE hint | 给 Vivado 一个起点但不强制 |

RTL fix needed — vpu_ready timing
vpu_ready 在最后若干 VPU_BUF AXI 写的 BVALID 尚未返回前拉高。需要在 VPU 内部等待最后一笔写完成（outstanding write counter 清零）后再拉高 vpu_ready。

---

## Timing 失败根因分析：8tile_v4 URAM cascade timing violation（2026-06-16）

### 现象

`8tile_v4` 实现（place + phys_opt + route）全程无法收敛，**WNS = -2.3 ~ -2.8 ns**，phys_opt 完全无改善效果。`8tile_v3` 在相同约束下正常出 bitstream（WNS = +0.000 ns）。

各阶段 WNS/TNS 对比：

| 阶段 | v3 WNS | v3 Failing EP | v4 WNS | v4 Failing EP |
|---|---|---|---|---|
| post_place attempt1 | -0.912 ns | 68 | **-2.521 ns** | 18007 |
| post_place attempt2 | -0.062 ns | 6200 | **-2.834 ns** | 20369 |
| post_phys_opt attempt1 | **+0.031 ns ✅** | 0 | **-2.321 ns** | 16289 |
| post_phys_opt attempt2 | **+0.037 ns ✅** | 0 | **-2.685 ns** | 18901 |
| post_route attempt2 | -0.019 ns | 18 | **-2.615 ns** | 171812 |
| 最终结果 | **出 bitstream ✅** | — | **从未收敛 ❌** | — |

### 违例路径特征（v4）

全部违例集中在同一类路径（`post_phys_opt_attempt1_failing.rpt` / `post_route_attempt2_failing.rpt`）：

```
Source:      lite_i/vpu_0/inst/u_vpu_buf/u_uram/mem_reg_uram_N/CLK   (URAM288)
Destination: lite_i/vpu_0/inst/u_vpu_buf/u_uram/dat_pipe_a_reg[0][X]/D (FDRE)
Logic Levels: 13~15 (URAM288×7 + LUT5×6~8)
Data Path Delay: 5.9~6.7 ns  (period = 4.0 ns)
Slack: -2.3 ~ -2.8 ns
```

路径组成：

```
URAM_N → CAS_OUT(2.15ns) → URAM_N+1 → CAS_OUT(0.19ns) × 6 → URAM_N+6/DOUT_B
→ [route ~1.2~1.6ns] → LUT5 × 6~8 级 MUX 树 → FDRE dat_pipe_a_reg[0][X]/D
```

v3 的最差路径是 inst_decoder→DCIM 的纯路由路径（Logic Levels=0，WNS=-0.912 ns），phys_opt 可修复；v4 是结构性的逻辑级超限，phys_opt 对 URAM 物理延迟无能为力。

### 根因定位：commit `98045d9` 对 `uram_tdp_bytewrite.v` 的修改

**v3（commit `c5be628`）**：
```verilog
reg [NBPIPE:0] men_pipe_a;
always @(posedge clk)
    men_pipe_a <= {men_pipe_a[NBPIPE-1:0], mem_ena};  // 简单单比特信号
```

**v4（commit `98045d9`）**：
```verilog
wire rd_en_a = mem_ena & ~(|wea);   // ← 新增：16-bit wea 归约 OR
always @(posedge clk)
    men_pipe_a <= {men_pipe_a[NBPIPE-1:0], rd_en_a};
```

`wea` 是 16-bit byte-enable 向量（`NUM_COL=16`），`|wea` 需要若干 LUT6 归约树。由于 `men_pipe_a[0..N]` 用作 `dat_pipe_a` 各级的 CE（clock enable），Vivado 在 FDRE CE 逻辑较复杂时会**将 CE 转为数据路径 MUX**（`dat_pipe_a[0] <= men_pipe_a[0] ? memrega : dat_pipe_a[0]`），从而在 URAM DOUT → FDRE.D 之间插入 6~8 级 LUT5 MUX 树。叠加 7 级 URAM cascade chain（3.3 ns），总逻辑延迟突破 4 ns 周期。

v3 中 `men_pipe_a[0]` 仅是 `mem_ena` 延迟一拍的简单 FDRE 输出，Vivado 使用 FDRE CE pin，数据路径上无 LUT，URAM cascade 不是瓶颈。

### 修复方案

#### 方案 A：`rd_en` 提前一拍寄存（中等复杂度）

```verilog
// uram_tdp_bytewrite.v
reg rd_valid_a, rd_valid_b;
always @(posedge clk) rd_valid_a <= mem_ena & ~(|wea);  // 寄存后使用
always @(posedge clk) rd_valid_b <= mem_enb & ~(|web);
always @(posedge clk)
    men_pipe_a <= {men_pipe_a[NBPIPE-1:0], rd_valid_a};
always @(posedge clk)
    men_pipe_b <= {men_pipe_b[NBPIPE-1:0], rd_valid_b};
```

`|wea` 归约结果先打一拍再进入 pipeline，不出现在 URAM→FDRE 关键路径。**代价**：总延迟变为 NBPIPE+3 拍（+1），需将 `RD_LATENCY` 从 10 改为 11（`NBPIPE` 从 8 改为 9）。

#### 方案 B：回退 `men_pipe` 使用 `mem_ena`，`valid` 由上层管理（推荐）

```verilog
// uram_tdp_bytewrite.v — 仅改这两行，回到 v3 行为
always @(posedge clk)
    men_pipe_a <= {men_pipe_a[NBPIPE-1:0], mem_ena};
always @(posedge clk)
    men_pipe_b <= {men_pipe_b[NBPIPE-1:0], mem_enb};
```

v4 想修复的问题（写时 `douta_valid` 误为 1 导致 VPU 读到脏数据）已由 `vpu_buf.v` 的 `rd_valid_pipe_a` 正确处理（`mem_ena & ~wr_en_a`）。`dat_pipe_a` 数据流水中写周期传播的是 stale `memrega`，但 URAM No-Change 模式保证写时 `memrega` 不更新，且消费方（VPU）只在 `douta_valid=1` 时使用 `douta`，**Port A 功能安全**。Port B（AXI BRAM Controller 侧）在写操作时本身不读 `doutb`，同样安全。

**优点**：改动量最小（2 行），不改接口，不改延迟，timing 立即恢复 v3 水平。

#### 方案 C：方案 A 的精确版（`|wea` 单独寄存，不影响延迟）

```verilog
// uram_tdp_bytewrite.v
reg wea_any_r, web_any_r;
always @(posedge clk) wea_any_r <= |wea;   // 16-bit 归约先寄存
always @(posedge clk) web_any_r <= |web;
wire rd_en_a = mem_ena & ~wea_any_r;       // wea_any_r 是纯 FDRE，不在关键路径
wire rd_en_b = mem_enb & ~web_any_r;
always @(posedge clk)
    men_pipe_a <= {men_pipe_a[NBPIPE-1:0], rd_en_a};
always @(posedge clk)
    men_pipe_b <= {men_pipe_b[NBPIPE-1:0], rd_en_b};
```

`wea_any_r` 是寄存器输出，进入 `men_pipe_a` 的 CE 路径时不含组合逻辑。**代价**：写后立刻读时，`rd_en_a` 的判断比实际读操作晚 1 拍，即写操作发出后若紧接读，pipeline 使能会晚一拍——需要在 `vpu_buf.v` 的 `rd_valid_pipe_a` 对应调整，或接受写-读间至少 1 拍气泡（通常 VPU 软件已满足此要求）。实际延迟不变（NBPIPE 不变），但写→读的最小间隔变为 2 拍而非 1 拍。

### 选用方案与改动

**选用方案 B**（`rtl/common/uram_tdp_bytewrite.v`，改动 2 行）：

- timing 立即恢复（关键路径 LUT5×6~8 消失）
- 功能正确性由 `vpu_buf.v` 层保证，无需修改其他文件
- 不改接口，不改 `RD_LATENCY`，不影响 testbench/仿真

改动后需重新跑 `8tile_v4` 实现（预期 WNS ≥ 0，与 v3 基本一致）。