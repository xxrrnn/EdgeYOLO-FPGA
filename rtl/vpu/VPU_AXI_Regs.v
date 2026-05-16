`timescale 1ns / 1ps
//==============================================================================
// VPU_AXI_Regs - AXI-Lite Slave 寄存器模块
//==============================================================================
// 功能：为 INST_Decoder 提供 AXI-Lite 控制接口
// 
// 架构说明：
//   - 旧架构：软件通过此模块直接控制VPU（已废弃）
//   - 新架构：只用于控制INST_Decoder，VPU由Decoder直接控制
//
// 寄存器映射（字节地址，4字节对齐）：
//   === VPU状态读取（保留用于兼容性）===
//   0x00: CTRL       - [0] start (保留，未使用)
//   0x04: STATUS     - [0] ready (RO, 来自VPU)
//   
//   === INST_Decoder 控制寄存器 ===
//   0x38: DECODER_CTRL   - [0] start (写1启动解码器，产生上升沿)
//   0x3C: INST_COUNT     - 指令总数（32位字数）
//   0x40: DECODER_STATUS - [0] busy, [1] done, [31] error
//
// 注意：
//   - 0x08-0x34 的VPU配置寄存器已废弃，由INST_Decoder直接控制VPU
//   - 软件只需通过 DECODER_CTRL 启动指令序列执行
//==============================================================================

module VPU_AXI_Regs #(
    parameter AXI_ADDR_WIDTH = 8,
    parameter AXI_DATA_WIDTH = 32,
    parameter ADDR_WIDTH     = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // AXI-Lite Slave Interface
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                    s_axi_awprot,
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,

    input  wire [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]   s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,

    output reg  [1:0]                    s_axi_bresp,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,

    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                    s_axi_arprot,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,

    output reg  [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                    s_axi_rresp,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready,

    // VPU 状态输入（只读）
    input  wire                          ready,
    
    // INST_Decoder 控制接口
    output reg                           decoder_start,      // 启动解码器
    output reg  [ADDR_WIDTH-1:0]         inst_count,         // 指令总数（32位字数）
    input  wire                          decoder_busy,       // 解码器忙
    input  wire                          decoder_done,       // 解码完成
    input  wire [ADDR_WIDTH-1:0]         decoder_status      // 解码器状态
);

    // 寄存器地址（字节地址）
    localparam [7:0] ADDR_STATUS         = 8'h04;  // VPU ready状态
    // 0x08-0x34: VPU配置寄存器（已废弃，由INST_Decoder控制）
    localparam [7:0] ADDR_DECODER_CTRL   = 8'h38;  // INST_Decoder启动
    localparam [7:0] ADDR_INST_COUNT     = 8'h3C;  // 指令数量
    localparam [7:0] ADDR_DECODER_STATUS = 8'h40;  // 解码器状态

    // AXI-Lite 写通道
    reg [AXI_ADDR_WIDTH-1:0] aw_addr_reg;
    reg aw_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            aw_en <= 1'b1;
            aw_addr_reg <= 0;
        end else begin
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                aw_en <= 1'b0;
                aw_addr_reg <= s_axi_awaddr;
            end else if (s_axi_bready && s_axi_bvalid) begin
                aw_en <= 1'b1;
                s_axi_awready <= 1'b0;
            end else begin
                s_axi_awready <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_wready <= 1'b0;
        end else begin
            if (~s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end
        end
    end

    // 寄存器写逻辑
    wire wr_en = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;
    
    // INST_Decoder 控制寄存器
    reg decoder_start_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // INST_Decoder 控制寄存器
            decoder_start_reg    <= 1'b0;
            decoder_start        <= 1'b0;
            inst_count           <= 0;
        end else begin
            // INST_Decoder：直接输出电平，由 INST_Decoder 内部做上升沿检测
            decoder_start <= decoder_start_reg;

            if (wr_en) begin
                case (aw_addr_reg[7:0])
                    // INST_Decoder 寄存器
                    ADDR_DECODER_CTRL: begin
                        if (s_axi_wstrb[0])
                            decoder_start_reg <= s_axi_wdata[0];
                    end
                    ADDR_INST_COUNT:  inst_count  <= s_axi_wdata[ADDR_WIDTH-1:0];
                    default: ;
                endcase
            end
        end
    end

    // 写响应
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else begin
            if (s_axi_awready && s_axi_awvalid && ~s_axi_bvalid && s_axi_wready && s_axi_wvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // AXI-Lite 读通道
    reg [AXI_ADDR_WIDTH-1:0] ar_addr_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
            ar_addr_reg   <= 0;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                ar_addr_reg   <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= 0;
        end else begin
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;

                case (ar_addr_reg[7:0])
                    ADDR_STATUS:      s_axi_rdata <= {31'b0, ready};
                    // INST_Decoder 寄存器
                    ADDR_DECODER_CTRL:   s_axi_rdata <= {31'b0, decoder_start_reg};
                    ADDR_INST_COUNT:     s_axi_rdata <= inst_count;
                    ADDR_DECODER_STATUS: s_axi_rdata <= decoder_status;
                    default:          s_axi_rdata <= 32'h0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
