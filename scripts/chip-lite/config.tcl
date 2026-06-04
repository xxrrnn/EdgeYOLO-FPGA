# DCIM_Array + VPU Lite project configuration
set projName "lite"
set bdName "lite"
set topName "${bdName}_wrapper"

# module reference IP（OOC 后需有 stub/DCP）
set modRefIpTops [list lite_vpu_0_0 lite_dcim_array_0_0]

set ScriptDir [file dirname [file normalize [info script]]]
set scriptsDir [file normalize "$ScriptDir/.."]
set localDir [file normalize "$scriptsDir/.."]
set buildDir [file normalize "$localDir/build"]
set projPath [file normalize "$buildDir/$projName"]
set bdDir [file normalize "$localDir/bd"]
set ipBdDir [file normalize "$scriptsDir/ip/bd/lite"]

set part "xcvu37p-fsvh2892-2L-e"
set boardPart "xilinx.com:vcu128:part0:1.0"

set rootDir $localDir
set srcDir [file normalize "$rootDir/rtl"]

# 解析 chip_defines.vh → ::DCIM_* / ::VPU_* 等全局变量（hbm.tcl / export 使用）
source [file normalize "$scriptsDir/common/chip_defines.tcl"]
chip_defines_load $localDir
set vpuRtlDir [file normalize "$srcDir/vpu"]
set xdcDir [file normalize "$rootDir/xdc"]
set SynOutputDir [file normalize "$projPath/SynOutputDir"]
set ImplOutputDir [file normalize "$projPath/ImplOutputDir"]

set synDirective Default
set optDirective ExploreWithRemap
# NOTE: "AltSpreadLogic_high" triggered Vivado 2024.2 placer SIGSEGV
# (Phase 2.6.2 HAPLFTypeUtils::buildTypeToIdMap multi-thread race condition crash).
# Fix: use Default directive + single thread + disable ILR.
set placeDirective Default
set physOptDirectiveAp AggressiveExplore
set routeDirective AggressiveExplore
set physOptDirectiveAr AggressiveExplore
# Multi-thread for synth / IP-synth / opt / route (machine has 128 cores).
# The Vivado 2024.2 SIGSEGV is ONLY in place_design's multi-threaded ILR, so we
# drop to single thread JUST around place_design (see 2_synth.tcl) instead of
# crippling the whole flow. This keeps QoR identical but is much faster.
set_param general.maxThreads 8
# NOTE: 'place.ILREnabled' does not exist in Vivado 2024.2.2 (Common 17-153).
# It is redundant anyway: the real fix is maxThreads 1 (single thread => no ILR race).
# Guard with catch so a missing param can never abort the whole flow.
catch {set_param place.ILREnabled false}
