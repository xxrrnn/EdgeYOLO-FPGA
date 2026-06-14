# ==============================================================================
# DCIM+VPU+HBM 系统地址映射
# ==============================================================================
# 地址空间 (64-bit):
#   0x0_0000_0000 ~ 0x0_FFFF_FFFF  HBM 4GB
#   0x1_0000_0000 ~ 0x1_001F_FFFF  DCIM IBUF Group 0~7 (8×256KB = 2MB)
#   0x1_0020_0000 ~ 0x1_003F_FFFF  DCIM OBUF Group 0~7 (8×256KB = 2MB)
#   0x1_0040_0000                   VPU GB (512KB)
#   0x1_0048_0000                   VPU WB (32KB)
#   0x1_0050_0000                   INST_BRAM (128KB)
#   0x1_0060_0000                   VPU_AXI_Regs (4KB)
#   0x1_0060_1000                   DCIM_Array AXI regs (4KB)
#
# CDMA 可访问: HBM + DCIM IBUF/OBUF + VPU GB/WB
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
  axi_cdma_0/Data/SEG_vpu_gb_ctrl_Mem0
  axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0
} {
  set seg [get_bd_addr_segs -quiet -excluded $pattern]
  if {[llength $seg] != 0} {
    include_bd_addr_seg $seg
  }
}
# 只有 ctrl_0 存在（统一接口）
foreach suffix {ibuf obuf} {
  set seg [get_bd_addr_segs -quiet -excluded "axi_cdma_0/Data/SEG_dcim_${suffix}_ctrl_0_Mem0"]
  if {[llength $seg] != 0} { include_bd_addr_seg $seg }
}
endgroup

# ==============================================================================
# XDMA address assignments
# ==============================================================================

# HBM: 8 MC × 256MB each = 2GB usable (single stack), starting at 0x0
for {set i 0} {$i < 8} {incr i} {
  set mem_name [format "HBM_MEM%02d" $i]
  set offset [format "0x%09X" [expr {$i * 0x10000000}]]
  set_addr_seg_flex [list \
    "xdma_0/M_AXI/SEG_hbm_0_${mem_name}" \
    "xdma_0/M_AXI/*hbm_0*${mem_name}*" \
  ] $offset 256M "XDMA HBM $mem_name"
}

# Move small peripherals out of IBUF/OBUF range FIRST (avoid overlap)
# VPU_AXI_Regs 4KB @ 0x1_0060_0000
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_regs_reg0}
  {xdma_0/M_AXI/*vpu_regs*}
} 0x100600000 4K "XDMA VPU Regs"

# INST_BRAM 128KB @ 0x1_0050_0000
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_inst_bram_reg0}
  {xdma_0/M_AXI/*inst_bram*}
} 0x100500000 128K "XDMA INST_BRAM"

# VPU GB 512KB @ 0x1_0040_0000
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_gb_ctrl_Mem0}
  {xdma_0/M_AXI/*vpu_gb_ctrl*}
} 0x100400000 512K "XDMA VPU GB"

# VPU WB 32KB @ 0x1_0048_0000
set_addr_seg_flex {
  {xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0}
  {xdma_0/M_AXI/*vpu_wb_ctrl*}
} 0x100480000 32K "XDMA VPU WB"

# DCIM IBUF: 1 Controller, 全部 8 Group 广播，地址空间 2MB @ 0x1_0000_0000
# （bd层将单一写接口广播到所有8组IBUF，软件写一次即可）
set_addr_seg_flex [list \
  "xdma_0/M_AXI/SEG_dcim_ibuf_ctrl_0_Mem0" \
  "xdma_0/M_AXI/*dcim_ibuf_ctrl_0*" \
] 0x100000000 2M "XDMA DCIM IBUF (unified broadcast)"

# DCIM OBUF: 1 Controller, 统一扩展地址空间 2MB @ 0x1_0020_0000
# 地址高3位=[14:12]选择Group (0~7)，低14位为组内字地址
set_addr_seg_flex [list \
  "xdma_0/M_AXI/SEG_dcim_obuf_ctrl_0_Mem0" \
  "xdma_0/M_AXI/*dcim_obuf_ctrl_0*" \
] 0x100200000 2M "XDMA DCIM OBUF (unified extended addr)"

# ==============================================================================
# CDMA address assignments (same offsets for data movement)
# ==============================================================================

for {set i 0} {$i < 8} {incr i} {
  set mem_name [format "HBM_MEM%02d" $i]
  set offset [format "0x%09X" [expr {$i * 0x10000000}]]
  set_addr_seg_flex [list \
    "axi_cdma_0/Data/SEG_hbm_0_${mem_name}" \
    "axi_cdma_0/Data/*hbm_0*${mem_name}*" \
  ] $offset 256M "CDMA HBM $mem_name"
}

# CDMA DCIM IBUF: 1 Controller (unified broadcast)
set_addr_seg_flex [list \
  "axi_cdma_0/Data/SEG_dcim_ibuf_ctrl_0_Mem0" \
  "axi_cdma_0/Data/*dcim_ibuf_ctrl_0*" \
] 0x100000000 2M "CDMA DCIM IBUF (unified)"

# CDMA DCIM OBUF: 1 Controller (unified extended addr)
set_addr_seg_flex [list \
  "axi_cdma_0/Data/SEG_dcim_obuf_ctrl_0_Mem0" \
  "axi_cdma_0/Data/*dcim_obuf_ctrl_0*" \
] 0x100200000 2M "CDMA DCIM OBUF (unified)"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_gb_ctrl_Mem0}
  {axi_cdma_0/Data/*vpu_gb_ctrl*}
} 0x100400000 512K "CDMA VPU GB"

set_addr_seg_flex {
  {axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0}
  {axi_cdma_0/Data/*vpu_wb_ctrl*}
} 0x100480000 32K "CDMA VPU WB"

# ==============================================================================
# CDMA_Controller → CDMA S_AXI_LITE at offset 0x0
# ==============================================================================
set_addr_seg_flex {
  {cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg}
  {cdma_ctrl/cdma_axilm/*}
} 0x00000000 64K "CDMA_Controller -> CDMA"
