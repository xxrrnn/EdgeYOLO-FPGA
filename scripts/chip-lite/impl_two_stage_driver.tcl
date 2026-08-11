# ==============================================================================
# impl_two_stage_driver.tcl — invoke the Linux two-stage implementation race
# from project-mode Tcl and reopen its canonical winning checkpoint.
# ==============================================================================
proc run_two_stage_impl {sourceDcp} {
    global ScriptDir runTag ImplOutputDir placeThreads routeThreads vivadoThreads

    if {$::tcl_platform(platform) ne "unix"} {
        error "two-stage parallel implementation requires the Linux build host"
    }

    set raceScript [file normalize "$ScriptDir/impl_two_stage.sh"]
    if {![file exists $raceScript]} { error "two-stage race script not found: $raceScript" }

    catch {close_design -quiet}
    set command [list env \
        "BUILD_TAG=$runTag" \
        "SOURCE_DCP=[file normalize $sourceDcp]" \
        "PLACE_THREADS=$placeThreads" \
        "ROUTE_THREADS=$routeThreads" \
        "VIVADO_THREADS=$vivadoThreads" \
        bash $raceScript]

    puts "INFO: launching two-stage implementation race"
    puts "INFO: command = $command"
    if {[catch {exec {*}$command >@stdout 2>@stderr} err opts]} {
        puts "ERROR: two-stage implementation race failed: $err"
        return -options $opts $err
    }

    set winnerDcp [file normalize "$ImplOutputDir/post_route.dcp"]
    if {![file exists $winnerDcp]} {
        error "two-stage implementation did not produce $winnerDcp"
    }
    open_checkpoint $winnerDcp

    set setupPath [get_timing_paths -max_paths 1 -delay_type max -quiet]
    set holdPath  [get_timing_paths -max_paths 1 -delay_type min -quiet]
    set routeWns 0.0
    set routeWhs 0.0
    if {[llength $setupPath]} { set routeWns [get_property SLACK [lindex $setupPath 0]] }
    if {[llength $holdPath]}  { set routeWhs [get_property SLACK [lindex $holdPath 0]] }
    puts "INFO: selected two-stage result WNS=${routeWns}ns WHS=${routeWhs}ns"

    report_drc -file [file normalize "$ImplOutputDir/post_route_drc.rpt"]
    report_methodology -file [file normalize "$ImplOutputDir/post_route_methodology.rpt"]
    report_design_analysis -congestion -complexity \
        -file [file normalize "$ImplOutputDir/post_route_congestion.rpt"]
    report_power -advisory -file [file normalize "$ImplOutputDir/post_route_power.rpt"]
    if {$routeWns >= 0.0 && $routeWhs >= 0.0} {
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]
        write_debug_probes -force [file normalize "$ImplOutputDir/top.ltx"]
        puts "INFO: canonical bitstream/debug probes written once for selected winner."
    }
    return [list $routeWns $routeWhs]
}
