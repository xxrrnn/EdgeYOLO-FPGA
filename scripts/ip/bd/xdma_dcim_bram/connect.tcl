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
#   M00 = global_bram
#   M01 = local_bram
#   M02 = controller AXI-Lite registers
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mem_smc
set_property -dict [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {3} \
] [get_bd_cells axi_mem_smc]
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_cdma_0/M_AXI] [get_bd_intf_pins axi_mem_smc/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M00_AXI] [get_bd_intf_pins global_bram_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M01_AXI] [get_bd_intf_pins local_bram_ctrl/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_mem_smc/M02_AXI] [get_bd_intf_pins xdma_dcim_bram_ctrl_0/s_axil]

# Controller configures CDMA through a private AXI-Lite master.
connect_bd_intf_net [get_bd_intf_pins xdma_dcim_bram_ctrl_0/m_axil_cdma] [get_bd_intf_pins axi_cdma_0/S_AXI_LITE]

# AXI BRAM controllers <-> BRAM IPs.
connect_bd_intf_net [get_bd_intf_pins global_bram/BRAM_PORTA] [get_bd_intf_pins global_bram_ctrl/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_pins local_bram/BRAM_PORTA] [get_bd_intf_pins local_bram_ctrl/BRAM_PORTA]

# Controller native port <-> local BRAM port B.
connect_bd_net [get_bd_pins xdma_dcim_bram_ctrl_0/local_bram_en] [get_bd_pins local_bram/enb]
connect_bd_net [get_bd_pins xdma_dcim_bram_ctrl_0/local_bram_we] [get_bd_pins local_bram/web]
connect_bd_net [get_bd_pins xdma_dcim_bram_ctrl_0/local_bram_addr] [get_bd_pins local_bram/addrb]
connect_bd_net [get_bd_pins xdma_dcim_bram_ctrl_0/local_bram_din] [get_bd_pins local_bram/dinb]
connect_bd_net [get_bd_pins xdma_dcim_bram_ctrl_0/local_bram_dout] [get_bd_pins local_bram/doutb]

# Common clock/reset from XDMA.
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_mem_smc/aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_mem_smc/aresetn]

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins global_bram_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins global_bram_ctrl/s_axi_aresetn]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins local_bram_ctrl/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins local_bram_ctrl/s_axi_aresetn]

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/m_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_cdma_0/s_axi_lite_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/s_axi_lite_aresetn]
if {[llength [get_bd_pins -quiet axi_cdma_0/m_axi_aresetn]] != 0} {
  connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_cdma_0/m_axi_aresetn]
}

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins xdma_dcim_bram_ctrl_0/aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins xdma_dcim_bram_ctrl_0/aresetn]

connect_bd_net [get_bd_pins local_bram/clkb] [get_bd_pins xdma_0/axi_aclk]

# Reset BRAMs with active-high reset derived from XDMA aresetn.
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins bram_inv/Op1]
connect_bd_net [get_bd_pins bram_inv/Res] [get_bd_pins local_bram/rstb]
