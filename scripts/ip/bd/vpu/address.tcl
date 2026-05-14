# VPU + XDMA/CDMA 地址映射
#
# ==================== 地址空间分配 ====================
# 地址             大小    名称                 说明
# 0x1000_0000      64KB    GLOBAL_BRAM_BASE    主机暂存缓冲区 (staging buffer)
# 0x1001_0000      64KB    VPU_GB_BASE         VPU Global Buffer (输入/输出数据)
# 0x1002_0000      64KB    VPU_WB_BASE         VPU Weight Buffer (权重/参数/Scale)
# 0x1003_0000      64KB    CDMA_BASE           CDMA 寄存器
# 0x1004_0000      4KB     VPU_REGS_BASE       VPU 控制寄存器
# ====================================================
#
# 注意事项：
# 1. 修改此文件后，需要同步更新 tests/vpu/xdma_helpers.py 中的常量定义
# 2. 需要重新生成 bitstream 才能生效
# 3. 所有地址必须与 RTL 中的 AXI 接口匹配

assign_bd_address

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

# XDMA address space
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_global_bram_ctrl_Mem0}
  {xdma_0/M_AXI/*global_bram_ctrl*}
} 0x10000000 64K "XDMA global_bram"

# vpu_0 有两个 AXI 接口: gb_axis 和 wb_axis
# Vivado 自动命名为 SEG_vpu_0_reg0 和 SEG_vpu_0_reg0_1
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_0_reg0}
  {xdma_0/M_AXI/*vpu_0*reg0}
} 0x10010000 64K "XDMA VPU GB"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_0_reg0_1}
  {xdma_0/M_AXI/*vpu_0*reg0_1}
} 0x10020000 64K "XDMA VPU WB"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_axi_cdma_0_Reg}
  {xdma_0/M_AXI/*axi_cdma_0*}
} 0x10030000 64K "XDMA CDMA registers"

set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_regs_reg0}
  {xdma_0/M_AXI/*vpu_regs*}
} 0x10040000 4K "XDMA VPU regs"

# CDMA address space
set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_global_bram_ctrl_Mem0}
  {axi_cdma_0/Data/*global_bram_ctrl*}
} 0x10000000 64K "CDMA global_bram"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_0_reg0}
  {axi_cdma_0/Data/*vpu_0*reg0}
} 0x10010000 64K "CDMA VPU GB"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_0_reg0_1}
  {axi_cdma_0/Data/*vpu_0*reg0_1}
} 0x10020000 64K "CDMA VPU WB"
