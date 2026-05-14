`timescale 1ns / 1ps

// ============================================================================
// DCIM_Array_bd - Vivado Block Design 用的 Verilog Wrapper
// ============================================================================
// Vivado IP Integrator 不支持 SystemVerilog 作为 module reference 的顶层，
// 因此用纯 Verilog wrapper 包装 DCIM_Array_Top。
//
// 架构：8 组 × 8 Tile/组 = 64 Tile
// 每组独立的 IBUF/OBUF，需要 8 组独立的 AXI BRAM Controller 接口
//
// 地址转换：
//   AXI BRAM Controller 输出字节地址
//   DCIM_Array 内部使用字地址（128-bit = 16 bytes per word）
//   转换：word_addr = byte_addr >> 4 (除以 16)
// ============================================================================

module DCIM_Array_bd #(
    parameter NUM_GROUPS          = 8,
    parameter TILES_PER_GROUP     = 8,
    parameter NUM_TILES           = 64,       // NUM_GROUPS × TILES_PER_GROUP
    parameter BUF_ADDR_WIDTH      = 14,       // 每组 IBUF/OBUF 内部字地址宽度
    parameter BUF_DATA_WIDTH      = 128,
    parameter AXI_BRAM_ADDR_WIDTH = 18,       // AXI BRAM Controller 字节地址宽度 (每组 256KB)
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
    
    // ========================================================================
    // 8 组外部 IBUF 接口（连接 AXI BRAM Controller，字节地址）
    // ========================================================================
    // Group 0
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_0,
    input  wire                               ibuf_ext_ena_0,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_0,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_0,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_0,
    // Group 1
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_1,
    input  wire                               ibuf_ext_ena_1,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_1,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_1,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_1,
    // Group 2
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_2,
    input  wire                               ibuf_ext_ena_2,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_2,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_2,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_2,
    // Group 3
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_3,
    input  wire                               ibuf_ext_ena_3,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_3,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_3,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_3,
    // Group 4
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_4,
    input  wire                               ibuf_ext_ena_4,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_4,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_4,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_4,
    // Group 5
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_5,
    input  wire                               ibuf_ext_ena_5,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_5,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_5,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_5,
    // Group 6
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_6,
    input  wire                               ibuf_ext_ena_6,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_6,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_6,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_6,
    // Group 7
    input  wire [BUF_DATA_WIDTH/8-1:0]        ibuf_ext_wea_7,
    input  wire                               ibuf_ext_ena_7,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     ibuf_ext_addra_7,
    input  wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_dina_7,
    output wire [BUF_DATA_WIDTH-1:0]          ibuf_ext_douta_7,
    
    // ========================================================================
    // 8 组外部 OBUF 接口（连接 AXI BRAM Controller，字节地址）
    // ========================================================================
    // Group 0
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_0,
    input  wire                               obuf_ext_ena_0,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_0,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_0,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_0,
    // Group 1
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_1,
    input  wire                               obuf_ext_ena_1,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_1,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_1,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_1,
    // Group 2
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_2,
    input  wire                               obuf_ext_ena_2,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_2,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_2,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_2,
    // Group 3
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_3,
    input  wire                               obuf_ext_ena_3,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_3,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_3,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_3,
    // Group 4
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_4,
    input  wire                               obuf_ext_ena_4,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_4,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_4,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_4,
    // Group 5
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_5,
    input  wire                               obuf_ext_ena_5,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_5,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_5,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_5,
    // Group 6
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_6,
    input  wire                               obuf_ext_ena_6,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_6,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_6,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_6,
    // Group 7
    input  wire [BUF_DATA_WIDTH/8-1:0]        obuf_ext_wea_7,
    input  wire                               obuf_ext_ena_7,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0]     obuf_ext_addra_7,
    input  wire [BUF_DATA_WIDTH-1:0]          obuf_ext_dina_7,
    output wire [BUF_DATA_WIDTH-1:0]          obuf_ext_douta_7,
    
    // 状态输出
    output wire                          done,
    output wire                          ready
);

    // 地址转换：字节地址 -> 字地址
    // 128-bit = 16 bytes, 所以右移 4 位
    localparam ADDR_SHIFT = 4;  // log2(128/8) = log2(16) = 4
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8;  // 128/8 = 16
    
    // ========================================================================
    // 聚合信号
    // ========================================================================
    wire [NUM_GROUPS*STRB_WIDTH-1:0]     ibuf_ext_wea;
    wire [NUM_GROUPS-1:0]                ibuf_ext_ena;
    wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0] ibuf_ext_addra;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0] ibuf_ext_dina;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0] ibuf_ext_douta;
    
    wire [NUM_GROUPS*STRB_WIDTH-1:0]     obuf_ext_wea;
    wire [NUM_GROUPS-1:0]                obuf_ext_ena;
    wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0] obuf_ext_addra;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0] obuf_ext_dina;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0] obuf_ext_douta;
    
    // ========================================================================
    // IBUF 信号聚合与地址转换
    // ========================================================================
    // Group 0
    assign ibuf_ext_wea[0*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_0;
    assign ibuf_ext_ena[0] = ibuf_ext_ena_0;
    assign ibuf_ext_addra[0*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_0[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[0*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_0;
    assign ibuf_ext_douta_0 = ibuf_ext_douta[0*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 1
    assign ibuf_ext_wea[1*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_1;
    assign ibuf_ext_ena[1] = ibuf_ext_ena_1;
    assign ibuf_ext_addra[1*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_1[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[1*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_1;
    assign ibuf_ext_douta_1 = ibuf_ext_douta[1*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 2
    assign ibuf_ext_wea[2*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_2;
    assign ibuf_ext_ena[2] = ibuf_ext_ena_2;
    assign ibuf_ext_addra[2*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_2[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[2*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_2;
    assign ibuf_ext_douta_2 = ibuf_ext_douta[2*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 3
    assign ibuf_ext_wea[3*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_3;
    assign ibuf_ext_ena[3] = ibuf_ext_ena_3;
    assign ibuf_ext_addra[3*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_3[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[3*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_3;
    assign ibuf_ext_douta_3 = ibuf_ext_douta[3*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 4
    assign ibuf_ext_wea[4*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_4;
    assign ibuf_ext_ena[4] = ibuf_ext_ena_4;
    assign ibuf_ext_addra[4*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_4[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[4*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_4;
    assign ibuf_ext_douta_4 = ibuf_ext_douta[4*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 5
    assign ibuf_ext_wea[5*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_5;
    assign ibuf_ext_ena[5] = ibuf_ext_ena_5;
    assign ibuf_ext_addra[5*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_5[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[5*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_5;
    assign ibuf_ext_douta_5 = ibuf_ext_douta[5*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 6
    assign ibuf_ext_wea[6*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_6;
    assign ibuf_ext_ena[6] = ibuf_ext_ena_6;
    assign ibuf_ext_addra[6*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_6[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[6*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_6;
    assign ibuf_ext_douta_6 = ibuf_ext_douta[6*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 7
    assign ibuf_ext_wea[7*STRB_WIDTH +: STRB_WIDTH] = ibuf_ext_wea_7;
    assign ibuf_ext_ena[7] = ibuf_ext_ena_7;
    assign ibuf_ext_addra[7*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = ibuf_ext_addra_7[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign ibuf_ext_dina[7*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_ext_dina_7;
    assign ibuf_ext_douta_7 = ibuf_ext_douta[7*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    
    // ========================================================================
    // OBUF 信号聚合与地址转换
    // ========================================================================
    // Group 0
    assign obuf_ext_wea[0*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_0;
    assign obuf_ext_ena[0] = obuf_ext_ena_0;
    assign obuf_ext_addra[0*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_0[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[0*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_0;
    assign obuf_ext_douta_0 = obuf_ext_douta[0*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 1
    assign obuf_ext_wea[1*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_1;
    assign obuf_ext_ena[1] = obuf_ext_ena_1;
    assign obuf_ext_addra[1*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_1[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[1*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_1;
    assign obuf_ext_douta_1 = obuf_ext_douta[1*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 2
    assign obuf_ext_wea[2*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_2;
    assign obuf_ext_ena[2] = obuf_ext_ena_2;
    assign obuf_ext_addra[2*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_2[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[2*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_2;
    assign obuf_ext_douta_2 = obuf_ext_douta[2*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 3
    assign obuf_ext_wea[3*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_3;
    assign obuf_ext_ena[3] = obuf_ext_ena_3;
    assign obuf_ext_addra[3*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_3[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[3*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_3;
    assign obuf_ext_douta_3 = obuf_ext_douta[3*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 4
    assign obuf_ext_wea[4*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_4;
    assign obuf_ext_ena[4] = obuf_ext_ena_4;
    assign obuf_ext_addra[4*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_4[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[4*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_4;
    assign obuf_ext_douta_4 = obuf_ext_douta[4*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 5
    assign obuf_ext_wea[5*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_5;
    assign obuf_ext_ena[5] = obuf_ext_ena_5;
    assign obuf_ext_addra[5*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_5[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[5*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_5;
    assign obuf_ext_douta_5 = obuf_ext_douta[5*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 6
    assign obuf_ext_wea[6*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_6;
    assign obuf_ext_ena[6] = obuf_ext_ena_6;
    assign obuf_ext_addra[6*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_6[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[6*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_6;
    assign obuf_ext_douta_6 = obuf_ext_douta[6*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    // Group 7
    assign obuf_ext_wea[7*STRB_WIDTH +: STRB_WIDTH] = obuf_ext_wea_7;
    assign obuf_ext_ena[7] = obuf_ext_ena_7;
    assign obuf_ext_addra[7*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = obuf_ext_addra_7[ADDR_SHIFT +: BUF_ADDR_WIDTH];
    assign obuf_ext_dina[7*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_ext_dina_7;
    assign obuf_ext_douta_7 = obuf_ext_douta[7*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];

    // ========================================================================
    // DCIM_Array_Top 实例化
    // ========================================================================
    DCIM_Array_Top #(
        .NUM_GROUPS(NUM_GROUPS),
        .TILES_PER_GROUP(TILES_PER_GROUP),
        .NUM_TILES(NUM_TILES),
        .WD1(4),
        .CH_IN(16),
        .CH_OUT(16),
        .SRAM_DP(128),
        .CYCLE(8),
        .ACC(80),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .IBUF_RD_LATENCY(8),
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
        .ibuf_ext_addra(ibuf_ext_addra),
        .ibuf_ext_dina(ibuf_ext_dina),
        .ibuf_ext_douta(ibuf_ext_douta),
        
        .obuf_ext_wea(obuf_ext_wea),
        .obuf_ext_ena(obuf_ext_ena),
        .obuf_ext_addra(obuf_ext_addra),
        .obuf_ext_dina(obuf_ext_dina),
        .obuf_ext_douta(obuf_ext_douta),
        
        .done(done),
        .ready(ready)
    );

endmodule
