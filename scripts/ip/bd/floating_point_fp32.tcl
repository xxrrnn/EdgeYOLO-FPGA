# FP32 乘/加 IP（xilinx.com:ip:floating_point），供 rtl/vpu_yolov11/fp_mac_array.sv 例化为一维阵列。
# 在已打开的工程内调用：fp32_mac_ips_create
#
# 与 fp_mac_array.sv 中 localparam 对齐：MULT_TOTAL_LATENCY = FP32_MULT_LAT + FP32_ADD_LAT
# 修改 Latency 后请同步 rtl/vpu_yolov11/fp_mac_array.sv 顶部 localparam，并用 report_timing 核对对齐。

proc fp32_mac_ips_resolve_fp_ip {} {
    set defs [get_ipdefs -filter {NAME == floating_point}]
    if {[llength $defs] == 0} {
        error "IP floating_point not found. Use a Vivado edition that includes Floating-Point operator."
    }
    set chosen {}
    foreach v {7.2 7.1 7.0} {
        set hit [get_ipdefs -filter "NAME == floating_point && VERSION == $v"]
        if {[llength $hit] > 0} {
            set chosen [lindex $hit 0]
            puts "Info: Using floating_point IP: $chosen"
            return $chosen
        }
    }
    set chosen [lindex [lsort $defs] end]
    puts "Info: Using floating_point IP: $chosen"
    return $chosen
}

proc fp32_mac_ips_create {} {
    if {[llength [info commands create_ip]] == 0} {
        error "fp32_mac_ips_create must be sourced in Vivado Tcl (project open)."
    }
    set vlnv [fp32_mac_ips_resolve_fp_ip]

    if {[llength [get_ips -quiet fp32_mult_lane]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_mult_lane
        set_property -dict [list \
            CONFIG.Component_Name {fp32_mult_lane} \
            CONFIG.Operation_Type {Multiply} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.B_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
        ] [get_ips fp32_mult_lane]
        puts "Info: Created IP fp32_mult_lane (FP32 multiply)."
    } else {
        puts "Info: IP fp32_mult_lane already exists, skipping create."
    }

    if {[llength [get_ips -quiet fp32_add_lane]] == 0} {
        create_ip -vlnv $vlnv -module_name fp32_add_lane
        set_property -dict [list \
            CONFIG.Component_Name {fp32_add_lane} \
            CONFIG.Operation_Type {Add} \
            CONFIG.A_Precision_Type {Single} \
            CONFIG.B_Precision_Type {Single} \
            CONFIG.Result_Precision_Type {Single} \
            CONFIG.Flow_Control {NonBlocking} \
        ] [get_ips fp32_add_lane]
        puts "Info: Created IP fp32_add_lane (FP32 add)."
    } else {
        puts "Info: IP fp32_add_lane already exists, skipping create."
    }

    generate_target {instantiation_template synthesis} [get_ips fp32_mult_lane fp32_add_lane]
}
