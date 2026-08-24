`timescale 1ns / 1ns
`include "chip_defines.vh"

// Eight independently placed DCIM Tiles with private IBUF/OBUF memories.
// Both physical ports are reused only while a Tile is active:
//   IBUF: 2 x 128-bit reads/cycle = the exact DCIM phase demand.
//   OBUF: 2 x 128-bit writes/cycle = one 512-bit result in two cycles.
// The host-visible memory map remains pixel-major and unchanged.
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

    localparam ACC_UBD_WD = $clog2(ACC + 1),
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8,
    localparam PEAK_JOB_W = $clog2(64)
)(
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              start,
    output wire                              done,
    output wire                              ready,

    input  wire [2:0]                        mode,
    input  wire [ACC_UBD_WD-1:0]             acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]         act_base_addr,
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0] wei_base_addrs,
    input  wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] out_base_addrs,
    input  wire [NUM_TILES-1:0]              tile_mask,
    input  wire                              batch_enable,
    input  wire [31:0]                       batch_count,
    input  wire                              benchmark_repeat,
    input  wire [31:0]                       repeat_count,
    input  wire [BUF_ADDR_WIDTH-1:0]         act_stride_words,
    input  wire [TILE_OBUF_ADDR_WIDTH-1:0]   out_stride_words,

    input  wire [NUM_TILES*STRB_WIDTH-1:0]   tile_ibuf_ext_wea,
    input  wire [NUM_TILES-1:0]              tile_ibuf_ext_ena,
    input  wire [NUM_TILES*TILE_IBUF_ADDR_WIDTH-1:0] tile_ibuf_ext_addra,
    input  wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_ibuf_ext_dina,
    output wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_ibuf_ext_douta,

    input  wire [NUM_TILES*STRB_WIDTH-1:0]   tile_obuf_ext_wea,
    input  wire [NUM_TILES-1:0]              tile_obuf_ext_ena,
    input  wire [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] tile_obuf_ext_addra,
    input  wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_obuf_ext_dina,
    output wire [NUM_TILES*BUF_DATA_WIDTH-1:0] tile_obuf_ext_douta,
    output wire [NUM_TILES-1:0]              tile_obuf_ext_douta_valid,

    output wire [NUM_TILES-1:0]              peak_compute_mask,
    output wire [31:0]                       peak_dcim_input,
    output wire [PEAK_JOB_W-1:0]             peak_job,
    output wire [1:0]                        peak_phase,
    output wire                              peak_result_valid,
    output wire [31:0]                       peak_result_data
);

    wire [NUM_TILES-1:0] tile_done;
    wire [NUM_TILES-1:0] tile_ready;

    // One register at the array boundary keeps the existing SLR crossing
    // strategy and makes start/config arrive at every Tile on the same edge.
    (* shreg_extract = "no", KEEP = "TRUE" *) reg ready_r;
    (* shreg_extract = "no", KEEP = "TRUE" *) reg start_r;
    (* shreg_extract = "no" *) reg [2:0] mode_r;
    (* shreg_extract = "no" *) reg [ACC_UBD_WD-1:0] acc_depth_r;
    (* shreg_extract = "no" *) reg [BUF_ADDR_WIDTH-1:0] act_base_addr_r;
    (* shreg_extract = "no" *) reg [NUM_TILES*BUF_ADDR_WIDTH-1:0] wei_base_addrs_r;
    (* shreg_extract = "no" *) reg [NUM_TILES*TILE_OBUF_ADDR_WIDTH-1:0] out_base_addrs_r;
    (* shreg_extract = "no" *) reg [NUM_TILES-1:0] tile_mask_r;
    (* shreg_extract = "no" *) reg batch_enable_r;
    (* shreg_extract = "no" *) reg [31:0] batch_count_r;
    (* shreg_extract = "no" *) reg benchmark_repeat_r;
    (* shreg_extract = "no" *) reg [31:0] repeat_count_r;
    (* shreg_extract = "no" *) reg [BUF_ADDR_WIDTH-1:0] act_stride_words_r;
    (* shreg_extract = "no" *) reg [TILE_OBUF_ADDR_WIDTH-1:0] out_stride_words_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready_r <= 1'b1;
            start_r <= 1'b0;
            mode_r <= `MODE_INT8;
            acc_depth_r <= '0;
            act_base_addr_r <= '0;
            wei_base_addrs_r <= '0;
            out_base_addrs_r <= '0;
            tile_mask_r <= {NUM_TILES{1'b1}};
            batch_enable_r <= 1'b0;
            batch_count_r <= 32'd1;
            benchmark_repeat_r <= 1'b0;
            repeat_count_r <= 32'd1;
            act_stride_words_r <= '0;
            out_stride_words_r <= '0;
        end else begin
            ready_r <= &(tile_ready | ~tile_mask_r);
            start_r <= start;
            mode_r <= mode;
            acc_depth_r <= acc_depth;
            act_base_addr_r <= act_base_addr;
            wei_base_addrs_r <= wei_base_addrs;
            out_base_addrs_r <= out_base_addrs;
            tile_mask_r <= tile_mask;
            batch_enable_r <= batch_enable;
            batch_count_r <= batch_count;
            benchmark_repeat_r <= benchmark_repeat;
            repeat_count_r <= repeat_count;
            act_stride_words_r <= act_stride_words;
            out_stride_words_r <= out_stride_words;
        end
    end

    assign done = &(tile_done | ~tile_mask_r);
    assign ready = ready_r;

    generate
        genvar tile_i;
        for (tile_i = 0; tile_i < NUM_TILES; tile_i = tile_i + 1) begin : gen_tiles
            localparam TILE_DSP_COL = `DCIM_DSP_COL_NUM;
            localparam TILE_DSP_PARTIAL = `DCIM_DSP_PARTIAL_SUBCOL;

            wire t_ibuf0_rd_en;
            wire [BUF_ADDR_WIDTH-1:0] t_ibuf0_rd_addr;
            wire t_ibuf0_data_valid;
            wire [BUF_DATA_WIDTH-1:0] t_ibuf0_data;
            wire t_ibuf1_rd_en;
            wire [BUF_ADDR_WIDTH-1:0] t_ibuf1_rd_addr;
            wire t_ibuf1_data_valid;
            wire [BUF_DATA_WIDTH-1:0] t_ibuf1_data;

            wire t_obuf0_wr_valid;
            wire [TILE_OBUF_ADDR_WIDTH-1:0] t_obuf0_wr_addr;
            wire [BUF_DATA_WIDTH-1:0] t_obuf0_wr_data;
            wire [STRB_WIDTH-1:0] t_obuf0_wr_strb;
            wire t_obuf1_wr_valid;
            wire [TILE_OBUF_ADDR_WIDTH-1:0] t_obuf1_wr_addr;
            wire [BUF_DATA_WIDTH-1:0] t_obuf1_wr_data;
            wire [STRB_WIDTH-1:0] t_obuf1_wr_strb;

            wire t_peak_compute_fire;
            wire [31:0] t_peak_dcim_input;
            wire [PEAK_JOB_W-1:0] t_peak_job;
            wire [1:0] t_peak_phase;
            wire t_peak_result_valid;
            wire [31:0] t_peak_result_data;

            assign peak_compute_mask[tile_i] = t_peak_compute_fire;
            if (tile_i == 0) begin : gen_peak_tile0
                assign peak_dcim_input = t_peak_dcim_input;
                assign peak_job = t_peak_job;
                assign peak_phase = t_peak_phase;
                assign peak_result_valid = t_peak_result_valid;
                assign peak_result_data = t_peak_result_data;
            end

            (* keep_hierarchy = "yes" *)
            DCIM_Tile #(
                .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
                .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC),
                .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
                .BUF_DATA_WIDTH(BUF_DATA_WIDTH), .TILE_IDX(tile_i),
                .MULT_DSP_EN(1), .DSP_COL_NUM(TILE_DSP_COL),
                .DSP_PARTIAL_SUBCOL(TILE_DSP_PARTIAL)
            ) u_tile (
                .clk(clk), .rst_n(rst_n), .start(start_r),
                .tile_enable(tile_mask_r[tile_i]),
                .done(tile_done[tile_i]), .ready(tile_ready[tile_i]),
                .mode(mode_r), .acc_depth(acc_depth_r),
                .wei_base_addr(wei_base_addrs_r[tile_i*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH]),
                .act_base_addr(act_base_addr_r),
                .out_base_addr({{(BUF_ADDR_WIDTH-TILE_OBUF_ADDR_WIDTH){1'b0}},
                    out_base_addrs_r[tile_i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH]}),
                .batch_enable(batch_enable_r), .batch_count(batch_count_r),
                .benchmark_repeat(benchmark_repeat_r),
                .repeat_count(repeat_count_r),
                .act_stride_words(act_stride_words_r),
                .out_stride_words({{(BUF_ADDR_WIDTH-TILE_OBUF_ADDR_WIDTH){1'b0}},
                    out_stride_words_r}),
                .ibuf0_rd_en(t_ibuf0_rd_en), .ibuf0_rd_addr(t_ibuf0_rd_addr),
                .ibuf0_data_valid(t_ibuf0_data_valid), .ibuf0_data(t_ibuf0_data),
                .ibuf1_rd_en(t_ibuf1_rd_en), .ibuf1_rd_addr(t_ibuf1_rd_addr),
                .ibuf1_data_valid(t_ibuf1_data_valid), .ibuf1_data(t_ibuf1_data),
                .obuf0_wr_valid(t_obuf0_wr_valid), .obuf0_wr_addr(t_obuf0_wr_addr),
                .obuf0_wr_data(t_obuf0_wr_data), .obuf0_wr_strb(t_obuf0_wr_strb),
                .obuf1_wr_valid(t_obuf1_wr_valid), .obuf1_wr_addr(t_obuf1_wr_addr),
                .obuf1_wr_data(t_obuf1_wr_data), .obuf1_wr_strb(t_obuf1_wr_strb),
                .peak_compute_fire(t_peak_compute_fire),
                .peak_dcim_input(t_peak_dcim_input), .peak_job(t_peak_job),
                .peak_phase(t_peak_phase), .peak_result_valid(t_peak_result_valid),
                .peak_result_data(t_peak_result_data)
            );

            // Port B is stream 0. Port A is stream 1 while computing and
            // returns to the host interface automatically when idle.
            (* keep_hierarchy = "yes" *)
            tile_ibuf u_tile_ibuf (
                .clk(clk),
                .wea(t_ibuf1_rd_en ? {STRB_WIDTH{1'b0}} :
                    tile_ibuf_ext_wea[tile_i*STRB_WIDTH +: STRB_WIDTH]),
                .mem_ena(t_ibuf1_rd_en | tile_ibuf_ext_ena[tile_i]),
                .dina(t_ibuf1_rd_en ? '0 :
                    tile_ibuf_ext_dina[tile_i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .addra(t_ibuf1_rd_en ? t_ibuf1_rd_addr[TILE_IBUF_ADDR_WIDTH-1:0] :
                    tile_ibuf_ext_addra[tile_i*TILE_IBUF_ADDR_WIDTH +: TILE_IBUF_ADDR_WIDTH]),
                .douta(tile_ibuf_ext_douta[tile_i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .douta_valid(t_ibuf1_data_valid),
                .web({STRB_WIDTH{1'b0}}), .mem_enb(t_ibuf0_rd_en), .dinb('0),
                .addrb(t_ibuf0_rd_addr[TILE_IBUF_ADDR_WIDTH-1:0]),
                .doutb(t_ibuf0_data), .doutb_valid(t_ibuf0_data_valid)
            );
            assign t_ibuf1_data =
                tile_ibuf_ext_douta[tile_i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH];

            // Result stream 0 uses Port B; stream 1 temporarily owns Port A.
            (* keep_hierarchy = "yes" *)
            tile_obuf u_tile_obuf (
                .clk(clk),
                .wea(t_obuf1_wr_valid ? t_obuf1_wr_strb :
                    tile_obuf_ext_wea[tile_i*STRB_WIDTH +: STRB_WIDTH]),
                .mem_ena(t_obuf1_wr_valid | tile_obuf_ext_ena[tile_i]),
                .dina(t_obuf1_wr_valid ? t_obuf1_wr_data :
                    tile_obuf_ext_dina[tile_i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .addra(t_obuf1_wr_valid ? t_obuf1_wr_addr :
                    tile_obuf_ext_addra[tile_i*TILE_OBUF_ADDR_WIDTH +: TILE_OBUF_ADDR_WIDTH]),
                .douta(tile_obuf_ext_douta[tile_i*BUF_DATA_WIDTH +: BUF_DATA_WIDTH]),
                .douta_valid(tile_obuf_ext_douta_valid[tile_i]),
                .web(t_obuf0_wr_strb), .mem_enb(t_obuf0_wr_valid),
                .dinb(t_obuf0_wr_data), .addrb(t_obuf0_wr_addr)
            );
        end
    endgenerate

endmodule
