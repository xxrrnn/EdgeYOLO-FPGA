`timescale 1ns / 1ps

// ============================================================================
// GEMM_Top - GEMM 加速器顶层模块
// ============================================================================
//
// 功能：整合 PE Array、AXI-Lite 配置接口和 BRAM 接口
//
// 接口：
//   - AXI-Lite：配置寄存器访问
//   - IBUF 端口 A：外部写入权重和激活数据
//   - OBUF 端口 A：外部读取计算结果
//
// 架构：
//   ┌─────────────────────────────────────────────────────────────┐
//   │                        GEMM_Top                             │
//   │  ┌─────────────┐    ┌─────────────────────────────────┐    │
//   │  │ AXI_Lite    │───▶│          PE_Array               │    │
//   │  │ _Regs       │    │  ┌──────┐ ┌──────┐   ┌──────┐  │    │
//   │  └─────────────┘    │  │Tile 0│ │Tile 1│...│Tile 7│  │    │
//   │        ▲            │  └──────┘ └──────┘   └──────┘  │    │
//   │        │            │       │        │          │     │    │
//   │   AXI-Lite          │       ▼        ▼          ▼     │    │
//   │                     │  ┌─────────────────────────────┐│    │
//   │                     │  │      OBUF_Arbiter          ││    │
//   │                     │  └─────────────────────────────┘│    │
//   │                     │       │                         │    │
//   │                     │  ┌────┴────┐    ┌──────────┐   │    │
//   │                     │  │  OBUF   │    │   IBUF   │   │    │
//   │                     │  └────┬────┘    └────┬─────┘   │    │
//   │                     └───────┼──────────────┼─────────┘    │
//   │                             │              │               │
//   └─────────────────────────────┼──────────────┼───────────────┘
//                                 ▼              ▼
//                            OBUF Port A    IBUF Port A
//                            (外部读取)      (外部写入)
//
// ============================================================================

`include "para.v"

module GEMM_Top #(
    // Tile 配置
    parameter NUM_TILES = 8,
    parameter WD1       = 4,
    parameter CH_IN     = 16,
    parameter CH_OUT    = 16,
    parameter SRAM_DP   = 128,
    parameter CYCLE     = 8,
    parameter ACC       = 80,
    
    // Buffer 配置
    parameter BUF_ADDR_WIDTH = 14,
    parameter BUF_DATA_WIDTH = 128,
    parameter WEIGHT_TILE_SIZE = 8,
    
    // AXI-Lite 配置
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 8,
    
    localparam ACC_UBD_WD = $clog2(ACC+1)
)(
    // 系统时钟和复位
    input  wire                                  clk,
    input  wire                                  rst_n,
    
    // AXI-Lite 从接口
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  wire [2:0]                            S_AXI_AWPROT,
    input  wire                                  S_AXI_AWVALID,
    output wire                                  S_AXI_AWREADY,
    
    input  wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]     S_AXI_WSTRB,
    input  wire                                  S_AXI_WVALID,
    output wire                                  S_AXI_WREADY,
    
    output wire [1:0]                            S_AXI_BRESP,
    output wire                                  S_AXI_BVALID,
    input  wire                                  S_AXI_BREADY,
    
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  wire [2:0]                            S_AXI_ARPROT,
    input  wire                                  S_AXI_ARVALID,
    output wire                                  S_AXI_ARREADY,
    
    output wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA,
    output wire [1:0]                            S_AXI_RRESP,
    output wire                                  S_AXI_RVALID,
    input  wire                                  S_AXI_RREADY,
    
    // IBUF 外部接口（端口 A：写入权重和激活）
    input  wire [BUF_DATA_WIDTH/8-1:0]           ibuf_wea,
    input  wire [BUF_ADDR_WIDTH-1:0]             ibuf_addra,
    input  wire [BUF_DATA_WIDTH-1:0]             ibuf_dina,
    input  wire                                  ibuf_ena,
    output wire [BUF_DATA_WIDTH-1:0]             ibuf_douta,
    
    // OBUF 外部接口（端口 A：读取结果）
    input  wire [BUF_DATA_WIDTH/8-1:0]           obuf_wea,
    input  wire [BUF_ADDR_WIDTH-1:0]             obuf_addra,
    input  wire [BUF_DATA_WIDTH-1:0]             obuf_dina,
    input  wire                                  obuf_ena,
    output wire [BUF_DATA_WIDTH-1:0]             obuf_douta,
    
    // 状态输出（可选，用于中断等）
    output wire                                  done,
    output wire                                  ready
);

    // ========================================================================
    // 内部信号
    // ========================================================================
    
    // AXI-Lite 寄存器到 PE Array 的控制信号
    wire                                  pe_start;
    wire                                  pe_soft_reset;
    wire                                  pe_ready;
    wire                                  pe_done;
    wire [NUM_TILES-1:0]                  pe_tile_ready;
    wire [NUM_TILES-1:0]                  pe_tile_done;
    
    // 配置信号
    wire [2:0]                            pe_mode;
    wire [ACC_UBD_WD-1:0]                 pe_acc_depth;
    wire [15:0]                           pe_num_rows;
    wire [BUF_ADDR_WIDTH-1:0]             pe_wei_base_addr;
    wire [BUF_ADDR_WIDTH-1:0]             pe_act_base_addr;
    wire [BUF_ADDR_WIDTH-1:0]             pe_out_base_addr;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]   pe_tile_out_offset;
    
    // 复位信号（系统复位 OR 软复位）
    wire rst_n_internal = rst_n & ~pe_soft_reset;
    
    // 状态输出
    assign done  = pe_done;
    assign ready = pe_ready;
    
    // ========================================================================
    // AXI-Lite 配置寄存器
    // ========================================================================
    
    AXI_Lite_Regs #(
        .NUM_TILES(NUM_TILES),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .ACC_UBD_WD(ACC_UBD_WD),
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) u_axi_lite_regs (
        .S_AXI_ACLK(clk),
        .S_AXI_ARESETN(rst_n),
        
        .S_AXI_AWADDR(S_AXI_AWADDR),
        .S_AXI_AWPROT(S_AXI_AWPROT),
        .S_AXI_AWVALID(S_AXI_AWVALID),
        .S_AXI_AWREADY(S_AXI_AWREADY),
        
        .S_AXI_WDATA(S_AXI_WDATA),
        .S_AXI_WSTRB(S_AXI_WSTRB),
        .S_AXI_WVALID(S_AXI_WVALID),
        .S_AXI_WREADY(S_AXI_WREADY),
        
        .S_AXI_BRESP(S_AXI_BRESP),
        .S_AXI_BVALID(S_AXI_BVALID),
        .S_AXI_BREADY(S_AXI_BREADY),
        
        .S_AXI_ARADDR(S_AXI_ARADDR),
        .S_AXI_ARPROT(S_AXI_ARPROT),
        .S_AXI_ARVALID(S_AXI_ARVALID),
        .S_AXI_ARREADY(S_AXI_ARREADY),
        
        .S_AXI_RDATA(S_AXI_RDATA),
        .S_AXI_RRESP(S_AXI_RRESP),
        .S_AXI_RVALID(S_AXI_RVALID),
        .S_AXI_RREADY(S_AXI_RREADY),
        
        .pe_start(pe_start),
        .pe_soft_reset(pe_soft_reset),
        .pe_ready(pe_ready),
        .pe_done(pe_done),
        .pe_tile_ready(pe_tile_ready),
        .pe_tile_done(pe_tile_done),
        
        .pe_mode(pe_mode),
        .pe_acc_depth(pe_acc_depth),
        .pe_num_rows(pe_num_rows),
        .pe_wei_base_addr(pe_wei_base_addr),
        .pe_act_base_addr(pe_act_base_addr),
        .pe_out_base_addr(pe_out_base_addr),
        .pe_tile_out_offset(pe_tile_out_offset)
    );
    
    // ========================================================================
    // PE Array
    // ========================================================================
    
    PE_Array #(
        .NUM_TILES(NUM_TILES),
        .WD1(WD1),
        .CH_IN(CH_IN),
        .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP),
        .CYCLE(CYCLE),
        .ACC(ACC),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .WEIGHT_TILE_SIZE(WEIGHT_TILE_SIZE)
    ) u_pe_array (
        .clk(clk),
        .rst_n(rst_n_internal),
        
        .start(pe_start),
        .done(pe_done),
        .ready(pe_ready),
        .tile_done(pe_tile_done),
        .tile_ready(pe_tile_ready),
        
        .mode(pe_mode),
        .acc_depth(pe_acc_depth),
        .num_rows(pe_num_rows),
        
        .wei_base_addr(pe_wei_base_addr),
        .act_base_addr(pe_act_base_addr),
        .out_base_addr(pe_out_base_addr),
        .tile_out_offset(pe_tile_out_offset),
        
        .ibuf_wea(ibuf_wea),
        .ibuf_addra(ibuf_addra),
        .ibuf_dina(ibuf_dina),
        .ibuf_ena(ibuf_ena),
        .ibuf_douta(ibuf_douta),
        
        .obuf_wea(obuf_wea),
        .obuf_addra(obuf_addra),
        .obuf_dina(obuf_dina),
        .obuf_ena(obuf_ena),
        .obuf_douta(obuf_douta)
    );

endmodule
