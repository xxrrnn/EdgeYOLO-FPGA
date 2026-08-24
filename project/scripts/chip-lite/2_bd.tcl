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
    [file normalize "$srcDir/common/uram_tdp_bytewrite.v"] \
    [file normalize "$srcDir/chip/DCIM_Array.sv"] \
    [file normalize "$srcDir/chip/DCIM_Array_bd.v"] \
    [file normalize "$srcDir/chip/DCIM_Tile.sv"] \
    [file normalize "$srcDir/chip/DCIM_Activation_Stream.sv"] \
    [file normalize "$srcDir/chip/DCIM_Weight_Cache.sv"] \
    [file normalize "$srcDir/chip/DCIM_Partial_Sum_RAM.sv"] \
    [file normalize "$srcDir/chip/DCIM_Result_Stream.sv"] \
    [file normalize "$srcDir/chip/tile_ibuf.v"] \
    [file normalize "$srcDir/chip/tile_obuf.v"] \
]

set dcimRtlFiles [list \
    [file normalize "$srcDir/ref/DCIM/src/inc/para.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/counter.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/dff.v"] \
    [file normalize "$srcDir/ref/DCIM/src/inc/pipe_stage.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/multiplier.v"] \
    [file normalize "$srcDir/ref/DCIM/src/dcim/multiplier_dsp.v"] \
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
    [file normalize "$srcDir/common"] \
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
set_property -dict [list CONFIG.NUM_TILES $::DCIM_NUM_TILES] [get_bd_cells dcim_array_0]
catch {set_property generate_synth_checkpoint false [get_bd_cells dcim_array_0]}

create_bd_cell -type module -reference Global_VPU_top vpu_0
catch {set_property generate_synth_checkpoint false [get_bd_cells vpu_0]}

# IP 配置和连接
source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/hbm.tcl"]
source [file normalize "$ipBdDir/cdma.tcl"]
source [file normalize "$ipBdDir/peak_ila.tcl"]
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

# Lightweight integration check used by test/tops/fpga/synth/validate_stream_bd.tcl.
# At this point module references, all BD connections, address assignment and
# the generated wrapper have already been validated. Skip the expensive OOC
# IP synthesis when only the streamed-DCIM interface contract is under test.
if {[info exists ::env(BD_VALIDATE_ONLY)] && $::env(BD_VALIDATE_ONLY) eq "1"} {
    puts "INFO: BD_VALIDATE_ONLY=1 - BD validation and wrapper generation complete."
    return
}

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
# DSP 用量由 RTL 层精确控制（maArray 按 col < DCIM_DSP_COL_NUM 选择 DSP/LUT），
# 无需 TCL 层 -max_dsp 注入，直接 reset + launch 即可。
#
# 注意：-jobs 32 时子进程内 STATUS="synth_design complete"，但父工程轮询
# STATUS 可能停在 "Scripts Generated" 或 "Complete" 等变体，无法用正则可靠
# 匹配。改为：①宽松正则覆盖所有完成态；②DCP 存在即视为成功（最可靠）。
foreach batch [list $smcRuns $otherRuns] {
    if {![llength $batch]} { continue }
    puts "INFO: Launching [llength $batch] OOC run(s)..."
    reset_run $batch
    launch_runs $batch -jobs 32   ;# 每 job 独立 Vivado 进程，32 并发安全
    foreach r $batch {
        set rname [get_property NAME $r]
        wait_on_run $r
        set st [get_property STATUS [get_runs $rname]]
        # DCP 路径：lite.runs/<rname>/<rname>.dcp
        set dcpPath [file normalize "$projPath/${bdName}.runs/${rname}/${rname}.dcp"]
        # 成功判断：STATUS 含 complete/Complete，或 DCP 文件已生成
        set ok 0
        if {[regexp -nocase {complete} $st]}         { set ok 1 }
        if {[string match "*cached*" $st]}            { set ok 1 }
        if {[file exists $dcpPath]}                   { set ok 1 }
        if {!$ok} {
            error "OOC synthesis failed: $rname (STATUS=$st, DCP=$dcpPath)"
        }
        puts "INFO: OOC done: $rname (STATUS=$st)"
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
        # 从 DCP 生成 stub（顶层综合需要）
        set curDesign [current_design -quiet]
        open_checkpoint $dcpRun -quiet
        write_verilog -force -mode synth_stub $stub
        close_design
        if {$curDesign ne ""} { current_design $curDesign }
        puts "INFO: Generated stub for $ipTop from DCP"
    }
}

export_ip_user_files -of_objects [get_files $bdFile] -no_script -sync -force

# -----------------------------------------------------------------------
# 把所有 OOC IP 的 stub 文件持久化到 projPath/ip_stubs/，
# 避免依赖 .Xil/realtime/（在新 Vivado session 启动后会为空）。
# 3_synth.tcl 会从这里 read_verilog，确保顶层综合器能找到黑盒定义。
# -----------------------------------------------------------------------
set _stub_persist_dir [file normalize "$projPath/ip_stubs"]
file mkdir $_stub_persist_dir
set _xil_root [file normalize "$projPath/../../.Xil"]
set _bd_ip_dir_2bd [file normalize "$bdDir/$bdName/ip"]
foreach _xci [glob -nocomplain "$_bd_ip_dir_2bd/*/*.xci"] {
    set _ipn [file rootname [file tail $_xci]]
    set _dst  [file normalize "$_stub_persist_dir/${_ipn}_stub.v"]
    if {[file exists $_dst]} { continue }
    # 先找 .Xil/realtime 里由 export_ip_user_files 写入的 stub
    set _cands [glob -nocomplain "$_xil_root/Vivado-*/realtime/${_ipn}_stub.v"]
    set _best ""
    set _best_t 0
    foreach _c $_cands {
        set _t [file mtime $_c]
        if {$_t > $_best_t} { set _best_t $_t; set _best $_c }
    }
    if {$_best ne ""} {
        file copy -force $_best $_dst
        puts "INFO: \[2_bd\] stub persisted: $_ipn"
    }
}

# 确保 chip.xdc 已在 fileset（chip_timing.xdc 只走 reload_xdc 的 -unmanaged 路径）
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/chip/*.xdc"]] {
    if {[string match "*chip_timing*" $xdcFile]} { continue }
    if {[llength [get_files -quiet $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

puts "INFO: 2_bd complete — BD validated, OOC synthesized, wrapper ready."
