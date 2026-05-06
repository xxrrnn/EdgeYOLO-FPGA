`timescale 1ns / 1ps
`include "para.v"
`include "counter.v"

module mergeArray#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	parameter WD2 = 2*WD1 + $clog2(CH_IN)
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [2: 0] mode,
	input  up_valid,
	output up_ready,
	input  dn_ready,
	output dn_valid,
	input  [CH_OUT*WD2-1: 0] up_data,
	output [CH_OUT*WD2-1: 0] dn_data
);
	wire w_merge_cnt_zero;

	mergeArrayController u_mergeArrayController(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena), .mode(mode),
		.up_valid(up_valid), .up_ready(up_ready),
		.dn_valid(dn_valid), .dn_ready(dn_ready),
		.cnt_zero(w_merge_cnt_zero)
	);

	genvar col;
	generate
		for(col=0; col<CH_OUT/4; col=col+1) begin:MergeColumn
			merge#(.WD1(WD1), .CH_IN(CH_IN)) u_merge(
				.clk(clk), .rstn(rstn), .clr(clr), .ena(up_valid & up_ready),
				.mode(mode),
				.refresh(w_merge_cnt_zero),
				.up_data(up_data[col*4*WD2+: 4*WD2]),
				.dn_data(dn_data[col*4*WD2+: 4*WD2])
			);
		end
	endgenerate

endmodule


module merge#(
	parameter WD1 =  4,
	parameter CH_IN = 16,
	parameter WD2 = 2*WD1 + $clog2(CH_IN)
)(
	input clk,
	input rstn,
	input clr,

	input [2: 0] mode,
	input ena,

	input refresh,

	input [4*WD2-1: 0] up_data,
	output [4*WD2-1: 0] dn_data
);
	localparam WD_PS1 = WD2 + WD1 + 1;
	localparam PAD_0_WD1 = {(WD1){1'b0}};
	localparam WD_PS2 = WD_PS1 + 2*WD1 + 1;
	localparam PAD_0_2WD1 = {PAD_0_WD1, PAD_0_WD1};
	localparam WD_TEMP = WD_PS1 + WD1 + 1;

	wire [WD2-1: 0] up_data_split [3: 0];

	wire [WD_PS1-1: 0] psum1_s[1: 0];
	wire [WD_PS1-1: 0] psum1_u[1: 0];
	wire [WD_TEMP-1: 0] psum1_s_ext_WD_TEMP[1: 0];
	wire [WD_TEMP-1: 0] psum1_u_ext_WD_TEMP[1: 0];

	wire [WD_PS2-1: 0] psum2_s;
	wire [WD_PS2-1: 0] psum2_u;
	wire [2*WD_TEMP-1 : 0] psum2_s_ext_2WD_TEMP;
	wire [2*WD_TEMP-1 : 0] psum2_u_ext_2WD_TEMP;

	reg [WD_TEMP-1: 0] tempH, tempL;

	wire w_s1;
	wire [3:0] w_s2;
	wire [3:0] sub_sign;
	assign w_s1 = (mode==`MODE_INT8 || mode==`MODE_INT16) ? refresh : 1'b0;
	assign w_s2 = (mode==`MODE_INT8) ? 4'b1010 : ((mode==`MODE_INT16) ? 4'b1000 : 4'b0000);

	assign sub_sign[0] = (w_s1 | w_s2[0]) ? up_data_split[0][WD2-1] : 1'b0;
	assign sub_sign[1] = (w_s1 | w_s2[1]) ? up_data_split[1][WD2-1] : 1'b0;
	assign sub_sign[2] = (w_s1 | w_s2[2]) ? up_data_split[2][WD2-1] : 1'b0;
	assign sub_sign[3] = (w_s1 | w_s2[3]) ? up_data_split[3][WD2-1] : 1'b0;

	// 为 psum2_s 预留的二级符号判定
	wire psum1_sign0, psum1_sign1;
	assign psum1_sign0 = (w_s1 | w_s2[1] | w_s2[0]) ? psum1_s[0][WD_PS1-1] : 1'b0;
	assign psum1_sign1 = (w_s1 | w_s2[3] | w_s2[2]) ? psum1_s[1][WD_PS1-1] : 1'b0;

	genvar i;
	generate
		for(i=0; i<4; i=i+1) begin
			assign up_data_split[i] = up_data[i*WD2+: WD2];
		end

		for(i=0; i<2; i=i+1) begin
			assign psum1_s[i] = {sub_sign[2*i+1], up_data_split[2*i+1], PAD_0_WD1} +{ {(WD_PS1-WD2){sub_sign[2*i]}}, up_data_split[2*i]};
			assign psum1_u[i] = {1'b0, up_data_split[2*i+1], PAD_0_WD1} +{ {(WD_PS1-WD2){1'b0}}, up_data_split[2*i]};
			assign psum1_s_ext_WD_TEMP[i] = { {(WD_TEMP-WD_PS1){psum1_s[i][WD_PS1-1]}}, psum1_s[i] };
			assign psum1_u_ext_WD_TEMP[i] = { {(WD_TEMP-WD_PS1){1'b0}}, psum1_u[i] };
		end
	endgenerate

	assign psum2_s = {psum1_sign1, psum1_s[1], PAD_0_2WD1} + { {(WD_PS2-WD_PS1){psum1_sign0}}, psum1_s[0] };
	assign psum2_u = {1'b0, psum1_u[1], PAD_0_2WD1} + { {(WD_PS2-WD_PS1){1'b0}}, psum1_u[0] };
	assign psum2_s_ext_2WD_TEMP = { {(2*WD_TEMP-WD_PS2){psum2_s[WD_PS2-1]}}, psum2_s };
	assign psum2_u_ext_2WD_TEMP = { {(2*WD_TEMP-WD_PS2){1'b0}}, psum2_u };

	reg [WD_TEMP-1: 0] n_tempH, n_tempL;
	reg [2*WD_TEMP-1: 0] n_temp;
	reg [2*WD_TEMP-1: 0] temp;
	always@(*) begin
		n_temp = 0;
		temp = {tempH, tempL};
		case(mode)
			`MODE_INT8: begin
				if(refresh) begin
					n_tempH = psum1_s_ext_WD_TEMP[1];
					n_tempL = psum1_s_ext_WD_TEMP[0];
				end else begin
					n_tempH = psum1_s_ext_WD_TEMP[1] + (tempH<<<WD1);
					n_tempL = psum1_s_ext_WD_TEMP[0] + (tempL<<<WD1);
				end
			end
			`MODE_UINT8: begin
				if(refresh) begin
					n_tempH = psum1_u_ext_WD_TEMP[1];
					n_tempL = psum1_u_ext_WD_TEMP[0];
				end else begin
					n_tempH = psum1_u_ext_WD_TEMP[1] + (tempH<<WD1);
					n_tempL = psum1_u_ext_WD_TEMP[0] + (tempL<<WD1);
				end
			end
			`MODE_INT16: begin
				if(refresh) begin
					n_temp = psum2_s_ext_2WD_TEMP;
				end else begin
					n_temp = psum2_s_ext_2WD_TEMP + (temp<<<WD1);
				end
				n_tempH = n_temp[WD_TEMP+: WD_TEMP];
				n_tempL = n_temp[0      +: WD_TEMP];
			end
			`MODE_UINT16: begin
				if(refresh) begin
					n_temp = psum2_u_ext_2WD_TEMP;
				end else begin
					n_temp = psum2_u_ext_2WD_TEMP + (temp<<WD1);
				end
				n_tempH = n_temp[WD_TEMP+: WD_TEMP];
				n_tempL = n_temp[0      +: WD_TEMP];
			end
			default: begin
				n_tempH = 0;
				n_tempL = 0;
			end
		endcase
	end

	always@(posedge clk or negedge rstn) begin
		if(~rstn) begin
			tempH <= 0;
			tempL <= 0;
		end else begin
			if(clr) begin
				tempH <= 0;
				tempL <= 0;
			end else if(ena) begin
				tempH <= n_tempH;
				tempL <= n_tempL;
			end else begin
				tempH <= tempH;
				tempL <= tempL;
			end
		end
	end

	wire [4*WD2-1: 0] w_result_INT16, w_result_UINT16, w_result_INT8, w_result_UINT8;
	assign w_result_INT16 = { {(4*WD2-2*WD_TEMP){tempH[WD_TEMP-1]}}, tempH, tempL };
	assign w_result_UINT16 = { {(4*WD2-2*WD_TEMP){1'b0}}, tempH, tempL };
	assign w_result_INT8 = { {(2*WD2-WD_TEMP){tempH[WD_TEMP-1]}}, tempH, {(2*WD2-WD_TEMP){tempL[WD_TEMP-1]}}, tempL };
	assign w_result_UINT8 = { {(2*WD2-WD_TEMP){1'b0}}, tempH, {(2*WD2-WD_TEMP){1'b0}}, tempL };

	assign dn_data = (mode==`MODE_INT4 || mode==`MODE_UINT4)? up_data: (
		(mode==`MODE_INT8)? w_result_INT8: (
			(mode==`MODE_UINT8)? w_result_UINT8: (
				(mode==`MODE_INT16)? w_result_INT16: (
					(mode==`MODE_UINT16)? w_result_UINT16: {(4*WD2){1'b0}}
				)
			)
		)
	);

endmodule

module mergeArrayController(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [2: 0] mode,
	input  up_valid,
	output up_ready,
	output dn_valid,
	input  dn_ready,
	output cnt_zero
);
	wire [1: 0] w_cnt;
	wire w_cnt_done;
	wire [2: 0] w_ubd;
	wire w_up_ready, w_dn_valid;

	assign w_ubd = (mode==`MODE_UINT4 || mode==`MODE_INT4)? 3'b001:(
		(mode==`MODE_UINT8 || mode==`MODE_INT8)? 3'b010: (
			(mode==`MODE_UINT16 || mode==`MODE_INT16)? 3'b100: 3'b001
		)
	);

	counter_cfg#(.UBD_MAX(4)) u_counter_cfg(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena&up_valid&up_ready),
		.ubd(w_ubd),
		.cnt(w_cnt),
		.cnt_done(w_cnt_done)
	);

	pipe_stage u_pipe_stage_ctrl(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.up_valid(w_cnt_done), .up_ready(w_up_ready),
		.dn_valid(w_dn_valid), .dn_ready(dn_ready)
	);

	assign up_ready = (mode==`MODE_UINT4 || mode==`MODE_INT4)? (ena&dn_ready): w_up_ready;
	assign dn_valid = (mode==`MODE_UINT4 || mode==`MODE_INT4)? (ena&up_valid): w_dn_valid;
	assign cnt_zero = ena & (w_cnt==0);

endmodule
