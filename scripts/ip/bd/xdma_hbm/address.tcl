# XDMA M_AXI address map for direct HBM access.
#
# HBM switch is disabled in hbm.tcl for this bring-up design, so each SAXI
# port exposes one 256 MB memory segment:
#   SAXI_00/HBM_MEM00 -> 0x0000_0000
#   SAXI_01/HBM_MEM01 -> 0x1000_0000
#   ...
#   SAXI_31/HBM_MEM31 -> 0x1F000_0000

set xdma_as [get_bd_addr_spaces -quiet xdma_0/M_AXI]
if {[llength $xdma_as] == 0} {
  error "Cannot find XDMA M_AXI address space"
}

for {set idx 0} {$idx < 32} {incr idx} {
  set axi_num [format "%02d" $idx]
  set hbm_seg_name [format "hbm_0/SAXI_%s/HBM_MEM%s" $axi_num $axi_num]
  set hbm_seg [get_bd_addr_segs -quiet $hbm_seg_name]
  if {[llength $hbm_seg] == 0} {
    error "Cannot find HBM address segment $hbm_seg_name"
  }

  set offset [format "0x%X" [expr {$idx * 0x10000000}]]
  assign_bd_address \
    -target_address_space $xdma_as \
    -offset $offset \
    -range 256M \
    $hbm_seg \
    -force
}
