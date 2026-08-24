# ==============================================================================
# run_bd_only.tcl — 只执行 1_build + 2_bd（为 Non-Project Mode 准备 IP DCP）
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

puts "INFO: BD-only flow — running 1_build + 2_bd, stopping before synth."

source [file normalize "$thisScriptDir/1_build.tcl"]
source [file normalize "$thisScriptDir/2_bd.tcl"]

puts "INFO: run_bd_only complete — IP stubs + OOC DCPs ready under $projPath"
puts "INFO: Next: make synth-np TAG=$runTag"
