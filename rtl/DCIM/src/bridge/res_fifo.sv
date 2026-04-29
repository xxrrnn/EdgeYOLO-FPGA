module res_fifo#(
	parameter	AXI_DATA_WIDTH	=	axi_bridge_pkg::AXI_DATA_WIDTH,
	parameter	AXI_BYTE_WIDTH	=	axi_bridge_pkg::AXI_BYTE_WIDTH,
	parameter	AXI_ADDR_WIDTH	=	axi_bridge_pkg::AXI_ADDR_WIDTH,
	parameter	RES_DATA_WIDTH	=	axi_bridge_pkg::RES_DATA_WIDTH,
	parameter	RES_ADDR_WIDTH	=	axi_bridge_pkg::RES_ADDR_WIDTH,
	parameter	RES_DEPTH		=	axi_bridge_pkg::RES_DEPTH
)(
	input	logic							clk,
	input	logic							rstn,
	input	logic							clr,
	input	logic							axi_req_i,
	input	logic							axi_we_i,
	input	logic	[AXI_ADDR_WIDTH-1: 0]	axi_addr_i,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_wdata_i,
	input	logic	[AXI_BYTE_WIDTH-1: 0]	axi_be_i,
	output	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o,
	
	input	logic							res_valid,
	output	logic							res_ready,
	input	logic	[RES_DATA_WIDTH-1: 0]	res_data,

	input	logic							cfg_res_right
);

	logic	[RES_ADDR_WIDTH-1: 0]	res_cnt;

	always_comb begin
		res_ready = cfg_res_right;
	end

	counter#(
		.UBD(RES_DEPTH)
	)	u_res_counter(
		.clk		(clk			),
		.rstn		(rstn			),
		.clr		(clr			),
		.ena		(res_valid		),
		.cnt		(res_cnt		),
		.cnt_done	(				)
	);

	buffer_res#(
		.AXI_DATA_WIDTH(AXI_DATA_WIDTH),
		.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
	) u_buffer_res (
		.clk			(clk			),
		.rstn			(rstn			),

		.axi_req_i		(axi_req_i		),
		.axi_we_i		(axi_we_i		),
		.axi_addr_i		(axi_addr_i		),
		.axi_wdata_i	(axi_wdata_i	),
		.axi_be_i		(axi_be_i		),
		.axi_rdata_o	(axi_rdata_o	),

		.int_req_i		(res_valid		),
		.int_we_i		(1'b1			),
		.int_addr_i		(res_cnt		),
		.int_wdata_i	(res_data		),
		.int_be_i		('1				),
		.int_rdata_o	(				),

		.cfg_right		(cfg_res_right	)
	);

endmodule
