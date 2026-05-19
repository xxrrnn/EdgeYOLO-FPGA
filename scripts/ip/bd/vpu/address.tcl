# VPU + XDMA/CDMA 地址映射
#
# 地址映射由 vpu_defines.vh 定义，通过 parse_vpu_defines.tcl 解析
#
# 默认映射（从 vpu_defines.vh 读取）：
# 0x1000_0000  hbm_bram (1MB) - 暂时替代HBM的外部数据暂存区
# 0x1010_0000  inst_bram (128KB) - 指令区
# 0x1018_0000  VPU GB (512KB, 512KB-aligned) - 通过 vpu_gb_ctrl
# 0x1020_0000  VPU WB (32KB) - 通过 vpu_wb_ctrl
# 0x1020_8000  VPU_AXI_Regs (4KB) - 配置 + 状态 + 解码器控制
# 0x1012_0000–0x1017_FFFF 保留未用
#
# 注意：软件不再直接访问 CDMA 寄存器，由 INST_Decoder 通过 CDMA_Controller 控制

# ==============================================================================
# 加载 VPU 参数
# ==============================================================================
set script_dir [file dirname [info script]]
source [file join $script_dir "../../../common/parse_vpu_defines.tcl"]
parse_vpu_defines [file join $script_dir "../../../../rtl/vpu/vpu_defines.vh"]

# 从解析的参数中获取地址和大小
set addr_hbm_bram   [format "0x%08X" [get_vpu_param ADDR_HBM_BRAM 0x10000000]]
set addr_inst       [format "0x%08X" [get_vpu_param ADDR_INST_BRAM 0x10200000]]
set addr_vpu_gb     [format "0x%08X" [get_vpu_param ADDR_VPU_GB 0x10400000]]
set addr_vpu_wb     [format "0x%08X" [get_vpu_param ADDR_VPU_WB 0x10420000]]
set addr_vpu_regs   [format "0x%08X" [get_vpu_param ADDR_VPU_REGS 0x10440000]]

set hbm_bram_size   [bytes_to_range [get_vpu_param HBM_BRAM_SIZE_BYTES 1048576]]
set inst_size       [bytes_to_range [get_vpu_param INST_SIZE_BYTES 1048576]]
set gb_size         [bytes_to_range [get_vpu_param GB_SIZE_BYTES 131072]]
set wb_size         [bytes_to_range [get_vpu_param WB_SIZE_BYTES 32768]]

puts "INFO: VPU Address Map:"
puts "  HBM_BRAM      @ $addr_hbm_bram ($hbm_bram_size)"
puts "  INST_BRAM     @ $addr_inst ($inst_size)"
puts "  VPU_GB        @ $addr_vpu_gb ($gb_size)"
puts "  VPU_WB        @ $addr_vpu_wb ($wb_size)"
puts "  VPU_REGS      @ $addr_vpu_regs (4K)"

assign_bd_address

# ==============================================================================
# Include CDMA 地址空间中被排除的段
# CDMA 需要能访问 VPU_GB 和 VPU_WB 来搬运数据
# ==============================================================================
startgroup
foreach pattern {
  axi_cdma_0/Data/SEG_vpu_gb_ctrl_Mem0
  axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0
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
# XDMA / CDMA 地址空间
# assign_bd_address 默认将 WB 放在 0x10140000，会挡住 GB 扩到 256KB。
# 必须先 relocation WB/REGS，再扩展 GB range。
# ==============================================================================
set xdma_wb_patterns {
  {xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0}
  {xdma_0/M_AXI/*vpu_wb_ctrl*}
}
set xdma_regs_patterns {
  {xdma_0/M_AXI/SEG_vpu_regs_reg0}
  {xdma_0/M_AXI/*vpu_regs*}
}
set xdma_gb_patterns {
  {xdma_0/M_AXI/SEG_vpu_gb_ctrl_Mem0}
  {xdma_0/M_AXI/*vpu_gb_ctrl*}
}
set cdma_wb_patterns {
  {axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0}
  {axi_cdma_0/Data/*vpu_wb_ctrl*}
}
set cdma_gb_patterns {
  {axi_cdma_0/Data/SEG_vpu_gb_ctrl_Mem0}
  {axi_cdma_0/Data/*vpu_gb_ctrl*}
}

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_global_bram_ctrl_Mem0}
  {xdma_0/M_AXI/*global_bram_ctrl*}
} $addr_hbm_bram $hbm_bram_size "XDMA hbm_bram"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_inst_bram_reg0}
  {xdma_0/M_AXI/*inst_bram*}
} $addr_inst $inst_size "XDMA inst_bram"

# 1) 先挪 WB / REGS（assign_bd_address 默认 WB@0x10140000 会挡住 256KB GB）
set_addr_seg_flex $xdma_wb_patterns $addr_vpu_wb $wb_size "XDMA VPU WB"
set_addr_seg_flex $xdma_regs_patterns $addr_vpu_regs 4K "XDMA VPU regs"

# 2) 再扩展 GB 到 256KB
set_addr_seg_flex $xdma_gb_patterns $addr_vpu_gb $gb_size "XDMA VPU GB"

# CDMA 同样顺序
set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_global_bram_ctrl_Mem0}
  {axi_cdma_0/Data/*global_bram_ctrl*}
} $addr_hbm_bram $hbm_bram_size "CDMA hbm_bram"

set_addr_seg_flex $cdma_wb_patterns $addr_vpu_wb $wb_size "CDMA VPU WB"
set_addr_seg_flex $cdma_gb_patterns $addr_vpu_gb $gb_size "CDMA VPU GB"

# ==============================================================================
# cdma_ctrl 的 AXI-Lite Master 地址空间
# Vivado 默认将 CDMA S_AXI_LITE 分配到 0x44A00000，
# 但我们的 CDMA_Controller RTL 使用 CDMA_BASE_ADDR=0，
# 所以必须将该映射改为 offset=0
# ==============================================================================
set_addr_seg_flex {
  {cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg}
  {cdma_ctrl/cdma_axilm/*}
} 0x00000000 64K "CDMA_Controller -> CDMA S_AXI_LITE"
