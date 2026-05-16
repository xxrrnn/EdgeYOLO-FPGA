`timescale 1ns / 1ps
//==============================================================================
// VPU_AXI_Regs - AXI-Lite Slave 寄存器模块
//==============================================================================
// 为 Global_VPU_top 提供 AXI-Lite 配置/状态接口，替代 14 个 AXI GPIO。
// 寄存器映射（字节地址，4 字节对齐）：
//   0x00: CTRL       - [0] start (W/R, 写 1/0 控制；上升沿检测后输出脉冲)
//   0x04: STATUS     - [0] ready (RO)
//   0x08: UNIT_CHOOSE
//   0x0C: SRC_ADDR
//   0x10: SRC2_ADDR
//   0x14: SRC_C
//   0x18: SRC_H
//   0x1C: SRC_W
//   0x20: BIAS_ADDR
//   0x24: SCALE_ADDR
//   0x28: DST_ADDR
//   0x2C: ADDR_BREAK
//   0x30: ADDR_S
//   0x34: ADDR_T
//   --- INST_Decoder 控制寄存器 ---
//   0x38: DECODER_CTRL   - [0] start (写 1 启动解码器)
//   0x3C: INST_COUNT     - 指令总数（32位字数）
//   0x40: DECODER_STATUS - [0] busy, [1] done, [31] error
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

    // VPU 配置输出
    output reg                           vpu_start,
    output reg  [ADDR_WIDTH-1:0]         unit_choose,
    output reg  [ADDR_WIDTH-1:0]         src_addr,
    output reg  [ADDR_WIDTH-1:0]         src2_addr,
    output reg  [ADDR_WIDTH-1:0]         src_c,
    output reg  [ADDR_WIDTH-1:0]         src_h,
    output reg  [ADDR_WIDTH-1:0]         src_w,
    output reg  [ADDR_WIDTH-1:0]         bias_addr,
    output reg  [ADDR_WIDTH-1:0]         scale_addr,
    output reg  [ADDR_WIDTH-1:0]         dst_addr,
    output reg  [ADDR_WIDTH-1:0]         addr_break,
    output reg  [ADDR_WIDTH-1:0]         addr_s,
    output reg  [ADDR_WIDTH-1:0]         addr_t,

    // VPU 状态输入
    input  wire                          ready,
    
    // INST_Decoder 控制接口
    output reg                           decoder_start,      // 启动解码器
    output reg  [ADDR_WIDTH-1:0]         inst_count,         // 指令总数（32位字数）
    input  wire                          decoder_busy,       // 解码器忙
    input  wire                          decoder_done,       // 解码完成
    input  wire [ADDR_WIDTH-1:0]         decoder_status      // 解码器状态
);

    // 寄存器地址（字节地址）
    localparam [7:0] ADDR_CTRL        = 8'h00;
    localparam [7:0] ADDR_STATUS      = 8'h04;
    localparam [7:0] ADDR_UNIT_CHOOSE = 8'h08;
    localparam [7:0] ADDR_SRC_ADDR    = 8'h0C;
    localparam [7:0] ADDR_SRC2_ADDR   = 8'h10;
    localparam [7:0] ADDR_SRC_C       = 8'h14;
    localparam [7:0] ADDR_SRC_H       = 8'h18;
    localparam [7:0] ADDR_SRC_W       = 8'h1C;
    localparam [7:0] ADDR_BIAS_ADDR   = 8'h20;
    localparam [7:0] ADDR_SCALE_ADDR  = 8'h24;
    localparam [7:0] ADDR_DST_ADDR    = 8'h28;
    localparam [7:0] ADDR_ADDR_BREAK  = 8'h2C;
    localparam [7:0] ADDR_ADDR_S      = 8'h30;
    localparam [7:0] ADDR_ADDR_T      = 8'h34;
    // INST_Decoder 控制寄存器
    localparam [7:0] ADDR_DECODER_CTRL   = 8'h38;
    localparam [7:0] ADDR_INST_COUNT     = 8'h3C;
    localparam [7:0] ADDR_DECODER_STATUS = 8'h40;

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

    // 寄存器写逻辑 + start 上升沿检测
    wire wr_en = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;
    
    reg ctrl_start_reg;     // CTRL[0] 寄存器：保存 host 写入的 start 电平
    reg ctrl_start_reg_d1;  // 上升沿检测：保存上一拍的 start 电平
    
    // INST_Decoder 控制寄存器
    reg decoder_start_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_start_reg    <= 1'b0;
            ctrl_start_reg_d1 <= 1'b0;
            vpu_start         <= 1'b0;
            unit_choose <= 0;
            src_addr    <= 0;
            src2_addr   <= 0;
            src_c       <= 0;
            src_h       <= 0;
            src_w       <= 0;
            bias_addr   <= 0;
            scale_addr  <= 0;
            dst_addr    <= 0;
            addr_break  <= 0;
            addr_s      <= 0;
            addr_t      <= 0;
            // INST_Decoder
            decoder_start_reg    <= 1'b0;
            decoder_start        <= 1'b0;
            inst_count           <= 0;
        end else begin
            // VPU 上升沿检测
            ctrl_start_reg_d1 <= ctrl_start_reg;
            vpu_start <= ctrl_start_reg && ~ctrl_start_reg_d1;
            
            // INST_Decoder：直接输出电平，由 INST_Decoder 内部做上升沿检测
            decoder_start <= decoder_start_reg;

            if (wr_en) begin
                case (aw_addr_reg[7:0])
                    ADDR_CTRL: begin
                        if (s_axi_wstrb[0])
                            ctrl_start_reg <= s_axi_wdata[0];
                    end
                    ADDR_UNIT_CHOOSE: unit_choose <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_SRC_ADDR:    src_addr    <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_SRC2_ADDR:   src2_addr   <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_SRC_C:       src_c       <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_SRC_H:       src_h       <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_SRC_W:       src_w       <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_BIAS_ADDR:   bias_addr   <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_SCALE_ADDR:  scale_addr  <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_DST_ADDR:    dst_addr    <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_ADDR_BREAK:  addr_break  <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_ADDR_S:      addr_s      <= s_axi_wdata[ADDR_WIDTH-1:0];
                    ADDR_ADDR_T:      addr_t      <= s_axi_wdata[ADDR_WIDTH-1:0];
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
                    ADDR_CTRL:        s_axi_rdata <= {31'b0, ctrl_start_reg};
                    ADDR_STATUS:      s_axi_rdata <= {31'b0, ready};
                    ADDR_UNIT_CHOOSE: s_axi_rdata <= unit_choose;
                    ADDR_SRC_ADDR:    s_axi_rdata <= src_addr;
                    ADDR_SRC2_ADDR:   s_axi_rdata <= src2_addr;
                    ADDR_SRC_C:       s_axi_rdata <= src_c;
                    ADDR_SRC_H:       s_axi_rdata <= src_h;
                    ADDR_SRC_W:       s_axi_rdata <= src_w;
                    ADDR_BIAS_ADDR:   s_axi_rdata <= bias_addr;
                    ADDR_SCALE_ADDR:  s_axi_rdata <= scale_addr;
                    ADDR_DST_ADDR:    s_axi_rdata <= dst_addr;
                    ADDR_ADDR_BREAK:  s_axi_rdata <= addr_break;
                    ADDR_ADDR_S:      s_axi_rdata <= addr_s;
                    ADDR_ADDR_T:      s_axi_rdata <= addr_t;
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
