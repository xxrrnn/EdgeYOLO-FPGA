# XDMA DCIM HBM TB usage

这个目录放的是 `PE` 大矩阵分块乘法相关测试。当前路径已经迁到：

- `rtl/tb/xdma_dcim_hbm/tb_pe_large_gemm.sv`
- `rtl/tb/xdma_dcim_hbm/tb_pe_large_gemm_int16.sv`

---

## 1) INT8*INT8 大矩阵分块测试

文件：`tb_pe_large_gemm.sv`

测试目标：

- 验证 `PE` 在大行数场景（`M_ROWS=128`）下，支持 K 维分块累加。
- `K_TILES=8`，每个 tile 先检查输出不含 `X/Z`（避免未初始化或读时序假通过）。
- 再把 8 个 tile 写回同一目的地址：
  - 第一次 `accumulate_type=0`（初始化）
  - 后续 `accumulate_type=1`（累加）
- 最终结果与“逐 tile 输出结果的 lane-wise 累加”逐行对比。

说明：

- `accumulate_type=2`（减法）已从 RTL 去除，TB 不再覆盖该模式。
- 现在的 TB 先验证单 tile 输出稳定（无 `X/Z`），再验证累加链路。
- 本测试重点仍是单个 `PE` 的分块累加链路，不是 host 侧 AXI/CDMA 系统联调，也不是完整多 `N` tile 的系统级 blocked GEMM。

运行：

```bash
vivado -mode batch -source rtl/tb/xdma_dcim_hbm/run_xsim_pe_large_gemm.tcl
```

---

## 2) INT16*INT16 大矩阵分块测试

文件：`tb_pe_large_gemm_int16.sv`

测试目标：

- 在 `MODE_INT16` 下验证 K 分块累加链路可用。
- `tb_pe_large_gemm_int16.sv` 使用：
  - `M_ROWS=64`
  - `K_TILES=4`
- 判定标准同 INT8：
  - 每个 tile 的 DUT 输出必须无 `X/Z`
  - 统一目的区结果必须等于每个 tile 输出的 lane-wise 累加

运行：

```bash
vivado -mode batch -source rtl/tb/xdma_dcim_hbm/run_xsim_pe_large_gemm_int16.tcl
```

---

## 3) 关键执行流程（两个 TB 都一样）

每个 tile 的执行顺序：

1. 往 IBUF 写权重 tile（`W_BASE_BYTE`）
2. 往 IBUF 写激活 tile（`A_BASE_BYTE`）
3. 配置 `dcim_*` 控制信号并 `dcim_start` 启动
4. 轮询 `dcim_done`，若 `dcim_error` 则 `fatal`
5. 从 OBUF 读回结果，先检查无 `X/Z`
6. 所有 tile 跑完后，再检查累加目标区是否等于所有 tile 输出的 lane-wise 累加

补充：

- INT16 激活按照每行 16 个 `int16` 存放（每行 32B，1 行/word）。
- INT16 权重按照 `16x4 int16` tile 存放（总 128B，4 words）。
- `accumulate_type=1` 的 OBUF 合并逻辑在 RTL 中是按 `WD3` lane 局部相加，不带跨 lane 进位，所以 TB 对累加目标区也按同样的 lane-wise 语义构造期望值。

---

## 4) 这个 TB 现在验证了什么

- 单个 INT8 / INT16 tile 的输出是否稳定（无 `X/Z`）。
- K 分块多次回写同一目的区时，`accumulate_type=0/1` 的行为是否与 RTL 规定的 lane-wise 累加一致。
- 大行数下地址生成、FSM、done/error 流程是否能稳定跑通。

仍未覆盖：

- `dcim_acc=2/4/8/16` 的 `postProcess` 行折叠模式。
- 多个 `N` tile 拼接成完整大矩阵 `C` 的系统级 blocked GEMM。
- AXI/XDMA/CDMA 联调。

---

## 5) 关于 Python 测试与 BRAM IP

- 这个 TB 是纯 RTL 级（`dcim_tdp_byte_ram` 推断 RAM），理论上可以改造成 Python/cocotb 驱动。
- 若要直接仿真 Xilinx `.xci` Block Memory IP，建议继续使用 Vivado `xsim`（或已编译 Xilinx 仿真库的第三方仿真器）。
- 当前目录下脚本默认走 Vivado `xsim`，避免 IP 库兼容问题。
