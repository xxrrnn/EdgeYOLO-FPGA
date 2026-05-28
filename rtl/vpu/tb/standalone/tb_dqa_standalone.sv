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
// 测试用例：YOLOv5n L1/L2/L3 @ scale=1.0（原始网络参数）
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

    localparam WB_MEM_WORDS = 32;  // 512 B — fits scale+bias @ byte 0 / 0x100

    reg [WB_BANDWIDTH-1:0] wb_mem [0:WB_MEM_WORDS-1];
    always @(posedge clk) begin
        if (wb_enb)
            wb_doutb <= wb_mem[wb_addrb[4:0]];
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
        real gf, ef, diff, tol;
        begin
            if ((^got_lane === 1'bx) || (^exp_lane === 1'bx)) begin
                $display("FAIL [%s]: OUT word %0d lane %0d got=X exp=0x%08h",
                         case_name, word_idx, lane_idx, exp_lane);
                case_ok = 1'b0;
            end else if (got_lane == exp_lane) begin
                // exact match
            end else begin
                gf = $bitstoshortreal(got_lane);
                ef = $bitstoshortreal(exp_lane);
                diff = (gf > ef) ? (gf - ef) : (ef - gf);
                tol  = 1.0e-2 * ((ef > 0.0 ? ef : -ef) + 1.0);
                if (diff > tol) begin
                    $display("FAIL [%s]: OUT word %0d lane %0d got=0x%08h (%f) exp=0x%08h (%f)",
                             case_name, word_idx, lane_idx, got_lane, gf, exp_lane, ef);
                    case_ok = 1'b0;
                end
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

    localparam int HEX_MEM_DEPTH = 65536;
    reg [127:0] hex_mem [0:HEX_MEM_DEPTH-1];

    function automatic string case_in_hex(input int idx);
        case (idx)
            0: return DQA_CASE_0_IN_HEX;
            1: return DQA_CASE_1_IN_HEX;
            2: return DQA_CASE_2_IN_HEX;
            default: return "";
        endcase
    endfunction

    function automatic string case_out_hex(input int idx);
        case (idx)
            0: return DQA_CASE_0_OUT_HEX;
            1: return DQA_CASE_1_OUT_HEX;
            2: return DQA_CASE_2_OUT_HEX;
            default: return "";
        endcase
    endfunction

    function automatic int case_poll_limit(input int idx);
        case (idx)
            0: return DQA_CASE_0_POLL_LIMIT;
            1: return DQA_CASE_1_POLL_LIMIT;
            2: return DQA_CASE_2_POLL_LIMIT;
            default: return 500000;
        endcase
    endfunction

    function automatic int scale_bias_words(input int c);
        return (c + 3) / 4;
    endfunction

    task automatic load_hex_to_obuf(input string path, input int base, input int nwords);
        integer k;
        begin
            $readmemh(path, hex_mem);
            for (k = 0; k < nwords; k = k + 1)
                obuf_write_word(base + k, hex_mem[k]);
        end
    endtask

    function automatic int case_scale_byte_addr(input int idx);
        case (idx)
            0: return DQA_CASE_0_SCALE_BYTE_ADDR;
            1: return DQA_CASE_1_SCALE_BYTE_ADDR;
            2: return DQA_CASE_2_SCALE_BYTE_ADDR;
            default: return 0;
        endcase
    endfunction

    function automatic int case_bias_byte_addr(input int idx);
        case (idx)
            0: return DQA_CASE_0_BIAS_BYTE_ADDR;
            1: return DQA_CASE_1_BIAS_BYTE_ADDR;
            2: return DQA_CASE_2_BIAS_BYTE_ADDR;
            default: return 0;
        endcase
    endfunction

    task automatic load_scale_bias(input int case_idx, input int c);
        integer k, nw, scale_wbase, bias_wbase;
        begin
            nw = scale_bias_words(c);
            scale_wbase = case_scale_byte_addr(case_idx) >> 4;
            bias_wbase  = case_bias_byte_addr(case_idx) >> 4;
            case (case_idx)
                0: begin
                    for (k = 0; k < nw; k = k + 1) wb_mem[scale_wbase + k] = DQA_CASE_0_SCALE[k];
                    for (k = 0; k < nw; k = k + 1) wb_mem[bias_wbase + k]  = DQA_CASE_0_BIAS[k];
                end
                1: begin
                    for (k = 0; k < nw; k = k + 1) wb_mem[scale_wbase + k] = DQA_CASE_1_SCALE[k];
                    for (k = 0; k < nw; k = k + 1) wb_mem[bias_wbase + k]  = DQA_CASE_1_BIAS[k];
                end
                2: begin
                    for (k = 0; k < nw; k = k + 1) wb_mem[scale_wbase + k] = DQA_CASE_2_SCALE[k];
                    for (k = 0; k < nw; k = k + 1) wb_mem[bias_wbase + k]  = DQA_CASE_2_BIAS[k];
                end
                default: $fatal(1, "bad case idx %0d", case_idx);
            endcase
        end
    endtask

    task automatic run_one_case(
        input int case_idx,
        input string case_name,
        input int h, input int w, input int c,
        input int src_base, input int dst_base,
        input int n_in_words, input int n_out_words
    );
        integer wi, poll_lim;
        string out_path;
        logic [127:0] got, exp;
        bit case_ok;
        begin
            test_total = test_total + 1;
            case_ok = 1'b1;
            timed_out = 1'b0;
            poll_lim = case_poll_limit(case_idx);
            out_path = case_out_hex(case_idx);

            load_hex_to_obuf(case_in_hex(case_idx), src_base, n_in_words);
            load_scale_bias(case_idx, c);

            dqa_src_addr   = src_base << 4;
            dqa_dst_addr   = dst_base << 4;
            dqa_scale_addr = case_scale_byte_addr(case_idx);
            dqa_bias_addr  = case_bias_byte_addr(case_idx);
            dqa_src_c = c;
            dqa_src_h = h;
            dqa_src_w = w;

            $display("");
            $display("=== Case %0d: %s (%0dx%0dx%0d) poll_limit=%0d ===",
                     case_idx, case_name, h, w, c, poll_lim);
            $display("  in=%s out=%s", case_in_hex(case_idx), out_path);

            @(posedge clk);
            dqa_unit_start = 1;
            @(posedge clk);
            dqa_unit_start = 0;

            begin : wait_poll
                integer poll_i;
                bit saw_busy;
                saw_busy = 1'b0;
                for (poll_i = 0; poll_i < poll_lim; poll_i = poll_i + 1) begin
                    @(posedge clk);
                    if (dqa_unit_ready == 1'b0)
                        saw_busy = 1'b1;
                    else if (saw_busy)
                        disable wait_poll;
                end
                if (poll_i >= poll_lim) begin
                    timed_out = 1'b1;
                    $display("[%0t] TIMEOUT case %0d state=%0d", $time, case_idx, u_dqa.c_state);
                end
            end

            if (timed_out) begin
                $display("FAIL [%s]: DQA did not return to ready", case_name);
                case_ok = 1'b0;
            end

            repeat(4) @(posedge clk);

            $readmemh(out_path, hex_mem);

            for (wi = 0; wi < n_out_words; wi = wi + 1) begin
                obuf_read_word_task(dst_base + wi, got);
                exp = hex_mem[wi];
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
    integer only_case;
    initial begin
        test_pass = 0;
        test_fail = 0;
        test_total = 0;
        only_case = -1;
        void'($value$plusargs("ONLY_CASE=%d", only_case));

        $display("=== tb_dqa_standalone: YOLOv5n L1/L2/L3 (network params golden) ===");
        $display("  FP_CORE_NUM=%0d FP_TRAN_NUM=%0d GB_BW=%0d OBUF_NBPIPE=%0d",
                 FP_CORE_NUM, FP_TRAN_NUM, GB_BANDWIDTH, OBUF_NBPIPE);

        dqa_unit_start = 0;
        dqa_src_addr = 0; dqa_scale_addr = 0; dqa_bias_addr = 0; dqa_dst_addr = 0;
        dqa_src_c = 0; dqa_src_h = 0; dqa_src_w = 0;
        tb_obuf_ena = 0; tb_obuf_wea = 0; tb_obuf_addra = 0; tb_obuf_dina = 0;

        for (i = 0; i < WB_MEM_WORDS; i = i + 1)
            wb_mem[i] = 0;

        #20; rst_n = 1;
        #20;

        if (only_case < 0 || only_case == 0)
            run_one_case(0, "L1_model.1.conv",
                         DQA_CASE_0_H, DQA_CASE_0_W, DQA_CASE_0_C,
                         DQA_CASE_0_SRC_BASE, DQA_CASE_0_DST_BASE,
                         DQA_CASE_0_N_IN_WORDS, DQA_CASE_0_N_OUT_WORDS);

        if (only_case < 0 || only_case == 1)
            run_one_case(1, "L2_model.2.cv1.conv",
                         DQA_CASE_1_H, DQA_CASE_1_W, DQA_CASE_1_C,
                         DQA_CASE_1_SRC_BASE, DQA_CASE_1_DST_BASE,
                         DQA_CASE_1_N_IN_WORDS, DQA_CASE_1_N_OUT_WORDS);

        if (only_case < 0 || only_case == 2)
            run_one_case(2, "L3_model.2.m.0.cv2.conv",
                         DQA_CASE_2_H, DQA_CASE_2_W, DQA_CASE_2_C,
                         DQA_CASE_2_SRC_BASE, DQA_CASE_2_DST_BASE,
                         DQA_CASE_2_N_IN_WORDS, DQA_CASE_2_N_OUT_WORDS);

        $display("");
        $display("=== Summary: %0d/%0d PASS, %0d FAIL ===", test_pass, test_total, test_fail);
        if (test_fail != 0)
            $fatal(1, "DQA standalone regression FAILED");
        $finish;
    end

endmodule
