# add XDMA IP into block design
# 不能直接source xdma.tcl，比如在这里直接指定
set xdma_0 [get_bd_cells -quiet xdma_0]
if {$xdma_0 eq ""} {
  set xdma_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0]
}

# copy the same config from fpga/local/scripts/ip/xdma.tcl
# xdma_rnum_chnl/xdma_wnum_chnl 改为 1:
#   - Thunderbolt/PCIe-over-Type-C 场景下，4 通道的 MSI-X 向量数过多，
#     容易触发 Thunderbolt 枚举超时或 Windows 设备管理器 "Unknown device"
#   - 1 通道够用（host 通过 M_AXI Memory-Mapped 接口直接读写所有 slave）
#   - usr_irq_req 由 4-bit 缩为 1-bit，与 xdma_constant(CONST_WIDTH=1) 完全匹配，
#     消除原有 width mismatch warning
# pf0_msix_cap_table_size 同步从 01F(31) 改为 001(1)，减少 MSI-X 向量数
set_property -dict [list \
  CONFIG.PCIE_BOARD_INTERFACE {pci_express_x8} \
  CONFIG.axi_data_width {256_bit} \
  CONFIG.axil_master_64bit_en {false} \
  CONFIG.axilite_master_en {false} \
  CONFIG.axisten_freq {250} \
  CONFIG.cfg_mgmt_if {false} \
  CONFIG.en_ext_ch_gt_drp {false} \
  CONFIG.en_pcie_drp {false} \
  CONFIG.en_transceiver_status_ports {false} \
  CONFIG.enable_jtag_dbg {false} \
  CONFIG.mode_selection {Advanced} \
  CONFIG.pcie_extended_tag {true} \
  CONFIG.pf0_device_id {9024} \
  CONFIG.pf0_interrupt_pin {NONE} \
  CONFIG.pf0_msix_cap_pba_bir {BAR_1:0} \
  CONFIG.pf0_msix_cap_pba_offset {00008020} \
  CONFIG.pf0_msix_cap_table_bir {BAR_1:0} \
  CONFIG.pf0_msix_cap_table_offset {00008000} \
  CONFIG.pf0_msix_cap_table_size {001} \
  CONFIG.pf0_msix_enabled {true} \
  CONFIG.pipe_sim {false} \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.plltype {QPLL1} \
  CONFIG.xdma_axi_intf_mm {AXI_Memory_Mapped} \
  CONFIG.xdma_pcie_64bit_en {true} \
  CONFIG.xdma_rnum_chnl {1} \
  CONFIG.xdma_wnum_chnl {1} \
  CONFIG.pf0_bar0_64bit {true} \
  CONFIG.pf0_bar0_prefetchable {true} \
  CONFIG.pf0_bar0_scale {Megabytes} \
  CONFIG.pf0_bar0_size {128} \
  CONFIG.pciebar2axibar_0 {0x0000000100000000} \
] $xdma_0

make_bd_pins_external  [get_bd_pins xdma_0/user_lnk_up]
set xdma_constant [get_bd_cells -quiet xdma_constant]
if {$xdma_constant eq ""} {
  set xdma_constant [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xdma_constant]
}
set_property -dict [list \
  CONFIG.CONST_WIDTH {1} \
  CONFIG.CONST_VAL {0} \
] $xdma_constant

set xdma_inv [get_bd_cells -quiet xdma_inv]
if {$xdma_inv eq ""} {
  set xdma_inv [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 xdma_inv]
}
set_property -dict [list \
  CONFIG.C_OPERATION {not} \
  CONFIG.C_SIZE {1} \
] $xdma_inv
