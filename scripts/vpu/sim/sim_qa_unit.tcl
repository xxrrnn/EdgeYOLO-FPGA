# QA Unit 仿真脚本
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/../config.tcl"]

puts "========================================================================"
puts "  QA Unit 仿真测试"
puts "========================================================================"

if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
}

set tbFile [file normalize "$vpuRtlDir/tb/tb_qa_unit.sv"]
add_files -fileset sim_1 -norecurse $tbFile -force
update_compile_order -fileset sim_1
set_property top tb_qa_unit [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {2ms} -objects [get_filesets sim_1]

puts "\n启动仿真..."
# 添加新模块到工程
set packFile [file normalize "$vpuRtlDir/int8_pack_writer.sv"]
add_files -fileset sources_1 -norecurse $packFile -force
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_simulation

puts "\n========================================================================"
puts "  QA Unit 仿真完成"
puts "========================================================================"
