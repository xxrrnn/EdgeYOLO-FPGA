# VPU 构建和测试流程

## 脚本执行顺序

### 1. 创建项目 - `0_build.tcl`
创建Vivado项目，添加基础配置和约束文件。

```bash
cd /home/triton/task/YOLO_on_FPGA/fpga/EdgeYOLO-FPGA
vivado -mode batch -source scripts/vpu/0_build.tcl
```

### 2. 创建Block Design - `1_bd.tcl`
创建VPU Block Design，包含：
- Global_VPU_top (VPU核心)
- XDMA (PCIe接口)
- INST_Decoder (指令解码器)
- CDMA_Controller (DMA控制器)
- AXI CDMA IP
- 各种BRAM和互连

```bash
vivado -mode batch -source scripts/vpu/1_bd.tcl
```

### 3. 仿真验证 - `2_sim.tcl`
在Vivado中运行完整硬件仿真，验证：
- INST_Decoder 指令解析
- CDMA 数据搬运
- VPU 计算功能

**批处理模式（无GUI）**：
```bash
vivado -mode batch -source scripts/vpu/2_sim.tcl
```

**GUI模式（查看波形）**：
```bash
vivado -mode gui -source scripts/vpu/2_sim.tcl
```

仿真内容：
- 通过INST_Decoder配置CDMA搬运64字节数据
- 验证global_bram → VPU GB数据搬运
- 可扩展添加VPU计算测试

### 4. 综合和实现 - `run.tcl` 或 `3_synth.tcl`
生成bitstream用于FPGA烧录。

```bash
vivado -mode batch -source scripts/vpu/run.tcl
```

## 测试脚本

### Python硬件测试

在烧录bitstream后，运行Python测试：

**基础INST_Decoder测试**：
```bash
cd tests/vpu
python3 test_inst_decoder.py
```

**VPU Max Pooling完整测试**：
```bash
cd tests/vpu
python3 test_vpu_mp.py
```

## 地址映射

- `0x1000_0000`: global_bram (1MB) - 数据区
- `0x1020_0000`: inst_bram (1MB) - 指令区
- `0x1040_0000`: VPU GB (128KB)
- `0x1042_0000`: VPU WB (128KB)
- `0x1044_0000`: VPU_AXI_Regs (4KB) - 配置+状态+解码器控制

## 常用命令

### 查看BD状态
```bash
vivado -mode tcl
open_project build/vpu/vpu.xpr
open_bd_design [get_files vpu.bd]
validate_bd_design
```

### 重新生成wrapper
```bash
reset_target all [get_files vpu.bd]
generate_target all [get_files vpu.bd]
make_wrapper -files [get_files vpu.bd] -top -force
```

## 调试技巧

1. **仿真失败**：检查层次化路径是否正确（RTL模块实例名）
2. **硬件不响应**：
   - 确认bitstream是最新的
   - 检查上升沿检测逻辑
   - 使用Python调试脚本检查寄存器值
3. **CDMA传输失败**：检查地址映射和AXI互连配置

## 已知问题

1. ~~双重上升沿检测问题~~ - 已修复（VPU_AXI_Regs.v）
2. CDMA传输>32字节时部分数据丢失 - 需要进一步调试AXI burst对齐
