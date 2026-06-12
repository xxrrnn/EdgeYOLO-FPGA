`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// tile_ibuf.v  —  Per-Tile Input Buffer  512KB  (chip-v3 lite)
// ============================================================================
// 使用 uram_tdp_bytewrite：URAM byte-enable TDP，综合/仿真行为完全一致。
// 总读延迟 = NBPIPE + 2 = RD_LATENCY 拍。
//
// Port A : CDMA/XDMA 写入 + 读取验证
// Port B : Tile 内部读取激活数据（只读，web 由 Tile 内部逻辑保持为 0）
// ============================================================================

module tile_ibuf (
    input clk,
    // Port A (CDMA/XDMA write + read)
    input  [`DCIM_BUF_NUM_COL-1:0]         wea,
    input                                   mem_ena,
    input  [`DCIM_BUF_DATA_WIDTH-1:0]       dina,
    input  [`DCIM_TILE_IBUF_ADDR_WIDTH-1:0] addra,
    output [`DCIM_BUF_DATA_WIDTH-1:0]       douta,
    output wire                              douta_valid,
    // Port B (Tile internal read)
    input  [`DCIM_BUF_NUM_COL-1:0]         web,
    input                                   mem_enb,
    input  [`DCIM_BUF_DATA_WIDTH-1:0]       dinb,
    input  [`DCIM_TILE_IBUF_ADDR_WIDTH-1:0] addrb,
    output [`DCIM_BUF_DATA_WIDTH-1:0]       doutb,
    output wire                              doutb_valid
);

    localparam DATA_WIDTH = `DCIM_BUF_DATA_WIDTH;           // 128
    localparam ADDR_WIDTH = `DCIM_TILE_IBUF_ADDR_WIDTH;     // 15  (512KB / 16B = 32K words)
    localparam NUM_COL    = `DCIM_BUF_NUM_COL;              // 16
    localparam RD_LATENCY = `DCIM_TILE_IBUF_RD_LATENCY;    // 10
    localparam NBPIPE     = RD_LATENCY - 2;                 // 8

    wire wr_en_a = |wea;
    wire wr_en_b = |web;

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
    // Port A/B read-valid：read-enable 延迟 RD_LATENCY 拍
    // -----------------------------------------------------------------------
    reg [RD_LATENCY-1:0] rd_valid_pipe_a;
    reg [RD_LATENCY-1:0] rd_valid_pipe_b;

    always @(posedge clk) begin
        rd_valid_pipe_a <= {rd_valid_pipe_a[RD_LATENCY-2:0], (mem_ena & ~wr_en_a)};
        rd_valid_pipe_b <= {rd_valid_pipe_b[RD_LATENCY-2:0], (mem_enb & ~wr_en_b)};
    end

    assign douta_valid = rd_valid_pipe_a[RD_LATENCY-1];
    assign doutb_valid = rd_valid_pipe_b[RD_LATENCY-1];

    initial begin
        rd_valid_pipe_a = {RD_LATENCY{1'b0}};
        rd_valid_pipe_b = {RD_LATENCY{1'b0}};
    end

endmodule
