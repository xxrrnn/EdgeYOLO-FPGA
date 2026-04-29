`timescale 1ns / 1ps

module xdma_dcim_bram_ctrl_top #(
    parameter integer AXIL_ADDR_WIDTH = 12,
    parameter integer AXIL_DATA_WIDTH = 32,
    parameter integer BRAM_ADDR_WIDTH = 32,
    parameter integer BRAM_DATA_WIDTH = 256,
    parameter [31:0] GLOBAL_BASE_ADDR = 32'h1000_0000,
    parameter [31:0] LOCAL_BASE_ADDR  = 32'h1001_0000,
    parameter integer DCIM_WD1 = 4,
    parameter integer DCIM_CH_IN = 16,
    parameter integer DCIM_CH_OUT = 16,
    parameter integer DCIM_ACC_MAX = 16
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axil:m_axil_cdma, ASSOCIATED_RESET aresetn" *)
    input  wire                         aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                         aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *)
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *)
    input  wire                         s_axil_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *)
    output reg                          s_axil_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *)
    input  wire [AXIL_DATA_WIDTH-1:0]   s_axil_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *)
    input  wire [(AXIL_DATA_WIDTH/8)-1:0] s_axil_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *)
    input  wire                         s_axil_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *)
    output reg                          s_axil_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *)
    output reg  [1:0]                   s_axil_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *)
    output reg                          s_axil_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *)
    input  wire                         s_axil_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *)
    input  wire [AXIL_ADDR_WIDTH-1:0]   s_axil_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *)
    input  wire                         s_axil_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *)
    output reg                          s_axil_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *)
    output reg  [AXIL_DATA_WIDTH-1:0]   s_axil_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *)
    output reg  [1:0]                   s_axil_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *)
    output reg                          s_axil_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *)
    input  wire                         s_axil_rready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWADDR" *)
    output reg  [31:0]                  m_axil_cdma_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWVALID" *)
    output reg                          m_axil_cdma_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWREADY" *)
    input  wire                         m_axil_cdma_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WDATA" *)
    output reg  [31:0]                  m_axil_cdma_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WSTRB" *)
    output wire [3:0]                   m_axil_cdma_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WVALID" *)
    output reg                          m_axil_cdma_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WREADY" *)
    input  wire                         m_axil_cdma_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BRESP" *)
    input  wire [1:0]                   m_axil_cdma_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BVALID" *)
    input  wire                         m_axil_cdma_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BREADY" *)
    output reg                          m_axil_cdma_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARADDR" *)
    output reg  [31:0]                  m_axil_cdma_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARVALID" *)
    output reg                          m_axil_cdma_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARREADY" *)
    input  wire                         m_axil_cdma_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RDATA" *)
    input  wire [31:0]                  m_axil_cdma_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RRESP" *)
    input  wire [1:0]                   m_axil_cdma_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RVALID" *)
    input  wire                         m_axil_cdma_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RREADY" *)
    output reg                          m_axil_cdma_rready,

    output reg                          local_bram_en,
    output reg  [(BRAM_DATA_WIDTH/8)-1:0] local_bram_we,
    output reg  [BRAM_ADDR_WIDTH-1:0]   local_bram_addr,
    output reg  [BRAM_DATA_WIDTH-1:0]   local_bram_din,
    input  wire [BRAM_DATA_WIDTH-1:0]   local_bram_dout
);

    localparam integer AXIL_STRB_WIDTH = AXIL_DATA_WIDTH / 8;
    localparam integer BRAM_STRB_WIDTH = BRAM_DATA_WIDTH / 8;
    localparam integer WD2 = 2 * DCIM_WD1 + $clog2(DCIM_CH_IN);
    localparam integer WD3 = WD2 + $clog2(DCIM_ACC_MAX);
    localparam integer DCIM_ACT_WIDTH = DCIM_CH_IN * DCIM_WD1;
    localparam integer DCIM_TILE_WIDTH = DCIM_CH_IN * DCIM_CH_OUT * DCIM_WD1;
    localparam integer DCIM_RES_WIDTH = DCIM_CH_OUT * WD3;
    localparam integer RAW_ACT_ROW_BYTES = DCIM_CH_IN;
    localparam integer RAW_ACT_ROWS_PER_WORD = BRAM_DATA_WIDTH / (RAW_ACT_ROW_BYTES * 8);

    localparam [AXIL_ADDR_WIDTH-1:0] REG_CTRL          = 12'h000;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_STATUS        = 12'h004;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_ROWS          = 12'h008;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_MODE          = 12'h00c;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_ACC           = 12'h010;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_G_OP_OFFSET   = 12'h014;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_G_IN_OFFSET   = 12'h018;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_G_OUT_OFFSET  = 12'h01c;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_L_OP_OFFSET   = 12'h020;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_L_IN_OFFSET   = 12'h024;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_L_OUT_OFFSET  = 12'h028;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_OP_BYTES      = 12'h02c;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_ROWS_SENT     = 12'h030;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_ROWS_OUT      = 12'h034;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_ERROR_CODE    = 12'h038;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_DEBUG_STATE   = 12'h03c;
    localparam [AXIL_ADDR_WIDTH-1:0] REG_VERSION       = 12'h040;

    localparam [2:0] MODE_UINT4  = 3'b000;
    localparam [2:0] MODE_UINT8  = 3'b010;
    localparam [2:0] MODE_UINT16 = 3'b011;
    localparam [2:0] MODE_INT4   = 3'b100;
    localparam [2:0] MODE_INT8   = 3'b110;
    localparam [2:0] MODE_INT16  = 3'b111;

    localparam [31:0] CDMA_CR      = 32'h0000_0000;
    localparam [31:0] CDMA_SR      = 32'h0000_0004;
    localparam [31:0] CDMA_SA      = 32'h0000_0018;
    localparam [31:0] CDMA_SA_MSB  = 32'h0000_001c;
    localparam [31:0] CDMA_DA      = 32'h0000_0020;
    localparam [31:0] CDMA_DA_MSB  = 32'h0000_0024;
    localparam [31:0] CDMA_BTT     = 32'h0000_0028;
    localparam [31:0] CDMA_ERR_MASK = 32'h0000_7770;

    localparam [5:0] ST_IDLE            = 6'd0;
    localparam [5:0] ST_CDMA_OP_START   = 6'd1;
    localparam [5:0] ST_CDMA_OP_WAIT    = 6'd2;
    localparam [5:0] ST_CDMA_IN_START   = 6'd3;
    localparam [5:0] ST_CDMA_IN_WAIT    = 6'd4;
    localparam [5:0] ST_LOAD_OP_REQ     = 6'd5;
    localparam [5:0] ST_LOAD_OP_WAIT0   = 6'd6;
    localparam [5:0] ST_LOAD_OP_WAIT1   = 6'd7;
    localparam [5:0] ST_PREP_OP         = 6'd8;
    localparam [5:0] ST_ACT_NEXT        = 6'd9;
    localparam [5:0] ST_ACT_REQ         = 6'd10;
    localparam [5:0] ST_ACT_WAIT0       = 6'd11;
    localparam [5:0] ST_ACT_WAIT1       = 6'd12;
    localparam [5:0] ST_ACT_SEND        = 6'd13;
    localparam [5:0] ST_DRAIN           = 6'd14;
    localparam [5:0] ST_CDMA_OUT_START  = 6'd15;
    localparam [5:0] ST_CDMA_OUT_WAIT   = 6'd16;
    localparam [5:0] ST_DONE            = 6'd17;
    localparam [5:0] ST_ERROR           = 6'd18;

    reg [5:0] state;
    wire busy = (state != ST_IDLE) && (state != ST_DONE) && (state != ST_ERROR);
    wire config_writable = (state == ST_IDLE) || (state == ST_DONE) || (state == ST_ERROR);

    reg [31:0] rows_reg;
    reg [2:0] mode_reg;
    reg [4:0] acc_reg;
    reg [31:0] g_op_offset_reg;
    reg [31:0] g_in_offset_reg;
    reg [31:0] g_out_offset_reg;
    reg [31:0] l_op_offset_reg;
    reg [31:0] l_in_offset_reg;
    reg [31:0] l_out_offset_reg;
    reg [31:0] op_bytes_reg;
    reg [31:0] rows_sent_reg;
    reg [31:0] rows_out_reg;
    reg [31:0] expected_out_rows_reg;
    reg [31:0] error_code_reg;
    reg done_reg;
    reg start_pulse;

    reg [AXIL_ADDR_WIDTH-1:0] awaddr_reg;
    reg awaddr_valid_reg;
    reg [31:0] wdata_reg;
    reg [3:0] wstrb_reg;
    reg wdata_valid_reg;

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  wstrb;
        integer b;
        begin
            apply_wstrb = old_value;
            for (b = 0; b < 4; b = b + 1) begin
                if (wstrb[b]) begin
                    apply_wstrb[b*8 +: 8] = new_value[b*8 +: 8];
                end
            end
        end
    endfunction

    function [31:0] mode_group;
        input [2:0] mode;
        begin
            if ((mode == MODE_UINT8) || (mode == MODE_INT8)) begin
                mode_group = 32'd2;
            end else if ((mode == MODE_UINT16) || (mode == MODE_INT16)) begin
                mode_group = 32'd4;
            end else begin
                mode_group = 32'd1;
            end
        end
    endfunction

    function valid_mode;
        input [2:0] mode;
        begin
            valid_mode = (mode == MODE_UINT4) || (mode == MODE_INT4) ||
                         (mode == MODE_UINT8) || (mode == MODE_INT8) ||
                         (mode == MODE_UINT16) || (mode == MODE_INT16);
        end
    endfunction

    wire [31:0] group_rows = (acc_reg == 5'd0) ? 32'd1 : {27'd0, acc_reg};
    wire [31:0] computed_out_rows = (group_rows == 32'd0) ? 32'd0 : (rows_reg / group_rows);
    wire [31:0] input_bytes = rows_reg << 4;
    wire [31:0] output_bytes = expected_out_rows_reg << 5;

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axil_awready <= 1'b0;
            s_axil_wready <= 1'b0;
            s_axil_bresp <= 2'b00;
            s_axil_bvalid <= 1'b0;
            s_axil_arready <= 1'b0;
            s_axil_rdata <= 32'd0;
            s_axil_rresp <= 2'b00;
            s_axil_rvalid <= 1'b0;
            awaddr_reg <= {AXIL_ADDR_WIDTH{1'b0}};
            awaddr_valid_reg <= 1'b0;
            wdata_reg <= 32'd0;
            wstrb_reg <= 4'd0;
            wdata_valid_reg <= 1'b0;
            rows_reg <= 32'd0;
            mode_reg <= MODE_INT8;
            acc_reg <= 5'd0;
            g_op_offset_reg <= 32'd0;
            g_in_offset_reg <= 32'd1024;
            g_out_offset_reg <= 32'd4096;
            l_op_offset_reg <= 32'd0;
            l_in_offset_reg <= 32'd1024;
            l_out_offset_reg <= 32'd4096;
            op_bytes_reg <= 32'd128;
            start_pulse <= 1'b0;
        end else begin
            s_axil_awready <= 1'b0;
            s_axil_wready <= 1'b0;
            s_axil_arready <= 1'b0;
            start_pulse <= 1'b0;

            if (s_axil_bvalid && s_axil_bready) begin
                s_axil_bvalid <= 1'b0;
            end
            if (s_axil_rvalid && s_axil_rready) begin
                s_axil_rvalid <= 1'b0;
            end

            if (!awaddr_valid_reg && !s_axil_bvalid && s_axil_awvalid) begin
                s_axil_awready <= 1'b1;
                awaddr_reg <= s_axil_awaddr;
                awaddr_valid_reg <= 1'b1;
            end
            if (!wdata_valid_reg && !s_axil_bvalid && s_axil_wvalid) begin
                s_axil_wready <= 1'b1;
                wdata_reg <= s_axil_wdata;
                wstrb_reg <= s_axil_wstrb;
                wdata_valid_reg <= 1'b1;
            end

            if (awaddr_valid_reg && wdata_valid_reg && !s_axil_bvalid) begin
                s_axil_bvalid <= 1'b1;
                s_axil_bresp <= 2'b00;
                awaddr_valid_reg <= 1'b0;
                wdata_valid_reg <= 1'b0;
                case (awaddr_reg)
                    REG_CTRL: begin
                        if (wdata_reg[0]) begin
                            start_pulse <= 1'b1;
                        end
                    end
                    REG_ROWS: begin
                        if (config_writable) rows_reg <= apply_wstrb(rows_reg, wdata_reg, wstrb_reg);
                    end
                    REG_MODE: begin
                        if (config_writable && wstrb_reg[0]) mode_reg <= wdata_reg[2:0];
                    end
                    REG_ACC: begin
                        if (config_writable && wstrb_reg[0]) acc_reg <= wdata_reg[4:0];
                    end
                    REG_G_OP_OFFSET: begin
                        if (config_writable) g_op_offset_reg <= apply_wstrb(g_op_offset_reg, wdata_reg, wstrb_reg);
                    end
                    REG_G_IN_OFFSET: begin
                        if (config_writable) g_in_offset_reg <= apply_wstrb(g_in_offset_reg, wdata_reg, wstrb_reg);
                    end
                    REG_G_OUT_OFFSET: begin
                        if (config_writable) g_out_offset_reg <= apply_wstrb(g_out_offset_reg, wdata_reg, wstrb_reg);
                    end
                    REG_L_OP_OFFSET: begin
                        if (config_writable) l_op_offset_reg <= apply_wstrb(l_op_offset_reg, wdata_reg, wstrb_reg);
                    end
                    REG_L_IN_OFFSET: begin
                        if (config_writable) l_in_offset_reg <= apply_wstrb(l_in_offset_reg, wdata_reg, wstrb_reg);
                    end
                    REG_L_OUT_OFFSET: begin
                        if (config_writable) l_out_offset_reg <= apply_wstrb(l_out_offset_reg, wdata_reg, wstrb_reg);
                    end
                    REG_OP_BYTES: begin
                        if (config_writable) op_bytes_reg <= apply_wstrb(op_bytes_reg, wdata_reg, wstrb_reg);
                    end
                    default: begin
                    end
                endcase
            end

            if (!s_axil_rvalid && s_axil_arvalid) begin
                s_axil_arready <= 1'b1;
                s_axil_rvalid <= 1'b1;
                s_axil_rresp <= 2'b00;
                case (s_axil_araddr)
                    REG_CTRL:         s_axil_rdata <= 32'd0;
                    REG_STATUS:       s_axil_rdata <= {28'd0, cdma_busy, (error_code_reg != 32'd0), done_reg, busy};
                    REG_ROWS:         s_axil_rdata <= rows_reg;
                    REG_MODE:         s_axil_rdata <= {29'd0, mode_reg};
                    REG_ACC:          s_axil_rdata <= {27'd0, acc_reg};
                    REG_G_OP_OFFSET:  s_axil_rdata <= g_op_offset_reg;
                    REG_G_IN_OFFSET:  s_axil_rdata <= g_in_offset_reg;
                    REG_G_OUT_OFFSET: s_axil_rdata <= g_out_offset_reg;
                    REG_L_OP_OFFSET:  s_axil_rdata <= l_op_offset_reg;
                    REG_L_IN_OFFSET:  s_axil_rdata <= l_in_offset_reg;
                    REG_L_OUT_OFFSET: s_axil_rdata <= l_out_offset_reg;
                    REG_OP_BYTES:     s_axil_rdata <= op_bytes_reg;
                    REG_ROWS_SENT:    s_axil_rdata <= rows_sent_reg;
                    REG_ROWS_OUT:     s_axil_rdata <= rows_out_reg;
                    REG_ERROR_CODE:   s_axil_rdata <= error_code_reg;
                    REG_DEBUG_STATE:  s_axil_rdata <= {26'd0, state};
                    REG_VERSION:      s_axil_rdata <= 32'h4443_494d;
                    default:          s_axil_rdata <= 32'd0;
                endcase
            end
        end
    end

    localparam [2:0] AXILM_IDLE  = 3'd0;
    localparam [2:0] AXILM_WRITE = 3'd1;
    localparam [2:0] AXILM_WRESP = 3'd2;
    localparam [2:0] AXILM_READ  = 3'd3;
    localparam [2:0] AXILM_RRESP = 3'd4;

    reg [2:0] axilm_state;
    reg axilm_start;
    reg axilm_write;
    reg [31:0] axilm_addr;
    reg [31:0] axilm_wdata;
    reg axilm_done;
    reg axilm_error;
    reg [31:0] axilm_rdata;
    assign m_axil_cdma_wstrb = 4'hf;

    always @(posedge aclk) begin
        if (!aresetn) begin
            axilm_state <= AXILM_IDLE;
            m_axil_cdma_awaddr <= 32'd0;
            m_axil_cdma_awvalid <= 1'b0;
            m_axil_cdma_wdata <= 32'd0;
            m_axil_cdma_wvalid <= 1'b0;
            m_axil_cdma_bready <= 1'b0;
            m_axil_cdma_araddr <= 32'd0;
            m_axil_cdma_arvalid <= 1'b0;
            m_axil_cdma_rready <= 1'b0;
            axilm_done <= 1'b0;
            axilm_error <= 1'b0;
            axilm_rdata <= 32'd0;
        end else begin
            axilm_done <= 1'b0;
            axilm_error <= 1'b0;
            case (axilm_state)
                AXILM_IDLE: begin
                    m_axil_cdma_bready <= 1'b0;
                    m_axil_cdma_rready <= 1'b0;
                    if (axilm_start && axilm_write) begin
                        m_axil_cdma_awaddr <= axilm_addr;
                        m_axil_cdma_wdata <= axilm_wdata;
                        m_axil_cdma_awvalid <= 1'b1;
                        m_axil_cdma_wvalid <= 1'b1;
                        axilm_state <= AXILM_WRITE;
                    end else if (axilm_start) begin
                        m_axil_cdma_araddr <= axilm_addr;
                        m_axil_cdma_arvalid <= 1'b1;
                        axilm_state <= AXILM_READ;
                    end
                end
                AXILM_WRITE: begin
                    if (m_axil_cdma_awvalid && m_axil_cdma_awready) begin
                        m_axil_cdma_awvalid <= 1'b0;
                    end
                    if (m_axil_cdma_wvalid && m_axil_cdma_wready) begin
                        m_axil_cdma_wvalid <= 1'b0;
                    end
                    if ((!m_axil_cdma_awvalid || m_axil_cdma_awready) &&
                        (!m_axil_cdma_wvalid || m_axil_cdma_wready)) begin
                        m_axil_cdma_bready <= 1'b1;
                        axilm_state <= AXILM_WRESP;
                    end
                end
                AXILM_WRESP: begin
                    if (m_axil_cdma_bvalid) begin
                        m_axil_cdma_bready <= 1'b0;
                        axilm_error <= (m_axil_cdma_bresp != 2'b00);
                        axilm_done <= 1'b1;
                        axilm_state <= AXILM_IDLE;
                    end
                end
                AXILM_READ: begin
                    if (m_axil_cdma_arvalid && m_axil_cdma_arready) begin
                        m_axil_cdma_arvalid <= 1'b0;
                        m_axil_cdma_rready <= 1'b1;
                        axilm_state <= AXILM_RRESP;
                    end
                end
                AXILM_RRESP: begin
                    if (m_axil_cdma_rvalid) begin
                        m_axil_cdma_rready <= 1'b0;
                        axilm_rdata <= m_axil_cdma_rdata;
                        axilm_error <= (m_axil_cdma_rresp != 2'b00);
                        axilm_done <= 1'b1;
                        axilm_state <= AXILM_IDLE;
                    end
                end
                default: begin
                    axilm_state <= AXILM_IDLE;
                end
            endcase
        end
    end

    localparam [3:0] CDMA_IDLE      = 4'd0;
    localparam [3:0] CDMA_WRITE_CR  = 4'd1;
    localparam [3:0] CDMA_WRITE_SA  = 4'd2;
    localparam [3:0] CDMA_WRITE_SAH = 4'd3;
    localparam [3:0] CDMA_WRITE_DA  = 4'd4;
    localparam [3:0] CDMA_WRITE_DAH = 4'd5;
    localparam [3:0] CDMA_WRITE_BTT = 4'd6;
    localparam [3:0] CDMA_WAIT_BTT  = 4'd7;
    localparam [3:0] CDMA_POLL_SR   = 4'd8;
    localparam [3:0] CDMA_CLEAR_SR  = 4'd9;

    reg [3:0] cdma_state;
    reg cdma_start;
    reg [31:0] cdma_src_addr;
    reg [31:0] cdma_dst_addr;
    reg [31:0] cdma_btt;
    reg cdma_busy;
    reg cdma_done;
    reg cdma_error;
    reg [31:0] cdma_status_reg;

    always @(posedge aclk) begin
        if (!aresetn) begin
            cdma_state <= CDMA_IDLE;
            cdma_busy <= 1'b0;
            cdma_done <= 1'b0;
            cdma_error <= 1'b0;
            cdma_status_reg <= 32'd0;
            axilm_start <= 1'b0;
            axilm_write <= 1'b0;
            axilm_addr <= 32'd0;
            axilm_wdata <= 32'd0;
        end else begin
            cdma_done <= 1'b0;
            axilm_start <= 1'b0;
            case (cdma_state)
                CDMA_IDLE: begin
                    cdma_busy <= 1'b0;
                    cdma_error <= 1'b0;
                    if (cdma_start && (cdma_btt != 32'd0)) begin
                        cdma_busy <= 1'b1;
                        cdma_state <= CDMA_WRITE_CR;
                    end
                end
                CDMA_WRITE_CR: begin
                    if (axilm_state == AXILM_IDLE && !axilm_done) begin
                        axilm_start <= 1'b1;
                        axilm_write <= 1'b1;
                        axilm_addr <= CDMA_CR;
                        axilm_wdata <= 32'h0000_0001;
                        cdma_state <= CDMA_WRITE_SA;
                    end
                end
                CDMA_WRITE_SA: begin
                    if (axilm_done) begin
                        if (axilm_error) begin
                            cdma_error <= 1'b1;
                            cdma_state <= CDMA_IDLE;
                            cdma_done <= 1'b1;
                        end else begin
                            axilm_start <= 1'b1;
                            axilm_write <= 1'b1;
                            axilm_addr <= CDMA_SA;
                            axilm_wdata <= cdma_src_addr;
                            cdma_state <= CDMA_WRITE_SAH;
                        end
                    end
                end
                CDMA_WRITE_SAH: begin
                    if (axilm_done) begin
                        if (axilm_error) begin
                            cdma_error <= 1'b1;
                            cdma_state <= CDMA_IDLE;
                            cdma_done <= 1'b1;
                        end else begin
                            axilm_start <= 1'b1;
                            axilm_write <= 1'b1;
                            axilm_addr <= CDMA_SA_MSB;
                            axilm_wdata <= 32'd0;
                            cdma_state <= CDMA_WRITE_DA;
                        end
                    end
                end
                CDMA_WRITE_DA: begin
                    if (axilm_done) begin
                        if (axilm_error) begin
                            cdma_error <= 1'b1;
                            cdma_state <= CDMA_IDLE;
                            cdma_done <= 1'b1;
                        end else begin
                            axilm_start <= 1'b1;
                            axilm_write <= 1'b1;
                            axilm_addr <= CDMA_DA;
                            axilm_wdata <= cdma_dst_addr;
                            cdma_state <= CDMA_WRITE_DAH;
                        end
                    end
                end
                CDMA_WRITE_DAH: begin
                    if (axilm_done) begin
                        if (axilm_error) begin
                            cdma_error <= 1'b1;
                            cdma_state <= CDMA_IDLE;
                            cdma_done <= 1'b1;
                        end else begin
                            axilm_start <= 1'b1;
                            axilm_write <= 1'b1;
                            axilm_addr <= CDMA_DA_MSB;
                            axilm_wdata <= 32'd0;
                            cdma_state <= CDMA_WRITE_BTT;
                        end
                    end
                end
                CDMA_WRITE_BTT: begin
                    if (axilm_done) begin
                        if (axilm_error) begin
                            cdma_error <= 1'b1;
                            cdma_state <= CDMA_IDLE;
                            cdma_done <= 1'b1;
                        end else begin
                            axilm_start <= 1'b1;
                            axilm_write <= 1'b1;
                            axilm_addr <= CDMA_BTT;
                            axilm_wdata <= cdma_btt;
                            cdma_state <= CDMA_WAIT_BTT;
                        end
                    end
                end
                CDMA_WAIT_BTT: begin
                    if (axilm_done) begin
                        if (axilm_error) begin
                            cdma_error <= 1'b1;
                            cdma_state <= CDMA_IDLE;
                            cdma_done <= 1'b1;
                        end else begin
                            cdma_state <= CDMA_POLL_SR;
                        end
                    end
                end
                CDMA_POLL_SR: begin
                    if (axilm_done) begin
                        if (axilm_error) begin
                            cdma_error <= 1'b1;
                            cdma_state <= CDMA_IDLE;
                            cdma_done <= 1'b1;
                        end else begin
                            axilm_start <= 1'b1;
                            axilm_write <= 1'b0;
                            axilm_addr <= CDMA_SR;
                            cdma_status_reg <= axilm_rdata;
                            if ((axilm_rdata & CDMA_ERR_MASK) != 32'd0) begin
                                cdma_error <= 1'b1;
                                cdma_state <= CDMA_IDLE;
                                cdma_done <= 1'b1;
                            end else if (axilm_rdata[1] || axilm_rdata[12]) begin
                                cdma_state <= CDMA_CLEAR_SR;
                            end
                        end
                    end else if (axilm_state == AXILM_IDLE && !axilm_start) begin
                        axilm_start <= 1'b1;
                        axilm_write <= 1'b0;
                        axilm_addr <= CDMA_SR;
                    end
                end
                CDMA_CLEAR_SR: begin
                    if (axilm_done) begin
                        cdma_state <= CDMA_IDLE;
                        cdma_busy <= 1'b0;
                        cdma_done <= 1'b1;
                    end else if (axilm_state == AXILM_IDLE && !axilm_start) begin
                        axilm_start <= 1'b1;
                        axilm_write <= 1'b1;
                        axilm_addr <= CDMA_SR;
                        axilm_wdata <= 32'h0000_1000;
                    end
                end
                default: begin
                    cdma_state <= CDMA_IDLE;
                end
            endcase
        end
    end

    reg dcim_clr;
    reg dcim_act_valid;
    wire dcim_act_ready;
    reg [DCIM_ACT_WIDTH-1:0] dcim_act_data;
    wire dcim_mid_valid;
    wire dcim_mid_ready;
    wire [DCIM_CH_OUT*WD2-1:0] dcim_mid_data;
    wire dcim_res_valid;
    wire dcim_res_ready;
    wire [DCIM_RES_WIDTH-1:0] dcim_res_data;
    reg [DCIM_TILE_WIDTH-1:0] op_tile_reg;
    reg [DCIM_TILE_WIDTH-1:0] raw_op_tile_reg;
    reg [31:0] op_word_idx;
    reg [31:0] act_word_idx;
    reg act_row_sel;
    reg act_slice_sel;
    reg [BRAM_DATA_WIDTH-1:0] raw_act_word_reg;
    wire [DCIM_TILE_WIDTH-1:0] preprocessed_op_tile;
    wire [DCIM_ACT_WIDTH-1:0] preprocessed_act_high;
    wire [DCIM_ACT_WIDTH-1:0] preprocessed_act_low;
    wire [BRAM_DATA_WIDTH-1:0] preprocess_act_word;

    assign preprocess_act_word = (state == ST_ACT_WAIT1) ? local_bram_dout : raw_act_word_reg;

    xdma_dcim_preprocess #(
        .CH_IN(DCIM_CH_IN),
        .INT8_OUT_COLS(DCIM_CH_OUT / 2),
        .RAW_ACT_WORD_WIDTH(BRAM_DATA_WIDTH),
        .RAW_WEIGHT_WIDTH(DCIM_TILE_WIDTH),
        .DCIM_ACT_WIDTH(DCIM_ACT_WIDTH),
        .DCIM_WEIGHT_WIDTH(DCIM_TILE_WIDTH)
    ) u_preprocess (
        .raw_weight_i(raw_op_tile_reg),
        .dcim_weight_o(preprocessed_op_tile),
        .raw_act_word_i(preprocess_act_word),
        .raw_act_row_sel_i(act_row_sel),
        .dcim_act_high_o(preprocessed_act_high),
        .dcim_act_low_o(preprocessed_act_low)
    );

    calculate_core #(
        .WD1(DCIM_WD1),
        .CH_IN(DCIM_CH_IN),
        .CH_OUT(DCIM_CH_OUT)
    ) u_calculate_core (
        .clk(aclk),
        .rstn(aresetn),
        .clr(dcim_clr),
        .ena(1'b1),
        .mode(mode_reg),
        .up_valid(dcim_act_valid),
        .up_ready(dcim_act_ready),
        .dn_valid(dcim_mid_valid),
        .dn_ready(dcim_mid_ready),
        .up_data1(dcim_act_data),
        .up_data2(op_tile_reg),
        .dn_data(dcim_mid_data)
    );

    postProcess #(
        .WD1(DCIM_WD1),
        .CH_IN(DCIM_CH_IN),
        .CH_OUT(DCIM_CH_OUT),
        .ACC(DCIM_ACC_MAX)
    ) u_post_process (
        .clk(aclk),
        .rstn(aresetn),
        .clr(dcim_clr),
        .ena(1'b1),
        .mode(mode_reg),
        .acc(acc_reg),
        .up_valid(dcim_mid_valid),
        .up_ready(dcim_mid_ready),
        .dn_valid(dcim_res_valid),
        .dn_ready(dcim_res_ready),
        .up_data(dcim_mid_data),
        .dn_data(dcim_res_data)
    );

    assign dcim_res_ready = ((state == ST_ACT_NEXT) || (state == ST_ACT_SEND) || (state == ST_DRAIN)) &&
                            (rows_out_reg < expected_out_rows_reg);

    wire dcim_result_fire = dcim_res_valid && dcim_res_ready;
    wire dcim_act_fire = dcim_act_valid && dcim_act_ready;

    always @(posedge aclk) begin
        if (!aresetn) begin
            state <= ST_IDLE;
            local_bram_en <= 1'b0;
            local_bram_we <= {BRAM_STRB_WIDTH{1'b0}};
            local_bram_addr <= {BRAM_ADDR_WIDTH{1'b0}};
            local_bram_din <= {BRAM_DATA_WIDTH{1'b0}};
            rows_sent_reg <= 32'd0;
            rows_out_reg <= 32'd0;
            expected_out_rows_reg <= 32'd0;
            error_code_reg <= 32'd0;
            done_reg <= 1'b0;
            cdma_start <= 1'b0;
            cdma_src_addr <= 32'd0;
            cdma_dst_addr <= 32'd0;
            cdma_btt <= 32'd0;
            dcim_clr <= 1'b0;
            dcim_act_valid <= 1'b0;
            dcim_act_data <= {DCIM_ACT_WIDTH{1'b0}};
            op_tile_reg <= {DCIM_TILE_WIDTH{1'b0}};
            raw_op_tile_reg <= {DCIM_TILE_WIDTH{1'b0}};
            op_word_idx <= 32'd0;
            act_word_idx <= 32'd0;
            act_row_sel <= 1'b0;
            act_slice_sel <= 1'b0;
            raw_act_word_reg <= {BRAM_DATA_WIDTH{1'b0}};
        end else begin
            local_bram_en <= 1'b0;
            local_bram_we <= {BRAM_STRB_WIDTH{1'b0}};
            local_bram_din <= {BRAM_DATA_WIDTH{1'b0}};
            cdma_start <= 1'b0;
            dcim_clr <= 1'b0;

            case (state)
                ST_IDLE: begin
                    dcim_act_valid <= 1'b0;
                    if (start_pulse) begin
                        done_reg <= 1'b0;
                        error_code_reg <= 32'd0;
                        rows_sent_reg <= 32'd0;
                        rows_out_reg <= 32'd0;
                        expected_out_rows_reg <= computed_out_rows;
                        op_word_idx <= 32'd0;
                        dcim_clr <= 1'b1;
                        if (!valid_mode(mode_reg)) begin
                            error_code_reg <= 32'h0000_0001;
                            state <= ST_ERROR;
                        end else if (rows_reg == 32'd0) begin
                            error_code_reg <= 32'h0000_0002;
                            state <= ST_ERROR;
                        end else if (mode_reg != MODE_INT8) begin
                            error_code_reg <= 32'h0000_0006;
                            state <= ST_ERROR;
                        end else if (op_bytes_reg != 32'd128) begin
                            error_code_reg <= 32'h0000_0003;
                            state <= ST_ERROR;
                        end else if ((rows_reg % group_rows) != 32'd0) begin
                            error_code_reg <= 32'h0000_0004;
                            state <= ST_ERROR;
                        end else if ((g_op_offset_reg[4:0] != 5'd0) || (g_in_offset_reg[4:0] != 5'd0) ||
                                     (g_out_offset_reg[4:0] != 5'd0) || (l_op_offset_reg[4:0] != 5'd0) ||
                                     (l_in_offset_reg[4:0] != 5'd0) || (l_out_offset_reg[4:0] != 5'd0)) begin
                            error_code_reg <= 32'h0000_0005;
                            state <= ST_ERROR;
                        end else begin
                            state <= ST_CDMA_OP_START;
                        end
                    end
                end

                ST_CDMA_OP_START: begin
                    if (!cdma_busy) begin
                        cdma_src_addr <= GLOBAL_BASE_ADDR + g_op_offset_reg;
                        cdma_dst_addr <= LOCAL_BASE_ADDR + l_op_offset_reg;
                        cdma_btt <= op_bytes_reg;
                        cdma_start <= 1'b1;
                        state <= ST_CDMA_OP_WAIT;
                    end
                end

                ST_CDMA_OP_WAIT: begin
                    if (cdma_done) begin
                        if (cdma_error) begin
                            error_code_reg <= 32'h0000_0010 | {16'd0, cdma_status_reg[15:0]};
                            state <= ST_ERROR;
                        end else begin
                            state <= ST_CDMA_IN_START;
                        end
                    end
                end

                ST_CDMA_IN_START: begin
                    if (!cdma_busy) begin
                        cdma_src_addr <= GLOBAL_BASE_ADDR + g_in_offset_reg;
                        cdma_dst_addr <= LOCAL_BASE_ADDR + l_in_offset_reg;
                        cdma_btt <= input_bytes;
                        cdma_start <= 1'b1;
                        state <= ST_CDMA_IN_WAIT;
                    end
                end

                ST_CDMA_IN_WAIT: begin
                    if (cdma_done) begin
                        if (cdma_error) begin
                            error_code_reg <= 32'h0000_0020 | {16'd0, cdma_status_reg[15:0]};
                            state <= ST_ERROR;
                        end else begin
                            op_word_idx <= 32'd0;
                            state <= ST_LOAD_OP_REQ;
                        end
                    end
                end

                ST_LOAD_OP_REQ: begin
                    local_bram_en <= 1'b1;
                    local_bram_we <= {BRAM_STRB_WIDTH{1'b0}};
                    local_bram_addr <= l_op_offset_reg + (op_word_idx << 5);
                    state <= ST_LOAD_OP_WAIT0;
                end

                ST_LOAD_OP_WAIT0: begin
                    local_bram_en <= 1'b1;
                    local_bram_we <= {BRAM_STRB_WIDTH{1'b0}};
                    local_bram_addr <= l_op_offset_reg + (op_word_idx << 5);
                    state <= ST_LOAD_OP_WAIT1;
                end

                ST_LOAD_OP_WAIT1: begin
                    raw_op_tile_reg[op_word_idx*BRAM_DATA_WIDTH +: BRAM_DATA_WIDTH] <= local_bram_dout;
                    if (op_word_idx == 32'd3) begin
                        state <= ST_PREP_OP;
                    end else begin
                        op_word_idx <= op_word_idx + 1'b1;
                        state <= ST_LOAD_OP_REQ;
                    end
                end

                ST_PREP_OP: begin
                    op_tile_reg <= preprocessed_op_tile;
                    rows_sent_reg <= 32'd0;
                    rows_out_reg <= 32'd0;
                    dcim_clr <= 1'b1;
                    state <= ST_ACT_NEXT;
                end

                ST_ACT_NEXT: begin
                    if (dcim_result_fire) begin
                        local_bram_en <= 1'b1;
                        local_bram_we <= {BRAM_STRB_WIDTH{1'b1}};
                        local_bram_addr <= l_out_offset_reg + (rows_out_reg << 5);
                        local_bram_din <= dcim_res_data;
                        rows_out_reg <= rows_out_reg + 1'b1;
                    end else if (rows_sent_reg < rows_reg) begin
                        act_word_idx <= rows_sent_reg >> 1;
                        act_row_sel <= rows_sent_reg[0];
                        state <= ST_ACT_REQ;
                    end else begin
                        state <= ST_DRAIN;
                    end
                end

                ST_ACT_REQ: begin
                    local_bram_en <= 1'b1;
                    local_bram_we <= {BRAM_STRB_WIDTH{1'b0}};
                    local_bram_addr <= l_in_offset_reg + (act_word_idx << 5);
                    state <= ST_ACT_WAIT0;
                end

                ST_ACT_WAIT0: begin
                    local_bram_en <= 1'b1;
                    local_bram_we <= {BRAM_STRB_WIDTH{1'b0}};
                    local_bram_addr <= l_in_offset_reg + (act_word_idx << 5);
                    state <= ST_ACT_WAIT1;
                end

                ST_ACT_WAIT1: begin
                    raw_act_word_reg <= local_bram_dout;
                    act_slice_sel <= 1'b0;
                    dcim_act_data <= preprocessed_act_high;
                    dcim_act_valid <= 1'b1;
                    state <= ST_ACT_SEND;
                end

                ST_ACT_SEND: begin
                    if (dcim_result_fire) begin
                        local_bram_en <= 1'b1;
                        local_bram_we <= {BRAM_STRB_WIDTH{1'b1}};
                        local_bram_addr <= l_out_offset_reg + (rows_out_reg << 5);
                        local_bram_din <= dcim_res_data;
                        rows_out_reg <= rows_out_reg + 1'b1;
                    end
                    if (dcim_act_fire) begin
                        if (!act_slice_sel) begin
                            dcim_act_data <= preprocessed_act_low;
                            act_slice_sel <= 1'b1;
                        end else begin
                            dcim_act_valid <= 1'b0;
                            rows_sent_reg <= rows_sent_reg + 1'b1;
                            state <= ST_ACT_NEXT;
                        end
                    end
                end

                ST_DRAIN: begin
                    if (dcim_result_fire) begin
                        local_bram_en <= 1'b1;
                        local_bram_we <= {BRAM_STRB_WIDTH{1'b1}};
                        local_bram_addr <= l_out_offset_reg + (rows_out_reg << 5);
                        local_bram_din <= dcim_res_data;
                        rows_out_reg <= rows_out_reg + 1'b1;
                    end else if (rows_out_reg >= expected_out_rows_reg) begin
                        state <= ST_CDMA_OUT_START;
                    end
                end

                ST_CDMA_OUT_START: begin
                    if (!cdma_busy) begin
                        cdma_src_addr <= LOCAL_BASE_ADDR + l_out_offset_reg;
                        cdma_dst_addr <= GLOBAL_BASE_ADDR + g_out_offset_reg;
                        cdma_btt <= output_bytes;
                        cdma_start <= 1'b1;
                        state <= ST_CDMA_OUT_WAIT;
                    end
                end

                ST_CDMA_OUT_WAIT: begin
                    if (cdma_done) begin
                        if (cdma_error) begin
                            error_code_reg <= 32'h0000_0030 | {16'd0, cdma_status_reg[15:0]};
                            state <= ST_ERROR;
                        end else begin
                            done_reg <= 1'b1;
                            state <= ST_DONE;
                        end
                    end
                end

                ST_DONE: begin
                    dcim_act_valid <= 1'b0;
                    if (start_pulse) begin
                        done_reg <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                ST_ERROR: begin
                    dcim_act_valid <= 1'b0;
                    done_reg <= 1'b1;
                    if (start_pulse) begin
                        done_reg <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
