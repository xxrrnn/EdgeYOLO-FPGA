`timescale 1ns / 1ps
//==============================================================================
// fp32_mac_array: FP32 MAC 阵列（res = a*b + c）
//==============================================================================
// 通过 Xilinx floating_point IP 实现：FP32 * FP32 + FP32 → FP32
// 使用 FP_CORE_NUM 个并行 MAC 单元（乘法 + 加法流水线）
//==============================================================================

module fp32_mac_array #(
    parameter FP_CORE_NUM = 32,
    parameter FP_WIDTH = 32
)(
    input  wire                              clk,
    input  wire                              fp_array_tvalid,
    output wire                              fp_array_tready,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0]   a_tdata,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0]   b_tdata,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0]   c_tdata,
    output wire [FP_CORE_NUM*FP_WIDTH-1:0]   res,
    output wire                              res_tvalid
);

    assign fp_array_tready = 1'b1;

    wire [FP_CORE_NUM-1:0] mult_tvalid_arr;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] mult_result;
    wire [FP_CORE_NUM-1:0] add_tvalid_arr;

    genvar i;
    generate
        for (i = 0; i < FP_CORE_NUM; i = i + 1) begin: FP32_MAC_LANE
            // 乘法：a * b
            fp32_mult_lane fp32_mult_inst (
                .aclk(clk),
                .s_axis_a_tvalid(fp_array_tvalid),
                .s_axis_a_tdata(a_tdata[i*FP_WIDTH +: FP_WIDTH]),
                .s_axis_b_tvalid(fp_array_tvalid),
                .s_axis_b_tdata(b_tdata[i*FP_WIDTH +: FP_WIDTH]),
                .m_axis_result_tvalid(mult_tvalid_arr[i]),
                .m_axis_result_tdata(mult_result[i*FP_WIDTH +: FP_WIDTH])
            );

            // 加法：(a*b) + c
            fp32_add_lane fp32_add_inst (
                .aclk(clk),
                .s_axis_a_tvalid(mult_tvalid_arr[i]),
                .s_axis_a_tdata(mult_result[i*FP_WIDTH +: FP_WIDTH]),
                .s_axis_b_tvalid(mult_tvalid_arr[i]),
                .s_axis_b_tdata(c_tdata[i*FP_WIDTH +: FP_WIDTH]),
                .m_axis_result_tvalid(add_tvalid_arr[i]),
                .m_axis_result_tdata(res[i*FP_WIDTH +: FP_WIDTH])
            );
        end
    endgenerate

    assign res_tvalid = add_tvalid_arr[0];

endmodule
