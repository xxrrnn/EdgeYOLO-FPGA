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

# 将 DCIM tile_ibuf / tile_obuf / VPU_BUF 的 axi_bram_ctrl READ_LATENCY 与 chip_defines 对齐
proc apply_dcim_axi_bram_read_latency {} {
    # tile_ibuf controllers
    for {set t 0} {$t < 4} {incr t} {
        set cell "tile_ibuf_ctrl_${t}"
        set cells [get_bd_cells -quiet $cell]
        if {[llength $cells] == 0} { continue }
        set lat [chip_get DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY]
        if {![string is integer -strict $lat]} {
            error "Invalid DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY=$lat"
        }
        set_property CONFIG.READ_LATENCY $lat $cells
        puts "INFO: $cell CONFIG.READ_LATENCY=$lat (DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY)"
    }
    # tile_obuf controllers
    for {set t 0} {$t < 4} {incr t} {
        set cell "tile_obuf_ctrl_${t}"
        set cells [get_bd_cells -quiet $cell]
        if {[llength $cells] == 0} { continue }
        set lat [chip_get DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY]
        if {![string is integer -strict $lat]} {
            error "Invalid DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY=$lat"
        }
        set_property CONFIG.READ_LATENCY $lat $cells
        puts "INFO: $cell CONFIG.READ_LATENCY=$lat (DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY)"
    }
    # VPU_BUF controller
    set cells [get_bd_cells -quiet vpu_buf_ctrl]
    if {[llength $cells] != 0} {
        set lat [chip_get VPU_BUF_AXI_BRAM_READ_LATENCY]
        if {![string is integer -strict $lat]} {
            error "Invalid VPU_BUF_AXI_BRAM_READ_LATENCY=$lat"
        }
        set_property CONFIG.READ_LATENCY $lat $cells
        puts "INFO: vpu_buf_ctrl CONFIG.READ_LATENCY=$lat (VPU_BUF_AXI_BRAM_READ_LATENCY)"
    }
}
