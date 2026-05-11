`timescale 1ns / 1ps

// ============================================================================
// PE_Array - 多 Tile 并行计算阵列
// ============================================================================
//
// 功能：实例化多个 DCIM_Tile，共享 IBUF（激活+权重）和 OBUF
//
// 架构：
//   - NUM_TILES 个 DCIM_Tile 并行
//   - 共享 IBUF：轮询仲裁读取
//   - 共享 OBUF：优先级仲裁写入
//   - Weight Stationary 数据流
//
// 关键设计：
//   - 权重加载阶段：轮询仲裁，每个 Tile 依次加载
//   - 激活读取阶段：所有 Tile 同步读取相同地址，广播数据
//
// ============================================================================

`include "para.v"

module PE_Array #(
    parameter NUM_TILES = 8,
    parameter WD1       = 4,
    parameter CH_IN     = 16,
    parameter CH_OUT    = 16,
    parameter SRAM_DP   = 128,
    parameter CYCLE     = 8,
    parameter ACC       = 80,
    
    parameter BUF_ADDR_WIDTH = 14,
    parameter BUF_DATA_WIDTH = 128,
    parameter WEIGHT_TILE_SIZE = 8,
    
    localparam ACC_UBD_WD = $clog2(ACC+1)
)(
    input  wire                          clk,
    input  wire                          rst_n,
    
    input  wire                          start,
    output wire                          done,
    output wire                          ready,
    output wire [NUM_TILES-1:0]          tile_done,
    output wire [NUM_TILES-1:0]          tile_ready,
    
    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [15:0]                   num_rows,
    
    input  wire [BUF_ADDR_WIDTH-1:0]     wei_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     out_base_addr,
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_out_offset,
    
    input  wire [BUF_DATA_WIDTH/8-1:0]   ibuf_wea,
    input  wire [BUF_ADDR_WIDTH-1:0]     ibuf_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_dina,
    input  wire                          ibuf_ena,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_douta,
    
    input  wire [BUF_DATA_WIDTH/8-1:0]   obuf_wea,
    input  wire [BUF_ADDR_WIDTH-1:0]     obuf_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_dina,
    input  wire                          obuf_ena,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_douta
);

    // ========================================================================
    // 内部信号
    // ========================================================================
    
    // Tile IBUF 读请求
    wire [NUM_TILES-1:0]                     tile_ibuf_rd_en;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]      tile_ibuf_rd_addr;
    
    // Tile OBUF 写请求
    wire [NUM_TILES-1:0]                     tile_obuf_wr_req;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]      tile_obuf_wr_addr;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]      tile_obuf_wr_data;
    wire [NUM_TILES*(BUF_DATA_WIDTH/8)-1:0]  tile_obuf_wr_be;
    wire [NUM_TILES-1:0]                     tile_obuf_wr_grant;
    
    // IBUF 内部读接口
    reg  [BUF_ADDR_WIDTH-1:0]    ibuf_addrb;
    reg                          ibuf_enb;
    wire [BUF_DATA_WIDTH-1:0]    ibuf_doutb;
    
    // OBUF 内部写接口
    wire                         obuf_wr_en;
    wire [BUF_ADDR_WIDTH-1:0]    obuf_wr_addr;
    wire [BUF_DATA_WIDTH-1:0]    obuf_wr_data;
    wire [BUF_DATA_WIDTH/8-1:0]  obuf_wr_be;
    
    // ========================================================================
    // IBUF 读仲裁（轮询仲裁）
    // ========================================================================
    
    reg [$clog2(NUM_TILES)-1:0] rr_ptr;  // 轮询指针
    reg [NUM_TILES-1:0] ibuf_rd_grant;
    reg [$clog2(NUM_TILES)-1:0] ibuf_granted_idx;
    reg ibuf_any_grant;
    
    // 轮询仲裁逻辑
    always_comb begin
        integer i, j;
        ibuf_rd_grant = {NUM_TILES{1'b0}};
        ibuf_granted_idx = 0;
        ibuf_any_grant = 1'b0;
        
        // 从 rr_ptr 开始轮询
        for (i = 0; i < NUM_TILES; i = i + 1) begin
            j = (rr_ptr + i) % NUM_TILES;
            if (tile_ibuf_rd_en[j] && !ibuf_any_grant) begin
                ibuf_rd_grant[j] = 1'b1;
                ibuf_granted_idx = j[$clog2(NUM_TILES)-1:0];
                ibuf_any_grant = 1'b1;
            end
        end
    end
    
    // 更新轮询指针
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr <= 0;
        end else if (ibuf_any_grant) begin
            rr_ptr <= (ibuf_granted_idx + 1) % NUM_TILES;
        end
    end
    
    // IBUF 读地址选择
    always_comb begin
        ibuf_enb = ibuf_any_grant;
        ibuf_addrb = tile_ibuf_rd_addr[ibuf_granted_idx*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH];
    end
    
    // ========================================================================
    // Tile 实例化
    // ========================================================================
    
    genvar gi;
    generate
        for (gi = 0; gi < NUM_TILES; gi = gi + 1) begin : gen_tiles
            
            wire [BUF_ADDR_WIDTH-1:0] tile_wei_base = wei_base_addr + gi * WEIGHT_TILE_SIZE;
            wire [BUF_ADDR_WIDTH-1:0] tile_out_base = out_base_addr + 
                tile_out_offset[gi*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH];
            
            // 每个 Tile 只有在获得授权时才能使用 IBUF 数据
            wire tile_ibuf_data_valid = ibuf_rd_grant[gi];
            
            DCIM_Tile #(
                .TILE_ID(gi),
                .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
                .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC),
                .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH), .BUF_DATA_WIDTH(BUF_DATA_WIDTH)
            ) u_tile (
                .clk(clk), .rst_n(rst_n),
                .start(start),
                .done(tile_done[gi]),
                .ready(tile_ready[gi]),
                .mode(mode), .acc_depth(acc_depth), .num_rows(num_rows),
                .wei_base_addr(tile_wei_base),
                .act_base_addr(act_base_addr),
                .out_base_addr(tile_out_base),
                .ibuf_rd_addr(tile_ibuf_rd_addr[gi*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_rd_en(tile_ibuf_rd_en[gi]),
                .ibuf_rd_data(ibuf_doutb),
                .ibuf_rd_grant(ibuf_rd_grant[gi]),  // 新增：授权信号
                .obuf_wr_req(tile_obuf_wr_req[gi]),
                .obuf_wr_addr(tile_obuf_wr_addr[gi*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .obuf_wr_data(tile_obuf_wr_data[gi*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .obuf_wr_be(tile_obuf_wr_be[gi*(BUF_DATA_WIDTH/8) +: (BUF_DATA_WIDTH/8)]),
                .obuf_wr_grant(tile_obuf_wr_grant[gi])
            );
        end
    endgenerate
    
    // ========================================================================
    // 全局状态（锁存每个 Tile 的完成状态）
    // ========================================================================
    
    reg [NUM_TILES-1:0] tile_done_latch;
    wire all_tiles_done = &tile_done_latch;
    
    // 锁存 done 信号
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tile_done_latch <= {NUM_TILES{1'b0}};
        end else if (ready && !start) begin
            // 当所有 Tile 都回到 IDLE 且 start 为低时，清除锁存
            tile_done_latch <= {NUM_TILES{1'b0}};
        end else begin
            // 锁存每个 Tile 的 done 信号
            tile_done_latch <= tile_done_latch | tile_done;
        end
    end
    
    assign ready = &tile_ready;
    assign done  = all_tiles_done;
    
    // ========================================================================
    // OBUF 仲裁器
    // ========================================================================
    
    OBUF_Arbiter #(
        .NUM_TILES(NUM_TILES),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_obuf_arbiter (
        .clk(clk), .rst_n(rst_n),
        .tile_wr_req(tile_obuf_wr_req),
        .tile_wr_addr(tile_obuf_wr_addr),
        .tile_wr_data(tile_obuf_wr_data),
        .tile_wr_be(tile_obuf_wr_be),
        .tile_wr_grant(tile_obuf_wr_grant),
        .obuf_wr_en(obuf_wr_en),
        .obuf_wr_addr(obuf_wr_addr),
        .obuf_wr_data(obuf_wr_data),
        .obuf_wr_be(obuf_wr_be)
    );
    
    // ========================================================================
    // 共享 IBUF
    // ========================================================================
    
    ibuf #(
        .AWIDTH(BUF_ADDR_WIDTH),
        .NUM_COL(BUF_DATA_WIDTH/8),
        .DWIDTH(BUF_DATA_WIDTH),
        .NBPIPE(1)
    ) u_ibuf (
        .clk(clk),
        .wea(ibuf_wea), .mem_ena(ibuf_ena), .dina(ibuf_dina),
        .addra(ibuf_addra), .douta(ibuf_douta),
        .web({(BUF_DATA_WIDTH/8){1'b0}}), .mem_enb(ibuf_enb),
        .dinb({BUF_DATA_WIDTH{1'b0}}), .addrb(ibuf_addrb), .doutb(ibuf_doutb)
    );
    
    // ========================================================================
    // 共享 OBUF
    // ========================================================================
    
    obuf #(
        .AWIDTH(BUF_ADDR_WIDTH),
        .NUM_COL(BUF_DATA_WIDTH/8),
        .DWIDTH(BUF_DATA_WIDTH),
        .NBPIPE(1)
    ) u_obuf (
        .clk(clk),
        .wea(obuf_wea), .mem_ena(obuf_ena), .dina(obuf_dina),
        .addra(obuf_addra), .douta(obuf_douta),
        .web(obuf_wr_en ? obuf_wr_be : {(BUF_DATA_WIDTH/8){1'b0}}),
        .mem_enb(obuf_wr_en), .dinb(obuf_wr_data), .addrb(obuf_wr_addr), .doutb()
    );

endmodule
