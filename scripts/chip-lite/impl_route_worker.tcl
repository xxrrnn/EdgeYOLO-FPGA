# ==============================================================================
# impl_route_worker.tcl — phys_opt/route from a selected post_place DCP
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

proc env_required {name} {
    if {![info exists ::env($name)] || [string trim $::env($name)] eq ""} {
        error "required environment variable $name is not set"
    }
    return [string trim $::env($name)]
}

proc env_double_default {name default} {
    if {[info exists ::env($name)] && [string is double -strict [string trim $::env($name)]]} {
        return [string trim $::env($name)]
    }
    return $default
}

proc write_route_status {status detail} {
    global routeDir taskName sourceCandidate physDirectiveWorker routeDirectiveWorker
    global routeWns routeWhs minWns minWhs
    file mkdir $routeDir
    set fp [open [file normalize "$routeDir/status.txt"] w]
    puts $fp "STATUS\t$status"
    puts $fp "DETAIL\t$detail"
    puts $fp "TASK\t$taskName"
    puts $fp "SOURCE_CANDIDATE\t$sourceCandidate"
    puts $fp "PHYS_OPT\t$physDirectiveWorker"
    puts $fp "ROUTE\t$routeDirectiveWorker"
    puts $fp "MIN_WNS\t$minWns"
    puts $fp "MIN_WHS\t$minWhs"
    if {[info exists routeWns]} { puts $fp "POST_ROUTE_WNS\t$routeWns" }
    if {[info exists routeWhs]} { puts $fp "POST_ROUTE_WHS\t$routeWhs" }
    puts $fp "TIME\t[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    close $fp
}

set sourceDcp           [file normalize [env_required SOURCE_DCP]]
set raceRoot            [file normalize [env_required RACE_ROOT]]
set taskName            [env_required IMPL_TASK]
set sourceCandidate     [env_required SOURCE_CANDIDATE]
set physDirectiveWorker [env_required PHYS_OPT_DIRECTIVE]
set routeDirectiveWorker [env_required ROUTE_DIRECTIVE]
set minWns              [env_double_default RACE_MIN_WNS_NS 0.05]
set minWhs              [env_double_default RACE_MIN_WHS_NS 0.02]
set routeDir            [file normalize "$raceRoot/route/$taskName"]
file mkdir $routeDir

if {![file exists $sourceDcp]} {
    write_route_status ERROR "post-place checkpoint not found: $sourceDcp"
    error "post-place checkpoint not found: $sourceDcp"
}

puts "INFO: two-stage route worker: $taskName"
puts "INFO: source=$sourceDcp candidate=$sourceCandidate"
puts "INFO: phys_opt=$physDirectiveWorker route=$routeDirectiveWorker threads=$routeThreads"

if {[catch {
    # The selected post_place checkpoint already contains the exact XDC/Pblocks
    # used during placement. Do not reload constraints here.
    open_checkpoint $sourceDcp

    phys_opt_design -directive $physDirectiveWorker
    report_timing_summary -file [file normalize "$routeDir/post_phys_opt_timing_summary.rpt"]

    use_route_threads
    route_design -directive $routeDirectiveWorker
    use_vivado_threads

    phys_opt_design -directive AggressiveExplore
    phys_opt_design -hold_fix

    set routeDcp [file normalize "$routeDir/post_route.dcp"]
    write_checkpoint -force $routeDcp
    report_timing_summary -file [file normalize "$routeDir/post_route_timing_summary.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$routeDir/post_route_failing_paths.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type min \
        -file [file normalize "$routeDir/post_route_hold_paths.rpt"]
    report_utilization -file [file normalize "$routeDir/post_route_util.rpt"]

    set setupPath [get_timing_paths -max_paths 1 -delay_type max -quiet]
    set holdPath  [get_timing_paths -max_paths 1 -delay_type min -quiet]
    set routeWns 0.0
    set routeWhs 0.0
    if {[llength $setupPath]} { set routeWns [get_property SLACK [lindex $setupPath 0]] }
    if {[llength $holdPath]}  { set routeWhs [get_property SLACK [lindex $holdPath 0]] }
    puts "INFO: post-route WNS=${routeWns}ns WHS=${routeWhs}ns"

    if {$routeWns >= 0.0 && $routeWhs >= 0.0} {
        if {$routeWns >= $minWns && $routeWhs >= $minWhs} {
            write_route_status SUCCESS "timing met with requested margin"
        } else {
            write_route_status LOW_MARGIN "timing met below requested margin"
        }
    } else {
        write_route_status TIMING_FAIL "timing not met"
    }
} err opts]} {
    write_route_status ERROR $err
    puts "ERROR: route worker failed: $err"
    return -options $opts $err
}
