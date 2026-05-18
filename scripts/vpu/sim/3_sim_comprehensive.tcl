set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

puts "================================================================"
puts "  VPU 全面仿真测试（CDMA + VPU + END）"
puts "================================================================"

# 打开项目
if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
} else {
    set current_proj [current_project]
    if {$current_proj != $projName} {
        close_project
        open_project $projPath/$projName.xpr
    }
    puts "项目已打开: $projName"
}

# 检查BD
set bdFile [get_files vpu.bd]
if {[llength $bdFile] == 0} {
    puts "ERROR: BD文件不存在，请先运行 1_bd.tcl"
    exit 1
}

# 添加全面测试testbench
set tbFile [file normalize "$vpuRtlDir/tb/tb_vpu_comprehensive.sv"]
if {![file exists $tbFile]} {
    puts "ERROR: testbench不存在: $tbFile"
    exit 1
}
puts "使用 testbench: $tbFile"
add_files -fileset sim_1 -norecurse $tbFile -force

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top tb_vpu_comprehensive [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {500us} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

puts "\n启动仿真..."
launch_simulation

puts "\n运行仿真..."
run all

puts "\n================================================================"
puts "  仿真完成"
puts "================================================================"
