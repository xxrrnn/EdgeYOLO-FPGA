set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

set synthDcp [file normalize "$SynOutputDir/post_synth.dcp"]
set optDcp   [file normalize "$ImplOutputDir/post_opt.dcp"]
set placeDcp [file normalize "$ImplOutputDir/post_place.dcp"]
set routeDcp [file normalize "$ImplOutputDir/post_route.dcp"]

file mkdir $ImplOutputDir

# ============================================================================
# DSP 修复 proc：Group7/Tile7 乘法器强制到 LUT（在 open_checkpoint 后调用）
# ============================================================================
proc fix_dsp_overuse {} {
    set cells [get_cells -quiet -hierarchical -filter \
        {NAME =~ *gen_groups\[7\].u_group/gen_tiles\[7\]*u_multiplier*}]
    if {[llength $cells] == 0} {
        # 尝试宽泛匹配
        set cells [get_cells -quiet -hierarchical -filter \
            {REF_NAME == DSP48E2 && NAME =~ *gen_groups\[7\]*gen_tiles\[7\]*}]
    }
    if {[llength $cells] > 0} {
        set_property DONT_TOUCH FALSE $cells
        # 手动转换：把 DSP48E2 的 USE_DSP 属性设为 no
        foreach c $cells {
            catch {set_property USE_DSP no $c}
        }
        puts "INFO: DSP fix: [llength $cells] cells in Group7/Tile7 targeted"
    } else {
        puts "WARNING: DSP fix: no Group7/Tile7 cells found, skipping"
    }
}

# ============================================================================
# 断点续跑：从已有的最新 checkpoint 开始
# ============================================================================
if {[file exists $routeDcp]} {
    puts "INFO: post_route.dcp exists, re-running reports and bitstream."
    open_checkpoint $routeDcp

} elseif {[file exists $placeDcp]} {
    puts "INFO: Resuming from post_place.dcp"
    open_checkpoint $placeDcp

    phys_opt_design -directive $physOptDirectiveAp
    write_checkpoint -force $ImplOutputDir/post_phys_opt_ap.dcp
    report_timing_summary -file $ImplOutputDir/post_phys_opt_ap_timing_summary.rpt
    report_utilization    -file $ImplOutputDir/post_phys_opt_ap_util.rpt

    route_design -directive $routeDirective
    write_checkpoint -force $routeDcp

} elseif {[file exists $optDcp]} {
    puts "INFO: Resuming from post_opt.dcp"
    open_checkpoint $optDcp

    set setupPaths [get_timing_paths -max_paths 1 -delay_type max]
    if {[llength $setupPaths] > 0} {
        set wns [get_property SLACK $setupPaths]
        puts "INFO: Post-Opt WNS = ${wns} ns"
        if {$wns < -1.5} {
            error "Timing gate: WNS = ${wns} ns. Fix RTL first."
        }
    }

    place_design -directive $placeDirective
    write_checkpoint -force $ImplOutputDir/post_place.dcp
    report_timing_summary -file $ImplOutputDir/post_place_timing_summary.rpt
    report_utilization    -file $ImplOutputDir/post_place_util.rpt

    phys_opt_design -directive $physOptDirectiveAp
    write_checkpoint -force $ImplOutputDir/post_phys_opt_ap.dcp
    report_timing_summary -file $ImplOutputDir/post_phys_opt_ap_timing_summary.rpt
    report_utilization    -file $ImplOutputDir/post_phys_opt_ap_util.rpt

    route_design -directive $routeDirective
    write_checkpoint -force $routeDcp

} elseif {[file exists $synthDcp]} {
    puts "INFO: Resuming from post_synth.dcp (running full impl flow)"
    open_checkpoint $synthDcp

    # 应用 XDC 约束（synth checkpoint 不含 impl XDC）
    foreach xdcFile [glob -nocomplain [file normalize \
        "[file dirname [file dirname $thisScriptDir]]/xdc/chip/*.xdc"]] {
        read_xdc $xdcFile
        puts "INFO: Loaded XDC: $xdcFile"
    }

    opt_design -directive $optDirective
    write_checkpoint -force $optDcp
    report_timing_summary -file $ImplOutputDir/post_opt_timing_summary.rpt
    report_utilization    -file $ImplOutputDir/post_opt_util.rpt

    set setupPaths [get_timing_paths -max_paths 1 -delay_type max]
    if {[llength $setupPaths] > 0} {
        set wns [get_property SLACK $setupPaths]
        puts "INFO: Post-Opt WNS = ${wns} ns"
        if {$wns < -1.5} {
            error "Timing gate: WNS = ${wns} ns. Fix RTL first."
        }
    }

    place_design -directive $placeDirective
    write_checkpoint -force $ImplOutputDir/post_place.dcp
    report_timing_summary -file $ImplOutputDir/post_place_timing_summary.rpt
    report_utilization    -file $ImplOutputDir/post_place_util.rpt

    phys_opt_design -directive $physOptDirectiveAp
    write_checkpoint -force $ImplOutputDir/post_phys_opt_ap.dcp
    report_timing_summary -file $ImplOutputDir/post_phys_opt_ap_timing_summary.rpt
    report_utilization    -file $ImplOutputDir/post_phys_opt_ap_util.rpt

    route_design -directive $routeDirective
    write_checkpoint -force $routeDcp

} else {
    error "No checkpoint found. Please run run.tcl (0_build + 1_bd + synth) first."
}

# ============================================================================
# 最终报告
# ============================================================================
report_timing_summary -file $ImplOutputDir/post_route_timing_summary.rpt
report_utilization    -file $ImplOutputDir/post_route_util.rpt
report_utilization -hierarchical -hierarchical_depth 5 \
    -file $ImplOutputDir/post_route_area_hierarchical.rpt

# 生成 failing path 详细报告
file mkdir $ImplOutputDir/reports
report_timing -max_paths 500 -nworst 5 -delay_type max -sort_by slack \
    -file $ImplOutputDir/reports/timing_failing_setup.rpt

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]

puts "INFO: Implementation complete. Bitstream: $ImplOutputDir/top.bit"
