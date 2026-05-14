`timescale 1ns / 1ps

// ============================================================================
// DCIM_Array_Group - 8 个 DCIM_Tile 共享 1 组 IBUF/OBUF
// ============================================================================
// 时序优化：将原来 16 Tile 共享改为 8 Tile 共享
// 优点：
//   1. Arbiter 仲裁路数减半（8 路 vs 16 路）
//   2. URAM 容量减半，级联深度更浅
//   3. 更容易约束到单个 SLR 内
// ============================================================================

module DCIM_Array_Group #(
    parameter GROUP_ID       = 0,       // 组 ID，用于 SLR 约束标识
    parameter TILES_PER_GROUP = 8,      // 每组 Tile 数量
    parameter WD1            = 4,
    parameter CH_IN          = 16,
    parameter CH_OUT         = 16,
    parameter SRAM_DP        = 128,
    parameter CYCLE          = 8,
    parameter ACC            = 80,
    parameter BUF_ADDR_WIDTH = 14,
    parameter BUF_DATA_WIDTH = 128,
    parameter IBUF_RD_LATENCY = 8,      // 8 Tile 仲裁延迟
    
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
    // num_rows 端口已移除：在 CNN 应用中 num_rows == acc_depth
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0] wei_base_addrs,
    input  wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0] out_base_addrs,
    
    // 外部 IBUF 接口（Port A: 外部加载数据）
    input  wire [STRB_WIDTH-1:0]         ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     ibuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,
    
    // 外部 OBUF 接口（Port A: 外部读取结果）
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
    wire [BUF_DATA_WIDTH-1:0]     ibuf_int_dout;
    
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
    // 优化：IN_REG=1 打断跨 SLR 路径，NUM_BANKS=2 减少级联深度
    ibuf #(
        .AWIDTH(BUF_ADDR_WIDTH),
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
        .doutb(ibuf_int_dout)
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
