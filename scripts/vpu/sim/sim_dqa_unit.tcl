# DQA Unit 仿真测试
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/../config.tcl"]

puts "========================================================================"
puts "  DQA Unit 仿真测试"
puts "========================================================================"

if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
}

set tbFile [file normalize "$vpuRtlDir/tb/tb_dqa_unit.sv"]
add_files -fileset sim_1 -norecurse $tbFile -force
update_compile_order -fileset sim_1
set_property top tb_dqa_unit [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {5ms} -objects [get_filesets sim_1]

puts "\n启动仿真..."
launch_simulation

puts "\n========================================================================"
puts "  DQA Unit 仿真完成"
puts "========================================================================"
