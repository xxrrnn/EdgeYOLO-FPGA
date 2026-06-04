#==============================================================================
# chip_lite_bd.tcl — lite 工程 / BD 打开辅助（batch 每脚本独立进程，须显式 open_project）
#
#   chip_lite_ensure_project_open
#   chip_lite_open_bd_design $bdFile $bdName
#==============================================================================

# batch 模式下 0_build.tcl 结束后 Vivado 会退出；后续 1_bd / export 须在本进程 open_project
proc chip_lite_ensure_project_open {} {
    if {[llength [get_projects -quiet]] > 0} {
        return
    }
    if {![info exists projPath] || ![info exists projName]} {
        error "chip_lite_ensure_project_open: projPath/projName undefined — source config.tcl first"
    }
    set xpr [file normalize "$projPath/${projName}.xpr"]
    if {![file exists $xpr]} {
        error "Vivado project not found: $xpr\nRun: vivado -mode batch -source scripts/chip-lite/0_build.tcl"
    }
    puts "INFO: open_project $xpr (new Vivado session — 0_build does not persist across batch runs)"
    open_project $xpr
}

proc chip_lite_open_bd_design {bdFile bdName} {
    chip_lite_ensure_project_open
    if {![file exists $bdFile]} {
        error "BD file not found: $bdFile — run scripts/chip-lite/1_bd.tcl (after 0_build.tcl)"
    }

    set bdObj [get_files -quiet $bdFile]
    if {$bdObj eq ""} {
        puts "INFO: chip_lite_open_bd_design: add_files $bdFile"
        add_files -norecurse $bdFile
        set bdObj [get_files -quiet $bdFile]
    }
    if {$bdObj eq ""} {
        error "Failed to register BD in project: $bdFile"
    }

    set cur [current_bd_design -quiet]
    if {$cur ne "" && $cur ne $bdName} {
        catch {close_bd_design $cur}
    }

    if {[llength [get_bd_designs -quiet $bdName]] > 0} {
        open_bd_design $bdName
    } else {
        open_bd_design $bdObj
    }

    if {[llength [get_bd_cells -quiet]] == 0} {
        puts "INFO: chip_lite_open_bd_design: validate_bd_design (populate cells)"
        if {[catch {validate_bd_design} err]} {
            puts "WARNING: validate_bd_design: $err"
        }
    }

    if {[llength [get_bd_cells -quiet]] == 0} {
        catch {close_bd_design $bdName}
        open_bd_design $bdObj
        if {[catch {validate_bd_design} err]} {
            puts "WARNING: validate_bd_design (retry): $err"
        }
    }

    if {[llength [get_bd_cells -quiet]] == 0} {
        puts "ERROR: Block design '$bdName' opened but get_bd_cells is empty."
        puts "ERROR: Common causes:"
        puts "ERROR:   1) Ran 0_build.tcl (deletes bd/lite/) without re-running 1_bd.tcl"
        puts "ERROR:   2) Opened lite.bd outside project context (fixed by this proc — retry failed)"
        puts "ERROR: Fix: vivado -mode batch -source scripts/chip-lite/0_build.tcl"
        puts "ERROR:      vivado -mode batch -source scripts/chip-lite/1_bd.tcl"
        error "BD has no cells — re-run 1_bd.tcl to rebuild bd/lite and register RTL"
    }

    return $bdName
}

proc chip_lite_get_bd_cell {name {vlnv_glob ""}} {
    set cells [get_bd_cells -quiet $name]
    if {[llength $cells] == 0 && $vlnv_glob ne ""} {
        set cells [get_bd_cells -quiet -filter "VLNV =~ $vlnv_glob"]
    }
    return $cells
}
