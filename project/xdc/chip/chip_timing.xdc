# ============================================================================
# chip_timing.xdc - DCIM_Array + VPU Chip (lite)
# Target: 250 MHz (4.000 ns), xcvu37p-fsvh2892-2L-e
# ============================================================================
# 分区:
#   Section 1: 时钟定义 & 时钟组
#   Section 2: 复位 false path
#   Section 3: IP 内部 false path (HBM / XDMA-PCIe)
#   Section 4: 多周期路径 (MCP)
#   Section 5: 扇出优化 (MAX_FANOUT)
#   Section 6: Pblock / SLR 分配
# ============================================================================

# ############################################################################
# Section 1: 时钟定义 & 时钟组
# ############################################################################

# clk_main: PCIe UserClk, BUFG_GT 产生, 250 MHz
set _xdc_user_clk_pins [get_pins -quiet -hierarchical \
  -filter {NAME =~ */xdma_0/inst/pcie4_ip_i/inst/*/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O}]
if {[llength $_xdc_user_clk_pins] == 0} {
  set _xdc_user_clk_pins [get_pins -quiet -hierarchical \
    -filter {NAME =~ */xdma_0/*bufg_gt_userclk/O}]
}
if {[llength $_xdc_user_clk_pins]} {
  create_clock -period 4.000 -name clk_main [lindex $_xdc_user_clk_pins 0]
  # UU=25ps: 给 placer 施加额外 setup 压力, 迫使高扇出 data1_reg/s2_reg
  # 与 DSP/product_pipe_reg 紧凑放置。
  # 原 50ps 过大: post-route 全局路径均差 ~60ps，降至 25ps 释放余量。
  set_clock_uncertainty 0.025 [get_clocks clk_main]
}

# clk_main <-> GTYE4_TXOUTCLK: XDMA 内部 CoreClk, 与 UserClk 独立分频,
# IP 内部用 async FIFO 处理 CDC (RQ_FIFO 等), 无用户需保证的时序路径
set _clk_txout [get_clocks -quiet GTYE4_CHANNEL_TXOUTCLK*]
if {[llength $_clk_txout]} {
  set_clock_groups -asynchronous \
    -group [get_clocks clk_main] \
    -group [get_clocks GTYE4_CHANNEL_TXOUTCLK*]
}

# clk_main <-> HBM AXI clock: 独立 MMCM 产生,
# hbm_axi_cc (AXI Clock Converter) 提供完整 CDC 握手
set _clk_hbm_axi [get_clocks -quiet clk_out1_lite_hbm_axi_clk_wiz_0*]
if {[llength $_clk_hbm_axi]} {
  set_clock_groups -asynchronous \
    -group [get_clocks clk_main] \
    -group [get_clocks clk_out1_lite_hbm_axi_clk_wiz_0*]
}

# ############################################################################
# Section 2: 复位 false path
# ############################################################################

# cpu_reset: 板级按键/PCIe hot_reset, 异步输入
if {[llength [get_ports -quiet cpu_reset]]} {
  set_false_path -from [get_ports cpu_reset]
}

# DCIM 异步复位: main_rst -> FDCE/FDPE CLR/PRE
# 仅匹配 FDCE/FDPE 原语, 避免 DSP/BRAM 等原语导致对象数过大 [12-4439]
set _dcim_arst_to [get_pins -quiet -of_objects \
  [get_cells -quiet -hierarchical -filter {
    NAME =~ *dcim_array_0/inst/* && IS_PRIMITIVE &&
    (REF_NAME == FDCE || REF_NAME == FDPE)
  }] -filter {REF_PIN_NAME == CLR || REF_PIN_NAME == PRE}]
if {[llength $_dcim_arst_to]} {
  set_false_path -to $_dcim_arst_to
  puts "INFO: DCIM async reset false_path: [llength $_dcim_arst_to] CLR/PRE pins"
}

# ############################################################################
# Section 3: IP 内部 false path (HBM / XDMA)
# ############################################################################

# HBM WREADY_PIPE: 硬核原语输出 pin, PG276 明确指出 setup 负值属正常,
# AR#73476 建议忽略. 用 -through 因为该 pin 不是 valid startpoint
set _hbm_wready [get_pins -quiet -hierarchical \
  -filter {NAME =~ */hbm_0/inst/*HBM_SNGLBLI_INTF_AXI*/WREADY_PIPE}]
if {[llength $_hbm_wready]} {
  set_false_path -setup -through $_hbm_wready
}

# ############################################################################
# Section 4: 多周期路径 (MCP) — 已全部替换为 pipeline register
# ############################################################################
# 4.1 maArray 计算流水: adderTreePipe 已逐级 pipeline，无需 MCP
# 4.1c/d mergeArray→accumulateArray: postProcess.v 中加 pipe_stage + data reg
# 4.3a ready_r→inst_decoder: DCIM_Array_bd.v 中加 ready_pipe 寄存器
# 4.3b cfg_*→tile FSM: DCIM_Array.sv 中加 cfg_*_r pipeline（与 start_r 对齐）
# 4.4 URAM buffer: XPM READ_LATENCY=10，无需 MCP

# ############################################################################
# Section 5: 扇出优化 (MAX_FANOUT)
# ############################################################################

# maArray counter -> DSP 使能 (跨 SLR 广播)
set _fanout_cnt [get_cells -quiet -hierarchical -filter {NAME =~ */u_maArray/u_counter*/r_cnt_reg*}]
if {[llength $_fanout_cnt]} { set_property MAX_FANOUT 32 $_fanout_cnt }

set _cnt_cfg [get_cells -quiet -hierarchical -filter {NAME =~ */u_maArray/u_counter_cfg/*}]
if {[llength $_cnt_cfg]} { set_property MAX_FANOUT 32 $_cnt_cfg }

# DCIM cfg_start / cfg_* 高扇出
set _cfg_start [get_cells -quiet -hierarchical -filter {NAME =~ *dcim_array_0/inst/cfg_start_reg}]
if {[llength $_cfg_start]} { set_property MAX_FANOUT 16 $_cfg_start }

set _dcim_cfg_regs [get_cells -quiet -hierarchical -filter {NAME =~ *dcim_array_0/inst/cfg_*_reg*}]
if {[llength $_dcim_cfg_regs]} { set_property MAX_FANOUT 16 $_dcim_cfg_regs }

# DQA group_sel (fo=16384, worst path source)
set _dqa_gs [get_cells -quiet -hierarchical -filter {NAME =~ *dqa_inst/dqa_scale_bias_group_sel_reg*}]
if {[llength $_dqa_gs]} { set_property MAX_FANOUT 64 $_dqa_gs }

# pip_data_q_reg: Stage-2 broadcast register (mid_data_q → ppCache, fo=128 per bit)
# RTL already carries (* MAX_FANOUT = 16 *); XDC reinforces placement replication.
# Vivado places 8 copies (ceil(128/16)) near each cacheMem region,
# breaking the long-distance mid_data_q→r_mem route (was 3.824ns in 3cef48c).
# mid_data_q_reg now has fo=1 (only drives pip_data_q), no constraint needed there.
set _pip_data_q [get_cells -quiet -hierarchical -filter {NAME =~ */u_memory/pip_data_q_reg*}]
if {[llength $_pip_data_q]} {
    set_property MAX_FANOUT 16 $_pip_data_q
    puts "INFO: pip_data_q_reg MAX_FANOUT=16: [llength $_pip_data_q] cells"
}

# ############################################################################
# Section 6: Pblock / SLR 分配
# ############################################################################

# ==============================================================================
# Section 6: SLR Pblock 约束（参数化，2+3+3 分布）
# ==============================================================================
# 8 Tiles 分布: SLR0=Tile0,1  SLR1=Tile2,3,4  SLR2=Tile5,6,7
# 改变分布只需修改 slr_map；改变 tile 数只需修改 chip_defines.vh

set slr_map {
  {0 1}
  {2 3 4}
  {5 6 7}
}

foreach slr_idx {0 1 2} {
  set tiles [lindex $slr_map $slr_idx]
  if {[llength $tiles] == 0} continue
  set pblock_name "pblock_tiles_slr${slr_idx}"
  create_pblock $pblock_name
  set pblock_roots {}
  foreach t $tiles {
    # Square brackets in generate-block names are literal hierarchy
    # characters.  The old glob treated them as a character class and matched
    # no cells, leaving all three Tile pblocks empty.  Match the three preserved
    # module roots explicitly with a regexp so adding a root also adds all of
    # its descendants without collecting hundreds of thousands of primitives.
    set tile_roots {}
    foreach tile_inst {u_tile u_tile_ibuf u_tile_obuf} {
      set tile_re [format {^.*/gen_tiles\[%d\]\.%s$} $t $tile_inst]
      set matched [get_cells -quiet -hierarchical -regexp $tile_re]
      if {[llength $matched] != 1} {
        error "Tile $t pblock match failed for $tile_inst: regexp=$tile_re matches=[llength $matched]"
      }
      lappend tile_roots [lindex $matched 0]
    }
    # The AXI BRAM controllers directly drive the Tile IBUF/OBUF URAM address,
    # enable and write pins.  They were previously unconstrained; in a measured
    # route, Tile0's controller landed in SLR1 while its URAM was in SLR0 and
    # created a 2.9 ns route-only path.  Keep both controllers with their Tile.
    foreach ctrl_kind {tile_ibuf_ctrl tile_obuf_ctrl} {
      set ctrl_re [format {^.*/%s_%d$} $ctrl_kind $t]
      set ctrl_match [get_cells -quiet -hierarchical -regexp $ctrl_re]
      if {[llength $ctrl_match] != 1} {
        error "Tile $t $ctrl_kind pblock match failed: regexp=$ctrl_re matches=[llength $ctrl_match]"
      }
      lappend tile_roots [lindex $ctrl_match 0]
      set_property USER_SLR_ASSIGNMENT SLR${slr_idx} [lindex $ctrl_match 0]
    }
    add_cells_to_pblock [get_pblocks $pblock_name] $tile_roots
    set pblock_roots [concat $pblock_roots $tile_roots]
  }
  # Local reset release for all controllers in this SLR.  This replaces the
  # measured 3.2 ns XDMA-reset route across an SLR boundary.
  set rst_re [format {^.*/tile_rst_slr%d$} $slr_idx]
  set rst_match [get_cells -quiet -hierarchical -regexp $rst_re]
  if {[llength $rst_match] != 1} {
    error "SLR$slr_idx Tile reset pblock match failed: regexp=$rst_re matches=[llength $rst_match]"
  }
  add_cells_to_pblock [get_pblocks $pblock_name] [lindex $rst_match 0]
  set_property USER_SLR_ASSIGNMENT SLR${slr_idx} [lindex $rst_match 0]
  lappend pblock_roots [lindex $rst_match 0]
  resize_pblock $pblock_name -add "SLR${slr_idx}"
  set_property IS_SOFT TRUE [get_pblocks $pblock_name]
  puts "INFO: $pblock_name -> SLR${slr_idx} (tiles: $tiles, roots: [llength $pblock_roots])"
}

# AXI 互连 + VPU + INST_Decoder + CDMA + vpu_buf_ctrl -> SLR0 (PCIe 物理引脚在 SLR0)
create_pblock pblock_axi_vpu
foreach _f {
  {NAME =~ lite_i/axi_xdma_smc/*}
  {NAME =~ lite_i/axi_cdma_smc/*}
  {NAME =~ lite_i/axi_misc_smc/*}
  {NAME =~ lite_i/vpu_0/*}
  {NAME =~ lite_i/vpu_buf_ctrl/*}
  {NAME =~ lite_i/axi_cdma_0/*}
  {NAME =~ lite_i/inst_decoder/*}
  {NAME =~ lite_i/cdma_ctrl/*}
  {NAME =~ lite_i/inst_bram/*}
  {NAME =~ lite_i/inst_bram_ctrl/*}
  {NAME =~ lite_i/vpu_wb_ctrl/*}
  {NAME =~ lite_i/vpu_regs/*}
} {
  set _c [get_cells -quiet -hierarchical -filter $_f]
  if {[llength $_c]} { add_cells_to_pblock [get_pblocks pblock_axi_vpu] $_c }
}
resize_pblock [get_pblocks pblock_axi_vpu] -add {SLR0}
set_property IS_SOFT TRUE [get_pblocks pblock_axi_vpu]

# --------------------------------------------------------------------------
# 方案 B: URAM Pblock + VPU 逻辑 Pblock（解决 obuf_din_r → URAM 长距离布线违例）
#
# 问题: obuf_din_r_reg(CR X2Y3) → URAM288_X4Y0(CR X6Y0) 路由 3.579ns, slack=-0.710ns
# 根因: Placer 把 VPU 逻辑放在 SLR0 左侧(CRX2), URAM 散到最右列(CRX6), 对角距离7个CR
#
# VU37P SLR0 URAM 列布局 (from DCP query):
#   X=0 → CRX1 (SLICE 31~56)     X=1 → CRX3 (SLICE 95~116)
#   X=2 → CRX4 (SLICE 117~145)   X=3 → CRX5 (SLICE 146~175)
#   X=4 → CRX6 (SLICE 176~205)   ← 最远, 排除
# SLR0 总 URAM: 5列 × 64 = 320 sites, vpu_buf 需要 256 (80%)
# --------------------------------------------------------------------------

# (B-1) 将 vpu_buf 的 256 个 URAM 约束到 X=0~3（排除最远的 X=4 列/CRX6）
set _vpu_buf_uram [get_cells -quiet -hierarchical \
  -filter {PRIMITIVE_TYPE =~ BLOCKRAM.URAM.* && NAME =~ *u_vpu_buf*}]
if {[llength $_vpu_buf_uram]} {
  create_pblock pblock_vpu_buf_uram
  add_cells_to_pblock [get_pblocks pblock_vpu_buf_uram] $_vpu_buf_uram
  resize_pblock [get_pblocks pblock_vpu_buf_uram] -add {URAM288_X0Y0:URAM288_X3Y63}
  set_property IS_SOFT FALSE [get_pblocks pblock_vpu_buf_uram]
  puts "INFO: pblock_vpu_buf_uram: [llength $_vpu_buf_uram] cells -> URAM288 X0~3, Y0~63"
}

# (B-2) VPU 逻辑 Pblock: 已删除
# 实测 CRX1~X3 导致严重拥挤 (route 后 WNS -2.577ns)，CRX1~X5 仍有风险。
# 仅靠 B-1 排除 URAM X=4(CRX6) 已能将最大 obuf→URAM 距离从 4CR 降到 3CR，
# 配合 phys_opt_design 优化足以收敛（旧 build 差 60ps）。
# 如仍不足，启用方案 C (再加一级 pipeline) 替代。

# 方案B end--------------------------------------------------------------------------


# SLR 分配: 仅约束 VPU/INST 层次 cell 到 SLR0 (PCIe 在此)
# Tile 及其 ibuf/obuf ctrl 的 SLR 分配由上方参数化 Pblock 处理
foreach _cell {lite_i/vpu_0 lite_i/inst_decoder lite_i/cdma_ctrl lite_i/inst_bram} {
  set _c [get_cells -quiet $_cell]
  if {[llength $_c]} { set_property USER_SLR_ASSIGNMENT SLR0 $_c }
}
