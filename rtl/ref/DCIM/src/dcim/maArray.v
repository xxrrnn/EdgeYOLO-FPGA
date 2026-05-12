`timescale 1ns / 1ps
// `include "para.v"  // 注释掉，已在 filelist.f 中包含
// `include "counter.v"
// `include "dff.v"

//ma: multiply & add
module maArray#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter WD2 = 2*WD1+ $clog2(CH_IN),
	parameter CH_OUT = 4
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [2: 0] mode,

	input  up_valid,
	output up_ready,
	input  dn_ready,
	output dn_valid,

	input [WD1*CH_IN-1: 0] 			up_data1,
	input [WD1*CH_IN*CH_OUT-1: 0]	up_data2,
	output [WD2*CH_OUT-1: 0]		dn_data
);

	wire [WD2*CH_OUT-1: 0] w_data_ma;
	wire [2: 0] w_ubd;
	wire [1: 0] w_cnt;
	wire w_cnt_zero;
	assign w_cnt_zero = (w_cnt==0);

	assign w_ubd = (mode==`MODE_UINT4 || mode==`MODE_INT4)? 3'b001: (
		(mode==`MODE_UINT8 || mode==`MODE_INT8)? 3'b010 : (
			(mode==`MODE_UINT16 || mode==`MODE_INT16)? 3'b100: 3'b001
		)
	);

	counter_cfg#(.UBD_MAX(4)) u_counter_cfg(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena & up_valid & up_ready),
		.ubd(w_ubd),
		.cnt(w_cnt),
		.cnt_done()
	);

	genvar col;
	generate
		for(col=0; col<CH_OUT/4; col=col+1) begin:MaColumn
			maColumn#(.WD1(WD1), .CH_IN(CH_IN)) 
				u_maColumn(
					.mode(mode),
					.cnt_zero(w_cnt_zero),
					.up_data1(up_data1),
					.up_data2(up_data2[col*4*WD1*CH_IN+: 4*WD1*CH_IN]),
					.dn_data(w_data_ma[col*4*WD2+: 4*WD2])
				);
		end
	endgenerate

	pipe_stage u_pipe_stage_ctrl(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.up_valid(up_valid), .up_ready(up_ready),
		.dn_valid(dn_valid), .dn_ready(dn_ready)
	);

	dff#(.WD(WD2*CH_OUT), .DP(1)) u_dff_result(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena & up_valid & up_ready),
		.up_data(w_data_ma), .dn_data(dn_data)
	);
endmodule


module maColumn#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter WD2 = 2*WD1 + $clog2(CH_IN)
)(
	input [2: 0] mode,
	input cnt_zero,

	input [WD1*CH_IN-1: 0] 		up_data1,
	input [4*WD1*CH_IN-1: 0]	up_data2,
	output [4*WD2-1: 0]			dn_data

);
	wire w_mode_in_sign;
	
	wire s1;
	wire [3: 0] s2;

	assign w_mode_in_sign = (mode==`MODE_INT4) || (mode==`MODE_INT8) || (mode==`MODE_INT16);

	assign s1 = w_mode_in_sign? (cnt_zero): 1'b0; // Act Sign Part
	assign s2 = w_mode_in_sign? ( 
		(mode==`MODE_INT4)? 4'b1111: (
			(mode==`MODE_INT8)? 4'b1010: (
				(mode==`MODE_INT16)? 4'b1000: 4'b0000
			)
		)
	): 4'b0000; // Weight Sign Part

	genvar subcol;
	generate
		for(subcol=0; subcol<4; subcol=subcol+1) begin:MaSubcolumn
			maSubcolumn#(.WD1(WD1), .CH_IN(CH_IN)) u_maSubcolumn(
				.data1(up_data1),
				.data2(up_data2[subcol*WD1*CH_IN+: WD1*CH_IN]),
				.s1(s1),
				.s2(s2[subcol]),
				.result(dn_data[subcol*WD2+: WD2])
			);
		end
	endgenerate

endmodule


module maSubcolumn#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter WD2 = 2*WD1+$clog2(CH_IN)
)(
	input [WD1*CH_IN-1: 0] data1,
	input [WD1*CH_IN-1: 0] data2,
	input s1,
	input s2,
	output [WD2-1: 0] result

);
	wire [2*WD1*CH_IN-1: 0] product;
	genvar ch;

	// Input Multiply
	generate
		for(ch=0; ch<CH_IN; ch=ch+1) begin:MultiplierChannels
			multiplier#(.WD_IN(WD1))
				u_multiplier(
					.a(data1[ch*WD1+: WD1]),
					.b(data2[ch*WD1+: WD1]),
					.c(product[ch*2*WD1+: 2*WD1]),
					.sa(s1),
					.sb(s2)
				);
		end
	endgenerate

	// Sum
	adderTree#(.WD_IN(2*WD1), .CH_IN(CH_IN)) u_adderTree(
		.d(product),
		.sum(result),
		.s(s1|s2)
	);

endmodule
