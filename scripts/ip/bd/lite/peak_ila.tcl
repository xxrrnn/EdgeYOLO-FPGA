# ==============================================================================
# peak_ila.tcl - Minimal ILA for exact-fit INT8 array peak evidence
# ==============================================================================
# Intended workload:
#   M=1, K=64, N=128, acc_depth=1, tile_mask=8'hFF, clk=250 MHz
#
# Evidence:
#   probe0 == 8'hFF for two consecutive samples
#     => 8 tiles * 64 inputs * 16 INT8 outputs/tile * 2 ops/MAC
#        / (2 cycles / 250 MHz) = 2.048 TOPS
#   probe1 shows one Tile's real nibble input in those cycles.
#   probe2/probe3 show one final host-visible INT32 result for correctness.
#
# No host register, address, instruction, IBUF, or OBUF mapping is changed.
# ==============================================================================

if {[llength [get_bd_cells -quiet peak_tops_ila]] != 0} {
    delete_bd_objs [get_bd_cells peak_tops_ila]
}

create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 peak_tops_ila
set_property -dict [list \
    CONFIG.C_MONITOR_TYPE     {Native} \
    CONFIG.C_NUM_OF_PROBES    {4} \
    CONFIG.C_DATA_DEPTH       {1024} \
    CONFIG.C_ADV_TRIGGER      {false} \
    CONFIG.C_EN_STRG_QUAL     {false} \
    CONFIG.C_INPUT_PIPE_STAGES {1} \
    CONFIG.C_PROBE0_WIDTH     $::DCIM_NUM_TILES \
    CONFIG.C_PROBE1_WIDTH     {32} \
    CONFIG.C_PROBE2_WIDTH     {1} \
    CONFIG.C_PROBE3_WIDTH     {32} \
] [get_bd_cells peak_tops_ila]

puts "INFO: peak_tops_ila created: probes=$::DCIM_NUM_TILES+32+1+32 depth=1024"
