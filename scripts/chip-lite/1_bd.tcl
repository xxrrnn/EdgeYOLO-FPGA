# create block design for DCIM_Array + VPU Chip (HBM version)
set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

if {[llength [get_projects -quiet]] == 0} {
    error "Please source 0_build.tcl before 1_bd.tcl."
}

# FP32 IPs for VPU
source [file normalize "$scriptsDir/ip/floating_point_fp32.tcl"]
if {[llength [get_ips -quiet fp32_mult_lane]] == 0 || [llength [get_ips -quiet fp32_add_lane]] == 0} {
    fp32_mac_ips_create
}

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[llength [get_files -quiet $bdFile]] != 0} {
    remove_files $bdFile
}
if {[file exists [file dirname $bdFile]]} {
    catch {file delete -force [file dirname $bdFile]}
    if {[file exists [file dirname $bdFile]]} {
        # Directory still exists (open file handles); do incremental update instead
    }
}

create_bd_design -dir $bdDir $bdName

# ============================================================================
# 添加 RTL 源文件
# ============================================================================

# --- DCIM Array RTL ---
set chipRtlFiles [list \
    [file normalize "$srcDir/chip/DCIM_Array.sv"] \
    [file normalize "$srcDir/chip/DCIM_Array_bd.v"] \
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

# --- VPU RTL ---
set vpuRtlDir [file normalize "$srcDir/vpu"]
set vpuRtlFiles {}
foreach pattern {*.v *.sv} {
    foreach f [glob -nocomplain [file normalize "$vpuRtlDir/$pattern"]] {
        if {![regexp {(tb_.*|.*_v2|.*\.bak)\.(v|sv)$} [file tail $f]]} {
            lappend vpuRtlFiles $f
        }
    }
}
foreach f [glob -nocomplain [file normalize "$vpuRtlDir/fp_array/*.v"] [file normalize "$vpuRtlDir/fp_array/*.sv"]] {
    lappend vpuRtlFiles $f
}

# --- Header files ---
set chipHeaderFiles [list \
    [file normalize "$srcDir/chip/chip_defines.vh"] \
]

add_files -norecurse [concat $chipRtlFiles $dcimRtlFiles $bufferRtlFiles $vpuRtlFiles $chipHeaderFiles]

set_property include_dirs [list \
    [file normalize "$srcDir/chip"] \
    [file normalize "$srcDir/ref/DCIM/src/inc"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim"] \
    [file normalize "$srcDir/ref/DCIM/src/model"] \
    $vpuRtlDir \
    [file normalize "$vpuRtlDir/fp_array"] \
] [current_fileset]

set paraFile [file normalize "$srcDir/ref/DCIM/src/inc/para.v"]
set_property file_type {Verilog Header} [get_files $paraFile]
set_property is_global_include true [get_files $paraFile]

foreach vhFile $chipHeaderFiles {
    set_property file_type {Verilog Header} [get_files $vhFile]
    set_property is_global_include true [get_files $vhFile]
}

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
# 创建计算引擎 BD cells
# ============================================================================
create_bd_cell -type module -reference DCIM_Array_bd dcim_array_0
set_property -dict [list \
    CONFIG.NUM_GROUPS {1} \
    CONFIG.TILES_PER_GROUP {4} \
    CONFIG.NUM_TILES {4} \
] [get_bd_cells dcim_array_0]
# 禁用 dcim_array_0 的 OOC 综合（同 vpu_0，避免 project 重建后 DCP 关联失效）
catch {set_property generate_synth_checkpoint false [get_bd_cells dcim_array_0]}
create_bd_cell -type module -reference Global_VPU_top vpu_0
# 禁用 vpu_0 的 OOC 综合：module reference 类型的 BD cell 在 project 重建后
# OOC run DCP 有时无法被顶层 synth_design 找到（Vivado bug）。
# 设置 OOC 属性使 Vivado 在顶层综合中内联展开 RTL，
# 避免 "module 'lite_vpu_0_0' not found" 错误。
catch {set_property generate_synth_checkpoint false [get_bd_cells vpu_0]}

# ============================================================================
# 加载 IP 配置和连接脚本
# ============================================================================
source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/hbm.tcl"]
source [file normalize "$ipBdDir/cdma.tcl"]
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
catch {update_module_reference [get_ips -quiet *dcim_array_0*]}
catch {update_module_reference [get_ips -quiet *vpu_0*]}

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    add_files -fileset constrs_1 $xdcFile
}
