# tb_mp_unit 行为仿真（需 Vivado xsim）。在仓库根目录执行：
#   vivado -mode batch -source rtl/vpu/sim/run_tb_mp_xsim.tcl
# 可选器件：FP_MAC_SIM_PART=xc7z020clg400-1 ...
# 源文件：max_pooling2d5x5.sv、mp_unit.sv、global_buffer_bram.v、tb_mp_unit.sv
set scriptDir [file dirname [file normalize [info script]]]
set repoRoot [file normalize [file join $scriptDir "../../.."]]

if {[llength [info commands create_project]] == 0} {
    puts {ERROR: Run with vivado -mode batch -source ...}
    exit 1
}

set memDir [file normalize [file join $repoRoot rtl/vpu/tb]]
set vh [file join $memDir mem_defines_auto.vh]
set vf [open $vh w]
puts $vf {// Auto-generated — paths for $readmemh}
puts $vf {`ifndef MEM_DEFINES_AUTO_VH}
puts $vf {`define MEM_DEFINES_AUTO_VH}
puts $vf "`define MEM_MP_ACT \"$memDir/mem/mp_act_data.mem\""
puts $vf "`define MEM_MP_EXP \"$memDir/mem/mp_expected_data.mem\""
puts $vf "`define MEM_US_ACT \"$memDir/mem/us_act_data.mem\""
puts $vf "`define MEM_US_EXP \"$memDir/mem/us_output_data.mem\""
puts $vf {`endif}
close $vf
puts "Info: Wrote $vh"

if {[info exists ::env(FP_MAC_SIM_PART)]} {
    set simPart $::env(FP_MAC_SIM_PART)
} else {
    set simPart {xc7z020clg400-1}
}

set simOut [file normalize [file join $scriptDir out_mp]]
file mkdir $simOut
set projPath [file normalize [file join $simOut tb_mp_xsim]]
if {[file exists $projPath]} {
    file delete -force $projPath
}

create_project tb_mp_xsim $projPath -part $simPart -force
set_property target_language Verilog [current_project]

set incDirs [list $memDir]
set_property include_dirs $incDirs [get_filesets sim_1]
set_property include_dirs $incDirs [get_filesets sources_1]

add_files -norecurse [file join $repoRoot rtl/vpu/max_pooling2d5x5.sv]
add_files -norecurse [file join $repoRoot rtl/vpu/mp_unit.sv]
add_files -norecurse [file join $repoRoot rtl/vpu/global_buffer_bram.v]
add_files -fileset sim_1 -norecurse [file join $repoRoot rtl/vpu/tb/tb_mp_unit.sv]
set_property top tb_mp_unit [get_filesets sim_1]
# 默认 1000ns 不够；本 MP TB 在约 90ms 仿真时间内可跑完自检（略加裕量）。
set_property -name {xsim.simulate.runtime} -value {150ms} -objects [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

if {[catch {launch_simulation -step all -mode behavioral -simset sim_1} err]} {
    puts "ERROR: $err"
    exit 1
}
close_sim
exit 0
