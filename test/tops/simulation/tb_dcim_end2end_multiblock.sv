`timescale 1ns/1ps
`include "chip_defines.vh"

// Normal end-to-end Tile regression beyond the 64-job scratch-RAM boundary.
// Three accumulator rows exercise weight-cache rotation and partial sums; 70
// pixels exercise a full 64-job block followed by a six-job tail block.
module tb_dcim_end2end_multiblock;
    localparam integer IBUF_AW = `DCIM_TILE_IBUF_ADDR_WIDTH;
    localparam integer OBUF_AW = `DCIM_TILE_OBUF_ADDR_WIDTH;
    localparam integer LAT = `DCIM_TILE_IBUF_RD_LATENCY;
    localparam integer PIXELS = 70;
    localparam integer ACC_DEPTH = 3;
    localparam integer WEIGHT_BASE = 15'h1000;
    localparam integer EXPECTED_VALUE = ACC_DEPTH * 64 * 8'h11 * 8'h11;

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
        for (pi=1; pi<LAT; pi=pi+1) begin
            vp0[pi] <= vp0[pi-1]; vp1[pi] <= vp1[pi-1];
            ap0[pi] <= ap0[pi-1]; ap1[pi] <= ap1[pi-1];
        end
        if (wv0) omem[wa0] <= wd0;
        if (wv1) omem[wa1] <= wd1;
    end

    DCIM_Tile #(.MULT_DSP_EN(0), .DSP_COL_NUM(0), .DSP_PARTIAL_SUBCOL(0)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .tile_enable(1'b1),
        .done(done), .ready(ready), .mode(`MODE_INT8), .acc_depth(7'd3),
        .wei_base_addr(WEIGHT_BASE[IBUF_AW-1:0]), .act_base_addr('0), .out_base_addr('0),
        .batch_enable(1'b1), .batch_count(PIXELS),
        .benchmark_repeat(1'b0), .repeat_count(32'd1),
        .act_stride_words(15'd12), .out_stride_words(15'd4),
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

    integer cycles=0, fires=0, results=0;
    integer last_fire=-1, expected_job=0, expected_phase=0;
    integer row_in_block=0, block_pixels=64;
    always @(posedge clk) begin
        cycles = cycles + 1;
        if (rst_n && fire) begin
            if (job !== expected_job[5:0] || phase !== expected_phase[1:0])
                $fatal(1, "normal sequence mismatch cycle=%0d got=%0d/%0d expected=%0d/%0d",
                       cycles, job, phase, expected_job, expected_phase);
            if (fires != 0 && !(expected_job==0 && expected_phase==0) && cycles != last_fire+1)
                $fatal(1, "normal bubble inside acc row cycle=%0d previous=%0d", cycles, last_fire);
            last_fire = cycles;
            fires = fires + 1;
            if (expected_phase == 1) begin
                expected_phase = 0;
                if (expected_job == block_pixels-1) begin
                    expected_job = 0;
                    if (row_in_block == ACC_DEPTH-1) begin
                        row_in_block = 0;
                        block_pixels = PIXELS-64;
                    end else begin
                        row_in_block = row_in_block + 1;
                    end
                end else expected_job = expected_job + 1;
            end else expected_phase = 1;
        end
        if (rst_n && result_valid) begin
            if (result_data !== EXPECTED_VALUE[31:0])
                $fatal(1, "normal result mismatch result=%0d got=%08h expected=%08h",
                       results, result_data, EXPECTED_VALUE);
            results = results + 1;
        end
    end

    integer p,w,lane,timeout;
    initial begin
        for (w=0; w<ACC_DEPTH*64; w=w+1)
            imem[WEIGHT_BASE+w] = {32{4'h1}};
        for (p=0; p<PIXELS; p=p+1)
            for (w=0; w<ACC_DEPTH*4; w=w+1)
                imem[p*ACC_DEPTH*4+w] = {16{8'h11}};
        for (w=0; w<PIXELS*4; w=w+1) omem[w] = 'x;

        repeat(6) @(negedge clk); rst_n=1;
        repeat(3) @(negedge clk); start=1;
        @(negedge clk); start=0;
        timeout=0;
        while(!done && timeout<20000) begin @(negedge clk); timeout=timeout+1; end
        if(timeout>=20000) $fatal(1,"normal multiblock timeout state=%0d",dut.state);
        repeat(2) @(negedge clk);
        if(fires != PIXELS*ACC_DEPTH*2)
            $fatal(1,"normal fire count=%0d expected=%0d",fires,PIXELS*ACC_DEPTH*2);
        if(results != PIXELS)
            $fatal(1,"normal result count=%0d expected=%0d",results,PIXELS);
        for(p=0;p<PIXELS;p=p+1)
            for(lane=0;lane<4;lane=lane+1)
                if(omem[p*4+lane][31:0] !== EXPECTED_VALUE[31:0])
                    $fatal(1,"normal OBUF mismatch pixel=%0d lane=%0d",p,lane);
        $display("END2END_MULTIBLOCK_PASS pixels=%0d acc_depth=%0d fires=%0d results=%0d",
                 PIXELS,ACC_DEPTH,fires,results);
        $finish;
    end
endmodule
