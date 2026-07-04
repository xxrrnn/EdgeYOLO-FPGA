# ==============================================================================
# 4_rpt.tcl — 生成详细时序、利用率、DRC 等报告
#             独立执行：加载最新 checkpoint 后生成
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
if {![info exists ScriptDir]} { source [file normalize "$thisScriptDir/config.tcl"] }

file mkdir $ImplOutputDir
set rptDir [file normalize "$ImplOutputDir/reports"]
file mkdir $rptDir

# 找最新的 implementation checkpoint
set postDcp ""
foreach dcpName {post_route.dcp post_phys_opt.dcp post_place.dcp post_opt.dcp} {
    set candidate [file normalize "$ImplOutputDir/$dcpName"]
    if {[file exists $candidate]} { set postDcp $candidate; break }
}
if {$postDcp eq ""} {
    error "No implementation checkpoint found in $ImplOutputDir — run 3_synth.tcl first."
}

puts "========================================================================"
puts "  Loading: $postDcp"
puts "========================================================================"
open_checkpoint $postDcp

# ==============================================================================
# Timing Reports
# ==============================================================================
puts "\[1/6\] Timing summary..."
report_timing_summary -max_paths 10 -report_unconstrained \
    -file [file normalize "$rptDir/timing_summary.rpt"]

puts "\[2/6\] Failing paths (setup top 500, hold top 20)..."
report_timing -max_paths 500 -nworst 5 -delay_type max -sort_by slack \
    -file [file normalize "$rptDir/timing_failing_setup.rpt"]
report_timing -max_paths 20 -nworst 5 -delay_type min -sort_by slack \
    -file [file normalize "$rptDir/timing_failing_hold.rpt"]

puts "\[3/6\] Clock reports..."
report_clock_interaction -delay_type min_max \
    -file [file normalize "$rptDir/clock_interaction.rpt"]
report_clock_networks \
    -file [file normalize "$rptDir/clock_networks.rpt"]

# ==============================================================================
# Utilization Reports
# ==============================================================================
puts "\[4/6\] Utilization..."
report_utilization -hierarchical -hierarchical_depth 4 \
    -file [file normalize "$rptDir/utilization_hierarchical.rpt"]
report_utilization \
    -file [file normalize "$rptDir/utilization_summary.rpt"]

# ==============================================================================
# Design Analysis
# ==============================================================================
puts "\[5/6\] DRC / methodology / CDC..."
report_methodology -file [file normalize "$rptDir/methodology.rpt"]
report_drc -file [file normalize "$rptDir/drc.rpt"]
report_cdc -details -file [file normalize "$rptDir/cdc.rpt"]

# ==============================================================================
# Power & Congestion
# ==============================================================================
puts "\[6/6\] Power & congestion..."
report_power -advisory -file [file normalize "$rptDir/power.rpt"]
report_design_analysis -congestion -complexity \
    -file [file normalize "$rptDir/congestion.rpt"]

# ==============================================================================
# Console Summary
# ==============================================================================
puts "\n========================================================================"
puts "  REPORT SUMMARY"
puts "========================================================================"

set setupPaths [get_timing_paths -max_paths 1 -nworst 1 -delay_type max]
if {[llength $setupPaths]} {
    set wns [get_property SLACK $setupPaths]
    puts "  Post-impl WNS = ${wns} ns"
}

puts "\n  Reports saved to: $rptDir/"
foreach f [lsort [glob -nocomplain $rptDir/*.rpt]] {
    puts "    [file tail $f] ([format %.1f [expr {[file size $f]/1024.0}]] KB)"
}
puts "========================================================================"
