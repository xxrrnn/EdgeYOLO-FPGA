create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells axi_bram_ctrl_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 xdma_bram
set_property -dict [list \
  CONFIG.use_bram_block {BRAM_Controller} \
  CONFIG.EN_SAFETY_CKT {false} \
  CONFIG.Memory_Type {True_Dual_Port_RAM} \
  CONFIG.Write_Depth_A {256} \
  CONFIG.Write_Width_A {256} \
  CONFIG.Read_Width_A {256} \
  CONFIG.Write_Width_B {256} \
  CONFIG.Read_Width_B {256} \
  CONFIG.Byte_Size {8} \
  CONFIG.Use_Byte_Write_Enable {true} \
  CONFIG.Assume_Synchronous_Clk {true} \
] [get_bd_cells xdma_bram]

set bram_inv [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 bram_inv]
set_property -dict [list \
  CONFIG.C_OPERATION {not} \
  CONFIG.C_SIZE {1} \
] $bram_inv
