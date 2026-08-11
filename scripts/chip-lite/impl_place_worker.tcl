# ==============================================================================
# impl_place_worker.tcl — one place-only candidate from a shared post_opt DCP
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

proc env_required {name} {
    if {![info exists ::env($name)] || [string trim $::env($name)] eq ""} {
        error "required environment variable $name is not set"
    }
    return [string trim $::env($name)]
}

proc write_place_status {status detail} {
    global candidateDir candidateName placeDirectiveWorker ppWns
    file mkdir $candidateDir
    set fp [open [file normalize "$candidateDir/status.txt"] w]
    puts $fp "STATUS\t$status"
    puts $fp "DETAIL\t$detail"
    puts $fp "CANDIDATE\t$candidateName"
    puts $fp "PLACE\t$placeDirectiveWorker"
    if {[info exists ppWns]} { puts $fp "POST_PLACE_WNS\t$ppWns" }
    puts $fp "TIME\t[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    close $fp
}

set sourceDcp            [file normalize [env_required SOURCE_DCP]]
set raceRoot             [file normalize [env_required RACE_ROOT]]
set candidateName        [env_required IMPL_CANDIDATE]
set placeDirectiveWorker [env_required PLACE_DIRECTIVE]
set candidateDir         [file normalize "$raceRoot/place/$candidateName"]
file mkdir $candidateDir

if {![file exists $sourceDcp]} {
    write_place_status ERROR "source checkpoint not found: $sourceDcp"
    error "source checkpoint not found: $sourceDcp"
}

puts "INFO: two-stage place worker: $candidateName"
puts "INFO: source=$sourceDcp directive=$placeDirectiveWorker threads=$placeThreads"

if {[catch {
    open_checkpoint $sourceDcp
    if {$raceReloadXdc} {
        puts "INFO: RACE_RELOAD_XDC=1 — replacing embedded Pblocks with current chip_timing.xdc"
        set pbs [get_pblocks -quiet]
        if {[llength $pbs]} { delete_pblocks $pbs }
        read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
    } else {
        puts "INFO: using timing constraints and Pblocks embedded in post_opt.dcp"
    }

    catch {set_param place.ILREnabled false}
    use_place_threads
    place_design -directive $placeDirectiveWorker
    use_vivado_threads

    set placeDcp [file normalize "$candidateDir/post_place.dcp"]
    write_checkpoint -force $placeDcp
    report_timing_summary -file [file normalize "$candidateDir/post_place_timing_summary.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$candidateDir/post_place_failing_paths.rpt"]
    report_utilization -file [file normalize "$candidateDir/post_place_util.rpt"]
    report_design_analysis -congestion \
        -file [file normalize "$candidateDir/post_place_congestion.rpt"]

    set ppPath [get_timing_paths -max_paths 1 -delay_type max -quiet]
    set ppWns 0.0
    if {[llength $ppPath]} { set ppWns [get_property SLACK [lindex $ppPath 0]] }
    puts "INFO: post-place WNS=${ppWns}ns"

    if {$ppWns < $wns_stop_place} {
        write_place_status SKIP "post-place WNS ${ppWns} < threshold ${wns_stop_place}"
    } else {
        write_place_status SUCCESS "place completed"
    }
} err opts]} {
    write_place_status ERROR $err
    puts "ERROR: place worker failed: $err"
    return -options $opts $err
}
