source [file normalize [file dirname [info script]]/config.tcl]
open_project [file normalize $projPath/${projName}.xpr]
reset_run lite_dcim_array_0_0_synth_1
launch_runs lite_dcim_array_0_0_synth_1 -jobs 8
wait_on_run lite_dcim_array_0_0_synth_1
set st [get_property STATUS [get_runs lite_dcim_array_0_0_synth_1]]
puts "STATUS=$st"
if {![string match "*Complete*" $st]} { exit 1 }
