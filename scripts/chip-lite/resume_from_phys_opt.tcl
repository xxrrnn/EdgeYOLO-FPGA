set BuildDir [file normalize "build/lite/260612_2213"]
set ImplOutputDir "$BuildDir/ImplOutputDir"

open_checkpoint [file normalize "$ImplOutputDir/post_phys_opt.dcp"]

set_param general.maxThreads 32

puts "\n========== Resume: Route Design =========="
route_design -directive AggressiveExplore

puts "\n========== Resume: Post-route Hold Fix =========="
phys_opt_design -hold_fix
puts "INFO: Post-route hold phys_opt done"

write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
report_timing -max_paths 50 -slack_lesser_than 0.0 -delay_type max \
    -file [file normalize "$ImplOutputDir/post_route_failing_paths.rpt"]
report_timing -max_paths 20 -slack_lesser_than 0.0 -delay_type min \
    -file [file normalize "$ImplOutputDir/post_route_failing_hold.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]
report_drc -file [file normalize "$ImplOutputDir/post_route_drc.rpt"]

puts "\n========== Resume: Check Timing =========="
set wns [get_property SLACK [get_timing_paths -max_paths 1 -delay_type max]]
puts "INFO: Post-route WNS = ${wns} ns"

if {$wns >= 0} {
    puts "\n========== Resume: Generate Bitstream =========="
    write_bitstream -force [file normalize "$ImplOutputDir/lite_top.bit"]
    puts "INFO: Bitstream generated successfully"
} else {
    puts "WARNING: Timing not met (WNS=${wns}ns), skipping bitstream"
}

close_design
puts "=== DONE ==="
