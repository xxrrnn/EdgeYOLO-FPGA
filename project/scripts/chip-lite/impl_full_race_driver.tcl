# ==============================================================================
# impl_full_race_driver.tcl — run complete place/phys_opt/route attempts in
# parallel from the post_opt checkpoint produced by the current full run.
# ==============================================================================
proc run_full_race_impl {sourceDcp} {
    global ScriptDir runTag ImplOutputDir placeThreads routeThreads vivadoThreads

    if {$::tcl_platform(platform) ne "unix"} {
        error "parallel full implementation race requires the Linux build host"
    }

    set raceScript [file normalize "$ScriptDir/impl_race.sh"]
    if {![file exists $raceScript]} { error "full implementation race script not found: $raceScript" }
    if {![file exists $sourceDcp]} { error "post_opt checkpoint not found: $sourceDcp" }

    set ::fullRaceBitWritten 0
    catch {close_design -quiet}
    set command [list env \
        "TAG=$runTag" \
        "BUILD_TAG=$runTag" \
        "PLACE_THREADS=$placeThreads" \
        "ROUTE_THREADS=$routeThreads" \
        "VIVADO_THREADS=$vivadoThreads" \
        bash $raceScript]

    puts "INFO: launching full-space implementation race"
    puts "INFO: command = $command"
    if {[catch {exec {*}$command >@stdout 2>@stderr} err opts]} {
        puts "ERROR: full implementation race failed: $err"
        return -options $opts $err
    }

    set winnerDcp [file normalize "$ImplOutputDir/post_route.dcp"]
    set winnerBit [file normalize "$ImplOutputDir/top.bit"]
    set winnerLtx [file normalize "$ImplOutputDir/top.ltx"]
    foreach required [list $winnerDcp $winnerBit $winnerLtx] {
        if {![file exists $required]} { error "full implementation race did not produce $required" }
    }

    open_checkpoint $winnerDcp
    set setupPath [get_timing_paths -max_paths 1 -delay_type max -quiet]
    set holdPath  [get_timing_paths -max_paths 1 -delay_type min -quiet]
    set routeWns 0.0
    set routeWhs 0.0
    if {[llength $setupPath]} { set routeWns [get_property SLACK [lindex $setupPath 0]] }
    if {[llength $holdPath]}  { set routeWhs [get_property SLACK [lindex $holdPath 0]] }
    puts "INFO: selected full-race result WNS=${routeWns}ns WHS=${routeWhs}ns"

    report_drc -file [file normalize "$ImplOutputDir/post_route_drc.rpt"]
    report_methodology -file [file normalize "$ImplOutputDir/post_route_methodology.rpt"]
    report_design_analysis -congestion -complexity \
        -file [file normalize "$ImplOutputDir/post_route_congestion.rpt"]
    report_power -advisory -file [file normalize "$ImplOutputDir/post_route_power.rpt"]
    set ::fullRaceBitWritten 1
    return [list $routeWns $routeWhs]
}
