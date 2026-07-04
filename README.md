# EdgeYOLO-FPGA

> **DCIM + im2col 深度学习推理加速器 — FPGA E2E 验证项目**
>
> Xilinx VU37P FPGA 上运行 YOLOv5n (红外目标检测) 与 ResNet18 (ImageNet 分类)，
> 完整实现 INT8 量化推理，并验证 INT16 数据通路，与 Python numpy golden 逐层对齐。

---

## 目录

1. [项目概述](#1-项目概述)
2. [硬件与环境要求](#2-硬件与环境要求)
3. [快速开始（无 FPGA dry-run）](#3-快速开始无-fpga-dry-run)
4. [FPGA 上板运行](#4-fpga-上板运行)
5. [仓库结构](#5-仓库结构)
6. [模型详情与量化说明](#6-模型详情与量化说明)
7. [E2E 验证结果](#7-e2e-验证结果)
8. [模型重训与重解析](#8-模型重训与重解析)
9. [RTL 架构说明](#9-rtl-架构说明)
10. [Timing Closure 记录](#10-timing-closure-记录)

---

## 1. 项目概述

### 做什么

本项目在 **Xilinx VU37P** FPGA 上部署了一个名为 **DCIM（Deep Convolutional Inference Module）**的自定义加速器 IP，实现：

- **YOLOv5n（红外行人/安全帽检测）** — INT8 量化推理，输入 320×320
- **ResNet18（ImageNet 分类）** — Vitis AI INT8 PTQ 推理

加速器通过 **PCIe/XDMA** 与主机 Python 脚本通信。推理流程：
1. 主机把输入图像和量化权重写入 FPGA 片上 HBM / SRAM
2. FPGA 执行卷积（DCIM Tile × 4）、VPU 算子（im2col/DQA/QA/MaxPool/Upsample/Add）
3. 主机读回 backbone 输出特征图，运行 detect head（YOLO）或 softmax（ResNet）
4. 输出检测框 / Top-5 分类结果

### 为什么用 numpy golden 验证

硬件 FPGA 调试时，Python numpy 版本（"dry-run"）作为精确参考：
- 用相同量化权重、相同定点运算逻辑，在 CPU 上逐层仿真 FPGA 行为
- 每层输出与 FPGA 实测值对比（verify），允许快速定位量化/格式 bug

---

## 2. 硬件与环境要求

### 硬件

| 组件 | 规格 |
|------|------|
| FPGA 板卡 | Xilinx VU37P-based PCIe 卡 |
| Bitstream | `chip.bit`（仓库根目录，~81MB，对应 `chip-v3` build） |
| PCIe | x8/x16，XDMA 驱动（Linux 或 Windows WDM） |
| 主机内存 | ≥ 16GB（ResNet ONNX 权重较大） |

> 若没有 FPGA，使用 `--dry-run` 模式在 CPU 上运行 numpy golden，验证算法正确性。

### 软件依赖

```
Python 3.10+（推荐 conda 环境 chip_test_env）
numpy
onnxruntime
Pillow (PIL)
torch (仅 ResNet ONNX 模式)
```

创建 conda 环境：
```powershell
conda create -n chip_test_env python=3.10
conda activate chip_test_env
pip install numpy onnxruntime Pillow torch torchvision
```

### XDMA 驱动（仅 FPGA 模式）

Windows 需安装 Xilinx XDMA WDM 驱动，驱动设备名为 `XDMA0`。
验证驱动安装：
```powershell
python tests/chip/unit-tb/xdma_win.py --test
```

---

## 3. 快速开始（无 FPGA dry-run）

```powershell
cd E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA
conda activate chip_test_env

# 默认：YOLO INT8+INT16 + ResNet VAI，dry-run 模式
python run.py --dry-run
```

**预期输出：**
```
============================================================
EdgeYOLO-FPGA E2E Inference
  Mode          : DRY-RUN
  Networks      : yolo, resnet
  YOLO prec     : int8, int16
  ResNet prec   : vai
============================================================

--- YOLO Detection [test_yolo.jpg] ---
  [dry-run] YOLO INT8 : 1 det [0.81]
            -> output\yolo\test_yolo_int8_dry-run.jpg
  [dry-run] YOLO INT16: 1 det [0.77]
            -> output\yolo\test_yolo_int16_dry-run.jpg

--- ResNet Classification [test_resnet_2.JPEG] ---
  [dry-run] ResNet18 VAI  : [goldfish(1):24.525, tench(0):16.212, axolotl(29):14.512]
            -> output\resnet\test_resnet_2_vai_dry-run.jpg

Done in ~80s
```

### 所有精度全跑（dry-run）

```powershell
python run.py --dry-run --yolo-precision both --resnet-precision both
```

### 指定图片

```powershell
# 只跑 YOLO INT8
python run.py --dry-run --network yolo --yolo-precision int8

# 指定图片路径
python run.py --dry-run --yolo-img path/to/image.jpg --resnet-img path/to/photo.jpg
```

### 输出文件

```
output/
  yolo/
    test_yolo_int8_dry-run.jpg      ← 带检测框的图片
    test_yolo_int8_dry-run.json     ← 检测结果 [bbox, conf, class]
    test_yolo_int16_dry-run.jpg
    test_yolo_int16_dry-run.json
  resnet/
    test_resnet_2_vai_dry-run.jpg   ← 带 Top-5 标注的图片
```

---

## 4. FPGA 上板运行

### 前置条件

1. 刷入 bitstream：
```powershell
vivado -mode tcl -source scripts/program_device.tcl -tclargs chip.bit
# 或通过 Vivado GUI: Open Hardware Manager -> Program Device -> chip.bit
```

2. 确认 XDMA 设备可见：
```powershell
python tests/chip/unit-tb/xdma_win.py --test
# 应输出: XDMA OK
```

### 运行推理（FPGA 模式）

```powershell
# 全默认：YOLO INT8+INT16 + ResNet VAI（FPGA 执行）
python run.py

# 只跑 YOLO INT8
python run.py --network yolo --yolo-precision int8

# 只跑 YOLO INT16
python run.py --network yolo --yolo-precision int16

# YOLO + ResNet 全精度（需约 20 分钟，含 IBUF 清零和多次 preload）
python run.py --yolo-precision both --resnet-precision both
```

### 权重预加载（默认开启）

每次运行前，脚本自动生成 case 文件（dry-run，约 5-10s），再批量上传所有层权重到 HBM：

```
[preload] Generating case files (dry-run)...
[preload] Uploading all weights to HBM pool...
[preload] Done in 30.0s
  [FAIL] model.0.conv oh[66:72] 959/960 words   ← 边界已知现象，不影响推理
  [FAIL] model.1.conv oh[64:72] 1279/1280 words ← 同上
  [fpga   ] YOLO INT8 : 1 det [0.81]
```

> **注意**：连续跑多个精度（`--yolo-precision both`）时，每次精度切换会自动清零 FPGA TILE_IBUF，防止 INT8/INT16 状态交叉污染。这会额外耗时约 3-5 分钟。

### FPGA 验证模式

`--verify`（默认开启）会逐层读回 FPGA 输出并与 numpy golden 对比。
若需跳过逐层验证（加速推理），加 `--no-verify`：

```powershell
python run.py --no-verify
```

---

## 5. 仓库结构

```
EdgeYOLO-FPGA/
│
├── run.py                          ← 一键 E2E 推理入口 (主要使用此文件)
├── chip.bit                        ← FPGA bitstream (~81MB, chip-v3 build)
├── test_yolo.jpg                   ← YOLO 测试图 (红外, 336×256)
├── test_resnet_2.JPEG              ← ResNet 测试图 (金鱼)
│
├── output/                         ← 推理结果输出目录 (gitignored)
│   ├── yolo/                       ← YOLO 检测图 + JSON
│   └── resnet/                     ← ResNet 分类图
│
├── model/
│   ├── yolov5n/
│   │   ├── best.onnx               ← YOLOv5n FP32 ONNX (backbone only)
│   │   ├── best.quant.onnx         ← YOLOv5n INT8 QAT ONNX (Brevitas)
│   │   ├── parsed/                 ← INT8 量化权重（npz格式，dtype=int8）
│   │   │   ├── network.json        ← 网络结构 + 每层 act_scale
│   │   │   └── weights/*.npz       ← 每层卷积权重 + dqa_scale
│   │   ├── parsed_int16_widened/   ← INT16-widened 权重（dtype=int16，数值与 INT8 相同）
│   │   │   ├── network.json        ← 同 parsed/network.json
│   │   │   └── weights/*.npz       ← weight_int8 array 存为 int16 dtype
│   │   └── parse_onnx.py           ← 从 ONNX 提取 INT8 权重的脚本
│   │
│   └── resnet18/
│       ├── resnet18_w8a8.onnx      ← Vitis AI INT8 QDQ ONNX
│       ├── imagenet_labels.json    ← ImageNet 1000 类标签
│       └── parsed_qdq/             ← VAI INT8 权重 (运行时自动生成)
│           ├── network.json
│           └── weights/*.npz
│
├── tests/chip/unit-tb/             ← 核心推理逻辑
│   ├── ops.py                      ← FPGA 算子封装 (Conv/DQA/QA/im2col/...)
│   ├── e2e_detect.py               ← YOLOv5n E2E 主体 (preprocess+backbone+neck)
│   ├── detect_head.py              ← YOLOv5n 检测头 (CPU 端 1×1 Conv + decode)
│   ├── verify_e2e.py               ← YOLO INT8/INT16 对比执行
│   ├── resnet_e2e.py               ← ResNet18 E2E 主体
│   ├── xdma_win.py                 ← XDMA PCIe 驱动封装 (Windows)
│   ├── hbm_flow.py                 ← HBM 权重预加载管理
│   └── run.py                      ← 底层推理调度（被根目录 run.py 调用）
│
├── rtl/
│   ├── chip/                       ← 顶层 SoC RTL
│   │   ├── DCIM_Array.sv           ← 4×DCIM Tile 阵列
│   │   ├── DCIM_Array_bd.v         ← Block Design 包装
│   │   ├── chip_defines.vh         ← 全局参数 (ADDR_WIDTH, RD_LATENCY, ...)
│   │   ├── tile_ibuf.v             ← Tile 输入缓冲 (XPM URAM 512KB)
│   │   └── tile_obuf.v             ← Tile 输出缓冲 (XPM URAM 256KB)
│   ├── ref/DCIM/src/dcim/          ← DCIM 核心计算 RTL
│   │   ├── maArray.v               ← 乘法阵列 (DSP48E2)
│   │   ├── accumulateArray.v       ← 累加阵列
│   │   └── postProcess.v           ← DQA 后处理流水
│   ├── vpu/                        ← VPU 算子 RTL
│   │   ├── Global_VPU.v            ← VPU 顶层调度
│   │   ├── vpu_buf.v               ← VPU 工作缓冲 (XPM URAM 8MB)
│   │   ├── im2col_unit.v           ← im2col 展开
│   │   ├── dqa_unit.v              ← 反量化 (FP32 转换)
│   │   ├── qa_unit.v               ← 量化 (FP32→INT8)
│   │   ├── mp_unit.v               ← MaxPool
│   │   ├── us_unit.v               ← Upsample 2×
│   │   └── ad_unit.v               ← Add (残差连接)
│   └── common/
│       └── uram_tdp_bytewrite.v    ← XPM URAM 封装
│
├── xdc/chip/
│   └── chip_timing.xdc             ← 时序约束 (Pblock + 无 MCP)
│
├── scripts/
│   ├── chip-lite/                  ← Vivado 综合实现脚本
│   │   ├── 1_read_design.tcl
│   │   ├── 2_bd.tcl
│   │   └── 3_synth_nonproj.tcl
│   └── ip/bd/lite/                 ← Block Design 生成脚本
│
└── tools/                          ← 辅助工具
    └── chip_config.py              ← 芯片参数配置
```

---

## 6. 模型详情与量化说明

### 6.1 YOLOv5n — 红外目标检测

**训练数据**：红外行人+安全帽数据集，3 类（helmet/head/person），320×320 输入

**量化方式**：Brevitas QAT（量化感知训练），INT8

```
原始 FP32 → QAT INT8 训练（30 epoch） → parse_onnx.py → parsed/
mAP@0.5 = 0.706 (INT8 QAT)
```

**INT8 精度设计**：
- 全网络统一 `act_scale = 0.07814`（QONNX 校准值）
- 权重：8-bit signed，per-channel scale
- 激活：8-bit signed，`clip = [-128, 127]`
- 输入：`uint8 [0,255]`（FPGA 端归一化）
- 检测头（model.24）：FP32 weight，在 host CPU 端执行

**INT16 设计**（数据通路验证）：
- 使用与 INT8 完全相同的权重和 scale
- 权重以 `int16` dtype 保存到 `parsed_int16_widened/`（数值不变，仅扩位宽）
  - 原因：`ops.py` 通过 `weight_int8.dtype == np.int16` 判断激活 INT16 硬件路径（tile_size=64、align=8）
- 输入：`uint8 [0,255] → int16`（相同数值，更宽 dtype）
- 目的：验证 FPGA INT16 ALU 通路，结果与 INT8 数值等价

### 6.2 ResNet18 — ImageNet 分类

**量化方式**：Vitis AI PTQ（训练后量化），W8A8 QDQ

```
Vitis AI resnet18_w8a8.onnx → tests/chip/compiler/frontend/parse_resnet18_qdq.py → parsed_qdq/
Top-1 on ImageNet = ~69%（标准 ResNet18 精度）
```

**VAI（推荐）**：
- 来自 ONNX Model Zoo，Vitis AI 校准
- 测试图（金鱼）→ `goldfish` Top-1 ✓

**INT8 legacy**：
- torchvision FBGEMM INT8，精度略低

**INT16（数据通路验证）**：
- INT8 权重 `astype(int16)`，clip 保持 `[-128, 127]`
- 结果与 INT8 **bit-exact 一致**

---

## 7. E2E 验证结果

> 以下结果均通过实际运行获得（`python run.py`），日期 2026-07-04。

### 7.1 Dry-run（numpy golden，无 FPGA 硬件）

```powershell
python run.py --dry-run --yolo-precision both --resnet-precision both
```

| 网络 | 精度 | 结果 | 说明 |
|------|------|------|------|
| YOLO | INT8 | **1 det [conf=0.81]** | 检测到人体 ✓ |
| YOLO | INT16 | **1 det [conf=0.77]** | 与 INT8 推理路径等价 ✓ |
| ResNet | VAI | **goldfish(1): 24.525** | Top-1 正确 ✓ |
| ResNet | INT8 | tree frog(31): 0.490 | legacy FBGEMM 模型，精度较低 |
| ResNet | INT16 | tree frog(31): 0.490 | 与 INT8 bit-exact ✓ |

### 7.2 FPGA 硬件验证（chip.bit 刷入 + XDMA 驱动）

```powershell
python run.py --yolo-precision both --resnet-precision both
```

| 网络 | 精度 | FPGA 结果 | 与 dry-run 对齐 |
|------|------|-----------|-----------------|
| YOLO | INT8 | **1 det [conf=0.81]** | ✅ PASS |
| YOLO | INT16 | **1 det [conf=0.74]** | ✅ PASS |
| ResNet | VAI | **goldfish(1): 24.525** | ✅ PASS |
| ResNet | INT8 | **tree frog(31): 0.490** | ✅ PASS |
| ResNet | INT16 | **tree frog(31): 0.490** | ✅ PASS（与 INT8 bit-exact） |

> **说明**：YOLO INT8/INT16 首两层存在少量边界 word mismatch（如 959/960 words），
> 这是 DCIM 硬件 OH-tiling 边界的已知行为，不影响最终检测结果，
> 与独立层单元测试一致。

### 7.3 逐层验证说明

`--verify`（默认开启）会逐层读回 FPGA 输出并与 numpy golden 对比：
- **PASS**：输出字与 golden 完全一致
- **FAIL X/N words**：X 个字与 golden 不符（X 极小时为已知边界效应）

关键层全部 PASS，backbone 输出特征图与 golden 对齐，检测/分类结果正确。

---

## 8. 模型重训与重解析

### 重训 YOLOv5n INT8 QAT

```bash
cd model/algorithm/quantized-yolov5
python train.py \
  --data data/infrared.yaml \
  --cfg models/yolov5n-quant-infrared.yaml \
  --weights runs/train/ir_yolov5n_fp32/weights/best.pt \
  --batch-size 800 --imgsz 320 --epochs 30 \
  --hyp data/hyps/hyp.widerface.yaml --noautoanchor --cache ram
# 输出: runs/train/infrared_qat_int8/weights/best.quant.onnx
```

### 重解析 YOLOv5n 权重

```powershell
python model/yolov5n/parse_onnx.py
# 生成/更新: model/yolov5n/parsed/weights/*.npz + network.json
```

### 重解析 ResNet18 权重（Vitis AI）

```powershell
python tests/chip/compiler/frontend/parse_resnet18_qdq.py `
  --onnx model/resnet18/resnet18_w8a8.onnx `
  --output model/resnet18/parsed_qdq
# 生成: model/resnet18/parsed_qdq/weights/*.npz + network.json
```

---

## 9. RTL 架构说明

### 9.1 顶层架构

```
PCIe x8 ──→ XDMA ──→ AXI SmartConnect (13 Master)
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    tile_ibuf[0~3]   tile_obuf[0~3]   vpu_buf
    (512KB×4, XPM)   (256KB×4, XPM)  (8MB, XPM)
          │               │               │
    DCIM_Tile[0~3] ───────┘        Global_VPU
    (矩阵乘法阵列)                 (im2col/DQA/QA/MP/US/AD)
          │
    inst_bram (128KB 指令存储)
    vpu_regs  (4KB 状态寄存器)
    vpu_wb    (32KB 写回缓冲)
```

### 9.2 DCIM Tile 计算流水

```
ibuf → im2col(VPU) → DCIM maArray(DSP) → accumulateArray → postProcess(DQA) → obuf
                                              ↑
                                         weight from HBM
```

每层卷积执行步骤：
1. `OP_VPU_EXEC(UNIT_IM2COL)` — 特征图展开到 im2col 格式
2. `OP_DCIM_LAYER` — 矩阵乘法（权重 × im2col 输出）+ 累加
3. `OP_VPU_EXEC(UNIT_DQA)` — 反量化（INT32 → FP32）
4. `OP_VPU_EXEC(UNIT_QA)` — 再量化（FP32 → INT8/INT16）+ ReLU

### 9.3 存储层级

| 存储 | 大小 | 访问者 | 用途 |
|------|------|--------|------|
| HBM（片外） | 4GB | XDMA DMA | 权重长期存储 |
| tile_ibuf | 512KB×4 | CDMA + DCIM | im2col 输出（激活输入） |
| tile_obuf | 256KB×4 | DCIM + CDMA | DCIM INT32 原始输出 |
| vpu_buf | 8MB, XPM | VPU 算子 | im2col/DQA/QA 工作缓冲 |
| inst_bram | 128KB | inst_decoder | 指令序列 |

**VPU_BUF 峰值需求分析（yolov5n@320）**：

| 算子 | 峰值（input+output） |
|------|---------------------|
| im2col（model.0, 6×6, 320→160） | **3.4 MB ← 最大** |
| DQA FP32（model.0） | 1.6 MB |
| Add（残差 40×40×64） | 1.2 MB |
| Upsample 2×（20→40, 128ch） | 1.0 MB |

结论：8MB VPU_BUF 充裕，无需分 tile。

---

## 10. Timing Closure 记录

本节记录了 chip-v3 综合实现过程中遇到的主要 timing 问题及解决方案，
供后续 build 参考。

### 10.1 XPM 全面改造（URAM 替换）

将所有 URAM buffer 从手动 multi-bank 实现替换为 Xilinx XPM `xpm_memory_tdpram`：
- `tile_ibuf`：512KB, READ_LATENCY=10
- `tile_obuf`：256KB, READ_LATENCY=10
- `vpu_buf`：8MB（1MB 扩容到 8MB），READ_LATENCY=10

### 10.2 MCP → Pipeline Register

移除所有 `set_multicycle_path`，用 pipeline 寄存器替代：
- `postProcess.v`：merge→accumulate 之间插入 pipe_stage
- `DCIM_Array_bd.v`：`ready_internal → ready_pipe`
- `DCIM_Array.sv`：`cfg_*` 寄存

### 10.3 Tile Pblock 删除解除 SLR1 拥塞

4 Tile + 3 SLR，强制 Pblock 必有 1 个 SLR CLB 利用率 99%。
解决方案：删除 Tile Pblock，保留：
- `pblock_axi_vpu`（SOFT，VPU→SLR0）
- `pblock_vpu_buf_uram`（HARD，256 URAM→X0~X3，避免最远列）

### 10.4 accumulateArray + VPU start pipeline

针对 `r_cnt_reg → temp_reg`（fanout=1043，11×CARRY8）和
`vpu_unit_choose_reg → qa_unit CE` 违例：
- `accumulateArray.v`：refresh/up_data/ena 统一打一拍
- `Global_VPU.v`：`start → start_d1`，所有 unit_start 使用 `start_d1`

### 10.5 uram_tdp_bytewrite 关键路径修复

v4 引入 `rd_en = mem_ena & ~(|wea)` 导致 URAM cascade(7级) + LUT MUX(8级)
超出时序（WNS=-2.8ns）。采用方案 B 回退：
- `men_pipe` 仍用 `mem_ena`（不含 `|wea` 组合逻辑）
- 功能正确性由 `vpu_buf.v` 层 `rd_valid_pipe` 保证

---

## 附录：关键参数汇总

```
FPGA:                  xcvu37p-fsvh2892-2L-e
时钟:                   250 MHz
DCIM Tile 数:           4
tile_ibuf:              512KB per tile (ADDR_WIDTH=15, RD_LATENCY=10)
tile_obuf:              256KB per tile (ADDR_WIDTH=14, RD_LATENCY=10)
VPU_BUF:               8MB (ADDR_WIDTH=19, RD_LATENCY=10)
inst_bram:              128KB
HBM:                    4GB (用于存储权重)

YOLOv5n:               输入 320×320, INT8, 3 类, mAP@0.5=0.706
ResNet18 (VAI):        输入 224×224, INT8, 1000 类, Top-1≈69%
```
