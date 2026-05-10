`timescale 1ns / 1ps
module column_tb();

	localparam WD1 = 4;
	localparam CH_IN = 4;
	localparam T = 10;

	localparam actH = {4'b0000, 4'b0111, 4'b1000, 4'b1111};
			//Signed 		0		 7		 -8		  -1				
	localparam actL = {4'b0001, 4'b0110, 4'b1001, 4'b1110};
			//Signed 	    1		 6		 -7		  -2
	localparam weightH = {4'b0010, 4'b0101, 4'b1010, 4'b1101};
			//Signed	    2		 5		 -6		  -3
	localparam weightL = {4'b0011, 4'b0100, 4'b1011, 4'b1100};
			//Signed	    3		 4		 -5		  -4
	
	reg [WD1*CH_IN-1: 0] data1L;
	reg [WD1*CH_IN-1: 0] data2L;
	reg [WD1*CH_IN-1: 0] data1H;
	reg [WD1*CH_IN-1: 0] data2H;

	reg sH1;
	reg sH2;
	reg sL1;
	reg sL2;

	wire[2*WD1+$clog2(CH_IN)-1: 0] resultL;
	wire[2*WD1+$clog2(CH_IN)-1: 0] resultH;
	

	column#(.WD1(WD1), .CH_IN(CH_IN)) u_columnL(
		.data1(data1L),
		.data2(data2L),
		.s1(sL1),
		.s2(sL2),
		.result(resultL)
	);

	column#(.WD1(WD1), .CH_IN(CH_IN)) u_columnH(
		.data1(data1H),
		.data2(data2H),
		.s1(sH1),
		.s2(sH2),
		.result(resultH)
	);

	reg signed [2*WD1+$clog2(CH_IN)+2*WD1 : 0] sum0 = 0;
	reg signed [2*WD1+$clog2(CH_IN)+2*WD1 : 0] sum1 = 0;

	initial begin

		data2H = weightH;
		data2L = weightL;

		// INT4 Multiply & Add Respectly
		sH1 = 1;
		sH2 = 1;
		sL1 = 1;
		sL2 = 1;

		data1H = actH;
		data1L = actH;

		#(T);
		$display("----------------INT4 MODE----------------");
		$display("(actH, weightH) = %b(%d)", resultH, $signed(resultH));
		$display("(actH, weightL) = %b(%d)", resultL, $signed(resultL));

		
		

		// INT8 Mutiply & Add Together
		sum0 = 0;
		sum1 = 0;
		$display("----------------INT8 MODE----------------");
		sH1 = 1;
		sH2 = 1;
		sL1 = 1;
		sL2 = 0;
		data1H = actH;
		data1L = actH;
		#(T);
		$display("actH x weightH = %b(%d)", resultH, $signed(resultH));
		$display("actH x weightL = %b(%d)", resultL, $signed(resultL));

	 	sum0 = ($signed(resultL) + ($signed(resultH)<<<WD1))<<<WD1;
		$display("Cycle 0 Sum = %d", sum0);


		data1H = actL;
		data1L = actL;
		sH1 = 0;
		sL1 = 0;
		#(T);

		$display("actL x weightH = %b(%d)", resultH, $signed(resultH));
		$display("actL x weightL = %b(%d)", resultL, $signed(resultL));
		sum1 = $signed(resultL) + ($signed(resultH)<<<WD1);
		$display("Cycle 1 Sum = %d", sum1);
		$display("Result = sum0 + sum1 = %d)", sum0+sum1);

		$finish;
	end

	initial begin
		$fsdbDumpvars();
		$fsdbDumpfile("waveform.fsdb");
	end

endmodule
