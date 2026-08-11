# ==============================================================================
# hbm.tcl - chip-v3: distributed tile_ibuf + tile_obuf + VPU_BUF
#
# chip-v3 变更:
#   - 删除 dcim_ibuf_smc / dcim_ibuf_ctrl_0（共享 IBUF 已拆分为 per-tile）
#   - 新增 Nx tile_ibuf_ctrl_N（per-Tile IBUF, 512KB each, N=$::DCIM_NUM_TILES）
#   - 保留 Nx tile_obuf_ctrl_N（per-Tile OBUF, 256KB each）
#   - 保留 vpu_buf_ctrl（VPU 本地 buffer, 8MB）
#   - SmartConnect NUM_MI = DCIM_NUM_TILES*2 + 5
# ==============================================================================

# ==============================================================================
# 1. Main Domain Reset (250 MHz, driven by cpu_reset)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 main_rst

# The 16 per-Tile AXI BRAM controllers are physically distributed over all
# three SLRs.  Give each SLR a local reset synchronizer so reset release does
# not become a high-fanout, route-only path from the XDMA in SLR0.  The XDC
# places these three tiny blocks beside the controllers that they reset.
foreach slr_idx {0 1 2} {
  create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 tile_rst_slr${slr_idx}
}

# ==============================================================================
# 2. HBM IP (1 stack, 4GB, interleaved via SAXI_00 + internal switch)
# ==============================================================================
set hbm_0 [get_bd_cells -quiet hbm_0]
if {$hbm_0 eq ""} {
  set hbm_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 hbm_0]
}

set hbm_cfg [list \
  CONFIG.USER_HBM_DENSITY       {4GB} \
  CONFIG.USER_HBM_STACK         {1} \
  CONFIG.USER_AXI_CLK_FREQ      {450} \
  CONFIG.USER_APB_EN            {false} \
  CONFIG.USER_MC_ENABLE_APB_00  {false} \
  CONFIG.USER_SAXI_00           {true} \
  CONFIG.USER_SWITCH_ENABLE_00  {true} \
  CONFIG.USER_SWITCH_ENABLE_01  {false} \
]

# 只启用 SAXI_00，关闭其余所有端口
for {set idx 1} {$idx < 32} {incr idx} {
  lappend hbm_cfg [format "CONFIG.USER_SAXI_%02d" $idx] {false}
}

# 启用全部 8 个 MC（1 stack），确保 interleave 能覆盖完整 4GB
for {set idx 0} {$idx < 8} {incr idx} {
  lappend hbm_cfg [format "CONFIG.USER_MC_ENABLE_%02d"  $idx] {TRUE}
  lappend hbm_cfg [format "CONFIG.USER_PHY_ENABLE_%02d" $idx] {TRUE}
}
# 关闭 Stack1 的 MC（仅使用 Stack0）
for {set idx 8} {$idx < 16} {incr idx} {
  lappend hbm_cfg [format "CONFIG.USER_MC_ENABLE_%02d"  $idx] {FALSE}
  lappend hbm_cfg [format "CONFIG.USER_PHY_ENABLE_%02d" $idx] {FALSE}
}

set_property -dict $hbm_cfg $hbm_0

# ==============================================================================
# 3. HBM reference clock (100 MHz from XDMA 250MHz via clk_wiz)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 hbm_ref_clk_wiz
set_property -dict [list \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.USE_RESET {true} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] [get_bd_cells hbm_ref_clk_wiz]

# HBM APB domain reset (100 MHz)
# APB_0_PRESET_N 必须连接有效的 active-low 复位信号
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 hbm_apb_rst

# HBM AXI clock (450 MHz)
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 hbm_axi_clk_wiz
set_property -dict [list \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {450} \
  CONFIG.USE_LOCKED {true} \
  CONFIG.USE_RESET {true} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] [get_bd_cells hbm_axi_clk_wiz]

# HBM domain reset
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 hbm_rst

# ==============================================================================
# 4. AXI Clock Converter (250 MHz system → 450 MHz HBM)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 hbm_axi_cc
set_property -dict [list \
  CONFIG.ADDR_WIDTH {33} \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.ID_WIDTH {4} \
] [get_bd_cells hbm_axi_cc]

# ==============================================================================
# 5. tile_ibuf Controllers (chip-v3: N x 512KB per-tile IBUF, 128-bit)
#    Tile 数量由 $::DCIM_NUM_TILES 驱动（config.tcl 定义）
# ==============================================================================

if {![info exists ::DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY]} {
    error "DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY not set — source config.tcl before hbm.tcl"
}
if {![info exists ::DCIM_NUM_TILES]} {
    error "DCIM_NUM_TILES not set — source config.tcl before hbm.tcl"
}
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 tile_ibuf_ctrl_${t}
  set_property -dict [list \
    CONFIG.DATA_WIDTH {128} \
    CONFIG.SINGLE_PORT_BRAM {1} \
    CONFIG.ECC_TYPE {0} \
    CONFIG.READ_LATENCY $::DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY \
  ] [get_bd_cells tile_ibuf_ctrl_${t}]
}

# ==============================================================================
# 5b. tile_obuf Controllers (N x 256KB, 128-bit each)
#     Tile 数量由 $::DCIM_NUM_TILES 驱动
# ==============================================================================
if {![info exists ::DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY]} {
    error "DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY not set — source config.tcl before hbm.tcl"
}
for {set t 0} {$t < $::DCIM_NUM_TILES} {incr t} {
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 tile_obuf_ctrl_${t}
  set_property -dict [list \
    CONFIG.DATA_WIDTH {128} \
    CONFIG.SINGLE_PORT_BRAM {1} \
    CONFIG.ECC_TYPE {0} \
    CONFIG.READ_LATENCY $::DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY \
  ] [get_bd_cells tile_obuf_ctrl_${t}]
}

# ==============================================================================
# 5c. VPU_BUF Controller (chip-v3 XPM: 8MB, 128-bit)
# ==============================================================================
if {![info exists ::VPU_BUF_AXI_BRAM_READ_LATENCY]} {
    error "VPU_BUF_AXI_BRAM_READ_LATENCY not set — source config.tcl before hbm.tcl"
}
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_buf_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
  CONFIG.READ_LATENCY $::VPU_BUF_AXI_BRAM_READ_LATENCY \
] [get_bd_cells vpu_buf_ctrl]

# ==============================================================================
# 6. VPU Weight Buffer Controller (WB only; GB removed in lite)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_wb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
  CONFIG.READ_LATENCY {1} \
] [get_bd_cells vpu_wb_ctrl]

# ==============================================================================
# 6b. Instruction BRAM Controller (128KB, 32-bit)
# ==============================================================================
if {![info exists ::INST_BRAM_READ_LATENCY]} {
    error "INST_BRAM_READ_LATENCY not set — source config.tcl before hbm.tcl"
}
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 inst_bram_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
  CONFIG.READ_LATENCY $::INST_BRAM_READ_LATENCY \
] [get_bd_cells inst_bram_ctrl]

# ==============================================================================
# 7. VPU Control Infrastructure (RTL Module References)
# ==============================================================================
create_bd_cell -type module -reference VPU_AXI_Regs vpu_regs
create_bd_cell -type module -reference INST_BRAM inst_bram
create_bd_cell -type module -reference INST_Decoder_wrapper inst_decoder
create_bd_cell -type module -reference CDMA_Controller_wrapper cdma_ctrl
