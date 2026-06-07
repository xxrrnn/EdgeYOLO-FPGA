# ==============================================================================
# address.tcl - lite version: DCIM + VPU + HBM address map
# ==============================================================================
# 地址空间 (64-bit):
#   0x0_0000_0000 ~ 0x0_FFFF_FFFF  HBM (4GB, interleaved, SAXI_00)
#   0x1_0000_0000 ~ 0x1_001F_FFFF  DCIM IBUF (2MB)
#   0x1_0100_0000 ~ 0x1_01FF_FFFF  DCIM OBUF (16MB, feature buffer)
#   0x1_0200_0000 ~ 0x1_0207_FFFF  VPU WB (32KB)
#   0x1_0300_0000 ~ 0x1_031F_FFFF  INST_BRAM (128KB)
#   0x1_0400_0000 ~ 0x1_0400_0FFF  VPU_AXI_Regs (4KB)
#
# CDMA 可访问: HBM + DCIM IBUF/OBUF + VPU WB
# XDMA 可访问: 上述全部
# ==============================================================================

# ==============================================================================
# Step 1: auto-assign — Vivado 自动分配（布局不可预测，取决于 IP 数量/类型）
# ==============================================================================
assign_bd_address

# ==============================================================================
# Helper: 找到 seg（先找已分配，再找 excluded），设置 offset/range
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
# XDMA M_AXI 两阶段搬移:
#   Phase 1: 全部移到高位临时区（0x1_E000_0000 起），消除 auto-assign 冲突
#   Phase 2: 从临时区移到最终地址
#
#   最终目标:
#     ibuf          @ 0x1_0000_0000 (2MB)
#     obuf          @ 0x1_0100_0000 (16MB)
#     wb            @ 0x1_0200_0000 (32KB)
#     inst_bram_ctrl@ 0x1_0300_0000 (128KB)
#     vpu_regs      @ 0x1_0400_0000 (4KB)
# ==============================================================================
# Phase 1: 全部搬到临时高位（互不重叠）
mv "xdma_0/M_AXI/SEG_dcim_ibuf_ctrl_0_Mem0"  0x1E0000000  2M
mv "xdma_0/M_AXI/SEG_dcim_obuf_ctrl_0_Mem0"  0x1E2000000  16M
mv "xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0"       0x1F0000000  32K
mv "xdma_0/M_AXI/SEG_inst_bram_ctrl_Mem0"    0x1F2000000  128K
mv "xdma_0/M_AXI/SEG_vpu_regs_reg0"          0x1F4000000  4K

# Phase 2: 从临时区移到最终目标地址
mv "xdma_0/M_AXI/SEG_dcim_ibuf_ctrl_0_Mem0"  0x100000000  2M
mv "xdma_0/M_AXI/SEG_dcim_obuf_ctrl_0_Mem0"  0x101000000  16M
mv "xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0"       0x102000000  32K
mv "xdma_0/M_AXI/SEG_inst_bram_ctrl_Mem0"    0x103000000  128K
mv "xdma_0/M_AXI/SEG_vpu_regs_reg0"          0x104000000  4K

# ==============================================================================
# CDMA M_AXI Data: ibuf/obuf/wb (vpu_regs 是 reg 类型会被 exclude)
# inst_bram_ctrl 是 Mem 类型可能被 auto-assign，CDMA 不需要访问它，exclude 掉
# ==============================================================================
# Exclude inst_bram_ctrl from CDMA address space (CDMA only needs ibuf/obuf/wb)
set _cdma_inst_seg [get_bd_addr_segs -quiet "axi_cdma_0/Data/SEG_inst_bram_ctrl_Mem0"]
if {[llength $_cdma_inst_seg]} {
  exclude_bd_addr_seg $_cdma_inst_seg
  puts "INFO: Excluded inst_bram_ctrl from CDMA address space"
}

# Phase 1: 临时高位
mv "axi_cdma_0/Data/SEG_dcim_ibuf_ctrl_0_Mem0"  0x1E0000000  2M
mv "axi_cdma_0/Data/SEG_dcim_obuf_ctrl_0_Mem0"  0x1E2000000  16M
mv "axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0"       0x1F0000000  32K

# Phase 2: 最终地址（与 XDMA 一致）
mv "axi_cdma_0/Data/SEG_dcim_ibuf_ctrl_0_Mem0"  0x100000000  2M
mv "axi_cdma_0/Data/SEG_dcim_obuf_ctrl_0_Mem0"  0x101000000  16M
mv "axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0"       0x102000000  32K

# ==============================================================================
# HBM @ 0x0_0000_0000 (4GB)
# interleave 产生 HBM_MEM00~15 (各 256MB)；保留 MEM00 改 4GB，exclude 其余
# ==============================================================================
proc fix_hbm {master_prefix} {
  # 已分配的 HBM segs
  set assigned [get_bd_addr_segs -quiet "${master_prefix}/SEG_hbm_0_*"]
  # excluded 的 HBM segs
  set excluded_segs [get_bd_addr_segs -quiet -excluded "${master_prefix}/SEG_hbm_0_*"]

  # 第一步：把除 MEM00 以外的所有 assigned HBM seg 先 exclude 掉
  set anchor ""
  foreach seg $assigned {
    if {[string match "*HBM_MEM00*" $seg]} {
      set anchor $seg
    } else {
      catch { exclude_bd_addr_seg $seg }
      puts "INFO: HBM excl $seg"
    }
  }
  # excluded 列表里的也保持 exclude（通常已经是了）

  # 第二步：把 anchor (MEM00) 改为 4GB
  if {$anchor ne ""} {
    set_property range  4G         $anchor
    set_property offset 0x000000000 $anchor
    puts "INFO: HBM keep $anchor -> 0x0_0000_0000 (4G)"
  } else {
    # 如果 MEM00 还在 excluded 里，include 后设置
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
# 段名可能是 SEG_axi_cdma_0_Reg 或 SEG_axi_cdma_0_Reg0，尝试两种
set _cdma_lite_seg [get_bd_addr_segs -quiet "cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg"]
if {[llength $_cdma_lite_seg] == 0} {
  set _cdma_lite_seg [get_bd_addr_segs -quiet -excluded "cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg"]
  if {[llength $_cdma_lite_seg]} { include_bd_addr_seg [lindex $_cdma_lite_seg 0] }
}
if {[llength $_cdma_lite_seg] == 0} {
  # 尝试通配符查找
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
  puts "WARNING: CDMA AXI-Lite segment not found — may need assign_bd_address for cdma_ctrl"
  # 手动分配
  catch {
    assign_bd_address -target_address_space cdma_ctrl/cdma_axilm \
      [get_bd_addr_segs axi_cdma_0/S_AXI_LITE/Reg] -range 64K -offset 0x00000000
    puts "INFO: Manually assigned CDMA AXI-Lite @ 0x0 (64K)"
  }
}
