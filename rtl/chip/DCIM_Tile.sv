`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Tile - 单个 DCIM 计算 Tile（支持任意 acc_depth 的 im2col matmul）
// ============================================================================
// 架构：每个 acc_word 流式加载 CYCLE=8 个 weight entries + 1 个 activation word
//   → ppCache → maArray → mergeArray → accumulateArray → 输出
//
// Weight SRAM 用作 ppCache 的暂存（不需要预加载全部 weight）。
// 每个 acc_word 的 8 entries 从 IBUF[wei_base + row_cnt*CYCLE + 0..7] 实时加载。
//
// 支持的 CNN 算子范围（im2col 后的 matmul）：
//   - 1×1 conv 任意 IC (acc_depth = ceil(IC/16))
//   - 3×3 conv 任意 IC (acc_depth = ceil(9*IC/16))
//   - 6×6 conv (acc_depth = ceil(36*IC/16))
//   - 任意 kernel 只要 acc_depth ≤ DCIM_ACC_MAX=80
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
    parameter TILE_IDX        = 0,              // 由 DCIM_Array_Group 传入 genvar
    
    localparam SRAM_WD     = CH_IN * CH_OUT * WD1 / CYCLE,
    localparam ADDR_WD     = $clog2(SRAM_DP),
    localparam OUT_WIDTH   = CH_OUT * (2*WD1 + $clog2(CH_IN) + $clog2(ACC)),
    localparam WD3         = 2*WD1 + $clog2(CH_IN) + $clog2(ACC),
    localparam ACC_UBD_WD  = $clog2(ACC+1)
)(
    input  wire                          clk,
    input  wire                          rst_n,
    
    input  wire                          start,
    input  wire                          tile_enable,  // 1=enabled, 0=stay IDLE (from DCIM_REG_TILE_MASK)
    output wire                          done,
    output wire                          ready,
    
    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]     wei_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     out_base_addr,
    
    // IBUF read interface (shared via arbiter)
    output reg                           ibuf_rd_valid,
    input  wire                          ibuf_rd_ready,
    output reg  [BUF_ADDR_WIDTH-1:0]     ibuf_rd_addr,
    input  wire                          ibuf_rd_data_valid,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_rd_data,
    
    // OBUF write interface (to arbiter)
    output reg                           obuf_wr_valid,
    input  wire                          obuf_wr_ready,
    output reg  [BUF_ADDR_WIDTH-1:0]     obuf_wr_addr,
    output reg  [BUF_DATA_WIDTH-1:0]     obuf_wr_data,
    output reg  [BUF_DATA_WIDTH/8-1:0]   obuf_wr_strb
);

    // ========================================================================
    // 状态机定义
    // ========================================================================
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
        ST_LOAD_ACT2_REQ,
        ST_LOAD_ACT2_RESP,
        ST_COMPUTE,
        ST_WAIT_RESULT,
        ST_DONE
    } state_t;
    
    state_t state, next_state;
    
    // ========================================================================
    // DCIM 核心接口信号
    // ========================================================================
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
    
    // ========================================================================
    // 激活预处理接口信号
    // ========================================================================
    reg                      conv_valid;
    wire                     conv_ready;
    reg  [CH_IN*16-1:0]      conv_data;
    wire                     dcim_valid_act;
    wire                     dcim_ready_act;
    wire [CH_IN*WD1-1:0]     dcim_data_act;
    
    // ========================================================================
    // 计数器和配置寄存器
    // ========================================================================
    reg [ACC_UBD_WD-1:0]     row_cnt;
    reg [9:0]                wei_load_cnt;
    reg [5:0]                ppcache_cnt;
    reg [ACC_UBD_WD-1:0]     chunk_base;
    reg                      chunk_continue_req;
    reg signed [31:0]        int8_partial_accum [0:7];
    reg signed [31:0]        int16_partial_accum [0:3];
    reg [1:0]                result_cnt;
    reg                      result_cnt_nonzero;
    reg [BUF_DATA_WIDTH-1:0] act_buf_lo;
    reg [BUF_DATA_WIDTH-1:0] ibuf_data_latch;
    
    // ========================================================================
    // start 上升沿检测 + tile_enable 门控
    // tile_enable=0 的 Tile 不响应 start，永远停在 IDLE
    // ========================================================================
    reg start_d;
    wire start_pulse_raw = start && !start_d;
    wire start_pulse     = start_pulse_raw && tile_enable;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_d <= 0;
        else start_d <= start;
    end
    
    (* max_fanout = 32 *) reg [2:0] mode_reg;
    reg [ACC_UBD_WD-1:0]     acc_reg;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] act_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] out_base_addr_reg;
    
    localparam [31:0] EXPECTED_OUTPUTS = 32'd1;
    localparam integer MAX_ROWS_PER_CHUNK_INT = SRAM_DP / CYCLE;
    localparam [ACC_UBD_WD-1:0] MAX_ROWS_PER_CHUNK = MAX_ROWS_PER_CHUNK_INT[ACC_UBD_WD-1:0];
    
    (* max_fanout = 16 *) reg is_int16_reg;
    wire is_int16 = is_int16_reg;
    
    assign ready = (state == ST_IDLE);
    
    reg done_reg;
    assign done = done_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) done_reg <= 0;
        else if (state == ST_DONE) done_reg <= 1'b1;
        else if (state == ST_IDLE && start_pulse) done_reg <= 1'b0;
    end
    
    // ========================================================================
    // 状态机辅助信号
    // ========================================================================
    (* max_fanout = 8 *) reg ibuf_handshake_done;
    (* max_fanout = 8 *) reg ibuf_data_received;
    (* max_fanout = 8 *) reg conv_sent_reg;
    reg [1:0] compute_phase_cnt;
    wire [1:0] compute_phase_last = (mode_reg == `MODE_INT16) ? 2'd3 : 2'd1;
    wire compute_phase_fire = (dcim_valid_act && dcim_ready_act);
    wire compute_done = compute_phase_fire && (compute_phase_cnt == compute_phase_last);
    wire [ACC_UBD_WD-1:0] rows_left_inclusive = acc_reg - chunk_base;
    wire [ACC_UBD_WD-1:0] chunk_rows = (rows_left_inclusive > MAX_ROWS_PER_CHUNK) ?
                                       MAX_ROWS_PER_CHUNK : rows_left_inclusive;
    wire chunk_has_more = (chunk_base + chunk_rows < acc_reg);
    (* max_fanout = 8 *) reg wei_load_finished;
    (* max_fanout = 8 *) reg ppcache_finished;
    (* max_fanout = 8 *) reg all_rows_processed;
    (* max_fanout = 8 *) reg all_results_collected;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ibuf_handshake_done <= 0;
            ibuf_data_received <= 0;
            wei_load_finished <= 0;
            ppcache_finished <= 0;
            all_rows_processed <= 0;
            all_results_collected <= 0;
            result_cnt_nonzero <= 0;
        end else begin
            ibuf_handshake_done <= (ibuf_rd_valid && ibuf_rd_ready);
            ibuf_data_received <= ibuf_rd_data_valid;
            wei_load_finished <= (wei_load_cnt >= chunk_rows * CYCLE - 1);
            ppcache_finished <= (state == ST_LOAD_PPCACHE) && ((row_cnt == 0) ? (ppcache_cnt >= 4 * CYCLE) : (ppcache_cnt >= 2 * CYCLE));
            all_rows_processed <= (row_cnt >= chunk_rows - 1);
            result_cnt_nonzero <= (result_cnt != 2'd0);
            all_results_collected <= result_cnt_nonzero || chunk_continue_req;
        end
    end
    
    // ========================================================================
    // 状态机转移（核心改动：COMPUTE 后回到 LOAD_WEI 加载下一组 weight）
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else begin
            state <= next_state;
`ifdef SIMULATION
`ifdef PROBE_DCIM_TILE_STATE
            if (next_state != state) begin
                if (next_state == ST_CLEAR && state == ST_IDLE)
                    $display("[%0t] DCIM_Tile(%m) CLEAR", $time);
                else if (next_state == ST_LOAD_WEI_REQ && state == ST_CLEAR)
                    $display("[%0t] DCIM_Tile(%m) START", $time);
                else if (next_state == ST_COMPUTE)
                    $display("[%0t] DCIM_Tile(%m) COMPUTE (acc pass)", $time);
                else if (next_state == ST_WAIT_RESULT)
                    $display("[%0t] DCIM_Tile(%m) WAIT_RESULT (all acc done)", $time);
                else if (next_state == ST_DONE)
                    $display("[%0t] DCIM_Tile(%m) DONE", $time);
            end
`endif
`endif
        end
    end
    
    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:           if (start_pulse) next_state = ST_CLEAR;
            ST_CLEAR:          next_state = ST_LOAD_WEI_REQ;
            ST_LOAD_WEI_REQ:   if (ibuf_handshake_done) next_state = ST_LOAD_WEI_RESP;
            ST_LOAD_WEI_RESP:  if (ibuf_data_received) next_state = ST_LOAD_WEI_DONE;
            ST_LOAD_WEI_DONE: begin
                if (wei_load_finished) next_state = ST_PREP_PPCACHE;
                else next_state = ST_LOAD_WEI_REQ;
            end
            ST_PREP_PPCACHE:   next_state = ST_LOAD_PPCACHE;
            ST_LOAD_PPCACHE:   if (ppcache_finished) next_state = ST_SWAP_PPCACHE;
            ST_SWAP_PPCACHE:   next_state = ST_LOAD_ACT_REQ;
            ST_LOAD_ACT_REQ:   if (ibuf_handshake_done) next_state = ST_LOAD_ACT_RESP;
            ST_LOAD_ACT_RESP:  if (ibuf_data_received) begin
                if (is_int16) next_state = ST_LOAD_ACT2_REQ;
                else next_state = ST_COMPUTE;
            end
            ST_LOAD_ACT2_REQ:  if (ibuf_handshake_done) next_state = ST_LOAD_ACT2_RESP;
            ST_LOAD_ACT2_RESP: if (ibuf_data_received) next_state = ST_COMPUTE;
            ST_COMPUTE: begin
                if (compute_done) begin
                    if (all_rows_processed) next_state = ST_WAIT_RESULT;
                    else next_state = ST_PREP_PPCACHE;  // Next acc_word after all nibble phases are consumed
                end
            end
            ST_WAIT_RESULT:    if (all_results_collected) begin
                if (chunk_has_more) next_state = ST_CLEAR;
                else next_state = ST_DONE;
            end
            ST_DONE:           next_state = ST_IDLE;
            default:           next_state = ST_IDLE;
        endcase
    end
    
    // ========================================================================
    // 配置寄存器
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg <= `MODE_INT8;
            acc_reg <= 0;
            wei_base_addr_reg <= 0;
            act_base_addr_reg <= 0;
            out_base_addr_reg <= 0;
            is_int16_reg <= 0;
        end else if (state == ST_IDLE && start_pulse) begin
            mode_reg <= mode;
            acc_reg <= acc_depth;
            wei_base_addr_reg <= wei_base_addr;
            act_base_addr_reg <= act_base_addr;
            out_base_addr_reg <= out_base_addr;
            is_int16_reg <= (mode == `MODE_INT16);
        end
    end
    
    // ========================================================================
    // 主控制逻辑
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wei_load_cnt <= 0; ppcache_cnt <= 0; row_cnt <= 0;
            chunk_base <= 0;
            dcim_wr_wei <= 0; dcim_load_wei <= 0; dcim_swap_wei <= 0;
            dcim_addr_wei <= 0; dcim_data_wei <= 0;
            conv_valid <= 0; conv_data <= 0;
            ibuf_rd_valid <= 0; ibuf_rd_addr <= 0;
            ibuf_data_latch <= 0;
            act_buf_lo <= 0;
            conv_sent_reg <= 0;
            compute_phase_cnt <= 0;
        end else begin
            dcim_wr_wei <= 0;
            dcim_load_wei <= 0;
            dcim_swap_wei <= 0;
            conv_valid <= 0;
            
            case (state)
                ST_IDLE: begin
                    wei_load_cnt <= 0; ppcache_cnt <= 0; row_cnt <= 0;
                    chunk_base <= 0;
                    ibuf_rd_valid <= 0;
                    conv_sent_reg <= 0;
                    compute_phase_cnt <= 0;
                end

                ST_CLEAR: begin
                    wei_load_cnt <= 0;
                    ppcache_cnt <= 0;
                    row_cnt <= 0;
                    if (chunk_continue_req) begin
                        chunk_base <= chunk_base + chunk_rows;
                    end
                    ibuf_rd_valid <= 0;
                    conv_sent_reg <= 0;
                    compute_phase_cnt <= 0;
                end
                
                // ==============================================================
                // Weight 加载：每个 acc_word 从 IBUF 读 CYCLE=8 entries
                // 地址 = wei_base + row_cnt * CYCLE + wei_load_cnt
                // ==============================================================
                ST_LOAD_WEI_REQ: begin
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= wei_base_addr_reg + chunk_base * CYCLE + wei_load_cnt;
                    if (ibuf_handshake_done)
                        ibuf_rd_valid <= 1'b0;
                end
                
                ST_LOAD_WEI_RESP: begin
                    ibuf_rd_valid <= 0;
                    if (ibuf_data_received)
                        ibuf_data_latch <= ibuf_rd_data;
                end
                
                ST_LOAD_WEI_DONE: begin
                    dcim_wr_wei <= 1'b1;
                    dcim_addr_wei <= wei_load_cnt[ADDR_WD-1:0];
                    dcim_data_wei <= ibuf_data_latch;
                    wei_load_cnt <= wei_load_cnt + 1;
                end
                
                // ==============================================================
                // ppCache 加载
                // ==============================================================
                ST_PREP_PPCACHE: begin
                    dcim_addr_wei <= row_cnt * CYCLE;
                    ppcache_cnt <= 0;
                end
                
                ST_LOAD_PPCACHE: begin
                    // row_cnt==0: 2 loads (IDLE→PREPARE→READY), trigger at cnt=0 and cnt=2*CYCLE
                    // row_cnt>0: 1 load (PREPARE→READY), trigger at cnt=0 only
                    if (row_cnt == 0)
                        dcim_load_wei <= (ppcache_cnt == 0) || (ppcache_cnt == 2 * CYCLE);
                    else
                        dcim_load_wei <= (ppcache_cnt == 0);
                    ppcache_cnt <= ppcache_cnt + 1;
                end
                
                ST_SWAP_PPCACHE: begin
                    dcim_swap_wei <= 1'b1;
                end
                
                // ==============================================================
                // Activation 加载
                // ==============================================================
                ST_LOAD_ACT_REQ: begin
                    conv_sent_reg <= 0;
                    compute_phase_cnt <= 0;
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= is_int16 ? (act_base_addr_reg + (chunk_base + row_cnt) * 2)
                                             : (act_base_addr_reg + chunk_base + row_cnt);
                    if (ibuf_handshake_done)
                        ibuf_rd_valid <= 1'b0;
                end
                
                ST_LOAD_ACT_RESP: begin
                    ibuf_rd_valid <= 0;
                    if (ibuf_data_received) begin
                        if (is_int16) begin
                            act_buf_lo <= ibuf_rd_data;
                        end else begin
                            for (int ch = 0; ch < CH_IN; ch++) begin
                                conv_data[ch*16 +: 16] <= {{8{ibuf_rd_data[ch*8 + 7]}}, ibuf_rd_data[ch*8 +: 8]};
                            end
                        end
                    end
                end
                
                ST_LOAD_ACT2_REQ: begin
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= act_base_addr_reg + (chunk_base + row_cnt) * 2 + 1;
                    if (ibuf_handshake_done)
                        ibuf_rd_valid <= 1'b0;
                end
                
                ST_LOAD_ACT2_RESP: begin
                    ibuf_rd_valid <= 0;
                    if (ibuf_data_received) begin
                        conv_data <= {ibuf_rd_data, act_buf_lo};
                    end
                end
                
                // ==============================================================
                // 计算
                // ==============================================================
                ST_COMPUTE: begin
                    conv_valid <= !conv_sent_reg;
                    if (conv_valid && conv_ready) begin
                        conv_sent_reg <= 1'b1;
                    end
                    if (compute_phase_fire) begin
                        compute_phase_cnt <= compute_phase_cnt + 1'b1;
                    end
                    if (compute_done) begin
                        conv_valid <= 1'b0;
                        conv_sent_reg <= 1'b0;
                        compute_phase_cnt <= 0;
                        row_cnt <= row_cnt + 1;
                    end
                end
                
                ST_WAIT_RESULT: begin
`ifdef SIMULATION
                    // 若长时间停在此状态，检查 dcim_valid_out 是否 fire
                    // 原因：结果还在 dcim 核内部流水线中，需等 dcim_valid_out 拉高
`endif
                end
                
                default: begin
                end
            endcase
        end
    end
    
    // ========================================================================
    // 结果保存：OBUF 写入
    // ========================================================================
    reg [2:0] save_phase;
    (* keep = "true" *) reg [OUT_WIDTH-1:0] dcim_data_latch;
    (* keep = "true" *) reg signed [WD3-1:0] phys_ch_reg [0:CH_OUT-1];
    (* keep = "true" *) reg [255:0] int8_packed_reg;
    (* keep = "true" *) reg [127:0] int16_packed_reg;
    
    wire signed [31:0] int8_result [0:7];
    wire signed [31:0] int16_result [0:3];
    
    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : int8_extract
            localparam PHYS_IDX = gi * 2;
            if (WD3 <= 32) begin : sign_extend
                assign int8_result[gi] = {{(32-WD3){phys_ch_reg[PHYS_IDX][WD3-1]}}, phys_ch_reg[PHYS_IDX]};
            end else begin : truncate
                assign int8_result[gi] = phys_ch_reg[PHYS_IDX][31:0];
            end
        end
    endgenerate
    
    // INT16 模式：4 个有效输出通道对应 4 个 accumulate col（col 0..3）
    // 每个 col 的结果存在 temp0(WD3) + temp1(WD3) + temp2(WD3) 中，
    // 完整值 = {temp2, temp1, temp0}（3×WD3 bit），截取低 32 bit 即 INT32 结果。
    // phys_ch_reg[col*4+0] = temp0, phys_ch_reg[col*4+1] = temp1, phys_ch_reg[col*4+2] = temp2
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : int16_extract
            localparam COL_BASE = gi * 4;
            wire [3*WD3-1:0] raw_int16;
            assign raw_int16 = {phys_ch_reg[COL_BASE+2], phys_ch_reg[COL_BASE+1], phys_ch_reg[COL_BASE]};
            assign int16_result[gi] = raw_int16[31:0];
        end
    endgenerate
    
    wire [255:0] int8_packed_comb = {int8_result[7], int8_result[6], int8_result[5], int8_result[4],
                                      int8_result[3], int8_result[2], int8_result[1], int8_result[0]};
    wire [127:0] int16_packed_comb = {int16_result[3], int16_result[2], int16_result[1], int16_result[0]};
    wire [31:0] int8_accum_result [0:7];
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : int8_chunk_accum
            assign int8_accum_result[gi] = int8_result[gi] + int8_partial_accum[gi];
        end
    endgenerate
    wire [255:0] int8_accum_packed_comb = {int8_accum_result[7], int8_accum_result[6],
                                           int8_accum_result[5], int8_accum_result[4],
                                           int8_accum_result[3], int8_accum_result[2],
                                           int8_accum_result[1], int8_accum_result[0]};
    wire [31:0] int16_accum_result [0:3];
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : int16_chunk_accum
            assign int16_accum_result[gi] = int16_result[gi] + int16_partial_accum[gi];
        end
    endgenerate
    wire [127:0] int16_accum_packed_comb = {int16_accum_result[3], int16_accum_result[2],
                                            int16_accum_result[1], int16_accum_result[0]};
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_cnt <= 0;
            obuf_wr_valid <= 0; obuf_wr_addr <= 0; obuf_wr_data <= 0; obuf_wr_strb <= 0;
            save_phase <= 0;
            dcim_data_latch <= 0;
            int8_packed_reg <= 0;
            int16_packed_reg <= 0;
            for (int i = 0; i < CH_OUT; i++) phys_ch_reg[i] <= 0;
        end else begin
            if (state == ST_IDLE) begin
                result_cnt <= 0;
                obuf_wr_valid <= 0;
                save_phase <= 0;
                chunk_continue_req <= 0;
                for (int i = 0; i < 8; i++) int8_partial_accum[i] <= 0;
                for (int i = 0; i < 4; i++) int16_partial_accum[i] <= 0;
            end else begin
                if (state == ST_CLEAR) begin
                    result_cnt <= 0;
                    obuf_wr_valid <= 0;
                    save_phase <= 0;
                    chunk_continue_req <= 0;
                end
                case (save_phase)
                    3'd0: begin
                        obuf_wr_valid <= 0;
                        if (dcim_valid_out && dcim_ready_out) begin
                            dcim_data_latch <= dcim_data_out;
                            save_phase <= 3'd1;
                            `ifdef SIM
                            $display("[%0t] Tile save: dcim_valid_out fired, result_cnt=%0d, out_base=0x%05h", $time, result_cnt, out_base_addr_reg);
                            `endif
                        end
                    end
                    
                    3'd1: begin
                        for (int i = 0; i < CH_OUT; i++) begin
                            phys_ch_reg[i] <= dcim_data_latch[i*WD3 +: WD3];
                        end
                        save_phase <= 3'd2;
                    end
                    
                    3'd2: begin
                        if (chunk_has_more) begin
                            if (is_int16_reg) begin
                                for (int i = 0; i < 4; i++) begin
                                    int16_partial_accum[i] <= int16_partial_accum[i] + int16_result[i];
                                end
                            end else begin
                                for (int i = 0; i < 8; i++) begin
                                    int8_partial_accum[i] <= int8_partial_accum[i] + int8_result[i];
                                end
                            end
                            chunk_continue_req <= 1'b1;
                            save_phase <= 3'd0;
                        end else begin
                            int8_packed_reg <= int8_accum_packed_comb;
                            int16_packed_reg <= int16_packed_comb;
                            // Pre-arm valid + addr/data so phase=3 already has
                            // valid=1 from cycle 0, removing the "valid is 0
                            // on entry" race with the arbiter.
                            obuf_wr_valid <= 1'b1;
                            obuf_wr_strb  <= {(BUF_DATA_WIDTH/8){1'b1}};
                            if (is_int16_reg) begin
                                obuf_wr_addr <= out_base_addr_reg + result_cnt;
                                obuf_wr_data <= int16_accum_packed_comb;
                            end else begin
                                obuf_wr_addr <= out_base_addr_reg + result_cnt * 2;
                                obuf_wr_data <= int8_accum_packed_comb[127:0];
                            end
                            save_phase <= 3'd3;
                        end
                    end
                    
                    3'd3: begin
                        // valid/addr/data already driven from phase=2; just
                        // wait for arbiter ready.
                        if (obuf_wr_ready) begin
                            obuf_wr_valid <= 0;  // Always clear valid after handshake
                            if (is_int16_reg) begin
                                save_phase <= 3'd0;
                                result_cnt <= result_cnt + 1;
                            end else begin
                                // INT8: go to phase=4 for second word.
                                // Clear valid for one cycle to let arbiter's grant_taken reset.
                                save_phase <= 3'd4;
                            end
                        end
                    end
                    
                    3'd4: begin
                        // Second INT8 word: arm valid/addr/data on entry.
                        // Only check ready when our own valid is asserted.
                        obuf_wr_valid <= 1'b1;
                        obuf_wr_strb  <= {(BUF_DATA_WIDTH/8){1'b1}};
                        obuf_wr_addr  <= out_base_addr_reg + result_cnt * 2 + 1;
                        obuf_wr_data  <= int8_packed_reg[255:128];
                        if (obuf_wr_valid && obuf_wr_ready) begin
                            obuf_wr_valid <= 0;
                            save_phase <= 3'd0;
                            result_cnt <= result_cnt + 1;
                        end
                    end
                    
                    default: begin
                        obuf_wr_valid <= 0;
                        save_phase <= 3'd0;
                    end
                endcase
            end
        end
    end

`ifdef SIM
`ifdef PROBE_OBUF_X
    // ========================================================================
    // SIM-only probe: log phase=3/4 valid/ready/addr to debug INT8 second-word issue
    // Off by default; enable with `xvlog -d PROBE_OBUF_X`
    // ========================================================================
    always_ff @(posedge clk) begin
        if (rst_n && (save_phase == 3'd3 || save_phase == 3'd4) &&
            (out_base_addr_reg == 20'h20000)) begin
            $display("[%0t] PROBE.Tile@%m: phase=%0d result_cnt=%0d valid=%b ready=%b addr=0x%05h data[31:0]=0x%08h",
                     $time, save_phase, result_cnt, obuf_wr_valid, obuf_wr_ready,
                     obuf_wr_addr, obuf_wr_data[31:0]);
        end
    end
`endif
`endif

`ifdef SIMULATION
`ifdef PROBE_DCIM_TILE_VALID
    always_ff @(posedge clk) begin
        if (rst_n && dcim_valid_out && dcim_ready_out) begin
            $display("[%0t] DCIM_Tile[%0d] dcim_valid_out fired: result_cnt=%0d save_phase=%0d",
                     $time, TILE_IDX, result_cnt, save_phase);
            if (is_int16_reg && out_base_addr_reg >= 20'h20018 && out_base_addr_reg <= 20'h2001f) begin
                $display("[%0t] DCIM_Tile[%0d] INT16 debug: out_base=0x%05h chunk_base=%0d row_cnt=%0d data_out=0x%0h",
                         $time, TILE_IDX, out_base_addr_reg, chunk_base, row_cnt, dcim_data_out);
            end
        end
        if (rst_n && state == ST_WAIT_RESULT && !all_results_collected && dcim_valid_out === 1'b0)
            if ($time % 10000 == 0)
                $display("[%0t] DCIM_Tile[%0d] WAIT_RESULT: still waiting dcim_valid_out (phase=%0d result_cnt=%0d)",
                         $time, TILE_IDX, save_phase, result_cnt);
    end
`endif
`endif

    // ========================================================================
    // DCIM 计算核心实例化
    // ========================================================================
    act_nibble_converter #(
        .CH_IN(CH_IN)
    ) u_act_nibble_converter (
        .clk          (clk),
        .rst_n        (rst_n),
        .mode         (mode_reg),
        .raw_act_valid(conv_valid),
        .raw_act_ready(conv_ready),
        .raw_act_data (conv_data),
        .dcim_act_valid(dcim_valid_act),
        .dcim_act_ready(dcim_ready_act),
        .dcim_act_data (dcim_data_act)
    );

    dcim #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC)
    ) u_dcim (
        .clk(clk), .rstn(rst_n), .clr(dcim_clr), .ena(dcim_ena),
        .mode_cal(mode_reg), .acc(chunk_rows),
        .wr_wei(dcim_wr_wei), .load_wei(dcim_load_wei), .swap_wei(dcim_swap_wei),
        .up_ready_wei(dcim_ready_wei), .up_address_wei(dcim_addr_wei),
        .up_data_wei(dcim_data_wei), .up_be_wei({SRAM_WD{1'b1}}),
        .up_valid_cal(dcim_valid_act), .up_ready_cal(dcim_ready_act),
        .up_data_cal(dcim_data_act),
        .dn_valid(dcim_valid_out), .dn_ready(dcim_ready_out), .dn_data(dcim_data_out)
    );

endmodule
