`timescale 1ns/1ps
`include "chip_defines.vh"

// End-to-end streamed-Tile proof.  It exercises two accumulator rows so the
// test covers weight prefetch, dual-port activation bandwidth, the unmodified
// DCIM arithmetic pipeline, partial-sum BRAM and final dual-port OBUF writes.
module tb_dcim_stream_tile;
    localparam integer IBUF_AW = `DCIM_TILE_IBUF_ADDR_WIDTH;
    localparam integer OBUF_AW = `DCIM_TILE_OBUF_ADDR_WIDTH;
    localparam integer IBUF_LATENCY = `DCIM_TILE_IBUF_RD_LATENCY;
    localparam integer PIXELS = 64;
    localparam integer ACC_DEPTH = 2;
    localparam integer WEIGHT_BASE = 15'h1000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    reg [2:0] mode = `MODE_INT8;
    reg [6:0] acc_depth = ACC_DEPTH;
    reg [IBUF_AW-1:0] act_stride_words = 8;

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

    // Short, stable FSDB aliases used by the compact Verdi view.
    wire        COMPUTE      = peak_compute_fire;
    wire [5:0]  JOB          = peak_job;
    wire [1:0]  PHASE        = peak_phase;
    wire [31:0] INPUT_DATA   = peak_dcim_input;
    wire        MA_VALID     = dut.ma_valid;
    wire        CORE_VALID   = dut.core_out_valid;
    wire        RESULT_VALID = peak_result_valid;
    wire [31:0] RESULT_DATA  = peak_result_data;

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
        .done(done), .ready(ready), .mode(mode), .acc_depth(acc_depth),
        .wei_base_addr(WEIGHT_BASE[IBUF_AW-1:0]), .act_base_addr('0),
        .out_base_addr('0), .batch_enable(1'b1), .batch_count(PIXELS),
        .benchmark_repeat(1'b0), .repeat_count(32'd1),
        .act_stride_words(act_stride_words), .out_stride_words(15'd4),
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

    integer cycle;
    integer fire_count;
    integer result_count;
    integer last_fire_cycle;
    integer last_result_cycle;
    integer expected_job;
    integer expected_phase;
    integer phases_per_job;
    integer expected_value;

    always @(posedge clk) begin
        cycle = cycle + 1;
        if (rst_n && peak_compute_fire) begin
            if ((peak_job !== expected_job[5:0]) ||
                (peak_phase !== expected_phase[1:0]))
                $fatal(1, "phase sequence mismatch cycle=%0d got=%0d/%0d expected=%0d/%0d",
                       cycle, peak_job, peak_phase, expected_job, expected_phase);

            // There must be no bubbles inside an accumulator row.  A row
            // boundary may pause while the wide weight cache swaps banks.
            if ((fire_count != 0) && !((expected_job == 0) && (expected_phase == 0)) &&
                (cycle != last_fire_cycle + 1))
                $fatal(1, "compute bubble inside row at cycle=%0d previous=%0d",
                       cycle, last_fire_cycle);

            $display("STREAM_FIRE mode=%0d cycle=%0d job=%0d phase=%0d input=%08h",
                     mode, cycle, peak_job, peak_phase, peak_dcim_input);
            fire_count = fire_count + 1;
            last_fire_cycle = cycle;
            if (expected_phase + 1 >= phases_per_job) begin
                expected_phase = 0;
                if (expected_job + 1 >= PIXELS)
                    expected_job = 0;
                else
                    expected_job = expected_job + 1;
            end else begin
                expected_phase = expected_phase + 1;
            end
        end

        if (rst_n && peak_result_valid) begin
            if (peak_result_data !== expected_value[31:0])
                $fatal(1, "result mismatch mode=%0d job=%0d got=%08h expected=%08h",
                       mode, result_count, peak_result_data, expected_value);
            if ((result_count != 0) &&
                (cycle != last_result_cycle + phases_per_job))
                $fatal(1, "result II mismatch mode=%0d cycle=%0d previous=%0d expected_ii=%0d",
                       mode, cycle, last_result_cycle, phases_per_job);
            $display("STREAM_RESULT mode=%0d cycle=%0d job=%0d data=%08h",
                     mode, cycle, result_count, peak_result_data);
            result_count = result_count + 1;
            last_result_cycle = cycle;
        end
    end

    task automatic prepare_and_run(input [2:0] test_mode);
        integer pixel;
        integer word_idx;
        integer lane;
        integer timeout;
        integer words_per_row;
        reg [127:0] activation_word;
        begin
            mode = test_mode;
            phases_per_job = (test_mode == `MODE_INT16) ? 4 : 2;
            words_per_row = phases_per_job * 2;
            act_stride_words = ACC_DEPTH * words_per_row;
            // Physical DCIM columns merge into one logical weight: two
            // 4-bit columns form INT8 0x11; four form native INT16 0x1111.
            expected_value = (test_mode == `MODE_INT16) ?
                             (ACC_DEPTH * 64 * 16'h1111) :
                             (ACC_DEPTH * 64 * 8'h11 * 8'h11);
            activation_word = (test_mode == `MODE_INT16) ?
                              {8{16'h0001}} : {16{8'h11}};

            for (word_idx = 0; word_idx < ACC_DEPTH*64; word_idx = word_idx + 1)
                ibuf_mem[WEIGHT_BASE + word_idx] = {32{4'h1}};
            for (pixel = 0; pixel < PIXELS; pixel = pixel + 1)
                for (word_idx = 0; word_idx < ACC_DEPTH*words_per_row; word_idx = word_idx + 1)
                    ibuf_mem[pixel*ACC_DEPTH*words_per_row + word_idx] = activation_word;
            for (word_idx = 0; word_idx < PIXELS*4; word_idx = word_idx + 1)
                obuf_mem[word_idx] = 'x;

            rst_n = 1'b0;
            start = 1'b0;
            valid0_pipe = '0;
            valid1_pipe = '0;
            cycle = 0;
            fire_count = 0;
            result_count = 0;
            last_fire_cycle = -1;
            last_result_cycle = -1;
            expected_job = 0;
            expected_phase = 0;
            repeat (6) @(negedge clk);
            rst_n = 1'b1;
            repeat (3) @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            timeout = 0;
            while ((result_count < PIXELS) && (timeout < 10000)) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (timeout >= 10000)
                $fatal(1, "stream timeout mode=%0d fire=%0d results=%0d state=%0d",
                       test_mode, fire_count, result_count, dut.state);
            wait (done);

            if (fire_count != PIXELS*phases_per_job*ACC_DEPTH)
                $fatal(1, "fire count mismatch got=%0d expected=%0d",
                       fire_count, PIXELS*phases_per_job*ACC_DEPTH);
            if (result_count != PIXELS)
                $fatal(1, "result count mismatch got=%0d expected=%0d", result_count, PIXELS);

            for (pixel = 0; pixel < PIXELS; pixel = pixel + 1) begin
                for (lane = 0; lane < 4; lane = lane + 1) begin
                    if (obuf_mem[pixel*4 + lane][31:0] !== expected_value[31:0])
                        $fatal(1, "OBUF mismatch mode=%0d pixel=%0d word=%0d got=%08h expected=%08h",
                               test_mode, pixel, lane,
                               obuf_mem[pixel*4 + lane][31:0], expected_value);
                end
            end
            $display("STREAM_PASS mode=%0d fires=%0d results=%0d expected=%0d",
                     test_mode, fire_count, result_count, expected_value);
            repeat (5) @(negedge clk);
        end
    endtask

    initial begin
        cycle = 0;
        fire_count = 0;
        result_count = 0;
        if ($test$plusargs("FSDB")) begin
            $fsdbDumpfile("dcim_stream_tile.fsdb");
            $fsdbDumpvars(0, tb_dcim_stream_tile);
        end
        prepare_and_run(`MODE_INT8);
        prepare_and_run(`MODE_INT16);
        $display("PASS: unified INT8/native-INT16 streamed Tile");
        $finish;
    end
endmodule
