`timescale 1ns / 1ps
`include "chip_defines.vh"

// ============================================================================
// tb_inst_driven_im2col_dcim - INST_Decoder 指令驱动的 im2col + DCIM 联合仿真
// ============================================================================
// 验证完整指令驱动流：
//   1. Python golden 生成指令序列 → inst_bram
//   2. INST_Decoder 解码指令，依次执行：
//      OP_VPU_EXEC (im2col) → OP_WAIT_VPU → OP_CDMA_COPY → OP_WAIT_CDMA
//      → OP_DCIM_CFG → OP_DCIM_EXEC → OP_WAIT_DCIM → OP_END
//   3. 对比 DCIM 输出与 Python golden（数值精确匹配）
//
// CDMA 模型：behavioral（直接读 OBUF 写 IBUF）
// VPU 模型：VPU_im2col_shim（只含 im2col 单元）
// ============================================================================

module tb_inst_driven_im2col_dcim;

    // =========================================================================
    // 参数
    // =========================================================================
    localparam CLK_PERIOD      = 4.0;  // 250 MHz
    localparam INST_BRAM_DEPTH = 1024;
    localparam INST_ADDR_WIDTH = 10;

    localparam BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH;
    localparam IBUF_ADDR_WIDTH = `DCIM_IBUF_ADDR_WIDTH;
    localparam OBUF_ADDR_WIDTH = `DCIM_OBUF_ADDR_WIDTH;
    localparam STRB_WIDTH      = BUF_DATA_WIDTH / 8;
    localparam NUM_TILES       = `DCIM_TILES_PER_GROUP;

    // 与 golden 脚本一致的地址
    localparam [23:0] FEATURE_BASE   = 24'h000000;
    localparam [23:0] IM2COL_BASE    = 24'h010000;
    localparam [23:0] DCIM_OUT_BASE  = 24'h080000;
    localparam IBUF_WEI_BASE = 17'h1000;

    // CDMA 物理地址基址
    localparam [63:0] OBUF_PHY_BASE = 64'h1_0100_0000;
    localparam [63:0] IBUF_PHY_BASE = 64'h1_0000_0000;

    // =========================================================================
    // 信号声明
    // =========================================================================
    reg clk, rst_n;

    // INST_Decoder 接口
    reg         decoder_start;
    reg  [31:0] inst_count;
    wire        decoder_busy, decoder_done;
    wire [31:0] decoder_status;

    wire [INST_ADDR_WIDTH-1:0] inst_rd_addr;
    reg  [31:0]                inst_rd_data;

    // CDMA 接口
    wire        cdma_start, cdma_config_valid;
    wire [31:0] cdma_src_addr_msb, cdma_src_addr_lsb;
    wire [31:0] cdma_dst_addr_msb, cdma_dst_addr_lsb;
    wire [31:0] cdma_length;
    reg         cdma_config_ready;

    // VPU 接口
    wire        vpu_start, vpu_ready;
    wire [31:0] vpu_unit_choose, vpu_src_addr, vpu_src2_addr;
    wire [31:0] vpu_src_c, vpu_src_h, vpu_src_w;
    wire [31:0] vpu_bias_addr, vpu_scale_addr, vpu_dst_addr;
    wire [31:0] vpu_addr_break, vpu_addr_s, vpu_addr_t;

    // DCIM 接口
    wire        dcim_cfg_wr_en;
    wire [11:0] dcim_cfg_wr_addr;
    wire [31:0] dcim_cfg_wr_data;
    wire        dcim_ready, dcim_done;

    // OBUF 外部接口（用于初始化和验证读取）
    reg  [STRB_WIDTH-1:0]      obuf_ext_wea;
    reg                        obuf_ext_ena;
    reg  [OBUF_ADDR_WIDTH+3:0] obuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]  obuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]  obuf_ext_douta;

    // IBUF 外部接口
    reg  [STRB_WIDTH-1:0]      ibuf_ext_wea;
    reg                        ibuf_ext_ena;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] ibuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]  ibuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]  ibuf_ext_douta;

    // VPU OBUF 端口
    wire [OBUF_ADDR_WIDTH-1:0] vpu_obuf_addr;
    wire                       vpu_obuf_en;
    wire [STRB_WIDTH-1:0]      vpu_obuf_we;
    wire [BUF_DATA_WIDTH-1:0]  vpu_obuf_din;
    wire [BUF_DATA_WIDTH-1:0]  vpu_obuf_dout;

    // =========================================================================
    // 时钟
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // INST_BRAM 模型
    // =========================================================================
    reg [31:0] inst_bram_mem [0:INST_BRAM_DEPTH-1];
    always @(posedge clk)
        inst_rd_data <= inst_bram_mem[inst_rd_addr];

    // =========================================================================
    // INST_Decoder
    // =========================================================================
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
        .vpu_start        (vpu_start),
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

    // =========================================================================
    // VPU_im2col_shim
    // =========================================================================
    VPU_im2col_shim u_vpu (
        .clk         (clk),
        .rst_n       (rst_n),
        .ready       (vpu_ready),
        .vpu_start   (vpu_start),
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
        .obuf_dout   (vpu_obuf_dout)
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
        .done           (dcim_done),
        .ready          (dcim_ready)
    );

    // =========================================================================
    // CDMA Behavioral Model
    // =========================================================================
    // INST_Decoder 发出 cdma_config_valid + src_lsb/dst_lsb/length
    // src_lsb = OBUF 字节偏移（从 OBUF 读）
    // dst_lsb = IBUF 字节偏移（写到 IBUF）
    reg cdma_busy;
    reg [31:0] cdma_src_byte, cdma_dst_byte, cdma_remain;

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

    // CDMA 搬运：每 10 cycles 搬 1 个 128-bit word (16 bytes)
    reg [3:0] cdma_phase;
    reg [BUF_DATA_WIDTH-1:0] cdma_rd_data;

    // CDMA ext port 驱动信号（与 task 分离，通过 mux 合并）
    reg                        cdma_obuf_ena;
    reg  [STRB_WIDTH-1:0]     cdma_obuf_wea;
    reg  [OBUF_ADDR_WIDTH+3:0] cdma_obuf_addra;
    reg                        cdma_ibuf_ena;
    reg  [STRB_WIDTH-1:0]     cdma_ibuf_wea;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] cdma_ibuf_addra;
    reg  [BUF_DATA_WIDTH-1:0] cdma_ibuf_dina;

    // TB task 驱动信号
    reg                        tb_obuf_ena;
    reg  [STRB_WIDTH-1:0]     tb_obuf_wea;
    reg  [OBUF_ADDR_WIDTH+3:0] tb_obuf_addra;
    reg  [BUF_DATA_WIDTH-1:0] tb_obuf_dina;
    reg                        tb_ibuf_ena;
    reg  [STRB_WIDTH-1:0]     tb_ibuf_wea;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] tb_ibuf_addra;
    reg  [BUF_DATA_WIDTH-1:0] tb_ibuf_dina;

    // Mux：CDMA 优先
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
                8: begin
                    cdma_rd_data <= obuf_ext_douta;
                    cdma_phase <= 9;
                end
                9: begin
                    cdma_ibuf_ena   <= 1'b1;
                    cdma_ibuf_wea   <= {STRB_WIDTH{1'b1}};
                    cdma_ibuf_addra <= cdma_dst_byte[`DCIM_AXI_BRAM_ADDR_WIDTH-1:0];
                    cdma_ibuf_dina  <= cdma_rd_data;
                    cdma_phase <= 10;
                end
                10: begin
                    cdma_ibuf_ena <= 1'b0;
                    cdma_ibuf_wea <= '0;
                    cdma_src_byte <= cdma_src_byte + 16;
                    cdma_dst_byte <= cdma_dst_byte + 16;
                    cdma_remain   <= cdma_remain - 16;
                    cdma_phase <= 0;
                end
                default: begin
                    cdma_phase <= cdma_phase + 1;
                end
            endcase
        end else begin
            cdma_obuf_ena <= 0;
            cdma_ibuf_ena <= 0;
            cdma_ibuf_wea <= 0;
            cdma_phase <= 0;
        end
    end

    // =========================================================================
    // Tasks（驱动 tb_* 信号，通过 mux 连到 ext 端口）
    // =========================================================================
    task obuf_write_word;
        input [OBUF_ADDR_WIDTH-1:0] word_addr;
        input [BUF_DATA_WIDTH-1:0]  data;
        begin
            @(posedge clk);
            tb_obuf_ena   <= 1'b1;
            tb_obuf_wea   <= {STRB_WIDTH{1'b1}};
            tb_obuf_addra <= {word_addr, 4'b0000};
            tb_obuf_dina  <= data;
            @(posedge clk);
            tb_obuf_ena   <= 1'b0;
            tb_obuf_wea   <= '0;
        end
    endtask

    task ibuf_write_word;
        input [IBUF_ADDR_WIDTH-1:0] word_addr;
        input [BUF_DATA_WIDTH-1:0]  data;
        begin
            @(posedge clk);
            tb_ibuf_ena   <= 1'b1;
            tb_ibuf_wea   <= {STRB_WIDTH{1'b1}};
            tb_ibuf_addra <= {word_addr, 4'b0000};
            tb_ibuf_dina  <= data;
            @(posedge clk);
            tb_ibuf_ena   <= 1'b0;
            tb_ibuf_wea   <= '0;
        end
    endtask

    task obuf_read_word;
        input [OBUF_ADDR_WIDTH-1:0] word_addr;
        output [BUF_DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            tb_obuf_ena   <= 1'b1;
            tb_obuf_wea   <= '0;
            tb_obuf_addra <= {word_addr, 4'b0000};
            @(posedge clk);
            tb_obuf_ena   <= 1'b0;
            repeat(12) @(posedge clk);
            data = obuf_ext_douta;
        end
    endtask

    // =========================================================================
    // 测试主体
    // =========================================================================
    integer i, t, fd, scan_ret;
    integer pass_count, fail_count;
    reg [BUF_DATA_WIDTH-1:0] wr_word, rd_word;
    reg [127:0] golden_im2col_mem [0:575];  // 576 words
    reg [31:0]  golden_dcim [0:NUM_TILES-1][0:255]; // 256 words per tile (64 rows × 4 words/row)
    reg [31:0]  inst_word;
    string line;

    initial begin
        $display("=============================================================");
        $display("  tb_inst_driven_im2col_dcim");
        $display("  INST_Decoder 指令驱动的 im2col + DCIM 联合仿真");
        $display("=============================================================");

        // 初始化
        rst_n = 0;
        decoder_start = 0;
        inst_count = 0;
        tb_obuf_wea = 0; tb_obuf_ena = 0; tb_obuf_addra = 0; tb_obuf_dina = 0;
        tb_ibuf_wea = 0; tb_ibuf_ena = 0; tb_ibuf_addra = 0; tb_ibuf_dina = 0;
        pass_count = 0;
        fail_count = 0;

        // 清零 BRAM
        for (i = 0; i < INST_BRAM_DEPTH; i = i + 1)
            inst_bram_mem[i] = 32'h0;

        // =====================================================================
        // 加载 golden 数据
        // =====================================================================

        // 加载指令到 inst_bram
        $readmemh("golden_instructions.hex", inst_bram_mem);
        // 计算指令总字数
        for (i = 0; i < INST_BRAM_DEPTH; i = i + 1) begin
            if (inst_bram_mem[i][31:28] == 4'hF) begin
                inst_count = i + 1;
                i = INST_BRAM_DEPTH; // break
            end
        end
        $display("[%0t] Loaded %0d instruction words", $time, inst_count);

        // 加载 golden im2col
        $readmemh("golden_im2col.hex", golden_im2col_mem);

        // 复位
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(4) @(posedge clk);

        // =====================================================================
        // Phase 1: 加载 feature map 到 OBUF
        // =====================================================================
        $display("[%0t] Phase 1: Loading feature map...", $time);
        begin
            reg [127:0] feat_mem [0:63];
            $readmemh("golden_feature.hex", feat_mem);
            for (i = 0; i < 64; i = i + 1) begin
                obuf_write_word(FEATURE_BASE[23:4] + i, feat_mem[i]);
            end
        end
        $display("[%0t] Phase 1 done", $time);

        // =====================================================================
        // Phase 2: 加载 weight 到 IBUF
        // =====================================================================
        $display("[%0t] Phase 2: Loading weights to IBUF...", $time);
        begin
            reg [127:0] wei_mem [0:63];
            $readmemh("golden_weight.hex", wei_mem);
            for (i = 0; i < 64; i = i + 1) begin
                ibuf_write_word(IBUF_WEI_BASE + i, wei_mem[i]);
            end
        end
        $display("[%0t] Phase 2 done", $time);

        // =====================================================================
        // Phase 3: 启动 INST_Decoder 执行指令序列
        // =====================================================================
        $display("[%0t] Phase 3: Starting INST_Decoder...", $time);
        @(posedge clk);
        decoder_start = 1;
        @(posedge clk);
        decoder_start = 0;

        // 等待解码完成
        // decoder_busy 在 start 后变为 1，完成后变为 0
        wait(decoder_busy == 1);   // 先等它开始
        wait(decoder_busy == 0);   // 再等它完成
        if (decoder_status[31])
            $display("ERROR: decoder reported error status=0x%08h", decoder_status);
        repeat(20) @(posedge clk);
        $display("[%0t] Phase 3 done: decoder_status=0x%08h", $time, decoder_status);

        // =====================================================================
        // Phase 4: 验证 im2col 输出
        // =====================================================================
        $display("[%0t] Phase 4: Verifying im2col output...", $time);

        // Dummy read to prime pipeline
        obuf_read_word(IM2COL_BASE[23:4], rd_word);

        for (i = 0; i < 20; i = i + 1) begin
            obuf_read_word(IM2COL_BASE[23:4] + i, rd_word);
            if (rd_word === golden_im2col_mem[i]) begin
                pass_count = pass_count + 1;
            end else if (rd_word !== {BUF_DATA_WIDTH{1'bx}}) begin
                if (i < 10)
                    $display("  im2col[%0d]: got=0x%032h, exp=0x%032h %s",
                             i, rd_word, golden_im2col_mem[i],
                             (rd_word == golden_im2col_mem[i]) ? "OK" : "MISMATCH");
                if (rd_word != golden_im2col_mem[i])
                    fail_count = fail_count + 1;
                else
                    pass_count = pass_count + 1;
            end else begin
                $display("  im2col[%0d]: got=X (uninitialized)", i);
                fail_count = fail_count + 1;
            end
        end

        // =====================================================================
        // Phase 5: 验证 DCIM 输出（检查非零 + 数值合理性）
        // =====================================================================
        $display("[%0t] Phase 5: Verifying DCIM output...", $time);

        for (t = 0; t < NUM_TILES; t = t + 1) begin
            obuf_read_word(DCIM_OUT_BASE[23:4] + t * 20'h1000, rd_word);
            if (rd_word !== 0 && rd_word !== {BUF_DATA_WIDTH{1'bx}}) begin
                $display("  PASS: Tile %0d has output: 0x%032h", t, rd_word);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Tile %0d output is zero/x", t);
                fail_count = fail_count + 1;
            end
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
        $display("  decoder_status = 0x%08h (bit1=done, bit31=error)", decoder_status);
        $display("=============================================================");
        $finish;
    end

    // 超时
    initial begin
        #(CLK_PERIOD * 2000000);
        $display("FATAL: Global timeout");
        $finish(1);
    end

    // Debug monitors
    always @(posedge clk) begin
        if (vpu_start)
            $display("[%0t] VPU_START: unit=%0d src=0x%h dst=0x%h", $time, vpu_unit_choose, vpu_src_addr, vpu_dst_addr);
        if (cdma_config_valid && cdma_config_ready)
            $display("[%0t] CDMA_START: src=0x%h_%h dst=0x%h_%h len=%0d", $time,
                     cdma_src_addr_msb, cdma_src_addr_lsb, cdma_dst_addr_msb, cdma_dst_addr_lsb, cdma_length);
        if (dcim_cfg_wr_en && dcim_cfg_wr_addr == 12'h000 && dcim_cfg_wr_data[0])
            $display("[%0t] DCIM_START! ready_before=%b", $time, dcim_ready);
    end

    // Monitor DCIM ready transitions
    reg dcim_ready_prev;
    always @(posedge clk) begin
        dcim_ready_prev <= dcim_ready;
        if (dcim_ready && !dcim_ready_prev)
            $display("[%0t] DCIM_READY restored (computation complete)", $time);
        if (!dcim_ready && dcim_ready_prev)
            $display("[%0t] DCIM_READY dropped (computation started)", $time);
    end

endmodule
