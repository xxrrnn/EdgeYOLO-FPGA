`timescale 1ns/1ps
`include "chip_defines.vh"
`include "dqa_standalone_golden.svh"

// ==============================================================================
// tb_dqa_standalone - DQA unit standalone testbench (lite 参数版)
// ==============================================================================
//
// 目的：
//   验证 DQA unit 在 lite 配置下的数值正确性（GB=128, FP_CORE_NUM=4）
//
// 架构：
//   ┌─────────────┐
//   │  Testbench  │ ← 通过 obuf_write_word/obuf_read_word_sync 读写 OBUF
//   └──────┬──────┘
//          │ (Port A: gb_addrb/gb_dinb/gb_web/gb_enb/gb_doutb/gb_doutb_valid)
//   ┌──────▼──────────────────────────────────────────────────────────────┐
//   │  OBUF (真实 URAM 双端口，NBPIPE=3 → 7 拍读延迟 + douta_valid)      │
//   └──────▲──────────────────────────────────────────────────────────────┘
//          │
//   ┌──────┴──────┐
//   │  DQA unit   │ ← DUT
//   │  ├─ int32_2_fp32_array (内部实例化，Vivado IP)
//   │  ├─ fp_mac_array (外部实例化，a*b+c)
//   │  └─ WB BRAM (scale/bias，testbench 提供)
//   └─────────────┘
//
// 数据流：
//   1. Testbench 通过 obuf_write_word 写入 INT32 输入到 OBUF
//   2. Testbench 通过 WB BRAM 提供 per-channel scale/bias
//   3. DQA unit 启动：
//      a. 从 OBUF 读 INT32 (通过 gb_doutb + gb_doutb_valid)
//      b. int32_2_fp32 转换
//      c. fp_mac 计算 fp*scale + bias
//      d. 写回 FP32 到 OBUF
//   4. Testbench 通过 obuf_read_word_sync 读取 FP32 结果
//   5. 与 Python golden (tools/golden_dqa_standalone.py) 对比（FP32 容差 1e-5）
//
// Golden 生成：
//   Python: dqa_out[h,w,c] = int32[h,w,c] * scale[c] + bias[c]
//   输出 NHWC flatten → 128-bit words (4 FP32 per word, little-endian)
//
// 测试用例：
//   - t1_min_4ch: 1×1×4 (最小用例)
//   - t2_full_word_16ch: 1×1×16 (完整 128-bit word)
//   - t3_8ch_2px: 2×1×8 (多 pixel)
//   - t4_2x2x4: 2×2×4 (空间多 pixel)
//
// ==============================================================================

// Comprehensive DQA unit standalone testbench
// - Correct lite parameters (GB=128, FP_CORE_NUM=4, FP_TRAN_NUM=4)
// - Multi-case golden from tools/golden_dqa_standalone.py
// - Real OBUF with douta_valid (7-cycle read latency)
// - Full 128-bit word compare
module tb_dqa_standalone;

    localparam CLK_PERIOD       = 4.0;
    localparam ADDR_WIDTH       = 32;
    localparam GB_BANDWIDTH     = `GB_BANDWIDTH;
    localparam GB_ADDR_WIDTH    = `GB_ADDR_WIDTH;
    localparam WB_BANDWIDTH     = `WB_BANDWIDTH;
    localparam WB_ADDR_WIDTH    = `WB_ADDR_WIDTH;
    localparam FP_CORE_NUM      = `FP_CORE_NUM;
    localparam FP_TRAN_NUM      = `FP_TRAN_NUM;
    localparam FP_WIDTH         = `FP_WIDTH;
    localparam C_INT_WIDTH_IN   = 32;
    localparam MAX_CHANNEL_NUM  = `MAX_CHANNEL_NUM;
    localparam OBUF_AWIDTH      = 20;
    localparam OBUF_NBPIPE      = 3;

    reg clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    reg rst_n = 0;

    reg  dqa_unit_start;
    wire dqa_unit_ready;
    reg  [ADDR_WIDTH-1:0] dqa_src_addr, dqa_scale_addr, dqa_bias_addr, dqa_dst_addr;
    reg  [ADDR_WIDTH-1:0] dqa_src_c, dqa_src_h, dqa_src_w;

    wire                              fp_array_tvalid;
    wire                              fp_array_tready;
    wire [FP_CORE_NUM*FP_WIDTH-1:0]   fp_a_tdata, fp_b_tdata, fp_c_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0]   fp_res;
    wire                              fp_res_tvalid;

    wire [GB_ADDR_WIDTH-1:0]   gb_addrb;
    wire [GB_BANDWIDTH-1:0]    gb_dinb;
    wire [GB_BANDWIDTH/8-1:0]  gb_web;
    wire                       gb_enb;
    wire [GB_BANDWIDTH-1:0]    gb_doutb;
    wire                       gb_doutb_valid;

    wire [WB_ADDR_WIDTH-1:0]  wb_addrb;
    wire [WB_BANDWIDTH-1:0]   wb_dinb;
    wire                      wb_enb;
    wire                      wb_web;
    reg  [WB_BANDWIDTH-1:0]   wb_doutb;

    // Real OBUF with douta_valid
    // Port A: DQA unit 读写（gb_addrb/gb_dinb/gb_web/gb_enb → addra/dina/wea/mem_ena）
    // Port B: Testbench 初始化和验证（通过 tb_obuf_* 信号）
    reg                       tb_obuf_ena;
    reg  [GB_BANDWIDTH/8-1:0] tb_obuf_wea;
    reg  [OBUF_AWIDTH-1:0]    tb_obuf_addra;
    reg  [GB_BANDWIDTH-1:0]   tb_obuf_dina;
    wire [GB_BANDWIDTH-1:0]   tb_obuf_douta;
    wire                      tb_obuf_douta_valid;

    obuf #(
        .AWIDTH(OBUF_AWIDTH),
        .NUM_COL(GB_BANDWIDTH/8),
        .DWIDTH(GB_BANDWIDTH),
        .NBPIPE(OBUF_NBPIPE),
        .NUM_BANKS(2)
    ) u_obuf (
        .clk(clk),
        // Port A: DQA unit
        .wea(gb_web),
        .mem_ena(gb_enb),
        .dina(gb_dinb),
        .addra(gb_addrb[OBUF_AWIDTH-1:0]),
        .douta(gb_doutb),
        .douta_valid(gb_doutb_valid),
        // Port B: Testbench
        .web(tb_obuf_wea),
        .mem_enb(tb_obuf_ena),
        .dinb(tb_obuf_dina),
        .addrb(tb_obuf_addra),
        .doutb(tb_obuf_douta)
    );

    reg [WB_BANDWIDTH-1:0] wb_mem [0:15];
    always @(posedge clk) begin
        if (wb_enb)
            wb_doutb <= wb_mem[wb_addrb[3:0]];
    end

    dqa_relu_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BANDWIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .C_INT_WIDTH_IN(C_INT_WIDTH_IN),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_TRAN_NUM(FP_TRAN_NUM),
        .FP_WIDTH(FP_WIDTH),
        .WB_BANDWIDTH(WB_BANDWIDTH),
        .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
        .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM)
    ) u_dqa (
        .clk(clk),
        .rst_n(rst_n),
        .dqa_unit_start(dqa_unit_start),
        .dqa_unit_ready(dqa_unit_ready),
        .dqa_src_addr(dqa_src_addr),
        .dqa_scale_addr(dqa_scale_addr),
        .dqa_bias_addr(dqa_bias_addr),
        .dqa_dst_addr(dqa_dst_addr),
        .dqa_src_c(dqa_src_c),
        .dqa_src_h(dqa_src_h),
        .dqa_src_w(dqa_src_w),
        .fp_array_tvalid(fp_array_tvalid),
        .fp_array_tready(fp_array_tready),
        .fp_a_tdata(fp_a_tdata),
        .fp_b_tdata(fp_b_tdata),
        .fp_c_tdata(fp_c_tdata),
        .fp_res(fp_res),
        .fp_res_tvalid(fp_res_tvalid),
        .gb_addrb(gb_addrb),
        .gb_dinb(gb_dinb),
        .gb_web(gb_web),
        .gb_enb(gb_enb),
        .gb_doutb(gb_doutb),
        .gb_doutb_valid(gb_doutb_valid),
        .wb_addrb(wb_addrb),
        .wb_dinb(wb_dinb),
        .wb_enb(wb_enb),
        .wb_web(wb_web),
        .wb_doutb(wb_doutb)
    );

    fp_mac_array #(
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_WIDTH(FP_WIDTH)
    ) u_fp_mac (
        .clk(clk),
        .fp_array_tvalid(fp_array_tvalid),
        .fp_array_tready(fp_array_tready),
        .a_tdata(fp_a_tdata),
        .b_tdata(fp_b_tdata),
        .c_tdata(fp_c_tdata),
        .res(fp_res),
        .res_tvalid(fp_res_tvalid)
    );

    // FP32 lane comparison: Vivado FP IP 与 Python/numpy golden 偶尔会有 1 ULP rounding 差异。
    // 这里按 bit pattern 比较，允许同符号 FP32 相差 <= 2 ULP；X/Z 直接失败。
    function automatic bit fp32_lane_close(input logic [31:0] got, input logic [31:0] exp);
        logic [31:0] diff;
        begin
            if ((^got === 1'bx) || (^exp === 1'bx)) begin
                fp32_lane_close = 1'b0;
            end else if (got == exp) begin
                fp32_lane_close = 1'b1;
            end else if (got[31] != exp[31]) begin
                fp32_lane_close = 1'b0;
            end else begin
                diff = (got > exp) ? (got - exp) : (exp - got);
                fp32_lane_close = (diff <= 32'd2);
            end
        end
    endfunction

    task automatic compare_fp32_lane(
        input string case_name,
        input int word_idx,
        input int lane_idx,
        input logic [31:0] got_lane,
        input logic [31:0] exp_lane,
        inout bit case_ok
    );
        begin
            if (!fp32_lane_close(got_lane, exp_lane)) begin
                $display("FAIL [%s]: OUT word %0d lane %0d got=0x%08h exp=0x%08h",
                         case_name, word_idx, lane_idx, got_lane, exp_lane);
                case_ok = 1'b0;
            end
        end
    endtask

    integer test_pass, test_fail, test_total;
    reg     timed_out;

    // =========================================================================
    // OBUF 读写辅助任务（通过 Port B）
    // -------------------------------------------------------------------------
    // 说明：
    //   - obuf_write_word: 通过 Port B 写入一个 128-bit word（testbench 初始化）
    //   - obuf_read_word_task: 通过 Port B 读取一个 128-bit word（等待 7 拍延迟）
    //   - Port A 完全留给 DQA unit 使用
    //   - OBUF 读延迟 = NBPIPE+4 = 7 拍
    // =========================================================================
    task automatic obuf_write_word(input int addr, input logic [127:0] data);
        @(posedge clk);
        tb_obuf_wea <= 16'hFFFF;
        tb_obuf_ena <= 1'b1;
        tb_obuf_dina <= data;
        tb_obuf_addra <= addr;
        @(posedge clk);
        tb_obuf_ena <= 1'b0;
    endtask

    task automatic obuf_read_word_task(input int addr, output logic [127:0] result);
        @(posedge clk);
        // 发起读请求
        tb_obuf_wea <= 16'h0;
        tb_obuf_ena <= 1'b1;
        tb_obuf_addra <= addr;
        // Testbench 在 posedge 后用 NBA 发请求，OBUF 下一拍才采到；因此比 RTL 端到端延迟多等 1 拍。
        repeat(OBUF_NBPIPE + 5) @(posedge clk);
        // 在 posedge 后等待一个 delta，避开 OBUF 内部 doutb <= ... 的 NBA 更新竞态。
        #1;
        result = tb_obuf_douta;
        tb_obuf_ena <= 1'b0;
    endtask

    function automatic logic [127:0] get_expect_word(input int case_idx, input int wi);
        case (case_idx)
            0: return DQA_CASE_0_OUT[wi];
            1: return DQA_CASE_1_OUT[wi];
            2: return DQA_CASE_2_OUT[wi];
            3: return DQA_CASE_3_OUT[wi];
            default: return '0;
        endcase
    endfunction

    task automatic load_case_input(input int case_idx, input int src_base, input int n_in_words);
        integer k;
        case (case_idx)
            0: for (k = 0; k < n_in_words; k = k + 1) obuf_write_word(src_base + k, DQA_CASE_0_IN[k]);
            1: for (k = 0; k < n_in_words; k = k + 1) obuf_write_word(src_base + k, DQA_CASE_1_IN[k]);
            2: for (k = 0; k < n_in_words; k = k + 1) obuf_write_word(src_base + k, DQA_CASE_2_IN[k]);
            3: for (k = 0; k < n_in_words; k = k + 1) obuf_write_word(src_base + k, DQA_CASE_3_IN[k]);
            default: $fatal(1, "bad case idx %0d", case_idx);
        endcase
    endtask

    task automatic load_scale_bias(input int case_idx);
        integer k;
        case (case_idx)
            0: begin
                for (k = 0; k < 1; k = k + 1) wb_mem[0 + k] = DQA_CASE_0_SCALE[k];
                for (k = 0; k < 1; k = k + 1) wb_mem[4 + k] = DQA_CASE_0_BIAS[k];
            end
            1: begin
                for (k = 0; k < 4; k = k + 1) wb_mem[0 + k] = DQA_CASE_1_SCALE[k];
                for (k = 0; k < 4; k = k + 1) wb_mem[4 + k] = DQA_CASE_1_BIAS[k];
            end
            2: begin
                for (k = 0; k < 2; k = k + 1) wb_mem[0 + k] = DQA_CASE_2_SCALE[k];
                for (k = 0; k < 2; k = k + 1) wb_mem[4 + k] = DQA_CASE_2_BIAS[k];
            end
            3: begin
                for (k = 0; k < 1; k = k + 1) wb_mem[0 + k] = DQA_CASE_3_SCALE[k];
                for (k = 0; k < 1; k = k + 1) wb_mem[4 + k] = DQA_CASE_3_BIAS[k];
            end
            default: $fatal(1, "bad case idx %0d", case_idx);
        endcase
    endtask

    task automatic run_one_case(
        input int case_idx,
        input string case_name,
        input int h, input int w, input int c,
        input int src_base, input int dst_base,
        input int n_in_words, input int n_out_words
    );
        integer wi;
        logic [127:0] got, exp;
        bit case_ok;
        begin
            test_total = test_total + 1;
            case_ok = 1'b1;
            timed_out = 1'b0;

            load_case_input(case_idx, src_base, n_in_words);
            load_scale_bias(case_idx);

            dqa_src_addr   = src_base << 4;
            dqa_dst_addr   = dst_base << 4;
            dqa_scale_addr = 32'h0;
            dqa_bias_addr  = 32'h40;
            dqa_src_c = c;
            dqa_src_h = h;
            dqa_src_w = w;

            $display("");
            $display("=== Case %0d: %s (%0dx%0dx%0d) ===", case_idx, case_name, h, w, c);
            $display("  src_addr=0x%08h dst_addr=0x%08h scale_addr=0x%08h bias_addr=0x%08h",
                     dqa_src_addr, dqa_dst_addr, dqa_scale_addr, dqa_bias_addr);

            @(posedge clk);
            dqa_unit_start = 1;
            @(posedge clk);
            dqa_unit_start = 0;
            
            begin : wait_poll
                integer poll_i;
                bit saw_busy;
                saw_busy = 1'b0;
                for (poll_i = 0; poll_i < 200000; poll_i = poll_i + 1) begin
                    @(posedge clk);
                    if (dqa_unit_ready == 1'b0)
                        saw_busy = 1'b1;
                    else if (saw_busy)
                        disable wait_poll;
                end
                if (poll_i >= 200000) begin
                    timed_out = 1'b1;
                    $display("[%0t] TIMEOUT case %0d state=%0d", $time, case_idx, u_dqa.c_state);
                end
            end
            dqa_unit_start = 0;

            if (timed_out) begin
                $display("FAIL [%s]: DQA did not return to ready", case_name);
                case_ok = 1'b0;
            end

            // DQA 写 OBUF Port A 需要穿过 OBUF 顶层两级输入寄存器后才真正落到 bank。
            // ready 回到 1 后等待几拍，确保最后一个写请求已经提交到存储体。
            repeat(4) @(posedge clk);

            for (wi = 0; wi < n_out_words; wi = wi + 1) begin
                obuf_read_word_task(dst_base + wi, got);
                exp = get_expect_word(case_idx, wi);
                compare_fp32_lane(case_name, wi, 0, got[31:0],   exp[31:0],   case_ok);
                compare_fp32_lane(case_name, wi, 1, got[63:32],  exp[63:32],  case_ok);
                compare_fp32_lane(case_name, wi, 2, got[95:64],  exp[95:64],  case_ok);
                compare_fp32_lane(case_name, wi, 3, got[127:96], exp[127:96], case_ok);
            end

            if (case_ok) begin
                test_pass = test_pass + 1;
                $display("PASS [%s]", case_name);
            end else begin
                test_fail = test_fail + 1;
            end
        end
    endtask

    integer i;
    initial begin
        test_pass = 0;
        test_fail = 0;
        test_total = 0;

        $display("=== tb_dqa_standalone: multi-case DQA coverage ===");
        $display("  FP_CORE_NUM=%0d FP_TRAN_NUM=%0d GB_BW=%0d OBUF_NBPIPE=%0d",
                 FP_CORE_NUM, FP_TRAN_NUM, GB_BANDWIDTH, OBUF_NBPIPE);

        dqa_unit_start = 0;
        dqa_src_addr = 0; dqa_scale_addr = 0; dqa_bias_addr = 0; dqa_dst_addr = 0;
        dqa_src_c = 0; dqa_src_h = 0; dqa_src_w = 0;
        tb_obuf_ena = 0; tb_obuf_wea = 0; tb_obuf_addra = 0; tb_obuf_dina = 0;

        for (i = 0; i < 16; i = i + 1)
            wb_mem[i] = 0;

        #20; rst_n = 1;
        #20;

        run_one_case(0, "t1_min_4ch",
                     DQA_CASE_0_H, DQA_CASE_0_W, DQA_CASE_0_C,
                     DQA_CASE_0_SRC_BASE, DQA_CASE_0_DST_BASE,
                     DQA_CASE_0_N_IN_WORDS, DQA_CASE_0_N_OUT_WORDS);

        run_one_case(1, "t2_full_word_16ch",
                     DQA_CASE_1_H, DQA_CASE_1_W, DQA_CASE_1_C,
                     DQA_CASE_1_SRC_BASE, DQA_CASE_1_DST_BASE,
                     DQA_CASE_1_N_IN_WORDS, DQA_CASE_1_N_OUT_WORDS);

        run_one_case(2, "t3_8ch_2px",
                     DQA_CASE_2_H, DQA_CASE_2_W, DQA_CASE_2_C,
                     DQA_CASE_2_SRC_BASE, DQA_CASE_2_DST_BASE,
                     DQA_CASE_2_N_IN_WORDS, DQA_CASE_2_N_OUT_WORDS);

        run_one_case(3, "t4_2x2x4",
                     DQA_CASE_3_H, DQA_CASE_3_W, DQA_CASE_3_C,
                     DQA_CASE_3_SRC_BASE, DQA_CASE_3_DST_BASE,
                     DQA_CASE_3_N_IN_WORDS, DQA_CASE_3_N_OUT_WORDS);

        $display("");
        $display("=== Summary: %0d/%0d PASS, %0d FAIL ===", test_pass, test_total, test_fail);
        if (test_fail != 0)
            $fatal(1, "DQA standalone regression FAILED");
        $finish;
    end

endmodule
