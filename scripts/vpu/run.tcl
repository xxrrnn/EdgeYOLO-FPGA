# 一键：创建工程 → BD → 综合实现 → top.bit（输出 build/vpu/ImplOutputDir/top.bit）。
set thisScriptDir [file dirname [file normalize [info script]]]

source [file normalize "$thisScriptDir/0_build.tcl"]
source [file normalize "$thisScriptDir/1_bd.tcl"]
source [file normalize "$thisScriptDir/2_synth.tcl"]
