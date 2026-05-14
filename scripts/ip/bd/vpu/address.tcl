# VPU + XDMA/CDMA 地址映射
#
# 0x1000_0000  staging global_bram (128KB)
# 0x1002_0000  VPU GB (vpu_0/gb_axis, 64KB)
# 0x1003_0000  VPU WB (vpu_0/wb_axis, 64KB)
# 0x1004_0000  CDMA 寄存器 (64KB)
# 0x1005_0000  VPU_AXI_Regs (4KB)

assign_bd_address

# ==============================================================================
# Include CDMA 地址空间中被排除的段
# CDMA 需要能访问 VPU_GB 和 VPU_WB 来搬运数据
# ==============================================================================
startgroup
foreach pattern {
  axi_cdma_0/Data/SEG_vpu_0_reg0
  axi_cdma_0/Data/SEG_vpu_0_reg0_1
} {
  set seg [get_bd_addr_segs -quiet -excluded $pattern]
  if {[llength $seg] != 0} {
    include_bd_addr_seg $seg
    puts "INFO: Included CDMA segment: $pattern"
  }
}
endgroup

# Helper: find and set address segment
proc set_addr_seg_flex {patterns offset range_bytes label} {
  foreach pattern $patterns {
    set segs [get_bd_addr_segs -quiet $pattern]
    if {[llength $segs] != 0} {
      foreach seg $segs {
        set_property range $range_bytes $seg
        set_property offset $offset $seg
      }
      puts "INFO: Set $label at $offset ($range_bytes) using pattern: $pattern"
      return
    }
  }
  puts "WARNING: Cannot find address segment for $label"
  puts "  Tried patterns: $patterns"
}

# ==============================================================================
# XDMA address space (xdma_0/M_AXI)
# ==============================================================================
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_global_bram_ctrl_Mem0}
  {xdma_0/M_AXI/*global_bram_ctrl*}
} 0x10000000 128K "XDMA global_bram"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_0_reg0}
  {xdma_0/M_AXI/*vpu_0*reg0}
} 0x10020000 64K "XDMA VPU GB"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_0_reg0_1}
  {xdma_0/M_AXI/*vpu_0*reg0_1}
} 0x10030000 64K "XDMA VPU WB"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_axi_cdma_0_Reg}
  {xdma_0/M_AXI/*axi_cdma_0*}
} 0x10040000 64K "XDMA CDMA registers"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_regs_reg0}
  {xdma_0/M_AXI/*vpu_regs*}
} 0x10050000 4K "XDMA VPU regs"

# ==============================================================================
# CDMA address space (axi_cdma_0/Data)
# ==============================================================================
set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_global_bram_ctrl_Mem0}
  {axi_cdma_0/Data/*global_bram_ctrl*}
} 0x10000000 128K "CDMA global_bram"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_0_reg0}
  {axi_cdma_0/Data/*vpu_0*reg0}
} 0x10020000 64K "CDMA VPU GB"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_0_reg0_1}
  {axi_cdma_0/Data/*vpu_0*reg0_1}
} 0x10030000 64K "CDMA VPU WB"
