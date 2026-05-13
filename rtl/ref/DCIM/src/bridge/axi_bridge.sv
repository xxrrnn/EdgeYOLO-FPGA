module axi_bridge#(
	parameter	AXI_DATA_WIDTH	=	axi_bridge_pkg::AXI_DATA_WIDTH,
	parameter	AXI_ADDR_WIDTH	=	axi_bridge_pkg::AXI_ADDR_WIDTH,
	parameter	AXI_BYTE_WIDTH	=	axi_bridge_pkg::AXI_BYTE_WIDTH,
	parameter	ACT_LENG_WIDTH	=	axi_bridge_pkg::ACT_LENG_WIDTH,
	parameter	ACT_DATA_WIDTH	=	axi_bridge_pkg::ACT_DATA_WIDTH,
	parameter	ACT_ADDR_WIDTH	=	axi_bridge_pkg::ACT_ADDR_WIDTH,
	parameter	ACT_DEPTH		=	axi_bridge_pkg::ACT_DEPTH,
	parameter	WEI_DATA_WIDTH	=	axi_bridge_pkg::WEI_DATA_WIDTH,
	parameter	WEI_ADDR_WIDTH	=	axi_bridge_pkg::WEI_ADDR_WIDTH,
	parameter	RES_DATA_WIDTH	=	axi_bridge_pkg::RES_DATA_WIDTH,
	parameter	RES_ADDR_WIDTH	=	axi_bridge_pkg::RES_ADDR_WIDTH,
	parameter	RES_DEPTH		=	axi_bridge_pkg::RES_DEPTH
)(
	// AXI Interface
	input	logic							clk,
	input	logic							rstn,

	input	logic							axi_req_i,
	input	logic							axi_we_i,
	input	logic	[AXI_ADDR_WIDTH-1: 0]	axi_addr_i,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_wdata_i,
	input	logic	[AXI_BYTE_WIDTH-1: 0]	axi_be_i,
	output	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o,

	// DCIM Interface
	output	logic							dcim_clr,
	output	logic							dcim_ena,

	output	logic	[2: 0]					dcim_mode,
	output	logic	[4: 0]					dcim_acc,

	output	logic							dcim_wei_wr,
	output	logic	[WEI_ADDR_WIDTH-1: 0]	dcim_wei_addr,
	output	logic	[WEI_DATA_WIDTH-1: 0]	dcim_wei_data,
	output	logic	[WEI_DATA_WIDTH-1: 0]	dcim_wei_be,
	output	logic							dcim_load,
	output	logic							dcim_swap,

	output	logic							dcim_act_valid,
	input	logic							dcim_act_ready,
	output	logic	[ACT_DATA_WIDTH-1: 0]	dcim_act_data,

	input	logic							dcim_res_valid,
	output	logic							dcim_res_ready,
	input	logic	[RES_DATA_WIDTH-1: 0]	dcim_res_data
);
	logic							ctrl_clr;

	logic							axi_req_i_act;
	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o_act;
	logic	[ACT_LENG_WIDTH-1: 0]	cfg_act_len;
	logic							cfg_loop;
	logic							ctrl_start;

	logic							axi_req_i_wei;
	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o_wei;

	logic							axi_req_i_res;
	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o_res;
	logic							cfg_res_right;

	axi_slave#(
		.AXI_DATA_WIDTH	(AXI_DATA_WIDTH	),
		.AXI_BYTE_WIDTH	(AXI_BYTE_WIDTH	),
		.AXI_ADDR_WIDTH	(AXI_ADDR_WIDTH	)
	)	u_axi_slave	(
		.clk			(clk			),
		.rstn			(rstn			),

		.axi_req_i		(axi_req_i		),
		.axi_we_i		(axi_we_i		),
		.axi_addr_i		(axi_addr_i		),
		.axi_be_i		(axi_be_i		),
		.axi_wdata_i	(axi_wdata_i	),
		.axi_rdata_o	(axi_rdata_o	),

		.ctrl_clr		(ctrl_clr		),
		.cfg_dcim_ena	(dcim_ena		),
		.cfg_dcim_acc	(dcim_acc		),
		.cfg_dcim_mode	(dcim_mode		),

		.axi_req_i_act	(axi_req_i_act	),
		.axi_rdata_o_act(axi_rdata_o_act),
		.cfg_act_len	(cfg_act_len	),
		.cfg_loop		(cfg_loop		),
		.ctrl_start		(ctrl_start		),

		.axi_req_i_wei	(axi_req_i_wei	),
		.axi_rdata_o_wei(axi_rdata_o_wei),
		.ctrl_load		(dcim_load		),
		.ctrl_swap		(dcim_swap		),
		
		.axi_req_i_res	(axi_req_i_res	),
		.axi_rdata_o_res(axi_rdata_o_res),
		.cfg_res_right	(cfg_res_right	)
	);

	act_sequencer#(
		.AXI_DATA_WIDTH	(AXI_DATA_WIDTH	),
		.AXI_BYTE_WIDTH	(AXI_BYTE_WIDTH	),
		.AXI_ADDR_WIDTH	(AXI_ADDR_WIDTH	),
		.ACT_DATA_WIDTH	(ACT_DATA_WIDTH	),
		.ACT_ADDR_WIDTH	(ACT_ADDR_WIDTH	),
		.ACT_DEPTH		(ACT_DEPTH		),
		.ACT_LENG_WIDTH	(ACT_LENG_WIDTH	)
	)	u_act_sequencer	(
		.clk			(clk			),
		.rstn			(rstn			),
		.clr			(ctrl_clr		),
		.ctrl_start		(ctrl_start		),
		.cfg_loop		(cfg_loop		),
		.cfg_act_len	(cfg_act_len	),
		.axi_req_i		(axi_req_i_act	),
		.axi_we_i		(axi_we_i		),
		.axi_addr_i		(axi_addr_i		),
		.axi_wdata_i	(axi_wdata_i	),
		.axi_be_i		(axi_be_i		),
		.axi_rdata_o	(axi_rdata_o_act),
		.act_valid		(dcim_act_valid	),
		.act_ready		(dcim_act_ready	),
		.act_data		(dcim_act_data	)
	);

	wei_packer#(
		.AXI_DATA_WIDTH	(AXI_DATA_WIDTH	),
		.AXI_BYTE_WIDTH	(AXI_BYTE_WIDTH	),
		.AXI_ADDR_WIDTH	(AXI_ADDR_WIDTH	),
		.WEI_DATA_WIDTH	(WEI_DATA_WIDTH	),
		.WEI_ADDR_WIDTH	(WEI_ADDR_WIDTH	)
	) u_wei_packer	(
		.clk			(clk			),
		.rstn			(rstn			),
		.axi_req_i		(axi_req_i_wei	),
		.axi_we_i		(axi_we_i		),
		.axi_addr_i		(axi_addr_i		),
		.axi_wdata_i	(axi_wdata_i	),
		.axi_be_i		(axi_be_i		),
		.axi_rdata_o	(axi_rdata_o_wei),
		.wei_wr			(dcim_wei_wr	),
		.wei_addr		(dcim_wei_addr	),
		.wei_wdata		(dcim_wei_data	),
		.wei_be			(dcim_wei_be	)
	);

	res_fifo#(
		.AXI_DATA_WIDTH	(AXI_DATA_WIDTH	),
		.AXI_BYTE_WIDTH	(AXI_BYTE_WIDTH	),
		.AXI_ADDR_WIDTH	(AXI_ADDR_WIDTH	),
		.RES_DATA_WIDTH	(RES_DATA_WIDTH	),
		.RES_ADDR_WIDTH	(RES_ADDR_WIDTH	),
		.RES_DEPTH		(RES_DEPTH		)
	)	u_res_fifo	(
		.clk			(clk			),
		.rstn			(rstn			),
		.clr			(ctrl_clr		),
		.cfg_res_right	(cfg_res_right	),
		.axi_req_i		(axi_req_i_res	),
		.axi_we_i		(axi_we_i		),
		.axi_addr_i		(axi_addr_i		),
		.axi_wdata_i	(axi_wdata_i	),
		.axi_be_i		(axi_be_i		),
		.axi_rdata_o	(axi_rdata_o_res),
		.res_valid		(dcim_res_valid	),
		.res_ready		(dcim_res_ready	),
		.res_data		(dcim_res_data	)
	);
	
endmodule
