# DCIM_Macro Testbench

| 文件 | 说明 |
|------|------|
| **`dcim_tb.v`** | 顶层 TB：权重 **`simToolUp`**、激活 **`simToolUp`**、输出 **`simToolDown`**，实例化 **`dcim`**（RTL 来自 **`rtl/DCIM_Macro/`**）。 |
| **`sim/`** | VCS 仿真：`Makefile`、`sim_vars.mk`、`filelist.f`、**`transfer.py`（golden 比对）**、`verdi_config_file`。 |

## 运行仿真（本仓库）

```bash
cd rtl/tb/DCIM_Macro/sim
export VERDI_HOME=/path/to/verdi    # 默认 FSDB=1 时需要
make compile
make run
make check                          # transfer.py 黄金模型
```

源码与 include 路径指向 **`../../../DCIM_Macro/`**（相对本 `sim/` 目录）。更完整的算法与端口说明见 **`rtl/ref/DCIM/sim/dcim/README.md`**（原理文档）。
