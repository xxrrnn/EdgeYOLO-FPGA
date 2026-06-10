`timescale 1ns / 1ps
// `include "para.v"  // 注释掉，已在 filelist.f 中包含
// `include "counter.v"
// `include "dff.v"

//ma: multiply & add
module maArray#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter WD2 = 2*WD1+ $clog2(CH_IN),
	parameter CH_OUT = 4,
	parameter MULT_DSP_EN = 1,
	parameter DSP_COL_NUM = CH_OUT/4,     // 前 DSP_COL_NUM 列用 DSP，其余用 LUT
	parameter DSP_PARTIAL_SUBCOL = 0      // 第 DSP_COL_NUM 列中前 N 个 subcol 用 DSP
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

	input [WD1*CH_IN-1: 0] 			up_data1,
	input [WD1*CH_IN*CH_OUT-1: 0]	up_data2,
	output [WD2*CH_OUT-1: 0]		dn_data
);

	wire [WD2*CH_OUT-1: 0] w_data_ma;
	wire [2: 0] w_ubd;
	wire [1: 0] w_cnt;
	wire w_cnt_zero;
	assign w_cnt_zero = (w_cnt==0);

	assign w_ubd = (mode==`MODE_UINT4 || mode==`MODE_INT4)? 3'b001: (
		(mode==`MODE_UINT8 || mode==`MODE_INT8)? 3'b010 : (
			(mode==`MODE_UINT16 || mode==`MODE_INT16)? 3'b100: 3'b001
		)
	);

	counter_cfg#(.UBD_MAX(4)) u_counter_cfg(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena & up_valid & up_ready),
		.ubd(w_ubd),
		.cnt(w_cnt),
		.cnt_done()
	);

	localparam ADDER_PIPE_DEPTH = $clog2(CH_IN);
	localparam MA_PIPE_DEPTH = 4 + ADDER_PIPE_DEPTH;

	wire [MA_PIPE_DEPTH:0] valid_pipe;
	wire [MA_PIPE_DEPTH:0] ready_pipe;
	assign valid_pipe[0] = up_valid;
	assign up_ready = ready_pipe[0];

	genvar col;
	generate
		for(col=0; col<CH_OUT/4; col=col+1) begin:MaColumn
			localparam COL_DSP_EN = (MULT_DSP_EN && (col < DSP_COL_NUM)) ? 1 : 0;
			localparam COL_IS_PARTIAL = (MULT_DSP_EN && !COL_DSP_EN && (col == DSP_COL_NUM) && (DSP_PARTIAL_SUBCOL > 0)) ? 1 : 0;
			localparam COL_DSP_SUBCOL_CNT = COL_DSP_EN ? 4 : (COL_IS_PARTIAL ? DSP_PARTIAL_SUBCOL : 0);
			maColumn#(.WD1(WD1), .CH_IN(CH_IN), .MULT_DSP_EN(COL_DSP_EN || COL_IS_PARTIAL), .DSP_SUBCOL_CNT(COL_DSP_SUBCOL_CNT)) 
				u_maColumn(
					.clk(clk),
					.rstn(rstn),
					.clr(clr),
					.ena(ena),
					.mode(mode),
					.cnt_zero(w_cnt_zero),
					.up_data1(up_data1),
					.up_data2(up_data2[col*4*WD1*CH_IN+: 4*WD1*CH_IN]),
					.dn_data(w_data_ma[col*4*WD2+: 4*WD2])
				);
		end
	endgenerate

	genvar ps;
	generate
		for (ps = 0; ps < MA_PIPE_DEPTH; ps = ps + 1) begin: gen_ma_valid_pipe
			pipe_stage u_pipe_stage_ctrl(
				.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
				.up_valid(valid_pipe[ps]), .up_ready(ready_pipe[ps]),
				.dn_valid(valid_pipe[ps+1]), .dn_ready(ready_pipe[ps+1])
			);
		end
	endgenerate
	assign dn_valid = valid_pipe[MA_PIPE_DEPTH];
	assign ready_pipe[MA_PIPE_DEPTH] = dn_ready;

	assign dn_data = w_data_ma;
endmodule


module maColumn#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter WD2 = 2*WD1 + $clog2(CH_IN),
	parameter MULT_DSP_EN = 1,
	parameter DSP_SUBCOL_CNT = 4    // 4 subcol 中前 N 个使用 DSP
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [2: 0] mode,
	input cnt_zero,

	input [WD1*CH_IN-1: 0] 		up_data1,
	input [4*WD1*CH_IN-1: 0]	up_data2,
	output [4*WD2-1: 0]			dn_data

);
	wire w_mode_in_sign;
	
	wire s1;
	wire [3: 0] s2;

	assign w_mode_in_sign = (mode==`MODE_INT4) || (mode==`MODE_INT8) || (mode==`MODE_INT16);

	assign s1 = w_mode_in_sign? (cnt_zero): 1'b0; // Act Sign Part
	assign s2 = w_mode_in_sign? ( 
		(mode==`MODE_INT4)? 4'b1111: (
			(mode==`MODE_INT8)? 4'b1010: (
				(mode==`MODE_INT16)? 4'b1000: 4'b0000
			)
		)
	): 4'b0000; // Weight Sign Part

	genvar subcol;
	generate
		for(subcol=0; subcol<4; subcol=subcol+1) begin:MaSubcolumn
			localparam SUBCOL_DSP_EN = (MULT_DSP_EN && (subcol < DSP_SUBCOL_CNT)) ? 1 : 0;
			maSubcolumn#(.WD1(WD1), .CH_IN(CH_IN), .MULT_DSP_EN(SUBCOL_DSP_EN)) u_maSubcolumn(
				.clk(clk),
				.rstn(rstn),
				.clr(clr),
				.ena(ena),
				.data1(up_data1),
				.data2(up_data2[subcol*WD1*CH_IN+: WD1*CH_IN]),
				.s1(s1),
				.s2(s2[subcol]),
				.result(dn_data[subcol*WD2+: WD2])
			);
		end
	endgenerate

endmodule


module maSubcolumn#(
	parameter WD1 = 4,
	parameter CH_IN = 16,
	parameter WD2 = 2*WD1+$clog2(CH_IN),
	parameter MULT_DSP_EN = 1
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input [WD1*CH_IN-1: 0] data1,
	input [WD1*CH_IN-1: 0] data2,
	input s1,
	input s2,
	output reg [WD2-1: 0] result

);
	wire [2*WD1*CH_IN-1: 0] product;
	reg s_pipe;
	wire [WD2-1: 0] sum_out;
	genvar ch;

	// Input pipeline registers: fanout distribution for data1/data2/s1/s2
	// 乘法器内部有 AREG/BREG (1 cycle)，替代了原 product_pipe 的 pipeline 作用
	// 本级 reg 仅负责扇出分发 + 打断跨 SLR 路径
	(* max_fanout = 16 *) reg [WD1*CH_IN-1: 0] data1_reg;
	(* max_fanout = 16 *) reg [WD1*CH_IN-1: 0] data2_reg;
	reg s1_reg;
	(* max_fanout = 16 *) reg s2_reg;

	always @(posedge clk or negedge rstn) begin
		if (!rstn) begin
			data1_reg <= 0;
			data2_reg <= 0;
			s1_reg <= 0;
			s2_reg <= 0;
		end else if (clr) begin
			data1_reg <= 0;
			data2_reg <= 0;
			s1_reg <= 0;
			s2_reg <= 0;
		end else if (ena) begin
			data1_reg <= data1;
			data2_reg <= data2;
			s1_reg <= s1;
			s2_reg <= s2;
		end
	end

	// 乘法器实例化：内含 1 级 input pipeline (AREG/BREG)
	// 路径: data1_reg → LUT(符号扩展) → multiplier 内部 a_reg → multiply → product
	// multiplier 输出为组合逻辑（从内部 a_reg/b_reg 出发），直连 adderTree
	generate
		if (MULT_DSP_EN) begin : gen_mult_dsp
			for(ch=0; ch<CH_IN; ch=ch+1) begin:MultiplierChannels
				multiplier_dsp#(.WD_IN(WD1))
					u_multiplier(
						.clk(clk),
						.rstn(rstn),
						.ena(ena),
						.a(data1_reg[ch*WD1+: WD1]),
						.b(data2_reg[ch*WD1+: WD1]),
						.c(product[ch*2*WD1+: 2*WD1]),
						.sa(s1_reg),
						.sb(s2_reg)
					);
			end
		end else begin : gen_mult_lut
			for(ch=0; ch<CH_IN; ch=ch+1) begin:MultiplierChannels
				multiplier#(.WD_IN(WD1))
					u_multiplier(
						.clk(clk),
						.rstn(rstn),
						.ena(ena),
						.a(data1_reg[ch*WD1+: WD1]),
						.b(data2_reg[ch*WD1+: WD1]),
						.c(product[ch*2*WD1+: 2*WD1]),
						.sa(s1_reg),
						.sb(s2_reg)
					);
			end
		end
	endgenerate

	// s_pipe: 与 multiplier 内部 AREG/BREG 对齐（同 cycle latch）
	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			s_pipe <= 1'b0;
		else if (clr)
			s_pipe <= 1'b0;
		else if (ena)
			s_pipe <= s1_reg | s2_reg;
	end

	// multiplier 输出 product 与 s_pipe 在同一 cycle 有效，直连 adderTree
	adderTreePipe#(.WD_IN(2*WD1), .CH_IN(CH_IN)) u_adderTree(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(ena),
		.d(product),
		.s(s_pipe),
		.sum(sum_out)
	);

	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			result <= {WD2{1'b0}};
		else if (clr)
			result <= {WD2{1'b0}};
		else if (ena)
			result <= sum_out;
	end

endmodule
