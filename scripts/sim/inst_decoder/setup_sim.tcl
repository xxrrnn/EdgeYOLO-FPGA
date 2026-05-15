################################################################################
# 在现有 Vivado 项目中设置仿真
# 使用项目中已有的 IP 进行完整系统仿真
################################################################################

# 打开现有项目
set proj_root [file normalize [file dirname [info script]]/../..]
set build_dir $proj_root/build/vpu
set sim_dir   [file dirname [info script]]

if {![file exists $build_dir/vpu.xpr]} {
    puts "ERROR: 项目不存在: $build_dir/vpu.xpr"
    exit 1
}

open_project $build_dir/vpu.xpr

# 添加 testbench 到 sim_1 fileset
set tb_file $sim_dir/tb_inst_decoder_system.sv
if {[file exists $tb_file]} {
    add_files -fileset sim_1 -norecurse $tb_file
}

# 设置仿真顶层
set_property top tb_inst_decoder_system [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

# 生成仿真所需的 IP 输出
# 这会生成 IP 的仿真模型
generate_target simulation [get_files $build_dir/bd/vpu/vpu.bd]

# 导出仿真脚本
export_simulation -simulator xsim -directory $sim_dir/xsim_export -force

puts "=========================================="
puts "仿真设置完成"
puts "导出目录: $sim_dir/xsim_export"
puts "=========================================="

close_project
