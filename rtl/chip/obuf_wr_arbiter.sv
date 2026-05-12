`timescale 1ns / 1ps

// ============================================================================
// obuf_wr_arbiter - 参数化 Round-Robin OBUF 写仲裁器
// ============================================================================
// 多个 Tile 共享一个 OBUF 写端口，使用 Round-Robin 策略公平调度。
// 写操作为单周期完成（valid & ready 握手即完成写入）。
// ============================================================================

module obuf_wr_arbiter #(
    parameter NUM_TILES  = 16,
    parameter ADDR_WIDTH = 14,
    parameter DATA_WIDTH = 128
)(
    input  wire                                  clk,
    input  wire                                  rst_n,
    
    // Tile 侧接口 (N 路)
    input  wire [NUM_TILES-1:0]                  tile_wr_valid,
    output wire [NUM_TILES-1:0]                  tile_wr_ready,
    input  wire [NUM_TILES*ADDR_WIDTH-1:0]       tile_wr_addr,
    input  wire [NUM_TILES*DATA_WIDTH-1:0]       tile_wr_data,
    input  wire [NUM_TILES*(DATA_WIDTH/8)-1:0]   tile_wr_strb,
    
    // OBUF 侧接口 (单写端口)
    output reg                                   obuf_en,
    output reg  [DATA_WIDTH/8-1:0]               obuf_we,
    output reg  [ADDR_WIDTH-1:0]                 obuf_addr,
    output reg  [DATA_WIDTH-1:0]                 obuf_din
);

    localparam TILE_IDX_W = (NUM_TILES <= 1) ? 1 : $clog2(NUM_TILES);
    localparam STRB_WIDTH = DATA_WIDTH / 8;
    
    // ========================================================================
    // Round-Robin 优先级指针
    // ========================================================================
    reg [TILE_IDX_W-1:0] rr_ptr;
    
    // ========================================================================
    // 仲裁逻辑：从 rr_ptr 开始找到第一个有效写请求
    // ========================================================================
    reg [TILE_IDX_W-1:0] grant_idx;
    reg                   grant_valid;
     
    always_comb begin
        grant_valid = 1'b0;
        grant_idx = 0;
        for (int i = 0; i < NUM_TILES; i++) begin
            automatic int idx = (rr_ptr + i) % NUM_TILES;
            if (!grant_valid && tile_wr_valid[idx]) begin
                grant_valid = 1'b1;
                grant_idx = idx[TILE_IDX_W-1:0];
            end
        end
    end
    
    // ready 信号：当前周期被选中的 Tile
    generate
        genvar g;
        for (g = 0; g < NUM_TILES; g = g + 1) begin : gen_ready
            assign tile_wr_ready[g] = grant_valid && (grant_idx == g);
        end
    endgenerate
    
    // ========================================================================
    // 写入逻辑：每周期最多服务一个 Tile 的写请求
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rr_ptr <= 0;
            obuf_en <= 0;
            obuf_we <= 0;
            obuf_addr <= 0;
            obuf_din <= 0;
        end else begin
            if (grant_valid) begin
                obuf_en <= 1'b1;
                obuf_we <= tile_wr_strb[grant_idx*STRB_WIDTH +: STRB_WIDTH];
                obuf_addr <= tile_wr_addr[grant_idx*ADDR_WIDTH +: ADDR_WIDTH];
                obuf_din <= tile_wr_data[grant_idx*DATA_WIDTH +: DATA_WIDTH];
                rr_ptr <= grant_idx + 1;
            end else begin
                obuf_en <= 0;
                obuf_we <= 0;
            end
        end
    end

endmodule
