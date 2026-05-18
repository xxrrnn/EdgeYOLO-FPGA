# VPU Block Design connections
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

# Shared memory-mapped interconnect:
#   S00 = XDMA M_AXI
#   S01 = CDMA M_AXI
#   M00 = global_bram (VPU GB)
#   M01 = PE ibuf (VPU WB/input buffer)
#   M02 = PE obuf (VPU output buffer)
#   M03 = CDMA AXI-Lite registers
#   M04 = VPU control GPIO
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mem_smc
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {5} \
] [get_bd_cells axi_mem_smc]

connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S01_AXI]

connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M00_AXI] [get_bd_intf_pins vpu_global_bram_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M01_AXI] [get_bd_intf_pins vpu_pe_ibuf_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M02_AXI] [get_bd_intf_pins vpu_pe_obuf_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M03_AXI] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M04_AXI] [get_bd_intf_pins vpu_axi_regs_0/s_axil]

# AXI BRAM controllers <-> VPU BRAM ports
connect_bd_net [get_bd_pins vpu_global_bram_ctrl_0/bram_en_a]     [get_bd_pins vpu_0/gb_ena]
connect_bd_net [get_bd_pins vpu_global_bram_ctrl_0/bram_we_a]     [get_bd_pins vpu_0/gb_wea]
connect_bd_net [get_bd_pins vpu_global_bram_ctrl_0/bram_addr_a]   [get_bd_pins vpu_0/gb_addra]
connect_bd_net [get_bd_pins vpu_global_bram_ctrl_0/bram_wrdata_a] [get_bd_pins vpu_0/gb_dina]
connect_bd_net [get_bd_pins vpu_global_bram_ctrl_0/bram_rddata_a] [get_bd_pins vpu_0/gb_douta]

connect_bd_net [get_bd_pins vpu_pe_ibuf_ctrl_0/bram_en_a]     [get_bd_pins vpu_0/wb_ena]
connect_bd_net [get_bd_pins vpu_pe_ibuf_ctrl_0/bram_we_a]     [get_bd_pins vpu_0/wb_wea]
connect_bd_net [get_bd_pins vpu_pe_ibuf_ctrl_0/bram_addr_a]   [get_bd_pins vpu_0/wb_addra]
connect_bd_net [get_bd_pins vpu_pe_ibuf_ctrl_0/bram_wrdata_a] [get_bd_pins vpu_0/wb_dina]
connect_bd_net [get_bd_pins vpu_pe_ibuf_ctrl_0/bram_rddata_a] [get_bd_pins vpu_0/wb_douta]

connect_bd_net [get_bd_pins vpu_pe_obuf_ctrl_0/bram_en_a]     [get_bd_pins vpu_0/ob_ena]
connect_bd_net [get_bd_pins vpu_pe_obuf_ctrl_0/bram_we_a]     [get_bd_pins vpu_0/ob_wea]
connect_bd_net [get_bd_pins vpu_pe_obuf_ctrl_0/bram_addr_a]   [get_bd_pins vpu_0/ob_addra]
connect_bd_net [get_bd_pins vpu_pe_obuf_ctrl_0/bram_wrdata_a] [get_bd_pins vpu_0/ob_dina]
connect_bd_net [get_bd_pins vpu_pe_obuf_ctrl_0/bram_rddata_a] [get_bd_pins vpu_0/ob_douta]

# VPU AXI Regs <-> VPU control/config signals
connect_bd_net [get_bd_pins vpu_axi_regs_0/ready]        [get_bd_pins vpu_0/ready]
connect_bd_net [get_bd_pins vpu_axi_regs_0/vpu_start]    [get_bd_pins vpu_0/vpu_start]
connect_bd_net [get_bd_pins vpu_axi_regs_0/unit_choose]  [get_bd_pins vpu_0/unit_choose]
connect_bd_net [get_bd_pins vpu_axi_regs_0/src_addr]     [get_bd_pins vpu_0/src_addr]
connect_bd_net [get_bd_pins vpu_axi_regs_0/src2_addr]    [get_bd_pins vpu_0/src2_addr]
connect_bd_net [get_bd_pins vpu_axi_regs_0/src_c]        [get_bd_pins vpu_0/src_c]
connect_bd_net [get_bd_pins vpu_axi_regs_0/src_h]        [get_bd_pins vpu_0/src_h]
connect_bd_net [get_bd_pins vpu_axi_regs_0/src_w]        [get_bd_pins vpu_0/src_w]
connect_bd_net [get_bd_pins vpu_axi_regs_0/bias_addr]    [get_bd_pins vpu_0/bias_addr]
connect_bd_net [get_bd_pins vpu_axi_regs_0/scale_addr]   [get_bd_pins vpu_0/scale_addr]
connect_bd_net [get_bd_pins vpu_axi_regs_0/dst_addr]     [get_bd_pins vpu_0/dst_addr]
connect_bd_net [get_bd_pins vpu_axi_regs_0/addr_break]   [get_bd_pins vpu_0/addr_break]
connect_bd_net [get_bd_pins vpu_axi_regs_0/addr_s]       [get_bd_pins vpu_0/addr_s]
connect_bd_net [get_bd_pins vpu_axi_regs_0/addr_t]       [get_bd_pins vpu_0/addr_t]

# Common clock/reset from XDMA
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_mem_smc/aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_mem_smc/aresetn]

foreach axi_slave {vpu_global_bram_ctrl_0 vpu_pe_ibuf_ctrl_0 vpu_pe_obuf_ctrl_0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins ${axi_slave}/s_axi_aclk]
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins ${axi_slave}/s_axi_aresetn]
}

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
if {[llength [get_bd_pins -quiet axi_cdma_0/m_axi_aresetn]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/m_axi_aresetn]
}

# ==============================================================================
# VPU 核心模块使用独立的外部板级复位（通过 Processor System Reset 同步）
# 原因：避免依赖 XDMA AXI 复位的不确定时序
# ==============================================================================
# 创建 Processor System Reset IP 用于生成同步复位
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 vpu_reset_sync
set_property -dict [list CONFIG.C_AUX_RESET_HIGH {0}] [get_bd_cells vpu_reset_sync]

# 将 cpu_reset (板级复位) 连接到 vpu_reset_sync
# 注意：cpu_reset 是 ACTIVE_HIGH，vpu_reset_sync/ext_reset_in 也是 ACTIVE_HIGH
connect_bd_net [get_bd_ports cpu_reset] [get_bd_pins vpu_reset_sync/ext_reset_in]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_reset_sync/slowest_sync_clk]

# VPU 相关模块使用外部板级复位（同步后的 ACTIVE_LOW 信号）
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_axi_regs_0/aclk]
connect_bd_net [get_bd_pins vpu_reset_sync/peripheral_aresetn] [get_bd_pins vpu_axi_regs_0/aresetn]

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins vpu_0/clk]
connect_bd_net [get_bd_pins vpu_reset_sync/peripheral_aresetn] [get_bd_pins vpu_0/rst_n]
