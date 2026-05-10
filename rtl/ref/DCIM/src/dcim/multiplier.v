`timescale 1ns / 1ps
module multiplier#(
	parameter WD_IN = 4,
	parameter WD_OUT = 2*WD_IN
)(
	input [WD_IN-1: 0] a,
	input [WD_IN-1: 0] b,
	input sa,
	input sb,
	output [WD_OUT-1: 0] c
);
	// Partial Product Array
	wire [WD_IN-1: 0] pp [WD_IN-1: 0];

	genvar row, col;

	generate
		for(row = 0; row < WD_IN ; row = row + 1) begin: GenerateRows
			for(col = 0; col < WD_IN; col = col + 1) begin: GenerateColumns
				wire raw_pp  = a[col] & b[row];
				wire inv_row = (sb && (row == WD_IN-1));
				wire inv_col = (sa && (col == WD_IN-1));
				assign pp[row][col] = inv_row ^ inv_col ^ raw_pp;
			end
		end
	endgenerate

	// Sum Terms
	wire [WD_OUT-1: 0] pp_sum;
	wire [WD_OUT-1: 0] step_sum [WD_IN: 0];

	assign step_sum[0] = {WD_OUT{1'b0}};
	genvar k;
	generate
		for(k=0; k<WD_IN; k=k+1) begin: AdderArray
			assign step_sum[k+1] = step_sum[k] + (({ {WD_IN{1'b0}}, pp[k] })<<k);
		end
	endgenerate

	assign pp_sum = step_sum[WD_IN];

	// Bias
	wire [WD_OUT-1: 0] bias;
	wire [WD_OUT-1: 0] one = 1'b1;
	assign bias = (sa & sb)? ( (one<<(2*WD_IN-1)) + (one<<(WD_IN)) ): ( (sa ^ sb)? ( (one<<(2*WD_IN-1)) + (one<<(WD_IN-1)) ): 0);

	assign c = pp_sum + bias;
 
endmodule


/*
 	row/col	3	2	1	0	
	0	a3b0	a2b0	a1b0	a0b0
	1	a3b1	a2b1	a1b1	a0b1
	2	a3b2	a2b2	a1b2	a0b2
	3	a3b3	a2b3	a1b3	a0b3
	row -> b[row]
	col -> a[col]
*/

