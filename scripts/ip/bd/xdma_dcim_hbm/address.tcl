# XDMA/CDMA address map.
#
# HBM keeps the xdma_hbm bring-up layout.  HBM switch is disabled in hbm.tcl,
# so each SAXI port exposes one 256 MB segment:
#   SAXI_00/HBM_MEM00 -> 0x000000000
#   SAXI_01/HBM_MEM01 -> 0x010000000
#   ...
#   SAXI_31/HBM_MEM31 -> 0x1F0000000
#
# Local PE/CDMA/GPIO aperture starts after the 8 GB HBM window:
#   0x200000000 - 0x20000ffff  PE ibuf,      64 KB
#   0x200010000 - 0x20001ffff  PE obuf,      64 KB
#   0x200020000 - 0x20002ffff  CDMA regs,    64 KB
#   0x200030000 - 0x200030fff  PE cfg0 GPIO
#   0x200031000 - 0x200031fff  PE cfg1 GPIO
#   0x200032000 - 0x200032fff  PE cfg2 GPIO
#   0x200033000 - 0x200033fff  PE cfg3 GPIO
#   0x200034000 - 0x200034fff  PE control GPIO
#   0x200035000 - 0x200035fff  PE status GPIO
#
# Host-orchestrated flow:
#   1. XDMA writes input tensors into HBM.
#   2. XDMA programs CDMA to copy HBM -> PE ibuf.
#   3. XDMA programs PE GPIO config/control and polls PE status.
#   4. XDMA programs CDMA to copy PE obuf -> HBM.
#   5. XDMA reads HBM and compares against software golden data.

proc require_addr_space {pattern label} {
  set addr_space [get_bd_addr_spaces -quiet $pattern]
  if {[llength $addr_space] == 0} {
    error "Cannot find address space for $label using pattern: $pattern"
  }
  return $addr_space
}

proc require_addr_segs {pattern label} {
  set segs [get_bd_addr_segs -quiet $pattern]
  if {[llength $segs] == 0} {
    error "Cannot find address segment for $label using pattern: $pattern"
  }
  return $segs
}

proc map_seg {addr_space pattern offset range label} {
  foreach seg [require_addr_segs $pattern $label] {
    assign_bd_address \
      -target_address_space $addr_space \
      -offset $offset \
      -range $range \
      $seg \
      -force
  }
}

set xdma_as [require_addr_space xdma_0/M_AXI "XDMA M_AXI"]
set cdma_as [require_addr_space axi_cdma_0/Data "CDMA M_AXI"]

for {set idx 0} {$idx < 32} {incr idx} {
  set axi_num [format "%02d" $idx]
  set hbm_seg_name [format "hbm_0/SAXI_%s/HBM_MEM%s" $axi_num $axi_num]
  set hbm_seg [require_addr_segs $hbm_seg_name "HBM SAXI_$axi_num"]
  set offset [format "0x%X" [expr {$idx * 0x10000000}]]

  assign_bd_address \
    -target_address_space $xdma_as \
    -offset $offset \
    -range 256M \
    $hbm_seg \
    -force

  assign_bd_address \
    -target_address_space $cdma_as \
    -offset $offset \
    -range 256M \
    $hbm_seg \
    -force
}

map_seg $xdma_as {pe_ibuf_ctrl/S_AXI/*}       0x200000000 64K "XDMA PE ibuf"
map_seg $xdma_as {pe_obuf_ctrl/S_AXI/*}       0x200010000 64K "XDMA PE obuf"
map_seg $xdma_as {axi_cdma_0/S_AXI_LITE/*}    0x200020000 64K "XDMA CDMA registers"
map_seg $xdma_as {pe_cfg0_gpio/S_AXI/*}       0x200030000 4K  "XDMA PE cfg0"
map_seg $xdma_as {pe_cfg1_gpio/S_AXI/*}       0x200031000 4K  "XDMA PE cfg1"
map_seg $xdma_as {pe_cfg2_gpio/S_AXI/*}       0x200032000 4K  "XDMA PE cfg2"
map_seg $xdma_as {pe_cfg3_gpio/S_AXI/*}       0x200033000 4K  "XDMA PE cfg3"
map_seg $xdma_as {pe_ctrl_gpio/S_AXI/*}       0x200034000 4K  "XDMA PE control"
map_seg $xdma_as {pe_status_gpio/S_AXI/*}     0x200035000 4K  "XDMA PE status"

map_seg $cdma_as {pe_ibuf_ctrl/S_AXI/*}       0x200000000 64K "CDMA PE ibuf"
map_seg $cdma_as {pe_obuf_ctrl/S_AXI/*}       0x200010000 64K "CDMA PE obuf"
map_seg $cdma_as {axi_cdma_0/S_AXI_LITE/*}    0x200020000 64K "CDMA CDMA registers"
map_seg $cdma_as {pe_cfg0_gpio/S_AXI/*}       0x200030000 4K  "CDMA PE cfg0"
map_seg $cdma_as {pe_cfg1_gpio/S_AXI/*}       0x200031000 4K  "CDMA PE cfg1"
map_seg $cdma_as {pe_cfg2_gpio/S_AXI/*}       0x200032000 4K  "CDMA PE cfg2"
map_seg $cdma_as {pe_cfg3_gpio/S_AXI/*}       0x200033000 4K  "CDMA PE cfg3"
map_seg $cdma_as {pe_ctrl_gpio/S_AXI/*}       0x200034000 4K  "CDMA PE control"
map_seg $cdma_as {pe_status_gpio/S_AXI/*}     0x200035000 4K  "CDMA PE status"
