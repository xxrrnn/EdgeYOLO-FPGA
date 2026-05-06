`timescale 1ns / 1ps

module sramWrap#(
	parameter WD = 128,
	parameter DP = 128, // 128x
	localparam ADDR_WD = $clog2(DP)
)(
	input 					clk,
	input 					ena,
	
	input  					req,
	input  					we,

	input  [ADDR_WD-1: 0] 	addr,
	input  [WD-1: 0] 		wdata,
	input  [WD-1: 0] 		be,
	output [WD-1: 0] 		rdata
);

	`ifdef VERILATOR
	model_rf#(
		.WIDTH(128),
		.DEPTH(128)
	) u_rf(
		.clk(clk),
		.cen(~(ena & req)),
		.gwen(~we),
		.wen(~be),
		.a(addr),
		.d(wdata),
		.q(rdata)
	);
	`else
	rf128x128 u_rf(
		.clk(clk),
		.cen(~(ena & req)),
		.gwen(~we),
		.wen(~be),
		.a(addr),
		.d(wdata),
		.q(rdata),
		.ema(3'b111),
		.emaw(2'b11),
		.emas(1'b1),
		.ret1n(1'b1)
	);
	`endif

endmodule
