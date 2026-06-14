# Global BRAM: visible to XDMA and CDMA through AXI.
# 128KB = 8192 x 128-bit
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 global_bram_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells global_bram_ctrl]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 global_bram
set_property -dict [list \
  CONFIG.use_bram_block {BRAM_Controller} \
  CONFIG.EN_SAFETY_CKT {false} \
  CONFIG.Memory_Type {Single_Port_RAM} \
  CONFIG.Write_Depth_A {8192} \
  CONFIG.Write_Width_A {128} \
  CONFIG.Read_Width_A {128} \
  CONFIG.Byte_Size {8} \
  CONFIG.Use_Byte_Write_Enable {true} \
] [get_bd_cells global_bram]

# ============================================================================
# DCIM_Array 8 组 IBUF/OBUF 控制器
# 架构：8 组 × 8 Tile/组 = 64 Tile
# 每组独立的 IBUF/OBUF，256KB 每组 (16K x 128-bit, 14-bit word address)
# AXI BRAM Controller 使用字节地址，需要 18-bit 地址 (14 + 4 for 128-bit = 16 bytes)
# ============================================================================

# 创建 8 组 IBUF 控制器
for {set i 0} {$i < 8} {incr i} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 dcim_ibuf_ctrl_$i
    set_property -dict [list \
      CONFIG.DATA_WIDTH {128} \
      CONFIG.SINGLE_PORT_BRAM {1} \
      CONFIG.ECC_TYPE {0} \
    ] [get_bd_cells dcim_ibuf_ctrl_$i]
}

# 创建 8 组 OBUF 控制器
for {set i 0} {$i < 8} {incr i} {
    create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 dcim_obuf_ctrl_$i
    set_property -dict [list \
      CONFIG.DATA_WIDTH {128} \
      CONFIG.SINGLE_PORT_BRAM {1} \
      CONFIG.ECC_TYPE {0} \
    ] [get_bd_cells dcim_obuf_ctrl_$i]
}
