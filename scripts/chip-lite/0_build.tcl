# DCIM_Array Chip project creation script.
set thisScriptDir [file dirname [file normalize [info script]]]
source [file normalize "$thisScriptDir/config.tcl"]

if {[llength [info commands create_project]] == 0} {
    error "This script must be sourced in Vivado Tcl, not plain tclsh."
}

if {[llength [get_projects -quiet]] != 0} {
    close_project
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
