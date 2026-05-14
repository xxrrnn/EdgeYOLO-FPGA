# create block design for DCIM_Array Chip
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

# ============================================================================
# 添加 RTL 源文件
# ============================================================================
set chipRtlFiles [list \
    [file normalize "$srcDir/chip/DCIM_Array.sv"] \
    [file normalize "$srcDir/chip/DCIM_Array_AXI.sv"] \
    [file normalize "$srcDir/chip/DCIM_Array_Top.sv"] \
    [file normalize "$srcDir/chip/DCIM_Array_bd.v"] \
    [file normalize "$srcDir/chip/DCIM_Array_Group.sv"] \
    [file normalize "$srcDir/chip/DCIM_Tile.sv"] \
    [file normalize "$srcDir/chip/ibuf_rd_arbiter.sv"] \
    [file normalize "$srcDir/chip/obuf_wr_arbiter.sv"] \
]

set dcimRtlFiles [list \
    [file normalize "$srcDir/ref/DCIM/src/inc/para.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/counter.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/dff.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/pipe_stage.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/multiplier.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/adderTree.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/maArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/calculate_core.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/mergeArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/accumulateArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/postProcess.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/ppCache.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/sramWrap.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/memory.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/dcim.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/act_nibble_converter.sv"] \
    [file normalize "$srcDir/ref/DCIM/src/model/model_rf.sv"] \
    [file normalize "$srcDir/ref/DCIM/src/model/model_rf_bram.sv"] \
]

set bufferRtlFiles [list \
    [file normalize "$srcDir/DCIM_Macro/ibuf.v"] \
    [file normalize "$srcDir/DCIM_Macro/obuf.v"] \
]

set chipHeaderFiles [list \
    [file normalize "$srcDir/chip/chip_defs.vh"] \
]

add_files -norecurse [concat $chipRtlFiles $dcimRtlFiles $bufferRtlFiles $chipHeaderFiles]

set_property include_dirs [list \
    [file normalize "$srcDir/chip"] \
    [file normalize "$srcDir/ref/DCIM/src/inc"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim"] \
    [file normalize "$srcDir/ref/DCIM/src/model"] \
] [current_fileset]

set paraFile [file normalize "$srcDir/ref/DCIM/src/inc/para.v"]
set_property file_type {Verilog Header} [get_files $paraFile]
set_property is_global_include true [get_files $paraFile]

foreach vhFile $chipHeaderFiles {
    set_property file_type {Verilog Header} [get_files $vhFile]
    set_property is_global_include true [get_files $vhFile]
}

# FPGA: sramWrap.v 选用 model_rf_bram（推断 BRAM），避免 ASIC IP rf_sp_hde128x128
set_property verilog_define [list \
    FPGA=1 \
    MODE_INT4=3'b100 \
    MODE_INT8=3'b110 \
    MODE_INT16=3'b111 \
    MODE_UINT4=3'b000 \
    MODE_UINT8=3'b010 \
    MODE_UINT16=3'b011 \
] [current_fileset]

# ============================================================================
# 创建 DCIM_Array_bd 模块引用
# ============================================================================
create_bd_cell -type module -reference DCIM_Array_bd dcim_array_0

# ============================================================================
# 加载 IP 配置脚本
# ============================================================================
# DCIM done/ready：已由 DCIM_Array_AXI 映射到 AXI-Lite STATUS（基址见 address.tcl，
# 偏移 +0x004，rdata[0]=done，rdata[1]=ready）。主机经 XDMA M_AXI（PCIe BAR）读该字即可。
source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/bram.tcl"]
source [file normalize "$ipBdDir/cdma.tcl"]
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
update_module_reference [get_ips -quiet *dcim_array_0*]

# add xdc
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    add_files -fileset constrs_1 $xdcFile
}
