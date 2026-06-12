# ==============================================================================
# connect.tcl - chip-v3: distributed tile_ibuf + tile_obuf + VPU_BUF system connections
#
# chip-v3 变更:
#   - 删除 dcim_ibuf_smc / dcim_ibuf_ctrl_0 → dcim_array_0 IBUF 连接
#   - 新增 4x tile_ibuf_ctrl → dcim_array_0 tile_ibufN 连接
#   - 保留 4x tile_obuf_ctrl → dcim_array_0 tile_obufN 连接
#   - 保留 vpu_buf_ctrl → vpu_0 vpu_buf_bram 连接
#   - SmartConnect NUM_MI = 13
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
# SmartConnect: NUM_SI=2, NUM_MI=13
#   S00 = XDMA M_AXI
#   S01 = CDMA M_AXI
#   M00 = tile_ibuf_ctrl_0 (512KB)
#   M01 = tile_ibuf_ctrl_1 (512KB)
#   M02 = tile_ibuf_ctrl_2 (512KB)
#   M03 = tile_ibuf_ctrl_3 (512KB)
#   M04 = tile_obuf_ctrl_0 (256KB)
#   M05 = tile_obuf_ctrl_1 (256KB)
#   M06 = tile_obuf_ctrl_2 (256KB)
#   M07 = tile_obuf_ctrl_3 (256KB)
#   M08 = vpu_buf_ctrl (8MB)
#   M09 = vpu_wb_ctrl (32KB)
#   M10 = inst_bram/s_axi
#   M11 = vpu_regs/s_axi
#   M12 = hbm_axi_cc (→ HBM SAXI_00, interleaved 4GB)
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mem_smc
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {13} \
] [get_bd_cells axi_mem_smc]

# Slave ports
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S01_AXI]

# M00~M03: tile_ibuf_ctrl_0..3
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M00_AXI] [get_bd_intf_pins tile_ibuf_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M01_AXI] [get_bd_intf_pins tile_ibuf_ctrl_1/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M02_AXI] [get_bd_intf_pins tile_ibuf_ctrl_2/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M03_AXI] [get_bd_intf_pins tile_ibuf_ctrl_3/S_AXI]

# M04~M07: tile_obuf_ctrl_0..3
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M04_AXI] [get_bd_intf_pins tile_obuf_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M05_AXI] [get_bd_intf_pins tile_obuf_ctrl_1/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M06_AXI] [get_bd_intf_pins tile_obuf_ctrl_2/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M07_AXI] [get_bd_intf_pins tile_obuf_ctrl_3/S_AXI]

# M08: VPU_BUF controller
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M08_AXI] [get_bd_intf_pins vpu_buf_ctrl/S_AXI]

# M09: VPU Weight Buffer BRAM controller
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M09_AXI] [get_bd_intf_pins vpu_wb_ctrl/S_AXI]

# M10: Instruction BRAM controller
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M10_AXI] [get_bd_intf_pins inst_bram_ctrl/S_AXI]

# M11: VPU AXI Register interface
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M11_AXI] [get_bd_intf_pins vpu_regs/S_AXI]

# ==============================================================================
# CDMA_Controller → CDMA S_AXI_LITE
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins cdma_ctrl/cdma_axilm] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]

# ==============================================================================
# Main reset connection
# ==============================================================================
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins main_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins main_rst/ext_reset_in]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins main_rst/dcm_locked]

# ==============================================================================
# tile_ibuf[0..3]: AXI BRAM Controller → dcim_array_0
# ==============================================================================
foreach t {0 1 2 3} {
  connect_bd_net [get_bd_pins tile_ibuf_ctrl_${t}/bram_en_a]     [get_bd_pins dcim_array_0/tile_ibuf${t}_ext_ena]
  connect_bd_net [get_bd_pins tile_ibuf_ctrl_${t}/bram_we_a]     [get_bd_pins dcim_array_0/tile_ibuf${t}_ext_wea]
  connect_bd_net [get_bd_pins tile_ibuf_ctrl_${t}/bram_addr_a]   [get_bd_pins dcim_array_0/tile_ibuf${t}_ext_addra]
  connect_bd_net [get_bd_pins tile_ibuf_ctrl_${t}/bram_wrdata_a] [get_bd_pins dcim_array_0/tile_ibuf${t}_ext_dina]
  connect_bd_net [get_bd_pins dcim_array_0/tile_ibuf${t}_ext_douta] [get_bd_pins tile_ibuf_ctrl_${t}/bram_rddata_a]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins tile_ibuf_ctrl_${t}/s_axi_aclk]
  connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins tile_ibuf_ctrl_${t}/s_axi_aresetn]
}

# ==============================================================================
# tile_obuf[0..3]: AXI BRAM Controller → dcim_array_0
# ==============================================================================
foreach t {0 1 2 3} {
  connect_bd_net [get_bd_pins tile_obuf_ctrl_${t}/bram_en_a]     [get_bd_pins dcim_array_0/tile_obuf${t}_ext_ena]
  connect_bd_net [get_bd_pins tile_obuf_ctrl_${t}/bram_we_a]     [get_bd_pins dcim_array_0/tile_obuf${t}_ext_wea]
  connect_bd_net [get_bd_pins tile_obuf_ctrl_${t}/bram_addr_a]   [get_bd_pins dcim_array_0/tile_obuf${t}_ext_addra]
  connect_bd_net [get_bd_pins tile_obuf_ctrl_${t}/bram_wrdata_a] [get_bd_pins dcim_array_0/tile_obuf${t}_ext_dina]
  connect_bd_net [get_bd_pins dcim_array_0/tile_obuf${t}_ext_douta] [get_bd_pins tile_obuf_ctrl_${t}/bram_rddata_a]
  connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins tile_obuf_ctrl_${t}/s_axi_aclk]
  connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins tile_obuf_ctrl_${t}/s_axi_aresetn]
}

# ==============================================================================
# VPU_BUF: AXI BRAM Controller → vpu_0/vpu_buf_bram (BRAM interface)
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins vpu_buf_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/vpu_buf_bram]
connect_bd_net [get_bd_pins xdma_0/axi_aclk]            [get_bd_pins vpu_buf_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins vpu_buf_ctrl/s_axi_aresetn]

# ==============================================================================
# VPU WB: AXI BRAM Controller → vpu_0/wb_bram (BRAM interface)
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins vpu_wb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/wb_bram]

# ==============================================================================
# inst_bram_ctrl → inst_bram Port A (BRAM interface)
# ==============================================================================
connect_bd_net [get_bd_pins inst_bram_ctrl/bram_en_a]     [get_bd_pins inst_bram/bram_en_a]
connect_bd_net [get_bd_pins inst_bram_ctrl/bram_we_a]     [get_bd_pins inst_bram/bram_we_a]
connect_bd_net [get_bd_pins inst_bram_ctrl/bram_addr_a]   [get_bd_pins inst_bram/bram_addr_a]
connect_bd_net [get_bd_pins inst_bram_ctrl/bram_wrdata_a] [get_bd_pins inst_bram/bram_wrdata_a]
connect_bd_net [get_bd_pins inst_bram/bram_rddata_a]      [get_bd_pins inst_bram_ctrl/bram_rddata_a]

# ==============================================================================
# INST_Decoder <-> inst_bram (Port B: direct read interface)
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
# INST_Decoder <-> DCIM Array (dcim_array_0)
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

# AXI BRAM controllers
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_wb_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins vpu_wb_ctrl/s_axi_aresetn]

# inst_bram_ctrl
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins inst_bram_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins main_rst/peripheral_aresetn] [get_bd_pins inst_bram_ctrl/s_axi_aresetn]

# inst_bram
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
# ==============================================================================

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_ref_clk_wiz/clk_in1]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_axi_clk_wiz/clk_in1]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_ref_clk_wiz/reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_axi_clk_wiz/reset]

connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1] [get_bd_pins hbm_0/HBM_REF_CLK_0]
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1] [get_bd_pins hbm_0/APB_0_PCLK]

connect_bd_net [get_bd_pins hbm_ref_clk_wiz/clk_out1]  [get_bd_pins hbm_apb_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset]                 [get_bd_pins hbm_apb_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_ref_clk_wiz/locked]    [get_bd_pins hbm_apb_rst/dcm_locked]
connect_bd_net [get_bd_pins hbm_apb_rst/peripheral_aresetn] [get_bd_pins hbm_0/APB_0_PRESET_N]

connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_rst/slowest_sync_clk]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins hbm_rst/ext_reset_in]
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/locked] [get_bd_pins hbm_rst/dcm_locked]

connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_0/AXI_00_ACLK]
connect_bd_net [get_bd_pins hbm_rst/peripheral_aresetn] [get_bd_pins hbm_0/AXI_00_ARESET_N]

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins hbm_axi_cc/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins hbm_axi_cc/s_axi_aresetn]
connect_bd_net [get_bd_pins hbm_axi_clk_wiz/clk_out1] [get_bd_pins hbm_axi_cc/m_axi_aclk]
connect_bd_net [get_bd_pins hbm_rst/peripheral_aresetn] [get_bd_pins hbm_axi_cc/m_axi_aresetn]

# SmartConnect M12 → AXI Clock Converter → HBM SAXI_00 (interleaved, full 4GB)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M12_AXI] [get_bd_intf_pins hbm_axi_cc/S_AXI]
connect_bd_intf_net [get_bd_intf_pins hbm_axi_cc/M_AXI] [get_bd_intf_pins hbm_0/SAXI_00]
