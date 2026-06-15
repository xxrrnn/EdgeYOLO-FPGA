`timescale 1ns / 1ns
//==============================================================================
// fp32_2_int16_array: FP32 → INT16 转换阵列
//==============================================================================
// 通过 Xilinx floating_point IP (fp32_to_int16) 实现：FP32 → signed INT16。
// 使用 FP_TRAN_NUM 个并行转换器。
//==============================================================================

module fp32_2_int16_array #(
    parameter FP_TRAN_NUM = 4
)(
    input  wire                              clk,
    input  wire                              s_axis_a_tvalid,
    input  wire [FP_TRAN_NUM*32-1:0]         s_axis_a_tdata,
    output wire [FP_TRAN_NUM*16-1:0]         m_axis_result_tdata,
    output wire                              m_axis_result_tvalid
);

    wire [FP_TRAN_NUM-1:0] tvalid_arr;

    genvar i;
    generate
`ifdef FP32_2_INT16_BEHAVIORAL
        begin : GEN_BEHAVIORAL
            logic [FP_TRAN_NUM*16-1:0] result_reg;
            logic valid_reg;
            for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin: FP32_TO_INT16_BEH_LANE
                always_ff @(posedge clk) begin
                    shortreal fp_value;
                    int rounded_value;
                    fp_value = $bitstoshortreal(s_axis_a_tdata[i*32 +: 32]);
                    rounded_value = $rtoi((fp_value >= 0.0) ? (fp_value + 0.5) : (fp_value - 0.5));
                    if (rounded_value > 32767)
                        result_reg[i*16 +: 16] <= 16'sh7fff;
                    else if (rounded_value < -32768)
                        result_reg[i*16 +: 16] <= 16'sh8000;
                    else
                        result_reg[i*16 +: 16] <= rounded_value[15:0];
                end
            end
            always_ff @(posedge clk) begin
                valid_reg <= s_axis_a_tvalid;
            end
            assign m_axis_result_tdata = result_reg;
            assign m_axis_result_tvalid = valid_reg;
        end
`else
        begin : GEN_IP
            for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin: FP32_TO_INT16_LANE
                fp32_to_int16 fp32_to_int16_inst (
                    .aclk(clk),
                    .s_axis_a_tvalid(s_axis_a_tvalid),
                    .s_axis_a_tdata(s_axis_a_tdata[i*32 +: 32]),
                    .m_axis_result_tvalid(tvalid_arr[i]),
                    .m_axis_result_tdata(m_axis_result_tdata[i*16 +: 16])
                );
            end
            assign m_axis_result_tvalid = &tvalid_arr;
        end
`endif
    endgenerate

endmodule
