# Global_VPU 块设计：vpu_0 ← Global_VPU_top（rtl/vpu/Global_VPU_top.v）
set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

if {[llength [get_projects -quiet]] == 0} {
    error "Please source 0_build.tcl before 1_bd.tcl."
}

source [file normalize "$scriptsDir/ip/floating_point_fp32.tcl"]
if {[llength [get_ips -quiet fp32_mult_lane]] == 0 || [llength [get_ips -quiet fp32_add_lane]] == 0} {
    fp32_mac_ips_create
}

if {![file exists $vpuRtlDir]} {
    error "VPU RTL directory not found: $vpuRtlDir"
}

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[llength [get_files -quiet $bdFile]] != 0} {
    remove_files $bdFile
}
if {[file exists [file dirname $bdFile]]} {
    file delete -force [file dirname $bdFile]
}

create_bd_design -dir $bdDir $bdName

# 收集所有 VPU RTL 文件（.v 和 .sv），包括子目录，但排除测试文件和备份文件
set vpuRtlFiles {}
foreach pattern {*.v *.sv */*.v */*.sv} {
    foreach f [glob -nocomplain [file normalize "$vpuRtlDir/$pattern"]] {
        # 排除 testbench 文件和备份文件
        if {![regexp {(tb_.*|.*_v2)\.(v|sv)$} [file tail $f]]} {
            lappend vpuRtlFiles $f
        }
    }
}

if {[llength $vpuRtlFiles] == 0} {
    error "No RTL files under $vpuRtlDir"
}

puts "Info: Adding [llength $vpuRtlFiles] RTL files from $vpuRtlDir"
foreach f $vpuRtlFiles {
    puts "  - [file tail $f]"
}

add_files -norecurse $vpuRtlFiles
set_property include_dirs [list $vpuRtlDir "$vpuRtlDir/fp array"] [current_fileset]
update_compile_order -fileset sources_1

# 强制刷新 IP 目录以识别所有 RTL 模块
set_property top Global_VPU_top [current_fileset]
update_compile_order -fileset sources_1

create_bd_cell -type module -reference Global_VPU_top vpu_0

source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/bram.tcl"]
source [file normalize "$scriptsDir/ip/bd/xdma_dcim_bram/cdma.tcl"]
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
catch {update_module_reference [get_ips -quiet *vpu_0*]}

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/$bdName/*.xdc"]] {
    add_files -fileset constrs_1 $xdcFile
}
