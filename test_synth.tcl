# 快速测试综合以验证 MAX_CHANNEL_NUM 修改
# 只编译需要的几个VPU模块

create_project -in_memory -part xcvu37p-fsvh2892-2L-e

# 添加源文件
set vpuRtlDir "/data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-vpu/rtl/vpu"
add_files [glob $vpuRtlDir/*.v $vpuRtlDir/*.sv]
set_property include_dirs [list $vpuRtlDir] [current_fileset]

# 设置顶层
set_property top Global_VPU [current_fileset]
update_compile_order -fileset sources_1

# 运行综合
synth_design -top Global_VPU -part xcvu37p-fsvh2892-2L-e -mode out_of_context

# 报告任何错误
report_timing_summary -file timing_summary.rpt
puts "Info: Synthesis completed. Check for errors above."
