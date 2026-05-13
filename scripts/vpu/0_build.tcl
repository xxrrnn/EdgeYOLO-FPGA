# VPU（PE/DCIM + XDMA + CDMA）工程创建。
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

if {[llength [info commands create_project]] == 0} {
    error "This script must be sourced in Vivado Tcl, not plain tclsh."
}

if {[llength [get_projects -quiet]] != 0} {
    close_project
}

if {[file exists $projPath]} {
    puts "Info: Project directory exists, removing: $projPath"
    file delete -force $projPath
}

create_project $projName $projPath -part $part
set_property board_part $boardPart [current_project]

source [file normalize "$scriptsDir/ip/floating_point_fp32.tcl"]
fp32_mac_ips_create

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/$bdName/*.xdc"]] {
    add_files -fileset constrs_1 $xdcFile
}
