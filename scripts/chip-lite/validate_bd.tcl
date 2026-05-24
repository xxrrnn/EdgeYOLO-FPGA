# validate_bd.tcl - 创建 BD 并运行 validate_bd_design，验证设计可行性
# 运行到 validate_bd_design 后保存并退出，不进行综合
# 用法: vivado -mode batch -source scripts/chip/validate_bd.tcl
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

if {[llength [get_projects -quiet]] != 0} { close_project }
if {[file exists $projPath]} {
    file delete -force $projPath
}
create_project $projName $projPath -part $part
set_property board_part $boardPart [current_project]

# FP32 IPs for VPU
source [file normalize "$scriptsDir/ip/floating_point_fp32.tcl"]
if {[llength [get_ips -quiet fp32_mult_lane]] == 0 || \
    [llength [get_ips -quiet fp32_add_lane]] == 0} {
    fp32_mac_ips_create
}

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[llength [get_files -quiet $bdFile]] != 0} { remove_files $bdFile }
if {[file exists [file dirname $bdFile]]} { file delete -force [file dirname $bdFile] }
create_bd_design -dir $bdDir $bdName

# ---- 添加 RTL 源文件（同 1_bd.tcl）----
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

set vpuRtlFiles {}
foreach pattern {*.v *.sv} {
    foreach f [glob -nocomplain [file normalize "$vpuRtlDir/$pattern"]] {
        if {![regexp {(tb_.*|.*_v2|.*\.bak)\.(v|sv)$} [file tail $f]]} {
            lappend vpuRtlFiles $f
        }
    }
}
foreach f [glob -nocomplain \
    [file normalize "$vpuRtlDir/fp_array/*.v"] \
    [file normalize "$vpuRtlDir/fp_array/*.sv"]] {
    lappend vpuRtlFiles $f
}

set chipHeaderFiles [list [file normalize "$srcDir/chip/chip_defs.vh"]]
add_files -norecurse [concat $chipRtlFiles $dcimRtlFiles $bufferRtlFiles $vpuRtlFiles $chipHeaderFiles]

set vpuHeaderFile [file normalize "$vpuRtlDir/vpu_defines.vh"]
if {[file exists $vpuHeaderFile]} { add_files -norecurse $vpuHeaderFile }

set_property include_dirs [list \
    [file normalize "$srcDir/chip"] \
    [file normalize "$srcDir/ref/DCIM/src/inc"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim"] \
    [file normalize "$srcDir/ref/DCIM/src/model"] \
    $vpuRtlDir \
    [file normalize "$vpuRtlDir/fp array"] \
] [current_fileset]

set paraFile [file normalize "$srcDir/ref/DCIM/src/inc/para.v"]
set_property file_type {Verilog Header} [get_files $paraFile]
set_property is_global_include true [get_files $paraFile]
foreach vhFile $chipHeaderFiles {
    set_property file_type {Verilog Header} [get_files $vhFile]
    set_property is_global_include true [get_files $vhFile]
}
if {[file exists $vpuHeaderFile]} {
    set_property file_type {Verilog Header} [get_files $vpuHeaderFile]
    set_property is_global_include true [get_files $vpuHeaderFile]
}
set_property verilog_define [list FPGA=1 \
    MODE_INT4=3'b100 MODE_INT8=3'b110 MODE_INT16=3'b111 \
    MODE_UINT4=3'b000 MODE_UINT8=3'b010 MODE_UINT16=3'b011 \
] [current_fileset]

create_bd_cell -type module -reference DCIM_Array_bd dcim_array_0
create_bd_cell -type module -reference Global_VPU_top vpu_0

source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/hbm.tcl"]
source [file normalize "$ipBdDir/cdma.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]
source [file normalize "$ipBdDir/address.tcl"]

puts ""
puts "============================================================"
puts "  Running validate_bd_design ..."
puts "============================================================"
validate_bd_design
puts "============================================================"
puts "  validate_bd_design PASSED"
puts "============================================================"

regenerate_bd_layout
save_bd_design

puts ""
puts "=============================="
puts "  BD Validation: SUCCESS"
puts "  BD saved. Synthesis not started."
puts "=============================="
