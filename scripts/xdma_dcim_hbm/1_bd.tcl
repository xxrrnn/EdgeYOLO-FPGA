# create block design
set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists xdma_dcim_hbmScriptDir]} {
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

set localRtlFiles [glob -nocomplain [file normalize "$srcDir/xdma_dcim_bram/*.{v,sv}"]]
set localHeaderFiles [glob -nocomplain [file normalize "$srcDir/xdma_dcim_bram/*.vh"]]
set dcimRtlFiles [list \
    [file normalize "$srcDir/ref/DCIM/src/inc/para.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/counter.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/dff.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/pipe_stage.v"] \
    [file normalize "$srcDir/DCIM/src/dcim/multiplier_dsp.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/adderTree.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/maArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/calculate_core.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/mergeArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/accumulateArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/postProcess.v"] \
]

if {[llength $localRtlFiles] == 0} {
    error "No RTL files found in $srcDir/xdma_dcim_bram"
}

add_files -norecurse [concat $localRtlFiles $localHeaderFiles $dcimRtlFiles]
set_property include_dirs [list \
    [file normalize "$srcDir/xdma_dcim_bram"] \
    [file normalize "$srcDir/ref/DCIM/src/inc"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim"] \
] [current_fileset]
set paraFile [file normalize "$srcDir/ref/DCIM/src/inc/para.v"]
set_property file_type {Verilog Header} [get_files $paraFile]
set_property is_global_include true [get_files $paraFile]
foreach vhFile $localHeaderFiles {
    set_property file_type {Verilog Header} [get_files $vhFile]
    set_property is_global_include true [get_files $vhFile]
}
set_property verilog_define [list \
    MODE_INT4=3'b100 \
    MODE_INT8=3'b110 \
    MODE_INT16=3'b111 \
    MODE_UINT4=3'b000 \
    MODE_UINT8=3'b010 \
    MODE_UINT16=3'b011 \
] [current_fileset]

create_bd_cell -type module -reference PE_bd pe_0

source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/hbm.tcl"]
source [file normalize "$ipBdDir/clocks.tcl"]
source [file normalize "$ipBdDir/axi_clock_converters.tcl"]
source [file normalize "$ipBdDir/smartconnect.tcl"]
source [file normalize "$ipBdDir/pe_buffers.tcl"]
source [file normalize "$ipBdDir/cdma.tcl"]
source [file normalize "$ipBdDir/gpio.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]
source [file normalize "$ipBdDir/address.tcl"]

validate_bd_design
regenerate_bd_layout
save_bd_design

make_wrapper -files [get_files $bdFile] -top
add_files -norecurse [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

report_ip_status -name ip_status
update_module_reference [get_ips -quiet *pe_0*]
