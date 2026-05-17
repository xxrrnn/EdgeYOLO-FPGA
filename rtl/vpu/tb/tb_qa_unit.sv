`timescale 1ns/1ps

// tb_qa_unit.sv - Testbench for qa_unit (Quantize Unit)
// Uses REAL Xilinx IP: fp32_mac (via fp_mac_array), fp32_2_int8_array
// No emulation, no force.
//
// QA pipeline: Load FP32 data → Multiply by scale → Convert to INT8 → Save
//
// Usage (Vivado):
//   vivado -mode batch -source scripts/vpu/run_qa_dqa_tests.tcl

module tb_qa_unit;

    parameter ADDR_WIDTH    = 32;
    parameter GB_BANDWIDTH  = 256;
    parameter GB_ADDR_WIDTH = 16;
    parameter WB_BANDWIDTH  = 256;
    parameter WB_ADDR_WIDTH = 512;
    parameter FP_CORE_NUM   = 8;
    parameter FP_TRAN_NUM   = 8;
    parameter FP_WIDTH      = 32;
    parameter Q_INT_WIDTH_OUT = 8;
    parameter MAX_CHANNEL_NUM = 1024;

    parameter CLK_PERIOD = 10;
    parameter LANES = GB_BANDWIDTH / FP_WIDTH;
    parameter BRAM_DEPTH = 4096;

    //==========================================================================
    // Signals
    //==========================================================================
    reg                         clk;
    reg                         rst_n;
    reg                         qa_unit_start;
    wire                        qa_unit_ready;

    reg  [ADDR_WIDTH-1:0]       qa_src_addr;
    reg  [ADDR_WIDTH-1:0]       qa_src_c;
    reg  [ADDR_WIDTH-1:0]       qa_src_h;
    reg  [ADDR_WIDTH-1:0]       qa_src_w;
    reg  [ADDR_WIDTH-1:0]       qa_scale_addr;
    reg  [ADDR_WIDTH-1:0]       qa_dst_addr;

    wire [GB_ADDR_WIDTH-1:0]    gb_addrb;
    wire [GB_BANDWIDTH-1:0]     gb_dinb;
    wire [GB_BANDWIDTH/8-1:0]   gb_web;
    wire                        gb_enb;
    wire [GB_BANDWIDTH-1:0]     gb_doutb;

    wire [WB_ADDR_WIDTH-1:0]    wb_addrb;
    wire [WB_BANDWIDTH-1:0]     wb_dinb;
    wire [WB_BANDWIDTH/8-1:0]   wb_web;
    wire                        wb_enb;
    wire [WB_BANDWIDTH-1:0]     wb_doutb;

    // FP MAC array interface (external to qa_unit)
    wire                        fp_array_tvalid;
    wire                        fp_array_tready;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] fp_a_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] fp_b_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] fp_c_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] fp_res;
    wire                        fp_res_tvalid;

    //==========================================================================
    // Clock
    //==========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    //==========================================================================
    // Global Buffer BRAM (real)
    //==========================================================================
    global_buffer_bram #(
        .NB_COL(GB_BANDWIDTH/8),
        .COL_WIDTH(8),
        .RAM_DEPTH(BRAM_DEPTH),
        .RAM_PERFORMANCE("LOW_LATENCY"),
        .INIT_FILE("")
    ) u_bram (
        .addra('0),
        .dina('0),
        .clka(clk),
        .wea('0),
        .ena(1'b0),
        .rsta(1'b0),
        .regcea(1'b0),
        .douta(),
        .addrb(gb_addrb),
        .dinb(gb_dinb),
        .web(gb_web),
        .enb(gb_enb),
        .rstb(~rst_n),
        .regceb(1'b0),
        .doutb(gb_doutb)
    );

    //==========================================================================
    // Weight BRAM (simple model for scale storage)
    //==========================================================================
    reg [WB_BANDWIDTH-1:0] wb_mem [0:1023];
    reg [WB_BANDWIDTH-1:0] wb_doutb_reg;
    assign wb_doutb = wb_doutb_reg;

    always @(posedge clk) begin
        if (wb_enb)
            wb_doutb_reg <= wb_mem[wb_addrb[9:0]];
    end

    //==========================================================================
    // Real FP MAC Array (a*b+c, used for multiply by scale)
    //==========================================================================
    fp_mac_array #(
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_WIDTH(FP_WIDTH)
    ) fp_mac_inst (
        .clk(clk),
        .fp_array_tvalid(fp_array_tvalid),
        .fp_array_tready(fp_array_tready),
        .a_tdata(fp_a_tdata),
        .b_tdata(fp_b_tdata),
        .c_tdata(fp_c_tdata),
        .res(fp_res),
        .res_tvalid(fp_res_tvalid)
    );

    //==========================================================================
    // DUT: qa_unit (uses real fp32_2_int8_array internally)
    //==========================================================================
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
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .qa_unit_start(qa_unit_start),
        .qa_unit_ready(qa_unit_ready),
        .qa_src_addr(qa_src_addr),
        .qa_src_c(qa_src_c),
        .qa_src_h(qa_src_h),
        .qa_src_w(qa_src_w),
        .qa_scale_addr(qa_scale_addr),
        .qa_dst_addr(qa_dst_addr),
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
        .wb_addrb(wb_addrb),
        .wb_dinb(wb_dinb),
        .wb_web(wb_web),
        .wb_enb(wb_enb),
        .wb_doutb(wb_doutb)
    );

    //==========================================================================
    // Monitoring
    //==========================================================================
    int mon_iter = 0;
    always @(posedge clk) begin
        if (gb_enb && gb_web == 0 && dut.c_state == dut.QA_LOAD_X)
            $display("  [QA RD] iter=%0d: addr=%0d (SRC)", mon_iter, gb_addrb);
        if (gb_enb && gb_web != 0 && dut.c_state == dut.QA_SAVE) begin
            $display("  [QA WR] iter=%0d: addr=%0d (DST), save_cnt=%0d",
                mon_iter, gb_addrb, dut.qa_save_cnt);
            mon_iter++;
        end
        if (dut.c_state == dut.IDLE && dut.qa_unit_start)
            mon_iter = 0;
    end

    //==========================================================================
    // Helper
    //==========================================================================
    function [FP_WIDTH-1:0] real_to_fp32;
        input real rval;
        begin
            real_to_fp32 = $shortrealtobits(shortreal'(rval));
        end
    endfunction

    //==========================================================================
    // Test Task
    //==========================================================================
    task automatic run_qa_test(
        input string test_name,
        input int num_c, num_h, num_w,
        input [ADDR_WIDTH-1:0] src_byte_addr,
        input [ADDR_WIDTH-1:0] scale_byte_addr,
        input [ADDR_WIDTH-1:0] dst_byte_addr,
        input real scale_value,
        output int test_errors
    );
        int num_elements, num_src_words, num_dst_int8_words;
        int src_word, dst_word;
        int cycle_count, timeout;

        num_elements = num_c * num_h * num_w;
        num_src_words = (num_elements * FP_WIDTH + GB_BANDWIDTH - 1) / GB_BANDWIDTH;
        num_dst_int8_words = (num_elements * Q_INT_WIDTH_OUT + GB_BANDWIDTH - 1) / GB_BANDWIDTH;
        src_word = src_byte_addr >> 5;
        dst_word = dst_byte_addr >> 5;
        test_errors = 0;

        $display("\n" + "="*70);
        $display("Test: %s", test_name);
        $display("  Config: C=%0d, H=%0d, W=%0d, scale=%.4f", num_c, num_h, num_w, scale_value);
        $display("  Elements: %0d FP32 (%0d words) -> %0d INT8 (%0d words)",
            num_elements, num_src_words, num_elements, num_dst_int8_words);
        $display("  Address: SRC=word %0d, DST=word %0d", src_word, dst_word);
        $display("="*70);

        // Init source FP32 data
        for (int w = 0; w < num_src_words; w++) begin
            for (int lane = 0; lane < LANES; lane++) begin
                int elem_idx = w * LANES + lane;
                if (elem_idx < num_elements)
                    u_bram.BRAM[src_word + w][lane*FP_WIDTH +: FP_WIDTH] = real_to_fp32((elem_idx + 1) * 1.0);
                else
                    u_bram.BRAM[src_word + w][lane*FP_WIDTH +: FP_WIDTH] = 32'h0;
            end
        end

        // Init scale in WB
        wb_mem[scale_byte_addr >> 5][31:0] = real_to_fp32(scale_value);

        // Clear DST
        for (int i = 0; i < num_dst_int8_words; i++)
            u_bram.BRAM[dst_word + i] = '0;

        // Configure
        qa_src_addr   = src_byte_addr;
        qa_scale_addr = scale_byte_addr;
        qa_dst_addr   = dst_byte_addr;
        qa_src_c      = num_c;
        qa_src_h      = num_h;
        qa_src_w      = num_w;

        wait(qa_unit_ready);
        @(posedge clk);

        $display("  Starting qa_unit...");
        qa_unit_start = 1'b1;
        @(posedge clk);
        qa_unit_start = 1'b0;

        wait(!qa_unit_ready);

        cycle_count = 0;
        timeout = 200000;
        while (!qa_unit_ready && cycle_count < timeout) begin
            @(posedge clk);
            cycle_count++;
        end

        if (cycle_count >= timeout) begin
            $display("  TIMEOUT after %0d cycles!", timeout);
            test_errors = num_elements;
        end else begin
            $display("  Done! Took %0d cycles", cycle_count);
            repeat(5) @(posedge clk);

            // Verify DST non-zero
            begin
                int nonzero = 0;
                for (int w = 0; w < num_dst_int8_words; w++)
                    if (u_bram.BRAM[dst_word + w] !== '0) nonzero++;
                if (nonzero == 0) begin
                    $display("  FAIL: All DST words are zero!");
                    test_errors = num_elements;
                end else begin
                    $display("  OK: %0d/%0d DST words written", nonzero, num_dst_int8_words);
                end
            end
        end
    endtask

    //==========================================================================
    // Main
    //==========================================================================
    integer total_tests = 0, total_errors = 0, test_errors;

    initial begin
        $display("\n======================================================================");
        $display("        qa_unit Testbench - Real IP, FP32 Mode");
        $display("======================================================================\n");

        rst_n = 0; qa_unit_start = 0;
        qa_src_addr = 0; qa_src_c = 0; qa_src_h = 0; qa_src_w = 0;
        qa_scale_addr = 0; qa_dst_addr = 0;
        for (int i = 0; i < 1024; i++) wb_mem[i] = '0;

        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        // Test 1: C=8, H=1, W=1
        run_qa_test("QA_Test1: C=8,H=1,W=1", .num_c(8), .num_h(1), .num_w(1),
            .src_byte_addr(32'h0000_0000), .scale_byte_addr(32'h0000_0000),
            .dst_byte_addr(32'h0000_0200), .scale_value(1.0),
            .test_errors(test_errors));
        total_tests++; total_errors += test_errors;
        repeat(20) @(posedge clk);

        // Test 2: C=16, H=1, W=1
        run_qa_test("QA_Test2: C=16,H=1,W=1", .num_c(16), .num_h(1), .num_w(1),
            .src_byte_addr(32'h0000_0400), .scale_byte_addr(32'h0000_0020),
            .dst_byte_addr(32'h0000_0600), .scale_value(0.5),
            .test_errors(test_errors));
        total_tests++; total_errors += test_errors;
        repeat(20) @(posedge clk);

        // Test 3: C=8, H=2, W=2
        run_qa_test("QA_Test3: C=8,H=2,W=2 (2D)", .num_c(8), .num_h(2), .num_w(2),
            .src_byte_addr(32'h0000_0800), .scale_byte_addr(32'h0000_0040),
            .dst_byte_addr(32'h0000_0C00), .scale_value(2.0),
            .test_errors(test_errors));
        total_tests++; total_errors += test_errors;
        repeat(20) @(posedge clk);

        // Test 4: C=16, H=4, W=4
        run_qa_test("QA_Test4: C=16,H=4,W=4 (3D)", .num_c(16), .num_h(4), .num_w(4),
            .src_byte_addr(32'h0000_1000), .scale_byte_addr(32'h0000_0060),
            .dst_byte_addr(32'h0000_3000), .scale_value(0.25),
            .test_errors(test_errors));
        total_tests++; total_errors += test_errors;

        $display("\n======================================================================");
        $display("                    qa_unit Test Summary");
        $display("======================================================================");
        $display("  Total tests: %0d, Errors: %0d", total_tests, total_errors);
        $display("  Status: %s", total_errors == 0 ? "*** ALL PASSED ***" : "*** FAILURES ***");
        $display("======================================================================\n");
        repeat(10) @(posedge clk);
        $finish;
    end

    initial begin
        #(CLK_PERIOD * 2000000);
        $display("ERROR: Global timeout!");
        $finish;
    end

endmodule
