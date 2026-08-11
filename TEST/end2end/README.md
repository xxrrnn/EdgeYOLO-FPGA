# ResNet / YOLO 端到端测试

本目录是端到端测试的唯一维护入口。根目录 `run.py` 仅作为兼容转发；模型、样例、
编译器、运行时和 Golden 代码都归档在这里，不再依赖原来的 `model/`、`examples/`
或 `tests/chip/` 路径。

## 目录

```text
TEST/end2end/
├── run.py                 统一 E2E 入口
├── model_inputs_manifest.json
├── README.md              本文件（唯一文档入口）
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
├── common/
│   ├── compiler/          两种网络共用的 full-network compiler
│   ├── runtime/           FPGA one-shot、特征比对和 host head
│   ├── unit_tb/           前后处理及算子级 host 实现
│   └── golden/            数值 Golden
└── output/                本目录运行产物（compiled / inference / acceptance）
```

板卡和不同测试分支共用的内容位于 `TEST/utils/`：统一路径、XDMA/HBM host 访问、
bitstream、XDMA 可执行文件和 benchmark/report helper。

编译产物默认落在 `TEST/end2end/output/compiled/`，推理与可视化在
`TEST/end2end/output/inference/`，`--acceptance` 报告在
`TEST/end2end/output/acceptance/`。可用 `--out-dir` 覆盖推理/验收输出根目录。

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
用于验证 INT16 硬件数据通路，不能表述为原生 INT16 精度模型。

默认 YOLO smoke 图为 `yolo/examples/000000000139.jpg`；在 `conf=0.15` /
`iou=0.45` 下 host head 期望检出 **5** 个框（与 Python golden 一致）。可用
`--one-shot-yolo-expect-detections -1` 关闭个数门禁，或传其他正整数覆盖。

## 硬件 / 编译器入口

本树包含维护中的 full-network compiler、软件 golden、Windows XDMA runtime、
host 侧 YOLO/ResNet head，以及面向 `80832ec_attempt1` release 的 RTL 支持测试。

关键入口：

- `common/compiler/compile.py`：parsed model → FPGA program/weights/WB
- `common/compiler/test_int16_contract.py`：原生 W16A16 signed-INT64 layout 契约
- `common/compiler/check_release_repro.py`：四条维护 workload 各编译两次
- `common/runtime/hw_runner_win.py`：经 XDMA 上传并执行 one-shot
- `common/runtime/compare_one_shot.py`：FPGA 特征 vs compiler golden
- `common/runtime/one_shot_host_head.py`：YOLO Detect/NMS 与 ResNet GAP/FC/Top-k

生成的 compiler / runtime 产物放在 `TEST/end2end/output/`，不入库。日常操作使用
仓库根目录或本目录的 `run.py`。

## 验收样例

- `yolo/examples/`：20 张来自官方 COCO 2017 val 的图片及 SHA/来源 manifest
- `resnet/examples/`：20 张公开 ImageNet-1k class 样例（class ID / synset 在 manifest）

这是紧凑功能测试集，用于验证 FPGA/compiler 一致性并跑通 host head；规模不足以
宣称 COCO mAP 或 ImageNet Top-1。完整验收：

```powershell
python TEST/end2end/run.py --acceptance
```

会按所选网络跑 INT8 与对应 INT16 模式。

## YOLO 资产

- `yolo/model/int8/`：W8A8 QAT 的 PT、普通 ONNX 和 FPGA quant ONNX
- `yolo/model/int16/`：原生 W16A16 QAT 的 PT、普通 ONNX 和 FPGA quant ONNX
- `yolo/model/parsed_int8/`、`yolo/model/parsed_int16/`：compiler 直接使用的网络描述与 NPZ
- `yolo/examples/`：20 张 COCO val2017 输入及 manifest
- `yolo/detect_head.py`：YOLO 专用 host 检测头；`yolo/run.py` 只跑 YOLO

INT8 与 INT16 必须分别运行并分别出结果；一次 `--yolo-precision both` 可连续执行，
但报告中仍需保留两组独立的数值正确性、检测结果和耗时证据。

## ResNet 资产

- `resnet/model/resnet18_fp32.onnx`：FP32 参考图
- `resnet/model/resnet18_w8a8.onnx`：W8A8 QDQ 图
- `resnet/model/parsed_vai/`：当前原生 INT8 部署权重
- `resnet/model/parsed_vai_int16_widened/`：INT8 数值扩宽为 INT16 的数据通路测试集
- `resnet/examples/`：20 张 ImageNet 输入及 manifest
- `resnet/resnet_e2e.py`：图连接、前后处理与 host FC；`resnet/run.py` 为专用入口

当前没有“重新训练或量化得到的原生 INT16 ResNet PT/ONNX”。因此 widened INT16 的
合格结论应写成“支持 INT16 硬件执行路径”，不能用它证明原生 INT16 ResNet 模型精度。
INT8 和 widened INT16 仍应分别运行、分别记录结果。
