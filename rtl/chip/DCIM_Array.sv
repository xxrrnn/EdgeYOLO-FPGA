`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array - Tile-Array 结构 (chip-v2)
// ============================================================================
// chip-v2 变更：
//   - 删除共享 OBUF 和 obuf_wr_arbiter
//   - 每 Tile 内置 tile_obuf（256KB），Tile 直写，零仲裁延迟
//   - tile_obuf Port A 暴露给外部（CDMA 读取 Tile 结果）
//   - VPU 使用独立 vpu_buf（在 Global_VPU_top 中实例化）
// ============================================================================

module DCIM_Array #(
    parameter NUM_TILES       = `DCIM_NUM_TILES,
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter SRAM_DP         = `DCIM_SRAM_DP,
    parameter CYCLE           = `DCIM_CYCLE,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH  = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,
    parameter TILE_OBUF_ADDR_WIDTH = `DCIM_TILE_OBUF_ADDR_WIDTH,

    localparam ACC_UBD_WD = $clog2(ACC+1),
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire                          start,
    output wire                          done,
    output wire                          ready,

    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] wei_base_addrs,
    input  wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] out_base_addrs,
    input  wire [NUM_TILES-1:0]          tile_mask,

    // IBUF 外部端口（XDMA/CDMA 写入 IBUF）
    input  wire [STRB_WIDTH-1:0]         ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     ibuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,

    // tile_obuf[0..3] 外部端口（CDMA 读取 Tile 结果）
    input  wire [NUM_TILES*STRB_WIDTH-1:0]              tile_obuf_ext_wea,
    input  wire [NUM_TILES-1:0]                         tile_obuf_ext_ena,
    input  wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0]    tile_obuf_ext_addra,
    input  wire [NUM_TILES*BUF_DATA_WIDTH-1:0]          tile_obuf_ext_dina,
    output wire [NUM_TILES*BUF_DATA_WIDTH-1:0]          tile_obuf_ext_douta,
    output wire [NUM_TILES-1:0]                         tile_obuf_ext_douta_valid
);

    wire [NUM_TILES-1:0] tile_done;
    wire [NUM_TILES-1:0] tile_ready;

    // -----------------------------------------------------------------------
    // SLR 穿越流水寄存器（ready 上行 + start 下行）
    // -----------------------------------------------------------------------
    (* shreg_extract = "no", KEEP = "TRUE" *) reg ready_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ready_r <= 1'b1;
        else        ready_r <= &tile_ready;
    end

    (* shreg_extract = "no", KEEP = "TRUE" *) reg start_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_r <= 1'b0;
        else        start_r <= start;
    end

    assign done  = &(tile_done | ~tile_mask);
    assign ready = ready_r;

    // -----------------------------------------------------------------------
    // IBUF 仲裁（保留不变：所有 Tile 共享 IBUF 读取）
    // -----------------------------------------------------------------------
    wire [NUM_TILES-1:0]                tile_ibuf_rd_valid;
    wire [NUM_TILES-1:0]                tile_ibuf_rd_ready;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_ibuf_rd_addr;
    wire [NUM_TILES-1:0]                tile_ibuf_rd_data_valid;
    wire [BUF_DATA_WIDTH-1:0]           tile_ibuf_rd_data;

    wire                          ibuf_int_en;
    wire [BUF_ADDR_WIDTH-1:0]     ibuf_int_addr;
    wire [BUF_DATA_WIDTH-1:0]     ibuf_int_dout_raw;
    (* shreg_extract = "no", max_fanout = 32 *) reg [BUF_DATA_WIDTH-1:0] ibuf_int_dout;

    always @(posedge clk) begin
        ibuf_int_dout <= ibuf_int_dout_raw;
    end

    // -----------------------------------------------------------------------
    // Tile + tile_obuf 实例化
    // -----------------------------------------------------------------------
    // Tile 写 tile_obuf：直连，无仲裁器
    wire [NUM_TILES-1:0]                tile_obuf_wr_valid;
    wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] tile_obuf_wr_addr;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_obuf_wr_data;
    wire [NUM_TILES*STRB_WIDTH-1:0]     tile_obuf_wr_strb;

    generate
        genvar i;
        for (i = 0; i < NUM_TILES; i = i + 1) begin : gen_tiles
            localparam TILE_IS_SOLO = (i == 0 || i == 3) ? 1 : 0;
            localparam TILE_DSP_COL = TILE_IS_SOLO ? `DCIM_DSP_COL_SOLO : `DCIM_DSP_COL_SHARED;
            localparam TILE_DSP_PARTIAL = TILE_IS_SOLO ? `DCIM_DSP_PARTIAL_SOLO : `DCIM_DSP_PARTIAL_SHARED;

            // Tile 写信号
            wire                          t_wr_valid;
            wire [BUF_ADDR_WIDTH-1:0]     t_wr_addr_full;
            wire [BUF_DATA_WIDTH-1:0]     t_wr_data;
            wire [STRB_WIDTH-1:0]         t_wr_strb;

            assign tile_obuf_wr_valid[i] = t_wr_valid;
            assign tile_obuf_wr_addr[i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH] = t_wr_addr_full[TILE_OBUF_ADDR_WIDTH-1:0];
            assign tile_obuf_wr_data[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = t_wr_data;
            assign tile_obuf_wr_strb[i*STRB_WIDTH +: STRB_WIDTH] = t_wr_strb;

            (* keep_hierarchy = "yes" *)
            DCIM_Tile #(
                .WD1(WD1),
                .CH_IN(CH_IN),
                .CH_OUT(CH_OUT),
                .SRAM_DP(SRAM_DP),
                .CYCLE(CYCLE),
                .ACC(ACC),
                .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
                .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
                .TILE_IDX(i),
                .MULT_DSP_EN(1),
                .DSP_COL_NUM(TILE_DSP_COL),
                .DSP_PARTIAL_SUBCOL(TILE_DSP_PARTIAL)
            ) u_tile (
                .clk(clk),
                .rst_n(rst_n),
                .start(start_r),
                .tile_enable(tile_mask[i]),
                .done(tile_done[i]),
                .ready(tile_ready[i]),
                .mode(mode),
                .acc_depth(acc_depth),
                .wei_base_addr(wei_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .act_base_addr(act_base_addr),
                .out_base_addr({{(BUF_ADDR_WIDTH-TILE_OBUF_ADDR_WIDTH){1'b0}}, out_base_addrs[i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH]}),
                .ibuf_rd_valid(tile_ibuf_rd_valid[i]),
                .ibuf_rd_ready(tile_ibuf_rd_ready[i]),
                .ibuf_rd_addr(tile_ibuf_rd_addr[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_rd_data_valid(tile_ibuf_rd_data_valid[i]),
                .ibuf_rd_data(tile_ibuf_rd_data),
                .obuf_wr_valid(t_wr_valid),
                .obuf_wr_ready(1'b1),
                .obuf_wr_addr(t_wr_addr_full),
                .obuf_wr_data(t_wr_data),
                .obuf_wr_strb(t_wr_strb)
            );

            // Per-tile tile_obuf 实例
            tile_obuf u_tile_obuf (
                .clk(clk),
                // Port A: 外部 CDMA 读/写
                .wea(tile_obuf_ext_wea[i*STRB_WIDTH +: STRB_WIDTH]),
                .mem_ena(tile_obuf_ext_ena[i]),
                .dina(tile_obuf_ext_dina[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .addra(tile_obuf_ext_addra[i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH]),
                .douta(tile_obuf_ext_douta[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .douta_valid(tile_obuf_ext_douta_valid[i]),
                // Port B: Tile 写入（直连，无仲裁）
                .web(t_wr_strb),
                .mem_enb(t_wr_valid),
                .dinb(t_wr_data),
                .addrb(t_wr_addr_full[TILE_OBUF_ADDR_WIDTH-1:0])
            );
        end
    endgenerate

    // -----------------------------------------------------------------------
    // IBUF 仲裁器（保持不变）
    // -----------------------------------------------------------------------
    ibuf_rd_arbiter #(
        .NUM_TILES(NUM_TILES),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_ibuf_arb (
        .clk(clk),
        .rst_n(rst_n),
        .tile_rd_valid(tile_ibuf_rd_valid),
        .tile_rd_ready(tile_ibuf_rd_ready),
        .tile_rd_addr(tile_ibuf_rd_addr),
        .tile_rd_data_valid(tile_ibuf_rd_data_valid),
        .tile_rd_data(tile_ibuf_rd_data),
        .ibuf_en(ibuf_int_en),
        .ibuf_addr(ibuf_int_addr),
        .ibuf_dout(ibuf_int_dout)
    );

    // -----------------------------------------------------------------------
    // IBUF（共享，保留不变）
    // -----------------------------------------------------------------------
    ibuf u_ibuf (
        .clk(clk),
        .wea(ibuf_ext_wea),
        .mem_ena(ibuf_ext_ena),
        .dina(ibuf_ext_dina),
        .addra(ibuf_ext_addra[`DCIM_IBUF_ADDR_WIDTH-1:0]),
        .douta(ibuf_ext_douta),
        .web({STRB_WIDTH{1'b0}}),
        .mem_enb(ibuf_int_en),
        .dinb({BUF_DATA_WIDTH{1'b0}}),
        .addrb(ibuf_int_addr[`DCIM_IBUF_ADDR_WIDTH-1:0]),
        .doutb(ibuf_int_dout_raw)
    );

endmodule
