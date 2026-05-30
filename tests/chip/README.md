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
│   ├── xdma_driver.py      # XDMA 驱动封装
│   └── hw_runner.py        # 高层运行器
├── golden/                 # Golden 参考脚本
├── step0_single_layer/     # Phase 0: 单层验证
├── step1_resnet18_w8a8/    # Phase 1: ResNet18 W8A8 全网
├── step2_yolov5n_w8a8/     # Phase 2: YOLOv5n W8A8 全网
└── step3_w16a16/           # Phase 3: W16A16 双网络
```

## 快速开始

### 1. 编译网络

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

## 地址映射

| 段 | 地址 | 大小 |
|----|------|------|
| IBUF | 0x1_0000_0000 | 2MB |
| OBUF | 0x1_0100_0000 | 16MB |
| WB | 0x1_0200_0000 | 32KB |
| INST | 0x1_0300_0000 | 128KB |
| REGS | 0x1_0400_0000 | 4KB |
