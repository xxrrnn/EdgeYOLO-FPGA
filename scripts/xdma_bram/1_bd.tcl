# create block design
set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

if {[llength [get_projects -quiet]] == 0} {
    error "Please source 0_build.tcl before 1_bd.tcl."
}

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[llength [get_files -quiet $bdFile]] != 0} {
    remove_files $bdFile
}
if {[file exists [file dirname $bdFile]]} {
    file delete -force [file dirname $bdFile]
}

create_bd_design -dir $bdDir $bdName

set rtlFiles [glob -nocomplain [file normalize "$srcDir/xdma_bram/*.v"]]
if {[llength $rtlFiles] == 0} {
    error "No RTL files found in $srcDir/xdma_bram"
}
add_files -norecurse $rtlFiles
create_bd_cell -type module -reference xdma_bram_axil_ctrl_top xdma_bram_axil_ctrl_0
source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/bram.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]
source [file normalize "$ipBdDir/address.tcl"]

validate_bd_design
regenerate_bd_layout
save_bd_design

# Generate and add the BD top wrapper used by 2_synth.tcl.
make_wrapper -files [get_files $bdFile] -top
add_files -norecurse [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

report_ip_status -name ip_status 
update_module_reference [get_ips  xdma_bram_xdma_bram_axil_ctrl_0_0]
