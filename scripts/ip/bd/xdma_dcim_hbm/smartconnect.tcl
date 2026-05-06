# SmartConnect IPs for XDMA/CDMA access to HBM and PE-local peripherals.
#
# SmartConnect high-performance mode is limited to 16 MI. Use a small root
# switch, two 16-port HBM data switches, and one local peripheral switch:
#   xdma_0/M_AXI                  -> root/S00_AXI
#   axi_cdma_0/M_AXI              -> root/S01_AXI
#   root/M00_AXI -> hbm_smc_0     -> SAXI_00..15
#   root/M01_AXI -> hbm_smc_1     -> SAXI_16..31
#   root/M02_AXI -> local_smc     -> PE buffers, CDMA regs, GPIOs

proc create_bd_ip_if_missing {name vlnv} {
  set cell [get_bd_cells -quiet $name]
  if {$cell eq ""} {
    set cell [create_bd_cell -type ip -vlnv $vlnv $name]
  }
  return $cell
}

set xdma_dcim_hbm_smc_root [create_bd_ip_if_missing xdma_dcim_hbm_smc_root xilinx.com:ip:smartconnect:1.0]
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {3} \
] $xdma_dcim_hbm_smc_root

set xdma_dcim_hbm_smc_0 [create_bd_ip_if_missing xdma_dcim_hbm_smc_0 xilinx.com:ip:smartconnect:1.0]
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {16} \
] $xdma_dcim_hbm_smc_0

set xdma_dcim_hbm_smc_1 [create_bd_ip_if_missing xdma_dcim_hbm_smc_1 xilinx.com:ip:smartconnect:1.0]
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {16} \
] $xdma_dcim_hbm_smc_1

set xdma_dcim_hbm_local_smc [create_bd_ip_if_missing xdma_dcim_hbm_local_smc xilinx.com:ip:smartconnect:1.0]
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {9} \
] $xdma_dcim_hbm_local_smc
