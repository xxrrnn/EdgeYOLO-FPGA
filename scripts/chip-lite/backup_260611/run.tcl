# ==============================================================================
# run.tcl — 完整流程入口（顺序执行 config → build → bd → synth → rpt）
# ==============================================================================
# 用法（完整流程）：
#   cd /data/home/rn_xu29/Projects/YOLO-On-FPGA/EdgeYOLO-FPGA-lite
#   vivado -mode batch -source scripts/chip-lite/run.tcl
#
# ------------------------------------------------------------------------------
# 并行构建 / BUILD_TAG（支持多个 Vivado 进程同时跑，互不干扰）
# ------------------------------------------------------------------------------
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
#   # 查看所有历史 build
#   ls build/lite/
#
# ------------------------------------------------------------------------------
# 断点恢复（通过环境变量 RESUME_FROM 指定从哪个 checkpoint 继续）
# 必须同时传入与原始 run 相同的 BUILD_TAG，确保找到正确的 projPath
# ------------------------------------------------------------------------------
#   RESUME_FROM=opt       从 post_opt.dcp 恢复
#                         跑步骤：place → phys_opt → route → bitstream
#                         命令：BUILD_TAG=<tag> RESUME_FROM=opt vivado -mode batch -source scripts/chip-lite/run.tcl
#
#   RESUME_FROM=place     从 post_place.dcp 恢复
#                         跑步骤：phys_opt → route → bitstream
#                         命令：BUILD_TAG=<tag> RESUME_FROM=place vivado -mode batch -source scripts/chip-lite/run.tcl
#
#   RESUME_FROM=phys_opt  从 post_phys_opt.dcp 恢复（最快，仅跑 route + bitstream）
#                         跑步骤：route → bitstream
#                         命令：BUILD_TAG=<tag> RESUME_FROM=phys_opt vivado -mode batch -source scripts/chip-lite/run.tcl
#
# Checkpoint 位置：build/lite/<tag>/ImplOutputDir/post_{opt,place,phys_opt}.dcp
# 注意：Vivado maxThreads 上限为 32（软件硬性限制，与服务器核数无关）
# ==============================================================================

set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

# --- Resume 模式 ---
set resumeFrom ""
if {[info exists ::env(RESUME_FROM)]} {
    set resumeFrom [string tolower [string trim $::env(RESUME_FROM)]]
}

if {$resumeFrom ne "" && $resumeFrom ne "opt" && $resumeFrom ne "place" && $resumeFrom ne "phys_opt"} {
    puts "WARNING: Unknown RESUME_FROM='$resumeFrom' — running full flow."
    set resumeFrom ""
}

set _run_error ""
if {[catch {

if {$resumeFrom ne ""} {
    # Resume 模式：打开工程，加载 checkpoint，从指定阶段继续
    set xpr [file normalize "$projPath/${projName}.xpr"]
    if {![file exists $xpr]} {
        error "Project not found: $xpr — run full flow first."
    }
    open_project $xpr

    if {$resumeFrom eq "opt"} {
        set dcp [file normalize "$ImplOutputDir/post_opt.dcp"]
    } elseif {$resumeFrom eq "place"} {
        set dcp [file normalize "$ImplOutputDir/post_place.dcp"]
    } else {
        set dcp [file normalize "$ImplOutputDir/post_phys_opt.dcp"]
    }
    if {![file exists $dcp]} {
        error "Checkpoint not found: $dcp — run full flow first."
    }

    puts "INFO: RESUME_FROM=$resumeFrom — loading $dcp"
    open_checkpoint $dcp

    # 重新加载 chip_timing.xdc（含 Tcl 控制流，必须 -unmanaged）
    # chip.xdc 已在 project fileset，open_checkpoint 后不需重复加载。
    set pbs [get_pblocks -quiet]
    if {[llength $pbs]} { delete_pblocks $pbs }
    read_xdc -unmanaged [file normalize "$xdcDir/chip/chip_timing.xdc"]

    file mkdir $ImplOutputDir

    if {$resumeFrom eq "opt"} {
        # place → phys_opt → route → bit
        # place_design 会在当前工作目录下生成 cong/ 拥塞热图，cd 到 ImplOutputDir
        # 使其落在 build 树内而不是仓库根目录。
        set _savedCwd [pwd]
        cd $ImplOutputDir
        if {$placeMode eq "safe"} {
            catch {set_param place.ILREnabled true}
            set_param general.maxThreads 1
            puts "INFO: \[place_mode\] safe — ILR=on, threads=1"
        } else {
            catch {set_param place.ILREnabled false}
            set_param general.maxThreads 32
            puts "INFO: \[place_mode\] fast — ILR=off, threads=32"
        }
        place_design -directive $placeDirective
        set_param general.maxThreads 32
        cd $_savedCwd
        write_checkpoint -force [file normalize "$ImplOutputDir/post_place.dcp"]
        report_timing_summary -file [file normalize "$ImplOutputDir/post_place_timing_summary.rpt"]
    }

    if {$resumeFrom eq "opt" || $resumeFrom eq "place"} {
        # phys_opt → route → bit
        phys_opt_design -directive $physOptDirective
        write_checkpoint -force [file normalize "$ImplOutputDir/post_phys_opt.dcp"]
    }

    # route → bit（phys_opt 已完成时直接从此继续）
    route_design -directive $routeDirective
    write_checkpoint -force [file normalize "$ImplOutputDir/post_route.dcp"]
    report_timing_summary -file [file normalize "$ImplOutputDir/post_route_timing_summary.rpt"]

    set paths [get_timing_paths -max_paths 1 -delay_type max]
    set wns 0.0
    if {[llength $paths]} { set wns [get_property SLACK [lindex $paths 0]] }
    puts "INFO: Post-route WNS = ${wns} ns"

    if {$wns >= 0} {
        set_property CONFIG_MODE SPIx4 [current_design]
        set_property BITSTREAM.CONFIG.CONFIGRATE 63.8 [current_design]
        write_bitstream -verbose -force -bin_file [file normalize "$ImplOutputDir/top.bit"]
        puts "INFO: Bitstream written."
    } else {
        puts "ERROR: Timing not met — bitstream skipped."
    }

    # 报告
    source [file normalize "$thisScriptDir/4_rpt.tcl"]
} else {
    # --- 完整流程 ---
    source [file normalize "$thisScriptDir/1_build.tcl"]
    source [file normalize "$thisScriptDir/2_bd.tcl"]
    source [file normalize "$thisScriptDir/3_synth.tcl"]
    source [file normalize "$thisScriptDir/4_rpt.tcl"]
}

} _catch_msg]} {
    set _run_error $_catch_msg
    puts "ERROR: Run failed — $_catch_msg"
}

puts "\n======== run.tcl DONE ========"

# ==============================================================================
# 完成通知（终端打印 + 126邮箱 SMTP）
# ==============================================================================

# 辅助：读一行 SMTP 响应（定义在 proc 外部，避免重定义）
proc _smtp_read {sock} {
    set line [gets $sock]
    return $line
}

proc notify_completion {status detail} {
    global notifyEmail notify126From notify126Auth projName runTag projPath

    set host      [info hostname]
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    # Subject 内容纯 ASCII，不需要 base64 编码整行
    set subject   "\[Vivado\] ${projName}/${runTag}: ${status}"
    set body      "Build:  $projName / $runTag\nStatus: $status\nDetail: $detail\nHost:   $host\nTime:   $timestamp\nPath:   $projPath"

    # 终端醒目输出（无论是否配置邮件）
    puts "\a"
    puts "=============================================="
    puts "  BUILD $status  |  $projName/$runTag"
    puts "  $detail"
    puts "  $timestamp"
    puts "=============================================="

    # 邮件通知（仅当三个变量都非空时）
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

# 判断最终状态
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
