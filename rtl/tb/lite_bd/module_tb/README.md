# module_tb — lite BD 模块级数值验证

工作目录：`rtl/tb/lite_bd/module_tb`

目标：在完整 lite BD（Block Design）上验证单个模块或小链路的数值正确性。所有任务都由 `inst.hex` 指令流、`preload.txt` 输入预加载和 `checks.txt` 检查点在运行期配置；VCS 编译产物 `simv` 可复用，不需要为每个 case 重新编译。

默认设置：

- `MODULE_CASE=dcim_matmul`
- `MODULE_VARIANT=dcim_tiny_1x1`
- `MODULE_VERIFY_WORDS=0`，表示校验全部 expected words
- `FAST=1`，跳过 `-debug_access`，更快
- `STOP_ON_FAIL=1`，批量仿真遇到失败即停止

---

## 快速开始

第一次或 BD/IP 改动后：

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
| `dcim_all` | `dcim_matmul` | `dcim_int8` + `dcim_int16` |
| `dcim_network` | `dcim_matmul` | `dcim_model_3_conv`、`dcim_model_5_conv`、`dcim_model_7_conv` |
| `qa_all` | `qa` | `qa_c16_signed`、`qa_c64_clip`、`qa_c128_dense` |
| `dqa_all` | `dqa` | `dqa_c16_small`、`dqa_c64_mid`、`dqa_c128_sppf` |
| `im2col_all` | `im2col` | `im2col_6x6_s2_c3`、`im2col_3x3_s2_c32`、`im2col_3x3_s1_c128`、`im2col_1x1_c512` |
| `mp_all` | `mp` | `mp_sppf_128_10` |
| `us_all` | `us` | `us_128_10_to20`、`us_64_20_to40` |
| `conv_pipe_all` | `conv_pipeline` | `pipe_conv3_s2_c32_to64`、`pipe_conv1_c512_to64_tilepass` |

---

## 当前验证状态（2026-05-28）

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
| `concat_2src_c64_c64_hw8x8` | UNTESTED |
| `concat_2src_c128_c128_hw10x10` | UNTESTED |
| `concat_4src_sppf_c128_hw10x10` | UNTESTED |

运行：

```bash
make list-cases MODULE_CASE=concat_by_cdma
make sim MODULE_CASE=concat_by_cdma MODULE_VARIANT=concat_2src_c64_c64_hw8x8
```

### large_channel_pressure

| 用例 | 实际模块 | 状态 |
|------|----------|------|
| `dcim_conv1_c512_to64_tilepass` | `dcim_matmul` | UNTESTED |
| `pipe_conv1_c512_to64_tilepass` | `conv_pipeline` | UNTESTED |
| `dqa_c256_pressure` | `dqa` | UNTESTED |
| `qa_c256_pressure` | `qa` | UNTESTED |
| `concat_c128_c128_to256` | `concat_by_cdma` | UNTESTED |

运行：

```bash
make list-cases MODULE_CASE=large_channel_pressure
make sim MODULE_CASE=large_channel_pressure MODULE_VARIANT=qa_c256_pressure
```

---

## 下一步建议测试顺序

当前已确认：

- `dcim_all`：8 case，`1272 PASS / 0 FAIL`
- `us_all`：2 case，`38400 PASS / 0 FAIL`
- `mp_all`：1 case，`3200 PASS / 0 FAIL`
- `im2col_all`、`qa_all`、`dqa_all`：已有 PASS 记录

仍建议优先补跑：

1. **DCIM 网络真实尺寸 smoke**：确认 `dcim_model_3/5/7_conv` 这类从网络层抽取的真实配置。

```bash
timeout 3h make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_network STOP_ON_FAIL=0 LOG=1
```

2. **完整 conv pipeline**：覆盖 `im2col + CDMA + DCIM + DQA/QA` 的组合路径，是单元都 PASS 后最关键的链路测试。

```bash
timeout 3h make rebuild-suite MODULE_CASE=conv_pipeline BATCH_SUITE=conv_pipe_all STOP_ON_FAIL=0 LOG=1
```

3. **可选重跑 VPU 单元回归**：如果最近改过 VPU/OBUF 接口，可重跑以下 suite 做回归。

```bash
timeout 2h make rebuild-suite MODULE_CASE=im2col BATCH_SUITE=im2col_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=qa BATCH_SUITE=qa_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=dqa BATCH_SUITE=dqa_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=us BATCH_SUITE=us_all STOP_ON_FAIL=0 LOG=1
timeout 1h make rebuild-suite MODULE_CASE=mp BATCH_SUITE=mp_all STOP_ON_FAIL=0 LOG=1
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
