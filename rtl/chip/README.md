# rtl/chip — DCIM 多 Tile 阵列与单 Tile 封装

本目录在参考 DCIM 核心 RTL 之上，提供**单 Tile 封装**（`DCIM_Tile`）、**多 Tile 共享缓冲**的顶层（`DCIM_Array`），以及对应的仿真测试平台与 VCS 工程。

## 目录结构

| 文件 | 说明 |
|------|------|
| `DCIM_Tile.sv` | 单颗计算 Tile：内部例化 `dcim` 等参考核，对外通过 **ready/valid** 访问 IBUF 读与 OBUF 写。 |
| `DCIM_Array.sv` | 参数化 `NUM_TILES` 阵列：多路 Tile + `ibuf_rd_arbiter` + `obuf_wr_arbiter` + 各一颗 `ibuf`/`obuf`（双端口：Port A 给外部加载/读回，Port B 给 Tile）。 |
| `ibuf_rd_arbiter.sv` | IBUF 读 Round-Robin 仲裁；将 Tile 侧握手转为单端口 `en/addr`，并按 `IBUF_RD_LATENCY` 在对应 Tile 上打 `rd_data_valid`。 |
| `obuf_wr_arbiter.sv` | OBUF 写 Round-Robin 仲裁；单周期完成被选 Tile 的 `we/addr/din`。 |
| `tb_DCIM_Array.sv` | 阵列级：`NUM_TILES=8`；Test 1–7 基础 ACC/行数；Test 8–13 对齐 YOLO `best.quant` 典型 im2col（acc=9/18/32/36/72 等）；`zero_pad_im2col_k` 处理 K 非 16 倍数（如 K=108→acc=7）。 |
| `tb_DCIM_Tile.sv` | 单 Tile 大规模回归；经 `ibuf_rd_arbiter`/`obuf_wr_arbiter`（`NUM_TILES=1`）接 `ibuf`/`obuf`，与阵列侧握手一致。 |
| `filelist.f` | VCS 文件列表：引用 `../../ref/DCIM/...`、`../../DCIM_Macro/...` 与本目录 RTL。 |
| `Makefile` | `make test`：`tb_DCIM_Array`；`make test_tile`：`tb_DCIM_Tile`；`make test_all`：两者依次运行；可选 FSDB/Verdi。 |
| `chip_defs.vh` | 片上系统级宏参数（本 Makefile 默认 flow 未包含进 filelist，供后续集成使用）。 |

## 硬件数据流（概念）

1. **外部**经 IBUF Port A 写入权重与激活；经 OBUF Port A 读回结果。
2. **`start` 脉冲**后，各 Tile 在相同 `mode`、`acc_depth`、`num_rows`、`act_base_addr` 下并行推进；**每 Tile 独立** `wei_base_addr` / `out_base_addr`。
3. 所有 Tile 的 IBUF 读请求经 **`ibuf_rd_arbiter`** 复用到一颗 IBUF 的 Port B；读数据广播，**仅当前 `ibuf_rd_data_valid` 对应的 Tile** 采样。
4. OBUF 写同理经 **`obuf_wr_arbiter`** 复用到 OBUF Port B。
5. **`done`** 为各 Tile `done` 相与；**`ready`** 为各 Tile `ready` 相与（均空闲才可再次启动）。

## 仿真依赖与编译方式

- **工具**：Synopsys VCS（示例命令行含 `-full64`、`-kdb`、`-lca`）；波形使用 Verdi FSDB（测试台内调用 `$fsdbDumpvars`）。
- **RTL 依赖**：`rtl/ref/DCIM`（`dcim.v`、`para.v` 等）、`rtl/DCIM_Macro/ibuf.v`、`obuf.v`。

**务必通过本目录 `Makefile` 编译**：`make compile` 会先 `cd build` 再调用 VCS，`filelist.f` 内路径（如 `../../ref/...`、`../DCIM_Tile.sv`）是**相对于 `build/` 当前工作目录**解析的。若在 `rtl/chip` 下手动执行 VCS 且工作目录不是 `build/`，相对路径会错位。

常用目标：

```bash
cd rtl/chip
make test       # tb_DCIM_Array
make test_tile  # tb_DCIM_Tile（用时长）
make test_all   # 依次跑上述两项
make fsdb       # 阵列测试并生成 dcim_array.fsdb
make verdi      # 在 build 目录打开 Verdi（需已有 fsdb）
make clean
```

## 测试说明

### `tb_DCIM_Array.sv`

- 例化 `DCIM_Array`，默认 **`NUM_TILES=8`**，`IBUF_RD_LATENCY=4`（与 `ibuf` NBPIPE=1 及仲裁器一致）。
- 地址：`wei` 区 Tile `t` 起始于 `t*CYCLE`；激活自 `ACT_BASE`；各 Tile 输出基址间隔 `OUT_STRIDE`，避免 OBUF 写重叠。
- **Test 1–7**：`ACC` ∈ {0,1,2,4,8,18}，行数 8/16/72 等（回归与小压力）。
- **Test 8–13（im2col 全空间 M，与 `best.quant.onnx` shape_inference 一致；不缩短行数）**  
  - Test 8：`acc=18`，`num_rows=28800`（`M=40×40`，model.3，K=288）  
  - Test 9：`acc=36`，`num_rows=14400`（`M=20×20`，model.5，K=576）  
  - Test 10：`acc=72`，`num_rows=7200`（`M=10×10`，model.7/21，K=1152）  
  - Test 11：`acc=32`，`num_rows=3200`（`M=10×10`，model.9.cv2，K=512）  
  - Test 12：**K=108 不整除 16**：`acc=7`，`zero_pad_im2col_k(...,108)`；`num_rows=179200`（`M=160×160`，model.0 全图）  
  - Test 13：`acc=9`，`num_rows=57600`（`M=80×80`，model.1，K=144）  
- **`zero_pad_im2col_k(rows, t_acc, k_raw)`**：每个输出组占 `t_acc` 行 IBUF 读，组内线性 K 下标 `row_in_group*16+ch`；若 `k_raw < t_acc*16`，将 `≥k_raw` 位置置 0 后再 `load_activations`，golden 仍用同一 `activation` 数组，与硬件 `acc_depth` 一致。  
- **`num_rows` 为 32 位**（阵列与 `DCIM_Tile` 端口一致）；**IBUF/OBUF 地址**在测试台中为 **`BUF_ADDR_WIDTH=19`**，以覆盖大 `M×acc` 的激活布局；各 Tile 输出基址间隔 **`OUT_STRIDE=19'h10000`**，避免写回重叠。  
- **单测超时**：`pulse_start_and_wait_done(loops_100k)` 表示最多等待约 `loops_100k×100000` 个时钟周期（避免 `repeat` 字面量触发 32 位 DCTL 截断）；`done` 先到则立即结束，不空转计数。全局仿真时长上限为 **`repeat(14400) #1000000000`**（约 4h 仿真时间，与 `timescale 1ns` 一致）。  
- 每轮 `passed_tests` 仍用 `errs_before` 与 `total_errors` 比较。

### `tb_DCIM_Tile.sv`

- 覆盖 INT8/INT16、多种 ACC、边界与随机等大量用例。
- 与 `DCIM_Array` 相同：`IBUF_RD_LATENCY=4` 且经单 Tile 仲裁器接 BRAM，避免直连 BRAM 时序与 DUT 状态机假设不一致。

## 已知问题与注意点

1. **`filelist.f` 路径依赖工作目录**：须通过 Makefile 从 `build/` 调用 VCS。
2. **`ibuf_rd_arbiter` 状态枚举**含 `ARB_GRANTED`，实际状态机未使用该状态，属冗余定义，不影响功能。
3. **`NUM_TILES=1`**：仲裁器内 `TILE_IDX_W` 在 `NUM_TILES<=1` 时钳位为 1，避免 `$clog2(1)==0` 产生非法 0 位寄存器。
4. **多 Tile 性能/公平性**：Round-Robin 在极端并发下会拉长单 Tile 完成时间；功能仿真默认 `NUM_TILES=2` 已覆盖基本仲裁路径。
5. **`chip_defs.vh`**：与当前 `filelist` 默认仿真无强绑定，集成更大系统时再统一包含即可。

## 参数与 `para.v`

Tile/阵列通过 `` `include "../../ref/DCIM/src/inc/para.v" `` 使用 `MODE_INT8`、`MODE_INT16` 等宏；默认数据宽度 128 bit。`DCIM_Array`/`DCIM_Tile` 的 **`BUF_ADDR_WIDTH` 参数化**：RTL 默认可为 14 bit，**`tb_DCIM_Array` 例化为 19 bit** 以容纳全图 im2col 激活地址空间。

---

## 目标网络：EdgeYOLO (`model/best.quant.onnx`)

- 输入：`1×3×320×320`（INT8 量化）
- 输出：3 scale 检测头（40×40, 20×20, 10×10），每 scale 输出 `3×8` = 24 通道
- 60 个 Conv 层（含 backbone + neck + detect head），全部 `group=1`
- 量化：per-channel scale + zero_point，权重 INT4（4-bit nibble），激活 INT8

### 卷积层 → im2col GEMM → DCIM 映射

DCIM 单 Tile：**CH_IN=16**（16 个输入通道/cycle），**CH_OUT=16**（产出 16 个输出通道）。

将 Conv(Cout, Cin, Kh, Kw) 经 im2col 展开为 GEMM：
- **K（累加维度）** = `Cin × Kh × Kw`
- **N（输出通道）** = `Cout`
- **M（空间像素）** = `Hout × Wout`（每像素为一"行"输入到 DCIM）

DCIM 映射：
- `acc_depth = K / 16`（K 必须整除 16）
- `num_tiles = Cout / 16`（Cout 必须整除 16）

### 各层 GEMM 尺寸总览

| im2col_K | Cout | acc_depth | tiles | 层数 | 代表层 |
|----------|------|-----------|-------|------|--------|
| 16       | 16   | 1         | 1     | 1    | model.2.m.0.cv1 |
| 32       | 16   | 2         | 1     | 2    | model.2.cv1 |
| 32       | 32   | 2         | 2     | 3    | model.2.cv3, model.4.m.X.cv1 |
| 64       | 32   | 4         | 2     | 2    | model.4.cv1 |
| 64       | 64   | 4         | 4     | 8    | model.4.cv3, model.6.m.X.cv1 |
| 128      | 32   | 8         | 2     | 2    | model.17.cv1 |
| 128      | 64   | 8         | 4     | 5    | model.6.cv1, model.14, model.20.cv1 |
| 128      | 128  | 8         | 8     | 3    | model.6.cv3, model.20.cv3, model.23.m.0.cv1 |
| 144      | 32   | 9         | 2     | 1    | model.1 (3×3, Cin=16) |
| 256      | 64   | 16        | 4     | 2    | model.13.cv1 |
| 256      | 128  | 16        | 8     | 6    | model.8.cv1, model.10, model.23.cv1 |
| 256      | 256  | 16        | 16    | 2    | model.8.cv3, model.23.cv3 |
| 288      | 64   | 18        | 4     | 1    | model.3 (3×3, Cin=32) |
| 512      | 256  | 32        | 16    | 1    | model.9.cv2 (1×1, Cin=512) |
| 576      | 64   | 36        | 4     | 5    | model.18, model.6.m.X.cv2 |
| 576      | 128  | 36        | 8     | 1    | model.5 (3×3, Cin=64) |
| 1152     | 128  | 72        | 8     | 1    | model.21 (3×3, Cin=128) |
| 1152     | 256  | 72        | 16    | 1    | model.7 (3×3, Cin=128) |

### 硬件限制 vs 需求

| 参数 | 当前硬件 | 网络最大需求 | 结论 |
|------|----------|-------------|------|
| ACC_MAX | 80 | 72 (model.7/21) | **满足** |
| NUM_TILES (chip_defs) | 16 | 16 (model.7/8.cv3/9.cv2/23.cv3) | **满足** |
| BUF_DATA_WIDTH | 128 bit | — | 满足 |
| BUF_ADDR_WIDTH | 14（默认 RTL）；`tb_DCIM_Array` 用 **19** 以覆盖全 M×acc 激活 | 见下文讨论 | 阵列参数可抬高 |

### 需要额外处理的层（不能直接单 pass 映射到当前 DCIM）

| 问题 | 涉及层 | 解决方案 |
|------|--------|---------|
| **K 不整除 16**：`K=108`（3×6×6） | model.0（首层） | 补零到 `K=112`（acc=7）或 `K=128`（acc=8），在 im2col 输入末尾 pad 0 |
| **Cout 不整除 16**：`Cout=24` | model.24.m.{0,1,2}（检测头） | 用 2 Tile（32 ch），丢弃多余 8 ch；或软件完成此小 Conv |
| **BatchNorm / ReLU / Add / Concat** | 57 BN + 57 ReLU + 加/拼接 | 需要后处理单元或在输出后由控制器做 requantize |
| **MaxPool (3 层)** | model.9 SPP | 纯内存操作，需单独支持 |
| **Resize (2 层)** | 上采样 (neck) | 最近邻/双线性插值，需单独模块或软件预处理 |

### 已经可以做的（当前 DCIM_Array 验证）

1. **所有 1×1 卷积** —— im2col 退化为简单通道向量乘累加（无空间展开），直接以 `num_rows = Hout×Wout` 行、`acc_depth = Cin/16` 即可
2. **所有 3×3 卷积**（K 整除 16 的层）—— 假设外部已完成 im2col 展开，每行 = K 个元素 → 按 `acc_depth = K/16` 送入
3. **最大 acc_depth=72**（model.7 / model.21）—— 测试台已有 `ACC=18` 的 72 行测试；改为 `ACC=72` 即可验证最大深度
4. **16 Tile 并行**（model.7: Cout=256, tiles=16）—— 改 `tb_DCIM_Array` 的 `NUM_TILES=16` 即可

### 建议先跑的 im2col 尺寸仿真（可直接在 `tb_DCIM_Array` 中添加）

以下维度已在 **`tb_DCIM_Array` Test 8–13** 中实现（**全分辨率 M**，`num_rows=M×acc_depth`；K 非 16 倍数见 Test 12 的 `zero_pad_im2col_k`）：

| 测试名 | 对应层 | acc_depth | num_rows (=M×acc) | NUM_TILES | 说明 |
|--------|--------|-----------|-------------------|-----------|------|
| Test 8 / im2col_3x3_s2 | model.3 | 18 | 28800 (1600×18) | 4 | 40² 全图 |
| Test 9 / im2col_3x3_deep | model.5 | 36 | 14400 (400×36) | 8 | 20² 全图 |
| Test 10 / im2col_max_acc | model.7/21 | 72 | 7200 (100×72) | 8 | 10² 全图 |
| Test 11 / im2col_1x1_wide | model.9.cv2 | 32 | 3200 (100×32) | 16 | 10² 全图 |
| Test 12 / model.0 pad | model.0 (K=108) | 7 | 179200 (25600×7) | 8 | 160²×acc，补零到 112 |
| Test 13 | model.1 | 9 | 57600 (6400×9) | 2 | 80² 全图 |

> **注意**：全图 Test 12/13 等仿真**耗时可观**；波形默认 `$fsdbDumpvars(1, tb_DCIM_Array)` 以控制 FSDB 体积。部署时仍需核对真实 IBUF 深度与带宽。

### 还需要做的工作

1. **im2col 控制器**：在 DCIM_Array 外做地址生成，将 feature map + kernel 映射为 IBUF 线性地址
2. **后处理 / requantize**：BN 融合 + ReLU + scale/shift → 下一层的 INT8 输入
3. **池化 / 上采样**：MaxPool(SPP)、Resize(上采样)
4. **控制调度**：多层复用 DCIM_Array（权重按层切换、Feature Map 双 buffer ping-pong）
5. **首层特殊处理**：K=108 不整除 16，需要在 im2col 输出侧做 zero-pad 到 112 或 128
6. **检测头**：Cout=24 不整除 16，需分配 2 Tile 后截断
7. **存储带宽评估**：im2col 后最大行 K=1152 元素（72×16 bytes = 1152 B），IBUF 深度需足够

