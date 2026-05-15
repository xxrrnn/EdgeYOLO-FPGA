# ==============================================================================
# run_cdma_sim.tcl - 基于 VPU Block Design 的 CDMA 仿真
#
# 使用 VPU 自己的 BD (真实 CDMA IP, SmartConnect, BRAM Controller)
# Testbench 直接配置 inst_decoder 来触发 CDMA 数据搬运
#
# 用法: vivado -mode batch -source scripts/vpu/run_cdma_sim.tcl
# ==============================================================================

set scriptDir [file dirname [file normalize [info script]]]
source [file normalize "$scriptDir/config.tcl"]

set simOut [file normalize "$buildDir/vpu_cdma_sim"]
file mkdir $simOut
set projPath [file normalize "$simOut/cdma_sim"]
if {[file exists $projPath]} { file delete -force $projPath }

puts "================================================================"
puts "  创建 VPU BD 并运行 CDMA 仿真"
puts "================================================================"

# 创建项目
create_project cdma_sim $projPath -part $part -force
set_property board_part $boardPart [current_project]

# --- 添加 RTL (与 1_bd.tcl 相同) ---
source [file normalize "$scriptsDir/ip/floating_point_fp32.tcl"]
if {[llength [get_ips -quiet fp32_mult_lane]] == 0 || [llength [get_ips -quiet fp32_add_lane]] == 0} {
    fp32_mac_ips_create
}

set vpuRtlFiles {}
foreach pattern {*.v *.sv */*.v */*.sv} {
    foreach f [glob -nocomplain [file normalize "$vpuRtlDir/$pattern"]] {
        if {![regexp {(tb_.*)\.(v|sv)$} [file tail $f]]} {
            lappend vpuRtlFiles $f
        }
    }
}
add_files -norecurse $vpuRtlFiles
set_property include_dirs [list $vpuRtlDir "$vpuRtlDir/fp array"] [current_fileset]
update_compile_order -fileset sources_1
set_property top Global_VPU_top [current_fileset]
update_compile_order -fileset sources_1

# --- 创建 BD (与 1_bd.tcl 相同) ---
set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
create_bd_design -dir $bdDir $bdName

create_bd_cell -type module -reference Global_VPU_top vpu_0

source [file normalize "$scriptsDir/ip/bd/xdma.tcl"]
source [file normalize "$ipBdDir/bram.tcl"]
source [file normalize "$scriptsDir/ip/bd/xdma_dcim_bram/cdma.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]
source [file normalize "$ipBdDir/address.tcl"]

puts "\n--- 验证地址映射 ---"
set cdma_axilm_segs [get_bd_addr_segs -quiet cdma_ctrl/cdma_axilm/*]
foreach seg $cdma_axilm_segs {
    puts "  $seg: offset=[get_property OFFSET $seg] range=[get_property RANGE $seg]"
}

validate_bd_design
save_bd_design

# 生成 targets
generate_target all [get_files ${bdName}.bd]

# 生成 wrapper
make_wrapper -files [get_files ${bdName}.bd] -top
set wrapperFiles [glob -nocomplain "$bdDir/$bdName/hdl/*_wrapper.v"]
if {[llength $wrapperFiles] > 0} {
    add_files -norecurse [lindex $wrapperFiles 0]
    puts "INFO: Added wrapper: [lindex $wrapperFiles 0]"
}

# --- 添加 Testbench ---
set tbFile [file normalize "$vpuRtlDir/tb/tb_vpu_bd_cdma.sv"]
add_files -fileset sim_1 -norecurse $tbFile
set_property top tb_vpu_bd_cdma [get_filesets sim_1]
update_compile_order -fileset sim_1

# 仿真时间
set_property -name {xsim.simulate.runtime} -value {300us} -objects [get_filesets sim_1]

puts "\n================================================================"
puts "  BD 完成，开始仿真..."
puts "================================================================\n"

# 运行仿真
launch_simulation -mode behavioral
run all
close_sim

puts "\n================================================================"
puts "  仿真完成"
puts "================================================================\n"

exit 0
