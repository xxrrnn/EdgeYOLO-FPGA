`timescale 1ns/1ps
//==============================================================================
// Global_VPU_top：上板集成 wrapper。
//
//   - GB/WB BRAM 由 Global_VPU 内部的 global_buffer_bram 提供，Port A 通过
//     native BRAM 接口（en/we/addr/din/dout）从此 wrapper 引出。
//   - BD 中 XDMA M_AXI → smartconnect → axi_bram_ctrl（DATA_WIDTH=256）→
//     vpu_0 的 gb_*/wb_* Port A，可由 host 直接读写权重/激活/结果。
//   - 控制/配置寄存器（unit_choose/src*/dst*/addr_*/vpu_start）由 AXI GPIO
//     提供；ready 通过状态 GPIO 回读。
//   - 时钟/复位与 BD 中 xdma_0/axi_aclk 同步（rst_n = axi_aresetn）。
//
//   参数默认值与 Global_VPU 保持一致；如需修改 GB/WB 容量，请同时调整
//   RAM_DEPTH_GB / RAM_DEPTH_WB 和 BD 中 vpu_padded_addr_net 的目标位宽。
//==============================================================================
module Global_VPU_top #(
    parameter ADDR_WIDTH      = 32,
    parameter GB_ADDR_WIDTH   = 20,
    parameter WB_ADDR_WIDTH   = 20,
    parameter C_INT_WIDTH_IN  = 32,
    parameter BANDWIDTH       = 256,   // 修正：与 NB_COL*COL_WIDTH 一致
    parameter FP_CORE_NUM     = 32,
    parameter FP_TRAN_NUM     = 8,
    parameter FP_WIDTH        = 32,
    parameter MAX_CHANNEL_NUM = 256,
    parameter INTERVAL_NUM    = 16,
    parameter RAM_DEPTH_GB    = 1024,
    parameter RAM_DEPTH_WB    = 1024,
    parameter Q_INT_WIDTH_OUT = 8,
    parameter NB_COL          = 32,
    parameter COL_WIDTH       = 8
)(
    input  wire                          clk,
    input  wire                          rst_n,
    output wire                          ready,
    input  wire                          vpu_start,

    // 配置寄存器（AXI GPIO 驱动）
    input  wire [ADDR_WIDTH-1:0]         unit_choose,
    input  wire [ADDR_WIDTH-1:0]         src_addr,
    input  wire [ADDR_WIDTH-1:0]         src2_addr,
    input  wire [ADDR_WIDTH-1:0]         src_c,
    input  wire [ADDR_WIDTH-1:0]         src_h,
    input  wire [ADDR_WIDTH-1:0]         src_w,
    input  wire [ADDR_WIDTH-1:0]         bias_addr,
    input  wire [ADDR_WIDTH-1:0]         scale_addr,
    input  wire [ADDR_WIDTH-1:0]         dst_addr,
    input  wire [ADDR_WIDTH-1:0]         addr_break,
    input  wire [ADDR_WIDTH-1:0]         addr_s,
    input  wire [ADDR_WIDTH-1:0]         addr_t,

    // Global Buffer：BD 中 axi_bram_ctrl Port A → 此端口
    input  wire [GB_ADDR_WIDTH-1:0]      gb_addra,
    input  wire [(NB_COL*COL_WIDTH)-1:0] gb_dina,
    input  wire [NB_COL-1:0]             gb_wea,
    input  wire                          gb_ena,
    output wire [(NB_COL*COL_WIDTH)-1:0] gb_douta,

    // Weight Buffer：BD 中 axi_bram_ctrl Port A → 此端口
    input  wire [WB_ADDR_WIDTH-1:0]      wb_addra,
    input  wire [(NB_COL*COL_WIDTH)-1:0] wb_dina,
    input  wire [NB_COL-1:0]             wb_wea,
    input  wire                          wb_ena,
    output wire [(NB_COL*COL_WIDTH)-1:0] wb_douta
);

    Global_VPU #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .GB_ADDR_WIDTH   (GB_ADDR_WIDTH),
        .C_INT_WIDTH_IN  (C_INT_WIDTH_IN),
        .BANDWIDTH       (BANDWIDTH),
        .FP_CORE_NUM     (FP_CORE_NUM),
        .FP_TRAN_NUM     (FP_TRAN_NUM),
        .FP_WIDTH        (FP_WIDTH),
        .WB_ADDR_WIDTH   (WB_ADDR_WIDTH),
        .MAX_CHANNEL_NUM (MAX_CHANNEL_NUM),
        .INTERVAL_NUM    (INTERVAL_NUM),
        .RAM_DEPTH_GB    (RAM_DEPTH_GB),
        .RAM_DEPTH_WB    (RAM_DEPTH_WB),
        .Q_INT_WIDTH_OUT (Q_INT_WIDTH_OUT),
        .NB_COL          (NB_COL),
        .COL_WIDTH       (COL_WIDTH)
    ) u_global_vpu (
        .clk         (clk),
        .rst_n       (rst_n),
        .ready       (ready),
        .vpu_start   (vpu_start),

        .unit_choose (unit_choose),
        .src_addr    (src_addr),
        .src2_addr   (src2_addr),
        .src_c       (src_c),
        .src_h       (src_h),
        .src_w       (src_w),
        .scale_addr  (scale_addr),
        .bias_addr   (bias_addr),
        .dst_addr    (dst_addr),
        .addr_break  (addr_break),
        .addr_s      (addr_s),
        .addr_t      (addr_t),

        .gb_addra    (gb_addra),
        .gb_dina     (gb_dina),
        .gb_wea      (gb_wea),
        .gb_ena      (gb_ena),
        .gb_douta    (gb_douta),

        .wb_addra    (wb_addra),
        .wb_dina     (wb_dina),
        .wb_wea      (wb_wea),
        .wb_ena      (wb_ena),
        .wb_douta    (wb_douta)
    );

endmodule
