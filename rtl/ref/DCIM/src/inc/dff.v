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
		for(k=0; k<DP; k=k+1) begin
			always@(posedge clk or negedge rstn) begin
				if(~rstn) begin
					r_dff[k] <= 0;
				end else if(clr) begin
					r_dff[k] <= 0;
				end else if(ena) begin
					if(k==0) begin
						r_dff[k] <= up_data;
					end else begin
						r_dff[k] <= r_dff[k-1];
					end
				end else begin
					r_dff[k] <= r_dff[k];
				end
			end
		end
	endgenerate

	assign dn_data = r_dff[DP-1];

endmodule

`endif
