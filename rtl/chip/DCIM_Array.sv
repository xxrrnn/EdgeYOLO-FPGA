`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array - 8 组 DCIM_Array_Group 的顶层模块
// ============================================================================
// 架构：8 组 × 8 Tile/组 = 64 Tile
//
// 共用大 IBUF 改造说明：
//   - act_base_addr：1 个全局地址，广播给所有 8 个 Group
//   - IBUF 外部写接口：1 套端口，顶层广播到所有 Group 的 IBUF
//     （所有 Group IBUF 物理独立，存相同激活数据，软件写一次）
//   - OBUF 保持 8 组独立（各组输出通道不同）
//   - weight 地址：64 Tile 各自独立（每 Tile 输出通道不同）
//   - 时序：IBUF 本地读，仲裁延迟不变
// ============================================================================

module DCIM_Array #(
    parameter NUM_GROUPS      = `DCIM_NUM_GROUPS,
    parameter TILES_PER_GROUP = `DCIM_TILES_PER_GROUP,
    parameter NUM_TILES       = `DCIM_NUM_TILES,
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter SRAM_DP         = `DCIM_SRAM_DP,
    parameter CYCLE           = `DCIM_CYCLE,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH  = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,
    parameter IBUF_RD_LATENCY = `DCIM_IBUF_RD_LATENCY,
    
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
    //   - 全阵列共享：mode / acc_depth
    //   - 全阵列共享：act_base_addr（统一激活基址，广播给所有 Group）
    //   - 每 Tile 独立：wei_base_addrs、out_base_addrs
    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,    // 全局统一激活基址（广播）
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]      wei_base_addrs,   // 每 Tile 的权重基址
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]      out_base_addrs,   // 每 Tile 的输出基址
    
    // 1 套外部 IBUF 接口（已由 bd 层广播展开为 NUM_GROUPS 套向量，Port A）
    input  wire [NUM_GROUPS*STRB_WIDTH-1:0]                 ibuf_ext_wea,
    input  wire [NUM_GROUPS-1:0]                            ibuf_ext_ena,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]             ibuf_ext_addra,
    input  wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]             ibuf_ext_dina,
    output wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]             ibuf_ext_douta,
    
    // 8 组外部 OBUF 接口（Port A: 外部读取结果，各组独立）
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
                // act_base_addr 全局广播，所有 Group 使用同一地址
                .act_base_addr(act_base_addr),
                .wei_base_addrs(group_wei_base_addrs),
                .out_base_addrs(group_out_base_addrs),
                
                // IBUF 广播写接口：各 Group 取各自对应分片
                .ibuf_ext_wea(ibuf_ext_wea[g*STRB_WIDTH +: STRB_WIDTH]),
                .ibuf_ext_ena(ibuf_ext_ena[g]),
                .ibuf_ext_addra(ibuf_ext_addra[g*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_ext_dina(ibuf_ext_dina[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .ibuf_ext_douta(ibuf_ext_douta[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                
                // OBUF 各组独立
                .obuf_ext_wea(obuf_ext_wea[g*STRB_WIDTH +: STRB_WIDTH]),
                .obuf_ext_ena(obuf_ext_ena[g]),
                .obuf_ext_addra(obuf_ext_addra[g*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .obuf_ext_dina(obuf_ext_dina[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .obuf_ext_douta(obuf_ext_douta[g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH])
            );
        end
    endgenerate

endmodule
