# VPU + XDMA/CDMA 地址映射
#
# 0x1000_0000  staging global_bram (1MB) - 数据区
# 0x1020_0000  inst_bram (1MB) - 指令区
# 0x1040_0000  VPU GB (128KB)
# 0x1042_0000  VPU WB (128KB)
# 0x1044_0000  VPU_AXI_Regs (4KB) - 配置 + 状态 + 解码器控制
#
# 注意：软件不再直接访问 CDMA 寄存器，由 INST_Decoder 通过 CDMA_Controller 控制

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
} 0x10000000 1M "XDMA global_bram"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_inst_bram_reg0}
  {xdma_0/M_AXI/*inst_bram*}
} 0x10200000 1M "XDMA inst_bram"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_0_reg0}
  {xdma_0/M_AXI/*vpu_0*reg0}
} 0x10400000 128K "XDMA VPU GB"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_0_reg0_1}
  {xdma_0/M_AXI/*vpu_0*reg0_1}
} 0x10420000 128K "XDMA VPU WB"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_regs_reg0}
  {xdma_0/M_AXI/*vpu_regs*}
} 0x10440000 4K "XDMA VPU regs"

# ==============================================================================
# CDMA address space (axi_cdma_0/Data)
# ==============================================================================
set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_global_bram_ctrl_Mem0}
  {axi_cdma_0/Data/*global_bram_ctrl*}
} 0x10000000 1M "CDMA global_bram"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_0_reg0}
  {axi_cdma_0/Data/*vpu_0*reg0}
} 0x10400000 128K "CDMA VPU GB"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_0_reg0_1}
  {axi_cdma_0/Data/*vpu_0*reg0_1}
} 0x10420000 128K "CDMA VPU WB"
