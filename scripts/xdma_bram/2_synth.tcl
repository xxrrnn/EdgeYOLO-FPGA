set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists xdmaBramScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

if {[llength [get_projects -quiet]] == 0} {
    error "Please open the Vivado project before sourcing 2_synth.tcl."
}

file mkdir $SynOutputDir
file mkdir $ImplOutputDir

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
set wrapperFile [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]

if {![file exists $bdFile]} {
    error "BD file does not exist: $bdFile. Please source 1_bd.tcl before 2_synth.tcl."
}

if {[llength [get_files -quiet $bdFile]] == 0} {
    add_files -norecurse $bdFile
}

if {![file exists $wrapperFile]} {
    make_wrapper -files [get_files $bdFile] -top
}

if {![file exists $wrapperFile]} {
    error "BD wrapper was not generated: $wrapperFile"
}

if {[llength [get_files -quiet $wrapperFile]] == 0} {
    add_files -norecurse $wrapperFile
}

set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

# Generate BD output products and IP user files. The top-level synthesis later
# depends on the generated BD/IP files and the OOC IP checkpoints.
generate_target all [get_files $bdFile]
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force -quiet

# Create out-of-context synthesis runs for all IP instances inside this BD.
# Without these DCPs, top-level synth_design can fail with "DCP does not exist".
catch {create_ip_run [get_files -of_objects [get_fileset sources_1] $bdFile]}
set ipSynthRuns [get_runs -quiet ${bdName}_*_synth_1]
if {[llength $ipSynthRuns] > 0} {
    reset_run $ipSynthRuns
    launch_runs $ipSynthRuns -jobs [get_param general.maxThreads]
    foreach ipRun $ipSynthRuns {
        wait_on_run $ipRun
        set runStatus [get_property STATUS [get_runs $ipRun]]
        if {![string match "*Complete*" $runStatus] && ![string match "*Using cached IP results*" $runStatus]} {
            error "IP synthesis run $ipRun failed: $runStatus"
        }
    }
}

# Export simulation scripts for the BD/IPs. This is not required for bitstream
# generation, but keeps the project-generated IP user files complete.
export_simulation \
  -of_objects [get_files $bdFile] \
  -directory [file normalize "$projPath/${projName}.ip_user_files/sim_scripts"] \
  -ip_user_files_dir [file normalize "$projPath/${projName}.ip_user_files"] \
  -ipstatic_source_dir [file normalize "$projPath/${projName}.ip_user_files/ipstatic"] \
  -use_ip_compiled_libs \
  -force \
  -quiet

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/$bdName/*.xdc"]] {
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

update_compile_order -fileset sources_1

# 1. Synthesis
synth_design -top $topName -part $part -directive $synDirective
write_checkpoint -force [file normalize "$SynOutputDir/post_synth.dcp"]
report_timing_summary -file [file normalize "$SynOutputDir/post_synth_timing_summary.rpt"]
report_utilization -file [file normalize "$SynOutputDir/post_synth_util.rpt"]

set launchDir [pwd]
cd $ImplOutputDir

# 2. Optimization
opt_design -directive $optDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_opt.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_opt_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_opt_util.rpt"]

# 3. Placement
place_design -directive $placeDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_place_util.rpt"]

# 4. Physical optimization after placement
phys_opt_design -directive $physOptDirectiveAp
write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_ap.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_ap_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_phys_opt_ap_util.rpt"]

# 5. Routing
route_design -directive $routeDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]

# 6. Optional physical optimization after routing
phys_opt_design -directive $physOptDirectiveAr
write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_ar.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_ar_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_phys_opt_ar_util.rpt"]

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]

cd $launchDir
