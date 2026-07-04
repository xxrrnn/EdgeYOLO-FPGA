`ifndef PIPE_STAGE
`define PIPE_STAGE
`timescale 1ns / 1ps
module pipe_stage(
	input clk,
	input rstn,
	input clr,
	input ena,

	input  up_valid,
	output up_ready,
	output dn_valid,
	input  dn_ready
);

	reg r_valid;
	always@(posedge clk or negedge rstn) begin
		if(~rstn) begin
			r_valid <= 1'b0;
		end else if(clr) begin
			r_valid <= 1'b0;
		end else if(up_ready) begin
			r_valid <= up_valid;
		end else begin
			r_valid <= r_valid;
		end
	end

	assign up_ready = ena & (dn_ready | (~r_valid));
	assign dn_valid = ena & r_valid;

endmodule

`endif
