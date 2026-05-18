# Global_VPU（rtl/vpu/Global_VPU_top）+ XDMA + CDMA + HBM BRAM（暂时替代HBM）。
# BD：scripts/ip/bd/vpu；比特流 build/vpu/ImplOutputDir/top.bit

set projName "vpu"
set bdName "vpu"
set topName "${bdName}_wrapper"

set ScriptDir [file dirname [file normalize [info script]]]
set scriptsDir [file normalize "$ScriptDir/.."]
set localDir [file normalize "$scriptsDir/.."]
set buildDir [file normalize "$localDir/build"]
set projPath [file normalize "$buildDir/$projName"]
set bdDir [file normalize "$projPath/bd"]
set ipBdDir [file normalize "$scriptsDir/ip/bd/vpu"]
set vpuRtlDir [file normalize "$localDir/rtl/vpu"]

set part "xcvu37p-fsvh2892-2L-e"
set boardPart "xilinx.com:vcu128:part0:1.0"

set rootDir $localDir
set srcDir [file normalize "$rootDir/rtl"]
set xdcDir [file normalize "$rootDir/xdc"]
set SynOutputDir [file normalize "$projPath/SynOutputDir"]
set ImplOutputDir [file normalize "$projPath/ImplOutputDir"]

set synDirective Default
set optDirective Default
set placeDirective Default
set physOptDirectiveAp Default
set routeDirective Default
set physOptDirectiveAr Default
# IP综合和Block Design使用32线程（Vivado某些操作有限制）
# 主综合和实现阶段会自动使用所有可用核心
set_param general.maxThreads 32
