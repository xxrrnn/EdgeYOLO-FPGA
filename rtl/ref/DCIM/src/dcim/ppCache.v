`timescale 1ns / 1ps
// `include "counter.v"  // 注释掉，已在 filelist.f 中包含
module ppCache#(
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	parameter WD1 = 4,
	parameter CYCLE = 8,
	localparam CYCLE_CNT_WD = $clog2(CYCLE),
	localparam TILE_WD = CH_IN*CH_OUT*WD1/CYCLE
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input swap,
	input  up_valid,
	output up_ready,
	output dn_valid,
	input [TILE_WD-1: 0] up_data,
	output [TILE_WD*CYCLE-1: 0] dn_data
);

	wire w_ptr_in;
	wire [CYCLE_CNT_WD-1: 0] w_address;
	wire w_handshake_in;
	wire [TILE_WD*CYCLE-1: 0] w_data0, w_data1;

	assign w_handshake_in = up_valid & up_ready;
	assign dn_data = w_ptr_in? w_data0: w_data1;

	ppCacheController#(
		.CYCLE(CYCLE)
	) u_ppCacheController(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(ena),
		.swap(swap),
		.up_valid(up_valid),
		.up_ready(up_ready),
		.dn_valid(dn_valid),
		.ptr_in(w_ptr_in),
		.address(w_address)
	);
	
	cacheMem#(
		.CH_IN(CH_IN),
		.CH_OUT(CH_OUT),
		.WD1(WD1),
		.CYCLE(CYCLE)
	) u_cacheMem0 (
		.clk(clk),
		.wr(ena && (~w_ptr_in) && w_handshake_in),
		.address(w_address),
		.up_data(up_data),
		.dn_data(w_data0)
	);
	
	cacheMem#(
		.CH_IN(CH_IN),
		.CH_OUT(CH_OUT),
		.WD1(WD1),
		.CYCLE(CYCLE)
	) u_cacheMem1 (
		.clk(clk),
		.wr(ena && w_ptr_in && w_handshake_in),
		.address(w_address),
		.up_data(up_data),
		.dn_data(w_data1)
	);


endmodule

module cacheMem#(
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	parameter WD1 = 4,
	parameter CYCLE = 8,
	localparam CYCLE_CNT_WD = $clog2(CYCLE),
	localparam TILE_WD = CH_IN*CH_OUT*WD1/CYCLE
)(
	input clk,
	input wr,
	input [CYCLE_CNT_WD-1: 0] address,
	input [TILE_WD-1: 0] up_data,
	output [TILE_WD*CYCLE-1: 0] dn_data
);

	reg [TILE_WD-1: 0] r_mem[CYCLE-1: 0];

	always@(posedge clk) begin
	    if(wr) begin
			r_mem[address] <= up_data;
		end
	end

	genvar i;
	generate
		for(i=0; i<CYCLE; i=i+1)
			assign dn_data[i*TILE_WD+: TILE_WD] = r_mem[i];
	endgenerate

endmodule

module ppCacheController#(
	parameter CYCLE = 8,
	localparam CYCLE_CNT_WD = $clog2(CYCLE)
)(
	input clk,
	input clr,
	input rstn,
	input ena,
	input swap,
	input up_valid,
	output up_ready,
	output dn_valid,
	output ptr_in,
	output [CYCLE_CNT_WD-1: 0] address
);

	localparam IDLE = 2'b00;
	localparam PREPARE = 2'b01;
	localparam READY = 2'b11;
	localparam PTR0 = 1'b0;

	reg [1: 0] r_state;
	reg r_ptr_in;
	wire w_handshake_in;
	wire w_cnt_done;

	assign w_handshake_in = up_valid & up_ready;

	assign ptr_in = r_ptr_in;
	assign dn_valid = ena && (r_state==PREPARE || r_state==READY);
	assign up_ready = ena && (r_state==IDLE || r_state==PREPARE);

	reg [1: 0] n_state;
	always@(*) begin
		case(r_state)
			IDLE:	 n_state = w_cnt_done? PREPARE: IDLE;
			PREPARE: n_state = w_cnt_done? READY: PREPARE;
			READY:	 n_state = swap? PREPARE: READY;	
			default: n_state = IDLE;
		endcase
	end

	reg n_ptr_in;
	always@(*) begin
		if(r_state==IDLE && w_cnt_done) begin
			n_ptr_in = ~r_ptr_in;
		end else if(r_state==READY && swap) begin
			n_ptr_in = ~r_ptr_in;
		end else begin
			n_ptr_in = r_ptr_in;
		end
	end

	always@(posedge clk or negedge rstn) begin
		if(~rstn) begin
			r_state <= IDLE;
			r_ptr_in <= PTR0;
		end else if(clr) begin
			r_state <= IDLE;
			r_ptr_in <= PTR0;
		end else if(ena) begin
			r_state <= n_state;
			r_ptr_in <= n_ptr_in;
		end else begin
			r_state <= r_state;
			r_ptr_in <= r_ptr_in;
		end
	end

	counter#(.UBD(CYCLE)) u_counter(
		.clk(clk),
		.rstn(rstn),
		.clr(clr),
		.ena(w_handshake_in),
		.cnt(address),
		.cnt_done(w_cnt_done)
	);

endmodule
