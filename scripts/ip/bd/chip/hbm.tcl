# ==============================================================================
# hbm.tcl - All IP and RTL module instantiations for the chip BD
#
# Contents:
#   1. HBM + clock infrastructure
#   2. PE buffer controllers (IBUF/OBUF)
#   3. VPU buffer controllers (GB/WB)
#   4. VPU control infrastructure (RTL modules)
#
# Parameters from vpu_defines.vh are available via parse_vpu_defines.tcl:
#   $::VPU_BANDWIDTH  = 256
#   $::GB_SIZE_BYTES  = 524288
#   $::WB_SIZE_BYTES  = 32768
# ==============================================================================

# ==============================================================================
# 1. Main Domain Reset (250 MHz, driven by cpu_reset)
# ==============================================================================
# 为主时钟域（250MHz）提供同步复位，所有 RTL 模块的 rst_n 均来自此输出
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 main_rst

# ==============================================================================
# 2. HBM + Clock Infrastructure
# ==============================================================================

# --- HBM ref clock wizard: 100 MHz from XDMA 250 MHz ---
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 hbm_ref_clk_wiz
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {250.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
  CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] [get_bd_cells hbm_ref_clk_wiz]

# --- HBM AXI clock wizard: 450 MHz from XDMA 250 MHz ---
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 hbm_axi_clk_wiz
set_property -dict [list \
  CONFIG.PRIM_IN_FREQ {250.000} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {450.000} \
  CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
  CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] [get_bd_cells hbm_axi_clk_wiz]

# --- Reset generators ---
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 hbm_apb_rst
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 hbm_axi_rst

# --- AXI Clock Converter: 250 MHz (SmartConnect) → 450 MHz (HBM) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 hbm_axi_cc
set_property -dict [list \
  CONFIG.ADDR_WIDTH {33} \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.ID_WIDTH {4} \
] [get_bd_cells hbm_axi_cc]

# --- HBM IP: 4GB, 1 stack, SAXI_00 only, 450 MHz AXI ---
create_bd_cell -type ip -vlnv xilinx.com:ip:hbm:1.0 hbm_0
set_property -dict [list \
  CONFIG.USER_HBM_DENSITY {4GB} \
  CONFIG.USER_HBM_STACK {1} \
  CONFIG.USER_AXI_CLK_FREQ {450} \
  CONFIG.USER_APB_EN {false} \
  CONFIG.USER_MC_ENABLE_APB_00 {false} \
  CONFIG.USER_SAXI_00 {true} \
] [get_bd_cells hbm_0]

# Disable SAXI ports 1-31
for {set idx 1} {$idx < 32} {incr idx} {
  set_property [format "CONFIG.USER_SAXI_%02d" $idx] {false} [get_bd_cells hbm_0]
}

# Enable first 8 MCs (1 stack)
for {set idx 0} {$idx < 8} {incr idx} {
  set_property [format "CONFIG.USER_MC_ENABLE_%02d" $idx] {TRUE} [get_bd_cells hbm_0]
  set_property [format "CONFIG.USER_PHY_ENABLE_%02d" $idx] {TRUE} [get_bd_cells hbm_0]
}
for {set idx 8} {$idx < 16} {incr idx} {
  set_property [format "CONFIG.USER_MC_ENABLE_%02d" $idx] {FALSE} [get_bd_cells hbm_0]
  set_property [format "CONFIG.USER_PHY_ENABLE_%02d" $idx] {FALSE} [get_bd_cells hbm_0]
}

# ==============================================================================
# 2. DCIM Buffer Controllers
#    IBUF: 1 AXI BRAM Controller（广播写入所有 8 Group，统一外部接口）
#    OBUF: 1 AXI BRAM Controller（扩展地址高3位=Group选择，统一外部接口）
# ==============================================================================

# Sub-level SmartConnect for DCIM IBUF (1 slave → 1 master: broadcast ctrl)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 dcim_ibuf_smc
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {1} \
] [get_bd_cells dcim_ibuf_smc]

# Sub-level SmartConnect for DCIM OBUF (1 slave → 1 master: unified ctrl)
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 dcim_obuf_smc
set_property -dict [list \
  CONFIG.NUM_SI {1} \
  CONFIG.NUM_MI {1} \
] [get_bd_cells dcim_obuf_smc]

# 1 IBUF controller (broadcast to all groups，128-bit)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 dcim_ibuf_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
] [get_bd_cells dcim_ibuf_ctrl_0]

# 1 OBUF controller (unified, extended address 21-bit byte addr：高3位选Group)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 dcim_obuf_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {128} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
] [get_bd_cells dcim_obuf_ctrl_0]

# ==============================================================================
# 3. VPU Buffer Controllers (GB/WB)
#    DATA_WIDTH matches VPU_BANDWIDTH (256 bits) from vpu_defines.vh
# ==============================================================================

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_gb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
] [get_bd_cells vpu_gb_ctrl]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 vpu_wb_ctrl
set_property -dict [list \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.ECC_TYPE {0} \
] [get_bd_cells vpu_wb_ctrl]

# ==============================================================================
# 4. VPU Control Infrastructure (RTL Module References)
# ==============================================================================

# --- VPU AXI-Lite register block ---
create_bd_cell -type module -reference VPU_AXI_Regs vpu_regs

# --- Instruction BRAM (dual-port: AXI write + decoder read) ---
create_bd_cell -type module -reference INST_BRAM inst_bram

# --- Instruction Decoder ---
create_bd_cell -type module -reference INST_Decoder_wrapper inst_decoder

# --- CDMA Controller ---
create_bd_cell -type module -reference CDMA_Controller_wrapper cdma_ctrl
