`timescale 1ns / 1ps

// ============================================================================
// ibuf_rd_arbiter - 参数化 Round-Robin IBUF 读仲裁器
// ============================================================================
// 多个 Tile 共享一个 IBUF 读端口，使用 Round-Robin 策略公平调度。
// Tile 侧使用 ready/valid 握手，IBUF 侧使用 en/addr/dout 接口。
//
// 时序：
//   Cycle 0: Tile 发出 rd_valid + rd_addr
//   Cycle 0: Arbiter 选中并回复 rd_ready（valid & ready 握手成功）
//   Cycle 1~N: IBUF 读取延迟（NBPIPE+1 个周期）
//   Cycle N+1: Arbiter 向对应 Tile 发出 rd_data_valid + rd_data
// ============================================================================

module ibuf_rd_arbiter #(
    parameter NUM_TILES      = 16,
    parameter ADDR_WIDTH     = 14,
    parameter DATA_WIDTH     = 128,
    parameter IBUF_RD_LATENCY = 4   // ibuf.v NBPIPE=1 时的总读延迟
)(
    input  wire                              clk,
    input  wire                              rst_n,
    
    // Tile 侧接口 (N 路)
    input  wire [NUM_TILES-1:0]              tile_rd_valid,
    output wire [NUM_TILES-1:0]              tile_rd_ready,
    input  wire [NUM_TILES*ADDR_WIDTH-1:0]   tile_rd_addr,
    output reg  [NUM_TILES-1:0]              tile_rd_data_valid,
    output wire [DATA_WIDTH-1:0]             tile_rd_data,
    
    // IBUF 侧接口 (单读端口)
    output reg                               ibuf_en,
    output reg  [ADDR_WIDTH-1:0]             ibuf_addr,
    input  wire [DATA_WIDTH-1:0]             ibuf_dout
);

    // NUM_TILES==1 时 $clog2(1)==0，避免 0 位寄存器
    localparam TILE_IDX_W = (NUM_TILES <= 1) ? 1 : $clog2(NUM_TILES);
    
    // ========================================================================
    // Round-Robin 优先级指针
    // ========================================================================
    reg [TILE_IDX_W-1:0] rr_ptr;
    
    // ========================================================================
    // 仲裁逻辑：从 rr_ptr 开始找到第一个有效请求
    // 添加流水线寄存器打破组合逻辑链
    // ========================================================================
    (* max_fanout = 8 *) reg [NUM_TILES-1:0] tile_rd_valid_q;
    reg [TILE_IDX_W-1:0] grant_idx;
    reg                   grant_valid;
    
    // 第一级：请求锁存
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) tile_rd_valid_q <= 0;
        else tile_rd_valid_q <= tile_rd_valid;
    end
    
    // 第二级：仲裁逻辑（使用锁存后的请求）
    always_comb begin
        grant_valid = 1'b0;
        grant_idx = 0;
        for (int i = 0; i < NUM_TILES; i++) begin
            automatic int idx = (rr_ptr + i) % NUM_TILES;
            if (!grant_valid && tile_rd_valid_q[idx]) begin
                grant_valid = 1'b1;
                grant_idx = idx[TILE_IDX_W-1:0];
            end
        end
    end
    
    // ========================================================================
    // 状态机
    // ========================================================================
    typedef enum logic [1:0] {
        ARB_IDLE,       // 等待请求
        ARB_GRANTED,    // 已授权，发出IBUF读请求
        ARB_WAIT_DATA   // 等待IBUF数据返回
    } arb_state_t;
    
    arb_state_t arb_state;
    reg [TILE_IDX_W-1:0] active_tile;
    reg [3:0] latency_cnt;
    
    // ready 信号：注册以减少扇出
    (* max_fanout = 4 *) reg [NUM_TILES-1:0] tile_rd_ready_reg;
    assign tile_rd_ready = tile_rd_ready_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) tile_rd_ready_reg <= 0;
        else begin
            for (int g = 0; g < NUM_TILES; g++) begin
                tile_rd_ready_reg[g] <= (arb_state == ARB_IDLE) && grant_valid && (grant_idx == g);
            end
        end
    end
    
    // 读数据广播给所有 Tile（添加寄存器减少扇出）
    (* max_fanout = 8 *) reg [DATA_WIDTH-1:0] tile_rd_data_reg;
    assign tile_rd_data = tile_rd_data_reg;
    
    always_ff @(posedge clk) begin
        tile_rd_data_reg <= ibuf_dout;
    end    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arb_state <= ARB_IDLE;
            active_tile <= 0;
            rr_ptr <= 0;
            latency_cnt <= 0;
            ibuf_en <= 0;
            ibuf_addr <= 0;
            tile_rd_data_valid <= 0;
        end else begin
            tile_rd_data_valid <= 0;
            
            case (arb_state)
                ARB_IDLE: begin
                    ibuf_en <= 0;
                    if (grant_valid) begin
                        // 握手成功：发出IBUF读
                        active_tile <= grant_idx;
                        ibuf_en <= 1'b1;
                        ibuf_addr <= tile_rd_addr[grant_idx*ADDR_WIDTH +: ADDR_WIDTH];
                        latency_cnt <= 1;
                        rr_ptr <= grant_idx + 1;
                        arb_state <= ARB_WAIT_DATA;
                    end
                end
                
                ARB_WAIT_DATA: begin
                    ibuf_en <= 0;
                    latency_cnt <= latency_cnt + 1;
                    if (latency_cnt >= IBUF_RD_LATENCY) begin
                        tile_rd_data_valid[active_tile] <= 1'b1;
                        arb_state <= ARB_IDLE;
                    end
                end
                
                default: arb_state <= ARB_IDLE;
            endcase
        end
    end

endmodule
