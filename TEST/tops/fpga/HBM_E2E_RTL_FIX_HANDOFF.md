# HBM / CDMA 互连修复交接：情况说明 + RTL 修改计划

给后续 agent 的完整上下文。目标：**官方 HBM staging 峰值 8-tile 正确（含 drain），YOLO/ResNet end-to-end 特征比对稳定通过**。不要把 host 上的规避当成架构变更。不要改 DCIM 阵列、ISA、地址图、DQA/QA 数值语义。

---

## 2026-08-14 板测结论（`tops_ila_hbmfix_260813`）

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
| 峰值 `--staging hbm` 加载后读 tile_obuf 2048/2048 | **PASS**（HBM→IBUF 这组加载 CDMA 好了） |
| 峰值官方 drain（tile_obuf→HBM 再读 HBM）2048/2048 | **FAIL 256/2048**（仍只有 tile0） |
| YOLO INT8 一张图 `atol=1e-3` | **FAIL** `max_abs` 12～18，`corr≈0.18～0.25` |
| ResNet INT8 一张图 `atol=1e-3` | **FAIL** `max_abs=127`，`corr≈0.17` |
| 单笔 ≥4KB C2H 不拆包 | **未在本 bit 上重打**（上一份 ILA bit 会楔死 PCIe；本轮 Step D 没做） |

**一句话：DCIM 算对了，Host↔HBM 也对了。坏的是片上 CDMA 写 HBM（以及全网大量混合 CDMA）。加载方向单测过了，写回和 e2e 没有过。**

### 已证实（本 bit，2026-08-14 下午）

| 实验 | 结果 | 结论 |
|---|---|---|
| XDMA 枚举，REGS/OBUF/HBM 16B | 通 | 板卡能起来 |
| TILE_OBUF / HBM 单笔 C2H 16/256/512/1024/**2048** | 通 | 中等突发可读 |
| Host 写再读 HBM 4KB / 32KB / **256KB**（C2H 拆 256B） | **0 mismatch** | HBM 颗粒和 XDMA 通路本身是好的 |
| Host 写再读 VPU_BUF、TILE_OBUF 4KB（同样拆包） | PASS | 片上 BRAM 对 Host 也通 |
| 峰值 preload（H2C 直写 8×IBUF，读 tile_obuf） | **2048/2048** | **不要再怀疑 DCIM** |
| 峰值 hbm 加载（8× HBM→IBUF act/weight），`drain_output=False`，scatter 读 tile_obuf | **2048/2048** | **HBM→tile 加载 CDMA 对本峰值尺寸已修好** |
| 同上但 `drain_output=True`，从 HBM 读 flat 结果 | **256/2048** | **tile_obuf→HBM 写回仍只信第一笔** |
| YOLO INT8 `000000000139.jpg` | DONE 1.05s；P3/P4/P5 `max_abs` 16.2/18.3/12.0；按 16ch 切开 **每一组 corr 都低**（0.04～0.57） | **不是「只有 tile0 对」**，是很早的层就开始全局算错 |
| ResNet INT8 goldfish | DONE 0.82s；输出 (7,7,512) INT8 `max_abs=127` `corr=0.17` | 同一类全网搬运/计算错误，不是 1 ULP |
| YOLO 读回 700KB（256B 分块） | ~66s | 慢在 C2H 拆包，不是 execute |

峰值 golden 首字 `0x00001778` 在 preload 和（加载后读 tile_obuf 的）hbm 路径都能对上。

### 不要当成根因

- **不要**再改 DCIM / `OP_DCIM_LAYER` / 地址图 / DQA-QA golden。preload 2048/2048 和 golden 对齐已经证明计算语义对。
- **不要**把 `CDMA_COOLDOWN_CYCLES` 当主修复。
- **不要**把 YOLO `corr≈0.2` 解释成「和旧 bit 一样所以 HBM 加载没修好」。加载单测已经 2048/2048；e2e 是 **几十～上百次不同长度的 CDMA**（HBM 取权重、tile↔VPU_BUF、中间写回），压力和峰值 8 次加载不是一条路径。
- Host 写读 256KB HBM 全对 → **不是 HBM PHY 坏、也不是 XDMA 写 HBM 坏**。
- SmartConnect 2024.2 **没有**可写的 per-port outstanding 上限；`NUM_*_OUTSTANDING` 写在 register slice XCI 上也不会变成事务限流器。本轮没做 limiter 是已知缺口，不是「已经限流了但还是坏」。

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

1. **峰值官方 drain**：`--staging hbm --repeat-count 1`，host `drain_output=True` 且 `read_check(from_hbm=True)` → **2048/2048**。现在加载-only 的 2048/2048 **不算**这项过关。
2. **YOLO INT8** 一张图 compare 退出码 0（`atol=1e-3`）。ResNet INT8 同样。
3. **C2H**：临时 `C2H_CHUNK_BYTES=4096` 时 TILE_OBUF 与 HBM 单笔 4KB 成功（或文档明确仍建议 256B 分块，但 e2e 数值已过）。

功耗窗口：加载路径已可 `--staging hbm --repeat-count N`（结果仍读 tile_obuf）。不要为功耗改数据通路。

---

## 2. 问题拆开（下一步只修这些）

### 问题 P1 — CDMA 以 HBM 为**目的地**时，第 2 笔及以后静默损坏（主问题）

最小复现：峰值 hbm，`drain_output=True`。Decoder DONE、CDMA SR IDLE=1，HBM 里只有 tile0 的 256 字正确。

加载（HBM 为**源**、tile BRAM 为目的）8 笔已对。Drain（tile BRAM 为源、HBM 为目的）8 笔只留第一笔。方向不对称，要对准 **HBM 写通道**：`axi_hbm_smc` 写仲裁、`hbm_axi_regslice` W/B、`hbm_axi_cc` 写 FIFO、HBM SAXI 写。

E2E 的 `program.bin` 里有大量 `cdma_copy`（YOLO INT8 约 986 次），其中包含 HBM→IBUF 取权重和片上缓冲搬运。P1 未修时，全网必然错；即便部分读 HBM 是对的，中间写 HBM / 后续再读也会被污染。

### 问题 P2 — 全网 CDMA 尺寸/交织与峰值加载不同

YOLO 按 tile 切通道后 **没有**「ch[0:16] 对、后面全错」。这更像从第一层附近开始权重或激活就错，而不是单纯 drain 的 tile0-only 图案。可能仍是 P1（某次写 HBM 之后的读全错），也可能还有 **VPU_BUF↔tile** 多笔 CDMA 的同类损坏。修好 P1 后必须立刻重跑 YOLO；若 drain 2048/2048 而 YOLO 仍 `corr≈0.2`，再单独打一条「只有片上 BRAM、不碰 HBM」的多层用例。

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
| `tests/chip/unit-tb/hbm_flow.py` | 插入加载/drain CDMA |
| `tests/chip/unit-tb/xdma_win.py` | C2H 256B 分块；hbm staging **仍关 drain**（P1 未修） |
| `TEST/tops/fpga/run_peak_int8.py` | 默认 `--staging preload`；`--staging hbm` 测加载（读 tile_obuf） |
| `tests/chip/runtime/hw_runner_win.py` | E2E；权重 H2C→HBM，结果从 VPU_BUF C2H |

复现命令：

```powershell
# P1 最小复现：应 256/2048。若某次 bit 变成 2048/2048，再把 drain 设回 True 作为默认验收。
python TEST/tops/fpga/run_peak_int8.py --staging hbm --repeat-count 1 --quiet-xdma

# 加载-only（当前 host 默认）：应 2048/2048，回归用，不能代替 drain。
# ChipRunnerWin.run_case 里 drain_output=False。

python run.py --network yolo --yolo-precision int8 --one-shot-yolo-expect-detections -1
python run.py --network resnet --resnet-precision vai
```

临时打开 drain 验收（改 `xdma_win.py`）：

```python
n_words = self.upload_inst(run_dir, drain_output=True, ...)
results = self.read_check(run_dir, from_hbm=True)
```

---

## 4. RTL / BD 修改计划（P1 优先）

原则：先让 **HBM 写通道** 连续多笔 CDMA 正确，再谈 e2e 和 4KB C2H。每步单独出 bit、单独上板。C2H Busy 后先 PCIe 复位，不要继续打。

### Step G — 最小 drain 复现保持可开关（host，已有）

不要删 `drain_output=False` 这条安全路径，直到 drain 2048/2048。新 bit 验收顺序：preload → hbm 加载读 tile_obuf → **hbm drain 读 HBM** → YOLO。

### Step H — HBM 写通道 outstanding / 写交织（P1 主修）

本轮 A+B 已经：独立 `axi_hbm_smc`、regslice FULL、burst 16、ID=6。仍 256/2048，说明 **拆口+burst cap 不够**。下一步必须真正限制写 outstanding，而不是再写无效的 SMC 属性。

建议（用实验决定保留哪条，不要一次全上）：

1. **专用 AXI outstanding limiter**（推荐）：插在 `hbm_axi_regslice` 与 `hbm_axi_cc` 之间（或 CDMA→hbm_smc 的那条 SI 上），硬件保证 AW/W 在途 ≤1。这是 2024.2 SmartConnect 做不到的。
2. CDMA→HBM 路径 **关 DRE**（`C_INCLUDE_DRE=0`），只允许对齐传输；峰值 drain 长度已 4KB 对齐。
3. `hbm_axi_regslice` 的 W/B 已是 FULL；可再在 **450MHz 侧**（CC M → HBM）加一级 FULL slice，隔离 CC 写 FIFO 与 HBM。
4. 确认 `axi_hbm_smc` 两个 SI 上 CDMA 写与 XDMA 写不会在 drain 窗口交织（峰值 drain 期间 host 不应打 H2C）。若 host 后台仍有访问，先停干净。

验收：drain 2048/2048。若仍 256/2048：用 ILA 打 CDMA AW/W/B 与 `hbm_axi_cc` S 侧，看第 2 笔 AW 是否发出、B 是否回来、W 数据是否还是 tile0 的重复。

### Step I — CDMA 完成语义（仅作 H 的补强）

`CDMA_Controller.sv`：目的地址 bit32=0（HBM）时，SR IDLE 之后对 **该笔最后一个 HBM 地址** 发 AXI 读 fence，读回后再 `cdma_config_ready`。不要只加 cooldown 数字。INST_BRAM 128KB，禁止在指令流里塞几万 NOP。

### Step J — Drain 过关后再打 e2e

YOLO/ResNet 不要在 drain 仍 256/2048 时当主指标。Drain 过关后：

```powershell
python run.py --network yolo --yolo-precision int8 --vcs skip --verilator skip
python run.py --network resnet --resnet-precision vai
```

期望 `max_abs` 回到 1e-3。若 drain 过、e2e 仍 `corr<0.9`：做一条不碰 HBM 的多层片上-only 用例，区分 P2（VPU_BUF CDMA）与残留 HBM 读问题。

### Step D — 长 C2H（P3，可与 H 并行出另一份 bit，不要混进 P1 实验）

对 tile/vpu 的 128-bit MI：`MAX_BURST_LENGTH` ≤8 或 16，或 XDMA 后限制 burst 到 PCIe MPS。验收：`C2H_CHUNK_BYTES=4096` 时 OBUF 与 HBM 单笔 4KB 成功。本 bit 上先从 2048（已通）试 4096，失败就复位，不要循环重试。

### 不要动

- `OP_DCIM_LAYER`、tile streamed 数据通路、repeat/`CTRL[2]`
- `address.tcl` 段基址（HBM 仍 `0x0` 4GB）
- VPU DQA/QA；ILA probe 集合（除非时序不收敛）

---

## 5. Host 现状（不要无故回滚）

1. `xdma_win.py`：`C2H_CHUNK_BYTES=256`；`staging=hbm` 时 `drain_output=False`，结果读 tile_obuf。
2. `run_peak_int8.py`：默认 `--staging preload`；hbm 打印说明 drain 仍 tile0-only。
3. `compare_one_shot.py`：QA `×float32(1/act_scale)`，与 FPGA 一致。e2e corr 低不是 golden 造成的。
4. **不要提交** `TEST/end2end/` 残留、bit/ltx 大文件。

---

## 6. 给修改者的约束

- 用中文写每个 BD 改动对应 P1/P2/P3 哪条实验。
- 新 bit 必须带配对 `.ltx`；以能枚举为准。
- 不要把默认峰值改成「hbm+drain」直到 drain 2048/2048。
- 改完更新本文件顶部勾选，并在 `TEST/tops/fpga/README.md` 写清当前默认 staging。

---

## 7. 最小成功标准（停手用）

**完成**：hbm **drain** 2048/2048；YOLO INT8 一张图 compare 退出码 0；ResNet INT8 一张图同样。4KB C2H 过或文档明确继续 256B 分块。

**未完成**：只有加载-only 2048/2048；drain 仍 256/2048；YOLO `corr<0.9`；只加了 cooldown。
