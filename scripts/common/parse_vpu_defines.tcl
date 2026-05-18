#==============================================================================
# parse_vpu_defines.tcl
#
# 解析 vpu_defines.vh 头文件，提取参数供 Tcl 脚本使用。
# 支持简单的 `define 语法和基本的算术表达式。
#
# 用法：
#   source parse_vpu_defines.tcl
#   parse_vpu_defines $path_to_vpu_defines_vh
#   
#   # 之后可以使用全局变量访问参数
#   puts $::VPU_BANDWIDTH        ;# 256
#   puts $::GB_SIZE_BYTES        ;# 131072
#==============================================================================

namespace eval vpu_params {
    variable params
    array set params {}
}

#------------------------------------------------------------------------------
# 解析 vpu_defines.vh 文件
#------------------------------------------------------------------------------
proc parse_vpu_defines {filepath} {
    if {![file exists $filepath]} {
        puts "ERROR: Cannot find vpu_defines.vh at: $filepath"
        return 0
    }
    
    set fp [open $filepath r]
    set content [read $fp]
    close $fp
    
    # 清空之前的参数
    array unset ::vpu_params::params
    array set ::vpu_params::params {}
    
    # 第一遍：提取所有 `define
    set lines [split $content "\n"]
    foreach line $lines {
        # 跳过注释和空行
        set line [string trim $line]
        if {$line eq "" || [string match "//*" $line]} {
            continue
        }
        
        # 匹配 `define NAME VALUE 或 `define NAME (expr)
        if {[regexp {^`define\s+(\w+)\s+(.+)$} $line -> name value]} {
            # 去除行尾注释
            set value [regsub {//.*$} $value ""]
            set value [string trim $value]
            
            # 存储原始值（可能包含其他宏引用）
            set ::vpu_params::params($name) $value
        }
    }
    
    # 第二遍：解析表达式，替换宏引用
    foreach {name value} [array get ::vpu_params::params] {
        set resolved [resolve_value $value]
        set ::vpu_params::params($name) $resolved
        
        # 同时设置为全局变量，方便直接使用
        set ::$name $resolved
    }
    
    puts "INFO: Parsed [array size ::vpu_params::params] parameters from vpu_defines.vh"
    return 1
}

#------------------------------------------------------------------------------
# 解析值，替换宏引用并计算表达式
#------------------------------------------------------------------------------
proc resolve_value {value} {
    # 移除可能的括号
    set value [string trim $value "()"]
    
    # 替换十六进制格式 32'hXXXX -> 0xXXXX，同时移除数字中的下划线
    set value [regsub -all {(\d+)'h([0-9a-fA-F_]+)} $value {[string map {"_" ""} "0x\2"]}]
    set value [subst $value]
    
    # 替换宏引用 `NAME -> $::vpu_params::params(NAME)
    # 注意：不要移除宏名中的下划线！
    while {[regexp {`([A-Z_][A-Z0-9_]*)} $value -> macro_name]} {
        if {[info exists ::vpu_params::params($macro_name)]} {
            set macro_val $::vpu_params::params($macro_name)
            # 递归解析
            set macro_val [resolve_value $macro_val]
            set value [regsub "`$macro_name" $value $macro_val]
        } else {
            puts "WARNING: Undefined macro: $macro_name"
            break
        }
    }
    
    # 替换 $clog2(x) -> [clog2 x]
    set value [regsub -all {\$clog2\(([^)]+)\)} $value {[clog2 \1]}]
    
    # 移除表达式中数字的下划线（如 1_048_576 -> 1048576）
    set value [regsub -all {(\d)_(\d)} $value {\1\2}]
    
    # 尝试计算表达式
    if {[catch {expr $value} result]} {
        # 如果计算失败，返回原始值
        return $value
    }
    
    return $result
}

#------------------------------------------------------------------------------
# 计算 clog2 (向上取整的 log2)
#------------------------------------------------------------------------------
proc clog2 {n} {
    if {$n <= 1} {
        return 0
    }
    set result 0
    set n [expr {$n - 1}]
    while {$n > 0} {
        set n [expr {$n >> 1}]
        incr result
    }
    return $result
}

#------------------------------------------------------------------------------
# 获取参数值
#------------------------------------------------------------------------------
proc get_vpu_param {name {default ""}} {
    if {[info exists ::vpu_params::params($name)]} {
        return $::vpu_params::params($name)
    }
    if {$default ne ""} {
        return $default
    }
    puts "WARNING: Parameter $name not found"
    return 0
}

#------------------------------------------------------------------------------
# 打印所有参数（调试用）
#------------------------------------------------------------------------------
proc print_vpu_params {} {
    puts "=============================================="
    puts "VPU Parameters from vpu_defines.vh"
    puts "=============================================="
    foreach name [lsort [array names ::vpu_params::params]] {
        puts [format "  %-30s = %s" $name $::vpu_params::params($name)]
    }
    puts "=============================================="
}

#------------------------------------------------------------------------------
# 将字节数转换为 Vivado 地址范围格式
#------------------------------------------------------------------------------
proc bytes_to_range {bytes} {
    if {$bytes >= 1073741824} {
        return "[expr {$bytes / 1073741824}]G"
    } elseif {$bytes >= 1048576} {
        return "[expr {$bytes / 1048576}]M"
    } elseif {$bytes >= 1024} {
        return "[expr {$bytes / 1024}]K"
    } else {
        return $bytes
    }
}

#------------------------------------------------------------------------------
# 自动查找并解析 vpu_defines.vh
# 从当前脚本位置向上查找 rtl/vpu/vpu_defines.vh
#------------------------------------------------------------------------------
proc auto_parse_vpu_defines {} {
    # 尝试多个可能的路径
    set script_dir [file dirname [info script]]
    set possible_paths [list \
        [file join $script_dir "../../rtl/vpu/vpu_defines.vh"] \
        [file join $script_dir "../../../rtl/vpu/vpu_defines.vh"] \
        [file join $script_dir "../../../../rtl/vpu/vpu_defines.vh"] \
    ]
    
    # 如果在 Vivado 中运行，也尝试从项目根目录查找
    if {[info exists ::origin_dir]} {
        lappend possible_paths [file join $::origin_dir "rtl/vpu/vpu_defines.vh"]
    }
    
    foreach path $possible_paths {
        set norm_path [file normalize $path]
        if {[file exists $norm_path]} {
            puts "INFO: Found vpu_defines.vh at: $norm_path"
            return [parse_vpu_defines $norm_path]
        }
    }
    
    puts "ERROR: Cannot find vpu_defines.vh"
    return 0
}
