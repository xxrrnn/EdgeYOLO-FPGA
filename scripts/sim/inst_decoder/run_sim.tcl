################################################################################
# INST_Decoder + CDMA_Controller + Xilinx CDMA IP 完整仿真
# 使用 Vivado 真实 IP，不模拟任何接口
################################################################################

# 设置项目路径
set proj_root [file normalize [file dirname [info script]]/../..]
set sim_dir   [file dirname [info script]]
set rtl_dir   $proj_root/rtl/vpu
set build_dir $proj_root/build/vpu

# 检查 Vivado 项目是否存在
if {![file exists $build_dir/vpu.xpr]} {
    puts "ERROR: Vivado 项目不存在: $build_dir/vpu.xpr"
    puts "请先运行 Vivado 项目构建"
    exit 1
}

# 打开项目
open_project $build_dir/vpu.xpr

# 设置仿真顶层
set_property top tb_inst_decoder_system [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# 添加 testbench 文件
add_files -fileset sim_1 -norecurse $sim_dir/tb_inst_decoder_system.sv

# 更新编译顺序
update_compile_order -fileset sim_1

# 设置仿真时间
set_property -name {xsim.simulate.runtime} -value {100us} -objects [get_filesets sim_1]

# 启动仿真
launch_simulation

# 运行仿真
run all

# 关闭仿真
close_sim

puts "=========================================="
puts "仿真完成"
puts "=========================================="
