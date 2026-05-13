set_property PACKAGE_PIN BH24 [get_ports user_lnk_up_0]
set_property IOSTANDARD LVCMOS18 [get_ports user_lnk_up_0]

set_property PACKAGE_PIN BM29 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS12 [get_ports cpu_reset]

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]

# PCIe Reference Clock Constraints
set_property PACKAGE_PIN AR14 [get_ports pcie_refclk_clk_n]
set_property PACKAGE_PIN AR15 [get_ports pcie_refclk_clk_p]

# The pcie_refclk BD interface carries FREQ_HZ=100000000, so Vivado creates the
# input clock constraint from the generated IP metadata.
