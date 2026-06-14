# pcie_refclk <-> util_ds_buf
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf
set_property -dict [list \
  CONFIG.C_BUF_TYPE {IBUFDSGTE} \
  CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
  CONFIG.USE_BOARD_FLOW {true} \
] [get_bd_cells util_ds_buf]

# pci_express_x8 <-> xdma
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x8
connect_bd_intf_net [get_bd_intf_ports pci_express_x8] [get_bd_intf_pins xdma_0/pcie_mgt]

# cpu_reset <-> xdma_inv <-> xdma
create_bd_port -dir I -type rst cpu_reset
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports cpu_reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins xdma_inv/Op1]
connect_bd_net [get_bd_pins xdma_inv/Res] [get_bd_pins xdma_0/sys_rst_n]

# pcie_refclk <-> util_ds_buf <-> xdma
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk
set_property CONFIG.FREQ_HZ 100000000 [get_bd_intf_ports pcie_refclk]
connect_bd_intf_net [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]

# xdma_constant <-> xdma
connect_bd_net [get_bd_pins xdma_constant/dout] [get_bd_pins xdma_0/usr_irq_req]

# ============================================================================
# Create AXI-Lite slave interface for dcim_array_0
# ============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 dcim_axi_lite_ic
set_property -dict [list \
  CONFIG.NUM_MI {1} \
  CONFIG.NUM_SI {1} \
] [get_bd_cells dcim_axi_lite_ic]

# ============================================================================
# Two-level AXI Interconnect structure:
# Level 1: Main Interconnect
#   S00 = XDMA M_AXI
#   S01 = CDMA M_AXI
#   M00 = global_bram
#   M01 = CDMA AXI-Lite registers
#   M02 = DCIM AXI-Lite config
#   M03 = Buffer Interconnect
# Level 2: Buffer Interconnect (for 16 BRAM controllers)
#   S00 = Main Interconnect M03
#   M00-M07 = DCIM ibuf group 0-7
#   M08-M15 = DCIM obuf group 0-7
# ============================================================================

# Main Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_main_ic
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {4} \
] [get_bd_cells axi_main_ic]

# Buffer Interconnect
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_buf_ic
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {16} \
] [get_bd_cells axi_buf_ic]

# Connect XDMA and CDMA to main interconnect
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_main_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_main_ic/S01_AXI]

# Main interconnect masters
connect_bd_intf_net [get_bd_intf_pins axi_main_ic/M00_AXI] [get_bd_intf_pins global_bram_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_main_ic/M01_AXI] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_main_ic/M02_AXI] [get_bd_intf_pins dcim_axi_lite_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_main_ic/M03_AXI] [get_bd_intf_pins axi_buf_ic/S00_AXI]

# Buffer interconnect to IBUF/OBUF controllers
for {set i 0} {$i < 8} {incr i} {
    set mi_name [format "M%02d_AXI" $i]
    connect_bd_intf_net [get_bd_intf_pins axi_buf_ic/$mi_name] [get_bd_intf_pins dcim_ibuf_ctrl_$i/S_AXI]
}

for {set i 0} {$i < 8} {incr i} {
    set mi_idx [expr {$i + 8}]
    set mi_name [format "M%02d_AXI" $mi_idx]
    connect_bd_intf_net [get_bd_intf_pins axi_buf_ic/$mi_name] [get_bd_intf_pins dcim_obuf_ctrl_$i/S_AXI]
}

# ============================================================================
# Connect dcim_axi_lite_ic M00_AXI to dcim_array_0's AXI-Lite signals
# ============================================================================

# Write address channel
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_awaddr]  [get_bd_pins dcim_array_0/s_axi_awaddr]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_awprot]  [get_bd_pins dcim_array_0/s_axi_awprot]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_awvalid] [get_bd_pins dcim_array_0/s_axi_awvalid]
connect_bd_net [get_bd_pins dcim_array_0/s_axi_awready]       [get_bd_pins dcim_axi_lite_ic/M00_AXI_awready]

# Write data channel
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_wdata]   [get_bd_pins dcim_array_0/s_axi_wdata]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_wstrb]   [get_bd_pins dcim_array_0/s_axi_wstrb]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_wvalid]  [get_bd_pins dcim_array_0/s_axi_wvalid]
connect_bd_net [get_bd_pins dcim_array_0/s_axi_wready]        [get_bd_pins dcim_axi_lite_ic/M00_AXI_wready]

# Write response channel
connect_bd_net [get_bd_pins dcim_array_0/s_axi_bresp]         [get_bd_pins dcim_axi_lite_ic/M00_AXI_bresp]
connect_bd_net [get_bd_pins dcim_array_0/s_axi_bvalid]        [get_bd_pins dcim_axi_lite_ic/M00_AXI_bvalid]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_bready]  [get_bd_pins dcim_array_0/s_axi_bready]

# Read address channel
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_araddr]  [get_bd_pins dcim_array_0/s_axi_araddr]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_arprot]  [get_bd_pins dcim_array_0/s_axi_arprot]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_arvalid] [get_bd_pins dcim_array_0/s_axi_arvalid]
connect_bd_net [get_bd_pins dcim_array_0/s_axi_arready]       [get_bd_pins dcim_axi_lite_ic/M00_AXI_arready]

# Read data channel
connect_bd_net [get_bd_pins dcim_array_0/s_axi_rdata]         [get_bd_pins dcim_axi_lite_ic/M00_AXI_rdata]
connect_bd_net [get_bd_pins dcim_array_0/s_axi_rresp]         [get_bd_pins dcim_axi_lite_ic/M00_AXI_rresp]
connect_bd_net [get_bd_pins dcim_array_0/s_axi_rvalid]        [get_bd_pins dcim_axi_lite_ic/M00_AXI_rvalid]
connect_bd_net [get_bd_pins dcim_axi_lite_ic/M00_AXI_rready]  [get_bd_pins dcim_array_0/s_axi_rready]

# ============================================================================
# AXI BRAM controllers <-> global BRAM and DCIM buffer ports
# ============================================================================
connect_bd_intf_net [get_bd_intf_pins global_bram/BRAM_PORTA] [get_bd_intf_pins global_bram_ctrl/BRAM_PORTA]

# ============================================================================
# Connect 8 groups of IBUF controllers to dcim_array_0
# ============================================================================
for {set i 0} {$i < 8} {incr i} {
    connect_bd_net [get_bd_pins dcim_ibuf_ctrl_$i/bram_en_a]     [get_bd_pins dcim_array_0/ibuf_ext_ena_$i]
    connect_bd_net [get_bd_pins dcim_ibuf_ctrl_$i/bram_we_a]     [get_bd_pins dcim_array_0/ibuf_ext_wea_$i]
    connect_bd_net [get_bd_pins dcim_ibuf_ctrl_$i/bram_addr_a]   [get_bd_pins dcim_array_0/ibuf_ext_addra_$i]
    connect_bd_net [get_bd_pins dcim_ibuf_ctrl_$i/bram_wrdata_a] [get_bd_pins dcim_array_0/ibuf_ext_dina_$i]
    connect_bd_net [get_bd_pins dcim_array_0/ibuf_ext_douta_$i]  [get_bd_pins dcim_ibuf_ctrl_$i/bram_rddata_a]
}

# ============================================================================
# Connect 8 groups of OBUF controllers to dcim_array_0
# ============================================================================
for {set i 0} {$i < 8} {incr i} {
    connect_bd_net [get_bd_pins dcim_obuf_ctrl_$i/bram_en_a]     [get_bd_pins dcim_array_0/obuf_ext_ena_$i]
    connect_bd_net [get_bd_pins dcim_obuf_ctrl_$i/bram_we_a]     [get_bd_pins dcim_array_0/obuf_ext_wea_$i]
    connect_bd_net [get_bd_pins dcim_obuf_ctrl_$i/bram_addr_a]   [get_bd_pins dcim_array_0/obuf_ext_addra_$i]
    connect_bd_net [get_bd_pins dcim_obuf_ctrl_$i/bram_wrdata_a] [get_bd_pins dcim_array_0/obuf_ext_dina_$i]
    connect_bd_net [get_bd_pins dcim_array_0/obuf_ext_douta_$i]  [get_bd_pins dcim_obuf_ctrl_$i/bram_rddata_a]
}

# ============================================================================
# Common clock/reset from XDMA
# ============================================================================

# Main Interconnect
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_main_ic/ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_main_ic/S00_ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_main_ic/S01_ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_main_ic/ARESETN]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_main_ic/S00_ARESETN]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_main_ic/S01_ARESETN]

for {set i 0} {$i < 4} {incr i} {
    set mi_aclk [format "M%02d_ACLK" $i]
    set mi_rst [format "M%02d_ARESETN" $i]
    connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_main_ic/$mi_aclk]
    connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_main_ic/$mi_rst]
}

# Buffer Interconnect
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_buf_ic/ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_buf_ic/S00_ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_buf_ic/ARESETN]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_buf_ic/S00_ARESETN]

for {set i 0} {$i < 16} {incr i} {
    set mi_aclk [format "M%02d_ACLK" $i]
    set mi_rst [format "M%02d_ARESETN" $i]
    connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_buf_ic/$mi_aclk]
    connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_buf_ic/$mi_rst]
}

# Global BRAM controller clock/reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins global_bram_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins global_bram_ctrl/s_axi_aresetn]

# 8 groups IBUF/OBUF controllers clock/reset
for {set i 0} {$i < 8} {incr i} {
    connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_ibuf_ctrl_$i/s_axi_aclk]
    connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins dcim_ibuf_ctrl_$i/s_axi_aresetn]
    connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_obuf_ctrl_$i/s_axi_aclk]
    connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins dcim_obuf_ctrl_$i/s_axi_aresetn]
}

# CDMA clock/reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
if {[llength [get_bd_pins -quiet axi_cdma_0/m_axi_aresetn]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/m_axi_aresetn]
}

# DCIM AXI-Lite interconnect clock/reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_axi_lite_ic/ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_axi_lite_ic/S00_ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_axi_lite_ic/M00_ACLK]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins dcim_axi_lite_ic/ARESETN]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins dcim_axi_lite_ic/S00_ARESETN]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins dcim_axi_lite_ic/M00_ARESETN]

# DCIM_Array clock/reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_array_0/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins dcim_array_0/rst_n]
