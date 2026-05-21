`timescale 1ns / 1ps
// `include "para.v"  // 注释掉，已在 filelist.f 中包含
// `include "counter.v"
// `include "pipe_stage.v"

module accumulateArray#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	parameter ACC = 4,
	localparam ACC_UBD_WD = $clog2(ACC+1),
	localparam WD2 = 2*WD1 + $clog2(CH_IN),
	localparam WD3 = WD2 + $clog2(ACC)
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [2: 0] mode,
	input  [ACC_UBD_WD-1: 0] acc,
	input  up_valid,
	output up_ready,
	input  dn_ready,
	output dn_valid,
	input [CH_OUT*WD2-1: 0] up_data,
	output[CH_OUT*WD3-1: 0] dn_data
);
	wire w_accu_cnt_zero;

	accumulate_controller#(.ACC(ACC)) u_accumulate_controller(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena), .acc(acc),
		.up_valid(up_valid), .up_ready(up_ready),
		.dn_valid(dn_valid), .dn_ready(dn_ready),
		.cnt_zero(w_accu_cnt_zero)
	);

	genvar col;
	generate
		for(col=0; col<CH_OUT/4; col=col+1) begin:AccumulateColumn
			accumulate#(.WD1(WD1), .CH_IN(CH_IN), .ACC(ACC)) u_accumulate(
				.clk(clk), .rstn(rstn), .clr(clr), .ena(up_valid&up_ready),
				.acc_ena(acc!=0),
				.mode(mode),
				.refresh(w_accu_cnt_zero),
				.up_data(up_data[col*4*WD2+: 4*WD2]),
				.dn_data(dn_data[col*4*WD3+: 4*WD3])
			);
		end
	endgenerate

endmodule


module accumulate#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter ACC = 4,
	parameter WD2 = 2*WD1 + $clog2(CH_IN),
	parameter WD3 = WD2 + $clog2(ACC)
)(
	input clk,
	input rstn,
	input clr,
	input refresh,
	input ena,
	input acc_ena,
	input [2: 0] mode,
	input  [4*WD2-1: 0] up_data,
	output [4*WD3-1: 0] dn_data
);
	wire [WD3-1  : 0] up_data_s_ext_WD3 [3: 0];
	wire [WD3-1  : 0] up_data_u_ext_WD3 [3: 0];
	wire [2*WD3-1: 0] up_data_s_ext_2WD3 [1: 0];
	wire [2*WD3-1: 0] up_data_u_ext_2WD3 [1: 0];
	wire [4*WD3-1: 0] up_data_s_ext_4WD3;
	wire [4*WD3-1: 0] up_data_u_ext_4WD3;

	reg [WD3-1: 0] n_temp3, n_temp2, n_temp1, n_temp0;
	reg [2*WD3-1: 0] n_tempH, n_tempL;
	reg [4*WD3-1: 0] n_temp;
	
	reg [WD3-1: 0] temp3, temp2, temp1, temp0;


	genvar i;
	generate 
		for(i=0; i<4; i=i+1) begin
			assign up_data_s_ext_WD3[i] = { {(WD3-WD2){up_data[(i+1)*WD2-1]}}, up_data[i*WD2+: WD2] };
			assign up_data_u_ext_WD3[i] = { {(WD3-WD2){1'b0}}, up_data[i*WD2+: WD2] };
		end
		for(i=0; i<2; i=i+1) begin
			assign up_data_s_ext_2WD3[i] = { {(2*WD3-2*WD2){up_data[(i+1)*2*WD2-1]}}, up_data[i*2*WD2+: 2*WD2] };
			assign up_data_u_ext_2WD3[i] = { {(2*WD3-2*WD2){1'b0}}, up_data[i*2*WD2+: 2*WD2] };
		end
	endgenerate
		assign up_data_s_ext_4WD3 = { {(4*WD3-4*WD2){up_data[4*WD2-1]}}, up_data };
		assign up_data_u_ext_4WD3 = { {(4*WD3-4*WD2){1'b0}}, up_data };

	always@(*) begin
		n_tempH = 0;
		n_tempL = 0;
		n_temp = 0;
		n_temp3 = 0;
		n_temp2 = 0;
		n_temp1 = 0;
		n_temp0 = 0;

		case(mode)
			`MODE_INT4: begin
				if(refresh) begin
					n_temp3 = up_data_s_ext_WD3[3];
					n_temp2 = up_data_s_ext_WD3[2];
					n_temp1 = up_data_s_ext_WD3[1];
					n_temp0 = up_data_s_ext_WD3[0];
				end else begin
					n_temp3 = temp3 + up_data_s_ext_WD3[3];
					n_temp2 = temp2 + up_data_s_ext_WD3[2];
					n_temp1 = temp1 + up_data_s_ext_WD3[1];
					n_temp0 = temp0 + up_data_s_ext_WD3[0];
				end
			end
			`MODE_UINT4: begin
				if(refresh) begin
					n_temp3 = up_data_u_ext_WD3[3];
					n_temp2 = up_data_u_ext_WD3[2];
					n_temp1 = up_data_u_ext_WD3[1];
					n_temp0 = up_data_u_ext_WD3[0];
				end else begin
					n_temp3 = temp3 + up_data_u_ext_WD3[3];
					n_temp2 = temp2 + up_data_u_ext_WD3[2];
					n_temp1 = temp1 + up_data_u_ext_WD3[1];
					n_temp0 = temp0 + up_data_u_ext_WD3[0];
				end
			end
			`MODE_INT8: begin
				if(refresh) begin
					n_tempH = up_data_s_ext_2WD3[1];
					n_tempL = up_data_s_ext_2WD3[0];
				end else begin
					n_tempH = {temp3, temp2} + up_data_s_ext_2WD3[1];
					n_tempL = {temp1, temp0} + up_data_s_ext_2WD3[0];
				end
				n_temp3 = n_tempH[WD3+: WD3];
				n_temp2 = n_tempH[  0+: WD3];
				n_temp1 = n_tempL[WD3+: WD3];
				n_temp0 = n_tempL[  0+: WD3];
			end
			`MODE_UINT8: begin
				if(refresh) begin
					n_tempH = up_data_u_ext_2WD3[1];
					n_tempL = up_data_u_ext_2WD3[0];
				end else begin
					n_tempH = {temp3, temp2} + up_data_u_ext_2WD3[1];
					n_tempL = {temp1, temp0} + up_data_u_ext_2WD3[0];
				end
				n_temp3 = n_tempH[WD3+: WD3];
				n_temp2 = n_tempH[  0+: WD3];
				n_temp1 = n_tempL[WD3+: WD3];
				n_temp0 = n_tempL[  0+: WD3];
			end
			`MODE_INT16: begin
				if(refresh) begin
					n_temp = up_data_s_ext_4WD3;
				end else begin
					n_temp = {temp3, temp2, temp1, temp0} + up_data_s_ext_4WD3;
				end
				n_temp3 = n_temp[3*WD3+: WD3];
				n_temp2 = n_temp[2*WD3+: WD3];
				n_temp1 = n_temp[  WD3+: WD3];
				n_temp0 = n_temp[    0+: WD3];
			end
			`MODE_UINT16: begin
				if(refresh) begin
					n_temp = up_data_u_ext_4WD3;
				end else begin
					n_temp = {temp3, temp2, temp1, temp0} + up_data_u_ext_4WD3;
				end
				n_temp3 = n_temp[3*WD3+: WD3];
				n_temp2 = n_temp[2*WD3+: WD3];
				n_temp1 = n_temp[  WD3+: WD3];
				n_temp0 = n_temp[    0+: WD3];
			end
			default: begin
				n_temp3 = 0;
				n_temp2 = 0;
				n_temp1 = 0;
				n_temp0 = 0;
			end
		endcase

	end


	always@(posedge clk or negedge rstn) begin
		if(~rstn) begin
			temp3 <= 0;
			temp2 <= 0;
			temp1 <= 0;
			temp0 <= 0;
		end else begin
			if(clr) begin
				temp3 <= 0;
				temp2 <= 0;
				temp1 <= 0;
				temp0 <= 0;
			end else if(ena&acc_ena) begin
				temp3 <= n_temp3;
				temp2 <= n_temp2;
				temp1 <= n_temp1;
				temp0 <= n_temp0;
			end else begin
				temp3 <= temp3;
				temp2 <= temp2;
				temp1 <= temp1;
				temp0 <= temp0;
			end
		end
	end

	reg [4*WD3-1: 0] r_up_data_bypass;
	integer k;
	always@(*) begin
		r_up_data_bypass = 0;
		case(mode)
			`MODE_INT4: begin
				for(k=0; k<4; k=k+1)
					r_up_data_bypass[k*WD3+: WD3] = up_data_s_ext_WD3[k];
			end
			`MODE_UINT4: begin
				for(k=0; k<4; k=k+1)
					r_up_data_bypass[k*WD3+: WD3] = up_data_u_ext_WD3[k];
			end
			`MODE_INT8: begin
				for(k=0; k<2; k=k+1)
					r_up_data_bypass[k*2*WD3+: 2*WD3] = up_data_s_ext_2WD3[k];
			end
			`MODE_UINT8: begin
				for(k=0; k<2; k=k+1)
					r_up_data_bypass[k*2*WD3+: 2*WD3] = up_data_u_ext_2WD3[k];
			end
			`MODE_INT16: begin
				r_up_data_bypass = up_data_s_ext_4WD3;
			end
			`MODE_UINT16: begin
				r_up_data_bypass = up_data_u_ext_4WD3;
			end
			default: begin
				r_up_data_bypass = 0;
			end
		endcase
	end

	assign dn_data = acc_ena? {temp3, temp2, temp1, temp0}: r_up_data_bypass;

endmodule


module accumulate_controller#(
	parameter ACC = 8,
	localparam ACC_UBD_WD = $clog2(ACC+1),
	localparam ACC_CNT_WD = $clog2(ACC)
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [ACC_UBD_WD-1: 0] acc, // 0: bypas
	input  up_valid,
	output up_ready,
	input  dn_ready,
	output dn_valid,
	output cnt_zero
);
	wire w_up_ready, w_dn_valid;
	wire [ACC_CNT_WD-1: 0] w_cnt;
	wire w_cnt_done;

	counter_cfg#(.UBD_MAX(ACC)) u_counter_cfg(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(up_valid&up_ready),
		.ubd(acc),
		.cnt(w_cnt),
		.cnt_done(w_cnt_done)
	);

	pipe_stage u_pipe_stage_ctrl(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.up_valid(w_cnt_done), .up_ready(w_up_ready),
		.dn_valid(w_dn_valid), .dn_ready(dn_ready)
	);

	assign up_ready = (acc==0)? (ena&dn_ready): w_up_ready;
	assign dn_valid = (acc==0)? (ena&up_valid): w_dn_valid;
	assign cnt_zero = ena & (w_cnt==0);

endmodule

