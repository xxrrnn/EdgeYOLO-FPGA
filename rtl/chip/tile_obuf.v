`timescale 1ns / 1ns
`include "chip_defines.vh"

// ============================================================================
// tile_obuf.v  —  Per-Tile Output Buffer  256KB  (chip-v3 lite)
// ============================================================================
// 使用 uram_tdp_bytewrite：URAM byte-enable TDP，综合/仿真行为完全一致。
// 总读延迟 = NBPIPE + 2 = RD_LATENCY 拍。
//
// Port A : CDMA/VPU/AXI 读取（后处理：DQA、QA 等）
// Port B : DCIM Tile 写入累加结果（byte-enable，支持非整字写）
// ============================================================================

module tile_obuf (
    input clk,
    // Port A (CDMA/AXI read, optional write)
    input  [`DCIM_BUF_NUM_COL-1:0]         wea,
    input                                   mem_ena,
    input  [`DCIM_BUF_DATA_WIDTH-1:0]       dina,
    input  [`DCIM_TILE_OBUF_ADDR_WIDTH-1:0] addra,
    output [`DCIM_BUF_DATA_WIDTH-1:0]       douta,
    output wire                              douta_valid,
    // Port B (Tile write — write only)
    input  [`DCIM_BUF_NUM_COL-1:0]         web,
    input                                   mem_enb,
    input  [`DCIM_BUF_DATA_WIDTH-1:0]       dinb,
    input  [`DCIM_TILE_OBUF_ADDR_WIDTH-1:0] addrb
);

    localparam DATA_WIDTH = `DCIM_BUF_DATA_WIDTH;           // 128
    localparam ADDR_WIDTH = `DCIM_TILE_OBUF_ADDR_WIDTH;     // 14  (256KB / 16B = 16K words)
    localparam NUM_COL    = `DCIM_BUF_NUM_COL;              // 16
    localparam RD_LATENCY = `DCIM_TILE_OBUF_RD_LATENCY;    // 10
    localparam NBPIPE     = RD_LATENCY - 2;                 // 8

    wire wr_en_a = |wea;

    // -----------------------------------------------------------------------
    // URAM byte-enable TDP 实例（Port B doutb 悬空，无读需求）
    // -----------------------------------------------------------------------
    wire [`DCIM_BUF_DATA_WIDTH-1:0] doutb_nc;  // Port B doutb 不使用

    uram_tdp_bytewrite #(
        .AWIDTH  (ADDR_WIDTH),
        .NUM_COL (NUM_COL),
        .DWIDTH  (DATA_WIDTH),
        .NBPIPE  (NBPIPE)
    ) u_uram (
        .clk    (clk),
        .wea    (wea),        .mem_ena (mem_ena), .dina (dina), .addra (addra), .douta (douta),
        .web    (web),        .mem_enb (mem_enb), .dinb (dinb), .addrb (addrb), .doutb (doutb_nc)
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
