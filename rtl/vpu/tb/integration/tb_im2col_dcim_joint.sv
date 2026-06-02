`timescale 1ns / 1ps
`include "chip_defines.vh"
`include "chip_defines.vh"

// ============================================================================
// tb_im2col_dcim_joint - im2col + DCIM 联合仿真
// ============================================================================
// 验证完整数据流（单层卷积）：
//   1. 初始化 OBUF feature（NHWC 布局）
//   2. im2col_unit 将 feature 重排为 im2col 矩阵 → OBUF
//   3. 模拟 CDMA 将 OBUF im2col 数据搬到 IBUF
//   4. 初始化 DCIM weight SRAM（通过 IBUF 写端口写入权重）
//   5. 配置并启动 DCIM_Array 计算（IBUF × weight → OBUF）
//   6. 对比 OBUF 输出与 Python golden（self-check 模式用已知权重）
//
// Self-check 策略：weight 全设为 +1（INT4 = 4'b0001），
// 则 DCIM 输出 = sum(im2col_row[0:CH_IN-1])，即每 CH_OUT 通道都相同。
// ============================================================================

module tb_im2col_dcim_joint;

    // =========================================================================
    // 参数
    // =========================================================================
    localparam CLK_PERIOD = 4.0;  // 250 MHz

    // Feature map 配置（缩小尺寸加速仿真）
    localparam CH_IN   = 16;
    localparam H       = 8;
    localparam W       = 8;
    localparam KH      = 3;
    localparam KW      = 3;
    localparam STRIDE  = 1;
    localparam PAD     = 1;
    localparam OH      = (H + 2*PAD - KH) / STRIDE + 1;  // 8
    localparam OW      = (W + 2*PAD - KW) / STRIDE + 1;  // 8

    // im2col 每行长度 = kH * kW * CH_IN = 144 bytes = 9 个 128-bit word
    localparam IM2COL_ROW_BYTES = KH * KW * CH_IN;
    // im2col 总行数 = OH * OW = 64
    localparam IM2COL_ROWS = OH * OW;

    // DCIM 参数
    localparam NUM_TILES       = `DCIM_NUM_TILES;
    localparam WD1             = `DCIM_WD1;              // 4
    localparam DCIM_CH_IN      = `DCIM_CH_IN;            // 16
    localparam DCIM_CH_OUT     = `DCIM_CH_OUT;           // 16
    localparam SRAM_DP         = `DCIM_SRAM_DP;          // 128
    localparam CYCLE           = `DCIM_CYCLE;            // 8
    localparam ACC             = `DCIM_ACC_MAX;          // 80

    // Buffer 参数
    localparam BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH;   // 128
    localparam IBUF_ADDR_WIDTH = `DCIM_IBUF_ADDR_WIDTH;  // 17
    localparam OBUF_ADDR_WIDTH = `DCIM_OBUF_ADDR_WIDTH;  // 20
    localparam STRB_WIDTH      = BUF_DATA_WIDTH / 8;     // 16

    // OBUF 地址映射（字节地址）
    localparam [23:0] FEATURE_BASE  = 24'h000000;  // feature 起始
    localparam [23:0] IM2COL_BASE   = 24'h010000;  // im2col 输出起始（64KB 偏移）
    localparam [23:0] DCIM_OUT_BASE = 24'h080000;  // DCIM 输出起始（512KB 偏移）

    // IBUF 地址映射
    // im2col 数据从 OBUF IM2COL_BASE 搬到 IBUF ACT_BASE
    localparam [IBUF_ADDR_WIDTH-1:0] IBUF_ACT_BASE = 0;
    // 权重从 IBUF WEI_BASE 开始，每 Tile CYCLE words
    localparam [IBUF_ADDR_WIDTH-1:0] IBUF_WEI_BASE = 17'h1000;

    // DCIM acc_depth = ceil(IM2COL_ROW_BYTES / 16) = 9
    localparam ACC_DEPTH = (IM2COL_ROW_BYTES + 15) / 16;  // 9

    // =========================================================================
    // 信号声明
    // =========================================================================
    reg clk, rst_n;

    // DCIM_Array_bd 接口
    reg        cfg_wr_en;
    reg [11:0] cfg_wr_addr;
    reg [31:0] cfg_wr_data;

    reg  [STRB_WIDTH-1:0]    ibuf_ext_wea;
    reg                      ibuf_ext_ena;
    reg  [IBUF_ADDR_WIDTH+3:0] ibuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0] ibuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0] ibuf_ext_douta;

    reg  [STRB_WIDTH-1:0]    obuf_ext_wea;
    reg                      obuf_ext_ena;
    reg  [OBUF_ADDR_WIDTH+3:0] obuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0] obuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0] obuf_ext_douta;

    // VPU OBUF 端口（im2col_unit → DCIM_Array_bd）
    wire [OBUF_ADDR_WIDTH-1:0]  vpu_obuf_addr;
    wire                        vpu_obuf_en;
    wire [STRB_WIDTH-1:0]       vpu_obuf_we;
    wire [BUF_DATA_WIDTH-1:0]   vpu_obuf_din;
    wire [BUF_DATA_WIDTH-1:0]   vpu_obuf_dout;
    wire                        vpu_obuf_rd_valid;

    wire dcim_done;
    wire dcim_ready;

    // im2col_unit 接口
    reg  im2col_start;
    wire im2col_ready;

    wire [23:0]              im2col_gb_addrb;
    wire [BUF_DATA_WIDTH-1:0] im2col_gb_dinb;
    wire [STRB_WIDTH-1:0]    im2col_gb_web;
    wire                     im2col_gb_enb;

    // im2col → VPU OBUF 端口映射
    assign vpu_obuf_addr = im2col_gb_addrb[OBUF_ADDR_WIDTH+3:4]; // 字节→字地址
    assign vpu_obuf_en   = im2col_gb_enb;
    assign vpu_obuf_we   = im2col_gb_web;
    assign vpu_obuf_din  = im2col_gb_dinb;

    // =========================================================================
    // 时钟
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // DUT: DCIM_Array_bd
    // =========================================================================
    DCIM_Array_bd #(
        .NUM_TILES       (NUM_TILES),
        .WD1             (WD1),
        .CH_IN           (DCIM_CH_IN),
        .CH_OUT          (DCIM_CH_OUT),
        .SRAM_DP         (SRAM_DP),
        .CYCLE           (CYCLE),
        .ACC             (ACC),
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
        .vpu_obuf_rd_valid(vpu_obuf_rd_valid),
        .ready          (dcim_ready)
    );

    // =========================================================================
    // DUT: im2col_unit
    // =========================================================================
    im2col_unit #(
        .ADDR_WIDTH    (32),
        .GB_BANDWIDTH  (BUF_DATA_WIDTH),
        .GB_ADDR_WIDTH (24),
        .FP_WIDTH      (32)
    ) u_im2col (
        .clk               (clk),
        .rst_n             (rst_n),
        .im2col_unit_start (im2col_start),
        .im2col_unit_ready (im2col_ready),
        .im2col_src_addr   (FEATURE_BASE),
        .im2col_dst_addr   (IM2COL_BASE),
        .im2col_src_c      (CH_IN),
        .im2col_src_h      (H),
        .im2col_src_w      (W),
        .im2col_addr_break ({KH[7:0], KW[7:0], STRIDE[3:0], STRIDE[3:0], PAD[3:0], PAD[3:0]}),
        .im2col_addr_s     (OH),
        .im2col_addr_t     (OW),
        .gb_addrb          (im2col_gb_addrb),
        .gb_dinb           (im2col_gb_dinb),
        .gb_web            (im2col_gb_web),
        .gb_enb            (im2col_gb_enb),
        .gb_doutb          (vpu_obuf_dout),
        .gb_doutb_valid    (vpu_obuf_rd_valid)
    );

    // =========================================================================
    // 辅助 Task
    // =========================================================================

    // 通过 OBUF 外部端口写一个 128-bit word
    task obuf_write;
        input [OBUF_ADDR_WIDTH-1:0] word_addr;
        input [BUF_DATA_WIDTH-1:0]  data;
        begin
            @(posedge clk);
            obuf_ext_ena   <= 1'b1;
            obuf_ext_wea   <= {STRB_WIDTH{1'b1}};
            obuf_ext_addra <= {word_addr, 4'b0000};  // 字→字节地址
            obuf_ext_dina  <= data;
            @(posedge clk);
            obuf_ext_ena   <= 1'b0;
            obuf_ext_wea   <= '0;
        end
    endtask

    // 通过 OBUF 外部端口读一个 128-bit word
    // OBUF 读延迟链: DCIM_Array_bd(无) → obuf.v input_reg(1) → bank_select(1)
    //   → obuf_bank memreg(1) → pipe_rega[0..NBPIPE-1](NBPIPE=2) → bank output mux(1)
    //   → obuf.v output mux(1)
    // 总延迟 ≈ 1 + 1 + 1 + 2 + 1 + 1 = 7 cycles
    // 但 pipe 由 en_pipe 门控：只有 en=1 的周期才推进
    // 安全起见用 12 cycles
    task obuf_read;
        input [OBUF_ADDR_WIDTH-1:0] word_addr;
        output [BUF_DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            obuf_ext_ena   <= 1'b1;
            obuf_ext_wea   <= '0;
            obuf_ext_addra <= {word_addr, 4'b0000};
            obuf_ext_dina  <= '0;
            @(posedge clk);
            obuf_ext_ena   <= 1'b0;
            repeat(12) @(posedge clk);
            data = obuf_ext_douta;
        end
    endtask

    // 通过 IBUF 外部端口写一个 128-bit word
    task ibuf_write;
        input [IBUF_ADDR_WIDTH-1:0] word_addr;
        input [BUF_DATA_WIDTH-1:0]  data;
        begin
            @(posedge clk);
            ibuf_ext_ena   <= 1'b1;
            ibuf_ext_wea   <= {STRB_WIDTH{1'b1}};
            ibuf_ext_addra <= {word_addr, 4'b0000};  // 字→字节
            ibuf_ext_dina  <= data;
            @(posedge clk);
            ibuf_ext_ena   <= 1'b0;
            ibuf_ext_wea   <= '0;
        end
    endtask

    // 写 DCIM 配置寄存器
    task dcim_cfg_write;
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

    // =========================================================================
    // 测试主体
    // =========================================================================
    integer i, j, k, t;
    integer pass_count, fail_count;
    reg [7:0] pixel_val;
    reg [BUF_DATA_WIDTH-1:0] wr_word;
    reg [BUF_DATA_WIDTH-1:0] rd_word;

    // 用于 golden 计算
    reg signed [7:0]  feature_flat [0:H*W*CH_IN-1];
    reg signed [31:0] golden_sum [0:NUM_TILES-1][0:IM2COL_ROWS-1];

    initial begin
        $display("=============================================================");
        $display("  tb_im2col_dcim_joint - im2col + DCIM 联合仿真");
        $display("  Feature: %0dx%0dx%0d, Kernel: %0dx%0d, Stride: %0d, Pad: %0d",
                 H, W, CH_IN, KH, KW, STRIDE, PAD);
        $display("  OH=%0d, OW=%0d, IM2COL_ROWS=%0d, ACC_DEPTH=%0d",
                 OH, OW, IM2COL_ROWS, ACC_DEPTH);
        $display("=============================================================");

        // 初始化信号
        rst_n = 0;
        im2col_start = 0;
        cfg_wr_en = 0; cfg_wr_addr = 0; cfg_wr_data = 0;
        ibuf_ext_wea = 0; ibuf_ext_ena = 0; ibuf_ext_addra = 0; ibuf_ext_dina = 0;
        obuf_ext_wea = 0; obuf_ext_ena = 0; obuf_ext_addra = 0; obuf_ext_dina = 0;
        pass_count = 0;
        fail_count = 0;

        // 生成 feature 数据并记录 flat 数组
        for (i = 0; i < H*W*CH_IN; i = i + 1) begin
            feature_flat[i] = (i & 8'h7F) + 1;  // 1~128 避免全 0
        end

        // 复位
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(4) @(posedge clk);

        // =====================================================================
        // Phase 1: 通过 OBUF 外部端口初始化 feature map
        // =====================================================================
        $display("[%0t] Phase 1: Loading feature map into OBUF...", $time);
        for (i = 0; i < (H*W*CH_IN + 15) / 16; i = i + 1) begin
            wr_word = 0;
            for (j = 0; j < 16; j = j + 1) begin
                if (i*16 + j < H*W*CH_IN)
                    wr_word[j*8 +: 8] = feature_flat[i*16 + j];
            end
            obuf_write(FEATURE_BASE[23:4] + i, wr_word);
        end
        $display("[%0t] Phase 1 done: %0d words written", $time, (H*W*CH_IN + 15) / 16);

        // =====================================================================
        // Phase 2: 启动 im2col_unit
        // =====================================================================
        $display("[%0t] Phase 2: Starting im2col...", $time);
        repeat(2) @(posedge clk);
        im2col_start = 1;
        @(posedge clk);
        im2col_start = 0;

        // 等待 im2col 完成
        wait(im2col_ready == 1);
        repeat(5) @(posedge clk);
        $display("[%0t] Phase 2 done: im2col complete", $time);

        // =====================================================================
        // Phase 3: 模拟 CDMA 将 OBUF im2col 数据搬到 IBUF
        // =====================================================================
        $display("[%0t] Phase 3: CDMA copy OBUF→IBUF (im2col data)...", $time);

        // Prime OBUF read pipeline (first read after idle may have x in pipeline)
        obuf_read(IM2COL_BASE[23:4], rd_word);  // dummy read to flush pipeline

        // im2col 数据量 = IM2COL_ROWS * ACC_DEPTH words（每行 ACC_DEPTH 个 128-bit word）
        for (i = 0; i < IM2COL_ROWS * ACC_DEPTH; i = i + 1) begin
            // 读 OBUF
            obuf_read(IM2COL_BASE[23:4] + i, rd_word);
            // 写 IBUF
            ibuf_write(IBUF_ACT_BASE + i, rd_word);
        end
        $display("[%0t] Phase 3 done: %0d words copied to IBUF", $time, IM2COL_ROWS * ACC_DEPTH);

        // =====================================================================
        // Phase 4: 初始化 DCIM weight（weight=+1 即 4'b0001）
        // =====================================================================
        $display("[%0t] Phase 4: Loading weights into IBUF...", $time);
        // 每 Tile 需要 CYCLE words（每 word = 128-bit = CH_IN*CH_OUT*WD1/CYCLE/128 ???）
        // Weight SRAM 布局：每 word = SRAM_WD bits = CH_IN*CH_OUT*WD1/CYCLE = 16*16*4/8 = 128 bits
        // 正好 1 个 128-bit IBUF word = 1 个 SRAM entry
        // weight 全为 +1 (INT4 signed: 4'b0001)
        // 每 entry 128 bits = 32 个 4-bit nibble，全设为 0001
        begin
            reg [BUF_DATA_WIDTH-1:0] wei_word;
            // INT8 mode weight format: 128-bit entry = {high_nibble(64-bit), low_nibble(64-bit)}
            // For weight=+1 (INT8=0x01): low=0x1, high=0x0
            wei_word = {64'h0000000000000000, 64'h1111111111111111};
            for (t = 0; t < NUM_TILES; t = t + 1) begin
                for (i = 0; i < CYCLE; i = i + 1) begin
                    ibuf_write(IBUF_WEI_BASE + t * CYCLE + i, wei_word);
                end
            end
        end
        $display("[%0t] Phase 4 done: %0d weight words loaded", $time, NUM_TILES * CYCLE);

        // =====================================================================
        // Phase 5: 配置并启动 DCIM
        // =====================================================================
        $display("[%0t] Phase 5: Configuring and starting DCIM...", $time);
        $display("[%0t]   dcim_ready=%b dcim_done=%b", $time, dcim_ready, dcim_done);

        // MODE = INT4 (3'b100), acc_depth = ACC_DEPTH
        dcim_cfg_write(`DCIM_REG_MODE, {16'h0, ACC_DEPTH[7:0], 5'h0, `MODE_INT8});

        // ACT_BASE = IBUF_ACT_BASE
        dcim_cfg_write(`DCIM_REG_ACT_BASE, {{(32-IBUF_ADDR_WIDTH){1'b0}}, IBUF_ACT_BASE});

        // WEI_BASE 每 Tile
        for (t = 0; t < NUM_TILES; t = t + 1) begin
            dcim_cfg_write(`DCIM_REG_WEI_BASE + t*4,
                           {{(32-IBUF_ADDR_WIDTH){1'b0}}, IBUF_WEI_BASE + t * CYCLE});
        end

        // OUT_BASE 每 Tile（在 OBUF 中，使用字地址）
        for (t = 0; t < NUM_TILES; t = t + 1) begin
            dcim_cfg_write(`DCIM_REG_OUT_BASE + t*4,
                           DCIM_OUT_BASE[23:4] + t * 20'h1000);
        end

        // 确认 DCIM ready 再启动
        $display("[%0t]   Before start: dcim_ready=%b", $time, dcim_ready);

        // 启动 DCIM
        dcim_cfg_write(`DCIM_REG_CTRL, 32'h1);

        // 等待 DCIM 完成（ready 会先降后升，或 done 脉冲）
        $display("[%0t] Waiting for DCIM done...", $time);
        repeat(5) @(posedge clk);
        wait(dcim_done == 1);
        repeat(20) @(posedge clk);  // extra cycles for last write to settle in OBUF
        $display("[%0t] Phase 5 done: DCIM computation complete (ready=%b done=%b)", $time, dcim_ready, dcim_done);

        // =====================================================================
        // Phase 6: 验证结果
        // =====================================================================
        $display("[%0t] Phase 6: Verifying results...", $time);

        // 扫描 OBUF 寻找 DCIM 输出（从 0x2000 到 0xFFFF word 范围）
        $display("\n--- Scanning OBUF for non-zero/non-x data (word 0x2000~0x200F) ---");
        for (i = 0; i < 16; i = i + 1) begin
            obuf_read(20'h08000 + i, rd_word);
            if (rd_word !== 0 && rd_word !== {BUF_DATA_WIDTH{1'bx}})
                $display("  OBUF[0x%05h] = 0x%032h", 20'h08000 + i, rd_word);
        end

        // 检查 DCIM OUT_BASE 配置的地址
        $display("\n--- DCIM output at configured OUT_BASE (word 0x%05h) ---", DCIM_OUT_BASE[23:4]);
        for (i = 0; i < 8; i = i + 1) begin
            obuf_read(DCIM_OUT_BASE[23:4] + i, rd_word);
            $display("  dcim_out[word %0d] = 0x%032h", i, rd_word);
        end

        // 检查每个 Tile 的输出位置
        for (t = 0; t < NUM_TILES; t = t + 1) begin
            obuf_read(DCIM_OUT_BASE[23:4] + t * 20'h1000, rd_word);
            if (rd_word !== 0 && rd_word !== {BUF_DATA_WIDTH{1'bx}}) begin
                $display("PASS: Tile %0d output non-zero: 0x%032h", t, rd_word);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: Tile %0d output at word 0x%05h = 0x%032h",
                         t, DCIM_OUT_BASE[23:4] + t * 20'h1000, rd_word);
                fail_count = fail_count + 1;
            end
        end

        // Dump 第一行 im2col 结果用于调试
        $display("\n--- im2col row 0 (first %0d words) ---", ACC_DEPTH);
        for (i = 0; i < ACC_DEPTH; i = i + 1) begin
            obuf_read(IM2COL_BASE[23:4] + i, rd_word);
            $display("  im2col[0][word %0d] = 0x%032h", i, rd_word);
        end

        // Dump DCIM Tile 0 输出
        $display("\n--- DCIM Tile 0 output (first 4 words) ---");
        for (i = 0; i < 4; i = i + 1) begin
            obuf_read(DCIM_OUT_BASE[23:4] + i, rd_word);
            $display("  dcim_out[0][word %0d] = 0x%032h", i, rd_word);
        end

        // =====================================================================
        // 结果汇总
        // =====================================================================
        $display("");
        $display("=============================================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("  ALL TESTS PASSED");
        end else begin
            $display("  SOME TESTS FAILED");
        end
        $display("=============================================================");
        $finish;
    end

    // 超时保护
    initial begin
        #(CLK_PERIOD * 500000);
        $display("FATAL: Global timeout (500K cycles)");
        $finish(1);
    end

endmodule
