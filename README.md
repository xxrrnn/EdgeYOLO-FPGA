# EdgeYOLO-FPGA

> **DCIM + im2col 深度学习推理加速器 — FPGA E2E 验证项目**
>
> Xilinx VU37P FPGA 上运行 YOLOv5n (红外目标检测) 与 ResNet18 (ImageNet 分类)，
> 完整实现 INT8 量化推理，并验证 INT16 数据通路，与 Python numpy golden 逐层对齐。

---

## 目录

1. [项目概述](#1-项目概述)
2. [硬件与环境要求](#2-硬件与环境要求)
3. [快速开始（无 FPGA dry-run）](#3-快速开始无-fpga-dry-run)
4. [FPGA 上板运行](#4-fpga-上板运行)
5. [仓库结构](#5-仓库结构)
6. [模型详情与量化说明](#6-模型详情与量化说明)
7. [E2E 验证结果](#7-e2e-验证结果)
8. [模型重训与重解析](#8-模型重训与重解析)
9. [RTL 架构说明](#9-rtl-架构说明)
10. [Timing Closure 记录](#10-timing-closure-记录)

---

## 当前里程碑

### 2026-07-22 Native W16A16 candidate on `eff` (pending synthesis and board validation)

- 本候选只在 `eff` 开发，不合并到 `main`。已确认 `c1773f6` 到当前源码之间
  没有 BD、XDMA IP 或 pin XDC 差异；新 bitstream 在运行 workload 之前就让
  `xdma_info.exe` 卡顿时，不能归因于网络 compiler。此前 race 的 6 个候选虽
  无 setup/hold failure，但 WNS 只有 `0.000--0.010 ns`、WHS 只有
  `0.003--0.006 ns`，裕量过低，不能仅凭 `timing met` 判定为稳定。
- 原生 INT16 的确定性功能错误是 RTL/compiler/golden 数据布局不一致：
  `DCIM_Tile` 每 tile 输出 8 个 signed INT64 accumulator，即每个 128-bit word
  只有 2 个结果、每 tile 4 words；旧 compiler 仍按 INT32 的 4 results/word、
  每 tile 2 words 推进地址，导致像素输出重叠且 DQA 只读取一半 accumulator。
- 当前候选统一了这份 contract：INT16 DCIM 输出 stride 为 4 words/tile，DQA
  使用 native INT64 load/converter，numpy/module golden 保持 signed INT64，
  compiler 在 native INT16 conv 上设置 `VPU_FLAG_INT16`。INT8 的 INT32 contract
  不变。COCO YOLO true INT16 full compile 已完成 57/57 conv、0 warning；
  infrared YOLO、COCO YOLO、ResNet 的 INT8/INT16 compile matrix 均通过。
- RTL 经过 Verilator lint（0 error）且新增 native INT16 contract test。新 RTL
  尚未完成综合和上板验证，因此本节不宣称 true W16A16 已通过。

远程推荐一次生成 8 个实现候选：4 个从稳定版 `c1773f6` routed DCP 做
incremental implementation，4 个 clean implementation。incremental 只复用
placement/routing 参考，不复用旧逻辑网表；新的 post-opt netlist 仍来自当前
`eff` 源码。

```bash
cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-eff
git checkout eff
git pull --ff-only origin eff

TAG=$(git rev-parse --short HEAD)
make synth-to-opt TAG=$TAG SYNTH_JOBS=128 VIVADO_THREADS=32
make impl-race TAG=$TAG IMPL_JOBS=8 \
  RACE_PLACE_THREADS=16 RACE_ROUTE_THREADS=16 RACE_STOP_ON_WIN=0 \
  RACE_INCREMENTAL_DCP=build/lite/c1773f6/ImplOutputDir/post_route.dcp \
  RACE_INCREMENTAL_ATTEMPTS=4 RACE_MIN_WNS_NS=0.05 RACE_MIN_WHS_NS=0.02
```

只部署 `build/lite/$TAG/summary/impl_race_summary.tsv` 中标记为 `SUCCESS` 的
候选；`LOW_MARGIN` 仅保留作诊断。上板后依次运行 `xdma_info.exe`、小块
H2C/C2H、decoder status 和 progressive gate，基础通路通过后才运行 COCO
true INT16：

```powershell
python run.py --one-shot --network yolo --yolo-precision int16 `
  --one-shot-build-dir output\compile_yolo_coco50k_int16_full `
  --one-shot-yolo-parsed-dir model\yolov5n_coco50k_qat\parsed_int16 `
  --one-shot-yolo-expect-detections -1 `
  --yolo-img model\yolov5n_coco50k_qat\template\000000000139.jpg `
  --out-dir output\inference\yolov5n_coco50k_qat\int16_fpga `
  --conf 0.25 --iou 0.45 --one-shot-poll-timeout-s 300
```

### 2026-07-22 Stable-bitstream recovery and INT16-widened deployment

- 新生成的 true-INT16/INT64-accumulator bitstream 在网络启动前就出现
  `xdma_info.exe` 极慢、H2C/C2H `Win32 error 1359`。这属于 PCIe/XDMA
  基础通路失败，不能用 YOLO/ResNet 数值或 compiler 调度解释。
- 最后一个已知稳定并完成四 workload one-shot 验证的 bitstream 是
  `c1773f6`。本机回退副本：
  `build/stable_bitstreams/c1773f6.bit`，SHA256
  `314d65d3711d464d60f8f5d158d270275d9cc2203ddbaa3b41c7e6a64823764d`。
  `build/stable_bitstreams/dd1ed80_260707.bit` 是更早的备用版本。
- `c1773f6` 支持已验证的 INT16-widened 路径：量化值和 scale 与 INT8
  完全相同，权重/激活只从 8-bit 容器扩成 16-bit 容器。它不等同于
  使用 `[-32768,32767]` 大数值权重的 true W16A16。
- COCO YOLO 新增 `parse_quant_export.py --mode int16_widened`。该模式必须
  读取 INT8 export，且会拒绝任何超出 `[-128,127]` 的权重，避免误把
  true INT16 artifact 部署到稳定旧 RTL。生成的 60 个 NPZ 已验证与 INT8
  共 `1,861,888` 个权重值 bit-exact，full compile 为 57/57 conv、0 runtime
  warning、单 program segment。卷积 DQA 保持 `c1773f6` 的 INT32 accumulator
  读取语义，不依赖后来新增的 INT64 converter RTL。完整 numpy/compiler
  golden + host detect head 结果为 3 个目标（2 chair、1 tv），与 COCO INT8
  的类别和数量一致。
- `c1773f6` 上板六项连续复测通过，soft reset 可在 workload 之间恢复
  decoder，不需要整板 reset：
  - infrared YOLO INT8: 1 person，runner `2.511s`，execute `2.115s`；
  - infrared YOLO INT16-widened: 1 person，runner `3.081s`，execute `2.579s`；
  - COCO YOLO INT8: 2 chair + 1 tv，runner `2.575s`，execute `2.120s`；
  - COCO YOLO INT16-widened: 2 chair + 1 tv，runner `3.033s`，execute `2.571s`；
  - ResNet INT8: Top-1 `goldfish(1)`，runner `2.757s`，execute `2.365s`；
  - ResNet INT16-widened: Top-1 `goldfish(1)`，runner `6.942s`，execute `4.060s`。
  六项 runner 合计 `20.899s`，满足 1 分钟目标。
- 六项 data-level gate 全部通过：YOLO PAN 最大绝对误差不超过
  `1.90735e-06`，ResNet INT8/INT16 最终 feature 均 `max_abs=0`。
  COCO widened-INT16 的 golden 必须按 RTL QA 顺序执行
  `FP32 * float32(1/act_scale)`；若写成除法，会在 model.18 的两个舍入
  边界值产生假差异，并在后层放大到 3--4 LSB。

刷入 `c1773f6.bit` 并重新枚举 XDMA 驱动后，先运行基础门禁：

```powershell
tests\bin\xdma_info.exe
tests\bin\xdma_rw.exe c2h_0 read 0x0 -l 16
python tests\chip\runtime\hw_runner_win.py --build-dir output\compile_yolo_int8_full_eff --status-only --quiet-xdma
```

三条命令都应在数秒内结束；如果回退 bitstream 后仍然极慢，则问题位于
板卡 PCIe link、Windows XDMA driver 或主机枚举状态，而不是网络 RTL。

稳定 bitstream 上的最终推理命令：

```powershell
# Infrared YOLO
python run.py --one-shot --network yolo --yolo-precision int8 --one-shot-poll-timeout-s 300
python run.py --one-shot --network yolo --yolo-precision int16 --one-shot-poll-timeout-s 300

# ResNet18
python run.py --one-shot --network resnet --resnet-precision vai --one-shot-poll-timeout-s 300
python run.py --one-shot --network resnet --resnet-precision int16 --one-shot-poll-timeout-s 300

# COCO/original YOLO
python run.py --one-shot --network yolo --yolo-precision int8 --one-shot-build-dir output\compile_yolo_coco50k_int8_full --one-shot-yolo-parsed-dir model\yolov5n_coco50k_qat\parsed_int8 --one-shot-yolo-expect-detections -1 --yolo-img model\yolov5n_coco50k_qat\template\000000000139.jpg --out-dir output\inference\yolov5n_coco50k_qat\int8_fpga --conf 0.25 --iou 0.45 --one-shot-poll-timeout-s 300
python run.py --one-shot --network yolo --yolo-precision int16 --one-shot-build-dir output\compile_yolo_coco50k_int16_widened_full --one-shot-yolo-parsed-dir model\yolov5n_coco50k_qat\parsed_int16_widened --one-shot-yolo-expect-detections -1 --yolo-img model\yolov5n_coco50k_qat\template\000000000139.jpg --out-dir output\inference\yolov5n_coco50k_qat\int16_widened_fpga --conf 0.25 --iou 0.45 --one-shot-poll-timeout-s 300
```

COCO widened artifact 的可复现生成命令：

```powershell
python model\yolov5n_coco50k_qat\parse_quant_export.py --quant-onnx model\yolov5n_coco50k_qat\int8\best.quant.onnx --onnx model\yolov5n_coco50k_qat\int8\best.onnx --out model\yolov5n_coco50k_qat\parsed_int16_widened --mode int16_widened
python tests\chip\compiler\compile.py --network yolov5n --mode int16 --full --parsed model\yolov5n_coco50k_qat\parsed_int16_widened --out output\compile_yolo_coco50k_int16_widened_full
```

### 2026-07-17 COCO/original YOLOv5n export separated from infrared YOLO

- 原 infrared YOLO 继续使用默认目录和命令：
  - model: `model/yolov5n/parsed`
  - build: `output/compile_yolo_int8_full_eff` / `output/compile_yolo_int16_full_eff`
  - command: `python run.py --one-shot --network yolo --yolo-precision int8 --one-shot-poll-timeout-s 300`
- 新 COCO/original YOLO export 独立放置，不覆盖 infrared：
  - source: `model/yolov5n_coco50k_qat/int8|int16/{best.pt,best.onnx,best.quant.onnx}`
  - parsed: `model/yolov5n_coco50k_qat/parsed_int8` / `parsed_int16`
  - build: `output/compile_yolo_coco50k_int8_full` / `output/compile_yolo_coco50k_int16_full`
  - sample: `model/yolov5n_coco50k_qat/template/000000000139.jpg`
- COCO INT8 one-shot FPGA 已通过：
  - command: `python run.py --one-shot --network yolo --yolo-precision int8 --one-shot-build-dir output\compile_yolo_coco50k_int8_full --one-shot-yolo-parsed-dir model\yolov5n_coco50k_qat\parsed_int8 --one-shot-yolo-expect-detections -1 --yolo-img model\yolov5n_coco50k_qat\template\000000000139.jpg --out-dir output\inference\yolov5n_coco50k_qat\int8_fpga --conf 0.25 --iou 0.45 --one-shot-poll-timeout-s 300`
  - data compare: `PAN_P3/P4/P5 max_abs <= 1.90735e-06`
  - host detect head: 3 COCO detections at 320 input, `chair/chair/tv`
  - timing: total `2.629s`，execute `2.132s`
  - result image: `output/inference/yolov5n_coco50k_qat/int8_fpga/yolo/one_shot_int8/000000000139_yolo_int8_fpga_oneshot.jpg`
- COCO true INT16 one-shot 在旧 contract 下未通过 data-level（已由上面的
  native W16A16 candidate 取代，保留以下记录用于追溯）：
  - command: same as INT8 but using `--yolo-precision int16`, `output\compile_yolo_coco50k_int16_full`, and `parsed_int16`
  - FPGA executes and returns DONE, timing total `3.039s`，execute `2.546s`
  - compare still fails (`PAN max_abs` about `14-19`) and host head returns 0 detections
  - L1-only probe also fails (`max_abs` about `21.6`), so blocker is in base true-INT16 DCIM/DQA path, not in network scheduling.
  - 当时曾误判为 DQA 16/32-bit 读取问题；后续 RTL diff 和 layout contract
    检查确认 true W16A16 的正确 accumulator 是 signed INT64，最终修复见本页
    最上方 native W16A16 candidate。

### 2026-07-17 Full one-shot YOLO/ResNet INT8/INT16 PASS on new bitstream

- 新 bitstream 基础稳定性通过：
  - `status_read`: 10/10 pass。
  - host 小块 HBM/INST/WB 写读：60/60 pass。
  - CDMA `HBM->WB` 与 `WB->HBM` 双向小块搬运：20/20 pass。
- YOLO INT8 one-shot full 通过：
  - build: `output/compile_yolo_int8_full_eff`
  - output: `output/inference/yolo/one_shot_int8/`
  - feature compare: `PAN_P3/P4/P5 max_abs <= 9.53674e-07`
  - host detect head: 1 detection，bbox `[113.7, 64.6, 178.1, 237.4]`，conf `0.8108`
  - timing: total `2.495s`，execute `2.121s`
- ResNet INT8 one-shot full 通过：
  - build: `output/compile_resnet_vai_full_qdq_fixscale`
  - output: `output/inference/resnet/one_shot_int8/`
  - feature compare: `max_abs=0`
  - host FC/top-k: Top-1 `goldfish(class 1)`
  - timing: total `2.799s`，execute `2.375s`
- YOLO INT16 one-shot full 通过：
  - build: `output/compile_yolo_int16_full_eff`
  - output: `output/inference/yolo/one_shot_int16/`
  - feature compare: `PAN_P3/P4/P5 max_abs <= 9.53674e-07`
  - host detect head: 1 detection，bbox `[111.5, 56.5, 185.1, 242.5]`，conf `0.7381`
  - timing: total `3.022s`，execute `2.567s`
- ResNet INT16 one-shot full 通过：
  - build: `output/compile_resnet_int16_full_qdq_fixscale`
  - output: `output/inference/resnet/one_shot_int16/`
  - feature compare: `max_abs=0`
  - host FC/top-k: Top-1 `goldfish(class 1)`
  - timing: total `7.214s`，execute `4.070s`
- 本轮 compiler root cause：
  - ResNet downsample/conv 的 QA scale 不能固定使用本层 `act_scale`；必须使用实际输入 activation 的 scale。`layer2.0.downsample.0.Conv` 输入来自 `layer1.1.Add` scale `0.03125`，而该 downsample 自身 `act_scale=0.015625`，旧 lowering 因此把 residual 分支重缩放错。
  - ResNet one-shot conv 输出现在显式插入 `QA -> DQA_ACT`，stem maxpool 和 residual add 后也保持 VAI 量化边界，和旧 E2E oracle 对齐。
  - `compare_one_shot.py` 已同步 ResNet golden 语义，避免 FPGA 和错误 compiler golden 自洽但 host Top-1 错误。
- `run.py` 已新增统一 full one-shot 入口，默认最终推理输出统一写到 `output/inference/`；以下命令会按顺序运行 YOLO INT8/INT16 + ResNet INT8/INT16、做 data-level compare、跑允许的 host head，并输出 timing/json/result image：
  - `python run.py --one-shot --network all --yolo-precision both --resnet-precision both --one-shot-poll-timeout-s 300`
  - 已上板验证通过，四个 workload 合计 FPGA runner total `15.530s`。
- 四条单独运行命令：
  - YOLO INT8: `python run.py --one-shot --network yolo --yolo-precision int8 --one-shot-poll-timeout-s 300`
  - YOLO INT16: `python run.py --one-shot --network yolo --yolo-precision int16 --one-shot-poll-timeout-s 300`
  - ResNet INT8: `python run.py --one-shot --network resnet --resnet-precision vai --one-shot-poll-timeout-s 300`
  - ResNet INT16: `python run.py --one-shot --network resnet --resnet-precision int16 --one-shot-poll-timeout-s 300`
  - 每条命令都会打印数字结果，保存 `*.json`、`*_timing.json`，并生成可查看的结果图片 `*.jpg`。
- 历史 probe/debug/check 输出不作为最终结果保存；如需临时调试，请显式传 `--out-dir output\probes\<name>`，最终 demo/inference 保持使用默认 `output/inference/`。
- 当前四个 full one-shot workload 已经低于 1 分钟目标，也低于 30s 目标；后续优化重点从 correctness 转向减少 segmented program upload、压缩 ResNet INT16 execute time、整理 runtime/compiler 代码。

### 2026-07-13 ResNet residual QDQ root cause and RTL/compiler fix

- YOLO INT8 one-shot 复测通过：`python run.py --one-shot-yolo-int8 --yolo-img test_yolo.jpg --out-dir output --conf 0.25 --iou 0.45`
  - FPGA timing: total `2.532s`，execute `2.120s`
  - PAN feature compare: `max_abs <= 9.53674e-07`
  - host detect head: 1 detection，conf `0.810775`，class_id `0`
- ResNet INT8 full one-shot 当前旧 bitstream 可稳定 DONE，但 Top-1 错误：
  - artifact: `output/compile_resnet_vai_full_finalqa`
  - timing: total `2.525s`，execute `2.089s`
  - host head Top-1 为 `lighter(626)`，不是 `goldfish(1)`
- Root cause：one-shot ResNet residual Add 只做 `FP32 add + ReLU`，缺少旧 E2E/numpy oracle 中每个 BasicBlock 后的 `round/clip` 量化边界。只在最后加 final QA 不能修复分类，因为后续 block 的 skip path 已经使用了未量化的 FP32 residual。
- 已实现最小 RTL/compiler 修复：
  - `dqa_relu_unit.sv` 新增 `dqa_act_mode`，支持从 QA packed INT8/INT16 activation 读入并 sign-extend，再复用原 DQA int32->FP32 + scale/bias 路径。
  - `Global_VPU.v` 新增 `VPU_FLAG_DQA_ACT=2` 并传给 DQA；旧 DCIM accumulator DQA 路径不置该 flag，行为保持不变。
  - ResNet full lowering 在 8 个 residual Add 后插入 `AD -> QA -> DQA(act_mode)`，输出仍为 FP32，最后 host boundary 继续 final QA 成 INT8/INT16。
  - `wb_packer.py` 新增 `qdq` WB section；`parsed_vai_int16_widened` 缺失 `add_output_scales.json` 时复用 sibling `parsed_vai` 的 add scales。
- 新 artifact 已生成但需要包含上述 RTL 的新 bitstream 才能上板：
  - `output/compile_resnet_vai_full_qdq`: 20/20 conv，`program.bin` 68,968B，`weights.bin` 11,169,792B，`wb.bin` 54,224B。
  - `output/compile_resnet_int16_full_qdq`: 20/20 conv，2 segments，`program.bin` 209,836B，`weights.bin` 22,339,584B，`wb.bin` 54,224B。
- 本机 Codex 环境看不到用户 WSL distro，Verilator 需在用户 shell 运行：
  - `wsl -d Ubuntu-22.04 -- bash -lc "cd /mnt/g/PKU/Task/Yolo_on_FPGA/EdgeYOLO-FPGA && verilator --lint-only -sv -Wall -Wno-fatal -Irtl/chip -Irtl/vpu rtl/vpu/dqa_relu_unit.sv rtl/vpu/Global_VPU.v"`

### 2026-07-08 YOLO INT8 full one-shot data-level PASS

- 当前 bitstream/FPGA 健康，使用 `--soft-reset-decoder` 连续跑 progressive gate 未再要求整板 reset。
- YOLO INT8 one-shot 已跑通 full backbone/FPN/PAN，host 边界只剩 detect head 和 postprocess/NMS：
  - build: `output/compile_yolo_int8_full_concat_persist_check`
  - output: `output/yolo_int8_full_concat_persist_outputs/{PAN_P3,PAN_P4,PAN_P5}.bin`
  - FPGA timing: total `2.427s`，execute `2.121s`，weights upload `0.030s`，WB upload `0.022s`，input upload `0.022s`，program upload `0.022s`，readback `0.085s`
  - data compare:
    - primary/PAN_P5 `max_abs=4.76837e-07`
    - PAN_P3 `max_abs=9.53674e-07`
    - PAN_P4 `max_abs=9.53674e-07`
  - host detect head gate: 1 detection，conf `0.810775`，class_id `0`
- 本轮修复的 compiler root cause：
  - `OP_CDMA_STRIDE` concat 仍保留 64B chunk，避免当前 CDMA stride 128B same-memory path 卡死。
  - weight packer 不再固定只打包 8 个硬件 tile；按 `expected_tiles` 打包 INT8/INT16 权重，支持 `Cout > 128` 的 output-channel multi-pass。
  - multi-pass 后续 pass 的 im2col 现在复用第一 pass 的 QA scratch，不再误读 FP32 input。
  - concat 后紧跟 save 的 tensor 现在写入 persistent skip buffer，避免 C3 主分支中间输出覆盖旁路输入。
- 已通过 progressive checkpoints：L26、L28、L32、L38、L40、L48、full。
- 下一步：复测 YOLO INT16 full，随后复测 ResNet VAI/INT16 full；若 INT16 或 ResNet 后段仍错，继续用同样的 staged data gate 定位，暂不需要重新综合 RTL。

### 2026-07-07 one-shot progressive 修复进展

- YOLO INT8 one-shot L2/L3/L4/L5/L6 已在当前 FPGA 上通过 data-level compare：
  - L3：`max_abs=9.53674e-07`。
  - L4：`max_abs=9.53674e-07`，总耗时约 0.79s，其中 execute 约 0.60s。
  - L5：`max_abs=9.53674e-07`。
  - L6：`max_abs=9.53674e-07`。
- 修复了 YOLO route tensor 的真实 buffer 生命周期问题：当 named/residual 输入需要保留且 conv 按 output-H 分块时，QA 的 compact activation 不能和本层 FP32 输出共用同一地址；否则第一块 DQA 会覆盖后续 chunk 尚未读取的 quantized input。compiler 现在在这种情况下从 skip/free-list 分配临时 QA scratch，并在该层 emit 后释放。
- L7 首次失败点已收敛到 `model.2` C3 concat 后的 `model.2.cv3.conv`。L5/L6 两个 concat 输入分支单独正确，concat probe 读回为错误地址空间垃圾。
- 已定位 `OP_CDMA_STRIDE` RTL/codegen 地址格式 bug：旧 RTL 在 stride CDMA issue 时把 `src_msb/dst_msb` 固定为 0，而 VPU_BUF/OBUF 物理地址位于 `0x1_0200_0000`，必须使用 64-bit 地址。普通 `OP_CDMA_COPY` 已经发送 MSB+LSB，所以卷积路径正常，concat stride 路径异常。
- 已做最小 RTL+compiler 修复：`OP_CDMA_STRIDE` 指令体改为 8 word，包含 `src_msb/src_lsb/dst_msb/dst_lsb/copy_bytes/src_stride/dst_stride/count`；`INST_Decoder` 发送 stride CDMA 时使用这两个 MSB，soft reset 也清理 stride 状态。
- 该 RTL 修复需要重新综合/生成 bitstream 后才能验证 L7/L8 及后续 full YOLO。当前旧 bitstream 仍可继续验证无 concat 的 L1-L6，但不能用于新的 concat stride program。
- 2026-07-07 复测新 bitstream 后，L5/L6 concat 输入分支仍逐层对齐，但截断到第一处 concat 的 probe 读回仍是旧 input/垃圾；进一步检查 RTL 发现 `S_CDMA_STRIDE_WAIT` 只等到 CDMA 接收配置的 ready，未像 `OP_CDMA_COPY` 一样等待 CDMA 传输完成后再进入下一 stride。已在 `INST_Decoder` 增加 `S_CDMA_STRIDE_DONE`，并修正 `INST_COUNT=0` soft reset 不再 latch start pulse。该修复需要重新综合后再验证 L7/L8。

### 2026-07-07 新 bitstream one-shot 功能复测

- 已刷入包含 AD ReLU mode 的新 bitstream；对应 RTL commit 为 `15964cc rtl: add optional relu mode to ad unit`。该 RTL 只给 `ad_unit` 增加可选 ReLU clamp，用于 ResNet residual `add + relu`，避免再把 residual add 长期留在 host。
- 当前工作分支已切到 `eff`，RTL 变更保持单独 commit，compiler/runtime one-shot 变更继续在工作树中迭代。
- 新 bitstream 基础健康检查未通过：reset/reprogram 后 `--status-only` 读到 `DECODER_STATUS=0x00000001`，说明 decoder 仍处 busy。随后用 1-word `OP_END` probe 测试主机链路，16B H2C 写 `VPU_BUF 0x102000000` 超时 30s，报 `xdma_rw.exe hung`。因此当前不是 YOLO/ResNet data-level mismatch，而是 XDMA/decoder 基础状态不可用；需要重新 reset/reprogram FPGA 或重启 XDMA driver 后再上板跑 progressive gate。
- 第二次 reset 后基础链路恢复：`DECODER_STATUS=0x00000000`，1-word `OP_END` probe 可正常上传 16B input / 4B program，decoder 返回 `DONE`，总耗时约 0.09s。已修复 `hw_runner_win.py` 对小于 16B program 的写后读回验证，避免 tiny probe 访问 `INST_BASE-12`。
- 随后运行 YOLO INT8 L4 one-shot，weights/WB/input/program 上传均成功，但 segment 0 在 120s 后仍 `DECODER_STATUS=0x00000001` busy。当前判断卡点在执行阶段，优先怀疑 `OP_DCIM_LAYER` / DCIM ready handshake 路径；已生成 `output/probe_yolo_l4_before_first_dcim` 与 `output/probe_yolo_l4_first_dcim`，下一次 reset 后用 prefix probe 定位是否第一个 DCIM_LAYER 即 hang。
- 为减少后续整板 reset 频率，RTL 已增加 decoder 控制保护：`INST_COUNT=0` 的 decoder start pulse 作为 decoder-local soft reset；`OP_DCIM_LAYER_WAIT` 增加 watchdog，超时进入 `STATUS_ERROR` 而不是永久 busy。该改动只在 `INST_Decoder` 控制状态机内，不改 DCIM datapath。当前 bitstream 尚不包含该 RTL，需要下一次综合后生效；Windows runner 已预留 `--soft-reset-decoder`。
- 当前 FPGA 不再冒险直接跑 `probe_yolo_l4_first_dcim`：`probe_yolo_l4_before_first_dcim` 已通过，证明卡点之前的 WB/weight/input/program upload、im2col、CDMA activation load 都正常；下一版 bitstream 带 watchdog 后再跑 first-DCIM probe，可避免再次要求整板 reset。
- 已新增 `--dcim-loop legacy` 诊断编译路径：把高效的 `OP_DCIM_LAYER` 展开为显式 `dcim_cfg + dcim_exec + wait_dcim` per-pixel loop，只用于定位当前 bitstream 的 layer-loop 控制问题，不作为最终效率方案。
  - YOLO INT8 L1 legacy-loop artifact：`output/compile_yolo_int8_l1_legacy_loop`，无 `dcim_layer`，无 runtime warnings，program 被拆成 6 个 INST_BRAM segments。
  - 上板通过：6 个 segment 全部 `DONE`，读回 `160x160x16` feature，总耗时 1.227s，其中 execute 0.508s、program upload 0.166s、readback 0.318s。
  - Data-level 对齐通过：`compare_one_shot.py` 对 compiler golden 的 `primary max_abs=1.90735e-06, mean_abs=2.57629e-08, rmse=7.45895e-08`。
  - 结论：DCIM primitive 数据通路、weight/WB/input staging、im2col/CDMA/DQA 对 L1 是正确的；当前 one-shot 高效路径的 blocker 进一步收敛到 `OP_DCIM_LAYER` decoder-side loop / DCIM ready handshake。最终性能仍必须修复/验证 `OP_DCIM_LAYER`，不能用 legacy-loop 扩展到 full network。
- YOLO INT16 L1 legacy-loop 已定位并修复多处 compiler 语义问题，但 data-level 仍未通过：
  - 修复默认 parsed 目录：`mode=int16` 现在默认使用 `model/yolov5n/parsed_int16_widened`。
  - 修复 INT16 `acc_depth`：按 `ceil(K / DCIM_CH_IN)` 计算；INT16 只增加每个 acc step 的 activation words，不应按 `ceil(K / 8)` 或 `ceil(K / 32)` 放大 logical acc depth。
  - 修复 INT16 weight packer：按 `golden_module_tb.pack_weight_tile_int16` 的 nibble matrix / `DCIM_CYCLE` 顺序打包；首层 `weights.bin` 从 57,344B 降到 16,384B。
  - 修复 one-shot im2col：INT16 conv 的 `UNIT_IM2COL` 指令现在带 `VPU_FLAG_INT16`。
  - 上板可稳定 DONE，最新耗时：8 segments，总耗时 1.577s，execute 0.626s，readback 0.437s。
  - 最新 compare 仍失败：`primary max_abs=14.9612, mean_abs=1.34532, rmse=1.99379`。相比修复前 `max_abs=24.646, mean_abs=3.096, rmse=5.047` 已明显收敛；剩余 blocker 暂定为 INT16 DCIM output lane 到 DQA FP32 layout / compiler golden 语义未完全对齐。
- 当前 bitstream 的 legacy E2E baseline 已重新复测通过，作为 one-shot correctness oracle：
  - YOLO INT8 `--no-verify --reuse-cases`：1 det，conf 0.8108，总耗时 36.8s。
  - YOLO INT16 `--no-verify --reuse-cases`：1 det，conf 0.7381，总耗时 86.4s。
  - ResNet18 VAI `--no-verify --reuse-cases`：Top-1 goldfish，总耗时 131.2s。
  - ResNet18 INT16 `--no-verify --reuse-cases`：Top-1 goldfish，总耗时 172.8s。
  - 每次运行后 `DECODER_STATUS=0x00000002`，说明 legacy path 没有留下 busy 状态。
- one-shot YOLO INT8 已修复并通过前两层 data-level gate：
  - L1 (`max-layers 1`)：上板 DONE，读回 feature 与 compiler numpy golden 对齐，`max_abs=1.90735e-06`。
  - L2 (`max-layers 2`)：上板 DONE，读回 feature 与 compiler numpy golden 对齐，`max_abs=1.90735e-06`。
- ResNet one-shot 工具链已补齐到可上板验证状态：
  - Windows runner 新增 `--resnet-image`，可直接按 ResNet18 ImageNet resize/crop/normalize/quantize 生成输入并一次上传到 VPU_BUF。
  - `compare_one_shot.py` 新增 ResNet compiler-semantics golden：conv DQA 按 `has_activation` 控 ReLU，stem maxpool 走 FP32 3x3 stride2 pad1，residual add 走 FP32 add + ReLU，FC/softmax 留在 host 边界外。
  - 离线 golden-only 已通过：ResNet18 VAI / INT16 full 均生成 `7x7x512 float32` backbone feature，作为下一次 FPGA 读回 data-level 对齐目标。
- Windows one-shot runner 已补 timing/report 能力：
  - `hw_runner_win.py` 新增 `--timing-json`，记录 weights/WB/input/program upload、每个 segment execute、output readback 和 total time；segment timeout/error 时也会尽量写出 partial timing，便于定位 hang 的 segment。
  - 新增 `--status-only`，可只读 `DECODER_STATUS`，用于 reset 后确认 decoder 是否 idle。
  - 新增 `tests/chip/runtime/progressive_gate_win.py`，可按 staged artifacts 自动跑硬件 + compare，失败即停，并在 summary JSON 内嵌每一阶段 compact timing/return code。
  - YOLO full staged gate 会自动加 `--output-dir`，读回并比较 `PAN_P3/PAN_P4/PAN_P5` 三路 feature，避免只验证 primary `PAN_P5`。
- 已新增最终 host-boundary gate：`tests/chip/runtime/one_shot_host_head.py`。
  - YOLO：读取 one-shot `PAN_P3/PAN_P4/PAN_P5` FP32 feature，按 detect-head input scale 重新量化到 INT8，再运行 host `DetectHead.forward + decode/NMS`；progressive 默认要求 `test_yolo.jpg` 输出 1 个 detection。
  - ResNet：读取 one-shot `7x7x512` feature，运行 host FC/top-k；progressive 默认要求 `test_resnet_2.JPEG` Top-1 为 goldfish(class 1)。
  - 已修复 YOLO one-shot schedule 与旧 E2E oracle 的 C3 shortcut 语义差异：当前 parsed/legacy YOLO C3 bottleneck 不执行 shortcut add，one-shot schedule 已去掉这些 C3 add。离线 YOLO INT8 full compiler-golden + host head 已恢复为 1 个 detection，conf 0.8108。
  - ResNet VAI full 离线 host-head gate 仍会失败：Top-1 为 lighter(class 626)，不是 goldfish(class 1)。这说明 ResNet one-shot full-network correctness 还没有达标，下一步必须对齐 one-shot ResNet schedule/golden 与旧 E2E oracle，而不能只看中间 feature 自洽 compare。
- 本轮修复的关键问题：
  - host 上传 C=3 输入时按 im2col RTL 期望补齐到每 pixel 16B stride，避免 tight NHWC 输入导致首层 im2col 错位。
  - `OP_DCIM_LAYER.act_stride_words` 改为使用 `DCIM_INT8_ACT_WORDS` / `DCIM_INT16_ACT_WORDS`，而不是只按 accumulator depth 估算。
  - output-H tile crop 的源地址使用 16B 对齐后的 pixel stride，避免输入/中间 tensor 行步长不一致。
  - `wb.bin` 内 QA scale 改为 `1 / act_scale`，匹配 RTL `qa_unit` 的 `fp32 * qa_scale -> int` 语义。
- YOLO INT8 full one-shot 最新 artifact 已能 compile 到 runtime warnings = 0 / unsupported = 0；但上板 full run 在 240s 后仍 `DECODER_STATUS=0x00000001` busy，说明 full path 仍有 hang/超慢 op 需要定位。当前 FPGA 需要 reset/reprogram 后才能继续下一轮硬件测试。
- 离线 full compile 已通过：
  - YOLO INT16：57/57 conv，`program.bin` 184,916B，`weights.bin` 7,979,008B，`wb.bin` 38,928B，2 个 program segment。
  - ResNet18 VAI：20/20 conv，`program.bin` 159,828B，`weights.bin` 3,989,504B，`wb.bin` 38,720B，2 个 program segment。
  - ResNet18 INT16 widened：20/20 conv，`program.bin` 846,136B，`weights.bin` 15,937,536B，`wb.bin` 38,720B，7 个 program segment。
- 2026-07-07 `eff` fresh artifacts 已重新生成，供 reset/reprogram 后直接上板：
  - YOLO INT8 progressive：`output/compile_yolo_int8_l4_eff`、`l8_eff`、`l16_eff`、`l32_eff`、`full_eff`；full 为 57/57 conv，`program.bin` 68,296B，runtime warnings = 0。
  - YOLO INT16：`output/compile_yolo_int16_l4_eff`、`output/compile_yolo_int16_full_eff`；full 为 57/57 conv，`program.bin` 184,328B，2 segments，runtime warnings = 0。
  - ResNet VAI：`output/compile_resnet_vai_l2_eff`、`output/compile_resnet_vai_l7_eff`、`output/compile_resnet_vai_full_eff`；full 为 20/20 conv，2 segments，runtime warnings = 0。
  - ResNet INT16：`output/compile_resnet_int16_full_eff`；full 为 20/20 conv，7 segments，runtime warnings = 0。
- 已修复 ResNet one-shot partial compile：当 `max-layers` 截在 basic block 中间，compiler/compare 现在停在当前 conv 输出，不再错误发 residual add；离线 golden-only 通过：
  - YOLO INT8 L4：`80x80x16 float32`。
  - YOLO INT8 L32：`10x10x128 float32`。
  - YOLO INT16 L4：`80x80x16 float32`。
  - ResNet VAI L2：`56x56x64 float32`。
  - ResNet VAI L7：`28x28x128 float32`。
  - ResNet VAI/INT16 full：`7x7x512 float32`。
- 下一步硬件策略：reset/reprogram 后先做 progressive gate，而不是直接 full：YOLO INT8 `max-layers 4/8/16/32/full`，定位 busy 的具体 layer/op；ResNet VAI/INT16 则直接用 one-shot runner + golden compare 做 data-level gate。
- 下一轮 YOLO progressive 上板命令示例：
  - `python tests\chip\runtime\hw_runner_win.py --build-dir output\compile_yolo_int8_l4_eff --yolo-image test_yolo.jpg --output output\hw_yolo_int8_l4_eff.bin --poll-timeout-s 120 --quiet-xdma --read-chunk-bytes 65536`
  - `python tests\chip\runtime\compare_one_shot.py --build-dir output\compile_yolo_int8_l4_eff --image test_yolo.jpg --output output\hw_yolo_int8_l4_eff.bin --atol 1e-3`
- 自动 progressive 命令示例：
  - `python tests\chip\runtime\hw_runner_win.py --build-dir output\compile_yolo_int8_l4_eff --status-only --quiet-xdma`
  - `python tests\chip\runtime\progressive_gate_win.py --suite yolo-int8 --quiet-xdma --out-dir output\progressive_yolo_int8_eff`
  - `python tests\chip\runtime\progressive_gate_win.py --suite resnet-vai --quiet-xdma --out-dir output\progressive_resnet_vai_eff`
- 下一轮 ResNet 上板命令示例：
  - `python tests\chip\runtime\hw_runner_win.py --build-dir output\compile_resnet_vai_full_eff --resnet-image test_resnet_2.JPEG --output output\hw_resnet_vai_full_eff.bin --poll-timeout-s 240 --quiet-xdma --read-chunk-bytes 65536`
  - `python tests\chip\runtime\compare_one_shot.py --build-dir output\compile_resnet_vai_full_eff --image test_resnet_2.JPEG --output output\hw_resnet_vai_full_eff.bin --atol 1e-3`
  - `python tests\chip\runtime\one_shot_host_head.py --build-dir output\compile_resnet_vai_full_eff --image test_resnet_2.JPEG --output output\hw_resnet_vai_full_eff.bin --expect-top1 1`

### 2026-07-06 基线连通与端到端正确性

- XDMA smoke 通过：HBM `0x0`、HBM `0x1000`、INST_BRAM `0x104000000` 写读均 PASS。
- dry-run 基线通过：YOLO INT8 输出 1 个检测框，conf 0.81；ResNet18 VAI Top-1 为 goldfish。
- FPGA `--no-verify` 基线通过：
  - YOLO INT8：1 个检测框，conf 0.81，耗时 51.1s。
  - YOLO INT16 widened：1 个检测框，conf 0.74，耗时 74.7s。
  - ResNet18 VAI：Top-1 goldfish，Top-5 分数与 dry-run 一致，耗时 111.7s。
  - ResNet18 INT16 widened：Top-1 goldfish，Top-5 分数与 dry-run 一致，耗时 287.9s。
- FPGA 逐层 verify：
  - ResNet18 VAI/INT16 均无 FAIL，逐层数据与 numpy golden 对齐。
  - YOLO INT8/INT16 最终检测正确；`model.0.conv` 与 `model.1.conv` 各有 1 个 word 的 +1 LSB 差异，属于当前 README 定义的量化舍入容差，但还不是严格 bit-exact。
- 已修复运行链路基础问题：case/work 目录改到 `output/work/e2e`，Windows XDMA wrapper 支持 `tests/bin/xdma_rw.exe` 和 `XDMA_RW_EXE`，runtime/compiler 地址表同步到 chip-v3 BD，补齐默认 `hw_caps.yaml`。
- 当前瓶颈：老 E2E 路径仍然是逐层生成 case、逐层上传输入/指令、逐层启动 decoder；要达到“ResNet + YOLO INT8/INT16 全部 1 分钟内”，必须切到单 program、权重一次上传、VPU/CDMA 内部算子尽量上 FPGA 的 one-shot 路径。
- one-shot compiler 当前 blockers：
  - YOLO INT8 full compile 已清零 runtime warnings，但首次 one-shot 上板运行 decoder busy 超时，尚未完成 data-level 对齐。
  - YOLO INT16、ResNet VAI/INT16 已清掉 IBUF/tile_obuf 容量 warning；超过 128KB INST_BRAM 的 program 已改为 segmented execution，但还需要上板验证。
  - ResNet 3x3 stride2 pad1 maxpool 已映射到 `mp_unit_fixed` mode=1；ResNet full compile 的 unsupported 已降到 0。
  - 大输出通道层的 output-channel pass / 权重分段还需要继续验证，尤其是 INT16 和 ResNet 后段大层。
  - 当前硬件侧 blocker：YOLO L2 读回超时后，重新测试时读取 `DECODER_STATUS` 4B 仍 C2H timeout；需要重新 reset/restart XDMA 后继续 one-shot 上板。

### 2026-07-06 one-shot compiler 进展

- YOLOv5n full compiler 已能生成 INT8/INT16 backbone+neck artifacts，并已切到 `OP_DCIM_LAYER` + tile_obuf collect + tile-sequential DQA 路径：
  - INT8：57/57 conv + C3 residual add + concat/upsample/maxpool，`program.bin` 68,884B，`weights.bin` 2,056,192B，`wb.bin` 38,928B；runtime warnings = 0；unsupported = 0。
  - INT16 widened：57/57 conv + C3 residual add + concat/upsample/maxpool，`program.bin` 184,916B，`weights.bin` 7,979,008B，`wb.bin` 38,928B；2 个 program segment，runtime warnings = 0；unsupported = 0。
  - host detect head 所需三路 feature 已写入 `host_io.outputs`：`PAN_P3` = 40x40x64 FP32，`PAN_P4` = 20x20x128 FP32，`PAN_P5` = 10x10x256 FP32。
- ResNet18 full compiler：
  - VAI：20/20 conv + stem maxpool，`program.bin` 159,828B，`weights.bin` 3,989,504B，`wb.bin` 38,720B；2 个 program segment；runtime warnings = 0；unsupported = 0。
  - INT16 widened：20/20 conv + stem maxpool，`program.bin` 846,136B，`weights.bin` 15,937,536B，`wb.bin` 38,720B；7 个 program segment；runtime warnings = 0；unsupported = 0。
- 已把 `lower_full.py` 的 YOLO VPU_BUF 静态布局迁到 chip-v3 8MB，并修复 full lowering 对 `yolov5n-int8-signed` / `resnet18-vai` 名称的 dispatch。
- 已补 `OP_DCIM_LAYER` codegen encoder；full conv lowering 已从逐 primitive `dcim_cfg`/`dcim_exec` 切到 decoder 内部 layer loop。
- 已实现 compiler output-H tiling：按 512KB tile_ibuf 和 256KB tile_obuf 自动拆输出行 chunk，YOLO INT8 full compile 的容量 warning 已降到 0。
- 已实现 one-shot 权重 staging：host 只需把 `weights.bin` 上传一次到 HBM，program 按层、按 tile 通过 CDMA 搬到各 tile_ibuf；`hw_runner.py` 也改为从 HBM staging 权重。
- 已实现 program segmentation：`program_manifest.json` + `program_segments/segment_*.bin`，host 逐段写 INST_BRAM 执行，权重/input/WB 仍只上传一次，中间 activation 保持在 FPGA buffer。
- 已新增 Windows runner：`tests/chip/runtime/hw_runner_win.py`，支持 `program_manifest.json`、YOLO image preprocess、INT8/INT16 input bytes、busy 状态快速检查。
- Windows/Linux runner 均支持 `--output-dir` 多输出读回；YOLO full 可一次读回 `PAN_P3.bin`、`PAN_P4.bin`、`PAN_P5.bin` 给 host detect head。
- 已新增 `tests/chip/runtime/compare_one_shot.py`，按 compiler schedule 生成 numpy golden FP32 taps，用于 one-shot L1/L2/full 读回后的 data-level 对齐；YOLO INT8 full 与 INT16 full 的 golden 生成路径均已本地跑通。
- 已修复 `DCIM_LAYER` weight base：每个 tile 使用自己的 tile_ibuf，因此 `wei_base_words[t]` 必须是相同 local offset，不能按 tile 递增。
- 已修复 output-channel pass 布局：大通道层的第二/后续 pass 会加载对应 weight tile group，并把 DQA 写回同一 NHWC tensor 的 channel offset，而不是写成独立连续 block。
- 已重写 YOLO full schedule 以匹配 `network.json` 的真实 layer 顺序，并补上 backbone C3 的 residual add；这些 add 通过 VPU `UNIT_AD` 在 FPGA 内执行。
- 已接通 ResNet stem maxpool：compiler 发 `UNIT_MP` 且 `addr_break[1:0]=1`，使用 RTL 现有 3x3 stride2 pad1 mode，不改 RTL timing。
- one-shot 上板状态：
  - `output/compile_yolo_int8_l1`：旧 artifact 曾 DONE 并读回 1,638,400B feature；当前 artifact 已在 19:45 之后重新生成，必须重新上板读回后再做 data-level 对齐。
  - `output/compile_yolo_int8_l2`：decoder DONE；读回 819,200B feature 时单次 C2H 读超时，已把 Windows runner 改成 chunked read。
  - 2026-07-06 复测：重新运行 L2 时，最开始读取 `REGS_BASE+DECODER_STATUS` 的 4B C2H 读超时，说明当时还没进入计算/上传，XDMA C2H 通道仍处于异常状态。
  - YOLO INT8 full artifact 曾在修复前尝试运行，权重/WB/input/program 上传成功，但 segment 0 decoder busy 180s 超时；后续需 reset/reprogram 后用已修复 artifacts 继续 L2/full 验证。

### 2026-07-06 旧 E2E 路径复用 case 加速

- `run.py` 不再删除 `output/work/e2e`，只清理结果图/JSON；已生成的 case 文件可跨运行保留。
- 新增 `--reuse-cases`：复用现有 case，跳过在线 dry-run case 生成。
- 实测 YOLO INT8 FPGA `--no-verify`：
  - 重新生成 case：60.6s，1 个检测框，conf 0.81。
  - `--reuse-cases`：39.8s，1 个检测框，conf 0.81。
  - one-shot compiler 修改后复测 `--reuse-cases`：33.1s，1 个检测框，conf 0.81。
- 这仍不是最终 one-shot 方案，因为权重仍会每次上传到 HBM pool，且各层仍逐 case 启动 decoder；但它能显著加快当前硬件调试迭代。

---

## 1. 项目概述

### 做什么

本项目在 **Xilinx VU37P** FPGA 上部署了一个名为 **DCIM（Deep Convolutional Inference Module）**的自定义加速器 IP，实现：

- **YOLOv5n（红外行人/安全帽检测）** — INT8 量化推理，输入 320×320
- **ResNet18（ImageNet 分类）** — Vitis AI INT8 PTQ 推理

加速器通过 **PCIe/XDMA** 与主机 Python 脚本通信。推理流程：
1. 主机把输入图像和量化权重写入 FPGA 片上 HBM / SRAM
2. FPGA 执行卷积（DCIM Tile × 8）、VPU 算子（im2col/DQA/QA/MaxPool/Upsample/Add）
3. 主机读回 backbone 输出特征图，运行 detect head（YOLO）或 softmax（ResNet）
4. 输出检测框 / Top-5 分类结果

### 为什么用 numpy golden 验证

硬件 FPGA 调试时，Python numpy 版本（"dry-run"）作为精确参考：
- 用相同量化权重、相同定点运算逻辑，在 CPU 上逐层仿真 FPGA 行为
- 每层输出与 FPGA 实测值对比（verify），允许快速定位量化/格式 bug

---

## 2. 硬件与环境要求

### 硬件

| 组件 | 规格 |
|------|------|
| FPGA 板卡 | Xilinx VU37P-based PCIe 卡 |
| Bitstream | `chip.bit`（仓库根目录，~81MB，对应 `chip-v3` build） |
| PCIe | x8/x16，XDMA 驱动（Linux 或 Windows WDM） |
| 主机内存 | ≥ 16GB（ResNet ONNX 权重较大） |

> 若没有 FPGA，使用 `--dry-run` 模式在 CPU 上运行 numpy golden，验证算法正确性。

### 软件依赖

```
Python 3.10+（推荐 conda 环境 chip_test_env）
numpy
onnxruntime
Pillow (PIL)
torch (仅 ResNet ONNX 模式)
```

创建 conda 环境：
```powershell
conda create -n chip_test_env python=3.10
conda activate chip_test_env
pip install numpy onnxruntime Pillow torch torchvision
```

### XDMA 驱动（仅 FPGA 模式）

Windows 需安装 Xilinx XDMA WDM 驱动，驱动设备名为 `XDMA0`。
验证驱动安装：
```powershell
python tests/chip/unit-tb/xdma_win.py --test
```

---

## 3. 快速开始（无 FPGA dry-run）

```powershell
cd E:\work2026\runnan_xu\FPGA\EdgeYOLO-FPGA
conda activate chip_test_env

# 默认：YOLO INT8+INT16 + ResNet VAI，dry-run 模式
python run.py --dry-run
```

**预期输出：**
```
============================================================
EdgeYOLO-FPGA E2E Inference
  Mode          : DRY-RUN
  Networks      : yolo, resnet
  YOLO prec     : int8, int16
  ResNet prec   : vai
============================================================

--- YOLO Detection [test_yolo.jpg] ---
  [dry-run] YOLO INT8 : 1 det [0.81]
            -> output\yolo\test_yolo_int8_dry-run.jpg
  [dry-run] YOLO INT16: 1 det [0.77]
            -> output\yolo\test_yolo_int16_dry-run.jpg

--- ResNet Classification [test_resnet_2.JPEG] ---
  [dry-run] ResNet18 VAI  : [goldfish(1):24.525, tench(0):16.212, axolotl(29):14.512]
            -> output\resnet\test_resnet_2_vai_dry-run.jpg

Done in ~80s
```

### 所有精度全跑（dry-run）

```powershell
python run.py --dry-run --yolo-precision both --resnet-precision both
```

### 指定图片

```powershell
# 只跑 YOLO INT8
python run.py --dry-run --network yolo --yolo-precision int8

# 指定图片路径
python run.py --dry-run --yolo-img path/to/image.jpg --resnet-img path/to/photo.jpg
```

### 输出文件

```
output/
  yolo/
    test_yolo_int8_dry-run.jpg      ← 带检测框的图片
    test_yolo_int8_dry-run.json     ← 检测结果 [bbox, conf, class]
    test_yolo_int16_dry-run.jpg
    test_yolo_int16_dry-run.json
  resnet/
    test_resnet_2_vai_dry-run.jpg   ← 带 Top-5 标注的图片
```

---

## 4. FPGA 上板运行

### 前置条件

1. 刷入 bitstream：
```powershell
vivado -mode tcl -source scripts/program_device.tcl -tclargs chip.bit
# 或通过 Vivado GUI: Open Hardware Manager -> Program Device -> chip.bit
```

2. 确认 XDMA 设备可见：
```powershell
python tests/chip/unit-tb/xdma_win.py --test
# 应输出: XDMA OK
```

### 运行推理（FPGA 模式）

```powershell
# 全默认：YOLO INT8+INT16 + ResNet VAI（FPGA 执行）
python run.py

# 只跑 YOLO INT8
python run.py --network yolo --yolo-precision int8

# 只跑 YOLO INT16
python run.py --network yolo --yolo-precision int16

# YOLO + ResNet 全精度（需约 20 分钟，含 IBUF 清零和多次 preload）
python run.py --yolo-precision both --resnet-precision both
```

### 权重预加载（默认开启）

每次运行前，脚本自动生成 case 文件（dry-run，约 5-10s），再批量上传所有层权重到 HBM：

```
[preload] Generating case files (dry-run)...
[preload] Uploading all weights to HBM pool...
[preload] Done in 30.0s
  [FAIL] model.0.conv oh[66:72] 959/960 words   ← 边界已知现象，不影响推理
  [FAIL] model.1.conv oh[64:72] 1279/1280 words ← 同上
  [fpga   ] YOLO INT8 : 1 det [0.81]
```

> **注意**：连续跑多个精度（`--yolo-precision both`）时，每次精度切换会自动清零 FPGA TILE_IBUF，防止 INT8/INT16 状态交叉污染。这会额外耗时约 3-5 分钟。

### FPGA 验证模式

`--verify`（默认开启）会逐层读回 FPGA 输出并与 numpy golden 对比。
若需跳过逐层验证（加速推理），加 `--no-verify`：

```powershell
python run.py --no-verify
```

---

## 5. 仓库结构

```
EdgeYOLO-FPGA/
│
├── run.py                          ← 一键 E2E 推理入口 (主要使用此文件)
├── chip.bit                        ← FPGA bitstream (~81MB, chip-v3 build)
├── test_yolo.jpg                   ← YOLO 测试图 (红外, 336×256)
├── test_resnet_2.JPEG              ← ResNet 测试图 (金鱼)
│
├── output/                         ← 推理结果输出目录 (gitignored)
│   ├── yolo/                       ← YOLO 检测图 + JSON
│   └── resnet/                     ← ResNet 分类图
│
├── model/
│   ├── yolov5n/
│   │   ├── best.onnx               ← YOLOv5n FP32 ONNX (backbone only)
│   │   ├── best.quant.onnx         ← YOLOv5n INT8 QAT ONNX (Brevitas)
│   │   ├── parsed/                 ← INT8 量化权重（npz格式，dtype=int8）
│   │   │   ├── network.json        ← 网络结构 + 每层 act_scale
│   │   │   └── weights/*.npz       ← 每层卷积权重 + dqa_scale
│   │   ├── parsed_int16_widened/   ← INT16-widened 权重（dtype=int16，数值与 INT8 相同）
│   │   │   ├── network.json        ← 同 parsed/network.json
│   │   │   └── weights/*.npz       ← weight_int8 array 存为 int16 dtype
│   │   └── parse_onnx.py           ← 从 ONNX 提取 INT8 权重的脚本
│   │
│   └── resnet18/
│       ├── resnet18_w8a8.onnx      ← Vitis AI INT8 QDQ ONNX
│       ├── imagenet_labels.json    ← ImageNet 1000 类标签
│       └── parsed_qdq/             ← VAI INT8 权重 (运行时自动生成)
│           ├── network.json
│           └── weights/*.npz
│
├── tests/chip/unit-tb/             ← 核心推理逻辑
│   ├── ops.py                      ← FPGA 算子封装 (Conv/DQA/QA/im2col/...)
│   ├── e2e_detect.py               ← YOLOv5n E2E 主体 (preprocess+backbone+neck)
│   ├── detect_head.py              ← YOLOv5n 检测头 (CPU 端 1×1 Conv + decode)
│   ├── verify_e2e.py               ← YOLO INT8/INT16 对比执行
│   ├── resnet_e2e.py               ← ResNet18 E2E 主体
│   ├── xdma_win.py                 ← XDMA PCIe 驱动封装 (Windows)
│   ├── hbm_flow.py                 ← HBM 权重预加载管理
│   └── run.py                      ← 底层推理调度（被根目录 run.py 调用）
│
├── rtl/
│   ├── chip/                       ← 顶层 SoC RTL
│   │   ├── DCIM_Array.sv           ← 8×DCIM Tile 阵列
│   │   ├── DCIM_Array_bd.v         ← Block Design 包装
│   │   ├── chip_defines.vh         ← 全局参数 (ADDR_WIDTH, RD_LATENCY, ...)
│   │   ├── tile_ibuf.v             ← Tile 输入缓冲 (XPM URAM 512KB)
│   │   └── tile_obuf.v             ← Tile 输出缓冲 (XPM URAM 256KB)
│   ├── ref/DCIM/src/dcim/          ← DCIM 核心计算 RTL
│   │   ├── maArray.v               ← 乘法阵列 (DSP48E2)
│   │   ├── accumulateArray.v       ← 累加阵列
│   │   └── postProcess.v           ← DQA 后处理流水
│   ├── vpu/                        ← VPU 算子 RTL
│   │   ├── Global_VPU.v            ← VPU 顶层调度
│   │   ├── vpu_buf.v               ← VPU 工作缓冲 (XPM URAM 8MB)
│   │   ├── im2col_unit.v           ← im2col 展开
│   │   ├── dqa_unit.v              ← 反量化 (FP32 转换)
│   │   ├── qa_unit.v               ← 量化 (FP32→INT8)
│   │   ├── mp_unit.v               ← MaxPool
│   │   ├── us_unit.v               ← Upsample 2×
│   │   └── ad_unit.v               ← Add (残差连接)
│   └── common/
│       └── uram_tdp_bytewrite.v    ← XPM URAM 封装
│
├── xdc/chip/
│   └── chip_timing.xdc             ← 时序约束 (Pblock + 无 MCP)
│
├── scripts/
│   ├── chip-lite/                  ← Vivado 综合实现脚本
│   │   ├── 1_read_design.tcl
│   │   ├── 2_bd.tcl
│   │   └── 3_synth_nonproj.tcl
│   └── ip/bd/lite/                 ← Block Design 生成脚本
│
└── tools/                          ← 辅助工具
    └── chip_config.py              ← 芯片参数配置
```

---

## 6. 模型详情与量化说明

### 6.1 YOLOv5n — 红外目标检测

**训练数据**：红外行人+安全帽数据集，3 类（helmet/head/person），320×320 输入

**量化方式**：Brevitas QAT（量化感知训练），INT8

```
原始 FP32 → QAT INT8 训练（30 epoch） → parse_onnx.py → parsed/
mAP@0.5 = 0.706 (INT8 QAT)
```

**INT8 精度设计**：
- 全网络统一 `act_scale = 0.07814`（QONNX 校准值）
- 权重：8-bit signed，per-channel scale
- 激活：8-bit signed，`clip = [-128, 127]`
- 输入：`uint8 [0,255]`（FPGA 端归一化）
- 检测头（model.24）：FP32 weight，在 host CPU 端执行

**INT16 设计**（数据通路验证）：
- 使用与 INT8 完全相同的权重和 scale
- 权重以 `int16` dtype 保存到 `parsed_int16_widened/`（数值不变，仅扩位宽）
  - 原因：`ops.py` 通过 `weight_int8.dtype == np.int16` 判断激活 INT16 硬件路径（tile_size=64、align=8）
- 输入：`uint8 [0,255] → int16`（相同数值，更宽 dtype）
- 目的：验证 FPGA INT16 ALU 通路，结果与 INT8 数值等价

### 6.2 ResNet18 — ImageNet 分类

**量化方式**：Vitis AI PTQ（训练后量化），W8A8 QDQ

```
Vitis AI resnet18_w8a8.onnx → tests/chip/compiler/frontend/parse_resnet18_qdq.py → parsed_qdq/
Top-1 on ImageNet = ~69%（标准 ResNet18 精度）
```

**VAI（推荐）**：
- 来自 ONNX Model Zoo，Vitis AI 校准
- 测试图（金鱼）→ `goldfish` Top-1 ✓

**INT8 legacy**：
- torchvision FBGEMM INT8，精度略低

**INT16（数据通路验证）**：
- INT8 权重 `astype(int16)`，clip 保持 `[-128, 127]`
- 结果与 INT8 **bit-exact 一致**

---

## 7. E2E 验证结果

> 以下结果均通过实际运行获得（`python run.py`），日期 2026-07-04。

### 7.1 Dry-run（numpy golden，无 FPGA 硬件）

```powershell
python run.py --dry-run --yolo-precision both --resnet-precision both
```

| 网络 | 精度 | 结果 | 说明 |
|------|------|------|------|
| YOLO | INT8 | **1 det [conf=0.81]** | 检测到人体 ✓ |
| YOLO | INT16 | **1 det [conf=0.77]** | 与 INT8 推理路径等价 ✓ |
| ResNet | VAI | **goldfish(1): 24.525** | Top-1 正确 ✓ |
| ResNet | INT8 | tree frog(31): 0.490 | legacy FBGEMM 模型，精度较低 |
| ResNet | INT16 | tree frog(31): 0.490 | 与 INT8 bit-exact ✓ |

### 7.2 FPGA 硬件验证（chip.bit 刷入 + XDMA 驱动）

```powershell
python run.py --yolo-precision both --resnet-precision both
```

| 网络 | 精度 | FPGA 结果 | 与 dry-run 对齐 |
|------|------|-----------|-----------------|
| YOLO | INT8 | **1 det [conf=0.81]** | ✅ PASS |
| YOLO | INT16 | **1 det [conf=0.74]** | ✅ PASS |
| ResNet | VAI | **goldfish(1): 24.525** | ✅ PASS |
| ResNet | INT8 | **tree frog(31): 0.490** | ✅ PASS |
| ResNet | INT16 | **tree frog(31): 0.490** | ✅ PASS（与 INT8 bit-exact） |

> **说明**：YOLO INT8/INT16 首两层存在少量边界 word mismatch（如 959/960 words），
> 这是 DCIM 硬件 OH-tiling 边界的已知行为，不影响最终检测结果，
> 与独立层单元测试一致。

### 7.3 逐层验证说明

`--verify`（默认开启）会逐层读回 FPGA 输出并与 numpy golden 对比：
- **PASS**：输出字与 golden 完全一致
- **FAIL X/N words**：X 个字与 golden 不符（X 极小时为已知边界效应）

关键层全部 PASS，backbone 输出特征图与 golden 对齐，检测/分类结果正确。

---

## 8. 模型重训与重解析

### 重训 YOLOv5n INT8 QAT

```bash
cd model/algorithm/quantized-yolov5
python train.py \
  --data data/infrared.yaml \
  --cfg models/yolov5n-quant-infrared.yaml \
  --weights runs/train/ir_yolov5n_fp32/weights/best.pt \
  --batch-size 800 --imgsz 320 --epochs 30 \
  --hyp data/hyps/hyp.widerface.yaml --noautoanchor --cache ram
# 输出: runs/train/infrared_qat_int8/weights/best.quant.onnx
```

### 重解析 YOLOv5n 权重

```powershell
python model/yolov5n/parse_onnx.py
# 生成/更新: model/yolov5n/parsed/weights/*.npz + network.json
```

### 重解析 ResNet18 权重（Vitis AI）

```powershell
python tests/chip/compiler/frontend/parse_resnet18_qdq.py `
  --onnx model/resnet18/resnet18_w8a8.onnx `
  --output model/resnet18/parsed_qdq
# 生成: model/resnet18/parsed_qdq/weights/*.npz + network.json
```

---

## 9. RTL 架构说明

### 9.1 顶层架构

```
PCIe x8 ──→ XDMA ──→ AXI SmartConnect (13 Master)
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    tile_ibuf[0~3]   tile_obuf[0~3]   vpu_buf
    (512KB×4, XPM)   (256KB×4, XPM)  (8MB, XPM)
          │               │               │
    DCIM_Tile[0~3] ───────┘        Global_VPU
    (矩阵乘法阵列)                 (im2col/DQA/QA/MP/US/AD)
          │
    inst_bram (128KB 指令存储)
    vpu_regs  (4KB 状态寄存器)
    vpu_wb    (32KB 写回缓冲)
```

### 9.2 DCIM Tile 计算流水

```
ibuf → im2col(VPU) → DCIM maArray(DSP) → accumulateArray → postProcess(DQA) → obuf
                                              ↑
                                         weight from HBM
```

每层卷积执行步骤：
1. `OP_VPU_EXEC(UNIT_IM2COL)` — 特征图展开到 im2col 格式
2. `OP_DCIM_LAYER` — 矩阵乘法（权重 × im2col 输出）+ 累加
3. `OP_VPU_EXEC(UNIT_DQA)` — 反量化（INT32 → FP32）
4. `OP_VPU_EXEC(UNIT_QA)` — 再量化（FP32 → INT8/INT16）+ ReLU

### 9.3 存储层级

| 存储 | 大小 | 访问者 | 用途 |
|------|------|--------|------|
| HBM（片外） | 4GB | XDMA DMA | 权重长期存储 |
| tile_ibuf | 512KB×4 | CDMA + DCIM | im2col 输出（激活输入） |
| tile_obuf | 256KB×4 | DCIM + CDMA | DCIM INT32 原始输出 |
| vpu_buf | 8MB, XPM | VPU 算子 | im2col/DQA/QA 工作缓冲 |
| inst_bram | 128KB | inst_decoder | 指令序列 |

**VPU_BUF 峰值需求分析（yolov5n@320）**：

| 算子 | 峰值（input+output） |
|------|---------------------|
| im2col（model.0, 6×6, 320→160） | **3.4 MB ← 最大** |
| DQA FP32（model.0） | 1.6 MB |
| Add（残差 40×40×64） | 1.2 MB |
| Upsample 2×（20→40, 128ch） | 1.0 MB |

结论：8MB VPU_BUF 充裕，无需分 tile。

---

## 10. Timing Closure 记录

本节记录了 chip-v3 综合实现过程中遇到的主要 timing 问题及解决方案，
供后续 build 参考。

### 10.0 当前 Vivado build 策略

一次 build 只使用一个唯一输出根目录：`build/lite/<tag>/`。`<tag>` 默认是
当前 git short SHA；不要再把 log、bitstream 或 summary 分散到顶层 `logs/`
或 `artifacts/`。

推荐在远程 tmux 中执行：

```bash
cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-eff
git checkout eff
git pull --ff-only origin eff

TAG=$(git rev-parse --short HEAD)
make synth-to-opt TAG=$TAG SYNTH_JOBS=128 VIVADO_THREADS=32
make impl-race TAG=$TAG IMPL_JOBS=8 \
  RACE_PLACE_THREADS=16 RACE_ROUTE_THREADS=16 RACE_STOP_ON_WIN=0 \
  RACE_INCREMENTAL_DCP=build/lite/c1773f6/ImplOutputDir/post_route.dcp \
  RACE_INCREMENTAL_ATTEMPTS=4 RACE_MIN_WNS_NS=0.05 RACE_MIN_WHS_NS=0.02
```

所有结果都在 `build/lite/<tag>/` 下：

| 路径 | 内容 |
|------|------|
| `logs/` | Vivado batch log、journal、每个 race worker stdout |
| `SynOutputDir/` | synthesis checkpoint/report |
| `ImplOutputDir/` | opt/place/route checkpoint/report；`race/` 下是每个策略的独立实现目录 |
| `bitstreams/` | 每个 timing-met attempt 单独复制出的 `.bit/.bin`；是否可部署仍以 summary 的 `SUCCESS` 为准 |
| `summary/impl_race_summary.md` | 人读报告：每个 attempt/bitstream 的 WNS/TNS/WHS/THS/失败端点 |
| `summary/impl_race_summary.tsv` | 机器可读总表，便于排序或归档 |

`SUCCESS` 表示同时满足 setup/hold 且达到指定裕量；`LOW_MARGIN` 表示报告没有
违例、但裕量不足，只能用于诊断。若不提供 `RACE_INCREMENTAL_DCP`，全部 worker
自动退化为 clean implementation。若只想最快找到第一个 margin-qualified
候选，可改成：

```bash
make impl-race TAG=$TAG IMPL_JOBS=8 RACE_PLACE_THREADS=16 RACE_ROUTE_THREADS=16 \
  RACE_STOP_ON_WIN=1 RACE_INCREMENTAL_DCP=build/lite/c1773f6/ImplOutputDir/post_route.dcp
```

Vivado 2024.2.2 单进程 `general.maxThreads` 上限为 32。当前推荐是 8 个
implementation worker 并行、每个 worker 的 place/route 使用 16 threads；
如果服务器内存和 license 都稳定，再尝试 `RACE_PLACE_THREADS=32 RACE_ROUTE_THREADS=32`。

### 10.1 XPM 全面改造（URAM 替换）

将所有 URAM buffer 从手动 multi-bank 实现替换为 Xilinx XPM `xpm_memory_tdpram`：
- `tile_ibuf`：512KB, READ_LATENCY=10
- `tile_obuf`：256KB, READ_LATENCY=10
- `vpu_buf`：8MB（1MB 扩容到 8MB），READ_LATENCY=10

### 10.2 MCP → Pipeline Register

移除所有 `set_multicycle_path`，用 pipeline 寄存器替代：
- `postProcess.v`：merge→accumulate 之间插入 pipe_stage
- `DCIM_Array_bd.v`：`ready_internal → ready_pipe`
- `DCIM_Array.sv`：`cfg_*` 寄存

### 10.3 Tile Pblock 删除解除 SLR1 拥塞

4 Tile + 3 SLR，强制 Pblock 必有 1 个 SLR CLB 利用率 99%。
解决方案：删除 Tile Pblock，保留：
- `pblock_axi_vpu`（SOFT，VPU→SLR0）
- `pblock_vpu_buf_uram`（HARD，256 URAM→X0~X3，避免最远列）

### 10.4 accumulateArray + VPU start pipeline

针对 `r_cnt_reg → temp_reg`（fanout=1043，11×CARRY8）和
`vpu_unit_choose_reg → qa_unit CE` 违例：
- `accumulateArray.v`：refresh/up_data/ena 统一打一拍
- `Global_VPU.v`：`start → start_d1`，所有 unit_start 使用 `start_d1`

### 10.5 uram_tdp_bytewrite 关键路径修复

v4 引入 `rd_en = mem_ena & ~(|wea)` 导致 URAM cascade(7级) + LUT MUX(8级)
超出时序（WNS=-2.8ns）。采用方案 B 回退：
- `men_pipe` 仍用 `mem_ena`（不含 `|wea` 组合逻辑）
- 功能正确性由 `vpu_buf.v` 层 `rd_valid_pipe` 保证

---

## 附录：关键参数汇总

```
FPGA:                  xcvu37p-fsvh2892-2L-e
时钟:                   250 MHz
DCIM Tile 数:           8
tile_ibuf:              512KB per tile (ADDR_WIDTH=15, RD_LATENCY=10)
tile_obuf:              256KB per tile (ADDR_WIDTH=14, RD_LATENCY=10)
VPU_BUF:               8MB (ADDR_WIDTH=19, RD_LATENCY=10)
inst_bram:              128KB
HBM:                    4GB (用于存储权重)

YOLOv5n:               输入 320×320, INT8, 3 类, mAP@0.5=0.706
ResNet18 (VAI):        输入 224×224, INT8, 1000 类, Top-1≈69%
```
