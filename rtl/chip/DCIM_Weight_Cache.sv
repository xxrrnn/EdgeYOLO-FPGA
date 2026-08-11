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

    assign row_load_busy = load_active | load_rsp_valid;

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
            assign weight_data[word_i*WORD_WIDTH +: WORD_WIDTH] =
                active_bank ? cache1[word_i] : cache0[word_i];
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

            if (load_rsp_valid) begin
                if (load_bank)
                    cache1[load_rsp_word] <= mem_q;
                else
                    cache0[load_rsp_word] <= mem_q;

                if (load_rsp_word == CYCLE-1)
                    row_load_done <= 1'b1;
                if (load_rsp_word == CYCLE-1)
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
