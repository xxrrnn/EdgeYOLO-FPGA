`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// tb_e2e_inst_driven - End-to-end instruction-driven E2E simulation
// ============================================================================
// 3-layer real-YOLO conv golden compare. Driven by INST_Decoder reading
// inst.hex from inst_bram. CDMA is a behavioral model.
//
// Generated companion: rtl/vpu/tb/e2e/golden_e2e_inst.py
//   produces hex_inst/{input_feat,L?_*,inst,wb_init,manifest.txt}
// ============================================================================

module tb_e2e_inst_driven;

    // -------- Parameters --------
    localparam CLK_PERIOD      = 4.0;       // 250 MHz
    localparam INST_BRAM_DEPTH = 32768;
    localparam INST_ADDR_WIDTH = 15;

    localparam BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH;     // 128
    localparam IBUF_ADDR_WIDTH = `DCIM_IBUF_ADDR_WIDTH;    // 17 (words)
    localparam OBUF_ADDR_WIDTH = `DCIM_OBUF_ADDR_WIDTH;    // 20 (words)
    localparam STRB_WIDTH      = BUF_DATA_WIDTH / 8;       // 16
    localparam NUM_TILES       = `DCIM_TILES_PER_GROUP;    // 8
    localparam WB_ADDR_WIDTH   = `WB_ADDR_WIDTH;           // 15 (byte)
    localparam WB_DEPTH_WORDS  = 1 << (WB_ADDR_WIDTH - $clog2(BUF_DATA_WIDTH/8));

    // OBUF byte address bases (must match golden_e2e_inst.py)
    localparam [23:0] OB_L1_IN     = 24'h000000;
    localparam [23:0] OB_L1_IM2COL = 24'h100000;
    localparam [23:0] OB_L1_ACCUM  = 24'h200000;
    localparam [23:0] OB_L1_DQA    = 24'h300000;
    localparam [23:0] OB_L1_OUT    = 24'h400000;
    localparam [23:0] OB_L2_IM2COL = 24'h500000;
    localparam [23:0] OB_L2_ACCUM  = 24'h600000;
    localparam [23:0] OB_L2_DQA    = 24'h700000;
    localparam [23:0] OB_L2_OUT    = 24'h800000;
    localparam [23:0] OB_L3_IM2COL = 24'h900000;
    localparam [23:0] OB_L3_ACCUM  = 24'hA00000;
    localparam [23:0] OB_L3_DQA    = 24'hB00000;
    localparam [23:0] OB_L3_OUT    = 24'hC00000;

    localparam [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] IB_L1_WEI = 24'h000000;
    localparam [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] IB_L2_WEI = 24'h010000;
    localparam [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] IB_L3_WEI = 24'h020000;
    localparam [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] IB_ACT    = 24'h040000;

    // Max words to verify per checkpoint (limit for fast sim)
    localparam integer VERIFY_MAX_WORDS = 32;   // 验证前 32 个 word 即可（每层）
    localparam integer FAIL_LOG_FIRST_N = 10;

    // -------- Signals --------
    reg clk, rst_n;

    // INST_Decoder interface
    reg         decoder_start;
    reg  [31:0] inst_count;
    wire        decoder_busy, decoder_done;
    wire [31:0] decoder_status;
    wire [INST_ADDR_WIDTH-1:0] inst_rd_addr;
    reg  [31:0]                inst_rd_data;

    // CDMA interface (from decoder)
    wire        cdma_start, cdma_config_valid;
    wire [31:0] cdma_src_addr_msb, cdma_src_addr_lsb;
    wire [31:0] cdma_dst_addr_msb, cdma_dst_addr_lsb;
    wire [31:0] cdma_length;
    reg         cdma_config_ready;

    // VPU interface (from decoder to Global_VPU_top)
    wire        vpu_start_w;
    wire        vpu_ready;
    wire [31:0] vpu_unit_choose, vpu_src_addr, vpu_src2_addr;
    wire [31:0] vpu_src_c, vpu_src_h, vpu_src_w;
    wire [31:0] vpu_bias_addr, vpu_scale_addr, vpu_dst_addr;
    wire [31:0] vpu_addr_break, vpu_addr_s, vpu_addr_t;

    // DCIM cfg interface
    wire        dcim_cfg_wr_en;
    wire [11:0] dcim_cfg_wr_addr;
    wire [31:0] dcim_cfg_wr_data;
    wire        dcim_done;
    wire        dcim_ready = dcim_done;  // ready = done (ready port removed from DCIM_Array_bd)

    // OBUF / IBUF external ports (driven by mux of CDMA and TB tasks)
    reg  [STRB_WIDTH-1:0]                obuf_ext_wea;
    reg                                  obuf_ext_ena;
    reg  [OBUF_ADDR_WIDTH+3:0]           obuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]            obuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]            obuf_ext_douta;

    reg  [STRB_WIDTH-1:0]                ibuf_ext_wea;
    reg                                  ibuf_ext_ena;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] ibuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]            ibuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]            ibuf_ext_douta;

    // VPU <-> OBUF port (vpu_obuf_*)
    wire [OBUF_ADDR_WIDTH-1:0] vpu_obuf_addr;
    wire                       vpu_obuf_en;
    wire [STRB_WIDTH-1:0]      vpu_obuf_we;
    wire [BUF_DATA_WIDTH-1:0]  vpu_obuf_din;
    wire [BUF_DATA_WIDTH-1:0]  vpu_obuf_dout;
    wire                       vpu_obuf_rd_valid;

    // VPU WB BRAM (Port A driven by TB; Port B internal to VPU)
    wire        wb_bram_clk_w, wb_bram_rst_w;
    reg         tb_wb_en;
    reg  [15:0] tb_wb_we;
    reg  [WB_ADDR_WIDTH-1:0] tb_wb_addr;
    reg  [127:0] tb_wb_din;
    wire [127:0] wb_bram_dout;

    assign wb_bram_clk_w = clk;
    assign wb_bram_rst_w = ~rst_n;

    // -------- Clock --------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------- inst_bram model --------
    reg [31:0] inst_bram_mem [0:INST_BRAM_DEPTH-1];
    always @(posedge clk)
        inst_rd_data <= inst_bram_mem[inst_rd_addr];

    // -------- DUT: INST_Decoder --------
    INST_Decoder #(
        .INST_BRAM_DEPTH(INST_BRAM_DEPTH),
        .INST_ADDR_WIDTH(INST_ADDR_WIDTH)
    ) u_decoder (
        .clk              (clk),
        .rst_n            (rst_n),
        .decoder_start    (decoder_start),
        .inst_count       (inst_count),
        .decoder_busy     (decoder_busy),
        .decoder_done     (decoder_done),
        .decoder_status   (decoder_status),
        .inst_rd_addr     (inst_rd_addr),
        .inst_rd_data     (inst_rd_data),
        .cdma_start       (cdma_start),
        .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(cdma_config_ready),
        .cdma_src_addr_msb(cdma_src_addr_msb),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(cdma_dst_addr_msb),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length      (cdma_length),
        .vpu_start        (vpu_start_w),
        .vpu_ready        (vpu_ready),
        .vpu_unit_choose  (vpu_unit_choose),
        .vpu_src_addr     (vpu_src_addr),
        .vpu_src2_addr    (vpu_src2_addr),
        .vpu_src_c        (vpu_src_c),
        .vpu_src_h        (vpu_src_h),
        .vpu_src_w        (vpu_src_w),
        .vpu_bias_addr    (vpu_bias_addr),
        .vpu_scale_addr   (vpu_scale_addr),
        .vpu_dst_addr     (vpu_dst_addr),
        .vpu_addr_break   (vpu_addr_break),
        .vpu_addr_s       (vpu_addr_s),
        .vpu_addr_t       (vpu_addr_t),
        .dcim_cfg_wr_en   (dcim_cfg_wr_en),
        .dcim_cfg_wr_addr (dcim_cfg_wr_addr),
        .dcim_cfg_wr_data (dcim_cfg_wr_data),
        .dcim_ready       (dcim_ready)
    );

    // -------- DUT: Global_VPU_top (full VPU with real FP IPs) --------
    Global_VPU_top u_vpu_top (
        .clk         (clk),
        .rst_n       (rst_n),
        .ready       (vpu_ready),
        .vpu_start   (vpu_start_w),
        .unit_choose (vpu_unit_choose),
        .src_addr    (vpu_src_addr),
        .src2_addr   (vpu_src2_addr),
        .src_c       (vpu_src_c),
        .src_h       (vpu_src_h),
        .src_w       (vpu_src_w),
        .bias_addr   (vpu_bias_addr),
        .scale_addr  (vpu_scale_addr),
        .dst_addr    (vpu_dst_addr),
        .addr_break  (vpu_addr_break),
        .addr_s      (vpu_addr_s),
        .addr_t      (vpu_addr_t),
        .obuf_addr   (vpu_obuf_addr),
        .obuf_en     (vpu_obuf_en),
        .obuf_we     (vpu_obuf_we),
        .obuf_din    (vpu_obuf_din),
        .obuf_dout   (vpu_obuf_dout),
        .obuf_rd_valid(vpu_obuf_rd_valid),
        .wb_bram_clk (wb_bram_clk_w),
        .wb_bram_rst (wb_bram_rst_w),
        .wb_bram_en  (tb_wb_en),
        .wb_bram_we  (tb_wb_we),
        .wb_bram_addr(tb_wb_addr),
        .wb_bram_din (tb_wb_din),
        .wb_bram_dout(wb_bram_dout)
    );

    // -------- DUT: DCIM_Array_bd --------
    DCIM_Array_bd #(
        .NUM_GROUPS      (`DCIM_NUM_GROUPS),
        .TILES_PER_GROUP (`DCIM_TILES_PER_GROUP),
        .NUM_TILES       (NUM_TILES),
        .IBUF_ADDR_WIDTH (IBUF_ADDR_WIDTH),
        .OBUF_ADDR_WIDTH (OBUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH  (BUF_DATA_WIDTH)
    ) u_dcim_bd (
        .clk            (clk),
        .rst_n          (rst_n),
        .cfg_wr_en      (dcim_cfg_wr_en),
        .cfg_wr_addr    (dcim_cfg_wr_addr),
        .cfg_wr_data    (dcim_cfg_wr_data),
        .ibuf_ext_wea   (ibuf_ext_wea),
        .ibuf_ext_ena   (ibuf_ext_ena),
        .ibuf_ext_addra (ibuf_ext_addra),
        .ibuf_ext_dina  (ibuf_ext_dina),
        .ibuf_ext_douta (ibuf_ext_douta),
        .obuf_ext_wea   (obuf_ext_wea),
        .obuf_ext_ena   (obuf_ext_ena),
        .obuf_ext_addra (obuf_ext_addra),
        .obuf_ext_dina  (obuf_ext_dina),
        .obuf_ext_douta (obuf_ext_douta),
        .vpu_obuf_addr  (vpu_obuf_addr),
        .vpu_obuf_en    (vpu_obuf_en),
        .vpu_obuf_we    (vpu_obuf_we),
        .vpu_obuf_din   (vpu_obuf_din),
        .vpu_obuf_dout  (vpu_obuf_dout),
        .vpu_obuf_rd_valid(vpu_obuf_rd_valid),
        .done           (dcim_done)
    );

    // ========================================================================
    // CDMA Behavioral Model: copy bytes from OBUF[src_lsb] to IBUF[dst_lsb]
    // ========================================================================
    reg cdma_busy;
    reg [31:0] cdma_src_byte, cdma_dst_byte, cdma_remain;
    reg [3:0]  cdma_phase;
    reg [BUF_DATA_WIDTH-1:0] cdma_rd_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cdma_config_ready <= 1'b1;
            cdma_busy <= 1'b0;
        end else if (cdma_config_valid && cdma_config_ready) begin
            cdma_src_byte <= cdma_src_addr_lsb;
            cdma_dst_byte <= cdma_dst_addr_lsb;
            cdma_remain   <= cdma_length;
            cdma_config_ready <= 1'b0;
            cdma_busy <= 1'b1;
        end else if (cdma_busy && cdma_remain == 0) begin
            cdma_busy <= 1'b0;
            cdma_config_ready <= 1'b1;
        end
    end

    // CDMA-driven ext signals
    reg                                  cdma_obuf_ena;
    reg  [STRB_WIDTH-1:0]                cdma_obuf_wea;
    reg  [OBUF_ADDR_WIDTH+3:0]           cdma_obuf_addra;
    reg                                  cdma_ibuf_ena;
    reg  [STRB_WIDTH-1:0]                cdma_ibuf_wea;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] cdma_ibuf_addra;
    reg  [BUF_DATA_WIDTH-1:0]            cdma_ibuf_dina;

    // TB-driven ext signals
    reg                                  tb_obuf_ena;
    reg  [STRB_WIDTH-1:0]                tb_obuf_wea;
    reg  [OBUF_ADDR_WIDTH+3:0]           tb_obuf_addra;
    reg  [BUF_DATA_WIDTH-1:0]            tb_obuf_dina;
    reg                                  tb_ibuf_ena;
    reg  [STRB_WIDTH-1:0]                tb_ibuf_wea;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] tb_ibuf_addra;
    reg  [BUF_DATA_WIDTH-1:0]            tb_ibuf_dina;

    // Mux: CDMA wins while busy
    always @(*) begin
        if (cdma_busy) begin
            obuf_ext_ena   = cdma_obuf_ena;
            obuf_ext_wea   = cdma_obuf_wea;
            obuf_ext_addra = cdma_obuf_addra;
            obuf_ext_dina  = '0;
            ibuf_ext_ena   = cdma_ibuf_ena;
            ibuf_ext_wea   = cdma_ibuf_wea;
            ibuf_ext_addra = cdma_ibuf_addra;
            ibuf_ext_dina  = cdma_ibuf_dina;
        end else begin
            obuf_ext_ena   = tb_obuf_ena;
            obuf_ext_wea   = tb_obuf_wea;
            obuf_ext_addra = tb_obuf_addra;
            obuf_ext_dina  = tb_obuf_dina;
            ibuf_ext_ena   = tb_ibuf_ena;
            ibuf_ext_wea   = tb_ibuf_wea;
            ibuf_ext_addra = tb_ibuf_addra;
            ibuf_ext_dina  = tb_ibuf_dina;
        end
    end

    // CDMA byte-copy FSM (10 phases per 16-byte word)
    always @(posedge clk) begin
        if (!rst_n) begin
            cdma_phase <= 0;
            cdma_obuf_ena <= 0; cdma_obuf_wea <= 0; cdma_obuf_addra <= 0;
            cdma_ibuf_ena <= 0; cdma_ibuf_wea <= 0; cdma_ibuf_addra <= 0; cdma_ibuf_dina <= 0;
        end else if (cdma_busy && cdma_remain > 0) begin
            case (cdma_phase)
                0: begin
                    cdma_obuf_ena   <= 1'b1;
                    cdma_obuf_wea   <= '0;
                    cdma_obuf_addra <= cdma_src_byte[OBUF_ADDR_WIDTH+3:0];
                    cdma_phase <= 1;
                end
                1: begin
                    cdma_obuf_ena <= 1'b0;
                    cdma_phase <= 2;
                end
                9: begin
                    cdma_rd_data <= obuf_ext_douta;
                    cdma_phase <= 10;
                end
                10: begin
                    cdma_ibuf_ena   <= 1'b1;
                    cdma_ibuf_wea   <= {STRB_WIDTH{1'b1}};
                    cdma_ibuf_addra <= cdma_dst_byte[`DCIM_AXI_BRAM_ADDR_WIDTH-1:0];
                    cdma_ibuf_dina  <= cdma_rd_data;
                    cdma_phase <= 11;
                end
                11: begin
                    cdma_ibuf_ena <= 1'b0;
                    cdma_ibuf_wea <= '0;
                    cdma_src_byte <= cdma_src_byte + 16;
                    cdma_dst_byte <= cdma_dst_byte + 16;
                    cdma_remain   <= cdma_remain - 16;
                    cdma_phase    <= 0;
                end
                default: cdma_phase <= cdma_phase + 1;
            endcase
        end else begin
            cdma_obuf_ena <= 0;
            cdma_ibuf_ena <= 0;
            cdma_ibuf_wea <= 0;
            cdma_phase <= 0;
        end
    end

    // ========================================================================
    // TB tasks: drive TB-side ext / WB signals
    // ========================================================================
    task obuf_write_word(input [OBUF_ADDR_WIDTH-1:0] word_addr,
                         input [BUF_DATA_WIDTH-1:0]  data);
        begin
            @(posedge clk);
            tb_obuf_ena   <= 1'b1;
            tb_obuf_wea   <= {STRB_WIDTH{1'b1}};
            tb_obuf_addra <= {word_addr, 4'b0000};
            tb_obuf_dina  <= data;
            @(posedge clk);
            tb_obuf_ena <= 1'b0;
            tb_obuf_wea <= '0;
        end
    endtask

    task ibuf_write_word(input [IBUF_ADDR_WIDTH-1:0] word_addr,
                         input [BUF_DATA_WIDTH-1:0]  data);
        begin
            @(posedge clk);
            tb_ibuf_ena   <= 1'b1;
            tb_ibuf_wea   <= {STRB_WIDTH{1'b1}};
            tb_ibuf_addra <= {word_addr, 4'b0000};
            tb_ibuf_dina  <= data;
            @(posedge clk);
            tb_ibuf_ena <= 1'b0;
            tb_ibuf_wea <= '0;
        end
    endtask

    task obuf_read_word(input  [OBUF_ADDR_WIDTH-1:0] word_addr,
                        output [BUF_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            tb_obuf_ena   <= 1'b1;
            tb_obuf_wea   <= '0;
            tb_obuf_addra <= {word_addr, 4'b0000};
            @(posedge clk);
            tb_obuf_ena <= 1'b0;
            repeat(14) @(posedge clk);
            data = obuf_ext_douta;
        end
    endtask

    task wb_write_word(input [WB_ADDR_WIDTH-1:0] byte_addr,
                       input [127:0] data);
        begin
            @(posedge clk);
            tb_wb_en   <= 1'b1;
            tb_wb_we   <= 16'hFFFF;
            tb_wb_addr <= byte_addr;
            tb_wb_din  <= data;
            @(posedge clk);
            tb_wb_en <= 1'b0;
            tb_wb_we <= 16'h0000;
        end
    endtask

    // ========================================================================
    // Golden memories (sized to L1 worst case)
    // ========================================================================
    // Worst case sizes (L1, scaled or full):
    //   im2col rows = OH*OW <= 6400 (full) or 256 (scaled), * acc_depth = 9 -> max 57600 words.
    //   accum   rows = OH*OW * OC/4 words (4 INT32/word). Full L1: 6400*32/4 = 51200 words.
    //   dqa     same shape as accum (4 FP32 per word) = 51200 words.
    //   output  rows = OH*OW*OC/16 words (16 UINT8/word). Full L1: 6400*32/16 = 12800 words.
    //
    // We size for the SCALED case to keep xsim memory footprint tractable.
    localparam integer GOLDEN_DEPTH = 4096;
    reg [127:0] g_im2col [0:GOLDEN_DEPTH-1];
    reg [127:0] g_accum  [0:GOLDEN_DEPTH-1];
    reg [127:0] g_dqa    [0:GOLDEN_DEPTH-1];
    reg [127:0] g_output [0:GOLDEN_DEPTH-1];

    // Helpers to load goldens
    task automatic load_golden_im2col(input string fname);
        begin $readmemh(fname, g_im2col); end
    endtask
    task automatic load_golden_accum(input string fname);
        begin $readmemh(fname, g_accum); end
    endtask
    task automatic load_golden_dqa(input string fname);
        begin $readmemh(fname, g_dqa); end
    endtask
    task automatic load_golden_output(input string fname);
        begin $readmemh(fname, g_output); end
    endtask

    // ========================================================================
    // Golden compare task
    //   mode : 0=exact, 1=FP32 tolerance (4 lanes per 128-bit word)
    //   which: 0=g_im2col, 1=g_accum, 2=g_dqa, 3=g_output
    // ========================================================================
    integer total_pass, total_fail;

    task automatic compare_checkpoint(
        input string                   label,
        input [OBUF_ADDR_WIDTH-1:0]    base_word,
        input integer                  num_words,
        input integer                  mode,
        input integer                  which);
        integer i, locF, locP, logged;
        integer lane, lane_fail;
        reg [127:0] rd, exp;
        reg [31:0] g_lane, e_lane;
        real gf, ef, diff, tol;
        begin
            locF = 0; locP = 0; logged = 0;
            $display("--- compare %s : %0d words at OBUF word 0x%05h ---",
                      label, num_words, base_word);
            obuf_read_word(base_word, rd);
            for (i = 0; i < num_words; i = i + 1) begin
                obuf_read_word(base_word + i, rd);
                case (which)
                    0: exp = g_im2col[i];
                    1: exp = g_accum [i];
                    2: exp = g_dqa   [i];
                    default: exp = g_output[i];
                endcase
                if (mode == 0) begin
                    if (rd === exp) locP = locP + 1;
                    else begin
                        locF = locF + 1;
                        if (logged < FAIL_LOG_FIRST_N) begin
                            $display("    [%s] MISMATCH w%0d: got=0x%032h exp=0x%032h",
                                     label, i, rd, exp);
                            logged = logged + 1;
                        end
                    end
                end else begin
                    lane_fail = 0;
                    for (lane = 0; lane < 4; lane = lane + 1) begin
                        g_lane = rd [lane*32 +: 32];
                        e_lane = exp[lane*32 +: 32];
                        gf = $bitstoshortreal(g_lane);
                        ef = $bitstoshortreal(e_lane);
                        diff = (gf > ef) ? (gf - ef) : (ef - gf);
                        tol  = 1.0e-2 * ((ef > 0 ? ef : -ef) + 1.0);
                        if (g_lane === e_lane) begin
                        end else if (diff <= tol) begin
                        end else begin
                            lane_fail = lane_fail + 1;
                            if (logged < FAIL_LOG_FIRST_N) begin
                                $display("    [%s] FP MISMATCH w%0d lane%0d: got=%f (0x%08h) exp=%f (0x%08h)",
                                         label, i, lane, gf, g_lane, ef, e_lane);
                                logged = logged + 1;
                            end
                        end
                    end
                    if (lane_fail == 0) locP = locP + 1;
                    else                locF = locF + 1;
                end
            end
            $display("--- %s : %0d PASS, %0d FAIL ---", label, locP, locF);
            total_pass = total_pass + locP;
            total_fail = total_fail + locF;
        end
    endtask

    // ========================================================================
    // Top-level vars used by main initial block
    // ========================================================================
    integer i;
    reg [127:0] tmp128;
    reg [127:0] in_feat_mem [0:16383];   // up to 256KB input feature (scaled)
    reg [127:0] wei_mem     [0:1023];    // weight scratch
    reg [127:0] wb_init_mem [0:2047];    // 32KB / 16B = 2048 words

    // -------- Per-layer dims & address bases (set by load_manifest_defaults) --------
    // For now we hard-code the SCALED values matching golden_e2e_inst.py default
    // (scale=0.2 -> L1 32x32, L2 16x16, L3 16x16). A future enhancement can parse
    // hex_inst/manifest.txt for parametric configurability.
    localparam integer L1_IN_H = 16, L1_IN_W = 16, L1_IN_C = 16;
    localparam integer L1_OH = 8, L1_OW = 8, L1_OC = 32, L1_ACC_DEPTH = 9, L1_NUM_TILES = 4;
    localparam integer L2_IN_H = 8, L2_IN_W = 8, L2_IN_C = 32;
    localparam integer L2_OH = 8, L2_OW = 8, L2_OC = 16, L2_ACC_DEPTH = 2, L2_NUM_TILES = 2;
    localparam integer L3_IN_H = 8, L3_IN_W = 8, L3_IN_C = 16;
    localparam integer L3_OH = 8, L3_OW = 8, L3_OC = 16, L3_ACC_DEPTH = 9, L3_NUM_TILES = 2;

    // Number of golden words to compare per checkpoint (cap by VERIFY_MAX_WORDS)
    function automatic integer min2(input integer a, input integer b);
        min2 = (a < b) ? a : b;
    endfunction

    // ========================================================================
    // Main
    // ========================================================================
    initial begin
        $display("============================================================");
        $display("  tb_e2e_inst_driven: 3-layer real-YOLO conv E2E");
        $display("============================================================");
        rst_n = 0;
        decoder_start = 0;
        inst_count = 0;
        tb_obuf_ena = 0; tb_obuf_wea = 0; tb_obuf_addra = 0; tb_obuf_dina = 0;
        tb_ibuf_ena = 0; tb_ibuf_wea = 0; tb_ibuf_addra = 0; tb_ibuf_dina = 0;
        tb_wb_en = 0; tb_wb_we = 0; tb_wb_addr = 0; tb_wb_din = 0;
        total_pass = 0; total_fail = 0;

        for (i = 0; i < INST_BRAM_DEPTH; i = i + 1) inst_bram_mem[i] = 32'h0;
        for (i = 0; i < 16384; i = i + 1) in_feat_mem[i] = 128'h0;
        for (i = 0; i < 1024;  i = i + 1) wei_mem[i] = 128'h0;
        for (i = 0; i < 2048;  i = i + 1) wb_init_mem[i] = 128'h0;
        for (i = 0; i < GOLDEN_DEPTH; i = i + 1) begin
            g_im2col[i] = 128'h0;
            g_accum [i] = 128'h0;
            g_dqa   [i] = 128'h0;
            g_output[i] = 128'h0;
        end

        // -- Load all hex (must be in current sim dir as flat files) --
        $readmemh("inst.hex",       inst_bram_mem);
        $readmemh("wb_init.hex",    wb_init_mem);
        $readmemh("input_feat.hex", in_feat_mem);

        // count instructions (find OP_END = 0xF in top nibble)
        for (i = 0; i < INST_BRAM_DEPTH; i = i + 1) begin
            if (inst_bram_mem[i][31:28] == 4'hF) begin
                inst_count = i + 1;
                i = INST_BRAM_DEPTH; // break
            end
        end
        $display("[%0t] Loaded %0d instruction words", $time, inst_count);

        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(4) @(posedge clk);

        // ====================================================================
        // Phase 0a: Load input feature into OBUF[L1_IN]
        // ====================================================================
        $display("[%0t] Phase 0a: load input feature (L1 NHWC = %0d words)",
                 $time, L1_IN_H * L1_IN_W);
        for (i = 0; i < L1_IN_H * L1_IN_W; i = i + 1)
            obuf_write_word(OB_L1_IN[OBUF_ADDR_WIDTH+3:4] + i, in_feat_mem[i]);
        $display("[%0t] Phase 0a done", $time);

        // ====================================================================
        // Phase 0b: Load WB BRAM (DQA scale/bias + QA scale, all layers)
        // ====================================================================
        $display("[%0t] Phase 0b: load WB BRAM (%0d words)", $time, 2048);
        for (i = 0; i < 2048; i = i + 1)
            wb_write_word(i << 4, wb_init_mem[i]);
        $display("[%0t] Phase 0b done", $time);

        // ====================================================================
        // Phase 0c: Load weights to IBUF for L1, L2, L3
        // ====================================================================
        $display("[%0t] Phase 0c: load weights for all layers", $time);
        // L1: 2 tiles, 144 entries each, base IB_L1_WEI + tile*256
        $readmemh("L1_weight_tile0.hex", wei_mem);
        for (i = 0; i < L1_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L1_WEI >> 4) + 0*256 + i, wei_mem[i]);
        $readmemh("L1_weight_tile1.hex", wei_mem);
        for (i = 0; i < L1_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L1_WEI >> 4) + 1*256 + i, wei_mem[i]);
        $readmemh("L1_weight_tile2.hex", wei_mem);
        for (i = 0; i < L1_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L1_WEI >> 4) + 2*256 + i, wei_mem[i]);
        $readmemh("L1_weight_tile3.hex", wei_mem);
        for (i = 0; i < L1_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L1_WEI >> 4) + 3*256 + i, wei_mem[i]);
        // L2: 1 tile, 32 entries
        $readmemh("L2_weight_tile0.hex", wei_mem);
        for (i = 0; i < L2_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L2_WEI >> 4) + 0*256 + i, wei_mem[i]);
        $readmemh("L2_weight_tile1.hex", wei_mem);
        for (i = 0; i < L2_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L2_WEI >> 4) + 1*256 + i, wei_mem[i]);
        // L3: 1 tile, 144 entries
        $readmemh("L3_weight_tile0.hex", wei_mem);
        for (i = 0; i < L3_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L3_WEI >> 4) + 0*256 + i, wei_mem[i]);
        $readmemh("L3_weight_tile1.hex", wei_mem);
        for (i = 0; i < L3_ACC_DEPTH * 8; i = i + 1)
            ibuf_write_word((IB_L3_WEI >> 4) + 1*256 + i, wei_mem[i]);
        $display("[%0t] Phase 0c done", $time);

        // ====================================================================
        // Phase 1: Kick INST_Decoder and wait for completion
        // ====================================================================
        $display("[%0t] Phase 1: start INST_Decoder", $time);
        @(posedge clk);
        decoder_start = 1;
        @(posedge clk);
        decoder_start = 0;
        wait(decoder_busy == 1);
        wait(decoder_busy == 0);
        if (decoder_status[31])
            $display("ERROR: decoder reported error status=0x%08h", decoder_status);
        repeat(50) @(posedge clk);
        $display("[%0t] Phase 1 done: decoder_status=0x%08h", $time, decoder_status);

        // Phase 1.5: sanity reads to localize where the data first goes missing
        $display("[%0t] Phase 1.5: sanity reads", $time);
        obuf_read_word(OB_L1_IN     [OBUF_ADDR_WIDTH+3:4], tmp128);
        $display("    OBUF[L1_IN]     w0 = 0x%032h", tmp128);
        obuf_read_word(OB_L1_IM2COL [OBUF_ADDR_WIDTH+3:4], tmp128);
        $display("    OBUF[L1_IM2COL] w0 = 0x%032h", tmp128);
        obuf_read_word(OB_L1_ACCUM  [OBUF_ADDR_WIDTH+3:4], tmp128);
        $display("    OBUF[L1_ACCUM]  w0 = 0x%032h", tmp128);
        obuf_read_word(OB_L1_DQA    [OBUF_ADDR_WIDTH+3:4], tmp128);
        $display("    OBUF[L1_DQA]    w0 = 0x%032h", tmp128);
        obuf_read_word(OB_L1_OUT    [OBUF_ADDR_WIDTH+3:4], tmp128);
        $display("    OBUF[L1_OUT]    w0 = 0x%032h", tmp128);

        // ====================================================================
        // Phase 2: Per-layer checkpoint comparisons
        // ====================================================================
        $display("[%0t] Phase 2: per-layer checkpoints", $time);

        // ---- L1: accum (INT32) + dqa (FP32) ----
        $readmemh("L1_accum.hex", g_accum);
        $readmemh("L1_dqa.hex",   g_dqa);
        compare_checkpoint("L1_accum",
                           OB_L1_ACCUM[OBUF_ADDR_WIDTH+3:4],
                           min2(L1_OH * L1_OW * L1_OC / 4, VERIFY_MAX_WORDS),
                           0,   // exact
                           1);  // g_accum
        compare_checkpoint("L1_dqa",
                           OB_L1_DQA[OBUF_ADDR_WIDTH+3:4],
                           min2(L1_OH * L1_OW * L1_OC / 4, VERIFY_MAX_WORDS),
                           1,   // FP tolerance
                           2);  // g_dqa
        $readmemh("L1_output.hex", g_output);
        compare_checkpoint("L1_output",
                           OB_L1_OUT[OBUF_ADDR_WIDTH+3:4],
                           min2(L1_OH * L1_OW * L1_OC / 16, VERIFY_MAX_WORDS),
                           0,   // exact UINT8
                           3);  // g_output

        // ---- L2: accum + dqa + output ----
        $readmemh("L2_accum.hex", g_accum);
        $readmemh("L2_dqa.hex",   g_dqa);
        compare_checkpoint("L2_accum",
                           OB_L2_ACCUM[OBUF_ADDR_WIDTH+3:4],
                           min2(L2_OH * L2_OW * L2_OC / 4, VERIFY_MAX_WORDS),
                           0, 1);
        compare_checkpoint("L2_dqa",
                           OB_L2_DQA[OBUF_ADDR_WIDTH+3:4],
                           min2(L2_OH * L2_OW * L2_OC / 4, VERIFY_MAX_WORDS),
                           1, 2);
        $readmemh("L2_output.hex", g_output);
        compare_checkpoint("L2_output",
                           OB_L2_OUT[OBUF_ADDR_WIDTH+3:4],
                           min2(L2_OH * L2_OW * L2_OC / 16, VERIFY_MAX_WORDS),
                           0, 3);

        // ---- L3: accum + dqa + output ----
        $readmemh("L3_accum.hex", g_accum);
        $readmemh("L3_dqa.hex",   g_dqa);
        compare_checkpoint("L3_accum",
                           OB_L3_ACCUM[OBUF_ADDR_WIDTH+3:4],
                           min2(L3_OH * L3_OW * L3_OC / 4, VERIFY_MAX_WORDS),
                           0, 1);
        compare_checkpoint("L3_dqa",
                           OB_L3_DQA[OBUF_ADDR_WIDTH+3:4],
                           min2(L3_OH * L3_OW * L3_OC / 4, VERIFY_MAX_WORDS),
                           1, 2);
        $readmemh("L3_output.hex", g_output);
        compare_checkpoint("L3_output",
                           OB_L3_OUT[OBUF_ADDR_WIDTH+3:4],
                           min2(L3_OH * L3_OW * L3_OC / 16, VERIFY_MAX_WORDS),
                           0, 3);

        // ====================================================================
        // Phase 3: Results
        // ====================================================================
        $display("");
        $display("============================================================");
        $display("  GRAND RESULTS: %0d PASS, %0d FAIL", total_pass, total_fail);
        if (total_fail == 0)
            $display("  ALL CHECKPOINTS PASSED");
        else
            $display("  SOME CHECKPOINTS FAILED");
        $display("============================================================");
        $finish;
    end

    // Timeout (cycles)
    initial begin
        #(CLK_PERIOD * 500000000);
        $display("FATAL: Global timeout at 500M cycles");
        $finish(1);
    end

    // ------------------------------------------------------------------------
    // Debug monitors
    // ------------------------------------------------------------------------
    always @(posedge clk) begin
        if (vpu_start_w)
            $display("[%0t] VPU_START: unit=%0d src=0x%08h dst=0x%08h c=%0d h=%0d w=%0d",
                     $time, vpu_unit_choose, vpu_src_addr, vpu_dst_addr, vpu_src_c, vpu_src_h, vpu_src_w);
        if (cdma_config_valid && cdma_config_ready)
            $display("[%0t] CDMA_GO: src=0x%08h dst=0x%08h len=%0d",
                     $time, cdma_src_addr_lsb, cdma_dst_addr_lsb, cdma_length);
        if (dcim_cfg_wr_en)
            $display("[%0t] DCIM_CFG: addr=0x%03h data=0x%08h",
                     $time, dcim_cfg_wr_addr, dcim_cfg_wr_data);
    end
    reg dcim_ready_prev;
    always @(posedge clk) begin
        dcim_ready_prev <= dcim_ready;
        if (dcim_ready && !dcim_ready_prev)
            $display("[%0t] DCIM_READY rising (compute complete)", $time);
        if (!dcim_ready && dcim_ready_prev)
            $display("[%0t] DCIM_READY falling (compute started)", $time);
    end

endmodule
