proc connect_bd_net_if_present {driver pin} {
  set dst [get_bd_pins -quiet $pin]
  if {$dst ne ""} {
    connect_bd_net $driver $dst
  }
}

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

connect_bd_net [get_bd_pins xdma_constant/dout] [get_bd_pins xdma_0/usr_irq_req]

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_0_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins user_clk_wiz/clk_in1]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_0_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins user_clk_wiz/reset]

# hbm_ref_clk_1_wiz only instantiated when hbmStackCount > 1
if {[llength [get_bd_cells -quiet hbm_ref_clk_1_wiz]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_1_wiz/clk_in1]
  connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_1_wiz/reset]
  connect_bd_net_if_present [get_bd_pins hbm_ref_clk_1_wiz/clk_out1] hbm_0/HBM_REF_CLK_1
}

connect_bd_net_if_present [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] hbm_0/HBM_REF_CLK_0

# Even with USER_APB_EN=false Vivado keeps APB_x_PCLK / APB_x_PRESET_N pinned;
# drive them from hbm_ref_clk_0_wiz so validate_bd_design does not error.
connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/clk_out1] [get_bd_pins hbm_apb_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset]                  [get_bd_pins hbm_apb_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_ref_clk_0_wiz/locked]   [get_bd_pins hbm_apb_rst/dcm_locked]
foreach apb_idx {0 1} {
  connect_bd_net_if_present [get_bd_pins hbm_ref_clk_0_wiz/clk_out1]       hbm_0/APB_${apb_idx}_PCLK
  connect_bd_net_if_present [get_bd_pins hbm_apb_rst/peripheral_aresetn]   hbm_0/APB_${apb_idx}_PRESET_N
}

# XDMA host routing hierarchy.
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins final_root_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins final_root_smc/M00_AXI] [get_bd_intf_pins final_hbm_smc_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins final_root_smc/M01_AXI] [get_bd_intf_pins final_hbm_smc_1/S00_AXI]
for {set group_idx 0} {$group_idx < 4} {incr group_idx} {
  set mi_num [format "%02d" [expr {$group_idx + 2}]]
  connect_bd_intf_net \
    [get_bd_intf_pins final_root_smc/M${mi_num}_AXI] \
    [get_bd_intf_pins [format "final_ctrl_smc_%d/S00_AXI" $group_idx]]
}

foreach smc {final_root_smc final_hbm_smc_0 final_hbm_smc_1} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${smc}/aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${smc}/aresetn]
}

for {set group_idx 0} {$group_idx < 4} {incr group_idx} {
  set ctrl_smc [format "final_ctrl_smc_%d" $group_idx]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${ctrl_smc}/aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${ctrl_smc}/aresetn]
}

for {set bank_idx 0} {$bank_idx < $ctrlBankCount} {incr bank_idx} {
  set bank_name [format "cluster_ctrl_bank_%02d" $bank_idx]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${bank_name}/s_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${bank_name}/s_axi_aresetn]
}

for {set compact_idx 0} {$compact_idx < 4} {incr compact_idx} {
  set ctrl_smc [format "final_ctrl_smc_%d" $compact_idx]
  set cdma_base [expr {$compact_idx * 4}]
  set bank_base [expr {$compact_idx * 2}]
  connect_bd_intf_net [get_bd_intf_pins ${ctrl_smc}/M00_AXI] [get_bd_intf_pins [format "axi_cdma_%02d/S_AXI_LITE" $cdma_base]]
  connect_bd_intf_net [get_bd_intf_pins ${ctrl_smc}/M01_AXI] [get_bd_intf_pins [format "axi_cdma_%02d/S_AXI_LITE" [expr {$cdma_base + 1}]]]
  connect_bd_intf_net [get_bd_intf_pins ${ctrl_smc}/M02_AXI] [get_bd_intf_pins [format "axi_cdma_%02d/S_AXI_LITE" [expr {$cdma_base + 2}]]]
  connect_bd_intf_net [get_bd_intf_pins ${ctrl_smc}/M03_AXI] [get_bd_intf_pins [format "axi_cdma_%02d/S_AXI_LITE" [expr {$cdma_base + 3}]]]
  connect_bd_intf_net [get_bd_intf_pins ${ctrl_smc}/M04_AXI] [get_bd_intf_pins [format "cluster_ctrl_bank_%02d/S_AXI" $bank_base]]
  connect_bd_intf_net [get_bd_intf_pins ${ctrl_smc}/M05_AXI] [get_bd_intf_pins [format "cluster_ctrl_bank_%02d/S_AXI" [expr {$bank_base + 1}]]]
}

set shared_data_hbm_mi [format "%02d" [expr {$clustersPerSharedCdma * 2}]]
set shared_cdmas_per_hbm_half [expr {$sharedCdmaCount / 2}]
for {set group_idx 0} {$group_idx < $sharedCdmaCount} {incr group_idx} {
  set group_num [format "%02d" $group_idx]
  set cdma_name [format "axi_cdma_%02d" $group_idx]
  set data_smc [format "shared_cdma_data_smc_%02d" $group_idx]

  connect_bd_intf_net [get_bd_intf_pins ${cdma_name}/M_AXI] [get_bd_intf_pins ${data_smc}/S00_AXI]

  if {$group_idx < $shared_cdmas_per_hbm_half} {
    set hbm_smc final_hbm_smc_0
    set hbm_si [expr {$group_idx + 1}]
  } else {
    set hbm_smc final_hbm_smc_1
    set hbm_si [expr {$group_idx - $shared_cdmas_per_hbm_half + 1}]
  }
  set hbm_si_num [format "%02d" $hbm_si]
  connect_bd_intf_net \
    [get_bd_intf_pins ${data_smc}/M${shared_data_hbm_mi}_AXI] \
    [get_bd_intf_pins ${hbm_smc}/S${hbm_si_num}_AXI]

  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${data_smc}/aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${data_smc}/aresetn]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${cdma_name}/m_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${cdma_name}/s_axi_lite_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${cdma_name}/s_axi_lite_aresetn]
  if {[llength [get_bd_pins -quiet ${cdma_name}/m_axi_aresetn]] != 0} {
    connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${cdma_name}/m_axi_aresetn]
  }
}

for {set hbm_idx 0} {$hbm_idx < $hbmPortCount} {incr hbm_idx} {
  set axi_num [format "%02d" $hbm_idx]
  if {$hbm_idx < ($hbmPortCount / 2)} {
    set hbm_smc final_hbm_smc_0
    set hbm_group_mi $hbm_idx
  } else {
    set hbm_smc final_hbm_smc_1
    set hbm_group_mi [expr {$hbm_idx - ($hbmPortCount / 2)}]
  }
  set hbm_group_mi_num [format "%02d" $hbm_group_mi]
  connect_bd_intf_net [get_bd_intf_pins ${hbm_smc}/M${hbm_group_mi_num}_AXI] [get_bd_intf_pins hbm_0/SAXI_${axi_num}]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_0/AXI_${axi_num}_ACLK]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins hbm_0/AXI_${axi_num}_ARESET_N]
}

for {set idx 0} {$idx < $clusterCount} {incr idx} {
  set cluster_name [format "cluster_pe_%02d" $idx]
  set ibuf_ctrl [format "pe_ibuf_ctrl_%02d" $idx]
  set obuf_ctrl [format "pe_obuf_ctrl_%02d" $idx]
  set cdma_group [expr {$idx / $clustersPerSharedCdma}]
  set cdma_slot [expr {$idx % $clustersPerSharedCdma}]
  set ctrl_bank_idx [expr {$idx / $clustersPerCtrlBank}]
  set ctrl_bank_slot [expr {$idx % $clustersPerCtrlBank}]
  set data_smc [format "shared_cdma_data_smc_%02d" $cdma_group]
  set ctrl_bank [format "cluster_ctrl_bank_%02d" $ctrl_bank_idx]

  set ibuf_mi [format "%02d" [expr {$cdma_slot * 2}]]
  set obuf_mi [format "%02d" [expr {$cdma_slot * 2 + 1}]]
  connect_bd_intf_net [get_bd_intf_pins ${data_smc}/M${ibuf_mi}_AXI] [get_bd_intf_pins ${ibuf_ctrl}/S_AXI]
  connect_bd_intf_net [get_bd_intf_pins ${data_smc}/M${obuf_mi}_AXI] [get_bd_intf_pins ${obuf_ctrl}/S_AXI]

  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${ibuf_ctrl}/s_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${ibuf_ctrl}/s_axi_aresetn]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${obuf_ctrl}/s_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${obuf_ctrl}/s_axi_aresetn]

  connect_bd_net [get_bd_pins ${ibuf_ctrl}/bram_en_a]     [get_bd_pins ${cluster_name}/ibuf_ena]
  connect_bd_net [get_bd_pins ${ibuf_ctrl}/bram_we_a]     [get_bd_pins ${cluster_name}/ibuf_wea]
  connect_bd_net [get_bd_pins ${ibuf_ctrl}/bram_addr_a]   [get_bd_pins ${cluster_name}/ibuf_addra]
  connect_bd_net [get_bd_pins ${ibuf_ctrl}/bram_wrdata_a] [get_bd_pins ${cluster_name}/ibuf_dina]
  connect_bd_net [get_bd_pins ${ibuf_ctrl}/bram_rddata_a] [get_bd_pins ${cluster_name}/ibuf_douta]

  connect_bd_net [get_bd_pins ${obuf_ctrl}/bram_en_a]     [get_bd_pins ${cluster_name}/obuf_ena]
  connect_bd_net [get_bd_pins ${obuf_ctrl}/bram_we_a]     [get_bd_pins ${cluster_name}/obuf_wea]
  connect_bd_net [get_bd_pins ${obuf_ctrl}/bram_addr_a]   [get_bd_pins ${cluster_name}/obuf_addra]
  connect_bd_net [get_bd_pins ${obuf_ctrl}/bram_wrdata_a] [get_bd_pins ${cluster_name}/obuf_dina]
  connect_bd_net [get_bd_pins ${obuf_ctrl}/bram_rddata_a] [get_bd_pins ${cluster_name}/obuf_douta]

  connect_bd_net [get_bd_pins ${ctrl_bank}/cfg_word_${ctrl_bank_slot}] [get_bd_pins ${cluster_name}/cfg_word]
  connect_bd_net [get_bd_pins ${cluster_name}/status_word] [get_bd_pins ${ctrl_bank}/status_word_${ctrl_bank_slot}]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${cluster_name}/clk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${cluster_name}/rst_n]
}
