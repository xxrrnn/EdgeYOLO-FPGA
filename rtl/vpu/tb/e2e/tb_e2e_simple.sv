`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// tb_e2e_simple - 简化端到端仿真 (1×1 conv, IC=16, OC=16)
// ============================================================================
// 验证完整硬件流水线：
//   INST_Decoder → im2col → CDMA → DCIM → dqa → nn(ReLU) → qa
// 使用 1×1 conv 确保 acc_depth=1，DCIM 单 pass 即可完成
//
// 配置: 8×8×16 输入 → 1×1 conv → 8×8×16 输出 (UINT8)
// 所有 VPU 单元使用真实 Vivado IP (fp32_mac, int32_2_fp32, fp32_to_int8)
// ============================================================================

module tb_e2e_simple;

    localparam CLK_PERIOD      = 4.0;
    localparam INST_BRAM_DEPTH = 4096;
    localparam INST_ADDR_WIDTH = 12;

    localparam BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH;   // 128
    localparam IBUF_ADDR_WIDTH = `DCIM_IBUF_ADDR_WIDTH;  // 17
    localparam OBUF_ADDR_WIDTH = `DCIM_OBUF_ADDR_WIDTH;  // 20
    localparam STRB_WIDTH      = BUF_DATA_WIDTH / 8;     // 16
    localparam NUM_TILES       = `DCIM_TILES_PER_GROUP;   // 8
    localparam WB_ADDR_WIDTH   = `WB_ADDR_WIDTH;         // 15

    // Feature config
    localparam H = 8, W = 8, IC = 16, OC = 16;
    localparam KH = 3, KW = 3, STRIDE = 1, PAD = 1;
    localparam OH = (H + 2*PAD - KH) / STRIDE + 1;  // 8
    localparam OW = (W + 2*PAD - KW) / STRIDE + 1;  // 8
    localparam ACC_DEPTH = (KH * KW * IC + 15) / 16; // 9

    // =========================================================================
    // 信号
    // =========================================================================
    reg clk, rst_n;

    // Global_VPU_top 接口
    wire        vpu_ready;
    reg         vpu_start;
    reg  [31:0] unit_choose, src_addr, src2_addr, src_c, src_h, src_w;
    reg  [31:0] bias_addr, scale_addr, dst_addr, addr_break, addr_s, addr_t;

    // VPU OBUF 端口
    wire [OBUF_ADDR_WIDTH-1:0]  vpu_obuf_addr;
    wire                        vpu_obuf_en;
    wire [STRB_WIDTH-1:0]       vpu_obuf_we;
    wire [BUF_DATA_WIDTH-1:0]   vpu_obuf_din;
    wire [BUF_DATA_WIDTH-1:0]   vpu_obuf_dout;

    // VPU WB BRAM 端口
    wire        wb_bram_clk, wb_bram_rst, wb_bram_en;
    wire [15:0] wb_bram_we;
    wire [WB_ADDR_WIDTH-1:0] wb_bram_addr;
    wire [127:0] wb_bram_din;
    wire [127:0] wb_bram_dout;

    // DCIM 接口
    reg         cfg_wr_en;
    reg  [11:0] cfg_wr_addr;
    reg  [31:0] cfg_wr_data;
    wire        dcim_done, dcim_ready;

    // OBUF/IBUF ext
    reg  [STRB_WIDTH-1:0]      obuf_ext_wea;
    reg                        obuf_ext_ena;
    reg  [OBUF_ADDR_WIDTH+3:0] obuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]  obuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]  obuf_ext_douta;

    reg  [STRB_WIDTH-1:0]      ibuf_ext_wea;
    reg                        ibuf_ext_ena;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] ibuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]  ibuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]  ibuf_ext_douta;

    // =========================================================================
    // Clock
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // WB BRAM interface - drives Global_VPU_top's wb_bram port
    // Global_VPU internally has its own BRAM; Port A is the external write path
    // =========================================================================
    reg         tb_wb_en;
    reg  [15:0] tb_wb_we;
    reg  [WB_ADDR_WIDTH-1:0] tb_wb_addr;
    reg  [127:0] tb_wb_din;

    assign wb_bram_clk = clk;
    assign wb_bram_rst = ~rst_n;
    assign wb_bram_en  = tb_wb_en;
    assign wb_bram_we  = tb_wb_we;
    assign wb_bram_addr = tb_wb_addr;
    assign wb_bram_din  = tb_wb_din;
    // wb_bram_dout not used by TB (only VPU internal reads via Port B)

    task wb_write;
        input [WB_ADDR_WIDTH-1:0] byte_addr;
        input [127:0] data;
        begin
            @(posedge clk);
            tb_wb_en   <= 1'b1;
            tb_wb_we   <= 16'hFFFF;
            tb_wb_addr <= byte_addr;
            tb_wb_din  <= data;
            @(posedge clk);
            tb_wb_en   <= 1'b0;
            tb_wb_we   <= 16'h0;
        end
    endtask

    // =========================================================================
    // Global_VPU_top (full VPU with real FP IPs)
    // =========================================================================
    Global_VPU_top u_vpu_top (
        .clk         (clk),
        .rst_n       (rst_n),
        .ready       (vpu_ready),
        .vpu_start   (vpu_start),
        .unit_choose (unit_choose),
        .src_addr    (src_addr),
        .src2_addr   (src2_addr),
        .src_c       (src_c),
        .src_h       (src_h),
        .src_w       (src_w),
        .bias_addr   (bias_addr),
        .scale_addr  (scale_addr),
        .dst_addr    (dst_addr),
        .addr_break  (addr_break),
        .addr_s      (addr_s),
        .addr_t      (addr_t),
        .obuf_addr   (vpu_obuf_addr),
        .obuf_en     (vpu_obuf_en),
        .obuf_we     (vpu_obuf_we),
        .obuf_din    (vpu_obuf_din),
        .obuf_dout   (vpu_obuf_dout),
        .wb_bram_clk (wb_bram_clk),
        .wb_bram_rst (wb_bram_rst),
        .wb_bram_en  (wb_bram_en),
        .wb_bram_we  (wb_bram_we),
        .wb_bram_addr(wb_bram_addr),
        .wb_bram_din (wb_bram_din),
        .wb_bram_dout(wb_bram_dout)
    );

    // =========================================================================
    // DCIM_Array_bd
    // =========================================================================
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
        .cfg_wr_en      (cfg_wr_en),
        .cfg_wr_addr    (cfg_wr_addr),
        .cfg_wr_data    (cfg_wr_data),
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
        .done           (dcim_done),
        .ready          (dcim_ready)
    );

    // =========================================================================
    // Tasks
    // =========================================================================
    task obuf_write;
        input [OBUF_ADDR_WIDTH-1:0] word_addr;
        input [BUF_DATA_WIDTH-1:0]  data;
        begin
            @(posedge clk);
            obuf_ext_ena   <= 1'b1;
            obuf_ext_wea   <= {STRB_WIDTH{1'b1}};
            obuf_ext_addra <= {word_addr, 4'b0};
            obuf_ext_dina  <= data;
            @(posedge clk);
            obuf_ext_ena   <= 1'b0;
            obuf_ext_wea   <= '0;
        end
    endtask

    task ibuf_write;
        input [IBUF_ADDR_WIDTH-1:0] word_addr;
        input [BUF_DATA_WIDTH-1:0]  data;
        begin
            @(posedge clk);
            ibuf_ext_ena   <= 1'b1;
            ibuf_ext_wea   <= {STRB_WIDTH{1'b1}};
            ibuf_ext_addra <= {word_addr, 4'b0};
            ibuf_ext_dina  <= data;
            @(posedge clk);
            ibuf_ext_ena   <= 1'b0;
            ibuf_ext_wea   <= '0;
        end
    endtask

    task obuf_read;
        input [OBUF_ADDR_WIDTH-1:0] word_addr;
        output [BUF_DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            obuf_ext_ena   <= 1'b1;
            obuf_ext_wea   <= '0;
            obuf_ext_addra <= {word_addr, 4'b0};
            @(posedge clk);
            obuf_ext_ena   <= 1'b0;
            repeat(12) @(posedge clk);
            data = obuf_ext_douta;
        end
    endtask

    task dcim_cfg;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cfg_wr_en   <= 1'b1;
            cfg_wr_addr <= addr;
            cfg_wr_data <= data;
            @(posedge clk);
            cfg_wr_en   <= 1'b0;
        end
    endtask

    task vpu_exec;
        input [31:0] unit;
        input [31:0] p_src, p_src2, p_c, p_h, p_w;
        input [31:0] p_bias, p_scale, p_dst, p_break, p_s, p_t;
        begin
            wait(vpu_ready);
            @(posedge clk);
            unit_choose <= unit;
            src_addr    <= p_src;
            src2_addr   <= p_src2;
            src_c       <= p_c;
            src_h       <= p_h;
            src_w       <= p_w;
            bias_addr   <= p_bias;
            scale_addr  <= p_scale;
            dst_addr    <= p_dst;
            addr_break  <= p_break;
            addr_s      <= p_s;
            addr_t      <= p_t;
            @(posedge clk);  // 等参数被 config_ready&&config_valid 锁存
            @(posedge clk);  // 再等一 cycle 确保 unit_choose_reg 更新
            vpu_start   <= 1'b1;
            @(posedge clk);
            vpu_start   <= 1'b0;
            @(posedge clk);
            wait(vpu_ready);
        end
    endtask

    // =========================================================================
    // Test body
    // =========================================================================
    integer i, j, pass_count, fail_count;
    reg [BUF_DATA_WIDTH-1:0] wr_word, rd_word;

    initial begin
        $display("=============================================================");
        $display("  tb_e2e_simple: 3x3 conv E2E (IC=16, OC=16, 8x8, pad=1)");
        $display("  Full pipeline: im2col -> CDMA -> DCIM -> dqa -> relu -> qa");
        $display("=============================================================");

        rst_n = 0;
        vpu_start = 0;
        unit_choose = 0; src_addr = 0; src2_addr = 0;
        src_c = 0; src_h = 0; src_w = 0;
        bias_addr = 0; scale_addr = 0; dst_addr = 0;
        addr_break = 0; addr_s = 0; addr_t = 0;
        cfg_wr_en = 0; cfg_wr_addr = 0; cfg_wr_data = 0;
        obuf_ext_wea = 0; obuf_ext_ena = 0; obuf_ext_addra = 0; obuf_ext_dina = 0;
        ibuf_ext_wea = 0; ibuf_ext_ena = 0; ibuf_ext_addra = 0; ibuf_ext_dina = 0;
        tb_wb_en = 0; tb_wb_we = 0; tb_wb_addr = 0; tb_wb_din = 0;
        pass_count = 0; fail_count = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        // =================================================================
        // Phase 1: Load input feature (8×8×16 UINT8) into OBUF
        // =================================================================
        $display("[%0t] Phase 1: Loading input feature...", $time);
        // Simple pattern: feature[h][w][c] = (h*W + w + c) & 0xFF
        for (i = 0; i < H*W; i = i + 1) begin  // 64 pixels, each 16 bytes = 1 word
            wr_word = 0;
            for (j = 0; j < 16; j = j + 1)
                wr_word[j*8 +: 8] = (i + j) & 8'hFF;
            obuf_write(i, wr_word);
        end
        $display("[%0t] Phase 1 done: %0d words loaded", $time, H*W);

        // =================================================================
        // Phase 2: Load weight into IBUF (identity-like: weight=+1)
        // =================================================================
        $display("[%0t] Phase 2: Loading weight...", $time);
        // Weight for 1×1 conv: [16, 16] INT8 → 8 SRAM entries per tile
        // Use weight = identity-ish: all +1 (low nibble=1, high nibble=0)
        begin
            reg [BUF_DATA_WIDTH-1:0] wei_entry;
            wei_entry = {64'h0000000000000000, 64'h1111111111111111};
            for (i = 0; i < 8; i = i + 1)
                ibuf_write(17'h1000 + i, wei_entry);
        end
        $display("[%0t] Phase 2 done", $time);

        // =================================================================
        // Phase 3: Load DQA params into WB via wb_bram interface
        // =================================================================
        $display("[%0t] Phase 3: Loading DQA/QA params into WB...", $time);
        // DQA scale (16 channels × FP32): scale=1.0 for all = 0x3f800000
        // Pack 4 FP32 per 128-bit word, WB byte addresses 0x00..0x3F
        wb_write(15'h0000, {32'h3f800000, 32'h3f800000, 32'h3f800000, 32'h3f800000});
        wb_write(15'h0010, {32'h3f800000, 32'h3f800000, 32'h3f800000, 32'h3f800000});
        wb_write(15'h0020, {32'h3f800000, 32'h3f800000, 32'h3f800000, 32'h3f800000});
        wb_write(15'h0030, {32'h3f800000, 32'h3f800000, 32'h3f800000, 32'h3f800000});
        // DQA bias (16 channels × FP32): bias=0.0, WB byte addresses 0x40..0x7F
        wb_write(15'h0040, 128'h0);
        wb_write(15'h0050, 128'h0);
        wb_write(15'h0060, 128'h0);
        wb_write(15'h0070, 128'h0);
        // QA scale (1 × FP32): scale=1.0, WB byte address 0x80
        wb_write(15'h0080, {96'h0, 32'h3f800000});
        $display("[%0t] Phase 3 done", $time);

        // =================================================================
        // Phase 4: Run im2col (1×1 kernel = identity copy)
        // =================================================================
        $display("[%0t] Phase 4: Running im2col...", $time);
        // im2col for 1×1: src→dst is just a copy (addr remap)
        // addr_break = {kH=1, kW=1, stride=1, stride=1, pad=0, pad=0}
        vpu_exec(
            32'd7,             // UNIT_IM2COL
            32'h0,             // src_addr (feature base)
            32'h0,             // src2 (unused)
            IC,                // src_c
            H,                 // src_h
            W,                 // src_w
            32'h0,             // bias (unused)
            32'h0,             // scale (unused)
            32'h010000,        // dst_addr (im2col output)
            {8'd3, 8'd3, 4'd1, 4'd1, 4'd1, 4'd1},  // addr_break: kH=3,kW=3,stride=1,pad=1
            OH,                // addr_s = OH
            OW                 // addr_t = OW
        );
        $display("[%0t] Phase 4 done: im2col complete", $time);

        // =================================================================
        // Phase 5: CDMA (simulated: copy OBUF → IBUF)
        // =================================================================
        $display("[%0t] Phase 5: CDMA copy OBUF→IBUF...", $time);
        // For 3×3 conv: im2col output = 64 pixels × 9 words = 576 words
        for (i = 0; i < OH*OW*ACC_DEPTH; i = i + 1) begin
            obuf_read(20'h01000 + i, rd_word);  // im2col output at 0x010000 byte = 0x1000 word
            ibuf_write(i, rd_word);
        end
        $display("[%0t] Phase 5 done", $time);

        // =================================================================
        // Phase 6: DCIM execution
        // =================================================================
        $display("[%0t] Phase 6: Running DCIM...", $time);
        // Configure DCIM
        dcim_cfg(`DCIM_REG_MODE, {16'h0, ACC_DEPTH[7:0], 5'h0, `MODE_INT8});
        dcim_cfg(`DCIM_REG_ACT_BASE, 0);       // IBUF base = 0
        dcim_cfg(`DCIM_REG_WEI_BASE, 17'h1000); // Weight base
        dcim_cfg(`DCIM_REG_OUT_BASE, 20'h02000); // OBUF output at word 0x2000
        // Start DCIM
        dcim_cfg(`DCIM_REG_CTRL, 32'h1);
        wait(dcim_ready == 0);
        wait(dcim_ready == 1);
        $display("[%0t] Phase 6 done: DCIM complete", $time);

        // Verify DCIM output in OBUF
        obuf_read(20'h02000, rd_word);
        $display("  DCIM out[0] = 0x%032h (expected non-zero INT32s)", rd_word);
        obuf_read(20'h02001, rd_word);
        $display("  DCIM out[1] = 0x%032h", rd_word);

        // =================================================================
        // Phase 7: DQA (INT32 → FP32, scale*x + bias)
        // =================================================================
        $display("[%0t] Phase 7: Running DQA...", $time);
        // DQA: src=DCIM output, dst=DQA output area
        // WB: scale at word 0 (byte addr 0), bias at word 4 (byte addr 64)
        vpu_exec(
            32'd1,               // UNIT_DQA
            32'h020000,          // src_addr: DCIM output (word 0x2000 = byte 0x20000)
            32'h0,               // src2 (unused)
            OC,                  // src_c = 16
            OH,                  // src_h = 8
            OW,                  // src_w = 8
            32'h0040,            // bias_addr: WB byte offset = word 4 × 16 = 64
            32'h0000,            // scale_addr: WB byte offset = 0
            32'h030000,          // dst_addr: DQA output in OBUF
            32'h0, 32'h0, 32'h0
        );
        $display("[%0t] Phase 7 done: DQA complete", $time);

        // Verify DQA output in OBUF (should be valid FP32)
        $display("[%0t] --- DQA output verification ---", $time);
        obuf_read(20'h03000, rd_word);  // DQA dst at 0x030000 byte = 0x3000 word
        $display("  DQA out[0] = 0x%032h", rd_word);
        // Each 128-bit = 4 FP32 values; with scale=1.0, bias=0.0:
        // FP32 output = float(DCIM_INT32_accumulator)
        // DCIM with weight=+1, 3x3 im2col: accumulator = sum of 144 INT8 activations
        obuf_read(20'h03001, rd_word);
        $display("  DQA out[1] = 0x%032h", rd_word);

        // =================================================================
        // Phase 8: QA (FP32 → INT8)
        // =================================================================
        $display("[%0t] Phase 8: Running QA...", $time);
        // QA: src=DQA output, dst=QA output area
        // WB: qa_scale at word 8 (byte addr 128)
        vpu_exec(
            32'd3,               // UNIT_QA
            32'h030000,          // src_addr: DQA output
            32'h0,
            OC,                  // src_c = 16
            OH,                  // src_h = 8
            OW,                  // src_w = 8
            32'h0,
            32'h0080,            // scale_addr: WB byte offset = 128
            32'h040000,          // dst_addr: QA output (final INT8)
            32'h0, 32'h0, 32'h0
        );
        $display("[%0t] Phase 8 done: QA complete", $time);

        // =================================================================
        // Phase 9: Verify output
        // =================================================================
        $display("[%0t] Phase 9: Verifying output...", $time);
        // Read first few output words and check non-zero
        for (i = 0; i < 4; i = i + 1) begin
            obuf_read(20'h04000 + i, rd_word);
            $display("  output[%0d] = 0x%032h", i, rd_word);
            if (rd_word !== 0 && rd_word !== {BUF_DATA_WIDTH{1'bx}}) begin
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: output word %0d is zero/x", i);
                fail_count = fail_count + 1;
            end
        end

        // =================================================================
        // Results
        // =================================================================
        $display("");
        $display("=============================================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");
        $display("=============================================================");
        $finish;
    end

    // Timeout
    initial begin
        #(CLK_PERIOD * 5000000);
        $display("FATAL: Global timeout");
        $finish(1);
    end

endmodule
