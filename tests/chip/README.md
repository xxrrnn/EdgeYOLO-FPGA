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
├── unit-tb/                # ★ Windows 片上单元测试 (Jupyter)
│   ├── xdma_win.py         # Windows XDMA 驱动封装 (via xdma_rw.exe)
│   ├── gen_data.py         # 调用 module_tb golden 生成测试数据
│   └── run_unit_test.ipynb # 主 Notebook: 交互式片上测试
├── step0_single_layer/     # Phase 0: 单层验证
├── step1_resnet18_w8a8/    # Phase 1: ResNet18 W8A8 全网
├── step2_yolov5n_w8a8/     # Phase 2: YOLOv5n W8A8 全网
└── step3_w16a16/           # Phase 3: W16A16 双网络
```

## 快速开始

### 0. Windows 片上单元测试（推荐首次使用）

复用 `rtl/tb/lite_bd/module_tb/golden_module_tb.py` 的数据生成和验证逻辑，
通过 `tests/bin/xdma_rw.exe` 在 Windows 上直接与 FPGA 通信。

**前提**: FPGA 已烧录 bitstream, `xdma_info.exe` 能看到设备。

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
results = runner.run_case(run_dir)
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

### 1. 编译网络（全网推理）

```bash
# ResNet18 W8A8 全网
python tests/chip/compiler/compile.py --network resnet18 --out build/resnet18_w8a8 --full

# YOLOv5n W8A8 全网
python tests/chip/compiler/compile.py --network yolov5n --out build/yolov5n_w8a8 --full

# W16A16 模式
python tests/chip/compiler/compile.py --network resnet18 --out build/resnet18_w16 --full --mode int16
```

### 2. Dry-run 测试（无硬件）

```bash
python tests/chip/step1_resnet18_w8a8/run.py --dry-run
python tests/chip/step2_yolov5n_w8a8/run.py --dry-run
python tests/chip/step3_w16a16/run.py --dry-run
```

### 3. 板上测试

```bash
# 确保 XDMA 驱动已加载 (/dev/xdma0_h2c_0, /dev/xdma0_c2h_0)
python tests/chip/step1_resnet18_w8a8/run.py
python tests/chip/step2_yolov5n_w8a8/run.py
python tests/chip/step3_w16a16/run.py
```

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

| 段 | 地址 | 大小 | 说明 |
|----|------|------|------|
| HBM | 0x0_0000_0000 | 4GB | interleaved |
| tile_ibuf[t] | 0x1_0000_0000 + t×0x80000 | 512KB/tile | DCIM 输入缓冲 (4 tiles) |
| tile_obuf[t] | 0x1_0100_0000 + t×0x40000 | 256KB/tile | DCIM 输出缓冲 (4 tiles) |
| VPU_BUF | 0x1_0200_0000 | 8MB | VPU 特征图缓冲 |
| VPU WB | 0x1_0300_0000 | 32KB | Scale/Bias 参数 |
| INST_BRAM | 0x1_0400_0000 | 128KB | 指令存储 |
| VPU_AXI_Regs | 0x1_0500_0000 | 4KB | 控制/状态寄存器 |

### VPU_AXI_Regs 寄存器偏移

| 偏移 | 名称 | 方向 | 说明 |
|------|------|------|------|
| 0x04 | STATUS | R | [0] VPU ready |
| 0x38 | DECODER_CTRL | W | [0] 写 1 启动 decoder (脉冲) |
| 0x3C | INST_COUNT | RW | 指令总数 (32-bit words) |
| 0x40 | DECODER_STATUS | R | [0] busy, [1] done, [31] error |
