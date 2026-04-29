create_bd_cell -type ip -vlnv xilinx.com:ip:axi_cdma:4.1 axi_cdma_0
set_property -dict [list \
  CONFIG.C_ADDR_WIDTH {32} \
  CONFIG.C_INCLUDE_SG {0} \
  CONFIG.C_M_AXI_DATA_WIDTH {256} \
  CONFIG.C_INCLUDE_DRE {1} \
] [get_bd_cells axi_cdma_0]
