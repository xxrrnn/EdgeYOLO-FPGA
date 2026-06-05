# ==============================================================================
# config.tcl — 项目基础配置 + 实现阈值
# ==============================================================================

# --- 项目名称与路径 ---
set projName   "lite"
set bdName     "lite"
set topName    "${bdName}_wrapper"
set part       "xcvu37p-fsvh2892-2L-e"
set boardPart  "xilinx.com:vcu128:part0:1.0"

set ScriptDir   [file dirname [file normalize [info script]]]
set scriptsDir  [file normalize "$ScriptDir/.."]
set localDir    [file normalize "$scriptsDir/.."]
set buildDir    [file normalize "$localDir/build"]
set projPath    [file normalize "$buildDir/$projName"]
set bdDir       [file normalize "$localDir/bd"]
set ipBdDir     [file normalize "$scriptsDir/ip/bd/lite"]
set rootDir     $localDir
set srcDir      [file normalize "$rootDir/rtl"]
set vpuRtlDir   [file normalize "$srcDir/vpu"]
set xdcDir      [file normalize "$rootDir/xdc"]
set SynOutputDir  [file normalize "$projPath/SynOutputDir"]
set ImplOutputDir [file normalize "$projPath/ImplOutputDir"]

# module reference IP（OOC 需要 stub/DCP）
set modRefIpTops [list lite_vpu_0_0 lite_dcim_array_0_0]

# --- 解析 chip_defines.vh（BD 脚本依赖 ::DCIM_* 等全局变量）---
source [file normalize "$scriptsDir/common/chip_defines.tcl"]
chip_defines_load $localDir

# --- 综合/实现 directives ---
set synDirective        Default
set optDirective        ExploreWithRemap
set placeDirective      Default
set physOptDirective    AggressiveExplore
set routeDirective      AggressiveExplore

# --- DSP 限额（xcvu37p 共 9024 DSP48E2）---
# DCIM OOC 限额: 确保 DCIM + VPU(~57) + other < 9024
set dcimMaxDsp  8700
# 顶层综合总限额（二次保险）
set topMaxDsp   8800

# --- 时序门控阈值 ---
# post-place: 超过阈值 → 中止（不浪费 route 时间）
set wns_stop_place   -3.5
set tns_stop_place   -80000.0
set fail_stop_place  50000
set wns_warn_place   -2.0

# post-route: WNS < 0 不写 bitstream
# (hardcoded in proc, threshold = 0)

# --- 并发线程 ---
# Vivado 上限 64 线程；服务器 128 核，以下设置在安全范围内。
# 注意：place_design 必须单线程（Vivado 2024.2 ILR 多线程 SIGSEGV），
#       见 3_synth.tcl / run.tcl 中专门的 maxThreads 1 包围。
set_param general.maxThreads 32
catch {set_param place.ILREnabled false}

puts "INFO: config.tcl loaded — project: $projName, part: $part"
