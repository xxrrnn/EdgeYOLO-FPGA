# 完整流程：0→1→2→3
# 续跑（不重跑 BD/综合）：
#   RESUME_FROM=opt   — 从 post_opt.dcp 重读 XDC → place → route
#   RESUME_FROM=place — 从 post_place.dcp 重读 XDC → phys_opt → route
#
# 示例：
#   vivado -mode batch -source scripts/chip-lite/run.tcl
#   RESUME_FROM=place vivado -mode batch -source scripts/chip-lite/run.tcl

set thisScriptDir [file dirname [file normalize [info script]]]

set resumeFrom ""
if {[info exists ::env(RESUME_FROM)]} {
    set resumeFrom [string tolower [string trim $::env(RESUME_FROM)]]
}

if {$resumeFrom eq "place" || $resumeFrom eq "opt"} {
    source [file normalize "$thisScriptDir/config.tcl"]
    set xpr [file normalize "$projPath/${bdName}.xpr"]
    if {![file exists $xpr]} {
        error "Project not found: $xpr (run full flow first: vivado -mode batch -source scripts/chip-lite/run.tcl)"
    }
    set dcpNeeded [file normalize "$ImplOutputDir/post_${resumeFrom}.dcp"]
    if {![file exists $dcpNeeded]} {
        error "RESUME_FROM=$resumeFrom requires checkpoint: $dcpNeeded (not found). Run full flow first."
    }
    open_project $xpr
    set ::chipLiteResumeFrom $resumeFrom
    source [file normalize "$thisScriptDir/2_synth.tcl"]
    source [file normalize "$thisScriptDir/3_rpt.tcl"]
} else {
    if {$resumeFrom ne ""} {
        puts "WARNING: Unknown RESUME_FROM='$resumeFrom' — running full 0→1→2→3 flow"
    }
    source [file normalize "$thisScriptDir/0_build.tcl"]
    source [file normalize "$thisScriptDir/1_bd.tcl"]
    source [file normalize "$thisScriptDir/2_synth.tcl"]
    source [file normalize "$thisScriptDir/3_rpt.tcl"]
}
