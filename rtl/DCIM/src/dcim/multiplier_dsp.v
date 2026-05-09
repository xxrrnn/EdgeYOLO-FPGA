`timescale 1ns / 1ps
// DSP-inferrable signed/unsigned 4x4-bit multiplier
// Uses behavioral description that Vivado can map to DSP48E2
// Supports mixed signed/unsigned via sa/sb flags (same as original multiplier.v)

(* use_dsp = "yes" *)
module multiplier #(
    parameter WD_IN = 4,
    parameter WD_OUT = 2*WD_IN
)(
    input  wire [WD_IN-1:0]  a,
    input  wire [WD_IN-1:0]  b,
    input  wire              sa,  // a is signed
    input  wire              sb,  // b is signed
    output wire [WD_OUT-1:0] c
);

    // Sign-extend inputs based on sign flags
    wire signed [WD_IN:0] a_ext = sa ? $signed({a[WD_IN-1], a}) : $signed({1'b0, a});
    wire signed [WD_IN:0] b_ext = sb ? $signed({b[WD_IN-1], b}) : $signed({1'b0, b});
    
    // Perform signed multiplication
    wire signed [2*WD_IN+1:0] product_full = a_ext * b_ext;
    
    // Truncate to output width
    assign c = product_full[WD_OUT-1:0];

endmodule
