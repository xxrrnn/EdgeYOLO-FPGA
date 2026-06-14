# One AXI clock converter per HBM AXI port.
#
# Intended direction:
#   250 MHz XDMA/SmartConnect side -> hbm_axi_cc_xx/S_AXI
#   hbm_axi_cc_xx/M_AXI     -> hbm_0/SAXI_xx at 450 MHz
#
# Width/protocol are left for Vivado to infer from connected interfaces. HBM
# SAXI ports are AXI3, 256-bit data, 33-bit address.

proc create_bd_ip_if_missing {name vlnv} {
  set cell [get_bd_cells -quiet $name]
  if {$cell eq ""} {
    set cell [create_bd_cell -type ip -vlnv $vlnv $name]
  }
  return $cell
}

for {set idx 0} {$idx < 32} {incr idx} {
  set name [format "hbm_axi_cc_%02d" $idx]
  create_bd_ip_if_missing $name xilinx.com:ip:axi_clock_converter:2.1
}
