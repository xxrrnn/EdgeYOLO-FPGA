module fp_add_array #(
    parameter integer FP_CORE_NUM = 4,
    parameter integer FP_WIDTH    = 16    // 16 或 32
)(
    input  wire                     clk,

    // 单一 valid 信号，表示整个阵列的输入有效
    input  wire                     fp_array_tvalid,

    // 拼接输入信号
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0] a_tdata,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0] b_tdata,

    // 拼接输出信号
    output wire [FP_CORE_NUM*FP_WIDTH-1:0] res,
    output wire                            res_tvalid
);

    wire [FP_CORE_NUM-1:0]        m_axis_result_tvalid;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] m_axis_result_tdata_concat;

    genvar i;
    generate
        if (FP_WIDTH == 16) begin : GEN_FP16
            for (i = 0; i < FP_CORE_NUM; i = i + 1) begin : GEN_FP16_ADD
                localparam integer BASE = i * 16;
                fp16_add fp16_add_inst (
                    .aclk(clk),
                    .s_axis_a_tvalid(fp_array_tvalid),
                    .s_axis_a_tdata(a_tdata[BASE +: 16]),
                    .s_axis_b_tvalid(fp_array_tvalid),
                    .s_axis_b_tdata(b_tdata[BASE +: 16]),
                    .m_axis_result_tvalid(m_axis_result_tvalid[i]),
                    .m_axis_result_tdata(m_axis_result_tdata_concat[BASE +: 16])
                );
            end
        end else if (FP_WIDTH == 32) begin : GEN_FP32
            for (i = 0; i < FP_CORE_NUM; i = i + 1) begin : GEN_FP32_ADD
                localparam integer BASE = i * 32;
                fp32_add fp32_add_inst (
                    .aclk(clk),
                    .s_axis_a_tvalid(fp_array_tvalid),
                    .s_axis_a_tdata(a_tdata[BASE +: 32]),
                    .s_axis_b_tvalid(fp_array_tvalid),
                    .s_axis_b_tdata(b_tdata[BASE +: 32]),
                    .m_axis_result_tvalid(m_axis_result_tvalid[i]),
                    .m_axis_result_tdata(m_axis_result_tdata_concat[BASE +: 32])
                );
            end
        end else begin : GEN_UNSUPPORTED
            initial $error("Unsupported FP_WIDTH: %0d (only 16 or 32 allowed)", FP_WIDTH);
        end
    endgenerate

    // 聚合结果
    assign res        = m_axis_result_tdata_concat;
    assign res_tvalid = |m_axis_result_tvalid;

endmodule
