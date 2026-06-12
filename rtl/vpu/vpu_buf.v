`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// vpu_buf.v  —  VPU 本地 Buffer  8MB  (chip-v3 lite)
// ============================================================================
// 使用 uram_tdp_bytewrite：URAM byte-enable TDP，综合/仿真行为完全一致。
// 总读延迟 = NBPIPE + 2 = RD_LATENCY 拍（NBPIPE = RD_LATENCY - 2）。
//
// Port A : VPU 内部读写（im2col / qa / dqa / mp / us / ad）
// Port B : AXI BRAM Controller 读写（CDMA / XDMA 搬运）
// ============================================================================

module vpu_buf (
    input clk,
    // Port A (VPU internal R/W)
    input  [`DCIM_BUF_NUM_COL-1:0]    wea,
    input                              mem_ena,
    input  [`DCIM_BUF_DATA_WIDTH-1:0] dina,
    input  [`VPU_BUF_ADDR_WIDTH-1:0]  addra,
    output [`DCIM_BUF_DATA_WIDTH-1:0] douta,
    output wire                        douta_valid,
    // Port B (AXI BRAM Controller R/W)
    input  [`DCIM_BUF_NUM_COL-1:0]    web,
    input                              mem_enb,
    input  [`DCIM_BUF_DATA_WIDTH-1:0] dinb,
    input  [`VPU_BUF_ADDR_WIDTH-1:0]  addrb,
    output [`DCIM_BUF_DATA_WIDTH-1:0] doutb
);

    localparam DATA_WIDTH = `DCIM_BUF_DATA_WIDTH;  // 128
    localparam ADDR_WIDTH = `VPU_BUF_ADDR_WIDTH;   // 19  (8MB / 16B = 512K words)
    localparam NUM_COL    = `DCIM_BUF_NUM_COL;     // 16  (byte-enable)
    localparam RD_LATENCY = `VPU_BUF_AXI_BRAM_READ_LATENCY;  // 10
    localparam NBPIPE     = RD_LATENCY - 2;        // 8  → 总延迟 = 10

    wire wr_en_a = |wea;

    // -----------------------------------------------------------------------
    // URAM byte-enable TDP 实例
    // -----------------------------------------------------------------------
    uram_tdp_bytewrite #(
        .AWIDTH  (ADDR_WIDTH),
        .NUM_COL (NUM_COL),
        .DWIDTH  (DATA_WIDTH),
        .NBPIPE  (NBPIPE)
    ) u_uram (
        .clk    (clk),
        .wea    (wea),    .mem_ena (mem_ena), .dina (dina), .addra (addra), .douta (douta),
        .web    (web),    .mem_enb (mem_enb), .dinb (dinb), .addrb (addrb), .doutb (doutb)
    );

    // -----------------------------------------------------------------------
    // Port A read-valid：read-enable 延迟 RD_LATENCY 拍
    // -----------------------------------------------------------------------
    reg [RD_LATENCY-1:0] rd_valid_pipe_a;

    always @(posedge clk)
        rd_valid_pipe_a <= {rd_valid_pipe_a[RD_LATENCY-2:0], (mem_ena & ~wr_en_a)};

    assign douta_valid = rd_valid_pipe_a[RD_LATENCY-1];

    initial rd_valid_pipe_a = {RD_LATENCY{1'b0}};

endmodule
