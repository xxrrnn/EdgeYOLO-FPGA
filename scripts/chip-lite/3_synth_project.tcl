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
for {set _tidx 0} {$_tidx < $::DCIM_NUM_TILES} {incr _tidx} {
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

if {[info exists stopAfter] && $stopAfter eq "opt"} {
    puts "INFO: STOP_AFTER=opt — stopping after post_opt.dcp."
    return
}

# ==============================================================================
# Step 3~6: Place → Phys Opt → Route → Bitstream (with Retry)
# ==============================================================================
puts "\n========== Step 3-6: Implementation with Retry =========="

set optDcp [file normalize "$ImplOutputDir/post_opt.dcp"]
set bestWns -999.0
set bestStrategy ""
set timingMet 0

for {set _retry_idx 0} {$_retry_idx < [llength $retryStrategies]} {incr _retry_idx} {
    set _strat [lindex $retryStrategies $_retry_idx]
    set _placeDir  [lindex $_strat 0]
    set _physDir   [lindex $_strat 1]
    set _routeDir  [lindex $_strat 2]

    set _attempt [expr {$_retry_idx + 1}]
    set _totalAttempts [llength $retryStrategies]
    puts "\n================================================================"
    puts "  ATTEMPT $_attempt/$_totalAttempts: place=$_placeDir  phys_opt=$_physDir  route=$_routeDir"
    puts "================================================================"

    if {$_retry_idx > 0} {
        close_design -quiet
        open_checkpoint $optDcp
        set pbs [get_pblocks -quiet]
        if {[llength $pbs]} { delete_pblocks $pbs }
        read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
    }

    # --- Place ---
    puts "\n---------- Place Design (attempt $_attempt) ----------"
    catch {set_param place.ILREnabled false}
    use_place_threads
    place_design -directive $_placeDir
    use_vivado_threads

    set _placeDcp [file normalize "$ImplOutputDir/post_place_attempt${_attempt}.dcp"]
    write_checkpoint -force $_placeDcp
    report_timing_summary -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_timing.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_failing.rpt"]
    report_utilization -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_util.rpt"]
    report_design_analysis -congestion \
        -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_congestion.rpt"]

    set _pp [get_timing_paths -max_paths 1 -delay_type max]
    set _ppWns 0.0
    if {[llength $_pp]} { set _ppWns [get_property SLACK [lindex $_pp 0]] }
    puts "INFO: Post-place WNS (attempt $_attempt) = ${_ppWns} ns"
    if {$_ppWns < $wns_stop_place} {
        puts "WARNING: Post-place WNS ${_ppWns} < threshold ${wns_stop_place} — skipping this strategy."
        continue
    }

    # --- Phys Opt ---
    puts "\n---------- Phys Opt Design (attempt $_attempt) ----------"
    phys_opt_design -directive $_physDir

    write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_attempt${_attempt}.dcp"]
    report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_attempt${_attempt}_timing.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$ImplOutputDir/post_phys_opt_attempt${_attempt}_failing.rpt"]

    # --- Route ---
    puts "\n---------- Route Design (attempt $_attempt) ----------"
    use_route_threads
    route_design -directive $_routeDir

    # --- Post-route phys_opt (setup + hold) ---
    phys_opt_design -directive AggressiveExplore
    phys_opt_design -hold_fix
    puts "INFO: Post-route phys_opt (setup + hold) done (attempt $_attempt)"

    set _routeDcp [file normalize "$ImplOutputDir/post_route_attempt${_attempt}.dcp"]
    write_checkpoint -force $_routeDcp
    report_timing_summary -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_timing.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_failing.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type min \
        -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_hold.rpt"]
    report_utilization -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_util.rpt"]
    report_design_analysis -congestion -complexity \
        -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_congestion.rpt"]

    set _rp [get_timing_paths -max_paths 1 -delay_type max]
    set _rWns 0.0
    if {[llength $_rp]} { set _rWns [get_property SLACK [lindex $_rp 0]] }
    set _rHp [get_timing_paths -max_paths 1 -delay_type min]
    set _rWhs 0.0
    if {[llength $_rHp]} { set _rWhs [get_property SLACK [lindex $_rHp 0]] }
    puts "INFO: Post-route (attempt $_attempt): WNS = ${_rWns} ns  WHS = ${_rWhs} ns"

    if {$_rWns > $bestWns} {
        set bestWns $_rWns
        set bestStrategy "$_placeDir/$_physDir/$_routeDir"
    }

    if {$_rWns >= 0 && $_rWhs >= 0} {
        puts "INFO: *** TIMING MET on attempt $_attempt! ***"
        set timingMet 1

        file copy -force $_routeDcp [file normalize "$ImplOutputDir/post_route.dcp"]
        report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
        report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]
        report_drc -file [file normalize "$ImplOutputDir/post_route_drc.rpt"]
        report_methodology -file [file normalize "$ImplOutputDir/post_route_methodology.rpt"]
        report_power -advisory -file [file normalize "$ImplOutputDir/post_route_power.rpt"]

        puts "\n========== Write Bitstream =========="
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]
        puts "INFO: Bitstream written: $ImplOutputDir/top.bit"

        set wns $_rWns
        break
    }

    puts "INFO: Attempt $_attempt timing NOT met — trying next strategy..."
}

if {!$timingMet} {
    puts ""
    puts "============================================================"
    puts "  ALL $_totalAttempts STRATEGIES FAILED"
    puts "  Best WNS = ${bestWns} ns (strategy: $bestStrategy)"
    puts "============================================================"
    set wns $bestWns
    error "\[timing_retry\] All strategies exhausted. Best WNS=${bestWns}ns ($bestStrategy)"
}

puts "INFO: 3_synth_project complete — full project mode implementation successful."
