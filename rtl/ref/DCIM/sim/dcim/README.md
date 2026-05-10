# DCIM 顶层仿真（`sim/dcim`）

本目录对 RTL 中的 **`dcim`** 做 **Synopsys VCS** 功能仿真：权重经 SRAM 与 **`ppCache`** 送入乘加阵列，激活流式输入，结果经 **`postProcess`** 输出。默认波形为 **FSDB**（Verdi）。**所有 `make` 命令在本目录执行**：

```bash
cd rtl/ref/DCIM/sim/dcim
```

---

## 1. 文档结构

| 章节 | 内容 |
|------|------|
| §2 | 环境、Makefile、波形、仿真文件 |
| §3 | **硬件数据流**、**计算阶段**、**`up_ready_cal` 含义** |
| §4 | **`ppCache` / `swap`、从 SRAM 加载的比特数** |
| §5 | **WD2 / WD3**、**Golden 模型**（`transfer.py`） |
| §6 | 编译参数、**CH_OUT≠CH_IN** 与 **CH_OUT=64** 注意 |
| §7 | CNN 到矩阵乘的**映射要点**（含 im2col） |
| §8 | 常见问题、相关文件 |

---

## 2. 构建、运行与波形

### 2.1 环境

| 用途 | 说明 |
|------|------|
| **VCS** | `vcs` 在 `PATH`，或 `make VCS=/path/to/vcs`。 |
| **Verdi / FSDB** | 默认 **`FSDB=1`** 需链接 Verdi PLI，**必须设置 `VERDI_HOME`**。 |
| **Python** | `make check` 需 **Python 3**、**NumPy**；可 `make check PYTHON=python3`。 |
| **仅 VCD** | 无 `VERDI_HOME` 时：`FSDB=0 make compile`，生成 **`waveform.vcd`**。 |

### 2.2 主要 `make` 目标

| 目标 | 作用 |
|------|------|
| `make help` | 简要帮助。 |
| `make compile` / `make compile_vcs` / `make simv` | VCS 生成 **`./simv`**（默认 FSDB）。 |
| `make run` / `make run_vcs` | 运行 **`./simv`**。 |
| `make all` / `make all_vcs` | `compile` → `run` →（`WAVE=y` 时 `wave`）→ `check`。 |
| `make wave` / `make verdi` | 优先打开 **`waveform.fsdb`**，否则 **`waveform.vcd`**。 |
| `make check` | 运行 **`transfer.py`**。 |
| `make clean` | 删除 `simv`、`simv.daidir`、`*.fsdb`、`*.mem`、`compile.log` 等。 |
| `make test_int8xint8` / `test_int16xint16` | `TYPE=INT8` 或 `INT16` 全流程 + `check`。 |

**`FSDB`**：`FSDB=1`（默认）需 `VERDI_HOME`；`FSDB=0` 仅 VCD、不需 PLI。

**KDB 调试**：`make run` 后 `verdi -dbdir simv.daidir &`（与 **`verdi_config_file`** 中 `simv.daidir` 一致）。

### 2.3 编译与运行参数

| 变量 | 含义 | 默认 |
|------|------|------|
| `TYPE` | `TEST_INT4` … `TEST_UINT16` | `INT4` |
| `ACC` | 与 TB / **`transfer.py`** 中批累加一致 | `0` |
| `CH_IN` / `CH_OUT` | 输入 / 输出通道维 | `16` |
| `WD1` | 物理小段宽（INT8/16 由多段拼接） | `4` |
| `R` | 与 `dcim` 的累加深度参数、**WD3** 一致 | `16` |
| `WAVE` | `y` 时 `make all` 会 `make wave` | `n` |

```bash
export VERDI_HOME=/path/to/verdi
make all TYPE=INT8 WAVE=y
FSDB=0 make compile && make run
```

### 2.4 仿真生成的文件

| 文件 | 说明 |
|------|------|
| `memory.mem` / `calculate.mem` | `simToolUp` 写出的激励。 |
| `result.mem` | `simToolDown` 采集的 DUT 输出。 |
| `cache.mem` | TB **`printMemory`** 写出的、与 **`mid_data_wei`** 一致的权重视图。 |
| `waveform.fsdb` / `waveform.vcd` | 由 **`FSDB`** 与 TB 中 dump 方式决定。 |

---

## 3. 硬件数据流与计算阶段

### 3.1 顶层连接（数学抽象）

- **`memory`** 输出 **`mid_data_wei`**：当前 tile 的权重量，总宽 **`CH_IN×CH_OUT×WD1`**（**`mode_cal`** 决定 INT4/8/16 打包）。
- **`calculate_core`（`maArray`）**：**激活 `up_data_cal`**（**`CH_IN×WD1`**）与 **`mid_data_wei`** 做乘加，得到 **`CH_OUT×WD2`**。
- **`postProcess`**：按 **`mode_cal`、`acc`** 规整到 **`CH_OUT×WD3`**，即 **`dn_data`**。
- **握手**：**`up_ready_cal = w_ready_cal & mid_valid_wei`** —— **权重侧 tile 有效且计算准备好时才接收激活**，避免激活先于权重。

### 3.2 时间顺序（与 `dcim_tb` 对应）

| 阶段 | TB / 控制 | 硬件含义 |
|------|-----------|----------|
| **写 SRAM** | 递增 **`up_address_wei`**，持续 **`wr_wei`** | 向 **`SRAM_DP` 深度**写入权重 slice（口宽 **`SRAM_WD`**）。 |
| **装入 ppCache** | **`load_wei`** 脉冲触发 **`load_fsm`** | 从 SRAM **连续读 `CYCLE` 次**，每拍 **`TILE_WD`** bit，拼满一半 ping-pong；详见 §4。 |
| **swap** | **`swap_wei`** 一拍 | 切换 **`ppCache`** 对外输出的 bank（见 §4）。 |
| **计算** | **`ena_stu_c`**，激活通道 **`simToolUp_cal`** | 送 **`calculate.mem`**，输出 **`result.mem`**；同一 **`swap` 后的权重量**下可送多拍激活（多行矩阵乘）。 |

---

## 4. `ppCache` 与 `swap`

### 4.1 `ppCache` 做什么

- **`TILE_WD = CH_IN×CH_OUT×WD1 / CYCLE`**：SRAM **单拍读宽度**（等于 **`memory.WD`**）。
- 内部 **`cacheMem`** 含 **`CYCLE`个（默认 8）** 存储槽；每槽 **`TILE_WD`** bit。
- **连续 `CYCLE` 次有效握手**写满后，输出 **`dn_data`** 拼成 **`TILE_WD×CYCLE = CH_IN×CH_OUT×WD1`**，即 **一整块 tile**。
- **双缓冲**：两套 **`cacheMem`**（`w_data0` / `w_data1`），写指针由控制器 **`ptr_in`** 选择。

### 4.2 `swap` 做什么

- **`swap`** 在控制器 **READY** 状态下 **翻转 `ptr_in`**，切换 **哪一块缓冲接到 `dn_data`**（送给 **`calculate_core`**）。
- 用于 **ping-pong**：一侧继续从 SRAM 填充，另一侧稳定输出；或 **切换当前参与计算的权重版本**。

### 4.3 一次从 SRAM 装入 ppCache 的量

| 项目 | 公式 |
|------|------|
| 每拍读 SRAM | **`TILE_WD`** bit |
| 一次完整 `load` 序列（`CYCLE` 拍） | **`CYCLE × TILE_WD = CH_IN × CH_OUT × WD1`** bit |

默认 **16×16×4、CYCLE=8**：**`TILE_WD=128`** bit/拍，**一整 tile = 1024 bit**。

---

## 5. WD2 / WD3 与 Golden 模型

### 5.1 位宽定义（RTL localparam）

- **WD2** = **`2×WD1 + log2(CH_IN)`**：单通道 **乘加树输出**（内积跨 **CH_IN** 累加）。
- **WD3** = **WD2 + log2(ACC)**：**`postProcess`** 后每通道输出位宽；**`ACC`** 为 **`dcim` 的 parameter**（TB 常与宏 **`R`** 绑定），与 Makefile 里传给 **`transfer.py`** 的 **`ACC`（批累加）** 名称易混，需区分。

### 5.2 `transfer.py`（`make check`）

- **`cache.mem`** → **权重矩阵**；**`calculate.mem`** → **激活矩阵**（**INT8** 时 **`C=2`** 行拼一节；**INT16** 时 **`C=4`**）。
- **参考**：**`result.mem`**，解析位宽 **`WD3×C`**，列数为 **`CH_OUT//C`**。
- **对比**：**`calculated_result = act_mat @ weight_mat`**；若环境变量 **`ACC≠0`**，再按 **`ACC` 行一组**对 **`calculated_result`** 求和。

验证通过表示：**端到端数值与该定点矩阵模型一致**（在脚本解析规则下）。

---

## 6. 参数扩展（如 CH_OUT=64、矩阵乘）

### 6.1 必须满足

- **`CH_OUT % 4 == 0`**（`maArray` / `mergeArray` / `accumulateArray` 以 **`CH_OUT/4`** 展开）。
- **`CH_IN×CH_OUT×WD1` 能被 `CYCLE` 整除**（**`TILE_WD`** 为整数）。

### 6.2 当前 TB 限制（修改 RTL 前必读）

- **`dcim_tb.v`** 中 **`parameter CH_OUT = `CH_IN`**：实例化 **`dcim`** 时 **输出通道随 CH_IN**，仅改 Makefile **`CH_OUT`** **不会**得到独立的 **64**，需改为 **`CH_OUT` 宏**（例如 `` `CH_OUT ``）或保证 **`CH_IN=CH_OUT`** 的使用场景。

### 6.3 仿真 SRAM 模型

- **`sramWrap.v`（SIM）** 若仍将 **`model_rf`** 固定为 **128×128**，当 **`SRAM_WD≠128`**（如 **CH_OUT=64** 导致口宽变大）时，需改为 **参数化 WIDTH/DEPTH** 或拆分，否则仿真与总线不一致。

### 6.4 INT8×INT8 / INT16×INT16 且 OUT=64 的配置思路

- **`CH_OUT=64`**，**`TYPE=INT8`** 或 **`INT16`**，**`WD1=4`**。
- **`CH_IN`** = 矩阵乘的 **K**（例如 **64×64** 且两侧对齐则 **`CH_IN=64`**）。
- **编译与 `transfer.py`** 使用 **同一套 `CH_IN`、`CH_OUT`、`WD1`、`R`、`TYPE`、`ACC`**。

---

## 7. CNN 映射要点（矩阵乘视角）

- **DCIM 路径最适合 GEMM**：卷积常通过 **im2col（或等价 patch 展开）** 变为 **`A @ B`**。
- **输出通道** ↔ **`CH_OUT`**；**展开后的输入维（K²·C_in 等）** ↔ **`CH_IN`**（需在片上 **tile / 多趟** 若一次放不下）。
- **减轻 im2col 存储膨胀**：优先 **滑动窗口复用、分块 tiling**，而非单独依赖换一种数学形式。
- **深度可分离**：DW 与 PW 映射不同；**1×1 conv** 即 **`C_in×C_out`** 矩阵乘，与 **`dcim`** 形态最近。

---

## 8. 常见问题

**FSDB 编译报错需 `VERDI_HOME`**  
→ `export VERDI_HOME=...`，或 `FSDB=0 make compile`。

**找不到 `./simv`**  
→ `make clean` 后 `make compile`，或删 **`simv.daidir/.vcs.timestamp`** 再编译。

**Verdi 警告找不到 `novas.conf`**  
→ 可选在工作目录放置配置文件，或忽略（一般不影响打开 FSDB）。

---

## 9. 相关文件

| 文件 | 说明 |
|------|------|
| `filelist.f` | RTL + `model_rf.sv` + `dcim_tb.v`。 |
| `sim_vars.mk` | `TYPE`、`CH_*`、`WD1`、`R`、`ACC` 等 **VCS 宏**。 |
| `Makefile` | `compile`/`run`/`clean`、`FSDB`、`test_*`。 |
| `transfer.py` | Golden 比对。 |
| `verdi_config_file` | KDB：`simv.daidir` 别名示例。 |

更多单行说明：**`make help`**。
