# Resume P&R from post_opt checkpoint (bypass timing gate)
set ImplOutputDir [file normalize "../../build/lite/ImplOutputDir"]
open_checkpoint [file normalize "$ImplOutputDir/post_opt.dcp"]

set placeDirective "Explore"
set routeDirective "Explore"

puts "INFO: Resuming from post_opt.dcp — starting place_design..."
place_design -directive $placeDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]

puts "INFO: Starting phys_opt_design..."
phys_opt_design -directive AggressiveExplore
write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt.dcp"]

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
        write_bitstream -force [file normalize "$ImplOutputDir/lite.bit"]
        puts "INFO: Bitstream generated: $ImplOutputDir/lite.bit"
    } else {
        puts "WARNING: Timing not met (WNS=${final_wns}), bitstream skipped."
    }
}
puts "INFO: Implementation complete."
