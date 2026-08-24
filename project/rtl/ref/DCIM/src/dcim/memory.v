module memory#(
	parameter WD = 128,
	parameter DP = 128,
	parameter CH_IN = 16,
	parameter CH_OUT = 16,
	parameter WD1 = 4,
	parameter CYCLE = 8,
	localparam ADDR_WD = $clog2(DP)
)(
	input  							clk,
	input  							rstn,
	input  							clr,
	input  							ena,
	input  [ADDR_WD-1: 0] 			addr,
	input  							load,
	input							swap,
	input							req,
	input							we,
	output 							up_ready,
	input  [WD-1: 0] 				up_data,
	input  [WD-1: 0]				be,
	output 							dn_valid,
	output [CH_IN*CH_OUT*WD1-1: 0]	dn_data
);

	wire mid_valid, mid_ready;
	wire [WD-1: 0] mid_data;
	wire fsm_req, fsm_we;
	wire [ADDR_WD-1: 0] fsm_addr;

	assign up_ready = ~fsm_req;

	sramWrap#(.WD(WD), .DP(DP)) u_sramWrap(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.req(fsm_req | req),
		.we(fsm_req? fsm_we: we),
		.addr(fsm_req? fsm_addr: addr),
		.wdata(up_data),
		.be(be),
		.rdata(mid_data)
	);

	wire load_ready;
	load_fsm#(
		.ADDR_WD(ADDR_WD), .CYCLE(CYCLE)
	) u_load_fsm(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.load(load),		
		.req(fsm_req),
		.we(fsm_we),
		.base_addr(addr),
		.addr(fsm_addr),
		.ready(load_ready)
	);

	pipe_stage u_load_pipe_stage_ctrl(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.up_valid(fsm_req), 	.up_ready(load_ready),
		.dn_valid(mid_valid),	.dn_ready(mid_ready)
	);

	// Stage 1: capture BRAM rdata, placed near BRAM.
	// Fanout is now 1 per bit (only drives pip_data_q), so no MAX_FANOUT needed here.
	wire pip_valid, pip_ready;
	(* shreg_extract = "no" *) reg [WD-1: 0] mid_data_q;

	pipe_stage u_mid_pipe_stage(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.up_valid(mid_valid),	.up_ready(mid_ready),
		.dn_valid(pip_valid),	.dn_ready(pip_ready)
	);

	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			mid_data_q <= {WD{1'b0}};
		else if (clr)
			mid_data_q <= {WD{1'b0}};
		else if (mid_valid & mid_ready)
			mid_data_q <= mid_data;
	end

	// Stage 2: broadcast register placed near ppCache (breaks mid_data_q→r_mem critical path).
	// MAX_FANOUT=16: Vivado replicates pip_data_q near each cacheMem region,
	// splitting fo=128 into 8 local copies (each fo=16), eliminating long-distance routing.
	wire pip2_valid, pip2_ready;
	(* shreg_extract = "no" *) (* MAX_FANOUT = 16 *) reg [WD-1: 0] pip_data_q;

	pipe_stage u_pip_pipe_stage(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.up_valid(pip_valid),	.up_ready(pip_ready),
		.dn_valid(pip2_valid),	.dn_ready(pip2_ready)
	);

	always @(posedge clk or negedge rstn) begin
		if (!rstn)
			pip_data_q <= {WD{1'b0}};
		else if (clr)
			pip_data_q <= {WD{1'b0}};
		else if (pip_valid & pip_ready)
			pip_data_q <= mid_data_q;
	end

	ppCache#(.CH_IN(CH_IN), .CH_OUT(CH_OUT), .WD1(WD1), .CYCLE(CYCLE)) u_ppCache(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
		.swap(swap),
		.up_valid(pip2_valid), .up_ready(pip2_ready), .up_data(pip_data_q),
		.dn_valid(dn_valid),  .dn_data(dn_data)
	);

endmodule

module load_fsm#(
	parameter ADDR_WD = 8,
	parameter CYCLE = 8
)(
	input clk,
	input rstn,
	input clr,
	input ena,
	input load,
	input [ADDR_WD-1: 0] base_addr,
	output [ADDR_WD-1: 0] addr,
	output req,
	output we,
	input  ready
);
	localparam IDLE = 1'b0;
	localparam ST_LOAD = 1'b1;
	reg state;
	wire load_cnt_done;
	wire [$clog2(CYCLE)-1: 0] w_load_cnt;
	reg [ADDR_WD-1: 0]		base_addr_q;

	always@(posedge clk) begin
		if(clr) begin
			base_addr_q <= 0;
		end else if(ena && (state==IDLE) && load) begin
			base_addr_q <= base_addr;
		end else begin
			base_addr_q <= base_addr_q;
		end
	end

	always@(posedge clk or negedge rstn) begin
		if(~rstn) begin
			state <= IDLE;
		end else if(clr) begin
			state <= IDLE;
		end else if(ena) begin
			case(state)
				IDLE: begin
					state <= load? ST_LOAD: state;
				end
				ST_LOAD: begin
					state <= load_cnt_done? IDLE: state;
				end
				default: begin
					state <= IDLE;
				end
			endcase
		end else begin
			state <= state;
		end
	end

	counter#(.UBD(CYCLE)) u_load_counter(
		.clk(clk), .rstn(rstn), .clr(clr), .ena(ena && (state==ST_LOAD) && ready),
		.cnt_done(load_cnt_done),
		.cnt(w_load_cnt)
	);

	assign req = ena & (state==ST_LOAD);
	assign we = 1'b0;	// Read Only.
	assign addr = base_addr_q + w_load_cnt;

endmodule
