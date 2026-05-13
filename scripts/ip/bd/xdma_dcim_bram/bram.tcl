# VPU BRAM Controllers
# VPU Global Buffer (GB): visible to XDMA and CDMA through AXI
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_global_bram_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_global_bram_ctrl_0]

# VPU Weight Buffer (WB/ibuf): AXI controller drives VPU wb_* Port A
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_pe_ibuf_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_pe_ibuf_ctrl_0]

# VPU Output Buffer (obuf): AXI controller drives VPU ob_* Port A
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_pe_obuf_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_bd_cells vpu_pe_obuf_ctrl_0]

# VPU AXI Registers: AXI-Lite slave for VPU configuration/control
create_bd_cell -type module -reference VPU_AXI_Regs vpu_axi_regs_0
