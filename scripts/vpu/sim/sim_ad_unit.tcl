# AD Unit 仿真脚本
# 使用方法: vivado -mode batch -source scripts/vpu/sim_ad_unit.tcl

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/../config.tcl"]

puts "========================================================================"
puts "  AD Unit 仿真测试"
puts "========================================================================"

# 打开项目
if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
}

# 添加 testbench
set tbFile [file normalize "$vpuRtlDir/tb/tb_ad_unit.sv"]
add_files -fileset sim_1 -norecurse $tbFile -force

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top tb_ad_unit [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {2ms} -objects [get_filesets sim_1]

puts "\n启动仿真..."
launch_simulation

puts "\n========================================================================"
puts "  AD Unit 仿真完成"
puts "========================================================================"
