# rtl/chip — DCIM 多 Tile 阵列与单 Tile 封装

本目录在参考 DCIM 核心 RTL 之上，提供**单 Tile 封装**（`DCIM_Tile`）、**多 Tile 共享缓冲**的顶层（`DCIM_Array`），以及对应的仿真测试平台与 VCS 工程。

## 目录结构

| 文件 | 说明 |
|------|------|
| `DCIM_Tile.sv` | 单颗计算 Tile：内部例化 `dcim` 等参考核，对外通过 **ready/valid** 访问 IBUF 读与 OBUF 写。 |
| `DCIM_Array.sv` | 参数化 `NUM_TILES` 阵列：多路 Tile + `ibuf_rd_arbiter` + `obuf_wr_arbiter` + 各一颗 `ibuf`/`obuf`（双端口：Port A 给外部加载/读回，Port B 给 Tile）。 |
| `ibuf_rd_arbiter.sv` | IBUF 读 Round-Robin 仲裁；将 Tile 侧握手转为单端口 `en/addr`，并按 `IBUF_RD_LATENCY` 在对应 Tile 上打 `rd_data_valid`。 |
| `obuf_wr_arbiter.sv` | OBUF 写 Round-Robin 仲裁；单周期完成被选 Tile 的 `we/addr/din`。 |
| `tb_DCIM_Array.sv` | 阵列级测试：`NUM_TILES=8`，7 组 INT8 用例（`ACC` ∈ {0,1,2,4,8,18}、8/16/72 行等），共享激活、各 Tile 独立权重与输出区，golden 比对。 |
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
- **Test 1**：`ACC=0`，8 行，各 Tile 不同权重模板。 **Test 2**：`ACC=2` 随机。 **Test 3**：`ACC=4`。 **Test 4**：`ACC=8`（8 行仅 1 组输出）。 **Test 5**：`ACC=4`，16 行。 **Test 6**：`ACC=1`。 **Test 7**：`ACC=18`，72 行（仲裁与读延迟压力更大）。
- 每轮统计 `passed_tests` 时对比本轮开始前后 `total_errors`，避免沿用旧逻辑误计。
- 修改 Tile 数量时同步调整 `ACT_BASE` / `OUT_STRIDE` / `MAX_TEST_ROWS`，并保证 `num_rows % acc_depth == 0`（`acc_depth=0` 表示按 1 行一组）。

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

Tile/阵列通过 `` `include "../../ref/DCIM/src/inc/para.v" `` 使用 `MODE_INT8`、`MODE_INT16` 等宏；阵列默认数据宽度 128 bit、地址宽度 14 bit，与 `DCIM_Array`/`tb_DCIM_Array` 一致。
