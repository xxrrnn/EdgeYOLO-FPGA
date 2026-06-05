# ==============================================================================
# 2_bd.tcl — 创建 Block Design, 添加 RTL, validate, OOC 综合, wrapper
# ==============================================================================
set thisScriptDir [file dirname [file normalize [info script]]]
if {![info exists ScriptDir]} { source [file normalize "$thisScriptDir/config.tcl"] }

# --- 确保工程已打开 ---
if {[llength [get_projects -quiet]] == 0} {
    set xpr [file normalize "$projPath/${projName}.xpr"]
    if {![file exists $xpr]} {
        error "Project not found: $xpr — run 1_build.tcl first."
    }
    open_project $xpr
}

# --- FP32 IPs for VPU ---
source [file normalize "$scriptsDir/ip/floating_point_fp32.tcl"]
if {[llength [get_ips -quiet fp32_mult_lane]] == 0 || [llength [get_ips -quiet fp32_add_lane]] == 0} {
    fp32_mac_ips_create
}

# --- 清理旧 BD ---
set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
set bdRoot [file normalize "$bdDir/$bdName"]
if {[llength [get_files -quiet $bdFile]] != 0} { remove_files $bdFile }
if {[file exists $bdRoot]} {
    puts "INFO: Removing stale BD: $bdRoot"
    for {set i 0} {$i < 3 && [file exists $bdRoot]} {incr i} {
        catch {file delete -force $bdRoot}
        if {[file exists $bdRoot]} { after 500 }
    }
    if {[file exists $bdRoot]} {
        error "Cannot delete $bdRoot — close other Vivado sessions."
    }
}

# ==============================================================================
# 添加 RTL 源文件
# ==============================================================================
create_bd_design -dir $bdDir $bdName

set chipRtlFiles [list \
    [file normalize "$srcDir/chip/DCIM_Array.sv"] \
    [file normalize "$srcDir/chip/DCIM_Array_bd.v"] \
    [file normalize "$srcDir/chip/DCIM_Tile.sv"] \
    [file normalize "$srcDir/chip/ibuf_rd_arbiter.sv"] \
    [file normalize "$srcDir/chip/obuf_wr_arbiter.sv"] \
]

set dcimRtlFiles [list \
    [file normalize "$srcDir/ref/DCIM/src/inc/para.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/counter.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/dff.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/pipe_stage.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/multiplier.v"] \
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

set bufferRtlFiles [list \
    [file normalize "$srcDir/DCIM_Macro/ibuf.v"] \
    [file normalize "$srcDir/DCIM_Macro/obuf.v"] \
]

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

set chipHeaderFiles [list [file normalize "$srcDir/chip/chip_defines.vh"]]

add_files -norecurse [concat $chipRtlFiles $dcimRtlFiles $bufferRtlFiles $vpuRtlFiles $chipHeaderFiles]

set_property include_dirs [list \
    [file normalize "$srcDir/chip"] \
    [file normalize "$srcDir/ref/DCIM/src/inc"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim"] \
    [file normalize "$srcDir/ref/DCIM/src/model"] \
    $vpuRtlDir \
    [file normalize "$vpuRtlDir/fp_array"] \
] [current_fileset]

set paraFile [file normalize "$srcDir/ref/DCIM/src/inc/para.v"]
set_property file_type {Verilog Header} [get_files $paraFile]
set_property is_global_include true [get_files $paraFile]
foreach vhFile $chipHeaderFiles {
    set_property file_type {Verilog Header} [get_files $vhFile]
    set_property is_global_include true [get_files $vhFile]
}

set_property verilog_define [list \
    FPGA=1 \
    MODE_INT4=3'b100  MODE_INT8=3'b110  MODE_INT16=3'b111 \
    MODE_UINT4=3'b000 MODE_UINT8=3'b010 MODE_UINT16=3'b011 \
] [current_fileset]

# ==============================================================================
# 创建 BD cells
# ==============================================================================
create_bd_cell -type module -reference DCIM_Array_bd dcim_array_0
set_property -dict [list CONFIG.NUM_TILES {4}] [get_bd_cells dcim_array_0]
catch {set_property generate_synth_checkpoint false [get_bd_cells dcim_array_0]}

create_bd_cell -type module -reference Global_VPU_top vpu_0
catch {set_property generate_synth_checkpoint false [get_bd_cells vpu_0]}

# IP 配置和连接
source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/hbm.tcl"]
source [file normalize "$ipBdDir/cdma.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]
source [file normalize "$ipBdDir/address.tcl"]

validate_bd_design
regenerate_bd_layout
apply_dcim_axi_bram_read_latency
save_bd_design

# --- Wrapper ---
make_wrapper -files [get_files $bdFile] -top
add_files -norecurse [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

# ==============================================================================
# OOC 综合（IP 独立综合 → 生成 DCP/stub）
# ==============================================================================
puts "INFO: Generating IP targets and creating OOC synthesis runs..."
generate_target all [get_files $bdFile]
create_ip_run [get_files $bdFile]
export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force

# 收集所有 OOC 综合 run
set allOocRuns [get_runs -quiet *_synth_1]
if {![llength $allOocRuns]} {
    error "No OOC synthesis runs found — IP generation failed."
}

# 分批：SmartConnect 先跑（其他 IP 依赖其 stub）
set smcRuns {}
set otherRuns {}
foreach r $allOocRuns {
    set rname [get_property NAME $r]
    set st    [get_property STATUS $r]
    if {[regexp -nocase {synth_design complete} $st]} {
        puts "INFO: OOC cached: $rname"
        continue
    }
    if {[string match "*smc*" $rname] || [string match "*smartconnect*" $rname]} {
        lappend smcRuns $r
    } else {
        lappend otherRuns $r
    }
}

# 顺序执行 OOC 综合
foreach batch [list $smcRuns $otherRuns] {
    if {![llength $batch]} { continue }
    puts "INFO: Launching [llength $batch] OOC run(s)..."
    reset_run $batch

    # 对 dcim_array OOC 脚本注入 -max_dsp（reset_run 后 tcl 已在磁盘）
    foreach r $batch {
        set rname [get_property NAME $r]
        if {![string match "*dcim_array*" $rname]} { continue }
        set oocTcl [file normalize "$projPath/${bdName}.runs/${rname}/${rname}.tcl"]
        if {![file exists $oocTcl]} {
            puts "WARNING: OOC tcl not found for $rname — cannot patch -max_dsp"
            continue
        }
        set fh [open $oocTcl r]; set src [read $fh]; close $fh
        if {[string match "*synth_design *" $src] && ![string match "*-max_dsp*" $src]} {
            regsub -- {(synth_design[^\n]+)} $src "\\1 -max_dsp $dcimMaxDsp" src
            set fh [open $oocTcl w]; puts -nonewline $fh $src; close $fh
            puts "INFO: Patched $rname: synth_design ... -max_dsp $dcimMaxDsp"
        }
    }

    launch_runs $batch -jobs 32   ;# 每 job 是独立 Vivado 进程，32 并发在 128 核机器上安全
    foreach r $batch {
        set rname [get_property NAME $r]
        wait_on_run $r
        set st [get_property STATUS [get_runs $rname]]
        if {![regexp -nocase {synth_design complete} $st]} {
            error "OOC synthesis failed: $rname ($st)"
        }
        puts "INFO: OOC done: $rname"
    }
}

# 确保 module-ref DCP/stub 存在
set ipRoot [file normalize "$bdDir/$bdName/ip"]
foreach ipTop $modRefIpTops {
    set stub [file normalize "$ipRoot/$ipTop/${ipTop}_stub.v"]
    set dcpRun [file normalize "$projPath/${bdName}.runs/${ipTop}_synth_1/${ipTop}.dcp"]
    if {![file exists $stub] && [file exists $dcpRun]} {
        file mkdir [file normalize "$ipRoot/$ipTop"]
        file copy -force $dcpRun [file normalize "$ipRoot/$ipTop/${ipTop}.dcp"]
        puts "INFO: Copied OOC DCP for $ipTop"
    }
}

export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force

# 确保 XDC 在 fileset 中
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

puts "INFO: 2_bd complete — BD validated, OOC synthesized, wrapper ready."
