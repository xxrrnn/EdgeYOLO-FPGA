`timescale 1ns / 1ps

// ============================================================================
// DCIM_Array_AXI - AXI-Lite Slave 寄存器模块
// ============================================================================
// 为 DCIM_Array 提供 AXI-Lite 配置接口
// 支持 32 个 Tile（可扩展到 64）
// ============================================================================

module DCIM_Array_AXI #(
    parameter NUM_TILES       = 32,
    parameter BUF_ADDR_WIDTH  = 19,
    parameter ACC_UBD_WD      = 7,
    parameter AXI_ADDR_WIDTH  = 12,
    parameter AXI_DATA_WIDTH  = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,
    
    // AXI-Lite Slave Interface
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire [2:0]                    s_axi_awprot,
    input  wire                          s_axi_awvalid,
    output reg                           s_axi_awready,
    
    input  wire [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]   s_axi_wstrb,
    input  wire                          s_axi_wvalid,
    output reg                           s_axi_wready,
    
    output reg  [1:0]                    s_axi_bresp,
    output reg                           s_axi_bvalid,
    input  wire                          s_axi_bready,
    
    input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire [2:0]                    s_axi_arprot,
    input  wire                          s_axi_arvalid,
    output reg                           s_axi_arready,
    
    output reg  [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                    s_axi_rresp,
    output reg                           s_axi_rvalid,
    input  wire                          s_axi_rready,
    
    // DCIM_Array 配置输出
    output reg                           cfg_start,
    output reg  [2:0]                    cfg_mode,
    output reg  [ACC_UBD_WD-1:0]         cfg_acc_depth,
    output reg  [31:0]                   cfg_num_rows,
    output reg  [BUF_ADDR_WIDTH-1:0]     cfg_act_base_addr,
    output reg  [NUM_TILES*BUF_ADDR_WIDTH-1:0] cfg_wei_base_addrs,
    output reg  [NUM_TILES*BUF_ADDR_WIDTH-1:0] cfg_out_base_addrs,
    
    // DCIM_Array 状态输入
    input  wire                          sts_done,
    input  wire                          sts_ready
);

    // ========================================================================
    // 寄存器地址映射 (字节地址，4字节对齐)
    // ========================================================================
    // 0x000: CTRL      - [0] start (W1C), [1] soft_reset
    // 0x004: STATUS    - [0] done, [1] ready
    // 0x008: MODE      - [2:0] mode, [15:8] acc_depth
    // 0x00C: NUM_ROWS  - [31:0] num_rows
    // 0x010: ACT_BASE  — 仅 1 个寄存器，全 Tile 共享（IBUF 内激活区起始字地址）
    // 0x014-0x01F: RESERVED
    // 0x020-0x09F: WEI_BASE[0..NUM_TILES-1] — 每 Tile 一个（NUM_TILES=32 时 32×4B；与 Tile 数一致）
    // 0x0A0-0x11F: OUT_BASE[0..NUM_TILES-1] — 每 Tile 一个（OBUF 写回基址）
    // 0x120-0x1FF: 扩 64 Tile 时扩展 WEI_BASE/OUT_BASE 映射（当前 RTL 解码见 default 分支上界）
    
    localparam ADDR_CTRL      = 12'h000;
    localparam ADDR_STATUS    = 12'h004;
    localparam ADDR_MODE      = 12'h008;
    localparam ADDR_NUM_ROWS  = 12'h00C;
    localparam ADDR_ACT_BASE  = 12'h010;
    localparam ADDR_WEI_BASE  = 12'h020;  // 0x020 - 0x09F
    localparam ADDR_OUT_BASE  = 12'h0A0;  // 0x0A0 - 0x11F
    
    // ========================================================================
    // AXI-Lite 写通道状态机
    // ========================================================================
    reg [AXI_ADDR_WIDTH-1:0] aw_addr_reg;
    reg aw_en;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_awready <= 1'b0;
            aw_en <= 1'b1;
            aw_addr_reg <= 0;
        end else begin
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                aw_en <= 1'b0;
                aw_addr_reg <= s_axi_awaddr;
            end else if (s_axi_bready && s_axi_bvalid) begin
                aw_en <= 1'b1;
                s_axi_awready <= 1'b0;
            end else begin
                s_axi_awready <= 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_wready <= 1'b0;
        end else begin
            if (~s_axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en) begin
                s_axi_wready <= 1'b1;
            end else begin
                s_axi_wready <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // 寄存器写逻辑
    // ========================================================================
    wire wr_en = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_start <= 1'b0;
            cfg_mode <= 3'b110;  // 默认 INT8
            cfg_acc_depth <= 0;
            cfg_num_rows <= 0;
            cfg_act_base_addr <= 0;
            for (i = 0; i < NUM_TILES; i = i + 1) begin
                cfg_wei_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] <= 0;
                cfg_out_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] <= 0;
            end
        end else begin
            // start 脉冲自动清零
            cfg_start <= 1'b0;
            
            if (wr_en) begin
                case (aw_addr_reg[11:2])  // 字地址
                    ADDR_CTRL[11:2]: begin
                        if (s_axi_wstrb[0] && s_axi_wdata[0])
                            cfg_start <= 1'b1;
                    end
                    ADDR_MODE[11:2]: begin
                        if (s_axi_wstrb[0])
                            cfg_mode <= s_axi_wdata[2:0];
                        if (s_axi_wstrb[1])
                            cfg_acc_depth <= s_axi_wdata[8 +: ACC_UBD_WD];
                    end
                    ADDR_NUM_ROWS[11:2]: begin
                        cfg_num_rows <= s_axi_wdata;
                    end
                    ADDR_ACT_BASE[11:2]: begin
                        cfg_act_base_addr <= s_axi_wdata[BUF_ADDR_WIDTH-1:0];
                    end
                    default: begin
                        // WEI_BASE[0..31]: 0x020-0x09F -> word addr 0x08-0x27
                        if (aw_addr_reg >= ADDR_WEI_BASE && aw_addr_reg < ADDR_OUT_BASE) begin
                            automatic int tile_idx = (aw_addr_reg - ADDR_WEI_BASE) >> 2;
                            if (tile_idx < NUM_TILES)
                                cfg_wei_base_addrs[tile_idx*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] <= s_axi_wdata[BUF_ADDR_WIDTH-1:0];
                        end
                        // OUT_BASE[0..31]: 0x0A0-0x11F -> word addr 0x28-0x47
                        else if (aw_addr_reg >= ADDR_OUT_BASE && aw_addr_reg < 12'h120) begin
                            automatic int tile_idx = (aw_addr_reg - ADDR_OUT_BASE) >> 2;
                            if (tile_idx < NUM_TILES)
                                cfg_out_base_addrs[tile_idx*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] <= s_axi_wdata[BUF_ADDR_WIDTH-1:0];
                        end
                    end
                endcase
            end
        end
    end
    
    // ========================================================================
    // 写响应
    // ========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= 2'b00;
        end else begin
            if (s_axi_awready && s_axi_awvalid && ~s_axi_bvalid && s_axi_wready && s_axi_wvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= 2'b00;  // OKAY
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end
    
    // ========================================================================
    // AXI-Lite 读通道
    // ========================================================================
    reg [AXI_ADDR_WIDTH-1:0] ar_addr_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_arready <= 1'b0;
            ar_addr_reg <= 0;
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                ar_addr_reg <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= 2'b00;
            s_axi_rdata <= 0;
        end else begin
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;
                
                case (ar_addr_reg[11:2])
                    ADDR_CTRL[11:2]:
                        s_axi_rdata <= 32'h0;
                    ADDR_STATUS[11:2]:
                        s_axi_rdata <= {30'b0, sts_ready, sts_done};
                    ADDR_MODE[11:2]:
                        s_axi_rdata <= {16'b0, {(8-ACC_UBD_WD){1'b0}}, cfg_acc_depth, 5'b0, cfg_mode};
                    ADDR_NUM_ROWS[11:2]:
                        s_axi_rdata <= cfg_num_rows;
                    ADDR_ACT_BASE[11:2]:
                        s_axi_rdata <= {{(32-BUF_ADDR_WIDTH){1'b0}}, cfg_act_base_addr};
                    default: begin
                        if (ar_addr_reg >= ADDR_WEI_BASE && ar_addr_reg < ADDR_OUT_BASE) begin
                            automatic int tile_idx = (ar_addr_reg - ADDR_WEI_BASE) >> 2;
                            if (tile_idx < NUM_TILES)
                                s_axi_rdata <= {{(32-BUF_ADDR_WIDTH){1'b0}}, cfg_wei_base_addrs[tile_idx*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]};
                            else
                                s_axi_rdata <= 32'h0;
                        end
                        else if (ar_addr_reg >= ADDR_OUT_BASE && ar_addr_reg < 12'h120) begin
                            automatic int tile_idx = (ar_addr_reg - ADDR_OUT_BASE) >> 2;
                            if (tile_idx < NUM_TILES)
                                s_axi_rdata <= {{(32-BUF_ADDR_WIDTH){1'b0}}, cfg_out_base_addrs[tile_idx*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]};
                            else
                                s_axi_rdata <= 32'h0;
                        end
                        else begin
                            s_axi_rdata <= 32'h0;
                        end
                    end
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
