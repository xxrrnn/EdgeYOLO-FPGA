`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array_bd - Vivado Block Design 顶层封装 (chip-v3 XPM)
// ============================================================================
// chip-v3 变更：
//   - 删除单个 ibuf_ext_* 端口（旧共享 IBUF）
//   - 新增 4 组 tile_ibuf*_ext_* AXI BRAM 端口（per-tile IBUF）
//   - 4 组 tile_obuf*_ext_* AXI BRAM 端口（CDMA 读取各 Tile 结果）
// ============================================================================

module DCIM_Array_bd #(
    parameter NUM_TILES           = `DCIM_NUM_TILES,
    parameter WD1                 = `DCIM_WD1,
    parameter CH_IN               = `DCIM_CH_IN,
    parameter CH_OUT              = `DCIM_CH_OUT,
    parameter SRAM_DP             = `DCIM_SRAM_DP,
    parameter CYCLE               = `DCIM_CYCLE,
    parameter ACC                 = `DCIM_ACC_MAX,
    parameter IBUF_ADDR_WIDTH     = `DCIM_TILE_IBUF_ADDR_WIDTH,
    parameter TILE_OBUF_ADDR_WIDTH = `DCIM_TILE_OBUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH      = `DCIM_BUF_DATA_WIDTH,
    parameter BUF_ADDR_WIDTH      = IBUF_ADDR_WIDTH
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // 配置寄存器写入（来自 INST_Decoder）
    input  wire                          cfg_wr_en,
    input  wire [11:0]                   cfg_wr_addr,
    input  wire [31:0]                   cfg_wr_data,

    // tile_ibuf[0] 外部端口（XDMA/CDMA write + read）
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf0_ext_wea,
    input  wire                          tile_ibuf0_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf0_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf0_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf0_ext_douta,

    // tile_ibuf[1] 外部端口
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf1_ext_wea,
    input  wire                          tile_ibuf1_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf1_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf1_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf1_ext_douta,

    // tile_ibuf[2] 外部端口
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf2_ext_wea,
    input  wire                          tile_ibuf2_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf2_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf2_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf2_ext_douta,

    // tile_ibuf[3] 外部端口
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf3_ext_wea,
    input  wire                          tile_ibuf3_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf3_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf3_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf3_ext_douta,

    // tile_obuf[0] 外部端口
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf0_ext_wea,
    input  wire                          tile_obuf0_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf0_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf0_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf0_ext_douta,

    // tile_obuf[1] 外部端口
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf1_ext_wea,
    input  wire                          tile_obuf1_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf1_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf1_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf1_ext_douta,

    // tile_obuf[2] 外部端口
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf2_ext_wea,
    input  wire                          tile_obuf2_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf2_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf2_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf2_ext_douta,

    // tile_obuf[3] 外部端口
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf3_ext_wea,
    input  wire                          tile_obuf3_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf3_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf3_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf3_ext_douta,

    output wire ready
);

    localparam ADDR_SHIFT = 4;  // 128bit = 16 bytes → 4 bit shift

    // SLR 穿越 pipeline: ready 从 DCIM_Array 上行到 inst_decoder（替代 MCP 4.3a）
    wire ready_internal;
    (* shreg_extract = "no", KEEP = "TRUE" *) reg ready_pipe;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ready_pipe <= 1'b1;
        else        ready_pipe <= ready_internal;
    end
    assign ready = ready_pipe;
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8;
    localparam ACC_UBD_WD = $clog2(ACC + 1);
    localparam TILE_IDX_W = (NUM_TILES <= 1) ? 1 : $clog2(NUM_TILES);

    // -----------------------------------------------------------------------
    // 配置寄存器逻辑
    // -----------------------------------------------------------------------
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

    reg                                  cfg_start;
    reg [2:0]                            cfg_mode;
    reg [ACC_UBD_WD-1:0]                 cfg_acc_depth;
    reg [IBUF_ADDR_WIDTH-1:0]            cfg_act_base_addr;
    reg [NUM_TILES*IBUF_ADDR_WIDTH-1:0]  cfg_wei_base_addrs;
    reg [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] cfg_out_base_addrs;
    reg [NUM_TILES-1:0]                  cfg_tile_mask;

    wire cfg_wr_wei_range = (cfg_wr_addr_d >= `DCIM_REG_WEI_BASE) &&
                            (cfg_wr_addr_d < (`DCIM_REG_WEI_BASE + (NUM_TILES << 2)));
    wire cfg_wr_out_range = (cfg_wr_addr_d >= `DCIM_REG_OUT_BASE) &&
                            (cfg_wr_addr_d < (`DCIM_REG_OUT_BASE + (NUM_TILES << 2)));
    wire [TILE_IDX_W-1:0] cfg_wr_wei_tile_idx = (cfg_wr_addr_d - `DCIM_REG_WEI_BASE) >> 2;
    wire [TILE_IDX_W-1:0] cfg_wr_out_tile_idx = (cfg_wr_addr_d - `DCIM_REG_OUT_BASE) >> 2;

    integer _i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cfg_start         <= 1'b0;
            cfg_mode          <= `MODE_INT8;
            cfg_acc_depth     <= {ACC_UBD_WD{1'b0}};
            cfg_act_base_addr <= {IBUF_ADDR_WIDTH{1'b0}};
            cfg_tile_mask     <= {NUM_TILES{1'b1}};
            for (_i = 0; _i < NUM_TILES; _i = _i + 1) begin
                cfg_wei_base_addrs[_i*IBUF_ADDR_WIDTH +: IBUF_ADDR_WIDTH] <= {IBUF_ADDR_WIDTH{1'b0}};
                cfg_out_base_addrs[_i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH] <= {TILE_OBUF_ADDR_WIDTH{1'b0}};
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
                    cfg_act_base_addr <= cfg_wr_data_d[IBUF_ADDR_WIDTH-1:0];
                end else if (cfg_wr_wei_range) begin
                    cfg_wei_base_addrs[cfg_wr_wei_tile_idx*IBUF_ADDR_WIDTH +: IBUF_ADDR_WIDTH]
                        <= cfg_wr_data_d[IBUF_ADDR_WIDTH-1:0];
                end else if (cfg_wr_out_range) begin
                    cfg_out_base_addrs[cfg_wr_out_tile_idx*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH]
                        <= cfg_wr_data_d[TILE_OBUF_ADDR_WIDTH-1:0];
                end else if (cfg_wr_addr_d == `DCIM_REG_TILE_MASK) begin
                    for (_i = 0; _i < NUM_TILES; _i = _i + 1) begin
                        if (_i < 32)
                            cfg_tile_mask[_i] <= cfg_wr_data_d[_i];
                        else
                            cfg_tile_mask[_i] <= 1'b0;
                    end
                end else if (cfg_wr_addr_d == `DCIM_REG_TILE_MASK_HI) begin
                    for (_i = 0; _i < NUM_TILES; _i = _i + 1) begin
                        if (_i >= 32)
                            cfg_tile_mask[_i] <= cfg_wr_data_d[_i-32];
                    end
                end
            end
        end
    end

    // -----------------------------------------------------------------------
    // AXI 字节地址 → 字地址 转换
    // -----------------------------------------------------------------------
    // tile_ibuf 外部地址转换
    wire [IBUF_ADDR_WIDTH-1:0] tibuf0_word_addr = tile_ibuf0_ext_addra[ADDR_SHIFT +: IBUF_ADDR_WIDTH];
    wire [IBUF_ADDR_WIDTH-1:0] tibuf1_word_addr = tile_ibuf1_ext_addra[ADDR_SHIFT +: IBUF_ADDR_WIDTH];
    wire [IBUF_ADDR_WIDTH-1:0] tibuf2_word_addr = tile_ibuf2_ext_addra[ADDR_SHIFT +: IBUF_ADDR_WIDTH];
    wire [IBUF_ADDR_WIDTH-1:0] tibuf3_word_addr = tile_ibuf3_ext_addra[ADDR_SHIFT +: IBUF_ADDR_WIDTH];

    // tile_obuf 外部地址转换
    wire [TILE_OBUF_ADDR_WIDTH-1:0] tobuf0_word_addr = tile_obuf0_ext_addra[ADDR_SHIFT +: TILE_OBUF_ADDR_WIDTH];
    wire [TILE_OBUF_ADDR_WIDTH-1:0] tobuf1_word_addr = tile_obuf1_ext_addra[ADDR_SHIFT +: TILE_OBUF_ADDR_WIDTH];
    wire [TILE_OBUF_ADDR_WIDTH-1:0] tobuf2_word_addr = tile_obuf2_ext_addra[ADDR_SHIFT +: TILE_OBUF_ADDR_WIDTH];
    wire [TILE_OBUF_ADDR_WIDTH-1:0] tobuf3_word_addr = tile_obuf3_ext_addra[ADDR_SHIFT +: TILE_OBUF_ADDR_WIDTH];

    // -----------------------------------------------------------------------
    // 组装 tile_ibuf 外部端口向量
    // -----------------------------------------------------------------------
    wire [NUM_TILES*STRB_WIDTH-1:0]          tile_ibuf_ext_wea_vec;
    wire [NUM_TILES-1:0]                     tile_ibuf_ext_ena_vec;
    wire [NUM_TILES*IBUF_ADDR_WIDTH-1:0]     tile_ibuf_ext_addra_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]      tile_ibuf_ext_dina_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]      tile_ibuf_ext_douta_vec;

    assign tile_ibuf_ext_wea_vec   = {tile_ibuf3_ext_wea,  tile_ibuf2_ext_wea,  tile_ibuf1_ext_wea,  tile_ibuf0_ext_wea};
    assign tile_ibuf_ext_ena_vec   = {tile_ibuf3_ext_ena,  tile_ibuf2_ext_ena,  tile_ibuf1_ext_ena,  tile_ibuf0_ext_ena};
    assign tile_ibuf_ext_addra_vec = {tibuf3_word_addr, tibuf2_word_addr, tibuf1_word_addr, tibuf0_word_addr};
    assign tile_ibuf_ext_dina_vec  = {tile_ibuf3_ext_dina, tile_ibuf2_ext_dina, tile_ibuf1_ext_dina, tile_ibuf0_ext_dina};

    assign tile_ibuf0_ext_douta = tile_ibuf_ext_douta_vec[0*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    assign tile_ibuf1_ext_douta = tile_ibuf_ext_douta_vec[1*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    assign tile_ibuf2_ext_douta = tile_ibuf_ext_douta_vec[2*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    assign tile_ibuf3_ext_douta = tile_ibuf_ext_douta_vec[3*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];

    // -----------------------------------------------------------------------
    // 组装 tile_obuf 外部端口向量
    // -----------------------------------------------------------------------
    wire [NUM_TILES*STRB_WIDTH-1:0]           tile_obuf_ext_wea_vec;
    wire [NUM_TILES-1:0]                      tile_obuf_ext_ena_vec;
    wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] tile_obuf_ext_addra_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]       tile_obuf_ext_dina_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]       tile_obuf_ext_douta_vec;
    wire [NUM_TILES-1:0]                      tile_obuf_ext_douta_valid_vec;

    assign tile_obuf_ext_wea_vec   = {tile_obuf3_ext_wea,  tile_obuf2_ext_wea,  tile_obuf1_ext_wea,  tile_obuf0_ext_wea};
    assign tile_obuf_ext_ena_vec   = {tile_obuf3_ext_ena,  tile_obuf2_ext_ena,  tile_obuf1_ext_ena,  tile_obuf0_ext_ena};
    assign tile_obuf_ext_addra_vec = {tobuf3_word_addr, tobuf2_word_addr, tobuf1_word_addr, tobuf0_word_addr};
    assign tile_obuf_ext_dina_vec  = {tile_obuf3_ext_dina, tile_obuf2_ext_dina, tile_obuf1_ext_dina, tile_obuf0_ext_dina};

    assign tile_obuf0_ext_douta = tile_obuf_ext_douta_vec[0*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    assign tile_obuf1_ext_douta = tile_obuf_ext_douta_vec[1*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    assign tile_obuf2_ext_douta = tile_obuf_ext_douta_vec[2*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];
    assign tile_obuf3_ext_douta = tile_obuf_ext_douta_vec[3*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];

    // -----------------------------------------------------------------------
    // DCIM_Array 实例化
    // -----------------------------------------------------------------------
    DCIM_Array #(
        .NUM_TILES       (NUM_TILES),
        .WD1             (WD1),
        .CH_IN           (CH_IN),
        .CH_OUT          (CH_OUT),
        .SRAM_DP         (SRAM_DP),
        .CYCLE           (CYCLE),
        .ACC             (ACC),
        .BUF_ADDR_WIDTH  (IBUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH  (BUF_DATA_WIDTH),
        .TILE_IBUF_ADDR_WIDTH(IBUF_ADDR_WIDTH),
        .TILE_OBUF_ADDR_WIDTH(TILE_OBUF_ADDR_WIDTH)
    ) u_dcim_array (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (cfg_start),
        .done            (),
        .ready           (ready_internal),
        .mode            (cfg_mode),
        .acc_depth       (cfg_acc_depth),
        .act_base_addr   (cfg_act_base_addr),
        .wei_base_addrs  (cfg_wei_base_addrs),
        .out_base_addrs  (cfg_out_base_addrs),
        .tile_mask       (cfg_tile_mask),
        // per-tile IBUF
        .tile_ibuf_ext_wea    (tile_ibuf_ext_wea_vec),
        .tile_ibuf_ext_ena    (tile_ibuf_ext_ena_vec),
        .tile_ibuf_ext_addra  (tile_ibuf_ext_addra_vec),
        .tile_ibuf_ext_dina   (tile_ibuf_ext_dina_vec),
        .tile_ibuf_ext_douta  (tile_ibuf_ext_douta_vec),
        // per-tile OBUF
        .tile_obuf_ext_wea         (tile_obuf_ext_wea_vec),
        .tile_obuf_ext_ena         (tile_obuf_ext_ena_vec),
        .tile_obuf_ext_addra       (tile_obuf_ext_addra_vec),
        .tile_obuf_ext_dina        (tile_obuf_ext_dina_vec),
        .tile_obuf_ext_douta       (tile_obuf_ext_douta_vec),
        .tile_obuf_ext_douta_valid (tile_obuf_ext_douta_valid_vec)
    );

endmodule
