# sim_us_unit_fixed.tcl - 仅仿真 us_unit_fixed testbench
# 用法: vivado -mode batch -source scripts/vpu/sim_us_unit_fixed.tcl

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

puts "========================================================================"
puts "  tb_us_unit_fixed 仿真"
puts "========================================================================"

if {[llength [get_projects -quiet]] == 0} {
    open_project $projPath/$projName.xpr
}

set rtlFile [file normalize "$vpuRtlDir/us_unit_fixed.sv"]
set tbFile  [file normalize "$vpuRtlDir/tb/tb_us_unit_fixed.sv"]

if {![file exists $rtlFile]} {
    puts "ERROR: RTL not found: $rtlFile"
    exit 1
}
if {![file exists $tbFile]} {
    puts "ERROR: TB not found: $tbFile"
    exit 1
}

add_files -fileset sources_1 -norecurse $rtlFile -force
add_files -fileset sim_1     -norecurse $tbFile  -force

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

set_property top tb_us_unit_fixed [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {5ms} -objects [get_filesets sim_1]

puts "\n启动仿真 (runtime=5ms, launch_simulation 内已 run)..."
launch_simulation
close_sim -force

puts "\n========================================================================"
puts "  仿真结束"
puts "========================================================================"
