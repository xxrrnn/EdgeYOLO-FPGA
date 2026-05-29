# ==============================================================================
# connect.tcl - lite version: DCIM + VPU system connections (no HBM, no GB)
#
# Lite changes vs chip:
#   1. HBM 完全删除
#   2. VPU GB 删除（vpu_0 不再有 gb_bram 接口）
#   3. SmartConnect NUM_MI 从 7 降到 5
#   4. OBUF 扩大到 16MB（在 obuf_ctrl 端不影响连接，地址由 BD 自动推导）
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
# SmartConnect: NUM_SI=2, NUM_MI=6 (lite+HBM: added M05 for HBM interleave)
#   S00 = XDMA M_AXI
#   S01 = CDMA M_AXI
#   M00 = dcim_ibuf_smc (→ 1 IBUF controller, 2MB)
#   M01 = dcim_obuf_smc (→ 1 OBUF controller, 16MB)
#   M02 = vpu_wb_ctrl   (32KB)
#   M03 = inst_bram/s_axi
#   M04 = vpu_regs/s_axi
#   M05 = hbm_axi_cc    (→ HBM SAXI_00, interleaved 4GB view)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mem_smc
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {6} \
] [get_bd_cells axi_mem_smc]

# Slave ports
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S01_AXI]

# M00: DCIM IBUF sub-SmartConnect
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M00_AXI] [get_bd_intf_pins dcim_ibuf_smc/S00_AXI]

# M01: DCIM OBUF sub-SmartConnect
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M01_AXI] [get_bd_intf_pins dcim_obuf_smc/S00_AXI]

# M02: VPU Weight Buffer BRAM controller
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M02_AXI] [get_bd_intf_pins vpu_wb_ctrl/S_AXI]

# M03: Instruction BRAM (AXI write from XDMA, wire read from INST_Decoder)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M03_AXI] [get_bd_intf_pins inst_bram/S_AXI]

# M04: VPU AXI Register interface
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M04_AXI] [get_bd_intf_pins vpu_regs/S_AXI]

# ==============================================================================
# CDMA_Controller (cdma_ctrl): point-to-point S_AXI_LITE
# cdma_ctrl 的 AXI-Lite master 接口 (cdma_axilm) 直连 CDMA IP S_AXI_LITE
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins cdma_ctrl/cdma_axilm] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]

# ==============================================================================
# Main reset connection
# ==============================================================================
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins main_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins main_rst/ext_reset_in]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins main_rst/dcm_locked]

# ==============================================================================
# DCIM IBUF: 1 AXI BRAM Controller → dcim_array_0
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins dcim_ibuf_smc/M00_AXI] \
                    [get_bd_intf_pins dcim_ibuf_ctrl_0/S_AXI]
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_en_a]     [get_bd_pins dcim_array_0/ibuf_ext_ena]
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_we_a]     [get_bd_pins dcim_array_0/ibuf_ext_wea]
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_addr_a]   [get_bd_pins dcim_array_0/ibuf_ext_addra]
connect_bd_net [get_bd_pins dcim_ibuf_ctrl_0/bram_wrdata_a] [get_bd_pins dcim_array_0/ibuf_ext_dina]
connect_bd_net [get_bd_pins dcim_array_0/ibuf_ext_douta]    [get_bd_pins dcim_ibuf_ctrl_0/bram_rddata_a]
# Clock/reset
connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins dcim_ibuf_ctrl_0/s_axi_aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins dcim_ibuf_ctrl_0/s_axi_aresetn]

# ==============================================================================
# DCIM OBUF: 1 AXI BRAM Controller → dcim_array_0
# lite: OBUF 16MB (20-bit word addr, 24-bit byte addr)
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
# VPU WB: AXI BRAM Controller BRAM_PORTA → vpu_0 BRAM interface
# lite: GB 已删除，VPU 通过 obuf_rd_* 直接读 DCIM OBUF
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins vpu_wb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/wb_bram]

# ==============================================================================
# VPU obuf 访问接口（lite 新增）
# VPU 所有 unit（im2col, mp, us, qa, dqa, ad, nn）通过 256-bit vpu_obuf_* 端口
# 直接读写 DCIM OBUF（feature buffer）；VPU 不访问 IBUF
# ==============================================================================
# VPU OBUF 256-bit 读写端口
connect_bd_net [get_bd_pins vpu_0/obuf_addr] [get_bd_pins dcim_array_0/vpu_obuf_addr]
connect_bd_net [get_bd_pins vpu_0/obuf_en]   [get_bd_pins dcim_array_0/vpu_obuf_en]
connect_bd_net [get_bd_pins vpu_0/obuf_we]   [get_bd_pins dcim_array_0/vpu_obuf_we]
connect_bd_net [get_bd_pins vpu_0/obuf_din]  [get_bd_pins dcim_array_0/vpu_obuf_din]
connect_bd_net [get_bd_pins dcim_array_0/vpu_obuf_dout]     [get_bd_pins vpu_0/obuf_dout]
connect_bd_net [get_bd_pins dcim_array_0/vpu_obuf_rd_valid] [get_bd_pins vpu_0/obuf_rd_valid]

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
connect_bd_net [get_bd_pins inst_decoder/vpu_flags]      [get_bd_pins vpu_0/vpu_flags]

# ==============================================================================
# INST_Decoder <-> DCIM Array (dcim_array_0) via direct config write interface
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/dcim_cfg_wr_en]   [get_bd_pins dcim_array_0/cfg_wr_en]
connect_bd_net [get_bd_pins inst_decoder/dcim_cfg_wr_addr] [get_bd_pins dcim_array_0/cfg_wr_addr]
connect_bd_net [get_bd_pins inst_decoder/dcim_cfg_wr_data] [get_bd_pins dcim_array_0/cfg_wr_data]
connect_bd_net [get_bd_pins dcim_array_0/ready]            [get_bd_pins inst_decoder/dcim_ready]

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

# AXI BRAM controllers (lite: GB 已删除，只剩 WB)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_wb_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins vpu_wb_ctrl/s_axi_aresetn]

# inst_bram 时钟
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins inst_bram/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins inst_bram/rst_n]

# VPU_AXI_Regs
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_regs/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins vpu_regs/rst_n]

# CDMA
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
if {[llength [get_bd_pins -quiet axi_cdma_0/m_axi_aresetn]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/m_axi_aresetn]
}

# CDMA_Controller
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins cdma_ctrl/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins cdma_ctrl/rst_n]

# DCIM Array
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins dcim_array_0/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins dcim_array_0/rst_n]

# VPU
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_0/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins vpu_0/rst_n]

# INST_Decoder
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins inst_decoder/clk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins inst_decoder/rst_n]

# ==============================================================================
# HBM Clock/Reset/AXI connections (1 stack, interleaved via SAXI_00)
# APB_0_PCLK 必须连接 ref clock (100 MHz)，否则 BD 41-758 warning
# ==============================================================================

# Clock wizard inputs (250 MHz from XDMA → 100 MHz ref + 450 MHz AXI)
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_axi_clk_wiz/clk_in1]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_axi_clk_wiz/reset]

# HBM reference clock (100 MHz) → HBM_REF_CLK_0
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1] [get_bd_pins hbm_0/HBM_REF_CLK_0]

# APB_0_PCLK: HBM APB 监控时钟，必须连接 ref clock（100 MHz）
# 即使 USER_APB_EN=false，该时钟引脚仍然存在，不连接会触发 BD 41-758
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1] [get_bd_pins hbm_0/APB_0_PCLK]

# APB_0_PRESET_N: HBM APB 复位（active-low），必须连接，否则 BD 41-759
# hbm_apb_rst 使用 ref clock (100 MHz)，locked 来自 hbm_ref_clk_wiz
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1]  [get_bd_pins hbm_apb_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset]                 [get_bd_pins hbm_apb_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/locked]    [get_bd_pins hbm_apb_rst/dcm_locked]
connect_bd_net [get_bd_pins hbm_apb_rst/peripheral_aresetn] [get_bd_pins hbm_0/APB_0_PRESET_N]

# HBM domain reset (driven by 450 MHz AXI clock)
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/locked] [get_bd_pins hbm_rst/dcm_locked]

# HBM AXI port 0 clock and reset (interleaved port: sees all 4GB)
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_0/AXI_00_ACLK]
connect_bd_net [get_bd_pins hbm_rst/peripheral_aresetn] [get_bd_pins hbm_0/AXI_00_ARESET_N]

# AXI Clock Converter: system 250 MHz → HBM 450 MHz
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_axi_cc/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins hbm_axi_cc/s_axi_aresetn]
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_axi_cc/m_axi_aclk]
connect_bd_net [get_bd_pins hbm_rst/peripheral_aresetn] [get_bd_pins hbm_axi_cc/m_axi_aresetn]

# SmartConnect M05 → AXI Clock Converter → HBM SAXI_00 (interleaved, full 4GB)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M05_AXI] [get_bd_intf_pins hbm_axi_cc/S_AXI]
connect_bd_intf_net [get_bd_intf_pins hbm_axi_cc/M_AXI] [get_bd_intf_pins hbm_0/SAXI_00]
