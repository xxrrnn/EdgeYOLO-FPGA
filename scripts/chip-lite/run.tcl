# ==============================================================================
# run.tcl — 完整流程入口（支持 Project Mode / Non-Project Mode 切换）
# ==============================================================================
# 用法（完整流程）：
#   cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite
#   vivado -mode batch -source scripts/chip-lite/run.tcl
#
# ==============================================================================
# FLOW_MODE 选择（环境变量）
# ==============================================================================
# FLOW_MODE=project   → Project Mode（默认）
#   - 使用 Vivado .xpr 工程，launch_runs 管理 OOC 综合
#   - 适合日常开发、GUI 交互式调试
#   - 流程：1_build → 2_bd → 3_synth_project → 4_rpt
#
# FLOW_MODE=nonproj   → Non-Project Mode
#   - 纯 Tcl 命令驱动，不依赖 .xpr（但仍需 2_bd 产物）
#   - 适合 CI/CD、服务器批处理、精细 directive 调参
#   - 前提：先跑过一次 project mode 到 2_bd（生成 IP DCP + stubs）
#   - 流程：加载 config → 3_synth_nonproj → 4_rpt
#
# 示例：
#   # Project Mode（默认）
#   vivado -mode batch -source scripts/chip-lite/run.tcl
#
#   # Non-Project Mode
#   FLOW_MODE=nonproj vivado -mode batch -source scripts/chip-lite/run.tcl
#
#   # Non-Project Mode + 自定义 tag
#   FLOW_MODE=nonproj BUILD_TAG=np_test vivado -mode batch -source scripts/chip-lite/run.tcl
#
# ==============================================================================
# 并行构建 / BUILD_TAG（支持多个 Vivado 进程同时跑，互不干扰）
# ==============================================================================
# 每次 run 的产物位于独立子目录 build/lite/<tag>/，BD 也在其中，完全隔离。
#
#   # 自动时间戳（无需指定，每次唯一，默认行为）
#   vivado -mode batch -source scripts/chip-lite/run.tcl > logs/run1.log 2>&1 &
#   vivado -mode batch -source scripts/chip-lite/run.tcl > logs/run2.log 2>&1 &
#
#   # 自定义 tag（方便区分实验，两个进程并行）
#   BUILD_TAG=aggressive vivado -mode batch -source scripts/chip-lite/run.tcl > logs/agg.log 2>&1 &
#   BUILD_TAG=default    vivado -mode batch -source scripts/chip-lite/run.tcl > logs/def.log 2>&1 &
#
# ==============================================================================
# 断点恢复（通过环境变量 RESUME_FROM 指定从哪个 checkpoint 继续）
# ==============================================================================
#   RESUME_FROM=opt       从 post_opt.dcp 恢复（place → phys_opt → route → bit）
#   RESUME_FROM=place     从 post_place.dcp 恢复（phys_opt → route → bit）
#   RESUME_FROM=phys_opt  从 post_phys_opt.dcp 恢复（route → bit）
#
# 默认从当前 BUILD_TAG 目录加载 .xpr 和 DCP（同一 build 内重跑 place/route）：
#   BUILD_TAG=45a8845 RESUME_FROM=opt vivado -mode batch -source scripts/chip-lite/run.tcl
#
# 跨 tag 恢复：SOURCE_TAG 指定 .xpr 和 DCP 来源，BUILD_TAG 为新输出目录：
#   SOURCE_TAG=45a8845 BUILD_TAG=45a8845_pipeclk_fix RESUME_FROM=opt vivado ...
#   → 从 build/lite/45a8845/{lite.xpr, ImplOutputDir/post_opt.dcp} 加载
#   → 输出到 build/lite/45a8845_pipeclk_fix/ImplOutputDir/
#
# Checkpoint 位置：build/lite/<SOURCE_TAG>/ImplOutputDir/post_{opt,place,phys_opt}.dcp
# ==============================================================================

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

# --- 解析 FLOW_MODE ---
set flowMode "project"
if {[info exists ::env(FLOW_MODE)]} {
    set flowMode [string tolower [string trim $::env(FLOW_MODE)]]
}
if {$flowMode ne "project" && $flowMode ne "nonproj"} {
    puts "WARNING: Unknown FLOW_MODE='$flowMode' — defaulting to 'project'."
    set flowMode "project"
}
puts "INFO: FLOW_MODE = $flowMode"

# --- 解析 RESUME_FROM ---
set resumeFrom ""
if {[info exists ::env(RESUME_FROM)]} {
    set resumeFrom [string tolower [string trim $::env(RESUME_FROM)]]
}
if {$resumeFrom ne "" && $resumeFrom ne "opt" && $resumeFrom ne "place" && $resumeFrom ne "phys_opt"} {
    puts "WARNING: Unknown RESUME_FROM='$resumeFrom' — running full flow."
    set resumeFrom ""
}

# --- 解析 SOURCE_TAG（跨 tag 恢复时指定 .xpr/.dcp 来源 tag）---
# 未设置时默认等于当前 BUILD_TAG（即在同一目录内重跑）
set sourceTag $runTag
if {[info exists ::env(SOURCE_TAG)]} {
    set sourceTag [string trim $::env(SOURCE_TAG)]
}
set sourceProjPath     [file normalize "$buildDir/$projName/$sourceTag"]
set sourceImplDir      [file normalize "$sourceProjPath/ImplOutputDir"]
puts "INFO: SOURCE_TAG = $sourceTag (src: $sourceProjPath)"

# ==============================================================================
# Resume 模式（从 checkpoint 继续，project/nonproj 通用）
# ==============================================================================
set _run_error ""
if {[catch {

if {$resumeFrom ne ""} {
    # 加载已有 checkpoint 继续实现
    if {$flowMode eq "project"} {
        set xpr [file normalize "$sourceProjPath/${projName}.xpr"]
        if {![file exists $xpr]} { error "Project not found: $xpr — run full flow first (or set SOURCE_TAG)." }
        open_project $xpr
    }

    if {$resumeFrom eq "opt"} {
        set dcp [file normalize "$sourceImplDir/post_opt.dcp"]
    } elseif {$resumeFrom eq "place"} {
        set dcp [file normalize "$sourceImplDir/post_place.dcp"]
    } else {
        set dcp [file normalize "$sourceImplDir/post_phys_opt.dcp"]
    }
    if {![file exists $dcp]} { error "Checkpoint not found: $dcp" }
    file mkdir $ImplOutputDir

    # RESUME_FROM=opt 时支持 retry 策略循环（与 3_synth_project.tcl 一致）：
    # - 若设置了 PLACE_DIRECTIVE 环境变量，则只跑一次（单 pass 模式）
    # - 未设置则按 config.tcl 中的 retryStrategies 依次尝试，直到 timing 收敛
    set _singlePassMode [info exists ::env(PLACE_DIRECTIVE)]

    if {$resumeFrom eq "opt" && !$_singlePassMode} {
        # ── 多策略 Retry 循环（从 post_opt.dcp 重复 place→phys_opt→route）──
        puts "INFO: RESUME_FROM=opt — entering retry loop ([llength $retryStrategies] strategies)"
        set _best_wns -9999
        set _best_dcp ""
        set _best_bit ""

        for {set _ri 0} {$_ri < [llength $retryStrategies]} {incr _ri} {
            set _strat     [lindex $retryStrategies $_ri]
            set _placeDir  [lindex $_strat 0]
            set _physDir   [lindex $_strat 1]
            set _routeDir  [lindex $_strat 2]
            set _att       [expr {$_ri + 1}]
            set _total     [llength $retryStrategies]

            puts "\n========== RESUME Attempt $_att/$_total: place=$_placeDir  phys_opt=$_physDir  route=$_routeDir =========="

            puts "INFO: Loading checkpoint: $dcp"
            open_checkpoint $dcp
            set pbs [get_pblocks -quiet]
            if {[llength $pbs]} { delete_pblocks $pbs }
            read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]

            catch {set_param place.ILREnabled false}
            use_place_threads
            place_design -directive $_placeDir

            set _ppaths [get_timing_paths -max_paths 1 -delay_type max -quiet]
            set _ppWns 0.0
            if {[llength $_ppaths]} { set _ppWns [get_property SLACK [lindex $_ppaths 0]] }
            puts "INFO: Post-place WNS (attempt $_att) = ${_ppWns} ns"

            report_timing_summary -file [file normalize "$ImplOutputDir/post_place_attempt${_att}_timing.rpt"]
            write_checkpoint -force [file normalize "$ImplOutputDir/post_place_attempt${_att}.dcp"]

            if {$_ppWns < $wns_stop_place} {
                puts "WARNING: Post-place WNS ${_ppWns} < threshold ${wns_stop_place} — skipping strategy."
                continue
            }

            phys_opt_design -directive $_physDir
            write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt_attempt${_att}.dcp"]

            use_route_threads
            route_design -directive $_routeDir
            use_vivado_threads
            phys_opt_design -directive AggressiveExplore
            phys_opt_design -hold_fix

            set _rpaths [get_timing_paths -max_paths 1 -delay_type max -quiet]
            set _rwns 0.0
            if {[llength $_rpaths]} { set _rwns [get_property SLACK [lindex $_rpaths 0]] }
            puts "INFO: Post-route WNS (attempt $_att) = ${_rwns} ns"

            report_timing_summary -file [file normalize "$ImplOutputDir/post_route_attempt${_att}_timing.rpt"]
            report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
                -file [file normalize "$ImplOutputDir/post_route_attempt${_att}_failing.rpt"]
            write_checkpoint -force [file normalize "$ImplOutputDir/post_route_attempt${_att}.dcp"]

            if {$_rwns > $_best_wns} {
                set _best_wns  $_rwns
                set _best_dcp  [file normalize "$ImplOutputDir/post_route_attempt${_att}.dcp"]
            }

            if {$_rwns >= 0} {
                puts "INFO: Timing MET at attempt $_att (WNS=${_rwns}ns) — stopping retry loop."
                break
            }
        }

        # 从最优 checkpoint 生成 bitstream
        if {$_best_dcp ne "" && [file exists $_best_dcp]} {
            puts "INFO: Best route WNS = ${_best_wns} ns  (source: $_best_dcp)"
            open_checkpoint $_best_dcp
            read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]
        }
        set wns $_best_wns
        write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
        report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
        report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
            -file [file normalize "$ImplOutputDir/post_route_failing_paths.rpt"]
        report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]

    } else {
        # ── 单 Pass 模式（指定了 PLACE_DIRECTIVE 或从 place/phys_opt 恢复）──
        puts "INFO: RESUME_FROM=$resumeFrom — loading $dcp"
        open_checkpoint $dcp
        set pbs [get_pblocks -quiet]
        if {[llength $pbs]} { delete_pblocks $pbs }
        read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]

        if {$resumeFrom eq "opt"} {
            catch {set_param place.ILREnabled false}
            set _pd $placeDirective
            if {[info exists ::env(PLACE_DIRECTIVE)]} {
                set _pd [string trim $::env(PLACE_DIRECTIVE)]
                puts "INFO: PLACE_DIRECTIVE override = $_pd"
            }
            use_place_threads
            place_design -directive $_pd
            write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
            report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
            report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
                -file [file normalize "$ImplOutputDir/post_place_failing_paths.rpt"]
            report_utilization -file [file normalize "$ImplOutputDir/post_place_util.rpt"]
        }

        if {$resumeFrom eq "opt" || $resumeFrom eq "place"} {
            phys_opt_design -directive $physOptDirective
            write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt.dcp"]
            report_timing_summary -file [file normalize "$ImplOutputDir/post_phys_opt_timing_summary.rpt"]
        }

        use_route_threads
        route_design -directive $routeDirective
        use_vivado_threads
        phys_opt_design -directive AggressiveExplore
        phys_opt_design -hold_fix
        write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
        report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]
        report_timing -max_paths $rptMaxPaths -slack_lesser_than 0.0 -delay_type max \
            -file [file normalize "$ImplOutputDir/post_route_failing_paths.rpt"]
        report_utilization -file [file normalize "$ImplOutputDir/post_route_util.rpt"]

        set paths [get_timing_paths -max_paths 1 -delay_type max]
        set wns 0.0
        if {[llength $paths]} { set wns [get_property SLACK [lindex $paths 0]] }
    }

    puts "INFO: Post-route WNS = ${wns} ns"

    # FORCE_BITSTREAM=1 时，即使 WNS < 0 也生成 bitstream（用于微小违例如 -0.05ns 以内）
    set _forceThresh -0.05
    set _forceBit [expr {[info exists ::env(FORCE_BITSTREAM)] && $::env(FORCE_BITSTREAM) eq "1"}]

    if {$wns >= 0 || ($wns > $_forceThresh && $_forceBit)} {
        if {$wns < 0} {
            puts "WARNING: Forcing bitstream despite WNS=${wns}ns (FORCE_BITSTREAM=1, threshold=${_forceThresh}ns)"
        }
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]
        puts "INFO: Bitstream written."
    } else {
        puts "ERROR: Timing not met (WNS=${wns}ns) — bitstream skipped."
    }

    source [file normalize "$thisScriptDir/4_rpt.tcl"]

} else {
    # ==============================================================================
    # 完整流程（含 Timing Retry）
    # ==============================================================================
    if {$flowMode eq "project"} {
        # --- Project Mode: 从头创建工程 → BD → 综合实现 ---
        source [file normalize "$thisScriptDir/1_build.tcl"]
        source [file normalize "$thisScriptDir/2_bd.tcl"]
        source [file normalize "$thisScriptDir/3_synth_project.tcl"]
        source [file normalize "$thisScriptDir/4_rpt.tcl"]

    } else {
        # --- Non-Project Mode ---
        # 检查必要前置产物是否存在（2_bd 产出的 IP DCP 和 stubs）
        set _stubDir [file normalize "$projPath/ip_stubs"]
        set _ipRunsDir [file normalize "$projPath/${bdName}.runs"]
        if {![file exists $_stubDir] || ![file exists $_ipRunsDir]} {
            puts "ERROR: Non-project mode requires 2_bd products (ip_stubs + OOC DCPs)."
            puts "ERROR: Run project mode first, or set BUILD_TAG to an existing build."
            puts "ERROR: Expected: $_stubDir"
            puts "ERROR: Expected: $_ipRunsDir"
            error "Missing prerequisites for non-project mode. Run project mode (1_build + 2_bd) first."
        }
        source [file normalize "$thisScriptDir/3_synth_nonproj.tcl"]
        source [file normalize "$thisScriptDir/4_rpt.tcl"]
    }
}

} _catch_msg]} {
    set _run_error $_catch_msg
    puts "ERROR: Run failed — $_catch_msg"
}

puts "\n======== run.tcl DONE (mode=$flowMode) ========"

# ==============================================================================
# 完成通知（终端打印 + 126邮箱 SMTP）
# ==============================================================================
proc _smtp_read {sock} {
    set line [gets $sock]
    return $line
}

proc notify_completion {status detail} {
    global notifyEmail notify126From notify126Auth projName runTag projPath flowMode

    set host      [info hostname]
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    set subject   "\[Vivado\] ${projName}/${runTag}: ${status} (${flowMode})"
    set body      "Build:  $projName / $runTag\nMode:   $flowMode\nStatus: $status\nDetail: $detail\nHost:   $host\nTime:   $timestamp\nPath:   $projPath"

    puts "\a"
    puts "=============================================="
    puts "  BUILD $status  |  $projName/$runTag  |  mode=$flowMode"
    puts "  $detail"
    puts "  $timestamp"
    puts "=============================================="

    if {$notifyEmail eq "" || $notify126From eq "" || $notify126Auth eq ""} {
        return
    }

    set smtp_server "smtp.126.com"
    set port        25
    set b64_user [binary encode base64 $notify126From]
    set b64_pass [binary encode base64 $notify126Auth]

    if {[catch {set sock [socket $smtp_server $port]} err]} {
        puts "WARNING: 无法连接 SMTP 服务器 $smtp_server:$port — $err"
        return
    }
    fconfigure $sock -buffering line -translation crlf

    _smtp_read $sock
    puts $sock "HELO localhost";  _smtp_read $sock
    puts $sock "AUTH LOGIN";      _smtp_read $sock
    puts $sock $b64_user;         _smtp_read $sock
    puts $sock $b64_pass
    set auth_resp [_smtp_read $sock]

    if {![string match "235 *" $auth_resp]} {
        puts "WARNING: 126邮箱认证失败（$auth_resp），请检查授权码"
        catch {puts $sock "QUIT"}
        close $sock
        return
    }

    puts $sock "MAIL FROM:<$notify126From>";  _smtp_read $sock
    puts $sock "RCPT TO:<$notifyEmail>";      _smtp_read $sock
    puts $sock "DATA";                        _smtp_read $sock

    puts $sock "From: Vivado Build <$notify126From>"
    puts $sock "To: $notifyEmail"
    puts $sock "Subject: $subject"
    puts $sock "Content-Type: text/plain; charset=\"UTF-8\""
    puts $sock ""
    foreach line [split $body "\n"] { puts $sock $line }
    puts $sock ".";   _smtp_read $sock
    puts $sock "QUIT"; _smtp_read $sock
    close $sock
    puts "INFO: 通知邮件已发送至 $notifyEmail"
}

if {$_run_error ne ""} {
    notify_completion "FAILED" $_run_error
} else {
    if {[info exists wns]} {
        if {$wns >= 0} {
            notify_completion "SUCCESS" "WNS=${wns}ns, bitstream generated"
        } else {
            notify_completion "TIMING_FAIL" "WNS=${wns}ns, bitstream skipped"
        }
    } else {
        notify_completion "COMPLETED" "Flow finished (check reports)"
    }
}
