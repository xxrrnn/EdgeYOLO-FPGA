# Focused 250 MHz implementation check for the fixed-latency URAM data pipe.
# The default is the real VPU capacity (1M x 128, AWIDTH=20).  Do not reduce it:
# a smaller memory omits the multi-bank output selector that caused the full
# design timing regression.

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize "$script_dir/../../.."]
set out_dir [file normalize "$repo_root/output/tops/fpga/uram_pipe_ooc"]
if {[info exists ::env(URAM_PIPE_OOC_DIR)] && $::env(URAM_PIPE_OOC_DIR) ne ""} {
    set out_dir [file normalize $::env(URAM_PIPE_OOC_DIR)]
}
file mkdir $out_dir

set awidth 20
if {[info exists ::env(URAM_PIPE_AWIDTH)] && $::env(URAM_PIPE_AWIDTH) ne ""} {
    set awidth $::env(URAM_PIPE_AWIDTH)
}

set_part xcvu37p-fsvh2892-2L-e
read_verilog "$repo_root/rtl/common/uram_tdp_bytewrite.v"
synth_design -mode out_of_context -top uram_tdp_bytewrite \
    -part xcvu37p-fsvh2892-2L-e \
    -generic AWIDTH=$awidth -generic NUM_COL=16 -generic DWIDTH=128 \
    -generic NBPIPE=8
create_clock -name clk -period 4.000 [get_ports clk]
opt_design
place_design -directive Explore
phys_opt_design -directive AggressiveExplore

report_utilization -file "$out_dir/utilization.rpt"
report_timing_summary -delay_type min_max -max_paths 20 \
    -file "$out_dir/timing_summary.rpt"
report_timing -from [get_cells -hier -filter {PRIMITIVE_TYPE =~ BLOCKRAM.URAM.*}] \
    -delay_type max -max_paths 20 -file "$out_dir/uram_to_pipe.rpt"

set srl_cells [get_cells -quiet -hier -filter {REF_NAME =~ SRL*}]
set pipe_srl_cells [get_cells -quiet -hier -filter \
    {(NAME =~ *dat_pipe_a* || NAME =~ *dat_pipe_b*) && REF_NAME =~ SRL*}]
set pipe_ff_cells [get_cells -quiet -hier -filter \
    {(NAME =~ *dat_pipe_a* || NAME =~ *dat_pipe_b*) && REF_NAME =~ FD*}]
puts "URAM_PIPE_ALL_SRL_COUNT=[llength $srl_cells]"
puts "URAM_PIPE_DATA_SRL_COUNT=[llength $pipe_srl_cells]"
puts "URAM_PIPE_DATA_FF_COUNT=[llength $pipe_ff_cells]"
puts "URAM_PIPE_AWIDTH=$awidth"
if {[llength $pipe_srl_cells] != 0} {
    error "URAM data pipeline still contains SRLs"
}

# With the known-good CE pipeline Vivado may absorb/rename the first data FFs
# as registered bank-select cells, so their source-level dat_pipe name is not a
# correctness requirement.  The hard requirements are no data-pipe SRL and a
# timing-clean implementation at the real capacity.
set setup_path [get_timing_paths -quiet -max_paths 1 -delay_type max]
set hold_path  [get_timing_paths -quiet -max_paths 1 -delay_type min]
set setup_wns 0.0
set hold_whs 0.0
if {[llength $setup_path]} { set setup_wns [get_property SLACK [lindex $setup_path 0]] }
if {[llength $hold_path]}  { set hold_whs [get_property SLACK [lindex $hold_path 0]] }
puts "URAM_PIPE_WNS=$setup_wns"
puts "URAM_PIPE_WHS=$hold_whs"
if {$setup_wns < 0.0 || $hold_whs < 0.0} {
    error "real-capacity URAM pipeline timing failed: WNS=$setup_wns WHS=$hold_whs"
}
puts "URAM_PIPE_OOC_DONE=$out_dir"
