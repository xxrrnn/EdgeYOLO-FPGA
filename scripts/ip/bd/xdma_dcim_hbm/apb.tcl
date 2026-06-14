# HBM exposes required SAPB management ports. These bridges keep the data path
# as XDMA -> HBM AXI while satisfying the HBM APB management interfaces.

proc create_bd_ip_if_missing {name vlnv} {
  set cell [get_bd_cells -quiet $name]
  if {$cell eq ""} {
    set cell [create_bd_cell -type ip -vlnv $vlnv $name]
  }
  return $cell
}

for {set idx 0} {$idx < 2} {incr idx} {
  set br [create_bd_ip_if_missing hbm_apb_bridge_${idx} xilinx.com:ip:axi_apb_bridge:3.0]
  set_property -dict [list \
    CONFIG.C_APB_NUM_SLAVES {1} \
    CONFIG.C_M_APB_PROTOCOL {apb3} \
  ] $br
}
