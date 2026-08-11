`ifndef DFF
`define DFF

`timescale 1ns / 1ps
module dff#(
	parameter WD = 1,
	parameter DP = 1
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [WD-1: 0]  up_data,
	output [WD-1: 0] dn_data
);

	reg [WD-1: 0] r_dff [DP-1: 0];

	genvar k;
	generate
		for(k=0; k<DP; k=k+1) begin: gen_dff
			if (k == 0) begin: gen_first
				// This delay line carries data-side sign metadata; validity is
				// tracked by pipe_stage.  Resetting it would recreate the same
				// high-fanout reset tree as the arithmetic data registers.
				always@(posedge clk) begin
					if(ena) begin
						r_dff[k] <= up_data;
					end
				end
			end else begin: gen_rest
				always@(posedge clk) begin
					if(ena) begin
						r_dff[k] <= r_dff[k-1];
					end
				end
			end
		end
	endgenerate

	assign dn_data = r_dff[DP-1];

endmodule

`endif
