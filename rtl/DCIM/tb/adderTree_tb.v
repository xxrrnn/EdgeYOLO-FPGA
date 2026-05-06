`timescale 1ns / 1ps
module adderTree_tb();

	localparam T = 10;
	localparam WD = 4;
	localparam DP = 4;

	reg [WD*DP-1: 0] d;
	reg s;
	wire [WD+$clog2(DP)-1: 0] sum;
	
	adderTree#(.WD(WD), .DP(DP)) u_adderTree(
		.d(d),
		.s(s),
		.sum(sum)
	);

	initial begin
		d = {4'b0011, 4'b1100, 4'b0001, 4'b1110};
		
		s = 0;
		#(T);
		$display("Unsigned Sum: %b", sum);

		s = 1;
		#(T);
		$display("Signed Sum: %b", sum);

		$fsdbDumpvars();
		$fsdbDumpfile("waveform.fsdb");

		$finish;
	end

endmodule
