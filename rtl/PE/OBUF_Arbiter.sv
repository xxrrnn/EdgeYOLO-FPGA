`timescale 1ns / 1ps

// ============================================================================
// OBUF_Arbiter - 多 Tile OBUF 写入优先级仲裁器
// ============================================================================
//
// 功能：仲裁多个 Tile 对共享 OBUF 的写入请求
//       采用固定优先级仲裁，Tile 0 优先级最高
//
// 参数：
//   - NUM_TILES: Tile 数量（默认 8）
//   - ADDR_WIDTH: OBUF 地址位宽
//   - DATA_WIDTH: OBUF 数据位宽
//
// ============================================================================

module OBUF_Arbiter #(
    parameter NUM_TILES  = 8,
    parameter ADDR_WIDTH = 12,
    parameter DATA_WIDTH = 128
)(
    input  wire                              clk,
    input  wire                              rst_n,
    
    // Tile 写请求接口（NUM_TILES 个）
    input  wire [NUM_TILES-1:0]              tile_wr_req,      // 写请求
    input  wire [NUM_TILES*ADDR_WIDTH-1:0]   tile_wr_addr,     // 写地址
    input  wire [NUM_TILES*DATA_WIDTH-1:0]   tile_wr_data,     // 写数据
    input  wire [NUM_TILES*(DATA_WIDTH/8)-1:0] tile_wr_be,     // 字节使能
    output wire [NUM_TILES-1:0]              tile_wr_grant,    // 写授权
    
    // OBUF 写接口
    output reg                               obuf_wr_en,
    output reg  [ADDR_WIDTH-1:0]             obuf_wr_addr,
    output reg  [DATA_WIDTH-1:0]             obuf_wr_data,
    output reg  [DATA_WIDTH/8-1:0]           obuf_wr_be
);

    localparam BE_WIDTH = DATA_WIDTH / 8;
    
    // ========================================================================
    // 固定优先级仲裁：Tile 0 优先级最高
    // ========================================================================
    
    reg [NUM_TILES-1:0] grant_reg;
    
    // 优先级编码器：找到最高优先级的请求
    always_comb begin
        integer i1;
        grant_reg = {NUM_TILES{1'b0}};
        for (i1 = NUM_TILES - 1; i1 >= 0; i1 = i1 - 1) begin
            if (tile_wr_req[i1]) begin
                grant_reg = {NUM_TILES{1'b0}};
                grant_reg[i1] = 1'b1;
            end
        end
    end
    
    assign tile_wr_grant = grant_reg;
    
    // ========================================================================
    // 输出多路选择器
    // ========================================================================
    
    // 找到被授权的 Tile 索引
    reg [$clog2(NUM_TILES)-1:0] granted_idx;
    reg                          any_grant;
    
    always_comb begin
        integer i2;
        granted_idx = 0;
        any_grant = 1'b0;
        for (i2 = 0; i2 < NUM_TILES; i2 = i2 + 1) begin
            if (grant_reg[i2]) begin
                granted_idx = i2[$clog2(NUM_TILES)-1:0];
                any_grant = 1'b1;
            end
        end
    end
    
    // 输出寄存器（单周期延迟，提高时序）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            obuf_wr_en   <= 1'b0;
            obuf_wr_addr <= {ADDR_WIDTH{1'b0}};
            obuf_wr_data <= {DATA_WIDTH{1'b0}};
            obuf_wr_be   <= {BE_WIDTH{1'b0}};
        end else begin
            obuf_wr_en <= any_grant;
            if (any_grant) begin
                obuf_wr_addr <= tile_wr_addr[granted_idx*ADDR_WIDTH +: ADDR_WIDTH];
                obuf_wr_data <= tile_wr_data[granted_idx*DATA_WIDTH +: DATA_WIDTH];
                obuf_wr_be   <= tile_wr_be[granted_idx*BE_WIDTH +: BE_WIDTH];
            end
        end
    end

endmodule
