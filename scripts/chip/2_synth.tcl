set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
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

generate_target all [get_files $bdFile]
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force -quiet

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

foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

update_compile_order -fileset sources_1

# impl 策略属性（XDC 中禁止使用 get_runs；此处设置后再跑 opt/place/route）
if {[llength [get_runs -quiet impl_1]]} {
    set_property STRATEGY Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
    set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE ExploreWithRemap [get_runs impl_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraNetDelay_high [get_runs impl_1]
    set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
    set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
}

# 限制DSP使用：让部分乘法器用LUT实现以避免DSP超标
# xcvu37p有9024个DSP，设计需要16384个（182%），设置max_dsp为8800（留少量余量）
synth_design -top $topName -part $part -directive $synDirective \
    -max_dsp 8800 -resource_sharing auto
write_checkpoint -force [file normalize "$SynOutputDir/post_synth.dcp"]
report_timing_summary -file [file normalize "$SynOutputDir/post_synth_timing_summary.rpt"]
report_utilization -file [file normalize "$SynOutputDir/post_synth_util.rpt"]

# 综合后补充诊断报告（输出目录 = projPath，即 build/$projName，勿写死绝对路径）
set chipDiagDir [file normalize $projPath]
file mkdir $chipDiagDir

report_timing -max_paths 50 -slack_lesser_than 0 -delay_type max -sort_by slack \
    -file [file normalize "$chipDiagDir/worst_setup_paths.rpt"]
report_timing_summary -max_paths 10 -report_unconstrained \
    -file [file normalize "$chipDiagDir/timing_summary_detail.rpt"]
report_design_analysis -logic_level_distribution -timing \
    -file [file normalize "$chipDiagDir/logic_level_dist.rpt"]
report_clock_utilization \
    -file [file normalize "$chipDiagDir/clock_util.rpt"]
report_design_analysis -congestion \
    -file [file normalize "$chipDiagDir/congestion.rpt"]

# 面积/资源报告：分层汇总 LUT/FF/BRAM/URAM/DSP/CARRY 等（综合后网表）
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file normalize "$chipDiagDir/area_report_hierarchical.rpt"]

set launchDir [pwd]
cd $ImplOutputDir

opt_design -directive $optDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_opt.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_opt_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_opt_util.rpt"]

place_design -directive $placeDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_place_util.rpt"]

phys_opt_design -directive $physOptDirectiveAp
write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_ap.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_ap_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_phys_opt_ap_util.rpt"]

route_design -directive $routeDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file normalize "$ImplOutputDir/post_route_area_hierarchical.rpt"]

phys_opt_design -directive $physOptDirectiveAr
write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_ar.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_ar_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_phys_opt_ar_util.rpt"]

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]

cd $launchDir
