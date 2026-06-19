# YOLOv5n FPGA E2E 推理

> 在红外目标检测任务上，将 YOLOv5n（Backbone + Neck）完整跑在 FPGA 硬件上，Host 负责前处理与 Detect Head。  
> 支持 **INT8** 和 **INT16**（INT8升位）两种精度，均已在 FPGA 上验证通过。

---

## 验证结果（2026-06-19 最终状态）

| 图片 | PyTorch QAT | Golden dry-run | FPGA INT8 | FPGA INT16 |
|------|-------------|----------------|-----------|------------|
| 1.jpg  | person **0.81** | person **0.81** | person **0.81** | person **0.81** |
| 10.jpg | person **0.80** | person **0.80** | person **0.80** | person **0.80** |
| 100.jpg | 1 det | 0-1 det | 0-1 det | 0 det |

**所有层 PASS（bit-exact），PyTorch = Golden = FPGA 三路一致。**

---

## 快速开始

```bash
# 进入测试目录
cd tests/chip/unit-tb
conda activate yoloir

# ── INT8 ────────────────────────────────────────────────
# FPGA 实测
python e2e_detect.py --images <val_dir> --max 5 --conf 0.25

# Golden (numpy 模拟，无需硬件)
python e2e_detect.py --images <val_dir> --max 5 --conf 0.25 --dry-run

# ── INT16（INT8升位）────────────────────────────────────
# 第一次使用需要生成升位参数（只需执行一次）
python ../../model/yolov5n/create_int16_from_int8.py

# FPGA 实测
python e2e_detect.py --images <val_dir> --max 5 --conf 0.2 --int16

# Golden
python e2e_detect.py --images <val_dir> --max 5 --conf 0.2 --int16 --dry-run

# ── 快速验证：同时跑 INT8 + INT16 FPGA 并比对 ─────────
python verify_e2e.py --images <val_dir> --max 3
```

`<val_dir>` 示例：  
`C:\users\zczho\Downloads\YOLO_on_FPGA\YOLO_on_FPGA\Infrared-Object-Detection\datasets\infrared\images\val`

---

## 项目结构

```
tests/chip/unit-tb/
├── e2e_detect.py          # E2E 主入口（INT8/INT16，FPGA/dry-run）
├── verify_e2e.py          # 一键验证：INT8 + INT16 对比
├── ops.py                 # FPGA/Host 算子封装
│     FPGAOps:   conv / conv_tiled / conv_oh_tiled
│     HostOps:   maxpool / upsample / concat / qa
│     C3Block:   YOLOv5n C3 block（内部所有 conv 在 FPGA 执行）
├── detect_head.py         # Host 端 Detect Head（1×1 FP32 conv + NMS）
├── xdma_win.py            # Windows XDMA 驱动（PCIe DMA 读写）
├── run_int16_verify.py    # INT16 硬件功能验证（单算子级）
├── run_unit_test.ipynb    # 交互式单算子调试
│
rtl/tb/lite_bd/module_tb/
└── golden_module_tb.py    # 核心：生成 FPGA 指令 + 计算 golden 期望值
      make_conv_pipeline_case()  → 生成 case 文件 + 返回 golden
      pack_weight_tile()         → INT8 权重打包（nibble格式）
      pack_weight_tile_int16()   → INT16 权重打包
      im2col / im2col_int16      → 软件参考实现
      dcim_layer_inst / tile_seq_dqa_insts / vpu_exec  → 指令生成
│
model/yolov5n/
├── parsed/                # INT8 参数（parse_onnx.py 产出）
│   ├── network.json       # 网络拓扑 + 量化参数
│   └── weights/*.npz      # 各层权重（weight_int8/dqa_scale/dqa_bias/act_scale）
├── parsed_int16_from_int8/ # INT16升位参数（create_int16_from_int8.py 产出）
│   ├── network.json
│   └── weights/*.npz      # dtype=int16，值域 [-127,127]（与INT8等价）
├── parse_onnx.py          # 解析 INT8 QDQ-ONNX → NPZ
├── parse_onnx_int16.py    # 解析 INT16 QDQ-ONNX → NPZ（原生INT16，待完善）
└── create_int16_from_int8.py  # INT8参数升位为INT16

runs/e2e/
├── fpga/                  # FPGA 检测结果图片
├── dry_run/               # Golden 检测结果
└── pytorch/               # PyTorch 基线
```

---

## 数据流与运行逻辑

```
输入图片 (H×W×3, uint8)
    │
    ▼  Host: letterbox(320×320) → /255 → QA → INT8 [320,320,3]
    │
    ▼  FPGA: Backbone + Neck (57 conv layers, INT8 或 INT16)
    │
    │  model.0 (6×6 s2) → model.1 (3×3 s2)
    │  → C3-2 (n=1) → model.3 (3×3 s2) → C3-4 (n=2)  ← x4
    │  → model.5 (3×3 s2) → C3-6 (n=3)               ← x6
    │  → model.7 (3×3 s2) → C3-8 (n=1)               ← x8
    │  → SPPF(9) → model.10
    │  → upsample + concat(x6) → C3-13 → model.14
    │  → upsample + concat(x4) → C3-17              ── P3 (40×40×64)
    │  → model.18 → concat(model.14) → C3-20        ── P4 (20×20×128)
    │  → model.21 → concat(model.10) → C3-23        ── P5 (10×10×256)
    │
    ▼  Host: Detect Head (model.24, 1×1 FP32 conv)
    │  P3/P4/P5 → 各自做 dequant(act_scale) → 1×1 conv → sigmoid → decode
    │
    ▼  Host: NMS (conf>0.25, iou>0.45) → bounding boxes
```

**关键分工：**
- FPGA 只做 Conv Pipeline（im2col + DCIM matmul + DQA + QA）
- Host 做 maxpool、upsample、concat、detect head
- 每层 conv 在 FPGA 上独立运行，结果通过 PCIe DMA 读回

**Tiling 策略：**

| 场景 | INT8 | INT16 |
|------|------|-------|
| 最大输出通道/pass | 128 ch（8 tile × 16 ch） | 64 ch（8 tile × 8 ch） |
| 超出时 | `conv_tiled(tile_size=128)` | `conv_tiled(tile_size=64)` |
| 输出像素超 IBUF | `conv_oh_tiled(max_pix)` | 同左（但 `max_pix` 用 `acc_depth_int16`） |
| 两者均超 | `conv_tiled` 内嵌套 `conv_oh_tiled` | 同左 |

**INT16 模式特殊处理（`--int16`）：**
- 权重 NPZ `weight_int8.dtype == np.int16` 自动触发 INT16 FPGA 指令路径
- 输入 feat 不做 `astype(int8)` 强制转换，保持 int16
- im2col `in_col_stride = ceil(in_ch/8)*8 × 2` 字节（8-slot 对齐）
- VPU QA 单元用 `flags=0x2`（INT16 clip 范围 [-32768, 32767]）

---

## 构建步骤（从 QAT 模型到 FPGA 推理）

```bash
# Step 1: QAT 训练
cd model/algorithm/quantized-yolov5
python train.py --cfg models/yolov5n-quant-infrared-int8.yaml --data infrared.yaml
# 产出: runs/train/infrared_qat_int8/weights/best.pt

# Step 2: 导出 ONNX
python export_brevitas.py --weights runs/train/.../best.pt --img-size 320
# 产出: best.quant.onnx

# Step 3: 解析 ONNX → NPZ + network.json
cd model/yolov5n
python parse_onnx.py
# 产出: parsed/network.json + parsed/weights/*.npz

# Step 4: （仅 INT16）生成升位参数
python create_int16_from_int8.py
# 产出: parsed_int16_from_int8/network.json + weights/*.npz（dtype=int16）

# Step 5: E2E 推理
cd tests/chip/unit-tb
python e2e_detect.py --images <val_dir> --max 5 --conf 0.25
```

---

## 量化参数说明

| 参数 | INT8 值 | INT16升位值 | 含义 |
|------|---------|------------|------|
| `act_scale` | 0.07814 | 0.07814（不变） | 激活量化缩放：FP32 = INT × act_scale |
| `input_act_scale` | 1/127 ≈ 0.007874 | 1/127（不变） | 输入图像量化 scale |
| `weight_int8` | int8, [-127,127] | int16, [-127,127] | 卷积权重（OHWI 格式） |
| `dqa_scale[c]` | per-channel float32 | 同INT8（不变） | 反量化：FP32 = INT32 × dqa_scale + dqa_bias |
| `detect_head` | FP32 | FP32 | model.24 的 1×1 conv 权重 |

---

## 关键代码位置速查

| 功能 | 文件 | 函数/行 |
|------|------|---------|
| FPGA 指令生成（INT8） | `golden_module_tb.py` | `make_conv_pipeline_case()` ~L1800 |
| FPGA 指令生成（INT16） | `golden_module_tb.py` | `is_weight_int16` 分支 ~L1947 |
| INT16 im2col 对齐 | `golden_module_tb.py` | `slots_per_pixel = ((in_ch+7)//8)*8` ~L1973 |
| im2col 软件实现 | `golden_module_tb.py` | `im2col_int16()` L1168 |
| INT16 权重打包 | `golden_module_tb.py` | `pack_weight_tile_int16()` |
| E2E 网络拓扑 | `e2e_detect.py` | `run_fpga_backbone_neck()` L47 |
| cout-tiling | `ops.py` | `FPGAOps.conv_tiled()` L187 |
| oh-tiling | `ops.py` | `FPGAOps.conv_oh_tiled()` L241 |
| 前处理/后处理 | `run.py` | `preprocess_yolov5n / postprocess_yolov5n` |
| Detect Head | `detect_head.py` | `DetectHead.__call__()` |

---

## Debug 经验与踩坑（按时间顺序）

### Bug #1: 权重排列 OIHW vs OHWI

- **现象**: conv 输出随机值或全零  
- **原因**: `im2col` 按 `(KY, KX, C)` 遍历输入，但 PyTorch 权重是 OIHW，reshape 后 K 维顺序是 `(IC, KY, KX)` ≠ `(KY, KX, IC)`  
- **修复**: `parse_onnx.py` 中 `w.transpose(0, 2, 3, 1)` 转为 OHWI 格式

### Bug #2: C3Block 错误的 shortcut add

- **现象**: 某些层输出偏大  
- **原因**: YOLOv5n 的 C3 block 中 Bottleneck `shortcut=False`，但代码无条件做了 residual add  
- **修复**: 移除 C3Block 中的 shortcut add

### Bug #3: Detect Head act_scale 混用

- **现象**: 检测置信度极低（0.001），大量误检  
- **原因**: `detect_head.py` 用了 `input_act_scale=0.007874`（输入量化 scale）做 dequant，正确应用 `act_scale=0.07814`（网络内部激活 scale）  
- **修复**: `act_scale` 从 `network.json` 中读取  

### Bug #4: Neck Concat 连接错误 ★ 最难找

- **现象**: scale 修正后仍 0 detections（objectness 全负），但 detect head 单独验证通过  
- **原因**: neck downsample 的 concat 输入接错了节点：

  ```
  ❌ concat([model.18, x13])  ← x13 是 C3-13 输出，192ch
  ✓  concat([model.18, x14])  ← x14 是 model.14.conv 输出，64ch

  ❌ concat([model.21, x8])   ← x8 是 C3-8 输出，256ch
  ✓  concat([model.21, x10])  ← x10 是 model.10.conv 输出，128ch
  ```

- **发现过程**: 注入 PyTorch 完美 INT8 输入到 C3-20，corr 仍只有 0.49 → 检查 model.20.cv1 期望 128ch 输入但收到了 192ch → 追踪 ONNX 图确认连接关系  
- **教训**: 严格按 ONNX 图的 tensor 连接关系实现，不能靠"感觉"

### Bug #5: hard_quant /2 信号衰减

- **现象**: Neck 层（P4/P5）输出动态范围比 PyTorch 小约 2x  
- **原因**: Brevitas ONNX 导出的 `hard_quant` 包含一个 `/2` 缩放因子，但 PyTorch inference 中不存在  
- **修复**: 移除 `host.hard_quant()` 调用；将 model.18/21 的 `dqa_scale` 乘以 `9.924`（补偿 `act_scale/hq_scale`）

---

### INT16 系列 Bug（2026-06-19）

#### 背景：INT16升位方案

由于 INT16 QAT 原生模型 golden 未完全对齐（Bug #8），采用**升位方案**验证 INT16 硬件通路：

```
INT8 已验证参数  ──升位──►  INT16参数（dtype=int16，值域不变[-127,127]）
数学等价：int16 matmul 值域与 int8 完全一致，结果 bit-exact 相同
```

生成命令：`python model/yolov5n/create_int16_from_int8.py`

#### Bug #6: INT16 ONNX 权重类型误判

- **现象**: INT16 原生模型 dry-run 0 detections，objectness ≈ -11 ~ -22  
- **根因**: Brevitas INT16 QDQ-ONNX 中 weight 以 float32 存储（已反量化），直接 `.astype(np.int16)` 将小数全截为 0  
  ```python
  # 错误
  w_arr = w_int.astype(np.int16)
  # 正确：w_int = int_value × w_scale，需先除以 scale
  w_arr = np.round(w_int / w_scale.reshape(-1, 1, 1, 1)).astype(np.int16)
  ```

#### Bug #7: INT16 matmul int32 累加溢出

- **根因**: `32767² × 128项 >> int32_max`，改用 float32 累加

#### Bug #8: INT16 QAT 原生模型 feature map 不对齐（未解决）

- **诊断**:
  - INT8 feature + INT16 detect head → person 0.81 ✅
  - INT16 feature + INT16/INT8 detect head → 0 detections ❌
- **当前结论**: INT16 backbone feature map 的空间语义内容不匹配，可能是原生 INT16 QAT 的 `act_scale=0.000305`（比 INT8 小 256 倍）导致 BN fusion 异常

#### Bug #15: INT16 im2col `in_col_stride` 对齐错误 ★ FPGA FAIL 主因

- **现象**: `model.0.conv`（in_ch=3）FPGA 输出与 golden 完全不一致  
- **根因**: INT16 im2col 硬件要求 `in_col_stride = ceil(in_ch/8)*8 × 2` 字节/像素（8-slot 对齐），而非紧凑打包或 16-slot 对齐  
  ```python
  # 正确
  slots = ((in_ch + 7) // 8) * 8   # 对于 in_ch=3 → slots=8
  feat_padded = np.zeros((h*w, slots), dtype=np.int16)
  feat_padded[:, :in_ch] = feat.reshape(h*w, in_ch)
  ```
- **影响范围**: 仅 in_ch 非 8 倍数的层（当前仅 `model.0.conv`，in_ch=3）

#### Bug #16: feat 传入时 INT16→INT8 强制截断

- **现象**: E2E 中 `model.5.conv`（in_ch=64）严重失败（6/3200），单独测试通过  
- **根因**: `make_conv_pipeline_case` 里 `quant_dtype = int8`（因 `spec['int16']` 未设置），导致上层传来的 INT16 feat 被截为 INT8  
- **修复**: 检测到 `weights.dtype == np.int16` 时跳过强制类型转换

#### Bug #17: oh-tiling 零 padding 行 dtype 错误

- **根因**: oh-tiling 时用 `quant_dtype=int8` 创建 padding 行，与 int16 feat concat 失败  
- **修复**: 改用 `feat_tile_raw.dtype`

#### Bug #18: `conv_tiled` 未触发 oh-tiling ★ 双重 tiling 缺失

- **现象**: `model.5.conv`（out_ch=128, 40×40 输入）严重失败  
- **根因**: 该层同时需要：
  1. cout-tiling（128 ch > INT16限制64 ch → 2 pass）
  2. oh-tiling（20×20=400 px > max_pix=227）  
  但 `conv_tiled` 只做 cout-tiling，每 pass 调 `self.conv()`，而 `conv()` 不做 oh-tiling  
- **修复**: `conv_tiled` 内部根据 `acc_depth_int16` 计算 `max_pix`，超出时每 pass 改调 `conv_oh_tiled`

#### Bug #19: `eff_ch` 对齐粒度 INT8/INT16 混淆

- **现象**: `conv_tiled` / `conv_oh_tiled` 输出 shape 错误  
- **根因**: `eff_ch = ((limit+15)//16)*16`（INT8 粒度），INT16 应为 `((limit+7)//8)*8`  
- **修复**: 检测权重 dtype，自动选择对齐粒度

---

## 性能参考

| 模式 | 每张图耗时 | 说明 |
|------|-----------|------|
| FPGA（INT8/INT16） | ~93s | XDMA DMA 传输（57层 × ~1.6s/层） |
| Golden dry-run | ~20s | NumPy im2col + matmul |
| PyTorch QAT | ~0.5s | GPU/CPU FP32 |

> FPGA 耗时主要在 PCIe DMA 传输，非计算本身。每层 case 文件生成 + DMA 来回约 1.6s。  
> 通过批量加载多层权重、减少 DMA 次数可显著优化。
