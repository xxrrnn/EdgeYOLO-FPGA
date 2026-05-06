`timescale 1ns / 1ps
module multiplier_tb();

	localparam T = 10;
	localparam WD = 4;

	reg [WD-1: 0] a;
	reg [WD-1: 0] b;
	reg sa;
	reg sb;

	wire [2*WD-1: 0] c;

	multiplier #(.WD(WD)) u_multiplier(
		.a(a),
		.b(b),
		.sa(sa),
		.sb(sb),
		.c(c)
	);

	initial begin
		a = 4'b1101;
		b = 4'b1011;
		sa = 0;
		sb = 0;
		#(T);
		$display("a = %b, b = %b", a, b);
		$display("Unsigned a x Unsigned b = %b", c);

		sa = 1;
		sb = 0;
		#(T);
		$display("Signed a x Unsigned b = %b", c);

		sa = 0;
		sb = 1;
		#(T);
		$display("Unsigned a x Signed b = %b", c);

		sa = 1;
		sb = 1;
		#(T);
		$display("Signed a x Signed b = %b", c);

		$finish;
	end

	initial begin
		$fsdbDumpvars();
		$fsdbDumpfile("waveform.fsdb");
	end

endmodule
