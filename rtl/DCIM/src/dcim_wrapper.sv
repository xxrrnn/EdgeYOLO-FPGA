module dcim_wrapper#(
	parameter	AXI_DATA_WIDTH	=	64,
	localparam	AXI_BYTE_WIDTH	=	AXI_DATA_WIDTH / 8,
	parameter	AXI_ADDR_WIDTH	=	64,
	parameter	ACT_DATA_WIDTH	=	64,
	parameter	WEI_DATA_WIDTH	=	128,
	parameter	WEI_DEPTH		=	128,
	localparam	WEI_ADDR_WIDTH	=	$clog2(WEI_DEPTH),
	parameter	RES_DATA_WIDTH	=	256
)(
	input	logic							clk,
	input	logic							rstn,

	input	logic							axi_req_i,
	input	logic							axi_we_i,
	input	logic	[AXI_ADDR_WIDTH-1: 0]	axi_addr_i,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_wdata_i,
	input	logic	[AXI_BYTE_WIDTH-1: 0]	axi_be_i,
	output	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o
);

	logic							dcim_clr;
	logic							dcim_ena;
	logic	[2: 0]					dcim_mode;
	logic	[4: 0]					dcim_acc;
	logic							dcim_wei_wr;	
	logic	[WEI_ADDR_WIDTH-1: 0]	dcim_wei_addr;
	logic	[WEI_DATA_WIDTH-1: 0]	dcim_wei_data;
	logic	[WEI_DATA_WIDTH-1: 0]	dcim_wei_be;
	logic							dcim_load;
	logic							dcim_swap;
	logic							dcim_act_valid;
	logic							dcim_act_ready;
	logic	[ACT_DATA_WIDTH-1: 0]	dcim_act_data;
	logic							dcim_res_ready;
	logic							dcim_res_valid;
	logic	[RES_DATA_WIDTH-1: 0]	dcim_res_data;

	axi_bridge#(
		.AXI_DATA_WIDTH	(AXI_DATA_WIDTH	),
		.AXI_ADDR_WIDTH	(AXI_ADDR_WIDTH	),
		.AXI_BYTE_WIDTH	(AXI_BYTE_WIDTH	)
	) u_axi_bridge (
		.clk			(clk			),
		.rstn			(rstn			),
		.axi_req_i		(axi_req_i		),
		.axi_we_i		(axi_we_i		),
		.axi_addr_i		(axi_addr_i		),
		.axi_wdata_i	(axi_wdata_i	),
		.axi_be_i		(axi_be_i		),
		.axi_rdata_o	(axi_rdata_o	),

		.dcim_clr		(dcim_clr		),
		.dcim_ena		(dcim_ena		),
		.dcim_mode		(dcim_mode		),
		.dcim_acc		(dcim_acc		),
		.dcim_wei_wr	(dcim_wei_wr	),
		.dcim_wei_addr	(dcim_wei_addr	),
		.dcim_wei_data	(dcim_wei_data	),
		.dcim_wei_be	(dcim_wei_be	),
		.dcim_load		(dcim_load		),
		.dcim_swap		(dcim_swap		),
		.dcim_act_valid	(dcim_act_valid	),
		.dcim_act_ready	(dcim_act_ready	),
		.dcim_act_data	(dcim_act_data	),
		.dcim_res_ready	(dcim_res_ready	),
		.dcim_res_valid	(dcim_res_valid	),
		.dcim_res_data	(dcim_res_data	)
	);

	dcim#(
		.WD1		(4		),
		.CH_IN		(16		),
		.CH_OUT		(16		),
		.SRAM_DP	(128	),
		.CYCLE		(8		),
		.ACC		(16		)
	) u_dcim(
		.clk			(clk			),
		.rstn			(rstn			),
		.clr			(dcim_clr		),
		.ena			(dcim_ena		),
		.mode_cal		(dcim_mode		),
		.acc			(dcim_acc		),
		.wr_wei			(dcim_wei_wr	),
		.load_wei		(dcim_load		),
		.swap_wei		(dcim_swap		),
		.up_ready_wei	(				),
		.up_address_wei	(dcim_wei_addr	),
		.up_data_wei	(dcim_wei_data	),
		.up_be_wei		(dcim_wei_be	),
		.up_valid_cal	(dcim_act_valid	),
		.up_ready_cal	(dcim_act_ready	),
		.up_data_cal	(dcim_act_data	),
		.dn_valid		(dcim_res_valid	),
		.dn_ready		(dcim_res_ready	),
		.dn_data		(dcim_res_data	)
	);

endmodule
