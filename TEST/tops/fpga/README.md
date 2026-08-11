# FPGA 实机 INT8 峰值测试

## 前提

- Windows XDMA 驱动已枚举设备；
- FPGA 加载当前 streamed RTL 生成的 `.bit`；
- Hardware Manager 加载同一次实现的 `.ltx`；
- 实际 DCIM 时钟频率已知，目标为 250 MHz。

不要混用不同 attempt 的 `.bit` 与 `.ltx`。

## ILA

`peak_tops_ila` 只保留六个必要探针：

| probe | 信号 | 用途 |
|---|---|---|
| 0 | `peak_compute_mask[7:0]` | 8 Tile 同拍真实计算 |
| 1 | `peak_dcim_input[31:0]` | 与 Host 输入对应 |
| 2 | `peak_job[5:0]` | 连续 job 0..63 |
| 3 | `peak_phase[1:0]` | INT8 为 0、1 |
| 4 | `peak_result_valid` | 结果判定周期 |
| 5 | `peak_result_data[31:0]` | 与 Host 结果对应 |

推荐 Data Depth=1024、Trigger Position=256、Window Count=1，触发条件为
`peak_compute_mask == 8'hff`。Arm 后运行：

```powershell
python TEST/tops/fpga/run_peak_int8.py
```

脚本生成 `M=64,K=64,N=128` 固定 seed 数据，上传激活和8组权重，执行整层
streamed DCIM，回读并比较全部 2048 个 128-bit 结果字。Host 通过后先得到
`PASS_HOST_PENDING_ILA`。

普通单次峰值正确性测试（repeat=1，也是默认值）：

```powershell
python TEST/tops/fpga/run_peak_int8.py --repeat-count 1
```

连续 benchmark 测试由同一条 Host 命令配置轮数，例如4轮波形证明：

```powershell
python TEST/tops/fpga/run_peak_int8.py --repeat-count 4 --timeout-s 120
```

用于功耗表稳定读数时可以增大轮数。例如250 MHz下每轮128周期，
`repeat-count=10000000` 的纯计算窗口约5.12秒。计算结束后仍只回读并检查最后一轮
的同一组2048个128-bit结果字。

## 波形与报告

正确的峰值窗口应为：

- `peak_compute_mask=ff` 连续 `128 × repeat_count` 个采样周期；
- `peak_job=0..63`，每个 job 恰有 phase 0、1；
- 每个轮次边界必须是 `job63/phase1` 紧邻 `job0/phase0`；
- job0 两拍输入预期为 `b92d4ab3`、`db342919`；
- `peak_result_valid=1` 时，第一结果预期为 `00001778`。

随后由 Host 计算并生成最终报告：

```powershell
python TEST/tops/fpga/run_peak_int8.py --report-only --ila-active-cycles 512 --frequency-mhz 250
```

上例是repeat=4，因此计算量为 `4×2×64×64×128=4,194,304 OPS`，512周期@250 MHz对应
`2.048 TOPS@INT8`。只有 mask 全为 `ff` 的连续周期可以计入。

`repeat-count=1` 时仍使用1,048,576 OPS和128周期，计算结果同为2.048 TOPS。

只生成数据或强制重生成：

```powershell
python TEST/tops/fpga/run_peak_int8.py --prepare-only
python TEST/tops/fpga/run_peak_int8.py --regenerate
```

## 完整 BD 接口检查

启动耗时较长的综合和布局布线前，可先检查 streamed DCIM、ILA、AXI BRAM
以及指令寄存器接口能否在完整 `chip-lite` Block Design 中正确连接：

```bash
BUILD_TAG=dcim_stream_bdcheck vivado -mode batch \
  -source TEST/tops/fpga/validate_stream_bd.tcl
```

该检查会执行 BD 校验并生成 wrapper，但不会启动各 IP 的 OOC 综合。日志末尾出现
`STREAM_BD_VALIDATE_PASS` 即表示接口集成通过。

## 时序预检与单路线实现

本分支在进入实现前做了三类结构性硬化：

- 乘法、加法树、merge/accumulate 等纯数据寄存器不再承载 Tile 级异步复位；
  valid/状态寄存器仍保持确定复位，功能边界不变；
- 权重 BRAM 输出增加一级寄存，双 bank 选择改为每个 128-bit word 的本地副本，
  避免 BRAM cascade 长路径和单个 8194-load 选择网；
- 16 个 Tile IBUF/OBUF AXI BRAM controller 与三个本地 reset synchronizer 按
  `2+3+3` 固定到对应 SLR，避免 controller、URAM 与复位源跨 SLR。

先运行 8-Tile DCIM OOC 综合；默认只写报告，避免每轮序列化约 300 MB DCP：

```bash
DCIM_OOC_DIR=output/tops/fpga/dcim_stream_ooc_timingopt \
vivado -mode batch -source TEST/tops/fpga/synth_dcim_stream_ooc.tcl
```

需要交互检查 OOC 网表时才加 `DCIM_OOC_WRITE_DCP=1`。完整设计直接用一个命令从
工程创建和综合开始，一直运行到 routing、bitstream 和 `.ltx`：

```bash
BUILD_TAG=tops_ila_ranked FLOW_MODE=project IMPL_FLOW=two_stage \
IMPL_PLACE_TOP_N=0 IMPL_ROUTE_VARIANTS=4 \
PLACE_THREADS=24 ROUTE_THREADS=16 SYNTH_JOBS=128 \
vivado -mode batch -source scripts/chip-lite/run.tcl
```

`run.tcl` 先完成 OOC/IP 综合、顶层综合和 `opt_design`，随后从本轮自动生成的
`post_opt.dcp` 并行运行 `ExtraTimingOpt`、`Explore`、`Default`，以及
SLR-aware 的 `SSI_SpreadLogic_high` 四个唯一 place，按
WNS、TNS 和失败端点数排序。默认
`IMPL_PLACE_TOP_N=0` 表示取前一半并向上取整，即选 top-2；每个入选 place 展开
4种 phys_opt/route 组合，共8个 routing worker。每个 worker 的 phys_opt、route 和
post-route 修复均受 `ROUTE_THREADS=16` 限制，总并发上限约128 CPU线程。最终按
timing 状态、WNS、WHS 选择获胜项，只对 winner 发布统一的 `post_route.dcp`、
`top.bit` 和 `top.ltx`。设置 `IMPL_FLOW=sequential` 可退回原有顺序 retry；
`IMPL_FLOW=full_race` 保留为不筛选的诊断备选。Project run 已经保存综合 DCP，因此默认跳过重复的
`SynOutputDir/post_synth.dcp` 和完整 post-synth 诊断报告；仅在需要这些中间产物时
设置 `FULL_SYNTH_REPORTS=1`。

各 attempt 默认复用 `post_opt.dcp` 内嵌的 XDC/Pblock，避免重复读取约束。如果
刻意使用旧 DCP 验证新版 `chip_timing.xdc`，设置
`RACE_RELOAD_XDC=1`。

若综合后 implementation 中断，可使用同一 tag 执行
`make resume TAG=tops_ila_ranked FROM=opt`，无需重新综合；也仍支持从单个
`post_place.dcp` 或 `post_phys_opt.dcp` 继续调试。

每次完成后还会生成 `build/lite/<tag>/summary/two_stage_impl_summary.md`：顶部直接
给出推荐 winner、验收裕量和 `.bit/.ltx/.dcp` 链接，随后列出全部 place 和 route
的 WNS/TNS/WHS/THS、失败端点和错误原因；同目录的两个 TSV 便于脚本继续处理。

同一生产脚本已通过 `impl_rank_smoke` 小 RTL 实测：4 个 place 全部成功，top-2
展开4种 route，严格启动8个 route；8个结果均为 `WNS=+1.358 ns`、
`WHS=+0.088 ns`，最终正确发布 winner DCP 和 Markdown 汇总。复现方法见
`TEST/tops/fpga/impl_rank_smoke/README.md`。

最终8-Tile OOC预检结果保存在
`output/tops/fpga/dcim_stream_ooc_timingopt5/`：0 error、0 critical warning，
`WNS=+1.741 ns @ 250 MHz`，最大普通信号扇出748。与repeat功能基线相比，CLB LUT
减少19.37%、CLB Register减少23.83%，DSP/BRAM/URAM数量不变。
