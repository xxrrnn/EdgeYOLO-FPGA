# Clocking IPs for the XDMA + HBM block design.
#
# Outputs are intentionally not connected here. Connect the clk_wiz inputs to
# xdma_0/axi_aclk, then drive:
#   hbm_ref_clk_0_wiz/clk_out1 -> hbm_0/HBM_REF_CLK_0
#   hbm_ref_clk_1_wiz/clk_out1 -> hbm_0/HBM_REF_CLK_1
#   user_clk_wiz/clk_out1      -> 450 MHz HBM AXI clock
#   hbm_ref_clk_0_wiz/clk_out1 -> 100 MHz HBM APB clock

proc create_bd_ip_if_missing {name vlnv} {
  set cell [get_bd_cells -quiet $name]
  if {$cell eq ""} {
    set cell [create_bd_cell -type ip -vlnv $vlnv $name]
  }
  return $cell
}

set hbm_ref_clk_0_wiz [create_bd_ip_if_missing hbm_ref_clk_0_wiz xilinx.com:ip:clk_wiz:6.0]
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {250.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] $hbm_ref_clk_0_wiz

set hbm_ref_clk_1_wiz [create_bd_ip_if_missing hbm_ref_clk_1_wiz xilinx.com:ip:clk_wiz:6.0]
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {250.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] $hbm_ref_clk_1_wiz

set user_clk_wiz [create_bd_ip_if_missing user_clk_wiz xilinx.com:ip:clk_wiz:6.0]
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {250.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {450.000} \
  CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] $user_clk_wiz

set hbm_rst [create_bd_ip_if_missing hbm_rst xilinx.com:ip:proc_sys_reset:5.0]
set hbm_apb_rst [create_bd_ip_if_missing hbm_apb_rst xilinx.com:ip:proc_sys_reset:5.0]
