# ==============================================================================
# export_sim.tcl — 打开已有 Vivado 项目并导出仿真脚本
#
# 用法：
#   cd <repo_root>
#   vivado -mode batch -source scripts/chip-lite/export_sim.tcl
#   或通过 make export（在 rtl/tb/lite_bd/module_tb/ 或 rtl/tb/lite_bd/）
#
# BUILD_TAG 指定要 export 哪个 build（与 run.tcl 保持一致）：
#   BUILD_TAG=20260606_143000 vivado -mode batch -source scripts/chip-lite/export_sim.tcl
#   BUILD_TAG=aggressive      vivado -mode batch -source scripts/chip-lite/export_sim.tcl
#   不指定 BUILD_TAG 时：自动选取 build/lite/ 下最新的子目录
#
# SIMULATOR 可显式指定 xsim/vcs。默认值按宿主系统选择：Windows=xsim，
# Linux=vcs。Vivado Windows 版不支持导出 VCS 脚本，不能把其错误信息当成成功。
#
# 前提：
#   build/lite/<tag>/lite.xpr 已存在（先跑 1_build.tcl + 2_bd.tcl）
#   chip_defines.vh 的 READ_LATENCY 宏已与 BD IP 配置一致
# ==============================================================================

set thisScriptDir [file dirname [file normalize [info script]]]

# --- 若未指定 BUILD_TAG，自动选取 build/lite/ 下最新的已有工程目录 ---
# export_sim 不创建新工程，只读取已有的，所以不应生成新时间戳。
# BUILD_TAG 已设置时直接使用；未设置时找 build/lite/ 下最新含 lite.xpr 的子目录。
if {![info exists ::env(BUILD_TAG)] || [string trim $::env(BUILD_TAG)] eq ""} {
    set _buildLiteDir [file normalize "$thisScriptDir/../../build/lite"]
    set _candidates {}
    foreach _d [glob -nocomplain -type d "$_buildLiteDir/*"] {
        if {[file exists [file normalize "$_d/lite.xpr"]]} {
            lappend _candidates $_d
        }
    }
    if {[llength $_candidates] == 0} {
        error "No build found in $_buildLiteDir — run scripts/chip-lite/run.tcl first, or set BUILD_TAG."
    }
    # 按修改时间降序排列，取最新
    set _latest [lindex [lsort -decreasing -command {apply {{a b} {
        expr {[file mtime $a] - [file mtime $b]}
    }}} $_candidates] 0]
    set ::env(BUILD_TAG) [file tail $_latest]
    puts "INFO: export_sim.tcl — BUILD_TAG not set, auto-selected: $::env(BUILD_TAG)"
}

source [file normalize "$thisScriptDir/config.tcl"]

# --- 仿真器与导出路径 ---
if {[info exists ::env(SIMULATOR)] && [string trim $::env(SIMULATOR)] ne ""} {
    set simulator [string tolower [string trim $::env(SIMULATOR)]]
} elseif {$::tcl_platform(platform) eq "windows"} {
    set simulator "xsim"
} else {
    set simulator "vcs"
}
if {$simulator ni {xsim vcs}} {
    error "Unsupported SIMULATOR='$simulator'; expected xsim or vcs."
}
if {$::tcl_platform(platform) eq "windows" && $simulator eq "vcs"} {
    error "Vivado on Windows cannot export VCS scripts; use SIMULATOR=xsim locally or export VCS on the Linux server."
}
set exportRoot [file normalize "$localDir/sim/lite_bd_export"]
set exportDir  [file normalize "$exportRoot/$simulator"]
file mkdir $exportRoot

# --- 打开已有项目 ---
if {![file exists "$projPath/${projName}.xpr"]} {
    error "Project not found: $projPath/${projName}.xpr — run 1_build.tcl and 2_bd.tcl first."
}
open_project "$projPath/${projName}.xpr"

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

# The module-reference IP may also carry a synthesized simulation netlist.
# It is nearly 1 GB for the 8-Tile DCIM and makes VCS export spend tens of
# minutes scanning a duplicate implementation.  module_tb intentionally
# compiles the current DCIM_Array_bd RTL and the small module-ref sim wrapper,
# so the synthesized netlist must not participate in the VCS export.
if {$simulator eq "vcs"} {
    set dcimSynthNetlists [get_files -all -quiet "*lite_dcim_array_0_0_sim_netlist.*"]
    foreach dcimNetlist $dcimSynthNetlists {
        set_property USED_IN_SIMULATION false $dcimNetlist
        puts "INFO: VCS export excludes duplicate DCIM synth sim netlist: $dcimNetlist"
    }
}

# --- 导出仿真脚本；catch 是必要的，部分 Vivado 版本会打印 ERROR 却返回批处理成功 ---
puts "INFO: export_simulation → $exportDir"
set exportArgs [list \
    -of_objects [get_files $bdFile] \
    -simulator $simulator \
    -ip_user_files_dir [file normalize "$projPath/${projName}.ip_user_files"] \
    -ipstatic_source_dir [file normalize "$projPath/${projName}.ip_user_files/ipstatic"] \
    -force \
    -directory $exportDir]
if {$simulator eq "vcs"} {
    lappend exportArgs \
        -lib_map_path [file normalize "$projPath/${projName}.ip_user_files/sim_scripts/vcs"] \
        -use_ip_compiled_libs
}
if {[catch {export_simulation {*}$exportArgs} exportError exportOptions]} {
    close_project
    return -options $exportOptions $exportError
}
set exportedScript [file normalize "$exportDir/$bdName/$simulator/$bdName.sh"]
if {![file exists $exportedScript]} {
    close_project
    error "export_simulation did not create the expected script: $exportedScript"
}

# --- 更新 export stamp ---
set stampFile [file normalize "$exportRoot/.export_stamp_$simulator"]
set fh [open $stampFile w]
puts $fh [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
close $fh
puts "INFO: export stamp written: $stampFile"
if {$simulator eq "vcs"} {
    file copy -force $stampFile [file normalize "$exportRoot/.export_stamp"]
}

# --- 拷贝 BD sim wrapper 到导出根目录（module_tb run_script 依赖）---
set bdSimV [file normalize "$bdDir/$bdName/sim/$bdName.v"]
if {[file exists $bdSimV]} {
    set bdSimCopy [file normalize "$exportRoot/$bdName.v"]
    file copy -force $bdSimV $bdSimCopy
    puts "INFO: BD sim wrapper copied: $bdSimCopy"
}

puts "INFO: BD export simulation complete."
puts "INFO:   export dir : $exportDir"
puts "INFO:   simulator  : $simulator"
if {$simulator eq "vcs"} {
    puts "INFO: Set XILINX_VCS_LIB before VCS (see scripts/sim/compile_xilinx_vcs_lib.tcl)"
}

close_project
