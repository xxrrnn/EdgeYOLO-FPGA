# ==============================================================================
# 3_synth_nonproj.tcl — Non-Project Mode 实现全流程
# ==============================================================================
# Non-Project Mode 特点：
#   - 不依赖 Vivado .xpr 工程文件，直接操作 in-memory design
#   - 使用 read_verilog / read_xdc / synth_design 命令直接驱动
#   - 每一步手动调用 Tcl 命令，完全可控
#   - 适合 CI/CD、服务器批量跑、精细调参
#   - 没有 Vivado GUI 工程结构开销，启动更快
#   - 缺点：不能用 IP Catalog GUI，需要预先准备 IP 的 DCP/stub
#
# 前提条件：
#   - 2_bd.tcl 已在 project mode 下执行完成（生成了 BD wrapper + OOC IP DCP）
#   - ip_stubs/ 目录存在（2_bd.tcl 最后一步会持久化）
#   - 所有 OOC IP 的 DCP 已在 lite.runs/ 下
#
# 每阶段生成报告：
#   post_synth  → timing_summary + utilization + DSP check
#   post_opt    → timing_summary + utilization
#   post_place  → timing_summary + failing_paths + utilization + timing_gate
#   post_phys   → timing_summary + failing_paths
#   post_route  → timing_summary + failing_paths + utilization + DRC
#
# 用法：
#   FLOW_MODE=nonproj vivado -mode batch -source scripts/chip-lite/run.tcl
# ==============================================================================

set thisScriptDir [file dirname [file normalize [info script]]]
if {![info exists ScriptDir]} { source [file normalize "$thisScriptDir/config.tcl"] }

file mkdir $SynOutputDir
file mkdir $ImplOutputDir

# ==============================================================================
# 辅助函数
# ==============================================================================

# reload_xdc：加载含 Tcl 控制流的 chip_timing.xdc
# -unmanaged 表示 Vivado 按普通 Tcl 执行（支持 if/foreach/set 等语句）
# 每次调用前清除已有 pblock，避免重复定义报错
proc reload_xdc {} {
    global xdcDir
    set pbs [get_pblocks -quiet]
    if {[llength $pbs]} { delete_pblocks $pbs }
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
}

# user_clk：获取用户主时钟对象（250MHz AXI 域）
# non-project mode 下时钟名由 XDC 约束决定
proc user_clk {} {
    set clk [get_clocks -quiet clk_main]
    if {![llength $clk]} { set clk [get_clocks -quiet bram_clk_a] }
    return $clk
}

# timing_gate：时序门控
# 检查当前设计的 WNS/TNS/failing path 数量，超阈值中止构建
# 目的：在 place 之后尽早发现时序问题，避免浪费 route 的长时间
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
# Step 0: 关闭任何已打开的工程/设计（Non-project mode 不需要 .xpr）
# ==============================================================================
# non-project mode 在 in-memory 中操作，不需要打开 Vivado project。
# 如果之前有打开的 project，先关闭，避免干扰。
puts "\n========== Non-Project Mode: Initializing =========="
catch {close_project -quiet}
catch {close_design -quiet}

# ==============================================================================
# Step 1: 综合 (synth_design)
# ==============================================================================
# Non-project mode 综合流程：
#   1. read_verilog/read_vhdl 加载所有 RTL 源文件
#   2. read_ip / read_checkpoint 加载预综合好的 IP DCP
#   3. read_xdc 加载约束
#   4. synth_design -top <顶层模块> 执行综合
#
# 与 project mode 的区别：
#   - 没有 launch_runs / wait_on_runs，直接同步调用 synth_design
#   - 需要手动指定所有 include_dirs 和 define
#   - IP 必须预先综合为 DCP（2_bd.tcl 已完成）
# ==============================================================================
puts "\n========== Step 1: Synthesis (non-project mode) =========="

# --- 1a. 读入 OOC IP 的 DCP ---
# 每个 IP 在 project mode 的 OOC 综合后会生成 .dcp 文件
# non-project mode 通过 read_checkpoint -cell 将其作为黑盒 netlist 引入
set ipRunsDir [file normalize "$projPath/${bdName}.runs"]
set stubDir   [file normalize "$projPath/ip_stubs"]

# 收集所有 OOC IP 的 DCP（由 2_bd.tcl 的 OOC synth 生成）
set oocDcpList {}
foreach ipTop $modRefIpTops {
    set dcp [file normalize "$ipRunsDir/${ipTop}_synth_1/${ipTop}.dcp"]
    if {[file exists $dcp]} {
        lappend oocDcpList $dcp
    } else {
        puts "WARNING: OOC DCP not found for $ipTop: $dcp"
    }
}

# --- 1b. 读入 RTL 源文件 ---
# 定义 include 搜索路径和宏（与 2_bd.tcl 保持一致）
set inclDirs [list \
    [file normalize "$srcDir/chip"] \
    [file normalize "$srcDir/common"] \
    [file normalize "$srcDir/ref/DCIM/src/inc"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim"] \
    [file normalize "$srcDir/ref/DCIM/src/model"] \
    $vpuRtlDir \
    [file normalize "$vpuRtlDir/fp_array"] \
]

set vlogDefines [list \
    FPGA=1 \
    MODE_INT4=3'b100  MODE_INT8=3'b110  MODE_INT16=3'b111 \
    MODE_UINT4=3'b000 MODE_UINT8=3'b010 MODE_UINT16=3'b011 \
]

# BD wrapper（由 make_wrapper 生成的顶层文件）
set wrapperFile [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]

# 读入 BD 生成的 HDL（wrapper + BD netlist verilog）
# read_verilog -sv 用于 .sv 文件；-library 指定逻辑库
set bdHdlDir [file normalize "$bdDir/$bdName/hdl"]
foreach vf [glob -nocomplain "$bdHdlDir/*.v"] {
    read_verilog $vf
}

# 读入 IP stubs（黑盒声明，告诉综合器各 IP 的端口签名）
foreach stubFile [glob -nocomplain "$stubDir/*_stub.v"] {
    read_verilog $stubFile
}

# 读入设计 RTL 源文件
# chip 顶层
set chipRtlFiles [list \
    [file normalize "$srcDir/common/uram_tdp_bytewrite.v"] \
    [file normalize "$srcDir/chip/DCIM_Array.sv"] \
    [file normalize "$srcDir/chip/DCIM_Array_bd.v"] \
    [file normalize "$srcDir/chip/DCIM_Tile.sv"] \
    [file normalize "$srcDir/chip/tile_ibuf.v"] \
    [file normalize "$srcDir/chip/tile_obuf.v"] \
]

# DCIM 计算核心
set dcimRtlFiles [list \
    [file normalize "$srcDir/ref/DCIM/src/inc/para.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/counter.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/dff.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/pipe_stage.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/multiplier.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/multiplier_dsp.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/adderTree.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/maArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/calculate_core.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/mergeArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/accumulateArray.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/postProcess.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/ppCache.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/sramWrap.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/memory.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/dcim.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/act_nibble_converter.sv"] \
    [file normalize "$srcDir/ref/DCIM/src/model/model_rf.sv"] \
    [file normalize "$srcDir/ref/DCIM/src/model/model_rf_bram.sv"] \
]

# Buffer (shared ibuf removed; per-tile ibuf is in chipRtlFiles)
set bufferRtlFiles [list \
]

# VPU（自动收集，排除 testbench 和备份文件）
set vpuRtlFiles {}
foreach pattern {*.v *.sv} {
    foreach f [glob -nocomplain [file normalize "$vpuRtlDir/$pattern"]] {
        if {![regexp {(tb_.*|.*_v2|.*\.bak)\.(v|sv)$} [file tail $f]]} {
            lappend vpuRtlFiles $f
        }
    }
}
foreach f [glob -nocomplain [file normalize "$vpuRtlDir/fp_array/*.v"] \
                            [file normalize "$vpuRtlDir/fp_array/*.sv"]] {
    lappend vpuRtlFiles $f
}

# 分类读入（.sv 需要 -sv 标志）
set allRtl [concat $chipRtlFiles $dcimRtlFiles $bufferRtlFiles $vpuRtlFiles]
set vFiles  {}
set svFiles {}
foreach f $allRtl {
    if {[string match "*.sv" $f]} {
        lappend svFiles $f
    } else {
        lappend vFiles $f
    }
}

# read_verilog: -include_dirs 指定 `include 搜索路径
#               -define 传入宏定义（等价于 project mode 的 verilog_define）
if {[llength $vFiles]} {
    read_verilog -include_dirs $inclDirs -define $vlogDefines $vFiles
}
if {[llength $svFiles]} {
    read_verilog -sv -include_dirs $inclDirs -define $vlogDefines $svFiles
}

# --- 1c. 读入约束 ---
# chip.xdc: 纯 pin/IO 约束（无 Tcl 控制流），synth_design 可解析
read_xdc [file normalize "$xdcDir/chip/chip.xdc"]

# --- 1d. 读入预综合的 IP DCP ---
# 在 non-project mode 下，通过 read_checkpoint -cell 把 OOC 结果嵌入设计
# 但在综合阶段，IP 以 stub 形式存在即可；DCP 在 opt_design 前 link
# 这里使用 link_design 方式：先 synth 顶层（IP 为黑盒），再 link 时引入 DCP

# --- 1e. 执行综合 ---
# synth_design 参数说明：
#   -top: 顶层模块名
#   -part: 目标器件
#   -directive: 综合策略（Default/Flow*等）
#   -include_dirs: `include 搜索路径（synth_design 级别再次指定，确保一致）
#   -verilog_define: 预定义宏
# flatten_hierarchy rebuilt: 默认行为，综合后重建层次以利于优化
synth_design \
    -top $topName \
    -part $part \
    -directive $synDirective \
    -include_dirs $inclDirs \
    -verilog_define $vlogDefines

# --- 1f. post-synth 报告 ---
write_checkpoint -force [file normalize "$SynOutputDir/post_synth.dcp"]

# 加载 timing XDC（synth 后设计已在内存，可以施加时序约束并报告）
reload_xdc

report_timing_summary -file [file normalize "$SynOutputDir/post_synth_timing_summary.rpt"]
report_utilization -file [file normalize "$SynOutputDir/post_synth_util.rpt"]
report_utilization -hierarchical -hierarchical_depth 5 \
    -file [file normalize "$SynOutputDir/area_report_hierarchical.rpt"]

# DSP 用量检查
set _dsp_total [llength [get_cells -hierarchical -filter {REF_NAME == DSP48E2}]]
puts "INFO: Synthesis complete. DSP48E2 total: $_dsp_total"
puts "INFO: DSP per tile:"
foreach _tidx {0 1 2 3} {
    set _tdsp [llength [get_cells -hierarchical -filter "REF_NAME == DSP48E2 && NAME =~ *gen_tiles\[$_tidx\]*"]]
    puts "INFO:   Tile $_tidx: $_tdsp DSP48E2"
}
if {$_dsp_total > 9024} {
    error "FATAL: Total DSP48E2 ($_dsp_total) exceeds device capacity (9024)!"
}

# ==============================================================================
# Step 2: Opt Design (逻辑优化)
# ==============================================================================
# opt_design 在综合网表上做逻辑级优化：
#   - 常量传播、死逻辑删除
#   - BRAM/DSP 推断优化
#   - Retiming (directive 包含 Remap 时)
#   - 门级重组
# 这一步不涉及物理信息，纯逻辑变换。
# ==============================================================================
puts "\n========== Step 2: Opt Design =========="

opt_design -directive $optDirective

write_checkpoint -force [file normalize "$ImplOutputDir/post_opt.dcp"]
reload_xdc
report_timing_summary -file [file normalize "$ImplOutputDir/post_opt_timing_summary.rpt"]
report_utilization -file [file normalize "$ImplOutputDir/post_opt_util.rpt"]

if {[info exists stopAfter] && $stopAfter eq "opt"} {
    puts "INFO: STOP_AFTER=opt — stopping after post_opt.dcp."
    return
}

# ==============================================================================
# Step 3~6: Place → Phys Opt → Route → Bitstream (with Retry)
# ==============================================================================
# 从 post_opt.dcp 出发，尝试最多 3 组策略。
# 如果某组策略 post-route WNS >= 0，立即写 bitstream 并结束。
# 如果全部失败，报告最佳结果并 error。
# ==============================================================================
puts "\n========== Step 3-6: Implementation with Retry =========="

set optDcp [file normalize "$ImplOutputDir/post_opt.dcp"]
set bestWns -999.0
set bestStrategy ""
set timingMet 0

for {set _retry_idx 0} {$_retry_idx < [llength $retryStrategies]} {incr _retry_idx} {
    set _strat [lindex $retryStrategies $_retry_idx]
    set _placeDir  [lindex $_strat 0]
    set _physDir   [lindex $_strat 1]
    set _routeDir  [lindex $_strat 2]

    set _attempt [expr {$_retry_idx + 1}]
    set _totalAttempts [llength $retryStrategies]
    puts "\n================================================================"
    puts "  ATTEMPT $_attempt/$_totalAttempts: place=$_placeDir  phys_opt=$_physDir  route=$_routeDir"
    puts "================================================================"

    # 每次 retry 从 post_opt.dcp 干净重新开始
    if {$_retry_idx > 0} {
        close_design -quiet
        open_checkpoint $optDcp
        set pbs [get_pblocks -quiet]
        if {[llength $pbs]} { delete_pblocks $pbs }
        read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
    }

    # --- Place ---
    puts "\n---------- Place Design (attempt $_attempt) ----------"
    catch {set_param place.ILREnabled false}
    use_place_threads
    place_design -directive $_placeDir
    use_vivado_threads

    set _placeDcp [file normalize "$ImplOutputDir/post_place_attempt${_attempt}.dcp"]
    write_checkpoint -force $_placeDcp
    report_timing_summary -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_timing.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_failing.rpt"]
    report_utilization -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_util.rpt"]
    report_design_analysis -congestion \
        -file [file normalize "$ImplOutputDir/post_place_attempt${_attempt}_congestion.rpt"]

    # post-place 门控：太差则跳过此策略
    set _pp [get_timing_paths -max_paths 1 -delay_type max]
    set _ppWns 0.0
    if {[llength $_pp]} { set _ppWns [get_property SLACK [lindex $_pp 0]] }
    puts "INFO: Post-place WNS (attempt $_attempt) = ${_ppWns} ns"
    if {$_ppWns < $wns_stop_place} {
        puts "WARNING: Post-place WNS ${_ppWns} < threshold ${wns_stop_place} — skipping this strategy."
        continue
    }

    # --- Phys Opt ---
    puts "\n---------- Phys Opt Design (attempt $_attempt) ----------"
    phys_opt_design -directive $_physDir

    write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_attempt${_attempt}.dcp"]
    report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_attempt${_attempt}_timing.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$ImplOutputDir/post_phys_opt_attempt${_attempt}_failing.rpt"]

    # --- Route ---
    puts "\n---------- Route Design (attempt $_attempt) ----------"
    use_route_threads
    route_design -directive $_routeDir

    phys_opt_design -hold_fix
    puts "INFO: Post-route hold phys_opt done (attempt $_attempt)"

    set _routeDcp [file normalize "$ImplOutputDir/post_route_attempt${_attempt}.dcp"]
    write_checkpoint -force $_routeDcp
    report_timing_summary -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_timing.rpt"]
    report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
        -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_failing.rpt"]
    report_timing -max_paths 20 -slack_lesser_than 0.0 -delay_type min \
        -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_hold.rpt"]
    report_utilization -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_util.rpt"]
    report_design_analysis -congestion -complexity \
        -file [file normalize "$ImplOutputDir/post_route_attempt${_attempt}_congestion.rpt"]

    # 检查 timing
    set _rp [get_timing_paths -max_paths 1 -delay_type max]
    set _rWns 0.0
    if {[llength $_rp]} { set _rWns [get_property SLACK [lindex $_rp 0]] }
    set _rHp [get_timing_paths -max_paths 1 -delay_type min]
    set _rWhs 0.0
    if {[llength $_rHp]} { set _rWhs [get_property SLACK [lindex $_rHp 0]] }
    puts "INFO: Post-route (attempt $_attempt): WNS = ${_rWns} ns  WHS = ${_rWhs} ns"

    if {$_rWns > $bestWns} {
        set bestWns $_rWns
        set bestStrategy "$_placeDir/$_physDir/$_routeDir"
    }

    if {$_rWns >= 0 && $_rWhs >= 0} {
        puts "INFO: *** TIMING MET on attempt $_attempt! ***"
        set timingMet 1

        # 复制最终 DCP 为标准名
        file copy -force $_routeDcp [file normalize "$ImplOutputDir/post_route.dcp"]
        report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
        report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]
        report_drc -file [file normalize "$ImplOutputDir/post_route_drc.rpt"]
        report_methodology -file [file normalize "$ImplOutputDir/post_route_methodology.rpt"]
        report_power -advisory -file [file normalize "$ImplOutputDir/post_route_power.rpt"]

        # 写 bitstream
        puts "\n========== Write Bitstream =========="
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]
        puts "INFO: Bitstream written: $ImplOutputDir/top.bit"

        set wns $_rWns
        break
    }

    puts "INFO: Attempt $_attempt timing NOT met — trying next strategy..."
}

if {!$timingMet} {
    puts ""
    puts "============================================================"
    puts "  ALL $_totalAttempts STRATEGIES FAILED"
    puts "  Best WNS = ${bestWns} ns (strategy: $bestStrategy)"
    puts "============================================================"
    set wns $bestWns
    error "\[timing_retry\] All strategies exhausted. Best WNS=${bestWns}ns ($bestStrategy)"
}
puts "INFO: 3_synth_nonproj complete — full non-project mode implementation successful."
