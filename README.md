# EdgeYOLO-FPGA

面向 HBM 近存架构 AI 处理器的 FPGA 验证工程。当前 main 只保留源码、离线运行所需
模型、测试图片、XDMA 工具和一个实际使用的 bitstream；Vivado/编译/推理产物统一写入
被 Git 忽略的 `build/`、`output/` 或 `sim/`。

## 当前唯一 bitstream

烧录 [`bitstream/edgeyolo_80832ec_attempt1_native_w16a16.bit`](bitstream/edgeyolo_80832ec_attempt1_native_w16a16.bit)。

```text
原文件  = 80832ec_attempt1_clean_ExtraTimingOpt_AggressiveExplore_AggressiveExplore.bit
本地名  = 0725.bit
大小    = 84,989,276 bytes
SHA256  = 17ec07b150d187d777b02f79541adad7407ddbafa38aeddfdd7ff74c084933cf
RTL提交 = 80832ec49984c559d4f5c1bba8d8da40807369f3
```

这是 2026-07-25 实际选择并下载到本机的 attempt1，不是 `c1773f6`。attempt0 与旧 c177
文件不在 main；需要追溯时可查看 `codex/archive-main-full-20260810`。详细元数据见
[`bitstream/manifest.json`](bitstream/manifest.json)。原仓库没有提交 attempt1 的数值 timing
summary，因此本发布不沿用 c177 的 WNS/TNS 数字。

## 直接运行

Python 环境安装一次依赖：

```powershell
python -m pip install -r requirements-fpga-runtime.txt
```

无板卡文件自检：

```powershell
python run.py --self-check
```

板卡已烧录上述 bitstream、XDMA 驱动已枚举后，直接运行：

```powershell
python run.py
```

不需要填写模型、图片、编译产物或 XDMA 工具路径。`run.py` 会检查 bitstream 和八个
PT/ONNX 输入的 SHA256；若 workload 尚不存在，会自动编译到
`output/compiled/80832ec_attempt1/`。默认运行随仓库提供模型的 YOLO INT8/native
W16A16 和 ResNet INT8；ResNet native W16A16 需要先提供对应的 QDQ 模型：

| 网络 | `run.py` 选项 | 模型数值 | FPGA accumulator |
| --- | --- | --- | --- |
| COCO YOLOv5n | `--yolo-precision int8` | W8A8 | INT32 |
| COCO YOLOv5n | `--yolo-precision int16` | native W16A16 | signed INT64 |
| ImageNet ResNet18 | `--resnet-precision vai` | Vitis-AI W8A8 | INT32 |
| ImageNet ResNet18 | `--resnet-precision int16` | native W16A16 | signed INT64 |
| ImageNet ResNet18 | `--resnet-precision int16_widened` | 旧 INT8 值兼容模式 | signed INT64 |

YOLO native W16A16 的默认 feature 容差是 `0.01`；其他路径默认 `0.001`。可用
`--one-shot-compare-atol` 显式覆盖。单项运行示例：

```powershell
python run.py --network yolo --yolo-precision int16
python run.py --network resnet --resnet-precision vai
python tests/chip/compiler/frontend/parse_resnet18_qdq.py --onnx <resnet18_w16a16.qdq.onnx> --mode int16
python run.py --network resnet --resnet-precision int16
```

硬件只有一个 `MODE_INT16`，始终执行有符号 16×16 和 INT64 累加；native/widened
只在软件模型契约中区分。`compile.py --mode int16` 默认拒绝 widened 模型，旧模型必须
显式使用 `--allow-widened-int16`（或 `run.py --resnet-precision int16_widened`）。

## 保留的 PT/ONNX

完整哈希在 [`model/model_inputs_manifest.json`](model/model_inputs_manifest.json)。

| 目录 | 文件 | 用途 |
| --- | --- | --- |
| `model/yolov5n_coco50k_qat/int8/` | `best.pt`, `best.onnx`, `best.quant.onnx` | W8A8 QAT、参考推理、FPGA export |
| `model/yolov5n_coco50k_qat/int16/` | `best.pt`, `best.onnx`, `best.quant.onnx` | native W16A16 QAT、参考推理、FPGA export |
| `model/resnet18/` | `resnet18_fp32.onnx`, `resnet18_w8a8.onnx` | FP32 参考与 W8A8 QDQ 图 |

`parsed_int8/`、YOLO 的 `parsed_int16/`、ResNet 的 `parsed_vai/` 和兼容用
`parsed_vai_int16_widened/` 是 compiler
直接读取的部署输入，保留它们可以让 `run.py` 无需 ONNX/PyTorch 解析环境。由 compiler
生成的 `program.bin`、`weights.bin`、`wb.bin` 不进 Git。

## 项目结构

```text
bitstream/              唯一 attempt1 bitstream、SHA256 和来源说明
examples/coco/          20 张 COCO val2017 测试图片及 manifest
examples/imagenet/      20 张 ImageNet 测试图片及 manifest
model/                  PT/ONNX 原始模型与 compiler 直接使用的 parsed 模型
rtl/chip/               DCIM Array/Tile 和片上 buffer RTL
rtl/ref/DCIM/src/       DCIM macro 依赖源码
rtl/vpu/                VPU/decoder RTL，包括 native INT64→FP32 路径
rtl/tb/lite_bd/         Verilator/VCS testbench 与 golden
scripts/chip-lite/      Vivado 综合、实现和 impl-race 入口
scripts/ip/             block design 与 floating-point IP Tcl
tests/bin/              随仓库提供的 Windows XDMA 工具
tests/chip/compiler/    full-network compiler 与 native INT16 contract test
tests/chip/runtime/     FPGA runner、feature compare 和 host head
tests/chip/unit-tb/     算子 golden 与 host 侧实现
tools/                  RTL/compiler 共用硬件参数
xdc/                    引脚和时序约束源码
```

层次按“模型输入 → compiler → runtime → RTL → build scripts”划分，适合按数据流讲解；
历史实验、旧 bitstream、生成工程与结果不会混入主线。

## 验证记录与限制

2026-07-25 的上板记录：COCO YOLO native W16A16 完成 57/57 FPGA 层，PAN P3/P4/P5
最大绝对误差为 `0.00930/0.00712/0.00696`，在 `atol=0.01` 下通过并检测到 chair/tv；
ResNet INT8/widened INT16 通过 `atol=0.001` feature gate；这是历史兼容实测，不能作为
ResNet native W16A16 模型精度记录。当前软件/RTL 已支持 native ResNet W16A16，但仓库
没有随附该量化模型，需由上述 QDQ frontend 导入后重新上板验收。

Detect head/NMS 与 ResNet GAP/FC/Top-k 在 host 执行。20+20 样例用于硬件功能与数据一致性，
不能替代完整 COCO mAP 或 ImageNet Top-1 测试。当前仓库无法现场复现 routed timing 数字，
因此不把旧报告当成 attempt1 的证据。

更完整的命令和判定口径见 [`TESTING.md`](TESTING.md)。

## 重新综合

普通 project-mode 流程：

```bash
make synth TAG=my_build
```

复现 attempt1 所使用的并行实现策略入口：

```bash
make synth-to-opt TAG=my_build SYNTH_JOBS=128 VIVADO_THREADS=32
make impl-race TAG=my_build IMPL_JOBS=8 RACE_STOP_ON_WIN=0
```

`scripts/chip-lite/impl_race.sh` 会在 `build/lite/<tag>/summary/` 生成每个候选的 timing
汇总。只有当前运行重新生成的报告才能作为新 bitstream 的时序证据。
