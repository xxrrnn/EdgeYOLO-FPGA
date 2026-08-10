# 测试方法

## 1. 新克隆仓库自检

```powershell
python run.py --self-check
```

该命令不访问 FPGA，检查：

- 唯一 attempt1 bitstream 的大小与 SHA256；
- 8 个 PT/ONNX 模型输入的大小与 SHA256；
- 随仓库发布的 YOLO native INT8/W16A16、ResNet INT8 与 widened 兼容模型是否完整；
- 20 张 COCO、20 张 ImageNet 图片及 Windows XDMA 工具是否存在。

## 2. Compiler 与 native INT16 contract

```powershell
python tests/chip/compiler/test_int16_contract.py
python tests/chip/compiler/test_resnet_native_int16_frontend.py
python tests/chip/compiler/check_release_repro.py
```

`test_int16_contract.py` 验证 native INT16 的核心契约：四个权重 nibble 均保留、每个
INT16 DCIM 结果使用 signed INT64、每个 128-bit word 放两个 accumulator、compiler
设置匹配的 VPU flag/stride。frontend 测试用数值 `30000` 的合成 W16 QDQ Conv 验证
ResNet ONNX INT16 不会被收窄，并转换为 compiler 使用的 OHWI 权重。

`check_release_repro.py` 分别编译 YOLO INT8、YOLO native W16A16、ResNet INT8 和 ResNet
widened-INT16 两次，并比较 `program.bin/weights.bin/wb.bin`，确认编译可执行且确定性一致。
产物只进入临时目录，不加入 Git。

## 3. 纯 RTL 预检

本地有 WSL、Verilator、make 和 g++ 时：

```powershell
python run.py --verilator-only
```

用例验证 8 个 Tile/DCIM 同时激活、32 个输出 word 与 golden 一致，并输出 VCD、SVG 和
JSON/Markdown 报告到 `output/verilator_peak_int8/`。它不包含 XDMA/HBM/Xilinx 加密 IP，
所以不能替代上板或 VCS/route 验证。

## 4. 单图 FPGA 测试

前提：烧录 `bitstream/edgeyolo_80832ec_attempt1_native_w16a16.bit`，Windows 已安装 XDMA
驱动并重新枚举设备。

```powershell
python run.py
```

默认运行三套随附模型 workload；ResNet native W16A16 需先导入对应模型。每套 workload
依次执行输入预处理、上传、decoder 执行、输出读回、compiler golden feature compare、
host boundary 和结果绘制。

默认判定：

| Workload | 默认 `atol` | 说明 |
| --- | ---: | --- |
| YOLO INT8 | 0.001 | native W8A8 / INT32 accumulator |
| YOLO INT16 | 0.01 | native W16A16 / signed INT64 accumulator |
| ResNet INT8 | 0.001 | Vitis-AI W8A8 |
| ResNet native INT16 | 0.001 | native W16A16 / signed INT64 accumulator |
| ResNet widened INT16 | 0.001 | 显式兼容模式，使用同一 MODE_INT16 硬件路径 |

若只运行一项：

```powershell
python run.py --network yolo --yolo-precision int16
python run.py --network resnet --resnet-precision vai
python run.py --network resnet --resnet-precision int16 --one-shot-resnet-parsed-dir <parsed_int16>
```

## 5. 20+20 图片验收

只测 FPGA：

```powershell
python run.py --acceptance --vcs skip
```

同时调用远端 VCS：

```powershell
python run.py --acceptance --vcs-server user@server --vcs-remote-repo /path/to/EdgeYOLO-FPGA
```

导入 ResNet native W16A16 模型后，完整选择可运行 80 个硬件 workload：

```text
20 COCO × (YOLO INT8 + native W16A16) = 40
20 ImageNet × (ResNet INT8 + native W16A16) = 40
```

汇总写入 `output/acceptance/acceptance_report.json` 与 `.md`。YOLO 不以固定检测数量作为
20 图通用硬门限；ResNet 也不以样例 Top-1 必须正确作为硬门限，硬件门禁是 FPGA feature
与 compiler golden 的数值一致性。

## 6. 峰值与时序口径

VCS `peak_int8_all_tiles` 用例为 `M=1, K=512, N=128`，8 tiles，250 MHz，INT8 两个
nibble phase。计算窗口理论峰值为 `2.048 TOPS@INT8`，同时记录完整事务延迟，二者不可
混写。

当前 main 没有 attempt1 对应的 routed timing summary。因此：

- bitstream 的上板功能记录可以用于说明该文件可运行；
- 不能拿 `c1773f6` 的 timing report 证明 attempt1 的 WNS/WHS；
- 如需正式时序证据，应运行 `make synth-to-opt` + `make impl-race`，保存新生成候选自己的
  `impl_race_summary.tsv/.md` 与 routed report。

## 7. 结论边界

- Detect head/NMS 和 ResNet GAP/FC/Top-k 在 host；
- 20+20 图片说明功能覆盖与数据一致性，不等于完整 COCO mAP/ImageNet Top-1；
- Verilator 是纯 RTL 预检，不含 XDMA/HBM/Xilinx IP；
- 当前不测试 TOPS/W。
