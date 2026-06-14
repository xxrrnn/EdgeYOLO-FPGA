# XDMA/CDMA address map.
#
# 0x1000_0000 - 0x1000_ffff  global_bram, 64KB
# 0x1001_0000 - 0x1001_ffff  PE ibuf,     64KB
# 0x1002_0000 - 0x1002_ffff  PE obuf,     64KB
# 0x1003_0000 - 0x1003_ffff  CDMA regs,   64KB
# 0x1004_0000 - 0x1004_0fff  PE weight base GPIO
# 0x1004_1000 - 0x1004_1fff  PE activation base GPIO
# 0x1004_2000 - 0x1004_2fff  PE result base GPIO
# 0x1004_3000 - 0x1004_3fff  PE raw_rows GPIO
# 0x1004_4000 - 0x1004_4fff  PE control GPIO
# 0x1004_5000 - 0x1004_5fff  PE status GPIO
#
# Host-orchestrated flow:
#   1. Program CDMA regs to copy global_bram -> PE ibuf for weight/activation.
#   2. Program PE GPIO config/control, pulse start.
#   3. Poll PE status GPIO until done.
#   4. Program CDMA regs to copy PE obuf -> global_bram.

assign_bd_address

proc set_addr_seg {pattern offset range_bytes label} {
  set segs [get_bd_addr_segs -quiet $pattern]
  if {[llength $segs] == 0} {
    error "Cannot find address segment for $label using pattern: $pattern"
  }
  foreach seg $segs {
    set_property range $range_bytes $seg
    set_property offset $offset $seg
  }
}

set_addr_seg {xdma_0/M_AXI/*global_bram_ctrl*} 0x10000000 64K "XDMA global_bram"
set_addr_seg {xdma_0/M_AXI/*pe_ibuf_ctrl*}     0x10010000 64K "XDMA PE ibuf"
set_addr_seg {xdma_0/M_AXI/*pe_obuf_ctrl*}     0x10020000 64K "XDMA PE obuf"
set_addr_seg {xdma_0/M_AXI/*axi_cdma_0*}       0x10030000 64K "XDMA CDMA registers"
set_addr_seg {xdma_0/M_AXI/*pe_cfg0_gpio*}     0x10040000 4K  "XDMA PE cfg0"
set_addr_seg {xdma_0/M_AXI/*pe_cfg1_gpio*}     0x10041000 4K  "XDMA PE cfg1"
set_addr_seg {xdma_0/M_AXI/*pe_cfg2_gpio*}     0x10042000 4K  "XDMA PE cfg2"
set_addr_seg {xdma_0/M_AXI/*pe_cfg3_gpio*}     0x10043000 4K  "XDMA PE cfg3"
set_addr_seg {xdma_0/M_AXI/*pe_ctrl_gpio*}     0x10044000 4K  "XDMA PE control"
set_addr_seg {xdma_0/M_AXI/*pe_status_gpio*}   0x10045000 4K  "XDMA PE status"

set_addr_seg {axi_cdma_0/Data/*global_bram_ctrl*} 0x10000000 64K "CDMA global_bram"
set_addr_seg {axi_cdma_0/Data/*pe_ibuf_ctrl*}     0x10010000 64K "CDMA PE ibuf"
set_addr_seg {axi_cdma_0/Data/*pe_obuf_ctrl*}     0x10020000 64K "CDMA PE obuf"
