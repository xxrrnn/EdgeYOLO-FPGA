# XDMA BRAM project configuration.
# This file only defines paths and build parameters. It does not create or
# close a Vivado project, so it is safe to source after opening an existing
# project.

set projName "xdma_bram"
set bdName "xdma_bram"
set topName "${bdName}_wrapper"

set xdmaBramScriptDir [file dirname [file normalize [info script]]]
set scriptsDir [file normalize "$xdmaBramScriptDir/.."]
set localDir [file normalize "$scriptsDir/.."]
set buildDir [file normalize "$localDir/build"]
set projPath [file normalize "$buildDir/$projName"]
set bdDir [file normalize "$localDir/bd"]
set ipBdDir [file normalize "$scriptsDir/ip/bd/xdma_bram"]

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
set_param general.maxThreads 24
