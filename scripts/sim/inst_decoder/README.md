# INST_Decoder 系统仿真

## 目录结构

```
sim/inst_decoder/
├── README.md                    # 本文件
├── create_sim_bd.tcl           # 创建仿真专用 Block Design
├── setup_sim.tcl               # 在现有项目中设置仿真
├── run_sim.tcl                 # 运行仿真
├── run.sh                      # 一键运行脚本
└── tb_inst_decoder_system.sv   # 系统级 Testbench
```

## 仿真目标

测试完整的数据通路：
```
INST_Decoder → CDMA_Controller → Xilinx AXI CDMA IP → AXI BRAM
```

**不模拟任何接口**，使用 Vivado 的真实 IP 仿真模型。

## 使用方法

### 方法 1: 使用现有项目

```bash
# 确保已经构建了 Vivado 项目
cd sim/inst_decoder
vivado -mode batch -source setup_sim.tcl

# 然后在 Vivado GUI 中运行仿真
vivado build/vpu/vpu.xpr
# Run Simulation -> Run Behavioral Simulation
```

### 方法 2: 创建独立仿真项目

```bash
cd sim/inst_decoder
vivado -mode batch -source create_sim_bd.tcl
```

## 测试内容

1. **CDMA 数据搬运**: 通过 INST_Decoder 发起 CDMA 传输
2. **完整握手**: 验证 CDMA_Controller 与 CDMA IP 的 AXI-Lite 握手
3. **数据完整性**: 验证数据正确从源地址搬运到目标地址

## 注意事项

- 需要 Vivado 2024.2 或更高版本
- 仿真时间较长（包含真实 IP 模型）
- 确保 IP 的仿真模型已生成
