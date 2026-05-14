# ============================================================================
# DCIM Array Chip - 时序和物理约束
# 目标频率: 250 MHz
#
# 架构: 8 组 × 8 Tile/组 = 64 Tile
# 每组独立的 IBUF + OBUF，便于 SLR 约束
#
# 顶层为 chip_wrapper（见 scripts/chip/config.tcl）；层级前缀为 chip_wrapper_i。
# ============================================================================

# ============================================================================
# DSP 资源约束：避免 DSP 超标，使用 LUT 实现部分乘法器
# ============================================================================
# xcvu37p 有 5952 个 DSP48E2，64 Tile 需要 16384 个 DSP
# 通过 USE_DSP 属性让小乘法器用 LUT 实现，大乘法器（如 MAC）用 DSP

# 全局设置：优先使用 LUT 实现乘法器（除非明确标记 use_dsp="yes"）
set_property USE_DSP no [get_cells -quiet -hierarchical -filter {REF_NAME =~ "*mult*" || ORIG_REF_NAME =~ "*mult*"}]

# 保留 DCIM MAC 单元使用 DSP（这是性能关键路径）
set_property USE_DSP yes [get_cells -quiet -hierarchical -filter {NAME =~ */u_dcim/u_arrayTop/*mac* || NAME =~ */u_dcim/u_arrayTop/*mult* || NAME =~ */u_dcim/u_arrayTop/*acc*}]

# 时钟约束：XDMA PCIe user clock（BUFG_GT 输出）
set _xdc_user_clk_pins [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4_ip_i/inst/*/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O}]
if {[llength $_xdc_user_clk_pins] == 0} {
  set _xdc_user_clk_pins [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/*bufg_gt_userclk/O}]
}
if {[llength $_xdc_user_clk_pins]} {
  create_clock -period 4.000 -name clk_main [lindex $_xdc_user_clk_pins 0]
  set_clock_uncertainty 0.100 [get_clocks clk_main]
}

# ============================================================================
# False Path 设置
# ============================================================================

# 跨时钟域的 done/ready
set _fp_from_done [get_pins -quiet -hierarchical -filter {NAME =~ *group_done*}]
set _fp_to_done   [get_pins -quiet -hierarchical -filter {NAME =~ *done_reg*}]
if {[llength $_fp_from_done] && [llength $_fp_to_done]} {
  set_false_path -from $_fp_from_done -to $_fp_to_done
}
set _fp_from_rdy [get_pins -quiet -hierarchical -filter {NAME =~ *group_ready*}]
set _fp_to_rdy   [get_pins -quiet -hierarchical -filter {NAME =~ *ready_reg*}]
if {[llength $_fp_from_rdy] && [llength $_fp_to_rdy]} {
  set_false_path -from $_fp_from_rdy -to $_fp_to_rdy
}

# 复位
if {[llength [get_ports -quiet cpu_reset]]} {
  set_false_path -from [get_ports cpu_reset]
}

# ============================================================================
# SLR Pblock 约束 - 8 组分配到 3 个 SLR
# ============================================================================
# VCU37P/VU9P 有 3 个 SLR:
#   SLR0: Y0-Y4   (底部)
#   SLR1: Y5-Y9   (中间)
#   SLR2: Y10-Y14 (顶部)
#
# 分配策略:
#   SLR0: Group 0, 1, 2 (3 组, 24 Tile)
#   SLR1: Group 3, 4    (2 组, 16 Tile)
#   SLR2: Group 5, 6, 7 (3 组, 24 Tile)
# ============================================================================

# --- SLR0: Group 0, 1, 2 ---

create_pblock pblock_group_0
add_cells_to_pblock [get_pblocks pblock_group_0] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[0\].u_group}]
resize_pblock [get_pblocks pblock_group_0] -add {CLOCKREGION_X0Y0:CLOCKREGION_X2Y4}

create_pblock pblock_group_1
add_cells_to_pblock [get_pblocks pblock_group_1] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[1\].u_group}]
resize_pblock [get_pblocks pblock_group_1] -add {CLOCKREGION_X3Y0:CLOCKREGION_X5Y4}

create_pblock pblock_group_2
add_cells_to_pblock [get_pblocks pblock_group_2] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[2\].u_group}]
resize_pblock [get_pblocks pblock_group_2] -add {CLOCKREGION_X6Y0:CLOCKREGION_X7Y4}

# --- SLR1: Group 3, 4 ---

create_pblock pblock_group_3
add_cells_to_pblock [get_pblocks pblock_group_3] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[3\].u_group}]
resize_pblock [get_pblocks pblock_group_3] -add {CLOCKREGION_X0Y5:CLOCKREGION_X3Y9}

create_pblock pblock_group_4
add_cells_to_pblock [get_pblocks pblock_group_4] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[4\].u_group}]
resize_pblock [get_pblocks pblock_group_4] -add {CLOCKREGION_X4Y5:CLOCKREGION_X7Y9}

# --- SLR2: Group 5, 6, 7 ---

create_pblock pblock_group_5
add_cells_to_pblock [get_pblocks pblock_group_5] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[5\].u_group}]
resize_pblock [get_pblocks pblock_group_5] -add {CLOCKREGION_X0Y10:CLOCKREGION_X2Y14}

create_pblock pblock_group_6
add_cells_to_pblock [get_pblocks pblock_group_6] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[6\].u_group}]
resize_pblock [get_pblocks pblock_group_6] -add {CLOCKREGION_X3Y10:CLOCKREGION_X5Y14}

create_pblock pblock_group_7
add_cells_to_pblock [get_pblocks pblock_group_7] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[7\].u_group}]
resize_pblock [get_pblocks pblock_group_7] -add {CLOCKREGION_X6Y10:CLOCKREGION_X7Y14}

# ============================================================================
# 多周期路径设置
# ============================================================================

# Arbiter 仲裁逻辑可以放宽 1 周期
# 每组都有独立的 arbiter，使用通配符匹配所有组
set _mcp_ib_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_ibuf_arb/tile_rd_valid_q*}]
set _mcp_ib_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_ibuf_arb/grant_idx*}]
if {[llength $_mcp_ib_from] && [llength $_mcp_ib_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ib_from -to $_mcp_ib_to
  set_multicycle_path -hold 1 -from $_mcp_ib_from -to $_mcp_ib_to
}

set _mcp_ob_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_obuf_arb/tile_wr_valid_q*}]
set _mcp_ob_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_obuf_arb/grant_idx*}]
if {[llength $_mcp_ob_from] && [llength $_mcp_ob_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_from -to $_mcp_ob_to
  set_multicycle_path -hold 1 -from $_mcp_ob_from -to $_mcp_ob_to
}

# ============================================================================
# maArray 乘加流水多周期路径约束
# ============================================================================

# 从 multiplier DSP 输出到 maArray 流水寄存器
set _mcp_ma_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/MultiplierChannels*/u_multiplier/prod_full*/P[*]}]
set _mcp_ma_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/gen_ma_pipe.r_ma_pipe*/D}]
if {[llength $_mcp_ma_from] && [llength $_mcp_ma_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ma_from -to $_mcp_ma_to
  set_multicycle_path -hold 1 -from $_mcp_ma_from -to $_mcp_ma_to
}

# 从 adderTree CARRY8 输出到 maArray 流水寄存器
set _mcp_at_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/u_adderTree/*carry*/CO[*]}]
set _mcp_at_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/gen_ma_pipe.r_ma_pipe*/D}]
if {[llength $_mcp_at_from] && [llength $_mcp_at_to]} {
  set_multicycle_path -setup 2 -from $_mcp_at_from -to $_mcp_at_to
  set_multicycle_path -hold 1 -from $_mcp_at_from -to $_mcp_at_to
}

# 备用：更宽泛的匹配
set _mcp_sub_from [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*}]
set _mcp_sub_to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/gen_ma_pipe.r_ma_pipe*}]
if {[llength $_mcp_sub_from] && [llength $_mcp_sub_to]} {
  set_multicycle_path -setup 2 -from $_mcp_sub_from -to $_mcp_sub_to
  set_multicycle_path -hold 1 -from $_mcp_sub_from -to $_mcp_sub_to
}

# ============================================================================
# SLR 边界寄存器约束
# ============================================================================
# 确保跨 SLR 的路径使用 SLR 边界寄存器
# 这些约束帮助工具在 SLR 边界自动插入寄存器

set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[0\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[1\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[2\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[3\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR1 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[4\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[5\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[6\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR2 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[7\].u_group*}]
