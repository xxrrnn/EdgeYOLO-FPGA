create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells axi_bram_ctrl_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 axi_bram_ctrl_0_bram
set_property CONFIG.EN_SAFETY_CKT {false} [get_bd_cells axi_bram_ctrl_0_bram]