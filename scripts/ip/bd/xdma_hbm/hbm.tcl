
set hbm_0 [get_bd_cells -quiet hbm_0]
if {$hbm_0 eq ""} {
  set hbm_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 hbm_0]
}

# User Parameters
set hbm_cfg [list \
  CONFIG.USER_AXI_CLK_FREQ {450} \
  CONFIG.USER_AXI_CLK1_FREQ {450} \
  CONFIG.USER_CLK_SEL_LIST1 {AXI_23_ACLK} \
  CONFIG.USER_HBM_DENSITY {8GB} \
  CONFIG.USER_HBM_STACK {2} \
  CONFIG.USER_SWITCH_ENABLE_00 {false} \
  CONFIG.USER_SWITCH_ENABLE_01 {false} \
]

for {set idx 0} {$idx < 32} {incr idx} {
  lappend hbm_cfg [format "CONFIG.USER_SAXI_%02d" $idx] {true}
}

for {set idx 0} {$idx < 16} {incr idx} {
  lappend hbm_cfg [format "CONFIG.USER_MC_ENABLE_%02d" $idx] {TRUE}
  lappend hbm_cfg [format "CONFIG.USER_PHY_ENABLE_%02d" $idx] {TRUE}
}

lappend hbm_cfg CONFIG.USER_MC_ENABLE_APB_00 {false}
lappend hbm_cfg CONFIG.USER_MC_ENABLE_APB_01 {false}
lappend hbm_cfg CONFIG.USER_APB_EN {false}

set_property -dict $hbm_cfg $hbm_0
