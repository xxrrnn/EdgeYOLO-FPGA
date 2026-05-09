`timescale 1ns / 1ps
`include "dcim_defs.vh"

module xdma_dcim_preprocess #(
    parameter integer CH_IN = `DCIM_CH_IN,
    parameter integer INT8_OUT_COLS = (`DCIM_CH_OUT / 2),
    parameter integer INT16_OUT_COLS = (`DCIM_CH_OUT / 4),
    parameter integer RAW_ACT_WORD_WIDTH = `DCIM_BRAM_DATA_WIDTH,
    parameter integer RAW_WEIGHT_WIDTH = `DCIM_TILE_WIDTH,
    parameter integer DCIM_ACT_WIDTH = `DCIM_ACT_WIDTH,
    parameter integer DCIM_WEIGHT_WIDTH = `DCIM_TILE_WIDTH
) (
    input  wire [2:0]                      mode_i,
    input  wire [RAW_WEIGHT_WIDTH-1:0]   raw_weight_i,
    output wire [DCIM_WEIGHT_WIDTH-1:0]  dcim_weight_o,

    input  wire [RAW_ACT_WORD_WIDTH-1:0] raw_act_word_i,
    input  wire                          raw_act_row_sel_i,
    output wire [DCIM_ACT_WIDTH-1:0]     dcim_act_nib3_o,
    output wire [DCIM_ACT_WIDTH-1:0]     dcim_act_nib2_o,
    output wire [DCIM_ACT_WIDTH-1:0]     dcim_act_nib1_o,
    output wire [DCIM_ACT_WIDTH-1:0]     dcim_act_nib0_o
);

    localparam [2:0] MODE_INT16 = `DCIM_MODE_INT16;
    wire mode_int16 = (mode_i == MODE_INT16);

    reg [DCIM_ACT_WIDTH-1:0] act_nib3_r;
    reg [DCIM_ACT_WIDTH-1:0] act_nib2_r;
    reg [DCIM_ACT_WIDTH-1:0] act_nib1_r;
    reg [DCIM_ACT_WIDTH-1:0] act_nib0_r;
    reg [DCIM_WEIGHT_WIDTH-1:0] weight_r;

    integer ch;
    integer col;
    reg [7:0] act_byte;
    reg [15:0] act_halfword;
    reg [7:0] weight_byte;
    reg [15:0] weight_halfword;
    always @(*) begin
        act_nib3_r = '0;
        act_nib2_r = '0;
        act_nib1_r = '0;
        act_nib0_r = '0;
        weight_r   = '0;

        if (mode_int16) begin
            for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                act_halfword = raw_act_word_i[ch*16 +: 16];
                // int16 mode consumes activation nibbles from MSB to LSB.
                act_nib3_r[ch*4 +: 4] = act_halfword[15:12];
                act_nib2_r[ch*4 +: 4] = act_halfword[11:8];
                act_nib1_r[ch*4 +: 4] = act_halfword[7:4];
                act_nib0_r[ch*4 +: 4] = act_halfword[3:0];
            end
            for (col = 0; col < INT16_OUT_COLS; col = col + 1) begin
                for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                    weight_halfword = raw_weight_i[(ch*INT16_OUT_COLS + col)*16 +: 16];
                    // Lane order follows merge/sign logic: nib0..nib3.
                    weight_r[((4*col + 0)*CH_IN + ch)*4 +: 4] = weight_halfword[3:0];
                    weight_r[((4*col + 1)*CH_IN + ch)*4 +: 4] = weight_halfword[7:4];
                    weight_r[((4*col + 2)*CH_IN + ch)*4 +: 4] = weight_halfword[11:8];
                    weight_r[((4*col + 3)*CH_IN + ch)*4 +: 4] = weight_halfword[15:12];
                end
            end
        end else begin
            for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                act_byte = raw_act_word_i[(raw_act_row_sel_i ? 128 : 0) + ch*8 +: 8];
                act_nib3_r[ch*4 +: 4] = act_byte[7:4];
                act_nib0_r[ch*4 +: 4] = act_byte[3:0];
            end
            for (col = 0; col < INT8_OUT_COLS; col = col + 1) begin
                for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                    weight_byte = raw_weight_i[(ch*INT8_OUT_COLS + col)*8 +: 8];
                    weight_r[((2*col)*CH_IN + ch)*4 +: 4] = weight_byte[3:0];
                    weight_r[((2*col + 1)*CH_IN + ch)*4 +: 4] = weight_byte[7:4];
                end
            end
        end
    end

    assign dcim_act_nib3_o = act_nib3_r;
    assign dcim_act_nib2_o = act_nib2_r;
    assign dcim_act_nib1_o = act_nib1_r;
    assign dcim_act_nib0_o = act_nib0_r;
    assign dcim_weight_o = weight_r;

endmodule
