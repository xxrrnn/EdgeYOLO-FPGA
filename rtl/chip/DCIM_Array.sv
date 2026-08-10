`timescale 1ns / 1ns
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array - Tile-Array 结构 (chip-v3)
// ============================================================================
// chip-v3 变更（在 chip-v2 基础上）：
//   - 共享 IBUF 拆分为 per-tile tile_ibuf（512KB XPM）
//   - 删除 ibuf_rd_arbiter（每 Tile 直读本地 tile_ibuf Port B，零仲裁延迟）
//   - 外部接口：4 个独立 tile_ibuf_ext_* AXI BRAM 端口（CDMA/XDMA 写入各 Tile IBUF）
// ============================================================================

module DCIM_Array #(
    parameter NUM_TILES            = `DCIM_NUM_TILES,
    parameter WD1                  = `DCIM_WD1,
    parameter CH_IN                = `DCIM_CH_IN,
    parameter CH_OUT               = `DCIM_CH_OUT,
    parameter SRAM_DP              = `DCIM_SRAM_DP,
    parameter CYCLE                = `DCIM_CYCLE,
    parameter ACC                  = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH       = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH       = `DCIM_BUF_DATA_WIDTH,
    parameter TILE_IBUF_ADDR_WIDTH = `DCIM_TILE_IBUF_ADDR_WIDTH,
    parameter TILE_OBUF_ADDR_WIDTH = `DCIM_TILE_OBUF_ADDR_WIDTH,

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
    input  wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] out_base_addrs,
    input  wire [NUM_TILES-1:0]          tile_mask,

    // tile_ibuf[0..3] 外部端口（CDMA/XDMA 写入各 Tile IBUF）
    input  wire [NUM_TILES*STRB_WIDTH-1:0]               tile_ibuf_ext_wea,
    input  wire [NUM_TILES-1:0]                          tile_ibuf_ext_ena,
    input  wire [NUM_TILES*TILE_IBUF_ADDR_WIDTH-1:0]     tile_ibuf_ext_addra,
    input  wire [NUM_TILES*BUF_DATA_WIDTH-1:0]           tile_ibuf_ext_dina,
    output wire [NUM_TILES*BUF_DATA_WIDTH-1:0]           tile_ibuf_ext_douta,

    // tile_obuf[0..3] 外部端口（CDMA 读取 Tile 结果）
    input  wire [NUM_TILES*STRB_WIDTH-1:0]              tile_obuf_ext_wea,
    input  wire [NUM_TILES-1:0]                         tile_obuf_ext_ena,
    input  wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0]    tile_obuf_ext_addra,
    input  wire [NUM_TILES*BUF_DATA_WIDTH-1:0]          tile_obuf_ext_dina,
    output wire [NUM_TILES*BUF_DATA_WIDTH-1:0]          tile_obuf_ext_douta,
    output wire [NUM_TILES-1:0]                         tile_obuf_ext_douta_valid,

    // Minimal peak-TOPS evidence exported to the BD-level ILA.
    output wire [NUM_TILES-1:0]                         peak_compute_mask,
    output wire [31:0]                                  peak_dcim_input,
    output wire                                         peak_result_valid,
    output wire [31:0]                                  peak_result_data
);

    wire [NUM_TILES-1:0] tile_done;
    wire [NUM_TILES-1:0] tile_ready;

    // -----------------------------------------------------------------------
    // SLR 穿越流水寄存器（ready 上行 + start 下行）
    // -----------------------------------------------------------------------
    (* shreg_extract = "no", KEEP = "TRUE" *) reg ready_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ready_r <= 1'b1;
        else        ready_r <= &tile_ready;
    end

    (* shreg_extract = "no", KEEP = "TRUE" *) reg start_r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_r <= 1'b0;
        else        start_r <= start;
    end

    // cfg_* pipeline: 与 start_r 同拍到达 Tile（替代 MCP 4.3b）
    (* shreg_extract = "no" *) reg [2:0]                             mode_r;
    (* shreg_extract = "no" *) reg [ACC_UBD_WD-1:0]                  acc_depth_r;
    (* shreg_extract = "no" *) reg [BUF_ADDR_WIDTH-1:0]              act_base_addr_r;
    (* shreg_extract = "no" *) reg [NUM_TILES*BUF_ADDR_WIDTH-1:0]    wei_base_addrs_r;
    (* shreg_extract = "no" *) reg [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] out_base_addrs_r;
    (* shreg_extract = "no" *) reg [NUM_TILES-1:0]                   tile_mask_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_r           <= 3'b0;
            acc_depth_r      <= {ACC_UBD_WD{1'b0}};
            act_base_addr_r  <= {BUF_ADDR_WIDTH{1'b0}};
            wei_base_addrs_r <= {(NUM_TILES*BUF_ADDR_WIDTH){1'b0}};
            out_base_addrs_r <= {(NUM_TILES*TILE_OBUF_ADDR_WIDTH){1'b0}};
            tile_mask_r      <= {NUM_TILES{1'b1}};
        end else begin
            mode_r           <= mode;
            acc_depth_r      <= acc_depth;
            act_base_addr_r  <= act_base_addr;
            wei_base_addrs_r <= wei_base_addrs;
            out_base_addrs_r <= out_base_addrs;
            tile_mask_r      <= tile_mask;
        end
    end

    assign done  = &(tile_done | ~tile_mask_r);
    assign ready = ready_r;

    // -----------------------------------------------------------------------
    // Tile + tile_ibuf + tile_obuf 实例化
    // -----------------------------------------------------------------------
    // Tile 写 tile_obuf：直连，无仲裁器
    wire [NUM_TILES-1:0]                tile_obuf_wr_valid;
    wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] tile_obuf_wr_addr;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_obuf_wr_data;
    wire [NUM_TILES*STRB_WIDTH-1:0]     tile_obuf_wr_strb;

    // The result probe is output channel 0 of Tile 0, exactly as it is packed
    // into the first host-visible INT8/INT32 OBUF word.
    assign peak_result_valid = tile_obuf_wr_valid[0] &&
                               (tile_obuf_wr_addr[0 +: TILE_OBUF_ADDR_WIDTH] ==
                                out_base_addrs_r[0 +: TILE_OBUF_ADDR_WIDTH]);
    assign peak_result_data  = tile_obuf_wr_data[31:0];

    generate
        genvar i;
        for (i = 0; i < NUM_TILES; i = i + 1) begin : gen_tiles
            localparam TILE_DSP_COL = `DCIM_DSP_COL_NUM;
            localparam TILE_DSP_PARTIAL = `DCIM_DSP_PARTIAL_SUBCOL;

            // Tile 写信号
            wire                          t_wr_valid;
            wire [BUF_ADDR_WIDTH-1:0]     t_wr_addr_full;
            wire [BUF_DATA_WIDTH-1:0]     t_wr_data;
            wire [STRB_WIDTH-1:0]         t_wr_strb;
            wire                          t_peak_compute_fire;
            wire [31:0]                   t_peak_dcim_input;

            assign tile_obuf_wr_valid[i] = t_wr_valid;
            assign tile_obuf_wr_addr[i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH] = t_wr_addr_full[TILE_OBUF_ADDR_WIDTH-1:0];
            assign tile_obuf_wr_data[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = t_wr_data;
            assign tile_obuf_wr_strb[i*STRB_WIDTH +: STRB_WIDTH] = t_wr_strb;
            assign peak_compute_mask[i] = t_peak_compute_fire;

            if (i == 0) begin : gen_peak_tile0
                assign peak_dcim_input = t_peak_dcim_input;
            end

            // tile_ibuf Port B → Tile IBUF 读接口（无仲裁器，直连）
            wire                      t_ibuf_rd_valid;  // Tile → tile_ibuf: 读请求
            wire [BUF_ADDR_WIDTH-1:0] t_ibuf_rd_addr;   // Tile → tile_ibuf: 读地址
            wire                      t_ibuf_rd_data_valid; // tile_ibuf → Tile: 数据有效
            wire [BUF_DATA_WIDTH-1:0] t_ibuf_rd_data;   // tile_ibuf → Tile: 读数据

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
                .MULT_DSP_EN(1),
                .DSP_COL_NUM(TILE_DSP_COL),
                .DSP_PARTIAL_SUBCOL(TILE_DSP_PARTIAL)
            ) u_tile (
                .clk(clk),
                .rst_n(rst_n),
                .start(start_r),
                .tile_enable(tile_mask_r[i]),
                .done(tile_done[i]),
                .ready(tile_ready[i]),
                .mode(mode_r),
                .acc_depth(acc_depth_r),
                .wei_base_addr(wei_base_addrs_r[i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .act_base_addr(act_base_addr_r),
                .out_base_addr({{(BUF_ADDR_WIDTH-TILE_OBUF_ADDR_WIDTH){1'b0}}, out_base_addrs_r[i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH]}),
                .ibuf_rd_en(t_ibuf_rd_valid),
                .ibuf_rd_addr(t_ibuf_rd_addr),
                .ibuf_rd_data_valid(t_ibuf_rd_data_valid),
                .ibuf_rd_data(t_ibuf_rd_data),
                .obuf_wr_valid(t_wr_valid),
                .obuf_wr_ready(1'b1),
                .obuf_wr_addr(t_wr_addr_full),
                .obuf_wr_data(t_wr_data),
                .obuf_wr_strb(t_wr_strb),
                .peak_compute_fire(t_peak_compute_fire),
                .peak_dcim_input(t_peak_dcim_input)
            );

            // Per-tile tile_ibuf 实例（chip-v3: 512KB XPM, Port B 直连 Tile）
            (* keep_hierarchy = "yes" *)
            tile_ibuf u_tile_ibuf (
                .clk(clk),
                // Port A: 外部 CDMA/XDMA 写入
                .wea(tile_ibuf_ext_wea[i*STRB_WIDTH +: STRB_WIDTH]),
                .mem_ena(tile_ibuf_ext_ena[i]),
                .dina(tile_ibuf_ext_dina[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .addra(tile_ibuf_ext_addra[i*TILE_IBUF_ADDR_WIDTH +: TILE_IBUF_ADDR_WIDTH]),
                .douta(tile_ibuf_ext_douta[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .douta_valid(),  // 外部读验证未使用
                // Port B: Tile 内部读（直连，无仲裁器）
                .web({STRB_WIDTH{1'b0}}),
                .mem_enb(t_ibuf_rd_valid),
                .dinb({BUF_DATA_WIDTH{1'b0}}),
                .addrb(t_ibuf_rd_addr[TILE_IBUF_ADDR_WIDTH-1:0]),
                .doutb(t_ibuf_rd_data),
                .doutb_valid(t_ibuf_rd_data_valid)
            );

            // Per-tile tile_obuf 实例
            (* keep_hierarchy = "yes" *)
            tile_obuf u_tile_obuf (
                .clk(clk),
                // Port A: 外部 CDMA 读/写
                .wea(tile_obuf_ext_wea[i*STRB_WIDTH +: STRB_WIDTH]),
                .mem_ena(tile_obuf_ext_ena[i]),
                .dina(tile_obuf_ext_dina[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .addra(tile_obuf_ext_addra[i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH]),
                .douta(tile_obuf_ext_douta[i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .douta_valid(tile_obuf_ext_douta_valid[i]),
                // Port B: Tile 写入（直连，无仲裁）
                .web(t_wr_strb),
                .mem_enb(t_wr_valid),
                .dinb(t_wr_data),
                .addrb(t_wr_addr_full[TILE_OBUF_ADDR_WIDTH-1:0])
            );
        end
    endgenerate

endmodule
