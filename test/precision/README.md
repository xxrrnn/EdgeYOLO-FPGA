# 计算精度上板（INT8 / INT16）

本项证明 FPGA 存内计算阵列能做 **INT8×INT8** 和 **INT16×INT16**。
证据分两路，缺一不可：

1. **主机回读**：随机输入与权重送上板，读回乘加结果，与 Python golden 逐字一致。
2. **片上波形**：用仓库根目录现成的 `top.ltx` 抓 ILA。当前探针已经能看出走的是 8 位还是 16 位数据通路，**不必为精度测试重做 bitstream**。

网络端到端（YOLO / ResNet）只能说明应用层数值对，不能单独当作“片上确实按 INT16 相位在乘”的波形证据。峰值测试 `test/tops` 只覆盖 INT8。本目录补上随机矩阵乘。

## 现有 LTX 够不够？

够。`top.ltx` 对应 `peak_tops_ila`，接到 DCIM 阵列，六个探针：

| 探针 | 信号 | 精度测试里看什么 |
| --- | --- | --- |
| 0 | `peak_compute_mask[7:0]` | 8 个 tile 同时在算时应为 `8'hFF`。触发用 **`== 8'hFF`**，与峰值测试相同 |
| 1 | `peak_dcim_input[31:0]` | 该拍送进阵列的输入低 32bit |
| 2 | `peak_job[5:0]` | 像素/job 编号，本测例 0..7 |
| 3 | `peak_phase[1:0]` | **关键**。INT8 每个 job 只走 0、1 两拍（两个 4bit 相位拼一个 INT8）；INT16 每个 job 走 0、1、2、3 四拍（四个 4bit 相位拼一个 INT16） |
| 4 | `peak_result_valid` | 该拍写出结果 |
| 5 | `peak_result_data[31:0]` | 结果低 32bit，应与 `expected_ila.json` 里的 `probe5_first_result_low32` 一致 |

阵列把整数拆成 4bit 串行乘加：INT8 两拍，INT16 四拍。波形上 **phase 长度不同**，就是两种精度的片上证据。ILA 没有直接引出 mode 寄存器，不需要；phase 已经由 mode 决定。

## 测例

随机向量由 `golden_module_tb.py` 按 `--seed` 生成：

| 精度 | case | 随机内容 | 片上计算 |
| --- | --- | --- | --- |
| INT8 | `precision_int8_random` | 8 个像素的 INT8 输入，INT8 权重（满幅 -128..127） | INT8×INT8 → INT32 累加 |
| INT16 | `precision_int16_random` | 8 个像素的 INT16 输入（满幅 -32768..32767），INT16 权重 | INT16×INT16 → INT64 累加 |

同一 seed 可复现。产物在 `test/precision/output/<case>_seed<N>/`，含 `expected.hex`、`expected_ila.json`。

## 步骤

一律在仓库根目录。FPGA 已烧 `top.bit`，Vivado Lab 加载配对的 `top.ltx`。

先只出向量，确认 ILA 期望：

```text
python test/precision/run.py --prepare-only --seed 20260822
```

打开 Vivado Lab → Hardware Manager → 指定 `top.ltx`：

- Data Depth 1024，Trigger Position 约 64
- 触发：`peak_compute_mask == 8'hFF`
- Arm ILA

再上板（同一时刻只跑一路 XDMA）：

```text
python test/precision/run.py --mode int8 --seed 20260822
python test/precision/run.py --mode int16 --seed 20260822
```

主机打印 `PASS_HOST_PENDING_ILA` 表示回读与 golden 一致。然后看波形：

**INT8 必须同时满足**

- 每个 `peak_job` 上 `peak_phase` 为 0 然后 1，再换下一个 job
- `peak_result_valid=1` 时，`peak_result_data` 的第一个有效值等于该目录 `expected_ila.json` 的 `probe5_first_result_low32`

**INT16 必须同时满足**

- 每个 `peak_job` 上 `peak_phase` 为 0、1、2、3，再换下一个 job
- 同样用 probe5 对照 `expected_ila.json`

把两张波形截图放进中期报告即可：一张 INT8 两拍相位，一张 INT16 四拍相位。主机比对证明乘加数值正确，波形证明片上走了对应位宽的串行乘加。

## 和峰值 ILA 的差别

峰值脚本 `test/tops/fpga/run.py` 用 64 个 job、INT8、数周期算 TOPS。本测例同样 **8 tile 全开、同一触发 `8'hFF`**，但只有 8 个 job，并且多跑一组 INT16。INT8 波形上每个 job 两拍相位，INT16 每个 job 四拍。LTX 文件不用换。
