# Export lite Block Design simulation filelist for Synopsys VCS.
# Prerequisite: build/lite project exists (source 0_build.tcl + 1_bd.tcl + synth if needed).
#
# Usage (from repo root):
#   vivado -mode batch -source scripts/chip-lite/4_export_sim.tcl
#
# Output: sim/lite_bd_export/vcs/  (+ optional copy of bd/lite/sim/lite.v)

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

set exportRoot [file normalize "$localDir/sim/lite_bd_export"]
set exportDir  [file normalize "$exportRoot/vcs"]
file mkdir $exportRoot

source [file normalize "$scriptsDir/common/chip_lite_bd.tcl"]
chip_lite_ensure_project_open

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
chip_lite_open_bd_design $bdFile $bdName

# Apply DCIM module_ref parameters before exporting.  Vivado freezes module_ref
# parameters into lite_dcim_array_0_0.v, so changing chip_defines.vh alone is not enough.
set dcimCell [chip_lite_get_bd_cell dcim_array_0 {*DCIM_Array_bd*}]
if {[llength $dcimCell] == 0} {
    puts "ERROR: available BD cells: [get_bd_cells -quiet]"
    error "BD cell dcim_array_0 / DCIM_Array_bd not found"
}
set_property -dict [list \
    CONFIG.NUM_TILES {4} \
] $dcimCell

chip_defines_load $localDir
apply_dcim_axi_bram_read_latency
save_bd_design
set exportStamp [file normalize "$exportRoot/.export_stamp"]
close [open $exportStamp w]

# Regenerate module_ref wrappers via parent BD only (nested XCI cannot generate_target alone).
set bdSimV [file normalize "$bdDir/$bdName/sim/$bdName.v"]
if {![file exists $bdSimV]} {
    puts "INFO: regenerate simulation target for $bdName"
    if {[catch {generate_target {simulation} [get_files $bdFile] -force} err]} {
        puts "WARNING: generate_target simulation: $err"
        puts "INFO: continue — 1_bd.tcl generate_target {all} may have already produced IP sim models"
    }
} else {
    puts "INFO: reuse existing BD sim netlist $bdSimV"
}
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force

# Vivado does not always copy module_ref sim netlists into ip_user_files; sync for make check-export.
foreach ipTop $modRefIpTops {
    set src [file normalize "$bdDir/$bdName/ip/$ipTop/sim/${ipTop}.v"]
    if {![file exists $src]} {
        error "module_ref sim wrapper missing after generate_target: $src"
    }
    set dstDir [file normalize "$projPath/${projName}.ip_user_files/bd/$bdName/ip/$ipTop/sim"]
    file mkdir $dstDir
    set dst [file join $dstDir ${ipTop}.v]
    file copy -force $src $dst
    puts "INFO: synced $ipTop sim wrapper -> $dst"
}

puts "INFO: export_simulation -> $exportDir"
if {[file exists $exportDir]} {
    file delete -force $exportDir
}
file mkdir $exportDir

# 确保 vpu_defines.vh 已加入项目（新创建的转发文件，不在原始 fileset 里）
set vpuDefsFile [file normalize "$localDir/rtl/vpu/vpu_defines.vh"]
if {[file exists $vpuDefsFile]} {
    if {[llength [get_files -quiet $vpuDefsFile]] == 0} {
        puts "INFO: adding vpu_defines.vh to project fileset"
        add_files -norecurse $vpuDefsFile
        set_property file_type {Verilog Header} [get_files $vpuDefsFile]
    }
}

export_simulation \
  -of_objects [get_files $bdFile] \
  -directory $exportDir \
  -simulator vcs \
  -absolute_path \
  -force \
  -lib_map_path [list xpm=$::env(XILINX_VIVADO)/data/xpm] \
  -use_ip_compiled_libs

# Keep a stable copy of BD sim netlist beside export (filelist fallback)
# Optional: only copy if generate_target produced the sim netlist at the expected path.
set bdSimCopy [file normalize "$exportRoot/$bdName.v"]
if {[file exists $bdSimV]} {
    file copy -force $bdSimV $bdSimCopy
    puts "INFO: copied BD sim netlist to $bdSimCopy"
} else {
    puts "WARNING: BD sim netlist not found at $bdSimV (OK if export_simulation regenerated it)"
}

puts "INFO: BD export simulation complete."
puts "INFO:   export dir : $exportDir"
puts "INFO:   bd sim copy: $bdSimCopy"
puts "INFO: Set XILINX_VCS_LIB before VCS (see scripts/sim/compile_xilinx_vcs_lib.tcl)"

close_project
