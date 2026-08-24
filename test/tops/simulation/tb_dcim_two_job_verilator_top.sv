`timescale 1ns / 1ns
`include "chip_defines.vh"

// C++-driven wrapper for 4.x simulators: clock/reset/start from C++, memories inside.
module tb_dcim_two_job_verilator_top (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         start,
    input  wire         load_en,
    input  wire [14:0]  load_addr,
    input  wire [127:0] load_data,
    input  wire [13:0]  peek_addr,
    output wire [127:0] peek_data,
    output wire         done,
    output wire         ready
);
`ifndef TWO_JOB_PIXELS
    localparam integer PIXELS = 256;
`else
    localparam integer PIXELS = `TWO_JOB_PIXELS;
`endif
`ifndef TWO_JOB_ACC
    localparam integer ACC_DEPTH = 2;
`else
    localparam integer ACC_DEPTH = `TWO_JOB_ACC;
`endif
    localparam integer IBUF_AW = `DCIM_TILE_IBUF_ADDR_WIDTH;
    localparam integer OBUF_AW = `DCIM_TILE_OBUF_ADDR_WIDTH;
    localparam integer LAT = `DCIM_TILE_IBUF_RD_LATENCY;
    localparam integer ACT_STRIDE = ACC_DEPTH * 4;
    localparam integer WEIGHT_BASE = PIXELS * ACT_STRIDE;

    wire rd0, rd1, dv0, dv1;
    wire [IBUF_AW-1:0] ra0, ra1;
    wire [127:0] d0, d1;
    wire wv0, wv1;
    wire [OBUF_AW-1:0] wa0, wa1;
    wire [127:0] wd0, wd1;
    wire [15:0] ws0, ws1;
    wire fire, result_valid;
    wire [31:0] peak_input, result_data;
    wire [5:0] job;
    wire [1:0] phase;

    reg [127:0] imem [0:(1<<IBUF_AW)-1];
    reg [127:0] omem [0:(1<<OBUF_AW)-1];
    reg [LAT-1:0] vp0 = '0, vp1 = '0;
    reg [IBUF_AW-1:0] ap0 [0:LAT-1];
    reg [IBUF_AW-1:0] ap1 [0:LAT-1];

    assign dv0 = vp0[LAT-1];
    assign dv1 = vp1[LAT-1];
    assign d0 = imem[ap0[LAT-1]];
    assign d1 = imem[ap1[LAT-1]];
    assign peek_data = omem[peek_addr];

    integer pi;
    always @(posedge clk) begin
        vp0[0] <= rd0;
        vp1[0] <= rd1;
        ap0[0] <= ra0;
        ap1[0] <= ra1;
        for (pi = 1; pi < LAT; pi = pi + 1) begin
            vp0[pi] <= vp0[pi-1];
            vp1[pi] <= vp1[pi-1];
            ap0[pi] <= ap0[pi-1];
            ap1[pi] <= ap1[pi-1];
        end
        if (load_en)
            imem[load_addr] <= load_data;
        if (wv0)
            omem[wa0] <= wd0;
        if (wv1)
            omem[wa1] <= wd1;
    end

    DCIM_Tile #(
        .MULT_DSP_EN(1),
        .DSP_COL_NUM(`DCIM_DSP_COL_NUM),
        .DSP_PARTIAL_SUBCOL(`DCIM_DSP_PARTIAL_SUBCOL)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .tile_enable(1'b1),
        .done(done), .ready(ready), .mode(`MODE_INT8), .acc_depth(ACC_DEPTH[6:0]),
        .wei_base_addr(WEIGHT_BASE[IBUF_AW-1:0]), .act_base_addr('0), .out_base_addr('0),
        .batch_enable(1'b1), .batch_count(PIXELS[31:0]),
        .benchmark_repeat(1'b0), .repeat_count(32'd1),
        .act_stride_words(ACT_STRIDE[IBUF_AW-1:0]), .out_stride_words(15'd4),
        .ibuf0_rd_en(rd0), .ibuf0_rd_addr(ra0),
        .ibuf0_data_valid(dv0), .ibuf0_data(d0),
        .ibuf1_rd_en(rd1), .ibuf1_rd_addr(ra1),
        .ibuf1_data_valid(dv1), .ibuf1_data(d1),
        .obuf0_wr_valid(wv0), .obuf0_wr_addr(wa0), .obuf0_wr_data(wd0), .obuf0_wr_strb(ws0),
        .obuf1_wr_valid(wv1), .obuf1_wr_addr(wa1), .obuf1_wr_data(wd1), .obuf1_wr_strb(ws1),
        .peak_compute_fire(fire), .peak_dcim_input(peak_input),
        .peak_job(job), .peak_phase(phase),
        .peak_result_valid(result_valid), .peak_result_data(result_data)
    );
endmodule
