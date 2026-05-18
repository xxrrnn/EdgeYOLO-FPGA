set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

puts "================================================================"
puts "  INST_Decoder 指令解析验证（使用真实CDMA/VPU硬件）"
puts "================================================================"

if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
} else {
    set current_proj [current_project]
    if {$current_proj != $projName} {
        close_project
        open_project $projPath/$projName.xpr
    }
}

set tbFile [file normalize "$vpuRtlDir/tb/tb_vpu_inst_decoder.sv"]
if {![file exists $tbFile]} {
    puts "ERROR: testbench不存在: $tbFile"
    exit 1
}
puts "使用 testbench: $tbFile"
add_files -fileset sim_1 -norecurse $tbFile -force

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top tb_vpu_inst_decoder [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {300us} -objects [get_filesets sim_1]

puts "\n启动仿真..."
launch_simulation

puts "\n运行仿真..."
run all

puts "\n================================================================"
puts "  仿真完成"
puts "================================================================"
