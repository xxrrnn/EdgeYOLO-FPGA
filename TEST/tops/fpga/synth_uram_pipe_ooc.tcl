# Focused 250 MHz implementation check for the fixed-latency URAM data pipe.
# It deliberately uses a 32K x 128 memory so Vivado builds the same deep URAM
# cascade seen in the VPU buffer, while remaining much smaller than the chip.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize "$script_dir/../../.."]
set out_dir [file normalize "$repo_root/output/tops/fpga/uram_pipe_ooc"]
if {[info exists ::env(URAM_PIPE_OOC_DIR)] && $::env(URAM_PIPE_OOC_DIR) ne ""} {
    set out_dir [file normalize $::env(URAM_PIPE_OOC_DIR)]
}
file mkdir $out_dir

set_part xcvu37p-fsvh2892-2L-e
read_verilog "$repo_root/rtl/common/uram_tdp_bytewrite.v"
synth_design -mode out_of_context -top uram_tdp_bytewrite \
    -part xcvu37p-fsvh2892-2L-e \
    -generic AWIDTH=15 -generic NUM_COL=16 -generic DWIDTH=128 \
    -generic NBPIPE=8
create_clock -name clk -period 4.000 [get_ports clk]
opt_design
place_design -directive Explore
phys_opt_design -directive AggressiveExplore

report_utilization -file "$out_dir/utilization.rpt"
report_timing_summary -delay_type min_max -max_paths 20 \
    -file "$out_dir/timing_summary.rpt"
report_timing -from [get_cells -hier -filter {PRIMITIVE_TYPE =~ BLOCKRAM.URAM.*}] \
    -to [get_cells -hier -regexp {.*dat_pipe_[ab]_reg.*}] \
    -delay_type max -max_paths 20 -file "$out_dir/uram_to_pipe.rpt"

set srl_cells [get_cells -quiet -hier -filter {REF_NAME =~ SRL*}]
set pipe_srl_cells [get_cells -quiet -hier -filter \
    {(NAME =~ *dat_pipe_a* || NAME =~ *dat_pipe_b*) && REF_NAME =~ SRL*}]
set pipe_ff_cells [get_cells -quiet -hier -filter \
    {(NAME =~ *dat_pipe_a* || NAME =~ *dat_pipe_b*) && REF_NAME =~ FD*}]
puts "URAM_PIPE_ALL_SRL_COUNT=[llength $srl_cells]"
puts "URAM_PIPE_DATA_SRL_COUNT=[llength $pipe_srl_cells]"
puts "URAM_PIPE_DATA_FF_COUNT=[llength $pipe_ff_cells]"
if {[llength $pipe_srl_cells] != 0} {
    error "URAM data pipeline still contains SRLs"
}
if {[llength $pipe_ff_cells] == 0} {
    error "URAM data pipeline FFs were not preserved"
}
puts "URAM_PIPE_OOC_DONE=$out_dir"
