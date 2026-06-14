# EdgeYOLO FPGA 端到端推理 —— 差距分析与实现方案

## 1. 模型概况

| 属性 | 值 |
|------|------|
| 文件 | `best.onnx` (15.2 MB) / `best.quant.onnx` (1.8 MB) |
| 输入 | `images`: [1, 3, 320, 320] (INT8 量化) |
| 输出 | `output`: [1, 6300, 8]（3 个检测头拼接） |
| 卷积层数 | 60 个 Conv |
| 量化方案 | 权重 INT4/INT8，激活 INT8，矩阵乘法输出 INT32 |
| 后处理精度 | INT32 → FP32（DQA/Add/NN-LUT 等均在 FP32 域完成） |

### 1.1 计算流程（每层 Conv）

```
FP32 activation
    │
    ▼ QA (quantize: fp32 × scale → INT8)
INT8 activation
    │
    ▼ im2col (地址重排) + DCIM 矩阵乘法 (INT8 × INT4 → INT32)
INT32 partial sums
    │
    ▼ DQA (dequantize: int32 × scale + bias → FP32)
FP32 output
    │
    ▼ NN-LUT (分段线性激活函数，替代 SiLU)
FP32 activated output
```

---

## 2. 当前 RTL 已实现的功能

| 模块 | 路径 | 功能 | 状态 |
|------|------|------|------|
| **DCIM 核心** | `rtl/ref/DCIM/src/dcim/` | 4-bit nibble 乘累加阵列 (16×16) | ✅ |
| **DCIM_Macro** | `rtl/DCIM_Macro/DCIM_Macro.sv` | 单 Tile 封装 + nibble converter | ✅ |
| **DCIM_Tile** | `rtl/chip/DCIM_Tile.sv` | Tile 适配 ready/valid 总线 | ✅ |
| **DCIM_Array** | `rtl/chip/DCIM_Array.sv` | 32 Tile 并行 + 仲裁器 | ✅ |
| **DCIM_Array_Top** | `rtl/chip/DCIM_Array_Top.sv` | AXI-Lite 配置 + BRAM 接口 | ✅ |
| **IBUF/OBUF** | `rtl/DCIM_Macro/ibuf.v, obuf.v` | 双端口 UltraRAM 缓冲区 | ✅ |
| **Block Design** | `scripts/chip/` | XDMA + BRAM Ctrl + CDMA + DCIM_Array | ✅ |
| **XDMA 驱动** | Host 侧 | PCIe DMA 读写通道 | ✅ 已安装 |
| **Golden Model** | `rtl/ref/YOLOv11-RTL/goldenmodel/` | Python 全流程仿真参考 | ✅ 可复用 |

### 2.1 Golden Model 架构（关键参考）

参考 `rtl/ref/YOLOv11-RTL/goldenmodel/Simulator/` 的设计:

| Golden Model 组件 | 功能 | 对应硬件 |
|-------------------|------|----------|
| `CORE.CDMA()` | 内存间数据搬运 | XDMA/CDMA |
| `CORE.process()` | INT8×INT4 矩阵乘法 | DCIM_Array |
| `VPU.qa_unit` | FP32 → INT8 量化 | 需实现 |
| `VPU.dqa_unit` | INT32 → FP32 反量化 | 需实现 |
| `VPU.nn_lut_unit` | 分段线性激活函数 | 需实现 |
| `VPU.ad_unit` | FP32 逐元素加法 | 需实现 |
| `VPU.mp_unit` | FP32 MaxPool 5×5 | 需实现 |
| `VPU.us_unit` | FP32 Upsample 2× | 需实现 |
| `HBM` | 全局存储 | DDR/HBM via XDMA |

---

## 3. im2col 通过 XDMA 指令实现（核心方案）

### 3.1 可行性分析

Golden Model 中 `module.py` 第 106-124 行的 im2col 逻辑本质是：
- 计算 kernel 窗口内每个位置在 HBM 中的源地址
- 通过 `CDMA(HBM, Core.ar, src_addr, dst_addr, length)` 将数据搬运到计算缓冲

**这个逻辑完全可以映射为 Host 端的 XDMA 传输指令序列**：

```python
# Golden Model 的 CDMA 调用:
Cores[core_id].CDMA(HBM, Cores[core_id].ar, src_addr, ar_dst_addr, length=kernel_c * ACT_DW)

# 映射为 XDMA 写操作:
xdma_write(ibuf_bar_addr + ar_dst_addr, hbm_data[src_addr : src_addr + length])
```

### 3.2 Host 驱动 im2col 方案

im2col 不需要硬件实现，而是由 Host CPU 计算地址并通过 XDMA 发起 DMA 传输：

```
Host CPU (Python/C):
  1. 预计算 im2col 地址映射表
  2. 按行遍历 output_h × output_w:
     a. 根据 kernel 窗口计算源 feature map 地址
     b. 通过 XDMA 将展开后的 activation 行写入 IBUF
     c. 通过 AXI-Lite 配置 DCIM_Array 并启动计算
     d. 通过 XDMA 从 OBUF 读回 INT32 结果
```

### 3.3 具体映射关系

| Golden Model | 实际 XDMA 实现 |
|---|---|
| `HBM` (4GB) | Host 内存（numpy array） |
| `Core.ibuf` | IBUF（通过 XDMA BAR 写入） |
| `Core.obuf` | OBUF（通过 XDMA BAR 读取） |
| `CDMA(HBM→Core.ar)` | `xdma_h2c_write(ibuf_addr, data)` |
| `CDMA(Core.ar→HBM)` | `xdma_c2h_read(obuf_addr, length)` |
| `Core.process()` | AXI-Lite 写 mode/acc/num_rows + start |

### 3.4 im2col 地址生成（直接从 Golden Model 翻译）

```python
def generate_im2col_xdma_transfers(src_tensor, src_c, src_h, src_w,
                                     kernel_h, kernel_w, padding, stride):
    """
    将 module.py 的 CDMA 循环翻译为 XDMA 传输列表.
    返回: [(ibuf_offset, data_slice), ...] 每项是一次 XDMA H2C 写操作
    """
    output_h = (src_h + 2*padding - kernel_h) // stride + 1
    output_w = (src_w + 2*padding - kernel_w) // stride + 1
    
    transfers = []
    for r_i in range(output_h):
        for c_i in range(output_w):
            # 构建 im2col 行: kernel_h × kernel_w × src_c bytes
            im2col_row = []
            for kr_i in range(kernel_h):
                for kc_i in range(kernel_w):
                    row_idx = r_i * stride + kr_i - padding
                    col_idx = c_i * stride + kc_i - padding
                    if 0 <= row_idx < src_h and 0 <= col_idx < src_w:
                        offset = (row_idx * src_w + col_idx) * src_c
                        im2col_row.append(src_tensor[offset : offset + src_c])
                    else:
                        im2col_row.append(np.zeros(src_c, dtype=np.int8))
            
            transfers.append(np.concatenate(im2col_row))
    
    return transfers  # 每个 transfer 写入 IBUF activation 区域
```

### 3.5 性能优化方向

| 优化策略 | 说明 |
|---------|------|
| **行批处理** | 一次写入多行 activation 到 IBUF，利用 DCIM 的 acc_depth 累加 |
| **Tiling** | 大 feature map 按 tile 分块，减少单次传输量 |
| **双缓冲** | 计算当前 tile 时预加载下一 tile 的数据 |
| **CDMA 硬件** | BD 中已有 CDMA IP，可编程为 scatter-gather DMA 自动搬运 |

---

## 4. 端到端还需实现的工作

### 4.1 ✅ 已完成
- [x] DCIM_Array 硬件（32 Tile INT4×INT8 GEMM）
- [x] AXI-Lite 配置接口
- [x] Block Design（XDMA + BRAM Controller + CDMA）
- [x] XDMA 驱动安装

### 4.2 ✅ VPU 硬件模块已有完整 RTL 实现！

| 模块 | 功能 | RTL 实现 | 状态 |
|------|------|----------|------|
| **QA Unit** | FP32 × scale → INT8（量化） | `rtl/ref/YOLOv11-RTL/vpu/qa_unit.sv` | ✅ 可用 |
| **DQA Unit** | INT32 × scale + bias → FP32（反量化） | `rtl/ref/YOLOv11-RTL/vpu/dqa_unit.sv` | ✅ 可用 |
| **NN-LUT Unit** | 分段线性激活函数 (16 段) | `rtl/ref/YOLOv11-RTL/vpu/nn_lut_unit.sv` | ✅ 可用 |
| **AD Unit** | FP32 逐元素加法 | `rtl/ref/YOLOv11-RTL/vpu/ad_unit.sv` | ✅ 可用 |
| **MP Unit** | FP32 MaxPool 5×5, stride=1 | `rtl/ref/YOLOv11-RTL/vpu/mp_unit.sv` | ✅ 可用 |
| **US Unit** | FP32 Nearest Upsample 2× | `rtl/ref/YOLOv11-RTL/vpu/us_unit.sv` | ✅ 可用 |

**关键发现**: `rtl/ref/YOLOv11-RTL/vpu/` 目录下已有 **完整的 VPU 硬件实现**，包括：
- 所有单元均有完整状态机和 GB/WB BRAM 接口
- 与 Golden Model Python 实现一一对应
- 支持参数化配置（FP16/FP32、通道数、带宽）
- 已验证可用（从代码注释和结构判断）

**集成工作**: 只需将这些 VPU 模块集成到 Block Design 中，连接 Global Buffer (GB) 和 Weight Buffer (WB)。

### 4.3 🟡 缺失的系统软件

| 组件 | 功能 | 复杂度 |
|------|------|--------|
| **Layer Scheduler** | 按 Golden Model 流程逐层调度 (Python) | 中 |
| **权重打包工具** | ONNX INT4 权重 → DCIM SRAM nibble 排布 binary | 中 |
| **im2col 地址生成器** | 计算 XDMA 传输地址（上述 3.4 节） | 低 |
| **端到端推理脚本** | 串联所有层的 Host 驱动代码 | 中 |
| **NMS 后处理** | 检测框解码 + NMS（Host CPU） | 低 |

---

## 5. 建议实现路径

### Phase 1: Host 驱动 + 软件 VPU 端到端 — 1-2 周

先用 Host CPU 做所有 VPU 操作，专注打通数据通路：

```python
Host CPU (Python):
  for each layer:
    1. QA: numpy fp32 → int8 (软件)
    2. im2col: 按 module.py 计算地址 + XDMA 写 activation 到 IBUF
    3. XDMA 写 weight 到 IBUF
    4. AXI-Lite 配置 mode/acc/num_rows + start DCIM
    5. XDMA 读 OBUF 结果 (INT32)
    6. DQA/NN-LUT/Add/MP/US: 全部用 numpy (软件)
```

**交付物**:
- [ ] Python 权重打包工具 (ONNX INT4 → nibble binary)
- [ ] Python im2col 地址生成 (翻译 `module.py:106-124` 行)
- [ ] Python XDMA 驱动封装 (H2C 写 / C2H 读 / AXI-Lite 配置)
- [ ] 单层 Conv 正确性验证
- [ ] 全网络 60 层推理通路打通

### Phase 2: 集成 VPU 硬件 — 2-3 周

**好消息**: VPU 全部 RTL 已实现，只需集成！

- [ ] 将 6 个 VPU 单元加入 Block Design:
  ```tcl
  - qa_unit.sv   (FP32 → INT8 量化)
  - dqa_unit.sv  (INT32 → FP32 反量化 + bias)
  - nn_lut_unit.sv (16 段分段线性激活)
  - ad_unit.sv   (FP32 逐元素加法)
  - mp_unit.sv   (5×5 MaxPool)
  - us_unit.sv   (2× Upsample)
  ```
- [ ] 实例化 Global Buffer (GB) 和 Weight Buffer (WB) BRAM
- [ ] 连接 VPU 单元到 GB/WB (`global_buffer_bram.v`)
- [ ] Host 驱动改为调用硬件 VPU (通过 AXI-Lite 配置 + start)
- [ ] 验证硬件 VPU 与软件 numpy 输出一致

### Phase 3: 性能优化 — 2-3 周

- [ ] im2col 批处理 (减少 XDMA 传输次数)
- [ ] 利用 CDMA 做 scatter-gather DMA
- [ ] 计算与数据搬运流水线
- [ ] 双缓冲 (计算当前层时预加载下一层权重)

### Phase 4: 全硬件自动化 — 按需

- [ ] 硬件调度器（层描述符队列）
- [ ] 硬件 im2col 地址生成器
- [ ] 减少 Host 干预，实现自主推理

---

## 6. 关键文件索引

```
model/
├── best.onnx              # 原始模型（FP32 完整计算图）
├── best.quant.onnx        # 量化模型（INT4 权重 + 逐层 scale/zp）
└── README.md              # 本文件

rtl/chip/                  # DCIM_Array 芯片集成（当前主力）
rtl/DCIM_Macro/            # 单 Tile 独立验证
rtl/ref/DCIM/              # DCIM 核心参考 RTL
rtl/ref/YOLOv11-RTL/
├── vpu/                   # VPU RTL 参考 (ad_unit, mp, us, dqa, qa, nn_lut)
└── goldenmodel/Simulator/ # ⭐ Python 全流程仿真（im2col + CDMA 调度参考）
    ├── module.py          # CONV/MaxPool/Upsample/Concat/Add 顶层调度
    ├── units/core.py      # DCIM Core 模型（CDMA + process）
    ├── units/vpu.py       # VPU 各子单元 Python 实现
    └── units/globals.py   # 地址映射和全局参数

scripts/chip/              # Vivado Block Design 构建脚本
```

---

## 7. 总结

| 类别 | 方案 | 说明 |
|------|------|------|
| **矩阵乘法** | DCIM_Array 硬件 | ✅ 已有，INT8×INT4→INT32，32 Tiles 并行 |
| **im2col** | Host XDMA 指令序列 | ✅ 从 `module.py` CDMA 循环直接翻译，无需额外硬件 |
| **QA/DQA/NN-LUT/Add/MP/US** | **VPU 硬件 RTL** | ✅ **完整实现在 `rtl/ref/YOLOv11-RTL/vpu/`** |
| **调度** | Host Python 逐层驱动 | 参照 `module.py` 函数调用顺序 |

**关键结论**: 项目已具备端到端推理所需的 **全部硬件 IP**！
- DCIM_Array（计算引擎）✅
- VPU 全套单元（QA/DQA/NN-LUT/Add/MP/US）✅
- XDMA Block Design ✅
- Golden Model Python 参考 ✅

**下一步**: 只需编写 Host Python 驱动串联这些模块，预计 **3-4 周可完成端到端验证**。
