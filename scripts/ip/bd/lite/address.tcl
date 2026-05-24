# ==============================================================================
# address.tcl - lite version: DCIM + VPU system address map (no HBM, no GB)
# ==============================================================================
# 地址空间 (64-bit):
#   0x1_0000_0000 ~ 0x1_001F_FFFF  DCIM IBUF (2MB, 1 group)
#   0x1_0100_0000 ~ 0x1_01FF_FFFF  DCIM OBUF (16MB, 1 group, feature buffer)
#   0x1_0200_0000                   VPU WB (32KB)
#   0x1_0300_0000                   INST_BRAM (128KB)
#   0x1_0400_0000                   VPU_AXI_Regs (4KB)
#
# CDMA 可访问: DCIM IBUF/OBUF + VPU WB
# ==============================================================================

assign_bd_address

# Helper proc
proc set_addr_seg_flex {patterns offset range_bytes label} {
  foreach pattern $patterns {
    set segs [get_bd_addr_segs -quiet $pattern]
    if {[llength $segs] != 0} {
      foreach seg $segs {
        set_property range $range_bytes $seg
        set_property offset $offset $seg
      }
      puts "INFO: Set $label at $offset ($range_bytes)"
      return
    }
  }
  puts "WARNING: Cannot find segment for $label"
}

# ==============================================================================
# Include excluded CDMA segments
# ==============================================================================
startgroup
foreach pattern {
  axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0
} {
  set seg [get_bd_addr_segs -quiet -excluded $pattern]
  if {[llength $seg] != 0} {
    include_bd_addr_seg $seg
  }
}
foreach suffix {ibuf obuf} {
  set seg [get_bd_addr_segs -quiet -excluded "axi_cdma_0/Data/SEG_dcim_${suffix}_ctrl_0_Mem0"]
  if {[llength $seg] != 0} { include_bd_addr_seg $seg }
}
endgroup

# ==============================================================================
# XDMA address assignments
# ==============================================================================

# Move small peripherals out of IBUF/OBUF range FIRST (avoid overlap)
# VPU_AXI_Regs 4KB @ 0x1_0400_0000
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_regs_reg0}
  {xdma_0/M_AXI/*vpu_regs*}
} 0x104000000 4K "XDMA VPU Regs"

# INST_BRAM 128KB @ 0x1_0300_0000
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_inst_bram_reg0}
  {xdma_0/M_AXI/*inst_bram*}
} 0x103000000 128K "XDMA INST_BRAM"

# VPU WB 32KB @ 0x1_0200_0000
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0}
  {xdma_0/M_AXI/*vpu_wb_ctrl*}
} 0x102000000 32K "XDMA VPU WB"

# DCIM IBUF: 1 Controller, 2MB @ 0x1_0000_0000
set_addr_seg_flex [list \
  "xdma_0/M_AXI/SEG_dcim_ibuf_ctrl_0_Mem0" \
  "xdma_0/M_AXI/*dcim_ibuf_ctrl_0*" \
] 0x100000000 2M "XDMA DCIM IBUF"

# DCIM OBUF: 1 Controller, 16MB @ 0x1_0100_0000 (lite: 2MB → 16MB)
set_addr_seg_flex [list \
  "xdma_0/M_AXI/SEG_dcim_obuf_ctrl_0_Mem0" \
  "xdma_0/M_AXI/*dcim_obuf_ctrl_0*" \
] 0x101000000 16M "XDMA DCIM OBUF (feature buffer)"

# ==============================================================================
# CDMA address assignments (same offsets for data movement)
# ==============================================================================

# CDMA DCIM IBUF
set_addr_seg_flex [list \
  "axi_cdma_0/Data/SEG_dcim_ibuf_ctrl_0_Mem0" \
  "axi_cdma_0/Data/*dcim_ibuf_ctrl_0*" \
] 0x100000000 2M "CDMA DCIM IBUF"

# CDMA DCIM OBUF (16MB)
set_addr_seg_flex [list \
  "axi_cdma_0/Data/SEG_dcim_obuf_ctrl_0_Mem0" \
  "axi_cdma_0/Data/*dcim_obuf_ctrl_0*" \
] 0x101000000 16M "CDMA DCIM OBUF"

# CDMA VPU WB
set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0}
  {axi_cdma_0/Data/*vpu_wb_ctrl*}
} 0x102000000 32K "CDMA VPU WB"

# ==============================================================================
# HBM address assignment: 4GB @ 0x0_0000_0000
# Both XDMA and CDMA can access HBM for weight/feature storage
# ==============================================================================

# XDMA → HBM (4GB)
set_addr_seg_flex [list \
  "xdma_0/M_AXI/SEG_hbm_0_HBM_MEM00" \
  "xdma_0/M_AXI/*hbm*" \
] 0x000000000 4G "XDMA HBM (4GB)"

# CDMA → HBM (4GB, same offset for DMA transfers)
set_addr_seg_flex [list \
  "axi_cdma_0/Data/SEG_hbm_0_HBM_MEM00" \
  "axi_cdma_0/Data/*hbm*" \
] 0x000000000 4G "CDMA HBM (4GB)"

# ==============================================================================
# CDMA_Controller → CDMA S_AXI_LITE at offset 0x0
# ==============================================================================
set_addr_seg_flex {
  {cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg}
  {cdma_ctrl/cdma_axilm/*}
} 0x00000000 64K "CDMA_Controller -> CDMA"
