`timescale 1ns / 1ps
//==============================================================================
// fp32_add_array: FP32 加法阵列
//==============================================================================
// 通过 Xilinx floating_point IP 实现：FP32 + FP32 → FP32
// 使用 FP_CORE_NUM 个并行加法器
//==============================================================================

module fp32_add_array #(
    parameter FP_CORE_NUM = 32,
    parameter FP_WIDTH = 32
)(
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              fp_array_tvalid,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0]   a_tdata,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0]   b_tdata,
    output wire [FP_CORE_NUM*FP_WIDTH-1:0]   res,
    output wire                              res_tvalid
);

    wire [FP_CORE_NUM-1:0] tvalid_arr;

    genvar i;
    generate
        for (i = 0; i < FP_CORE_NUM; i = i + 1) begin: FP32_ADD_LANE
            fp32_add_lane fp32_add_lane_inst (
                .aclk(clk),
                .aresetn(rst_n),
                .s_axis_a_tvalid(fp_array_tvalid),
                .s_axis_a_tdata(a_tdata[i*FP_WIDTH +: FP_WIDTH]),
                .s_axis_b_tvalid(fp_array_tvalid),
                .s_axis_b_tdata(b_tdata[i*FP_WIDTH +: FP_WIDTH]),
                .m_axis_result_tvalid(tvalid_arr[i]),
                .m_axis_result_tdata(res[i*FP_WIDTH +: FP_WIDTH])
            );
        end
    endgenerate

    assign res_tvalid = tvalid_arr[0];

endmodule
