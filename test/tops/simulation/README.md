# VCS / FSDB 验证

所有 RTL 仿真在 eda02 使用 VCS，波形格式为 FSDB。

## Streamed Tile 主回归

```bash
cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-tops-ila
bash test/tops/simulation/run_dcim_stream_tile_vcs.sh
```

该用例是真实新 wrapper，不是抽离的算术核心模型。它固定使用64个 job、两个
acc-row，并检查：

- INT8 每个 acc-row 128 个 phase 连续无气泡，result II=2；
- native INT16 每个 acc-row 256 个 phase 连续无气泡，result II=4；
- weight BRAM 预载及 double wide-cache 换 bank；
- 512-bit×64 partial-sum BRAM；
- 两个 OBUF 端口写出的每个结果与 golden 一致。

产物：

```text
output/tops/simulation/stream_tile_vcs/
├── dcim_stream_tile.fsdb
├── sim.log
├── compile.log
└── vlogan.log
```

当前通过标志：

```text
STREAM_PASS mode=6 fires=256 results=64 expected=36992
STREAM_PASS mode=7 fires=512 results=64 expected=559232
PASS: unified INT8/native-INT16 streamed Tile
```

打开精简 Verdi 视图或自动截图：

```bash
nWave -ssf output/tops/simulation/stream_tile_vcs/dcim_stream_tile.fsdb \
  -play test/tops/simulation/verdi_stream.tcl
bash test/tops/simulation/capture_verdi_stream.sh \
  output/tops/simulation/stream_tile_vcs
```

INT8 的256次 fire 是两个 acc-row 各128拍；真正的峰值证据窗口选其中任意一个
完整 row：job 0..63，每个 job phase 0、1，共128拍。

## 其他回归

### Seamless repeat benchmark

单Tile focused测试检查轮次回卷和流水线细节：

```bash
bash test/tops/simulation/run_dcim_repeat_benchmark_vcs.sh
```

当前repeat=4结果：

```text
BENCHMARK_PASS repeats=4 fires=512 active_cycles=512 results=256
BENCHMARK_TOPS equivalent_8tile_ops_per_cycle=8192 tops_at_250mhz=2.048
```

### 完整BD/Decoder回归

完整仿真包含Host指令镜像、Decoder、8个Tile、BRAM/CDMA接口和结果检查。当前已通过：

```text
normal INT8:              128 PASS, 0 FAIL
native INT16 K=288:       128 PASS, 0 FAIL
CNN conv3s2 im2col链路:     64 PASS, 0 FAIL
repeat=4, all 8 Tiles:   2048 PASS, 0 FAIL
```

repeat=4的完整BD计数为：

```text
PEAK_INT8_METRIC tiles=8 any_cycles=512 all_cycles=512
                 skew_cycles=0 transaction_cycles=688
```

这里TOPS只使用 `all_cycles=512`；`transaction_cycles=688` 还包含权重准备及流水线
排空，特意不用于峰值算力计算。完整FSDB和两张讲解图位于：

```text
output/tops/simulation/bd_repeat4_vcs/
├── tb_lite_bd_module.fsdb
├── peak_repeat4_overview.png
├── peak_repeat4_boundary.png
└── sim.log
```

`overview` 展示ROUND 0..3、MASK8=`ff`的连续512周期与最终DONE；`boundary`
展示ROUND 0→1时JOB `...3e,3f,0,1...`、PHASE `0,1` 严格逐拍连续。

只做完整新 RTL 的快速语法分析：

```bash
bash test/tops/simulation/run_dcim_stream_compile_vcs.sh
```

测量未修改算术核心的固定延迟：

```bash
bash test/tops/simulation/run_dcim_core_latency_vcs.sh
```

旧的 `run_dcim_pipeline_vcs.sh` 仍可用于独立 arithmetic pipeline 回归，但新 Tile
已经能在真实 wrapper 中形成相同的连续流水，因此它不再承担实机性能证明。

完整 lite-BD 回归需在重新生成 BD export 后运行：

```powershell
python test/tops/simulation/run_peak_int8.py --export
```
