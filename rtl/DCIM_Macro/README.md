# DCIM_Macro — 计算核 RTL 副本

本目录是从 `rtl/ref/DCIM` 抽取的 **DCIM 矩阵乘 / 存算路径** 所需文件，供 **`rtl/tb/DCIM_Macro`** 仿真及上层 **`DCIM_Macro`** 集成引用。

## 目录

| 路径 | 内容 |
|------|------|
| **`dcim/`** | `dcim.v`、`memory`、`calculate_core`、`maArray`、`postProcess`、`ppCache`、`sramWrap` 等 **`.v`** |
| **`inc/`** | `para.v`、`counter.v`、`dff.v`、`pipe_stage.v`、`simTools.v`（供 `` `include ``） |
| **`model/`** | `model_rf.sv`（**`SIM`** 下 SRAM 行为模型） |

仿真 Makefile、`filelist.f`、**`transfer.py`（golden）** 在 **`rtl/tb/DCIM_Macro/sim/`**，请在仿真目录执行 `make`。
