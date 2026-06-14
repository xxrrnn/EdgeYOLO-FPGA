proc connect_bd_net_if_present {driver pin} {
  set dst [get_bd_pins -quiet $pin]
  if {$dst ne ""} {
    connect_bd_net $driver $dst
  }
}

# ------------------------------------------------------------------------------
# XDMA PCIe pins, refclock, and reset.
# ------------------------------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf
set_property -dict [list \
  CONFIG.C_BUF_TYPE {IBUFDSGTE} \
  CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
  CONFIG.USE_BOARD_FLOW {true} \
] [get_bd_cells util_ds_buf]

create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x8
connect_bd_intf_net [get_bd_intf_ports pci_express_x8] [get_bd_intf_pins xdma_0/pcie_mgt]

create_bd_port -dir I -type rst cpu_reset
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports cpu_reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins xdma_inv/Op1]
connect_bd_net [get_bd_pins xdma_inv/Res] [get_bd_pins xdma_0/sys_rst_n]

create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk
set_property CONFIG.FREQ_HZ 100000000 [get_bd_intf_ports pcie_refclk]
connect_bd_intf_net [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]

# XDMA user IRQs are unused in this design.
connect_bd_net [get_bd_pins xdma_constant/dout] [get_bd_pins xdma_0/usr_irq_req]

# ------------------------------------------------------------------------------
# Clock generators and reset generators.
#
# xdma_0/axi_aclk is the XDMA-buffered 250 MHz fabric clock. Use it as the
# clock-wizard source instead of adding a second BUFG_GT on IBUF_DS_ODIV2.
# ------------------------------------------------------------------------------
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_0_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_1_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins user_clk_wiz/clk_in1]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_0_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_1_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins user_clk_wiz/reset]

# 450 MHz HBM AXI reset domain.
connect_bd_net [get_bd_pins user_clk_wiz/clk_out1] [get_bd_pins hbm_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_rst/ext_reset_in]
connect_bd_net [get_bd_pins user_clk_wiz/locked] [get_bd_pins hbm_rst/dcm_locked]

# 100 MHz HBM APB reset domain.
connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] [get_bd_pins hbm_apb_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_apb_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/locked] [get_bd_pins hbm_apb_rst/dcm_locked]

# ------------------------------------------------------------------------------
# HBM refclock and APB pins.
# ------------------------------------------------------------------------------
connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] [get_bd_pins hbm_0/HBM_REF_CLK_0]
connect_bd_net [get_bd_pins hbm_ref_clk_1_wiz/clk_out1] [get_bd_pins hbm_0/HBM_REF_CLK_1]

# HBM exposes APB clock/reset pins even when the APB register interface is
# disabled. The APB clock must be slow enough for the HBM APB pulse-width
# requirement; do not drive it with the 250 MHz XDMA axi_aclk.
foreach apb_idx {0 1} {
  connect_bd_net_if_present [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] hbm_0/APB_${apb_idx}_PCLK
  connect_bd_net_if_present [get_bd_pins hbm_apb_rst/peripheral_aresetn] hbm_0/APB_${apb_idx}_PRESET_N
}

# ------------------------------------------------------------------------------
# SmartConnect hierarchy.
# ------------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins xdma_hbm_smc_root/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_hbm_smc_root/M00_AXI] [get_bd_intf_pins xdma_hbm_smc_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_hbm_smc_root/M01_AXI] [get_bd_intf_pins xdma_hbm_smc_1/S00_AXI]

foreach smc {xdma_hbm_smc_root xdma_hbm_smc_0 xdma_hbm_smc_1} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${smc}/aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${smc}/aresetn]
}

# ------------------------------------------------------------------------------
# HBM AXI ports and AXI clock converters.
#
# Each converter bridges the 250 MHz XDMA side to the 450 MHz HBM AXI side.
# ------------------------------------------------------------------------------
for {set idx 0} {$idx < 32} {incr idx} {
  set axi_num [format "%02d" $idx]
  set smc_name xdma_hbm_smc_0
  set smc_mi $idx
  if {$idx >= 16} {
    set smc_name xdma_hbm_smc_1
    set smc_mi [expr {$idx - 16}]
  }
  set smc_mi_num [format "%02d" $smc_mi]

  connect_bd_intf_net \
    [get_bd_intf_pins ${smc_name}/M${smc_mi_num}_AXI] \
    [get_bd_intf_pins hbm_axi_cc_${axi_num}/S_AXI]

  connect_bd_intf_net \
    [get_bd_intf_pins hbm_axi_cc_${axi_num}/M_AXI] \
    [get_bd_intf_pins hbm_0/SAXI_${axi_num}]

  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_axi_cc_${axi_num}/s_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins hbm_axi_cc_${axi_num}/s_axi_aresetn]

  connect_bd_net [get_bd_pins user_clk_wiz/clk_out1] [get_bd_pins hbm_axi_cc_${axi_num}/m_axi_aclk]
  connect_bd_net [get_bd_pins hbm_rst/peripheral_aresetn] [get_bd_pins hbm_axi_cc_${axi_num}/m_axi_aresetn]

  connect_bd_net [get_bd_pins user_clk_wiz/clk_out1] [get_bd_pins hbm_0/AXI_${axi_num}_ACLK]
  connect_bd_net [get_bd_pins hbm_rst/peripheral_aresetn] [get_bd_pins hbm_0/AXI_${axi_num}_ARESET_N]
}
