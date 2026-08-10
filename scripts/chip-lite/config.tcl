# ==============================================================================
# config.tcl — 项目基础配置 + 实现阈值
# ==============================================================================

# --- 项目名称 ---
set projName   "lite"
set bdName     "lite"
set topName    "${bdName}_wrapper"
set part       "xcvu37p-fsvh2892-2L-e"
set boardPart  "xilinx.com:vcu128:part0:1.0"

# ==============================================================================
# 构建 Tag（支持并行跑多个 build，每次结果互不干扰）
# ------------------------------------------------------------------------------
# 优先级：
#   1. 环境变量 BUILD_TAG   → 自定义标签，例如 aggressive / exp1 / 260606
#   2. 当前 git short sha    → 便于 bitstream 追溯源码
#   3. 自动时间戳           → 非 git 环境下兜底
#
# 用法示例：
#   # 自动时间戳（推荐日常使用，无需手动命名）
#   vivado -mode batch -source scripts/chip-lite/run.tcl
#
#   # 自定义 tag（方便比较不同 directive）
#   BUILD_TAG=aggressive vivado -mode batch -source scripts/chip-lite/run.tcl &
#   BUILD_TAG=default    vivado -mode batch -source scripts/chip-lite/run.tcl &
#
#   # Resume 断点续跑（必须传相同 tag，否则找不到工程）
#   BUILD_TAG=aggressive RESUME_FROM=place vivado -mode batch -source scripts/chip-lite/run.tcl
#
# 结果目录结构：
#   build/lite/<tag>/          ← 本次 run 的隔离根目录（projPath）
#     <tag>.xpr                ← Vivado 工程（projName 仍为 "lite"，工程文件名用 tag）
#     lite.runs/               ← OOC runs 产物（Vivado 自动创建）
#     bd/lite/                 ← BD 生成产物（lite.bd / wrapper / ip/）
#     SynOutputDir/            ← 综合报告 + DCP
#     ImplOutputDir/           ← 实现报告 + DCP + bitstream
# ==============================================================================
if {[info exists ::env(BUILD_TAG)] && [string trim $::env(BUILD_TAG)] ne ""} {
    # 用户指定 tag（去除两端空白）
    set runTag [string trim $::env(BUILD_TAG)]
} else {
    # 默认使用 git short sha；非 git 环境下自动生成时间戳兜底。
    if {[catch {exec git rev-parse --short HEAD} _git_sha] || [string trim $_git_sha] eq ""} {
        set runTag [clock format [clock seconds] -format "%y%m%d_%H%M"]
    } else {
        set runTag [string trim $_git_sha]
    }
}

# --- 路径 ---
set ScriptDir   [file dirname [file normalize [info script]]]
set scriptsDir  [file normalize "$ScriptDir/.."]
set localDir    [file normalize "$scriptsDir/.."]
set buildDir    [file normalize "$localDir/build"]

# projPath = build/lite/<runTag>/  — 每次 run 独立，并行安全
set projPath    [file normalize "$buildDir/$projName/$runTag"]

# bdDir 放在 projPath 内部，BD 产物随 run 完全隔离
# 注意：ipBdDir（BD 创建脚本目录）是只读源码，不受此影响
set bdDir       [file normalize "$projPath/bd"]

# ipBdDir：BD 创建脚本（hbm.tcl / connect.tcl 等），保持指向源码，不随 run 变化
set ipBdDir     [file normalize "$scriptsDir/ip/bd/lite"]

set rootDir     $localDir
set srcDir      [file normalize "$rootDir/rtl"]
set vpuRtlDir   [file normalize "$srcDir/vpu"]
set xdcDir      [file normalize "$rootDir/xdc"]
set SynOutputDir  [file normalize "$projPath/SynOutputDir"]
set ImplOutputDir [file normalize "$projPath/ImplOutputDir"]

# module reference IP（OOC 需要 stub/DCP）
set modRefIpTops [list lite_vpu_0_0 lite_dcim_array_0_0 lite_cdma_ctrl_0 lite_inst_bram_0 lite_inst_decoder_0 lite_vpu_regs_0]

# --- 解析 chip_defines.vh（BD 脚本依赖 ::DCIM_* 等全局变量）---
source [file normalize "$scriptsDir/common/chip_defines.tcl"]
chip_defines_load $localDir

# --- 综合/实现 directives ---
set synDirective        Default
set optDirective        ExploreWithRemap
set placeDirective      Default
set physOptDirective    AggressiveExplore
set routeDirective      AggressiveExplore

# --- Timing Retry 策略集 ---
# run.tcl 在 post-route timing 失败时，从 post_opt.dcp 重新尝试下一组 directive。
# 每组策略跑 place → phys_opt → route 完整流程。
# 策略名 | place | phys_opt | route
# 这些 directive 已按 Vivado 2024.2.2 help/probe 过滤，避免无效策略浪费整轮实现。
set retryStrategies {
    {ExtraTimingOpt  AggressiveExplore     NoTimingRelaxation}
    {ExtraTimingOpt  AggressiveExplore     AggressiveExplore}
    {Explore         AggressiveExplore     NoTimingRelaxation}
    {Explore         AggressiveExplore     AggressiveExplore}
    {ExtraTimingOpt  ExploreWithHoldFix    NoTimingRelaxation}
    {Explore         ExploreWithHoldFix    Explore}
    {Default         AggressiveExplore     AggressiveExplore}
    {Default         ExploreWithHoldFix    Explore}
}

# --- DSP 用量说明 ---
# DCIM DSP 用量由 RTL 层精确控制：
#   chip_defines.vh: DCIM_DSP_TILES=4（所有 Tile 参与）, DCIM_DSP_COL_NUM=5
#   每 Tile: 5 col × 4 subcol × 64 ch = 1280 DSP48E2
#   4 Tile 总: 5120 + VPU(57) = 5177 < 9024（设备容量）
#   每 SLR: 2 Tile = 2560 < 3008（SLR 容量）
# 无需 synth_design -max_dsp 或 OOC patch。

# --- 时序门控阈值 ---
# post-place: 超过阈值 → 中止（不浪费 route 时间）
set wns_stop_place   -3.5
set tns_stop_place   -80000.0
set fail_stop_place  50000
set wns_warn_place   -2.0

# --- 详细时序报告 ---
# report_timing -max_paths 输出前 N 条 failing 路径（slack < 0）
set rptMaxPaths      50

# post-route: WNS < 0 不写 bitstream
# (hardcoded in proc, threshold = 0)

# STOP_AFTER=opt 只跑到 post_opt.dcp，用作 impl-race 的共享起点。
set stopAfter ""
if {[info exists ::env(STOP_AFTER)]} {
    set stopAfter [string tolower [string trim $::env(STOP_AFTER)]]
}
if {$stopAfter ne "" && $stopAfter ne "opt"} {
    puts "WARNING: STOP_AFTER='$stopAfter' is unsupported; ignoring."
    set stopAfter ""
}

# --- 并发线程 ---
# Vivado 2024.2.2 对 general.maxThreads 的有效范围是 1..32。
# 服务器 128 核主要通过 launch_runs -jobs 并行 OOC/IP 综合来利用。
proc env_int_or_default {name default} {
    if {[info exists ::env($name)] && [string trim $::env($name)] ne ""} {
        set value [string trim $::env($name)]
        if {![string is integer -strict $value] || $value < 1} {
            puts "WARNING: $name='$value' is invalid; using $default."
            return $default
        }
        return $value
    }
    return $default
}

proc clamp_vivado_threads {name value} {
    if {$value > 32} {
        puts "WARNING: $name=$value exceeds Vivado 2024.2 limit; using 32."
        return 32
    }
    return $value
}

set synthJobs [env_int_or_default SYNTH_JOBS 128]
set vivadoThreads [clamp_vivado_threads VIVADO_THREADS [env_int_or_default VIVADO_THREADS 32]]
set placeThreads  [clamp_vivado_threads PLACE_THREADS  [env_int_or_default PLACE_THREADS 8]]
set routeThreads  [clamp_vivado_threads ROUTE_THREADS  [env_int_or_default ROUTE_THREADS 32]]

proc use_vivado_threads {} {
    global vivadoThreads
    set_param general.maxThreads $vivadoThreads
}

proc use_place_threads {} {
    global placeThreads
    set_param general.maxThreads $placeThreads
}

proc use_route_threads {} {
    global routeThreads
    set_param general.maxThreads $routeThreads
}

use_vivado_threads
catch {set_param place.ILREnabled false}

puts "INFO: config.tcl loaded — project: $projName  tag: $runTag  part: $part"
puts "INFO: projPath = $projPath"
puts "INFO: Vivado parallelism — VIVADO_THREADS=$vivadoThreads  PLACE_THREADS=$placeThreads  ROUTE_THREADS=$routeThreads  SYNTH_JOBS=$synthJobs"

# ==============================================================================
# 邮件通知配置（126邮箱，留空则不启用）
# ==============================================================================
# 通过环境变量配置；未设置时不发送，避免把邮箱授权码提交到仓库。
set notifyEmail    [expr {[info exists ::env(EDGEYOLO_NOTIFY_EMAIL)] ? $::env(EDGEYOLO_NOTIFY_EMAIL) : ""}]
set notify126From  [expr {[info exists ::env(EDGEYOLO_NOTIFY_FROM)] ? $::env(EDGEYOLO_NOTIFY_FROM) : ""}]
set notify126Auth  [expr {[info exists ::env(EDGEYOLO_NOTIFY_AUTH)] ? $::env(EDGEYOLO_NOTIFY_AUTH) : ""}]
