`timescale 1ns / 1ps
`include "dcim_defs.vh"

// Pack BRAM/XDMA raw tiles into calculate_core WD1=4 tensors.
// INT8:  activation rows are int8 (two rows packed per 256-bit ibuf word); two nibble phases.
//        Weights: byte pairs two int8 outputs per storage column (same as rtl/DCIM tb).
// INT16: activation row is int16×CH_IN = one 256-bit word; four nibble phases [15:12]..[3:0].
//        Weights: one int16 per (CH_IN × CH_OUT/4) cell; nibbles map to four adjacent CH_OUT
//        lanes (same packing as rtl/DCIM/tb/dcim_tb.sv INT16 write_weights).

module xdma_dcim_preprocess #(
    parameter integer CH_IN = `DCIM_CH_IN,
    parameter integer CH_OUT = `DCIM_CH_OUT,
    parameter integer RAW_ACT_WORD_WIDTH = `DCIM_BRAM_DATA_WIDTH,
    parameter integer RAW_WEIGHT_WIDTH = `DCIM_TILE_WIDTH,
    parameter integer DCIM_ACT_WIDTH = `DCIM_ACT_WIDTH,
    parameter integer DCIM_WEIGHT_WIDTH = `DCIM_TILE_WIDTH,
    localparam integer INT8_COLS = (CH_OUT / 2),
    localparam integer INT16_GROUPS = (CH_OUT / 4)
) (
    input  wire [2:0]                    mode_i,
    input  wire [1:0]                    nibble_phase_i,

    input  wire [RAW_WEIGHT_WIDTH-1:0]   raw_weight_i,
    output wire [DCIM_WEIGHT_WIDTH-1:0]  dcim_weight_o,

    input  wire [RAW_ACT_WORD_WIDTH-1:0] raw_act_word_i,
    input  wire                          raw_act_row_sel_i,
    output wire [DCIM_ACT_WIDTH-1:0]     dcim_act_o
);

    localparam [2:0] MODE_INT8  = `DCIM_MODE_INT8;
    localparam [2:0] MODE_INT16 = `DCIM_MODE_INT16;

    wire int8_mode  = (mode_i == MODE_INT8);
    wire int16_mode = (mode_i == MODE_INT16);

    wire [DCIM_WEIGHT_WIDTH-1:0] weight_int8;
    wire [DCIM_WEIGHT_WIDTH-1:0] weight_int16;

    genvar ch;
    genvar col;
    genvar g;

    // --- activations ------------------------------------------------------
    generate
        for (ch = 0; ch < CH_IN; ch = ch + 1) begin : GenAct
            wire [7:0] act_byte;
            wire [15:0] act_half;
            assign act_byte = raw_act_word_i[(raw_act_row_sel_i ? 128 : 0) + ch * 8 +: 8];
            assign act_half = raw_act_word_i[ch * 16 +: 16];
            assign dcim_act_o[ch * 4 +: 4] =
                int16_mode ? act_half[15 - 4 * nibble_phase_i -: 4]
                           : (int8_mode ? (nibble_phase_i[0] ? act_byte[3:0] : act_byte[7:4])
                                        : 4'b0);
        end
    endgenerate

    // --- weights INT8 (unchanged packing) ---------------------------------
    generate
        for (col = 0; col < INT8_COLS; col = col + 1) begin : GenWeightCols8
            for (ch = 0; ch < CH_IN; ch = ch + 1) begin : GenWeightRows8
                wire [7:0] weight_byte;
                assign weight_byte = raw_weight_i[(ch * INT8_COLS + col) * 8 +: 8];
                assign weight_int8[((2 * col) * CH_IN + ch) * 4 +: 4] = weight_byte[3:0];
                assign weight_int8[((2 * col + 1) * CH_IN + ch) * 4 +: 4] = weight_byte[7:4];
            end
        end
    endgenerate

    // --- weights INT16: expand each int16 to four adjacent CH_OUT lanes (rtl/DCIM tb) ---
    generate
        for (g = 0; g < INT16_GROUPS; g = g + 1) begin : GenWeightGrp16
            for (ch = 0; ch < CH_IN; ch = ch + 1) begin : GenWeightCh16
                wire [15:0] weight_half;
                assign weight_half = raw_weight_i[(ch * INT16_GROUPS + g) * 16 +: 16];
                assign weight_int16[((4 * g + 0) * CH_IN + ch) * 4 +: 4] = weight_half[15:12];
                assign weight_int16[((4 * g + 1) * CH_IN + ch) * 4 +: 4] = weight_half[11:8];
                assign weight_int16[((4 * g + 2) * CH_IN + ch) * 4 +: 4] = weight_half[7:4];
                assign weight_int16[((4 * g + 3) * CH_IN + ch) * 4 +: 4] = weight_half[3:0];
            end
        end
    endgenerate

    assign dcim_weight_o = int16_mode ? weight_int16 : weight_int8;

endmodule
