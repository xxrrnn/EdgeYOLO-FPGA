# pcie_refclk <-> util_ds_buf
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf
set_property -dict [list \
  CONFIG.C_BUF_TYPE {IBUFDSGTE} \
  CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
  CONFIG.USE_BOARD_FLOW {true} \
] [get_bd_cells util_ds_buf]

create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x8
connect_bd_intf_net [get_bd_intf_ports pci_express_x8] [get_bd_intf_pins xdma_0/pcie_mgt]

create_bd_port -dir I -type rst cpu_reset
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports cpu_reset]
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins xdma_inv/Op1]
connect_bd_net [get_bd_pins xdma_inv/Res] [get_bd_pins xdma_0/sys_rst_n]

create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk
set_property CONFIG.FREQ_HZ 100000000 [get_bd_intf_ports pcie_refclk]
connect_bd_intf_net [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_OUT] [get_bd_pins xdma_0/sys_clk_gt]
connect_bd_net [get_bd_pins util_ds_buf/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]

connect_bd_net [get_bd_pins xdma_constant/dout] [get_bd_pins xdma_0/usr_irq_req]

# ==============================================================================
# Smartconnect：S00=XDMA, S01=CDMA; M00-M04 见下
# ==============================================================================
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mem_smc
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {5} \
] [get_bd_cells axi_mem_smc]

connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI]     [get_bd_intf_pins axi_mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S01_AXI]

# M00: hbm_bram (暂时替代HBM，通过 global_bram_ctrl) - 外部数据暂存区
# M01: VPU GB (通过 vpu_gb_ctrl AXI BRAM Controller)
# M02: VPU WB (通过 vpu_wb_ctrl AXI BRAM Controller)
# M03: inst_bram (指令区，供 XDMA 写入指令)
# M04: VPU_AXI_Regs (配置 + 状态 + 解码器控制)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M00_AXI] [get_bd_intf_pins global_bram_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M01_AXI] [get_bd_intf_pins vpu_gb_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M02_AXI] [get_bd_intf_pins vpu_wb_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M03_AXI] [get_bd_intf_pins inst_bram/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M04_AXI] [get_bd_intf_pins vpu_regs/s_axi]

# Global BRAM 连接
connect_bd_intf_net [get_bd_intf_pins global_bram/BRAM_PORTA] [get_bd_intf_pins global_bram_ctrl/BRAM_PORTA]

# ==============================================================================
# VPU GB/WB BRAM Controller -> VPU 内部 TDP RAM
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins vpu_gb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/gb_bram]
connect_bd_intf_net [get_bd_intf_pins vpu_wb_ctrl/BRAM_PORTA] [get_bd_intf_pins vpu_0/wb_bram]

# ==============================================================================
# CDMA_Controller -> CDMA IP (AXI-Lite Master -> S_AXI_LITE)
# 注意：软件不再直接访问 CDMA 寄存器，由 INST_Decoder 通过 CDMA_Controller 控制
# ==============================================================================
connect_bd_intf_net [get_bd_intf_pins cdma_ctrl/cdma_axilm] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]

# ==============================================================================
# INST_Decoder -> CDMA_Controller (直接 wire 连接)
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/cdma_start]         [get_bd_pins cdma_ctrl/cdma_start]
connect_bd_net [get_bd_pins inst_decoder/cdma_config_valid]  [get_bd_pins cdma_ctrl/cdma_config_valid]
connect_bd_net [get_bd_pins cdma_ctrl/cdma_config_ready]     [get_bd_pins inst_decoder/cdma_config_ready]
connect_bd_net [get_bd_pins inst_decoder/cdma_src_addr_msb]  [get_bd_pins cdma_ctrl/cdma_src_addr_msb]
connect_bd_net [get_bd_pins inst_decoder/cdma_src_addr_lsb]  [get_bd_pins cdma_ctrl/cdma_src_addr_lsb]
connect_bd_net [get_bd_pins inst_decoder/cdma_dst_addr_msb]  [get_bd_pins cdma_ctrl/cdma_dst_addr_msb]
connect_bd_net [get_bd_pins inst_decoder/cdma_dst_addr_lsb]  [get_bd_pins cdma_ctrl/cdma_dst_addr_lsb]
connect_bd_net [get_bd_pins inst_decoder/cdma_length]        [get_bd_pins cdma_ctrl/cdma_length]

# ==============================================================================
# INST_Decoder -> inst_bram (直接 wire 读取)
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/inst_rd_addr] [get_bd_pins inst_bram/inst_rd_addr]
connect_bd_net [get_bd_pins inst_bram/inst_rd_data]    [get_bd_pins inst_decoder/inst_rd_data]

# ==============================================================================
# VPU_AXI_Regs -> INST_Decoder (控制接口)
# ==============================================================================
connect_bd_net [get_bd_pins vpu_regs/decoder_start]   [get_bd_pins inst_decoder/decoder_start]
connect_bd_net [get_bd_pins vpu_regs/inst_count]      [get_bd_pins inst_decoder/inst_count]
connect_bd_net [get_bd_pins inst_decoder/decoder_busy]   [get_bd_pins vpu_regs/decoder_busy]
connect_bd_net [get_bd_pins inst_decoder/decoder_done]   [get_bd_pins vpu_regs/decoder_done]
connect_bd_net [get_bd_pins inst_decoder/decoder_status] [get_bd_pins vpu_regs/decoder_status]

# ==============================================================================
# INST_Decoder -> VPU (直接 wire 连接)
# ==============================================================================
connect_bd_net [get_bd_pins inst_decoder/vpu_start]      [get_bd_pins vpu_0/vpu_start]
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
connect_bd_net [get_bd_pins vpu_0/ready]                 [get_bd_pins inst_decoder/vpu_ready]
connect_bd_net [get_bd_pins vpu_0/ready]                 [get_bd_pins vpu_regs/ready]

# ==============================================================================
# 时钟/复位
# ==============================================================================
connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins axi_mem_smc/aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_mem_smc/aresetn]

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins global_bram_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins global_bram_ctrl/s_axi_aresetn]

# VPU GB/WB BRAM Controller 时钟
connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins vpu_gb_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins vpu_gb_ctrl/s_axi_aresetn]
connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins vpu_wb_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins vpu_wb_ctrl/s_axi_aresetn]

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
if {[llength [get_bd_pins -quiet axi_cdma_0/m_axi_aresetn]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/m_axi_aresetn]
}

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins vpu_regs/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins vpu_regs/rst_n]

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins vpu_0/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins vpu_0/rst_n]

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins inst_bram/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins inst_bram/rst_n]

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins inst_decoder/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins inst_decoder/rst_n]

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins cdma_ctrl/clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins cdma_ctrl/rst_n]
