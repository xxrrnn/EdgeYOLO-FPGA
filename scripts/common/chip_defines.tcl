#==============================================================================
# chip_defines.tcl — 从 rtl/chip/chip_defines.vh 加载参数，供 BD / export 脚本使用
# 与 tools/chip_config.py 共用同一套 `define（勿在 Tcl 里写死魔法数字）
#==============================================================================

if {![info exists ::_chip_defines_tcl_sourced]} {
    source [file normalize [file dirname [info script]]/parse_chip_defines.tcl]
    set ::_chip_defines_tcl_sourced 1
}

proc chip_defines_load {repo_root} {
    set vh [file normalize "$repo_root/rtl/chip/chip_defines.vh"]
    if {![file exists $vh]} {
        error "chip_defines.vh not found: $vh"
    }
    if {![info exists ::chip_defines_loaded_vh] || $::chip_defines_loaded_vh ne $vh} {
        if {![parse_chip_defines $vh]} {
            error "parse_chip_defines failed: $vh"
        }
        set ::chip_defines_loaded_vh $vh
    }
    return $vh
}

proc chip_get {name {default ""}} {
    return [get_vpu_param $name $default]
}

# 将 DCIM IBUF/OBUF 的 axi_bram_ctrl READ_LATENCY 与 chip_defines 对齐
proc apply_dcim_axi_bram_read_latency {} {
    foreach {cell_name macro_name} {
        dcim_ibuf_ctrl_0 DCIM_IBUF_AXI_BRAM_READ_LATENCY
        dcim_obuf_ctrl_0 DCIM_OBUF_AXI_BRAM_READ_LATENCY
    } {
        set cells [get_bd_cells -quiet $cell_name]
        if {[llength $cells] == 0} {
            continue
        }
        set lat [chip_get $macro_name]
        if {![string is integer -strict $lat]} {
            error "Invalid $macro_name=$lat (expected integer)"
        }
        set_property CONFIG.READ_LATENCY $lat $cells
        puts "INFO: $cell_name CONFIG.READ_LATENCY=$lat ($macro_name)"
    }
}
