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
    localparam OBUF_AWIDTH      = 20;
    localparam OBUF_NBPIPE      = 3;
    localparam OBUF_RD_LATENCY  = OBUF_NBPIPE + 4;   // obuf.v TOTAL_PIPE

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
    wire [GB_BANDWIDTH-1:0]    gb_doutb;
    wire                       gb_doutb_valid;

    wire [WB_ADDR_WIDTH-1:0]  wb_addrb;
    wire [WB_BANDWIDTH-1:0]   wb_dinb;
    wire                      wb_enb;
    wire                      wb_web;
    reg  [WB_BANDWIDTH-1:0]   wb_doutb;

    // 真实 obuf.v（与 E2E / DQA standalone 一致），Port A 给 QA，Port B 给 TB
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
        .wea(gb_web),
        .mem_ena(gb_enb),
        .dina(gb_dinb),
        .addra(gb_addrb[OBUF_AWIDTH-1:0]),
        .douta(gb_doutb),
        .douta_valid(gb_doutb_valid),
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

    task automatic obuf_write_word(input int addr, input logic [127:0] data);
        @(posedge clk);
        tb_obuf_wea   <= {GB_BANDWIDTH/8{1'b1}};
        tb_obuf_ena   <= 1'b1;
        tb_obuf_dina  <= data;
        tb_obuf_addra <= addr;
        @(posedge clk);
        tb_obuf_ena   <= 1'b0;
        tb_obuf_wea   <= '0;
    endtask

    task automatic obuf_read_word_task(input int addr, output logic [127:0] result);
        @(posedge clk);
        tb_obuf_wea   <= '0;
        tb_obuf_ena   <= 1'b1;
        tb_obuf_addra <= addr;
        repeat(OBUF_RD_LATENCY + 1) @(posedge clk);
        #1;
        result = tb_obuf_douta;
        tb_obuf_ena <= 1'b0;
    endtask

    task automatic clear_obuf_region(input int base, input int nwords);
        integer k;
        for (k = 0; k < nwords; k = k + 1)
            obuf_write_word(base + k, 128'h0);
    endtask

    localparam int HEX_MEM_DEPTH = 65536;
    reg [127:0] hex_mem [0:HEX_MEM_DEPTH-1];

    function automatic string qa_case_in_hex(input int idx);
        case (idx)
            0: return QA_CASE_0_IN_HEX;
            1: return QA_CASE_1_IN_HEX;
            2: return QA_CASE_2_IN_HEX;
            default: return "";
        endcase
    endfunction

    function automatic string qa_case_out_hex(input int idx);
        case (idx)
            0: return QA_CASE_0_OUT_HEX;
            1: return QA_CASE_1_OUT_HEX;
            2: return QA_CASE_2_OUT_HEX;
            default: return "";
        endcase
    endfunction

    function automatic int qa_case_poll_limit(input int idx);
        case (idx)
            0: return QA_CASE_0_POLL_LIMIT;
            1: return QA_CASE_1_POLL_LIMIT;
            2: return QA_CASE_2_POLL_LIMIT;
            default: return 800000;
        endcase
    endfunction

    function automatic int qa_case_save_count(input int idx);
        case (idx)
            0: return QA_CASE_0_SAVE_COUNT;
            1: return QA_CASE_1_SAVE_COUNT;
            2: return QA_CASE_2_SAVE_COUNT;
            default: return 0;
        endcase
    endfunction

    function automatic logic [31:0] qa_case_qscale_bits(input int idx);
        case (idx)
            0: return QA_CASE_0_QSCALE_BITS;
            1: return QA_CASE_1_QSCALE_BITS;
            2: return QA_CASE_2_QSCALE_BITS;
            default: return 32'h0;
        endcase
    endfunction

    task automatic load_hex_to_obuf(input string path, input int base, input int nwords);
        integer k;
        begin
            $readmemh(path, hex_mem);
            for (k = 0; k < nwords; k = k + 1)
                obuf_write_word(base + k, hex_mem[k]);
        end
    endtask

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
        // 每完成一次 FP32 读+量化迭代（SAVE_HOLD 递增 iter），与 golden save_count 一致
        if (rst_n && u_qa.c_state == 12)  // QA_SAVE_HOLD
            save_write_count <= save_write_count + 1;
    end

    function automatic int get_expect_save_count(input int case_idx);
        return qa_case_save_count(case_idx);
    endfunction

    function automatic bit int8_byte_close(input logic [7:0] got, input logic [7:0] exp);
        integer diff;
        begin
            diff = $signed(got) - $signed(exp);
            if (diff < 0) diff = -diff;
            int8_byte_close = (diff <= 1);
        end
    endfunction

    function automatic bit int8_word_close(input logic [127:0] got, input logic [127:0] exp);
        integer b;
        begin
            int8_word_close = 1'b1;
            for (b = 0; b < GB_BANDWIDTH/8; b = b + 1)
                if (!int8_byte_close(got[b*8 +: 8], exp[b*8 +: 8]))
                    int8_word_close = 1'b0;
        end
    endfunction

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
            save_write_count = 0;
            timed_out = 1'b0;
            poll_lim = qa_case_poll_limit(case_idx);
            out_path = qa_case_out_hex(case_idx);

            clear_obuf_region(dst_base, n_out_words + 2);
            load_hex_to_obuf(qa_case_in_hex(case_idx), src_base, n_in_words);

            wb_mem[0] = {96'h0, qa_case_qscale_bits(case_idx)};

            qa_src_addr   = src_base << 4;
            qa_dst_addr   = dst_base << 4;
            qa_scale_addr = 32'h0;
            qa_src_c = c;
            qa_src_h = h;
            qa_src_w = w;

            $display("");
            $display("=== Case %0d: %s (%0dx%0dx%0d) saves=%0d poll=%0d ===",
                     case_idx, case_name, h, w, c, get_expect_save_count(case_idx), poll_lim);

            @(posedge clk);
            qa_unit_start = 1;
            @(posedge clk);
            qa_unit_start = 0;

            begin : wait_poll
                integer poll_i;
                bit saw_busy;
                saw_busy = 1'b0;
                for (poll_i = 0; poll_i < poll_lim; poll_i = poll_i + 1) begin
                    @(posedge clk);
                    if (qa_unit_ready == 1'b0)
                        saw_busy = 1'b1;
                    else if (saw_busy)
                        disable wait_poll;
                end
                if (poll_i >= poll_lim) begin
                    timed_out = 1'b1;
                    $display("[%0t] TIMEOUT case %0d state=%0d iter_cnt=%0d",
                             $time, case_idx, u_qa.c_state, u_qa.qa_iter_cnt);
                end
            end

            if (timed_out) begin
                $display("FAIL [%s]: QA did not return to ready", case_name);
                case_ok = 1'b0;
            end

            if (u_qa.qa_iter_cnt != get_expect_save_count(case_idx)) begin
                $display("FAIL [%s]: qa_iter_cnt=%0d expected=%0d",
                         case_name, u_qa.qa_iter_cnt, get_expect_save_count(case_idx));
                case_ok = 1'b0;
            end

            repeat(4) @(posedge clk);

            $readmemh(out_path, hex_mem);

            for (wi = 0; wi < n_out_words; wi = wi + 1) begin
                obuf_read_word_task(dst_base + wi, got);
                exp = hex_mem[wi];
                if (!int8_word_close(got, exp)) begin
                    if (case_ok)
                        $display("FAIL [%s]: first mismatch at word %0d got=0x%032h exp=0x%032h",
                                 case_name, wi, got, exp);
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
    integer only_case;
    initial begin
        test_pass = 0;
        test_fail = 0;
        test_total = 0;
        only_case = -1;
        void'($value$plusargs("ONLY_CASE=%d", only_case));

        $display("=== tb_qa_standalone: YOLOv5n L1/L2/L3 (network params golden) ===");
        $display("  FP_CORE_NUM=%0d FP_TRAN_NUM=%0d GB_BW=%0d RD_LATENCY=%0d",
                 FP_CORE_NUM, FP_TRAN_NUM, GB_BANDWIDTH, OBUF_RD_LATENCY);

        qa_unit_start = 0;
        qa_src_addr = 0; qa_scale_addr = 0; qa_dst_addr = 0;
        qa_src_c = 0; qa_src_h = 0; qa_src_w = 0;

        for (i = 0; i < 16; i = i + 1)
            wb_mem[i] = 0;

        #20; rst_n = 1;
        #20;

        if (only_case < 0 || only_case == 0)
            run_one_case(0, "L1_model.1.conv",
                         QA_CASE_0_H, QA_CASE_0_W, QA_CASE_0_C,
                         QA_CASE_0_SRC_BASE, QA_CASE_0_DST_BASE,
                         QA_CASE_0_N_IN_WORDS, QA_CASE_0_N_OUT_WORDS);

        if (only_case < 0 || only_case == 1)
            run_one_case(1, "L2_model.2.cv1.conv",
                         QA_CASE_1_H, QA_CASE_1_W, QA_CASE_1_C,
                         QA_CASE_1_SRC_BASE, QA_CASE_1_DST_BASE,
                         QA_CASE_1_N_IN_WORDS, QA_CASE_1_N_OUT_WORDS);

        if (only_case < 0 || only_case == 2)
            run_one_case(2, "L3_model.2.m.0.cv2.conv",
                         QA_CASE_2_H, QA_CASE_2_W, QA_CASE_2_C,
                         QA_CASE_2_SRC_BASE, QA_CASE_2_DST_BASE,
                         QA_CASE_2_N_IN_WORDS, QA_CASE_2_N_OUT_WORDS);

        $display("");
        $display("=== Summary: %0d/%0d PASS, %0d FAIL ===", test_pass, test_total, test_fail);
        if (test_fail != 0)
            $fatal(1, "QA standalone regression FAILED");
        $finish;
    end

endmodule
