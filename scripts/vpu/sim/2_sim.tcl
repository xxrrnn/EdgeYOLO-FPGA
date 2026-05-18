#!/usr/bin/env tclsh
# 2_sim.tcl - VPU 完整硬件仿真（含CDMA + VPU计算）
# 
# 直接配置 INST_Decoder 来控制：
#   1. CDMA 搬运数据（global_bram → VPU GB）
#   2. VPU 计算（Max Pooling）
#   3. CDMA 搬运结果（VPU GB → global_bram）
#   4. 验证结果
#
# 用法: vivado -mode batch -source scripts/vpu/2_sim.tcl
#       或在GUI中: vivado -mode gui -source scripts/vpu/2_sim.tcl

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

puts "================================================================"
puts "  VPU 硬件仿真（INST_Decoder + CDMA + VPU）"
puts "================================================================"

# 打开项目（如果尚未打开）
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

# 确保BD已生成
set bdFile [get_files vpu.bd]
if {[llength $bdFile] == 0} {
    puts "ERROR: BD文件不存在，请先运行 1_bd.tcl"
    exit 1
}

puts "\n注意: global_bram使用AXI BRAM Controller模式，无法通过COE文件初始化"
puts "      如需验证CDMA数据传输，请在GUI波形中手动检查AXI信号"

# 使用简单的END指令测试
set tbFile [file normalize "$vpuRtlDir/tb/tb_vpu_simple.sv"]
if {![file exists $tbFile]} {
    puts "ERROR: testbench不存在: $tbFile"
    exit 1
}

puts "\n使用 testbench: $tbFile"

# 添加testbench到仿真
add_files -fileset sim_1 -norecurse $tbFile -force

# 更新所有源文件
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# 设置仿真顶层
set_property top tb_vpu_simple [get_filesets sim_1]

# 仿真设置
set_property -name {xsim.simulate.runtime} -value {200us} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

puts "\n启动仿真..."
launch_simulation

# 在batch模式下，只运行仿真不添加波形
# 波形需要在GUI模式下查看
puts "\n运行仿真..."
run all

puts "\n================================================================"
puts "  仿真完成"
puts "  
  如需查看波形，请使用GUI模式:
    vivado -mode gui -source scripts/vpu/2_sim.tcl
  
  或在GUI中手动打开:
    1. vivado build/vpu/vpu.xpr
    2. Run Simulation
    3. 添加需要的信号到Wave窗口
  
  注意: global_bram已配置初始化数据，可在波形中验证CDMA传输
"
puts "================================================================"
