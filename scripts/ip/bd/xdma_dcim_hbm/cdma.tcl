# CDMA moves data between HBM and the PE-local buffers:
#   HBM -> pe_ibuf_ctrl before a DCIM run
#   pe_obuf_ctrl -> HBM after a DCIM run
#
# Use a 64-bit address width because the full 8 GB HBM map occupies
# 0x000000000-0x1FFFFFFFF and local PE/CDMA/GPIO registers are placed above it.
# Tests can still use HBM bank 0 with upper address bits left at zero.
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_cdma:4.1 axi_cdma_0
set_property -dict [list \
  CONFIG.C_ADDR_WIDTH {64} \
  CONFIG.C_INCLUDE_SG {0} \
  CONFIG.C_M_AXI_DATA_WIDTH {256} \
  CONFIG.C_INCLUDE_DRE {1} \
] [get_bd_cells axi_cdma_0]
