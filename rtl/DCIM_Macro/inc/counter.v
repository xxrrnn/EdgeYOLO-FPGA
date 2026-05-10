`ifndef COUNTER
`define COUNTER

`timescale 1ns / 1ps
module counter#(
	parameter UBD = 4,
	parameter UBD_WD = $clog2(UBD+1),
	parameter CNT_WD = $clog2(UBD)
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	output [CNT_WD-1: 0] cnt,
	output cnt_done
);

	reg [CNT_WD-1: 0] r_cnt;
	wire [UBD_WD-1: 0] w_cnt_plus1;
	wire [UBD_WD-1: 0] w_ubd;
	assign w_ubd = UBD[UBD_WD-1: 0];
	assign w_cnt_plus1 = r_cnt + 1'b1;

	always@(posedge clk or negedge rstn) begin
		if(~rstn) begin
			r_cnt <= 0;
		end else begin
			if(clr) begin
				r_cnt <= 0;
			end else begin
				if(ena) begin
					r_cnt <= (w_cnt_plus1 == w_ubd)? 0: r_cnt + 1'b1;
				end else begin
					r_cnt <= r_cnt;
				end
			end
		end
	end

	assign cnt_done = ena && (w_cnt_plus1 == w_ubd);
	assign cnt = r_cnt;

endmodule


module counter_cfg#(
	parameter UBD_MAX = 4,
	parameter UBD_WD = $clog2(UBD_MAX+1),
	parameter CNT_WD = $clog2(UBD_MAX)
)(
	input [UBD_WD-1: 0] ubd,
	input clk,
	input rstn,
	input clr,
	input ena,
	output [CNT_WD-1: 0] cnt,
	output cnt_done
);

	reg [CNT_WD-1: 0] r_cnt;
	wire [UBD_WD-1: 0] w_cnt_plus1;
	assign w_cnt_plus1 = r_cnt + 1'b1;

	always@(posedge clk or negedge rstn) begin
		if(~rstn) begin
			r_cnt <= 0;
		end else begin
			if(clr) begin
				r_cnt <= 0;
			end else begin
				if(ena) begin
					r_cnt <= (w_cnt_plus1 == ubd)? 0: r_cnt + 1'b1;
				end else begin
					r_cnt <= r_cnt;
				end
			end
		end
	end

	assign cnt_done = ena && (w_cnt_plus1 == ubd);
	assign cnt = r_cnt;

endmodule

`endif
