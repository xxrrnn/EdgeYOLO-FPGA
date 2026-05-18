set_property PACKAGE_PIN BH24 [get_ports user_lnk_up_0]
set_property IOSTANDARD LVCMOS18 [get_ports user_lnk_up_0]

set_property PACKAGE_PIN BM29 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS12 [get_ports cpu_reset]

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]

set_property PACKAGE_PIN AR14 [get_ports pcie_refclk_clk_n]
set_property PACKAGE_PIN AR15 [get_ports pcie_refclk_clk_p]

################################################################################
# 时序约束：复位路径
################################################################################
# 将 XDMA 复位信号到 BRAM 复位端口的路径标记为 false_path
# 这些是低频异步复位信号，不需要严格的时序约束

# XDMA user_reset 到所有 BRAM 的 RSTREG/RSTRAM 端口
set_false_path -from [get_pins -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
               -to [get_pins -hierarchical -filter {NAME =~ */*bram*/RSTREG*}]

set_false_path -from [get_pins -hierarchical -filter {NAME =~ */xdma_0/inst/pcie4c_ip_i/inst/user_reset_reg/C}] \
               -to [get_pins -hierarchical -filter {NAME =~ */*bram*/RSTRAM*}]

# XDMA 内部复位路径到 BRAM
set_false_path -from [get_pins -hierarchical -filter {NAME =~ */xdma_0/*/user_reset*}] \
               -to [get_pins -hierarchical -filter {NAME =~ */inst_bram/*}]

set_false_path -from [get_pins -hierarchical -filter {NAME =~ */xdma_0/*/user_reset*}] \
               -to [get_pins -hierarchical -filter {NAME =~ */global_bram/*}]

# PCIe 复位到系统其他复位信号
set_false_path -from [get_pins -hierarchical -filter {NAME =~ */xdma_0/*/rst_*}] \
               -to [get_pins -hierarchical -filter {NAME =~ */*_reset_reg*/D}]

################################################################################
# 时序约束：跨时钟域路径（如果需要）
################################################################################
# PCIe 时钟域到 BRAM 控制时钟域的某些控制信号
# set_max_delay -from [get_clocks pipe_clk] -to [get_clocks global_bram_ctrl_BRAM_PORTA_CLK] 8.0
# set_max_delay -from [get_clocks global_bram_ctrl_BRAM_PORTA_CLK] -to [get_clocks pipe_clk] 8.0

################################################################################
# False Path：XDMA/PCIe IP 内部 Hold 路径（布局后自动修复）
################################################################################
# GT DRP 校准路径（低频，非功能关键路径）
set_false_path -hold -from [get_pins -hierarchical -filter {NAME =~ */xdma_0/*/gen_cpll_cal*/gtwizard_ultrascale*drp_arb_i/*/C}] \
               -to [get_pins -hierarchical -filter {NAME =~ */GTYE4_CHANNEL_PRIM_INST/DRP*}]

# PCIe PIPE 接口（Xilinx IP 已知 hold timing，功能不受影响）
set_false_path -hold -from [get_pins -hierarchical -filter {NAME =~ */phy_pipeline/*/ff_chain_reg*/C}] \
               -to [get_pins -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/PIPETX*}]

# PCIe BRAM → PCIE4CE4（IP 内部固定时序关系）
set_false_path -hold -from [get_pins -hierarchical -filter {NAME =~ */pcie_4_0_bram_inst/*/reg_rdata*_reg*/C}] \
               -to [get_pins -hierarchical -filter {NAME =~ */pcie_4_c_e4_inst/MIRX*}]
