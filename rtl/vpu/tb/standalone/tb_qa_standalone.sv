`timescale 1ns/1ps
`include "chip_defines.vh"
`include "qa_standalone_golden.svh"

// Comprehensive QA unit standalone testbench
// - Correct lite parameters (GB=128, FP_CORE_NUM=4, FP_TRAN_NUM=4)
// - Multi-case golden from tools/golden_qa_standalone.py
// - Completion check (ready=1, no TIMEOUT)
// - Full 128-bit word compare + duplicate-slot detection
module tb_qa_standalone;

    localparam CLK_PERIOD     = 4.0;
    localparam ADDR_WIDTH       = 32;
    localparam GB_BANDWIDTH     = `GB_BANDWIDTH;
    localparam GB_ADDR_WIDTH    = `GB_ADDR_WIDTH;
    localparam WB_BANDWIDTH     = `WB_BANDWIDTH;
    localparam WB_ADDR_WIDTH    = `WB_ADDR_WIDTH;
    localparam FP_CORE_NUM      = `FP_CORE_NUM;
    localparam FP_TRAN_NUM      = `FP_TRAN_NUM;
    localparam FP_WIDTH         = `FP_WIDTH;
    localparam Q_INT_WIDTH_OUT  = `Q_INT_WIDTH_OUT;
    localparam MAX_CHANNEL_NUM  = `MAX_CHANNEL_NUM;
    localparam OBUF_RD_LATENCY  = 7;   // 1=fast mock; 7≈obuf.v TOTAL_PIPE

    reg clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    reg rst_n = 0;

    reg  qa_unit_start;
    wire qa_unit_ready;
    reg  [ADDR_WIDTH-1:0] qa_src_addr, qa_scale_addr, qa_dst_addr;
    reg  [ADDR_WIDTH-1:0] qa_src_c, qa_src_h, qa_src_w;

    wire                              fp_array_tvalid;
    wire                              fp_array_tready;
    wire [FP_CORE_NUM*FP_WIDTH-1:0]   fp_a_tdata, fp_b_tdata, fp_c_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0]   fp_res;
    wire                              fp_res_tvalid;

    wire [GB_ADDR_WIDTH-1:0]   gb_addrb;
    wire [GB_BANDWIDTH-1:0]    gb_dinb;
    wire [GB_BANDWIDTH/8-1:0]  gb_web;
    wire                       gb_enb;
    reg  [GB_BANDWIDTH-1:0]    gb_doutb;
    reg                        gb_doutb_valid;

    wire [WB_ADDR_WIDTH-1:0]  wb_addrb;
    wire [WB_BANDWIDTH-1:0]   wb_dinb;
    wire                      wb_enb;
    wire                      wb_web;
    reg  [WB_BANDWIDTH-1:0]   wb_doutb;

    // OBUF mock with configurable read latency + byte-write
    reg [127:0] obuf_mem [0:511];
    reg [127:0] obuf_rd_pipe [0:7];
    reg [7:0]   obuf_rd_valid_pipe;
    integer bi, pi;

    always @(posedge clk) begin
        obuf_rd_valid_pipe <= obuf_rd_valid_pipe << 1;
        obuf_rd_valid_pipe[0] <= 1'b0;

        if (gb_enb) begin
            if (|gb_web) begin
                for (bi = 0; bi < GB_BANDWIDTH/8; bi = bi + 1) begin
                    if (gb_web[bi])
                        obuf_mem[gb_addrb[8:0]][bi*8 +: 8] <= gb_dinb[bi*8 +: 8];
                end
            end else begin
                obuf_rd_pipe[0] <= obuf_mem[gb_addrb[8:0]];
                obuf_rd_valid_pipe[0] <= 1'b1;
            end
        end

        for (pi = 1; pi <= OBUF_RD_LATENCY; pi = pi + 1) begin
            obuf_rd_pipe[pi] <= obuf_rd_pipe[pi-1];
        end
    end

    always @(posedge clk) begin
        if (OBUF_RD_LATENCY == 0) begin
            gb_doutb       <= obuf_rd_pipe[0];
            gb_doutb_valid <= obuf_rd_valid_pipe[0];
        end else begin
            gb_doutb       <= obuf_rd_pipe[OBUF_RD_LATENCY];
            gb_doutb_valid <= obuf_rd_valid_pipe[OBUF_RD_LATENCY];
        end
    end

    reg [WB_BANDWIDTH-1:0] wb_mem [0:15];
    always @(posedge clk) begin
        if (wb_enb)
            wb_doutb <= wb_mem[wb_addrb[3:0]];
    end

    qa_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BANDWIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .WB_BANDWIDTH(WB_BANDWIDTH),
        .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_TRAN_NUM(FP_TRAN_NUM),
        .FP_WIDTH(FP_WIDTH),
        .Q_INT_WIDTH_OUT(Q_INT_WIDTH_OUT),
        .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM)
    ) u_qa (
        .clk(clk),
        .rst_n(rst_n),
        .qa_unit_start(qa_unit_start),
        .qa_unit_ready(qa_unit_ready),
        .qa_src_addr(qa_src_addr),
        .qa_scale_addr(qa_scale_addr),
        .qa_dst_addr(qa_dst_addr),
        .qa_src_c(qa_src_c),
        .qa_src_h(qa_src_h),
        .qa_src_w(qa_src_w),
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

    integer test_pass, test_fail, test_total;
    integer save_write_count;
    reg     timed_out;

    always @(posedge clk) begin
        if (rst_n && gb_enb && (|gb_web))
            save_write_count <= save_write_count + 1;
    end

    task automatic clear_obuf_region(input int base, input int nwords);
        integer k;
        for (k = 0; k < nwords; k = k + 1)
            obuf_mem[base + k] = 128'h0;
    endtask

    task automatic load_case_input(
        input int case_idx,
        input int src_base,
        input int n_in_words
    );
        integer k;
        case (case_idx)
            0: for (k = 0; k < n_in_words; k = k + 1) obuf_mem[src_base + k] = QA_CASE_0_IN[k];
            1: for (k = 0; k < n_in_words; k = k + 1) obuf_mem[src_base + k] = QA_CASE_1_IN[k];
            2: for (k = 0; k < n_in_words; k = k + 1) obuf_mem[src_base + k] = QA_CASE_2_IN[k];
            3: for (k = 0; k < n_in_words; k = k + 1) obuf_mem[src_base + k] = QA_CASE_3_IN[k];
            4: for (k = 0; k < n_in_words; k = k + 1) obuf_mem[src_base + k] = QA_CASE_4_IN[k];
            default: $fatal(1, "bad case idx %0d", case_idx);
        endcase
    endtask

    function automatic logic [127:0] get_expect_word(input int case_idx, input int wi);
        case (case_idx)
            0: return QA_CASE_0_OUT[wi];
            1: return QA_CASE_1_OUT[wi];
            2: return QA_CASE_2_OUT[wi];
            3: return QA_CASE_3_OUT[wi];
            4: return QA_CASE_4_OUT[wi];
            default: return '0;
        endcase
    endfunction

    function automatic int get_expect_save_count(input int case_idx);
        case (case_idx)
            0: return QA_CASE_0_SAVE_COUNT;
            1: return QA_CASE_1_SAVE_COUNT;
            2: return QA_CASE_2_SAVE_COUNT;
            3: return QA_CASE_3_SAVE_COUNT;
            4: return QA_CASE_4_SAVE_COUNT;
            default: return 0;
        endcase
    endfunction

    function automatic bit get_check_upper_zero(input int case_idx);
        case (case_idx)
            0: return QA_CASE_0_CHECK_UPPER_ZERO;
            1: return QA_CASE_1_CHECK_UPPER_ZERO;
            2: return QA_CASE_2_CHECK_UPPER_ZERO;
            3: return QA_CASE_3_CHECK_UPPER_ZERO;
            4: return QA_CASE_4_CHECK_UPPER_ZERO;
            default: return 0;
        endcase
    endfunction

    task automatic run_one_case(
        input int case_idx,
        input string case_name,
        input int h, input int w, input int c,
        input int src_base, input int dst_base,
        input int n_in_words, input int n_out_words,
        input logic [31:0] qscale_bits
    );
        integer wi;
        logic [127:0] got, exp;
        bit case_ok;
        begin
            test_total = test_total + 1;
            case_ok = 1'b1;
            save_write_count = 0;
            timed_out = 1'b0;

            clear_obuf_region(dst_base, n_out_words + 2);
            load_case_input(case_idx, src_base, n_in_words);

            wb_mem[0] = {96'h0, qscale_bits};

            qa_src_addr   = src_base << 4;
            qa_dst_addr   = dst_base << 4;
            qa_scale_addr = 32'h0;
            qa_src_c = c;
            qa_src_h = h;
            qa_src_w = w;

            $display("");
            $display("=== Case %0d: %s (%0dx%0dx%0d) saves=%0d ===",
                     case_idx, case_name, h, w, c, get_expect_save_count(case_idx));

            @(posedge clk);
            qa_unit_start = 1;
            @(posedge clk);
            qa_unit_start = 0;

            begin : wait_poll
                integer poll_i;
                bit saw_busy;
                saw_busy = 1'b0;
                for (poll_i = 0; poll_i < 200000; poll_i = poll_i + 1) begin
                    @(posedge clk);
                    if (qa_unit_ready == 1'b0)
                        saw_busy = 1'b1;
                    else if (saw_busy)
                        disable wait_poll;
                end
                if (poll_i >= 200000) begin
                    timed_out = 1'b1;
                    $display("[%0t] TIMEOUT case %0d state=%0d save_cnt=%0d total_blocks=%0d threshold=%0d",
                             $time, case_idx, u_qa.c_state, u_qa.qa_save_cnt,
                             u_qa.qa_x_total_blocks_reg, u_qa.qa_x_load_done_threshold);
                end
            end

            if (timed_out) begin
                $display("FAIL [%s]: QA did not return to ready", case_name);
                case_ok = 1'b0;
            end

            // SAVE 写次数必须等于 ceil(N/(FP_CORE_NUM))，防止旧 bug 的重复写同一 slot
            if (save_write_count != get_expect_save_count(case_idx)) begin
                $display("FAIL [%s]: save_writes=%0d expected=%0d (duplicate SAVE loop?)",
                         case_name, save_write_count, get_expect_save_count(case_idx));
                case_ok = 1'b0;
            end

            for (wi = 0; wi < n_out_words; wi = wi + 1) begin
                got = obuf_mem[dst_base + wi];
                exp = get_expect_word(case_idx, wi);
                if (got !== exp) begin
                    $display("FAIL [%s]: OUT word %0d got=0x%032h exp=0x%032h",
                             case_name, wi, got, exp);
                    case_ok = 1'b0;
                end
            end

            if (get_check_upper_zero(case_idx) && n_out_words >= 1) begin
                if (obuf_mem[dst_base][127:32] !== 96'h0) begin
                    $display("FAIL [%s]: upper 96 bits should be zero (no duplicate slot fill) got=0x%024h",
                             case_name, obuf_mem[dst_base][127:32]);
                    case_ok = 1'b0;
                end
            end

            // t2: slots must differ — check 4 SAVE slots in one word are not identical
            if (case_idx == 1 && n_out_words >= 1) begin
                if (obuf_mem[dst_base][31:0]   == obuf_mem[dst_base][63:32] &&
                    obuf_mem[dst_base][31:0]   == obuf_mem[dst_base][95:64] &&
                    obuf_mem[dst_base][31:0]   == obuf_mem[dst_base][127:96]) begin
                    $display("FAIL [%s]: all 4 slots identical — false-pass pattern", case_name);
                    case_ok = 1'b0;
                end
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

        $display("=== tb_qa_standalone: multi-case QA coverage ===");
        $display("  FP_CORE_NUM=%0d FP_TRAN_NUM=%0d GB_BW=%0d RD_LATENCY=%0d",
                 FP_CORE_NUM, FP_TRAN_NUM, GB_BANDWIDTH, OBUF_RD_LATENCY);

        qa_unit_start = 0;
        qa_src_addr = 0; qa_scale_addr = 0; qa_dst_addr = 0;
        qa_src_c = 0; qa_src_h = 0; qa_src_w = 0;

        for (i = 0; i < 512; i = i + 1)
            obuf_mem[i] = 0;
        for (i = 0; i < 16; i = i + 1)
            wb_mem[i] = 0;

        #20; rst_n = 1;
        #20;

        run_one_case(0, "t1_min_4ch",
                     QA_CASE_0_H, QA_CASE_0_W, QA_CASE_0_C,
                     QA_CASE_0_SRC_BASE, QA_CASE_0_DST_BASE,
                     QA_CASE_0_N_IN_WORDS, QA_CASE_0_N_OUT_WORDS,
                     QA_CASE_0_QSCALE_BITS);

        run_one_case(1, "t2_full_word_16ch",
                     QA_CASE_1_H, QA_CASE_1_W, QA_CASE_1_C,
                     QA_CASE_1_SRC_BASE, QA_CASE_1_DST_BASE,
                     QA_CASE_1_N_IN_WORDS, QA_CASE_1_N_OUT_WORDS,
                     QA_CASE_1_QSCALE_BITS);

        run_one_case(2, "t3_8ch_2px",
                     QA_CASE_2_H, QA_CASE_2_W, QA_CASE_2_C,
                     QA_CASE_2_SRC_BASE, QA_CASE_2_DST_BASE,
                     QA_CASE_2_N_IN_WORDS, QA_CASE_2_N_OUT_WORDS,
                     QA_CASE_2_QSCALE_BITS);

        run_one_case(3, "t4_32ch_2words",
                     QA_CASE_3_H, QA_CASE_3_W, QA_CASE_3_C,
                     QA_CASE_3_SRC_BASE, QA_CASE_3_DST_BASE,
                     QA_CASE_3_N_IN_WORDS, QA_CASE_3_N_OUT_WORDS,
                     QA_CASE_3_QSCALE_BITS);

        run_one_case(4, "t5_2x2x4",
                     QA_CASE_4_H, QA_CASE_4_W, QA_CASE_4_C,
                     QA_CASE_4_SRC_BASE, QA_CASE_4_DST_BASE,
                     QA_CASE_4_N_IN_WORDS, QA_CASE_4_N_OUT_WORDS,
                     QA_CASE_4_QSCALE_BITS);

        $display("");
        $display("=== Summary: %0d/%0d PASS, %0d FAIL ===", test_pass, test_total, test_fail);
        if (test_fail != 0)
            $fatal(1, "QA standalone regression FAILED");
        $finish;
    end

endmodule
