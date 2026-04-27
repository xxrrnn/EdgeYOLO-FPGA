if {![info exists topName] || ![info exists SynOutputDir] || ![info exists ImplOutputDir]} {
    error "Please source 1_bd.tcl before 2_synth.tcl."
}


file mkdir $SynOutputDir
file mkdir $ImplOutputDir

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
