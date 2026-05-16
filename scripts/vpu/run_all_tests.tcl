# VPU完整测试集 - Vivado TCL脚本
# 使用方法: vivado -mode batch -source scripts/vpu/run_all_tests.tcl

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

puts "========================================================================"
puts "  VPU完整测试集（INST_Decoder + CDMA + VPU）"
puts "========================================================================"

# 打开项目
if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
}

# 添加testbench
set tbFile [file normalize "$vpuRtlDir/tb/tb_vpu_all_tests.sv"]
add_files -fileset sim_1 -norecurse $tbFile -force

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top tb_vpu_all_tests [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {500us} -objects [get_filesets sim_1]

puts "\n启动仿真..."
launch_simulation

puts "\n运行仿真..."
run all

puts "\n========================================================================"
puts "  仿真完成"
puts "========================================================================"
