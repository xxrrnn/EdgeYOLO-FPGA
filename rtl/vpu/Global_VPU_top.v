`timescale 1ns/1ps

// Global_VPU_top - VPU 顶层模块
// 修改：移除内部占位符 AXI Controller，改为暴露 BRAM 原生端口
// BRAM Controller 将在 Block Design 中通过 Xilinx IP 实现
// 
// 架构说明：
// - Global_VPU 内部已有 global_buffer_bram 和 weight_buffer_bram
// - 这些 BRAM 的 Port A 用于外部访问（AXI BRAM Controller）
// - Port B 用于 VPU 内部计算访问
// - 本模块将 Port A 接口暴露为标准 BRAM 接口

module Global_VPU_top #(
    parameter ADDR_WIDTH = 32,
    
    parameter GB_ADDR_WIDTH = 22,
    parameter C_INT_WIDTH_IN = 32,
    parameter BANDWIDTH = 256,       // BRAM 数据位宽 = NB_COL * COL_WIDTH = 32*8 = 256 bits

    parameter FP_CORE_NUM = 8,       // 每次并行处理的 FP32 数量（8 * 32 = 256 bits）
    parameter FP_TRAN_NUM = 8,
    parameter FP_WIDTH    = 32,
    
    parameter WB_ADDR_WIDTH = 20,
    parameter MAX_CHANNEL_NUM = 1024,

    parameter INTERVAL_NUM = 16,
    parameter RAM_DEPTH_GB    = 4096,  // 128KB / 32B per word = 4096 words
    parameter RAM_DEPTH_WB    = 4096,
    parameter Q_INT_WIDTH_OUT = 8
)(
    // 时钟和复位
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK, ASSOCIATED_BUSIF gb_bram:wb_bram, ASSOCIATED_RESET rst_n, FREQ_HZ 250000000, PHASE 0.0, INSERT_VIP 0" *)
    input   wire                     clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RST_N RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RST_N, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
    input   wire                     rst_n,
    
    // VPU 控制和状态信号
    output  wire                     ready,        // 状态：VPU 准备好
    input   wire                     vpu_start,    // 控制：VPU 开始运行
      
    // VPU 配置/地址输入
    input   wire[ADDR_WIDTH - 1:0]   unit_choose,
    input   wire[ADDR_WIDTH - 1:0]   src_addr,
    input   wire[ADDR_WIDTH - 1:0]   src2_addr,
    input   wire[ADDR_WIDTH - 1:0]   src_c,
    input   wire[ADDR_WIDTH - 1:0]   src_h,
    input   wire[ADDR_WIDTH - 1:0]   src_w,
    input   wire[ADDR_WIDTH - 1:0]   bias_addr,
    input   wire[ADDR_WIDTH - 1:0]   scale_addr,
    input   wire[ADDR_WIDTH - 1:0]   dst_addr,
    input   wire [ADDR_WIDTH-1:0]    addr_break,
    input   wire [ADDR_WIDTH-1:0]    addr_s,
    input   wire [ADDR_WIDTH-1:0]    addr_t,

    // =========================================================================
    // Global Buffer (GB) BRAM 接口 - 由外部 AXI BRAM Controller 驱动
    // 连接到 Global_VPU 内部 global_buffer_bram 的 Port A
    // =========================================================================
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 gb_bram CLK" *)
    (* X_INTERFACE_MODE = "Slave" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME gb_bram, MEM_SIZE 131072, MEM_WIDTH 256, MEM_ECC NONE, MASTER_TYPE BRAM_CTRL, READ_LATENCY 1, READ_WRITE_MODE READ_WRITE" *)
    input  wire                      gb_bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 gb_bram RST" *)
    input  wire                      gb_bram_rst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 gb_bram EN" *)
    input  wire                      gb_bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 gb_bram WE" *)
    input  wire [31:0]               gb_bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 gb_bram ADDR" *)
    input  wire [GB_ADDR_WIDTH-1:0]  gb_bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 gb_bram DIN" *)
    input  wire [255:0]              gb_bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 gb_bram DOUT" *)
    output wire [255:0]              gb_bram_dout,

    // =========================================================================
    // Weight Buffer (WB) BRAM 接口 - 由外部 AXI BRAM Controller 驱动
    // 连接到 Global_VPU 内部 weight_buffer_bram 的 Port A
    // =========================================================================
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram CLK" *)
    (* X_INTERFACE_MODE = "Slave" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME wb_bram, MEM_SIZE 131072, MEM_WIDTH 256, MEM_ECC NONE, MASTER_TYPE BRAM_CTRL, READ_LATENCY 1, READ_WRITE_MODE READ_WRITE" *)
    input  wire                      wb_bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram RST" *)
    input  wire                      wb_bram_rst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram EN" *)
    input  wire                      wb_bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram WE" *)
    input  wire [31:0]               wb_bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram ADDR" *)
    input  wire [WB_ADDR_WIDTH-1:0]  wb_bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram DIN" *)
    input  wire [255:0]              wb_bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram DOUT" *)
    output wire [255:0]              wb_bram_dout
);

    // =========================================================================
    // 内部信号
    // =========================================================================
    localparam NB_COL = 32;
    localparam COL_WIDTH = 8;

    // =========================================================================
    // Global_VPU 核心模块实例化
    // 直接将外部 BRAM 接口连接到 Global_VPU 的 Port A 接口
    // =========================================================================
    Global_VPU #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .C_INT_WIDTH_IN(C_INT_WIDTH_IN),
        .BANDWIDTH(BANDWIDTH),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_TRAN_NUM(FP_TRAN_NUM),
        .FP_WIDTH(FP_WIDTH),
        .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
        .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM),
        .INTERVAL_NUM(INTERVAL_NUM),
        .RAM_DEPTH_GB(RAM_DEPTH_GB),
        .RAM_DEPTH_WB(RAM_DEPTH_WB),
        .Q_INT_WIDTH_OUT(Q_INT_WIDTH_OUT)
    ) u_global_vpu (
        .clk(clk),
        .rst_n(rst_n),
        .config_ready(ready),
        .config_valid(1'b1),
        .start(vpu_start),
        .unit_choose(unit_choose),
        .src_addr(src_addr),
        .src2_addr(src2_addr),
        .src_c(src_c),
        .src_h(src_h),
        .src_w(src_w),
        .scale_addr(scale_addr),
        .bias_addr(bias_addr),
        .dst_addr(dst_addr),
        .addr_break(addr_break),
        .addr_s(addr_s),
        .addr_t(addr_t),
        // GB 接口 - 外部 BRAM Controller 通过 Port A 访问
        .gb_addra(gb_bram_addr[GB_ADDR_WIDTH-1:0]),
        .gb_dina(gb_bram_din),
        .gb_wea(gb_bram_we),
        .gb_ena(gb_bram_en),
        .gb_douta(gb_bram_dout),
        // WB 接口 - 外部 BRAM Controller 通过 Port A 访问
        .wb_addra(wb_bram_addr[WB_ADDR_WIDTH-1:0]),
        .wb_dina(wb_bram_din),
        .wb_wea(wb_bram_we),
        .wb_ena(wb_bram_en),
        .wb_douta(wb_bram_dout)
    );

endmodule
