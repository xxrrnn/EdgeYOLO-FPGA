# DCIM_Array Chip project creation script.
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

if {[llength [info commands create_project]] == 0} {
    error "This script must be sourced in Vivado Tcl, not plain tclsh."
}

if {[llength [get_projects -quiet]] != 0} {
    close_project
}

# 与 build/lite 同步清理 BD 输出树，避免磁盘残留 *_0 目录导致 Vivado 生成 *_0_1 副本
set bdRoot [file normalize "$bdDir/$bdName"]
if {[file exists $bdRoot]} {
    puts "Info: Removing stale BD output tree: $bdRoot"
    set retries 3
    while {$retries > 0 && [file exists $bdRoot]} {
        catch {file delete -force $bdRoot}
        if {[file exists $bdRoot]} {
            incr retries -1
            after 500
        } else {
            break
        }
    }
    if {[file exists $bdRoot]} {
        error "ERROR: Cannot delete BD output tree $bdRoot (file lock?). Close Vivado and retry."
    }
}

# 如果工程已存在，删除后重建（最多重试 3 次，防止文件锁导致静默失败）
if {[file exists $projPath]} {
    puts "Info: Project directory exists, removing: $projPath"
    set retries 3
    while {$retries > 0 && [file exists $projPath]} {
        catch {file delete -force $projPath}
        if {[file exists $projPath]} {
            incr retries -1
            after 500
        } else {
            break
        }
    }
    if {[file exists $projPath]} {
        error "ERROR: Cannot delete project directory $projPath (file lock?). Please close Vivado, delete it manually, then re-source."
    }
}

create_project $projName $projPath -part $part
set_property board_part $boardPart [current_project]

# add xdc
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    add_files -fileset constrs_1 $xdcFile
}

puts "INFO: 0_build complete — project: $projPath/${projName}.xpr"
puts "INFO: Next (new batch command each): vivado -mode batch -source scripts/chip-lite/1_bd.tcl"
puts "INFO: Or full flow: vivado -mode batch -source scripts/chip-lite/run.tcl"
