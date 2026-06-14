# ==============================================================================
# connect.tcl - Integrated DCIM + VPU + HBM system connections
# ==============================================================================

# ==============================================================================
# PCIe / XDMA infrastructure (unchanged)
# ==============================================================================

# pcie_refclk <-> util_ds_buf
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf
set_property -dict [list \
  CONFIG.C_BUF_TYPE {IBUFDSGTE} \
  CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
  CONFIG.USE_BOARD_FLOW {true} \
] [get_bd_cells util_ds_buf]

# pci_express_x8 <-> xdma
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x8
connect_bd_intf_net [get_bd_intf_ports pci_express_x8] [get_bd_intf_pins xdma_0/pcie_mgt]

# cpu_reset <-> xdma_inv <-> xdma
create_bd_port -dir I -type rst cpu_reset
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports cpu_reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins xdma_inv/Op1]
connect_bd_net [get_bd_pins xdma_inv/Res] [get_bd_pins xdma_0/sys_rst_n]

# pcie_refclk <-> util_ds_buf <-> xdma
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk
set_property CONFIG.FREQ_HZ 100000000 [get_bd_intf_ports pcie_refclk]
connect_bd_intf_net [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]

# xdma_constant <-> xdma
connect_bd_net [get_bd_pins xdma_constant/dout] [get_bd_pins xdma_0/usr_irq_req]

# ==============================================================================
# SmartConnect: NUM_SI=2, NUM_MI=8
#   S00 = XDMA M_AXI
#   S01 = CDMA M_AXI
#   M00 = HBM (via hbm_axi_cc)
#   M01 = dcim_ibuf_smc (→ 8 IBUF controllers)
#   M02 = dcim_obuf_smc (→ 8 OBUF controllers)
#   M03 = vpu_gb_ctrl
#   M04 = vpu_wb_ctrl
#   M05 = inst_bram/s_axi
#   M06 = vpu_regs/s_axi
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mem_smc
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {7} \
] [get_bd_cells axi_mem_smc]

# Slave ports
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S01_AXI]

# M00: HBM via clock converter
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M00_AXI] [get_bd_intf_pins hbm_axi_cc/S_AXI]
connect_bd_intf_net [get_bd_intf_pins hbm_axi_cc/M_AXI] [get_bd_intf_pins hbm_0/SAXI_00]

# M01: DCIM IBUF sub-SmartConnect (→ 8 IBUF controllers)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M01_AXI] [get_bd_intf_pins dcim_ibuf_smc/S00_AXI]

# M02: DCIM OBUF sub-SmartConnect (→ 8 OBUF controllers)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M02_AXI] [get_bd_intf_pins dcim_obuf_smc/S00_AXI]

# M03: VPU Global Buffer BRAM controller
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M03_AXI] [get_bd_intf_pins vpu_gb_ctrl/S_AXI]

# M04: VPU Weight Buffer BRAM controller
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M04_AXI] [get_bd_intf_pins vpu_wb_ctrl/S_AXI]

# M05: Instruction BRAM (AXI write from XDMA, wire read from INST_Decoder)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M05_AXI] [get_bd_intf_pins inst_bram/S_AXI]

# M06: VPU AXI Register interface
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M06_AXI] [get_bd_intf_pins vpu_regs/S_AXI]

# ==============================================================================
# CDMA_Controller (cdma_ctrl): point-to-point S_AXI_LITE
# cdma_ctrl 的 AXI-Lite master 接口 (cdma_axilm) 直连 CDMA IP S_AXI_LITE
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins cdma_ctrl/cdma_axilm] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]

# ==============================================================================
# HBM clock and reset connections
# ==============================================================================
# main_rst: 主时钟域 (250 MHz) 同步复位
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins main_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins main_rst/ext_reset_in]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins main_rst/dcm_locked]

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_axi_clk_wiz/clk_in1]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_axi_clk_wiz/reset]

# HBM APB reset (100 MHz domain)
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1] [get_bd_pins hbm_apb_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_apb_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/locked] [get_bd_pins hbm_apb_rst/dcm_locked]

# HBM AXI reset (450 MHz domain)
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_axi_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_axi_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/locked] [get_bd_pins hbm_axi_rst/dcm_locked]

# HBM ref clock (100 MHz)
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1] [get_bd_pins hbm_0/HBM_REF_CLK_0]

# HBM APB clock/reset (for MC initialization)
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1] [get_bd_pins hbm_0/APB_0_PCLK]
connect_bd_net [get_bd_pins hbm_apb_rst/peripheral_aresetn] [get_bd_pins hbm_0/APB_0_PRESET_N]

# HBM SAXI_00 AXI clock = 450 MHz (from hbm_axi_clk_wiz)
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_0/AXI_00_ACLK]
connect_bd_net [get_bd_pins hbm_axi_rst/peripheral_aresetn] [get_bd_pins hbm_0/AXI_00_ARESET_N]

# AXI Clock Converter: S_AXI side = 250 MHz (XDMA), M_AXI side = 450 MHz (HBM)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_axi_cc/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins hbm_axi_cc/s_axi_aresetn]
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_axi_cc/m_axi_aclk]
connect_bd_net [get_bd_pins hbm_axi_rst/peripheral_aresetn] [get_bd_pins hbm_axi_cc/m_axi_aresetn]

# ==============================================================================
# DCIM IBUF: 1 个 AXI BRAM Controller → dcim_array_0（广播写入所有 Group）
# 改造说明：原 8 路 → 1 路，软件写一次，硬件广播到全部 8 组 IBUF
# ==============================================================================
# Sub-SmartConnect M00_AXI -> BRAM Controller S_AXI
connect_bd_intf_net [get_bd_intf_pins dcim_ibuf_smc/M00_AXI] \
                    [get_bd_intf_pins dcim_ibuf_ctrl_0/S_AXI]
# BRAM Controller -> DCIM Array 单一 IBUF 广播端口
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_en_a]     [get_bd_pins dcim_array_0/ibuf_ext_ena]
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_we_a]     [get_bd_pins dcim_array_0/ibuf_ext_wea]
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_addr_a]   [get_bd_pins dcim_array_0/ibuf_ext_addra]
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_wrdata_a] [get_bd_pins dcim_array_0/ibuf_ext_dina]
connect_bd_net [get_bd_pins dcim_array_0/ibuf_ext_douta]    [get_bd_pins dcim_ibuf_ctrl_0/bram_rddata_a]
# Clock/reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins dcim_ibuf_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins dcim_ibuf_ctrl_0/s_axi_aresetn]

# ==============================================================================
# DCIM OBUF: 1 个 AXI BRAM Controller → dcim_array_0 统一 OBUF 端口
# 改造说明：原 8 路 → 1 路统一端口
# 外部地址 obuf_ext_addra[OBUF_EXT_ADDR_BITS+3:4] 高 3 位为 Group 选择
# AXI 访问端口地址宽度需覆盖 21-bit 字节地址（17-bit word + 4-bit byte-sel）
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins dcim_obuf_smc/M00_AXI] \
                    [get_bd_intf_pins dcim_obuf_ctrl_0/S_AXI]
connect_bd_net [get_bd_pins dcim_obuf_ctrl_0/bram_en_a]     [get_bd_pins dcim_array_0/obuf_ext_ena]
connect_bd_net [get_bd_pins dcim_obuf_ctrl_0/bram_we_a]     [get_bd_pins dcim_array_0/obuf_ext_wea]
connect_bd_net [get_bd_pins dcim_obuf_ctrl_0/bram_addr_a]   [get_bd_pins dcim_array_0/obuf_ext_addra]
connect_bd_net [get_bd_pins dcim_obuf_ctrl_0/bram_wrdata_a] [get_bd_pins dcim_array_0/obuf_ext_dina]
connect_bd_net [get_bd_pins dcim_array_0/obuf_ext_douta]    [get_bd_pins dcim_obuf_ctrl_0/bram_rddata_a]
connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins dcim_obuf_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins dcim_obuf_ctrl_0/s_axi_aresetn]

# Sub-SmartConnect clock/reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins dcim_ibuf_smc/aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins dcim_ibuf_smc/aresetn]
connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins dcim_obuf_smc/aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins dcim_obuf_smc/aresetn]

# ==============================================================================
# VPU GB/WB: AXI BRAM Controller BRAM_PORTA → vpu_0 BRAM interfaces
# VPU uses X_INTERFACE_INFO annotated BRAM ports → connect as interface nets
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins vpu_gb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/gb_bram]
connect_bd_intf_net [get_bd_intf_pins vpu_wb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/wb_bram]

# ==============================================================================
# INST_Decoder <-> inst_bram (wire read interface)
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/inst_rd_addr] [get_bd_pins inst_bram/inst_rd_addr]
connect_bd_net [get_bd_pins inst_bram/inst_rd_data]    [get_bd_pins inst_decoder/inst_rd_data]

# ==============================================================================
# INST_Decoder <-> CDMA_Controller
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/cdma_start]          [get_bd_pins cdma_ctrl/cdma_start]
connect_bd_net [get_bd_pins inst_decoder/cdma_config_valid]   [get_bd_pins cdma_ctrl/cdma_config_valid]
connect_bd_net [get_bd_pins cdma_ctrl/cdma_config_ready]      [get_bd_pins inst_decoder/cdma_config_ready]
connect_bd_net [get_bd_pins inst_decoder/cdma_src_addr_msb]   [get_bd_pins cdma_ctrl/cdma_src_addr_msb]
connect_bd_net [get_bd_pins inst_decoder/cdma_src_addr_lsb]   [get_bd_pins cdma_ctrl/cdma_src_addr_lsb]
connect_bd_net [get_bd_pins inst_decoder/cdma_dst_addr_msb]   [get_bd_pins cdma_ctrl/cdma_dst_addr_msb]
connect_bd_net [get_bd_pins inst_decoder/cdma_dst_addr_lsb]   [get_bd_pins cdma_ctrl/cdma_dst_addr_lsb]
connect_bd_net [get_bd_pins inst_decoder/cdma_length]         [get_bd_pins cdma_ctrl/cdma_length]

# ==============================================================================
# INST_Decoder <-> VPU (vpu_0)
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/vpu_start]      [get_bd_pins vpu_0/vpu_start]
connect_bd_net [get_bd_pins vpu_0/ready]                 [get_bd_pins inst_decoder/vpu_ready]
connect_bd_net [get_bd_pins inst_decoder/vpu_unit_choose] [get_bd_pins vpu_0/unit_choose]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_addr]   [get_bd_pins vpu_0/src_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_src2_addr]  [get_bd_pins vpu_0/src2_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_c]      [get_bd_pins vpu_0/src_c]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_h]      [get_bd_pins vpu_0/src_h]
connect_bd_net [get_bd_pins inst_decoder/vpu_src_w]      [get_bd_pins vpu_0/src_w]
connect_bd_net [get_bd_pins inst_decoder/vpu_bias_addr]  [get_bd_pins vpu_0/bias_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_scale_addr] [get_bd_pins vpu_0/scale_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_dst_addr]   [get_bd_pins vpu_0/dst_addr]
connect_bd_net [get_bd_pins inst_decoder/vpu_addr_break] [get_bd_pins vpu_0/addr_break]
connect_bd_net [get_bd_pins inst_decoder/vpu_addr_s]     [get_bd_pins vpu_0/addr_s]
connect_bd_net [get_bd_pins inst_decoder/vpu_addr_t]     [get_bd_pins vpu_0/addr_t]

# ==============================================================================
# INST_Decoder <-> DCIM Array (dcim_array_0) via direct config write interface
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/dcim_cfg_wr_en]   [get_bd_pins dcim_array_0/cfg_wr_en]
connect_bd_net [get_bd_pins inst_decoder/dcim_cfg_wr_addr] [get_bd_pins dcim_array_0/cfg_wr_addr]
connect_bd_net [get_bd_pins inst_decoder/dcim_cfg_wr_data] [get_bd_pins dcim_array_0/cfg_wr_data]
connect_bd_net [get_bd_pins dcim_array_0/done]             [get_bd_pins inst_decoder/dcim_ready]

# ==============================================================================
# INST_Decoder <-> VPU_AXI_Regs (vpu_regs)
# ==============================================================================
connect_bd_net [get_bd_pins vpu_regs/decoder_start]  [get_bd_pins inst_decoder/decoder_start]
connect_bd_net [get_bd_pins vpu_regs/inst_count]     [get_bd_pins inst_decoder/inst_count]
connect_bd_net [get_bd_pins inst_decoder/decoder_busy]   [get_bd_pins vpu_regs/decoder_busy]
connect_bd_net [get_bd_pins inst_decoder/decoder_done]   [get_bd_pins vpu_regs/decoder_done]
connect_bd_net [get_bd_pins inst_decoder/decoder_status] [get_bd_pins vpu_regs/decoder_status]
connect_bd_net [get_bd_pins vpu_0/ready]                 [get_bd_pins vpu_regs/ready]

# ==============================================================================
# Common clock/reset from XDMA (250 MHz)
# ==============================================================================

# SmartConnect
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_mem_smc/aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_mem_smc/aresetn]

# AXI BRAM controllers
foreach axi_slave {vpu_gb_ctrl vpu_wb_ctrl} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${axi_slave}/s_axi_aclk]
  connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins ${axi_slave}/s_axi_aresetn]
}

# inst_bram 时钟（使用 clk/rst_n）
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins inst_bram/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins inst_bram/rst_n]

# VPU_AXI_Regs (使用 clk/rst_n，不是 s_axi_aclk)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_regs/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins vpu_regs/rst_n]

# CDMA
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
if {[llength [get_bd_pins -quiet axi_cdma_0/m_axi_aresetn]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/m_axi_aresetn]
}

# CDMA_Controller (使用 main_rst 同步复位)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins cdma_ctrl/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins cdma_ctrl/rst_n]

# DCIM Array (使用 main_rst 同步复位)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_array_0/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins dcim_array_0/rst_n]

# VPU (使用 main_rst 同步复位)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_0/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins vpu_0/rst_n]

# INST_Decoder (使用 main_rst 同步复位)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins inst_decoder/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins inst_decoder/rst_n]
