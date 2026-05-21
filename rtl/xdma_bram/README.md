# XDMA BRAM AXI-Lite Controller

`xdma_bram_axil_ctrl_top.v` 提供一个 AXI-Lite slave 控制器和一个 BRAM native 端口。

建议用法：

```text
PC
  |-- XDMA h2c/c2h M_AXI -> SmartConnect -> AXI BRAM Controller -> BRAM port A
  |
  `-- XDMA h2c/c2h M_AXI -> SmartConnect -> AXI-Lite regs
                                           xdma_bram_axil_ctrl_top -> BRAM port B
```

这样可以保持当前已经验证通过的 PCIe DMA BAR 布局，同时控制器本身仍然使用 AXI-Lite slave 寄存器。不要打开 XDMA IP 自带的单独 AXI-Lite master BAR；它会改变 XDMA control BAR 分配，可能导致 Windows XDMA 驱动启动失败。

## Register Map

| Offset | Name | Access | Description |
| --- | --- | --- | --- |
| `0x00` | `CTRL` | W | bit0 写 1 启动一次处理 |
| `0x04` | `STATUS` | R | bit0 busy, bit1 done, bit2 error |
| `0x08` | `SRC_ADDR` | RW | BRAM 输入 byte offset，必须按 BRAM word 对齐 |
| `0x0C` | `DST_ADDR` | RW | BRAM 输出 byte offset，必须按 BRAM word 对齐 |
| `0x10` | `LEN_BYTES` | RW | 处理字节数，必须按 BRAM word 对齐 |
| `0x14` | `OP` | RW | `0`: copy, `1`: xor32, `2`: add32, `3`: not32 |
| `0x18` | `OP_ARG` | RW | `xor32/add32` 的 32-bit 参数 |
| `0x1C` | `WORDS_DONE` | R | 已处理 BRAM word 数 |
| `0x20` | `VERSION` | R | 固定值 `0x58424101` |

默认参数下 BRAM 数据宽度是 256 bit，所以 `SRC_ADDR`、`DST_ADDR`、`LEN_BYTES` 都需要 32 字节对齐。
输入和输出区域建议不要重叠，避免处理过程中读写覆盖同一块 BRAM 数据。

## Test Flow

1. PC 通过 XDMA DMA 写 input 数据到 BRAM 的输入区域。
2. PC 通过 AXI-Lite 写 `SRC_ADDR`、`DST_ADDR`、`LEN_BYTES`、`OP`、`OP_ARG`。
3. PC 通过 AXI-Lite 写 `CTRL[0] = 1`。
4. PC 轮询 `STATUS.done`。
5. PC 通过 XDMA DMA 从输出区域读回数据。
6. Python 端用同样的 `copy/xor/add/not` 规则生成 golden data，并逐字节比较。
