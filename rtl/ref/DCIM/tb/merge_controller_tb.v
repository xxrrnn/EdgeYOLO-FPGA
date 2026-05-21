`timescale 1ns / 1ps
`include "para.v"

module merge_controller_tb();

	localparam T = 10;

	reg clk, rstn, clr;

	wire cnt_done;

	reg  i_valid, i_ready;
	wire o_ready, o_valid;
	reg [2: 0] mode;

	reg [2: 0] ubd;
	
	counter#(.UBD_MAX(4)) u_counter(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(i_valid && o_ready),
		.cnt_done(cnt_done),
		.ubd(ubd)
	);

	merge_controller u_merge_controller(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.mode(mode),
		.cnt_done(cnt_done),
		.i_valid(i_valid),
		.o_ready(o_ready),
		.i_ready(i_ready),
		.o_valid(o_valid)
	);

	always#(T/2) clk <= ~clk;

	initial begin
		clk = 0;
		rstn = 0;
		clr = 0;
		i_valid = 0;
		i_ready = 1;
		mode = `MODE_INT4;
		ubd = 1;

		#(T);
		rstn = 1;
		#(T);
		
		i_valid = 1;
		#(4*T);
		i_valid = 0;
		#(T);

		mode = `MODE_INT8;
		ubd = 2;
		clr = 1;
		#(T);
		clr = 0;

		i_valid = 1;
		#(10*T);
		i_valid = 0;
		#(T);

		mode = `MODE_INT16;
		ubd = 4;
		clr = 1;
		#(T);
		clr = 0;

		i_valid = 1;
		#(10*T);
		i_valid = 0;
		#(T);

		$finish;

	end

	`ifdef IVERILOG
		initial begin
			$dumpfile("waveform.vcd");
			$dumpvars(0, merge_controller_tb);
		end
	`else
		initial begin
			$fsdbDumpfile("waveform.fsdb");
			$fsdbDumpvars(0, merge_controller_tb);
		end
	`endif
endmodule
