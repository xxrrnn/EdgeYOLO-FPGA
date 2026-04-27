# run_xdma_bram.tcl
# XDMA BRAM 自动化构建脚本
set projName "xdma_bram"
set bdName "xdma_bram"


# 1. 路径和工程基础配置
set xdmaBramScriptDir [file dirname [file normalize [info script]]]
set scriptsDir [file normalize "$xdmaBramScriptDir/.."]
set localDir [file normalize "$scriptsDir/.."]
set buildDir [file normalize "$localDir/build"]
set projPath [file normalize "$buildDir/$projName"]
set bdDir [file normalize "$localDir/bd"]

set ipBdDir [file normalize "$scriptsDir/ip/bd/xdma_bram"]

set part "xcvu37p-fsvh2892-2L-e"
set boardPart "xilinx.com:vcu128:part0:1.0"

# 2. 后续脚本可直接使用的目录
set rootDir $localDir
set srcDir [file normalize "$rootDir/rtl"]
set xdcDir [file normalize "$rootDir/xdc"]
set SynOutputDir [file normalize "$projPath/SynOutputDir"]
set ImplOutputDir [file normalize "$projPath/ImplOutputDir"]

# 3. 设计工具指令和运行参数
set synDirective Default
set optDirective Default
set placeDirective Default
set physOptDirectiveAp Default
set routeDirective Default
set physOptDirectiveAr Default
set_param general.maxThreads 24

if {[llength [info commands create_project]] == 0} {
    error "This script must be sourced in Vivado Tcl, not plain tclsh."
}

if {[llength [get_projects -quiet]] != 0} {
    close_project
}

# 如果工程已存在，直接删除后重建
if {[file exists $projPath]} {
    puts "Info: Project directory exists, removing: $projPath"
    file delete -force $projPath
}

create_project $projName $projPath -part $part
set_property board_part $boardPart [current_project]

# add xdc for led
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/$bdName/*.xdc"]] {
    add_files -fileset constrs_1 $xdcFile
}