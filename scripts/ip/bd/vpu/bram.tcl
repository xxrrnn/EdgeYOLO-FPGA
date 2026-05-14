# Staging BRAM：由 axi_bram_ctrl 驱动
# VPU GB/WB：Global_VPU_top 内部有 AXI 从设备接口 (gb_axis, wb_axis)，直接连接

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
  CONFIG.Write_Depth_A {4096} \
  CONFIG.Write_Width_A {256} \
  CONFIG.Read_Width_A {256} \
  CONFIG.Byte_Size {8} \
  CONFIG.Use_Byte_Write_Enable {true} \
] [get_bd_cells global_bram]

# VPU_AXI_Regs：配置/状态寄存器
create_bd_cell -type module -reference VPU_AXI_Regs vpu_regs
