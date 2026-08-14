# HBM / CDMA 互连修复交接：情况说明 + RTL 修改计划

给后续 agent 的完整上下文。目标：**新 bitstream 上恢复官方 HBM staging 的峰值 8-tile 正确性，并让 YOLO/ResNet end-to-end 特征比对稳定通过**。不要把 host 上的规避当成架构变更。

## 2026-08-14 实施状态（bitstream 已生成，尚待板测）

已基于 `test/tops/ila` 的最新远程提交 `a6a29fa` 完成 Step A/B/C 的低风险版本：

- `axi_misc_smc` 已恢复为 4MI；HBM 从 misc 外设互连拆出，新增独立 `axi_hbm_smc`（XDMA/CDMA 两个 SI、一个 HBM MI）。
- HBM 前加入 full AXI register slice；CDMA 与 HBM 下游传播的最大 burst 均为 16 beat。
- `hbm_axi_cc` 的 ID width 从 4 修正为与 HBM 一致的 6，生成 BD 不再有 4↔6 bit ID 截断告警。
- PCIe/CPU 的组合复位请求分别在 250 MHz 和 450 MHz 域同步释放，clock converter 两侧及 HBM AXI 端共享同一个逻辑复位事件。
- XDMA 与 CDMA 的 HBM 地址仍是 `0x0`、范围仍是 4GB；host 地址图和命令格式不变。

验证状态：Vivado 2024.2 `validate_bd_design`、wrapper 生成及 6 个受影响 IP 的 OOC 综合均通过；VCS `END2END_MULTIBLOCK_PASS pixels=70 acc_depth=3`。HBM stub 不能复现板级 CC/PHY 故障，因此这些结果只表示修改可综合且没有改变 DCIM 计算语义，**不能勾选板级验收**。

完整 implementation `tops_ila_hbmfix_260813` 已结束。winner 为
`route7_place0_ExtraTimingOpt_ExploreWithHoldFix_Explore`，post-route
`WNS=+0.029 ns`、`WHS=+0.001 ns`、TNS/THS 均为 0，setup/hold 失败端点均为
0。该结果时序合法但属于 low-margin；构建日志未发现 `ERROR` 或
`CRITICAL WARNING`。发布文件及其 SHA-256：

```text
top.bit  cc0c28f9ee064c79528128dd462a59e8529d787a050090d91fb9ef5d95da9d2a
top.bin  7284d77df678b3e8ca2d8b85e33a1a5d4b8efe86e0db1f06e52823c3bf0739ee
top.ltx  b1feb90460ab4b581bb70a4736f2210c888efe9ba0f7a7cf17037af37b4f127d
```

绝对路径和输入 blob 绑定见 `tops_ila_hbmfix_260813_release.md`。上述结果只完成
实现验收；XDMA 枚举、HBM staging 2048/2048、YOLO/ResNet end-to-end 和 4KB
C2H 仍必须板测。

SmartConnect 2024.2 没有可写的 per-port outstanding 上限。虽然 register slice XCI 可记录 `NUM_*_OUTSTANDING=1`，连接后的接口能力仍传播为 32/16，而且 register slice 不是事务限流器，故未用该属性冒充修复。当前先以 HBM 独立、16-beat、full slice、统一复位和 ID 对齐生成 bitstream；若 `--staging hbm` 仍非 2048/2048，再实现并验证专用 AXI outstanding limiter。Step D（tile/vpu 4KB C2H 根治）本轮未做，host 仍应保持 256B C2H 分块。

---

## 0. 仓库与板卡身份

| 项 | 值 |
|---|---|
| Repo | `E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA` |
| Branch | `test/tops/ila`，本轮输入为 `a6a29fa` 加本次提交的 HBM Tcl 修改 |
| 设备 | VCU128 `xcvu37p-fsvh2892-2L-e`，Windows XDMA |
| 当前可枚举 bit | 工作区 `TEST/utils/bitstream/top.bit`（能进系统）。**不要**用会 Code 10 的 `tops_ila_cegate_260812.bit`（sha256 `8466f519…`，与 release md 中的 `top.bit` 同哈希但本机起不来） |
| Release 文档 | `TEST/tops/fpga/tops_ila_hbmfix_260813_release.md` |
| Host 驱动工具 | `tests/bin/xdma_rw.exe`, `tests/bin/xdma_info.exe` |
| Python | `D:\SoftwareTools\miniconda\miniconda\python.exe` |
| 功耗脚本 | `TEST/tops/fpga/vcu128_sc_power.py`（UART 读 INA226，与本问题正交） |

`main` 在 `f4ed27b`，含 golden DQA/QA 修复，**没有**本分支的 streamed DCIM / ILA / HBM 时序加固。不要把 `TEST/end2end/` 工作区残留合进本分支。

---

## 1. 目标（验收口径）

1. **End-to-end**：`python run.py --network yolo --yolo-precision int8 --vcs skip --verilator skip` 一张图（默认 `examples/coco/000000000139.jpg`）特征比对通过（INT8 `atol=1e-3`）。ResNet INT8 同样门限。不必先跑 80 张。
2. **峰值 TOPS**：官方路径 `python TEST/tops/fpga/run_peak_int8.py --staging hbm --repeat-count 1` → **2048/2048** 字通过（Host→HBM→CDMA→8×IBUF，再比对结果）。
3. **功耗窗口**：同一峰值 ISA，`--repeat-count N` 在片上无气泡循环（`OP_DCIM_LAYER` word7 + `CTRL[2]`）。`N=10000000` @250 MHz ≈ 5.12 s。功耗用 `vcu128_sc_power.py`，不要为功耗改数据通路。

当前 **DCIM 计算本身是对的**。坏的是 **HBM 相关 CDMA** 和 **XDMA C2H 长突发**。不要改 DCIM 阵列、im2col、DQA/QA 数值语义来“凑” e2e。

---

## 2. 已证实 vs 推断

### 已用板级实验钉死

| 实验 | 结果 | 结论 |
|---|---|---|
| 16B C2H：REGS / TILE_OBUF / VPU_BUF / HBM | 通 | 枚举和短读正常 |
| TILE_OBUF C2H 256B | 通 | |
| TILE_OBUF 或 HBM **单笔 C2H 4096B** | `xdma_rw` 30s 超时，C2H 常留 `Busy` | **C2H length≥4KB 会挂，与是否 HBM 无关** |
| Host 把 C2H 拆成 256B | 4KB/32KB/数百 KB 都能读完 | 规避有效，不是根治 |
| H2C 4KB～32KB（HBM 和 IBUF） | 通 | **写长突发基本正常** |
| 峰值 `staging=preload`（H2C 直写 8×IBUF，读 tile_obuf） | **2048/2048 PASS**，Decoder DONE | **8 tile DCIM INT8 数值正确** |
| 峰值官方 `staging=hbm`（H2C→HBM，CDMA 搬 8 tile） | Decoder DONE，**256/2048**（恰好 1 tile） | 只有第一次 HBM CDMA 的数据可信 |
| 同上但关掉 tile_obuf→HBM drain，改读 tile_obuf | 仍 **256/2048** | 坏在 **HBM→IBUF 加载 CDMA**，不是 drain、不是 C2H 比对 |
| YOLO INT8 全网 | 57 层编译，execute 1.1s DONE，PAN 读回非零 ReLU 形态 | 通路能跑完 |
| YOLO vs numpy golden | `max_abs` 12–22，`corr≈0.17–0.23` | **不是 1 ULP golden**，是错权重/错搬运后的计算 |

峰值 golden 首字 `0x00001778` 在 preload 路径的 tile_obuf 上能对上。

### 不要当成根因的东西

- **不要**把 `CDMA_COOLDOWN_CYCLES=2000`（8 µs）当成主修复。每次 `WAIT_CDMA` 已经包含这段 cooldown，8 次 CDMA 仍然只有 tile0 对。这是 **静默数据损坏**（CDMA SR IDLE=1，Decoder DONE），不是“再等多几微秒”。
- **不要**改 DCIM streamed 数据通路 / `OP_DCIM_LAYER` ISA 来修 e2e。峰值 preload 已证明计算正确。
- **不要**改地址图（`VPU_BUF=0x1_0200_0000` 等）。Host 与 `hw_caps.yaml` / `address.tcl` 一致。
- `int32_2_fp16_array.sv` 工作区 diff 是 **CRLF**，不要提交。

### 推断（RTL 改动应对准这些，但要用实验证实）

1. `axi_misc_smc`（2SI XDMA+CDMA，5MI 含 HBM）+ `hbm_axi_cc`（250↔450，256-bit）对 **第 2 笔及以后的 CDMA** 写坏或读坏。
2. 256-bit CDMA/XDMA 经 SmartConnect **降到 128-bit BRAM**，长 INCR（4KB=128 beat@256b 或更多 beat@128b）导致 C2H 挂死；PCIe 协商 **MPS=128**，User PRG MPS=4096，不匹配。
3. `hbm_axi_cc` **S/M 复位域分裂**：S=`xdma axi_aresetn`，M=`hbm_rst`（`cpu_reset`+450 MHz locked）。PCIe reset 只清 S 侧，异步 FIFO 半包 → 复位后 4KB C2H 仍挂。

---

## 3. 数据通路（改 BD 前必须看懂）

```
XDMA M_AXI 256b @250MHz
  → axi_xdma_smc (1SI, 2MI)
      M00 → axi_tile_smc S00 → 8×tile_ibuf_ctrl (128b) + 8×tile_obuf_ctrl (128b)
      M01 → axi_misc_smc S00 → vpu_buf, wb, inst, regs, HBM

AXI CDMA M_AXI 256b @250MHz  (C_INCLUDE_DRE=1, Simple DMA, 64-bit addr)
  → axi_cdma_smc (1SI, 2MI)
      M00 → axi_tile_smc S01
      M01 → axi_misc_smc S01

axi_misc_smc M04 → hbm_axi_cc (250MHz S / 450MHz M, 256b, ADDR=33, ID=4)
              → hbm_0/SAXI_00 (4GB interleaved, 1 stack)
```

地址（`scripts/ip/bd/lite/address.tcl`，与 host `tests/chip/unit-tb/xdma_win.py` 一致）：

- HBM `0x0` 4GB
- TILE_IBUF `0x1_0000_0000` 每 tile 512KB
- TILE_OBUF `0x1_0100_0000` 每 tile 256KB
- VPU_BUF `0x1_0200_0000` 8MB
- WB `0x1_0300_0000` 32KB
- INST `0x1_0400_0000`
- REGS `0x1_0500_0000`（`INST_COUNT=0x3C`, `DECODER_CTRL=0x38`, `DECODER_STATUS=0x40`）

峰值官方 host（`hbm_flow.py`）：

1. H2C：`act.hex` 重复写到 HBM `+0x0`（8 tile **共享同一份激活**，这是故意的）
2. H2C：`weight_tile{0..7}.hex` 到 HBM `+0x80000 + t*0x400`
3. 指令前插入 8×(HBM→各 IBUF act) + 8×(HBM→各 IBUF weight) 的 `OP_CDMA_COPY`+`WAIT_CDMA`
4. `OP_DCIM_LAYER`（64 job，INT8，repeat 在 body word 7）
5. （旧路径）8× tile_obuf→HBM drain；现已在 `ChipRunnerWin.run_case` 关掉 drain，改 scatter 读 tile_obuf

E2E（`tests/chip/runtime/hw_runner_win.py`）：

- 权重一次 H2C 到 HBM `0x200000`（`weights.bin` ≈1.76MB）
- 输入/WB scratch H2C 到 VPU_BUF
- `program.bin` 里约 **986 次 `cdma_copy`**（大量 HBM↔IBUF 以及片上 VPU_BUF↔IBUF/OBUF）
- 结果从 VPU_BUF 直接 C2H（本来就没有 HBM drain）

ISA：`OP_DCIM_LAYER=0x9`，body = 8 + 2×NUM_TILES 字，word7=`benchmark_repeat_count`（0 当 1）。Decoder：`rtl/vpu/INST_Decoder.sv`。Compiler 已发射该指令（`tests/chip/compiler/codegen/encode_isa.py`）。**不要改 ISA。**

---

## 4. 关键源文件

| 文件 | 作用 |
|---|---|
| `scripts/ip/bd/lite/connect.tcl` | SMC 拓扑、HBM CC 复位连接（约 L44–85, L307–337） |
| `scripts/ip/bd/lite/hbm.tcl` | HBM IP、clk_wiz 100/450、`hbm_axi_cc`、BRAM ctrl 128b |
| `scripts/ip/bd/lite/cdma.tcl` | AXI CDMA 256b + DRE |
| `scripts/ip/bd/lite/address.tcl` | 地址段 |
| `scripts/ip/bd/xdma.tcl` | XDMA 256b MM，BAR0→`0x1_0000_0000`（C2H/H2C 描述符仍用全 AXI 地址） |
| `rtl/vpu/CDMA_Controller.sv` | 轮询 SR IDLE 后 `CDMA_COOLDOWN` |
| `rtl/chip/chip_defines.vh` | `CDMA_COOLDOWN_CYCLES 2000` |
| `tests/chip/unit-tb/hbm_flow.py` | Host 插入 HBM CDMA；注释已警告多 tile drain 会坏 |
| `tests/chip/unit-tb/xdma_win.py` | Windows runner；**已改** C2H 256B 分块；HBM staging 不再 drain |
| `TEST/tops/fpga/run_peak_int8.py` | **已改** 默认 `--staging preload`，`--staging hbm` 仍可测旧路径 |
| `tests/chip/runtime/compare_one_shot.py` | **已改** golden DQA/QA 与 FPGA 对齐（从 main `57aff19` 移植） |
| `tests/chip/runtime/hw_runner_win.py` | E2E 上板；不要改地址 |
| `rtl/tb/lite_bd/module_tb/golden_module_tb.py` | 峰值向量 `peak_int8_all_tiles` |

---

## 5. 工作区里已有的 host 改动（不要无故回滚）

未提交（相对 `d443e6b`）：

1. **`xdma_win.py`**
   - `C2H_CHUNK_BYTES = 256`，`read()` 自动分块。新 bit 若单笔 4KB C2H 已通，可把 chunk 提到 4096/65536，但先留 256 作安全网。
   - `run_case(staging="hbm")`：`drain_output=False`，`read_check(from_hbm=False)`。HBM **加载**仍走 CDMA；结果读 tile_obuf。
2. **`run_peak_int8.py`**
   - `--staging {hbm,preload}`，默认 `preload`（这块 bit 上 hbm 只有 tile0）。
   - timeout = `max(timeout_s, 128*repeat/f_clk + 30)`。
3. **`compare_one_shot.py`**
   - QA 一律 `×float32(1/act_scale)`；DQA INT16 先 `int64→fp32` 再 float64 affine。与 FPGA 一致，**e2e corr 低不是它造成的**。
4. **不要提交** `rtl/vpu/fp_array/int32_2_fp16_array.sv`（换行符）。
5. **不要提交** 未跟踪的 `TEST/end2end/`（main 残留）。

峰值/功耗在修 BD 之前可用：

```powershell
python TEST/tops/fpga/run_peak_int8.py --staging preload --repeat-count 10000000 --quiet-xdma
python TEST/tops/fpga/vcu128_sc_power.py   # 另开终端，在计算窗口内采数
```

---

## 6. RTL / BD 修改计划（按顺序做，每步可单独上板）

原则：先互连约束，再复位耦合，最后才动 cooldown。**不要**为了 e2e 改 DCIM。

### Step A — 把 HBM 从 `axi_misc_smc` 拆出去（最重要）

现状：HBM 与 vpu_buf/wb/inst/regs 挤在 `axi_misc_smc` 的 M04，2 个 SI（XDMA+CDMA）仲裁。

建议拓扑：

```
axi_cdma_smc / axi_xdma_smc 增加一档 MI
  → axi_hbm_smc (建议 2SI 或各 1SI 再汇合, 1MI)
      → axi_register_slice (FULL)
      → hbm_axi_cc
      → axi_register_slice (FULL, 450MHz 侧可选)
      → hbm_0/SAXI_00
```

`axi_misc_smc` 改回 4MI：只留 vpu_buf、wb、inst、regs。

对 **HBM 那条 master** 强制：

```tcl
CONFIG.NUM_READ_OUTSTANDING  {1}
CONFIG.NUM_WRITE_OUTSTANDING {1}
CONFIG.MAX_BURST_LENGTH      {16}   ;# 256-bit → 512 B
```

SmartConnect 属性名以 Vivado 2024.2 实际为准（有的版本在 `S00_ENTRY` / `M00_ENTRY` 上设）。做完 `validate_bd_design`。

目的：消灭 HBM 口上的 outstanding 与和轻量外设的交织，这是 tile1–7 静默写坏的最大嫌疑。

### Step B — 对齐 AXI CDMA 突发

`scripts/ip/bd/lite/cdma.tcl` 增加与 HBM/BRAM 降宽匹配的突发上限，例如：

```tcl
CONFIG.C_M_AXI_MAX_BURST_LEN {16}
```

`C_INCLUDE_DRE {1}` 先保留。若 Step A+B 后峰值 HBM 仍只有 tile0，再对 HBM 通路关 DRE（只允许 32B 对齐传输；峰值 act/weight 已是 4KB/1KB 对齐）。

### Step C — `hbm_axi_cc` 复位域（修 PCIe reset 后长 C2H 仍挂）

现状（`connect.tcl` ≈ L330–333）：

- `hbm_axi_cc/s_axi_aresetn` ← `xdma_0/axi_aresetn`
- `hbm_axi_cc/m_axi_aresetn` ← `hbm_rst/peripheral_aresetn`
- `hbm_0/AXI_00_ARESET_N` ← `hbm_rst/peripheral_aresetn`

PG065：两侧 aresetn 必须在各自时钟上至少 16 拍，且逻辑上应同时有效。PCIe hot reset 只拉 XDMA 侧。

改法：

1. 组合复位源：`cpu_reset` **或** `~xdma_0/axi_aresetn`（注意极性）。
2. 两个 `proc_sys_reset`：一个 `slowest_sync_clk=axi_aclk`（250），一个 `=hbm_axi_clk`（450），`ext_reset_in` 接组合源，`dcm_locked` 接对应 `clk_wiz/locked`。
3. 250 域 `peripheral_aresetn` → CC `s_axi_aresetn`。
4. 450 域 `peripheral_aresetn` → CC `m_axi_aresetn` **和** `hbm_0/AXI_00_ARESET_N`。
5. 保持 APB 100 MHz 复位链独立，但 `cpu_reset` 仍要进 APB reset。

不要把未同步的 `xdma axi_aresetn` 直接接到 450 MHz 口。

### Step D — 限制通向 128-bit BRAM 的 AXI burst（修 C2H ≥4KB 挂死）

XDMA/CDMA 256-bit → `axi_tile_smc` / BRAM 128-bit。单笔 4KB C2H 在 TILE_OBUF 上也会挂，256B 不会。

对 **tile_ibuf / tile_obuf / vpu_buf** 的 SMC MI（或 XDMA 下游 slice）：

- `MAX_BURST_LENGTH` ≤ 8 或 16（128-bit 下 128–256B）
- 或在 XDMA `M_AXI` 后加 data-width converter / register slice，把主机侧 max burst 限制在 PCIe MPS（128B）的若干倍以内

验收：host **关掉** 256B 分块（临时 `C2H_CHUNK_BYTES=4096`）时，TILE_OBUF 4KB 和 HBM 4KB C2H 都要成功。通过后再考虑 64KB。

### Step E — Cooldown 只作保险，不当主修复

`rtl/vpu/CDMA_Controller.sv` / `chip_defines.vh`：

- 可把 `CDMA_COOLDOWN_CYCLES` 提到 8000–16000 作回归余量，**不能**指望单靠它修 tile1–7。
- 可选：源或目的在 HBM（addr `[32]==0`）时，IDLE 之后对 **最后一个 HBM 地址** 发 AXI 读 fence，完成后再 `cdma_config_ready`。这比空转 nop 更能冲掉 CC FIFO。

INST_BRAM 只有 128KB，**禁止** 在 host 指令流里插几万条 NOP 当 delay。

### Step F — 不要动的 RTL

- `OP_DCIM_LAYER` 编码、`DCIM_REG_*`、streamed tile、repeat/`CTRL[2]`
- `address.tcl` 段基址（除非 Step A 新增 IP 必须 map，HBM 仍必须在 `0x0` 4GB）
- VPU DQA/QA 数值；golden 已按 FPGA 对齐
- ILA probe 集合（除非时序不够）

---

## 7. 建议实现顺序与每步板上实验

每步出 bit 后用 **能枚举的那份** 上板。C2H 一旦 Busy，需要 PCIe/设备复位，不要继续发 DMA。

1. **只做 Step A+B**（HBM 独立 + outstanding=1 + CDMA burst cap）
   - `python TEST/tops/fpga/run_peak_int8.py --staging hbm --repeat-count 1 --quiet-xdma`
   - **必须 2048/2048**。若仍 256/2048：查 SMC 属性是否真写上、加 HBM 侧 register slice、试关 DRE。
2. **Step C**（CC 复位）后：PCIe 复位一次，再测 HBM 4KB C2H（可先保持 host 256B 分块测功能）。
3. **Step D** 后：把 `C2H_CHUNK_BYTES` 临时改 4096，TILE_OBUF 与 HBM 单笔 4KB 都应成功。
4. **E2E**：`python run.py --network yolo --yolo-precision int8 --vcs skip --verilator skip`  
   期望 PAN `max_abs` 回到 1e-3 量级，而不是 10+。通过后再 ResNet INT8 一张图。
5. **功耗**：`--staging hbm --repeat-count 10000000`（此时 hbm 路径应已正确）。`vcu128_sc_power.py` 并行采数。

仿真：`TEST/tops/simulation/` 的 HBM 是 stub，**不能**复现 PHY/CC 损坏。BD `validate_bd_design` + 板上峰值 HBM 才是闸门。有完整 HBM 仿真再加 e2e 多笔 CDMA testbench。

---

## 8. 给修改者的约束

- 用中文说明每个 BD 改动的**原因**（对应上面哪条实验）。
- 不要把默认峰值改回 `hbm` 直到 2048/2048 在新 bit 上通过；在那之前保留 `--staging preload`。
- 不要扩大范围：OOC 时序、ILA probe 精简、URAM CE-gating 与本次无关，除非新 SMC 导致时序不收敛。
- 新 bit 必须带配对 `.ltx`；本机以**能枚举**为准。
- 改完后更新本文件顶部“验收”勾选，并在 `TEST/tops/fpga/README.md` 用两三句写清：HBM 已独立、峰值应用 `--staging hbm`。

---

## 9. 最小成功标准（给 agent 停手用）

**完成**：峰值 `--staging hbm --repeat-count 1` → 2048/2048；YOLO INT8 一张图 compare 退出码 0（`atol=1e-3`）；单笔 ≥4KB C2H 不再需要 256B 才能活（或文档明确仍建议分块但 e2e 数值已过）。

**未完成**：只有 preload 峰值过、hbm 仍 256/2048；或 YOLO `corr<0.9`；或只加了 cooldown 数字。
