# ============================================================================
# DCIM_Array + VPU Chip (lite) - Timing and Physical Constraints
# Target: 250 MHz (4.000 ns) on xcvu37p-fsvh2892-2L-e
# Memory: XDMA only (HBM removed in lite version)
# ============================================================================

# ============================================================================
# DSP 资源约束
# ============================================================================
# multiplier.v 已移除 (* use_dsp = "no" *)，Vivado 自动将 8x8 乘法推断为 DSP48E2。
# - xcvu37p 有 9024 DSP；DCIM OOC synth 设 -max_dsp 8700（见 vivado_bd_ooc.tcl），
#   顶层 synth_design -max_dsp 8800，两道防线确保 DCIM(8700)+VPU(57)+other < 9024。
# - 设计总 16384 个 4-bit 乘法器（4 Tile × 16 col × 4 subcol × 64 ch），
#   Vivado 会尽量用满 ~8700 个 DSP，其余回落到 LUT，不产生综合 ERROR。
# - 估算效果：每 Tile 节省 ~40-60K LUT，两对 Tile 降至 ~370-380K / SLR < 432K。
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

# DCIM 异步复位 false path
# 用 cell-level 约束替代 pin-level，避免匹配 54 万个 CLR/PRE pin 导致性能问题
# (CRITICAL WARNING [Vivado 12-4439]: 541554 objects)
set _dcim_cells [get_cells -quiet -hierarchical -filter {NAME =~ *dcim_array_0*}]
if {[llength $_dcim_cells]} {
  set_false_path -to $_dcim_cells
}
set _main_rst_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */main_rst/U0/ACTIVE_LOW_PR_OUT_DFF*/C}]
if {[llength $_main_rst_from] && [llength $_dcim_cells]} {
  set_false_path -from $_main_rst_from -to $_dcim_cells
}

# XDMA user_reset → BRAM reset ports
set_false_path -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
               -to [get_pins -quiet -hierarchical -filter {NAME =~ */*bram*/RSTREG*}]
set_false_path -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
               -to [get_pins -quiet -hierarchical -filter {NAME =~ */*bram*/RSTRAM*}]
# inst_bram: 只约束寄存器的 D 引脚，排除 AXI 端口等非法 endpoint
# (WARNING [Constraints 18-401]: s_axi_* ports are not valid endpoints)
set _fp_instbram_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ */inst_bram/* && IS_LEAF && DIRECTION == IN && NAME =~ */D}]
set _fp_xdma_rst [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/*/user_reset*}]
if {[llength $_fp_xdma_rst] && [llength $_fp_instbram_to]} {
  set_false_path -from $_fp_xdma_rst -to $_fp_instbram_to
}

# PCIe GT DRP hold path
set _fp_drp_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */xdma_0/*/gen_cpll_cal*/gtwizard_ultrascale*drp_arb_i/*/C}]
set _fp_drp_to   [get_pins -quiet -hierarchical -filter {NAME =~ */GTYE4_CHANNEL_PRIM_INST/DRP*}]
if {[llength $_fp_drp_from] && [llength $_fp_drp_to]} {
  set_false_path -hold -from $_fp_drp_from -to $_fp_drp_to
}

# PCIe PIPE interface hold
set _fp_pipe_from [get_pins -quiet -hierarchical -filter {NAME =~ */phy_pipeline/*/ff_chain_reg*/C}]
set _fp_pipe_to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/PIPETX*}]
if {[llength $_fp_pipe_from] && [llength $_fp_pipe_to]} {
  set_false_path -hold -from $_fp_pipe_from -to $_fp_pipe_to
}

# PCIe BRAM → PCIE4CE4 hold
set _fp_bram_rdata_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_0_bram_inst/*/reg_rdata*_reg*/C}]
set _fp_bram_rdata_to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/MIRX*}]
if {[llength $_fp_bram_rdata_from] && [llength $_fp_bram_rdata_to]} {
  set_false_path -hold -from $_fp_bram_rdata_from -to $_fp_bram_rdata_to
}

# PCIe BRAM read pipeline setup: RAMB36E2 → reg_rdata1_reg
set _fp_bram_clk_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_0_bram_inst/*/RAMB36E2*/CLKARDCLK}]
set _fp_bram_clk_to   [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_0_bram_inst/*/FRMRDPIPELINE.reg_rdata*_reg*/D}]
if {[llength $_fp_bram_clk_from] && [llength $_fp_bram_clk_to]} {
  set_false_path -setup -from $_fp_bram_clk_from -to $_fp_bram_clk_to
}

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
set _fp_rate_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */phy_rate_chain_cp/*/ff_chain_reg*/C}]
set _fp_rate_to   [get_pins -quiet -hierarchical \
  -filter {NAME =~ */phy_pipeline/phy_rate_chain/*/ff_chain_reg*/D}]
if {[llength $_fp_rate_from] && [llength $_fp_rate_to]} {
  set_false_path -from $_fp_rate_from -to $_fp_rate_to
}

# PCIe SAXISCC (AXI stream crossing) hold — 仅 reg 时钟脚，避免匹配 BD 端口
set _fp_saxis_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */xdma_0/inst/* && NAME =~ *_reg*/C}]
set _fp_saxis_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_c_e4_inst/SAXISCC*}]
if {[llength $_fp_saxis_from] && [llength $_fp_saxis_to]} {
  set_false_path -hold -from $_fp_saxis_from -to $_fp_saxis_to
}

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
  puts "INFO: USE_DSP_AREG/BREG=2 applied to [llength $_dsp_cells] DSP48E2 cells in u_maArray"
  # DSP 推断后 prod_full 被映射为 DSP 原语，补充基于 DSP P 输出的 MCP
  # Vivado 对 (* use_dsp="yes" *) wire 推断 DSP 时：DSP 实例名带 prod_full 前缀
  # 同时用 REF_NAME+层次路径作为 fallback，确保约束命中
  set _dsp_p_pins [get_pins -quiet -of_objects $_dsp_cells -filter {NAME =~ */P[*] && DIRECTION == OUT}]
  set _pp_d [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/product_pipe_reg*/D}]
  if {[llength $_dsp_p_pins] && [llength $_pp_d]} {
    set_multicycle_path -setup 2 -from $_dsp_p_pins -to $_pp_d
    set_multicycle_path -hold 1  -from $_dsp_p_pins -to $_pp_d
    puts "INFO: DSP P→product_pipe MCP(2) applied: [llength $_dsp_p_pins] src, [llength $_pp_d] dst"
  }
}

set _cnt_cells_all [get_cells -quiet -hierarchical -filter {NAME =~ */u_maArray/u_counter_cfg/*}]
if {[llength $_cnt_cells_all]} {
  set_property MAX_FANOUT 32 $_cnt_cells_all
}

# post_place setup WNS=-3.747ns: cfg_start_reg(fan-out=54) → LUT3 → LUT5/LUT6(fan-out=190) → tile FSM CE
# 跨 SLR0↔SLR2 两次穿越，路由延迟 7.5ns，超出 4ns 时钟周期。
# 修复：对 cfg_start_reg 及 DCIM top-level 配置信号加 MAX_FANOUT，
#       让 Vivado 在每个 SLR 内复制寄存器，消除跨 SLR 广播路由。
set _cfg_start [get_cells -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/cfg_start_reg}]
if {[llength $_cfg_start]} {
  set_property MAX_FANOUT 16 $_cfg_start
}
# cfg_start 经过的中间 is_int16_reg LUT 输出 fan-out=190，也需要复制
set _is_int16_luts [get_cells -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/*is_int16_reg_i_1*}]
if {[llength $_is_int16_luts]} {
  set_property MAX_FANOUT 16 $_is_int16_luts
}
# DCIM Array 顶层所有配置寄存器统一限制扇出
set _dcim_cfg_regs [get_cells -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/cfg_*_reg*}]
if {[llength $_dcim_cfg_regs]} {
  set_property MAX_FANOUT 16 $_dcim_cfg_regs
}

# post_place setup WNS=-3.747ns: cfg_start → tile FSM CE 多周期路径
# 语义安全性：cfg_* 寄存器在 FSM 启动前由软件写入，至少等待 1 个指令解码周期（>100 个时钟），
# 与 FSM 启动时刻之间有足够的 setup margin，2-cycle MCP 不影响功能正确性。
# 路径：dcim_array_0/inst/cfg_*_reg → gen_tiles[*].u_tile/FSM_onehot_state_reg*/CE|D|S
set _mcp_cfg_from [get_cells -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/cfg_*_reg*}]
set _mcp_fsm_ce_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/FSM_onehot_state_reg*/CE ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/FSM_onehot_state_reg*/D  ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/*state_reg*/CE}]
if {[llength $_mcp_cfg_from] && [llength $_mcp_fsm_ce_to]} {
  set_multicycle_path 2 -setup -from $_mcp_cfg_from -to $_mcp_fsm_ce_to
  set_multicycle_path 1 -hold  -from $_mcp_cfg_from -to $_mcp_fsm_ce_to
  puts "INFO: cfg→FSM MCP 2-setup: [llength $_mcp_cfg_from] src, [llength $_mcp_fsm_ce_to] dst"
}

# ============================================================================
# HBM IP 内部时序豁免
# ============================================================================
# clk_out1_lite_hbm_axi_clk_wiz_0 setup WNS=-0.198ns (17 EP):
#   HBM_SNGLBLI_INTF_AXI.WREADY_PIPE → LUT4 → FDCE
#   HBM AXI IP 内部信号，Xilinx 官方 IP 不需要用户保证此路径时序，豁免之
set _hbm_wready [get_pins -quiet -hierarchical \
  -filter {NAME =~ */hbm_0/inst/*HBM_SNGLBLI_INTF_AXI*/WREADY_PIPE}]
if {[llength $_hbm_wready]} {
  set_false_path -setup -from $_hbm_wready
}

set _hbm_rst_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */hbm_rst/U0/ACTIVE_LOW_PR_OUT_DFF*/FDRE_PER_N/C}]
set _hbm_rst_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ */hbm_0/inst/*ARESET_N}]
if {[llength $_hbm_rst_from] && [llength $_hbm_rst_to]} {
  set_false_path -from $_hbm_rst_from -to $_hbm_rst_to
}

# ============================================================================
# DCIM maArray 多周期路径约束
# ============================================================================
# 注意：use_dsp="yes" 生效后，prod_full 被推断为 DSP48E2 原语。
# - 旧路径 prod_full*/P[*] → 变成 DSP 实例内部的 P 输出，filter 可能不匹配
# - 新路径：通过 _dsp_cells (REF_NAME==DSP48E2) 的 P 输出 pin 匹配
# - 两条路径均用 if guard，缺失不报错

# 路径1：multiplier P 输出 → product_pipe_reg D（LUT方式旧约束，DSP方式由上面 _dsp_cells 块覆盖）
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
set _mcp_ib_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_ibuf_arb/tile_rd_valid_q*}]
set _mcp_ib_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_ibuf_arb/grant_idx*}]
if {[llength $_mcp_ib_from] && [llength $_mcp_ib_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ib_from -to $_mcp_ib_to
  set_multicycle_path -hold 1 -from $_mcp_ib_from -to $_mcp_ib_to
}
set _mcp_ob_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_obuf_arb/tile_wr_valid_q*}]
set _mcp_ob_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_obuf_arb/grant_idx*}]
if {[llength $_mcp_ob_from] && [llength $_mcp_ob_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_from -to $_mcp_ob_to
  set_multicycle_path -hold 1 -from $_mcp_ob_from -to $_mcp_ob_to
}

# OBUF 仲裁器 obuf_addr 写入路径 MCP（worst path: tile_wr_valid_q → obuf_addr）
# 注意：Vivado 可能生成 _replica 后缀，用通配符匹配
set _mcp_ob_addr_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_obuf_arb/tile_wr_valid_q*C}]
set _mcp_ob_addr_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_obuf_arb/obuf_addr_reg*/D}]
if {[llength $_mcp_ob_addr_from] && [llength $_mcp_ob_addr_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_addr_from -to $_mcp_ob_addr_to
  set_multicycle_path -hold 1  -from $_mcp_ob_addr_from -to $_mcp_ob_addr_to
  puts "INFO: OBUF arb addr MCP: [llength $_mcp_ob_addr_from] src, [llength $_mcp_ob_addr_to] dst"
}

# OBUF arbiter grant_valid / rr_ptr 路径（同样需要覆盖 _replica）
set _mcp_ob_grant_from [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_obuf_arb/tile_wr_valid_q*C}]
set _mcp_ob_grant_to   [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_obuf_arb/rr_ptr_reg*/D}]
if {[llength $_mcp_ob_grant_from] && [llength $_mcp_ob_grant_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_grant_from -to $_mcp_ob_grant_to
  set_multicycle_path -hold 1  -from $_mcp_ob_grant_from -to $_mcp_ob_grant_to
}

# OBUF arbiter obuf_din/obuf_we 路径
set _mcp_ob_data_to [get_pins -quiet -hierarchical -filter {NAME =~ *u_dcim_array/u_obuf_arb/obuf_din_reg*/D}]
if {[llength $_mcp_ob_addr_from] && [llength $_mcp_ob_data_to]} {
  set_multicycle_path -setup 2 -from $_mcp_ob_addr_from -to $_mcp_ob_data_to
  set_multicycle_path -hold 1  -from $_mcp_ob_addr_from -to $_mcp_ob_data_to
}

# maArray 流水寄存器 MCP（LUT方式；DSP方式由 _dsp_cells 块的 P-pin MCP 覆盖）
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
# SLR Pblock 约束 (lite: 4 Tile Array, 4 OBUF bank, 器件仅 SLR0~2)
# ============================================================================
# 放置失败历史与修复（2026-06）：
#   Round 1: pblock_dcim_compute (SLR1+SLR2, 889K LUT) → Place 30-640 LUT overflow
#             + Place 30-99 SLL cut violation (100K nets vs 23K available)
#   Round 2: pblock_tile_01 (SLR1 only) + pblock_tile_23 (SLR2 only)
#             → Place 30-487 CLB packing failure: 445K LUT > 432K SLR1 上限 3%
#             + Control set 4399 个导致 CLB 打包效率下降
#
# Round 3 双重防护（当前）：
#   A. DSP 替代 LUT 乘法（multiplier.v 移除 use_dsp=no）：
#      - 8x8 乘法推断 DSP48E2；-max_dsp 8800 限总用量（设备 9024，余量给 VPU FP）
#      - 预计每 Tile 节省 ~40-60K LUT → 两 Tile/SLR 降至 ~370-380K << 432K
#   B. pblock 扩溢出 SLR（保险层，防 Vivado LUT 估算偏差）：
#      - pblock_tile_01: SLR1（主）+ SLR0（溢出）→ 2 SLR = 864K LUT 容量
#      - pblock_tile_23: SLR2（主）+ SLR1（溢出）→ 2 SLR = 864K LUT 容量
#
# SLL 保护（Round 2 策略保留）：
#   - OBUF bank0/1 → SLR1；bank2/3 → SLR2（Tile 数据通路同 SLR，消除大量 SLL）
#   - 历史 SLL: 100K → 0（已解决）
# ============================================================================

# Tile 0 + Tile 1 → SLR1
set _tile01_cells {}
foreach _t01_filt {
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[0].*}
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[1].*}
} {
  set _tc [get_cells -quiet -hierarchical -filter $_t01_filt]
  if {[llength $_tc]} { set _tile01_cells [concat $_tile01_cells $_tc] }
}
if {[llength $_tile01_cells]} {
  create_pblock pblock_tile_01
  add_cells_to_pblock [get_pblocks pblock_tile_01] $_tile01_cells
  resize_pblock [get_pblocks pblock_tile_01] -add {SLR1}
  resize_pblock [get_pblocks pblock_tile_01] -add {SLR0}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_01]
  puts "INFO: pblock_tile_01 -> SLR1+SLR0(overflow): [llength $_tile01_cells] cells"
}

# Tile 2 + Tile 3 → SLR2
set _tile23_cells {}
foreach _t23_filt {
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[2].*}
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[3].*}
} {
  set _tc [get_cells -quiet -hierarchical -filter $_t23_filt]
  if {[llength $_tc]} { set _tile23_cells [concat $_tile23_cells $_tc] }
}
if {[llength $_tile23_cells]} {
  create_pblock pblock_tile_23
  add_cells_to_pblock [get_pblocks pblock_tile_23] $_tile23_cells
  resize_pblock [get_pblocks pblock_tile_23] -add {SLR2}
  resize_pblock [get_pblocks pblock_tile_23] -add {SLR1}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_23]
  puts "INFO: pblock_tile_23 -> SLR2+SLR1(overflow): [llength $_tile23_cells] cells"
}

# 仲裁器放 SLR1（居中，面向两侧 Tile 数据通路）
foreach _arb_cell {
  {NAME =~ */dcim_array_0/inst/u_dcim_array/u_ibuf_arb}
  {NAME =~ */dcim_array_0/inst/u_dcim_array/u_obuf_arb}
} {
  set _arb_c [get_cells -quiet -hierarchical -filter $_arb_cell]
  if {[llength $_arb_c]} {
    set_property USER_SLR_ASSIGNMENT SLR1 $_arb_c
  }
}

# IBUF（2MB，64 URAM）→ SLR0，靠近 XDMA AXI 写通路
set _ibuf_top [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_dcim_array/u_ibuf}]
if {[llength $_ibuf_top]} {
  create_pblock pblock_ibuf
  add_cells_to_pblock [get_pblocks pblock_ibuf] $_ibuf_top
  resize_pblock [get_pblocks pblock_ibuf] -add {SLR0}
  set_property IS_SOFT TRUE [get_pblocks pblock_ibuf]
}

# AXI 互连 + VPU + INST_Decoder + CDMA：SLR0 软约束（与 OBUF port A / XDMA 近）
create_pblock pblock_axi_vpu
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/axi_mem_smc/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/vpu_0/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/axi_cdma_0/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/inst_decoder/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/cdma_ctrl/*}]
add_cells_to_pblock [get_pblocks pblock_axi_vpu] [get_cells -quiet -hierarchical -filter {NAME =~ lite_i/inst_bram/*}]
resize_pblock [get_pblocks pblock_axi_vpu] -add {SLR0}
set_property IS_SOFT TRUE [get_pblocks pblock_axi_vpu]

# SLR 分配：须作用在层次 cell 上（非 leaf）
foreach _slr_cell {
  lite_i/vpu_0
  lite_i/inst_decoder
  lite_i/cdma_ctrl
  lite_i/inst_bram
} {
  set _c [get_cells -quiet $_slr_cell]
  if {[llength $_c]} {
    set_property USER_SLR_ASSIGNMENT SLR0 $_c
  }
}

# ============================================================================
# OBUF per-bank Pblock（lite: 4 bank × 4MB URAM = 512 URAM total）
# bank0/1 → SLR1（与 Tile 0/1 同 SLR，消除 obuf_din/obuf_addr 路径跨 SLR）
# bank2/3 → SLR2（与 Tile 2/3 同 SLR）
# wea_reg3 与对应 bank URAM cascade 同 SLR；obuf.v reg3 已 DONT_TOUCH。
# ============================================================================

set _obuf_b0 [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf/gen_banks[0].*}]
if {[llength $_obuf_b0]} {
  create_pblock pblock_obuf_bank0
  add_cells_to_pblock [get_pblocks pblock_obuf_bank0] $_obuf_b0
  resize_pblock [get_pblocks pblock_obuf_bank0] -add {SLR1}
  set_property IS_SOFT TRUE [get_pblocks pblock_obuf_bank0]
}

set _obuf_b1 [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf/gen_banks[1].*}]
if {[llength $_obuf_b1]} {
  create_pblock pblock_obuf_bank1
  add_cells_to_pblock [get_pblocks pblock_obuf_bank1] $_obuf_b1
  resize_pblock [get_pblocks pblock_obuf_bank1] -add {SLR1}
  set_property IS_SOFT TRUE [get_pblocks pblock_obuf_bank1]
}

set _obuf_b2 [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf/gen_banks[2].*}]
if {[llength $_obuf_b2]} {
  create_pblock pblock_obuf_bank2
  add_cells_to_pblock [get_pblocks pblock_obuf_bank2] $_obuf_b2
  resize_pblock [get_pblocks pblock_obuf_bank2] -add {SLR2}
  set_property IS_SOFT TRUE [get_pblocks pblock_obuf_bank2]
}

set _obuf_b3 [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf/gen_banks[3].*}]
if {[llength $_obuf_b3]} {
  create_pblock pblock_obuf_bank3
  add_cells_to_pblock [get_pblocks pblock_obuf_bank3] $_obuf_b3
  resize_pblock [get_pblocks pblock_obuf_bank3] -add {SLR2}
  set_property IS_SOFT TRUE [get_pblocks pblock_obuf_bank3]
}

# ============================================================================
# OBUF / IBUF 延迟策略（lite @ 250MHz）
# obuf.v v4：reg3 写侧 + memrega/mem_rstage DONT_TOUCH 读侧；MCP 留 4-cycle 余量。
# ============================================================================
set _buf_mcp_setup 4

set _obuf_lat_src {}
foreach _obuf_lat_filt {
  {NAME =~ *u_obuf*gen_banks*wea_reg3*}
  {NAME =~ *u_obuf*gen_banks*web_reg3*}
  {NAME =~ *u_obuf*gen_banks*mem_ena_reg3*}
  {NAME =~ *u_obuf*gen_banks*mem_enb_reg3*}
  {NAME =~ *u_obuf*gen_banks*dina_reg3*}
  {NAME =~ *u_obuf*gen_banks*dinb_reg3*}
  {NAME =~ *u_obuf*gen_banks*addra_reg3*}
  {NAME =~ *u_obuf*gen_banks*addrb_reg3*}
  {NAME =~ *u_obuf*gen_banks*wea_reg2*}
  {NAME =~ *u_obuf*gen_banks*web_reg2*}
  {NAME =~ *u_obuf/wea_reg*}
  {NAME =~ *u_obuf/web_reg*}
  {NAME =~ *u_obuf/mem_ena_reg}
  {NAME =~ *u_obuf/mem_enb_reg}
  {NAME =~ *u_obuf/dina_reg}
  {NAME =~ *u_obuf/dinb_reg}
  {NAME =~ *u_obuf/addra_reg}
  {NAME =~ *u_obuf/addrb_reg}
} {
  set _c [get_cells -quiet -hierarchical -filter $_obuf_lat_filt]
  if {[llength $_c]} { set _obuf_lat_src [concat $_obuf_lat_src $_c] }
}
set _obuf_uram_all [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_reg_uram*}]
if {[llength $_obuf_lat_src] && [llength $_obuf_uram_all]} {
  set_multicycle_path -setup $_buf_mcp_setup -from $_obuf_lat_src -to $_obuf_uram_all
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -from $_obuf_lat_src -to $_obuf_uram_all
  puts "INFO: OBUF latency MCP $_buf_mcp_setup-setup: [llength $_obuf_lat_src] src -> [llength $_obuf_uram_all] uram"
}

set _ibuf_lat_src {}
foreach _ibuf_lat_filt {
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
  set _c [get_cells -quiet -hierarchical -filter $_ibuf_lat_filt]
  if {[llength $_c]} { set _ibuf_lat_src [concat $_ibuf_lat_src $_c] }
}
set _ibuf_uram_all [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_reg_uram*}]
if {[llength $_ibuf_lat_src] && [llength $_ibuf_uram_all]} {
  set_multicycle_path -setup $_buf_mcp_setup -from $_ibuf_lat_src -to $_ibuf_uram_all
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -from $_ibuf_lat_src -to $_ibuf_uram_all
  puts "INFO: IBUF latency MCP $_buf_mcp_setup-setup: [llength $_ibuf_lat_src] src -> [llength $_ibuf_uram_all] uram"
}

# URAM cascade 读数据路径（URAM288 不能作 -from 起点，用 -through）
# Port A/B 对称：rega+regb；memrega 被吸收时用 rstage 寄存器或 D 引脚兜底
set _obuf_uram_thru [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_reg_uram*}]
set _obuf_memreg    [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*memreg*_reg*}]
set _obuf_rstage    [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_rstage_reg*_reg*}]
set _obuf_pipe_dst  [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_pipe_reg*_reg*}]
set _obuf_rstage_pin [get_pins -quiet -hierarchical -filter {NAME =~ *u_obuf*mem_rstage_reg*_reg*/D}]
if {[llength $_obuf_uram_thru] && [llength $_obuf_memreg]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_obuf_uram_thru -to $_obuf_memreg
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_obuf_uram_thru -to $_obuf_memreg
  puts "INFO: OBUF URAM->memreg MCP $_buf_mcp_setup-setup: [llength $_obuf_uram_thru] uram -> [llength $_obuf_memreg] memreg"
}
if {[llength $_obuf_uram_thru] && [llength $_obuf_rstage]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_obuf_uram_thru -to $_obuf_rstage
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_obuf_uram_thru -to $_obuf_rstage
  puts "INFO: OBUF URAM->mem_rstage MCP $_buf_mcp_setup-setup: [llength $_obuf_uram_thru] uram -> [llength $_obuf_rstage] rstage"
}
if {[llength $_obuf_uram_thru] && [llength $_obuf_rstage_pin]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_obuf_uram_thru -to $_obuf_rstage_pin
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_obuf_uram_thru -to $_obuf_rstage_pin
  puts "INFO: OBUF URAM->mem_rstage(pin) MCP $_buf_mcp_setup-setup: [llength $_obuf_rstage_pin] pins"
}
if {[llength $_obuf_memreg] && [llength $_obuf_rstage]} {
  set_multicycle_path -setup 2 -from $_obuf_memreg -to $_obuf_rstage
  set_multicycle_path -hold 1 -from $_obuf_memreg -to $_obuf_rstage
}
if {[llength $_obuf_rstage] && [llength $_obuf_pipe_dst]} {
  set_multicycle_path -setup 1 -from $_obuf_rstage -to $_obuf_pipe_dst
  set_multicycle_path -hold 0 -from $_obuf_rstage -to $_obuf_pipe_dst
}
if {[llength $_obuf_uram_thru] && [llength $_obuf_pipe_dst]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_obuf_uram_thru -to $_obuf_pipe_dst
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_obuf_uram_thru -to $_obuf_pipe_dst
  puts "INFO: OBUF URAM cascade MCP $_buf_mcp_setup-setup: through [llength $_obuf_uram_thru] uram -> [llength $_obuf_pipe_dst] pipe"
}

set _ibuf_uram_thru [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_reg_uram*}]
set _ibuf_memreg    [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*memreg*_reg*}]
set _ibuf_rstage    [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_rstage_reg*_reg*}]
set _ibuf_pipe_dst  [get_cells -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_pipe_reg*_reg*}]
set _ibuf_rstage_pin [get_pins -quiet -hierarchical -filter {NAME =~ *u_ibuf*mem_rstage_reg*_reg*/D}]
if {[llength $_ibuf_uram_thru] && [llength $_ibuf_memreg]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_ibuf_uram_thru -to $_ibuf_memreg
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_ibuf_uram_thru -to $_ibuf_memreg
  puts "INFO: IBUF URAM->memreg MCP $_buf_mcp_setup-setup: [llength $_ibuf_uram_thru] uram -> [llength $_ibuf_memreg] memreg"
}
if {[llength $_ibuf_uram_thru] && [llength $_ibuf_rstage]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_ibuf_uram_thru -to $_ibuf_rstage
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_ibuf_uram_thru -to $_ibuf_rstage
  puts "INFO: IBUF URAM->mem_rstage MCP $_buf_mcp_setup-setup: [llength $_ibuf_uram_thru] uram -> [llength $_ibuf_rstage] rstage"
}
if {[llength $_ibuf_uram_thru] && [llength $_ibuf_rstage_pin]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_ibuf_uram_thru -to $_ibuf_rstage_pin
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_ibuf_uram_thru -to $_ibuf_rstage_pin
  puts "INFO: IBUF URAM->mem_rstage(pin) MCP $_buf_mcp_setup-setup: [llength $_ibuf_rstage_pin] pins"
}
if {[llength $_ibuf_memreg] && [llength $_ibuf_rstage]} {
  set_multicycle_path -setup 2 -from $_ibuf_memreg -to $_ibuf_rstage
  set_multicycle_path -hold 1 -from $_ibuf_memreg -to $_ibuf_rstage
}
if {[llength $_ibuf_rstage] && [llength $_ibuf_pipe_dst]} {
  set_multicycle_path -setup 1 -from $_ibuf_rstage -to $_ibuf_pipe_dst
  set_multicycle_path -hold 0 -from $_ibuf_rstage -to $_ibuf_pipe_dst
}
if {[llength $_ibuf_uram_thru] && [llength $_ibuf_pipe_dst]} {
  set_multicycle_path -setup $_buf_mcp_setup -through $_ibuf_uram_thru -to $_ibuf_pipe_dst
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -through $_ibuf_uram_thru -to $_ibuf_pipe_dst
  puts "INFO: IBUF URAM cascade MCP $_buf_mcp_setup-setup: through [llength $_ibuf_uram_thru] uram -> [llength $_ibuf_pipe_dst] pipe"
}

# OBUF bank 内 reg3 → u_bank 组合译码（reg3 已贴 URAM，MCP 仅兜底）
set _obuf_bank_reg3 [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*gen_banks*reg3*}]
set _obuf_bank_logic [get_cells -quiet -hierarchical -filter {NAME =~ *u_obuf*gen_banks*u_bank/*}]
if {[llength $_obuf_bank_reg3] && [llength $_obuf_bank_logic]} {
  set_multicycle_path -setup $_buf_mcp_setup -from $_obuf_bank_reg3 -to $_obuf_bank_logic
  set_multicycle_path -hold [expr {$_buf_mcp_setup - 1}] -from $_obuf_bank_reg3 -to $_obuf_bank_logic
}

# 保留旧 reg2 MCP 会被 reg3 覆盖（同路径取更宽松者由工具合并）
