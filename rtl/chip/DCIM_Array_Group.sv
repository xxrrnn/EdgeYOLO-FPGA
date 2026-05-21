`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array_Group - 8 个 DCIM_Tile 共享 1 组 IBUF/OBUF
// ============================================================================
// 改造说明（共用大IBUF）：
//   - act_base_addr：全局广播，由 DCIM_Array 顶层传入同一个值
//   - IBUF 外部写接口（Port A）：各组接收相同的广播写入信号
//     （软件写一次，硬件同时写入所有组的 IBUF，内容完全相同）
//   - OBUF 保持各组独立（每组 Tile 输出通道不同）
//   - 时序：IBUF 物理仍在各组本地，读延迟不变（8 Tile 仲裁）
// ============================================================================

module DCIM_Array_Group #(
    parameter GROUP_ID        = 0,
    parameter TILES_PER_GROUP = `DCIM_TILES_PER_GROUP,
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
    
    // 控制接口
    input  wire                          start,
    output wire                          done,
    output wire                          ready,
    
    // 配置接口
    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    // act_base_addr：全局广播，所有组使用同一激活基址
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0] wei_base_addrs,
    input  wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0] out_base_addrs,
    
    // 外部 IBUF 接口（Port A: 广播写入，所有组接收相同数据）
    // 软件只需发起一次写操作，由顶层将信号广播到所有 Group
    input  wire [STRB_WIDTH-1:0]         ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     ibuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,
    
    // 外部 OBUF 接口（Port A: 外部读取结果，各组独立）
    input  wire [STRB_WIDTH-1:0]         obuf_ext_wea,
    input  wire                          obuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     obuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_ext_douta
);

    // ========================================================================
    // Tile 控制信号
    // ========================================================================
    wire [TILES_PER_GROUP-1:0] tile_done;
    wire [TILES_PER_GROUP-1:0] tile_ready;
    
    assign done  = &tile_done;
    assign ready = &tile_ready;
    
    // ========================================================================
    // Tile <-> IBUF Arbiter 连线
    // ========================================================================
    wire [TILES_PER_GROUP-1:0]                     tile_ibuf_rd_valid;
    wire [TILES_PER_GROUP-1:0]                     tile_ibuf_rd_ready;
    wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0]      tile_ibuf_rd_addr;
    wire [TILES_PER_GROUP-1:0]                     tile_ibuf_rd_data_valid;
    wire [BUF_DATA_WIDTH-1:0]                      tile_ibuf_rd_data;
    
    // ========================================================================
    // Tile <-> OBUF Arbiter 连线
    // ========================================================================
    wire [TILES_PER_GROUP-1:0]                     tile_obuf_wr_valid;
    wire [TILES_PER_GROUP-1:0]                     tile_obuf_wr_ready;
    wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0]      tile_obuf_wr_addr;
    wire [TILES_PER_GROUP*BUF_DATA_WIDTH-1:0]      tile_obuf_wr_data;
    wire [TILES_PER_GROUP*STRB_WIDTH-1:0]          tile_obuf_wr_strb;
    
    // ========================================================================
    // Arbiter <-> IBUF/OBUF 连线
    // ========================================================================
    wire                          ibuf_int_en;
    wire [BUF_ADDR_WIDTH-1:0]     ibuf_int_addr;
    wire [BUF_DATA_WIDTH-1:0]     ibuf_int_dout_raw;  // URAM 原始输出
    
    // SLR 跨越寄存器：IBUF(URAM) 输出 → Tile 的数据路径
    // URAM 物理在某个 SLR，Tile 可能在不同 SLR，加 1 级 FF 打断跨 SLR 走线
    (* shreg_extract = "no" *) reg [BUF_DATA_WIDTH-1:0] ibuf_int_dout;
    always @(posedge clk) begin
        ibuf_int_dout <= ibuf_int_dout_raw;
    end
    
    wire                          obuf_int_en;
    wire [STRB_WIDTH-1:0]         obuf_int_we;
    wire [BUF_ADDR_WIDTH-1:0]     obuf_int_addr;
    wire [BUF_DATA_WIDTH-1:0]     obuf_int_din;
    
    // ========================================================================
    // 实例化 8 个 DCIM_Tile
    // ========================================================================
    generate
        genvar i;
        for (i = 0; i < TILES_PER_GROUP; i = i + 1) begin : gen_tiles
            DCIM_Tile #(
                .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
                .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC),
                .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH), .BUF_DATA_WIDTH(BUF_DATA_WIDTH)
            ) u_tile (
                .clk(clk), .rst_n(rst_n),
                .start(start),
                .done(tile_done[i]),
                .ready(tile_ready[i]),
                .mode(mode),
                .acc_depth(acc_depth),
                // num_rows 端口已移除：在 CNN 应用中 num_rows == acc_depth
                .wei_base_addr(wei_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .act_base_addr(act_base_addr),
                .out_base_addr(out_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                // IBUF read
                .ibuf_rd_valid(tile_ibuf_rd_valid[i]),
                .ibuf_rd_ready(tile_ibuf_rd_ready[i]),
                .ibuf_rd_addr(tile_ibuf_rd_addr[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_rd_data_valid(tile_ibuf_rd_data_valid[i]),
                .ibuf_rd_data(tile_ibuf_rd_data),
                // OBUF write
                .obuf_wr_valid(tile_obuf_wr_valid[i]),
                .obuf_wr_ready(tile_obuf_wr_ready[i]),
                .obuf_wr_addr(tile_obuf_wr_addr[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .obuf_wr_data(tile_obuf_wr_data[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .obuf_wr_strb(tile_obuf_wr_strb[i*STRB_WIDTH +: STRB_WIDTH])
            );
        end
    endgenerate
    
    // ========================================================================
    // IBUF 读仲裁器（8 路）
    // ========================================================================
    ibuf_rd_arbiter #(
        .NUM_TILES(TILES_PER_GROUP),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH),
        .IBUF_RD_LATENCY(IBUF_RD_LATENCY)
    ) u_ibuf_arb (
        .clk(clk), .rst_n(rst_n),
        .tile_rd_valid(tile_ibuf_rd_valid),
        .tile_rd_ready(tile_ibuf_rd_ready),
        .tile_rd_addr(tile_ibuf_rd_addr),
        .tile_rd_data_valid(tile_ibuf_rd_data_valid),
        .tile_rd_data(tile_ibuf_rd_data),
        .ibuf_en(ibuf_int_en),
        .ibuf_addr(ibuf_int_addr),
        .ibuf_dout(ibuf_int_dout)
    );
    
    // ========================================================================
    // OBUF 写仲裁器（8 路）
    // ========================================================================
    obuf_wr_arbiter #(
        .NUM_TILES(TILES_PER_GROUP),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_obuf_arb (
        .clk(clk), .rst_n(rst_n),
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
    
    // ========================================================================
    // IBUF 实例
    // ========================================================================
    // 每组独立的 IBUF，容量为原来的 1/8
    // 修复：IBUF 用实际需要的 IBUF_ADDR_WIDTH(17)，不用 OBUF 的 20-bit
    ibuf #(
        .AWIDTH(`DCIM_IBUF_ADDR_WIDTH),
        .NUM_COL(BUF_DATA_WIDTH/8),
        .DWIDTH(BUF_DATA_WIDTH),
        .NBPIPE(2),
        .NUM_BANKS(2),      // 每组容量小，2 bank 足够
        .IN_REG(1)
    ) u_ibuf (
        .clk(clk),
        .wea(ibuf_ext_wea),
        .mem_ena(ibuf_ext_ena),
        .dina(ibuf_ext_dina),
        .addra(ibuf_ext_addra),
        .douta(ibuf_ext_douta),
        .web({STRB_WIDTH{1'b0}}),
        .mem_enb(ibuf_int_en),
        .dinb({BUF_DATA_WIDTH{1'b0}}),
        .addrb(ibuf_int_addr),
        .doutb(ibuf_int_dout_raw)
    );
    
    // ========================================================================
    // OBUF 实例
    // ========================================================================
    obuf #(
        .AWIDTH(BUF_ADDR_WIDTH),
        .NUM_COL(BUF_DATA_WIDTH/8),
        .DWIDTH(BUF_DATA_WIDTH),
        .NBPIPE(2),
        .NUM_BANKS(2)       // 每组容量小，2 bank 足够
    ) u_obuf (
        .clk(clk),
        .wea(obuf_ext_wea),
        .mem_ena(obuf_ext_ena),
        .dina(obuf_ext_dina),
        .addra(obuf_ext_addra),
        .douta(obuf_ext_douta),
        .web(obuf_int_we),
        .mem_enb(obuf_int_en),
        .dinb(obuf_int_din),
        .addrb(obuf_int_addr),
        .doutb()
    );

endmodule
