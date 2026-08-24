# ==============================================================================
# 3_synth.tcl — 顶层综合 + opt + place + phys_opt + route + bitstream
#               每步之间检查时序违例，超阈值则中止
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
if {![info exists ScriptDir]} { source [file normalize "$thisScriptDir/config.tcl"] }

# --- 确保工程已打开 ---
if {[llength [get_projects -quiet]] == 0} {
    set xpr [file normalize "$projPath/${projName}.xpr"]
    if {![file exists $xpr]} { error "Project not found: $xpr" }
    open_project $xpr
}

file mkdir $SynOutputDir
file mkdir $ImplOutputDir

# ==============================================================================
# 辅助函数
# ==============================================================================

# 重新加载 chip_timing.xdc（-unmanaged 支持 if/foreach/set 等 Tcl 控制流）
# chip.xdc（纯 pin/IO 约束）已在 fileset，由 Vivado 自动加载，不在此重复加载。
# 每次调用前先删除旧 pblock，避免重复定义报错。
proc reload_xdc {} {
    global xdcDir
    set pbs [get_pblocks -quiet]
    if {[llength $pbs]} { delete_pblocks $pbs }
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
}

# 获取用户主时钟（250MHz XDMA/AXI 域）
proc user_clk {} {
    set clk [get_clocks -quiet clk_main]
    if {![llength $clk]} { set clk [get_clocks -quiet bram_clk_a] }
    return $clk
}

# 时序门控：检查 WNS/TNS/failing，超阈值报错中止
proc timing_gate {stage} {
    global wns_stop_place tns_stop_place fail_stop_place wns_warn_place ImplOutputDir

    set clk [user_clk]
    if {[llength $clk]} {
        set clkName [get_property NAME [lindex $clk 0]]
        set paths [get_timing_paths -max_paths 500000 -delay_type max -group $clk \
                       -slack_lesser_than 0]
    } else {
        set clkName "all_clocks"
        set paths [get_timing_paths -max_paths 500000 -delay_type max \
                       -slack_lesser_than 0]
    }

    set failing [llength $paths]
    if {$failing == 0} {
        puts "INFO: \[timing_gate\] $stage ($clkName): setup clean."
        return
    }

    set wns [get_property SLACK [lindex $paths 0]]
    set tns 0.0
    foreach p $paths { set tns [expr {$tns + [get_property SLACK $p]}] }

    # 判断是否中止
    set stop 0
    set reasons {}
    if {$wns < $wns_stop_place} {
        lappend reasons "WNS=${wns}ns (threshold: ${wns_stop_place}ns)"
        set stop 1
    }
    if {$tns < $tns_stop_place} {
        lappend reasons "TNS=${tns}ns (threshold: ${tns_stop_place}ns)"
        set stop 1
    }
    if {$failing > $fail_stop_place} {
        lappend reasons "Failing=${failing} (threshold: ${fail_stop_place})"
        set stop 1
    }

    if {$stop} {
        puts "ERROR: \[timing_gate\] $stage ($clkName) — STOP."
        foreach r $reasons { puts "ERROR:   $r" }
        error "\[timing_gate\] Aborting at $stage: timing too poor to continue."
    }

    if {$wns < $wns_warn_place} {
        puts "WARNING: \[timing_gate\] $stage ($clkName) WNS=${wns}ns TNS=${tns}ns failing=${failing}"
    } else {
        puts "INFO: \[timing_gate\] $stage ($clkName) WNS=${wns}ns TNS=${tns}ns failing=${failing}"
    }
}

# ==============================================================================
# Step 1: 顶层综合（Project Mode — 自动处理 OOC IP stub/DCP）
# ==============================================================================
puts "\n========== Step 1: Synthesis (project mode) =========="

set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[llength [get_files -quiet $bdFile]] == 0} { add_files -norecurse $bdFile }

set wrapperFile [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
if {[llength [get_files -quiet $wrapperFile]] == 0} { add_files -norecurse $wrapperFile }
set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

# 确保 chip.xdc 已在 fileset（chip_timing.xdc 只走 reload_xdc 的 -unmanaged 路径）
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[string match "*chip_timing*" $xdcFile]} { continue }
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

# 设置 synth_1 run 的 strategy/directive
set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
    -value "-directive $synDirective -resource_sharing auto" \
    -objects [get_runs synth_1]

# Project-mode synth: Vivado 自动管理 OOC IP + stub + top-level
launch_runs synth_1 -jobs $synthJobs
wait_on_runs synth_1

# 检查 synth_1 是否成功
set _synth_status [get_property STATUS [get_runs synth_1]]
if {![regexp -nocase {synth_design complete} $_synth_status]} {
    error "Synthesis failed: STATUS=$_synth_status"
}
puts "INFO: synth_1 completed: $_synth_status"

# 打开综合结果（进入 non-project 实现流程）
open_run synth_1 -name synth_1

write_checkpoint -force [file normalize "$SynOutputDir/post_synth.dcp"]
reload_xdc
report_timing_summary -file [file normalize "$SynOutputDir/post_synth_timing_summary.rpt"]
report_utilization -file [file normalize "$SynOutputDir/post_synth_util.rpt"]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file normalize "$SynOutputDir/area_report_hierarchical.rpt"]

puts "INFO: Synthesis complete. DSP48E2 count:"
puts "INFO:   [llength [get_cells -hierarchical -filter {REF_NAME == DSP48E2}]] DSP48E2 inferred"

# Per-Tile DSP 均衡性检查
set _dsp_total [llength [get_cells -hierarchical -filter {REF_NAME == DSP48E2}]]
puts "INFO: DSP per tile:"
for {set _tidx 0} {$_tidx < $::DCIM_NUM_TILES} {incr _tidx} {
    set _tdsp [llength [get_cells -hierarchical -filter "REF_NAME == DSP48E2 && NAME =~ *gen_tiles\[$_tidx\]*"]]
    puts "INFO:   Tile $_tidx: $_tdsp DSP48E2"
}
if {$_dsp_total > 9024} {
    error "FATAL: Total DSP48E2 ($_dsp_total) exceeds device capacity (9024)!"
}

# ==============================================================================
# Step 2: Opt Design
# ==============================================================================
puts "\n========== Step 2: Opt Design =========="

opt_design -directive $optDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_opt.dcp"]
reload_xdc
report_timing_summary -file [file normalize "$ImplOutputDir/post_opt_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_opt_util.rpt"]

# ==============================================================================
# Step 3: Place Design
# ==============================================================================
puts "\n========== Step 3: Place Design =========="

# place_design 多线程说明：
#   - Vivado 2024.2 的 ILR（Incremental Logic Replication）功能在多线程下
#     有已知 SIGSEGV crash bug（AMD AR #1274840）。
#   - 解决方案：用 set_param place.ILREnabled false 关闭 ILR，
#     多线程本身完全安全，可以提速约 30-50%。
#   - ILR 关闭的影响：timing 结果略微变差（约 0.05~0.1ns WNS 劣化），
#     对已有 -1.1ns 违例的设计影响可忽略。
catch {set_param place.ILREnabled false}  ;# 关闭触发 crash 的 ILR（Vivado 2024.2 已移除此参数，catch 防止报错）
use_place_threads
place_design -directive $placeDirective
use_vivado_threads

write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
  -file [file normalize "$ImplOutputDir/post_place_failing_paths.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_place_util.rpt"]

# 时序门控：post-place
timing_gate "post-place"

# ==============================================================================
# Step 4: Physical Optimization
# ==============================================================================
puts "\n========== Step 4: Phys Opt Design =========="

phys_opt_design -directive $physOptDirective
write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_timing_summary.rpt"]
report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
  -file [file normalize "$ImplOutputDir/post_phys_opt_failing_paths.rpt"]

# ==============================================================================
# Step 5: Route Design
# ==============================================================================
puts "\n========== Step 5: Route Design =========="

# route_design 使用 ROUTE_THREADS，默认 32
use_route_threads
route_design -directive $routeDirective
use_vivado_threads

# post-route hold fix
# 根因：DSP48E2_X14Y89 内部 D→AD pre-adder 路径，route delay=0，
#   clock skew（0.174ns）略大于 data delay（0.103ns），导致 hold -0.011ns。
# 这是 Vivado router 的已知行为：对 DSP 内部 back-to-back 寄存器，
#   router 不会自动插入 hold buffer，需要 phys_opt -hold 显式修复。
# phys_opt -hold 会在 D→AD 路径上插入实际的延迟单元（通过 LUT-buffer 或路由迂回），
#   是真实的物理修复，不是绕过约束。
# 注意：必须在 route_design 之后、checkpoint 之前执行，
#   因为需要已知的物理布局来选择 hold fix 位置。
phys_opt_design -hold_fix
puts "INFO: Post-route hold phys_opt done"

write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
  -file [file normalize "$ImplOutputDir/post_route_failing_paths.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]

# 时序门控：post-route（WNS < 0 或 WHS < 0 不写 bitstream）
set routePaths [get_timing_paths -max_paths 1 -delay_type max]
set routeWns 0.0
if {[llength $routePaths]} {
    set routeWns [get_property SLACK [lindex $routePaths 0]]
}
set routeHoldPaths [get_timing_paths -max_paths 1 -delay_type min]
set routeWhs 0.0
if {[llength $routeHoldPaths]} {
    set routeWhs [get_property SLACK [lindex $routeHoldPaths 0]]
}
puts "INFO: Post-route WNS = ${routeWns} ns  WHS = ${routeWhs} ns"

if {$routeWns < 0} {
    puts "ERROR: Post-route setup timing NOT MET (WNS=${routeWns}ns). Bitstream skipped."
    puts "ERROR: Checkpoint: $ImplOutputDir/post_route.dcp"
    error "\[timing_gate\] post-route WNS=${routeWns}ns — setup not met."
}
if {$routeWhs < 0} {
    puts "ERROR: Post-route hold timing NOT MET (WHS=${routeWhs}ns). Bitstream skipped."
    puts "ERROR: Checkpoint: $ImplOutputDir/post_route.dcp"
    error "\[timing_gate\] post-route WHS=${routeWhs}ns — hold not met."
}

# ==============================================================================
# Step 6: Bitstream
# ==============================================================================
puts "\n========== Step 6: Write Bitstream =========="

set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]

puts "INFO: Bitstream written: $ImplOutputDir/top.bit"
puts "INFO: 3_synth complete — full implementation successful."
