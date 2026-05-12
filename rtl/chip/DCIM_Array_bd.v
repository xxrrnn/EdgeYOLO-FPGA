`timescale 1ns / 1ps

// ============================================================================
// DCIM_Array_bd - Vivado Block Design 用的 Verilog Wrapper
// ============================================================================
// Vivado IP Integrator 不支持 SystemVerilog 作为 module reference 的顶层，
// 因此用纯 Verilog wrapper 包装 DCIM_Array_Top。
//
// 地址转换：
//   AXI BRAM Controller 输出字节地址（23 位用于 8MB）
//   DCIM_Array 内部使用字地址（19 位，128-bit = 16 bytes per word）
//   转换：word_addr = byte_addr >> 4 (除以 16)
// ============================================================================

module DCIM_Array_bd #(
    parameter NUM_TILES           = 32,
    parameter BUF_ADDR_WIDTH      = 19,     // 内部字地址宽度
    parameter BUF_DATA_WIDTH      = 128,
    parameter AXI_BRAM_ADDR_WIDTH = 23,     // AXI BRAM Controller 字节地址宽度 (8MB)
    parameter AXI_ADDR_WIDTH      = 12,
    parameter AXI_DATA_WIDTH      = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,
    
    // AXI-Lite Slave Interface (配置寄存器)
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                    s_axi_awprot,
    input  wire                          s_axi_awvalid,
    output wire                          s_axi_awready,
    
    input  wire [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]   s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output wire                          s_axi_wready,
    
    output wire [1:0]                    s_axi_bresp,
    output wire                          s_axi_bvalid,
    input  wire                          s_axi_bready,
    
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                    s_axi_arprot,
    input  wire                          s_axi_arvalid,
    output wire                          s_axi_arready,
    
    output wire [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output wire [1:0]                    s_axi_rresp,
    output wire                          s_axi_rvalid,
    input  wire                          s_axi_rready,
    
    // 外部 IBUF 接口（连接 AXI BRAM Controller，字节地址）
    input  wire [BUF_DATA_WIDTH/8-1:0]   ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0] ibuf_ext_addra,  // 字节地址
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,
    
    // 外部 OBUF 接口（连接 AXI BRAM Controller，字节地址）
    input  wire [BUF_DATA_WIDTH/8-1:0]   obuf_ext_wea,
    input  wire                          obuf_ext_ena,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0] obuf_ext_addra,  // 字节地址
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_ext_douta,
    
    // 状态输出
    output wire                          done,
    output wire                          ready
);

    // 地址转换：字节地址 -> 字地址
    // 128-bit = 16 bytes, 所以右移 4 位
    localparam ADDR_SHIFT = 4;  // log2(128/8) = log2(16) = 4
    
    wire [BUF_ADDR_WIDTH-1:0] ibuf_word_addr;
    wire [BUF_ADDR_WIDTH-1:0] obuf_word_addr;
    
    assign ibuf_word_addr = ibuf_ext_addra[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_word_addr = obuf_ext_addra[ADDR_SHIFT +: BUF_ADDR_WIDTH];

    DCIM_Array_Top #(
        .NUM_TILES(NUM_TILES),
        .WD1(4),
        .CH_IN(16),
        .CH_OUT(16),
        .SRAM_DP(128),
        .CYCLE(8),
        .ACC(80),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .IBUF_RD_LATENCY(4),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) u_top (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        
        .ibuf_ext_wea(ibuf_ext_wea),
        .ibuf_ext_ena(ibuf_ext_ena),
        .ibuf_ext_addra(ibuf_word_addr),  // 转换后的字地址
        .ibuf_ext_dina(ibuf_ext_dina),
        .ibuf_ext_douta(ibuf_ext_douta),
        
        .obuf_ext_wea(obuf_ext_wea),
        .obuf_ext_ena(obuf_ext_ena),
        .obuf_ext_addra(obuf_word_addr),  // 转换后的字地址
        .obuf_ext_dina(obuf_ext_dina),
        .obuf_ext_douta(obuf_ext_douta),
        
        .done(done),
        .ready(ready)
    );

endmodule
