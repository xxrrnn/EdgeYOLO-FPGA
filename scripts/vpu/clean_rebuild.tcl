# 清理并重建 VPU Block Design
# 用于解决模块引用缓存问题

set thisScriptDir [file dirname [file normalize [info script]]]

if {![info exists ScriptDir]} {
    source [file normalize "$thisScriptDir/config.tcl"]
}

# 打开已存在的工程
if {[llength [get_projects -quiet]] == 0} {
    open_project [file normalize "$projectDir/$projectName.xpr"]
}

puts "=========================================="
puts "Step 1: 清理旧的 IP 状态"
puts "=========================================="

# 重置 IP 状态
set bdFile [file normalize "$bdDir/$bdName/$bdName.bd"]
if {[file exists $bdFile]} {
    if {[llength [get_files -quiet $bdFile]] != 0} {
        remove_files $bdFile
    }
}

# 删除生成的文件
if {[file exists [file dirname $bdFile]]} {
    puts "Removing BD directory: [file dirname $bdFile]"
    file delete -force [file dirname $bdFile]
}

# 清理 IP 缓存
catch {delete_ip_run -quiet [get_runs ${bdName}_*]}

puts "=========================================="
puts "Step 2: 强制刷新 RTL 文件索引"
puts "=========================================="

# 移除所有 VPU RTL 文件
set vpuRtlFiles {}
foreach pattern {*.v *.sv */*.v */*.sv} {
    foreach f [glob -nocomplain [file normalize "$vpuRtlDir/$pattern"]] {
        if {[regexp {\.bak$} $f]} {
            continue
        }
        if {[regexp {(tb_.*|.*_v2)\.(v|sv)$} [file tail $f]]} {
            continue
        }
        lappend vpuRtlFiles $f
        catch {remove_files -quiet $f}
    }
}

# 重新添加 RTL 文件
puts "Re-adding [llength $vpuRtlFiles] RTL files:"
foreach f $vpuRtlFiles {
    puts "  + [file tail $f]"
}
add_files -norecurse $vpuRtlFiles
set_property include_dirs [list $vpuRtlDir "$vpuRtlDir/fp array"] [current_fileset]

puts "=========================================="
puts "Step 3: 更新编译顺序和模块引用"
puts "=========================================="

update_compile_order -fileset sources_1
set_property top Global_VPU_top [current_fileset]
update_compile_order -fileset sources_1

# 强制更新所有模块引用
catch {update_module_reference -quiet [get_ips -quiet *]}

puts "=========================================="
puts "Step 4: 重新创建 Block Design"
puts "=========================================="

# 调用原始 BD 创建脚本（从 1_bd.tcl 的第 29 行开始）
create_bd_design -dir $bdDir $bdName

create_bd_cell -type module -reference Global_VPU_top vpu_0

source [file normalize "$ipBdDir/../xdma.tcl"]
source [file normalize "$ipBdDir/bram.tcl"]
source [file normalize "$scriptsDir/ip/bd/xdma_dcim_bram/cdma.tcl"]
source [file normalize "$ipBdDir/connect.tcl"]
source [file normalize "$ipBdDir/address.tcl"]

puts "=========================================="
puts "Step 5: 验证 Block Design"
puts "=========================================="

validate_bd_design
regenerate_bd_layout
save_bd_design

puts "=========================================="
puts "Step 6: 生成 Wrapper"
puts "=========================================="

make_wrapper -files [get_files $bdFile] -top
add_files -norecurse [file normalize "$bdDir/$bdName/hdl/${bdName}_wrapper.v"]
set_property top $topName [current_fileset]
update_compile_order -fileset sources_1

puts "=========================================="
puts "Step 7: 检查 IP 状态"
puts "=========================================="

report_ip_status -name ip_status
catch {update_module_reference [get_ips -quiet *vpu_0*]}

# 添加约束文件
foreach xdcFile [glob -nocomplain [file normalize "$xdcDir/$bdName/*.xdc"]] {
    if {[llength [get_files -quiet -of_objects [get_filesets constrs_1] $xdcFile]] == 0} {
        add_files -fileset constrs_1 $xdcFile
    }
}

puts "=========================================="
puts "清理和重建完成！"
puts "=========================================="
puts "接下来你可以运行："
puts "  source scripts/vpu/3_synth.tcl"
puts "=========================================="
