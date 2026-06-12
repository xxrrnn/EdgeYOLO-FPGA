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
- `GB_ADDR_WIDTH=24` 给出 16MB 字节寻址空间，完全覆盖 8MB VPU_BUF

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
