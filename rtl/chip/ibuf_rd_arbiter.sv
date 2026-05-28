`timescale 1ns / 1ps

// ============================================================================
// ibuf_rd_arbiter - 时序友好的 IBUF 读仲裁器
// ============================================================================
// 多个 Tile 共享一个 IBUF 读端口。为了支持 64 Tile 且优先满足 250MHz 时序，
// 不使用单周期全宽 round-robin 优先级编码，而是每拍只检查一个 Tile。
// 命中后先锁存 tile/address，下一拍再 grant，避免 scan_idx 可变 part-select
// 与 IBUF 输出寄存器处于同一条组合路径。
// ============================================================================

module ibuf_rd_arbiter #(
    parameter NUM_TILES       = 16,
    parameter ADDR_WIDTH      = 14,
    parameter DATA_WIDTH      = 128,
    parameter IBUF_RD_LATENCY = 4
)(
    input  wire                              clk,
    input  wire                              rst_n,
    
    // Tile 侧接口 (N 路)
    input  wire [NUM_TILES-1:0]              tile_rd_valid,
    output wire [NUM_TILES-1:0]              tile_rd_ready,
    input  wire [NUM_TILES*ADDR_WIDTH-1:0]   tile_rd_addr,
    output reg  [NUM_TILES-1:0]              tile_rd_data_valid,
    output wire [DATA_WIDTH-1:0]             tile_rd_data,

    output reg                               ibuf_en,
    output reg  [ADDR_WIDTH-1:0]             ibuf_addr,
    input  wire [DATA_WIDTH-1:0]             ibuf_dout
);

    localparam TILE_IDX_W = (NUM_TILES <= 1) ? 1 : $clog2(NUM_TILES);
    localparam [TILE_IDX_W-1:0] LAST_TILE_IDX = NUM_TILES - 1'b1;

    typedef enum logic [1:0] {
        ARB_SCAN,
        ARB_GRANT,
        ARB_WAIT_DATA
    } arb_state_t;

    arb_state_t arb_state;
    reg [TILE_IDX_W-1:0] scan_idx;
    reg [TILE_IDX_W-1:0] active_tile;
    reg [ADDR_WIDTH-1:0] active_addr;
    reg [3:0] latency_cnt;
    reg [NUM_TILES-1:0] tile_rd_ready_reg;

    assign tile_rd_ready = tile_rd_ready_reg;
    assign tile_rd_data  = ibuf_dout;

    function automatic [TILE_IDX_W-1:0] inc_idx(input [TILE_IDX_W-1:0] idx);
        begin
            if (idx == LAST_TILE_IDX)
                inc_idx = '0;
            else
                inc_idx = idx + 1'b1;
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arb_state <= ARB_SCAN;
            scan_idx <= '0;
            active_tile <= '0;
            active_addr <= '0;
            latency_cnt <= '0;
            ibuf_en <= 1'b0;
            ibuf_addr <= '0;
            tile_rd_ready_reg <= '0;
            tile_rd_data_valid <= '0;
        end else begin
            ibuf_en <= 1'b0;
            tile_rd_ready_reg <= '0;
            tile_rd_data_valid <= '0;

            case (arb_state)
                ARB_SCAN: begin
                    if (tile_rd_valid[scan_idx]) begin
                        active_tile <= scan_idx;
                        active_addr <= tile_rd_addr[scan_idx*ADDR_WIDTH +: ADDR_WIDTH];
                        scan_idx <= inc_idx(scan_idx);
                        arb_state <= ARB_GRANT;
                    end else begin
                        scan_idx <= inc_idx(scan_idx);
                    end
                end

                ARB_GRANT: begin
                    ibuf_en <= 1'b1;
                    ibuf_addr <= active_addr;
                    tile_rd_ready_reg[active_tile] <= 1'b1;
                    latency_cnt <= 4'd1;
                    arb_state <= ARB_WAIT_DATA;
                end

                ARB_WAIT_DATA: begin
                    latency_cnt <= latency_cnt + 1'b1;
                    if (latency_cnt >= IBUF_RD_LATENCY) begin
                        tile_rd_data_valid[active_tile] <= 1'b1;
                        arb_state <= ARB_SCAN;
                    end
                end

                default: begin
                    arb_state <= ARB_SCAN;
                end
            endcase
        end
    end

endmodule
