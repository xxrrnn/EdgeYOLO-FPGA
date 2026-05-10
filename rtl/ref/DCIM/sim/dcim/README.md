# DCIM 顶层仿真（`sim/dcim`）

本目录对 **`dcim`** 顶层模块做功能仿真：权重 SRAM 写入、`load/swap`、激活侧握手送入 **`calculate_core`**、输出经 **`postProcess`**，SRAM 行为级模型为 **`model_rf`**（`filelist.f` 中引用）。所有 `make` 命令请在 **本目录** 下执行。

```bash
cd rtl/ref/DCIM/sim/dcim
```

---

## 环境要求

| 用途 | 说明 |
|------|------|
| **iverilog（默认）** | 需安装 [Icarus Verilog](https://github.com/steveicarus/iverilog)，可执行文件名为 `iverilog`（可通过 `make IVERILOG=...` 覆盖路径）。 |
| **VCS（可选）** | Synopsys VCS，可执行文件 `vcs` 在 `PATH` 中，或 `make VCS=/path/to/vcs`。 |
| **GTKWave（可选）** | 查看 `waveform.vcd`，与 `make wave` 配合。 |
| **Verdi（可选）** | 查看同一套 `waveform.vcd`，或打开 VCS 生成的 KDB；建议设置 `VERDI_HOME`，`make verdi` 会优先使用 `$VERDI_HOME/bin/verdi`。 |
| **结果校验** | `make check` 调用 `transfer.py`，需 **Python 3** 与 **NumPy**（`pip install numpy`）。若上级目录存在 `venv` / `.venv`，会自动选用其中的 Python。 |

---

## 两套仿真流程（务必区分）

| 项目 | iverilog（默认） | Synopsys VCS |
|------|------------------|--------------|
| 编译目标 | `make compile` 或 `make compile_iverilog` | `make compile_vcs` |
| 可执行文件 | **`./simv`** | **`./simv_vcs`**（勿与 `simv` 混用） |
| 运行 | `make run` 或 `make run_iverilog` | `make run_vcs` |
| 宏 | 定义 **`IVERILOG`** | 定义 **`VCS`**（不定义 `IVERILOG`） |
| 典型用途 | 开源、轻量、无 license | 与 **Verdi** 联调、KDB、企业流程 |

预处理器与公共参数集中在 **`sim_vars.mk`**。若在 RTL 里需要区分工具链，可使用 `` `ifdef IVERILOG `` / `` `ifdef VCS ``。

**VCS 说明**：编译选项中含 `-ignore initializer_driver_checks`，用于通过行为模型 `model_rf.sv` 中数组初始化与 `always_ff` 写入的检查策略差异，与 iverilog 侧行为对齐。

---

## Makefile 目标一览

| 目标 | 作用 |
|------|------|
| `make help` | 打印与本文档一致的简要说明。 |
| `make compile` | 默认等于 `compile_iverilog`。 |
| `make compile_iverilog` | 用 iverilog 生成 **`simv`**。 |
| `make run` | 默认运行 **`./simv`**。 |
| `make all` | `compile` → `run` →（若 `WAVE=y` 则 `wave`）→ `check`。 |
| `make compile_vcs` | 用 VCS 生成 **`simv_vcs`**，含 `-debug_access+all -kdb`。 |
| `make run_vcs` | 运行 **`./simv_vcs`**。 |
| `make all_vcs` | `compile_vcs` → `run_vcs` → `check`。 |
| `make wave` | `gtkwave waveform.vcd signals.gtkw &`（需自备 `signals.gtkw` 或按需修改 Makefile）。 |
| `make verdi` | 使用 Verdi 打开 **`waveform.vcd`**（`-ssf`）。 |
| `make check` | 运行 **`transfer.py`**，对比数值结果。 |
| `make clean` | 删除 `simv`、`simv_vcs`、`*.daidir`、`csrc`、`waveform.vcd`、`*.mem`、`compile_vcs.log` 等生成物（**慎用**：会删掉目录内匹配的 `.mem`/`.txt` 等，提交前请确认已备份激励与黄金结果）。 |

---

## 编译与运行参数

通过命令行传入（与 `sim_vars.mk` 中默认值一致时可省略）：

| 变量 | 含义 | 默认 |
|------|------|------|
| `TYPE` | 数据类型宏：`TEST_INT4` … `TEST_UINT16` 之一 | `INT4` |
| `ACC` | 累加相关配置（与 `para.v` / TB 一致） | `0` |
| `CH_IN` / `CH_OUT` | 输入/输出通道数 | `16` / `16` |
| `WD1` | 基础数据位宽 | `4` |
| `R` | 与量化深度相关的参数（与 TB 中累加位宽等有关） | `16` |
| `WAVE` | 设为 `y` 时，`make all` 会在仿真后自动执行 `make wave` | `n` |

示例：

```bash
make all TYPE=INT8 ACC=0 CH_IN=16 CH_OUT=16 WD1=4 R=16 WAVE=y
make compile_vcs TYPE=UINT4 R=8
```

`transfer.py` 通过环境变量读取同类配置（`make check` 前 Makefile 已 `export`），需与仿真所用参数一致。

---

## 仿真用到的文件（激励与结果）

Testbench **`dcim_tb.v`** 通过 **`simTools`** 读写二进制文本：

| 文件 | 方向 | 说明 |
|------|------|------|
| **`memory.mem`** | 写入 DUT | 权重侧 **`simToolUp`**，配合内部写握手写入 SRAM。 |
| **`calculate.mem`** | 写入 DUT | 计算侧激活/输入数据流。 |
| **`result.mem`** | 读出 | DUT 输出由 **`simToolDown`** 抓取。 |
| **`waveform.vcd`** | 输出 | `$dumpvars` 生成的波形；iverilog 与 VCS 仿真均会覆盖同名文件。 |
| **`cache.mem`** | 输出 | TB 中 **`printMemory`** 任务写出，用于核对缓存中的权重视图。 |

运行前请在本目录准备好 **`memory.mem`**、**`calculate.mem`** 等（可与仓库内 **`memory.data`** 等参考数据配合生成）。若缺失，`simTool*` 读文件可能报错或结果为空。

---

## `transfer.py`（`make check`）

脚本读取 **`cache.mem`**、**`calculate.mem`**、**`result.mem`**，按当前 `TYPE`、`WD1`、`CH_IN`、`CH_OUT`、`R`、`ACC` 做解析并与矩阵运算黄金结果对比，在终端打印 **验证通过 / 验证失败**。

依赖 NumPy；建议在虚拟环境中安装：

```bash
python3 -m pip install numpy
```

---

## 用 Verdi 看波形

1. 先完成任意一种仿真并生成 **`waveform.vcd`**（iverilog 或 VCS 均可）。
2. **方式 A（推荐简单）**：`make verdi`  
   等价于使用 `VERDI_HOME` 下的 `verdi -ssf waveform.vcd`（若未设置 `VERDI_HOME`，则使用 PATH 中的 `verdi`）。
3. **方式 B（VCS + KDB）**：先 `make run_vcs`，再例如：  
   `verdi -dbdir simv_vcs.daidir &`  
   用于需要与编译数据库联动的调试场景。

---

## 常见问题：`make run_vcs` 报 `./simv_vcs: Command not found`

VCS 会做增量编译：若 **`simv_vcs.daidir`** 仍在但 **`./simv_vcs` 已被删掉**（例如只删了可执行文件、或 `clean` 不完整），会出现 “The design hasn't changed and need not be recompiled”，且不再链接出新的 **`simv_vcs`**，随后运行阶段找不到二进制。

**处理方式（任选其一）**：

1. 在本目录执行 **`make compile_vcs`**（Makefile 会在缺少 `simv_vcs` 时自动删掉 **`simv_vcs.daidir/.vcs.timestamp`** 并强制重新生成可执行文件）。
2. 完整重来：**`make clean`** 后 **`make compile_vcs`**。
3. 手动：删除 **`simv_vcs.daidir/.vcs.timestamp`**（或整个 **`simv_vcs.daidir`**）后再 **`make compile_vcs`**。

---

## 相关文件

| 文件 | 说明 |
|------|------|
| **`filelist.f`** | RTL + `model_rf.sv` + `dcim_tb.v` 编译列表。 |
| **`sim_vars.mk`** | iverilog / VCS 共用宏与包含路径。 |
| **`Makefile`** | 双流程入口与 `clean`、`help`。 |

更多命令说明可随时执行 **`make help`**。
