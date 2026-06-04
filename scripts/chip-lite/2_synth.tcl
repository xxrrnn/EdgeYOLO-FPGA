set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

# ---------------------------------------------------------------------------
# 用户主时钟（250MHz XDMA/AXI 域）— 时序门控只检查此域，不含 GT/HBM 等
# ---------------------------------------------------------------------------
proc chip_lite_user_clk {} {
    set clk [get_clocks -quiet clk_main]
    if {![llength $clk]} {
        set clk [get_clocks -quiet bram_clk_a]
    }
    return $clk
}

proc chip_lite_reload_xdc {} {
    global xdcDir
    set _old_pbs [get_pblocks -quiet]
    if {[llength $_old_pbs]} {
        puts "INFO: Deleting [llength $_old_pbs] stale pblock(s) before re-read XDC"
        delete_pblocks $_old_pbs
    }
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip.xdc"]
}

# 统计指定 clock 域 setup 违例（report_timing_summary 无 -group 选项，用 get_timing_paths）
proc chip_lite_clk_violation_stats {clk} {
    set violators [get_timing_paths -max_paths 500000 -delay_type max -group $clk \
        -slack_lesser_than 0]
    set failing [llength $violators]
    if {$failing == 0} {
        return [list 0.0 0.0 0]
    }
    set wns [get_property SLACK [lindex $violators 0]]
    set tns 0.0
    foreach p $violators {
        set tns [expr {$tns + [get_property SLACK $p]}]
    }
    return [list $wns $tns $failing]
}

proc chip_lite_parse_setup_summary {rpt} {
    foreach line [split $rpt "\n"] {
        if {[regexp {^\s*([-0-9.]+)\s+([-0-9.]+)\s+(\d+)\s+\d+\s+} $line -> wns_val tns_val fail_val]} {
            return [list [expr {double($wns_val)}] [expr {double($tns_val)}] [expr {int($fail_val)}]]
        }
    }
    return {}
}

# post-place 门控：仅 user clock；违例超阈值则中止（不浪费 route 时间）
proc check_place_timing_gate_synth {} {
    set wns_stop   -3.5
    set tns_stop   -80000.0
    set fail_stop  50000
    set wns_warn   -2.0

    set clk [chip_lite_user_clk]
    if {[llength $clk]} {
        set clkName [get_property NAME [lindex $clk 0]]
        lassign [chip_lite_clk_violation_stats $clk] wns tns failing
    } else {
        set clkName "all_clocks"
        set setup_paths [get_timing_paths -max_paths 1 -delay_type max -filter {SLACK < 0}]
        if {![llength $setup_paths]} {
            puts "INFO: \[timing_gate\] post-place ($clkName): setup clean."
            return
        }
        set wns [get_property SLACK [lindex $setup_paths 0]]
        set parsed [chip_lite_parse_setup_summary \
            [report_timing_summary -no_detailed_paths -return_string]]
        set tns 0.0
        set failing 0
        if {[llength $parsed] == 3} {
            set tns     [lindex $parsed 1]
            set failing [lindex $parsed 2]
        }
    }

    if {$failing == 0} {
        puts "INFO: \[timing_gate\] post-place ($clkName): setup clean."
        return
    }

    set stop 0
    set reasons {}
    if {$wns < $wns_stop} {
        lappend reasons "WNS = ${wns} ns  (threshold: ${wns_stop} ns)"
        set stop 1
    }
    if {$tns < $tns_stop} {
        lappend reasons "TNS = ${tns} ns  (threshold: ${tns_stop} ns)"
        set stop 1
    }
    if {$failing > $fail_stop} {
        lappend reasons "Failing Endpoints = ${failing}  (threshold: ${fail_stop})"
        set stop 1
    }

    if {$stop} {
        puts "ERROR: \[timing_gate\] post-place ($clkName) setup violation — stopping."
        foreach r $reasons { puts "ERROR:   - $r" }
        puts "ERROR: Checkpoint: $::ImplOutputDir/post_place.dcp"
        puts "ERROR: Fix XDC/RTL then: RESUME_FROM=place vivado -mode batch -source scripts/chip-lite/run.tcl"
        error "\[timing_gate\] Aborting: post-place timing too poor to continue."
    }

    if {$wns < $wns_warn} {
        puts "WARNING: \[timing_gate\] post-place ($clkName) WNS=${wns} ns, TNS=${tns} ns, failing=${failing} — proceeding."
    } else {
        puts "INFO: \[timing_gate\] post-place ($clkName) OK. WNS=${wns} ns, TNS=${tns} ns, failing=${failing}."
    }
}

# post-route 门控：user clock 必须 MET 才写 bitstream
proc check_route_timing_gate_synth {} {
    set clk [chip_lite_user_clk]
    if {[llength $clk]} {
        set clkName [get_property NAME [lindex $clk 0]]
        set paths [get_timing_paths -max_paths 1 -delay_type max -group $clk]
    } else {
        set clkName "all_clocks"
        set paths [get_timing_paths -max_paths 1 -delay_type max]
    }
    if {![llength $paths]} {
        puts "WARNING: \[timing_gate\] post-route: no timing paths."
        return 0
    }
    set wns [get_property SLACK [lindex $paths 0]]
    puts "INFO: \[timing_gate\] post-route ($clkName) WNS = ${wns} ns"
    if {$wns < 0} {
        puts "ERROR: \[timing_gate\] post-route timing NOT MET on $clkName."
        puts "ERROR: Checkpoint: $::ImplOutputDir/post_route.dcp"
        error "\[timing_gate\] Aborting: post-route WNS = ${wns} ns."
    }
    return 1
}

proc chip_lite_impl_after_place {} {
    global ImplOutputDir physOptDirectiveAp routeDirective launchDir

    check_place_timing_gate_synth

    phys_opt_design -directive $physOptDirectiveAp
    write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_ap.dcp"]
    report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_ap_timing_summary.rpt"]
    report_utilization -file [file normalize "$ImplOutputDir/post_phys_opt_ap_util.rpt"]

    route_design -directive $routeDirective
    write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
    report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
    report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]
    report_utilization -hierarchical -hierarchical_depth 5 \
        -file [file normalize "$ImplOutputDir/post_route_area_hierarchical.rpt"]

    if {[check_route_timing_gate_synth]} {
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]
        puts "INFO: Bitstream written: $ImplOutputDir/top.bit"
    }
}

proc chip_lite_resume_impl {stage} {
    global ImplOutputDir placeDirective projPath

    set launchDir [pwd]
    cd $projPath

    if {$stage eq "opt"} {
        set dcp [file normalize "$ImplOutputDir/post_opt.dcp"]
        if {![file exists $dcp]} {
            error "Missing checkpoint: $dcp"
        }
        open_checkpoint $dcp
        chip_lite_reload_xdc
        set_param general.maxThreads 1
        catch {set_param place.ILREnabled false}
        place_design -directive $placeDirective
        set_param general.maxThreads 8
        write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
        report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
        report_utilization -file [file normalize "$ImplOutputDir/post_place_util.rpt"]
    } elseif {$stage eq "place"} {
        set dcp [file normalize "$ImplOutputDir/post_place.dcp"]
        if {![file exists $dcp]} {
            error "Missing checkpoint: $dcp"
        }
        open_checkpoint $dcp
        chip_lite_reload_xdc
    } else {
        error "chip_lite_resume_impl: unknown stage '$stage' (use opt or place)"
    }

    chip_lite_impl_after_place
    cd $launchDir
}

# ---------------------------------------------------------------------------
# RESUME 入口（run.tcl 设置 ::chipLiteResumeFrom）
# ---------------------------------------------------------------------------
if {[info exists ::chipLiteResumeFrom] && $::chipLiteResumeFrom ne ""} {
    chip_lite_resume_impl $::chipLiteResumeFrom
    return
}

# ---------------------------------------------------------------------------
# 完整综合 + 实现（0_build + 1_bd 之后）
# ---------------------------------------------------------------------------
source [file normalize "$scriptsDir/common/chip_lite_bd.tcl"]
chip_lite_ensure_project_open

file mkdir $SynOutputDir
file mkdir $ImplOutputDir

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
set wrapperFile [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]

if {![file exists $bdFile]} {
    error "BD file does not exist: $bdFile. Please source 1_bd.tcl before 2_synth.tcl."
}

if {[llength [get_files -quiet $bdFile]] == 0} {
    add_files -norecurse $bdFile
}

if {![file exists $wrapperFile]} {
    make_wrapper -files [get_files $bdFile] -top
}

if {![file exists $wrapperFile]} {
    error "BD wrapper was not generated: $wrapperFile"
}

if {[llength [get_files -quiet $wrapperFile]] == 0} {
    add_files -norecurse $wrapperFile
}

set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

source [file normalize "$scriptsDir/common/vivado_bd_ooc.tcl"]
vivado_run_bd_ip_synth $bdFile $projPath $bdDir $bdName $modRefIpTops

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

update_compile_order -fileset sources_1

if {[llength [get_runs -quiet impl_1]]} {
    set_property STRATEGY Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
    set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Default [get_runs impl_1]
    set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
}

set ipRoot [file normalize "$bdDir/$bdName/ip"]
vivado_ensure_ooc_xdc_stubs $ipRoot
vivado_assert_ooc_xdc_on_disk $ipRoot "2_synth pre-top-synth"
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force

synth_design -top $topName -part $part -directive $synDirective \
    -max_dsp 8800 -resource_sharing auto
write_checkpoint -force [file normalize "$SynOutputDir/post_synth.dcp"]
chip_lite_reload_xdc
report_timing_summary -file [file normalize "$SynOutputDir/post_synth_timing_summary.rpt"]
report_utilization -file [file normalize "$SynOutputDir/post_synth_util.rpt"]

set chipDiagDir [file normalize $projPath]
file mkdir $chipDiagDir

report_timing -max_paths 50 -slack_lesser_than 0 -delay_type max -sort_by slack \
    -file [file normalize "$chipDiagDir/worst_setup_paths.rpt"]
report_timing_summary -max_paths 10 -report_unconstrained \
    -file [file normalize "$chipDiagDir/timing_summary_detail.rpt"]
report_design_analysis -logic_level_distribution -timing \
    -file [file normalize "$chipDiagDir/logic_level_dist.rpt"]
report_clock_utilization \
    -file [file normalize "$chipDiagDir/clock_util.rpt"]
report_design_analysis -congestion \
    -file [file normalize "$chipDiagDir/congestion.rpt"]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file normalize "$chipDiagDir/area_report_hierarchical.rpt"]

set launchDir [pwd]
cd $projPath

opt_design -directive $optDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_opt.dcp"]
chip_lite_reload_xdc
report_timing_summary -file [file normalize "$ImplOutputDir/post_opt_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_opt_util.rpt"]

set mainClk [chip_lite_user_clk]
if {[llength $mainClk] > 0} {
    set setupPaths [get_timing_paths -max_paths 1 -delay_type max -group $mainClk]
} else {
    set setupPaths [get_timing_paths -max_paths 1 -delay_type max]
}
if {[llength $setupPaths] == 0} {
    puts "WARNING: No setup timing paths found; skipping Post-Opt WNS gate."
} else {
    set wns_post_opt [get_property SLACK $setupPaths]
    puts "INFO: Post-Opt WNS (user clock) = ${wns_post_opt} ns"
}

set_param general.maxThreads 1
catch {set_param place.ILREnabled false}
place_design -directive $placeDirective
set_param general.maxThreads 8
write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_place_util.rpt"]

chip_lite_impl_after_place

cd $launchDir
