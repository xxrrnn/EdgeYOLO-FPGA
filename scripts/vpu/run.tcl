# 一键：创建工程 → BD → 综合实现 → top.bit（输出 build/vpu/ImplOutputDir/top.bit）。
# 用法: vivado -mode batch -source run.tcl [-tclargs --to <stage>]
# stage: build, bd, validate, synth (默认 synth)

set thisScriptDir [file dirname [file normalize [info script]]]

# 解析命令行参数
set stopAt "synth"
for {set i 0} {$i < $argc} {incr i} {
    if {[lindex $argv $i] eq "--to"} {
        incr i
        set stopAt [lindex $argv $i]
    }
}

puts "Info: Running up to stage: $stopAt"

source [file normalize "$thisScriptDir/0_build.tcl"]
if {$stopAt eq "build"} {
    puts "Info: Stopping after build stage."
    return
}

source [file normalize "$thisScriptDir/1_bd.tcl"]
if {$stopAt eq "bd" || $stopAt eq "validate"} {
    puts "Info: Stopping after BD validation stage."
    return
}

source [file normalize "$thisScriptDir/2_synth.tcl"]
