`timescale 1ns / 1ps
// DSP48E2 版乘法器（use_dsp="yes"）。MULT_DSP_EN=1 的 Tile 使用此模块。
// 对应 LUT 版：multiplier.v（use_dsp="no"）
// 独立模块名保证 Vivado 不会做跨模块 sharing，属性各自生效。
module multiplier_dsp #(
	parameter WD_IN  = 4,
	parameter WD_OUT = 2 * WD_IN
) (
	input  [WD_IN-1:0]  a,
	input  [WD_IN-1:0]  b,
	input               sa,
	input               sb,
	output [WD_OUT-1:0] c
);
	wire signed [WD_OUT-1:0] ext_a;
	wire signed [WD_OUT-1:0] ext_b;
	assign ext_a = sa ? $signed({{(WD_OUT - WD_IN) {a[WD_IN-1]}}, a})
	                  : $signed({{(WD_OUT - WD_IN) {1'b0}}, a});
	assign ext_b = sb ? $signed({{(WD_OUT - WD_IN) {b[WD_IN-1]}}, b})
	                  : $signed({{(WD_OUT - WD_IN) {1'b0}}, b});

	(* use_dsp = "yes" *) wire signed [2*WD_OUT-1:0] prod_full;
	assign prod_full = ext_a * ext_b;
	assign c = prod_full[WD_OUT-1:0];
endmodule
