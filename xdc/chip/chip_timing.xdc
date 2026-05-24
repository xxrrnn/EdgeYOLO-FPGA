# ============================================================================
# DCIM_Array + VPU Chip (lite) - Timing and Physical Constraints
# Target: 250 MHz (4.000 ns) on xcvu37p-fsvh2892-2L-e
# Memory: XDMA only (HBM removed in lite version)
# ============================================================================

# ============================================================================
# DSP 资源约束
# ============================================================================
# multiplier.v 已设置 (* use_dsp = "no" *)，4-bit 乘法全部用 LUT 实现。
# xcvu37p 有 9024 个 DSP，LUT 方式 DSP 降至约 49（仅 VPU FP MAC），完全不超标。
# 注：VU37P 有 2.7M LUT，额外 ~18K LUT 对利用率影响极小。

# ============================================================================
# 时钟约束
# ============================================================================
set _xdc_user_clk_pins [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4_ip_i/inst/*/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O}]
if {[llength $_xdc_user_clk_pins] == 0} {
  set _xdc_user_clk_pins [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/*bufg_gt_userclk/O}]
}
if {[llength $_xdc_user_clk_pins]} {
  create_clock -period 4.000 -name clk_main [lindex $_xdc_user_clk_pins 0]
  set_clock_uncertainty 0.050 [get_clocks clk_main]
}

# (HBM clocks removed in lite version - single clock domain)

# ============================================================================
# 复位约束
# ============================================================================
if {[llength [get_ports -quiet cpu_reset]]} {
  set_false_path -from [get_ports cpu_reset]
}

# DCIM 异步复位
set _dcim_async_rst [get_pins -quiet -hierarchical -filter {NAME =~ *dcim_array_0/inst/u_top/u_dcim_array/*/CLR}]
if {[llength $_dcim_async_rst]} {
  set_false_path -to $_dcim_async_rst
}

# XDMA user_reset → BRAM reset ports
set_false_path -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
               -to [get_pins -quiet -hierarchical -filter {NAME =~ */*bram*/RSTREG*}]
set_false_path -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
               -to [get_pins -quiet -hierarchical -filter {NAME =~ */*bram*/RSTRAM*}]
set_false_path -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/*/user_reset*}] \
               -to [get_pins -quiet -hierarchical -filter {NAME =~ */inst_bram/*}]

# PCIe GT DRP hold path
set_false_path -hold \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/*/gen_cpll_cal*/gtwizard_ultrascale*drp_arb_i/*/C}] \
  -to [get_pins -quiet -hierarchical -filter {NAME =~ */GTYE4_CHANNEL_PRIM_INST/DRP*}]

# PCIe PIPE interface hold
set_false_path -hold \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */phy_pipeline/*/ff_chain_reg*/C}] \
  -to [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/PIPETX*}]

# PCIe BRAM → PCIE4CE4 hold
set_false_path -hold \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_0_bram_inst/*/reg_rdata*_reg*/C}] \
  -to [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/MIRX*}]

# PCIe BRAM read pipeline setup: RAMB36E2 → reg_rdata1_reg
set_false_path -setup \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_0_bram_inst/*/RAMB36E2*/CLKARDCLK}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_0_bram_inst/*/FRMRDPIPELINE.reg_rdata*_reg*/D}]

# PCIe seqnum FIFO CDC (write_addr → write_addr_read_clk, async crossing)
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */seqnum_fifo*/write_addr_reg*/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */seqnum_fifo*/write_addr_read_clk_reg*/D}]

# PCIe GT reset chain (rst_psrst_n_r_rep → core_clk_rst_ff / reg_phy_rdy)
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */rst_psrst_n_r_rep*reg*/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */core_clk_rst_ff_reg/D}]
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */rst_psrst_n_r_rep*reg*/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_0_init_ctrl_inst/reg_phy_rdy*/D}]

# PCIe phy_rate_chain CDC
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */phy_rate_chain_cp/*/ff_chain_reg*/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */phy_pipeline/phy_rate_chain/*/ff_chain_reg*/D}]

# PCIe SAXISCC (AXI stream crossing) hold
set_false_path -hold \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/*}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/SAXISCC*}]

# DCIM weight_reg → SRAM DINB hold（SRAM 写入时序由 DCIM 协议保证）
# 路径: gen_tiles[N].u_tile/dcim_data_wei_reg → u_dcim/.../mem_reg*/DINBDIN
set _fp_wei_from [get_pins -quiet -hierarchical -filter {NAME =~ */gen_tiles*.u_tile/dcim_data_wei_reg*/C}]
set _fp_wei_to   [get_pins -quiet -hierarchical -filter {NAME =~ */u_sramWrap/u_rf/mem_reg*/DINBDIN*}]
if {[llength $_fp_wei_from] && [llength $_fp_wei_to]} {
  set_false_path -hold -from $_fp_wei_from -to $_fp_wei_to
}

# ============================================================================
# 扇出优化
# ============================================================================
set _fanout_cnt [get_cells -quiet -hierarchical -filter {NAME =~ */u_maArray/u_counter*/r_cnt_reg*}]
if {[llength $_fanout_cnt]} {
  set_property MAX_FANOUT 32 $_fanout_cnt
}
# NOTE: REGISTER_DUPLICATION and MAX_FANOUT cannot be applied to [current_design] in XDC.
# These are synthesis attributes; set them in the RTL or synth_design options instead.
# set_property REGISTER_DUPLICATION TRUE [current_design]  <- removed
# set_property MAX_FANOUT 64 [current_design]              <- removed

set _dsp_cells [get_cells -quiet -hierarchical -filter {REF_NAME == DSP48E2 && NAME =~ */u_maArray/*}]
if {[llength $_dsp_cells]} {
  set_property USE_DSP_AREG 2 $_dsp_cells
  set_property USE_DSP_BREG 2 $_dsp_cells
}

set _cnt_cells_all [get_cells -quiet -hierarchical -filter {NAME =~ */u_maArray/u_counter_cfg/*}]
if {[llength $_cnt_cells_all]} {
  set_property MAX_FANOUT 32 $_cnt_cells_all
}

# ============================================================================
# DCIM maArray 多周期路径约束
# ============================================================================
set _mcp_dsp_p [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/MultiplierChannels*/u_multiplier/prod_full*/P[*]}]
set _mcp_pp_d  [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/product_pipe_reg*/D}]
if {[llength $_mcp_dsp_p] && [llength $_mcp_pp_d]} {
  set_multicycle_path -setup 2 -from $_mcp_dsp_p -to $_mcp_pp_d
  set_multicycle_path -hold 1  -from $_mcp_dsp_p -to $_mcp_pp_d
}

set _mcp_carry [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/u_adderTree/*carry*/CO[*]}]
set _mcp_res_d [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/result_reg*/D}]
if {[llength $_mcp_carry] && [llength $_mcp_res_d]} {
  set_multicycle_path -setup 2 -from $_mcp_carry -to $_mcp_res_d
  set_multicycle_path -hold 1  -from $_mcp_carry -to $_mcp_res_d
}

set _merge_cells [get_cells -quiet -hierarchical -filter {NAME =~ *u_mergeArray/*}]
set _accum_cells [get_cells -quiet -hierarchical -filter {NAME =~ *u_accumulateArray/*}]
if {[llength $_merge_cells] && [llength $_accum_cells]} {
  set_multicycle_path -setup 2 -from $_merge_cells -to $_accum_cells
  set_multicycle_path -hold 1  -from $_merge_cells -to $_accum_cells
}

set _post_cells [get_cells -quiet -hierarchical -filter {NAME =~ *u_postProcess/*}]
if {[llength $_accum_cells] && [llength $_post_cells]} {
  set_multicycle_path -setup 2 -from $_accum_cells -to $_post_cells
  set_multicycle_path -hold 1  -from $_accum_cells -to $_post_cells
}

# Arbiter MCP
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

# OBUF 仲裁器 obuf_addr 写入路径 MCP（worst path: tile_wr_valid_q → obuf_addr）
# 注意：Vivado 可能生成 _replica 后缀，用通配符匹配
set _mcp_ob_addr_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_obuf_arb/tile_wr_valid_q*C}]
set _mcp_ob_addr_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_obuf_arb/obuf_addr_reg*/D}]
if {[llength $_mcp_ob_addr_from] && [llength $_mcp_ob_addr_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_addr_from -to $_mcp_ob_addr_to
  set_multicycle_path -hold 1  -from $_mcp_ob_addr_from -to $_mcp_ob_addr_to
  puts "INFO: OBUF arb addr MCP: [llength $_mcp_ob_addr_from] src, [llength $_mcp_ob_addr_to] dst"
}

# OBUF arbiter grant_valid / rr_ptr 路径（同样需要覆盖 _replica）
set _mcp_ob_grant_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_obuf_arb/tile_wr_valid_q*C}]
set _mcp_ob_grant_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_obuf_arb/rr_ptr_reg*/D}]
if {[llength $_mcp_ob_grant_from] && [llength $_mcp_ob_grant_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_grant_from -to $_mcp_ob_grant_to
  set_multicycle_path -hold 1  -from $_mcp_ob_grant_from -to $_mcp_ob_grant_to
}

# OBUF arbiter obuf_din/obuf_we 路径
set _mcp_ob_data_to [get_pins -quiet -hierarchical -filter {NAME =~ *u_group/u_obuf_arb/obuf_din_reg*/D}]
if {[llength $_mcp_ob_addr_from] && [llength $_mcp_ob_data_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_addr_from -to $_mcp_ob_data_to
  set_multicycle_path -hold 1  -from $_mcp_ob_addr_from -to $_mcp_ob_data_to
}

# maArray 流水寄存器 MCP
set _mcp_ma_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/MultiplierChannels*/u_multiplier/prod_full*/P[*]}]
set _mcp_ma_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/gen_ma_pipe.r_ma_pipe*/D}]
if {[llength $_mcp_ma_from] && [llength $_mcp_ma_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ma_from -to $_mcp_ma_to
  set_multicycle_path -hold 1 -from $_mcp_ma_from -to $_mcp_ma_to
}
set _mcp_sub_from [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*}]
set _mcp_sub_to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/gen_ma_pipe.r_ma_pipe*}]
if {[llength $_mcp_sub_from] && [llength $_mcp_sub_to]} {
  set_multicycle_path -setup 2 -from $_mcp_sub_from -to $_mcp_sub_to
  set_multicycle_path -hold 1 -from $_mcp_sub_from -to $_mcp_sub_to
}

# ============================================================================
# SLR Pblock 约束 (lite: 仅 1 group)
# ============================================================================
create_pblock pblock_group_0
add_cells_to_pblock [get_pblocks pblock_group_0] [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_top/u_dcim_array/gen_groups\[0\].u_group}]
resize_pblock [get_pblocks pblock_group_0] -add {CLOCKREGION_X0Y0:CLOCKREGION_X3Y4}

# AXI 互连 + VPU + INST_Decoder + CDMA 放在 SLR0（与 Group 0 同层）
create_pblock pblock_axi_vpu
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/axi_mem_smc/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/vpu_0/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/axi_cdma_0/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/inst_decoder/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/cdma_ctrl/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/inst_bram/*}]
resize_pblock [get_pblocks pblock_axi_vpu] -add {CLOCKREGION_X4Y0:CLOCKREGION_X7Y4}
set_property IS_SOFT FALSE [get_pblocks pblock_axi_vpu]

# ============================================================================
# SLR 分配 (lite: 所有逻辑在 SLR0)
# ============================================================================
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ *gen_groups\[0\].u_group*}]
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/vpu_0/*}]
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/inst_decoder/*}]
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/cdma_ctrl/*}]
set_property USER_SLR_ASSIGNMENT SLR0 [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/inst_bram/*}]

# ============================================================================
# OBUF URAM cascade multicycle path
# ============================================================================
# OBUF is 16MB deep (AWIDTH=20), requiring 7+ URAM cascade stages.
# The cascade read data path takes ~5.5ns (> 4ns period at 250MHz).
# This is safe because obuf_bank has NBPIPE=2 pipeline registers that
# absorb the extra latency. OBUF READ_LATENCY is set to 9 in chip_defines.
set_multicycle_path 2 -setup \
  -from [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_reg_uram*}] \
  -to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_pipe_rega_reg*}]
set_multicycle_path 1 -hold \
  -from [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_reg_uram*}] \
  -to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_pipe_rega_reg*}]

# IBUF URAM cascade (AWIDTH=17, cascade ~16 deep)
set_multicycle_path 2 -setup \
  -from [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_reg_uram*}] \
  -to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_pipe_rega_reg*}]
set_multicycle_path 1 -hold \
  -from [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_reg_uram*}] \
  -to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_pipe_rega_reg*}]

# im2col S_INIT one-time precompute registers
