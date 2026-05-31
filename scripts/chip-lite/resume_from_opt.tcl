# Resume P&R from post_opt checkpoint (bypass timing gate)
# NOTE: AltSpreadLogic_high caused Vivado 2024.2 placer SIGSEGV in Phase 2.6.2
#       (HAPLFTypeUtils::buildTypeToIdMap crash). Use Default to avoid the bug.
set thisScriptDir [file dirname [file normalize [info script]]]
set localDir      [file normalize "$thisScriptDir/../.."]
set ImplOutputDir [file normalize "$localDir/build/lite/ImplOutputDir"]
set xdcDir        [file normalize "$localDir/xdc"]

open_checkpoint [file normalize "$ImplOutputDir/post_opt.dcp"]

# Reload updated XDC constraints (timing fixes: cfg→FSM MCP, HBM false_path, DCIM CLR false_path)
read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
read_xdc -unmanaged [file normalize "$xdcDir/chip/chip.xdc"]

set placeDirective "Default"
set routeDirective "Explore"

# Single-thread placement avoids ILR multi-thread race condition that triggers the crash
set_param general.maxThreads 1

puts "INFO: Resuming from post_opt.dcp — starting place_design..."
place_design -directive $placeDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]

# Restore multi-thread for phys_opt
set_param general.maxThreads 8

puts "INFO: Starting phys_opt_design pass 1 (AggressiveExplore)..."
phys_opt_design -directive AggressiveExplore
write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_timing_summary.rpt"]

puts "INFO: Starting route_design..."
route_design -directive $routeDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]

# Final WNS check
set finalPaths [get_timing_paths -max_paths 1 -delay_type max]
if {[llength $finalPaths] > 0} {
    set final_wns [get_property SLACK $finalPaths]
    puts "INFO: Final Post-Route WNS = ${final_wns} ns"
    if {$final_wns >= 0} {
        puts "INFO: TIMING MET! Generating bitstream..."
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/lite.bit"]
        puts "INFO: Bitstream generated: $ImplOutputDir/lite.bit"
    } else {
        puts "WARNING: Timing not met (WNS=${final_wns}), bitstream skipped."
    }
}
puts "INFO: Implementation complete."
