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

需要交互检查 OOC 网表时才加 `DCIM_OOC_WRITE_DCP=1`。完整设计推荐先只生成共享
`post_opt.dcp`，随后从同一 checkpoint 只跑默认的强时序路线：

```bash
BUILD_TAG=tops_ila_timing_hardened STOP_AFTER=opt FLOW_MODE=project \
vivado -mode batch -source scripts/chip-lite/run.tcl

BUILD_TAG=tops_ila_timing_hardened SOURCE_TAG=tops_ila_timing_hardened \
RESUME_FROM=opt PLACE_DIRECTIVE=ExtraTimingOpt FLOW_MODE=project \
vivado -mode batch -source scripts/chip-lite/run.tcl
```

该单路线使用 `ExtraTimingOpt → AggressiveExplore → NoTimingRelaxation`，route 后再做
增量 `AggressiveExplore` 与 hold fix。`config.tcl` 中的多策略 retry 仍作为兜底保留，
但不再是正常构建的前提。

最终8-Tile OOC预检结果保存在
`output/tops/fpga/dcim_stream_ooc_timingopt5/`：0 error、0 critical warning，
`WNS=+1.741 ns @ 250 MHz`，最大普通信号扇出748。与repeat功能基线相比，CLB LUT
减少19.37%、CLB Register减少23.83%，DSP/BRAM/URAM数量不变。
