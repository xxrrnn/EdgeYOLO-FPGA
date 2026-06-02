`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array_bd - Vivado Block Design 顶层封装
// ============================================================================
// lite/chip 结构：DCIM_Tile × NUM_TILES + 单 IBUF + 单 OBUF（无 Group 层）。
// ============================================================================

module DCIM_Array_bd #(
    parameter NUM_TILES           = `DCIM_NUM_TILES,
    parameter WD1                 = `DCIM_WD1,
    parameter CH_IN               = `DCIM_CH_IN,
    parameter CH_OUT              = `DCIM_CH_OUT,
    parameter SRAM_DP             = `DCIM_SRAM_DP,
    parameter CYCLE               = `DCIM_CYCLE,
    parameter ACC                 = `DCIM_ACC_MAX,
    parameter IBUF_ADDR_WIDTH     = `DCIM_IBUF_ADDR_WIDTH,
    parameter OBUF_ADDR_WIDTH     = `DCIM_OBUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH      = `DCIM_BUF_DATA_WIDTH,
    parameter AXI_BRAM_ADDR_WIDTH = `DCIM_AXI_BRAM_ADDR_WIDTH,
    parameter IBUF_RD_LATENCY     = `DCIM_IBUF_RD_LATENCY,
    parameter OBUF_EXT_ADDR_BITS  = `DCIM_OBUF_EXT_ADDR_BITS,
    parameter BUF_ADDR_WIDTH      = IBUF_ADDR_WIDTH
)(
    input  wire                          clk,
    input  wire                          rst_n,

    input  wire                          cfg_wr_en,
    input  wire [11:0]                   cfg_wr_addr,
    input  wire [31:0]                   cfg_wr_data,

    input  wire [BUF_DATA_WIDTH/8-1:0]   ibuf_ext_wea,
    input  wire                          ibuf_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    ibuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     ibuf_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   obuf_ext_wea,
    input  wire                          obuf_ext_ena,
    input  wire [OBUF_EXT_ADDR_BITS+3:0] obuf_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     obuf_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_ext_douta,

    input  wire [OBUF_ADDR_WIDTH-1:0]    vpu_obuf_addr,
    input  wire                          vpu_obuf_en,
    input  wire [BUF_DATA_WIDTH/8-1:0]   vpu_obuf_we,
    input  wire [BUF_DATA_WIDTH-1:0]     vpu_obuf_din,
    output wire [BUF_DATA_WIDTH-1:0]     vpu_obuf_dout,
    output wire                          vpu_obuf_rd_valid,

    output wire ready
);

    localparam ADDR_SHIFT = 4;
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8;
    localparam ACC_UBD_WD = $clog2(ACC + 1);
    localparam INT_ADDR_W = OBUF_ADDR_WIDTH;
    localparam TILE_IDX_W = (NUM_TILES <= 1) ? 1 : $clog2(NUM_TILES);

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
    reg [INT_ADDR_W-1:0]                 cfg_act_base_addr;
    reg [NUM_TILES*INT_ADDR_W-1:0]       cfg_wei_base_addrs;
    reg [NUM_TILES*INT_ADDR_W-1:0]       cfg_out_base_addrs;
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
            cfg_act_base_addr <= {INT_ADDR_W{1'b0}};
            cfg_tile_mask     <= {NUM_TILES{1'b1}};
            for (_i = 0; _i < NUM_TILES; _i = _i + 1) begin
                cfg_wei_base_addrs[_i*INT_ADDR_W +: INT_ADDR_W] <= {INT_ADDR_W{1'b0}};
                cfg_out_base_addrs[_i*INT_ADDR_W +: INT_ADDR_W] <= {INT_ADDR_W{1'b0}};
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
                    cfg_act_base_addr <= { {(INT_ADDR_W-IBUF_ADDR_WIDTH){1'b0}}, cfg_wr_data_d[IBUF_ADDR_WIDTH-1:0] };
                end else if (cfg_wr_wei_range) begin
                    cfg_wei_base_addrs[cfg_wr_wei_tile_idx*INT_ADDR_W +: INT_ADDR_W]
                        <= { {(INT_ADDR_W-IBUF_ADDR_WIDTH){1'b0}}, cfg_wr_data_d[IBUF_ADDR_WIDTH-1:0] };
                end else if (cfg_wr_out_range) begin
                    cfg_out_base_addrs[cfg_wr_out_tile_idx*INT_ADDR_W +: INT_ADDR_W]
                        <= cfg_wr_data_d[INT_ADDR_W-1:0];
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

    wire [INT_ADDR_W-1:0] ibuf_word_addr;
    assign ibuf_word_addr = { {(INT_ADDR_W-IBUF_ADDR_WIDTH){1'b0}}, ibuf_ext_addra[ADDR_SHIFT +: IBUF_ADDR_WIDTH] };

    wire vpu_use_port_a = vpu_obuf_en;
    wire [INT_ADDR_W-1:0] xdma_obuf_word_addr = obuf_ext_addra[ADDR_SHIFT +: OBUF_ADDR_WIDTH];

    wire                     obuf_porta_ena;
    wire [STRB_WIDTH-1:0]    obuf_porta_wea;
    wire [INT_ADDR_W-1:0]    obuf_porta_addr;
    wire [BUF_DATA_WIDTH-1:0] obuf_porta_din;

    assign obuf_porta_ena  = vpu_use_port_a ? 1'b1         : obuf_ext_ena;
    assign obuf_porta_wea  = vpu_use_port_a ? vpu_obuf_we  : obuf_ext_wea;
    assign obuf_porta_addr = vpu_use_port_a ? vpu_obuf_addr : xdma_obuf_word_addr;
    assign obuf_porta_din  = vpu_use_port_a ? vpu_obuf_din : obuf_ext_dina;

    wire array_obuf_douta_valid;

    assign vpu_obuf_dout     = obuf_ext_douta;
    assign vpu_obuf_rd_valid = array_obuf_douta_valid;

    DCIM_Array #(
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
        .done            (),
        .ready           (ready),
        .mode            (cfg_mode),
        .acc_depth       (cfg_acc_depth),
        .act_base_addr   (cfg_act_base_addr),
        .wei_base_addrs  (cfg_wei_base_addrs),
        .out_base_addrs  (cfg_out_base_addrs),
        .tile_mask       (cfg_tile_mask),
        .ibuf_ext_wea    (ibuf_ext_wea),
        .ibuf_ext_ena    (ibuf_ext_ena),
        .ibuf_ext_addra  (ibuf_word_addr),
        .ibuf_ext_dina   (ibuf_ext_dina),
        .ibuf_ext_douta  (ibuf_ext_douta),
        .obuf_ext_wea    (obuf_porta_wea),
        .obuf_ext_ena    (obuf_porta_ena),
        .obuf_ext_addra  (obuf_porta_addr),
        .obuf_ext_dina   (obuf_porta_din),
        .obuf_ext_douta  (obuf_ext_douta),
        .obuf_ext_douta_valid(array_obuf_douta_valid)
    );

endmodule
