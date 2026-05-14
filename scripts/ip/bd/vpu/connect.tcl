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
set_property CONFIG.NUM_MI {5} [get_bd_cells axi_mem_smc]

connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI]     [get_bd_intf_pins axi_mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S01_AXI]

# M00: staging global_bram (通过 axi_bram_ctrl)
# M01: VPU GB (直接连接 vpu_0/gb_axis AXI 接口)
# M02: VPU WB (直接连接 vpu_0/wb_axis AXI 接口)
# M03: CDMA regs
# M04: VPU_AXI_Regs (配置 + 状态)
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M00_AXI] [get_bd_intf_pins global_bram_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M01_AXI] [get_bd_intf_pins vpu_0/gb_axis]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M02_AXI] [get_bd_intf_pins vpu_0/wb_axis]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M03_AXI] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M04_AXI] [get_bd_intf_pins vpu_regs/s_axi]

connect_bd_intf_net [get_bd_intf_pins global_bram/BRAM_PORTA] [get_bd_intf_pins global_bram_ctrl/BRAM_PORTA]

# ==============================================================================
# VPU_AXI_Regs -> Global_VPU_top 配置/状态
# ==============================================================================
connect_bd_net [get_bd_pins vpu_regs/vpu_start]   [get_bd_pins vpu_0/vpu_start]
connect_bd_net [get_bd_pins vpu_regs/unit_choose] [get_bd_pins vpu_0/unit_choose]
connect_bd_net [get_bd_pins vpu_regs/src_addr]    [get_bd_pins vpu_0/src_addr]
connect_bd_net [get_bd_pins vpu_regs/src2_addr]   [get_bd_pins vpu_0/src2_addr]
connect_bd_net [get_bd_pins vpu_regs/src_c]       [get_bd_pins vpu_0/src_c]
connect_bd_net [get_bd_pins vpu_regs/src_h]       [get_bd_pins vpu_0/src_h]
connect_bd_net [get_bd_pins vpu_regs/src_w]       [get_bd_pins vpu_0/src_w]
connect_bd_net [get_bd_pins vpu_regs/bias_addr]   [get_bd_pins vpu_0/bias_addr]
connect_bd_net [get_bd_pins vpu_regs/scale_addr]  [get_bd_pins vpu_0/scale_addr]
connect_bd_net [get_bd_pins vpu_regs/dst_addr]    [get_bd_pins vpu_0/dst_addr]
connect_bd_net [get_bd_pins vpu_regs/addr_break]  [get_bd_pins vpu_0/addr_break]
connect_bd_net [get_bd_pins vpu_regs/addr_s]      [get_bd_pins vpu_0/addr_s]
connect_bd_net [get_bd_pins vpu_regs/addr_t]      [get_bd_pins vpu_0/addr_t]
connect_bd_net [get_bd_pins vpu_0/ready]          [get_bd_pins vpu_regs/ready]

# ==============================================================================
# 时钟/复位
# ==============================================================================
connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins axi_mem_smc/aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_mem_smc/aresetn]

connect_bd_net [get_bd_pins xdma_0/axi_aclk]    [get_bd_pins global_bram_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins global_bram_ctrl/s_axi_aresetn]

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
