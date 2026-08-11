# ResNet / YOLO 端到端测试

本目录是端到端测试的唯一维护入口。根目录 `run.py` 仅作为兼容转发；模型、样例、
编译器、运行时和 Golden 代码都归档在这里，不再依赖原来的 `model/`、`examples/`
或 `tests/chip/` 路径。

## 目录

```text
TEST/end2end/
├── run.py                 统一 E2E 入口
├── model_inputs_manifest.json
├── EXAMPLES.md            COCO/ImageNet 样例来源与验收边界
├── yolo/
│   ├── model/             INT8 与原生 W16A16 PT/ONNX、解析权重
│   ├── examples/          COCO 输入及 manifest
│   ├── detect_head.py     YOLO 专用 host 检测头
│   └── run.py             YOLO 专用入口
├── resnet/
│   ├── model/             FP32/W8A8 ONNX、INT8 与 widened-INT16 解析权重
│   ├── examples/          ImageNet 输入及 manifest
│   ├── resnet_e2e.py      ResNet 专用图连接与前后处理
│   └── run.py             ResNet 专用入口
└── common/
    ├── compiler/          两种网络共用的 full-network compiler
    ├── runtime/           FPGA one-shot、特征比对和 host head
    ├── unit_tb/           前后处理及算子级 host 实现
    └── golden/            数值 Golden
```

板卡和不同测试分支共用的内容位于 `TEST/utils/`：统一路径、XDMA/HBM host 访问、
bitstream、XDMA 可执行文件和 benchmark/report helper。

## 常用命令

```powershell
# 无板卡：校验所有随附模型、图片、bitstream 和 SHA256
python TEST/end2end/run.py --self-check

# 也可使用根目录兼容入口
python run.py --self-check

# 分别执行网络/精度，避免把两种精度混成一条无法追溯的结果
python TEST/end2end/run.py --network yolo --yolo-precision int8
python TEST/end2end/run.py --network yolo --yolo-precision int16
python TEST/end2end/run.py --network resnet --resnet-precision int8
python TEST/end2end/run.py --network resnet --resnet-precision int16

# 网络专用入口（自动固定 --network）
python TEST/end2end/yolo/run.py --yolo-precision int8
python TEST/end2end/resnet/run.py --resnet-precision int8

# 编译器的 INT16 数据通路契约测试
python TEST/end2end/common/compiler/test_int16_contract.py
```

`--network all` 适合回归，但验收报告仍应按“网络 × 精度”保留四条独立结果。
YOLO 的 INT16 是原生 W16A16 QAT/ONNX；ResNet 的 INT16 是由 INT8 VAI 权重扩宽，
用于验证 INT16 硬件数据通路，不能表述为原生 INT16 精度模型。详见两个网络各自的
README。
