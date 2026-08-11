`timescale 1ns / 1ps
// DSP48E2 版乘法器（use_dsp="yes"）。MULT_DSP_EN=1 的 Tile 使用此模块。
// 对应 LUT 版：multiplier.v（use_dsp="no"）
// 独立模块名保证 Vivado 不会做跨模块 sharing，属性各自生效。
//
// 内含 1 级 input pipeline（Vivado 推断为 DSP48E2 AREG=1, BREG=1）:
//   Cycle N:   ext_a/ext_b 组合计算(从外部 data1_reg/s2_reg)
//   Cycle N+1: a_reg/b_reg 锁存 → multiply 组合输出 product
// 延迟: 1 cycle (与 multiplier.v 一致)
module multiplier_dsp #(
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

	// Input pipeline registers → Vivado infers AREG=1, BREG=1 on DSP48E2
	reg signed [WD_OUT-1:0] a_reg;
	reg signed [WD_OUT-1:0] b_reg;

	// These are data-only pipeline registers.  Their contents are ignored until
	// the matching valid token reaches the output, so resetting them adds no
	// functional protection.  In particular, an asynchronous reset prevents
	// Vivado from packing these registers into DSP48E2 AREG/BREG and creates a
	// very large reset tree across every Tile.
	always @(posedge clk) begin
		if (ena) begin
			a_reg <= ext_a;
			b_reg <= ext_b;
		end
	end

	(* use_dsp = "yes" *) wire signed [2*WD_OUT-1:0] prod_full;
	assign prod_full = a_reg * b_reg;
	assign c = prod_full[WD_OUT-1:0];
endmodule
