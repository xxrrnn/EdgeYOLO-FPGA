`timescale 1ns / 1ps

module xdma_dcim_preprocess #(
    parameter integer CH_IN = 16,
    parameter integer INT8_OUT_COLS = 8,
    parameter integer RAW_ACT_WORD_WIDTH = 256,
    parameter integer RAW_WEIGHT_WIDTH = 1024,
    parameter integer DCIM_ACT_WIDTH = 64,
    parameter integer DCIM_WEIGHT_WIDTH = 1024
) (
    input  wire [RAW_WEIGHT_WIDTH-1:0]   raw_weight_i,
    output wire [DCIM_WEIGHT_WIDTH-1:0]  dcim_weight_o,

    input  wire [RAW_ACT_WORD_WIDTH-1:0] raw_act_word_i,
    input  wire                          raw_act_row_sel_i,
    output wire [DCIM_ACT_WIDTH-1:0]     dcim_act_high_o,
    output wire [DCIM_ACT_WIDTH-1:0]     dcim_act_low_o
);

    genvar ch;
    genvar col;

    generate
        for (ch = 0; ch < CH_IN; ch = ch + 1) begin : GenAct
            wire [7:0] act_byte;
            assign act_byte = raw_act_word_i[(raw_act_row_sel_i ? 128 : 0) + ch*8 +: 8];
            assign dcim_act_high_o[ch*4 +: 4] = act_byte[7:4];
            assign dcim_act_low_o [ch*4 +: 4] = act_byte[3:0];
        end

        for (col = 0; col < INT8_OUT_COLS; col = col + 1) begin : GenWeightCols
            for (ch = 0; ch < CH_IN; ch = ch + 1) begin : GenWeightRows
                wire [7:0] weight_byte;
                assign weight_byte = raw_weight_i[(ch*INT8_OUT_COLS + col)*8 +: 8];
                assign dcim_weight_o[((2*col)*CH_IN + ch)*4 +: 4] = weight_byte[3:0];
                assign dcim_weight_o[((2*col + 1)*CH_IN + ch)*4 +: 4] = weight_byte[7:4];
            end
        end
    endgenerate

endmodule
