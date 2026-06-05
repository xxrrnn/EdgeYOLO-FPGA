`timescale 1ns / 1ps
// INT4 基底（WD_IN=4）：用符号扩展后的整数乘代替部分积阵列，便于 Vivado 映射 DSP48。
// use_dsp 约束已移除：Vivado 自动推断 DSP48E2 用于 8x8 乘法。
// 顶层 synth_design -max_dsp 8800 限制总 DSP 用量（设备共 9024），防止超量。
// XDC 中 USE_DSP_AREG/BREG=2 在 impl 阶段将上游 data_reg 吸收入 DSP 输入流水。
module multiplier #(
	parameter WD_IN = 4,
	parameter WD_OUT = 2 * WD_IN
) (
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

	wire signed [2*WD_OUT-1:0] prod_full;
	assign prod_full = ext_a * ext_b;
	assign c = prod_full[WD_OUT-1:0];

endmodule
