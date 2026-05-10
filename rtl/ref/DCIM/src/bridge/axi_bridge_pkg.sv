package axi_bridge_pkg;

	parameter	AXI_BASE_ADDR	= '0;

	parameter 	AXI_DATA_WIDTH	= 64;
	parameter 	AXI_BYTE_WIDTH 	= AXI_DATA_WIDTH / 8;
	parameter 	AXI_ADDR_WIDTH 	= 64;

	parameter 	ACT_DATA_WIDTH 	= 64;
	parameter 	ACT_DEPTH		= 64;
	parameter 	ACT_LENG_WIDTH 	= $clog2(ACT_DEPTH+1);
	parameter 	ACT_ADDR_WIDTH 	= $clog2(ACT_DEPTH);

	parameter 	WEI_DATA_WIDTH	= 128;
	parameter 	WEI_DEPTH		= 128;
	parameter 	WEI_LENG_WIDTH 	= $clog2(ACT_DEPTH+1);
	parameter 	WEI_ADDR_WIDTH 	= $clog2(ACT_DEPTH);

	parameter 	RES_DATA_WIDTH 	= 256;
	parameter 	RES_DEPTH		= 64;
	parameter 	RES_LENG_WIDTH 	= $clog2(ACT_DEPTH+1);
	parameter 	RES_ADDR_WIDTH 	= $clog2(ACT_DEPTH);

	parameter	CFG_ENA_ADDR		=	AXI_BASE_ADDR + 16'h0000;
	parameter	CFG_MODE_ADDR		=	AXI_BASE_ADDR + 16'h0008;
	parameter	CFG_ACC_ADDR		=	AXI_BASE_ADDR + 16'h0010;
	parameter	CFG_RES_RIGHT_ADDR	=	AXI_BASE_ADDR + 16'h0018;
	parameter	CFG_ACT_LEN_ADDR	=	AXI_BASE_ADDR + 16'h0020;
	parameter	CFG_LOOP_ADDR		=	AXI_BASE_ADDR + 16'h0028;

	parameter	CLR_ADDR	=	AXI_BASE_ADDR + 16'h0100;
	parameter	START_ADDR	=	AXI_BASE_ADDR + 16'h0108;
	parameter	LOAD_ADDR	=	AXI_BASE_ADDR + 16'h0110;
	parameter	SWAP_ADDR	=	AXI_BASE_ADDR + 16'h0118;

	parameter	CFG_ADDR	=	AXI_BASE_ADDR + 16'h0000;
	parameter	CFG_SIZE	=	16'h0030;

	// WEI Size: 128x128 = 2KB	0x0800 	[1000, 1800)
	parameter	WEI_ADDR	=	AXI_BASE_ADDR + 16'h1000;
	parameter	WEI_SIZE	=	(WEI_DEPTH * WEI_DATA_WIDTH) / 8;

	// ACT Size: 64x64 = 512B	0x0200	[2000, 2200)
	parameter	ACT_ADDR	=	AXI_BASE_ADDR + 16'h2000;
	parameter	ACT_SIZE	=	(ACT_DEPTH * ACT_DATA_WIDTH) / 8;

	// RES Size: 64x256	= 2KB	0x0800	[3000, 3800)
	parameter	RES_ADDR	=	AXI_BASE_ADDR + 16'h3000;
	parameter	RES_SIZE	=	(RES_DEPTH * RES_DATA_WIDTH) / 8;


endpackage
