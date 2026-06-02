# module_tb — lite BD 模块级数值验证

工作目录：`rtl/tb/lite_bd/module_tb`

目标：作为后续主测试入口，在完整 lite BD（Block Design）上验证单个模块或小链路的数值级别等同。所有任务都由 `inst.hex` 指令流、`preload.txt` 输入预加载和 `checks.txt` 检查点在运行期配置；VCS 编译产物 `simv` 可复用，不需要为每个 case 重新编译。

默认设置：

- `MODULE_CASE=dcim_matmul`
- `MODULE_VARIANT=dcim_tiny_1x1`
- `MODULE_VERIFY_WORDS=0`，表示校验全部 expected words
- `FAST=1`，跳过 `-debug_access`，更快
- `STOP_ON_FAIL=1`，批量仿真遇到失败即停止

---

## 快速开始

第一次或 BD/IP/`chip_defines.vh` 参数改动后（包括 `NUM_TILES/CH_IN/CH_OUT/CYCLE` 变化）：

```bash
cd rtl/tb/lite_bd/module_tb
make export
make compile
make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
```

日常只改 RTL / golden / testbench 后：

```bash
cd rtl/tb/lite_bd/module_tb
make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
```

批量跑一个 suite：

```bash
make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8
```

查看可用 suite / case：

```bash
make list-suites
make list-cases MODULE_CASE=dcim_matmul
make list-cases MODULE_CASE=qa
make list-cases MODULE_CASE=dqa
make list-cases MODULE_CASE=im2col
```

---

## 新仿真流程：compile once / run many

共享编译目录：

```text
rtl/tb/lite_bd/module_tb/sim/build_shared/
```

单个 case 的运行目录：

```text
rtl/tb/lite_bd/module_tb/sim/run_<MODULE_CASE>_<MODULE_VARIANT>/
```

每个运行目录包含：

- `inst.hex`：INST_Decoder 执行的指令流
- `preload.txt`：运行期预加载列表，格式为 `<hex_file> <physical_addr>`
- `checks.txt`：运行期检查点列表，格式为 `<name> <expected_hex> <dst_obuf_hex> <words> <is_fp32>`
- `expected.hex`：Python golden 输出
- `manifest.txt`：case 元信息
- 其他输入 hex，例如 `act.hex`、`weight.hex`、`src0.hex`、`wb_init.hex`
- `sim.log`：仿真日志

注意：
- **compile once / run many**：多个 case 复用同一个 `simv`，但每次 `simv` 启动仍会等待 HBM 初始化。
- **sim-suite（单进程连续执行）**：一次 `simv` 内 HBM 只初始化一次，按 `suite.txt` 顺序对每个 case 执行 preload → **INST_BRAM backdoor 加载** `inst.hex` → decoder start → check（不用 AXI 写 INST_BRAM，BD 仿真中 AXI B-channel 不可靠）。

Suite 目录结构：

```text
rtl/tb/lite_bd/module_tb/sim/suite_<MODULE_CASE>/
  suite.txt              # 每行一个 case 子目录名（相对 suite 根目录）
  run_<case>_<variant>/  # 各 case 的 inst.hex / preload.txt / checks.txt
  sim.log
```

---

## 所有可用命令

### 核心命令

| 命令 | 作用 |
|------|------|
| `make export` | Vivado `export_simulation`，BD/IP 变更后执行 |
| `make compile` | 编译共享 `sim/build_shared/simv`，不生成 case 数据、不运行仿真 |
| `make data` | 只生成当前 `MODULE_CASE` / `MODULE_VARIANT` 的运行数据 |
| `make run` | 复用已有共享 `simv` 跑当前运行目录；要求先 `make data` 和 `make compile` |
| `make sim` | 生成当前 case 数据；若共享 `simv` 不存在则编译；然后运行 |
| `make sim-export` | `make export` + `make sim` |
| `make fsdb` | 强制带波形重新编译并运行当前 case |
| `make fsdb-export` | `make export` + `make fsdb` |
| `make verdi` | 打开当前 case 的 FSDB，或共享 `simv.daidir` |

### 批量命令

| 命令 | 作用 |
|------|------|
| `make sim-batch MODULE_CASE=<case> BATCH_SUITE=<suite>` | 批量运行预置 suite，复用共享 `simv` |
| `make sim-batch MODULE_CASE=<case> MODULE_VARIANTS="a b c"` | 按自定义 variant 列表批量运行 |
| `make sim-batch ... STOP_ON_FAIL=0` | 失败后继续跑完后续 case |
| `make sim-batch ... LOG=1` | 同时写 `sim_batch.log` |
| `make sim-batch-export ...` | `make export` 后批量运行 |
| `make data-batch MODULE_CASE=<case> BATCH_SUITE=<suite>` | 批量生成数据，不运行仿真 |

### 单进程 Suite（省 HBM 启动时间）

| 命令 | 作用 |
|------|------|
| `make data-suite MODULE_CASE=<case> BATCH_SUITE=<suite>` | 生成 `sim/suite_<case>/` 及 `suite.txt`，不仿真 |
| `make run-suite MODULE_CASE=<case>` | 复用已有 `simv`，单进程跑 `suite.txt` 中全部 case |
| `make sim-suite MODULE_CASE=<case> BATCH_SUITE=<suite>` | 生成 suite 数据 + 编译/复用 `simv` + 单进程连续跑 |
| `make rebuild-suite ...` | 强制重编译 `simv` 后单进程跑 suite |
| `make clean-suite MODULE_CASE=<case>` | 删除 `sim/suite_<case>/` |

与 `sim-batch` 对比：`sim-batch` 每个 case 启动一次 `simv`（HBM 每次重等）；`sim-suite` 只启动一次 `simv`，连续多次 decoder start。

示例：

```bash
make sim-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8
make sim-suite MODULE_CASE=dcim_matmul MODULE_VARIANTS="dcim_tiny_1x1 conv6_s2_c3_to16"
```

### 查询命令

| 命令 | 作用 |
|------|------|
| `make list-suites` | 列出所有预置 `BATCH_SUITE` |
| `make list-cases MODULE_CASE=dcim_matmul` | 列出 DCIM matmul 所有 variant |
| `make list-cases MODULE_CASE=qa` | 列出 QA 所有 variant |
| `make list-cases MODULE_CASE=dqa` | 列出 DQA 所有 variant |
| `make list-cases MODULE_CASE=im2col` | 列出 im2col 所有 variant |
| `make list-cases MODULE_CASE=us` | 列出 US 所有 variant |
| `make list-cases MODULE_CASE=mp` | 列出 MP 所有 variant |
| `make list-cases MODULE_CASE=conv_pipeline` | 列出 conv_pipeline 所有 variant |

### 监控命令

| 命令 | 作用 |
|------|------|
| `make sim-ps` | 查看共享 `simv` 是否在运行、CPU/RSS、当前 `sim.log` 末行 |
| `make sim-watch` | 每 5 秒刷新一次 `sim-ps` |
| `make sim-watch WATCH_INTERVAL=10` | 每 10 秒刷新一次 |
| `make sim-done` | 返回 `PASS` / `FAIL` / `RUNNING` / `UNKNOWN` |

### 清理命令

| 命令 | 作用 |
|------|------|
| `make clean` | 删除当前 `MODULE_CASE` / `MODULE_VARIANT` 的运行目录 |
| `make clean-compile` | 删除共享编译目录 `sim/build_shared` |
| `rm -rf sim/run_*` | 删除所有 case 运行目录 |
| `rm -rf sim/` | 删除所有 module_tb 仿真产物，谨慎使用 |

---

## 常用示例

默认 smoke：

```bash
make sim
```

只编译一次，然后连续跑多个 case：

```bash
make compile
make data MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
make run  MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
make data MODULE_CASE=qa MODULE_VARIANT=qa_c16_signed
make run  MODULE_CASE=qa MODULE_VARIANT=qa_c16_signed
```

批量跑 DCIM INT8（每个 case 独立 simv，便于隔离调试）：

```bash
make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8
```

单进程连续跑 DCIM INT8（HBM 只初始化一次）：

```bash
make sim-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_int8
```

批量跑 QA：

```bash
make sim-batch MODULE_CASE=qa BATCH_SUITE=qa_all
```

自定义 variant 列表：

```bash
make sim-batch MODULE_CASE=dcim_matmul MODULE_VARIANTS="conv1_c64_to32 conv3_c128_to128"
```

只校验前 N 个 128-bit word：

```bash
make sim MODULE_CASE=im2col MODULE_VARIANT=im2col_3x3_s2_c32 MODULE_VERIFY_WORDS=256
```

全量校验：

```bash
make sim MODULE_VERIFY_WORDS=0
```

带波形：

```bash
make fsdb MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
make verdi MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
```

---

## 预置 BATCH_SUITE

| BATCH_SUITE | MODULE_CASE | variants |
|-------------|-------------|----------|
| `dcim_int8` | `dcim_matmul` | `dcim_tiny_1x1`、`conv6_s2_c3_to16`、`conv3_s2_c32_to64`、`conv1_c64_to32`、`conv3_c128_to128` |
| `dcim_int16` | `dcim_matmul` | `int16_tiny_1x1`、`int16_conv3_c32_c64`、`int16_conv1_c128` |
| `dcim_extreme` | `dcim_matmul` | `extreme_int8_1x1_c512_to512`、`extreme_int8_3x3_c128_to512`、`extreme_int8_6x6_c3_to64`、`extreme_int16_3x3_c128` |
| `dcim_all` | `dcim_matmul` | `dcim_int8` + `dcim_int16` |
| `dcim_network` | `dcim_matmul` | `dcim_model_3_conv`、`dcim_model_5_conv`、`dcim_model_7_conv` |
| `qa_all` | `qa` | `qa_c16_signed`、`qa_c64_clip`、`qa_c128_dense` |
| `dqa_all` | `dqa` | `dqa_c16_small`、`dqa_c64_mid`、`dqa_c128_sppf` |
| `im2col_all` | `im2col` | `im2col_6x6_s2_c3`、`im2col_3x3_s2_c32`、`im2col_3x3_s1_c128`、`im2col_1x1_c512` |
| `mp_all` | `mp` | `mp_sppf_128_10`、`mp_resnet_stem`、`mp_gap_7x7_c512` |
| `us_all` | `us` | `us_128_10_to20`、`us_64_20_to40` |
| `add_all` | `add` | `add_residual_16`、`add_residual_32`、`add_pan_64` |
| `conv_pipe_all` | `conv_pipeline` | `pipe_conv3_s2_c32_to64`、`pipe_conv1_c512_to64_tilepass` |
| `concat_all` | `concat_by_cdma` | `concat_2src_c64_c64_hw8x8`、`concat_2src_c128_c128_hw10x10`、`concat_4src_sppf_c128_hw10x10` |
| `large_channel_all` | `large_channel_pressure` | `dcim_conv1_c512_to64_tilepass`、`pipe_conv1_c512_to64_tilepass`、`dqa_c256_pressure`、`qa_c256_pressure`、`concat_c128_c128_to256` |
| `mini_network_all` | `mini_network` | `mini_2conv_c16`、`mini_3conv_residual_c32` |

---

## 当前验证状态（2026-05-30）

硬件拓扑：DCIM lite 为 **4 Tile × 64×64** 的 Array–Tile 结构（`DCIM_Array` = 4×`DCIM_Tile` + 共享 IBUF/OBUF），无 Group 层。

注意：Vivado module_ref wrapper 会把 `NUM_TILES/CH_IN/CH_OUT/CYCLE` 固化到 `lite_dcim_array_0_0.v`。修改 `chip_defines.vh` 后必须先运行 `make export`，再 `make compile`/`make rebuild-suite`。

### 行为模型与综合 RTL 一致性约定

影响综合编译结果的开关不再使用默认打开的 RTL parameter。`fp32_2_int16_array` 默认实例化 Vivado `fp32_to_int16` IP，是可综合且用于上板的 RTL 路径；只有仿真脚本显式加入 `` `FP32_2_INT16_BEHAVIORAL`` 时，才替换成 `shortreal` 行为模型，避免行为代码进入综合默认路径。

- 默认综合/上板：不定义 `` `FP32_2_INT16_BEHAVIORAL``，使用真实 `fp32_to_int16` IP。
- module_tb 默认仿真：`FP32_2_INT16_BEHAVIORAL=1`，脚本加入 `+define+FP32_2_INT16_BEHAVIORAL`，加快 QA INT16 路径仿真。
- 如需用真实 IP 模型做仿真一致性抽查：在命令前加 `FP32_2_INT16_BEHAVIORAL=0`。

该行为模型只影响 `qa_unit` 内的 FP32→INT16 转换分支。当前 W8A8 主路径与 conv pipeline 主要使用 INT8 QA，和上板 RTL 一致；INT16/行为模型相关测试应视为功能快速回归，最终上板一致性以真实 IP 仿真或综合后板上测试为准。

验证策略更新：RTL 仿真不再把完整网络大尺寸层作为常规回归目标。常规 RTL 重点跑小规模但极端的 `dcim_extreme`，覆盖当前 4 Tile × 64×64 配置、高 acc_depth、INT8/INT16 和 1×1/3×3/6×6 kernel；完整网络/60 层端到端主要留给综合实现后上板验证。

### 新仿真方法：数值回归默认 backdoor preload

当前 `module_tb` 分成两类 preload 模式：

- `PRELOAD_MODE=backdoor`（默认）：直接把 `preload.txt` 指定的 `*.hex` 写入 RTL 内部 IBUF/OBUF/WB 存储数组。这样跳过最慢的 host AXI 逐 beat preload，但 **不跳过计算路径**：`inst.hex` 仍由 `INST_Decoder` 执行，CDMA/VPU/DCIM 仍在完整 lite BD RTL 中运行，最后从 OBUF 读回并与 `golden_module_tb.py` 的 `expected.hex` 逐 word 比较。
- `PRELOAD_MODE=axi`：通过 `host_axi_master_bfm` 走 XDMA M_AXI → SmartConnect → AXI BRAM ctrl，用于小规模地址映射/AXI 通路 smoke。大权重 case 不建议用该模式。
- `QUANT=all`：对 QA/DQA/conv_pipeline/mini_network 等模块会展开成 `int8`、`int16` 两套 run 目录；对 `dcim_matmul` 不使用 `QUANT` 覆盖精度，DCIM 模式由 case 名/spec 决定，运行目录后缀为 `dcim_int8` 或 `dcim_int16`。

因此，上板前功能完备性验证的主路径是 `backdoor` 数值回归，补充少量 `axi` smoke 验证总线窗口仍可达。

### 推荐执行命令

基础准备（首次或 BD/拓扑变化后）：

```bash
cd rtl/tb/lite_bd/module_tb
make export
make compile
```

`module_tb` 默认使用 `PRELOAD_MODE=backdoor`：测试数据由 testbench 直接写入 IBUF/OBUF/WB 的 RTL 存储数组，跳过 host AXI 逐 beat 预加载；随后仍通过同一套 `INST_Decoder → CDMA/VPU/DCIM → OBUF` RTL 数据路径执行，并与 `golden_module_tb.py` 生成的 `expected.hex` 逐 word 比较。该模式用于上板前的高覆盖数值级 RTL 回归。

当前优先级最高的 DCIM 小规模极限回归：

```bash
cd rtl/tb/lite_bd/module_tb
timeout 2h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_extreme STOP_ON_FAIL=0 LOG=1
```

完整 conv pipeline 链路（im2col → CDMA → DCIM → DQA/QA）：

```bash
cd rtl/tb/lite_bd/module_tb
timeout 3h make rebuild-suite MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all QUANT=all STOP_ON_FAIL=0 LOG=1
```

mini_network 多层链路：

```bash
cd rtl/tb/lite_bd/module_tb
timeout 4h make rebuild-suite MODULE_CASE=mini_network BATCH_SUITE=mini_network_all QUANT=all STOP_ON_FAIL=0 LOG=1
```

VPU 单元回归（改过 VPU/OBUF 接口后建议跑）：

```bash
cd rtl/tb/lite_bd/module_tb
timeout 2h make rebuild-suite MODULE_CASE=im2col BATCH_SUITE=im2col_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all STOP_ON_FAIL=0 LOG=1
timeout 2h make rebuild-suite MODULE_CASE=dqa BATCH_SUITE=dqa_all QUANT=all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=us BATCH_SUITE=us_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=mp BATCH_SUITE=mp_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=add BATCH_SUITE=add_all STOP_ON_FAIL=0 LOG=1
```

CDMA 拼接和大通道压力：

```bash
cd rtl/tb/lite_bd/module_tb
timeout 2h make rebuild-suite MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_all STOP_ON_FAIL=0 LOG=1
timeout 3h make rebuild-suite MODULE_CASE=large_channel_pressure BATCH_SUITE=large_channel_all STOP_ON_FAIL=0 LOG=1
```

一键全量数值回归（默认 `PRELOAD_MODE=backdoor`）：

```bash
cd rtl/tb/lite_bd/module_tb
timeout 8h make sim-all STOP_ON_FAIL=0 LOG=1
```

AXI/地址映射 smoke（非默认）：如果要确认 host BFM → XDMA/SmartConnect → IBUF/OBUF/WB AXI 窗口仍可达，只跑小 case，避免大权重 AXI 预加载拖慢仿真。

```bash
cd rtl/tb/lite_bd/module_tb
PRELOAD_MODE=axi timeout 1h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_smoke STOP_ON_FAIL=0 LOG=1
```

真实 IP 抽查 FP32→INT16 转换路径（非默认，较慢，用于对齐上板 RTL）：

```bash
cd rtl/tb/lite_bd/module_tb
FP32_2_INT16_BEHAVIORAL=0 timeout 1h make rebuild-suite MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all STOP_ON_FAIL=0 LOG=1
```

DCIM 网络真实尺寸 smoke（可选，不作为常规 RTL 回归）：

```bash
cd rtl/tb/lite_bd/module_tb
timeout 3h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_network STOP_ON_FAIL=0 LOG=1
```

综合检查（默认不定义行为模型，使用上板 RTL）：

```bash
vivado -mode batch -source scripts/chip-lite/2_synth.tcl
```

### 当前测试内容与上板一致性

当前 module_tb 是完整 lite BD 上的模块级/小链路数值验证，测试数据由 `golden_module_tb.py` 生成，运行时通过 `inst.hex` 指令流、`preload.txt` 输入预加载和 `checks.txt` 检查点驱动。已覆盖/建议覆盖的内容包括：

- `dcim_matmul`：DCIM IBUF → Tile 阵列 → OBUF，覆盖 INT8/INT16、1×1/3×3/6×6 kernel、当前 4 Tile × 64×64 配置和高 `acc_depth`。
- `im2col`：VPU 从 OBUF 读 feature 并写 OBUF im2col 结果。
- `conv_pipeline`：`im2col → CDMA(OBUF→IBUF) → DCIM → DQA → QA`，是最接近单层卷积上板数据流的 RTL 链路。
- `dqa` / `qa` / `mp` / `us` / `concat_by_cdma`：分别验证 VPU 后处理、量化、池化、上采样和 CDMA 拼接路径。

与上板 RTL 的一致性：

- BD 拓扑、地址映射、OBUF/IBUF、INST_Decoder、CDMA、VPU、DCIM_Array 主数据路径与 lite 上板设计一致。
- 默认 `PRELOAD_MODE=backdoor` 只跳过 host AXI 写入初始数据这一步，直接初始化 IBUF/OBUF/WB RTL 存储；decoder 指令执行、CDMA 搬运、VPU/DCIM 计算和 OBUF 检查仍走 RTL 数值路径。
- `PRELOAD_MODE=axi` 保留用于小规模 smoke，覆盖 XDMA/SmartConnect/AXI BRAM ctrl 地址映射，但不建议用于大权重回归。
- 仿真为提速替换了外设/非关键行为：XDMA 由 BFM 驱动，HBM 顶层用 fast stub；当前 lite 主路径不经过 HBM，因此不影响 OBUF/IBUF/DCIM/VPU 数值验证。
- `FP32_2_INT16_BEHAVIORAL=1` 只在仿真编译时打开，默认综合不打开。需要严格对齐上板时，用 `FP32_2_INT16_BEHAVIORAL=0` 重跑相关 QA INT16 测试。
- 完整 60 层网络没有作为常规 RTL 仿真目标；RTL 回归验证小规模但覆盖关键边界的 case，完整端到端一致性仍需综合/实现后在板上跑 `tests/chip`。

状态说明：

- `PASS`：已在 module_tb 全 BD 仿真中通过
- `FAIL`：已运行但失败
- `UNTESTED`：尚未运行或本轮未重跑确认
- `RUNNING/STALE`：旧记录显示运行中，但当前无新的 PASS 记录确认

### 编译/框架状态

| 项目 | 状态 | 说明 |
|------|------|------|
| 共享 `simv` 编译 | PASS | `make compile FAST=1` 已通过 |
| 运行期 `RUN_DIR` 驱动 | PASS | `preload.txt` / `checks.txt` 路径加载已验证 |
| 默认 smoke `dcim_tiny_1x1` | PASS | 复用共享 `simv`，`16 / 16` 通过 |
| 单进程 suite `sim-suite` | PASS | `dcim_all` 连续 8 case，`1272 PASS / 0 FAIL`；`us_all` 连续 2 case，`38400 PASS / 0 FAIL` |

### DCIM 矩阵乘（INT8）

| 用例 | M | K | N | acc_depth | check / total words | 状态 |
|------|---|---|---|-----------|---------------------|------|
| `dcim_tiny_1x1` | 4 | 32 | 16 | 2 | `16 / 16` | PASS |
| `conv6_s2_c3_to16` | 36 | 108 | 16 | 7 | `144 / 144` | PASS |
| `conv3_s2_c32_to64` | 16 | 288 | 64 | 18 | `256 / 256` | PASS |
| `conv1_c64_to32` | 36 | 64 | 32 | 4 | `288 / 288` | PASS |
| `conv3_c128_to128` | 25 | 576 | 128 | 36 | `400 / 400` | PASS |

运行：

```bash
make sim-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all
```

当前全量结果：`dcim_all` 共 8 case，`1272 PASS / 0 FAIL`，`MODULE CHECK PASSED`。

### DCIM 矩阵乘（INT16，全量 suite 已通过）

| 用例 | M | K | acc_depth | check / total words | 状态 |
|------|---|---|-----------|---------------------|------|
| `int16_tiny_1x1` | 4 | 32 | 4 | `—` | PASS |
| `int16_conv3_c32_c64` | 16 | 288 | 36 | `—` | PASS |
| `int16_conv1_c128` | 16 | 128 | 16 | `128 / 128` | PASS |

运行：

```bash
make sim-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all
```

### DCIM 网络真实尺寸 smoke

| 用例 | 状态 |
|------|------|
| `dcim_model_3_conv` | UNTESTED |
| `dcim_model_5_conv` | UNTESTED |
| `dcim_model_7_conv` | UNTESTED |

运行：

```bash
make sim-batch MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_network
```

### QA（量化）

| 用例 | check / total words | 状态 |
|------|---------------------|------|
| `qa_c16_signed` | `16 / 16` | PASS |
| `qa_c64_clip` | `60 / 60` | PASS |
| `qa_c128_dense` | `80 / 80` | PASS |

运行：

```bash
make sim-batch MODULE_CASE=qa BATCH_SUITE=qa_all
```

### DQA（反量化，`relu_en` 可配置）

`OP_VPU_EXEC` header 的 `flags[0]` = `relu_en`，由 `INST_Decoder` 经 `vpu_flags` 传入 `Global_VPU`，再连接到 `dqa_relu_unit.dqa_relu_en`。

- `relu_en=1`：`max(accum × scale + bias, 0)`，用于中间层
- `relu_en=0`：线性直通，用于 head 输出层

带 ReLU：

| 用例 | layer | out_ch | 状态 |
|------|-------|--------|------|
| `dqa_c16_small` | `model.0.conv` | 16 | PASS，`64 / 64` words |
| `dqa_c32_mid` | `model.2.m.0.cv1.conv` | 32 | UNTESTED |
| `dqa_c64_mid` | `model.3.conv` | 64 | PASS，`240 / 240` words |
| `dqa_c128_sppf` | `model.9.cv1.conv` | 128 | PASS，`320 / 320` words |
| `dqa_c256_head` | `model.7.conv` | 256 | UNTESTED |

无 ReLU：

| 用例 | layer | in_ch | 状态 |
|------|-------|-------|------|
| `dqa_nrelu_c24_in64` | `model.24.m.0` | 64 | UNTESTED |
| `dqa_nrelu_c24_in128` | `model.24.m.1` | 128 | UNTESTED |
| `dqa_nrelu_c24_in256` | `model.24.m.2` | 256 | UNTESTED |

运行当前 suite：

```bash
make sim-batch MODULE_CASE=dqa BATCH_SUITE=dqa_all
```

注意：`dqa_all` 当前只包含 `dqa_c16_small`、`dqa_c64_mid`、`dqa_c128_sppf`。

### US（上采样）

| 用例 | check / total words | 状态 |
|------|---------------------|------|
| `us_128_10_to20` | `12800 / 12800` | PASS |
| `us_64_20_to40` | `25600 / 25600` | PASS |

运行：

```bash
make sim-suite MODULE_CASE=us BATCH_SUITE=us_all
```

当前结果：`us_all` 共 2 case，`38400 PASS / 0 FAIL`，`MODULE CHECK PASSED`。

### MP（最大池化）

| 用例 | check / total words | 状态 |
|------|---------------------|------|
| `mp_sppf_128_10` | `3200 / 3200` | PASS |

运行：

```bash
make sim-suite MODULE_CASE=mp BATCH_SUITE=mp_all
```

当前结果：`mp_sppf_128_10`，`3200 PASS / 0 FAIL`，`MODULE CHECK PASSED`。

### im2col

| 用例 | check / total words | 状态 |
|------|---------------------|------|
| `im2col_6x6_s2_c3` | `252 / 252` | PASS |
| `im2col_3x3_s2_c32` | `256 / 256` | PASS |
| `im2col_3x3_s1_c128` | `256 / 256` | PASS |
| `im2col_1x1_c512` | `256 / 256` | PASS |

运行：

```bash
make sim-batch MODULE_CASE=im2col BATCH_SUITE=im2col_all
```

### conv_pipeline（im2col + DCIM + DQA + QA）

| 用例 | check / total words | 状态 |
|------|---------------------|------|
| `pipe_conv3_s2_c32_to64` | `— / 64` | UNTESTED，需重跑确认 |
| `pipe_conv1_c512_to64_tilepass` | `—` | UNTESTED |

运行：

```bash
make sim-batch MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all
```

### concat_by_cdma

| 用例 | 状态 |
|------|------|
| `concat_2src_c64_c64_hw8x8` | 待用 backdoor suite 重跑确认 |
| `concat_2src_c128_c128_hw10x10` | 待用 backdoor suite 重跑确认 |
| `concat_4src_sppf_c128_hw10x10` | 待用 backdoor suite 重跑确认 |

运行：

```bash
make rebuild-suite MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_all STOP_ON_FAIL=0 LOG=1
```

### large_channel_pressure

| 用例 | 实际模块 | 状态 |
|------|----------|------|
| `dcim_conv1_c512_to64_tilepass` | `dcim_matmul` | 待用 backdoor suite 重跑确认 |
| `pipe_conv1_c512_to64_tilepass` | `conv_pipeline` | 待用 backdoor suite 重跑确认 |
| `dqa_c256_pressure` | `dqa` | 待用 backdoor suite 重跑确认 |
| `qa_c256_pressure` | `qa` | 待用 backdoor suite 重跑确认 |
| `concat_c128_c128_to256` | `concat_by_cdma` | 待用 backdoor suite 重跑确认 |

运行：

```bash
make rebuild-suite MODULE_CASE=large_channel_pressure BATCH_SUITE=large_channel_all STOP_ON_FAIL=0 LOG=1
```

---

## 下一步建议测试顺序（基于 `PRELOAD_MODE=backdoor`）

当前验证策略：默认用 `PRELOAD_MODE=backdoor` 做数值级 RTL 回归，尽量充分覆盖 RTL 功能；只用 `PRELOAD_MODE=axi` 做小规模总线/地址映射 smoke。

### 1. 快速确认仿真框架

```bash
make compile FAST=1
make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1 PRELOAD_MODE=backdoor
make sim MODULE_CASE=qa MODULE_VARIANT=qa_c16_signed PRELOAD_MODE=backdoor
```

预期：两条单 case 都应出现 `MODULE CHECK PASSED`。这两条已用于确认 IBUF/OBUF/WB backdoor preload 路径可用。

### 2. DCIM 主路径和极限路径

```bash
timeout 2h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_all STOP_ON_FAIL=0 LOG=1
timeout 2h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_extreme STOP_ON_FAIL=0 LOG=1
```

覆盖：INT8/INT16、1×1/3×3/6×6、当前 4 Tile × 64×64 配置、高 `acc_depth`、大通道 tilepass。

### 3. VPU 单元完整回归

```bash
timeout 2h make rebuild-suite MODULE_CASE=im2col BATCH_SUITE=im2col_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all STOP_ON_FAIL=0 LOG=1
timeout 2h make rebuild-suite MODULE_CASE=dqa BATCH_SUITE=dqa_all QUANT=all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=mp BATCH_SUITE=mp_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=us BATCH_SUITE=us_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=add BATCH_SUITE=add_all STOP_ON_FAIL=0 LOG=1
```

覆盖：im2col、QA INT8/INT16、DQA ReLU/No-ReLU/accum16、MaxPool/SPPF/GAP、Upsample、Residual Add。

### 4. CDMA/拼接/单层端到端

```bash
timeout 2h make rebuild-suite MODULE_CASE=concat_by_cdma BATCH_SUITE=concat_all STOP_ON_FAIL=0 LOG=1
timeout 3h make rebuild-suite MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all QUANT=all STOP_ON_FAIL=0 LOG=1
```

覆盖：OBUF 内 CDMA copy/concat，以及 `im2col → CDMA → DCIM → DQA/ReLU → QA` 单层完整链路。

### 5. 多层链路和大通道压力

```bash
timeout 4h make rebuild-suite MODULE_CASE=mini_network BATCH_SUITE=mini_network_all QUANT=all STOP_ON_FAIL=0 LOG=1
timeout 3h make rebuild-suite MODULE_CASE=large_channel_pressure BATCH_SUITE=large_channel_all STOP_ON_FAIL=0 LOG=1
```

覆盖：多层 conv、residual add、c512/tilepass、c256 DQA/QA、大通道 concat。

### 6. AXI smoke（非默认，慢但更贴近 host 写入）

```bash
PRELOAD_MODE=axi timeout 1h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_smoke STOP_ON_FAIL=0 LOG=1
```

只用于确认 XDMA BFM/SmartConnect/AXI BRAM ctrl 地址窗口可达，不作为大规模数值回归方式。

### 7. 真实 IP 抽查 FP32→INT16

```bash
FP32_2_INT16_BEHAVIORAL=0 timeout 1h make rebuild-suite MODULE_CASE=qa BATCH_SUITE=qa_all QUANT=all STOP_ON_FAIL=0 LOG=1
```

用于抽查 QA INT16 路径与上板真实 `fp32_to_int16` IP 的一致性。

### 8. 结果汇总和实时监控

`simv` 输出默认写入 `sim.log`，终端停在 `=== VCS simulate ... ===` 不代表卡死。查看实时进度：

```bash
less +F sim/run_<MODULE_CASE>_<MODULE_VARIANT>_<mode>/sim.log
# 或单 case 监控
make sim-watch MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
```

汇总 batch 单 case 日志：

```bash
make sim-results
```

---

## 何时需要重新 export / compile / run

| 场景 | 操作 |
|------|------|
| 改了 BD 拓扑、IP 参数、AXI 地址分配、IP 端口 | `make export` → `make compile` → `make sim` |
| 改了用户 RTL（`rtl/vpu/`、`rtl/chip/` 等） | `make compile` → `make run`，或直接 `make sim` |
| 改了 `tb_lite_bd_module.sv` / BFM | `make compile` → `make run`，或直接 `make sim` |
| 改了 `golden_module_tb.py` | `make data` → `make run`，或直接 `make sim` |
| 只想换 case / 指令 / 输入 | `make data` → `make run`，共享 `simv` 可复用 |
| 需要快速数值回归 | 默认 `PRELOAD_MODE=backdoor`，直接 `make sim` / `make rebuild-suite` |
| 需要 AXI 地址映射 smoke | `PRELOAD_MODE=axi make sim ...`，只建议小 case |
| 需要观察运行进度 | `less +F <run_dir>/sim.log` 或 `make sim-watch ...` |
| 需要波形 | `make fsdb` |

---

## 修复记录

`us` 修复：原状态机只等 1 拍即锁存 `gb_doutb`，而 OBUF 读延迟为 7 拍，导致输出整体偏移 1 word。修复后增加 `gb_doutb_valid` 握手端口，`S_LOAD_WAIT` 改为 valid 等待，并修正 `LANES_BITS` 硬编码。

`im2col` 修复：

1. `S_INIT` 补 `kw_times_c_r <= kW_r * src_c_r`，避免 `row_stride = 0`。
2. `S_NEXT` kh 切换时修正 `out_col_offset_r` 更新。
3. `S_READ_WAIT` 收到 `gb_doutb_valid` 后清 `gb_enb`，避免 URAM 流水线残留 valid。
4. `S_READ_LATCH` 等残留 valid 消失再进 `S_WRITE`，避免写数据错位。

---

## 常见问题

### HBM Resetb / EMASA warning 很多，是否卡死？

通常不是卡死。HBM 初始化约需 207 us 仿真时间，大量 warning 是 Xilinx IP 模型自检。看到 `HBM init wait done` 后才开始 preload。

### `got` 全零和 `got` 非零但不等于 `exp` 有什么区别？

- `got` 全零：通常是没有写到目标 OBUF，优先查启动、写地址、done、tile mask。
- `got` 非零但不等于 `exp`：RTL 有输出，但数值或排列错误，优先查数据路径、pack/unpack、地址步进和量化语义。

### 报 `lite.sh` 或 `lite_dcim_array_0_0.v` 找不到怎么办？

先运行：

```bash
make export
```

### 如何确认当前运行结果？

```bash
make sim-done MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
```

或直接看：

```bash
less sim/run_dcim_matmul_dcim_tiny_1x1/sim.log
```

---

## 运行期文件格式

`preload.txt` 示例：

```text
act.hex 0000000100000000
weight.hex 0000000100080000
```

`checks.txt` 示例：

```text
dcim_tiny_1x1 expected.hex 200000 16 0
```

字段含义：

```text
<check_name> <expected_hex> <dst_obuf_hex> <check_words> <is_fp32>
```

其中 `is_fp32=0` 使用 128-bit bit-exact 比对；`is_fp32=1` 按 FP32 lane 做容差比较。
