# ==============================================================================
# 1_build.tcl — 创建 Vivado 工程，添加 RTL 源文件和 XDC 约束
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
if {![info exists ScriptDir]} { source [file normalize "$thisScriptDir/config.tcl"] }

if {[llength [info commands create_project]] == 0} {
    error "Must be sourced in Vivado Tcl (not plain tclsh)."
}
if {[llength [get_projects -quiet]] != 0} { close_project }

# --- 清理本次 run 的旧产物 ---
# bdDir（BD 产物）现在位于 projPath/bd/ 内部，删除 projPath 即可一并清理，
# 无需单独列出。各 run 的 projPath 均已通过 BUILD_TAG / 时间戳隔离，
# 不会影响其他正在运行的 Vivado 进程。
foreach dirToClean [list $projPath] {
    if {[file exists $dirToClean]} {
        puts "INFO: Removing: $dirToClean"
        for {set i 0} {$i < 3 && [file exists $dirToClean]} {incr i} {
            catch {file delete -force $dirToClean}
            if {[file exists $dirToClean]} { after 500 }
        }
        if {[file exists $dirToClean]} {
            error "Cannot delete $dirToClean — close other Vivado sessions and retry."
        }
    }
}

# --- 创建工程 ---
create_project $projName $projPath -part $part
set_property board_part $boardPart [current_project]

# -----------------------------------------------------------------------
# 把 IP Cache 限定在本次 build 的 projPath 内部（每次 run 独立目录）。
# 好处：
#   1. 不同同学/不同 Vivado 进程的 IP Cache 完全隔离，避免 cache hit
#      导致 OOC 子进程不启动、stub 不写入主进程 .Xil/realtime/ 的问题。
#   2. projPath 每次重建时被清空，缓存自动失效，确保使用最新 IP 配置。
# 注意：每次 build 都重新跑 OOC 综合，比共享 cache 略慢，但结果确定可靠。
# -----------------------------------------------------------------------
set _ip_cache_dir [file normalize "$projPath/ip_cache"]
file mkdir $_ip_cache_dir
set_property ip_output_repo $_ip_cache_dir [current_project]

# --- 添加 XDC ---
# chip.xdc（纯 pin/IO 约束，无 Tcl 控制流）→ 放入 fileset，synth_design 可直接读。
# chip_timing.xdc（含 if/foreach/set 等控制流）→ 只通过 reload_xdc 以 -unmanaged 加载，
#   不加入 fileset，避免 Vivado managed-mode 解析报 CRITICAL WARNING [Designutils 20-1307]。
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[string match "*chip_timing*" $xdcFile]} { continue }
    add_files -fileset constrs_1 $xdcFile
}

puts "INFO: 1_build complete — $projPath/${projName}.xpr"
