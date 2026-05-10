`timescale 1ns/1ps
module adder_tb();
	localparam WD = 4;
	localparam T = 10;

	reg [WD-1: 0] A;
	reg [WD-1: 0] B;

	reg S;

	wire [WD: 0] C;

	adder#(.WD(WD)) u_adder(
		.A(A),
		.B(B),
		.C(C),
		.S(S)
	);

	initial begin
		A = 0;
		B = 0;
		S = 0;
	
		#(T);

		A = 4'b0101;
		B = 4'b0100;
		S = 0;
		#(T);
		$display("Unsigned %b + %b = %b", A, B, C);

		S = 1;
		#(T);
		$display("Signed %b + %b = %b", A, B, C);

		A = 4'b1111;
		B = 4'b0010;
		S = 0;
		#(T);
		$display("Unsigned %b + %b = %b", A, B, C);

		S = 1;
		#(T);
		$display("Signed %b + %b = %b", A, B, C);
		
		$finish;
	end
	initial begin
		$fsdbDumpvars(1, adder_tb);
		$fsdbDumpfile("waveform.fsdb");
	end
endmodule	
