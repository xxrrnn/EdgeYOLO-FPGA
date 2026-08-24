# Export every setup-violating path from an existing checkpoint.
# Usage:
#   vivado -mode batch -source report_all_failing_paths.tcl \
#     -tclargs <post_route.dcp> <output.rpt>

if {$argc < 2} {
    error "usage: report_all_failing_paths.tcl <checkpoint.dcp> <output.rpt>"
}

set dcp_path [file normalize [lindex $argv 0]]
set rpt_path [file normalize [lindex $argv 1]]
if {![file exists $dcp_path]} {
    error "checkpoint not found: $dcp_path"
}

open_checkpoint $dcp_path
report_timing -delay_type max -max_paths 5000 -nworst 1 \
    -slack_lesser_than 0.0 -file $rpt_path
puts "ALL_FAILING_PATHS_REPORT=$rpt_path"
