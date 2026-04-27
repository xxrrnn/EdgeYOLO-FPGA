# add XDMA IP into block design
# 不能直接source xdma.tcl，比如在这里直接指定
set xdma_0 [get_bd_cells -quiet xdma_0]
if {$xdma_0 eq ""} {
  set xdma_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0]
}

# copy the same config from fpga/local/scripts/ip/xdma.tcl
set_property -dict [list \
  CONFIG.PCIE_BOARD_INTERFACE {pci_express_x8} \
  CONFIG.axi_data_width {256_bit} \
  CONFIG.axilite_master_en {false} \
  CONFIG.axisten_freq {250} \
  CONFIG.cfg_mgmt_if {false} \
  CONFIG.mode_selection {Advanced} \
  CONFIG.pf0_device_id {9024} \
  CONFIG.pf0_interrupt_pin {NONE} \
  CONFIG.pf0_msix_enabled {true} \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.xdma_axi_intf_mm {AXI_Memory_Mapped} \
  CONFIG.xdma_pcie_64bit_en {true} \
  CONFIG.xdma_rnum_chnl {4} \
  CONFIG.xdma_wnum_chnl {4} \
] $xdma_0

make_bd_pins_external  [get_bd_pins xdma_0/user_lnk_up]


set xdma_constant [get_bd_cells -quiet xdma_constant]
if {$xdma_constant eq ""} {
  set xdma_constant [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xdma_constant]
}
set_property CONFIG.CONST_VAL {0} $xdma_constant

set xdma_inv [get_bd_cells -quiet xdma_inv]
if {$xdma_inv eq ""} {
  set xdma_inv [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 xdma_inv]
}
set_property -dict [list \
  CONFIG.C_OPERATION {not} \
  CONFIG.C_SIZE {1} \
] $xdma_inv
