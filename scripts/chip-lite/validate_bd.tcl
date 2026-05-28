# validate_bd.tcl - rebuild lite project, create block design, and run validate_bd_design.
# This intentionally reuses the same flow as 0_build.tcl + 1_bd.tcl so validation
# cannot drift from the real chip-lite BD generation path.
# Usage: vivado -mode batch -source scripts/chip-lite/validate_bd.tcl

set thisScriptDir [file dirname [file normalize [info script]]]

if {[llength [info commands create_project]] == 0} {
    error "This script must be sourced in Vivado Tcl, not plain tclsh."
}

source [file normalize "$thisScriptDir/0_build.tcl"]
source [file normalize "$thisScriptDir/1_bd.tcl"]

puts ""
puts "=============================="
puts "  BD Validation: SUCCESS"
puts "  BD saved. Synthesis not started."
puts "=============================="
