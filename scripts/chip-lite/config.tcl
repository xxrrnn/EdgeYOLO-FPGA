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
#   2. 自动时间戳           → 格式 yymmdd_HHMM，每次唯一
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
    # 自动生成时间戳（yymmdd_HHMM），并行时每次唯一
    set runTag [clock format [clock seconds] -format "%y%m%d_%H%M"]
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

# --- Timing Retry 策略集（xcvu37p 实测有效 directive）---
# place_design -directive 在 xcvu37p 上实测有效：
#   Default | Explore | ExtraTimingOpt | RuntimeOptimized | Quick
# 以下对 xcvu37p 无效（Constraints 18-641）：
#   AggressiveExplore | AltSpreadLogic | SSI_SpreadSLLs
#
# 实测结果（fix4 attempt 1）：
#   ExtraTimingOpt + NoTimingRelaxation → post-route WNS = -0.016ns（极接近收敛）
#
# 格式：{placeDirective physOptDirective routeDirective}
set retryStrategies {
    {ExtraTimingOpt  AggressiveExplore  NoTimingRelaxation}
    {ExtraTimingOpt  AggressiveExplore  AggressiveExplore}
    {Explore         AggressiveExplore  NoTimingRelaxation}
    {Explore         AggressiveExplore  AggressiveExplore}
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

# --- 并发线程 ---
# Vivado 上限 64 线程；服务器 128 核，以下设置在安全范围内。
# synthJobs: launch_runs -jobs 的并行 OOC synth 进程数（充分利用 CPU）
# maxThreads: 单个 Vivado 进程内部的多线程数
set synthJobs 128
set_param general.maxThreads 32
catch {set_param place.ILREnabled false}

puts "INFO: config.tcl loaded — project: $projName  tag: $runTag  part: $part"
puts "INFO: projPath = $projPath"

# ==============================================================================
# 邮件通知配置（126邮箱，留空则不启用）
# ==============================================================================
# 填写后自动在 build 完成/失败时发送通知
set notifyEmail    "xrn2019@126.com"             ;# 接收通知的邮箱（可与发件箱不同）
set notify126From  "xrn2019@126.com"             ;# 你的126发件邮箱，例如 foo@126.com
set notify126Auth  "EP35FjvaTixBNgbq"             ;# 126邮箱授权码（网页端「设置-POP3/SMTP」获取）
