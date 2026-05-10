module act_sequencer#(
	parameter 	AXI_DATA_WIDTH 	= 	axi_bridge_pkg::AXI_DATA_WIDTH,
	parameter 	AXI_BYTE_WIDTH	= 	axi_bridge_pkg::AXI_BYTE_WIDTH,
	parameter 	AXI_ADDR_WIDTH 	= 	axi_bridge_pkg::AXI_ADDR_WIDTH,
	parameter 	ACT_DATA_WIDTH 	= 	axi_bridge_pkg::ACT_DATA_WIDTH,
	parameter	ACT_ADDR_WIDTH	= 	axi_bridge_pkg::ACT_ADDR_WIDTH,
	parameter	ACT_DEPTH		=	axi_bridge_pkg::ACT_DEPTH,
	parameter 	ACT_LENG_WIDTH	= 	axi_bridge_pkg::ACT_LENG_WIDTH
)(
	input	logic							clk,
	input	logic							rstn,
	input	logic							clr,

	input	logic							ctrl_start,

	input	logic							cfg_loop,
	input	logic	[ACT_LENG_WIDTH-1: 0]	cfg_act_len,

	input	logic							axi_req_i,
	input	logic							axi_we_i,
	input	logic	[AXI_ADDR_WIDTH-1: 0]	axi_addr_i,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_wdata_i,
	input	logic	[AXI_BYTE_WIDTH-1: 0]	axi_be_i,
	output	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o,

	output									act_valid,
	input									act_ready,
	output			[ACT_DATA_WIDTH-1: 0]	act_data
);
	typedef enum logic {
		IDLE,
		RUN
	} State;

	State 							state;
	logic							act_cnt_done;
	logic	[ACT_ADDR_WIDTH-1: 0]	act_cnt;
	logic							up_ready;
	logic							run;
	assign run = (state==RUN);

	always_ff @(posedge clk or negedge rstn) begin
		if(~rstn) begin
			state <= IDLE;
		end else if(clr) begin
			state <= IDLE;
		end else begin
			case(state)
				IDLE:	state <= ctrl_start? RUN: IDLE;
				RUN:	state <= act_cnt_done? (cfg_loop? state: IDLE): state;
				default:state <= IDLE;
			endcase
		end
	end

	counter_cfg#(
		.UBD_MAX(ACT_DEPTH)
	)	u_act_counter(
		.clk		(clk			),
		.rstn		(rstn			),
		.clr		(clr			),
		.ena		(up_ready && run),
		.ubd		(cfg_act_len	),
		.cnt		(act_cnt		),
		.cnt_done	(act_cnt_done	)
	);

	pipe_stage u_pipe_stage_ctrl(
		.clk		(clk		),
		.rstn		(rstn		),
		.clr		(clr		),
		.ena		(1'b1		),
		.up_valid	(run		),
		.up_ready	(up_ready	),
		.dn_valid	(act_valid	),
		.dn_ready	(act_ready	)
	);

	buffer_act#(
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH),
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
	) u_act_buffer(
		.clk			(clk			),
		.rstn			(rstn			),

		.axi_req_i		(axi_req_i		),
		.axi_we_i		(axi_we_i		),
		.axi_addr_i		(axi_addr_i		),
		.axi_wdata_i	(axi_wdata_i	),
		.axi_be_i		(axi_be_i		),
		.axi_rdata_o	(axi_rdata_o	),

		.int_req_i		( run&up_ready	),
		.int_we_i		( 1'b0			),
		.int_addr_i		( act_cnt		),
		.int_wdata_i	( '0			),
		.int_be_i		( '0			),
		.int_rdata_o	( act_data		),

		.cfg_right		( run			)
	);

endmodule
