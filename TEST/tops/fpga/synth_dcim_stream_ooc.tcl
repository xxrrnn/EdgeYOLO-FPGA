# Post-refactor DCIM_Array out-of-context synthesis/resource check.
# Run from repository root:
#   vivado -mode batch -source TEST/tops/fpga/synth_dcim_stream_ooc.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize "$script_dir/../../.."]
if {[info exists ::env(DCIM_OOC_DIR)] && $::env(DCIM_OOC_DIR) ne ""} {
    set out_dir [file normalize $::env(DCIM_OOC_DIR)]
} else {
    set out_dir [file normalize "$repo_root/output/tops/fpga/dcim_stream_ooc"]
}
file mkdir $out_dir

create_project -in_memory -part xcvu37p-fsvh2892-2L-e
set include_dirs [list \
    "$repo_root/rtl/chip" \
    "$repo_root/rtl/common" \
    "$repo_root/rtl/ref/DCIM/src/inc" \
    "$repo_root/rtl/ref/DCIM/src/dcim" \
    "$repo_root/rtl/ref/DCIM/src/model" \
]
set rtl_files [list \
    "$repo_root/rtl/ref/DCIM/src/inc/para.v" \
    "$repo_root/rtl/ref/DCIM/src/inc/counter.v" \
    "$repo_root/rtl/ref/DCIM/src/inc/dff.v" \
    "$repo_root/rtl/ref/DCIM/src/inc/pipe_stage.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/multiplier.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/multiplier_dsp.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/adderTree.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/maArray.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/calculate_core.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/mergeArray.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/accumulateArray.v" \
    "$repo_root/rtl/ref/DCIM/src/dcim/postProcess.v" \
    "$repo_root/rtl/ref/DCIM/src/model/model_rf_bram.sv" \
    "$repo_root/rtl/common/uram_tdp_bytewrite.v" \
    "$repo_root/rtl/chip/DCIM_Activation_Stream.sv" \
    "$repo_root/rtl/chip/DCIM_Weight_Cache.sv" \
    "$repo_root/rtl/chip/DCIM_Partial_Sum_RAM.sv" \
    "$repo_root/rtl/chip/DCIM_Result_Stream.sv" \
    "$repo_root/rtl/chip/DCIM_Tile.sv" \
    "$repo_root/rtl/chip/tile_ibuf.v" \
    "$repo_root/rtl/chip/tile_obuf.v" \
    "$repo_root/rtl/chip/DCIM_Array.sv" \
]

set_property include_dirs $include_dirs [current_fileset]
set_property verilog_define {FPGA=1} [current_fileset]
read_verilog -sv $rtl_files
synth_design -mode out_of_context -top DCIM_Array -part xcvu37p-fsvh2892-2L-e \
    -flatten_hierarchy rebuilt -directive Default
create_clock -name dcim_clk -period 4.000 [get_ports clk]

write_checkpoint -force "$out_dir/dcim_array_post_synth.dcp"
report_utilization -file "$out_dir/utilization.rpt"
report_utilization -hierarchical -hierarchical_depth 4 \
    -file "$out_dir/utilization_hier.rpt"
report_timing_summary -delay_type max -max_paths 20 \
    -file "$out_dir/timing_summary.rpt"
report_high_fanout_nets -max_nets 50 \
    -file "$out_dir/high_fanout.rpt"

puts "DCIM_STREAM_OOC_DONE=$out_dir"
