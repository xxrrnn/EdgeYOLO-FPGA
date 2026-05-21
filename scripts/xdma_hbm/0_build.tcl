set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]


create_project $projName $projPath -part $part -force
set_property board_part $boardPart [current_project]