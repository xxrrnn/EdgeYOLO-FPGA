`timescale 1ns / 1ps
//==============================================================================
// fp32_2_int8_array: FP32 → INT8 转换阵列
//==============================================================================
// 通过 Xilinx floating_point IP (fp32_to_fixed8) 实现：FP32 → INT8
// IP 输出端口 m_axis_result_tdata 为 8-bit
// 使用 FP_TRAN_NUM 个并行转换器
//==============================================================================

module fp32_2_int8_array #(
    parameter FP_TRAN_NUM = 8
)(
    input  wire                              clk,
    input  wire                              s_axis_a_tvalid,
    input  wire [FP_TRAN_NUM*32-1:0]         s_axis_a_tdata,
    output wire [FP_TRAN_NUM*8-1:0]          m_axis_result_tdata,
    output wire                              m_axis_result_tvalid
);

    wire [FP_TRAN_NUM-1:0] tvalid_arr;

    genvar i;
    generate
        for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin: FP32_TO_INT8_LANE
            fp32_to_int8 fp32_to_int8_inst (
                .aclk(clk),
                .s_axis_a_tvalid(s_axis_a_tvalid),
                .s_axis_a_tdata(s_axis_a_tdata[i*32 +: 32]),
                .m_axis_result_tvalid(tvalid_arr[i]),
                .m_axis_result_tdata(m_axis_result_tdata[i*8 +: 8])
            );
        end
    endgenerate

    assign m_axis_result_tvalid = tvalid_arr[0];

endmodule
