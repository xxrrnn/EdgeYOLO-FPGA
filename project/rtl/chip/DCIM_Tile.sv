`timescale 1ns / 1ns
`include "chip_defines.vh"

// One fully streamed DCIM Tile.
//
// Layer execution is acc-row major inside a 64-pixel micro-batch:
//   1. preload the layer weights once into local BRAM;
//   2. stream every pixel for acc row N while the inactive wide cache loads N+1;
//   3. accumulate row results in a 512-bit x 64 BRAM;
//   4. write the final four 128-bit result words through both OBUF ports.
//
// INT8 and native INT16 use the same controller and memory interfaces.  Mode
// only changes activation phases/job (2 or 4) and accumulator lanes
// (16xINT32 or 8xINT64).  Host-visible pixel-major address mapping is retained.
module DCIM_Tile #(
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter SRAM_DP         = `DCIM_SRAM_DP, // compatibility; storage is ACC*CYCLE
    parameter CYCLE           = `DCIM_CYCLE,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH  = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,
    parameter TILE_IDX        = 0,
    parameter MULT_DSP_EN        = 1,
    parameter DSP_COL_NUM        = CH_OUT/4,
    parameter DSP_PARTIAL_SUBCOL = 0,

    localparam ACC_W          = $clog2(ACC + 1),
    localparam STORE_DEPTH    = ACC * CYCLE,
    localparam STORE_AW       = $clog2(STORE_DEPTH),
    localparam CYCLE_SHIFT    = $clog2(CYCLE),
    localparam WD2            = 2*WD1 + $clog2(CH_IN),
    localparam WD3            = WD2 + $clog2(ACC),
    localparam CORE_OUT_WIDTH = CH_OUT * WD3,
    localparam WEIGHT_WIDTH   = CH_IN * CH_OUT * WD1,
    localparam STRB_WIDTH     = BUF_DATA_WIDTH / 8,
    localparam MICRO_BATCH    = 64,
    localparam JOB_W          = $clog2(MICRO_BATCH),
    localparam JOB_COUNT_W    = $clog2(MICRO_BATCH + 1),
    localparam OBUF_AW        = `DCIM_TILE_OBUF_ADDR_WIDTH
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         start,
    input  wire                         tile_enable,
    output wire                         done,
    output wire                         ready,

    input  wire [2:0]                   mode,
    input  wire [ACC_W-1:0]             acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]    wei_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]    act_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]    out_base_addr,
    input  wire                         batch_enable,
    input  wire [31:0]                  batch_count,
    input  wire                         benchmark_repeat,
    input  wire [31:0]                  repeat_count,
    input  wire [BUF_ADDR_WIDTH-1:0]    act_stride_words,
    input  wire [BUF_ADDR_WIDTH-1:0]    out_stride_words,

    output wire                         ibuf0_rd_en,
    output wire [BUF_ADDR_WIDTH-1:0]    ibuf0_rd_addr,
    input  wire                         ibuf0_data_valid,
    input  wire [BUF_DATA_WIDTH-1:0]    ibuf0_data,
    output wire                         ibuf1_rd_en,
    output wire [BUF_ADDR_WIDTH-1:0]    ibuf1_rd_addr,
    input  wire                         ibuf1_data_valid,
    input  wire [BUF_DATA_WIDTH-1:0]    ibuf1_data,

    output wire                         obuf0_wr_valid,
    output wire [OBUF_AW-1:0]           obuf0_wr_addr,
    output wire [BUF_DATA_WIDTH-1:0]    obuf0_wr_data,
    output wire [STRB_WIDTH-1:0]        obuf0_wr_strb,
    output wire                         obuf1_wr_valid,
    output wire [OBUF_AW-1:0]           obuf1_wr_addr,
    output wire [BUF_DATA_WIDTH-1:0]    obuf1_wr_data,
    output wire [STRB_WIDTH-1:0]        obuf1_wr_strb,

    output wire                         peak_compute_fire,
    output wire [31:0]                  peak_dcim_input,
    output wire [JOB_W-1:0]             peak_job,
    output wire [1:0]                   peak_phase,
    output wire                         peak_result_valid,
    output wire [31:0]                  peak_result_data
);

    initial begin
        if (CYCLE != (WEIGHT_WIDTH / BUF_DATA_WIDTH))
            $error("DCIM_Tile CYCLE/mapping mismatch cycle=%0d expected=%0d",
                   CYCLE, WEIGHT_WIDTH / BUF_DATA_WIDTH);
        if (MICRO_BATCH != 64)
            $error("DCIM_Tile currently requires a 64-context partial-sum RAM");
    end

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_PRELOAD,
        ST_PRIME_START,
        ST_PRIME_WAIT,
        ST_PRIME_ACTIVATE,
        ST_ROW_START,
        ST_ROW_RUN,
        ST_ROW_WAIT,
        ST_ROW_ACTIVATE,
        ST_DONE
    } state_t;

    state_t state, next_state;

    reg start_d;
    reg start_d2;
    wire start_pulse = start_d && !start_d2 && tile_enable;
    wire job_accept = (state == ST_IDLE) && start_pulse;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_d <= 1'b0;
            start_d2 <= 1'b0;
        end else begin
            start_d <= start;
            start_d2 <= start_d;
        end
    end

    reg [2:0] mode_reg;
    reg [ACC_W-1:0] acc_reg;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_reg;
    reg [BUF_ADDR_WIDTH-1:0] act_base_reg;
    reg [OBUF_AW-1:0] out_base_reg;
    reg [31:0] total_pixels_reg;
    reg benchmark_repeat_reg;
    reg [31:0] repeat_count_reg;
    reg [BUF_ADDR_WIDTH-1:0] act_stride_reg;
    reg [OBUF_AW-1:0] out_stride_reg;

    // Array-boundary configuration crosses SLRs only into these Tile-local
    // copies.  start_pulse is delayed one cycle so the command capture below
    // always sees the matching local configuration.
    reg [2:0] cfg_mode_local;
    reg [ACC_W-1:0] cfg_acc_depth_local;
    reg [BUF_ADDR_WIDTH-1:0] cfg_wei_base_local;
    reg [BUF_ADDR_WIDTH-1:0] cfg_act_base_local;
    reg [OBUF_AW-1:0] cfg_out_base_local;
    reg cfg_batch_enable_local;
    reg [31:0] cfg_batch_count_local;
    reg cfg_benchmark_repeat_local;
    reg [31:0] cfg_repeat_count_local;
    reg [BUF_ADDR_WIDTH-1:0] cfg_act_stride_local;
    reg [OBUF_AW-1:0] cfg_out_stride_local;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_mode_local <= `MODE_INT8;
            cfg_acc_depth_local <= '0;
            cfg_wei_base_local <= '0;
            cfg_act_base_local <= '0;
            cfg_out_base_local <= '0;
            cfg_batch_enable_local <= 1'b0;
            cfg_batch_count_local <= 32'd1;
            cfg_benchmark_repeat_local <= 1'b0;
            cfg_repeat_count_local <= 32'd1;
            cfg_act_stride_local <= '0;
            cfg_out_stride_local <= '0;
        end else begin
            cfg_mode_local <= mode;
            cfg_acc_depth_local <= acc_depth;
            cfg_wei_base_local <= wei_base_addr;
            cfg_act_base_local <= act_base_addr;
            cfg_out_base_local <= out_base_addr[OBUF_AW-1:0];
            cfg_batch_enable_local <= batch_enable;
            cfg_batch_count_local <= batch_count;
            cfg_benchmark_repeat_local <= benchmark_repeat;
            cfg_repeat_count_local <= repeat_count;
            cfg_act_stride_local <= act_stride_words;
            cfg_out_stride_local <= out_stride_words[OBUF_AW-1:0];
        end
    end

    reg [31:0] pixels_remaining;
    reg [JOB_COUNT_W-1:0] block_pixels;
    reg [BUF_ADDR_WIDTH-1:0] block_act_base;
    reg [OBUF_AW-1:0] block_out_base;
    reg [ACC_W-1:0] row_index;
    reg prefetch_done_reg;

    wire first_acc_row = (row_index == 0);
    wire last_acc_row = (row_index + 1'b1 >= acc_reg);
    wire last_pixel_block = (pixels_remaining <= block_pixels);
    wire next_operation_exists = !(last_acc_row && last_pixel_block);
    wire [ACC_W-1:0] prefetch_row_index = last_acc_row ? '0 : row_index + 1'b1;

    wire [BUF_ADDR_WIDTH-1:0] int8_row_offset =
        {{(BUF_ADDR_WIDTH-ACC_W-2){1'b0}}, row_index, 2'b00};
    wire [BUF_ADDR_WIDTH-1:0] int16_row_offset =
        {{(BUF_ADDR_WIDTH-ACC_W-3){1'b0}}, row_index, 3'b000};
    wire [BUF_ADDR_WIDTH-1:0] row_act_base = block_act_base +
        ((mode_reg == `MODE_INT16) ? int16_row_offset : int8_row_offset);

    wire [31:0] next_remaining = pixels_remaining - block_pixels;
    wire [JOB_COUNT_W-1:0] next_block_pixels =
        (next_remaining > MICRO_BATCH) ? MICRO_BATCH[JOB_COUNT_W-1:0] :
                                         next_remaining[JOB_COUNT_W-1:0];

    assign ready = (state == ST_IDLE);
    reg done_reg;
    assign done = done_reg;

    reg [$clog2(`DCIM_OBUF_WR_DRAIN+1)-1:0] drain_count;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_reg <= 1'b0;
            drain_count <= '0;
        end else begin
            if (job_accept)
                done_reg <= 1'b0;
            else if (state == ST_DONE)
                done_reg <= 1'b1;

            if (state != ST_DONE)
                drain_count <= '0;
            else if (drain_count < `DCIM_OBUF_WR_DRAIN)
                drain_count <= drain_count + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Layer-weight preload: one fully pipelined 128-bit IBUF read stream.
    // ------------------------------------------------------------------
    reg [STORE_AW:0] preload_req_count;
    reg [STORE_AW:0] preload_rsp_count;
    wire [STORE_AW:0] preload_word_count =
        {{(STORE_AW + 1 - ACC_W){1'b0}}, acc_reg} << CYCLE_SHIFT;
    wire preload_requests_active = (state == ST_PRELOAD) &&
                                   (preload_req_count < preload_word_count);
    wire preload_response = (state == ST_PRELOAD) && ibuf0_data_valid;
    wire preload_complete = preload_response &&
                            (preload_rsp_count + 1'b1 >= preload_word_count);

    wire act_ibuf0_rd_en;
    wire [BUF_ADDR_WIDTH-1:0] act_ibuf0_rd_addr;
    wire act_ibuf1_rd_en;
    wire [BUF_ADDR_WIDTH-1:0] act_ibuf1_rd_addr;

    assign ibuf0_rd_en = preload_requests_active | act_ibuf0_rd_en;
    assign ibuf0_rd_addr = preload_requests_active ?
                           (wei_base_reg +
                            {{(BUF_ADDR_WIDTH-STORE_AW-1){1'b0}}, preload_req_count}) :
                           act_ibuf0_rd_addr;
    assign ibuf1_rd_en = act_ibuf1_rd_en;
    assign ibuf1_rd_addr = act_ibuf1_rd_addr;

    wire weight_store_wr_valid = preload_response;
    wire [STORE_AW-1:0] weight_store_wr_addr = preload_rsp_count[STORE_AW-1:0];

    // ------------------------------------------------------------------
    // Weight store + double wide cache.
    // ------------------------------------------------------------------
    // A single accepted-command pulse defines the reset boundary of all
    // job-local state.  Holding clear throughout IDLE made the boundary depend
    // on how long the decoder happened to remain idle.
    wire job_clear = job_accept;
    wire cache_clear = job_clear;
    wire cache_row_load_start = (state == ST_PRIME_START) ||
                                ((state == ST_ROW_START) && next_operation_exists);
    wire [ACC_W-1:0] cache_row_load_index =
        (state == ST_PRIME_START) ? '0 : prefetch_row_index;
    wire cache_row_load_busy;
    wire cache_row_load_done;
    wire cache_row_activate = (state == ST_PRIME_ACTIVATE) ||
                              (state == ST_ROW_ACTIVATE);
    wire cache_weight_valid;
    wire [WEIGHT_WIDTH-1:0] cache_weight_data;

    DCIM_Weight_Cache #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
        .CYCLE(CYCLE), .ACC(ACC), .WORD_WIDTH(BUF_DATA_WIDTH)
    ) u_weight_cache (
        .clk(clk), .rst_n(rst_n), .clear(cache_clear),
        .store_wr_valid(weight_store_wr_valid),
        .store_wr_addr(weight_store_wr_addr),
        .store_wr_data(ibuf0_data),
        .row_load_start(cache_row_load_start),
        .row_load_index(cache_row_load_index),
        .row_load_busy(cache_row_load_busy),
        .row_load_done(cache_row_load_done),
        .row_activate(cache_row_activate),
        .weight_valid(cache_weight_valid),
        .weight_data(cache_weight_data)
    );

    // ------------------------------------------------------------------
    // Unified activation stream.
    // ------------------------------------------------------------------
    wire row_stream_start = (state == ST_ROW_START);
    wire phase_valid;
    wire phase_ready;
    wire [CH_IN*WD1-1:0] phase_data;
    wire [JOB_W-1:0] phase_job;
    wire [1:0] phase_index;
    wire phase_fire;
    wire job_last_phase_fire;
    wire activation_issue_done;
    wire activation_active;

    DCIM_Activation_Stream #(
        .WD1(WD1), .CH_IN(CH_IN),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .MICRO_BATCH(MICRO_BATCH)
    ) u_activation_stream (
        .clk(clk), .rst_n(rst_n), .clear(job_clear),
        .start(row_stream_start), .mode(mode_reg),
        .pixel_count(block_pixels),
        .benchmark_repeat(benchmark_repeat_reg),
        .repeat_count(repeat_count_reg),
        .row_base_addr(row_act_base),
        .pixel_stride_words(act_stride_reg),
        .ibuf0_rd_en(act_ibuf0_rd_en),
        .ibuf0_rd_addr(act_ibuf0_rd_addr),
        .ibuf0_data_valid(ibuf0_data_valid && (state == ST_ROW_RUN)),
        .ibuf0_data(ibuf0_data),
        .ibuf1_rd_en(act_ibuf1_rd_en),
        .ibuf1_rd_addr(act_ibuf1_rd_addr),
        .ibuf1_data_valid(ibuf1_data_valid && (state == ST_ROW_RUN)),
        .ibuf1_data(ibuf1_data),
        .phase_valid(phase_valid), .phase_ready(phase_ready),
        .phase_data(phase_data), .phase_job(phase_job),
        .phase_index(phase_index), .phase_fire(phase_fire),
        .job_last_phase_fire(job_last_phase_fire),
        .issue_done(activation_issue_done), .active(activation_active)
    );

    // ------------------------------------------------------------------
    // Existing DCIM arithmetic, now used as a pure row pipeline.  Cross-row
    // accumulation is performed in BRAM, so postProcess.acc is tied to bypass.
    // ------------------------------------------------------------------
    wire core_clear = job_clear || (state == ST_PRELOAD);
    wire ma_valid;
    wire ma_ready;
    wire [CH_OUT*WD2-1:0] ma_data;
    wire core_out_valid;
    wire core_out_ready;
    wire [CORE_OUT_WIDTH-1:0] core_out_data;

    calculate_core #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
        .MULT_DSP_EN(MULT_DSP_EN),
        .DSP_COL_NUM(DSP_COL_NUM),
        .DSP_PARTIAL_SUBCOL(DSP_PARTIAL_SUBCOL)
    ) u_calculate_core (
        .clk(clk), .rstn(rst_n), .clr(core_clear), .ena(1'b1),
        .mode(mode_reg),
        .up_valid(phase_valid && cache_weight_valid),
        .up_ready(phase_ready),
        .up_data1(phase_data), .up_data2(cache_weight_data),
        .dn_valid(ma_valid), .dn_ready(ma_ready), .dn_data(ma_data)
    );

    postProcess #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), .ACC(ACC)
    ) u_post_process (
        .clk(clk), .rstn(rst_n), .clr(core_clear), .ena(1'b1),
        .mode(mode_reg), .acc('0),
        .up_valid(ma_valid), .up_ready(ma_ready), .up_data(ma_data),
        .dn_valid(core_out_valid), .dn_ready(core_out_ready),
        .dn_data(core_out_data)
    );

    wire result_row_done;
    DCIM_Result_Stream #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), .ACC(ACC),
        .OBUF_ADDR_WIDTH(OBUF_AW), .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .MICRO_BATCH(MICRO_BATCH)
    ) u_result_stream (
        .clk(clk), .rst_n(rst_n), .clear(job_clear),
        .row_start(row_stream_start), .mode(mode_reg),
        .first_acc_row(first_acc_row), .last_acc_row(last_acc_row),
        .pixel_count(block_pixels), .out_base_addr(block_out_base),
        .benchmark_repeat(benchmark_repeat_reg),
        .repeat_count(repeat_count_reg),
        .out_stride_words(out_stride_reg),
        .job_last_phase_fire(job_last_phase_fire), .issue_job(phase_job),
        .core_out_valid(core_out_valid), .core_out_ready(core_out_ready),
        .core_out_data(core_out_data),
        .obuf0_wr_valid(obuf0_wr_valid), .obuf0_wr_addr(obuf0_wr_addr),
        .obuf0_wr_data(obuf0_wr_data), .obuf0_wr_strb(obuf0_wr_strb),
        .obuf1_wr_valid(obuf1_wr_valid), .obuf1_wr_addr(obuf1_wr_addr),
        .obuf1_wr_data(obuf1_wr_data), .obuf1_wr_strb(obuf1_wr_strb),
        .row_done(result_row_done),
        .peak_result_valid(peak_result_valid),
        .peak_result_data(peak_result_data)
    );

    assign peak_compute_fire = phase_fire;
    assign peak_dcim_input = phase_data[31:0];
    assign peak_job = phase_job;
    assign peak_phase = phase_index;

    // ------------------------------------------------------------------
    // Compact layer/micro-batch/row scheduler.
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:           if (start_pulse) next_state = ST_PRELOAD;
            ST_PRELOAD:        if (preload_complete) next_state = ST_PRIME_START;
            ST_PRIME_START:    next_state = ST_PRIME_WAIT;
            ST_PRIME_WAIT:     if (cache_row_load_done) next_state = ST_PRIME_ACTIVATE;
            ST_PRIME_ACTIVATE: next_state = ST_ROW_START;
            ST_ROW_START:      next_state = ST_ROW_RUN;
            ST_ROW_RUN:        if (result_row_done) next_state = ST_ROW_WAIT;
            ST_ROW_WAIT: begin
                if (!next_operation_exists)
                    next_state = ST_DONE;
                else if (prefetch_done_reg)
                    next_state = ST_ROW_ACTIVATE;
            end
            ST_ROW_ACTIVATE:   next_state = ST_ROW_START;
            ST_DONE:           if (drain_count >= `DCIM_OBUF_WR_DRAIN) next_state = ST_IDLE;
            default:           next_state = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg <= `MODE_INT8;
            acc_reg <= '0;
            wei_base_reg <= '0;
            act_base_reg <= '0;
            out_base_reg <= '0;
            total_pixels_reg <= 32'd1;
            benchmark_repeat_reg <= 1'b0;
            repeat_count_reg <= 32'd1;
            act_stride_reg <= '0;
            out_stride_reg <= '0;
            preload_req_count <= '0;
            preload_rsp_count <= '0;
            pixels_remaining <= '0;
            block_pixels <= '0;
            block_act_base <= '0;
            block_out_base <= '0;
            row_index <= '0;
            prefetch_done_reg <= 1'b0;
        end else begin
            if (job_accept) begin
                mode_reg <= cfg_mode_local;
                acc_reg <= cfg_acc_depth_local;
                wei_base_reg <= cfg_wei_base_local;
                act_base_reg <= cfg_act_base_local;
                out_base_reg <= cfg_out_base_local;
                total_pixels_reg <= cfg_batch_enable_local ? cfg_batch_count_local : 32'd1;
                benchmark_repeat_reg <= cfg_benchmark_repeat_local;
                repeat_count_reg <= (cfg_repeat_count_local == 0) ? 32'd1 : cfg_repeat_count_local;
                act_stride_reg <= cfg_act_stride_local;
                out_stride_reg <= cfg_out_stride_local;
                preload_req_count <= '0;
                preload_rsp_count <= '0;
            end

            if (preload_requests_active)
                preload_req_count <= preload_req_count + 1'b1;
            if (preload_response)
                preload_rsp_count <= preload_rsp_count + 1'b1;

            if (state == ST_PRIME_ACTIVATE) begin
                pixels_remaining <= total_pixels_reg;
                block_pixels <= (total_pixels_reg > MICRO_BATCH) ?
                                MICRO_BATCH[JOB_COUNT_W-1:0] :
                                total_pixels_reg[JOB_COUNT_W-1:0];
                block_act_base <= act_base_reg;
                block_out_base <= out_base_reg;
                row_index <= '0;
            end

            if (state == ST_ROW_START)
                prefetch_done_reg <= !next_operation_exists;
            else if (cache_row_load_done)
                prefetch_done_reg <= 1'b1;

            if (state == ST_ROW_ACTIVATE) begin
                if (!last_acc_row) begin
                    row_index <= row_index + 1'b1;
                end else begin
                    row_index <= '0;
                    pixels_remaining <= next_remaining;
                    block_pixels <= next_block_pixels;
                    block_act_base <= block_act_base + (act_stride_reg << 6);
                    block_out_base <= block_out_base + (out_stride_reg << 6);
                end
            end
        end
    end

`ifdef SIMULATION
    always_ff @(posedge clk) begin
        if (rst_n && start_pulse && (cfg_acc_depth_local == 0))
            $fatal(1, "DCIM_Tile[%0d] acc_depth must be nonzero", TILE_IDX);
        if (rst_n && start_pulse && cfg_batch_enable_local && (cfg_batch_count_local == 0))
            $fatal(1, "DCIM_Tile[%0d] batch_count must be nonzero", TILE_IDX);
        if (rst_n && start_pulse && cfg_benchmark_repeat_local &&
            ((cfg_acc_depth_local != 1) || !cfg_batch_enable_local ||
             (cfg_batch_count_local != MICRO_BATCH)))
            $fatal(1,
                   "DCIM_Tile[%0d] benchmark repeat requires batch=64 and acc_depth=1",
                   TILE_IDX);
    end
`endif

endmodule
