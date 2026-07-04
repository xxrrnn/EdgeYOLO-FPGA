`timescale 1ns / 1ps
module sramWrap_tb#(
	parameter WD = 128,
	parameter DP = 128,
	parameter ADDR_WD = $clog2(DP)
)();
	localparam T = 10;
	reg clk;
	reg rstn;
	reg clr;
	reg ena;
	reg mode;
	reg [ADDR_WD-1: 0] address;

	reg  i_valid;
	wire o_valid;
	reg  i_ready;
	reg  [WD-1: 0] i_data;
	wire [WD-1: 0] o_data;

	sramWrap#(.WD(WD), .DP(DP)) u_sramWrap(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(ena),
		.i_valid(i_valid),
		.o_valid(o_valid),
		.i_ready(i_ready),
		.mode(mode),
		.address(address),
		.i_data(i_data),
		.o_data(o_data)
	);
	
	always#(T/2) clk <= ~clk;

	initial begin
		i_valid = 0;
		i_ready = 0;
		mode = 0;
		address = 0;
		i_data = 0;
		clk = 0;
		rstn = 0;
		clr = 0;
		ena = 0;
		#(T);
		rstn = 1;
		ena = 1;
		#(T);

		i_data = 128'h20040423;
		i_valid = 1;
		mode = 0;
		#(T);
		
		mode = 1;
		i_ready = 1;
		#(T);
		i_valid = 0;
		#(2*T);

		$finish;

	end

	initial begin
		$dumpfile("waveform.vcd");
		$dumpvars(0, sramWrap_tb);
	end
endmodule
