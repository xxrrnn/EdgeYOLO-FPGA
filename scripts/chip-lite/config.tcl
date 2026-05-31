# DCIM_Array + VPU Lite project configuration (1-group DCIM + im2col).
set projName "lite"
set bdName "lite"
set topName "${bdName}_wrapper"

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
set vpuRtlDir [file normalize "$srcDir/vpu"]
set xdcDir [file normalize "$rootDir/xdc"]
set SynOutputDir [file normalize "$projPath/SynOutputDir"]
set ImplOutputDir [file normalize "$projPath/ImplOutputDir"]

set synDirective Default
set optDirective ExploreWithRemap
# NOTE: "Explore" / "AltSpreadLogic_high" triggered Vivado 2024.2 placer SIGSEGV
# (Phase 2.6.2 HAPLFTypeUtils::buildTypeToIdMap crash). Use Default for stability.
set placeDirective Default
set physOptDirectiveAp AggressiveExplore
set routeDirective AggressiveExplore
set physOptDirectiveAr AggressiveExplore
set_param general.maxThreads 32
