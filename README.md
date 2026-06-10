# EdgeYOLO-FPGA-lite

DCIM + im2col 裁剪验证项目。详见 `.cursor/rules/project-context.mdc`。

---

## 时序修复：DSP multiply critical path（2026-06-10）

### 问题

post-place WNS = -1.115ns，failing paths 全部为：
```
s2_reg/data1_reg → LUT(sign extend) → DSP48E2(multiply) → LUT(truncate) → product_pipe_reg
```
根因：`s2_reg` (Fabric FF) 到 DSP48E2 B port 路由过长（2.1ns, fanout=106），
加上 DSP 内部组合延迟 1.8ns，总 ~5.1ns 超过 4ns requirement。

### 方案 A：DSP 内置 input pipeline（已实施）

**原理**：将 `product_pipe`（DSP 输出端的 Fabric FF）替换为 multiplier 内部的 input pipeline
寄存器（Vivado 推断为 DSP48E2 AREG=1, BREG=1）。

**改后 pipeline**：
```
data1_reg ─→ LUT(sign ext) ─→ [DSP AREG/BREG] ─→ multiply(combo) ─→ adderTree
  (扇出分发)     (短路由到 DSP)   (DSP 内部 reg)    (~1.6ns DSP 内部)
```

**修改文件**：
- `rtl/ref/DCIM/src/dcim/multiplier_dsp.v` — 加 clk/rstn/ena，内部 a_reg/b_reg
- `rtl/ref/DCIM/src/dcim/multiplier.v` — 同样加 1 级 input pipeline（与 DSP 版延迟一致）
- `rtl/ref/DCIM/src/dcim/maArray.v` (maSubcolumn) — 删除 product_pipe，multiplier 输出直连 adderTree

**延迟变化**：无（2 级 pipeline → 2 级，data1_reg + AREG 替代 data1_reg + product_pipe）

**关键路径预估**：
- data1_reg → DSP AREG：LUT(0.1ns) + route(0.3-0.5ns) ≈ 0.6ns << 4ns ✓
- DSP AREG → adderTree 首级 FF：DSP multiply(1.6ns) + route(0.5ns) ≈ 2.1ns << 4ns ✓

**验证要求**：需重跑 DCIM 功能仿真（pipeline 行为等价，应直接 PASS）

---

### 方案 C：AREG/BREG + PREG 全流水化（备选）

如果方案 A 仍有微小余量不足，可进一步在 DSP P 输出端加 PREG。

**改后 pipeline**：
```
data1_reg ─→ LUT ─→ [DSP AREG/BREG] ─→ multiply ─→ [DSP PREG] ─→ adderTree
```

**延迟变化**：+1 cycle（对 DCIM 吞吐无影响，仅首批结果晚 1 clock）

**额外修改**：
- `multiplier_dsp.v` / `multiplier.v`：P 输出加 reg（Vivado 推断 PREG=1）
- `maArray.v`：`MA_PIPE_DEPTH` 从 `4 + ADDER_PIPE_DEPTH` 改为 `5 + ADDER_PIPE_DEPTH`
- `maSubcolumn`：s_pipe 需再多延 1 cycle

**时序余量**：极大（每段 <1.6ns / 4ns，支持提频到 350MHz+）

---

### 全 LUT 实验（不推荐，仅供时序对比测试）

如需验证"全 LUT 无 DSP 是否能过时序"：

```bash
# 方法：将 chip_defines.vh 中 DSP 列数设为 0
```

修改 `rtl/chip/chip_defines.vh`：
```verilog
// 原:
`define DCIM_DSP_COL_SOLO       9
`define DCIM_DSP_PARTIAL_SOLO   0
`define DCIM_DSP_COL_SHARED     5
`define DCIM_DSP_PARTIAL_SHARED 2

// 改为全 LUT:
`define DCIM_DSP_COL_SOLO       0
`define DCIM_DSP_PARTIAL_SOLO   0
`define DCIM_DSP_COL_SHARED     0
`define DCIM_DSP_PARTIAL_SHARED 0
```

这会使所有 Tile 的 `DSP_COL_NUM=0`，走 `multiplier.v`（`use_dsp="no"`）路径。

**预期效果**：
- 时序大概率通过（LUT FF 与 LUT 乘法在同一 SLICE，无长路由）
- DSP 利用率降为 0%（7424 个 DSP48E2 空闲）
- LUT 利用率增加 ~100K（+8%）
- 功耗增加 ~15-20W

**注意**：全 LUT 模式下 `multiplier.v` 已包含 1 级 input pipeline（与 DSP 版一致），
不需要额外 RTL 修改。仅改 defines 即可。

---

## XDC 约束审查

### 当前已知问题

| XDC Section | 约束 | 状态 |
|---|---|---|
| 4.1 | `maSubcolumn* → gen_ma_pipe.r_ma_pipe*` MCP(2) | **无效**：RTL 中无 `gen_ma_pipe`/`r_ma_pipe`，filter 不匹配任何 cell |
| 4.1 | `adderTree carry CO → result_reg D` MCP(2) | **可疑**：adderTreePipe 每级是单周期，carry→r_sum 是 1-cycle 路径。目前无 fail（carry chain 路由极短），低风险 |
| 4.1 | `mergeArray → accumulateArray → postProcess` MCP(2) | **合理**：accumulate 需要多 cycle 完成，数据在 FSM 控制下稳定 |
| 4.2 | OBUF/IBUF arbiter MCP(2) | **合理**：grant 逻辑在 FSM 状态稳定后才采样 |
| 4.3 | SLR 穿越 ready_r/start_r/cfg MCP(2) | **合理**：这些信号通过 `_r` 后缀寄存器打拍，FSM 在稳定后才读取 |
| 4.4 | URAM 延迟 MCP(4) | **合理**：URAM 读延迟 4 cycle，RTL 中有对应 pipeline |
| Sec 1 | `set_clock_uncertainty 0.050` | **方案 A 后可选删除**：原为迫使 s2_reg 靠近 DSP，现在 AREG 消除了该需求 |

### 建议清理

方案 A 验证通过后，可删除以下无用约束：
1. Line 91-96（`gen_ma_pipe` 不存在）
2. Line 27-31 的 `set_clock_uncertainty 0.050`（可选，保留无害）
