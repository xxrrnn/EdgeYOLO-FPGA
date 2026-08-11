# Validate the streamed DCIM ports in the complete chip-lite block design.
#
# Usage (from the repository root):
#   BUILD_TAG=dcim_stream_bdcheck vivado -mode batch \
#     -source TEST/tops/fpga/validate_stream_bd.tcl

set thisScriptDir [file dirname [file normalize [info script]]]
set repoRoot [file normalize "$thisScriptDir/../../.."]

set ::env(BD_VALIDATE_ONLY) 1
source [file normalize "$repoRoot/scripts/chip-lite/config.tcl"]
source [file normalize "$repoRoot/scripts/chip-lite/1_build.tcl"]
source [file normalize "$repoRoot/scripts/chip-lite/2_bd.tcl"]

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
set wrapperFile [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
if {![file exists $bdFile]} {
    error "BD validation did not produce $bdFile"
}
if {![file exists $wrapperFile]} {
    error "BD validation did not produce $wrapperFile"
}

puts "STREAM_BD_VALIDATE_PASS bd=$bdFile wrapper=$wrapperFile"
close_project
