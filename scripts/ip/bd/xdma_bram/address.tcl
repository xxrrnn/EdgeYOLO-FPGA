# XDMA M_AXI address map.
#
# Source order requirement:
#   1. xdma.tcl creates xdma_0.
#   2. bram.tcl creates axi_bram_ctrl_0 and xdma_bram.
#   3. connect.tcl connects xdma_0/M_AXI through SmartConnect to the slaves.
#   4. This file assigns and then fixes the address map.

assign_bd_address

set bramSeg [get_bd_addr_segs -quiet {xdma_0/M_AXI/SEG_axi_bram_ctrl_0_Mem0}]
if {[llength $bramSeg] == 0} {
  set bramSeg [get_bd_addr_segs -quiet xdma_0/M_AXI/*axi_bram_ctrl_0*]
}
if {[llength $bramSeg] == 0} {
  error "Cannot find XDMA BRAM address segment"
}
set_property offset 0x10000000 $bramSeg
set_property range 8K $bramSeg

set ctrlSeg [get_bd_addr_segs -quiet {xdma_0/M_AXI/SEG_xdma_bram_axil_ctrl_0_reg0}]
if {[llength $ctrlSeg] == 0} {
  set ctrlSeg [get_bd_addr_segs -quiet xdma_0/M_AXI/*xdma_bram_axil_ctrl_0*]
}
if {[llength $ctrlSeg] == 0} {
  error "Cannot find XDMA AXI-Lite controller address segment"
}
set_property offset 0x10002000 $ctrlSeg
set_property range 4K $ctrlSeg
