`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Tile - 单个 DCIM 计算 Tile 封装
// ============================================================================
// 目标优先级：250MHz 时序收敛 > 2TOPS 峰值 > 访存/写回性能。
// 因此本封装采用保守多拍控制：
//   - weight：每个 acc step 从 IBUF 读 CYCLE 个 128-bit word，写入 DCIM 内部 SRAM。
//   - ppCache：每个 acc step 从 SRAM 慢速 load 到 ppCache，再 swap 后计算。
//   - activation：按 CH_IN 参数多 beat 读取，INT8 为 CH_IN/16 个 word，INT16 为 CH_IN/8 个 word。
//   - output：按 INT32 结果慢速分 word 写回 OBUF；不追求连续写吞吐。
//
// 对 64×64 配置：
//   CYCLE = 64*64*4/128 = 128，SRAM_DP=128，因此每个 chunk 只包含 1 个 acc row。
//   acc_depth>1 时由本封装的 partial_accum 在 chunk 之间累加。
// ============================================================================

module DCIM_Tile #(
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter SRAM_DP         = `DCIM_SRAM_DP,
    parameter CYCLE           = `DCIM_CYCLE,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH  = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,
    parameter TILE_IDX        = 0,

    localparam SRAM_WD        = CH_IN * CH_OUT * WD1 / CYCLE,
    localparam ADDR_WD        = $clog2(SRAM_DP),
    localparam WD3            = 2*WD1 + $clog2(CH_IN) + $clog2(ACC),
    localparam OUT_WIDTH      = CH_OUT * WD3,
    localparam ACC_UBD_WD     = $clog2(ACC+1),
    localparam STRB_WIDTH     = BUF_DATA_WIDTH / 8,
    localparam RESULTS_PER_WORD = BUF_DATA_WIDTH / 32,
    localparam INT8_OUT_CH    = CH_OUT / 2,
    localparam INT16_OUT_CH   = CH_OUT / 4,
    localparam MAX_OUT_CH     = INT8_OUT_CH,
    localparam INT8_OUT_WORDS = (INT8_OUT_CH + RESULTS_PER_WORD - 1) / RESULTS_PER_WORD,
    localparam INT16_OUT_WORDS = (INT16_OUT_CH + RESULTS_PER_WORD - 1) / RESULTS_PER_WORD,
    localparam INT8_ACT_WORDS = (CH_IN * 8 + BUF_DATA_WIDTH - 1) / BUF_DATA_WIDTH,
    localparam INT16_ACT_WORDS = (CH_IN * 16 + BUF_DATA_WIDTH - 1) / BUF_DATA_WIDTH,
    localparam ACT_WORDS_MAX  = (INT16_ACT_WORDS > INT8_ACT_WORDS) ? INT16_ACT_WORDS : INT8_ACT_WORDS,
    localparam ACT_CNT_W      = (ACT_WORDS_MAX <= 1) ? 1 : $clog2(ACT_WORDS_MAX + 1),
    localparam SRAM_CNT_W     = (SRAM_DP <= 1) ? 1 : $clog2(SRAM_DP + 1),
    localparam PPCACHE_CNT_W  = ((CYCLE << 2) <= 1) ? 1 : $clog2((CYCLE << 2) + 1),
    localparam OUT_WORD_CNT_W = (INT8_OUT_WORDS <= 1) ? 1 : $clog2(INT8_OUT_WORDS + 1)
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire                          start,
    input  wire                          tile_enable,
    output wire                          done,
    output wire                          ready,

    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]     wei_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     out_base_addr,

    output reg                           ibuf_rd_valid,
    input  wire                          ibuf_rd_ready,
    output reg  [BUF_ADDR_WIDTH-1:0]     ibuf_rd_addr,
    input  wire                          ibuf_rd_data_valid,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_rd_data,

    output reg                           obuf_wr_valid,
    input  wire                          obuf_wr_ready,
    output reg  [BUF_ADDR_WIDTH-1:0]     obuf_wr_addr,
    output reg  [BUF_DATA_WIDTH-1:0]     obuf_wr_data,
    output reg  [STRB_WIDTH-1:0]         obuf_wr_strb
);

    initial begin
        if (SRAM_WD != BUF_DATA_WIDTH) begin
            $error("DCIM_Tile requires SRAM_WD == BUF_DATA_WIDTH: SRAM_WD=%0d BUF_DATA_WIDTH=%0d", SRAM_WD, BUF_DATA_WIDTH);
        end
        if (CH_OUT % 4 != 0) begin
            $error("DCIM_Tile requires CH_OUT to be divisible by 4");
        end
        if (BUF_DATA_WIDTH % 32 != 0) begin
            $error("DCIM_Tile requires BUF_DATA_WIDTH to contain whole INT32 results");
        end
    end

    // obuf.v：reg1+reg2+reg3 → mem；末次 grant 后等待写流水排空（DCIM_OBUF_WR_DRAIN）

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_CLEAR,
        ST_LOAD_WEI_REQ,
        ST_LOAD_WEI_RESP,
        ST_LOAD_WEI_DONE,
        ST_PREP_PPCACHE,
        ST_LOAD_PPCACHE,
        ST_SWAP_PPCACHE,
        ST_LOAD_ACT_REQ,
        ST_LOAD_ACT_RESP,
        ST_COMPUTE,
        ST_WAIT_RESULT,
        ST_DONE
    } state_t;

    state_t state, next_state;

    wire                     dcim_clr;
    wire                     dcim_ena = 1'b1;
    reg                      dcim_wr_wei;
    reg                      dcim_load_wei;
    reg                      dcim_swap_wei;
    wire                     dcim_ready_wei;
    reg  [ADDR_WD-1:0]       dcim_addr_wei;
    reg  [SRAM_WD-1:0]       dcim_data_wei;

    assign dcim_clr = (state == ST_IDLE) || (state == ST_CLEAR);

    wire                     dcim_valid_out;
    wire                     dcim_ready_out = 1'b1;
    wire [OUT_WIDTH-1:0]     dcim_data_out;

    reg                      conv_valid;
    wire                     conv_ready;
    reg  [CH_IN*16-1:0]      conv_data;
    wire                     dcim_valid_act;
    wire                     dcim_ready_act;
    wire [CH_IN*WD1-1:0]     dcim_data_act;

    reg [ACC_UBD_WD-1:0]     row_cnt;
    reg [SRAM_CNT_W-1:0]     wei_load_cnt;
    reg [PPCACHE_CNT_W-1:0]  ppcache_cnt;
    reg [ACC_UBD_WD-1:0]     chunk_base;
    reg                      chunk_continue_req;
    reg signed [31:0]        int8_partial_accum [0:INT8_OUT_CH-1];
    reg signed [31:0]        int16_partial_accum [0:INT16_OUT_CH-1];
    reg [OUT_WORD_CNT_W-1:0] result_cnt;
    reg                      result_write_done;
    reg [ACT_CNT_W-1:0]      act_load_cnt;
    reg [BUF_DATA_WIDTH-1:0] ibuf_data_latch;

    reg start_d;
    wire start_pulse_raw = start && !start_d;
    wire start_pulse     = start_pulse_raw && tile_enable;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_d <= 1'b0;
        else start_d <= start;
    end

    (* max_fanout = 32 *) reg [2:0] mode_reg;
    reg [ACC_UBD_WD-1:0]     acc_reg;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] act_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] out_base_addr_reg;

    localparam integer MAX_ROWS_PER_CHUNK_INT = SRAM_DP / CYCLE;
    localparam [ACC_UBD_WD-1:0] MAX_ROWS_PER_CHUNK = MAX_ROWS_PER_CHUNK_INT[ACC_UBD_WD-1:0];
    localparam integer CYCLE_SHIFT = $clog2(CYCLE);

    (* max_fanout = 16 *) reg is_int16_reg;
    wire is_int16 = is_int16_reg;

    localparam [ACT_CNT_W-1:0] INT8_ACT_WORDS_L = INT8_ACT_WORDS;
    localparam [ACT_CNT_W-1:0] INT16_ACT_WORDS_L = INT16_ACT_WORDS;
    localparam [OUT_WORD_CNT_W-1:0] INT8_OUT_WORDS_L = INT8_OUT_WORDS;
    localparam [OUT_WORD_CNT_W-1:0] INT16_OUT_WORDS_L = INT16_OUT_WORDS;
    localparam [7:0] INT8_OUT_CH_L = INT8_OUT_CH;
    localparam [7:0] INT16_OUT_CH_L = INT16_OUT_CH;

    wire [ACT_CNT_W-1:0] active_act_words = is_int16 ? INT16_ACT_WORDS_L : INT8_ACT_WORDS_L;
    wire [OUT_WORD_CNT_W-1:0] active_out_words = is_int16 ? INT16_OUT_WORDS_L : INT8_OUT_WORDS_L;
    wire [7:0] active_out_ch = is_int16 ? INT16_OUT_CH_L : INT8_OUT_CH_L;
    wire act_load_last = (act_load_cnt + 1'b1 >= active_act_words);

    assign ready = (state == ST_IDLE);

    reg done_reg;
    assign done = done_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) done_reg <= 1'b0;
        else if (state == ST_DONE) done_reg <= 1'b1;
        else if (state == ST_IDLE && start_pulse) done_reg <= 1'b0;
    end

    reg [$clog2(`DCIM_OBUF_WR_DRAIN+1)-1:0] wr_drain_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) wr_drain_cnt <= '0;
        else if (state != ST_DONE) wr_drain_cnt <= '0;
        else if (wr_drain_cnt < `DCIM_OBUF_WR_DRAIN) wr_drain_cnt <= wr_drain_cnt + 1'b1;
    end

    (* max_fanout = 8 *) reg ibuf_handshake_done;
    (* max_fanout = 8 *) reg ibuf_data_received;
    (* max_fanout = 8 *) reg conv_sent_reg;
    reg [1:0] compute_phase_cnt;
    wire [1:0] compute_phase_last = (mode_reg == `MODE_INT16) ? 2'd3 : 2'd1;
    wire compute_phase_fire = (dcim_valid_act && dcim_ready_act);
    wire compute_done = compute_phase_fire && (compute_phase_cnt == compute_phase_last);
    wire [ACC_UBD_WD-1:0] rows_left = acc_reg - chunk_base;
    wire [ACC_UBD_WD-1:0] chunk_rows = (rows_left > MAX_ROWS_PER_CHUNK) ? MAX_ROWS_PER_CHUNK : rows_left;
    wire chunk_has_more = (chunk_base + chunk_rows < acc_reg);
    (* max_fanout = 8 *) reg wei_load_finished;
    (* max_fanout = 8 *) reg ppcache_finished;
    (* max_fanout = 8 *) reg all_rows_processed;
    (* max_fanout = 8 *) reg all_results_collected;
    reg [SRAM_CNT_W-1:0] chunk_words;
    reg [BUF_ADDR_WIDTH-1:0] row_wei_base;
    reg [BUF_ADDR_WIDTH-1:0] row_act_addr;

    function automatic [ACC_UBD_WD-1:0] calc_chunk_rows(input [ACC_UBD_WD-1:0] start_row);
        reg [ACC_UBD_WD-1:0] left;
        begin
            left = acc_reg - start_row;
            calc_chunk_rows = (left > MAX_ROWS_PER_CHUNK) ? MAX_ROWS_PER_CHUNK : left;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ibuf_handshake_done <= 1'b0;
            ibuf_data_received <= 1'b0;
            wei_load_finished <= 1'b0;
            ppcache_finished <= 1'b0;
            all_rows_processed <= 1'b0;
            all_results_collected <= 1'b0;
        end else begin
            ibuf_handshake_done <= (ibuf_rd_valid && ibuf_rd_ready);
            ibuf_data_received <= ibuf_rd_data_valid;
            wei_load_finished <= (wei_load_cnt >= chunk_words - 1'b1);
            ppcache_finished <= (state == ST_LOAD_PPCACHE) &&
                                ((row_cnt == 0) ? (ppcache_cnt >= (CYCLE << 2)) : (ppcache_cnt >= (CYCLE << 1)));
            all_rows_processed <= (row_cnt >= chunk_rows - 1'b1);
            all_results_collected <= chunk_continue_req || result_write_done;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:          if (start_pulse) next_state = ST_CLEAR;
            ST_CLEAR:         next_state = ST_LOAD_WEI_REQ;
            ST_LOAD_WEI_REQ:  if (ibuf_handshake_done) next_state = ST_LOAD_WEI_RESP;
            ST_LOAD_WEI_RESP: if (ibuf_data_received) next_state = ST_LOAD_WEI_DONE;
            ST_LOAD_WEI_DONE: next_state = wei_load_finished ? ST_PREP_PPCACHE : ST_LOAD_WEI_REQ;
            ST_PREP_PPCACHE:  next_state = ST_LOAD_PPCACHE;
            ST_LOAD_PPCACHE:  if (ppcache_finished) next_state = ST_SWAP_PPCACHE;
            ST_SWAP_PPCACHE:  next_state = ST_LOAD_ACT_REQ;
            ST_LOAD_ACT_REQ:  if (ibuf_handshake_done) next_state = ST_LOAD_ACT_RESP;
            ST_LOAD_ACT_RESP: if (ibuf_data_received) next_state = act_load_last ? ST_COMPUTE : ST_LOAD_ACT_REQ;
            ST_COMPUTE: begin
                if (compute_done)
                    next_state = all_rows_processed ? ST_WAIT_RESULT : ST_PREP_PPCACHE;
            end
            ST_WAIT_RESULT: begin
                if (all_results_collected)
                    next_state = chunk_has_more ? ST_CLEAR : ST_DONE;
            end
            ST_DONE:          if (wr_drain_cnt >= `DCIM_OBUF_WR_DRAIN) next_state = ST_IDLE;
            default:          next_state = ST_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg <= `MODE_INT8;
            acc_reg <= '0;
            wei_base_addr_reg <= '0;
            act_base_addr_reg <= '0;
            out_base_addr_reg <= '0;
            is_int16_reg <= 1'b0;
        end else if (state == ST_IDLE && start_pulse) begin
            mode_reg <= mode;
            acc_reg <= acc_depth;
            wei_base_addr_reg <= wei_base_addr;
            act_base_addr_reg <= act_base_addr;
            out_base_addr_reg <= out_base_addr;
            is_int16_reg <= (mode == `MODE_INT16);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wei_load_cnt <= '0;
            ppcache_cnt <= '0;
            row_cnt <= '0;
            chunk_base <= '0;
            dcim_wr_wei <= 1'b0;
            dcim_load_wei <= 1'b0;
            dcim_swap_wei <= 1'b0;
            dcim_addr_wei <= '0;
            dcim_data_wei <= '0;
            conv_valid <= 1'b0;
            conv_data <= '0;
            ibuf_rd_valid <= 1'b0;
            ibuf_rd_addr <= '0;
            ibuf_data_latch <= '0;
            conv_sent_reg <= 1'b0;
            compute_phase_cnt <= '0;
            chunk_words <= '0;
            row_wei_base <= '0;
            row_act_addr <= '0;
            act_load_cnt <= '0;
        end else begin
            dcim_wr_wei <= 1'b0;
            dcim_load_wei <= 1'b0;
            dcim_swap_wei <= 1'b0;
            conv_valid <= 1'b0;

            case (state)
                ST_IDLE: begin
                    wei_load_cnt <= '0;
                    ppcache_cnt <= '0;
                    row_cnt <= '0;
                    chunk_base <= '0;
                    chunk_words <= '0;
                    row_wei_base <= wei_base_addr_reg;
                    row_act_addr <= act_base_addr_reg;
                    ibuf_rd_valid <= 1'b0;
                    conv_sent_reg <= 1'b0;
                    compute_phase_cnt <= '0;
                    act_load_cnt <= '0;
                end

                ST_CLEAR: begin
                    wei_load_cnt <= '0;
                    ppcache_cnt <= '0;
                    row_cnt <= '0;
                    ibuf_rd_valid <= 1'b0;
                    conv_sent_reg <= 1'b0;
                    compute_phase_cnt <= '0;
                    act_load_cnt <= '0;
                    if (chunk_continue_req) begin
                        chunk_base <= chunk_base + chunk_rows;
                        chunk_words <= calc_chunk_rows(chunk_base + chunk_rows) << CYCLE_SHIFT;
                        row_wei_base <= wei_base_addr_reg + ((chunk_base + chunk_rows) << CYCLE_SHIFT);
                        row_act_addr <= act_base_addr_reg + ((chunk_base + chunk_rows) * active_act_words);
                    end else begin
                        chunk_words <= calc_chunk_rows('0) << CYCLE_SHIFT;
                        row_wei_base <= wei_base_addr_reg;
                        row_act_addr <= act_base_addr_reg;
                    end
                end

                ST_LOAD_WEI_REQ: begin
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= row_wei_base + wei_load_cnt;
                    if (ibuf_handshake_done)
                        ibuf_rd_valid <= 1'b0;
                end

                ST_LOAD_WEI_RESP: begin
                    ibuf_rd_valid <= 1'b0;
                    if (ibuf_data_received)
                        ibuf_data_latch <= ibuf_rd_data;
                end

                ST_LOAD_WEI_DONE: begin
                    dcim_wr_wei <= 1'b1;
                    dcim_addr_wei <= wei_load_cnt[ADDR_WD-1:0];
                    dcim_data_wei <= ibuf_data_latch;
                    wei_load_cnt <= wei_load_cnt + 1'b1;
                end

                ST_PREP_PPCACHE: begin
                    dcim_addr_wei <= row_cnt << CYCLE_SHIFT;
                    ppcache_cnt <= '0;
                end

                ST_LOAD_PPCACHE: begin
                    if (row_cnt == 0)
                        dcim_load_wei <= (ppcache_cnt == 0) || (ppcache_cnt == 2 * CYCLE);
                    else
                        dcim_load_wei <= (ppcache_cnt == 0);
                    ppcache_cnt <= ppcache_cnt + 1'b1;
                end

                ST_SWAP_PPCACHE: begin
                    dcim_swap_wei <= 1'b1;
                    act_load_cnt <= '0;
                end

                ST_LOAD_ACT_REQ: begin
                    conv_sent_reg <= 1'b0;
                    compute_phase_cnt <= '0;
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= row_act_addr + act_load_cnt;
                    if (ibuf_handshake_done)
                        ibuf_rd_valid <= 1'b0;
                end

                ST_LOAD_ACT_RESP: begin
                    ibuf_rd_valid <= 1'b0;
                    if (ibuf_data_received) begin
                        if (is_int16) begin
                            for (int ch = 0; ch < BUF_DATA_WIDTH/16; ch++) begin
                                if ((act_load_cnt * (BUF_DATA_WIDTH/16) + ch) < CH_IN)
                                    conv_data[(act_load_cnt * (BUF_DATA_WIDTH/16) + ch)*16 +: 16] <= ibuf_rd_data[ch*16 +: 16];
                            end
                        end else begin
                            for (int ch = 0; ch < BUF_DATA_WIDTH/8; ch++) begin
                                if ((act_load_cnt * (BUF_DATA_WIDTH/8) + ch) < CH_IN)
                                    conv_data[(act_load_cnt * (BUF_DATA_WIDTH/8) + ch)*16 +: 16] <=
                                        {{8{ibuf_rd_data[ch*8 + 7]}}, ibuf_rd_data[ch*8 +: 8]};
                            end
                        end
                        if (act_load_last)
                            act_load_cnt <= '0;
                        else
                            act_load_cnt <= act_load_cnt + 1'b1;
                    end
                end

                ST_COMPUTE: begin
                    conv_valid <= !conv_sent_reg;
                    if (conv_valid && conv_ready)
                        conv_sent_reg <= 1'b1;
                    if (compute_phase_fire)
                        compute_phase_cnt <= compute_phase_cnt + 1'b1;
                    if (compute_done) begin
                        conv_valid <= 1'b0;
                        conv_sent_reg <= 1'b0;
                        compute_phase_cnt <= '0;
                        row_cnt <= row_cnt + 1'b1;
                        row_wei_base <= row_wei_base + CYCLE;
                        row_act_addr <= row_act_addr + active_act_words;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    typedef enum logic [2:0] {
        SAVE_WAIT,
        SAVE_LATCH,
        SAVE_ACCUM,
        SAVE_WRITE,
        SAVE_GAP
    } save_state_t;

    save_state_t save_state;
    (* keep = "true" *) reg [OUT_WIDTH-1:0] dcim_data_latch;
    (* keep = "true" *) reg signed [WD3-1:0] phys_ch_reg [0:CH_OUT-1];
    reg signed [31:0] result_buffer [0:MAX_OUT_CH-1];

    wire signed [31:0] int8_result [0:INT8_OUT_CH-1];
    wire signed [31:0] int16_result [0:INT16_OUT_CH-1];

    genvar gi;
    generate
        for (gi = 0; gi < INT8_OUT_CH; gi = gi + 1) begin : gen_int8_extract
            localparam PHYS_IDX = gi * 2;
            if (WD3 <= 32) begin : gen_sign_extend
                assign int8_result[gi] = {{(32-WD3){phys_ch_reg[PHYS_IDX][WD3-1]}}, phys_ch_reg[PHYS_IDX]};
            end else begin : gen_truncate
                assign int8_result[gi] = phys_ch_reg[PHYS_IDX][31:0];
            end
        end

        for (gi = 0; gi < INT16_OUT_CH; gi = gi + 1) begin : gen_int16_extract
            localparam COL_BASE = gi * 4;
            wire [4*WD3-1:0] raw_int16;
            assign raw_int16 = {phys_ch_reg[COL_BASE+3], phys_ch_reg[COL_BASE+2],
                                phys_ch_reg[COL_BASE+1], phys_ch_reg[COL_BASE]};
            assign int16_result[gi] = raw_int16[31:0];
        end
    endgenerate

    function automatic [BUF_DATA_WIDTH-1:0] pack_result_word(input [OUT_WORD_CNT_W-1:0] word_idx);
        reg [BUF_DATA_WIDTH-1:0] result_word;
        integer lane;
        integer out_idx;
        begin
            result_word = '0;
            for (lane = 0; lane < RESULTS_PER_WORD; lane = lane + 1) begin
                out_idx = word_idx * RESULTS_PER_WORD + lane;
                if (out_idx < active_out_ch)
                    result_word[lane*32 +: 32] = result_buffer[out_idx];
            end
            pack_result_word = result_word;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_cnt <= '0;
            obuf_wr_valid <= 1'b0;
            obuf_wr_addr <= '0;
            obuf_wr_data <= '0;
            obuf_wr_strb <= '0;
            save_state <= SAVE_WAIT;
            dcim_data_latch <= '0;
            chunk_continue_req <= 1'b0;
            result_write_done <= 1'b0;
            for (int i = 0; i < CH_OUT; i++) phys_ch_reg[i] <= '0;
            for (int i = 0; i < INT8_OUT_CH; i++) int8_partial_accum[i] <= '0;
            for (int i = 0; i < INT16_OUT_CH; i++) int16_partial_accum[i] <= '0;
            for (int i = 0; i < MAX_OUT_CH; i++) result_buffer[i] <= '0;
        end else begin
            if (state == ST_IDLE) begin
                result_cnt <= '0;
                obuf_wr_valid <= 1'b0;
                obuf_wr_strb <= '0;
                save_state <= SAVE_WAIT;
                chunk_continue_req <= 1'b0;
                result_write_done <= 1'b0;
                for (int i = 0; i < INT8_OUT_CH; i++) int8_partial_accum[i] <= '0;
                for (int i = 0; i < INT16_OUT_CH; i++) int16_partial_accum[i] <= '0;
            end else begin
                if (state == ST_CLEAR) begin
                    result_cnt <= '0;
                    obuf_wr_valid <= 1'b0;
                    obuf_wr_strb <= '0;
                    save_state <= SAVE_WAIT;
                    chunk_continue_req <= 1'b0;
                    result_write_done <= 1'b0;
                end

                case (save_state)
                    SAVE_WAIT: begin
                        obuf_wr_valid <= 1'b0;
                        if (dcim_valid_out && dcim_ready_out) begin
                            dcim_data_latch <= dcim_data_out;
                            save_state <= SAVE_LATCH;
                        end
                    end

                    SAVE_LATCH: begin
                        for (int i = 0; i < CH_OUT; i++)
                            phys_ch_reg[i] <= dcim_data_latch[i*WD3 +: WD3];
                        save_state <= SAVE_ACCUM;
                    end

                    SAVE_ACCUM: begin
                        if (chunk_has_more) begin
                            if (is_int16_reg) begin
                                for (int i = 0; i < INT16_OUT_CH; i++)
                                    int16_partial_accum[i] <= int16_partial_accum[i] + int16_result[i];
                            end else begin
                                for (int i = 0; i < INT8_OUT_CH; i++)
                                    int8_partial_accum[i] <= int8_partial_accum[i] + int8_result[i];
                            end
                            chunk_continue_req <= 1'b1;
                            save_state <= SAVE_WAIT;
                        end else begin
                            if (is_int16_reg) begin
                                for (int i = 0; i < INT16_OUT_CH; i++)
                                    result_buffer[i] <= int16_result[i] + int16_partial_accum[i];
                            end else begin
                                for (int i = 0; i < INT8_OUT_CH; i++)
                                    result_buffer[i] <= int8_result[i] + int8_partial_accum[i];
                            end
                            result_cnt <= '0;
                            save_state <= SAVE_WRITE;
                        end
                    end

                    SAVE_WRITE: begin
                        obuf_wr_valid <= 1'b1;
                        obuf_wr_strb <= {STRB_WIDTH{1'b1}};
                        obuf_wr_addr <= out_base_addr_reg + result_cnt;
                        obuf_wr_data <= pack_result_word(result_cnt);
                        if (obuf_wr_ready) begin
                            obuf_wr_valid <= 1'b0;
                            if (result_cnt + 1'b1 >= active_out_words) begin
                                result_write_done <= 1'b1;
                                result_cnt <= '0;
                                save_state <= SAVE_WAIT;
                            end else begin
                                result_cnt <= result_cnt + 1'b1;
                                save_state <= SAVE_GAP;
                            end
                        end
                    end

                    SAVE_GAP: begin
                        obuf_wr_valid <= 1'b0;
                        obuf_wr_strb <= '0;
                        save_state <= SAVE_WRITE;
                    end

                    default: begin
                        obuf_wr_valid <= 1'b0;
                        save_state <= SAVE_WAIT;
                    end
                endcase
            end
        end
    end

`ifdef SIMULATION
`ifdef PROBE_DCIM_TILE_VALID
    always_ff @(posedge clk) begin
        if (rst_n && dcim_valid_out && dcim_ready_out) begin
            $display("[%0t] DCIM_Tile[%0d] dcim_valid_out fired save_state=%0d", $time, TILE_IDX, save_state);
        end
    end
`endif
`endif

    act_nibble_converter #(
        .CH_IN(CH_IN)
    ) u_act_nibble_converter (
        .clk            (clk),
        .rst_n          (rst_n),
        .mode           (mode_reg),
        .raw_act_valid  (conv_valid),
        .raw_act_ready  (conv_ready),
        .raw_act_data   (conv_data),
        .dcim_act_valid (dcim_valid_act),
        .dcim_act_ready (dcim_ready_act),
        .dcim_act_data  (dcim_data_act)
    );

    dcim #(
        .WD1(WD1),
        .CH_IN(CH_IN),
        .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP),
        .CYCLE(CYCLE),
        .ACC(ACC)
    ) u_dcim (
        .clk            (clk),
        .rstn           (rst_n),
        .clr            (dcim_clr),
        .ena            (dcim_ena),
        .mode_cal       (mode_reg),
        .acc            (chunk_rows),
        .wr_wei         (dcim_wr_wei),
        .load_wei       (dcim_load_wei),
        .swap_wei       (dcim_swap_wei),
        .up_ready_wei   (dcim_ready_wei),
        .up_address_wei (dcim_addr_wei),
        .up_data_wei    (dcim_data_wei),
        .up_be_wei      ({SRAM_WD{1'b1}}),
        .up_valid_cal   (dcim_valid_act),
        .up_ready_cal   (dcim_ready_act),
        .up_data_cal    (dcim_data_act),
        .dn_valid       (dcim_valid_out),
        .dn_ready       (dcim_ready_out),
        .dn_data        (dcim_data_out)
    );

endmodule
