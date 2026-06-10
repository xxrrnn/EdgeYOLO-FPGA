`timescale 1ns / 1ps
// LUT 版乘法器（禁止 DSP）。MULT_DSP_EN=0 的 Tile 使用此模块。
// 对应 DSP 版：multiplier_dsp.v（use_dsp="yes"）
// 独立模块名保证 Vivado 不会做跨模块 sharing，属性各自生效。
//
// 内含 1 级 input pipeline（与 multiplier_dsp 延迟一致）:
//   Cycle N:   ext_a/ext_b 组合计算
//   Cycle N+1: a_reg/b_reg 锁存 → multiply 组合输出 product
// 延迟: 1 cycle (与 multiplier_dsp.v 一致)
module multiplier #(
	parameter WD_IN  = 4,
	parameter WD_OUT = 2 * WD_IN
) (
	input              clk,
	input              rstn,
	input              ena,
	input  [WD_IN-1:0] a,
	input  [WD_IN-1:0] b,
	input              sa,
	input              sb,
	output [WD_OUT-1:0] c
);
	wire signed [WD_OUT-1:0] ext_a;
	wire signed [WD_OUT-1:0] ext_b;
	assign ext_a = sa ? $signed({{(WD_OUT - WD_IN) {a[WD_IN-1]}}, a})
	                  : $signed({{(WD_OUT - WD_IN) {1'b0}}, a});
	assign ext_b = sb ? $signed({{(WD_OUT - WD_IN) {b[WD_IN-1]}}, b})
	                  : $signed({{(WD_OUT - WD_IN) {1'b0}}, b});

	// Input pipeline registers (与 multiplier_dsp 保持一致的 1-cycle 延迟)
	reg signed [WD_OUT-1:0] a_reg;
	reg signed [WD_OUT-1:0] b_reg;

	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			a_reg <= {WD_OUT{1'b0}};
			b_reg <= {WD_OUT{1'b0}};
		end else if (ena) begin
			a_reg <= ext_a;
			b_reg <= ext_b;
		end
	end

	(* use_dsp = "no" *) wire signed [2*WD_OUT-1:0] prod_full;
	assign prod_full = a_reg * b_reg;
	assign c = prod_full[WD_OUT-1:0];
endmodule
