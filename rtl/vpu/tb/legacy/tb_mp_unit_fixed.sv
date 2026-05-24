`timescale 1ns / 1ps
//==============================================================================
// tb_mp_unit_fixed - MaxPooling 5×5 硬编码单元 数值验证 Testbench
//==============================================================================
// 验证策略:
//   1. 生成随机 FP32 输入数据 (H=10, W=10, C=128, HWC layout)
//   2. 计算 Golden Model (软件 MaxPool 5×5, stride=1, pad=2)
//   3. 启动 DUT
//   4. 逐元素比较输出与 Golden Model (bit-exact)
//==============================================================================

module tb_mp_unit_fixed;

    // =========================================================================
    // 参数
    // =========================================================================
    localparam H         = 10;
    localparam W         = 10;
    localparam C         = 128;
    localparam KERNEL    = 5;
    localparam PAD       = 2;
    localparam OH        = 10;
    localparam OW        = 10;
    localparam GB_BW     = 256;
    localparam FP_W      = 32;
    localparam LANES     = GB_BW / FP_W;      // 8
    localparam C_BLOCKS  = C / LANES;          // 16
    localparam TOTAL_WORDS = H * W * C_BLOCKS; // 1600
    localparam ADDR_WIDTH = 32;
    localparam GB_ADDR_WIDTH = 32;

    localparam CLK_PERIOD = 4.0; // 250 MHz

    // =========================================================================
    // 信号
    // =========================================================================
    reg                       clk;
    reg                       rst_n;
    reg                       mp_unit_start;
    wire                      mp_unit_ready;

    reg  [ADDR_WIDTH-1:0]    mp_src_addr;
    reg  [ADDR_WIDTH-1:0]    mp_dst_addr;

    wire [GB_ADDR_WIDTH-1:0] gb_addrb;
    wire [GB_BW-1:0]         gb_dinb;
    wire [GB_BW/8-1:0]       gb_web;
    wire                     gb_enb;
    reg  [GB_BW-1:0]         gb_doutb;

    // =========================================================================
    // BRAM 模型
    // =========================================================================
    localparam BRAM_DEPTH = 4096;
    reg [GB_BW-1:0] bram [0:BRAM_DEPTH-1];

    // BRAM 读逻辑（1 周期延迟）
    always @(posedge clk) begin
        if (gb_enb && gb_web == '0) begin
            gb_doutb <= bram[gb_addrb];
        end
        if (gb_enb && gb_web != '0) begin
            bram[gb_addrb] <= gb_dinb;
        end
    end

    // =========================================================================
    // DUT
    // =========================================================================
    mp_unit_fixed #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BW),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .FP_WIDTH(FP_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mp_unit_start(mp_unit_start),
        .mp_unit_ready(mp_unit_ready),
        .mp_src_addr(mp_src_addr),
        .mp_dst_addr(mp_dst_addr),
        .gb_addrb(gb_addrb),
        .gb_dinb(gb_dinb),
        .gb_web(gb_web),
        .gb_enb(gb_enb),
        .gb_doutb(gb_doutb)
    );

    // =========================================================================
    // 时钟
    // =========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // Golden Model 存储
    // =========================================================================
    reg [FP_W-1:0] input_data  [0:H*W*C-1];   // 平铺 HWC
    reg [FP_W-1:0] golden_out  [0:OH*OW*C-1]; // 期望输出

    // FP32 比较函数：使用 SystemVerilog 原生浮点运算（独立于 RTL 的位操作实现）
    function [FP_W-1:0] fp32_max_func;
        input [FP_W-1:0] a, b;
        shortreal ra, rb;
        begin
            ra = $bitstoshortreal(a);
            rb = $bitstoshortreal(b);
            if (rb > ra)
                fp32_max_func = b;
            else
                fp32_max_func = a;
        end
    endfunction

    // =========================================================================
    // 测试流程
    // =========================================================================
    integer h, w, c_idx, kh, kw, ih, iw;
    integer src_word_base, dst_word_base;
    integer total_errors, total_checked;
    reg [FP_W-1:0] cur_max, val;
    reg [FP_W-1:0] actual_val, expected_val;

    initial begin
        $display("============================================================");
        $display("  tb_mp_unit_fixed: MaxPool 5x5, stride=1, pad=2");
        $display("  Input: H=%0d, W=%0d, C=%0d (HWC, FP32, 256-bit aligned)", H, W, C);
        $display("============================================================");

        // 初始化
        rst_n = 0;
        mp_unit_start = 0;
        mp_src_addr = 32'h0000_0000;  // 输入从 word 0 开始
        mp_dst_addr = 32'h0000_C800;  // 输出从 word 1600 开始 (1600*32=51200=0xC800)
        gb_doutb = '0;

        // 清空 BRAM
        for (int i = 0; i < BRAM_DEPTH; i++) bram[i] = '0;

        // 复位
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // -----------------------------------------------------------------
        // 生成随机输入数据并写入 BRAM
        // -----------------------------------------------------------------
        $display("\n[1] Generating random FP32 input data...");
        src_word_base = 0;
        dst_word_base = TOTAL_WORDS; // 1600

        for (h = 0; h < H; h++) begin
            for (w = 0; w < W; w++) begin
                for (c_idx = 0; c_idx < C; c_idx++) begin
                    // 生成值: value = (h*100 + w*10 + c_idx) 的 FP32 表示
                    // 这样数据有规律又不全相同，方便调试
                    val = real_to_fp32($itor(h * 100 + w * 10 + c_idx) / 10.0 - 5.0);
                    input_data[h*W*C + w*C + c_idx] = val;

                    // 写入 BRAM (HWC layout, 每 8 个 channel 一个 word)
                    bram[src_word_base + (h*W + w)*C_BLOCKS + c_idx/LANES]
                        [(c_idx % LANES)*FP_W +: FP_W] = val;
                end
            end
        end
        $display("   Done. Total input elements: %0d", H*W*C);

        // -----------------------------------------------------------------
        // 计算 Golden Model
        // -----------------------------------------------------------------
        $display("\n[2] Computing golden model (MaxPool 5x5, pad=2, stride=1)...");
        for (h = 0; h < OH; h++) begin
            for (w = 0; w < OW; w++) begin
                for (c_idx = 0; c_idx < C; c_idx++) begin
                    cur_max = 32'hFF80_0000; // -inf
                    for (kh = 0; kh < KERNEL; kh++) begin
                        for (kw = 0; kw < KERNEL; kw++) begin
                            ih = h + kh - PAD;
                            iw = w + kw - PAD;
                            if (ih >= 0 && ih < H && iw >= 0 && iw < W) begin
                                val = input_data[ih*W*C + iw*C + c_idx];
                                cur_max = fp32_max_func(cur_max, val);
                            end
                        end
                    end
                    golden_out[h*OW*C + w*C + c_idx] = cur_max;
                end
            end
        end
        $display("   Done.");

        // -----------------------------------------------------------------
        // 启动 DUT
        // -----------------------------------------------------------------
        $display("\n[3] Starting DUT...");
        @(posedge clk);
        mp_unit_start <= 1;
        @(posedge clk);
        mp_unit_start <= 0;

        // 等待完成
        wait(mp_unit_ready == 1'b0);
        $display("   DUT busy...");
        wait(mp_unit_ready == 1'b1);
        $display("   DUT done.");

        repeat(5) @(posedge clk);

        // -----------------------------------------------------------------
        // 比较输出
        // -----------------------------------------------------------------
        $display("\n[4] Comparing output with golden model...");
        total_errors = 0;
        total_checked = 0;

        for (h = 0; h < OH; h++) begin
            for (w = 0; w < OW; w++) begin
                for (c_idx = 0; c_idx < C; c_idx++) begin
                    actual_val = bram[dst_word_base + (h*OW + w)*C_BLOCKS + c_idx/LANES]
                                     [(c_idx % LANES)*FP_W +: FP_W];
                    expected_val = golden_out[h*OW*C + w*C + c_idx];
                    total_checked = total_checked + 1;

                    if (actual_val !== expected_val) begin
                        total_errors = total_errors + 1;
                        if (total_errors <= 20) begin
                            $display("   MISMATCH [h=%0d w=%0d c=%0d]: expected=0x%08h actual=0x%08h",
                                     h, w, c_idx, expected_val, actual_val);
                        end
                    end
                end
            end
        end

        // -----------------------------------------------------------------
        // 报告
        // -----------------------------------------------------------------
        $display("\n============================================================");
        $display("  RESULTS:");
        $display("    Total elements checked: %0d", total_checked);
        $display("    Errors:                 %0d", total_errors);
        if (total_errors == 0) begin
            $display("    STATUS:                 *** PASS ***");
        end else begin
            $display("    STATUS:                 *** FAIL ***");
        end
        $display("============================================================\n");

        $finish;
    end

    // =========================================================================
    // 辅助：生成随机 FP32
    // 使用简单的整数映射：value = integer / 10.0，范围 [-10, +100]
    // =========================================================================
    function [FP_W-1:0] int_to_fp32;
        input integer ival;
        real rval;
        reg [FP_W-1:0] bits;
        begin
            rval = $itor(ival) / 10.0;
            bits = $realtobits(rval);
            // $realtobits 返回 64-bit double，需要转为 32-bit float
            // 简化方案：直接用 shortreal
            int_to_fp32 = real_to_fp32(rval);
        end
    endfunction

    function [FP_W-1:0] real_to_fp32;
        input real rval;
        shortreal sr;
        begin
            sr = shortreal'(rval);
            real_to_fp32 = $shortrealtobits(sr);
        end
    endfunction

    // =========================================================================
    // 超时保护
    // =========================================================================
    initial begin
        #(CLK_PERIOD * 200000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    // =========================================================================
    // 波形 dump
    // =========================================================================
    initial begin
        $dumpfile("tb_mp_unit_fixed.vcd");
        $dumpvars(0, tb_mp_unit_fixed);
    end

endmodule
