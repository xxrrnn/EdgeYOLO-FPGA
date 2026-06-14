# PE IBUF/OBUF stay as PE-local inferred BRAMs.  The global staging memory
# used by the old xdma_dcim_bram design is replaced by HBM in this design.
#
# These AXI BRAM controllers drive only PE buffer port A; PE/DCIM uses port B.
# Keep the controllers and PE on xdma_0/axi_aclk so the single-clock inferred
# RAMs in PE.sv do not cross clock domains.
foreach ctrl_name {pe_ibuf_ctrl pe_obuf_ctrl} {
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 $ctrl_name
  set_property -dict [list \
    CONFIG.DATA_WIDTH {256} \
    CONFIG.SINGLE_PORT_BRAM {1} \
  ] [get_bd_cells $ctrl_name]
}
