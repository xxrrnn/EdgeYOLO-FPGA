module postProcess#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	parameter ACC = 16,
	localparam WD2 = 2*WD1 + $clog2(CH_IN),
	localparam WD3 = WD2 + $clog2(ACC),
	localparam ACC_UBD_WD = $clog2(ACC+1)
)(
	input clk,
	input rstn,
	input clr,
	input ena,

	input [2: 0] mode,
	input [ACC_UBD_WD-1: 0] acc,

	input  up_valid,
	output up_ready,
	output dn_valid,
	input  dn_ready,

	input  [WD2*CH_OUT-1: 0] up_data,
	output [WD3*CH_OUT-1: 0] dn_data

);
	wire mid_valid, mid_ready;
	wire [WD2*CH_OUT-1: 0] mid_data;

	mergeArray#(.WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT)) u_mergeArray(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.mode(mode),
		.up_valid(up_valid),  .up_ready(up_ready),  .up_data(up_data),
		.dn_valid(mid_valid), .dn_ready(mid_ready), .dn_data(mid_data)
	);

	accumulateArray#(.WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), .ACC(ACC)) u_accumulate(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.mode(mode), .acc(acc),
		.up_valid(mid_valid), .up_ready(mid_ready), .up_data(mid_data),
		.dn_valid(dn_valid),  .dn_ready(dn_ready),  .dn_data(dn_data)
	);

endmodule
