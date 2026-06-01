# DCIM Tile/Array 低层调试测试

工作目录：`rtl/chip/tb`

## 结论：后续主测试使用 `rtl/tb/lite_bd/module_tb`

后续数值级别等同验证建议统一使用：

```bash
cd rtl/tb/lite_bd/module_tb
make sim MODULE_CASE=dcim_matmul MODULE_VARIANT=dcim_tiny_1x1
```

或者跑 DCIM 极限回归：

```bash
cd rtl/tb/lite_bd/module_tb
make rebuild-suite MODULE_CASE=dcim_matmul BATCH_SUITE=dcim_extreme QUANT=all STOP_ON_FAIL=0 LOG=1
```

原因：`module_tb` 跑的是完整 lite BD 路径，能覆盖：

```text
inst.hex → INST_Decoder → CDMA/VPU/DCIM → OBUF → expected.hex 逐 word 比较
```

这比本目录单独实例化 `DCIM_Array` 更接近上板数据流，也能同时发现 BD wrapper 参数固化、地址映射、decoder 配置、CDMA 搬运、VPU 后处理和 OBUF 布局问题。

## 本目录定位

本目录只保留为低层 smoke/debug：

- `DCIM_Tile`：单 Tile 底层调试入口
- `DCIM_Array`：阵列 + 共享 IBUF/OBUF 的快速 smoke

`Group` 层已退出主 flow，不再作为功能验证对象。

当前 DCIM RTL 主线：

```text
DCIM_Array = NUM_TILES × DCIM_Tile + 1 套共享 IBUF + 1 套共享 OBUF
```

当前 `chip_defines.vh` 参数：

- `DCIM_NUM_TILES=4`
- `DCIM_CH_IN=64`
- `DCIM_CH_OUT=64`
- `DCIM_CYCLE=128`
- `DCIM_BUF_DATA_WIDTH=128`

INT8 模式下，每 Tile 的逻辑输出通道数为 `CH_OUT/2=32`，4 Tile 在 250MHz 下理论峰值为 2.048 TOPS。

## 可用命令

```bash
make help          # 查看命令说明
make test_smoke    # 低层 array smoke
make test_array    # test_smoke 别名
make test          # test_smoke 别名
make fsdb          # 带 FSDB 跑 array smoke
make verdi         # 打开 array smoke 波形
make clean         # 清理仿真产物
```

`test_smoke` 会编译并运行 `tb_DCIM_Array_64_smoke.sv`。该 smoke 使用当前 `chip_defines.vh` 参数，覆盖：

- 4 个 Tile 全部使能
- 每个 Tile 加载 `CYCLE=128` 个 128-bit weight word
- INT8 activation 按 `CH_IN=64` 多 beat 读取
- 每 Tile 输出 `CH_OUT/2=32` 个 INT32 逻辑通道，即 8 个 128-bit OBUF word
- 权重全 1、激活全 1，期望每个输出通道为 64

成功时日志包含：

```text
PASS: tb_DCIM_Array_64_smoke NUM_TILES=4 CH_IN=64 CH_OUT=64 CYCLE=128
```

`compile_tile/sim_tile/test_tile` 仅保留为 `DCIM_Tile` 单体调试入口。若继续使用，需要确保 `tb_DCIM_Tile.sv` 的参数、golden、输出检查已同步到 `CH_IN=64/CH_OUT=64/CYCLE=128`，否则它只是在验证旧参数行为。

## 数值等同判据

后续请以 `rtl/tb/lite_bd/module_tb` 为准：

1. Python golden 生成 `expected.hex`。
2. testbench preload 输入/权重/指令。
3. RTL 完整执行 `INST_Decoder → CDMA/VPU/DCIM → OBUF`。
4. 从 OBUF 读回结果，逐 128-bit word 对比 `expected.hex`。
5. 以 module_tb 的 `MODULE CHECK ... PASS` 作为主要数值等同结论。
