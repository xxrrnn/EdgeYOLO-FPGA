`timescale 1ns / 1ns
`include "chip_defines.vh"

// Unified INT8/native-INT16 activation reader.
//
// Each micro-batch keeps the existing pixel-major mapping:
//   pixel_addr = row_base_addr + pixel * pixel_stride_words
// INT8 consumes four 128-bit words and emits two 256-bit nibble phases;
// INT16 consumes eight words and emits four phases.  Both modes use the same
// dual-port request, ping-pong buffering and valid/ready datapath.
module DCIM_Activation_Stream #(
    parameter WD1            = `DCIM_WD1,
    parameter CH_IN          = `DCIM_CH_IN,
    parameter BUF_ADDR_WIDTH = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH = `DCIM_BUF_DATA_WIDTH,
    parameter MICRO_BATCH    = 64,

    localparam PHASE_WIDTH     = CH_IN * WD1,
    localparam INT8_WORDS      = (CH_IN * 8  + BUF_DATA_WIDTH - 1) / BUF_DATA_WIDTH,
    localparam INT16_WORDS     = (CH_IN * 16 + BUF_DATA_WIDTH - 1) / BUF_DATA_WIDTH,
    localparam MAX_WORDS       = (INT16_WORDS > INT8_WORDS) ? INT16_WORDS : INT8_WORDS,
    localparam MAX_PAIRS       = MAX_WORDS / 2,
    localparam PAIR_W          = (MAX_PAIRS <= 1) ? 1 : $clog2(MAX_PAIRS),
    localparam PAIR_COUNT_W    = $clog2(MAX_PAIRS + 1),
    localparam JOB_W           = (MICRO_BATCH <= 1) ? 1 : $clog2(MICRO_BATCH),
    localparam JOB_COUNT_W     = $clog2(MICRO_BATCH + 1)
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        clear,
    input  wire                        start,
    input  wire [2:0]                  mode,
    input  wire [JOB_COUNT_W-1:0]      pixel_count,
    input  wire                        benchmark_repeat,
    input  wire [31:0]                 repeat_count,
    input  wire [BUF_ADDR_WIDTH-1:0]   row_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]   pixel_stride_words,

    output wire                        ibuf0_rd_en,
    output wire [BUF_ADDR_WIDTH-1:0]   ibuf0_rd_addr,
    input  wire                        ibuf0_data_valid,
    input  wire [BUF_DATA_WIDTH-1:0]   ibuf0_data,
    output wire                        ibuf1_rd_en,
    output wire [BUF_ADDR_WIDTH-1:0]   ibuf1_rd_addr,
    input  wire                        ibuf1_data_valid,
    input  wire [BUF_DATA_WIDTH-1:0]   ibuf1_data,

    output wire                        phase_valid,
    input  wire                        phase_ready,
    output wire [PHASE_WIDTH-1:0]      phase_data,
    output wire [JOB_W-1:0]            phase_job,
    output wire [1:0]                  phase_index,
    output wire                        phase_fire,
    output wire                        job_last_phase_fire,
    output reg                         issue_done,
    output reg                         active
);

    localparam [PAIR_COUNT_W-1:0] INT8_PAIRS  = INT8_WORDS / 2;
    localparam [PAIR_COUNT_W-1:0] INT16_PAIRS = INT16_WORDS / 2;

    wire is_int16 = (mode == `MODE_INT16);
    wire [PAIR_COUNT_W-1:0] pairs_per_job = is_int16 ? INT16_PAIRS : INT8_PAIRS;
    wire [1:0] last_phase = is_int16 ? 2'd3 : 2'd1;
    wire [31:0] repeat_limit = (repeat_count == 0) ? 32'd1 : repeat_count;

    // Two 128-bit reads are issued every cycle.  With the configured 10-cycle
    // IBUF latency, responses remain aligned and arrive in the same order.
    reg [JOB_COUNT_W-1:0] req_pixel;
    reg [PAIR_W-1:0] req_pair;
    reg [BUF_ADDR_WIDTH-1:0] req_pixel_base;
    reg [31:0] req_repeat;
    wire requests_active = active && (req_pixel < pixel_count);
    wire [BUF_ADDR_WIDTH-1:0] pair_word_offset =
        {{(BUF_ADDR_WIDTH-PAIR_W-1){1'b0}}, req_pair, 1'b0};

    assign ibuf0_rd_en = requests_active;
    assign ibuf1_rd_en = requests_active;
    assign ibuf0_rd_addr = req_pixel_base + pair_word_offset;
    assign ibuf1_rd_addr = req_pixel_base + pair_word_offset + 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_pixel <= '0;
            req_pair <= '0;
            req_pixel_base <= '0;
            req_repeat <= '0;
        end else if (clear) begin
            req_pixel <= '0;
            req_pair <= '0;
            req_pixel_base <= '0;
            req_repeat <= '0;
        end else if (start) begin
            req_pixel <= '0;
            req_pair <= '0;
            req_pixel_base <= row_base_addr;
            req_repeat <= '0;
        end else if (requests_active) begin
            if ({1'b0, req_pair} + 1'b1 >= pairs_per_job) begin
                req_pair <= '0;
                if (req_pixel + 1'b1 >= pixel_count) begin
                    if (benchmark_repeat && (req_repeat + 1'b1 < repeat_limit)) begin
                        req_pixel <= '0;
                        req_pixel_base <= row_base_addr;
                        req_repeat <= req_repeat + 1'b1;
                    end else begin
                        req_pixel <= pixel_count;
                    end
                end else begin
                    req_pixel <= req_pixel + 1'b1;
                    req_pixel_base <= req_pixel_base + pixel_stride_words;
                end
            end else begin
                req_pair <= req_pair + 1'b1;
            end
        end
    end

    reg [PHASE_WIDTH-1:0] phase_buffer [0:1][0:3];
    reg [1:0] buffer_valid;
    reg fill_index;
    reg consume_index;
    reg [PAIR_W-1:0] response_pair;
    reg [1:0] consume_phase;
    reg [JOB_W-1:0] consume_job;
    reg [31:0] consume_repeat;

    assign phase_valid = active && buffer_valid[consume_index];
    assign phase_data = phase_buffer[consume_index][consume_phase];
    assign phase_job = consume_job;
    assign phase_index = consume_phase;
    assign phase_fire = phase_valid && phase_ready;
    assign job_last_phase_fire = phase_fire && (consume_phase == last_phase);

    integer word_lane;
    integer nibble_lane;
    // The ping-pong payload is qualified by buffer_valid, which is reset and
    // cleared below.  Keep the 2048 data bits out of the asynchronous-reset
    // tree; otherwise synthesis creates a 4084-load reset net in every Tile.
    always_ff @(posedge clk) begin
        if (active && ibuf0_data_valid && ibuf1_data_valid) begin
            if (is_int16) begin
                for (word_lane = 0; word_lane < BUF_DATA_WIDTH/16; word_lane = word_lane + 1) begin
                    for (nibble_lane = 0; nibble_lane < 4; nibble_lane = nibble_lane + 1) begin
                        phase_buffer[fill_index][nibble_lane]
                            [((response_pair*2)*(BUF_DATA_WIDTH/16)+word_lane)*WD1 +: WD1]
                            <= ibuf0_data[word_lane*16 + (3-nibble_lane)*WD1 +: WD1];
                        phase_buffer[fill_index][nibble_lane]
                            [(((response_pair*2+1)*(BUF_DATA_WIDTH/16)+word_lane)*WD1) +: WD1]
                            <= ibuf1_data[word_lane*16 + (3-nibble_lane)*WD1 +: WD1];
                    end
                end
            end else begin
                for (word_lane = 0; word_lane < BUF_DATA_WIDTH/8; word_lane = word_lane + 1) begin
                    phase_buffer[fill_index][0]
                        [((response_pair*2)*(BUF_DATA_WIDTH/8)+word_lane)*WD1 +: WD1]
                        <= ibuf0_data[word_lane*8 + 4 +: WD1];
                    phase_buffer[fill_index][1]
                        [((response_pair*2)*(BUF_DATA_WIDTH/8)+word_lane)*WD1 +: WD1]
                        <= ibuf0_data[word_lane*8 +: WD1];
                    phase_buffer[fill_index][0]
                        [(((response_pair*2+1)*(BUF_DATA_WIDTH/8)+word_lane)*WD1) +: WD1]
                        <= ibuf1_data[word_lane*8 + 4 +: WD1];
                    phase_buffer[fill_index][1]
                        [(((response_pair*2+1)*(BUF_DATA_WIDTH/8)+word_lane)*WD1) +: WD1]
                        <= ibuf1_data[word_lane*8 +: WD1];
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 1'b0;
            issue_done <= 1'b0;
            buffer_valid <= 2'b00;
            fill_index <= 1'b0;
            consume_index <= 1'b0;
            response_pair <= '0;
            consume_phase <= '0;
            consume_job <= '0;
            consume_repeat <= '0;
        end else if (clear) begin
            active <= 1'b0;
            issue_done <= 1'b0;
            buffer_valid <= 2'b00;
            fill_index <= 1'b0;
            consume_index <= 1'b0;
            response_pair <= '0;
            consume_phase <= '0;
            consume_job <= '0;
            consume_repeat <= '0;
        end else if (start) begin
            active <= (pixel_count != 0);
            issue_done <= (pixel_count == 0);
            buffer_valid <= 2'b00;
            fill_index <= 1'b0;
            consume_index <= 1'b0;
            response_pair <= '0;
            consume_phase <= '0;
            consume_job <= '0;
            consume_repeat <= '0;
        end else begin
            issue_done <= 1'b0;

            if (active && ibuf0_data_valid && ibuf1_data_valid) begin
                if ({1'b0, response_pair} + 1'b1 >= pairs_per_job) begin
                    buffer_valid[fill_index] <= 1'b1;
                    fill_index <= ~fill_index;
                    response_pair <= '0;
                end else begin
                    response_pair <= response_pair + 1'b1;
                end
            end

            if (phase_fire) begin
                if (consume_phase == last_phase) begin
                    buffer_valid[consume_index] <= 1'b0;
                    consume_index <= ~consume_index;
                    consume_phase <= '0;
                    if ({1'b0, consume_job} + 1'b1 >= pixel_count) begin
                        if (benchmark_repeat &&
                            (consume_repeat + 1'b1 < repeat_limit)) begin
                            consume_job <= '0;
                            consume_repeat <= consume_repeat + 1'b1;
                        end else begin
                            active <= 1'b0;
                            issue_done <= 1'b1;
                        end
                    end else begin
                        consume_job <= consume_job + 1'b1;
                    end
                end else begin
                    consume_phase <= consume_phase + 1'b1;
                end
            end
        end
    end

`ifdef SIMULATION
    always_ff @(posedge clk) begin
        if (rst_n && active && (ibuf0_data_valid ^ ibuf1_data_valid))
            $fatal(1, "DCIM activation IBUF response skew valid=%b%b",
                   ibuf1_data_valid, ibuf0_data_valid);
        if (rst_n && active && ibuf0_data_valid && ibuf1_data_valid &&
            ({1'b0, response_pair} + 1'b1 >= pairs_per_job) &&
            buffer_valid[fill_index])
            $fatal(1, "DCIM activation ping-pong overflow");
        if (rst_n && start && benchmark_repeat && (pixel_count != MICRO_BATCH))
            $fatal(1, "DCIM benchmark repeat requires exactly %0d jobs", MICRO_BATCH);
    end
`endif

endmodule
