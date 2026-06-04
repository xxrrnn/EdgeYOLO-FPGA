#==============================================================================
# vivado_bd_ooc.tcl — BD IP 出盒综合（OOC）通用流程
#
# SmartConnect 等嵌套 IP 在无 board 工程里不会生成 *_board.xdc；必须在
# generate_target / create_ip_run 之前创建占位 XDC，并在每次 generate 后复查，
# 否则 OOC 脚本 read_ip 后 get_files 为空 → Common 17-55。
#
#   source scripts/common/vivado_bd_ooc.tcl
#   vivado_run_bd_ip_synth $bdFile $projPath $bdDir $bdName $modRefIpTops
#==============================================================================

proc vivado_ip_synth_done {status} {
    return [expr {[string match "*Complete*" $status] \
        || [string match "*Using cached IP results*" $status]}]
}

proc vivado_ooc_xci_glob {ipRoot} {
    if {![file isdirectory $ipRoot]} {
        return {}
    }
    return [lsort -unique [concat \
        [glob -nocomplain -directory $ipRoot */*.xci] \
        [glob -nocomplain -directory $ipRoot */bd_0/ip/*/*.xci] \
        [glob -nocomplain -directory $ipRoot */ip_*/*.xci] \
        [glob -nocomplain -directory $ipRoot */ip_*/*/*.xci] \
        [glob -nocomplain -directory $ipRoot */ip_*/*/*/*.xci]]]
}

proc vivado_ooc_required_xdc_paths {xci} {
    set dir  [file dirname $xci]
    set base [file rootname [file tail $xci]]
    set paths {}
    foreach suffix {_board.xdc .xdc _ooc.xdc} {
        lappend paths [file join $dir ${base}${suffix}]
    }
    return $paths
}

# 创建缺失的占位 XDC（lite 无 board 时 Vivado 不会自动生成 *_board.xdc）
proc vivado_ensure_ooc_xdc_stubs {ipRoot} {
    set nCreated 0
    foreach xci [vivado_ooc_xci_glob $ipRoot] {
        foreach path [vivado_ooc_required_xdc_paths $xci] {
            if {![file exists $path]} {
                file mkdir [file dirname $path]
                set fh [open $path w]
                puts $fh "# Placeholder for Vivado OOC (lite: no board part)"
                close $fh
                incr nCreated
            }
        }
    }
    if {$nCreated > 0} {
        puts "INFO: vivado_ensure_ooc_xdc_stubs: created $nCreated stub XDC under $ipRoot"
    }
    return $nCreated
}

# 磁盘上必须存在全部占位 XDC；缺失则 error（不吞、不跳过）
proc vivado_assert_ooc_xdc_on_disk {ipRoot {context "OOC XDC check"}} {
    set missing {}
    foreach xci [vivado_ooc_xci_glob $ipRoot] {
        foreach path [vivado_ooc_required_xdc_paths $xci] {
            if {![file exists $path]} {
                lappend missing $path
            }
        }
    }
    if {[llength $missing]} {
        puts "ERROR: \[$context\] missing [llength $missing] XDC file(s) on disk:"
        foreach p [lrange $missing 0 19] {
            puts "ERROR:   $p"
        }
        if {[llength $missing] > 20} {
            puts "ERROR:   ... and [expr {[llength $missing] - 20}] more"
        }
        error "\[$context\] OOC XDC incomplete — run vivado_prepare_bd_ips before create_ip_run"
    }
}

# 校验已存在的 OOC launch 脚本（launch 前 tcl 可能尚未生成，此时跳过）
proc vivado_assert_ooc_run_scripts {projPath bdName runs} {
    foreach r $runs {
        set runName [get_property NAME $r]
        set ipTop   [regsub {_synth_1$} $runName {}]
        set tclPath [file normalize "$projPath/${bdName}.runs/${runName}/${ipTop}.tcl"]
        if {![file exists $tclPath]} {
            puts "INFO: OOC launch script pending for $runName (generated on launch_runs)"
            continue
        }
        set fh [open $tclPath r]
        set content [read $fh]
        close $fh
        foreach line [split $content \n] {
            foreach xdcPath [regexp -all -inline {(/[^\]\s]+\.xdc)} $line] {
                if {![file exists $xdcPath]} {
                    error "OOC script $tclPath references missing XDC on disk: $xdcPath — run vivado_refresh_ip_ooc_scripts"
                }
            }
        }
    }
}

proc vivado_ooc_xdc_missing_p {ipRoot} {
    foreach xci [vivado_ooc_xci_glob $ipRoot] {
        foreach path [vivado_ooc_required_xdc_paths $xci] {
            if {![file exists $path]} {
                return 1
            }
        }
    }
    return 0
}

proc vivado_ooc_split_pending {pending} {
    set smc {}
    set rest {}
    foreach r $pending {
        set name [get_property NAME $r]
        if {[string match *ibuf_smc* $name] || [string match *obuf_smc* $name] \
            || [string match *axi_mem_smc* $name]} {
            lappend smc $r
        } else {
            lappend rest $r
        }
    }
    return [list $smc $rest]
}

proc vivado_smc_nested_synth_missing_p {ipRoot} {
    foreach smcDir [glob -nocomplain -directory $ipRoot {lite_*smc_0}] {
        foreach xci [glob -nocomplain -directory $smcDir/bd_0/ip */*.xci] {
            set base [file rootname [file tail $xci]]
            set sv [file join [file dirname $xci] synth ${base}.sv]
            if {![file exists $sv]} {
                return 1
            }
        }
    }
    return 0
}

proc vivado_assert_no_duplicate_ip_dirs {ipRoot} {
    if {![file isdirectory $ipRoot]} {
        return
    }
    set dup {}
    foreach d [glob -nocomplain -directory $ipRoot *] {
        set name [file tail $d]
        if {[regexp {^(.+)_1$} $name -> stem] && [file isdirectory [file join $ipRoot $stem]]} {
            lappend dup $name
        }
    }
    if {[llength $dup]} {
        error "Duplicate BD IP dirs on disk ($dup). Delete $ipRoot and rerun 0_build."
    }
}

proc vivado_generate_all_bd_ip_targets {bdFile ipRoot} {
    vivado_assert_no_duplicate_ip_dirs $ipRoot
    generate_target {all} [get_files $bdFile]
    vivado_ensure_ooc_xdc_stubs $ipRoot
    if {[vivado_smc_nested_synth_missing_p $ipRoot]} {
        puts "INFO: SmartConnect nested synth RTL missing — regenerate BD IP outputs with -force"
        generate_target {all} [get_files $bdFile] -force
        vivado_ensure_ooc_xdc_stubs $ipRoot
    }
    if {[vivado_ooc_xdc_missing_p $ipRoot]} {
        puts "INFO: XDC still incomplete — regenerate BD IP outputs with -force"
        generate_target {all} [get_files $bdFile] -force
        vivado_ensure_ooc_xdc_stubs $ipRoot
    }
    vivado_assert_ooc_xdc_on_disk $ipRoot "after generate_target"
}

proc vivado_prepare_bd_ips {bdFile bdDir bdName} {
    set ipRoot [file normalize "$bdDir/$bdName/ip"]
    puts "INFO: vivado_prepare_bd_ips: $ipRoot"
    vivado_generate_all_bd_ip_targets $bdFile $ipRoot
}

# 补 stub → generate → create_ip_run → export → 校验
proc vivado_refresh_ip_ooc_scripts {bdFile ipRoot} {
    puts "INFO: vivado_refresh_ip_ooc_scripts"
    vivado_generate_all_bd_ip_targets $bdFile $ipRoot
    create_ip_run [get_files $bdFile]
    export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force
    vivado_assert_ooc_xdc_on_disk $ipRoot "after refresh"
}

proc vivado_launch_ip_synth_runs {runs ipRoot bdFile bdName projPath maxJobs} {
    if {![llength $runs]} {
        return
    }
    vivado_ensure_ooc_xdc_stubs $ipRoot
    vivado_assert_ooc_xdc_on_disk $ipRoot "pre-launch"
    puts "INFO: reset_run + launch_runs [llength $runs] OOC run(s)"
    reset_run $runs
    vivado_ensure_ooc_xdc_stubs $ipRoot
    launch_runs $runs -jobs $maxJobs
}

proc vivado_run_ip_synth_batch {runs ipRoot bdFile bdName projPath {maxJobs 8}} {
    if {![llength $runs]} {
        puts "WARNING: No IP synth runs in project"
        return
    }
    set pending {}
    foreach r $runs {
        set name [get_property NAME $r]
        set st   [get_property STATUS $r]
        if {[vivado_ip_synth_done $st]} {
            puts "INFO: Reuse OOC cache: $name ($st)"
        } else {
            lappend pending $r
            puts "INFO: OOC pending: $name ($st)"
        }
    }
    if {![llength $pending]} {
        return
    }

    lassign [vivado_ooc_split_pending $pending] smcRuns restRuns
    set phases {}
    if {[llength $smcRuns]} { lappend phases $smcRuns }
    if {[llength $restRuns]} { lappend phases $restRuns }

    set phaseIdx 0
    foreach phase $phases {
        incr phaseIdx
        puts "INFO: OOC phase $phaseIdx/[llength $phases]: [llength $phase] run(s)"
        set jobs $maxJobs
        if {$phaseIdx == 1 && [llength $phase] <= 3} {
            set jobs 3
        }
        vivado_launch_ip_synth_runs $phase $ipRoot $bdFile $bdName $projPath $jobs
        foreach r $phase {
            set name [get_property NAME $r]
            wait_on_run $r
            set st [get_property STATUS [get_runs $name]]
            if {![vivado_ip_synth_done $st]} {
                set logPath [file normalize "$projPath/${bdName}.runs/${name}/runme.log"]
                error "IP OOC synthesis failed: $name ($st). See $logPath"
            }
            puts "INFO: $name finished ($st)"
        }
    }
}

proc vivado_ensure_modref_artifacts {bdDir bdName projPath modRefTops} {
    foreach ipTop $modRefTops {
        set ipDir  [file normalize "$bdDir/$bdName/ip/$ipTop"]
        set stub   [file join $ipDir ${ipTop}_stub.v]
        set dcpIp  [file join $ipDir ${ipTop}.dcp]
        set dcpRun [file normalize "$projPath/${bdName}.runs/${ipTop}_synth_1/${ipTop}.dcp"]
        if {[file exists $stub]} { continue }
        if {![file exists $dcpIp] && [file exists $dcpRun]} {
            file mkdir $ipDir
            file copy -force $dcpRun $dcpIp
            puts "INFO: Copied OOC DCP $ipTop"
        }
        if {![file exists $stub] && ![file exists $dcpIp] && ![file exists $dcpRun]} {
            error "Missing module-ref OOC artifact for $ipTop. See ${ipTop}_synth_1 log."
        }
    }
}

proc vivado_run_bd_ip_synth {bdFile projPath bdDir bdName modRefTops {runGlob "*_synth_1"}} {
    set ipRoot [file normalize "$bdDir/$bdName/ip"]
    vivado_prepare_bd_ips $bdFile $bdDir $bdName
    vivado_refresh_ip_ooc_scripts $bdFile $ipRoot
    set allRuns [get_runs -quiet $runGlob]
    vivado_run_ip_synth_batch $allRuns $ipRoot $bdFile $bdName $projPath \
        [get_param general.maxThreads]
    export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force
    vivado_ensure_modref_artifacts $bdDir $bdName $projPath $modRefTops
}
