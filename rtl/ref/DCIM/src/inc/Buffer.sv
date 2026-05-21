module	Buffer#(
	parameter  AXI_DATA_WIDTH 	= 64,
	parameter  AXI_ADDR_WIDTH 	= 64,
	parameter  BUF_DATA_WIDTH 	= 64,
	parameter  BUF_DEPTH		= 128,
	localparam BUF_ADDR_WIDTH 	= $clog2(BUF_DEPTH),
	localparam RATIO			= BUF_DATA_WIDTH / AXI_DATA_WIDTH,
	localparam AXI_BYTE_WIDTH	= AXI_DATA_WIDTH / 8,
	localparam OFFSET_WIDTH 	= $clog2(RATIO)
)(
	input  logic							clk,
	input  logic							rstn,

	input  logic							axi_req_i,
	input  logic							axi_we_i,
	input  logic [AXI_ADDR_WIDTH-1: 0]		axi_addr_i,
	input  logic [AXI_DATA_WIDTH/8-1: 0] 	axi_be_i,	// Byte Enable
	input  logic [AXI_DATA_WIDTH-1: 0]		axi_wdata_i,
	output logic [AXI_DATA_WIDTH-1: 0]		axi_rdata_o,

	input  logic							int_req_i,
	input  logic							int_we_i,
	input  logic [BUF_ADDR_WIDTH-1: 0]		int_addr_i,
	input  logic [BUF_DATA_WIDTH-1: 0]		int_be_i,	// Bit Enable
	input  logic [BUF_DATA_WIDTH-1: 0]		int_wdata_i,
	output logic [BUF_DATA_WIDTH-1: 0]		int_rdata_o,

	input  logic							cfg_right	// 0 for AXI; 1 for Internel
);	
	logic						req;
	logic 						we;
	logic [BUF_ADDR_WIDTH-1: 0] addr;
	logic [BUF_DATA_WIDTH-1: 0] be;
	logic [BUF_DATA_WIDTH-1: 0] wdata;
	logic [BUF_DATA_WIDTH-1: 0] rdata;

	logic [BUF_DATA_WIDTH-1: 0] axi_wdata_t;
	logic [BUF_DATA_WIDTH-1: 0] axi_be_t;
	logic [BUF_ADDR_WIDTH-1: 0] axi_addr_t;

    logic [AXI_DATA_WIDTH-1:0] 	axi_bit_be;
	always_comb begin
		for (int i = 0; i < AXI_BYTE_WIDTH; i++) begin
			axi_bit_be[i*8 +: 8] = {8{axi_be_i[i]}};
		end
	end

	generate
		if(RATIO>1) begin:GenWideBuffer
			logic [OFFSET_WIDTH-1: 0] 	axi_sub_word_idx;
        	logic [OFFSET_WIDTH-1: 0]	axi_sub_word_idx_q;
			always_ff@(posedge clk or negedge rstn) begin
				if(~rstn) begin
					axi_sub_word_idx_q <= '0;
				end else if(axi_req_i && (~axi_we_i)) begin
					axi_sub_word_idx_q <= axi_sub_word_idx;
				end else begin
					axi_sub_word_idx_q <= axi_sub_word_idx_q;
				end
			end
			always_comb begin
				axi_be_t	= '0;
				axi_sub_word_idx = axi_addr_i[$clog2(AXI_BYTE_WIDTH) +: OFFSET_WIDTH];
				axi_rdata_o = rdata[axi_sub_word_idx_q*AXI_DATA_WIDTH +: AXI_DATA_WIDTH];
				axi_wdata_t = {(RATIO){axi_wdata_i}};
				axi_be_t[axi_sub_word_idx*AXI_DATA_WIDTH +: AXI_DATA_WIDTH] = axi_bit_be;
				axi_addr_t 	= axi_addr_i[$clog2(AXI_BYTE_WIDTH)+OFFSET_WIDTH +: BUF_ADDR_WIDTH];
			end
		end else begin:GenEqualBuffer
			always_comb begin
				axi_rdata_o = rdata;
				axi_wdata_t = axi_wdata_i;
				axi_be_t	= axi_bit_be;
				axi_addr_t	= axi_addr_i[$clog2(AXI_BYTE_WIDTH) +: BUF_ADDR_WIDTH];
			end
		end
	endgenerate

	always_comb begin
        if (cfg_right) begin
            req   = int_req_i;
            we    = int_we_i;
            addr  = int_addr_i;
            be    = int_be_i;
            wdata = int_wdata_i;
        end else begin
            req   = axi_req_i;
            we    = axi_we_i;
			addr  = axi_addr_t;
			be	  = axi_be_t;
			wdata = axi_wdata_t;
        end
    end

	assign int_rdata_o = rdata;

	`ifdef SIM
		model_buffer#(
			.WIDTH(BUF_DATA_WIDTH),
			.DEPTH(BUF_DEPTH)
		) u_buffer(
			.clk(clk),
			.cen(~req),
			.gwen(~we),
			.wen(~be),
			.a(addr),
			.d(wdata),
			.q(rdata)
		);
	`else
		// 填真实的SRAM IP
	`endif

endmodule

module model_buffer#(
	parameter WIDTH = 128,
	parameter DEPTH = 128
)(
	input  logic 						clk,
	input  logic						cen,
	input  logic [$clog2(DEPTH)-1: 0] 	a,
	input  logic 						gwen,
	input  logic [WIDTH-1: 0]			wen,	//bit Enable
	input  logic [WIDTH-1: 0]			d,
	output logic [WIDTH-1: 0]			q
);

	logic [WIDTH-1: 0] r_mem [DEPTH-1: 0];

	always_ff @(posedge clk) begin
        if (~cen) begin
            if (~gwen) begin
               	r_mem[a] <= ((~wen) & d) | (wen & r_mem[a]);
            end else begin
                q <= r_mem[a];
            end
        end
    end

endmodule
