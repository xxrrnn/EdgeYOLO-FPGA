# 3_rpt.tcl - 生成详细的时序和资源利用率报告
# 在 2_synth.tcl 之后执行，用于查看 error 和进一步优化
# 用法: vivado -mode batch -source scripts/vpu/3_rpt.tcl
#       或在已打开工程中: source scripts/vpu/3_rpt.tcl

set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
}

file mkdir $ImplOutputDir
set rptDir [file normalize "$ImplOutputDir/reports"]
file mkdir $rptDir

# 加载最新的 post-route checkpoint
set postRouteDcp [file normalize "$ImplOutputDir/post_phys_opt_ar.dcp"]
if {![file exists $postRouteDcp]} {
    set postRouteDcp [file normalize "$ImplOutputDir/post_route.dcp"]
}
if {![file exists $postRouteDcp]} {
    error "No post-route checkpoint found. Run 2_synth.tcl first."
}

puts "========================================================================"
puts "  Loading checkpoint: $postRouteDcp"
puts "========================================================================"
open_checkpoint $postRouteDcp

# ============================================================================
# 1. Timing Reports
# ============================================================================
puts "\n\[1/7\] Generating timing summary..."
report_timing_summary -max_paths 10 -report_unconstrained \
    -file [file normalize "$rptDir/timing_summary.rpt"]

puts "\[2/7\] Generating detailed failing paths (all setup violations)..."
report_timing -slack_less_than 0 -max_paths 1000000 -nworst 1 -delay_type max -sort_by slack \
    -file [file normalize "$rptDir/timing_failing_setup.rpt"]

report_timing -max_paths 20 -nworst 5 -delay_type min -sort_by slack \
    -file [file normalize "$rptDir/timing_failing_hold.rpt"]

puts "\[3/7\] Generating clock interaction report..."
report_clock_interaction -delay_type min_max \
    -file [file normalize "$rptDir/clock_interaction.rpt"]

report_clock_networks \
    -file [file normalize "$rptDir/clock_networks.rpt"]

# ============================================================================
# 2. Utilization Reports
# ============================================================================
puts "\[4/7\] Generating utilization reports..."
report_utilization -hierarchical -hierarchical_depth 4 \
    -file [file normalize "$rptDir/utilization_hierarchical.rpt"]

report_utilization \
    -file [file normalize "$rptDir/utilization_summary.rpt"]

# ============================================================================
# 3. Design Analysis
# ============================================================================
puts "\[5/7\] Generating design analysis..."
report_methodology \
    -file [file normalize "$rptDir/methodology.rpt"]

report_drc \
    -file [file normalize "$rptDir/drc.rpt"]

report_cdc -details \
    -file [file normalize "$rptDir/cdc.rpt"]

# ============================================================================
# 4. Power & Congestion
# ============================================================================
puts "\[6/7\] Generating power and congestion reports..."
report_power -advisory \
    -file [file normalize "$rptDir/power.rpt"]

report_design_analysis -congestion -complexity \
    -file [file normalize "$rptDir/congestion.rpt"]

# ============================================================================
# 5. Quick Summary to Console
# ============================================================================
puts "\[7/7\] Generating summary...\n"
puts "========================================================================"
puts "  REPORT SUMMARY"
puts "========================================================================"

set timRpt [report_timing_summary -no_header -return_string]
if {[regexp {WNS\(ns\)\s+TNS\(ns\).*?\n\s+-------.*?\n\s+([^\n]+)} $timRpt -> line]} {
    puts "  Timing: $line"
}

set wns [get_property STATS.WNS [get_runs impl_1] -quiet]
set tns [get_property STATS.TNS [get_runs impl_1] -quiet]
if {$wns ne ""} {
    puts "  WNS = ${wns} ns"
    puts "  TNS = ${tns} ns"
}

puts "\n  Reports saved to: $rptDir/"
puts "  Files:"
foreach f [lsort [glob -nocomplain $rptDir/*.rpt]] {
    set fsize [file size $f]
    puts "    [file tail $f] ([format %.1f [expr {$fsize/1024.0}]] KB)"
}
puts "========================================================================"
