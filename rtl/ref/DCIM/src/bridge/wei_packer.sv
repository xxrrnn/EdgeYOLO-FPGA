module wei_packer#(
	parameter	AXI_DATA_WIDTH	=	axi_bridge_pkg::AXI_DATA_WIDTH,
	parameter	AXI_BYTE_WIDTH	=	axi_bridge_pkg::AXI_BYTE_WIDTH,
	parameter	AXI_ADDR_WIDTH	=	axi_bridge_pkg::AXI_ADDR_WIDTH,
	parameter	WEI_DATA_WIDTH	=	axi_bridge_pkg::WEI_DATA_WIDTH,
	parameter	WEI_ADDR_WIDTH	=	axi_bridge_pkg::WEI_ADDR_WIDTH,
	localparam	RATIO			=	WEI_DATA_WIDTH/AXI_DATA_WIDTH,
	localparam	OFFSET_WIDTH	=	$clog2(RATIO)
)(
	input	logic							axi_req_i,
	input	logic							axi_we_i,
	input	logic	[AXI_ADDR_WIDTH-1: 0]	axi_addr_i,
	input	logic	[AXI_BYTE_WIDTH-1: 0]	axi_be_i,	// Byte Mask
	input	logic	[AXI_DATA_WIDTH-1: 0]	axi_wdata_i,
	output	logic	[AXI_DATA_WIDTH-1: 0]	axi_rdata_o,

	output	logic							wei_wr,
	output	logic	[WEI_ADDR_WIDTH-1: 0]	wei_addr,
	output	logic	[WEI_DATA_WIDTH-1: 0]	wei_wdata,
	output	logic	[WEI_DATA_WIDTH-1: 0]	wei_be
);

	assign axi_rdata_o = '0;
	logic	[AXI_DATA_WIDTH-1: 0]	axi_bit_be;
	always_comb begin
		for(int i=0; i<AXI_BYTE_WIDTH; i++) begin
			axi_bit_be[i*8 +: 8] = {8{axi_be_i[i]}};
		end
		wei_wr = axi_req_i && axi_we_i;
	end

	generate
		if(RATIO>1) begin:GenPacker
			logic [OFFSET_WIDTH-1: 0]	sub_word_idx;
			always_comb begin
				wei_be       = '0;
				sub_word_idx = axi_addr_i[$clog2(AXI_BYTE_WIDTH) +: OFFSET_WIDTH];
				wei_addr     = axi_addr_i[$clog2(AXI_BYTE_WIDTH)+OFFSET_WIDTH +: WEI_ADDR_WIDTH];
				wei_wdata    = {RATIO{axi_wdata_i}};
				wei_be[sub_word_idx*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = axi_bit_be;
			end
		end else begin:WriteThrough
			always_comb begin
				wei_addr  = axi_addr_i[$clog2(AXI_BYTE_WIDTH) +: WEI_ADDR_WIDTH];
				wei_wdata = axi_wdata_i;
				wei_be    = axi_bit_be;
			end
		end
	endgenerate

endmodule
