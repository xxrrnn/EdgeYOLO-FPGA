module axi_slave#(
	parameter	AXI_DATA_WIDTH	=	axi_bridge_pkg::AXI_DATA_WIDTH,
	parameter	AXI_BYTE_WIDTH	=	axi_bridge_pkg::AXI_BYTE_WIDTH,
	parameter	AXI_ADDR_WIDTH	=	axi_bridge_pkg::AXI_ADDR_WIDTH,

	parameter	ACT_LENG_WIDTH	=	axi_bridge_pkg::ACT_LENG_WIDTH,
	parameter	CLR_ADDR		=	axi_bridge_pkg::CLR_ADDR,
	parameter	LOAD_ADDR		=	axi_bridge_pkg::LOAD_ADDR,
	parameter	SWAP_ADDR		=	axi_bridge_pkg::SWAP_ADDR,
	parameter	START_ADDR		=	axi_bridge_pkg::START_ADDR,

	parameter	CFG_ENA_ADDR		=	axi_bridge_pkg::CFG_ENA_ADDR,
	parameter	CFG_MODE_ADDR		=	axi_bridge_pkg::CFG_MODE_ADDR,
	parameter	CFG_ACC_ADDR		=	axi_bridge_pkg::CFG_ACC_ADDR,
	parameter	CFG_RES_RIGHT_ADDR	=	axi_bridge_pkg::CFG_RES_RIGHT_ADDR,
	parameter	CFG_ACT_LEN_ADDR	=	axi_bridge_pkg::CFG_ACT_LEN_ADDR,
	parameter	CFG_LOOP_ADDR		=	axi_bridge_pkg::CFG_LOOP_ADDR,

	parameter	CFG_ADDR		=	axi_bridge_pkg::CFG_ADDR,
	parameter	CFG_SIZE		=	axi_bridge_pkg::CFG_SIZE,

	parameter	ACT_ADDR		=	axi_bridge_pkg::ACT_ADDR,
	parameter	WEI_ADDR		=	axi_bridge_pkg::WEI_ADDR,
	parameter	RES_ADDR		=	axi_bridge_pkg::RES_ADDR,

	parameter	ACT_SIZE		=	axi_bridge_pkg::ACT_SIZE,
	parameter	WEI_SIZE		=	axi_bridge_pkg::WEI_SIZE,
	parameter	RES_SIZE		=	axi_bridge_pkg::RES_SIZE
)(
	input	logic							clk,
	input	logic							rstn,

	// AXI Interface
	input	logic							axi_req_i,
	input	logic							axi_we_i,
	output	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o,
	output	logic							ctrl_clr,

	// public
	input	logic	[AXI_ADDR_WIDTH-1: 0]	axi_addr_i,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_wdata_i,
	input	logic	[AXI_BYTE_WIDTH-1: 0]	axi_be_i,

	// Buffer ACT
	output	logic							axi_req_i_act,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o_act,
	output	logic	[ACT_LENG_WIDTH-1: 0]	cfg_act_len,
	output	logic							cfg_loop,
	output	logic							ctrl_start,

	// DCIM WEIGHT
	output	logic							axi_req_i_wei,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o_wei,
	output	logic							ctrl_swap,
	output	logic							ctrl_load,

	// Buffer RES
	output	logic							axi_req_i_res,
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o_res,
	output	logic							cfg_res_right,

	// DCIM Cfg & Ctrl
	output	logic							cfg_dcim_ena,
	output	logic	[4: 0]					cfg_dcim_acc,
	output	logic	[2: 0]					cfg_dcim_mode
);

	logic		addr_in_cfg;
	logic		addr_in_act;
	logic		addr_in_res;
	logic		addr_in_wei;

	// 1 + 1 + 1 + 7 + 5 + 3 = 18 bit in total.
	logic			r_cfg_ena;
	logic			r_cfg_res_right;
	logic			r_cfg_loop;
	logic	[6: 0]	r_cfg_act_len;
	logic	[4: 0]	r_cfg_acc;
	logic	[2: 0]	r_cfg_mode;
	always_ff @(posedge clk or negedge rstn) begin
		if(~rstn) begin
			r_cfg_ena 		<=	1'b1;
			r_cfg_res_right	<=	1'b0;
			r_cfg_loop		<=	1'b0;
			r_cfg_act_len	<= 	'0;
			r_cfg_acc		<=	'0;
			r_cfg_mode		<=	'0;
		end else if(axi_req_i && axi_we_i) begin
			r_cfg_ena		<=	(axi_addr_i==CFG_ENA_ADDR)? 		axi_wdata_i[0]: r_cfg_ena;
			r_cfg_res_right	<=	(axi_addr_i==CFG_RES_RIGHT_ADDR)? 	axi_wdata_i[0]: r_cfg_res_right;
			r_cfg_loop		<=	(axi_addr_i==CFG_LOOP_ADDR)? 		axi_wdata_i[0]: r_cfg_loop;
			r_cfg_act_len	<= 	(axi_addr_i==CFG_ACT_LEN_ADDR)? 	axi_wdata_i[6:0]: r_cfg_act_len;
			r_cfg_acc		<=	(axi_addr_i==CFG_ACC_ADDR)? 		axi_wdata_i[4:0]: r_cfg_acc;
			r_cfg_mode		<=	(axi_addr_i==CFG_MODE_ADDR)? 		axi_wdata_i[2:0]: r_cfg_mode;
		end else begin
			r_cfg_ena 		<=	r_cfg_ena;
			r_cfg_res_right	<=	r_cfg_res_right;
			r_cfg_loop		<=	r_cfg_loop;
			r_cfg_act_len	<= 	r_cfg_act_len;
			r_cfg_acc		<=	r_cfg_acc;
			r_cfg_mode		<=	r_cfg_mode;
		end
	end

	always_comb begin
		addr_in_cfg		= (axi_addr_i >= CFG_ADDR) && (axi_addr_i <= CFG_ADDR+CFG_SIZE-AXI_BYTE_WIDTH);
		addr_in_act		= (axi_addr_i >= ACT_ADDR) && (axi_addr_i <= ACT_ADDR+ACT_SIZE-AXI_BYTE_WIDTH);
		addr_in_wei		= (axi_addr_i >= WEI_ADDR) && (axi_addr_i <= WEI_ADDR+WEI_SIZE-AXI_BYTE_WIDTH);
		addr_in_res		= (axi_addr_i >= RES_ADDR) && (axi_addr_i <= RES_ADDR+RES_SIZE-AXI_BYTE_WIDTH);

		cfg_act_len 	= r_cfg_act_len;
		cfg_loop 		= r_cfg_loop;
		cfg_res_right	= r_cfg_res_right;
		cfg_dcim_ena	= r_cfg_ena;
		cfg_dcim_acc	= r_cfg_acc;
		cfg_dcim_mode	= r_cfg_mode;

		ctrl_clr		= axi_req_i && axi_we_i && (axi_addr_i == CLR_ADDR);
		ctrl_start		= axi_req_i && axi_we_i && (axi_addr_i == START_ADDR);
		ctrl_swap		= axi_req_i && axi_we_i	&& (axi_addr_i == SWAP_ADDR);
		ctrl_load		= axi_req_i && axi_we_i && (axi_addr_i == LOAD_ADDR);

		axi_req_i_act	= addr_in_act && axi_req_i;
		axi_req_i_wei	= addr_in_wei && axi_req_i;
		axi_req_i_res	= addr_in_res && axi_req_i;

		axi_rdata_o		= '0;
		if (addr_in_cfg) begin
			axi_rdata_o[17: 0] = {r_cfg_ena, r_cfg_res_right, r_cfg_loop, r_cfg_act_len, r_cfg_acc, r_cfg_mode };
		end else if(addr_in_act) begin
			axi_rdata_o	=	axi_rdata_o_act;
		end else if(addr_in_wei) begin
			axi_rdata_o	=	axi_rdata_o_wei;
		end else if(addr_in_res) begin
			axi_rdata_o	=	axi_rdata_o_res;
		end else begin
			axi_rdata_o = '1;	// Error Flag
		end
	end

endmodule
