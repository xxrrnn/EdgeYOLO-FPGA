# SmartConnect IPs for distributing XDMA transactions across all HBM AXI ports.
#
# SmartConnect high-performance mode is limited to 16 MI. Use a small root
# switch and two 16-port data switches:
#   xdma_0/M_AXI             -> xdma_hbm_smc_root/S00_AXI
#   xdma_hbm_smc_root/M00_AXI -> xdma_hbm_smc_0/S00_AXI -> SAXI_00..15
#   xdma_hbm_smc_root/M01_AXI -> xdma_hbm_smc_1/S00_AXI -> SAXI_16..31

proc create_bd_ip_if_missing {name vlnv} {
  set cell [get_bd_cells -quiet $name]
  if {$cell eq ""} {
    set cell [create_bd_cell -type ip -vlnv $vlnv $name]
  }
  return $cell
}

set xdma_hbm_smc_root [create_bd_ip_if_missing xdma_hbm_smc_root xilinx.com:ip:smartconnect:1.0]
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {2} \
] $xdma_hbm_smc_root

set xdma_hbm_smc_0 [create_bd_ip_if_missing xdma_hbm_smc_0 xilinx.com:ip:smartconnect:1.0]
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {16} \
] $xdma_hbm_smc_0

set xdma_hbm_smc_1 [create_bd_ip_if_missing xdma_hbm_smc_1 xilinx.com:ip:smartconnect:1.0]
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {16} \
] $xdma_hbm_smc_1
