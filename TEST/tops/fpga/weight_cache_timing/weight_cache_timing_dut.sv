`timescale 1ns/1ps

// Reduced implementation model of the production DCIM_Weight_Cache critical
// topology.  It preserves the real 64 x 128-bit, double-buffered cache and the
// 5120 x 128-bit BRAM store, while omitting unrelated Tile control logic.
//
// REPLICAS=1 models the current single load_data register.  REPLICAS=4 keeps
// four physical copies and statically assigns 16 cache words to each copy.
module weight_cache_timing_dut #(
    parameter integer REPLICAS = 1,
    parameter integer WORD_WIDTH = 128,
    parameter integer CYCLE = 64,
    parameter integer STORE_DEPTH = 5120
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         store_wr_valid,
    input  wire [$clog2(STORE_DEPTH)-1:0] store_wr_addr,
    input  wire [WORD_WIDTH-1:0]        store_wr_data,
    input  wire                         row_load_start,
    input  wire [$clog2(STORE_DEPTH)-1:0] row_load_base,
    input  wire                         load_bank,
    output wire                         row_load_done,
    output wire [CYCLE*WORD_WIDTH-1:0]  cache0_flat,
    output wire [CYCLE*WORD_WIDTH-1:0]  cache1_flat
);
    localparam integer STORE_AW = $clog2(STORE_DEPTH);
    localparam integer CYCLE_AW = $clog2(CYCLE);

    reg load_active;
    reg [STORE_AW-1:0] load_base;
    reg [CYCLE_AW-1:0] load_req_word;
    reg load_rsp_valid;
    reg [CYCLE_AW-1:0] load_rsp_word;
    reg load_data_valid;
    reg [CYCLE_AW-1:0] load_data_word;
    reg done_r;

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
        for (word_i = 0; word_i < CYCLE; word_i = word_i + 1) begin : gen_flatten
            assign cache0_flat[word_i*WORD_WIDTH +: WORD_WIDTH] = cache0[word_i];
            assign cache1_flat[word_i*WORD_WIDTH +: WORD_WIDTH] = cache1[word_i];
        end
    endgenerate

    assign row_load_done = done_r;

    generate
        if (REPLICAS == 1) begin : gen_baseline
            reg [WORD_WIDTH-1:0] load_data;

            always_ff @(posedge clk) begin
                if (load_rsp_valid)
                    load_data <= mem_q;

                if (load_data_valid) begin
                    if (load_bank)
                        cache1[load_data_word] <= load_data;
                    else
                        cache0[load_data_word] <= load_data;
                end
            end
        end else begin : gen_replicated
            // Explicit copies are required: MAX_FANOUT alone is advisory and
            // Vivado can otherwise merge the pipeline into the BRAM output.
            (* keep = "true", dont_touch = "true", max_fanout = 32,
               shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep0;
            (* keep = "true", dont_touch = "true", max_fanout = 32,
               shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep1;
            (* keep = "true", dont_touch = "true", max_fanout = 32,
               shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep2;
            (* keep = "true", dont_touch = "true", max_fanout = 32,
               shreg_extract = "no" *) reg [WORD_WIDTH-1:0] load_data_rep3;

            always_ff @(posedge clk) begin
                if (load_rsp_valid) begin
                    load_data_rep0 <= mem_q;
                    load_data_rep1 <= mem_q;
                    load_data_rep2 <= mem_q;
                    load_data_rep3 <= mem_q;
                end

                if (load_data_valid) begin
                    case (load_data_word[CYCLE_AW-1:CYCLE_AW-2])
                        2'd0: begin
                            if (load_bank) cache1[load_data_word] <= load_data_rep0;
                            else           cache0[load_data_word] <= load_data_rep0;
                        end
                        2'd1: begin
                            if (load_bank) cache1[load_data_word] <= load_data_rep1;
                            else           cache0[load_data_word] <= load_data_rep1;
                        end
                        2'd2: begin
                            if (load_bank) cache1[load_data_word] <= load_data_rep2;
                            else           cache0[load_data_word] <= load_data_rep2;
                        end
                        default: begin
                            if (load_bank) cache1[load_data_word] <= load_data_rep3;
                            else           cache0[load_data_word] <= load_data_rep3;
                        end
                    endcase
                end
            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_active <= 1'b0;
            load_base <= '0;
            load_req_word <= '0;
            load_rsp_valid <= 1'b0;
            load_rsp_word <= '0;
            load_data_valid <= 1'b0;
            load_data_word <= '0;
            done_r <= 1'b0;
        end else begin
            done_r <= 1'b0;
            if (row_load_start && !load_active && !load_rsp_valid && !load_data_valid) begin
                load_active <= 1'b1;
                load_base <= row_load_base;
                load_req_word <= '0;
            end else if (load_active) begin
                if (load_req_word == CYCLE-1) begin
                    load_active <= 1'b0;
                    load_req_word <= '0;
                end else begin
                    load_req_word <= load_req_word + 1'b1;
                end
            end

            load_rsp_valid <= load_active;
            if (load_active)
                load_rsp_word <= load_req_word;

            load_data_valid <= load_rsp_valid;
            if (load_rsp_valid)
                load_data_word <= load_rsp_word;

            if (load_data_valid && load_data_word == CYCLE-1)
                done_r <= 1'b1;
        end
    end
endmodule
