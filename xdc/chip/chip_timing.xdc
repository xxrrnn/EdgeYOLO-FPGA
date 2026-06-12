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
  # UU=50ps: 给 placer 施加额外 setup 压力, 迫使高扇出 data1_reg/s2_reg
  # 与 DSP/product_pipe_reg 紧凑放置, 否则路由延迟从 ~2ns 爆增到 ~4ns.
  # 副作用: DSP 内部路径出现微小 hold violation (~-0.011ns),
  # 由 3_synth.tcl 中 phys_opt_design -hold 修复.
  set_clock_uncertainty 0.050 [get_clocks clk_main]
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
# Section 4: 多周期路径 (MCP)
# ############################################################################

# --- 4.1 DCIM maArray 计算流水 MCP ---
# maSubcolumn -> ma_pipe 流水寄存器 (DSP/LUT 两种映射均覆盖)
set _mcp_sub_from [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*}]
set _mcp_sub_to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/gen_ma_pipe.r_ma_pipe*}]
if {[llength $_mcp_sub_from] && [llength $_mcp_sub_to]} {
  set_multicycle_path -setup 2 -from $_mcp_sub_from -to $_mcp_sub_to
  set_multicycle_path -hold 1 -from $_mcp_sub_from -to $_mcp_sub_to
}

# adderTree carry -> result_reg
set _mcp_carry [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/u_adderTree/*carry*/CO[*]}]
set _mcp_res_d [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/result_reg*/D}]
if {[llength $_mcp_carry] && [llength $_mcp_res_d]} {
  set_multicycle_path -setup 2 -from $_mcp_carry -to $_mcp_res_d
  set_multicycle_path -hold 1  -from $_mcp_carry -to $_mcp_res_d
}

# mergeArray -> accumulateArray -> postProcess
set _merge_cells [get_cells -quiet -hierarchical -filter {NAME =~ *u_mergeArray/*}]
set _accum_cells [get_cells -quiet -hierarchical -filter {NAME =~ *u_accumulateArray/*}]
set _post_cells  [get_cells -quiet -hierarchical -filter {NAME =~ *u_postProcess/*}]
if {[llength $_merge_cells] && [llength $_accum_cells]} {
  set_multicycle_path -setup 2 -from $_merge_cells -to $_accum_cells
  set_multicycle_path -hold 1  -from $_merge_cells -to $_accum_cells
}
if {[llength $_accum_cells] && [llength $_post_cells]} {
  set_multicycle_path -setup 2 -from $_accum_cells -to $_post_cells
  set_multicycle_path -hold 1  -from $_accum_cells -to $_post_cells
}

# --- 4.2 DCIM Arbiter MCP ---
# IBUF arbiter
set _mcp_ib_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_ibuf_arb/tile_rd_valid_q*}]
set _mcp_ib_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_ibuf_arb/grant_idx*}]
if {[llength $_mcp_ib_from] && [llength $_mcp_ib_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ib_from -to $_mcp_ib_to
  set_multicycle_path -hold 1 -from $_mcp_ib_from -to $_mcp_ib_to
}

# OBUF arbiter: 已删除 (chip-v2: tile 直写 tile_obuf，无仲裁器)

# --- 4.3 SLR 穿越流水 MCP ---
# ready_r -> inst_decoder FSM
set _mcp_ready_r_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/ready_r_reg/C}]
set _mcp_ready_r_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ *inst_decoder*/FSM_onehot_state_reg*/CE ||
           NAME =~ *inst_decoder*/FSM_onehot_state_reg*/D  ||
           NAME =~ *inst_decoder*/dcim_layer_seen_busy_reg*/D}]
if {[llength $_mcp_ready_r_from] && [llength $_mcp_ready_r_to]} {
  set_multicycle_path 2 -setup -from $_mcp_ready_r_from -to $_mcp_ready_r_to
  set_multicycle_path 1 -hold  -from $_mcp_ready_r_from -to $_mcp_ready_r_to
}

# start_r -> tile FSM
set _mcp_start_r_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/start_r_reg/C}]
set _mcp_start_r_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/FSM_onehot_state_reg*/CE ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/*state_reg*/CE           ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/*state_reg*/D}]
if {[llength $_mcp_start_r_from] && [llength $_mcp_start_r_to]} {
  set_multicycle_path 2 -setup -from $_mcp_start_r_from -to $_mcp_start_r_to
  set_multicycle_path 1 -hold  -from $_mcp_start_r_from -to $_mcp_start_r_to
}

# cfg_* -> tile FSM (配置寄存器在 FSM 启动前已稳定)
set _mcp_cfg_from [get_cells -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/cfg_*_reg*}]
set _mcp_fsm_ce_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/FSM_onehot_state_reg*/CE ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/FSM_onehot_state_reg*/D  ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/*state_reg*/CE}]
if {[llength $_mcp_cfg_from] && [llength $_mcp_fsm_ce_to]} {
  set_multicycle_path 2 -setup -from $_mcp_cfg_from -to $_mcp_fsm_ce_to
  set_multicycle_path 1 -hold  -from $_mcp_cfg_from -to $_mcp_fsm_ce_to
}

# --- 4.4 IBUF URAM 延迟 MCP ---
# chip-v2: 共享 OBUF 已删除，tile_obuf 同 SLR 无跨越，cascade=2 不需要 MCP
# 仅保留 IBUF MCP（cascade 较深，仍需要）
set _buf_mcp_setup 4

# IBUF 写侧寄存器 -> URAM
set _ibuf_lat_src {}
foreach _f {
  {NAME =~ *u_ibuf*gen_banks*wea_reg2*}
  {NAME =~ *u_ibuf*gen_banks*web_reg2*}
  {NAME =~ *u_ibuf*gen_banks*mem_ena_reg2*}
  {NAME =~ *u_ibuf*gen_banks*mem_enb_reg2*}
  {NAME =~ *u_ibuf*gen_banks*dina_reg2*}
  {NAME =~ *u_ibuf*gen_banks*dinb_reg2*}
  {NAME =~ *u_ibuf*gen_banks*addra_reg2*}
  {NAME =~ *u_ibuf*gen_banks*addrb_reg2*}
  {NAME =~ *u_ibuf/wea_reg*}
  {NAME =~ *u_ibuf/web_reg*}
} {
  set _c [get_cells -quiet -hierarchical -filter $_f]
  if {[llength $_c]} { set _ibuf_lat_src [concat $_ibuf_lat_src $_c] }
}
set _ibuf_uram [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_reg_uram*}]
if {[llength $_ibuf_lat_src] && [llength $_ibuf_uram]} {
  set_multicycle_path -setup $_buf_mcp_setup -from $_ibuf_lat_src -to $_ibuf_uram
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -from $_ibuf_lat_src -to $_ibuf_uram
}

# IBUF URAM cascade 读路径
set _ibuf_memreg   [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*memreg*_reg*}]
set _ibuf_rstage   [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_rstage_reg*_reg*}]
set _ibuf_pipe_dst [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_pipe_reg*_reg*}]
if {[llength $_ibuf_uram] && [llength $_ibuf_memreg]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_ibuf_uram -to $_ibuf_memreg
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_ibuf_uram -to $_ibuf_memreg
}
if {[llength $_ibuf_uram] && [llength $_ibuf_rstage]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_ibuf_uram -to $_ibuf_rstage
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_ibuf_uram -to $_ibuf_rstage
}
if {[llength $_ibuf_memreg] && [llength $_ibuf_rstage]} {
  set_multicycle_path -setup 2 -from $_ibuf_memreg -to $_ibuf_rstage
  set_multicycle_path -hold 1 -from $_ibuf_memreg -to $_ibuf_rstage
}
if {[llength $_ibuf_rstage] && [llength $_ibuf_pipe_dst]} {
  set_multicycle_path -setup 1 -from $_ibuf_rstage -to $_ibuf_pipe_dst
  set_multicycle_path -hold 0 -from $_ibuf_rstage -to $_ibuf_pipe_dst
}
if {[llength $_ibuf_uram] && [llength $_ibuf_pipe_dst]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_ibuf_uram -to $_ibuf_pipe_dst
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_ibuf_uram -to $_ibuf_pipe_dst
}

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

# ############################################################################
# Section 6: Pblock / SLR 分配
# ############################################################################

# Tile 0 -> SLR0
set _tile0 [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[0].*}]
if {[llength $_tile0]} {
  create_pblock pblock_tile_0
  add_cells_to_pblock [get_pblocks pblock_tile_0] $_tile0
  resize_pblock [get_pblocks pblock_tile_0] -add {SLR0}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_0]
}

# Tile 1 + 2 -> SLR1
set _tile12 {}
foreach _f {
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[1].*}
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[2].*}
} {
  set _c [get_cells -quiet -hierarchical -filter $_f]
  if {[llength $_c]} { set _tile12 [concat $_tile12 $_c] }
}
if {[llength $_tile12]} {
  create_pblock pblock_tile_12
  add_cells_to_pblock [get_pblocks pblock_tile_12] $_tile12
  resize_pblock [get_pblocks pblock_tile_12] -add {SLR1}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_12]
}

# Tile 3 -> SLR2
set _tile3 [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[3].*}]
if {[llength $_tile3]} {
  create_pblock pblock_tile_3
  add_cells_to_pblock [get_pblocks pblock_tile_3] $_tile3
  resize_pblock [get_pblocks pblock_tile_3] -add {SLR2}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_3]
}

# IBUF arbiter -> SLR1 (居中)
set _c [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_dcim_array/u_ibuf_arb}]
if {[llength $_c]} { set_property USER_SLR_ASSIGNMENT SLR1 $_c }

# IBUF -> SLR0 (靠近 XDMA AXI 写通路)
set _ibuf_top [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_dcim_array/u_ibuf}]
if {[llength $_ibuf_top]} {
  create_pblock pblock_ibuf
  add_cells_to_pblock [get_pblocks pblock_ibuf] $_ibuf_top
  resize_pblock [get_pblocks pblock_ibuf] -add {SLR0}
  set_property IS_SOFT TRUE [get_pblocks pblock_ibuf]
}

# AXI 互连 + VPU + INST_Decoder + CDMA -> SLR0
create_pblock pblock_axi_vpu
foreach _f {
  {NAME =~ lite_i/axi_mem_smc/*}
  {NAME =~ lite_i/vpu_0/*}
  {NAME =~ lite_i/axi_cdma_0/*}
  {NAME =~ lite_i/inst_decoder/*}
  {NAME =~ lite_i/cdma_ctrl/*}
  {NAME =~ lite_i/inst_bram/*}
} {
  set _c [get_cells -quiet -hierarchical -filter $_f]
  if {[llength $_c]} { add_cells_to_pblock [get_pblocks pblock_axi_vpu] $_c }
}
resize_pblock [get_pblocks pblock_axi_vpu] -add {SLR0}
set_property IS_SOFT TRUE [get_pblocks pblock_axi_vpu]

# SLR 分配 (层次 cell)
foreach _cell {lite_i/vpu_0 lite_i/inst_decoder lite_i/cdma_ctrl lite_i/inst_bram} {
  set _c [get_cells -quiet $_cell]
  if {[llength $_c]} { set_property USER_SLR_ASSIGNMENT SLR0 $_c }
}
