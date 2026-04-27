##################################################################
# CHECK VIVADO VERSION
##################################################################

set scripts_vivado_version 2024.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
  catch {common::send_msg_id "IPS_TCL-100" "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_ip_tcl to create an updated script."}
  return 1
}

##################################################################
# START
##################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source xdma.tcl
# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
  create_project FULL_1104 FULL_1104 -part xcvu37p-fsvh2892-2L-e
  set_property BOARD_PART xilinx.com:vcu128:part0:1.0 [current_project]
  set_property target_language Verilog [current_project]
  set_property simulator_language Mixed [current_project]
}

##################################################################
# CHECK IPs
##################################################################

set bCheckIPs 1
set bCheckIPsPassed 1
if { $bCheckIPs == 1 } {
  set list_check_ips { xilinx.com:ip:xdma:4.1 }
  set list_ips_missing ""
  common::send_msg_id "IPS_TCL-1001" "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

  foreach ip_vlnv $list_check_ips {
  set ip_obj [get_ipdefs -all $ip_vlnv]
  if { $ip_obj eq "" } {
    lappend list_ips_missing $ip_vlnv
    }
  }

  if { $list_ips_missing ne "" } {
    catch {common::send_msg_id "IPS_TCL-105" "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
    set bCheckIPsPassed 0
  }
}

if { $bCheckIPsPassed != 1 } {
  common::send_msg_id "IPS_TCL-102" "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 1
}

##################################################################
# CREATE IP xdma
##################################################################

set xdma [create_ip -name xdma -vendor xilinx.com -library ip -version 4.1 -module_name xdma]

# User Parameters
set_property -dict [list \
  CONFIG.PCIE_BOARD_INTERFACE {pci_express_x8} \
  CONFIG.SYS_RST_N_BOARD_INTERFACE {cpu_reset} \
  CONFIG.axi_data_width {256_bit} \
  CONFIG.axil_master_64bit_en {false} \
  CONFIG.axilite_master_en {true} \
  CONFIG.axilite_master_size {8} \
  CONFIG.axisten_freq {250} \
  CONFIG.cfg_mgmt_if {false} \
  CONFIG.en_ext_ch_gt_drp {false} \
  CONFIG.en_pcie_drp {false} \
  CONFIG.en_transceiver_status_ports {false} \
  CONFIG.enable_jtag_dbg {false} \
  CONFIG.mode_selection {Advanced} \
  CONFIG.pcie_extended_tag {true} \
  CONFIG.pciebar2axibar_axil_master {0x0000_0000} \
  CONFIG.pf0_device_id {9024} \
  CONFIG.pf0_interrupt_pin {NONE} \
  CONFIG.pf0_msix_cap_pba_bir {BAR_3:2} \
  CONFIG.pf0_msix_cap_pba_offset {00008FE0} \
  CONFIG.pf0_msix_cap_table_bir {BAR_3:2} \
  CONFIG.pf0_msix_cap_table_offset {00008000} \
  CONFIG.pf0_msix_cap_table_size {01F} \
  CONFIG.pf0_msix_enabled {true} \
  CONFIG.pipe_sim {false} \
  CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
  CONFIG.plltype {QPLL1} \
  CONFIG.xdma_axi_intf_mm {AXI_Memory_Mapped} \
  CONFIG.xdma_pcie_64bit_en {true} \
  CONFIG.xdma_rnum_chnl {4} \
  CONFIG.xdma_wnum_chnl {4} \
] [get_ips xdma]

# Runtime Parameters
set_property -dict { 
  GENERATE_SYNTH_CHECKPOINT {1}
} $xdma

##################################################################
