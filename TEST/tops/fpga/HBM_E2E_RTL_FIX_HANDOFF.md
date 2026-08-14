# HBM / CDMA 互连修复交接：情况说明 + RTL 修改计划

给后续 agent 的完整上下文。目标：**官方 HBM staging 峰值 8-tile 正确（含 drain），YOLO/ResNet end-to-end 特征比对稳定通过**。不要把 host 上的规避当成架构变更。不要改 DCIM **乘加/nibble 数值语义**、ISA 编码、地址图、DQA/QA 公式。

---

## 2026-08-14：连续 DCIM job RTL 修复与仿真状态

已完成低资源的任务级状态修复，未修改 host ABI、地址图、数据 mapping、
INT8/native-INT16 数值语义或 HBM/CDMA：

- `DCIM_Tile` 以 `job_accept` 单周期脉冲作为 activation/cache/result-stream
  的唯一任务初始化边界；core 在 preload 期间继续保持 clear。
- `DCIM_Result_Stream` 不再用 response counter 推测 partial-sum context；
  BRAM 请求 tag 随两周期读延迟返回。
- 每个 Tile 增加 64-bit `partial_valid_map`，在 job start 清零、first-row
  写入后置位。后续 accumulator row 只允许读取本 job 已写 context；不清空
  64×512-bit BRAM payload，避免破坏 RAMB36 inference。
- 仿真加入 partial read-before-write、tag mismatch、response overflow 和
  row-done pending-token 断言。

VCS 已通过：

| 回归 | 结果 |
|---|---|
| 连续 INT8×2 + native INT16×2，中间均不 reset | PASS；每次 64/64 结果正确 |
| 实机等规模 INT8，4000 pixels、`acc_depth=2`，连续两次不 reset | PASS；两次均 16000 fires、4000/4000 结果正确 |
| 70 pixels、`acc_depth=3`、64+6 tail multiblock | PASS；420 fires、70/70 结果正确 |
| 峰值 pipeline | PASS；32/32，mismatch=0 |
| repeat benchmark | PASS；4 repeats、512/512 active cycles、2.048 TOPS@250MHz |
| INT8/native-INT16 core latency | PASS |

Vivado 预检也已通过：完整 `chip-lite` BD validation 生成 wrapper 成功；8-Tile
DCIM OOC 综合为 0 error、0 critical warning，250 MHz `WNS=+1.649 ns`、
`TNS=0`。partial-sum store 仍推断为每 Tile `7×RAMB36 + 1×RAMB18`；整个
8-Tile OOC 使用 LUT 37.74%、寄存器 20.85%、BRAM 10.32%、URAM 20.00%、
DSP 85.11%，本次任务隔离逻辑没有引起 RAM 寄存器化或显著资源膨胀。

以上证明 RTL 仿真中的连续任务、尾块、累加、native INT16 和峰值模式没有
回归。**仍必须由新 bitstream 依次执行 tile0、tile1、7 个 OH tile、再 tile0
的实机测试，才能关闭本节最初的板级故障。**

---

## 2026-08-14 夜：e2e 根因已钉死 — DCIM 第二次 job 内部状态脏

PCIe reset 后立刻复测（`tops_ila_hbmfix_260813`，脚本 `TEST/tops/fpga/e2e_isolate.py`）：

| 顺序 | 实验 | 结果 |
|---|---|---|
| 1 | XDMA C2H `Busy=false` | 复位成功 |
| 2 | YOLO `model.0.conv` **OH tile0 单独** DCIM vs numpy INT32 | **64000/64000**，`max_abs=0`，IBUF 权重 2048B 仍匹配 |
| 3 | 同一会话、decoder 重新 start：OH **tile1 单独**（HBM 再载权重） | **3783/64000**，`corr≈0.48`，首错像素 **211**，IBUF 权重仍匹配 |
| 4 | 再跑一遍 **tile0 单独** | **3783/64000**，同一套错法（3765 个坏像素从 px211 起） |

更早（复位前）已排除的：

| 实验 | 结果 |
|---|---|
| tile0 / tile1 **im2col** vs 软件 | 各 **32000/32000** |
| 编译器 OH crop vs 整图 im2col | 7 块全部 MATCH |
| tile0 一旦 DCIM 对，DQA FP32 | 出现过 **oh[0:25] max_abs=0 corr=1.0** |
| wait 后插 256 NOP、按 tile 拆开 + 50ms sleep | 不改变 e2e 错误 |
| YOLO 第一层整体 | `max_abs≈15.9` `corr≈0.56`；后面 6 个 OH tile `corr≈0.43–0.67` |

**结论：**

1. 峰值 INT8 含 drain **已经对**（单次 DCIM job，`acc_depth=1`）。
2. YOLO 第一层编译/im2col/DQA/HBM/IBUF 权重都不是根因。
3. `DCIM_Tile` **第一次 `dcim_layer` 在 reset 后 bit-exact；第二次起内部状态脏**。decoder soft-reset **清不掉**，只有 PCIe/bitstream reset 能恢复。
4. 脏状态特征稳定：约 5.9% INT32 仍 exact，从像素 211 起大面积错。权重 SRAM 从 IBUF 重载也救不回来 → 指向 **partial-sum RAM / micro-batch writer / start_pulse**，不是 host。

YOLO 第一层 7 次背靠背 `dcim_layer`（`acc_depth=2`，每块 4000 像素）。ResNet 同样会连打多次，且后层还有 `n_tiles*acc_depth>=256` 的 SRAM 分块缺口（`ops.py` 的 WA 编译器没用）。

RTL 下手处（**改 job 之间的状态，不要改 MAC**）：

- `rtl/chip/DCIM_Partial_Sum_RAM.sv`：BRAM **没有内容 clear**
- `rtl/chip/DCIM_Result_Stream.sv`：64-context 累加与 OBUF 写地址
- `rtl/chip/DCIM_Tile.sv`：`start_pulse`、`ST_PRELOAD`、`MICRO_BATCH=64`
- `rtl/chip/chip_defines.vh`：`DCIM_OBUF_WR_DRAIN` 仅 **2**
- `rtl/vpu/INST_Decoder.sv`：`S_EXEC_WAIT_DCIM` 无 `seen_busy`（`dcim_layer` 内部 wait 有）

复现（reset 后只打一次 tile0，不要先打别的 DCIM）：

```powershell
python TEST/tops/fpga/e2e_isolate.py --dcim-probe --dcim-tile 0   # 应 64000/64000
python TEST/tops/fpga/e2e_isolate.py --dcim-probe --dcim-tile 1   # 应失败，权重仍 match
python TEST/tops/fpga/e2e_isolate.py --skip-large-cdma --max-conv 1
```

Host C2H 仍拆 256B；隔离读回用 2048B 分块。不要打单笔 4KB C2H。

---

## 2026-08-14 晚：峰值 drain 已过，Step H **不要做**

隔离实验否定了「HBM 写第 2 笔必坏」：

| 实验 | 结果 |
|---|---|
| `cdma_dir_probe.py` 无 DCIM，BRAM↔BRAM / HBM↔HBM / HBM→BRAM / BRAM→HBM 共 57 项（含 8×4KB BRAM→HBM） | **57/57 PASS** |
| 软件 `hbm_drain_remap` 往返 | **2048/2048** |
| 峰值 drain 后 HBM slot[t] vs 当时 tile_obuf[t] | **8/8 MATCH_SELF**（CDMA 写回是对的） |
| 同一份 live scatter vs golden | **256/2048** |

根因是 **host**：`hbm_flow._preload_dst(fname)` 按文件名取 **第一行** 地址。峰值 `preload.txt` 里 `act.hex` 出现 8 次（8 个 tile IBUF），注入的 CDMA 却 8 次都写 **tile0**。tile1–7 用脏/旧激活计算。Drain 把这 8 份 OBUF 原样搬到 HBM，看起来像「只有 tile0」。此前 hbm scatter 偶发 2048/2048 是 **preload 残留 IBUF**，不是加载修过了。

已修：`tests/chip/unit-tb/hbm_flow.py` 的 `_preload_rows` 按 **每一行** 的 dst。`ChipRunnerWin.run_case(staging=hbm)` 恢复 `drain_output=True` + `read_check(from_hbm=True)`。

清 IBUF 后官方验收：

```text
python TEST/tops/fpga/run_peak_int8.py --staging hbm --repeat-count 1 --quiet-xdma
→ 2048/2048 PASS（含 drain）
```

**不要**为峰值 drain 再出 Step H（AXI outstanding limiter）/ Step I（HBM fence）bit。当前 bit 上峰值官方路径已经过。

YOLO INT8 一张图仍 FAIL（`PAN_P3/P4/P5 max_abs≈17/19/12`）。YOLO `plan.json` 里 **986 次 cdma_copy 的 dst 没有一次是 HBM**。不是 P1。根因见文首：连续 `dcim_layer` 弄脏 Tile。

---

## 2026-08-14 下午板测结论（`tops_ila_hbmfix_260813`，部分已更正）

Bitstream SHA-256 与 `TEST/tops/fpga/tops_ila_hbmfix_260813_release.md` 一致：

```text
top.bit  cc0c28f9ee064c79528128dd462a59e8529d787a050090d91fb9ef5d95da9d2a
```

本机烧录文件：`C:\Users\zczho\Downloads\top (2).bit`。代码：`test/tops/ila` @ `f88b510`（`fix-hbm-axi-path`，Step A/B/C 已进 BD）。

### 验收勾选

| 项 | 状态 |
|---|---|
| XDMA 枚举，16B～2048B C2H | **PASS** |
| 峰值 `--staging preload` 2048/2048 | **PASS**（DCIM 8 tile 计算正确） |
| 峰值 `--staging hbm` 加载后读 tile_obuf 2048/2048 | **PASS**（须先清 IBUF；旧 2048 可能是 preload 残留） |
| 峰值官方 drain（tile_obuf→HBM 再读 HBM）2048/2048 | **PASS**（晚间；下午 256/2048 是 act 只加载 tile0） |
| YOLO INT8 一张图 `atol=1e-3` | **FAIL** `max_abs` 12～18，`corr≈0.18～0.25` |
| ResNet INT8 一张图 `atol=1e-3` | **FAIL** `max_abs=127`，`corr≈0.17` |
| 单笔 ≥4KB C2H 不拆包 | **未在本 bit 上重打**（上一份 ILA bit 会楔死 PCIe；本轮 Step D 没做） |

**一句话（已更正）：峰值路径上单次 DCIM job 和 CDMA（含写 HBM）是对的。YOLO/ResNet e2e 错在连续 `dcim_layer`：reset 后第一笔 INT32 全对，第二笔起 Tile 内部状态脏。**

### 已证实（本 bit，2026-08-14 下午）

| 实验 | 结果 | 结论 |
|---|---|---|
| XDMA 枚举，REGS/OBUF/HBM 16B | 通 | 板卡能起来 |
| TILE_OBUF / HBM 单笔 C2H 16/256/512/1024/**2048** | 通 | 中等突发可读 |
| Host 写再读 HBM 4KB / 32KB / **256KB**（C2H 拆 256B） | **0 mismatch** | HBM 颗粒和 XDMA 通路本身是好的 |
| Host 写再读 VPU_BUF、TILE_OBUF 4KB（同样拆包） | PASS | 片上 BRAM 对 Host 也通 |
| 峰值 preload（H2C 直写 8×IBUF，读 tile_obuf） | **2048/2048** | **单次 DCIM job 的乘加语义对** |
| 峰值 hbm 加载（8× HBM→IBUF act/weight），`drain_output=False`，scatter 读 tile_obuf | **2048/2048** | **HBM→tile 加载 CDMA 对本峰值尺寸已修好** |
| 同上但 `drain_output=True`，从 HBM 读 flat 结果 | **256/2048** | **tile_obuf→HBM 写回仍只信第一笔** |
| YOLO INT8 `000000000139.jpg` | DONE 1.05s；P3/P4/P5 `max_abs` 16.2/18.3/12.0；按 16ch 切开 **每一组 corr 都低**（0.04～0.57） | **不是「只有 tile0 对」**，是很早的层就开始全局算错 |
| ResNet INT8 goldfish | DONE 0.82s；输出 (7,7,512) INT8 `max_abs=127` `corr=0.17` | 同一类全网搬运/计算错误，不是 1 ULP |
| YOLO 读回 700KB（256B 分块） | ~66s | 慢在 C2H 拆包，不是 execute |

峰值 golden 首字 `0x00001778` 在 preload 和（加载后读 tile_obuf 的）hbm 路径都能对上。

### 不要当成根因

- **不要**改 DCIM 的 nibble/MAC/INT8 打包去「凑」e2e。峰值单次 job 已与 golden 对齐。要改的是 **job 之间的 Tile 状态**（见文首夜节）。
- **不要**把 `CDMA_COOLDOWN_CYCLES` 当主修复。
- **不要**把 YOLO `corr≈0.2` 解释成 HBM 加载没修好。YOLO **从不 CDMA 写 HBM**。
- Host 写读 256KB HBM 全对 → **不是 HBM PHY 坏、也不是 XDMA 写 HBM 坏**。
- SmartConnect 2024.2 **没有**可写的 per-port outstanding 上限。不要为已关闭的 P1 再做 limiter。

### 当前拓扑（`f88b510` 已落地，不要再按旧图改）

```
XDMA M_AXI 256b @250MHz
  → axi_xdma_smc (1SI, 3MI)
      M00 → axi_tile_smc S00 → 8×ibuf + 8×obuf (128b)
      M01 → axi_misc_smc S00 → vpu_buf, wb, inst, regs
      M02 → axi_hbm_smc S00

AXI CDMA M_AXI 256b @250MHz  (DRE=1, MAX_BURST_LEN=16)
  → axi_cdma_smc (1SI, 3MI)
      M00 → axi_tile_smc S01
      M01 → axi_misc_smc S01
      M02 → axi_hbm_smc S01

axi_hbm_smc (2SI, 1MI)
  → hbm_axi_regslice (FULL, MAX_BURST_LENGTH=16)
  → hbm_axi_cc (250↔450, 256b, ID_WIDTH=6)
  → hbm_0/SAXI_00 (4GB interleaved)

复位：cpu_reset OR ~xdma axi_aresetn
  → hbm_s_rst @250MHz → CC S + hbm_smc + regslice
  → hbm_rst   @450MHz → CC M + HBM AXI_00
```

地址未改：HBM `0x0` 4GB，TILE_IBUF `0x1_0000_0000`，TILE_OBUF `0x1_0100_0000`，VPU_BUF `0x1_0200_0000`，WB `0x1_0300_0000`，INST `0x1_0400_0000`，REGS `0x1_0500_0000`。

---

## 0. 仓库与板卡身份

| 项 | 值 |
|---|---|
| Repo | `E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA` |
| Branch | `test/tops/ila` @ `f88b510` |
| 设备 | VCU128 `xcvu37p-fsvh2892-2L-e`，Windows XDMA |
| 当前 bit | `tops_ila_hbmfix_260813` / `cc0c28f9…`。**不要**烧会 Code 10 的 `tops_ila_cegate_260812.bit`（`8466f519…`） |
| Release | `TEST/tops/fpga/tops_ila_hbmfix_260813_release.md` |
| Host | `tests/bin/xdma_rw.exe`，`tests/chip/unit-tb/xdma_win.py` |
| Python | `D:\SoftwareTools\miniconda\miniconda\python.exe` |

不要把 `TEST/end2end/` 工作区残留合进本分支。

---

## 1. 仍未达到的验收口径

1. **峰值官方 drain**：**已过** 2048/2048（`--staging hbm`，`drain_output=True`）。
2. **YOLO INT8** 一张图 compare 退出码 0（`atol=1e-3`）。ResNet INT8 同样。**未过**。
3. **C2H**：临时 `C2H_CHUNK_BYTES=4096` 时 TILE_OBUF 与 HBM 单笔 4KB 成功（或文档明确仍建议 256B 分块，但 e2e 数值已过）。

功耗窗口：加载路径已可 `--staging hbm --repeat-count N`（结果仍读 tile_obuf）。不要为功耗改数据通路。

---

## 2. 问题拆开（下一步只修这些）

### 问题 P1 — ~~CDMA 写 HBM 第 2 笔~~ **已关闭（host bug）**

峰值 256/2048 不是 HBM 写通道。见文首「晚间」节。`cdma_dir_probe.py` 与 drain MATCH_SELF 已否证。**不要再为 P1 改 BD。**

### 问题 P2 — 连续 `dcim_layer` 把 Tile 打脏（当前主问题）

YOLO 第一层 oh[0:25] 在 DCIM 干净时可以 DQA bit-exact；oh[25:160] 和 **reset 之后的第二笔 DCIM** 失败。IBUF 权重未被激活 CDMA 覆盖。不是 `cdma_stride`、也不是 512KB VPU 搬运（那些尺寸的 unique-pattern CDMA 已 MATCH）。

下一步只修 DCIM_Tile job 复位 / partial-sum 清空。修完后用文首三条 `e2e_isolate` 命令验收：tile0 全对、tile1 仍全对、第一层 7 个 OH tile 全对。

### 问题 P3 — 通向 128-bit BRAM 的长 C2H（Step D，本轮未做）

上一份可枚举 ILA bit 上，TILE_OBUF/HBM **单笔 4096B** 会把 XDMA 打成 Busy，需 PCIe 复位。本 bit 上 2048B 已通，4096B 为保板卡未再测。Host 继续 `C2H_CHUNK_BYTES=256`。P3 不阻塞 P1 的 drain/e2e 数值修复，但不要在 P1 实验中途打 4KB 单笔。

---

## 3. 关键源文件

| 文件 | 作用 |
|---|---|
| `scripts/ip/bd/lite/connect.tcl` | 现拓扑：xdma/cdma 3MI、misc 4MI、hbm_smc、复位 OR |
| `scripts/ip/bd/lite/hbm.tcl` | `hbm_s_rst`/`hbm_rst`、`hbm_axi_cc` ID=6、`hbm_axi_regslice` |
| `scripts/ip/bd/lite/cdma.tcl` | 已设 `C_M_AXI_MAX_BURST_LEN=16` |
| `rtl/vpu/CDMA_Controller.sv` | SR IDLE + `CDMA_COOLDOWN` |
| `tests/chip/unit-tb/hbm_flow.py` | `_preload_rows` 按行 dst；禁止按文件名折叠 |
| `tests/chip/unit-tb/xdma_win.py` | C2H 256B 分块；hbm staging **已开 drain** |
| `TEST/tops/fpga/run_peak_int8.py` | `--staging hbm` 走官方 drain 读 HBM |
| `TEST/tops/fpga/e2e_isolate.py` | YOLO 第一层 OH tile：im2col / 孤立 DCIM / 连续 DCIM / prefix |
| `TEST/tops/fpga/cdma_dir_probe.py` | 无 DCIM 的 CDMA 方向/次数探针 |
| `rtl/chip/DCIM_Tile.sv` | 连续 job 状态；`start_pulse` / preload / micro-batch |
| `rtl/chip/DCIM_Partial_Sum_RAM.sv` | 64×512b 累加 RAM，无内容 clear |
| `TEST/tops/fpga/peak_hbm_retest.py` | 清 IBUF 后 peak load+drain 验收 |
| `tests/chip/runtime/hw_runner_win.py` | E2E；权重 H2C→HBM，结果从 VPU_BUF C2H |

复现命令：

```powershell
# 峰值官方 drain：应 2048/2048
python TEST/tops/fpga/run_peak_int8.py --staging hbm --repeat-count 1 --quiet-xdma

python run.py --network yolo --yolo-precision int8 --one-shot-yolo-expect-detections -1
python run.py --network resnet --resnet-precision vai
```

---

## 4. RTL / BD 修改计划

原则：P1（HBM 写）已关闭。当前只出 **DCIM job 复位** bit。C2H Busy 后先 PCIe 复位，不要继续打。

### Step G — 已完成

`drain_output=True` 已恢复为 hbm 默认。`drain_output=False` 仍可作调试开关。

### Step H / I — **取消**（不要为峰值 drain 出新 bit）

HBM write outstanding limiter 和 HBM read fence **没有**实验支持。本 bit 上 8× BRAM→HBM 和官方 peak drain 都已过。

### Step J — DCIM 连续 job 状态（当前主线）

验收（必须 **PCIe reset 后按顺序**，中间不要夹别的 DCIM）：

1. `--dcim-probe --dcim-tile 0` → 64000/64000
2. `--dcim-probe --dcim-tile 1` → **也要** 64000/64000（今天第二笔必挂）
3. `--skip-large-cdma --max-conv 1` → 7 个 OH tile 均 `max_abs=0`
4. 再打一遍 tile0 仍 64000/64000（证明不再粘滞）

改动范围：`DCIM_Partial_Sum_RAM` 在 start 清内容或 first_row 不读脏数据且 writer 状态机在 `ST_IDLE` 真正复位；检查 `start_pulse` 在 decoder 连发两次 `dcim_layer` 时是否丢边沿。不要改 nibble 打包、acc 公式、ISA 字段。

不要再改 HBM SMC / CC / limiter。

### Step D — 长 C2H（P3，独立）

对 tile/vpu 的 128-bit MI：`MAX_BURST_LENGTH` ≤8 或 16，或 XDMA 后限制 burst 到 PCIe MPS。验收：`C2H_CHUNK_BYTES=4096` 时 OBUF 与 HBM 单笔 4KB 成功。本 bit 上先从 2048（已通）试 4096，失败就复位，不要循环重试。

### 不要动

- DCIM MAC / nibble 布局、`OP_DCIM_LAYER` **编码**、repeat/`CTRL[2]` 峰值语义
- `address.tcl` 段基址（HBM 仍 `0x0` 4GB）
- VPU DQA/QA 数值公式；ILA probe 集合（除非时序不收敛）

---

## 5. Host 现状（不要无故回滚）

1. `xdma_win.py`：`C2H_CHUNK_BYTES=256`；`staging=hbm` 时 **drain_output=True**，结果读 HBM。
2. `run_peak_int8.py`：默认 `--staging preload`；`--staging hbm` 走官方 drain。
3. `compare_one_shot.py`：QA `×float32(1/act_scale)`，与 FPGA 一致。e2e corr 低不是 golden 造成的。
4. **不要提交** `TEST/end2end/` 残留、bit/ltx 大文件。

---

## 6. 给修改者的约束

- 用中文写每个 RTL 改动对应哪条 `e2e_isolate` 实验。
- 新 bit 必须带配对 `.ltx`；以能枚举为准。
- 不要为已关闭的 P1 再出 HBM limiter bit。
- 改完更新本文件顶部勾选。验证连续 DCIM 前必须 PCIe reset。

---

## 7. 最小成功标准（停手用）

**完成（峰值）**：hbm **drain** 2048/2048。

**未完成**：reset 后第二笔孤立 DCIM 仍非 64000/64000；YOLO/ResNet e2e；4KB 单笔 C2H。

**不要当成未完成**：再加 cooldown、再出 Step H limiter bit、再改 host preload。
