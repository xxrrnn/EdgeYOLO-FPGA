# create block design
set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists xdmaBramScriptDir]} {
    source [file normalize "$thisScriptDir/3_config.tcl"]
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

source [file normalize "$ipBdDir/xdma.tcl"]
source [file normalize "$ipBdDir/bram.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]

# address edit
set_property offset 0x10000000 [get_bd_addr_segs {xdma_0/M_AXI/SEG_axi_bram_ctrl_0_Mem0}]

validate_bd_design
regenerate_bd_layout
save_bd_design

# Generate and add the BD top wrapper used by 2_synth.tcl.
make_wrapper -files [get_files $bdFile] -top
add_files -norecurse [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
update_compile_order -fileset sources_1
