`timescale 1ns/1ps

module fp_mac_array #( 
    parameter integer FP_CORE_NUM = 4,
    parameter integer FP_WIDTH    = 32   // 可以是16或32
)( 
    input  wire                     clk,

    // single valid signals for the whole array
    input  wire                     fp_array_tvalid,

    // single ready outputs for the whole array (derived from cores)
    output wire                     fp_array_tready,

    // concatenated data buses
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0] a_tdata,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0] b_tdata,
    input  wire [FP_CORE_NUM*FP_WIDTH-1:0] c_tdata,

    // concatenated outputs
    output wire [FP_CORE_NUM*FP_WIDTH-1:0] res,
    output wire                            res_tvalid
);

    // per-core wires
    wire [FP_CORE_NUM-1:0] s_axis_a_tready;
    wire [FP_CORE_NUM-1:0] s_axis_b_tready;
    wire [FP_CORE_NUM-1:0] s_axis_c_tready;
    wire [FP_CORE_NUM-1:0] m_axis_result_tvalid;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] m_axis_result_tdata_concat;

    wire a_tready;
    wire b_tready;
    wire c_tready;

    genvar i;
    generate
        for (i = 0; i < FP_CORE_NUM; i = i + 1) begin : GEN_FP_MAC
            localparam integer BASE = i * FP_WIDTH;

            if (FP_WIDTH == 16) begin : GEN_FP16
                fp16_mac fp_mac_inst (
                    .aclk(clk),

                    .s_axis_a_tvalid(fp_array_tvalid),
                    .s_axis_a_tready(s_axis_a_tready[i]),
                    .s_axis_a_tdata(a_tdata[BASE +: 16]),

                    .s_axis_b_tvalid(fp_array_tvalid),
                    .s_axis_b_tready(s_axis_b_tready[i]),
                    .s_axis_b_tdata(b_tdata[BASE +: 16]),

                    .s_axis_c_tvalid(fp_array_tvalid),
                    .s_axis_c_tready(s_axis_c_tready[i]),
                    .s_axis_c_tdata(c_tdata[BASE +: 16]),

                    .m_axis_result_tvalid(m_axis_result_tvalid[i]),
                    .m_axis_result_tready(1'b1),
                    .m_axis_result_tdata(m_axis_result_tdata_concat[BASE +: 16])
                );
            end else if (FP_WIDTH == 32) begin : GEN_FP32
                fp32_mac fp_mac_inst (
                    .aclk(clk),

                    .s_axis_a_tvalid(fp_array_tvalid),
                    .s_axis_a_tready(s_axis_a_tready[i]),
                    .s_axis_a_tdata(a_tdata[BASE +: 32]),

                    .s_axis_b_tvalid(fp_array_tvalid),
                    .s_axis_b_tready(s_axis_b_tready[i]),
                    .s_axis_b_tdata(b_tdata[BASE +: 32]),

                    .s_axis_c_tvalid(fp_array_tvalid),
                    .s_axis_c_tready(s_axis_c_tready[i]),
                    .s_axis_c_tdata(c_tdata[BASE +: 32]),

                    .m_axis_result_tvalid(m_axis_result_tvalid[i]),
                    .m_axis_result_tready(1'b1),
                    .m_axis_result_tdata(m_axis_result_tdata_concat[BASE +: 32])
                );
            end else begin
                initial begin
                    $error("Unsupported FP_WIDTH = %0d (must be 16 or 32)", FP_WIDTH);
                end
            end
        end
    endgenerate

    // derive array-level ready
    assign a_tready = &s_axis_a_tready;
    assign b_tready = &s_axis_b_tready;
    assign c_tready = &s_axis_c_tready;

    assign fp_array_tready = a_tready && b_tready && c_tready;

    // collect per-core outputs
    assign res = m_axis_result_tdata_concat;

    // any core valid triggers overall valid
    assign res_tvalid = |m_axis_result_tvalid;

endmodule
