`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array - Tile-Array 结构
// ============================================================================
// 当前 lite/chip 目标取消 Group 层：
//   DCIM_Array = NUM_TILES 个 DCIM_Tile + 1 个共享 IBUF + 1 个共享 OBUF
//
// 设计目标：250MHz 时序收敛优先；IBUF/OBUF 访问均通过保守仲裁器串行化，
// 不追求 Tile 间读写吞吐，只保证功能一致和峰值计算阵列规模。
// ============================================================================

module DCIM_Array #(
    parameter NUM_TILES       = `DCIM_NUM_TILES,
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter SRAM_DP         = `DCIM_SRAM_DP,
    parameter CYCLE           = `DCIM_CYCLE,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH  = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,

    localparam ACC_UBD_WD = $clog2(ACC+1),
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire                          start,
    output wire                          done,
    output wire                          ready,

    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] wei_base_addrs,
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] out_base_addrs,
    input  wire [NUM_TILES-1:0]          tile_mask,

    input  wire [STRB_WIDTH-1:0]         ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     ibuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,

    input  wire [STRB_WIDTH-1:0]         obuf_ext_wea,
    input  wire                          obuf_ext_ena,
    input  wire [BUF_ADDR_WIDTH-1:0]     obuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_ext_douta,
    output wire                          obuf_ext_douta_valid
);

    wire [NUM_TILES-1:0] tile_done;
    wire [NUM_TILES-1:0] tile_ready;

    // -----------------------------------------------------------------------
    // SLR 穿越流水寄存器
    // -----------------------------------------------------------------------
    // ready 上行（SLR2/SLR1 Tile → SLR0 INST_Decoder）：
    //   worst path = tile[3](SLR2) → ready(SLR0)，直跨 2 个 SLR，routing 2.78 ns。
    //   在 DCIM_Array 顶层增加 1 级寄存器，Vivado 可将其放置于 SLR1 的 SLL TX 侧，
    //   把 SLR2→SLR0 的直跨拆成 SLR2→SLR1→SLR0 两段，每段约 1.0 ns，完全满足 4 ns 周期。
    //   功能安全性：INST_Decoder 用 dcim_layer_seen_busy 先捕捉 ready=0（忙），
    //   再等 ready=1（完成），延迟 1 拍仅意味着 INST_Decoder 多等 1 个时钟才感知到完成，
    //   不影响计算结果的正确性，也不影响 start 握手（seen_busy 保证 start 已先到达）。
    (* shreg_extract = "no", KEEP = "TRUE" *) reg ready_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ready_r <= 1'b1;   // 复位后 IDLE 即 ready
        else        ready_r <= &tile_ready;
    end

    // start 下行（SLR0 INST_Decoder → SLR1/SLR2 Tile）：
    //   start 原来由 DCIM_Array_bd 的 cfg_start 寄存器驱动（已有 1 级），
    //   再在 DCIM_Array 内部增加 1 级，确保 SLR0→SLR2 不直跨。
    //   功能安全性：start 为单周期脉冲，延迟 1 拍后 Tile 仍能正常捕捉启动沿；
    //   此时 ready_r=0 已先到达 INST_Decoder（因为 Tile 收到 start 后下一周期就拉低 ready），
    //   INST_Decoder 不会误判"已完成"。
    (* shreg_extract = "no", KEEP = "TRUE" *) reg start_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_r <= 1'b0;
        else        start_r <= start;
    end

    assign done  = &(tile_done | ~tile_mask);
    assign ready = ready_r;

    wire [NUM_TILES-1:0]                tile_ibuf_rd_valid;
    wire [NUM_TILES-1:0]                tile_ibuf_rd_ready;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_ibuf_rd_addr;
    wire [NUM_TILES-1:0]                tile_ibuf_rd_data_valid;
    wire [BUF_DATA_WIDTH-1:0]           tile_ibuf_rd_data;

    wire [NUM_TILES-1:0]                tile_obuf_wr_valid;
    wire [NUM_TILES-1:0]                tile_obuf_wr_ready;
    wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_obuf_wr_addr;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_obuf_wr_data;
    wire [NUM_TILES*STRB_WIDTH-1:0]     tile_obuf_wr_strb;

    // SLR crossing registers for obuf_wr signals (Tile→Arbiter)
    (* shreg_extract = "no" *) reg [NUM_TILES-1:0]                tile_obuf_wr_valid_q;
    (* shreg_extract = "no" *) reg [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_obuf_wr_addr_q;
    (* shreg_extract = "no" *) reg [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_obuf_wr_data_q;
    (* shreg_extract = "no" *) reg [NUM_TILES*STRB_WIDTH-1:0]     tile_obuf_wr_strb_q;

    always @(posedge clk) begin
        tile_obuf_wr_valid_q <= tile_obuf_wr_valid;
        tile_obuf_wr_addr_q  <= tile_obuf_wr_addr;
        tile_obuf_wr_data_q  <= tile_obuf_wr_data;
        tile_obuf_wr_strb_q  <= tile_obuf_wr_strb;
    end

    wire                          ibuf_int_en;
    wire [BUF_ADDR_WIDTH-1:0]     ibuf_int_addr;
    wire [BUF_DATA_WIDTH-1:0]     ibuf_int_dout_raw;
    (* shreg_extract = "no", max_fanout = 32 *) reg [BUF_DATA_WIDTH-1:0] ibuf_int_dout;

    always @(posedge clk) begin
        ibuf_int_dout <= ibuf_int_dout_raw;
    end

    wire                          obuf_int_en;
    wire [STRB_WIDTH-1:0]         obuf_int_we;
    wire [BUF_ADDR_WIDTH-1:0]     obuf_int_addr;
    wire [BUF_DATA_WIDTH-1:0]     obuf_int_din;

    generate
        genvar i;
        for (i = 0; i < NUM_TILES; i = i + 1) begin : gen_tiles
            (* keep_hierarchy = "yes" *)
            DCIM_Tile #(
                .WD1(WD1),
                .CH_IN(CH_IN),
                .CH_OUT(CH_OUT),
                .SRAM_DP(SRAM_DP),
                .CYCLE(CYCLE),
                .ACC(ACC),
                .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
                .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
                .TILE_IDX(i),
                // Per-Tile 部分 DSP：所有 Tile 均启用 DSP，
                // 内部 maArray 按 col_idx < DCIM_DSP_COL_NUM 选择 DSP/LUT，
                // 按 DCIM_DSP_PARTIAL_SUBCOL 控制第 DSP_COL_NUM 列的 subcol 级粒度。
                .MULT_DSP_EN(1),
                .DSP_COL_NUM(`DCIM_DSP_COL_NUM),
                .DSP_PARTIAL_SUBCOL(`DCIM_DSP_PARTIAL_SUBCOL)
            ) u_tile (
                .clk(clk),
                .rst_n(rst_n),
                .start(start_r),
                .tile_enable(tile_mask[i]),
                .done(tile_done[i]),
                .ready(tile_ready[i]),
                .mode(mode),
                .acc_depth(acc_depth),
                .wei_base_addr(wei_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .act_base_addr(act_base_addr),
                .out_base_addr(out_base_addrs[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_rd_valid(tile_ibuf_rd_valid[i]),
                .ibuf_rd_ready(tile_ibuf_rd_ready[i]),
                .ibuf_rd_addr(tile_ibuf_rd_addr[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .ibuf_rd_data_valid(tile_ibuf_rd_data_valid[i]),
                .ibuf_rd_data(tile_ibuf_rd_data),
                .obuf_wr_valid(tile_obuf_wr_valid[i]),
                .obuf_wr_ready(tile_obuf_wr_ready[i]),
                .obuf_wr_addr(tile_obuf_wr_addr[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .obuf_wr_data(tile_obuf_wr_data[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .obuf_wr_strb(tile_obuf_wr_strb[i*STRB_WIDTH +: STRB_WIDTH])
            );
        end
    endgenerate

    ibuf_rd_arbiter #(
        .NUM_TILES(NUM_TILES),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_ibuf_arb (
        .clk(clk),
        .rst_n(rst_n),
        .tile_rd_valid(tile_ibuf_rd_valid),
        .tile_rd_ready(tile_ibuf_rd_ready),
        .tile_rd_addr(tile_ibuf_rd_addr),
        .tile_rd_data_valid(tile_ibuf_rd_data_valid),
        .tile_rd_data(tile_ibuf_rd_data),
        .ibuf_en(ibuf_int_en),
        .ibuf_addr(ibuf_int_addr),
        .ibuf_dout(ibuf_int_dout)
    );

    obuf_wr_arbiter #(
        .NUM_TILES(NUM_TILES),
        .ADDR_WIDTH(BUF_ADDR_WIDTH),
        .DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_obuf_arb (
        .clk(clk),
        .rst_n(rst_n),
        .tile_wr_valid(tile_obuf_wr_valid_q),
        .tile_wr_ready(tile_obuf_wr_ready),
        .tile_wr_addr(tile_obuf_wr_addr_q),
        .tile_wr_data(tile_obuf_wr_data_q),
        .tile_wr_strb(tile_obuf_wr_strb_q),
        .obuf_en(obuf_int_en),
        .obuf_we(obuf_int_we),
        .obuf_addr(obuf_int_addr),
        .obuf_din(obuf_int_din)
    );

    ibuf u_ibuf (
        .clk(clk),
        .wea(ibuf_ext_wea),
        .mem_ena(ibuf_ext_ena),
        .dina(ibuf_ext_dina),
        .addra(ibuf_ext_addra[`DCIM_IBUF_ADDR_WIDTH-1:0]),
        .douta(ibuf_ext_douta),
        .web({STRB_WIDTH{1'b0}}),
        .mem_enb(ibuf_int_en),
        .dinb({BUF_DATA_WIDTH{1'b0}}),
        .addrb(ibuf_int_addr[`DCIM_IBUF_ADDR_WIDTH-1:0]),
        .doutb(ibuf_int_dout_raw)
    );

    obuf u_obuf (
        .clk(clk),
        .wea(obuf_ext_wea),
        .mem_ena(obuf_ext_ena),
        .dina(obuf_ext_dina),
        .addra(obuf_ext_addra),
        .douta(obuf_ext_douta),
        .douta_valid(obuf_ext_douta_valid),
        .web(obuf_int_we),
        .mem_enb(obuf_int_en),
        .dinb(obuf_int_din),
        .addrb(obuf_int_addr),
        .doutb()
    );

endmodule
