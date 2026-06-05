# ==============================================================================
# 1_build.tcl — 创建 Vivado 工程，添加 RTL 源文件和 XDC 约束
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
if {![info exists ScriptDir]} { source [file normalize "$thisScriptDir/config.tcl"] }

if {[llength [info commands create_project]] == 0} {
    error "Must be sourced in Vivado Tcl (not plain tclsh)."
}
if {[llength [get_projects -quiet]] != 0} { close_project }

# --- 清理旧工程 ---
foreach dirToClean [list [file normalize "$bdDir/$bdName"] $projPath] {
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

# --- 添加 XDC ---
# chip.xdc（纯 pin/IO 约束，无 Tcl 控制流）→ 放入 fileset，synth_design 可直接读。
# chip_timing.xdc（含 if/foreach/set 等控制流）→ 只通过 reload_xdc 以 -unmanaged 加载，
#   不加入 fileset，避免 Vivado managed-mode 解析报 CRITICAL WARNING [Designutils 20-1307]。
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[string match "*chip_timing*" $xdcFile]} { continue }
    add_files -fileset constrs_1 $xdcFile
}

puts "INFO: 1_build complete — $projPath/${projName}.xpr"
