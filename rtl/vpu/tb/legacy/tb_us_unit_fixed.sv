`timescale 1ns / 1ps
//==============================================================================
// tb_us_unit_fixed - Nearest Upsample ×2 数值验证 Testbench
//==============================================================================
// 验证两种配置:
//   Case 1: C=128, H=10, W=10 → C=128, H=20, W=20
//   Case 2: C=64,  H=20, W=20 → C=64,  H=40, W=40
//==============================================================================

module tb_us_unit_fixed;

    localparam GB_BW     = 256;
    localparam FP_W      = 32;
    localparam LANES     = GB_BW / FP_W;      // 8
    localparam ADDR_WIDTH = 32;
    localparam GB_ADDR_WIDTH = 32;
    localparam CLK_PERIOD = 4.0; // 250 MHz

    // =========================================================================
    // 信号
    // =========================================================================
    reg                       clk;
    reg                       rst_n;
    reg                       us_unit_start;
    wire                      us_unit_ready;

    reg  [ADDR_WIDTH-1:0]    us_src_addr;
    reg  [ADDR_WIDTH-1:0]    us_src_h;
    reg  [ADDR_WIDTH-1:0]    us_src_w;
    reg  [ADDR_WIDTH-1:0]    us_src_c;
    reg  [ADDR_WIDTH-1:0]    us_dst_addr;

    wire [GB_ADDR_WIDTH-1:0] gb_addrb;
    wire [GB_BW-1:0]         gb_dinb;
    wire [GB_BW/8-1:0]       gb_web;
    wire                     gb_enb;
    reg  [GB_BW-1:0]         gb_doutb;

    // =========================================================================
    // BRAM 模型 (足够大以容纳最大测试: 40×40×8 = 12800 words 输出)
    // =========================================================================
    localparam BRAM_DEPTH = 16384;
    reg [GB_BW-1:0] bram [0:BRAM_DEPTH-1];

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
    us_unit_fixed #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BW),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .FP_WIDTH(FP_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .us_unit_start(us_unit_start),
        .us_unit_ready(us_unit_ready),
        .us_src_addr(us_src_addr),
        .us_src_h(us_src_h),
        .us_src_w(us_src_w),
        .us_src_c(us_src_c),
        .us_dst_addr(us_dst_addr),
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
    // 测试任务
    // =========================================================================
    integer total_errors;

    task run_test(
        input integer t_h,
        input integer t_w,
        input integer t_c,
        input string  test_name
    );
        integer h, w, c_idx, oh, ow, ih_gold, iw_gold;
        integer c_blocks, in_words, out_words;
        integer src_base, dst_base;
        reg [FP_W-1:0] val, actual_val, expected_val;
        integer errors, checked;
    begin
        c_blocks  = t_c / LANES;
        in_words  = t_h * t_w * c_blocks;
        out_words = (t_h*2) * (t_w*2) * c_blocks;
        src_base  = 0;
        dst_base  = in_words;

        $display("\n  --- %s: C=%0d, H=%0d, W=%0d → H=%0d, W=%0d ---",
                 test_name, t_c, t_h, t_w, t_h*2, t_w*2);

        // 清空 BRAM
        for (int i = 0; i < BRAM_DEPTH; i++) bram[i] = '0;

        // 填入输入数据 (HWC layout)
        for (h = 0; h < t_h; h++) begin
            for (w = 0; w < t_w; w++) begin
                for (c_idx = 0; c_idx < t_c; c_idx++) begin
                    val = real_to_fp32($itor(h * 1000 + w * 10 + c_idx) / 10.0);
                    bram[src_base + (h*t_w + w)*c_blocks + c_idx/LANES]
                        [(c_idx % LANES)*FP_W +: FP_W] = val;
                end
            end
        end

        // 配置 DUT
        us_src_addr = src_base * 32; // word_addr * 32 = byte_addr
        us_dst_addr = dst_base * 32;
        us_src_h    = t_h;
        us_src_w    = t_w;
        us_src_c    = t_c;

        // 启动
        @(posedge clk);
        us_unit_start <= 1;
        @(posedge clk);
        us_unit_start <= 0;

        wait(us_unit_ready == 1'b0);
        wait(us_unit_ready == 1'b1);
        repeat(5) @(posedge clk);

        // 验证输出
        errors = 0;
        checked = 0;
        for (oh = 0; oh < t_h*2; oh++) begin
            for (ow = 0; ow < t_w*2; ow++) begin
                // Nearest floor: input[oh/2][ow/2]
                ih_gold = oh / 2;
                iw_gold = ow / 2;
                for (c_idx = 0; c_idx < t_c; c_idx++) begin
                    expected_val = bram[src_base + (ih_gold*t_w + iw_gold)*c_blocks + c_idx/LANES]
                                       [(c_idx % LANES)*FP_W +: FP_W];
                    actual_val = bram[dst_base + (oh*(t_w*2) + ow)*c_blocks + c_idx/LANES]
                                     [(c_idx % LANES)*FP_W +: FP_W];
                    checked = checked + 1;
                    if (actual_val !== expected_val) begin
                        errors = errors + 1;
                        if (errors <= 10) begin
                            $display("    MISMATCH [oh=%0d ow=%0d c=%0d]: expected=0x%08h actual=0x%08h",
                                     oh, ow, c_idx, expected_val, actual_val);
                        end
                    end
                end
            end
        end

        total_errors = total_errors + errors;
        if (errors == 0)
            $display("    PASS (%0d elements checked)", checked);
        else
            $display("    FAIL (%0d errors / %0d elements)", errors, checked);
    end
    endtask

    // =========================================================================
    // 主测试流程
    // =========================================================================
    initial begin
        $display("============================================================");
        $display("  tb_us_unit_fixed: Nearest Upsample x2");
        $display("============================================================");

        rst_n = 0;
        us_unit_start = 0;
        us_src_addr = 0;
        us_src_h = 0;
        us_src_w = 0;
        us_src_c = 0;
        us_dst_addr = 0;
        gb_doutb = '0;
        total_errors = 0;

        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // Case 1: C=128, H=10, W=10 → H=20, W=20
        run_test(10, 10, 128, "Case1");

        // Case 2: C=64, H=20, W=20 → H=40, W=40
        run_test(20, 20, 64, "Case2");

        // 报告
        $display("\n============================================================");
        if (total_errors == 0) begin
            $display("  ALL TESTS PASSED");
        end else begin
            $display("  TESTS FAILED (total errors: %0d)", total_errors);
        end
        $display("============================================================\n");
        $finish;
    end

    // =========================================================================
    // 辅助函数
    // =========================================================================
    function [FP_W-1:0] real_to_fp32;
        input real rval;
        shortreal sr;
        begin
            sr = shortreal'(rval);
            real_to_fp32 = $shortrealtobits(sr);
        end
    endfunction

    // 超时保护
    initial begin
        #(CLK_PERIOD * 500000);
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    // 波形
    initial begin
        $dumpfile("tb_us_unit_fixed.vcd");
        $dumpvars(0, tb_us_unit_fixed);
    end

endmodule
