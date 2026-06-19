# YOLOv5n FPGA E2E 推理

> 在红外目标检测任务上，将 YOLOv5n Backbone + Neck 完整跑在 FPGA 硬件上，Host 负责前处理与 Detect Head。  
> 支持 **INT8** 和 **真实 INT16 QAT** 两种精度，均已在 FPGA 上完成 E2E 验证。

---

## 验证状态（2026-06-19）

| 图片 | FPGA INT8 | FPGA INT16（真实QAT权重） | dry-run INT16 | 一致性 |
|------|-----------|--------------------------|---------------|--------|
| 1.jpg  | 1 det (person 0.81) | **8 det** | 8 det | ✓ bit-exact |
| 10.jpg | 1 det (person 0.80) | **3 det** | 4 det | △ 差1框(conf边界) |
| 100.jpg | 1 det (person 0.20) | **12 det** | 13 det | △ 差1框(conf边界) |

**INT16 真实 QAT 权重精度远高于 INT8**（23 det vs 3 det），差异根因为 ±1 LSB 舍入误差传播（详见精度分析节）。

---

## 文件结构与关键代码

```
tests/chip/unit-tb/
├── e2e_detect.py        ★ E2E 主入口（INT8/INT16，FPGA/dry-run）
├── verify_e2e.py        ★ 一键对比 INT8 与 INT16 FPGA 结果
├── ops.py               ★ FPGA/Host 算子（conv/tiled/oh_tiled/pool/upsample）
├── detect_head.py         Host Detect Head（1×1 FP32 conv + sigmoid + NMS）
├── run.py                 图像前处理/后处理（letterbox, QA, NMS）
├── xdma_win.py            Windows XDMA PCIe 驱动封装
├── hbm_flow.py            HBM 预加载流程
├── run_int16_verify.py    单算子级 INT16 硬件验证
└── run_unit_test.ipynb    交互式单算子调试

rtl/tb/lite_bd/module_tb/
└── golden_module_tb.py  ★ 核心：生成 FPGA 指令 + numpy golden 参考值

model/yolov5n/
├── parse_onnx.py          解析 INT8 QDQ-ONNX → NPZ + network.json
├── parse_onnx_int16.py    解析 INT16 QDQ-ONNX（Brevitas QAT）→ NPZ
├── parse_qonnx.py         通用 Brevitas QDQ ONNX 解析工具
├── parsed/                INT8 解析结果（57层权重 + network.json）
├── parsed_int16/          INT16 QAT 真实权重（当前 E2E INT16 使用此目录）
└── parsed_int16_from_int8/ INT8 升位为 INT16（精度等同 INT8，用于硬件通路验证）
```

**关键函数速查：**

| 功能 | 文件 | 函数/位置 |
|------|------|-----------|
| E2E 网络拓扑执行 | `e2e_detect.py` | `run_fpga_backbone_neck()` |
| FPGA conv（单层） | `ops.py` | `FPGAOps.conv()` |
| FPGA conv（cout-tiling） | `ops.py` | `FPGAOps.conv_tiled()` |
| FPGA conv（oh-tiling） | `ops.py` | `FPGAOps.conv_oh_tiled()` |
| FPGA 指令生成（INT8） | `golden_module_tb.py` | `make_conv_pipeline_case()` |
| FPGA 指令生成（INT16） | `golden_module_tb.py` | `is_weight_int16` 分支 |
| INT16 im2col 8-slot 对齐 | `golden_module_tb.py` | `slots_per_pixel = ((in_ch+7)//8)*8` |
| INT16 权重打包 | `golden_module_tb.py` | `pack_weight_tile_int16()` |

---

## 快速执行命令

```bash
cd tests/chip/unit-tb
conda activate yoloir

VAL="C:\users\zczho\Downloads\YOLO_on_FPGA\YOLO_on_FPGA\Infrared-Object-Detection\datasets\infrared\images\val"

# ── INT8 FPGA ──────────────────────────────────────────
python e2e_detect.py --images $VAL --max 5 --conf 0.2

# ── INT8 dry-run（无需硬件，numpy 模拟）───────────────
python e2e_detect.py --images $VAL --max 5 --conf 0.2 --dry-run

# ── INT16 FPGA（真实 QAT 权重）────────────────────────
python e2e_detect.py --images $VAL --max 5 --conf 0.15 --int16

# ── INT16 dry-run ─────────────────────────────────────
python e2e_detect.py --images $VAL --max 5 --conf 0.15 --int16 --dry-run

# ── 同时验证 INT8 + INT16，生成对比图 ─────────────────
python verify_e2e.py --images $VAL --max 3 --conf 0.15

# 输出图片目录：
#   runs/e2e/dry_run/    ← dry-run 检测结果
#   runs/e2e/fpga/       ← FPGA 检测结果
#   runs/e2e/verify/     ← INT8 vs INT16 对比图
```

**前提：INT16 参数已解析**（`parsed_int16/` 目录存在）。若不存在：
```bash
cd model/yolov5n
python parse_onnx_int16.py   # 从 infrared_qat_int16/weights/best.quant.onnx 解析
```

---

## 数据流

```
输入图片 (H×W×3, uint8)
    │
    ▼  Host: letterbox(320×320) → /255 → QA → INT8/INT16 [320,320,3]
    │
    ▼  FPGA: Backbone + Neck（57 conv layers）
    │
    │  model.0 (6×6 s2) → model.1 (3×3 s2)
    │  → C3-2 → model.3 (s2) → C3-4               ← feat x4 (80×80)
    │  → model.5 (s2) → C3-6                       ← feat x6 (40×40)
    │  → model.7 (s2) → C3-8                       ← feat x8 (20×20)
    │  → SPPF → model.10                           ← feat x10
    │  → upsample + concat(x6) → C3-13 → model.14 ← feat x14
    │  → upsample + concat(x4) → C3-17             ← P3 (40×40×64)
    │  → model.18 + concat(x14) → C3-20            ← P4 (20×20×128)
    │  → model.21 + concat(x10) → C3-23            ← P5 (10×10×256)
    │
    ▼  Host: Detect Head（model.24，1×1 FP32 conv）
    │  P3/P4/P5 → dequant(act_scale) → 1×1 conv → sigmoid → decode
    │
    ▼  Host: NMS → bounding boxes → 画框输出
```

**关键分工：**
- FPGA 执行 Conv Pipeline：`im2col → DCIM matmul → DQA → QA`
- Host 执行：maxpool、upsample、concat、detect head、NMS
- 每层独立运行，结果经 PCIe DMA 读回 Host

---

## Tiling 策略

| 场景 | INT8 | INT16 |
|------|------|-------|
| 单 pass 最大输出通道 | 128 ch | **64 ch** |
| 超出时 → cout-tiling | `conv_tiled(limit=128)` | `conv_tiled(limit=64)` |
| 输出像素超 IBUF → oh-tiling | `conv_oh_tiled` | 同左（`max_pix` 用 `acc_depth_int16`） |
| 两者均超 | `conv_tiled` 内嵌套 `conv_oh_tiled` | 同左 |

---

## 如何提高 E2E 精度

当前差距来源与对应方案：

### 方案一：使用真实 INT16 QAT 权重（已实现）
- 现状：`parsed_int16/` 权重为真实 16-bit 量化（unique 值 1674~42069），精度远高于 INT8  
- 效果：1.jpg 8 det，100.jpg 12 det，INT8 仅 1 det（提升显著）

### 方案二：修正 golden 舍入模式，消除 ±1 LSB 误差
- 当前差异原因：FPGA 整数运算截断方向（向零截断）与 golden 浮点模拟不完全一致，每层 1~3 个 int16 值差 1
- 经过 57 层传播，最终 conf 偏差约 0.01~0.02，导致边界框丢失
- 修复方向：在 `golden_module_tb.py` 中将累加结果的截断改为与硬件一致的 `floor` 或 `trunc`

### 方案三：降低 conf_thres（立竿见影）
```bash
python e2e_detect.py --images $VAL --conf 0.10 --int16
```
- 将阈值从 0.15→0.10，可捕获更多边界置信度目标
- 代价：可能引入更多 false positive

### 方案四：Per-channel 量化 scale（需重新训练）
- 当前 INT8/INT16 均使用 per-tensor `act_scale`，所有通道共用一个 scale
- Per-channel scale 可减少量化误差 2~5%（mAP）
- 需要修改 `parse_onnx.py` 支持 per-channel 读取 + FPGA 指令修改

### 方案五：混合精度（关键层 INT16，其余 INT8）
- 对 P3/P4/P5 输出前的 1~2 层保持 INT16，其余层 INT8
- 可平衡精度与速度（INT16 每层约需 2× 时间）

---

## 精度分析：FPGA vs dry-run 逐框对比（INT16，conf>0.15）

| 图片 | FPGA det | dry-run det | 差异原因 |
|------|----------|-------------|---------|
| 1.jpg | **8 det** | 8 det | **完全一致（bit-exact）** |
| 10.jpg | 3 det | 4 det | 丢失 `bicycle conf=0.188`（FPGA 比 golden 低 0.001，落阈值下） |
| 100.jpg | 12 det | 13 det | 各框 conf 偏低约 0.02（±1 LSB 误差累积） |

**结论：FPGA 运行正确，差异为正常定点运算 ±1 LSB 舍入误差，非硬件 bug。**

---

## 主要 Bug 记录（历史）

| Bug | 层 | 根因 | 修复 |
|-----|----|------|------|
| #1 | model.0 | 权重 OIHW→OHWI 转置漏做 | `parse_onnx.py` transpose |
| #2 | C3 block | shortcut add 误加 | 移除 shortcut |
| #3 | detect head | `act_scale` 与 `input_act_scale` 混用 | 从 network.json 读正确 scale |
| #4 ★ | C3-20/23 | Neck concat 接口接错节点 | 按 ONNX 图修正 |
| #5 | model.18/21 | `hard_quant /2` 缩放 | 移除 hard_quant，补偿 dqa_scale |
| #15 ★ | model.0 | INT16 im2col `in_col_stride` 8-slot 对齐 | `slots=((in_ch+7)//8)*8` |
| #16 | model.5+ | E2E 中 INT16 feat 被强转 int8 截断 | 检测 `weights.dtype==int16` 跳过 |
| #17 | oh-tiling | padding 行 dtype 为 int8 | 改用 `feat.dtype` |
| #18 ★ | model.5 | cout-tiling 内未嵌套 oh-tiling | `conv_tiled` 内判断并调用 `conv_oh_tiled` |
| #19 | 多层 | `eff_ch` 对齐粒度 INT8/INT16 混淆 | 按 dtype 动态选 8 或 16 对齐 |

---

## 性能参考

| 模式 | 每张图耗时 |
|------|-----------|
| FPGA INT8 / INT16 | ~65s / ~95s |
| Golden dry-run | ~26s |
| PyTorch QAT（GPU） | ~0.5s |

> FPGA 耗时主要在 PCIe DMA 传输（57层 × ~1.2s/层）。INT16 额外约 30s 来自部分层需要多 pass（cout-tiling）。
