set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists xdma_dcim_hbmScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

if {[llength [get_projects -quiet]] == 0} {
    error "Please open the Vivado project before sourcing 2_synth_sweep.tcl."
}

file mkdir $SynOutputDir
set sweepDir [file normalize "$SynOutputDir/sweep_synth"]
file mkdir $sweepDir

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
set wrapperFile [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]

if {![file exists $bdFile]} {
    error "BD file does not exist: $bdFile. Please source 1_bd.tcl before 2_synth_sweep.tcl."
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

# Generate BD/IP products and OOC checkpoints to avoid missing DCP failures in top synth.
generate_target all [get_files $bdFile]
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force -quiet

catch {create_ip_run [get_files -of_objects [get_fileset sources_1] $bdFile]}
set ipSynthRuns [get_runs -quiet ${bdName}_*_synth_1]
if {[llength $ipSynthRuns] > 0} {
    reset_run $ipSynthRuns
    set jobs [expr {[info exists ipSynthJobs] ? $ipSynthJobs : [get_param general.maxThreads]}]
    launch_runs $ipSynthRuns -jobs $jobs
    foreach ipRun $ipSynthRuns {
        wait_on_run $ipRun
        set runStatus [get_property STATUS [get_runs $ipRun]]
        if {![string match "*Complete*" $runStatus] && ![string match "*Using cached IP results*" $runStatus]} {
            error "IP synthesis run $ipRun failed: $runStatus"
        }
    }
}

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/$bdName/*.xdc"]] {
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}
update_compile_order -fileset sources_1

# If caller does not provide synthSweepDirectives, query the run property to get
# all directives supported by current Vivado version.
if {![info exists synthSweepDirectives] || [llength $synthSweepDirectives] == 0} {
    set run [get_runs -quiet synth_1]
    if {[llength $run] > 0} {
        set synthSweepDirectives [list_property_value STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE $run]
    } else {
        set synthSweepDirectives [list Default]
    }
}

proc sanitize_name {name} {
    regsub -all {[^A-Za-z0-9_]+} $name "_" out
    return $out
}

set summaryCsv [file normalize "$sweepDir/sweep_summary.csv"]
set fid [open $summaryCsv w]
puts $fid "directive,status,setup_wns,hold_whs,elapsed_sec,dcp"

set idx 0
foreach directive $synthSweepDirectives {
    incr idx
    puts "\n=== Sweep synth $idx/[llength $synthSweepDirectives]: $directive ==="

    catch {close_design}

    set startSec [clock seconds]
    set status "OK"
    set safeName [sanitize_name $directive]
    set dcpPath [file normalize "$sweepDir/post_synth_${safeName}.dcp"]
    set timingRpt [file normalize "$sweepDir/post_synth_${safeName}_timing_summary.rpt"]
    set utilRpt [file normalize "$sweepDir/post_synth_${safeName}_util.rpt"]

    if {[catch {synth_design -top $topName -part $part -directive $directive} synthErr]} {
        set status "FAIL:[string map {, ; \n { }} $synthErr]"
        set elapsed [expr {[clock seconds] - $startSec}]
        puts $fid [format "%s,%s,NA,NA,%d,%s" $directive $status $elapsed ""]
        puts "Directive $directive failed: $synthErr"
        continue
    }

    write_checkpoint -force $dcpPath
    report_timing_summary -file $timingRpt
    report_utilization -file $utilRpt

    set setupWns "NA"
    set holdWhs "NA"

    set setupPaths [get_timing_paths -quiet -max_paths 1 -setup]
    if {[llength $setupPaths] > 0} {
        catch {set setupWns [get_property SLACK [lindex $setupPaths 0]]}
    }

    set holdPaths [get_timing_paths -quiet -max_paths 1 -hold]
    if {[llength $holdPaths] > 0} {
        catch {set holdWhs [get_property SLACK [lindex $holdPaths 0]]}
    }

    set elapsed [expr {[clock seconds] - $startSec}]
    puts $fid [format "%s,%s,%s,%s,%d,%s" $directive $status $setupWns $holdWhs $elapsed $dcpPath]
}

close $fid
puts "\nSweep completed. Summary CSV: $summaryCsv"
