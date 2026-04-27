# XDMA BRAM project creation script.
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/3_config.tcl"]

if {[llength [info commands create_project]] == 0} {
    error "This script must be sourced in Vivado Tcl, not plain tclsh."
}

if {[llength [get_projects -quiet]] != 0} {
    close_project
}

# 如果工程已存在，直接删除后重建
if {[file exists $projPath]} {
    puts "Info: Project directory exists, removing: $projPath"
    file delete -force $projPath
}

create_project $projName $projPath -part $part
set_property board_part $boardPart [current_project]

# add xdc for led
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/$bdName/*.xdc"]] {
    add_files -fileset constrs_1 $xdcFile
}
