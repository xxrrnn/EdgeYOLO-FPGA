# Export lite Block Design simulation filelist for Synopsys VCS.
# Prerequisite: build/lite project exists (source 0_build.tcl + 1_bd.tcl + synth if needed).
#
# Usage (from repo root):
#   vivado -mode batch -source scripts/chip-lite/3_export_sim.tcl
#
# Output: sim/lite_bd_export/vcs/  (+ optional copy of bd/lite/sim/lite.v)

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

set exportRoot [file normalize "$localDir/sim/lite_bd_export"]
set exportDir  [file normalize "$exportRoot/vcs"]
file mkdir $exportRoot

if {![file exists $projPath/lite.xpr]} {
    error "Project not found: $projPath/lite.xpr — run 0_build.tcl and 1_bd.tcl first."
}

open_project $projPath/lite.xpr

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {![file exists $bdFile]} {
    error "BD not found: $bdFile"
}

# Apply DCIM module_ref parameters before exporting.  Vivado freezes module_ref
# parameters into lite_dcim_array_0_0.v, so changing chip_defines.vh alone is not enough.
open_bd_design $bdFile
set dcimCell [get_bd_cells -quiet dcim_array_0]
if {[llength $dcimCell] == 0} {
    set dcimCell [get_bd_cells -quiet -filter {VLNV =~ "*DCIM_Array_bd*"}]
}
if {[llength $dcimCell] == 0} {
    puts "ERROR: available BD cells: [get_bd_cells -quiet]"
    error "BD cell dcim_array_0 / DCIM_Array_bd not found"
}
set_property -dict [list \
    CONFIG.NUM_GROUPS {1} \
    CONFIG.TILES_PER_GROUP {64} \
    CONFIG.NUM_TILES {64} \
] $dcimCell
save_bd_design

# Ensure functional sim netlist for top BD is regenerated after parameter changes.
set bdSimV [file normalize "$bdDir/$bdName/sim/$bdName.v"]
puts "INFO: regenerate simulation target for $bdName"
generate_target {simulation} [get_files $bdFile] -force
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force

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
set bdSimCopy [file normalize "$exportRoot/$bdName.v"]
file copy -force $bdSimV $bdSimCopy

puts "INFO: BD export simulation complete."
puts "INFO:   export dir : $exportDir"
puts "INFO:   bd sim copy: $bdSimCopy"
puts "INFO: Set XILINX_VCS_LIB before VCS (see scripts/sim/compile_xilinx_vcs_lib.tcl)"

close_project
