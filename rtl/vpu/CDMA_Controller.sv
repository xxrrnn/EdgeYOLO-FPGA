`timescale 1 ns / 1 ps
	module CDMA_Controller # (
        parameter int CDMA_BASE_ADDR = 0,
        parameter int C_CDMA_AXILM_ADDR_WIDTH = 32,
        parameter int C_CDMA_AXILM_DATA_WIDTH = 32
    ) (
        input wire        clk,
        input wire        rst_n,
        input wire        cdma_start,
        input wire        cdma_config_valid,
        output wire       cdma_config_ready,
        input wire [31:0] cdma_src_addr_msb,
        input wire [31:0] cdma_src_addr_lsb,
        input wire [31:0] cdma_dst_addr_msb, 
        input wire [31:0] cdma_dst_addr_lsb,
        input wire [31:0] cdma_length,

        // cdma axil part
		// output  logic clk,
        // output  logic rst_n,
        output logic [C_CDMA_AXILM_ADDR_WIDTH-1 : 0] cdma_axilm_awaddr,
        output logic [2 : 0] cdma_axilm_awprot,
        output logic cdma_axilm_awvalid,
        input  logic cdma_axilm_awready,
        output logic [C_CDMA_AXILM_DATA_WIDTH-1 : 0] cdma_axilm_wdata,
        output logic [C_CDMA_AXILM_DATA_WIDTH/8-1 : 0] cdma_axilm_wstrb,
        output logic cdma_axilm_wvalid,
        input  logic cdma_axilm_wready,
        input  logic [1 : 0] cdma_axilm_bresp,
        input  logic cdma_axilm_bvalid,
        output logic cdma_axilm_bready,
        output logic [C_CDMA_AXILM_ADDR_WIDTH-1 : 0] cdma_axilm_araddr,
        output logic [2 : 0] cdma_axilm_arprot,
        output logic cdma_axilm_arvalid,
        input  logic cdma_axilm_arready,
        input  logic [C_CDMA_AXILM_DATA_WIDTH-1 : 0] cdma_axilm_rdata,
        input  logic [1 : 0] cdma_axilm_rresp,
        input  logic cdma_axilm_rvalid,
        output logic cdma_axilm_rready
    );

///////////////////////////////// Ö¸ÁîÒëÂëÆ÷×´Ì¬»ú /////////////////////////////////
    //// AXI Lite CDMA handshakes (unchanged variables)
    wire aw_handshake_cdma = cdma_axilm_awready && cdma_axilm_awvalid;
    wire w_handshake_cdma  = cdma_axilm_wready  && cdma_axilm_wvalid;
    wire ar_handshake_cdma = cdma_axilm_arready && cdma_axilm_arvalid;
    wire r_handshake_cdma  = cdma_axilm_rvalid  && cdma_axilm_rready;

    reg [31:0] cdma_src_addr_msb_reg;
    reg [31:0] cdma_src_addr_lsb_reg;
    reg [31:0] cdma_dst_addr_msb_reg;
    reg [31:0] cdma_dst_addr_lsb_reg;
    reg [31:0] cdma_length_reg;


    assign cdma_axilm_awprot = '0;
    assign cdma_axilm_arprot = '0;

    typedef enum logic [7:0] {
        IDLE                = 8'd0,
        CDMA_CONFIG         = 8'd1,
        CDMA_CHECK          = 8'd2,
        CDMA_ENABLE_IRQ     = 8'd3,
        CDMA_ENABLE_IRQ_CLR = 8'd4,
        CDMA_WRITE_SRC_MSB  = 8'd5,
        CDMA_WRITE_SRC_MSB_CLR = 8'd6,
        CDMA_WRITE_SRC_LSB  = 8'd7,
        CDMA_WRITE_SRC_LSB_CLR = 8'd8,
        CDMA_WRITE_DST_MSB  = 8'd9,
        CDMA_WRITE_DST_MSB_CLR = 8'd10,
        CDMA_WRITE_DST_LSB  = 8'd11,
        CDMA_WRITE_DST_LSB_CLR = 8'd12,
        CDMA_WRITE_LEN      = 8'd13,
        CDMA_WRITE_LEN_CLR  = 8'd14,
        CDMA_WAIT           = 8'd15
    } state_t;
    (* fsm_encoding = "one_hot" *) state_t n_state, c_state;

    assign cdma_config_ready = c_state == IDLE;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            c_state <= IDLE;
        else
            c_state <= n_state;
    end

    
    always_comb begin
        n_state = c_state;
        case (c_state)
            IDLE:             if (cdma_start) n_state = CDMA_CHECK;
            CDMA_CONFIG:      n_state = CDMA_CHECK;

            //// CDMA ²¿·Ö (Ê¹ÓÃ _CLR ÖÐ¼äÌ¬À´Çå³ý valid)
            CDMA_CHECK:             if (r_handshake_cdma && cdma_axilm_rdata[1]) n_state = CDMA_ENABLE_IRQ;
            CDMA_ENABLE_IRQ:        if (aw_handshake_cdma && w_handshake_cdma) n_state = CDMA_ENABLE_IRQ_CLR;
            CDMA_ENABLE_IRQ_CLR:    n_state = CDMA_WRITE_SRC_MSB;
            CDMA_WRITE_SRC_MSB:     if (aw_handshake_cdma && w_handshake_cdma) n_state = CDMA_WRITE_SRC_MSB_CLR;
            CDMA_WRITE_SRC_MSB_CLR: n_state = CDMA_WRITE_SRC_LSB;
            CDMA_WRITE_SRC_LSB:     if (aw_handshake_cdma && w_handshake_cdma) n_state = CDMA_WRITE_SRC_LSB_CLR;
            CDMA_WRITE_SRC_LSB_CLR: n_state = CDMA_WRITE_DST_MSB;
            CDMA_WRITE_DST_MSB:     if (aw_handshake_cdma && w_handshake_cdma) n_state = CDMA_WRITE_DST_MSB_CLR;
            CDMA_WRITE_DST_MSB_CLR: n_state = CDMA_WRITE_DST_LSB;
            CDMA_WRITE_DST_LSB:     if (aw_handshake_cdma && w_handshake_cdma) n_state = CDMA_WRITE_DST_LSB_CLR;
            CDMA_WRITE_DST_LSB_CLR: n_state = CDMA_WRITE_LEN;
            CDMA_WRITE_LEN:         if (aw_handshake_cdma && w_handshake_cdma) n_state = CDMA_WRITE_LEN_CLR;
            CDMA_WRITE_LEN_CLR:     n_state = CDMA_WAIT;
            CDMA_WAIT:              if (r_handshake_cdma && cdma_axilm_rdata[1]) n_state = IDLE;

            default: n_state = IDLE;
        endcase
    end


    // Register offsets within CDMA peripheral
    localparam logic [31:0] CDMA_CR_OFFSET             = 32'h00000000;
    localparam logic [31:0] CDMA_SR_OFFSET             = 32'h00000004;
    localparam logic [31:0] CDMA_SRC_ADDR_LSB_OFFSET   = 32'h00000018;
    localparam logic [31:0] CDMA_SRC_ADDR_MSB_OFFSET   = 32'h0000001C;
    localparam logic [31:0] CDMA_DST_ADDR_LSB_OFFSET   = 32'h00000020;
    localparam logic [31:0] CDMA_DST_ADDR_MSB_OFFSET   = 32'h00000024;
    localparam logic [31:0] CDMA_LEN_OFFSET            = 32'h00000028;
    localparam int          IOC_IRQ_EN_BIT             = 12;
    localparam int          ERR_IRQ_EN_BIT             = 14;




        // CDMA IO
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cdma_axilm_awvalid <= 1'b0;
            cdma_axilm_wvalid  <= 1'b0;
            cdma_axilm_bready  <= 1'b0;
            cdma_axilm_arvalid <= 1'b0;
            cdma_axilm_rready  <= 1'b0;
            cdma_axilm_awaddr  <= '0;
            cdma_axilm_wdata   <= '0;
            cdma_axilm_wstrb   <= '0;
        end else begin

            case (c_state)
                CDMA_CONFIG: begin
                    cdma_axilm_arvalid <= 1;
                    cdma_axilm_araddr  <= CDMA_BASE_ADDR + CDMA_SR_OFFSET;
                    cdma_axilm_rready  <= 1;
                                    end
                CDMA_ENABLE_IRQ: begin
                    cdma_axilm_awvalid <= 1;
                    cdma_axilm_awaddr  <= CDMA_BASE_ADDR + CDMA_CR_OFFSET;
                    cdma_axilm_wvalid  <= 1;
                    cdma_axilm_wdata   <= (1 << IOC_IRQ_EN_BIT) | (1 << ERR_IRQ_EN_BIT);
                    cdma_axilm_wstrb   <= {C_CDMA_AXILM_DATA_WIDTH/8{1'b1}};
                    cdma_axilm_bready  <= 1;
                end
                CDMA_WRITE_SRC_MSB: begin
                    cdma_axilm_awvalid <= 1;
                    cdma_axilm_awaddr  <= CDMA_BASE_ADDR + CDMA_SRC_ADDR_MSB_OFFSET;
                    cdma_axilm_wvalid  <= 1;
                    cdma_axilm_wdata   <= cdma_src_addr_msb_reg;
                    cdma_axilm_wstrb   <= {C_CDMA_AXILM_DATA_WIDTH/8{1'b1}};
                    cdma_axilm_bready  <= 1;
                end
                CDMA_WRITE_SRC_LSB: begin
                    cdma_axilm_awvalid <= 1;
                    cdma_axilm_awaddr  <= CDMA_BASE_ADDR + CDMA_SRC_ADDR_LSB_OFFSET;
                    cdma_axilm_wvalid  <= 1;
                    cdma_axilm_wdata   <= cdma_src_addr_lsb_reg;
                    cdma_axilm_wstrb   <= {C_CDMA_AXILM_DATA_WIDTH/8{1'b1}};
                    cdma_axilm_bready  <= 1;
                end
                CDMA_WRITE_DST_MSB: begin
                    cdma_axilm_awvalid <= 1;
                    cdma_axilm_awaddr  <= CDMA_BASE_ADDR + CDMA_DST_ADDR_MSB_OFFSET;
                    cdma_axilm_wvalid  <= 1;
                    cdma_axilm_wdata   <= cdma_dst_addr_msb_reg;
                    cdma_axilm_wstrb   <= {C_CDMA_AXILM_DATA_WIDTH/8{1'b1}};
                    cdma_axilm_bready  <= 1;
                end
                CDMA_WRITE_DST_LSB: begin
                    cdma_axilm_awvalid <= 1;
                    cdma_axilm_awaddr  <= CDMA_BASE_ADDR + CDMA_DST_ADDR_LSB_OFFSET;
                    cdma_axilm_wvalid  <= 1;
                    cdma_axilm_wdata   <= cdma_dst_addr_lsb_reg;
                    cdma_axilm_wstrb   <= {C_CDMA_AXILM_DATA_WIDTH/8{1'b1}};
                    cdma_axilm_bready  <= 1;
                end
                CDMA_WRITE_LEN: begin
                    cdma_axilm_awvalid <= 1;
                    cdma_axilm_awaddr  <= CDMA_BASE_ADDR + CDMA_LEN_OFFSET;
                    cdma_axilm_wvalid  <= 1;
                    cdma_axilm_wdata   <= cdma_length_reg;
                    cdma_axilm_wstrb   <= {C_CDMA_AXILM_DATA_WIDTH/8{1'b1}};
                    cdma_axilm_bready  <= 1;
                end
                CDMA_WAIT: begin
                    cdma_axilm_arvalid <= 1;
                    cdma_axilm_araddr  <= CDMA_BASE_ADDR + CDMA_SR_OFFSET;
                    cdma_axilm_rready  <= 1;
                                    end
                default: begin
                    cdma_axilm_awvalid <= 1'b0;
                    cdma_axilm_wvalid  <= 1'b0;
                    cdma_axilm_bready  <= 1'b0;
                    cdma_axilm_arvalid <= 1'b0;
                    cdma_axilm_rready  <= 1'b0;
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cdma_src_addr_msb_reg       <= '0;
            cdma_src_addr_lsb_reg       <= '0;
            cdma_dst_addr_msb_reg       <= '0;
            cdma_dst_addr_lsb_reg       <= '0;
            cdma_length_reg             <= '0;
        end else begin
            if(cdma_config_valid && cdma_config_ready) begin
                cdma_src_addr_msb_reg       <= cdma_src_addr_msb;
                cdma_src_addr_lsb_reg       <= cdma_src_addr_lsb;
                cdma_dst_addr_msb_reg       <= cdma_dst_addr_msb;
                cdma_dst_addr_lsb_reg       <= cdma_dst_addr_lsb;
                cdma_length_reg             <= cdma_length  ;
            end
        end
    end



endmodule