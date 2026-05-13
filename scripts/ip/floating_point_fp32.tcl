# FP32 乘/加 IP（xilinx.com:ip:floating_point），供 rtl/vpu/fp_mac_array.sv 例化为一维阵列。
# 在已打开的工程内调用：fp32_mac_ips_create
#
# 与 fp_mac_array.sv 中 localparam 对齐：MULT_TOTAL_LATENCY = FP32_MULT_LAT + FP32_ADD_LAT
# 修改 Latency 后请同步 rtl/vpu/fp_mac_array.sv 顶部 localparam，并用 report_timing 核对对齐。

proc fp32_mac_ips_resolve_fp_ip {} {
    set defs [get_ipdefs -filter {NAME == floating_point}]
    if {[llength $defs] == 0} {
        error "IP floating_point not found. Use a Vivado edition that includes Floating-Point operator."
    }
    foreach v {7.2 7.1 7.0} {
        foreach d $defs {
            if {[regexp ":floating_point:${v}$" $d]} {
                puts "Info: Using floating_point IP: $d"
                return $d
            }
        }
    }
    set chosen [lindex [lsort $defs] end]
    puts "Info: Using floating_point IP (fallback newest): $chosen"
    return $chosen
}

proc fp32_mac_ips_create {} {
    if {[llength [info commands create_ip]] == 0} {
        error "fp32_mac_ips_create must be sourced in Vivado Tcl (project open)."
    }
    set vlnv [fp32_mac_ips_resolve_fp_ip]

    # Vivado 2024.x / floating_point 7.1：无 B_Precision_Type；加法用 Add_Subtract + Add_Sub_Value。
    # CONFIG.C_Latency 由工具推导（Multiply NonBlocking 典型 8；Add 典型 11），须与 fp_mac_array.sv 对齐。
    if {[llength [get_ips -quiet fp32_mult_lane]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_mult_lane
        set_property -dict [list \
            CONFIG.Operation_Type {Multiply} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
            CONFIG.Has_ARESETn {true} \
        ] [get_ips fp32_mult_lane]
        puts "Info: Created IP fp32_mult_lane (FP32 multiply), C_Latency=[get_property CONFIG.C_Latency [get_ips fp32_mult_lane]]."
    } else {
        puts "Info: IP fp32_mult_lane already exists, skipping create."
    }

    if {[llength [get_ips -quiet fp32_add_lane]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_add_lane
        set_property -dict [list \
            CONFIG.Operation_Type {Add_Subtract} \
            CONFIG.Add_Sub_Value {Add} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
            CONFIG.Has_ARESETn {true} \
        ] [get_ips fp32_add_lane]
        puts "Info: Created IP fp32_add_lane (FP32 add via Add_Subtract), C_Latency=[get_property CONFIG.C_Latency [get_ips fp32_add_lane]]."
    } else {
        puts "Info: IP fp32_add_lane already exists, skipping create."
    }

    if {[llength [get_ips -quiet fp32_compare_leq]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_compare_leq
        set_property -dict [list \
            CONFIG.Operation_Type {Compare} \
            CONFIG.C_Compare_Operation {Less_Than_Or_Equal} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
        ] [get_ips fp32_compare_leq]
        puts "Info: Created IP fp32_compare_leq (FP32 compare <=)."
    } else {
        puts "Info: IP fp32_compare_leq already exists, skipping create."
    }

    if {[llength [get_ips -quiet fp32_to_fixed8]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_to_fixed8
        set_property -dict [list \
            CONFIG.Operation_Type {Float_to_fixed} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
        ] [get_ips fp32_to_fixed8]
        puts "Info: Created IP fp32_to_fixed8 (FP32 → Fixed, default 32-bit)."
    } else {
        puts "Info: IP fp32_to_fixed8 already exists, skipping create."
    }

    if {[llength [get_ips -quiet fixed32_to_fp32]] == 0} {
        create_ip -vlnv $vlnv -module_name fixed32_to_fp32
        set_property -dict [list \
            CONFIG.Operation_Type {Fixed_to_float} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
        ] [get_ips fixed32_to_fp32]
        puts "Info: Created IP fixed32_to_fp32 (Fixed → FP32, default 32-bit)."
    } else {
        puts "Info: IP fixed32_to_fp32 already exists, skipping create."
    }

    foreach ipname {fp32_mult_lane fp32_add_lane fp32_compare_leq fp32_to_fixed8 fixed32_to_fp32} {
        generate_target all [get_ips $ipname]
    }
}
