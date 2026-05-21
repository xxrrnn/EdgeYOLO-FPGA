# Lite: 仅做 BD 创建 + 综合（不做实现）
# 用法: vivado -mode batch -source scripts/chip/build_synth_only.tcl
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/0_build.tcl"]
source [file normalize "$thisScriptDir/1_bd.tcl"]
# 只跑综合，不跑实现
puts "==== LITE: Starting synthesis ===="
launch_runs synth_1 -jobs 16
wait_on_run synth_1
puts "==== LITE: Synthesis done ===="
report_utilization -file ${SynOutputDir}/post_synth_util_quick.rpt
