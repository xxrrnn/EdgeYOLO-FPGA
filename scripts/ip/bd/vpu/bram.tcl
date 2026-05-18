# HBM BRAM（暂时替代HBM）：由 axi_bram_ctrl 驱动
# VPU GB/WB：通过 AXI BRAM Controller 连接到 VPU 内部的 True Dual Port RAM
#
# 参数来自 vpu_defines.vh，通过 parse_vpu_defines.tcl 解析

# ==============================================================================
# 加载 VPU 参数
# ==============================================================================
set script_dir [file dirname [info script]]
source [file join $script_dir "../../../common/parse_vpu_defines.tcl"]
parse_vpu_defines [file join $script_dir "../../../../rtl/vpu/vpu_defines.vh"]

# 从解析的参数中获取值
set vpu_bandwidth     [get_vpu_param VPU_BANDWIDTH 256]
set hbm_bram_depth    [get_vpu_param HBM_BRAM_DEPTH 32768]
set gb_depth          [get_vpu_param GB_DEPTH 4096]
set wb_depth          [get_vpu_param WB_DEPTH 1024]

puts "INFO: VPU BRAM parameters:"
puts "  VPU_BANDWIDTH  = $vpu_bandwidth"
puts "  HBM_BRAM_DEPTH = $hbm_bram_depth"
puts "  GB_DEPTH       = $gb_depth"
puts "  WB_DEPTH       = $wb_depth"

# ==============================================================================
# HBM BRAM (暂时替代HBM的外部数据暂存区) - 由 HBM_BRAM_DEPTH 和 VPU_BANDWIDTH 决定大小
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 global_bram_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH $vpu_bandwidth \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells global_bram_ctrl]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 global_bram
set_property -dict [list \
  CONFIG.use_bram_block {BRAM_Controller} \
  CONFIG.EN_SAFETY_CKT {false} \
  CONFIG.Memory_Type {Single_Port_RAM} \
  CONFIG.Write_Depth_A $hbm_bram_depth \
  CONFIG.Write_Width_A $vpu_bandwidth \
  CONFIG.Read_Width_A $vpu_bandwidth \
  CONFIG.Byte_Size {8} \
  CONFIG.Use_Byte_Write_Enable {true} \
] [get_bd_cells global_bram]

# ==============================================================================
# VPU GB (Global Buffer) AXI BRAM Controller
# 连接到 VPU 内部的 True Dual Port RAM 的 Port A
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_gb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH $vpu_bandwidth \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_gb_ctrl]

# ==============================================================================
# VPU WB (Weight Buffer) AXI BRAM Controller
# 连接到 VPU 内部的 True Dual Port RAM 的 Port A
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_wb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH $vpu_bandwidth \
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
# - 通过 AXI-Lite Master 控制 CDMA IP（点对点连接）
# ==============================================================================
create_bd_cell -type module -reference CDMA_Controller_wrapper cdma_ctrl
