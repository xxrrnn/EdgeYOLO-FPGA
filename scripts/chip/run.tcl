set thisScriptDir [file dirname [file normalize [info script]]]

source [file normalize "$thisScriptDir/0_build.tcl"]
source [file normalize "$thisScriptDir/1_bd.tcl"]
source [file normalize "$thisScriptDir/2_synth.tcl"]
source [file normalize "$thisScriptDir/3_rpt.tcl"]
