`timescale 1ns / 1ps

// ============================================================================
// DCIM_Array_Top - 顶层封装模块
// ============================================================================
// 集成 DCIM_Array 计算核心 + AXI-Lite 配置接口
// 架构：8 组 × 8 Tile/组 = 64 Tile
// 对外提供：
//   - AXI-Lite Slave: 配置寄存器
//   - BRAM 接口: 8 组独立的 IBUF/OBUF 外部访问端口
// ============================================================================

`include "para.v"

module DCIM_Array_Top #(
    parameter NUM_GROUPS      = 8,
    parameter TILES_PER_GROUP = 8,
    parameter NUM_TILES       = 64,       // NUM_GROUPS × TILES_PER_GROUP
    parameter WD1             = 4,
    parameter CH_IN           = 16,
    parameter CH_OUT          = 16,
    parameter SRAM_DP         = 128,
    parameter CYCLE           = 8,
    parameter ACC             = 80,
    parameter BUF_ADDR_WIDTH  = 14,       // 每组 IBUF/OBUF 地址宽度
    parameter BUF_DATA_WIDTH  = 128,
    parameter IBUF_RD_LATENCY = 8,        // 8 Tile 仲裁 + URAM 延迟
    parameter AXI_ADDR_WIDTH  = 12,
    parameter AXI_DATA_WIDTH  = 32,
    
    localparam ACC_UBD_WD     = $clog2(ACC+1),
    localparam STRB_WIDTH     = BUF_DATA_WIDTH / 8
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
    
    // 8 组外部 IBUF 接口（Port A: 外部加载数据）
    input  wire [NUM_GROUPS*STRB_WIDTH-1:0]         ibuf_ext_wea,
    input  wire [NUM_GROUPS-1:0]                    ibuf_ext_ena,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]     ibuf_ext_addra,
    input  wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,
    
    // 8 组外部 OBUF 接口（Port A: 外部读取结果）
    input  wire [NUM_GROUPS*STRB_WIDTH-1:0]         obuf_ext_wea,
    input  wire [NUM_GROUPS-1:0]                    obuf_ext_ena,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]     obuf_ext_addra,
    input  wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     obuf_ext_douta,
    
    // 状态输出（可选，用于中断或 LED）
    output wire                          done,
    output wire                          ready
);

    // ========================================================================
    // AXI-Lite 配置模块 <-> DCIM_Array 连线
    // ========================================================================
    wire                                        cfg_start;
    wire [2:0]                                  cfg_mode;
    wire [ACC_UBD_WD-1:0]                       cfg_acc_depth;
    wire [31:0]                                 cfg_num_rows;
    wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]        cfg_act_base_addrs;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]         cfg_wei_base_addrs;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]         cfg_out_base_addrs;
    
    wire                                        sts_done;
    wire                                        sts_ready;
    
    assign done  = sts_done;
    assign ready = sts_ready;
    
    // ========================================================================
    // AXI-Lite 配置寄存器模块
    // ========================================================================
    DCIM_Array_AXI #(
        .NUM_GROUPS(NUM_GROUPS),
        .TILES_PER_GROUP(TILES_PER_GROUP),
        .NUM_TILES(NUM_TILES),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .ACC_UBD_WD(ACC_UBD_WD),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH)
    ) u_axi_regs (
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
        
        .cfg_start(cfg_start),
        .cfg_mode(cfg_mode),
        .cfg_acc_depth(cfg_acc_depth),
        .cfg_num_rows(cfg_num_rows),
        .cfg_act_base_addrs(cfg_act_base_addrs),
        .cfg_wei_base_addrs(cfg_wei_base_addrs),
        .cfg_out_base_addrs(cfg_out_base_addrs),
        
        .sts_done(sts_done),
        .sts_ready(sts_ready)
    );
    
    // ========================================================================
    // DCIM_Array 计算核心（8 组 × 8 Tile）
    // ========================================================================
    DCIM_Array #(
        .NUM_GROUPS(NUM_GROUPS),
        .TILES_PER_GROUP(TILES_PER_GROUP),
        .NUM_TILES(NUM_TILES),
        .WD1(WD1),
        .CH_IN(CH_IN),
        .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP),
        .CYCLE(CYCLE),
        .ACC(ACC),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .IBUF_RD_LATENCY(IBUF_RD_LATENCY)
    ) u_dcim_array (
        .clk(clk),
        .rst_n(rst_n),
        
        .start(cfg_start),
        .done(sts_done),
        .ready(sts_ready),
        
        .mode(cfg_mode),
        .acc_depth(cfg_acc_depth),
        .num_rows(cfg_num_rows),
        .act_base_addrs(cfg_act_base_addrs),
        .wei_base_addrs(cfg_wei_base_addrs),
        .out_base_addrs(cfg_out_base_addrs),
        
        .ibuf_ext_wea(ibuf_ext_wea),
        .ibuf_ext_ena(ibuf_ext_ena),
        .ibuf_ext_addra(ibuf_ext_addra),
        .ibuf_ext_dina(ibuf_ext_dina),
        .ibuf_ext_douta(ibuf_ext_douta),
        
        .obuf_ext_wea(obuf_ext_wea),
        .obuf_ext_ena(obuf_ext_ena),
        .obuf_ext_addra(obuf_ext_addra),
        .obuf_ext_dina(obuf_ext_dina),
        .obuf_ext_douta(obuf_ext_douta)
    );

endmodule
