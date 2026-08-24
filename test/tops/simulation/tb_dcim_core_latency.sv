`timescale 1ns/1ps
`include "chip_defines.vh"

// Measures the fixed phase-to-result latency used to align the local
// partial-sum BRAM with the unmodified DCIM arithmetic pipeline.
module tb_dcim_core_latency;
    localparam CH_IN = 64;
    localparam CH_OUT = 32;
    localparam WD1 = 4;
    localparam ACC = 80;
    localparam WD2 = 2*WD1 + $clog2(CH_IN);
    localparam WD3 = WD2 + $clog2(ACC);

    reg clk = 1'b0;
    reg rstn = 1'b0;
    reg clr = 1'b0;
    reg [2:0] mode = `MODE_INT8;
    reg in_valid = 1'b0;
    reg [CH_IN*WD1-1:0] in_data = '0;
    reg [CH_IN*CH_OUT*WD1-1:0] weight_data = '0;
    wire in_ready;
    wire ma_valid;
    wire pp_ready;
    wire [WD2*CH_OUT-1:0] ma_data;
    wire out_valid;
    wire [WD3*CH_OUT-1:0] out_data;

    integer cycle = 0;
    integer phase_count = 0;
    integer result_count = 0;
    integer phases_per_job = 2;

    always #2 clk = ~clk;
    always @(posedge clk) begin
        cycle <= cycle + 1;
        if (rstn && in_valid && in_ready) begin
            $display("LAT_ISSUE mode=%0d cycle=%0d job=%0d phase=%0d",
                     mode, cycle, phase_count/phases_per_job,
                     phase_count%phases_per_job);
            phase_count <= phase_count + 1;
        end
        if (rstn && out_valid) begin
            $display("LAT_RESULT mode=%0d cycle=%0d job=%0d",
                     mode, cycle, result_count);
            result_count <= result_count + 1;
        end
    end

    calculate_core #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
        .MULT_DSP_EN(0), .DSP_COL_NUM(0), .DSP_PARTIAL_SUBCOL(0)
    ) u_calculate_core (
        .clk(clk), .rstn(rstn), .clr(clr), .ena(1'b1), .mode(mode),
        .up_valid(in_valid), .up_ready(in_ready),
        .up_data1(in_data), .up_data2(weight_data),
        .dn_valid(ma_valid), .dn_ready(pp_ready), .dn_data(ma_data)
    );

    postProcess #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), .ACC(ACC)
    ) u_post_process (
        .clk(clk), .rstn(rstn), .clr(clr), .ena(1'b1),
        .mode(mode), .acc('0),
        .up_valid(ma_valid), .up_ready(pp_ready), .up_data(ma_data),
        .dn_valid(out_valid), .dn_ready(1'b1), .dn_data(out_data)
    );

    task automatic run_mode(input [2:0] test_mode, input integer ppj);
        integer p;
        begin
            rstn = 1'b0;
            in_valid = 1'b0;
            mode = test_mode;
            phases_per_job = ppj;
            phase_count = 0;
            result_count = 0;
            repeat (6) @(negedge clk);
            rstn = 1'b1;
            repeat (3) @(negedge clk);
            for (p = 0; p < ppj*4; p = p + 1) begin
                @(negedge clk);
                in_valid = 1'b1;
                in_data = p;
            end
            @(negedge clk);
            in_valid = 1'b0;
            wait (result_count == 4);
            repeat (4) @(negedge clk);
        end
    endtask

    initial begin
        run_mode(`MODE_INT8, 2);
        run_mode(`MODE_INT16, 4);
        $finish;
    end
endmodule
