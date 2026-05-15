# Staging BRAM：由 axi_bram_ctrl 驱动
# VPU GB/WB：通过 AXI BRAM Controller 连接到 VPU 内部的 True Dual Port RAM

# ==============================================================================
# Global BRAM (数据暂存区) - 1MB
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 global_bram_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells global_bram_ctrl]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 global_bram
set_property -dict [list \
  CONFIG.use_bram_block {BRAM_Controller} \
  CONFIG.EN_SAFETY_CKT {false} \
  CONFIG.Memory_Type {Single_Port_RAM} \
  CONFIG.Write_Depth_A {32768} \
  CONFIG.Write_Width_A {256} \
  CONFIG.Read_Width_A {256} \
  CONFIG.Byte_Size {8} \
  CONFIG.Use_Byte_Write_Enable {true} \
] [get_bd_cells global_bram]

# ==============================================================================
# VPU GB (Global Buffer) AXI BRAM Controller - 128KB
# 连接到 VPU 内部的 True Dual Port RAM 的 Port A
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_gb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_gb_ctrl]

# ==============================================================================
# VPU WB (Weight Buffer) AXI BRAM Controller - 128KB
# 连接到 VPU 内部的 True Dual Port RAM 的 Port A
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_wb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_wb_ctrl]

# ==============================================================================
# VPU_AXI_Regs：配置/状态寄存器 + INST_Decoder 控制
# ==============================================================================
create_bd_cell -type module -reference VPU_AXI_Regs vpu_regs

# ==============================================================================
# INST_BRAM：指令存储区
# - Port A: AXI4-Lite Slave (供 XDMA 写入指令)
# - Port B: 直接 wire 读取 (供 INST_Decoder 读取指令)
# ==============================================================================
create_bd_cell -type module -reference INST_BRAM inst_bram

# ==============================================================================
# INST_Decoder：硬件指令解码器（使用 Verilog wrapper）
# - 从 inst_bram 读取指令
# - 控制 CDMA_Controller 和 VPU
# ==============================================================================
create_bd_cell -type module -reference INST_Decoder_wrapper inst_decoder

# ==============================================================================
# CDMA_Controller：CDMA 控制器（使用 Verilog wrapper）
# - 接收 INST_Decoder 的命令
# - 通过 AXI-Lite Master 控制 CDMA IP
# ==============================================================================
create_bd_cell -type module -reference CDMA_Controller_wrapper cdma_ctrl
