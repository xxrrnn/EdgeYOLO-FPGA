# ==============================================================================
# impl_race_worker.tcl — one implementation strategy from post_opt.dcp
# ==============================================================================
# This script is launched by scripts/chip-lite/impl_race.sh. Each worker uses a
# private output directory, so several strategies can run in parallel from the
# same post_opt.dcp.

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

proc env_string_or_default {name default} {
    if {[info exists ::env($name)] && [string trim $::env($name)] ne ""} {
        return [string trim $::env($name)]
    }
    return $default
}

proc race_write_status {status detail} {
    global attemptDir attemptName placeDirectiveWorker physDirectiveWorker routeDirectiveWorker
    global ppWns routeWns routeWhs

    file mkdir $attemptDir
    set fp [open [file normalize "$attemptDir/status.txt"] w]
    puts $fp "STATUS\t$status"
    puts $fp "DETAIL\t$detail"
    puts $fp "ATTEMPT\t$attemptName"
    puts $fp "PLACE\t$placeDirectiveWorker"
    puts $fp "PHYS_OPT\t$physDirectiveWorker"
    puts $fp "ROUTE\t$routeDirectiveWorker"
    if {[info exists ppWns]} { puts $fp "POST_PLACE_WNS\t$ppWns" }
    if {[info exists routeWns]} { puts $fp "POST_ROUTE_WNS\t$routeWns" }
    if {[info exists routeWhs]} { puts $fp "POST_ROUTE_WHS\t$routeWhs" }
    puts $fp "TIME\t[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    close $fp
}

set attemptName [env_string_or_default IMPL_ATTEMPT "attempt0"]
set placeDirectiveWorker [env_string_or_default PLACE_DIRECTIVE $placeDirective]
set physDirectiveWorker  [env_string_or_default PHYS_OPT_DIRECTIVE $physOptDirective]
set routeDirectiveWorker [env_string_or_default ROUTE_DIRECTIVE $routeDirective]

set sourceDcp [env_string_or_default SOURCE_DCP [file normalize "$ImplOutputDir/post_opt.dcp"]]
set raceRoot  [env_string_or_default RACE_ROOT [file normalize "$ImplOutputDir/race"]]
set attemptDir [file normalize "$raceRoot/$attemptName"]
file mkdir $attemptDir

if {![file exists $sourceDcp]} {
    race_write_status "ERROR" "post_opt checkpoint not found: $sourceDcp"
    error "post_opt checkpoint not found: $sourceDcp"
}

puts "INFO: impl-race worker start"
puts "INFO: attempt=$attemptName"
puts "INFO: sourceDcp=$sourceDcp"
puts "INFO: attemptDir=$attemptDir"
puts "INFO: strategy place=$placeDirectiveWorker phys_opt=$physDirectiveWorker route=$routeDirectiveWorker"

if {[catch {
    open_checkpoint $sourceDcp

    set pbs [get_pblocks -quiet]
    if {[llength $pbs]} { delete_pblocks $pbs }
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]

    puts "\n---------- Race Place: $placeDirectiveWorker ----------"
    catch {set_param place.ILREnabled false}
    use_place_threads
    place_design -directive $placeDirectiveWorker
    use_vivado_threads

    set placeDcp [file normalize "$attemptDir/post_place.dcp"]
    write_checkpoint -force $placeDcp
    report_timing_summary -file [file normalize "$attemptDir/post_place_timing_summary.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$attemptDir/post_place_failing_paths.rpt"]
    report_utilization -file [file normalize "$attemptDir/post_place_util.rpt"]
    report_design_analysis -congestion -file [file normalize "$attemptDir/post_place_congestion.rpt"]

    set ppPath [get_timing_paths -max_paths 1 -delay_type max]
    set ppWns 0.0
    if {[llength $ppPath]} { set ppWns [get_property SLACK [lindex $ppPath 0]] }
    puts "INFO: Race post-place WNS = ${ppWns} ns"
    if {$ppWns < $wns_stop_place} {
        race_write_status "SKIP" "post-place WNS ${ppWns} < threshold ${wns_stop_place}"
        puts "WARNING: Race worker skipped after place."
        exit 0
    }

    puts "\n---------- Race Phys Opt: $physDirectiveWorker ----------"
    phys_opt_design -directive $physDirectiveWorker
    write_checkpoint -force [file normalize "$attemptDir/post_phys_opt.dcp"]
    report_timing_summary -file [file normalize "$attemptDir/post_phys_opt_timing_summary.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$attemptDir/post_phys_opt_failing_paths.rpt"]

    puts "\n---------- Race Route: $routeDirectiveWorker ----------"
    use_route_threads
    route_design -directive $routeDirectiveWorker
    use_vivado_threads
    phys_opt_design -directive AggressiveExplore
    phys_opt_design -hold_fix

    set routeDcp [file normalize "$attemptDir/post_route.dcp"]
    write_checkpoint -force $routeDcp
    report_timing_summary -file [file normalize "$attemptDir/post_route_timing_summary.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$attemptDir/post_route_failing_paths.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type min \
        -file [file normalize "$attemptDir/post_route_hold_paths.rpt"]
    report_utilization -file [file normalize "$attemptDir/post_route_util.rpt"]
    report_design_analysis -congestion -complexity -file [file normalize "$attemptDir/post_route_congestion.rpt"]
    report_drc -file [file normalize "$attemptDir/post_route_drc.rpt"]
    report_methodology -file [file normalize "$attemptDir/post_route_methodology.rpt"]

    set setupPath [get_timing_paths -max_paths 1 -delay_type max]
    set holdPath  [get_timing_paths -max_paths 1 -delay_type min]
    set routeWns 0.0
    set routeWhs 0.0
    if {[llength $setupPath]} { set routeWns [get_property SLACK [lindex $setupPath 0]] }
    if {[llength $holdPath]}  { set routeWhs [get_property SLACK [lindex $holdPath 0]] }
    puts "INFO: Race post-route WNS=${routeWns} ns WHS=${routeWhs} ns"

    if {$routeWns >= 0 && $routeWhs >= 0} {
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$attemptDir/top.bit"]
        race_write_status "SUCCESS" "timing met"
    } else {
        race_write_status "TIMING_FAIL" "timing not met"
    }
} err opts]} {
    race_write_status "ERROR" $err
    puts "ERROR: impl-race worker failed: $err"
    return -options $opts $err
}

puts "INFO: impl-race worker done: $attemptName"
