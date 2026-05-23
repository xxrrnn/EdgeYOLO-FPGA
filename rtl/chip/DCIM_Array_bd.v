`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array_bd - Vivado Block Design 顶层封装
// ============================================================================
// 架构：`DCIM_NUM_GROUPS 组 × `DCIM_TILES_PER_GROUP Tile/组 = `DCIM_NUM_TILES Tile
//
// 配置由 INST_Decoder 通过 cfg_wr_* 直接写入，无 AXI 接口。
//
// 共用大 IBUF / 统一 OBUF：
//   - IBUF 外部写：1 套端口，广播到所有 8 组 IBUF（内容相同，软件写 1 次）
//   - act_base_addr：1 个全局寄存器（`DCIM_REG_ACT_BASE）
//   - OBUF 外部读：1 套端口，扩展地址高 `DCIM_OBUF_GROUP_BITS 位选择 Group，
//                  低 `DCIM_BUF_ADDR_WIDTH 位为组内地址
//     extended_addr[`DCIM_OBUF_EXT_ADDR_BITS-1 : `DCIM_BUF_ADDR_WIDTH] = group_sel
//     extended_addr[`DCIM_BUF_ADDR_WIDTH-1  : 0]                        = word_addr
//   - 每 Tile 独立 weight_addr（64 个独立配置）
//   - 每 Tile 独立 out_base_addr（64 个独立配置）
//
// 寄存器地址映射（`DCIM_REG_*）：
//   `DCIM_REG_CTRL     (0x000): [0] start (W1S, 自清)
//   `DCIM_REG_MODE     (0x008): [15:8] acc_depth | [2:0] mode
//   `DCIM_REG_ACT_BASE (0x010): 全局激活基址
//   `DCIM_REG_WEI_BASE (0x040~0x13F): WEI_BASE[0..63] (+4 per tile)
//   `DCIM_REG_OUT_BASE (0x140~0x23F): OUT_BASE[0..63] (+4 per tile)
// ============================================================================

module DCIM_Array_bd #(
    // 阵列拓扑（默认值来自 chip_defines.vh）
    parameter NUM_GROUPS          = `DCIM_NUM_GROUPS,
    parameter TILES_PER_GROUP     = `DCIM_TILES_PER_GROUP,
    parameter NUM_TILES           = `DCIM_NUM_TILES,
    // Tile 计算参数
    parameter WD1                 = `DCIM_WD1,
    parameter CH_IN               = `DCIM_CH_IN,
    parameter CH_OUT              = `DCIM_CH_OUT,
    parameter SRAM_DP             = `DCIM_SRAM_DP,
    parameter CYCLE               = `DCIM_CYCLE,
    parameter ACC                 = `DCIM_ACC_MAX,
    // Buffer 参数（lite: 拆分 IBUF/OBUF）
    parameter IBUF_ADDR_WIDTH     = `DCIM_IBUF_ADDR_WIDTH,  // 17 bits (2MB)
    parameter OBUF_ADDR_WIDTH     = `DCIM_OBUF_ADDR_WIDTH,  // 20 bits (16MB)
    parameter BUF_DATA_WIDTH      = `DCIM_BUF_DATA_WIDTH,
    parameter AXI_BRAM_ADDR_WIDTH = `DCIM_AXI_BRAM_ADDR_WIDTH,
    parameter IBUF_RD_LATENCY     = `DCIM_IBUF_RD_LATENCY,
    // 统一 OBUF 扩展地址位宽（lite: NUM_GROUPS=1, OBUF_GROUP_BITS=0）
    parameter OBUF_GROUP_BITS     = `DCIM_OBUF_GROUP_BITS,       // 0
    parameter OBUF_EXT_ADDR_BITS  = `DCIM_OBUF_EXT_ADDR_BITS,    // = OBUF_ADDR_WIDTH
    // 向后兼容
    parameter BUF_ADDR_WIDTH      = IBUF_ADDR_WIDTH
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // =========================================================================
    // INST_Decoder 直接配置写接口
    // =========================================================================
    input  wire                          cfg_wr_en,
    input  wire [11:0]                   cfg_wr_addr,
    input  wire [31:0]                   cfg_wr_data,

    // =========================================================================
    // 1 套 IBUF 外部写接口（广播到所有组，字节地址）
    // lite: NUM_GROUPS=1, 实际无需广播，但保留接口兼容性
    // =========================================================================
    input  wire [BUF_DATA_WIDTH/8-1:0]   ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [AXI_BRAM_ADDR_WIDTH-1:0] ibuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,  // Group 0 读回

    // =========================================================================
    // 1 套 OBUF 统一外部接口（读取所有 Group 结果，扩展字节地址）
    // lite: NUM_GROUPS=1, OBUF_GROUP_BITS=0, 地址直接映射无需 group_sel
    //   byte_addr[OBUF_ADDR_WIDTH+3 : 4] = word_addr (OBUF_ADDR_WIDTH bits)
    //   byte_addr[3:0]                    = byte_sel (未使用)
    // =========================================================================
    input  wire [BUF_DATA_WIDTH/8-1:0]   obuf_ext_wea,
    input  wire                          obuf_ext_ena,
    input  wire [OBUF_EXT_ADDR_BITS+3:0] obuf_ext_addra,  // 字节地址：20+4=24 bits
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_ext_douta,

    // =========================================================================
    // VPU OBUF 端口（lite 新增）：128-bit 读写，与 OBUF 物理宽度一致
    // OBUF Port A 由 XDMA/CDMA 和 VPU 共享，VPU 优先
    // =========================================================================
    input  wire [OBUF_ADDR_WIDTH-1:0]    vpu_obuf_addr,       // 128-bit 字地址
    input  wire                          vpu_obuf_en,
    input  wire [BUF_DATA_WIDTH/8-1:0]   vpu_obuf_we,         // 16-byte strb
    input  wire [BUF_DATA_WIDTH-1:0]     vpu_obuf_din,        // 128-bit 写数据
    output wire [BUF_DATA_WIDTH-1:0]     vpu_obuf_dout,       // 128-bit 读数据

    // =========================================================================
    // 状态输出
    // =========================================================================
    output wire done,
    output wire ready
);

    // =========================================================================
    // 本地参数
    // =========================================================================
    localparam ADDR_SHIFT     = 4;   // 字节→字地址: 128-bit = 16 bytes
    localparam STRB_WIDTH     = BUF_DATA_WIDTH / 8;
    localparam ACC_UBD_WD     = $clog2(ACC + 1);
    localparam IBUF_ADDR_W    = IBUF_ADDR_WIDTH;
    localparam OBUF_ADDR_W    = OBUF_ADDR_WIDTH;
    // DCIM_Array 内部统一用 OBUF_ADDR_WIDTH (较大者)，IBUF 信号高位补 0
    localparam INT_ADDR_W     = OBUF_ADDR_WIDTH;

    // =========================================================================
    // cfg_wr SLR 跨越寄存器（INST_Decoder@SLR1 → DCIM_Array 分布于 SLR0/1/2）
    // 1 级打拍，打断跨 SLR 走线的时序路径
    // =========================================================================
    (* shreg_extract = "no" *) reg        cfg_wr_en_d;
    (* shreg_extract = "no" *) reg [11:0] cfg_wr_addr_d;
    (* shreg_extract = "no" *) reg [31:0] cfg_wr_data_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_wr_en_d   <= 1'b0;
            cfg_wr_addr_d <= 12'h0;
            cfg_wr_data_d <= 32'h0;
        end else begin
            cfg_wr_en_d   <= cfg_wr_en;
            cfg_wr_addr_d <= cfg_wr_addr;
            cfg_wr_data_d <= cfg_wr_data;
        end
    end

    // =========================================================================
    // 配置寄存器（由 INST_Decoder 写入，经 1 级流水后解码）
    // lite: NUM_TILES=8, 只需 8 个 weight/out base addr
    // 内部统一用 INT_ADDR_W (=OBUF_ADDR_W)，IBUF 类的寄存器高位补 0
    // =========================================================================
    reg                                  cfg_start;
    reg [2:0]                            cfg_mode;
    reg [ACC_UBD_WD-1:0]                 cfg_acc_depth;
    reg [INT_ADDR_W-1:0]                 cfg_act_base_addr;  // 全局统一激活基址
    reg [NUM_TILES*INT_ADDR_W-1:0]       cfg_wei_base_addrs; // 8 Tile 各自权重基址
    reg [NUM_TILES*INT_ADDR_W-1:0]       cfg_out_base_addrs; // 8 Tile 各自输出基址
    reg [NUM_TILES-1:0]                  cfg_tile_mask;      // 每 bit 控制对应 Tile 是否启用

    integer _i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_start         <= 1'b0;
            cfg_mode          <= `MODE_INT8;
            cfg_acc_depth     <= 0;
            cfg_act_base_addr <= 0;
            cfg_tile_mask     <= {NUM_TILES{1'b1}};  // default: all enabled
            for (_i = 0; _i < NUM_TILES; _i = _i + 1) begin
                cfg_wei_base_addrs[_i*INT_ADDR_W +: INT_ADDR_W] <= 0;
                cfg_out_base_addrs[_i*INT_ADDR_W +: INT_ADDR_W] <= 0;
            end
        end else begin
            cfg_start <= 1'b0;
            if (cfg_wr_en_d) begin
                if (cfg_wr_addr_d == `DCIM_REG_CTRL) begin
                    if (cfg_wr_data_d[0]) cfg_start <= 1'b1;
                end else if (cfg_wr_addr_d == `DCIM_REG_MODE) begin
                    cfg_mode      <= cfg_wr_data_d[2:0];
                    cfg_acc_depth <= cfg_wr_data_d[8 +: ACC_UBD_WD];
                end else if (cfg_wr_addr_d == `DCIM_REG_ACT_BASE) begin
                    cfg_act_base_addr <= { {(INT_ADDR_W-IBUF_ADDR_W){1'b0}}, cfg_wr_data_d[IBUF_ADDR_W-1:0] };
                end else if (cfg_wr_addr_d >= `DCIM_REG_WEI_BASE &&
                             cfg_wr_addr_d < `DCIM_REG_OUT_BASE) begin
                    begin : wei_decode
                        integer t;
                        t = (cfg_wr_addr_d - `DCIM_REG_WEI_BASE) >> 2;
                        if (t < NUM_TILES)
                            cfg_wei_base_addrs[t*INT_ADDR_W +: INT_ADDR_W]
                                <= { {(INT_ADDR_W-IBUF_ADDR_W){1'b0}}, cfg_wr_data_d[IBUF_ADDR_W-1:0] };
                    end
                end else if (cfg_wr_addr_d >= `DCIM_REG_OUT_BASE &&
                             cfg_wr_addr_d < (`DCIM_REG_OUT_BASE + NUM_TILES*4)) begin
                    begin : out_decode
                        integer t2;
                        t2 = (cfg_wr_addr_d - `DCIM_REG_OUT_BASE) >> 2;
                        if (t2 < NUM_TILES)
                            cfg_out_base_addrs[t2*INT_ADDR_W +: INT_ADDR_W]
                                <= cfg_wr_data_d[INT_ADDR_W-1:0];
                    end
                end else if (cfg_wr_addr_d == `DCIM_REG_TILE_MASK) begin
                    cfg_tile_mask <= cfg_wr_data_d[NUM_TILES-1:0];
                end
            end
        end
    end

    // =========================================================================
    // IBUF 广播：1 套外部信号 → NUM_GROUPS 套向量
    // 信号宽度统一扩展到 INT_ADDR_W (=OBUF_ADDR_W)，IBUF 实际只用低 IBUF_ADDR_W 位
    // lite: IBUF 仅由 XDMA/CDMA 访问（VPU 不直接写 IBUF）
    // =========================================================================
    wire [STRB_WIDTH-1:0]                ibuf_wea_bc;
    wire                                 ibuf_ena_bc;
    wire [INT_ADDR_W-1:0]                ibuf_addra_bc;
    wire [BUF_DATA_WIDTH-1:0]            ibuf_dina_bc;

    assign ibuf_wea_bc   = ibuf_ext_wea;
    assign ibuf_ena_bc   = ibuf_ext_ena;
    // IBUF 外部地址只有 IBUF_ADDR_W 位，高位补 0 扩展到 INT_ADDR_W
    assign ibuf_addra_bc = { {(INT_ADDR_W-IBUF_ADDR_W){1'b0}}, ibuf_ext_addra[ADDR_SHIFT +: IBUF_ADDR_W] };
    assign ibuf_dina_bc  = ibuf_ext_dina;

    wire [NUM_GROUPS*STRB_WIDTH-1:0]      ibuf_ext_wea_v;
    wire [NUM_GROUPS-1:0]                 ibuf_ext_ena_v;
    wire [NUM_GROUPS*INT_ADDR_W-1:0]      ibuf_ext_addra_v;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]  ibuf_ext_dina_v;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]  ibuf_ext_douta_v;

    genvar _g;
    generate
        for (_g = 0; _g < NUM_GROUPS; _g = _g + 1) begin : gen_ibuf_bc
            assign ibuf_ext_wea_v  [_g*STRB_WIDTH    +: STRB_WIDTH]      = ibuf_wea_bc;
            assign ibuf_ext_ena_v  [_g]                                   = ibuf_ena_bc;
            assign ibuf_ext_addra_v[_g*INT_ADDR_W    +: INT_ADDR_W]      = ibuf_addra_bc;
            assign ibuf_ext_dina_v [_g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = ibuf_dina_bc;
        end
    endgenerate

    assign ibuf_ext_douta = ibuf_ext_douta_v[BUF_DATA_WIDTH-1:0];  // Group 0 读回

    // =========================================================================
    // OBUF 统一外部接口
    // lite: NUM_GROUPS=1, OBUF_GROUP_BITS=0, 直接映射无需 group_sel
    //   obuf_ext_addra[ADDR_SHIFT+OBUF_ADDR_W-1 : ADDR_SHIFT] = word_addr
    // OBUF 信号宽度 = INT_ADDR_W (=OBUF_ADDR_W)
    // =========================================================================
    wire [INT_ADDR_W-1:0]               obuf_word_addr;
    assign obuf_word_addr = obuf_ext_addra[ADDR_SHIFT +: OBUF_ADDR_W];

    // =========================================================================
    // VPU OBUF 读端口适配（lite 新增）：256-bit ↔ 128-bit
    // VPU 一次读 256-bit = 2 个连续 128-bit OBUF word
    // 实现：分两拍读，第一拍读 {addr,1'b0}, 第二拍读 {addr,1'b1}，结果拼接
    // 通过状态机控制 Port A mux：当 vpu_obuf_rd_en=1 时, OBUF Port A 给 VPU 用
    // =========================================================================

    // VPU 使用 OBUF Port A 的时段（直接由 vpu_obuf_en 控制）
    wire vpu_use_port_a = vpu_obuf_en;

    // OBUF Port A: XDMA 和 VPU 共享，VPU 优先
    wire                     obuf_porta_ena;
    wire [STRB_WIDTH-1:0]    obuf_porta_wea;
    wire [INT_ADDR_W-1:0]    obuf_porta_addr;
    wire [BUF_DATA_WIDTH-1:0] obuf_porta_din;
    assign obuf_porta_ena  = vpu_use_port_a ? 1'b1                                          : obuf_ext_ena;
    assign obuf_porta_wea  = vpu_use_port_a ? vpu_obuf_we                                   : obuf_ext_wea;
    assign obuf_porta_addr = vpu_use_port_a ? vpu_obuf_addr                                 : obuf_word_addr;
    assign obuf_porta_din  = vpu_use_port_a ? vpu_obuf_din                                  : obuf_ext_dina;

    // 向 NUM_GROUPS 个 Group 分发 OBUF 读请求
    // lite: NUM_GROUPS=1, 直接连接无需 demux
    wire [NUM_GROUPS*STRB_WIDTH-1:0]     obuf_ext_wea_v;
    wire [NUM_GROUPS-1:0]                obuf_ext_ena_v;
    wire [NUM_GROUPS*INT_ADDR_W-1:0]     obuf_ext_addra_v;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0] obuf_ext_dina_v;
    wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0] obuf_ext_douta_v;

    // VPU 读出 = OBUF Port A 读出（同周期到达，需要等 OBUF 流水线延迟）
    assign vpu_obuf_dout = obuf_ext_douta_v[BUF_DATA_WIDTH-1:0];

    generate
        if (NUM_GROUPS == 1) begin : gen_obuf_single
            // 单组：直接连接（使用 mux 后的信号）
            assign obuf_ext_wea_v   = obuf_porta_wea;
            assign obuf_ext_ena_v   = obuf_porta_ena;
            assign obuf_ext_addra_v = obuf_porta_addr;
            assign obuf_ext_dina_v  = obuf_porta_din;
        end else begin : gen_obuf_multi
            // 多组：demux（向后兼容，未使用）
            wire [OBUF_GROUP_BITS-1:0] obuf_group_sel;
            assign obuf_group_sel = obuf_ext_addra[ADDR_SHIFT + OBUF_ADDR_W +: OBUF_GROUP_BITS];
            for (_g = 0; _g < NUM_GROUPS; _g = _g + 1) begin : gen_obuf_demux
                assign obuf_ext_wea_v  [_g*STRB_WIDTH    +: STRB_WIDTH]     =
                    (obuf_group_sel == _g) ? obuf_porta_wea : {STRB_WIDTH{1'b0}};
                assign obuf_ext_ena_v  [_g]                                   =
                    (obuf_group_sel == _g) ? obuf_porta_ena : 1'b0;
                assign obuf_ext_addra_v[_g*INT_ADDR_W +: INT_ADDR_W] = obuf_porta_addr;
                assign obuf_ext_dina_v [_g*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = obuf_porta_din;
            end
        end
    endgenerate

    // OBUF Port A 读回：XDMA 直接读 word0
    assign obuf_ext_douta = obuf_ext_douta_v[BUF_DATA_WIDTH-1:0];

    // 读回 MUX：流水线对齐 OBUF 读延迟
    // lite: NUM_GROUPS=1, 直接连接无需 mux
    // OBUF Port A 读回已在上面完成（obuf_ext_douta = obuf_ext_douta_v[127:0]）

    // =========================================================================
    // DCIM_Array 计算核心
    // lite: 内部 BUF_ADDR_WIDTH 统一用 INT_ADDR_W (=OBUF_ADDR_W=20)
    // =========================================================================
    DCIM_Array #(
        .NUM_GROUPS      (NUM_GROUPS),
        .TILES_PER_GROUP (TILES_PER_GROUP),
        .NUM_TILES       (NUM_TILES),
        .WD1             (WD1),
        .CH_IN           (CH_IN),
        .CH_OUT          (CH_OUT),
        .SRAM_DP         (SRAM_DP),
        .CYCLE           (CYCLE),
        .ACC             (ACC),
        .BUF_ADDR_WIDTH  (INT_ADDR_W),
        .BUF_DATA_WIDTH  (BUF_DATA_WIDTH),
        .IBUF_RD_LATENCY (IBUF_RD_LATENCY)
    ) u_dcim_array (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (cfg_start),
        .done            (done),
        .ready           (ready),
        .mode            (cfg_mode),
        .acc_depth       (cfg_acc_depth),
        .act_base_addr   (cfg_act_base_addr),
        .wei_base_addrs  (cfg_wei_base_addrs),
        .out_base_addrs  (cfg_out_base_addrs),
        .tile_mask       (cfg_tile_mask),
        .ibuf_ext_wea    (ibuf_ext_wea_v),
        .ibuf_ext_ena    (ibuf_ext_ena_v),
        .ibuf_ext_addra  (ibuf_ext_addra_v),
        .ibuf_ext_dina   (ibuf_ext_dina_v),
        .ibuf_ext_douta  (ibuf_ext_douta_v),
        .obuf_ext_wea    (obuf_ext_wea_v),
        .obuf_ext_ena    (obuf_ext_ena_v),
        .obuf_ext_addra  (obuf_ext_addra_v),
        .obuf_ext_dina   (obuf_ext_dina_v),
        .obuf_ext_douta  (obuf_ext_douta_v)
    );

endmodule
