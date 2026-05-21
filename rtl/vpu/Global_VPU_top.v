`timescale 1ns/1ps
`include "vpu_defines.vh"
`include "chip_defines.vh"

// Global_VPU_top - VPU 顶层模块 (lite 版本)
// lite 变更：
//   - 删除 GB BRAM 接口（VPU 通过 obuf_* 直接访问 DCIM OBUF）
//   - 保留 WB BRAM 接口（128-bit）
//   - obuf_* 端口连接到 DCIM_Array_bd 的 VPU OBUF 端口

module Global_VPU_top #(
    parameter ADDR_WIDTH = `VPU_DATA_WIDTH,
    parameter GB_ADDR_WIDTH = `GB_ADDR_WIDTH,
    parameter C_INT_WIDTH_IN = `C_INT_WIDTH_IN,
    parameter BANDWIDTH = `VPU_BANDWIDTH,
    parameter FP_CORE_NUM = `FP_CORE_NUM,
    parameter FP_TRAN_NUM = `FP_TRAN_NUM,
    parameter FP_WIDTH    = `FP_WIDTH,
    parameter WB_ADDR_WIDTH = `WB_ADDR_WIDTH,
    parameter MAX_CHANNEL_NUM = `MAX_CHANNEL_NUM,
    parameter INTERVAL_NUM = `INTERVAL_NUM,
    parameter RAM_DEPTH_GB    = `RAM_DEPTH_GB,
    parameter RAM_DEPTH_WB    = `RAM_DEPTH_WB,
    parameter Q_INT_WIDTH_OUT = `Q_INT_WIDTH_OUT
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK, ASSOCIATED_BUSIF wb_bram, ASSOCIATED_RESET rst_n, FREQ_HZ 250000000, PHASE 0.0, INSERT_VIP 0" *)
    input   wire                     clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RST_N RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RST_N, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
    input   wire                     rst_n,

    output  wire                     ready,
    input   wire                     vpu_start,

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

    // lite: OBUF 128-bit 端口（替代 GB，直连 DCIM OBUF）
    output wire [`DCIM_OBUF_ADDR_WIDTH-1:0]  obuf_addr,
    output wire                              obuf_en,
    output wire [`DCIM_BUF_DATA_WIDTH/8-1:0] obuf_we,
    output wire [`DCIM_BUF_DATA_WIDTH-1:0]   obuf_din,
    input  wire [`DCIM_BUF_DATA_WIDTH-1:0]   obuf_dout,

    // Weight Buffer (WB) BRAM 接口 - 128-bit
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram CLK" *)
    (* X_INTERFACE_MODE = "Slave" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME wb_bram, MEM_SIZE 32768, MEM_WIDTH 128, MEM_ECC NONE, MASTER_TYPE BRAM_CTRL, READ_LATENCY 1, READ_WRITE_MODE READ_WRITE" *)
    input  wire                      wb_bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram RST" *)
    input  wire                      wb_bram_rst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram EN" *)
    input  wire                      wb_bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram WE" *)
    input  wire [15:0]               wb_bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram ADDR" *)
    input  wire [WB_ADDR_WIDTH-1:0]  wb_bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram DIN" *)
    input  wire [127:0]              wb_bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 wb_bram DOUT" *)
    output wire [127:0]              wb_bram_dout
);

    localparam NB_COL = `NB_COL;
    localparam COL_WIDTH = `COL_WIDTH;
    localparam BYTE_ADDR_SHIFT = $clog2(BANDWIDTH / 8);

    wire [WB_ADDR_WIDTH-1:0] wb_bram_word_addr = wb_bram_addr >> BYTE_ADDR_SHIFT;

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
        // lite: OBUF 端口
        .obuf_addr(obuf_addr),
        .obuf_en(obuf_en),
        .obuf_we(obuf_we),
        .obuf_din(obuf_din),
        .obuf_dout(obuf_dout),
        // WB 接口
        .wb_addra(wb_bram_word_addr[WB_ADDR_WIDTH-1:0]),
        .wb_dina(wb_bram_din),
        .wb_wea(wb_bram_we),
        .wb_ena(wb_bram_en),
        .wb_douta(wb_bram_dout)
    );

endmodule
