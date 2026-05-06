`timescale 1ns / 1ps
module calculate_core#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	localparam WD2 = 2*WD1 + $clog2(CH_IN)
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input  [2: 0] 					mode,
	input  up_valid,
	output up_ready,
	output dn_valid,
	input  dn_ready,
	input  [CH_IN*WD1-1: 0] 		up_data1,
	input  [CH_OUT*CH_IN*WD1-1: 0]	up_data2,
	output [CH_OUT*WD2-1: 0]		dn_data
);

	maArray#(.WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT))
		u_maArray(
			.clk(clk), .rstn(rstn), .clr(clr), .ena(ena), .mode(mode),
			.up_valid(up_valid), .up_ready(up_ready),
			.up_data1(up_data1), .up_data2(up_data2),
			.dn_valid(dn_valid), .dn_ready(dn_ready),
			.dn_data(dn_data)
		);

endmodule
