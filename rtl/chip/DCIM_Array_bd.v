`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// DCIM_Array_bd - Vivado Block Design top wrapper (chip-v3 XPM, 8-tile)
// ============================================================================
// Per-tile split ports for BD module reference compatibility.
// Internal logic uses generate loops - adding tiles only requires updating
// chip_defines.vh (DCIM_NUM_TILES) and regenerating BD.
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

    input  wire                          cfg_wr_en,
    input  wire [11:0]                   cfg_wr_addr,
    input  wire [31:0]                   cfg_wr_data,

    // tile_ibuf[0..7] split ports (BD module reference requires named ports)
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf0_ext_wea,
    input  wire                          tile_ibuf0_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf0_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf0_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf0_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf1_ext_wea,
    input  wire                          tile_ibuf1_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf1_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf1_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf1_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf2_ext_wea,
    input  wire                          tile_ibuf2_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf2_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf2_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf2_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf3_ext_wea,
    input  wire                          tile_ibuf3_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf3_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf3_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf3_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf4_ext_wea,
    input  wire                          tile_ibuf4_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf4_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf4_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf4_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf5_ext_wea,
    input  wire                          tile_ibuf5_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf5_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf5_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf5_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf6_ext_wea,
    input  wire                          tile_ibuf6_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf6_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf6_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf6_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_ibuf7_ext_wea,
    input  wire                          tile_ibuf7_ext_ena,
    input  wire [IBUF_ADDR_WIDTH+3:0]    tile_ibuf7_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_ibuf7_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_ibuf7_ext_douta,

    // tile_obuf[0..7] split ports
    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf0_ext_wea,
    input  wire                          tile_obuf0_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf0_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf0_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf0_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf1_ext_wea,
    input  wire                          tile_obuf1_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf1_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf1_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf1_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf2_ext_wea,
    input  wire                          tile_obuf2_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf2_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf2_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf2_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf3_ext_wea,
    input  wire                          tile_obuf3_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf3_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf3_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf3_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf4_ext_wea,
    input  wire                          tile_obuf4_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf4_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf4_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf4_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf5_ext_wea,
    input  wire                          tile_obuf5_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf5_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf5_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf5_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf6_ext_wea,
    input  wire                          tile_obuf6_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf6_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf6_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf6_ext_douta,

    input  wire [BUF_DATA_WIDTH/8-1:0]   tile_obuf7_ext_wea,
    input  wire                          tile_obuf7_ext_ena,
    input  wire [TILE_OBUF_ADDR_WIDTH+3:0] tile_obuf7_ext_addra,
    input  wire [BUF_DATA_WIDTH-1:0]     tile_obuf7_ext_dina,
    output wire [BUF_DATA_WIDTH-1:0]     tile_obuf7_ext_douta,

    output wire ready
);

    localparam ADDR_SHIFT = 4;
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8;
    localparam ACC_UBD_WD = $clog2(ACC + 1);
    localparam TILE_IDX_W = (NUM_TILES <= 1) ? 1 : $clog2(NUM_TILES);

    // -----------------------------------------------------------------------
    // ready pipeline (SLR crossing buffer)
    // -----------------------------------------------------------------------
    wire ready_internal;
    (* shreg_extract = "no", KEEP = "TRUE" *) reg ready_pipe;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ready_pipe <= 1'b1;
        else        ready_pipe <= ready_internal;
    end
    assign ready = ready_pipe;

    // -----------------------------------------------------------------------
    // Configuration registers (unchanged from original)
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
    // Split port -> packed vector assembly (generate loop)
    // -----------------------------------------------------------------------
    wire [NUM_TILES*STRB_WIDTH-1:0]          ibuf_wea_vec;
    wire [NUM_TILES-1:0]                     ibuf_ena_vec;
    wire [NUM_TILES*IBUF_ADDR_WIDTH-1:0]     ibuf_addra_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]      ibuf_dina_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]      ibuf_douta_vec;

    wire [NUM_TILES*STRB_WIDTH-1:0]          obuf_wea_vec;
    wire [NUM_TILES-1:0]                     obuf_ena_vec;
    wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] obuf_addra_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]      obuf_dina_vec;
    wire [NUM_TILES*BUF_DATA_WIDTH-1:0]      obuf_douta_vec;

    // --- tile_ibuf assembly (split ports -> vector) ---
    `define IBUF_ASSIGN(IDX) \
        assign ibuf_wea_vec[IDX*STRB_WIDTH +: STRB_WIDTH] = tile_ibuf``IDX``_ext_wea; \
        assign ibuf_ena_vec[IDX] = tile_ibuf``IDX``_ext_ena; \
        assign ibuf_addra_vec[IDX*IBUF_ADDR_WIDTH +: IBUF_ADDR_WIDTH] = tile_ibuf``IDX``_ext_addra[ADDR_SHIFT +: IBUF_ADDR_WIDTH]; \
        assign ibuf_dina_vec[IDX*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = tile_ibuf``IDX``_ext_dina; \
        assign tile_ibuf``IDX``_ext_douta = ibuf_douta_vec[IDX*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];

    `IBUF_ASSIGN(0)
    `IBUF_ASSIGN(1)
    `IBUF_ASSIGN(2)
    `IBUF_ASSIGN(3)
    `IBUF_ASSIGN(4)
    `IBUF_ASSIGN(5)
    `IBUF_ASSIGN(6)
    `IBUF_ASSIGN(7)
    `undef IBUF_ASSIGN

    // --- tile_obuf assembly (split ports -> vector) ---
    `define OBUF_ASSIGN(IDX) \
        assign obuf_wea_vec[IDX*STRB_WIDTH +: STRB_WIDTH] = tile_obuf``IDX``_ext_wea; \
        assign obuf_ena_vec[IDX] = tile_obuf``IDX``_ext_ena; \
        assign obuf_addra_vec[IDX*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH] = tile_obuf``IDX``_ext_addra[ADDR_SHIFT +: TILE_OBUF_ADDR_WIDTH]; \
        assign obuf_dina_vec[IDX*BUF_DATA_WIDTH +: BUF_DATA_WIDTH] = tile_obuf``IDX``_ext_dina; \
        assign tile_obuf``IDX``_ext_douta = obuf_douta_vec[IDX*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];

    `OBUF_ASSIGN(0)
    `OBUF_ASSIGN(1)
    `OBUF_ASSIGN(2)
    `OBUF_ASSIGN(3)
    `OBUF_ASSIGN(4)
    `OBUF_ASSIGN(5)
    `OBUF_ASSIGN(6)
    `OBUF_ASSIGN(7)
    `undef OBUF_ASSIGN

    // -----------------------------------------------------------------------
    // DCIM_Array instantiation
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
        .tile_ibuf_ext_wea    (ibuf_wea_vec),
        .tile_ibuf_ext_ena    (ibuf_ena_vec),
        .tile_ibuf_ext_addra  (ibuf_addra_vec),
        .tile_ibuf_ext_dina   (ibuf_dina_vec),
        .tile_ibuf_ext_douta  (ibuf_douta_vec),
        .tile_obuf_ext_wea         (obuf_wea_vec),
        .tile_obuf_ext_ena         (obuf_ena_vec),
        .tile_obuf_ext_addra       (obuf_addra_vec),
        .tile_obuf_ext_dina        (obuf_dina_vec),
        .tile_obuf_ext_douta       (obuf_douta_vec),
        .tile_obuf_ext_douta_valid ()
    );

endmodule
