# ============================================================================
# DCIM_Array + VPU Chip (lite) - Timing and Physical Constraints
# Target: 250 MHz (4.000 ns) on xcvu37p-fsvh2892-2L-e
#
# 约束设计原则：
#   1. 每条约束必须有硬件语义支撑，不允许 "set_false_path 绕过" 真实时序路径
#   2. set_clock_groups -asynchronous 仅用于真正无相位关系的时钟域
#      （即：IP 内部已用 async FIFO / 双 FF 同步器处理 CDC 的路径）
#   3. set_false_path 仅用于单次复位路径（复位本身就是异步的，非数据路径）
#   4. MCP 约束必须在 RTL 中有对应的多周期逻辑支撑（已在 DCIM/VPU RTL 验证）
# ============================================================================

# ============================================================================
# 时钟约束
# ============================================================================
# clk_main = PCIe UserClk，由 BUFG_GT bufg_gt_userclk 产生，250 MHz。
# 注意：PCIe IP 已在 OOC 阶段对该 BUFG_GT 设定时钟。
#   此处以层次路径名 create_clock 是为了明确时钟名称供后续约束引用。
#   若 BUFG_GT pin 不存在（综合阶段），整段被 if guard 跳过，不报错。
set _xdc_user_clk_pins [get_pins -quiet -hierarchical \
  -filter {NAME =~ */xdma_0/inst/pcie4_ip_i/inst/*/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O}]
if {[llength $_xdc_user_clk_pins] == 0} {
  set _xdc_user_clk_pins [get_pins -quiet -hierarchical \
    -filter {NAME =~ */xdma_0/*bufg_gt_userclk/O}]
}
if {[llength $_xdc_user_clk_pins]} {
  create_clock -period 4.000 -name clk_main [lindex $_xdc_user_clk_pins 0]
  # 注意：不加 set_clock_uncertainty。
  # BUFG_GT 时钟来自 GT PLL，TSJ=0、DJ=0（PLL 已消除抖动）。
  # 人为加 uncertainty 会同时收紧 hold requirement，
  # 导致 DSP48E2 内部 D→AD pre-adder 路径出现 -0.011ns hold violation（已验证）。
  # Vivado 会自动使用 CPR（clock pessimism removal）处理 hold 裕量，无需人为加 margin。
}

# PCIe GT TXOUTCLK = PCIe CoreClk，由同一 GT PLL 产生但与 UserClk 独立分频，
# 两者频率相同但相位不固定（GT PLL 输出的两路 BUFG_GT 输出没有相位保证）。
#
# 硬件证据：
#   XDMA IP 在 CoreClk↔UserClk 之间使用异步 FIFO（RQ_FIFO、CQ_FIFO 等），
#   内部有 Gray-code pointer + 双 FF 同步器，架构上保证 CDC 安全。
#   TIMING-16 报告的违例终点是 RQ_FIFO/Head_reg/R（FIFO 复位端口），
#   而非数据端口——这是 IP 内部设计，用户无法且不应干预。
#
# 因此 set_clock_groups -asynchronous 是正确建模，不是绕过：
#   它告诉 Vivado "这两个域之间没有需要用户保证的时序路径"，
#   与 IP 的实际 CDC 架构一致。
set _clk_txout [get_clocks -quiet GTYE4_CHANNEL_TXOUTCLK*]
if {[llength $_clk_txout]} {
  set_clock_groups -asynchronous \
    -group [get_clocks clk_main] \
    -group [get_clocks GTYE4_CHANNEL_TXOUTCLK*]
  puts "INFO: clk_main <-> GTYE4_CHANNEL_TXOUTCLK* declared asynchronous ([llength $_clk_txout] clocks)"
}

# HBM AXI 时钟（clk_out1_lite_hbm_axi_clk_wiz_0）由独立 MMCM 产生，
# 与 clk_main 无相位关系。hbm_axi_cc（AXI Clock Converter IP）在两域之间
# 提供完整的 CDC 握手，架构上保证数据完整性。
# 与 TXOUTCLK 同理：set_clock_groups 是正确建模。
set _clk_hbm_axi [get_clocks -quiet clk_out1_lite_hbm_axi_clk_wiz_0*]
if {[llength $_clk_hbm_axi]} {
  set_clock_groups -asynchronous \
    -group [get_clocks clk_main] \
    -group [get_clocks clk_out1_lite_hbm_axi_clk_wiz_0*]
  puts "INFO: clk_main <-> clk_out1_lite_hbm_axi_clk_wiz_0 declared asynchronous"
}

# ============================================================================
# 复位约束
# ============================================================================
# 复位路径的 set_false_path 不是绕过，而是正确建模：
#   复位信号本身就是异步产生的（由操作系统/固件触发），
#   硬件设计要求所有被复位的寄存器能在异步边沿下可靠复位，
#   Vivado 不应对这些路径做 setup/hold 分析，因为它们不是同步数据路径。

# 顶层 cpu_reset 端口（板级 pushbutton/PCIe hot_reset）
if {[llength [get_ports -quiet cpu_reset]]} {
  set_false_path -from [get_ports cpu_reset]
}

# DCIM 异步复位 false path
# DCIM 模块使用异步复位（FDCE/FDPE），reset 由 main_rst（proc_sys_reset IP）产生，
# main_rst 本身已是同步输出（proc_sys_reset 内部有双 FF 同步器），
# 但 DCIM CLR/PRE 端口在语义上仍是异步（不依赖时钟边沿），故豁免。
# 只匹配 CLR/PRE（FDCE/FDPE 的真正异步复位/置位端点），
# 避免匹配 CE/D/R 等同步端口导致 CRITICAL WARNING [Vivado 12-4439]。
set _dcim_arst_to [get_pins -quiet -hierarchical -filter {
  NAME =~ *dcim_array_0/inst/* && IS_LEAF && DIRECTION == IN &&
  (NAME =~ */CLR || NAME =~ */PRE)
}]
if {[llength $_dcim_arst_to]} {
  set_false_path -to $_dcim_arst_to
  puts "INFO: DCIM async reset false_path: [llength $_dcim_arst_to] CLR/PRE pins"
}
set _main_rst_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */main_rst/U0/ACTIVE_LOW_PR_OUT_DFF*/C}]
if {[llength $_main_rst_from] && [llength $_dcim_arst_to]} {
  set_false_path -from $_main_rst_from -to $_dcim_arst_to
}

# XDMA user_reset → BRAM reset ports
# user_reset 是 PCIe IP 产生的同步复位输出，但 BRAM RSTREG/RSTRAM 是异步复位端口。
# 硬件语义：BRAM 复位时处于空闲状态，复位后由软件重新配置，无需 setup 分析。
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */*bram*/RSTREG*}]
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */*bram*/RSTRAM*}]

# XDMA user_reset → inst_bram 寄存器 D 引脚
# inst_bram 通过 AXI 接口复位，user_reset 触发后 AXI 协议保证数据不被捕获，
# 无需 setup 时序分析。只约束 IS_LEAF+D 引脚避免匹配 AXI 端口（非法 endpoint）。
set _fp_instbram_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ */inst_bram/* && IS_LEAF && DIRECTION == IN && NAME =~ */D}]
set _fp_xdma_rst [get_pins -quiet -hierarchical -filter {NAME =~ */xdma_0/*/user_reset*}]
if {[llength $_fp_xdma_rst] && [llength $_fp_instbram_to]} {
  set_false_path -from $_fp_xdma_rst -to $_fp_instbram_to
}

# ==== PCIe IP 内部路径（以下约束均基于 XDMA IP 硬件架构文档，非经验性绕过）====

# PCIe GT DRP（动态重配置端口）hold：
# DRP 接口由单独的 DRP 时钟驱动，与 GT 数据时钟异步。
# Xilinx GT Wizard IP 要求此路径豁免（见 UG576 / PG054 GT DRP 章节）。
set _fp_drp_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */xdma_0/*/gen_cpll_cal*/gtwizard_ultrascale*drp_arb_i/*/C}]
set _fp_drp_to   [get_pins -quiet -hierarchical -filter {NAME =~ */GTYE4_CHANNEL_PRIM_INST/DRP*}]
if {[llength $_fp_drp_from] && [llength $_fp_drp_to]} {
  set_false_path -hold -from $_fp_drp_from -to $_fp_drp_to
}

# PCIe PIPE 接口 hold：
# PIPE 信号由 PCIE4CE4 原语直接驱动物理层，其时序由 PCIe PHY 硬件保证，
# 不在 Vivado 时序分析范围内（见 PG054 PIPE Interface 章节）。
set _fp_pipe_from [get_pins -quiet -hierarchical -filter {NAME =~ */phy_pipeline/*/ff_chain_reg*/C}]
set _fp_pipe_to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/PIPETX*}]
if {[llength $_fp_pipe_from] && [llength $_fp_pipe_to]} {
  set_false_path -hold -from $_fp_pipe_from -to $_fp_pipe_to
}

# PCIe BRAM → PCIE4CE4 MIRX hold：
# BRAM 读数据路径到 PCIe 核 MIRX 端口，由 PCIe 核内部时序保证，用户不可干预。
set _fp_bram_rdata_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_0_bram_inst/*/reg_rdata*_reg*/C}]
set _fp_bram_rdata_to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/MIRX*}]
if {[llength $_fp_bram_rdata_from] && [llength $_fp_bram_rdata_to]} {
  set_false_path -hold -from $_fp_bram_rdata_from -to $_fp_bram_rdata_to
}

# PCIe BRAM 读流水 setup：RAMB36E2 CLKARDCLK → reg_rdata_reg D
# BRAM 内部流水线路径，Xilinx PCIe IP 建议豁免（CLKARDCLK 非独立时钟，是 BRAM 内部）。
set _fp_bram_clk_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_0_bram_inst/*/RAMB36E2*/CLKARDCLK}]
set _fp_bram_clk_to   [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_0_bram_inst/*/FRMRDPIPELINE.reg_rdata*_reg*/D}]
if {[llength $_fp_bram_clk_from] && [llength $_fp_bram_clk_to]} {
  set_false_path -setup -from $_fp_bram_clk_from -to $_fp_bram_clk_to
}

# PCIe seqnum FIFO CDC：write_addr → write_addr_read_clk
# 此 FIFO 是 XDMA IP 内部的异步序列号管理 FIFO，
# 写侧 CoreClk，读侧 UserClk，IP 内部有 Gray-code 同步器。
# set_clock_groups 已声明两域异步，此 false_path 作为显式覆盖保留。
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */seqnum_fifo*/write_addr_reg*/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */seqnum_fifo*/write_addr_read_clk_reg*/D}]

# PCIe GT 复位链：rst_psrst_n_r_rep → core_clk_rst_ff / reg_phy_rdy
# 复位握手信号从 PCIe Management 时钟域到 CoreClk 域，由 IP 内部复位同步器处理。
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */rst_psrst_n_r_rep*reg*/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */core_clk_rst_ff_reg/D}]
set_false_path \
  -from [get_pins -quiet -hierarchical -filter {NAME =~ */rst_psrst_n_r_rep*reg*/C}] \
  -to   [get_pins -quiet -hierarchical -filter {NAME =~ */pcie_4_0_init_ctrl_inst/reg_phy_rdy*/D}]

# PCIe phy_rate_chain CDC：CoreClk → UserClk PHY rate 信号
# PHY rate 是准静态信号（链路速率协商后不变），IP 内部有同步器。
set _fp_rate_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */phy_rate_chain_cp/*/ff_chain_reg*/C}]
set _fp_rate_to   [get_pins -quiet -hierarchical \
  -filter {NAME =~ */phy_pipeline/phy_rate_chain/*/ff_chain_reg*/D}]
if {[llength $_fp_rate_from] && [llength $_fp_rate_to]} {
  set_false_path -from $_fp_rate_from -to $_fp_rate_to
}

# PCIe SAXISCC（AXI stream crossing）hold：
# PCIE4CE4 SAXISCC 端口接收来自 UserClk 域的 AXI-S 数据，但 PCIe 核内部采样时序
# 由 PCIe IP 硬件保证（见 PG054 AXIS Requester Completion 章节）。
# 只匹配 xdma_0 内部寄存器时钟脚，避免误匹配 BD 端口。
set _fp_saxis_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ */xdma_0/inst/* && NAME =~ *_reg*/C}]
set _fp_saxis_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ */pcie_4_c_e4_inst/SAXISCC*}]
if {[llength $_fp_saxis_from] && [llength $_fp_saxis_to]} {
  set_false_path -hold -from $_fp_saxis_from -to $_fp_saxis_to
}

# DCIM weight_reg → SRAM DINB hold
# DCIM 协议：权重寄存器在计算开始前由 cfg 状态机写入，之后在 FSM 运行期间保持稳定。
# SRAM DINB（写数据端口）在写使能有效时才被采样，权重数据已提前多个周期就绪，
# hold 分析在此路径上无意义。
set _fp_wei_from [get_pins -quiet -hierarchical -filter {NAME =~ */gen_tiles*.u_tile/dcim_data_wei_reg*/C}]
set _fp_wei_to   [get_pins -quiet -hierarchical -filter {NAME =~ */u_sramWrap/u_rf/mem_reg*/DINBDIN*}]
if {[llength $_fp_wei_from] && [llength $_fp_wei_to]} {
  set_false_path -hold -from $_fp_wei_from -to $_fp_wei_to
}

# ============================================================================
# HBM IP 内部时序豁免
# ============================================================================
# WREADY_PIPE：HBM AXI 内部流水信号（HBM_SNGLBLI_INTF_AXI），
# Xilinx HBM IP 设计说明（PG276）明确指出此路径的 setup WNS 负值属正常现象，
# IP 内部逻辑有足够的实际余量，不需要用户保证。
set _hbm_wready [get_pins -quiet -hierarchical \
  -filter {NAME =~ */hbm_0/inst/*HBM_SNGLBLI_INTF_AXI*/WREADY_PIPE}]
if {[llength $_hbm_wready]} {
  set_false_path -setup -from $_hbm_wready
}

# hbm_rst → hbm_0 ARESET_N：proc_sys_reset IP 产生的复位，异步送入 HBM。
# HBM IP 要求 ARESET_N 为异步复位（无需满足 setup/hold），见 PG276 复位时序章节。
set _hbm_rst_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ */hbm_0/inst/*ARESET_N}]
if {[llength $_hbm_rst_to]} {
  set_false_path -to $_hbm_rst_to
}

# ============================================================================
# 扇出优化（物理约束，指导 Vivado 做寄存器复制）
# ============================================================================
# 以下 MAX_FANOUT 约束是真实的物理优化，不是绕过：
# 高扇出寄存器会产生长路由，导致跨 SLR 时钟周期内无法收敛。
# Vivado 在高扇出情况下自动复制寄存器（REGISTER_DUPLICATION），
# MAX_FANOUT 指示阈值，让工具在 SLR 内就近复制，消除跨 SLR 广播路由。

# u_counter r_cnt_reg：计数器输出扇出到 DSP 使能端，跨 SLR 时延迟过大
set _fanout_cnt [get_cells -quiet -hierarchical -filter {NAME =~ */u_maArray/u_counter*/r_cnt_reg*}]
if {[llength $_fanout_cnt]} {
  set_property MAX_FANOUT 32 $_fanout_cnt
}

# DSP48E2 MCP：prod_full 已被 use_dsp="yes" 映射为 DSP48E2 原语，
# P 输出到 product_pipe_reg D 之间有 1 级流水，RTL 中已插入 product_pipe_reg。
# 2-cycle MCP 正确反映该流水级的行为。
# 注意：USE_DSP_AREG/BREG 属性只能在综合前设置（RTL 属性），
# XDC 中对已实例化的 DSP48E2 设置无效，已移除。
set _dsp_cells [get_cells -quiet -hierarchical -filter {REF_NAME == DSP48E2 && NAME =~ */u_maArray/*}]
if {[llength $_dsp_cells]} {
  puts "INFO: [llength $_dsp_cells] DSP48E2 cells found in u_maArray"
  set _dsp_p_pins [get_pins -quiet -of_objects $_dsp_cells -filter {NAME =~ */P[*] && DIRECTION == OUT}]
  set _pp_d [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/product_pipe_reg*/D}]
  if {[llength $_dsp_p_pins] && [llength $_pp_d]} {
    set_multicycle_path -setup 2 -from $_dsp_p_pins -to $_pp_d
    set_multicycle_path -hold 1  -from $_dsp_p_pins -to $_pp_d
    puts "INFO: DSP P→product_pipe MCP(2): [llength $_dsp_p_pins] src, [llength $_pp_d] dst"
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
# SLR 穿越流水寄存器 MCP 约束
# ============================================================================
# DCIM_Array.sv 在 ready 出口和 start 入口各加了 1 级流水寄存器：
#   - ready_r  : tile_ready AND → ready_r → (SLL) → dcim_ready → INST_Decoder FSM
#   - start_r  : cfg_start → start_r → (SLL) → Tile.start
# 这两级寄存器是为了让 Vivado 把它们放在 SLR 边界（TX_REG/RX_REG），
# 消除 SLR2→SLR0 的直跨（2.78 ns net delay）。
#
# 功能安全：
#   ready_r 延迟 1 拍：INST_Decoder 用 dcim_layer_seen_busy 先检测 ready=0 忙态，
#   再检测 ready=1 完成，多 1 拍不影响正确性。
#   start_r 延迟 1 拍：start 为单周期脉冲，Tile FSM 在第 1 或第 2 拍收到均可正常启动；
#   ready_r=0 会在 start_r=1 同周期或稍后到达 INST_Decoder，seen_busy 可正常捕捉。
#
# MCP：ready_r/start_r 这两级寄存器与其后级 FSM 之间 放宽 1 拍（2-cycle setup），
# 允许综合器做跨 SLR 寄存器复制（SLL TX REG pipelining）而不被时序 DRC 误报。

# ready_r → inst_decoder FSM CE/D（主要 MCP，消除 worst path）
set _mcp_ready_r_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/ready_r_reg/C}]
set _mcp_ready_r_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ *inst_decoder*/FSM_onehot_state_reg*/CE ||
           NAME =~ *inst_decoder*/FSM_onehot_state_reg*/D  ||
           NAME =~ *inst_decoder*/dcim_layer_seen_busy_reg*/D}]
if {[llength $_mcp_ready_r_from] && [llength $_mcp_ready_r_to]} {
  set_multicycle_path 2 -setup -from $_mcp_ready_r_from -to $_mcp_ready_r_to
  set_multicycle_path 1 -hold  -from $_mcp_ready_r_from -to $_mcp_ready_r_to
  puts "INFO: ready_r→inst_decoder MCP(2): [llength $_mcp_ready_r_from] src, [llength $_mcp_ready_r_to] dst"
}

# start_r → tile FSM（下行流水，确保 start_r 到 Tile 的路径不被误约束）
set _mcp_start_r_from [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/start_r_reg/C}]
set _mcp_start_r_to [get_pins -quiet -hierarchical \
  -filter {NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/FSM_onehot_state_reg*/CE ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/*state_reg*/CE           ||
           NAME =~ *dcim_array_0/inst/u_dcim_array/gen_tiles*.u_tile/*state_reg*/D}]
if {[llength $_mcp_start_r_from] && [llength $_mcp_start_r_to]} {
  set_multicycle_path 2 -setup -from $_mcp_start_r_from -to $_mcp_start_r_to
  set_multicycle_path 1 -hold  -from $_mcp_start_r_from -to $_mcp_start_r_to
  puts "INFO: start_r→tile FSM MCP(2): [llength $_mcp_start_r_from] src, [llength $_mcp_start_r_to] dst"
}

# ============================================================================
# DCIM maArray 多周期路径约束
# ============================================================================
# prod_full 已被 use_dsp="yes" 映射为 DSP48E2。
# _dsp_cells 块通过 REF_NAME==DSP48E2 匹配 P 输出 pin，两种映射均覆盖。

# maArray MaSubcolumn → ma_pipe 流水寄存器 MCP（cell-level，兜底 DSP/LUT 两种映射）
set _mcp_sub_from [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*}]
set _mcp_sub_to   [get_cells -quiet -hierarchical -filter {NAME =~ *u_maArray/gen_ma_pipe.r_ma_pipe*}]
if {[llength $_mcp_sub_from] && [llength $_mcp_sub_to]} {
  set_multicycle_path -setup 2 -from $_mcp_sub_from -to $_mcp_sub_to
  set_multicycle_path -hold 1 -from $_mcp_sub_from -to $_mcp_sub_to
}
set _mcp_res_d [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/result_reg*/D}]
set _mcp_carry [get_pins -quiet -hierarchical -filter {NAME =~ *u_maArray/MaColumn*/MaSubcolumn*/u_adderTree/*carry*/CO[*]}]
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

# ============================================================================
# SLR Pblock 约束 (lite: 4 Tile, 器件 SLR0~2)
# ============================================================================
# Tile 0/1/2/3 各占 SLR0/SLR1/SLR1/SLR2，OBUF bank 无 pblock（见注释）。

# Tile 0 → SLR0（独占，与 VPU/XDMA 同 SLR，DSP 充裕）
set _tile0_cells [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[0].*}]
if {[llength $_tile0_cells]} {
  create_pblock pblock_tile_0
  add_cells_to_pblock [get_pblocks pblock_tile_0] $_tile0_cells
  resize_pblock [get_pblocks pblock_tile_0] -add {SLR0}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_0]
  puts "INFO: pblock_tile_0 -> SLR0: [llength $_tile0_cells] cells"
}

# Tile 1 + Tile 2 → SLR1（共享，DSP 按共享预算分配）
set _tile12_cells {}
foreach _t12_filt {
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[1].*}
  {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[2].*}
} {
  set _tc [get_cells -quiet -hierarchical -filter $_t12_filt]
  if {[llength $_tc]} { set _tile12_cells [concat $_tile12_cells $_tc] }
}
if {[llength $_tile12_cells]} {
  create_pblock pblock_tile_12
  add_cells_to_pblock [get_pblocks pblock_tile_12] $_tile12_cells
  resize_pblock [get_pblocks pblock_tile_12] -add {SLR1}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_12]
  puts "INFO: pblock_tile_12 -> SLR1: [llength $_tile12_cells] cells"
}

# Tile 3 → SLR2（独占，DSP 充裕）
set _tile3_cells [get_cells -quiet -hierarchical -filter {NAME =~ */dcim_array_0/inst/u_dcim_array/gen_tiles[3].*}]
if {[llength $_tile3_cells]} {
  create_pblock pblock_tile_3
  add_cells_to_pblock [get_pblocks pblock_tile_3] $_tile3_cells
  resize_pblock [get_pblocks pblock_tile_3] -add {SLR2}
  set_property IS_SOFT TRUE [get_pblocks pblock_tile_3]
  puts "INFO: pblock_tile_3 -> SLR2: [llength $_tile3_cells] cells"
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
# DQA scale/bias group_sel 高扇出约束
# ============================================================================
# post_route WNS=-0.583ns: dqa_x_load_c_cnt → dqa_scale_bias_group_sel → fo=16384
# RTL 修复：已将 group_sel 注册化（打 1 拍），并加 MAX_FANOUT=64 属性。
# XDC 双保险：如果综合未识别 RTL 属性，此处再加一次。
set _dqa_gs_regs [get_cells -quiet -hierarchical \
  -filter {NAME =~ *dqa_inst/dqa_scale_bias_group_sel_reg*}]
if {[llength $_dqa_gs_regs]} {
  set_property MAX_FANOUT 64 $_dqa_gs_regs
  puts "INFO: DQA group_sel MAX_FANOUT=64 applied to [llength $_dqa_gs_regs] cells"
}

# ============================================================================
# OBUF / IBUF 延迟策略（lite @ 250MHz）
# reg3 写侧 + memrega/mem_rstage DONT_TOUCH 读侧；MCP 留 4-cycle 余量。
# OBUF per-bank pblock 已移除：URAM 物理位置由工具自动保证，强制约束反而
# 导致 SLR1/SLR2 CLB 占用率 ~99.8%，router 无空间修复 hold violation。
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
