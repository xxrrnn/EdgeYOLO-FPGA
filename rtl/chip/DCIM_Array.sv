`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array - Tile-Array 结构
// ============================================================================
// 当前 lite/chip 目标取消 Group 层：
//   DCIM_Array = NUM_TILES 个 DCIM_Tile + 1 个共享 IBUF + 1 个共享 OBUF
//
// 设计目标：250MHz 时序收敛优先；IBUF/OBUF 访问均通过保守仲裁器串行化，
// 不追求 Tile 间读写吞吐，只保证功能一致和峰值计算阵列规模。
// ============================================================================

module DCIM_Array #(
    parameter NUM_GROUPS      = `DCIM_NUM_GROUPS,
    parameter TILES_PER_GROUP = `DCIM_TILES_PER_GROUP,
    parameter NUM_TILES       = `DCIM_NUM_TILES,
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter SRAM_DP         = `DCIM_SRAM_DP,
    parameter CYCLE           = `DCIM_CYCLE,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH  = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,
    parameter IBUF_RD_LATENCY = `DCIM_IBUF_RD_LATENCY,

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
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] out_base_addrs,
    input  wire [NUM_TILES-1:0]          tile_mask,

    input  wire [STRB_WIDTH-1:0]         ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     ibuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,

    input  wire [STRB_WIDTH-1:0]         obuf_ext_wea,
    input  wire                          obuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     obuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_ext_douta,
    output wire                          obuf_ext_douta_valid
);

    initial begin
        if (NUM_GROUPS != 1) begin
            $error("DCIM_Array tile-array implementation requires NUM_GROUPS=1");
        end
        if (TILES_PER_GROUP != NUM_TILES) begin
            $error("DCIM_Array tile-array expects TILES_PER_GROUP == NUM_TILES");
        end
    end

    wire [NUM_TILES-1:0] tile_done;
    wire [NUM_TILES-1:0] tile_ready;

    assign done  = &(tile_done | ~tile_mask);
    assign ready = &tile_ready;

    wire [NUM_TILES-1:0]                tile_ibuf_rd_valid;
    wire [NUM_TILES-1:0]                tile_ibuf_rd_ready;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_ibuf_rd_addr;
    wire [NUM_TILES-1:0]                tile_ibuf_rd_data_valid;
    wire [BUF_DATA_WIDTH-1:0]           tile_ibuf_rd_data;

    wire [NUM_TILES-1:0]                tile_obuf_wr_valid;
    wire [NUM_TILES-1:0]                tile_obuf_wr_ready;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_obuf_wr_addr;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_obuf_wr_data;
    wire [NUM_TILES*STRB_WIDTH-1:0]     tile_obuf_wr_strb;

    wire                          ibuf_int_en;
    wire [BUF_ADDR_WIDTH-1:0]     ibuf_int_addr;
    wire [BUF_DATA_WIDTH-1:0]     ibuf_int_dout_raw;
    (* shreg_extract = "no" *) reg [BUF_DATA_WIDTH-1:0] ibuf_int_dout;

    always @(posedge clk) begin
        ibuf_int_dout <= ibuf_int_dout_raw;
    end

    wire                          obuf_int_en;
    wire [STRB_WIDTH-1:0]         obuf_int_we;
    wire [BUF_ADDR_WIDTH-1:0]     obuf_int_addr;
    wire [BUF_DATA_WIDTH-1:0]     obuf_int_din;

    generate
        genvar i;
        for (i = 0; i < NUM_TILES; i = i + 1) begin : gen_tiles
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
                .TILE_IDX(i)
            ) u_tile (
                .clk(clk),
                .rst_n(rst_n),
                .start(start),
                .tile_enable(tile_mask[i]),
                .done(tile_done[i]),
                .ready(tile_ready[i]),
                .mode(mode),
                .acc_depth(acc_depth),
                .wei_base_addr(wei_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .act_base_addr(act_base_addr),
                .out_base_addr(out_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_rd_valid(tile_ibuf_rd_valid[i]),
                .ibuf_rd_ready(tile_ibuf_rd_ready[i]),
                .ibuf_rd_addr(tile_ibuf_rd_addr[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_rd_data_valid(tile_ibuf_rd_data_valid[i]),
                .ibuf_rd_data(tile_ibuf_rd_data),
                .obuf_wr_valid(tile_obuf_wr_valid[i]),
                .obuf_wr_ready(tile_obuf_wr_ready[i]),
                .obuf_wr_addr(tile_obuf_wr_addr[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .obuf_wr_data(tile_obuf_wr_data[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .obuf_wr_strb(tile_obuf_wr_strb[i*STRB_WIDTH +: STRB_WIDTH])
            );
        end
    endgenerate

    ibuf_rd_arbiter #(
        .NUM_TILES(NUM_TILES),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH),
        .IBUF_RD_LATENCY(IBUF_RD_LATENCY)
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

    obuf_wr_arbiter #(
        .NUM_TILES(NUM_TILES),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_obuf_arb (
        .clk(clk),
        .rst_n(rst_n),
        .tile_wr_valid(tile_obuf_wr_valid),
        .tile_wr_ready(tile_obuf_wr_ready),
        .tile_wr_addr(tile_obuf_wr_addr),
        .tile_wr_data(tile_obuf_wr_data),
        .tile_wr_strb(tile_obuf_wr_strb),
        .obuf_en(obuf_int_en),
        .obuf_we(obuf_int_we),
        .obuf_addr(obuf_int_addr),
        .obuf_din(obuf_int_din)
    );

    ibuf #(
        .AWIDTH(`DCIM_IBUF_ADDR_WIDTH),
        .NUM_COL(BUF_DATA_WIDTH/8),
        .DWIDTH(BUF_DATA_WIDTH),
        .NBPIPE(`DCIM_IBUF_NBPIPE),
        .NUM_BANKS(`DCIM_IBUF_NUM_BANKS),
        .IN_REG(`DCIM_IBUF_IN_REG)
    ) u_ibuf (
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

    obuf #(
        .AWIDTH(BUF_ADDR_WIDTH),
        .NUM_COL(BUF_DATA_WIDTH/8),
        .DWIDTH(BUF_DATA_WIDTH),
        .NBPIPE(`DCIM_OBUF_NBPIPE),
        .NUM_BANKS(`DCIM_OBUF_NUM_BANKS)
    ) u_obuf (
        .clk(clk),
        .wea(obuf_ext_wea),
        .mem_ena(obuf_ext_ena),
        .dina(obuf_ext_dina),
        .addra(obuf_ext_addra),
        .douta(obuf_ext_douta),
        .douta_valid(obuf_ext_douta_valid),
        .web(obuf_int_we),
        .mem_enb(obuf_int_en),
        .dinb(obuf_int_din),
        .addrb(obuf_int_addr),
        .doutb()
    );

endmodule
