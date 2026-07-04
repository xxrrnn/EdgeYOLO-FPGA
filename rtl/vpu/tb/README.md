# VPU Testbench

VPU 模块级与局部联合仿真。与板上路径一致的 **lite Block Design 系统级仿真** 在独立目录：

**[`rtl/tb/lite_bd/README.md`](../../tb/lite_bd/README.md)**

```bash
bash rtl/tb/lite_bd/sim/run_bd_sim.sh
```

---

## 目录结构

```
rtl/vpu/tb/
├── standalone/     # QA、DQA、im2col、INST_Decoder 单元 TB
├── integration/    # im2col + DCIM 等联合仿真（无完整 BD）
├── legacy/         # 旧 TB，仅供参考
└── sim/
    ├── vcs_common.sh
    ├── run_vcs_standalone.sh
    ├── run_vcs_dqa_standalone.sh
    ├── run_vcs_qa_standalone.sh
    └── run_xsim_*_standalone.sh
```

---

## 单元仿真（VCS）

```bash
bash rtl/vpu/tb/sim/run_vcs_standalone.sh
bash rtl/vpu/tb/sim/run_vcs_dqa_standalone.sh
bash rtl/vpu/tb/sim/run_vcs_qa_standalone.sh

# 快速冒烟
ONLY_CASE=2 STANDALONE_SCALE=0.1 bash rtl/vpu/tb/sim/run_vcs_qa_standalone.sh
```

| 变量 | 默认 | 含义 |
|------|------|------|
| `STANDALONE_SCALE` | `1.0` | golden 空间缩放 |
| `ONLY_CASE` | (all) | `0`=L1, `1`=L2, `2`=L3 |
| `XILINX_VCS_LIB` | 见 `vcs_common.sh` | 预编译 Xilinx IP 库 |
| `LITE_GEN` | `build/lite/lite.gen/sources_1/ip` | 浮点 IP sim 模型 |

一次性 VCS 库：`vivado -mode batch -source scripts/sim/compile_xilinx_vcs_lib.tcl`

建议验证顺序：`standalone` → `integration` → [`rtl/tb/lite_bd`](../tb/lite_bd/README.md)
