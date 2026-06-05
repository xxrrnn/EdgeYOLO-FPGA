# ==============================================================================
# run.tcl — 完整流程入口（顺序执行 config → build → bd → synth → rpt）
# ==============================================================================
# 用法:
#   vivado -mode batch -source scripts/chip-lite/run.tcl
#
# 环境变量:
#   RESUME_FROM=opt    从 post_opt.dcp 恢复（跳过 build/bd/synth，重跑 place→route→bit）
#   RESUME_FROM=place  从 post_place.dcp 恢复（跳过到 phys_opt→route→bit）
# ==============================================================================

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

# --- Resume 模式 ---
set resumeFrom ""
if {[info exists ::env(RESUME_FROM)]} {
    set resumeFrom [string tolower [string trim $::env(RESUME_FROM)]]
}

if {$resumeFrom ne "" && $resumeFrom ne "opt" && $resumeFrom ne "place"} {
    puts "WARNING: Unknown RESUME_FROM='$resumeFrom' — running full flow."
    set resumeFrom ""
}

if {$resumeFrom ne ""} {
    # Resume 模式：打开工程，加载 checkpoint，从指定阶段继续
    set xpr [file normalize "$projPath/${projName}.xpr"]
    if {![file exists $xpr]} {
        error "Project not found: $xpr — run full flow first."
    }
    open_project $xpr

    if {$resumeFrom eq "opt"} {
        set dcp [file normalize "$ImplOutputDir/post_opt.dcp"]
    } else {
        set dcp [file normalize "$ImplOutputDir/post_place.dcp"]
    }
    if {![file exists $dcp]} {
        error "Checkpoint not found: $dcp — run full flow first."
    }

    puts "INFO: RESUME_FROM=$resumeFrom — loading $dcp"
    open_checkpoint $dcp

    # 重新加载 XDC
    set pbs [get_pblocks -quiet]
    if {[llength $pbs]} { delete_pblocks $pbs }
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip.xdc"]

    file mkdir $ImplOutputDir

    if {$resumeFrom eq "opt"} {
        # place → phys_opt → route → bit
        set_param general.maxThreads 1
        place_design -directive $placeDirective
        set_param general.maxThreads 8
        write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
        report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
    }

    # phys_opt → route → bit
    phys_opt_design -directive $physOptDirective
    write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt.dcp"]

    route_design -directive $routeDirective
    write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
    report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]

    set paths [get_timing_paths -max_paths 1 -delay_type max]
    set wns 0.0
    if {[llength $paths]} { set wns [get_property SLACK [lindex $paths 0]] }
    puts "INFO: Post-route WNS = ${wns} ns"

    if {$wns >= 0} {
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]
        puts "INFO: Bitstream written."
    } else {
        puts "ERROR: Timing not met — bitstream skipped."
    }

    # 报告
    source [file normalize "$thisScriptDir/4_rpt.tcl"]
} else {
    # --- 完整流程 ---
    source [file normalize "$thisScriptDir/1_build.tcl"]
    source [file normalize "$thisScriptDir/2_bd.tcl"]
    source [file normalize "$thisScriptDir/3_synth.tcl"]
    source [file normalize "$thisScriptDir/4_rpt.tcl"]
}

puts "\n======== run.tcl DONE ========"
