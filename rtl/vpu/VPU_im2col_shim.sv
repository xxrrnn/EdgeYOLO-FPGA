`timescale 1ns/1ps
`include "chip_defines.vh"

// ============================================================================
// VPU_im2col_shim - 仅包含 im2col 分发的 VPU 简化模型
// ============================================================================
// 用于 INST_Decoder 联合仿真，避免引入完整 Global_VPU 的 FP IP 依赖。
// 接口与 Global_VPU_top 中 INST_Decoder 相关部分一致。
// ============================================================================

module VPU_im2col_shim #(
    parameter ADDR_WIDTH    = `VPU_DATA_WIDTH,
    parameter GB_ADDR_WIDTH = `GB_ADDR_WIDTH,
    parameter GB_BANDWIDTH  = `GB_BANDWIDTH,
    parameter OBUF_ADDR_WIDTH = `VPU_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // INST_Decoder 接口
    output wire                          ready,
    input  wire                          vpu_start,
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

    // OBUF 端口（连接到 DCIM_Array_bd vpu_obuf_*）
    output wire [OBUF_ADDR_WIDTH-1:0]    obuf_addr,
    output wire                          obuf_en,
    output wire [BUF_DATA_WIDTH/8-1:0]   obuf_we,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_din,
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_dout,
    input  wire                          obuf_rd_valid
);

    localparam UNIT_IM2COL = 32'd7;

    // 配置锁存
    reg [ADDR_WIDTH-1:0] unit_choose_reg;
    reg [ADDR_WIDTH-1:0] src_addr_reg, dst_addr_reg;
    reg [ADDR_WIDTH-1:0] src_c_reg, src_h_reg, src_w_reg;
    reg [ADDR_WIDTH-1:0] addr_break_reg, addr_s_reg, addr_t_reg;

    wire im2col_unit_ready;
    wire im2col_unit_start;

    assign ready = im2col_unit_ready;
    assign im2col_unit_start = (unit_choose_reg == UNIT_IM2COL) ? vpu_start : 1'b0;

    // 锁存配置（在 ready && vpu_start 时）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            unit_choose_reg <= 0;
            src_addr_reg <= 0; dst_addr_reg <= 0;
            src_c_reg <= 0; src_h_reg <= 0; src_w_reg <= 0;
            addr_break_reg <= 0; addr_s_reg <= 0; addr_t_reg <= 0;
        end else if (ready) begin
            unit_choose_reg <= unit_choose;
            src_addr_reg <= src_addr;
            dst_addr_reg <= dst_addr;
            src_c_reg <= src_c;
            src_h_reg <= src_h;
            src_w_reg <= src_w;
            addr_break_reg <= addr_break;
            addr_s_reg <= addr_s;
            addr_t_reg <= addr_t;
        end
    end

    // im2col GB 信号
    wire [GB_ADDR_WIDTH-1:0]     im2col_gb_addrb;
    wire [GB_BANDWIDTH-1:0]      im2col_gb_dinb;
    wire [GB_BANDWIDTH/8-1:0]    im2col_gb_web;
    wire                         im2col_gb_enb;

    im2col_unit #(
        .ADDR_WIDTH    (ADDR_WIDTH),
        .GB_BANDWIDTH  (GB_BANDWIDTH),
        .GB_ADDR_WIDTH (GB_ADDR_WIDTH),
        .FP_WIDTH      (32)
    ) u_im2col (
        .clk               (clk),
        .rst_n             (rst_n),
        .im2col_unit_start (im2col_unit_start),
        .im2col_unit_ready (im2col_unit_ready),
        .im2col_src_addr   (src_addr),
        .im2col_dst_addr   (dst_addr),
        .im2col_src_c      (src_c),
        .im2col_src_h      (src_h),
        .im2col_src_w      (src_w),
        .im2col_addr_break (addr_break),
        .im2col_addr_s     (addr_s),
        .im2col_addr_t     (addr_t),
        .gb_addrb          (im2col_gb_addrb),
        .gb_dinb           (im2col_gb_dinb),
        .gb_web            (im2col_gb_web),
        .gb_enb            (im2col_gb_enb),
        .gb_doutb          (obuf_dout),
        .gb_doutb_valid    (obuf_rd_valid)
    );

    // GB → OBUF 地址转换（字节地址 → 128-bit 字地址）
    assign obuf_addr = im2col_gb_addrb[OBUF_ADDR_WIDTH+3:4];
    assign obuf_en   = im2col_gb_enb;
    assign obuf_we   = im2col_gb_web;
    assign obuf_din  = im2col_gb_dinb;

endmodule
