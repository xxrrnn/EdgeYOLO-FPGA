# XDMA BRAM project configuration.
# This file only defines paths and build parameters. It does not create or
# close a Vivado project, so it is safe to source after opening an existing
# project.

set projName "xdma_hbm"
set bdName "xdma_hbm"
set topName "${bdName}_wrapper"

set xdma_hbmScriptDir [file dirname [file normalize [info script]]]
set scriptsDir [file normalize "$xdma_hbmScriptDir/.."]
set localDir [file normalize "$scriptsDir/.."]
set buildDir [file normalize "$localDir/build"]
set projPath [file normalize "$buildDir/$projName"]
set bdDir [file normalize "$localDir/bd"]
set ipBdDir [file normalize "$scriptsDir/ip/bd/xdma_hbm"]

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

# HBM + XDMA generates many large OOC IP synthesis runs. Keep those runs
# sequential and cap Vivado's internal worker threads so the build does not get
# killed by memory pressure on 32 GB machines.
set vivadoMaxThreads 32
# set ipSynthJobs 1
set_param general.maxThreads $vivadoMaxThreads
