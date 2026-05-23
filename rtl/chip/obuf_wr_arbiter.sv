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
    
    // Forward declaration: tile_wr_ready_reg is used by grant_taken update
    (* max_fanout = 4 *) reg [NUM_TILES-1:0] tile_wr_ready_reg;
    assign tile_wr_ready = tile_wr_ready_reg;
    
    // ========================================================================
    // 仲裁逻辑：从 rr_ptr 开始找到第一个有效写请求
    // 添加流水线寄存器打破组合逻辑链
    // ========================================================================
    (* max_fanout = 8 *) reg [NUM_TILES-1:0] tile_wr_valid_q;
    reg [NUM_TILES-1:0] grant_taken;       // anti-phantom: blocks re-grant for one cycle
    reg [TILE_IDX_W-1:0] grant_idx;
    reg                   grant_valid;
    
    // 第一级：请求锁存 + grant_taken (one-shot per granted tile)
    // grant_taken 记忆"上一拍刚发出过 ready"，下一拍 valid_q 还未来得及反映
    // Tile 已撤的 valid 时，把这一拍的 grant 屏蔽掉，避免幻影 grant。
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tile_wr_valid_q <= 0;
            grant_taken     <= 0;
        end else begin
            tile_wr_valid_q <= tile_wr_valid;
            for (int gg = 0; gg < NUM_TILES; gg++) begin
                grant_taken[gg] <= tile_wr_ready_reg[gg];
            end
        end
    end
     
    // 第二级：仲裁逻辑（grant_taken 屏蔽幻影 grant）
    always_comb begin
        grant_valid = 1'b0;
        grant_idx = 0;
        for (int i = 0; i < NUM_TILES; i++) begin
            automatic int idx = (rr_ptr + i) % NUM_TILES;
            if (!grant_valid && tile_wr_valid_q[idx] && !grant_taken[idx]) begin
                grant_valid = 1'b1;
                grant_idx = idx[TILE_IDX_W-1:0];
            end
        end
    end
    
    // ready 信号：注册减少扇出（声明已前置至文件顶部，这里只放 always 块）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) tile_wr_ready_reg <= 0;
        else begin
            for (int g = 0; g < NUM_TILES; g++) begin
                tile_wr_ready_reg[g] <= grant_valid && (grant_idx == g);
            end
        end
    end
    
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

`ifdef SIM
`ifdef PROBE_OBUF_X
    // ------------------------------------------------------------------
    // SIM-only probe (off by default; enable with `xvlog -d PROBE_OBUF_X`).
    // Logs every grant that produces a write into OBUF Port B with addr
    // 0x20000 / 0x20001. Together with the per-Tile probe this tells us
    // which Tile won the arbitration and what data/strb made it onto the
    // obuf_int_* bus.
    // ------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0] probe_addr_w =
        tile_wr_addr[grant_idx*ADDR_WIDTH +: ADDR_WIDTH];
    always_ff @(posedge clk) begin
        if (rst_n && grant_valid &&
            (probe_addr_w == 20'h20000 || probe_addr_w == 20'h20001)) begin
            $display("[%0t] PROBE.Arb@%m: GRANT tile=%0d addr=0x%05h data=0x%032h strb=0x%04h valid_q=0x%02h",
                     $time, grant_idx, probe_addr_w,
                     tile_wr_data[grant_idx*DATA_WIDTH +: DATA_WIDTH],
                     tile_wr_strb[grant_idx*STRB_WIDTH +: STRB_WIDTH],
                     tile_wr_valid_q);
        end
        if (rst_n && obuf_en && |obuf_we &&
            (obuf_addr == 20'h20000 || obuf_addr == 20'h20001)) begin
            $display("[%0t] PROBE.Arb@%m: OBUF_OUT addr=0x%05h data=0x%032h we=0x%04h",
                     $time, obuf_addr, obuf_din, obuf_we);
        end
    end
`endif
`endif

endmodule
