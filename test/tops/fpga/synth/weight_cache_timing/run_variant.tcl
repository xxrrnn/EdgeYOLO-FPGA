set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize "$script_dir/../../../../.."]

if {$argc < 2} {
    error "usage: vivado -mode batch -source run_variant.tcl -tclargs <baseline|replicated> <out_dir>"
}
set variant [string tolower [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
file mkdir $out_dir

switch -- $variant {
    baseline   { set replicas 1 }
    replicated { set replicas 4 }
    default    { error "unknown variant: $variant" }
}

create_project -in_memory -part xcvu37p-fsvh2892-2L-e
read_verilog -sv [file normalize "$repo_root/rtl/ref/DCIM/src/model/model_rf_bram.sv"]
read_verilog -sv [file normalize "$script_dir/weight_cache_timing_dut.sv"]

synth_design -mode out_of_context -top weight_cache_timing_dut \
    -part xcvu37p-fsvh2892-2L-e -flatten_hierarchy rebuilt \
    -directive PerformanceOptimized -generic REPLICAS=$replicas
create_clock -name cache_clk -period 4.000 [get_ports clk]
set_clock_uncertainty 0.025 [get_clocks cache_clk]

opt_design -directive ExploreWithRemap

# Recreate the measured long BRAM-to-cache topology in a deterministic small
# design.  The fixed design's preserved copies may occupy the central region,
# allowing the two registered hops to share the physical distance.
set store_cells [get_cells -quiet -hierarchical -filter {
    PRIMITIVE_TYPE =~ BLOCKRAM.BRAM.* && NAME =~ *u_weight_store*
}]
set cache_cells [get_cells -quiet -hierarchical -filter {
    IS_SEQUENTIAL && (NAME =~ *cache0_reg* || NAME =~ *cache1_reg*)
}]
set replica_cells [get_cells -quiet -hierarchical -filter {
    IS_SEQUENTIAL && NAME =~ *load_data_rep*
}]
puts "INFO: variant=$variant replicas=$replicas BRAM=[llength $store_cells] cache_ff=[llength $cache_cells] replica_ff=[llength $replica_cells]"
if {[llength $store_cells] == 0 || [llength $cache_cells] == 0} {
    error "expected BRAM/cache topology was optimized away"
}

create_pblock pblock_store
add_cells_to_pblock [get_pblocks pblock_store] $store_cells
resize_pblock [get_pblocks pblock_store] -add {RAMB36_X0Y0:RAMB36_X0Y79}
set_property IS_SOFT FALSE [get_pblocks pblock_store]

create_pblock pblock_cache
add_cells_to_pblock [get_pblocks pblock_cache] $cache_cells
resize_pblock [get_pblocks pblock_cache] -add {SLICE_X140Y0:SLICE_X190Y239}
set_property IS_SOFT FALSE [get_pblocks pblock_cache]

if {[llength $replica_cells]} {
    create_pblock pblock_replicas
    add_cells_to_pblock [get_pblocks pblock_replicas] $replica_cells
    resize_pblock [get_pblocks pblock_replicas] -add {SLICE_X70Y0:SLICE_X110Y239}
    set_property IS_SOFT FALSE [get_pblocks pblock_replicas]
}

place_design -directive ExtraTimingOpt
phys_opt_design -directive AggressiveExplore
route_design -directive AggressiveExplore
phys_opt_design -directive AggressiveExplore

report_timing_summary -delay_type min_max -max_paths 20 \
    -file [file normalize "$out_dir/post_route_timing_summary.rpt"]
report_timing -delay_type max -max_paths 50 -sort_by group \
    -file [file normalize "$out_dir/post_route_setup_paths.rpt"]
report_timing -delay_type min -max_paths 20 -sort_by group \
    -file [file normalize "$out_dir/post_route_hold_paths.rpt"]
report_high_fanout_nets -max_nets 100 \
    -file [file normalize "$out_dir/high_fanout.rpt"]
report_utilization -file [file normalize "$out_dir/utilization.rpt"]
report_design_analysis -congestion -complexity \
    -file [file normalize "$out_dir/congestion.rpt"]
write_checkpoint -force [file normalize "$out_dir/post_route.dcp"]

set setup_path [get_timing_paths -max_paths 1 -delay_type max -quiet]
set hold_path  [get_timing_paths -max_paths 1 -delay_type min -quiet]
set wns 0.0
set whs 0.0
if {[llength $setup_path]} { set wns [get_property SLACK [lindex $setup_path 0]] }
if {[llength $hold_path]}  { set whs [get_property SLACK [lindex $hold_path 0]] }

set fp [open [file normalize "$out_dir/result.tsv"] w]
puts $fp "variant\treplicas\tbram\tcache_ff\treplica_ff\twns\twhs"
puts $fp "$variant\t$replicas\t[llength $store_cells]\t[llength $cache_cells]\t[llength $replica_cells]\t$wns\t$whs"
close $fp
puts "WEIGHT_CACHE_TIMING_RESULT variant=$variant WNS=$wns WHS=$whs replica_ff=[llength $replica_cells]"
