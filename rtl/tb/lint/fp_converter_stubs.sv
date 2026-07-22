`timescale 1ns/1ns

// Lint-only declarations for generated floating-point IP. Synthesis uses
// the Xilinx IP definitions produced by scripts/ip/floating_point_fp32.tcl.
module int32_2_fp32 (
    input  wire        aclk,
    input  wire        s_axis_a_tvalid,
    input  wire [31:0] s_axis_a_tdata,
    output wire        m_axis_result_tvalid,
    output wire [31:0] m_axis_result_tdata
);
    assign m_axis_result_tvalid = s_axis_a_tvalid;
    assign m_axis_result_tdata = s_axis_a_tdata;
endmodule

module int64_2_fp32 (
    input  wire        aclk,
    input  wire        s_axis_a_tvalid,
    input  wire [63:0] s_axis_a_tdata,
    output wire        m_axis_result_tvalid,
    output wire [31:0] m_axis_result_tdata
);
    assign m_axis_result_tvalid = s_axis_a_tvalid;
    assign m_axis_result_tdata = s_axis_a_tdata[31:0];
endmodule

module fp32_2_fp16 (
    input  wire        aclk,
    input  wire        s_axis_a_tvalid,
    input  wire [31:0] s_axis_a_tdata,
    output wire        m_axis_result_tvalid,
    output wire [15:0] m_axis_result_tdata
);
    assign m_axis_result_tvalid = s_axis_a_tvalid;
    assign m_axis_result_tdata = s_axis_a_tdata[15:0];
endmodule
