module fp16_2_int8_array #(
    parameter integer FP_TRAN_NUM    = 4
)(
    input  wire                             clk,

    // single valid/ready wires for the whole array
    input  wire                             s_axis_a_tvalid,

    // concatenated input data: FP_TRAN_NUM * 16 bits
    input  wire [FP_TRAN_NUM*16-1:0]        s_axis_a_tdata,

    // concatenated outputs: FP_TRAN_NUM * 16 bits (每个 core 的结果被补全/截断到 16)
    output wire [FP_TRAN_NUM*8-1:0]        m_axis_result_tdata,
    output wire                             m_axis_result_tvalid
);

    // per-core wires
    wire [FP_TRAN_NUM-1:0]                  core_out_valid;
    // per-core raw outputs with parameter宽度
    wire [8-1:0]               core_out_data [0:FP_TRAN_NUM-1];

    genvar i;
    generate
        for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin : GEN_CORES
            localparam integer BASE_IN  = i*16;
            localparam integer BASE_OUT = i*8;

            // instantiate the core; 假设 core 的结果宽度是 8
            fp16_2_int8 your_instance_name (
                .aclk(clk),                                  // input wire aclk
                .s_axis_a_tvalid(s_axis_a_tvalid),            // input wire s_axis_a_tvalid
                .s_axis_a_tdata(s_axis_a_tdata[BASE_IN +: 16]),              // input wire [15 : 0] s_axis_a_tdata
                .m_axis_result_tvalid(core_out_valid[i]),  // output wire m_axis_result_tvalid
                .m_axis_result_tdata(core_out_data[i])    // output wire [7 : 0] m_axis_result_tdata
            );

            assign m_axis_result_tdata[BASE_OUT +: 8] =
                       core_out_data[i];
        end
    endgenerate

    // array-level ready: upstream只在所有 core 都 ready 时才可发送（AND）
//    assign s_axis_a_tready = &core_a_ready;

    // array-level valid: 任一 core 有结果即表示有有效输出（OR）
    assign m_axis_result_tvalid = |core_out_valid;

endmodule
