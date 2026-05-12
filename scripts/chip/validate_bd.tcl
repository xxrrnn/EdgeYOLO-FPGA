# Validate BD design only (no synthesis)
set thisScriptDir [file dirname [file normalize [info script]]]

source [file normalize "$thisScriptDir/0_build.tcl"]
source [file normalize "$thisScriptDir/1_bd.tcl"]

puts "=========================================="
puts "Block Design validation completed!"
puts "=========================================="
