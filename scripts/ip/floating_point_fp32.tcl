# FP32/FP16 乘/加 IP（xilinx.com:ip:floating_point），供 rtl/vpu/fp array/ 模块例化。
# 在已打开的工程内调用：fp32_mac_ips_create
#
# 与 fp_mac_array.v 中 localparam 对齐：MULT_TOTAL_LATENCY = FP32_MULT_LAT + FP32_ADD_LAT
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

    # ============================================================================
    # FP32 MAC (Fused Multiply-Add): a*b+c
    # 使用 Add_Sub_Value=Add 来固定为加法操作，避免需要 operation 端口
    # ============================================================================
    if {[llength [get_ips -quiet fp32_mac]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_mac
        set_property -dict [list \
            CONFIG.Operation_Type {FMA} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.C_A_Exponent_Width {8} \
            CONFIG.C_A_Fraction_Width {24} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.C_Result_Exponent_Width {8} \
            CONFIG.C_Result_Fraction_Width {24} \
            CONFIG.Flow_Control {Blocking} \
            CONFIG.Has_ARESETn {false} \
            CONFIG.Add_Sub_Value {Add} \
        ] [get_ips fp32_mac]
        puts "Info: Created IP fp32_mac (FP32 FMA), C_Latency=[get_property CONFIG.C_Latency [get_ips fp32_mac]]."
    } else {
        puts "Info: IP fp32_mac already exists, skipping create."
    }

    # ============================================================================
    # FP16 MAC (Fused Multiply-Add): a*b+c
    # ============================================================================
    if {[llength [get_ips -quiet fp16_mac]] == 0} {
        create_ip -vlnv $vlnv -module_name fp16_mac
        set_property -dict [list \
            CONFIG.Operation_Type {FMA} \
            CONFIG.A_Precision_Type {Half} \
            CONFIG.C_A_Exponent_Width {5} \
            CONFIG.C_A_Fraction_Width {11} \
            CONFIG.Result_Precision_Type {Half} \
            CONFIG.C_Result_Exponent_Width {5} \
            CONFIG.C_Result_Fraction_Width {11} \
            CONFIG.Flow_Control {Blocking} \
            CONFIG.Has_ARESETn {false} \
            CONFIG.Add_Sub_Value {Add} \
        ] [get_ips fp16_mac]
        puts "Info: Created IP fp16_mac (FP16 FMA), C_Latency=[get_property CONFIG.C_Latency [get_ips fp16_mac]]."
    } else {
        puts "Info: IP fp16_mac already exists, skipping create."
    }

    # ============================================================================
    # FP32 Add
    # ============================================================================
    if {[llength [get_ips -quiet fp32_add]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_add
        set_property -dict [list \
            CONFIG.Operation_Type {Add_Subtract} \
            CONFIG.Add_Sub_Value {Add} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
            CONFIG.Has_ARESETn {false} \
        ] [get_ips fp32_add]
        puts "Info: Created IP fp32_add (FP32 add), C_Latency=[get_property CONFIG.C_Latency [get_ips fp32_add]]."
    } else {
        puts "Info: IP fp32_add already exists, skipping create."
    }

    # ============================================================================
    # FP16 Add
    # ============================================================================
    if {[llength [get_ips -quiet fp16_add]] == 0} {
        create_ip -vlnv $vlnv -module_name fp16_add
        set_property -dict [list \
            CONFIG.Operation_Type {Add_Subtract} \
            CONFIG.Add_Sub_Value {Add} \
            CONFIG.A_Precision_Type {Half} \
            CONFIG.Result_Precision_Type {Half} \
            CONFIG.Flow_Control {NonBlocking} \
            CONFIG.Has_ARESETn {false} \
        ] [get_ips fp16_add]
        puts "Info: Created IP fp16_add (FP16 add), C_Latency=[get_property CONFIG.C_Latency [get_ips fp16_add]]."
    } else {
        puts "Info: IP fp16_add already exists, skipping create."
    }

    # ============================================================================
    # INT32 to FP32 (Fixed to Float)
    # ============================================================================
    if {[llength [get_ips -quiet int32_2_fp32]] == 0} {
        create_ip -vlnv $vlnv -module_name int32_2_fp32
        set_property -dict [list \
            CONFIG.Operation_Type {Fixed_to_float} \
            CONFIG.A_Precision_Type {Custom} \
            CONFIG.C_A_Exponent_Width {32} \
            CONFIG.C_A_Fraction_Width {0} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
            CONFIG.Has_ARESETn {false} \
        ] [get_ips int32_2_fp32]
        puts "Info: Created IP int32_2_fp32 (INT32 → FP32)."
    } else {
        puts "Info: IP int32_2_fp32 already exists, skipping create."
    }

    # ============================================================================
    # FP32 to FP16 (Float to Float conversion)
    # ============================================================================
    if {[llength [get_ips -quiet fp32_2_fp16]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_2_fp16
        set_property -dict [list \
            CONFIG.Operation_Type {Float_to_float} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Half} \
            CONFIG.Flow_Control {NonBlocking} \
            CONFIG.Has_ARESETn {false} \
        ] [get_ips fp32_2_fp16]
        puts "Info: Created IP fp32_2_fp16 (FP32 → FP16)."
    } else {
        puts "Info: IP fp32_2_fp16 already exists, skipping create."
    }

    # ============================================================================
    # FP16 to INT8 (Float to Fixed)
    # ============================================================================
    if {[llength [get_ips -quiet fp16_2_int8]] == 0} {
        create_ip -vlnv $vlnv -module_name fp16_2_int8
        set_property -dict [list \
            CONFIG.Operation_Type {Float_to_fixed} \
            CONFIG.A_Precision_Type {Half} \
            CONFIG.Result_Precision_Type {Custom} \
            CONFIG.C_Result_Exponent_Width {8} \
            CONFIG.C_Result_Fraction_Width {0} \
            CONFIG.Flow_Control {NonBlocking} \
            CONFIG.Has_ARESETn {false} \
        ] [get_ips fp16_2_int8]
        puts "Info: Created IP fp16_2_int8 (FP16 → INT8)."
    } else {
        puts "Info: IP fp16_2_int8 already exists, skipping create."
    }

    # ============================================================================
    # 保留原有的 IP（向后兼容）
    # ============================================================================
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

    if {[llength [get_ips -quiet fp32_to_int8]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_to_int8
        set_property -dict [list \
            CONFIG.Operation_Type {Float_to_fixed} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Custom} \
            CONFIG.C_Result_Exponent_Width {8} \
            CONFIG.C_Result_Fraction_Width {0} \
            CONFIG.Flow_Control {NonBlocking} \
        ] [get_ips fp32_to_int8]
        puts "Info: Created IP fp32_to_int8 (FP32 → INT8, signed 8-bit)."
    } else {
        puts "Info: IP fp32_to_int8 already exists, skipping create."
    }

    if {[llength [get_ips -quiet fp32_to_fixed8]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_to_fixed8
        set_property -dict [list \
            CONFIG.Operation_Type {Float_to_fixed} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Custom} \
            CONFIG.C_Result_Exponent_Width {8} \
            CONFIG.C_Result_Fraction_Width {0} \
            CONFIG.Flow_Control {NonBlocking} \
        ] [get_ips fp32_to_fixed8]
        puts "Info: Created IP fp32_to_fixed8 (FP32 → INT8, signed 8-bit, alias)."
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

    # ============================================================================
    # 生成所有 IP 的目标
    # ============================================================================
    set all_ips {
        fp32_mac fp16_mac fp32_add fp16_add 
        int32_2_fp32 fp32_2_fp16 fp16_2_int8
        fp32_mult_lane fp32_add_lane fp32_compare_leq fp32_to_int8 fp32_to_fixed8 fixed32_to_fp32
    }
    foreach ipname $all_ips {
        if {[llength [get_ips -quiet $ipname]] != 0} {
            generate_target all [get_ips $ipname]
        }
    }
}
