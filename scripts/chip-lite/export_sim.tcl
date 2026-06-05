# ==============================================================================
# export_sim.tcl — 打开已有 Vivado 项目，生成仿真目标，export_simulation → VCS
#
# 用法：
#   cd <repo_root>
#   vivado -mode batch -source scripts/chip-lite/export_sim.tcl
#   或通过 make export（在 rtl/tb/lite_bd/module_tb/ 或 rtl/tb/lite_bd/）
#
# 前提：
#   build/lite/lite.xpr 已存在（先跑 1_build.tcl + 2_bd.tcl）
#   chip_defines.vh 的 READ_LATENCY 宏已与 BD IP 配置一致
# ==============================================================================

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

# --- 导出路径 ---
set exportRoot [file normalize "$localDir/sim/lite_bd_export"]
set exportDir  [file normalize "$exportRoot/vcs"]
file mkdir $exportRoot

# --- 打开已有项目 ---
if {![file exists "$projPath/lite.xpr"]} {
    error "Project not found: $projPath/lite.xpr — run 1_build.tcl and 2_bd.tcl first."
}
open_project "$projPath/lite.xpr"

# --- BD 文件路径 ---
set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {![file exists $bdFile]} {
    error "BD not found: $bdFile"
}

# --- 如有 locked IP（手动编辑 XCI 后常见），先 upgrade 解锁 ---
set lockedIPs [get_ips -filter {UPGRADE_NEEDED == 1} -quiet]
if {[llength $lockedIPs] > 0} {
    puts "INFO: upgrading locked IPs: $lockedIPs"
    upgrade_ip $lockedIPs
}
# 再试一次（有时 axi_bram_ctrl 改参数后需要 reset_target 再 generate）
set lockedAfter [get_ips -filter {IP_STATUS == locked} -quiet]
if {[llength $lockedAfter] > 0} {
    puts "WARNING: IPs still locked after upgrade, trying reset_target + generate: $lockedAfter"
    reset_target simulation $lockedAfter
    generate_target simulation $lockedAfter
}

# --- 强制重新生成仿真目标（会更新 ip_user_files/bd/.../sim/*.vhd）---
puts "INFO: generate_target simulation for $bdName"
generate_target {simulation} [get_files $bdFile]
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force

# --- 导出 VCS 仿真脚本 ---
puts "INFO: export_simulation → $exportDir"
export_simulation \
    -of_objects [get_files $bdFile] \
    -simulator vcs \
    -ip_user_files_dir [file normalize "$projPath/${projName}.ip_user_files"] \
    -ipstatic_source_dir [file normalize "$projPath/${projName}.ip_user_files/ipstatic"] \
    -lib_map_path [file normalize "$projPath/${projName}.ip_user_files/sim_scripts/vcs"] \
    -use_ip_compiled_libs \
    -force \
    -directory $exportDir

# --- 更新 export stamp ---
set stampFile [file normalize "$exportRoot/.export_stamp"]
set fh [open $stampFile w]
puts $fh [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
close $fh
puts "INFO: export stamp written: $stampFile"

# --- 拷贝 BD sim wrapper 到导出根目录（module_tb run_script 依赖）---
set bdSimV [file normalize "$bdDir/$bdName/sim/$bdName.v"]
if {[file exists $bdSimV]} {
    set bdSimCopy [file normalize "$exportRoot/$bdName.v"]
    file copy -force $bdSimV $bdSimCopy
    puts "INFO: BD sim wrapper copied: $bdSimCopy"
}

puts "INFO: BD export simulation complete."
puts "INFO:   export dir : $exportDir"
puts "INFO: Set XILINX_VCS_LIB before VCS (see scripts/sim/compile_xilinx_vcs_lib.tcl)"

close_project
