`timescale 1ns/1ps
`include "chip_defines.vh"

// Seamless peak-load proof for one Tile.  The same 64-job INT8 matrix is
// executed REPEATS times after one weight preload.  From the first phase of
// round 0 through the final phase of round REPEATS-1, COMPUTE must be high on
// every clock and JOB must wrap 63 -> 0 without a bubble.
module tb_dcim_repeat_benchmark;
    localparam integer IBUF_AW = `DCIM_TILE_IBUF_ADDR_WIDTH;
    localparam integer OBUF_AW = `DCIM_TILE_OBUF_ADDR_WIDTH;
    localparam integer IBUF_LATENCY = `DCIM_TILE_IBUF_RD_LATENCY;
    localparam integer PIXELS = 64;
    localparam integer REPEATS = 4;
    localparam integer PHASES = 2;
    localparam integer WEIGHT_BASE = 15'h1000;
    localparam integer EXPECTED_FIRES = PIXELS * REPEATS * PHASES;
    localparam integer EXPECTED_RESULTS = PIXELS * REPEATS;
    localparam integer EXPECTED_VALUE = 64 * 8'h11 * 8'h11;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;

    wire done;
    wire ready;
    wire ibuf0_rd_en;
    wire [IBUF_AW-1:0] ibuf0_rd_addr;
    wire ibuf1_rd_en;
    wire [IBUF_AW-1:0] ibuf1_rd_addr;
    wire ibuf0_data_valid;
    wire ibuf1_data_valid;
    wire [127:0] ibuf0_data;
    wire [127:0] ibuf1_data;
    wire obuf0_wr_valid;
    wire [OBUF_AW-1:0] obuf0_wr_addr;
    wire [127:0] obuf0_wr_data;
    wire [15:0] obuf0_wr_strb;
    wire obuf1_wr_valid;
    wire [OBUF_AW-1:0] obuf1_wr_addr;
    wire [127:0] obuf1_wr_data;
    wire [15:0] obuf1_wr_strb;
    wire peak_compute_fire;
    wire [31:0] peak_dcim_input;
    wire [5:0] peak_job;
    wire [1:0] peak_phase;
    wire peak_result_valid;
    wire [31:0] peak_result_data;

    // Compact FSDB aliases. ROUND is an explanatory simulation-only tap; the
    // hardware ILA proves the same property from the visible JOB 63->0 wraps.
    wire        START        = start;
    wire [3:0]  STATE        = dut.state;
    wire        COMPUTE      = peak_compute_fire;
    wire [31:0] ROUND        = dut.u_activation_stream.consume_repeat;
    wire [5:0]  JOB          = peak_job;
    wire [1:0]  PHASE        = peak_phase;
    wire [31:0] INPUT_DATA   = peak_dcim_input;
    wire        MA_VALID     = dut.ma_valid;
    wire        CORE_VALID   = dut.core_out_valid;
    wire        RESULT_VALID = peak_result_valid;
    wire [31:0] RESULT_DATA  = peak_result_data;
    wire        DONE         = done;

    reg [127:0] ibuf_mem [0:(1<<IBUF_AW)-1];
    reg [127:0] obuf_mem [0:(1<<OBUF_AW)-1];
    reg [IBUF_LATENCY-1:0] valid0_pipe = '0;
    reg [IBUF_LATENCY-1:0] valid1_pipe = '0;
    reg [IBUF_AW-1:0] addr0_pipe [0:IBUF_LATENCY-1];
    reg [IBUF_AW-1:0] addr1_pipe [0:IBUF_LATENCY-1];

    assign ibuf0_data_valid = valid0_pipe[IBUF_LATENCY-1];
    assign ibuf1_data_valid = valid1_pipe[IBUF_LATENCY-1];
    assign ibuf0_data = ibuf_mem[addr0_pipe[IBUF_LATENCY-1]];
    assign ibuf1_data = ibuf_mem[addr1_pipe[IBUF_LATENCY-1]];

    always #2 clk = ~clk; // 250 MHz

    integer pipe_i;
    always @(posedge clk) begin
        valid0_pipe[0] <= ibuf0_rd_en;
        valid1_pipe[0] <= ibuf1_rd_en;
        addr0_pipe[0] <= ibuf0_rd_addr;
        addr1_pipe[0] <= ibuf1_rd_addr;
        for (pipe_i = 1; pipe_i < IBUF_LATENCY; pipe_i = pipe_i + 1) begin
            valid0_pipe[pipe_i] <= valid0_pipe[pipe_i-1];
            valid1_pipe[pipe_i] <= valid1_pipe[pipe_i-1];
            addr0_pipe[pipe_i] <= addr0_pipe[pipe_i-1];
            addr1_pipe[pipe_i] <= addr1_pipe[pipe_i-1];
        end
        if (obuf0_wr_valid)
            obuf_mem[obuf0_wr_addr] <= obuf0_wr_data;
        if (obuf1_wr_valid)
            obuf_mem[obuf1_wr_addr] <= obuf1_wr_data;
    end

    DCIM_Tile #(
        .MULT_DSP_EN(0), .DSP_COL_NUM(0), .DSP_PARTIAL_SUBCOL(0)
    ) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .tile_enable(1'b1),
        .done(done), .ready(ready), .mode(`MODE_INT8), .acc_depth(7'd1),
        .wei_base_addr(WEIGHT_BASE[IBUF_AW-1:0]), .act_base_addr('0),
        .out_base_addr('0), .batch_enable(1'b1), .batch_count(PIXELS),
        .benchmark_repeat(1'b1), .repeat_count(REPEATS),
        .act_stride_words(15'd4), .out_stride_words(15'd4),
        .ibuf0_rd_en(ibuf0_rd_en), .ibuf0_rd_addr(ibuf0_rd_addr),
        .ibuf0_data_valid(ibuf0_data_valid), .ibuf0_data(ibuf0_data),
        .ibuf1_rd_en(ibuf1_rd_en), .ibuf1_rd_addr(ibuf1_rd_addr),
        .ibuf1_data_valid(ibuf1_data_valid), .ibuf1_data(ibuf1_data),
        .obuf0_wr_valid(obuf0_wr_valid), .obuf0_wr_addr(obuf0_wr_addr),
        .obuf0_wr_data(obuf0_wr_data), .obuf0_wr_strb(obuf0_wr_strb),
        .obuf1_wr_valid(obuf1_wr_valid), .obuf1_wr_addr(obuf1_wr_addr),
        .obuf1_wr_data(obuf1_wr_data), .obuf1_wr_strb(obuf1_wr_strb),
        .peak_compute_fire(peak_compute_fire),
        .peak_dcim_input(peak_dcim_input), .peak_job(peak_job),
        .peak_phase(peak_phase), .peak_result_valid(peak_result_valid),
        .peak_result_data(peak_result_data)
    );

    integer cycle = 0;
    integer fire_count = 0;
    integer result_count = 0;
    integer expected_job = 0;
    integer expected_phase = 0;
    integer first_fire_cycle = -1;
    integer last_fire_cycle = -1;
    integer start_cycle = -1;
    integer done_cycle = -1;

    always @(posedge clk) begin
        cycle = cycle + 1;
        if (rst_n && start)
            start_cycle = cycle;

        if (rst_n && peak_compute_fire) begin
            if (peak_job !== expected_job[5:0] ||
                peak_phase !== expected_phase[1:0])
                $fatal(1, "benchmark sequence mismatch cycle=%0d got=%0d/%0d expected=%0d/%0d",
                       cycle, peak_job, peak_phase, expected_job, expected_phase);
            if (fire_count == 0)
                first_fire_cycle = cycle;
            else if (cycle != last_fire_cycle + 1)
                $fatal(1, "benchmark compute bubble cycle=%0d previous=%0d",
                       cycle, last_fire_cycle);
            last_fire_cycle = cycle;
            fire_count = fire_count + 1;

            if (expected_phase == PHASES-1) begin
                expected_phase = 0;
                expected_job = (expected_job == PIXELS-1) ? 0 : expected_job + 1;
            end else begin
                expected_phase = expected_phase + 1;
            end
        end

        if (rst_n && peak_result_valid) begin
            if (peak_result_data !== EXPECTED_VALUE[31:0])
                $fatal(1, "benchmark result mismatch count=%0d got=%08h expected=%08h",
                       result_count, peak_result_data, EXPECTED_VALUE);
            result_count = result_count + 1;
        end

        if (rst_n && done)
            done_cycle = cycle;
    end

    integer pixel;
    integer word_idx;
    integer timeout;
    initial begin
        if ($test$plusargs("FSDB")) begin
            $fsdbDumpfile("dcim_repeat_benchmark.fsdb");
            $fsdbDumpvars(0, tb_dcim_repeat_benchmark);
        end

        for (word_idx = 0; word_idx < 64; word_idx = word_idx + 1)
            ibuf_mem[WEIGHT_BASE + word_idx] = {32{4'h1}};
        for (pixel = 0; pixel < PIXELS; pixel = pixel + 1)
            for (word_idx = 0; word_idx < 4; word_idx = word_idx + 1)
                ibuf_mem[pixel*4 + word_idx] = {16{8'h11}};
        for (word_idx = 0; word_idx < PIXELS*4; word_idx = word_idx + 1)
            obuf_mem[word_idx] = 'x;

        repeat (6) @(negedge clk);
        rst_n = 1'b1;
        repeat (3) @(negedge clk);
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;

        timeout = 0;
        while (!done && timeout < 10000) begin
            @(negedge clk);
            timeout = timeout + 1;
        end
        if (timeout >= 10000)
            $fatal(1, "benchmark timeout fires=%0d results=%0d state=%0d",
                   fire_count, result_count, dut.state);
        repeat (2) @(negedge clk);

        if (fire_count != EXPECTED_FIRES)
            $fatal(1, "benchmark fire count=%0d expected=%0d",
                   fire_count, EXPECTED_FIRES);
        if (last_fire_cycle - first_fire_cycle + 1 != EXPECTED_FIRES)
            $fatal(1, "benchmark active span=%0d expected=%0d",
                   last_fire_cycle - first_fire_cycle + 1, EXPECTED_FIRES);
        if (result_count != EXPECTED_RESULTS)
            $fatal(1, "benchmark result count=%0d expected=%0d",
                   result_count, EXPECTED_RESULTS);
        for (pixel = 0; pixel < PIXELS; pixel = pixel + 1)
            if (obuf_mem[pixel*4][31:0] !== EXPECTED_VALUE[31:0])
                $fatal(1, "benchmark final OBUF mismatch pixel=%0d got=%08h expected=%08h",
                       pixel, obuf_mem[pixel*4][31:0], EXPECTED_VALUE);

        $display("BENCHMARK_PASS repeats=%0d fires=%0d active_cycles=%0d results=%0d",
                 REPEATS, fire_count, last_fire_cycle-first_fire_cycle+1,
                 result_count);
        $display("BENCHMARK_CYCLES start=%0d first_compute=%0d last_compute=%0d done=%0d total=%0d",
                 start_cycle, first_fire_cycle, last_fire_cycle, done_cycle,
                 done_cycle-start_cycle+1);
        $display("BENCHMARK_TOPS equivalent_8tile_ops_per_cycle=8192 tops_at_250mhz=2.048");
        $finish;
    end
endmodule
