# ==============================================================================
# hbm.tcl - lite version: 1 stack, 4GB, interleaved via SAXI_00
#
# VCU128 HBM2: 1 stack (4GB) with 8 MCs × 512MB = 4GB total.
# Interleave 策略：SAXI_00 开启 USER_SWITCH_ENABLE，HBM 内部 switch 将
# 地址哈希分发到所有 8 个 MC，使单端口能看到完整 4GB 地址空间，并充分
# 利用多 MC 带宽。
#
# Address interleave 映射：
#   SAXI_00 地址 [32:0] → HBM switch → MC00..MC07（各 512MB）
#   单端口可寻址范围：0x0_0000_0000 ~ 0x0_FFFF_FFFF (4GB)
#
# Architecture:
#   SmartConnect M05 → AXI Clock Converter (250→450 MHz)
#       → HBM SAXI_00 (switch interleaved, full 4GB view)
# ==============================================================================

# ==============================================================================
# 1. Main Domain Reset (250 MHz, driven by cpu_reset)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 main_rst

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
# 5. DCIM Buffer Controllers (unchanged from before)
# ==============================================================================

# Sub-level SmartConnect for DCIM IBUF (1 slave → 1 master)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 dcim_ibuf_smc
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {1} \
] [get_bd_cells dcim_ibuf_smc]

# Sub-level SmartConnect for DCIM OBUF (1 slave → 1 master)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 dcim_obuf_smc
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {1} \
] [get_bd_cells dcim_obuf_smc]

# 1 IBUF controller (lite: 1 group, 2MB, 128-bit)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 dcim_ibuf_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
] [get_bd_cells dcim_ibuf_ctrl_0]

# 1 OBUF controller (lite: 1 group, 16MB, 128-bit)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 dcim_obuf_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
] [get_bd_cells dcim_obuf_ctrl_0]

# ==============================================================================
# 6. VPU Weight Buffer Controller (WB only; GB removed in lite)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_wb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
] [get_bd_cells vpu_wb_ctrl]

# ==============================================================================
# 7. VPU Control Infrastructure (RTL Module References)
# ==============================================================================
create_bd_cell -type module -reference VPU_AXI_Regs vpu_regs
create_bd_cell -type module -reference INST_BRAM inst_bram
create_bd_cell -type module -reference INST_Decoder_wrapper inst_decoder
create_bd_cell -type module -reference CDMA_Controller_wrapper cdma_ctrl
