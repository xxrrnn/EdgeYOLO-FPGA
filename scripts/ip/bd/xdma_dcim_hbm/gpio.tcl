# Host-visible PE control/status registers implemented with AXI GPIO.
#
# Address map is assigned in address.tcl.  Software protocol:
#   pe_cfg0_gpio  GPIO[31:0] = PE weight base byte address inside ibuf
#   pe_cfg1_gpio  GPIO[31:0] = PE activation base byte address inside ibuf
#   pe_cfg2_gpio  GPIO[31:0] = PE result base byte address inside obuf
#   pe_cfg3_gpio  GPIO[31:0] = activation row count
#   pe_ctrl_gpio  GPIO[0]    = start pulse
#                 GPIO[1]    = config_valid
#                 GPIO[4:2]  = mode, use 3'b110 for int8
#                 GPIO[9:5]  = acc, 0/1/2/4/8/16 supported
#   pe_status_gpio GPIO[3:0] = {config_ready, error, done, busy}
#                  GPIO2     = error_code

foreach gpio_name {pe_cfg0_gpio pe_cfg1_gpio pe_cfg2_gpio pe_cfg3_gpio pe_ctrl_gpio} {
  create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 $gpio_name
  set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_IS_DUAL {0} \
  ] [get_bd_cells $gpio_name]
}

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 pe_status_gpio
set_property -dict [list \
  CONFIG.C_GPIO_WIDTH {4} \
  CONFIG.C_ALL_INPUTS {1} \
  CONFIG.C_IS_DUAL {1} \
  CONFIG.C_GPIO2_WIDTH {32} \
  CONFIG.C_ALL_INPUTS_2 {1} \
] [get_bd_cells pe_status_gpio]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 pe_start_slice
set_property -dict [list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_FROM {0} \
  CONFIG.DIN_TO {0} \
  CONFIG.DOUT_WIDTH {1} \
] [get_bd_cells pe_start_slice]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 pe_config_valid_slice
set_property -dict [list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_FROM {1} \
  CONFIG.DIN_TO {1} \
  CONFIG.DOUT_WIDTH {1} \
] [get_bd_cells pe_config_valid_slice]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 pe_mode_slice
set_property -dict [list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_FROM {4} \
  CONFIG.DIN_TO {2} \
  CONFIG.DOUT_WIDTH {3} \
] [get_bd_cells pe_mode_slice]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 pe_acc_slice
set_property -dict [list \
  CONFIG.DIN_WIDTH {32} \
  CONFIG.DIN_FROM {9} \
  CONFIG.DIN_TO {5} \
  CONFIG.DOUT_WIDTH {5} \
] [get_bd_cells pe_acc_slice]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 pe_status_concat
set_property -dict [list \
  CONFIG.NUM_PORTS {4} \
  CONFIG.IN0_WIDTH {1} \
  CONFIG.IN1_WIDTH {1} \
  CONFIG.IN2_WIDTH {1} \
  CONFIG.IN3_WIDTH {1} \
] [get_bd_cells pe_status_concat]
