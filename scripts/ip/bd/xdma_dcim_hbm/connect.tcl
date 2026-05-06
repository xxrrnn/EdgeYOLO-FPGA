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
# HBM follows the earlier xdma_hbm bring-up: 450 MHz AXI clock, 100 MHz APB/ref
# clocks.  The PE/DCIM side stays on xdma_0/axi_aclk (250 MHz) because the PE
# buffers are single-clock inferred RAMs shared with AXI BRAM controllers.
# ------------------------------------------------------------------------------
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_0_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_1_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins user_clk_wiz/clk_in1]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_0_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_1_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins user_clk_wiz/reset]

connect_bd_net [get_bd_pins user_clk_wiz/clk_out1] [get_bd_pins hbm_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_rst/ext_reset_in]
connect_bd_net [get_bd_pins user_clk_wiz/locked] [get_bd_pins hbm_rst/dcm_locked]

connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] [get_bd_pins hbm_apb_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_apb_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/locked] [get_bd_pins hbm_apb_rst/dcm_locked]

# ------------------------------------------------------------------------------
# HBM refclock and APB pins.
# ------------------------------------------------------------------------------
connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] [get_bd_pins hbm_0/HBM_REF_CLK_0]
connect_bd_net [get_bd_pins hbm_ref_clk_1_wiz/clk_out1] [get_bd_pins hbm_0/HBM_REF_CLK_1]

foreach apb_idx {0 1} {
  connect_bd_net_if_present [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] hbm_0/APB_${apb_idx}_PCLK
  connect_bd_net_if_present [get_bd_pins hbm_apb_rst/peripheral_aresetn] hbm_0/APB_${apb_idx}_PRESET_N
}

# ------------------------------------------------------------------------------
# SmartConnect hierarchy.
# ------------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins xdma_dcim_hbm_smc_root/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins xdma_dcim_hbm_smc_root/S01_AXI]

connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_smc_root/M00_AXI] [get_bd_intf_pins xdma_dcim_hbm_smc_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_smc_root/M01_AXI] [get_bd_intf_pins xdma_dcim_hbm_smc_1/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_smc_root/M02_AXI] [get_bd_intf_pins xdma_dcim_hbm_local_smc/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M00_AXI] [get_bd_intf_pins pe_ibuf_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M01_AXI] [get_bd_intf_pins pe_obuf_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M02_AXI] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M03_AXI] [get_bd_intf_pins pe_cfg0_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M04_AXI] [get_bd_intf_pins pe_cfg1_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M05_AXI] [get_bd_intf_pins pe_cfg2_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M06_AXI] [get_bd_intf_pins pe_cfg3_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M07_AXI] [get_bd_intf_pins pe_ctrl_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_hbm_local_smc/M08_AXI] [get_bd_intf_pins pe_status_gpio/S_AXI]

foreach smc {xdma_dcim_hbm_smc_root xdma_dcim_hbm_smc_0 xdma_dcim_hbm_smc_1 xdma_dcim_hbm_local_smc} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${smc}/aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${smc}/aresetn]
}

# ------------------------------------------------------------------------------
# HBM AXI ports and AXI clock converters.
# ------------------------------------------------------------------------------
for {set idx 0} {$idx < 32} {incr idx} {
  set axi_num [format "%02d" $idx]
  set smc_name xdma_dcim_hbm_smc_0
  set smc_mi $idx
  if {$idx >= 16} {
    set smc_name xdma_dcim_hbm_smc_1
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

# ------------------------------------------------------------------------------
# PE buffer ports and GPIO control/status wiring.
# ------------------------------------------------------------------------------
connect_bd_net [get_bd_pins pe_ibuf_ctrl/bram_en_a]     [get_bd_pins pe_0/ibuf_ena]
connect_bd_net [get_bd_pins pe_ibuf_ctrl/bram_we_a]     [get_bd_pins pe_0/ibuf_wea]
connect_bd_net [get_bd_pins pe_ibuf_ctrl/bram_addr_a]   [get_bd_pins pe_0/ibuf_addra]
connect_bd_net [get_bd_pins pe_ibuf_ctrl/bram_wrdata_a] [get_bd_pins pe_0/ibuf_dina]
connect_bd_net [get_bd_pins pe_ibuf_ctrl/bram_rddata_a] [get_bd_pins pe_0/ibuf_douta]

connect_bd_net [get_bd_pins pe_obuf_ctrl/bram_en_a]     [get_bd_pins pe_0/obuf_ena]
connect_bd_net [get_bd_pins pe_obuf_ctrl/bram_we_a]     [get_bd_pins pe_0/obuf_wea]
connect_bd_net [get_bd_pins pe_obuf_ctrl/bram_addr_a]   [get_bd_pins pe_0/obuf_addra]
connect_bd_net [get_bd_pins pe_obuf_ctrl/bram_wrdata_a] [get_bd_pins pe_0/obuf_dina]
connect_bd_net [get_bd_pins pe_obuf_ctrl/bram_rddata_a] [get_bd_pins pe_0/obuf_douta]

connect_bd_net [get_bd_pins pe_cfg0_gpio/gpio_io_o] [get_bd_pins pe_0/dcim_wsrc_base_addr]
connect_bd_net [get_bd_pins pe_cfg1_gpio/gpio_io_o] [get_bd_pins pe_0/dcim_asrc_base_addr]
connect_bd_net [get_bd_pins pe_cfg2_gpio/gpio_io_o] [get_bd_pins pe_0/dcim_dst_addr]
connect_bd_net [get_bd_pins pe_cfg3_gpio/gpio_io_o] [get_bd_pins pe_0/dcim_raw_rows]

connect_bd_net [get_bd_pins pe_ctrl_gpio/gpio_io_o] [get_bd_pins pe_start_slice/Din]
connect_bd_net [get_bd_pins pe_ctrl_gpio/gpio_io_o] [get_bd_pins pe_config_valid_slice/Din]
connect_bd_net [get_bd_pins pe_ctrl_gpio/gpio_io_o] [get_bd_pins pe_mode_slice/Din]
connect_bd_net [get_bd_pins pe_ctrl_gpio/gpio_io_o] [get_bd_pins pe_acc_slice/Din]
connect_bd_net [get_bd_pins pe_start_slice/Dout] [get_bd_pins pe_0/dcim_start]
connect_bd_net [get_bd_pins pe_config_valid_slice/Dout] [get_bd_pins pe_0/dcim_config_valid]
connect_bd_net [get_bd_pins pe_mode_slice/Dout] [get_bd_pins pe_0/dcim_mode]
connect_bd_net [get_bd_pins pe_acc_slice/Dout] [get_bd_pins pe_0/dcim_acc]

connect_bd_net [get_bd_pins pe_0/dcim_busy] [get_bd_pins pe_status_concat/In0]
connect_bd_net [get_bd_pins pe_0/dcim_done] [get_bd_pins pe_status_concat/In1]
connect_bd_net [get_bd_pins pe_0/dcim_error] [get_bd_pins pe_status_concat/In2]
connect_bd_net [get_bd_pins pe_0/dcim_config_ready] [get_bd_pins pe_status_concat/In3]
connect_bd_net [get_bd_pins pe_status_concat/dout] [get_bd_pins pe_status_gpio/gpio_io_i]
connect_bd_net [get_bd_pins pe_0/dcim_error_code] [get_bd_pins pe_status_gpio/gpio2_io_i]

# ------------------------------------------------------------------------------
# 250 MHz local clock/reset domain.
# ------------------------------------------------------------------------------
foreach axi_slave {pe_ibuf_ctrl pe_obuf_ctrl} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${axi_slave}/s_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${axi_slave}/s_axi_aresetn]
}

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
if {[llength [get_bd_pins -quiet axi_cdma_0/m_axi_aresetn]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/m_axi_aresetn]
}

foreach gpio_cell {pe_cfg0_gpio pe_cfg1_gpio pe_cfg2_gpio pe_cfg3_gpio pe_ctrl_gpio pe_status_gpio} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${gpio_cell}/s_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${gpio_cell}/s_axi_aresetn]
}

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins pe_0/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins pe_0/rst_n]
