`timescale 1ns / 1ns

// ============================================================================
// obuf_wr_arbiter - 时序友好的 OBUF 写仲裁器
// ============================================================================
// 多个 Tile 共享一个 OBUF 写端口。64 Tile 下优先保证时序，仲裁器每拍只检查
// 一个 Tile，避免单周期 64 路 round-robin 组合取模/优先级链。命中后先锁存
// data/address/strb，下一拍再 grant，避免可变 part-select 直连 OBUF 输出。
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

    output reg                                   obuf_en,
    output reg  [DATA_WIDTH/8-1:0]               obuf_we,
    output reg  [ADDR_WIDTH-1:0]                 obuf_addr,
    output reg  [DATA_WIDTH-1:0]                 obuf_din
);

    localparam TILE_IDX_W = (NUM_TILES <= 1) ? 1 : $clog2(NUM_TILES);
    localparam STRB_WIDTH = DATA_WIDTH / 8;
    localparam [TILE_IDX_W-1:0] LAST_TILE_IDX = NUM_TILES - 1'b1;

    typedef enum logic [0:0] {
        ARB_SCAN,
        ARB_GRANT
    } arb_state_t;

    arb_state_t arb_state;
    reg [TILE_IDX_W-1:0] scan_idx;
    reg [TILE_IDX_W-1:0] active_tile;
    reg [ADDR_WIDTH-1:0] active_addr;
    reg [DATA_WIDTH-1:0] active_data;
    reg [STRB_WIDTH-1:0] active_strb;
    reg [NUM_TILES-1:0] tile_wr_ready_reg;

    assign tile_wr_ready = tile_wr_ready_reg;

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
            active_data <= '0;
            active_strb <= '0;
            tile_wr_ready_reg <= '0;
            obuf_en <= 1'b0;
            obuf_we <= '0;
            obuf_addr <= '0;
            obuf_din <= '0;
        end else begin
            tile_wr_ready_reg <= '0;
            obuf_en <= 1'b0;
            obuf_we <= '0;

            case (arb_state)
                ARB_SCAN: begin
                    if (tile_wr_valid[scan_idx]) begin
                        active_tile <= scan_idx;
                        active_strb <= tile_wr_strb[scan_idx*STRB_WIDTH +: STRB_WIDTH];
                        active_addr <= tile_wr_addr[scan_idx*ADDR_WIDTH +: ADDR_WIDTH];
                        active_data <= tile_wr_data[scan_idx*DATA_WIDTH +: DATA_WIDTH];
                        scan_idx <= inc_idx(scan_idx);
                        arb_state <= ARB_GRANT;
                    end else begin
                        scan_idx <= inc_idx(scan_idx);
                    end
                end

                ARB_GRANT: begin
                    tile_wr_ready_reg[active_tile] <= 1'b1;
                    obuf_en <= 1'b1;
                    obuf_we <= active_strb;
                    obuf_addr <= active_addr;
                    obuf_din <= active_data;
                    arb_state <= ARB_SCAN;
                end

                default: begin
                    arb_state <= ARB_SCAN;
                end
            endcase
        end
    end

`ifdef SIM
`ifdef PROBE_OBUF_X
    always_ff @(posedge clk) begin
        if (rst_n && obuf_en && |obuf_we &&
            (obuf_addr == 20'h20000 || obuf_addr == 20'h20001)) begin
            $display("[%0t] PROBE.Arb@%m: OBUF_OUT tile=%0d addr=0x%05h data=0x%032h we=0x%04h",
                     $time, active_tile, obuf_addr, obuf_din, obuf_we);
        end
    end
`endif
`endif

endmodule
