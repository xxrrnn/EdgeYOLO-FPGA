# tests/chip/ — FPGA 板上端到端测试套件

EdgeYOLO-FPGA-lite 片上测试，覆盖从单算子到完整 YOLOv5n W8A8 网络的渐进验证。

---

## 目录结构

```
tests/chip/
├── compiler/               # 编译器 (network.json → ISA binary)
│   ├── compile.py          # 主入口
│   ├── ir_schema.py        # IR 模式定义
│   ├── lowering/
│   │   ├── lower.py        # Conv-only lowering (L4 当前路径)
│   │   ├── lower_full.py   # 全网络 lowering（含 Add/Concat/US/MP/Tiling，规划中）
│   │   ├── yolov5n_schedule.py  # YOLOv5n 静态调度表
│   │   ├── memory_plan.py  # VPU_BUF / IBUF / WB 地址规划
│   │   ├── hw_caps.yaml    # 硬件能力参数（acc_depth_max, num_tiles 等）
│   │   └── op_rules.py     # 算子合法性检查
│   ├── codegen/
│   │   └── encode_isa.py   # OP → 32-bit words
│   └── packer/
│       ├── weights_packer.py  # INT8 权重打包 → IBUF nibble 格式
│       └── wb_packer.py       # Scale/Bias 打包 → WB 格式
├── unit-tb/                # Windows 片上单元测试（主要测试目录）
│   ├── xdma_win.py         # XDMA 驱动封装 + ChipRunnerWin
│   ├── hbm_flow.py         # inst 补丁: HBM↔片内 CDMA 生成
│   ├── gen_data.py         # 调用 golden_module_tb.py 生成测试数据
│   ├── run_unit_test.ipynb # 主交互 Notebook（L1/L2/L3 全覆盖）
│   ├── _l3_rerun.py        # L3 批量重跑脚本（conv_pipeline + mini_network）
│   └── ...                 # 其余 _xxx.py 为调试临时脚本
├── dist/                   # 编译器输出目录（运行时生成）
│   └── yolov5n_N/          # --max-layers N 的编译结果
└── step0~step3/            # 未来完整网络验证阶段目录
```

---

## 快速开始（复现步骤）

### 前提条件

1. FPGA 已烧录 bitstream（`scripts/ip/bd/chip/` 生成）
2. `xdma_info.exe` 能看到设备（位于 `tests/xdma_exe/`）
3. conda 环境 `chip_test_env` 已安装

```bash
# 验证 XDMA 连接
tests\xdma_exe\xdma_info.exe

# 进入测试目录
cd tests/chip/unit-tb
conda activate chip_test_env
```

---

## L1：基础算子验证（全部通过 ✅）

### 运行方式

```bash
cd tests/chip/unit-tb
jupyter notebook run_unit_test.ipynb
```

或直接用脚本：

```python
# 单个 case
import sys; sys.path.insert(0, '.')
from xdma_win import ChipRunnerWin
from gen_data import generate_case

runner = ChipRunnerWin()
run_dir = generate_case("dcim_matmul", "dcim_tiny_1x1")
result = runner.run_case(run_dir, staging="hbm")
print(result)
```

### 覆盖的 case（均 preload + hbm 双路径）

| 模块 | variant | 输入规模 |
|------|---------|--------|
| `dcim_matmul` | dcim_tiny_1x1 | 1×1 pixel, 16ch |
| `dcim_matmul` | conv6_s2_c64_to128 | 6×6 kernel |
| `dcim_matmul` | conv3_s2_c32_to64 | 3×3, 3 tiles |
| `qa` | qa_c16_signed, qa_c64_clip, qa_int16_c32_signed | FP32→INT8/16 |
| `dqa` | dqa_c16_small, dqa_c32_mid, dqa_accum16_c32/c64 | INT32→FP32 |
| `im2col` | im2col_6x6_s2_c3, im2col_3x3_s1_c128 | 各种 kernel |
| `mp` | mp_sppf_128_10, mp_resnet_stem | MaxPool 5×5 |
| `us` | us_128_10_to20 | Upsample 2× |
| `add` | add_residual_16, add_pan_64 | Residual Add |

批量运行脚本（`_all_cases.py`）：

```bash
python _all_cases.py
```

---

## L2：大规模 DCIM 验证（全部通过 ✅）

针对真实 YOLOv5n 中各层的通道数（16→32→64→128）进行 DCIM 全规格测试。

```python
# 批量运行 L2（在 tests/chip/unit-tb/ 下）
import subprocess
subprocess.run(["python", "_batch_hbm.py"])
```

批量脚本（`_batch_hbm.py`）覆盖：
- `dcim_model_0_conv` ~ `dcim_model_7_conv`（对应真实层权重形状）
- `qa_int16_c32_signed`, `dqa_accum16_c32`, `dqa_accum16_c64`（需要 `quant='int16'`）

---

## L3：端到端 conv_pipeline 和 mini_network（全部通过 ✅）

多算子组合测试：CDMA + DCIM + DQA + QA + ADD 全链路。

```bash
# 重跑所有 L3 case（tests/chip/unit-tb/ 下）
python _l3_rerun.py
```

### L3 测试矩阵

| case | preload | hbm | 说明 |
|------|---------|-----|------|
| `pipe_conv1_c16_to16` | ✅ | ✅ | 单层 conv + DQA + QA |
| `pipe_conv3_s2_c32_to64` | ✅ | ✅ | 3×3 stride-2 |
| `pipe_conv3_s2_c64_to128` | ✅ | ✅ | 多 tile |
| `mini_2conv_c16` | ✅ | ✅ | 两层 conv 串联 |
| `mini_3conv_residual_c32` | ✅ | ✅ | 两层 + residual add |

### L3 `_l3_rerun.py` 关键代码

```python
# tests/chip/unit-tb/_l3_rerun.py
import sys; sys.path.insert(0, '.')
from xdma_win import ChipRunnerWin
from gen_data import generate_case

runner = ChipRunnerWin()

CONV_PIPELINE_CASES = [
    ("conv_pipeline", "pipe_conv1_c16_to16"),
    ("conv_pipeline", "pipe_conv3_s2_c32_to64"),
    ("conv_pipeline", "pipe_conv3_s2_c64_to128"),
]
MINI_NETWORK_CASES = [
    ("mini_network", "mini_2conv_c16"),
    ("mini_network", "mini_3conv_residual_c32"),
]

for mod, var in CONV_PIPELINE_CASES + MINI_NETWORK_CASES:
    run_dir = generate_case(mod, var)
    for staging in ["preload", "hbm"]:
        r = runner.run_case(run_dir, staging=staging)
        status = "PASS" if r["pass"] else f"FAIL {r['pass_words']}/{r['total_words']}"
        print(f"  {var:35s} {staging:8s}: {status}")
```

---

## Test Code 历史 Bug 修复记录

以下 bug 已全部修复，请勿回滚：

| # | 文件 | Bug | 修复方法 |
|---|------|-----|---------|
| 1 | `xdma_win.py` | `active_tiles` 超过 `DCIM_NUM_TILES`，CDMA 访问未映射地址 → IP 锁死 | `min(active_tiles, DCIM_NUM_TILES)` |
| 2 | `hbm_flow.py` | `src1.hex` 与 `src0.hex` 用同一 HBM offset，`add` 算子 hbm 输出全零 | `src1.hex` → `HBM_OFF_INPUT1` |
| 3 | `hbm_flow.py` | `build_hbm_input_cdma` 对已在 HBM 空间的 preload 目标生成重复 CDMA | `dst < TILE_IBUF_BASE` 时 `continue` |
| 4 | `hbm_flow.py` | VPU_BUF drain CDMA 在 URAM pipeline 未完成时读取 → 全零 | VPU_BUF 路径不追加 drain，主机直读 VPU_BUF |
| 5 | `hbm_flow.py` | `nbytes=0` 的 CDMA 指令触发 Xilinx AXI CDMA IP 锁死 | 过滤 `nbytes == 0` |

---

## 地址映射（chip-lite BD）

| 段 | 地址 | 大小 | 访问方式 |
|----|------|------|---------|
| HBM | `0x0_0000_0000` | 4GB | Host XDMA 读写 |
| tile_ibuf[t] | `0x1_0000_0000 + t×0x80000` | 512KB/tile | CDMA only |
| tile_obuf[t] | `0x1_0100_0000 + t×0x40000` | 256KB/tile | CDMA only |
| VPU_BUF | `0x1_0200_0000` | 8MB | Host + CDMA |
| VPU WB | `0x1_0300_0000` | 32KB | CDMA only |
| INST_BRAM | `0x1_0400_0000` | 128KB | Host XDMA 读写 |
| VPU_AXI_Regs | `0x1_0500_0000` | 4KB | Host 控制 |

### VPU_BUF 内存布局（L4 逐层执行）

每层可独占全部 8MB，ping/pong 各 4MB 交替：

```
偏移          大小    用途
0x000000     4MB    输入激活（偶数层） / 输出激活（奇数层）
0x400000     4MB    输出激活（偶数层） / 输入激活（奇数层）
0x600000     2MB    skip 连接（residual save）
```

---

## 已修复的 RTL 问题

### 问题 1：URAM 数据 Pipeline 与 Valid 不同步

| 属性 | 内容 |
|------|------|
| **文件** | `rtl/common/uram_tdp_bytewrite.v` |
| **症状** | im2col 输出 bit-flip；im2col 后偶发 AXI 总线锁死 |
| **严重程度** | Critical |

**修复**：
```verilog
// 修改前：
men_pipe_a <= {men_pipe_a[NBPIPE-1:0], mem_ena};
// 修改后：
wire rd_en_a = mem_ena & ~(|wea);
men_pipe_a <= {men_pipe_a[NBPIPE-1:0], rd_en_a};
```

### 问题 2：CDMA_COOLDOWN_CYCLES 未定义

| 属性 | 内容 |
|------|------|
| **文件** | `rtl/vpu/CDMA_Controller.sv`, `rtl/chip/chip_defines.vh` |
| **症状** | 多 tile drain HBM 时背靠背 CDMA 数据竞争 |

**修复**：在 `chip_defines.vh` 中定义 `` `define CDMA_COOLDOWN_CYCLES 2000 ``

### 问题 3：VPU `config_ready` 信号过早 assert

| 属性 | 内容 |
|------|------|
| **文件** | `rtl/vpu/Global_VPU.v`, `rtl/chip/chip_defines.vh` |
| **症状** | dqa/qa 偶发 1-4 word mismatch |

**修复**：`config_ready` 加 `VPU_READY_DELAY_CYCLES = 12` 拍延迟

---

## L4：YOLOv5n 完整网络渐进验证（进行中）

### 当前进展（2026-06-17 更新）

已完成 YOLOv5n **逐层算子 FPGA 测试**（`_l4_model0_test.py`），结果如下：

| 层 | 参数 | 小图尺寸 | FPGA 结果 |
|----|------|---------|-----------|
| model.0.conv | k=6×6, stride=2, in_ch=3, 3→16ch | 32×32 in | ✅ **PASS** |
| model.1.conv | k=3×3, stride=2, in_ch=16, 16→32ch | 16×16 in | ✅ **PASS** |
| model.2.cv1.conv | k=1×1, stride=1, in_ch=32, 32→16ch | 16×16 in | ✅ **PASS** |
| model.2.cv2.conv | k=1×1, stride=1, in_ch=32, 32→16ch | 16×16 in | ✅ **PASS** |

#### 修复的测试代码 Bug（#6）：conv_pipeline in_ch<16 时 CDMA 搬运量不足

**现象**：model.0.conv（in_ch=3）conv_pipeline 测试 FAIL，前 2 行正确后续全错

**根因**：`golden_module_tb.py` 的 `make_conv_pipeline_case` 中：
- `src0.hex` 按 `int8_hwc_words(feat)` 生成（**16B/pixel 对齐格式**，总 16384B）
- 但 CDMA 指令搬运量用 `src_bytes = h*w*in_ch = 3072B`（**紧排大小**）
- 导致 VPU_BUF 中只有前 3KB 有数据，im2col_unit 从第 3 行起读到零/残留值

**修复**（`golden_module_tb.py` line 1827）：
```python
# 修复前（错误）
src_bytes = h * w * meta.in_ch

# 修复后（正确）
src_bytes_aligned = h * w * (((meta.in_ch + 15) // 16) * 16)
# CDMA 搬运量改为对齐大小，与 int8_hwc_words(feat) 生成的数据量一致
```

**影响范围**：所有 `in_ch % 16 != 0` 的层（YOLOv5n 中只有 model.0.conv 的 in_ch=3）

### 硬件约束

| 约束 | 值 | 说明 |
|------|-----|------|
| 最大单 pass cout | 128 | `DCIM_INT8_OUT_CH_PER_TILE=16` × `NUM_TILES=8` |
| 最大 acc_depth | 80 | `DCIM_ACC_MAX=80` |
| VPU_BUF 半区 | 4MB | 最大单层激活 `160×160×128×4B = 13MB` → **需 Tiling** |
| im2col_unit 限制 | in_ch ≥ 1 稳定 | RTL 正确，支持任意 in_ch（通过 16B/pixel 对齐格式存储）|

### L4 渐进测试计划

```
L4-A（已验证）：model.0~2（stem + C3 block，含 in_ch=3 / stride=2）→ PASS ✅
L4-B（已验证 ✅）：cout-tiling  out_ch=256 层分 2 pass × 128ch 执行
  model.7.conv → tile0 PASS 32/32 words，tile1 PASS 32/32 words
  字节级精确：128-bit word level 完全一致（run_case 内 expected.hex vs VPU_BUF）
  实现方式：golden_module_tb.py out_ch_offset + ops.py FPGAOps.conv_tiled()
L4-C（FPGA 执行大部分 PASS ✅）：57 层全 conv 算子链式执行
  _l4_full_network_test.py: run_yolov5n_backbone_neck()
  Add / Concat / MaxPool / Upsample 在 host numpy 执行
  FPGA 执行所有 DCIM+im2col 算子
  已修复 BUG-1：DQA FP32 scratch 空间分配不足（acc=1 out_ch=in_ch 时溢出 dcim 区）
    → alloc_flat: im2col_alloc = max(im2col_bytes, dqa_fp32_bytes)
  已修复 BUG-2：im2col golden 函数 pad 参数错误（H/W 方向共用 pad_h0，不支持非对称 pad）
    → im2col / im2col_int16 改为分别使用 meta.pad_h0 / meta.pad_w0
  已验证 OH-tiling（L4-D）：model.4/6/8/17/20 等含大图 conv.m.cv2 层（acc=5, 40×40 等）
    全部 PASS（字节级精确），30×30 / 40×40 输入均通过 FPGA 验证 ✓
  当前状态（FPGA 完整网络测试）：
    model.2 及之后所有层（~55 层）：全部 PASS ✓（含 cout-tiling、OH-tiling）
    model.0.conv（320×320→160×160）：FAIL（级联失败，源头 IBUF overflow）
    model.1.conv（160×160→80×80）：FAIL（依赖 model.0 输出）
    model.3.conv（下采样后 80×80→40×40）：FAIL 11/6400（依赖 model.1 输出）
L4-D（已实现 ✅）：OH-tiling，大 feature map（IBUF pixel 数超限时分 tile 执行）
  实现：golden_module_tb.py make_conv_pipeline_case 支持 oh_tile_start/oh_tile_end 参数
  FPGA 测试：30×30 / 40×40 × acc=5 层 PASS 100%
  ops.py FPGAOps.conv_oh_tiled()：自动计算 ibuf max_pixels，拆分 OH tile 执行
  C3Block 自动选择 OH-tiling（acc_depth 超限时）
  待完成：model.0/1（320×320/160×160 输入）需要更大规模 OH-tiling（~40 tiles）
```

### 快速运行方式

```bash
cd tests/chip/unit-tb

# 1. 验证所有 YOLOv5n conv 层（小图 dry-run，不上 FPGA）
python _gen_all_cases.py

# 2. cout-tiling 单算子验证（model.7.conv 256ch, 2 pass）
python _cout_tiling_test.py --fpga    # FPGA 执行，PASS 32/32 words（字节级精确）

# 3. 完整网络渐进测试（stop-at 控制层数）
python _l4_full_network_test.py --dry-run --stop-at model.5.conv  # numpy golden
python _l4_full_network_test.py --stop-at model.5.conv            # FPGA 执行

# 4. 算子库直接调用（链式）
python -c "
from ops import FPGAOps, HostOps, verify_op
from xdma_win import ChipRunnerWin
runner = ChipRunnerWin()
fpga = FPGAOps(runner)
verify_op(fpga, 'model.0.conv', 'test_m0', (4,4))  # PASS 检验
"

# 5. Jupyter 交互测试
jupyter notebook run_unit_test.ipynb
# → Cell 9: cout-tiling 验证
# → Cell 10: 完整网络渐进测试
```

---

## 测试现状总结

| 层级 | 覆盖内容 | preload | hbm | 状态 |
|------|---------|---------|-----|------|
| L1 基础算子 | dcim_matmul × 8, qa, dqa, im2col, mp, us, add | ✅ | ✅ | **PASS** |
| L2 大规模 DCIM | dcim_model_0~7, qa_int16, dqa_accum16 | ✅ | ✅ | **PASS** |
| L3 端到端 | conv_pipeline × 3, mini_network × 2 | ✅ | ✅ | **PASS** |
| L4-A model.0~2 | model.0/1/2.cv1/cv2（含 in_ch=3 stem 层）| ✅ | ✅ | **PASS** |
| L4-B cout-tiling | model.7.conv (128→256, 2 pass × 128ch) | — | ✅ | **PASS** |
| L4-C 全网络 | 所有 57 个 conv 层 + Concat/Add/US/MP | — | dry-run ✅ | 进行中 |
