`timescale 1ns / 1ps
`include "para.v"
`include "simTools.v"
module calculate_tb#(
	parameter WD1 = `WD1,
	parameter CH_IN = `CH_IN,
	parameter CH_OUT = `CH_OUT,
	parameter R = `R,
	parameter FILE_DEPTH = 100
)();

	localparam T = 10;
	localparam R_UBD_WD = $clog2(R+1);
	localparam WD2 = 2*WD1 + $clog2(CH_IN);
	localparam WD3 = WD2 + $clog2(R);

	integer file_weight;

	wire i_valid, o_ready;
	wire o_valid, i_ready;
	wire [CH_IN*WD1-1: 0]			data_in1;
	wire [CH_OUT*WD3-1: 0]			data_out;

	reg  [CH_OUT*CH_IN*WD1-1: 0]	data_in2;

	reg clk, rstn, clr;
	reg ena, acc_ena;
	reg simToolRandom;
	reg simToolUpEna;
	reg simToolDownEna;
	reg [R_UBD_WD-1: 0] r;
	reg [2: 0] mode;

	simToolUp#(
		.INTERNAL_MAX(3),
		.FILE("simToolUp.mem"),
		.WD(CH_IN*WD1),
		.MEM_DEPTH(FILE_DEPTH),
		.SPLIT_WD(WD1),
		.MODE(1)
	) u_simToolUp(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(simToolUpEna),
		.r(simToolRandom),
		.data(data_in1),
		.i_ready(o_ready),
		.o_valid(i_valid)
	);

	calculate#(
		.WD1(WD1),
		.CH_IN(CH_IN),
		.CH_OUT(CH_OUT),
		.R(R)
	) u_calculate(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(ena),
		.acc_ena(acc_ena),
		.r(r),
		.mode(mode),
		.data_in1(data_in1),
		.data_in2(data_in2),
		.data_out(data_out),
		.i_valid(i_valid),
		.o_ready(o_ready),
		.i_ready(i_ready),
		.o_valid(o_valid)
	);

	simToolDown#(
		.INTERNAL_MAX(2),
		.FILE("simToolDown.mem"),
		.WD(CH_OUT*WD3),
		.MEM_DEPTH(FILE_DEPTH),
		.SPLIT_WD(WD3)
	) u_simToolDown(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(simToolDownEna),
		.r(simToolRandom),
		.data(data_out),
		.i_valid(o_valid),
		.o_ready(i_ready)
	);


	always#(T/2) clk <= ~clk;

	initial begin
		simToolRandom = !(`UNI);
		r = `ACC;

		clk = 0;
		rstn = 0;
		clr = 0;
		ena = 0;

		acc_ena = (r!=0);
		simToolUpEna = 1;
		simToolDownEna = 1;

	`ifdef TEST_INT4
		mode = `MODE_INT4;
	`elsif TEST_INT8
		mode = `MODE_INT8;
	`elsif TEST_INT16
		mode = `MODE_INT16;
	`elsif TEST_UINT4
		mode = `MODE_UINT4;
	`elsif TEST_UINT8
		mode = `MODE_UINT8;
	`elsif TEST_UINT16
		mode = `MODE_UINT16;
	`else
		mode = 3'bxxx;
	`endif

		// Randomize weight matrix compactly for any WD1/CH sizes
		for (integer bit_idx=0; bit_idx<CH_OUT*CH_IN*WD1; bit_idx=bit_idx+32) begin
			data_in2[bit_idx +: 32] = $urandom();
		end
	end

`ifdef TEST_INT4
	initial begin
		#(T);
		rstn = 1;
		#(T);
		mode = `MODE_INT4;
		ena = 1;
		#(40*T);

		simToolUpEna = 0;
		#(10*T);

		clr = 1;
		#(T);
		clr = 0;

		$finish;
	end
`endif

`ifdef TEST_INT8
	initial begin
		#(T);
		rstn = 1;
		#(T);
		mode = `MODE_INT8;
		ena = 1;
		#(40*T);

		simToolUpEna = 0;
		#(10*T);

		clr = 1;
		#(T);
		clr = 0;

		$finish;

	end
`endif

`ifdef TEST_INT16
	initial begin
		#(T);
		rstn = 1;
		#(T);
		mode = `MODE_INT16;
		ena = 1;

		#(40*T);

		simToolUpEna = 0;
		#(10*T);

		clr = 1;
		#(T);
		clr = 0;

		$finish;

	end
`endif

`ifdef TEST_UINT4
	initial begin
		#(T);
		rstn = 1;
		#(T);
		mode = `MODE_UINT4;
		ena = 1;
		#(10*T);

		simToolUpEna = 0;
		#(10*T);

		clr = 1;
		#(T);
		clr = 0;

		$finish;
	end
`endif

`ifdef TEST_UINT8
	initial begin
		#(T);
		rstn = 1;
		#(T);
		mode = `MODE_UINT8;
		ena = 1;
		#(16*T);

		simToolUpEna = 0;
		#(10*T);

		clr = 1;
		#(T);
		clr = 0;

		$finish;

	end
`endif

`ifdef TEST_UINT16
	initial begin
		#(T);
		rstn = 1;
		#(T);
		mode = `MODE_UINT16;
		ena = 1;

		#(100*T);

		simToolUpEna = 0;
		#(50*T);

		clr = 1;
		#(T);
		clr = 0;

		$finish;

	end
`endif

	initial begin
		file_weight = $fopen("weight.mem", "w");

		for(integer ch_in=CH_IN-1; ch_in>=0; ch_in=ch_in-1) begin
			for(integer ch_out=CH_OUT-1; ch_out>=0; ch_out=ch_out-1) begin
				$fwrite(file_weight, "%b ", data_in2[(ch_out*CH_IN+ch_in)*WD1 +: WD1]);
			end
			$fwrite(file_weight, "\n");
		end
	end

	initial begin
		$dumpfile("waveform.vcd");
		$dumpvars(0, calculate_tb);
	end
	
endmodule
