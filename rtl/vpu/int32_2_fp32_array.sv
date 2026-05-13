`timescale 1ns / 1ps
//==============================================================================
// int32_2_fp32_array: INT32 → FP32 转换阵列
//==============================================================================
// 通过 Xilinx floating_point IP 实现：Fixed(32,0) → FP32
// 使用 FP_TRAN_NUM 个并行转换器
//==============================================================================

module int32_2_fp32_array #(
    parameter FP_TRAN_NUM = 8
)(
    input  wire                              clk,
    input  wire                              s_axis_tvalid,
    input  wire [FP_TRAN_NUM*32-1:0]         s_axis_tdata,
    output wire                              m_axis_result_tvalid,
    output wire [FP_TRAN_NUM*32-1:0]         m_axis_result_tdata
);

    wire [FP_TRAN_NUM-1:0] tvalid_arr;

    genvar i;
    generate
        for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin: INT32_TO_FP32_LANE
            fixed32_to_fp32 fixed32_to_fp32_inst (
                .aclk(clk),
                .s_axis_a_tvalid(s_axis_tvalid),
                .s_axis_a_tdata(s_axis_tdata[i*32 +: 32]),
                .m_axis_result_tvalid(tvalid_arr[i]),
                .m_axis_result_tdata(m_axis_result_tdata[i*32 +: 32])
            );
        end
    endgenerate

    assign m_axis_result_tvalid = tvalid_arr[0];

endmodule
