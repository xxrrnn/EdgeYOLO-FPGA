# ==============================================================================
# address.tcl - chip-v3: distributed tile_ibuf + tile_obuf + VPU_BUF address map
# ==============================================================================
# 地址空间 (64-bit), N = $::DCIM_NUM_TILES:
#   0x0_0000_0000 ~ 0x0_FFFF_FFFF  HBM (4GB, interleaved, SAXI_00)
#   0x1_0000_0000 + t*0x80000       tile_ibuf_t (512KB each, t=0..N-1)
#   0x1_0100_0000 + t*0x40000       tile_obuf_t (256KB each, t=0..N-1)
#   0x1_0200_0000 ~ 0x1_020F_FFFF  VPU_BUF (8MB)
#   0x1_0300_0000 ~ 0x1_0307_FFFF  VPU WB (32KB)
#   0x1_0400_0000 ~ 0x1_041F_FFFF  INST_BRAM (128KB)
#   0x1_0500_0000 ~ 0x1_0500_0FFF  VPU_AXI_Regs (4KB)
#
# CDMA 可访问: HBM + tile_ibuf[0..N-1] + tile_obuf[0..N-1] + VPU_BUF + WB
# XDMA 可访问: 上述全部 + INST_BRAM + VPU_AXI_Regs
# ==============================================================================

# ==============================================================================
# Step 1: auto-assign
# ==============================================================================
assign_bd_address

# ==============================================================================
# Helper
# ==============================================================================
proc mv {pattern offset range_bytes} {
  set seg [lindex [get_bd_addr_segs -quiet $pattern] 0]
  if {$seg eq ""} {
    set seg [lindex [get_bd_addr_segs -quiet -excluded $pattern] 0]
    if {$seg ne ""} { include_bd_addr_seg $seg }
  }
  if {$seg eq ""} {
    puts "WARNING: Not found: $pattern"
    return
  }
  set_property range  $range_bytes $seg
  set_property offset $offset      $seg
  puts "INFO: $seg -> $offset ($range_bytes)"
}

# ==============================================================================
# XDMA M_AXI: Phase 1 临时高位 → Phase 2 最终地址
# ==============================================================================
# Phase 1: 全部搬到临时高位（互不重叠），tile 数由 $::DCIM_NUM_TILES 驱动
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set tmp_offset [format "0x%X" [expr {0x1E0000000 + $t * 0x100000}]]
  mv "xdma_0/M_AXI/SEG_tile_ibuf_ctrl_${t}_Mem0" $tmp_offset 512K
}
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set tmp_offset [format "0x%X" [expr {0x1E2000000 + $t * 0x100000}]]
  mv "xdma_0/M_AXI/SEG_tile_obuf_ctrl_${t}_Mem0" $tmp_offset 256K
}
mv "xdma_0/M_AXI/SEG_vpu_buf_ctrl_Mem0"      0x1E4000000  8M
mv "xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0"       0x1F0000000  32K
mv "xdma_0/M_AXI/SEG_inst_bram_ctrl_Mem0"    0x1F2000000  128K
mv "xdma_0/M_AXI/SEG_vpu_regs_reg0"          0x1F4000000  4K

# Phase 2: 最终目标地址
set ibuf_base 0x100000000
set ibuf_size 0x80000  ;# 512KB
set obuf_base 0x101000000
set obuf_size 0x40000  ;# 256KB

for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set offset [format "0x%X" [expr {$ibuf_base + $t * $ibuf_size}]]
  mv "xdma_0/M_AXI/SEG_tile_ibuf_ctrl_${t}_Mem0" $offset 512K
}
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set offset [format "0x%X" [expr {$obuf_base + $t * $obuf_size}]]
  mv "xdma_0/M_AXI/SEG_tile_obuf_ctrl_${t}_Mem0" $offset 256K
}
mv "xdma_0/M_AXI/SEG_vpu_buf_ctrl_Mem0"      0x102000000  8M
mv "xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0"       0x103000000  32K
mv "xdma_0/M_AXI/SEG_inst_bram_ctrl_Mem0"    0x104000000  128K
mv "xdma_0/M_AXI/SEG_vpu_regs_reg0"          0x105000000  4K

# ==============================================================================
# CDMA M_AXI Data: tile_ibuf[0..N-1] + tile_obuf[0..N-1] + VPU_BUF + WB
# Exclude inst_bram_ctrl and vpu_regs from CDMA
# ==============================================================================
set _cdma_inst_seg [get_bd_addr_segs -quiet "axi_cdma_0/Data/SEG_inst_bram_ctrl_Mem0"]
if {[llength $_cdma_inst_seg]} {
  exclude_bd_addr_seg $_cdma_inst_seg
}
set _cdma_regs_seg [get_bd_addr_segs -quiet "axi_cdma_0/Data/SEG_vpu_regs_reg0"]
if {[llength $_cdma_regs_seg]} {
  exclude_bd_addr_seg $_cdma_regs_seg
}

# Phase 1: 临时高位
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set tmp_offset [format "0x%X" [expr {0x1E0000000 + $t * 0x100000}]]
  mv "axi_cdma_0/Data/SEG_tile_ibuf_ctrl_${t}_Mem0" $tmp_offset 512K
}
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set tmp_offset [format "0x%X" [expr {0x1E2000000 + $t * 0x100000}]]
  mv "axi_cdma_0/Data/SEG_tile_obuf_ctrl_${t}_Mem0" $tmp_offset 256K
}
mv "axi_cdma_0/Data/SEG_vpu_buf_ctrl_Mem0"      0x1E4000000  8M
mv "axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0"       0x1F0000000  32K

# Phase 2: 最终地址（与 XDMA 一致）
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set offset [format "0x%X" [expr {$ibuf_base + $t * $ibuf_size}]]
  mv "axi_cdma_0/Data/SEG_tile_ibuf_ctrl_${t}_Mem0" $offset 512K
}
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  set offset [format "0x%X" [expr {$obuf_base + $t * $obuf_size}]]
  mv "axi_cdma_0/Data/SEG_tile_obuf_ctrl_${t}_Mem0" $offset 256K
}
mv "axi_cdma_0/Data/SEG_vpu_buf_ctrl_Mem0"      0x102000000  8M
mv "axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0"       0x103000000  32K

# ==============================================================================
# HBM @ 0x0_0000_0000 (4GB)
# ==============================================================================
proc fix_hbm {master_prefix} {
  # 已分配的 HBM segs
  set assigned [get_bd_addr_segs -quiet "${master_prefix}/SEG_hbm_0_*"]
  set excluded_segs [get_bd_addr_segs -quiet -excluded "${master_prefix}/SEG_hbm_0_*"]

  set anchor ""
  foreach seg $assigned {
    if {[string match "*HBM_MEM00*" $seg]} {
      set anchor $seg
    } else {
      catch { exclude_bd_addr_seg $seg }
    }
  }

  if {$anchor ne ""} {
    set_property range  4G         $anchor
    set_property offset 0x000000000 $anchor
    puts "INFO: HBM keep $anchor -> 0x0_0000_0000 (4G)"
  } else {
    foreach seg $excluded_segs {
      if {[string match "*HBM_MEM00*" $seg]} {
        include_bd_addr_seg $seg
        set_property range  4G         $seg
        set_property offset 0x000000000 $seg
        puts "INFO: HBM include+keep $seg -> 0x0_0000_0000 (4G)"
        set anchor $seg
        break
      }
    }
  }
  if {$anchor eq ""} { puts "WARNING: No HBM MEM00 for $master_prefix" }
}
fix_hbm "xdma_0/M_AXI"
fix_hbm "axi_cdma_0/Data"

# ==============================================================================
# CDMA_Controller → CDMA S_AXI_LITE @ 0x0 (64KB)
# ==============================================================================
set _cdma_lite_seg [get_bd_addr_segs -quiet "cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg"]
if {[llength $_cdma_lite_seg] == 0} {
  set _cdma_lite_seg [get_bd_addr_segs -quiet -excluded "cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg"]
  if {[llength $_cdma_lite_seg]} { include_bd_addr_seg [lindex $_cdma_lite_seg 0] }
}
if {[llength $_cdma_lite_seg] == 0} {
  set _cdma_lite_seg [get_bd_addr_segs -quiet "cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_*"]
  if {[llength $_cdma_lite_seg] == 0} {
    set _cdma_lite_seg [get_bd_addr_segs -quiet -excluded "cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_*"]
    if {[llength $_cdma_lite_seg]} { include_bd_addr_seg [lindex $_cdma_lite_seg 0] }
  }
}
if {[llength $_cdma_lite_seg]} {
  set_property range  64K        [lindex $_cdma_lite_seg 0]
  set_property offset 0x00000000 [lindex $_cdma_lite_seg 0]
  puts "INFO: CDMA_Controller AXI-Lite seg: [lindex $_cdma_lite_seg 0] -> 0x0 (64K)"
} else {
  puts "WARNING: CDMA AXI-Lite segment not found"
  catch {
    assign_bd_address -target_address_space cdma_ctrl/cdma_axilm \
      [get_bd_addr_segs axi_cdma_0/S_AXI_LITE/Reg] -range 64K -offset 0x00000000
  }
}
