`timescale 1ns / 1ps
`include "para.v"
`include "printTools.v"
module calculate_tb();

	localparam T = 10;
	localparam R = 8;
	localparam WD1 = 4;
	localparam CH_IN = 4;
	localparam CH_OUT = 4;

	reg clk, rstn, clr;
	reg ena;

	always#(T/2) clk <= clk;



	
endmodule
