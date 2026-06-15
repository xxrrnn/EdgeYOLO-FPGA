# tests/chip/ - End-to-End FPGA Board Test Suite

EdgeYOLO-FPGA-lite 板上端到端测试，支持 ResNet18 和 YOLOv5n。

## 目录结构

```
tests/chip/
├── compiler/               # 编译器 (ONNX parsed → ISA binary)
│   ├── compile.py          # 主入口
│   ├── ir_schema.py        # IR 模式定义
│   ├── lowering/           # 网络降低 (graph → primitive ops)
│   │   ├── lower.py        # Conv-only lowering
│   │   ├── lower_full.py   # 全网络 lowering (Add/Concat/US/MP/Tiling)
│   │   ├── yolov5n_schedule.py  # YOLOv5n 静态调度表
│   │   ├── memory_plan.py  # OBUF/IBUF 内存规划
│   │   ├── hw_caps.yaml    # 硬件能力描述
│   │   └── op_rules.py     # 算子合法性检查
│   ├── codegen/            # ISA 编码
│   │   └── encode_isa.py   # OP → 32-bit words
│   └── packer/             # 权重/WB 打包
├── runtime/                # 板上运行时
│   ├── xdma_driver.py      # XDMA 驱动封装 (Linux)
│   └── hw_runner.py        # 高层运行器
├── golden/                 # Golden 参考脚本
├── unit-tb/                # Windows 片上单元测试
│   ├── xdma_win.py         # XDMA 驱动 + HBM 流程 runner
│   ├── hbm_flow.py         # inst 补丁: HBM↔片内 CDMA
│   ├── gen_data.py         # 调用 module_tb golden 生成测试数据
│   └── run_unit_test.ipynb # 主 Notebook
├── step0_single_layer/     # Phase 0: 单层验证
├── step1_resnet18_w8a8/    # Phase 1: ResNet18 W8A8 全网
├── step2_yolov5n_w8a8/     # Phase 2: YOLOv5n W8A8 全网
└── step3_w16a16/           # Phase 3: W16A16 双网络
```

## 快速开始

### 0. Windows 片上单元测试（推荐首次使用）

复用 `golden_module_tb.py` 生成向量；**Host 仅通过 XDMA 读写 HBM 与 INST_BRAM**（默认 `staging=hbm`）。
片内数据经 inst 中的 CDMA 在 HBM ↔ tile_ibuf/VPU_BUF/WB ↔ tile_obuf/VPU_BUF 间搬运。

```
Host ──XDMA──> HBM (hbm_image.hex + wb @ 0xC0000 + output @ 0x100000)
Host ──XDMA──> INST_BRAM (inst + HBM CDMA 补丁)
                    │
                    ├─ CDMA: HBM → tile_ibuf / VPU_BUF / WB
                    ├─ DCIM / VPU 计算
                    └─ CDMA: tile_obuf / VPU_BUF → HBM
Host <──XDMA── HBM (结果读回, 与 expected.hex 逐 word 比对)
```

Lab 回退：`staging="preload"` 直写片内 + scatter 读 obuf。

**前提**: FPGA 已烧录 bitstream；`tests/xdma_exe/xdma_info.exe` 可见设备；conda 环境 `chip_test_env`。

```bash
cd tests/chip/unit-tb
jupyter notebook run_unit_test.ipynb
```

或使用 Python 脚本:

```python
from xdma_win import ChipRunnerWin
from gen_data import generate_case

# 生成最小 DCIM 测试数据 + 片上执行 + golden 比对
run_dir = generate_case("dcim_matmul", "dcim_tiny_1x1")
runner = ChipRunnerWin()
results = runner.run_case(run_dir)  # staging="hbm" by default
```

**可用测试 case** (与 module_tb 仿真完全一致):

| 模块 | 典型 variant | 验证内容 |
|------|-------------|----------|
| `dcim_matmul` | dcim_tiny_1x1, conv3_s2_c32_to64 | DCIM 矩阵乘 |
| `qa` | qa_c16_signed, qa_c64_clip | FP32→INT8 量化 |
| `dqa` | dqa_c16_small, dqa_c32_mid | INT32→FP32 反量化 |
| `im2col` | im2col_6x6_s2_c3, im2col_3x3_s1_c128 | im2col 变换 |
| `mp` | mp_sppf_128_10, mp_resnet_stem | MaxPool |
| `us` | us_128_10_to20 | Upsample 2x |
| `add` | add_residual_16, add_pan_64 | Residual Add |
| `conv_pipeline` | pipe_conv3_s2_c32_to64 | 单层 conv 全链路 |
| `mini_network` | mini_2conv_c16, mini_3conv_residual_c32 | 多层网络 |

---

## RTL 问题汇总与修复记录

### 问题 1：URAM 数据 Pipeline 与 Valid 不同步（im2col 数据错误 + AXI Hang）

| 属性 | 内容 |
|------|------|
| **文件** | `rtl/common/uram_tdp_bytewrite.v` |
| **影响** | `vpu_buf`, `tile_ibuf`, `tile_obuf`（所有使用该模块的 buffer） |
| **症状** | im2col 输出 bit-flip（1-2 bit 翻转），im2col 执行后 VPU_BUF AXI 端口间歇性锁死 |
| **严重程度** | Critical —— im2col 100% 不通过 |

**动机**：im2col 单元测试始终 FAIL（234/256 words pass），且有约 50% 概率在执行后导致整个 FPGA AXI 总线锁死（需要硬件重置）。

**根因分析**：

`uram_tdp_bytewrite.v` 中数据输出 pipeline 的使能 shift register `men_pipe_a` 使用 `mem_ena`（读写均推入 1）作为推进条件。但在 No-Change 模式下，写操作时 `memrega` **不更新**。当 im2col 在同一 URAM 端口快速交替执行 WRITE → READ 时：

1. WRITE 操作在 `men_pipe_a` 中推入一个 1
2. 这个"脏 1"让 `dat_pipe_a` 在后续级传播旧的 `memrega` 值
3. 真正 READ 的新数据与"脏数据"在 pipeline 中混合
4. 最终 `douta` 在 `douta_valid` assert 时输出了部分旧数据

而外部的 `douta_valid`（在 `vpu_buf.v`/`tile_ibuf.v`/`tile_obuf.v` 中）使用 `mem_ena & ~|wea`（仅读时推 1），二者不同步。

**验证证据**：
- im2col 错误位置在多次运行中**完全确定性**（同样的 word/byte 位置）
- 错误是 1-2 bit 翻转（bit5/bit7 最多），不是整字错误
- 错误集中在 oh=3~5（pipeline 累积效应在中后期放大）
- `qa`/`dqa`（仅连续读或连续写 VPU_BUF）通过，`im2col`（频繁交替读写）失败
- 源/目标 URAM word 地址无重叠（排除 RAW hazard）

**修复**：

```verilog
// 修改前（line 68）：
men_pipe_a <= {men_pipe_a[NBPIPE-1:0], mem_ena};

// 修改后：
wire rd_en_a = mem_ena & ~(|wea);
men_pipe_a <= {men_pipe_a[NBPIPE-1:0], rd_en_a};
```

Port B 同理。修改后 `men_pipe_a` 与 `douta_valid` 的推入条件完全一致，写操作不再污染数据 pipeline。

**URAM 推断安全性**：Vivado URAM 推断基于 `(* ram_style = "ultra" *)` 和内存阵列的 No-Change 读写编码，不依赖输出 pipeline 使能逻辑。此修改不影响 URAM 映射。

---

### 问题 2：CDMA_COOLDOWN_CYCLES 未定义（多 Tile drain HBM 失败）

| 属性 | 内容 |
|------|------|
| **文件** | `rtl/vpu/CDMA_Controller.sv`, `rtl/chip/chip_defines.vh` |
| **影响** | conv3 等多 Tile DCIM 在 `staging="hbm"` 路径下 drain 到 HBM 时数据错误 |
| **症状** | tile_obuf → HBM 的背靠背 CDMA 操作中，后续传输覆盖/混入前一传输的残留数据 |
| **严重程度** | High —— 多 Tile hbm 路径不通过 |

**动机**：dcim_matmul conv3（3 Tile 活跃）在 `staging="hbm"` 模式下始终 FAIL，表现为 obuf drain 到 HBM 的数据有数个 word 错位。`staging="preload"` 通过。

**根因**：`CDMA_Controller.sv` 中引用了 `` `CDMA_COOLDOWN_CYCLES `` 宏来控制两次 CDMA 传输之间的 AXI 写事务隔离等待周期。但该宏在模块内部**无默认值**，若 include 顺序问题导致未定义则为 0，等同于无冷却——连续 CDMA 的 AXI 写事务在 SmartConnect 中产生竞争。

**修复**：
1. 在 `rtl/chip/chip_defines.vh` 中定义 `` `define CDMA_COOLDOWN_CYCLES 2000 ``（保守值，约 6.7μs @ 300MHz）
2. 在 `CDMA_Controller.sv` 头部加 `` `ifndef/`define `` 兜底

---

### 问题 3：VPU `config_ready` 信号过早 assert（dqa 偶发 mismatch）

| 属性 | 内容 |
|------|------|
| **文件** | `rtl/vpu/Global_VPU.v` |
| **影响** | dqa/qa 通过 HBM drain 路径读出时，个别 word（1-4 个）与 expected 不一致 |
| **症状** | dqa_c16_small 在重复运行中约 30% 出现 1-4 word mismatch |
| **严重程度** | Medium —— 偶发，不影响 preload path |

**动机**：dqa 测试在大部分情况下 PASS，但在 HBM drain 路径下偶尔 FAIL。

**根因**：`Global_VPU.v` 的 `config_ready` 在 VPU 子单元 `xxx_unit_ready` 全部 assert 时拉高，允许下一条 ISA 指令（通常是 drain CDMA）开始执行。但 VPU 子单元（如 dqa）的 ready 在内部计算完成时 assert，此时最后的写操作可能仍在 URAM write pipeline 中（NBPIPE+2=10 拍）。若 drain CDMA 立即读取刚写入的 VPU_BUF 区域，可能读到旧值。

**当前临时缓解**：在 `hbm_flow.py` 中 VPU WAIT 与 drain CDMA 之间插入 `_VPU_SETTLE_NOPS = 256` 个 NOP 指令（约 0.85μs），给 URAM write pipeline 时间完成。

**推荐永久修复**（待实施）：在 VPU 子单元内部，将 ready 信号延迟到最后一笔写操作经过 URAM write pipeline 后再 assert（约延迟 NBPIPE+2 拍）。

---

### 问题 4：WB CDMA 写入后立即读取导致数据未就绪

| 属性 | 内容 |
|------|------|
| **文件** | 同问题 3（URAM write pipeline latency） |
| **影响** | qa_c16_signed 在 hbm path 下个别 word mismatch |
| **症状** | Scale/Bias 通过 CDMA 写入 WB BRAM 后，qa 立即读取时部分数据未就绪 |
| **严重程度** | Medium |

**当前临时缓解**：在 `hbm_flow.py` 中 WB CDMA 写入指令后插入 `_WB_SETTLE_NOPS = 512` 个 NOP。

**推荐永久修复**：与问题 3 相同思路——CDMA done 信号应等 URAM pipeline flush 后再 assert。

---

### 测试现状总结

| 测试 Case | preload | hbm | 状态 |
|-----------|---------|-----|------|
| dcim_matmul/dcim_tiny_1x1 | ✅ PASS | ✅ PASS | OK |
| dcim_matmul/conv6 (单Tile) | ✅ PASS | ✅ PASS | OK |
| dcim_matmul/conv3 (3Tile) | ✅ PASS | ❌ FAIL | 待修复：问题 2（CDMA_COOLDOWN） |
| qa/qa_c16_signed | ✅ PASS | ⚠️ 偶发 | 问题 4 + NOP 缓解后稳定 |
| dqa/dqa_c16_small | ✅ PASS | ⚠️ 偶发 | 问题 3 + NOP 缓解后大幅改善 |
| im2col/im2col_6x6_s2_c3 | ❌ FAIL | ❌ FAIL | 待修复：问题 1（URAM pipeline） |

---

### 待下次综合验证的 RTL 修改清单

| # | 文件 | 修改内容 | 状态 |
|---|------|---------|------|
| 1 | `rtl/common/uram_tdp_bytewrite.v` | `men_pipe_a/b` 推入条件：`mem_ena` → `mem_ena & ~\|wea` | ✅ 已改 |
| 2 | `rtl/vpu/CDMA_Controller.sv` | 加 `ifndef CDMA_COOLDOWN_CYCLES` 默认 2000 | ✅ 已改 |
| 3 | `rtl/chip/chip_defines.vh` | 定义 `CDMA_COOLDOWN_CYCLES 2000` | ✅ 已有 |
| 4 | `rtl/vpu/Global_VPU.v` | ready 延迟 NBPIPE+2 拍 | 🔲 待实施 |

---

## 支持的算子

| 算子 | RTL 单元 | 编译器支持 | 状态 |
|------|----------|-----------|------|
| Conv | im2col + CDMA + DCIM + DQA | ✅ | 仿真 PASS |
| Add (residual) | ad_unit | ✅ | 仿真 PASS |
| Concat | OP_CDMA_STRIDE | ✅ | 仿真 PASS |
| Upsample 2x | us_unit_fixed | ✅ | 仿真 PASS |
| MaxPool 5x5 s1 | mp_unit_fixed | ✅ | 仿真 PASS |
| QA (FP32→INT8/16) | qa_unit | ✅ | 仿真 PASS |
| DQA (INT32→FP32) | dqa_relu_unit | ✅ | 仿真 PASS |

## 硬件限制与解决方案

- **cout > 128**: 自动 cout tiling（多次 DCIM pass，每次 8 tiles）
- **MaxPool 3x3 s2**: host 预处理（mp_unit_fixed 仅支持 5x5 s1 p2）
- **Detect Head**: host 后处理（model.24 的 3 个 1x1 Conv + reshape + sigmoid）
- **AvgPool + FC**: host 后处理

## 地址映射 (chip-lite BD, 来自 scripts/ip/bd/lite/address.tcl)

| 段 | 地址 | 大小 | Host XDMA | 说明 |
|----|------|------|-----------|------|
| HBM | 0x0_0000_0000 | 4GB | **读写** | 输入/输出 staging |
| tile_ibuf[t] | 0x1_0000_0000 + t×0x80000 | 512KB/tile | CDMA only | DCIM 输入 |
| tile_obuf[t] | 0x1_0100_0000 + t×0x40000 | 256KB/tile | CDMA only | DCIM 输出 |
| VPU_BUF | 0x1_0200_0000 | 8MB | CDMA only | VPU 特征图 |
| VPU WB | 0x1_0300_0000 | 32KB | CDMA only | Scale/Bias |
| INST_BRAM | 0x1_0400_0000 | 128KB | **读写** | 指令 |
| VPU_AXI_Regs | 0x1_0500_0000 | 4KB | 控制* | Decoder 启停 |

### VPU_AXI_Regs 寄存器偏移

| 偏移 | 名称 | 方向 | 说明 |
|------|------|------|------|
| 0x04 | STATUS | R | [0] VPU ready |
| 0x38 | DECODER_CTRL | W | [0] 写 1 启动 decoder (脉冲) |
| 0x3C | INST_COUNT | RW | 指令总数 (32-bit words) |
| 0x40 | DECODER_STATUS | R | [0] busy, [1] done, [31] error |
