# DCIM 双模式与峰值算力测试

## Host 可配置的两种执行模式

两种模式共用完全相同的 INT8/native-INT16 数据流、权重映射和结果格式，切换只由
`OP_DCIM_LAYER` 的 `benchmark_repeat_count` 决定：

- `repeat_count=1`：普通 end-to-end 模式。每个 DCIM layer 执行一次，保留任意
  `num_pixels`、多 `acc_depth`、多 block 以及后续 DQA/QA 等网络映射流程；
- `repeat_count>1`：repeat benchmark 模式。固定使用恰好64个 job、INT8、
  `acc_depth=1`，一次预载权重后连续执行指定轮数，用于 TOPS 和稳定功耗测试。

Host 指令体 word 7 保存32-bit repeat count。Decoder 先写
`DCIM_REG_REPEAT_COUNT(0x024)`，再通过 `DCIM_REG_CTRL.bit2` 使能 benchmark。
写入0会归一化为1，旧命令及未填写该字段的软件因此仍按普通模式工作。

benchmark 每轮都读取相同的64-job输入并覆盖同一结果地址，最后一轮结果留在
Host 可见空间供完整比较。轮间不重新加载权重、不重新启动 Tile，也不产生计算
气泡；这样功耗测试可以把 repeat 设置得足够大，而不会不断消耗输出存储空间。

## RTL 数据流

- `DCIM_Activation_Stream`：两个128-bit IBUF端口每拍提供256-bit激活；INT8按
  phase 0/1连续发射，native INT16按phase 0..3连续发射；
- `DCIM_Weight_Cache`：权重从BRAM预取到双bank宽缓存，使当前计算与下一组预取
  解耦；
- `DCIM_Tile`：组织 acc-row、64-job micro-batch 和核心流水线，不改变每个Tile的
  channel/weight mapping；
- `DCIM_Partial_Sum_RAM`：保存多 `acc_depth` 的中间32-bit累加结果；
- `DCIM_Result_Stream`：完成结果合并并通过双128-bit OBUF端口写回；benchmark
  在轮尾把输出地址回卷，普通模式则正常推进block/row；
- `DCIM_Array`：并行实例化8个Tile。8 Tile的有效计算掩码为 `8'hff` 时，每周期
  完成4096次INT8乘法和4096次加法，即8192 OP/cycle。

INT8 实机与仿真使用同一个完整 micro-batch：

- `M=64, K=64, N=128`，8 个 Tile 全部启用；
- 每个 job 有 phase 0/1，共 128 个连续有效周期；
- 运算量 `2 × M × K × N = 1,048,576 OPS`；
- 250 MHz 下为 `1,048,576 / (128 / 250 MHz) = 2.048 TOPS`。

峰值窗口只统计 `peak_compute_mask == 8'hff` 的真实 DCIM phase，不包含 Host、
CDMA、权重预载或结果写回。Host 仍负责比较结果并根据周期数计算 TOPS。

## 快速入口

在 eda02 运行 unified streamed Tile 的 VCS/FSDB 回归：

```bash
bash test/tops/simulation/run_dcim_stream_tile_vcs.sh
```

它同时验证 INT8、native INT16、64-job 连续发射、两层 acc partial sum 和最终
OBUF 数据。FSDB 位于 `test/tops/output/simulation/stream_tile_vcs/`。

实机测试前先加载新 `.bit/.ltx` 并 arm ILA：

```powershell
python test/tops/fpga/run.py
python test/tops/fpga/run.py --report-only --ila-active-cycles 128
```

## 判定标准

1. Host 比较全部 2048 个 128-bit 输出字通过；
2. `peak_compute_mask == ff` 连续 128 周期；
3. `peak_job` 为 0..63，每个 job 的 `peak_phase` 严格为 0、1；
4. `peak_dcim_input` 与 Host 输入一致；
5. `peak_result_valid` 时的 `peak_result_data` 与 Host 结果一致；
6. Host 按下式得到不低于 2 TOPS：

```text
TOPS = (2 × M × K × N) × frequency_hz / active_cycles / 1e12
```

当前 VCS 实测 phase 无气泡，INT8 result II=2、native INT16 result II=4。旧的
focused arithmetic-pipeline 用例仍保留用于核心回归，但不再作为 wrapper 性能替代证据。

repeat=4 的完整BD实测为 `all_cycles=512`、`skew_cycles=0`，因此：

```text
TOPS = 8192 OP/cycle × 250,000,000 cycle/s / 1e12 = 2.048
```

## OOC 综合预检

在完整布局布线前对8-Tile `DCIM_Array` 做250 MHz OOC综合。下表以加入repeat后的
功能网表为基线，对比最终时序硬化网表：

| 资源 | repeat基线 | timing hardened | 变化 |
|---|---:|---:|---:|
| CLB LUT | 661,499 | 533,387 | -128,112 (-19.37%) |
| CLB Register | 717,218 | 546,290 | -170,928 (-23.83%) |
| BRAM Tile | 208 | 208 | 0 |
| URAM | 192 | 192 | 0 |
| DSP | 7,680 | 7,680 | 0 |

未布局 OOC setup WNS 从 `+1.605 ns` 提升到 `+1.741 ns @ 4.000 ns`。综合为
0 error、0 critical warning；DSP 异步复位打包 warning 和权重 BRAM 输出级 warning
均为0。原先72,702-load核心复位、8,194-load权重bank选择以及4,084-load activation
payload复位均已消失，最终最大普通信号扇出为748。

该结果说明时序硬化没有减少8-Tile乘加规模，也没有增加片上存储；它仍是未布局的
网表预检，不能替代完整 post-route timing 结论。
