# XDMA/CDMA address map for DCIM_Array Chip system (64 Tile, 8 Groups).
#
# 架构：8 组 × 8 Tile/组 = 64 Tile
# 每组独立的 IBUF/OBUF，256KB 每组
#
# Two-level AXI Interconnect:
#   Main IC (axi_main_ic):
#     M00 = global_bram @ 0x0000_0000
#     M01 = CDMA regs @ 0x0050_0000
#     M02 = DCIM config @ 0x0051_0000
#     M03 = Buffer IC @ 0x0010_0000 base
#   Buffer IC (axi_buf_ic) at 0x0010_0000 base:
#     M00-M07 = IBUF groups 0-7
#     M08-M15 = OBUF groups 0-7
#
# ============================================================================
# 地址映射
# ============================================================================
# 0x0000_0000 - 0x0001_ffff  global_bram,     128KB
#
# IBUF Group 0-7 (每组 256KB):
# 0x0010_0000 - 0x0013_ffff  DCIM ibuf group 0,  256KB
# 0x0014_0000 - 0x0017_ffff  DCIM ibuf group 1,  256KB
# 0x0018_0000 - 0x001b_ffff  DCIM ibuf group 2,  256KB
# 0x001c_0000 - 0x001f_ffff  DCIM ibuf group 3,  256KB
# 0x0020_0000 - 0x0023_ffff  DCIM ibuf group 4,  256KB
# 0x0024_0000 - 0x0027_ffff  DCIM ibuf group 5,  256KB
# 0x0028_0000 - 0x002b_ffff  DCIM ibuf group 6,  256KB
# 0x002c_0000 - 0x002f_ffff  DCIM ibuf group 7,  256KB
#
# OBUF Group 0-7 (每组 256KB):
# 0x0030_0000 - 0x0033_ffff  DCIM obuf group 0,  256KB
# 0x0034_0000 - 0x0037_ffff  DCIM obuf group 1,  256KB
# 0x0038_0000 - 0x003b_ffff  DCIM obuf group 2,  256KB
# 0x003c_0000 - 0x003f_ffff  DCIM obuf group 3,  256KB
# 0x0040_0000 - 0x0043_ffff  DCIM obuf group 4,  256KB
# 0x0044_0000 - 0x0047_ffff  DCIM obuf group 5,  256KB
# 0x0048_0000 - 0x004b_ffff  DCIM obuf group 6,  256KB
# 0x004c_0000 - 0x004f_ffff  DCIM obuf group 7,  256KB
#
# 控制寄存器:
# 0x0050_0000 - 0x0050_ffff  CDMA regs,          64KB
# 0x0051_0000 - 0x0051_0fff  DCIM AXI-Lite,      4KB
#
# ============================================================================
# DCIM AXI-Lite 寄存器映射（相对 0x0051_0000）
# ============================================================================
#  字节偏移    寄存器         说明
#  --------   -----------   ---------------------------------
#  0x000      CTRL          写 bit0 脉冲 start（W1C）
#  0x004      STATUS        读：bit[0]=done, bit[1]=ready
#  0x008      MODE          mode / acc_depth
#  0x00C      NUM_ROWS
#  0x010-0x02F ACT_BASE[0..7]  每组的激活基址 (8 × 4B)
#  0x040-0x13F WEI_BASE[0..63] 每 Tile 的权重基址 (64 × 4B)
#  0x140-0x23F OUT_BASE[0..63] 每 Tile 的输出基址 (64 × 4B)
#
# ============================================================================

assign_bd_address

proc set_addr_seg {pattern offset range_bytes label} {
  set segs [get_bd_addr_segs -quiet $pattern]
  if {[llength $segs] == 0} {
    puts "Warning: Cannot find address segment for $label using pattern: $pattern"
    return
  }
  foreach seg $segs {
    set_property range $range_bytes $seg
    set_property offset $offset $seg
  }
}

# ============================================================================
# Main Interconnect address assignments
# ============================================================================

# Global BRAM
set_addr_seg {xdma_0/M_AXI/*global_bram_ctrl*} 0x00000000 128K  "XDMA global_bram"
set_addr_seg {axi_cdma_0/Data/*global_bram_ctrl*} 0x00000000 128K  "CDMA global_bram"

# CDMA and DCIM config registers
set_addr_seg {xdma_0/M_AXI/*axi_cdma_0*}   0x00500000 64K   "XDMA CDMA registers"
set_addr_seg {xdma_0/M_AXI/*dcim_array_0*} 0x00510000 4K    "XDMA DCIM config"

# Buffer Interconnect (entire range for all buffers)
set_addr_seg {xdma_0/M_AXI/*axi_buf_ic*}   0x00100000 4M    "XDMA Buffer IC"
set_addr_seg {axi_cdma_0/Data/*axi_buf_ic*} 0x00100000 4M  "CDMA Buffer IC"

# ============================================================================
# Buffer Interconnect address assignments  
# ============================================================================

# IBUF groups 0-7 (256KB each, starting at 0x00100000 relative to buffer IC base)
for {set i 0} {$i < 8} {incr i} {
    set offset [expr {0x00100000 + $i * 0x00040000}]
    set_addr_seg "xdma_0/M_AXI/SEG_dcim_ibuf_ctrl_${i}_Mem0" $offset 256K "XDMA DCIM ibuf group $i"
    set_addr_seg "axi_cdma_0/Data/SEG_dcim_ibuf_ctrl_${i}_Mem0" $offset 256K "CDMA DCIM ibuf group $i"
}

# OBUF groups 0-7 (256KB each, starting at 0x00300000)
for {set i 0} {$i < 8} {incr i} {
    set offset [expr {0x00300000 + $i * 0x00040000}]
    set_addr_seg "xdma_0/M_AXI/SEG_dcim_obuf_ctrl_${i}_Mem0" $offset 256K "XDMA DCIM obuf group $i"
    set_addr_seg "axi_cdma_0/Data/SEG_dcim_obuf_ctrl_${i}_Mem0" $offset 256K "CDMA DCIM obuf group $i"
}
