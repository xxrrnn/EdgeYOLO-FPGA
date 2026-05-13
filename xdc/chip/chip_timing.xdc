# ============================================================================
# DCIM Array Chip - 时序和物理约束
# 目标频率: 250 MHz
# ============================================================================

# 时钟约束
create_clock -period 4.000 -name clk_main [get_pins dcim_array_chip_i/xdma_0/inst/pcie4_ip_i/inst/dcim_array_chip_xdma_0_0_pcie4_ip_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O]

# 时钟不确定度
set_clock_uncertainty 0.100 [get_clocks clk_main]

# ============================================================================
# False Path 设置
# ============================================================================

# 跨时钟域的 done/ready 信号为准静态信号
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *tile_done*}] -to [get_pins -hierarchical -filter {NAME =~ *done_reg*}]
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *tile_ready*}] -to [get_pins -hierarchical -filter {NAME =~ *ready_reg*}]

# 复位信号
set_false_path -from [get_ports cpu_reset]

# ============================================================================
# Pblock 物理约束 - 将 Tile 分组放置以减少布线延迟
# ============================================================================

# 为 16 个 Tile 创建 4 组 Pblock，每组 4 个 Tile
# VCU37P 有 3 个 SLR，我们将 Tile 分散到不同 SLR 以平衡资源

# SLR0: Tile 0-3
create_pblock pblock_tiles_0_3
add_cells_to_pblock [get_pblocks pblock_tiles_0_3] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[0].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_0_3] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[1].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_0_3] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[2].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_0_3] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[3].u_tile}]
resize_pblock [get_pblocks pblock_tiles_0_3] -add {CLOCKREGION_X0Y0:CLOCKREGION_X3Y4}

# SLR0-SLR1: Tile 4-7
create_pblock pblock_tiles_4_7
add_cells_to_pblock [get_pblocks pblock_tiles_4_7] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[4].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_4_7] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[5].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_4_7] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[6].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_4_7] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[7].u_tile}]
resize_pblock [get_pblocks pblock_tiles_4_7] -add {CLOCKREGION_X4Y0:CLOCKREGION_X7Y4}

# SLR1: Tile 8-11
create_pblock pblock_tiles_8_11
add_cells_to_pblock [get_pblocks pblock_tiles_8_11] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[8].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_8_11] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[9].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_8_11] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[10].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_8_11] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[11].u_tile}]
resize_pblock [get_pblocks pblock_tiles_8_11] -add {CLOCKREGION_X0Y5:CLOCKREGION_X3Y9}

# SLR1-SLR2: Tile 12-15
create_pblock pblock_tiles_12_15
add_cells_to_pblock [get_pblocks pblock_tiles_12_15] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[12].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_12_15] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[13].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_12_15] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[14].u_tile}]
add_cells_to_pblock [get_pblocks pblock_tiles_12_15] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/gen_tiles[15].u_tile}]
resize_pblock [get_pblocks pblock_tiles_12_15] -add {CLOCKREGION_X4Y5:CLOCKREGION_X7Y9}

# ============================================================================
# 仲裁器的 Pblock - 放置在中央位置
# ============================================================================

create_pblock pblock_ibuf_arbiter
add_cells_to_pblock [get_pblocks pblock_ibuf_arbiter] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/u_ibuf_arb}]
resize_pblock [get_pblocks pblock_ibuf_arbiter] -add {CLOCKREGION_X2Y5:CLOCKREGION_X3Y5}

create_pblock pblock_obuf_arbiter
add_cells_to_pblock [get_pblocks pblock_obuf_arbiter] [get_cells -hierarchical -filter {NAME =~ dcim_array_chip_i/dcim_array_0/inst/u_top/u_dcim_array/u_obuf_arb}]
resize_pblock [get_pblocks pblock_obuf_arbiter] -add {CLOCKREGION_X4Y5:CLOCKREGION_X5Y5}

# ============================================================================
# 时序优化指令
# ============================================================================

# 激进的时序优化策略
set_property STRATEGY Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

# 提高布局布线优化等级
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

# 启用所有后布线优化
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# ============================================================================
# 多周期路径设置 (如果需要)
# ============================================================================

# Arbiter 仲裁逻辑可以放宽 1 周期
set_multicycle_path -setup 2 -from [get_pins -hierarchical -filter {NAME =~ *u_ibuf_arb/tile_rd_valid_q*}] -to [get_pins -hierarchical -filter {NAME =~ *u_ibuf_arb/grant_idx*}]
set_multicycle_path -hold 1 -from [get_pins -hierarchical -filter {NAME =~ *u_ibuf_arb/tile_rd_valid_q*}] -to [get_pins -hierarchical -filter {NAME =~ *u_ibuf_arb/grant_idx*}]

set_multicycle_path -setup 2 -from [get_pins -hierarchical -filter {NAME =~ *u_obuf_arb/tile_wr_valid_q*}] -to [get_pins -hierarchical -filter {NAME =~ *u_obuf_arb/grant_idx*}]
set_multicycle_path -hold 1 -from [get_pins -hierarchical -filter {NAME =~ *u_obuf_arb/tile_wr_valid_q*}] -to [get_pins -hierarchical -filter {NAME =~ *u_obuf_arb/grant_idx*}]
