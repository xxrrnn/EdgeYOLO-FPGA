module int32_2_fp32_array #(
    parameter integer FP_TRAN_NUM = 4
)(
    input  wire                             clk,
    input  wire                             s_axis_a_tvalid,
    input  wire [FP_TRAN_NUM*32-1:0]        s_axis_a_tdata,   // 输入：多个 int32 拼接
    output wire [FP_TRAN_NUM*32-1:0]        m_axis_result_tdata, // 输出：多个 fp32 拼接
    output wire                             m_axis_result_tvalid
);

    // 每个 core 的 valid 信号
    wire [FP_TRAN_NUM-1:0]                  core_out_valid;
    // 每个 core 的结果（32 位 fp32）
    wire [31:0]                             core_out_data [0:FP_TRAN_NUM-1];

    genvar i;
    generate
        for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin : GEN_CORES
            localparam integer BASE_IN  = i*32;
            localparam integer BASE_OUT = i*32;

            // 每个 core 实例化 int32 -> fp32 转换 IP
            int32_2_fp32 int2fp_inst (
                .aclk(clk),
                .s_axis_a_tvalid(s_axis_a_tvalid),
                .s_axis_a_tdata(s_axis_a_tdata[BASE_IN +: 32]),
                .m_axis_result_tvalid(core_out_valid[i]),
                .m_axis_result_tdata(core_out_data[i])
            );

            // 拼接输出
            assign m_axis_result_tdata[BASE_OUT +: 32] = core_out_data[i];
        end
    endgenerate

    // array 级 valid 输出：任意一个 core 输出有效就视为 valid
    assign m_axis_result_tvalid = |core_out_valid;

endmodule
