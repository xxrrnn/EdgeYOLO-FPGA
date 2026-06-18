# tests/chip/ — FPGA 板上端到端测试套件

EdgeYOLO-FPGA-lite 片上测试，覆盖从单算子到完整 YOLOv5n W8A8 网络。

---

## 目录结构

```
tests/chip/unit-tb/
├── 核心模块 ─────────────────────────────────────
│   ├── xdma_win.py          # XDMA 驱动封装 + ChipRunnerWin（FPGA 交互）
│   ├── hbm_flow.py          # HBM staging + CDMA 指令补丁生成
│   ├── ops.py               # 算子库：FPGAOps / HostOps / C3Block
│   ├── numpy_golden_net.py  # 纯 NumPy YOLOv5n backbone+neck 参考实现
│   ├── detect_head.py       # 检测头 host 端 (model.24: Conv + decode + NMS)
│   └── gen_data.py          # 调用 golden_module_tb.py 生成 L1/L2/L3 测试数据
│
├── 测试脚本 ─────────────────────────────────────
│   ├── _l3_rerun.py              # L3 端到端 conv_pipeline 批量测试
│   ├── _cout_tiling_test.py      # L4-B cout-tiling 验证 (model.7.conv 256ch)
│   ├── _l4_full_network_test.py  # L4-C 全网络 57 层渐进测试
│   ├── _e2e_topology_verify.py   # L4-D 端到端拓扑验证 (19 节点 byte-exact)
│   ├── _int16_test.py            # L4-E INT16 模式 FPGA 验证
│   ├── _int16_ext_test.py        # L4-E INT16 扩展 (大图 + cout-tiling)
│   ├── _onnx_vs_parsed.py        # L4-F ONNX 参数一致性 (57 层 exact match)
│   ├── _onnx_e2e_verify.py       # L4-F ONNX→FPGA 全链路验证
│   ├── test_smoke.py             # 基础冒烟测试
│   └── test_dcim_tiny.py         # DCIM 最小测试
│
├── run_unit_test.ipynb     # Jupyter 交互式测试 (L1/L2/L3)
├── _archive/               # 历史调试脚本归档 (96 个)
└── runs/                   # 测试数据输出目录 (运行时生成)

model/yolov5n/
├── best.onnx               # FP32 原始模型
├── best.quant.onnx         # 量化参数导出 (W8A8, 57 层)
├── parse_onnx.py           # ONNX → parsed/ 提取工具
└── parsed/
    ├── network.json        # 网络拓扑 + Conv 参数
    ├── activation_scales.json  # 各层 output act_scale
    └── weights/            # 逐层 NPZ (weight_int8, dqa_scale, dqa_bias, act_scale)
```

---

## 快速开始

### 前提条件

1. FPGA 已烧录 bitstream（`scripts/ip/bd/chip/` 生成）
2. `xdma_info.exe` 能看到设备（位于 `tests/xdma_exe/`）
3. conda 环境 `chip_test_env`（numpy, onnx, onnxruntime）

```bash
cd tests/chip/unit-tb
conda activate chip_test_env
```

### 典型使用方式

#### 1. 单算子 FPGA 验证

```python
from ops import FPGAOps, verify_op
from xdma_win import ChipRunnerWin

runner = ChipRunnerWin()
fpga = FPGAOps(runner)

# 验证任意 conv 层（自动选择 tiling 策略）
verify_op(fpga, 'model.3.conv', 'test_m3', in_hw=(8, 8))  # → PASS
verify_op(fpga, 'model.7.conv', 'test_m7', in_hw=(4, 4))  # cout-tiling → PASS
```

#### 2. 完整网络 FPGA 测试

```python
# Dry-run（仅 numpy golden，不需要 FPGA）
python _l4_full_network_test.py --dry-run

# FPGA 执行（逐层上板验证）
python _l4_full_network_test.py

# 指定停止位置
python _l4_full_network_test.py --stop-at model.5.conv
```

#### 3. INT16 模式验证

```bash
python _int16_test.py       # 基础 (14/15 PASS, 1-LSB rounding)
python _int16_ext_test.py   # 扩展 (大图 + cout-tiling, 全 PASS)
```

#### 4. ONNX 对应验证

```bash
python _onnx_vs_parsed.py   # 57/57 层参数 EXACT MATCH
python _onnx_e2e_verify.py  # 量化公式独立验证
```

#### 5. 检测头 (Host 端推理)

```python
from numpy_golden_net import run_yolov5n_golden
from detect_head import DetectHead
import numpy as np

# 全网络推理: backbone+neck(FPGA) + 检测头(host)
input_img = np.random.default_rng(42).integers(-128, 128, (320, 320, 3), dtype=np.int8)
acts = run_yolov5n_golden(input_img)

head = DetectHead('../../../model/yolov5n/parsed/weights')
preds = head.forward(acts['model.17'], acts['model.20'], acts['model.23'])
detections = head.postprocess(preds, conf_thres=0.25, iou_thres=0.45)
print(f"Detections: {len(detections)}")
```

#### 6. 端到端拓扑验证

```bash
python _e2e_topology_verify.py   # 19 个关键节点 byte-exact match
```

---

## 核心模块 API

### `ops.py` — 算子库

```python
class FPGAOps:
    """FPGA 算子：每次调用生成 golden + 指令 → XDMA 上板执行"""
    def conv(layer, name, in_hw, feat=None) -> np.ndarray      # 单层 conv
    def conv_tiled(layer, name, in_hw, feat=None) -> np.ndarray # cout-tiling (out_ch>128)
    def conv_oh_tiled(layer, name, in_hw, feat=None) -> np.ndarray  # OH-tiling (大图)

class HostOps:
    """Host 算子：纯 NumPy 实现"""
    def add(a, b) -> np.ndarray         # Residual add (INT8 clip)
    def concat(feats) -> np.ndarray     # Channel concat
    def maxpool(feat, k=5) -> np.ndarray  # MaxPool (SPPF)
    def upsample(feat, scale=2) -> np.ndarray  # Nearest upsample

class C3Block:
    """YOLOv5 C3 模块：自动分配 FPGA/Host 算子"""
    def __call__(feat, module_id, n) -> np.ndarray
```

### `numpy_golden_net.py` — 纯 NumPy 参考

```python
def run_yolov5n_golden(input_img_int8: np.ndarray) -> dict:
    """完整 YOLOv5n backbone+neck。返回各关键层 INT8 激活。"""
```

### `detect_head.py` — 检测头

```python
class DetectHead:
    def forward(feat_p3, feat_p4, feat_p5) -> List[np.ndarray]  # 3 scale raw preds
    def decode(preds, img_size=320) -> np.ndarray   # → (6300, 8) boxes
    def postprocess(preds, conf_thres, iou_thres) -> np.ndarray  # → NMS results
```

### `xdma_win.py` — FPGA 通信

```python
class ChipRunnerWin:
    def run_case(run_dir, staging="hbm") -> list[dict]  # 执行测试 case
    def xdma_write(addr, data)    # 写 FPGA 地址空间
    def xdma_read(addr, size)     # 读 FPGA 地址空间
    def compare_result(...)       # expected vs actual 字节级对比
```

---

## 硬件约束

| 参数 | 值 | 说明 |
|------|-----|------|
| DCIM_CH_IN | 64 | 每步处理的输入通道数 |
| DCIM_NUM_TILES | 8 | Tile 并行度 |
| DCIM_INT8_OUT_CH_PER_TILE | 16 | INT8 每 tile 输出通道 |
| DCIM_INT16_OUT_CH_PER_TILE | 8 | INT16 每 tile 输出通道 |
| 最大单 pass out_ch | 128 (INT8) / 64 (INT16) | 超过则 cout-tiling |
| DCIM_ACC_MAX | 80 | 最大 acc_depth |
| VPU_BUF | 8MB (双半区 4+4) | 单层最大激活缓冲 |
| IBUF per tile | 256KB | im2col 像素数限制 → OH-tiling |
| HBM | 容量充足 | 中间激活 + 权重暂存 |

### Tiling 策略

| 情况 | 策略 | 说明 |
|------|------|------|
| out_ch > 128 | cout-tiling | 分 N pass, 每 pass ≤128 ch |
| im2col pixels > IBUF limit | OH-tiling | 按输出行拆分, 分 tile 执行 |
| 两者同时 | 组合 | 先 OH-tiling, 每 tile 内 cout-tiling |

---

## 量化方案

```
ONNX (best.quant.onnx)
  ↓ 57/57 层参数 EXACT MATCH
parsed/ (weight_int8 + weight_scale + act_scale)
  ↓ 量化公式:
  │   accum_int32 = im2col(act_int8) × weight_int8
  │   dqa_fp32    = relu(accum × dqa_scale + dqa_bias)
  │   out_int8    = clamp(round(dqa_fp32 / act_scale), -128, 127)
  ↓
numpy_golden_net (320×320 全网络)
  ↓ 19 节点 byte-exact match
FPGA 硬件执行
```

- **W8A8**: INT8 权重 × INT8 激活
- **Per-channel**: dqa_scale 逐通道, act_scale 全层共用 (0.02354532)
- **Unsigned ReLU**: 输出 [0, 127]（signed=False, zero_point=0）
- **检测头 (model.24)**: 无 ReLU, 无再量化, 直接输出 FP32

---

## 测试现状总结

| 层级 | 覆盖内容 | 状态 |
|------|---------|------|
| L1 基础算子 | dcim_matmul, qa, dqa, im2col, mp, us, add | **PASS** ✅ |
| L2 大规模 DCIM | 真实层维度 (16~128ch) | **PASS** ✅ |
| L3 端到端 | conv_pipeline + mini_network (多算子链) | **PASS** ✅ |
| L4-A 逐层 | model.0~model.23 所有 57 层 conv | **PASS** ✅ |
| L4-B cout-tiling | out_ch=256, 2 pass × 128ch | **PASS** ✅ |
| L4-C 全网络 | 57 Conv + Concat + Add + US + MP | **PASS** ✅ |
| L4-D OH-tiling | 大 feature map (40×40 等) | **PASS** ✅ |
| L4-E INT16 | INT16 accumulation 模式 | **PASS** ✅ |
| L4-F ONNX 对应 | ONNX ↔ parsed ↔ golden ↔ FPGA | **EXACT MATCH** ✅ |
| L4-G 检测头 | model.24 host 实现 | **已实现** ✅ |

---

## ResNet18 支持（已验证 ✅）

### 结论：**完全支持，已跑通全网络 golden**

```bash
# 1. 解析 ONNX 量化权重
python model/resnet18/parse_resnet18.py   # → parsed/weights/ (20 层 NPZ)

# 2. Numpy golden 全网络 dry-run (224×224)
cd tests/chip/unit-tb
python _resnet18_test.py    # 全网络 20 层 + MaxPool + Add → (7,7,512) ✅

# 3. FPGA 兼容性验证
python _resnet18_fpga.py    # 6 个代表层 golden 验证 ✅
```

### 硬件兼容性

| 参数 | ResNet18 最大值 | 硬件限制 | 状态 |
|------|---------------|---------|------|
| acc_depth | 72 (layer4.x.conv2, 512ch 3×3) | 80 | ✅ OK |
| cout-tiling | 4 passes (layer4, 512ch) | 无限制 | ✅ OK |
| kernel | 7×7 (conv1 stem) | im2col 支持 | ✅ OK |
| stride | 1, 2 | 已支持 | ✅ OK |

### ResNet18 vs YOLOv5n 对比

| 维度 | YOLOv5n (320×320) | ResNet18 (224×224) | 差异 |
|------|-------------------|-------------------|------|
| Conv 层数 | 57 | 20 | 更少 |
| 最大 out_ch | 256 | 512 | 需更多 cout-tiling |
| 最大 in_ch | 256 | 512 | acc_depth 72 仍 < 80 |
| 特殊算子 | SPPF/Upsample/Concat | MaxPool 3×3/GAP | 已支持 |
| Residual | C3 block (add) | BasicBlock (add) | 同机制 |
| 检测头 | 3 scale 1×1 Conv | FC 1000-class | 均 host 实现 |

### 需注意的差异

1. **无 ReLU 层**: ResNet 的 BasicBlock 第二个 conv 无 ReLU（add 后才 ReLU）
   - DQA 时不置 relu_en → `flags=0x0`
   - 输出可为负值（INT8 signed）
2. **MaxPool 3×3 s2**: 需用 VPU MaxPool 或 host 实现
3. **Global AvgPool + FC**: host 端 `np.mean() + matmul`

### ResNet-50 扩展性

ResNet-50 Bottleneck 最大 `acc_depth = ceil(512*3*3/64) = 72`，同样满足。
out_ch=2048 时需 `2048/128 = 16` passes cout-tiling，无硬件限制。

---

## 已修复的 Bug

| # | 位置 | 问题 | 修复 |
|---|------|------|------|
| 1 | `uram_tdp_bytewrite.v` | im2col 输出 bit-flip / AXI 锁死 | rd_en 排除 write enable |
| 2 | `CDMA_Controller.sv` | 背靠背 CDMA 数据竞争 | COOLDOWN_CYCLES=2000 |
| 3 | `Global_VPU.v` | config_ready 过早 assert | READY_DELAY_CYCLES=12 |
| 4 | `golden_module_tb.py` | in_ch<16 CDMA 搬运量不足 | 对齐到 16B/pixel |
| 5 | `golden_module_tb.py` | DQA scratch 空间不足 (1×1 conv) | max(im2col, dqa_fp32) |
| 6 | `golden_module_tb.py` | im2col pad_h/pad_w 共用 bug | 分别使用 pad_h0/pad_w0 |
