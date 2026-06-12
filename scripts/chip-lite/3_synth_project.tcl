# ==============================================================================
# 3_synth_project.tcl — Project Mode 实现全流程
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
if {![info exists ScriptDir]} { source [file normalize "$thisScriptDir/config.tcl"] }

if {[llength [get_projects -quiet]] == 0} {
    set xpr [file normalize "$projPath/${projName}.xpr"]
    if {![file exists $xpr]} { error "Project not found: $xpr" }
    open_project $xpr
}

file mkdir $SynOutputDir
file mkdir $ImplOutputDir

# ==============================================================================
proc reload_xdc {} {
    global xdcDir
    set pbs [get_pblocks -quiet]
    if {[llength $pbs]} { delete_pblocks $pbs }
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
}

proc user_clk {} {
    set clk [get_clocks -quiet clk_main]
    if {![llength $clk]} { set clk [get_clocks -quiet bram_clk_a] }
    return $clk
}

proc timing_gate {stage} {
    global wns_stop_place tns_stop_place fail_stop_place wns_warn_place ImplOutputDir

    set clk [user_clk]
    if {[llength $clk]} {
        set clkName [get_property NAME [lindex $clk 0]]
        set paths [get_timing_paths -max_paths 500000 -delay_type max -group $clk \
                       -slack_lesser_than 0]
    } else {
        set clkName "all_clocks"
        set paths [get_timing_paths -max_paths 500000 -delay_type max \
                       -slack_lesser_than 0]
    }

    set failing [llength $paths]
    if {$failing == 0} {
        puts "INFO: \[timing_gate\] $stage ($clkName): setup clean."
        return
    }

    set wns [get_property SLACK [lindex $paths 0]]
    set tns 0.0
    foreach p $paths { set tns [expr {$tns + [get_property SLACK $p]}] }

    set stop 0
    set reasons {}
    if {$wns < $wns_stop_place} {
        lappend reasons "WNS=${wns}ns (threshold: ${wns_stop_place}ns)"
        set stop 1
    }
    if {$tns < $tns_stop_place} {
        lappend reasons "TNS=${tns}ns (threshold: ${tns_stop_place}ns)"
        set stop 1
    }
    if {$failing > $fail_stop_place} {
        lappend reasons "Failing=${failing} (threshold: ${fail_stop_place})"
        set stop 1
    }

    if {$stop} {
        puts "ERROR: \[timing_gate\] $stage ($clkName) — STOP."
        foreach r $reasons { puts "ERROR:   $r" }
        error "\[timing_gate\] Aborting at $stage: timing too poor to continue."
    }

    if {$wns < $wns_warn_place} {
        puts "WARNING: \[timing_gate\] $stage ($clkName) WNS=${wns}ns TNS=${tns}ns failing=${failing}"
    } else {
        puts "INFO: \[timing_gate\] $stage ($clkName) WNS=${wns}ns TNS=${tns}ns failing=${failing}"
    }
}

# ==============================================================================
# Step 1: Synthesis (Project Mode)
# ==============================================================================
puts "\n========== Step 1: Synthesis (project mode) =========="

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[llength [get_files -quiet $bdFile]] == 0} { add_files -norecurse $bdFile }

set wrapperFile [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
if {[llength [get_files -quiet $wrapperFile]] == 0} { add_files -norecurse $wrapperFile }
set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[string match "*chip_timing*" $xdcFile]} { continue }
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value "-directive $synDirective -resource_sharing auto" \
    -objects [get_runs synth_1]

launch_runs synth_1 -jobs $synthJobs
wait_on_runs synth_1

set _synth_status [get_property STATUS [get_runs synth_1]]
if {![regexp -nocase {synth_design complete} $_synth_status]} {
    error "Synthesis failed: STATUS=$_synth_status"
}
puts "INFO: synth_1 completed: $_synth_status"

open_run synth_1 -name synth_1

write_checkpoint -force [file normalize "$SynOutputDir/post_synth.dcp"]
reload_xdc
report_timing_summary -file [file normalize "$SynOutputDir/post_synth_timing_summary.rpt"]
report_utilization -file [file normalize "$SynOutputDir/post_synth_util.rpt"]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file normalize "$SynOutputDir/area_report_hierarchical.rpt"]

set _dsp_total [llength [get_cells -hierarchical -filter {REF_NAME == DSP48E2}]]
puts "INFO: Synthesis complete. DSP48E2 total: $_dsp_total"
foreach _tidx {0 1 2 3} {
    set _tdsp [llength [get_cells -hierarchical -filter "REF_NAME == DSP48E2 && NAME =~ *gen_tiles\[$_tidx\]*"]]
    puts "INFO:   Tile $_tidx: $_tdsp DSP48E2"
}
if {$_dsp_total > 9024} {
    error "FATAL: Total DSP48E2 ($_dsp_total) exceeds device capacity (9024)!"
}

# ==============================================================================
# Step 2: Opt Design
# ==============================================================================
puts "\n========== Step 2: Opt Design =========="

opt_design -directive $optDirective

write_checkpoint -force [file normalize "$ImplOutputDir/post_opt.dcp"]
reload_xdc
report_timing_summary -file [file normalize "$ImplOutputDir/post_opt_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_opt_util.rpt"]

# ==============================================================================
# Step 3: Place Design
# ==============================================================================
puts "\n========== Step 3: Place Design =========="

catch {set_param place.ILREnabled false}
set_param general.maxThreads 8
place_design -directive $placeDirective
set_param general.maxThreads 32

write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
    -file [file normalize "$ImplOutputDir/post_place_failing_paths.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_place_util.rpt"]
report_design_analysis -congestion \
    -file [file normalize "$ImplOutputDir/post_place_congestion.rpt"]

timing_gate "post-place"

# ==============================================================================
# Step 4: Physical Optimization
# ==============================================================================
puts "\n========== Step 4: Phys Opt Design =========="

phys_opt_design -directive $physOptDirective

write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_timing_summary.rpt"]
report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
    -file [file normalize "$ImplOutputDir/post_phys_opt_failing_paths.rpt"]

# ==============================================================================
# Step 5: Route Design
# ==============================================================================
puts "\n========== Step 5: Route Design =========="

set_param general.maxThreads 32
route_design -directive $routeDirective

phys_opt_design -hold_fix -directive AggressiveExplore
puts "INFO: Post-route hold phys_opt done"

write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
    -file [file normalize "$ImplOutputDir/post_route_failing_paths.rpt"]
report_timing -max_paths 20 -slack_lesser_than 0.0 -delay_type min \
    -file [file normalize "$ImplOutputDir/post_route_failing_hold.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]
report_drc -file [file normalize "$ImplOutputDir/post_route_drc.rpt"]
report_methodology -file [file normalize "$ImplOutputDir/post_route_methodology.rpt"]
report_design_analysis -congestion -complexity \
    -file [file normalize "$ImplOutputDir/post_route_congestion.rpt"]
report_power -advisory -file [file normalize "$ImplOutputDir/post_route_power.rpt"]

set routePaths [get_timing_paths -max_paths 1 -delay_type max]
set routeWns 0.0
if {[llength $routePaths]} {
    set routeWns [get_property SLACK [lindex $routePaths 0]]
}
set routeHoldPaths [get_timing_paths -max_paths 1 -delay_type min]
set routeWhs 0.0
if {[llength $routeHoldPaths]} {
    set routeWhs [get_property SLACK [lindex $routeHoldPaths 0]]
}
puts "INFO: Post-route WNS = ${routeWns} ns  WHS = ${routeWhs} ns"

if {$routeWns < 0} {
    puts "ERROR: Post-route setup timing NOT MET (WNS=${routeWns}ns). Bitstream skipped."
    error "\[timing_gate\] post-route WNS=${routeWns}ns — setup not met."
}
if {$routeWhs < 0} {
    puts "ERROR: Post-route hold timing NOT MET (WHS=${routeWhs}ns). Bitstream skipped."
    error "\[timing_gate\] post-route WHS=${routeWhs}ns — hold not met."
}

# ==============================================================================
# Step 6: Bitstream
# ==============================================================================
puts "\n========== Step 6: Write Bitstream =========="

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]

puts "INFO: Bitstream written: $ImplOutputDir/top.bit"
puts "INFO: 3_synth_project complete — full project mode implementation successful."
