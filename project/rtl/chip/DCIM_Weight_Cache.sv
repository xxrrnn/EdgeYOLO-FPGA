`timescale 1ns / 1ns
`include "chip_defines.vh"

// Per-Tile layer-weight store and double-buffered compute cache.
//
// Expected input mapping:
//   store_addr = acc_row * CYCLE + word_in_row
//   one CYCLE-word row expands to CH_IN*CH_OUT*WD1 compute bits.
//
// All layer weights are copied once from tile_ibuf into block RAM.  During a
// pixel micro-batch, the inactive wide cache is filled from BRAM while the
// active cache continuously drives calculate_core.  No DSP or URAM is used.
module DCIM_Weight_Cache #(
    parameter WD1        = `DCIM_WD1,
    parameter CH_IN      = `DCIM_CH_IN,
    parameter CH_OUT     = `DCIM_CH_OUT,
    parameter CYCLE      = `DCIM_CYCLE,
    parameter ACC        = `DCIM_ACC_MAX,
    parameter WORD_WIDTH = `DCIM_BUF_DATA_WIDTH,

    localparam STORE_DEPTH = CYCLE * ACC,
    localparam STORE_AW    = $clog2(STORE_DEPTH),
    localparam ROW_AW      = $clog2(ACC + 1),
    localparam CYCLE_AW    = $clog2(CYCLE),
    localparam CACHE_WIDTH = CYCLE * WORD_WIDTH
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   clear,

    input  wire                   store_wr_valid,
    input  wire [STORE_AW-1:0]    store_wr_addr,
    input  wire [WORD_WIDTH-1:0]  store_wr_data,

    input  wire                   row_load_start,
    input  wire [ROW_AW-1:0]      row_load_index,
    output wire                   row_load_busy,
    output reg                    row_load_done,

    input  wire                   row_activate,
    output reg                    weight_valid,
    output wire [CACHE_WIDTH-1:0] weight_data
);

    initial begin
        if (CACHE_WIDTH != CH_IN * CH_OUT * WD1)
            $error("DCIM_Weight_Cache mapping mismatch cache=%0d compute=%0d",
                   CACHE_WIDTH, CH_IN * CH_OUT * WD1);
    end

    reg active_bank;
    reg load_bank;
    reg load_active;
    reg standby_valid;
    reg [STORE_AW-1:0] load_base;
    reg [CYCLE_AW-1:0] load_req_word;
    reg                 load_rsp_valid;
    reg [CYCLE_AW-1:0] load_rsp_word;
    reg                 load_data_valid;
    reg [CYCLE_AW-1:0]  load_data_word;

    // Four explicit response-register copies keep each 128-bit data net local
    // to one quarter of the 64-word cache.  KEEP/DONT_TOUCH are intentional:
    // without them Vivado folds this stage into the BRAM output and recreates
    // the 128-fanout, routing-dominated BRAM-to-cache critical path.
    (* keep = "true", dont_touch = "true", max_fanout = 32,
       shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep0;
    (* keep = "true", dont_touch = "true", max_fanout = 32,
       shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep1;
    (* keep = "true", dont_touch = "true", max_fanout = 32,
       shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep2;
    (* keep = "true", dont_touch = "true", max_fanout = 32,
       shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep3;
    // Four lane-local copies keep each one-hot write enable at fanout 32
    // instead of driving all 128 bits in a cache word.
    (* keep = "true", dont_touch = "true", max_fanout = 32,
       shreg_extract = "no" *) reg [3:0][CYCLE-1:0] load_we_cache0;
    (* keep = "true", dont_touch = "true", max_fanout = 32,
       shreg_extract = "no" *) reg [3:0][CYCLE-1:0] load_we_cache1;

    assign row_load_busy = load_active | load_rsp_valid | load_data_valid;

    wire [STORE_AW-1:0] load_mem_addr = load_base + load_req_word;
    wire mem_enable = store_wr_valid | load_active;
    wire [STORE_AW-1:0] mem_addr = store_wr_valid ? store_wr_addr : load_mem_addr;
    wire [WORD_WIDTH-1:0] mem_q;

    model_rf_bram #(
        .WIDTH(WORD_WIDTH),
        .DEPTH(STORE_DEPTH)
    ) u_weight_store (
        .clk (clk),
        .cen (~mem_enable),
        .gwen(~store_wr_valid),
        .wen ({WORD_WIDTH{1'b0}}),
        .d   (store_wr_data),
        .a   (mem_addr),
        .q   (mem_q)
    );

    reg [WORD_WIDTH-1:0] cache0 [0:CYCLE-1];
    reg [WORD_WIDTH-1:0] cache1 [0:CYCLE-1];

    genvar word_i;
    generate
        for (word_i = 0; word_i < CYCLE; word_i = word_i + 1) begin : gen_weight_bus
            // One select register per 128-bit word is enough to preserve the
            // atomic bank swap while replacing an 8194-load global mux select
            // with short local nets.  It need not be reset: weight_valid remains
            // low until row_activate initializes every copy.
            (* keep = "true", max_fanout = 32 *) reg active_bank_sel;
            always_ff @(posedge clk) begin
                if (row_activate)
                    active_bank_sel <= ~active_bank;
            end
            assign weight_data[word_i*WORD_WIDTH +: WORD_WIDTH] =
                active_bank_sel ? cache1[word_i] : cache0[word_i];
        end
    endgenerate

    // Data-only response registers intentionally have no reset.  They are
    // consumed only when load_data_valid is asserted after a real BRAM read.
    // Keeping this in a separate clocked process also prevents synthesis from
    // inferring FDCP cells from the resettable control process below.
    always_ff @(posedge clk) begin
        load_we_cache0 <= '0;
        load_we_cache1 <= '0;
        if (load_rsp_valid) begin
            load_data_rep0 <= mem_q;
            load_data_rep1 <= mem_q;
            load_data_rep2 <= mem_q;
            load_data_rep3 <= mem_q;
            if (load_bank) begin
                load_we_cache1[0][load_rsp_word] <= 1'b1;
                load_we_cache1[1][load_rsp_word] <= 1'b1;
                load_we_cache1[2][load_rsp_word] <= 1'b1;
                load_we_cache1[3][load_rsp_word] <= 1'b1;
            end else begin
                load_we_cache0[0][load_rsp_word] <= 1'b1;
                load_we_cache0[1][load_rsp_word] <= 1'b1;
                load_we_cache0[2][load_rsp_word] <= 1'b1;
                load_we_cache0[3][load_rsp_word] <= 1'b1;
            end
        end
    end

    // Static per-word writers avoid synthesizing a 64-way dynamic array write
    // mux.  Each one-hot bit and each response copy remains local to at most one
    // 128-bit cache word; the host-visible row/word mapping is unchanged.
    generate
        for (word_i = 0; word_i < CYCLE; word_i = word_i + 1) begin : gen_cache_write
            if (word_i < CYCLE/4) begin : gen_rep0
                always_ff @(posedge clk) begin
                    if (load_we_cache0[0][word_i]) cache0[word_i][31:0]   <= load_data_rep0[31:0];
                    if (load_we_cache0[1][word_i]) cache0[word_i][63:32]  <= load_data_rep0[63:32];
                    if (load_we_cache0[2][word_i]) cache0[word_i][95:64]  <= load_data_rep0[95:64];
                    if (load_we_cache0[3][word_i]) cache0[word_i][127:96] <= load_data_rep0[127:96];
                    if (load_we_cache1[0][word_i]) cache1[word_i][31:0]   <= load_data_rep0[31:0];
                    if (load_we_cache1[1][word_i]) cache1[word_i][63:32]  <= load_data_rep0[63:32];
                    if (load_we_cache1[2][word_i]) cache1[word_i][95:64]  <= load_data_rep0[95:64];
                    if (load_we_cache1[3][word_i]) cache1[word_i][127:96] <= load_data_rep0[127:96];
                end
            end else if (word_i < CYCLE/2) begin : gen_rep1
                always_ff @(posedge clk) begin
                    if (load_we_cache0[0][word_i]) cache0[word_i][31:0]   <= load_data_rep1[31:0];
                    if (load_we_cache0[1][word_i]) cache0[word_i][63:32]  <= load_data_rep1[63:32];
                    if (load_we_cache0[2][word_i]) cache0[word_i][95:64]  <= load_data_rep1[95:64];
                    if (load_we_cache0[3][word_i]) cache0[word_i][127:96] <= load_data_rep1[127:96];
                    if (load_we_cache1[0][word_i]) cache1[word_i][31:0]   <= load_data_rep1[31:0];
                    if (load_we_cache1[1][word_i]) cache1[word_i][63:32]  <= load_data_rep1[63:32];
                    if (load_we_cache1[2][word_i]) cache1[word_i][95:64]  <= load_data_rep1[95:64];
                    if (load_we_cache1[3][word_i]) cache1[word_i][127:96] <= load_data_rep1[127:96];
                end
            end else if (word_i < (3*CYCLE)/4) begin : gen_rep2
                always_ff @(posedge clk) begin
                    if (load_we_cache0[0][word_i]) cache0[word_i][31:0]   <= load_data_rep2[31:0];
                    if (load_we_cache0[1][word_i]) cache0[word_i][63:32]  <= load_data_rep2[63:32];
                    if (load_we_cache0[2][word_i]) cache0[word_i][95:64]  <= load_data_rep2[95:64];
                    if (load_we_cache0[3][word_i]) cache0[word_i][127:96] <= load_data_rep2[127:96];
                    if (load_we_cache1[0][word_i]) cache1[word_i][31:0]   <= load_data_rep2[31:0];
                    if (load_we_cache1[1][word_i]) cache1[word_i][63:32]  <= load_data_rep2[63:32];
                    if (load_we_cache1[2][word_i]) cache1[word_i][95:64]  <= load_data_rep2[95:64];
                    if (load_we_cache1[3][word_i]) cache1[word_i][127:96] <= load_data_rep2[127:96];
                end
            end else begin : gen_rep3
                always_ff @(posedge clk) begin
                    if (load_we_cache0[0][word_i]) cache0[word_i][31:0]   <= load_data_rep3[31:0];
                    if (load_we_cache0[1][word_i]) cache0[word_i][63:32]  <= load_data_rep3[63:32];
                    if (load_we_cache0[2][word_i]) cache0[word_i][95:64]  <= load_data_rep3[95:64];
                    if (load_we_cache0[3][word_i]) cache0[word_i][127:96] <= load_data_rep3[127:96];
                    if (load_we_cache1[0][word_i]) cache1[word_i][31:0]   <= load_data_rep3[31:0];
                    if (load_we_cache1[1][word_i]) cache1[word_i][63:32]  <= load_data_rep3[63:32];
                    if (load_we_cache1[2][word_i]) cache1[word_i][95:64]  <= load_data_rep3[95:64];
                    if (load_we_cache1[3][word_i]) cache1[word_i][127:96] <= load_data_rep3[127:96];
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_bank <= 1'b0;
            load_bank <= 1'b1;
            load_active <= 1'b0;
            standby_valid <= 1'b0;
            load_base <= '0;
            load_req_word <= '0;
            load_rsp_valid <= 1'b0;
            load_rsp_word <= '0;
            load_data_valid <= 1'b0;
            load_data_word <= '0;
            row_load_done <= 1'b0;
            weight_valid <= 1'b0;
        end else if (clear) begin
            active_bank <= 1'b0;
            load_bank <= 1'b1;
            load_active <= 1'b0;
            standby_valid <= 1'b0;
            load_base <= '0;
            load_req_word <= '0;
            load_rsp_valid <= 1'b0;
            load_rsp_word <= '0;
            load_data_valid <= 1'b0;
            load_data_word <= '0;
            row_load_done <= 1'b0;
            weight_valid <= 1'b0;
        end else begin
            row_load_done <= 1'b0;

            if (row_activate) begin
                active_bank <= ~active_bank;
                weight_valid <= 1'b1;
                standby_valid <= 1'b0;
            end

            if (row_load_start && !row_load_busy) begin
                load_bank <= ~active_bank;
                load_active <= 1'b1;
                load_base <= row_load_index * CYCLE;
                load_req_word <= '0;
            end else if (load_active) begin
                if (load_req_word == CYCLE-1) begin
                    load_active <= 1'b0;
                    load_req_word <= '0;
                end else begin
                    load_req_word <= load_req_word + 1'b1;
                end
            end

            // model_rf_bram is a one-cycle synchronous read.  Capture the
            // request index beside it and write the inactive wide cache when
            // the corresponding word appears.
            load_rsp_valid <= load_active;
            if (load_active)
                load_rsp_word <= load_req_word;

            // The additional response register is deliberately outside the wide
            // cache write.  Vivado can merge it into the memory output register,
            // breaking the four-RAMB cascade-to-cache timing path.  Only preload
            // latency grows by one clock; compute throughput is unchanged.
            load_data_valid <= load_rsp_valid;
            if (load_rsp_valid) begin
                load_data_word <= load_rsp_word;
            end

            if (load_data_valid) begin
                if (load_data_word == CYCLE-1)
                    row_load_done <= 1'b1;
                if (load_data_word == CYCLE-1)
                    standby_valid <= 1'b1;
            end
        end
    end

`ifdef SIMULATION
    always_ff @(posedge clk) begin
        if (rst_n && store_wr_valid && row_load_busy)
            $fatal(1, "DCIM_Weight_Cache store/load port conflict");
        if (rst_n && row_activate && !standby_valid)
            $fatal(1, "DCIM_Weight_Cache activated before row load completed");
    end
`endif

endmodule
