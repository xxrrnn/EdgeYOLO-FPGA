# XDMA/CDMA address map.
#
# 0x1000_0000 - 0x1000_ffff  global_bram, 64KB
# 0x1001_0000 - 0x1001_ffff  local_bram,  64KB
# 0x1002_0000 - 0x1002_0fff  controller registers, 4KB
#
# The controller adds GLOBAL_BASE_ADDR/LOCAL_BASE_ADDR to the programmed
# offsets before configuring CDMA transfers.

assign_bd_address

proc set_addr_seg {pattern offset range_bytes label} {
  set segs [get_bd_addr_segs -quiet $pattern]
  if {[llength $segs] == 0} {
    error "Cannot find address segment for $label using pattern: $pattern"
  }
  foreach seg $segs {
    set_property offset $offset $seg
    set_property range $range_bytes $seg
  }
}

set_addr_seg {xdma_0/M_AXI/*global_bram_ctrl*} 0x10000000 64K "XDMA global_bram"
set_addr_seg {xdma_0/M_AXI/*local_bram_ctrl*}  0x10010000 64K "XDMA local_bram"
set_addr_seg {xdma_0/M_AXI/*xdma_dcim_bram_ctrl*} 0x10020000 4K "XDMA controller"

set_addr_seg {axi_cdma_0/Data/*global_bram_ctrl*} 0x10000000 64K "CDMA global_bram"
set_addr_seg {axi_cdma_0/Data/*local_bram_ctrl*}  0x10010000 64K "CDMA local_bram"
set_addr_seg {xdma_dcim_bram_ctrl_0/m_axil_cdma/*axi_cdma_0*} 0x00000000 64K "controller CDMA registers"
