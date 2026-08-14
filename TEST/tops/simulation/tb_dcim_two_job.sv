`timescale 1ns/1ps
`include "chip_defines.vh"

// Two sequential DCIM_Tile jobs with no rst_n between them.
// Reproduces the board finding: job 1 after reset is exact, job 2 is dirty.
//
// Default shape matches YOLO model.0.conv OH-tile: acc_depth=2, 4000 pixels.
// Override at compile time:
//   +define+TWO_JOB_PIXELS=70 +define+TWO_JOB_ACC=3
module tb_dcim_two_job;
`ifndef TWO_JOB_PIXELS
    localparam integer PIXELS = 4000;
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
    localparam integer EXP_A = ACC_DEPTH * 64 * 8'h11 * 8'h11;
    localparam integer EXP_B = ACC_DEPTH * 64 * 8'h22 * 8'h11;
    localparam integer TIMEOUT_CYCLES = (PIXELS * ACC_DEPTH * 400) + 20000;

    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;
    wire done, ready;
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

    always #2 clk = ~clk;
    integer pi;
    always @(posedge clk) begin
        vp0[0] <= rd0; vp1[0] <= rd1;
        ap0[0] <= ra0; ap1[0] <= ra1;
        for (pi = 1; pi < LAT; pi = pi + 1) begin
            vp0[pi] <= vp0[pi-1]; vp1[pi] <= vp1[pi-1];
            ap0[pi] <= ap0[pi-1]; ap1[pi] <= ap1[pi-1];
        end
        if (wv0) omem[wa0] <= wd0;
        if (wv1) omem[wa1] <= wd1;
    end

    DCIM_Tile #(.MULT_DSP_EN(0), .DSP_COL_NUM(0), .DSP_PARTIAL_SUBCOL(0)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .tile_enable(1'b1),
        .done(done), .ready(ready), .mode(`MODE_INT8), .acc_depth(ACC_DEPTH[6:0]),
        .wei_base_addr(WEIGHT_BASE[IBUF_AW-1:0]), .act_base_addr('0), .out_base_addr('0),
        .batch_enable(1'b1), .batch_count(PIXELS),
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

    integer p, w, lane, timeout, mismatches, first_bad;
    integer results_a, results_b;
    integer exp_now;
    integer cur_job;

    always @(posedge clk) begin
        if (rst_n && result_valid) begin
            if (cur_job == 1) results_a = results_a + 1;
            else if (cur_job == 2) results_b = results_b + 1;
        end
    end

    task fill_act(input [7:0] val);
        integer pp, ww;
        begin
            for (pp = 0; pp < PIXELS; pp = pp + 1)
                for (ww = 0; ww < ACC_DEPTH * 4; ww = ww + 1)
                    imem[pp * ACC_DEPTH * 4 + ww] = {16{val}};
        end
    endtask

    task clear_obuf;
        integer ww;
        begin
            for (ww = 0; ww < PIXELS * 4; ww = ww + 1)
                omem[ww] = 128'hx;
        end
    endtask

    task pulse_start;
        begin
            @(negedge clk);
            start = 1;
            @(negedge clk);
            start = 0;
        end
    endtask

    task wait_done;
        begin
            timeout = 0;
            while (!done && timeout < TIMEOUT_CYCLES) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= TIMEOUT_CYCLES)
                $fatal(1, "TWO_JOB timeout job=%0d ready=%0b done=%0b", cur_job, ready, done);
            while (!ready && timeout < TIMEOUT_CYCLES) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            repeat (4) @(negedge clk);
        end
    endtask

    task check_obuf(input integer exp, input integer job_i);
        begin
            mismatches = 0;
            first_bad = -1;
            for (p = 0; p < PIXELS; p = p + 1) begin
                for (lane = 0; lane < 4; lane = lane + 1) begin
                    if (omem[p * 4 + lane][31:0] !== exp[31:0]) begin
                        if (first_bad < 0) first_bad = p;
                        mismatches = mismatches + 1;
                    end
                end
            end
            $display("TWO_JOB job%0d pixels=%0d acc=%0d mismatches=%0d first_bad_px=%0d exp=%0d results=%0d",
                     job_i, PIXELS, ACC_DEPTH, mismatches, first_bad, exp,
                     (job_i == 1) ? results_a : results_b);
            if (mismatches != 0)
                $fatal(1, "TWO_JOB_FAIL job=%0d first_bad_px=%0d mismatches=%0d",
                       job_i, first_bad, mismatches);
        end
    endtask

    initial begin
        results_a = 0;
        results_b = 0;
        cur_job = 0;
        for (w = 0; w < ACC_DEPTH * 64; w = w + 1)
            imem[WEIGHT_BASE + w] = {32{4'h1}};
        fill_act(8'h11);
        clear_obuf();

        repeat (6) @(negedge clk);
        rst_n = 1;
        repeat (3) @(negedge clk);

        $display("TWO_JOB start job1 pixels=%0d acc=%0d exp=%0d", PIXELS, ACC_DEPTH, EXP_A);
        cur_job = 1;
        pulse_start();
        wait_done();
        check_obuf(EXP_A, 1);

        // No rst_n. Reload activations only — IBUF weights stay, matching the board.
        fill_act(8'h22);
        clear_obuf();
        $display("TWO_JOB start job2 (no reset) exp=%0d ready=%0b", EXP_B, ready);
        cur_job = 2;
        pulse_start();
        wait_done();
        check_obuf(EXP_B, 2);

        $display("TWO_JOB_PASS pixels=%0d acc_depth=%0d", PIXELS, ACC_DEPTH);
        $finish;
    end
endmodule
