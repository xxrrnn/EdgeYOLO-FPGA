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
# Step 1: auto-assign — Vivado 固定分配结果 (XDMA):
#   inst_bram  @ 0x1_0000_0000 [128K]
#   vpu_regs   @ 0x1_0002_0000 [4K]
#   ibuf       @ 0x1_0200_0000 [16K]
#   obuf       @ 0x1_0400_0000 [16K]
#   wb         @ 0x1_0600_0000 [16K]
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
# XDMA M_AXI 无冲突搬移 (7步):
#   初始: inst_bram@0x1_0000 vpu_regs@0x1_0002 ibuf@0x1_0200 obuf@0x1_0400 wb@0x1_0600
#   目标: ibuf@0x1_0000 obuf@0x1_0100 wb@0x1_0200 inst_bram@0x1_0300 vpu_regs@0x1_0400
# ==============================================================================
# 1. obuf 0x1_0400 → 0x1_0800 (临时)
mv "xdma_0/M_AXI/SEG_dcim_obuf_ctrl_0_Mem0"  0x108000000  16M
# 2. vpu_regs 0x1_0002 → 0x1_0400 (obuf 已让出)
mv "xdma_0/M_AXI/SEG_vpu_regs_reg0"          0x104000000  4K
# 3. ibuf 0x1_0200 → 0x1_0700 (临时)
mv "xdma_0/M_AXI/SEG_dcim_ibuf_ctrl_0_Mem0"  0x107000000  2M
# 4. inst_bram 0x1_0000 → 0x1_0300
mv "xdma_0/M_AXI/SEG_inst_bram_reg0"         0x103000000  128K
# 5. wb 0x1_0600 → 0x1_0200
mv "xdma_0/M_AXI/SEG_vpu_wb_ctrl_Mem0"       0x102000000  32K
# 6. ibuf 0x1_0700 → 0x1_0000 (inst_bram 已让出)
mv "xdma_0/M_AXI/SEG_dcim_ibuf_ctrl_0_Mem0"  0x100000000  2M
# 7. obuf 0x1_0800 → 0x1_0100
mv "xdma_0/M_AXI/SEG_dcim_obuf_ctrl_0_Mem0"  0x101000000  16M

# ==============================================================================
# CDMA M_AXI Data (不含 inst_bram/vpu_regs, 它们是 reg 类型被自动 exclude)
# CDMA auto-assign:
#   ibuf @ 0x1_0200_0000, obuf @ 0x1_0400_0000, wb @ 0x1_0600_0000
# ==============================================================================
mv "axi_cdma_0/Data/SEG_dcim_obuf_ctrl_0_Mem0" 0x108000000  16M
mv "axi_cdma_0/Data/SEG_dcim_ibuf_ctrl_0_Mem0" 0x107000000  2M
mv "axi_cdma_0/Data/SEG_vpu_wb_ctrl_Mem0"       0x102000000  32K
mv "axi_cdma_0/Data/SEG_dcim_ibuf_ctrl_0_Mem0"  0x100000000  2M
mv "axi_cdma_0/Data/SEG_dcim_obuf_ctrl_0_Mem0"  0x101000000  16M

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
mv "cdma_ctrl/cdma_axilm/SEG_axi_cdma_0_Reg" 0x00000000 64K
