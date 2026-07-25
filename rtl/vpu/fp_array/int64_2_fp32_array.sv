`timescale 1ns/1ns

module int64_2_fp32_array #(
    parameter integer FP_TRAN_NUM = 4
)(
    input  wire                             clk,
    input  wire                             s_axis_a_tvalid,
    input  wire [FP_TRAN_NUM*64-1:0]        s_axis_a_tdata,
    output wire [FP_TRAN_NUM*32-1:0]        m_axis_result_tdata,
    output wire                             m_axis_result_tvalid
);

    wire [FP_TRAN_NUM-1:0] core_out_valid;
    wire [31:0]            core_out_data [0:FP_TRAN_NUM-1];

    genvar i;
    generate
        for (i = 0; i < FP_TRAN_NUM; i = i + 1) begin : GEN_CORES
            localparam integer BASE_IN  = i * 64;
            localparam integer BASE_OUT = i * 32;

            int64_2_fp32 int2fp_inst (
                .aclk(clk),
                .s_axis_a_tvalid(s_axis_a_tvalid),
                .s_axis_a_tdata(s_axis_a_tdata[BASE_IN +: 64]),
                .m_axis_result_tvalid(core_out_valid[i]),
                .m_axis_result_tdata(core_out_data[i])
            );

            assign m_axis_result_tdata[BASE_OUT +: 32] = core_out_data[i];
        end
    endgenerate

    // All converter instances have the same fixed latency. Lane 0 is the
    // transaction valid; reducing the vector with OR could expose stale data
    // if a lane ever became misconfigured or desynchronized.
    assign m_axis_result_tvalid = core_out_valid[0];

`ifdef SIMULATION
    always @(posedge clk) begin
        if ((|core_out_valid) && (core_out_valid != {FP_TRAN_NUM{core_out_valid[0]}}))
            $error("int64_2_fp32_array converter valid lanes are not synchronized: %b", core_out_valid);
    end
`endif

endmodule
