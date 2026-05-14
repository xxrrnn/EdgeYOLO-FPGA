`timescale 1ns / 1ps

// ============================================================================
// DCIM_Array - 8 组 DCIM_Array_Group 的顶层模块
// ============================================================================
// 架构：8 组 × 8 Tile/组 = 64 Tile
// 每组独立的 IBUF + OBUF，便于 SLR 约束和时序优化
//
// 外部接口：
//   - 8 组独立的 IBUF/OBUF 外部接口
//   - 统一的控制和配置接口
// ============================================================================

module DCIM_Array #(
    parameter NUM_GROUPS     = 8,       // 组数量
    parameter TILES_PER_GROUP = 8,      // 每组 Tile 数量
    parameter NUM_TILES      = 64,      // 总 Tile 数量 = NUM_GROUPS × TILES_PER_GROUP
    parameter WD1            = 4,
    parameter CH_IN          = 16,
    parameter CH_OUT         = 16,
    parameter SRAM_DP        = 128,
    parameter CYCLE          = 8,
    parameter ACC            = 80,
    parameter BUF_ADDR_WIDTH = 14,
    parameter BUF_DATA_WIDTH = 128,
    parameter IBUF_RD_LATENCY = 8,      // 8 Tile 仲裁 + URAM 延迟
    
    localparam ACC_UBD_WD = $clog2(ACC+1),
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8
)(
    input  wire                          clk,
    input  wire                          rst_n,
    
    // 控制接口：同步启动所有组
    input  wire                          start,
    output wire                          done,       // 所有组完成
    output wire                          ready,      // 所有组就绪
    
    // 配置接口：
    //   - 全阵列共享：mode / acc_depth / num_rows
    //   - 每组共享：act_base_addr（激活数据基址）
    //   - 每 Tile 独立：wei_base_addrs、out_base_addrs
    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [31:0]                   num_rows,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]     act_base_addrs,   // 每组的激活基址
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]      wei_base_addrs,   // 每 Tile 的权重基址
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]      out_base_addrs,   // 每 Tile 的输出基址
    
    // 8 组外部 IBUF 接口（Port A: 外部加载数据）
    input  wire [NUM_GROUPS*STRB_WIDTH-1:0]         ibuf_ext_wea,
    input  wire [NUM_GROUPS-1:0]                    ibuf_ext_ena,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]     ibuf_ext_addra,
    input  wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,
    
    // 8 组外部 OBUF 接口（Port A: 外部读取结果）
    input  wire [NUM_GROUPS*STRB_WIDTH-1:0]         obuf_ext_wea,
    input  wire [NUM_GROUPS-1:0]                    obuf_ext_ena,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]     obuf_ext_addra,
    input  wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]     obuf_ext_douta
);

    // ========================================================================
    // 组控制信号
    // ========================================================================
    wire [NUM_GROUPS-1:0] group_done;
    wire [NUM_GROUPS-1:0] group_ready;
    
    assign done  = &group_done;
    assign ready = &group_ready;
    
    // ========================================================================
    // 实例化 8 组 DCIM_Array_Group
    // ========================================================================
    generate
        genvar g, t;
        for (g = 0; g < NUM_GROUPS; g = g + 1) begin : gen_groups
            
            // 提取该组的 Tile 配置
            wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0] group_wei_base_addrs;
            wire [TILES_PER_GROUP*BUF_ADDR_WIDTH-1:0] group_out_base_addrs;
            
            // 将全局 Tile 索引映射到组内索引
            for (t = 0; t < TILES_PER_GROUP; t = t + 1) begin : gen_tile_addrs
                // 使用 assign 直接计算，避免 localparam 依赖 genvar
                assign group_wei_base_addrs[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = 
                       wei_base_addrs[(g*TILES_PER_GROUP + t)*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH];
                assign group_out_base_addrs[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = 
                       out_base_addrs[(g*TILES_PER_GROUP + t)*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH];
            end
            
            (* keep_hierarchy = "yes" *)
            DCIM_Array_Group #(
                .GROUP_ID(g),
                .TILES_PER_GROUP(TILES_PER_GROUP),
                .WD1(WD1),
                .CH_IN(CH_IN),
                .CH_OUT(CH_OUT),
                .SRAM_DP(SRAM_DP),
                .CYCLE(CYCLE),
                .ACC(ACC),
                .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
                .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
                .IBUF_RD_LATENCY(IBUF_RD_LATENCY)
            ) u_group (
                .clk(clk),
                .rst_n(rst_n),
                
                .start(start),
                .done(group_done[g]),
                .ready(group_ready[g]),
                
                .mode(mode),
                .acc_depth(acc_depth),
                .num_rows(num_rows),
                .act_base_addr(act_base_addrs[g*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .wei_base_addrs(group_wei_base_addrs),
                .out_base_addrs(group_out_base_addrs),
                
                // IBUF 外部接口
                .ibuf_ext_wea(ibuf_ext_wea[g*STRB_WIDTH +: STRB_WIDTH]),
                .ibuf_ext_ena(ibuf_ext_ena[g]),
                .ibuf_ext_addra(ibuf_ext_addra[g*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_ext_dina(ibuf_ext_dina[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .ibuf_ext_douta(ibuf_ext_douta[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                
                // OBUF 外部接口
                .obuf_ext_wea(obuf_ext_wea[g*STRB_WIDTH +: STRB_WIDTH]),
                .obuf_ext_ena(obuf_ext_ena[g]),
                .obuf_ext_addra(obuf_ext_addra[g*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .obuf_ext_dina(obuf_ext_dina[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .obuf_ext_douta(obuf_ext_douta[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH])
            );
        end
    endgenerate

endmodule
