`timescale 1ns/1ps

// tb_dqa_unit.sv - Testbench for dqa_unit (Dequantize Unit)
// Uses REAL Xilinx IP: fp32_mac (via fp_mac_array), int32_2_fp32_array
// No emulation, no force.
//
// DQA pipeline: Load INT32 → Convert to FP32 → FMA (val*scale+bias) → Save FP32
//
// Usage (Vivado):
//   vivado -mode batch -source scripts/vpu/run_qa_dqa_tests.tcl

module tb_dqa_unit;

    parameter ADDR_WIDTH     = 32;
    parameter GB_BANDWIDTH   = 256;
    parameter GB_ADDR_WIDTH  = 16;
    parameter C_INT_WIDTH_IN = 32;
    parameter FP_CORE_NUM    = 8;
    parameter FP_TRAN_NUM    = 8;
    parameter FP_WIDTH       = 32;
    parameter WB_BANDWIDTH   = 256;
    parameter WB_ADDR_WIDTH  = 32;
    parameter MAX_CHANNEL_NUM = 64;

    parameter CLK_PERIOD = 10;
    parameter INT_LANES = GB_BANDWIDTH / C_INT_WIDTH_IN;
    parameter FP_LANES  = GB_BANDWIDTH / FP_WIDTH;
    parameter BRAM_DEPTH = 4096;

    //==========================================================================
    // Signals
    //==========================================================================
    reg                         clk;
    reg                         rst_n;
    reg                         dqa_unit_start;
    wire                        dqa_unit_ready;

    reg  [ADDR_WIDTH-1:0]       dqa_src_addr;
    reg  [ADDR_WIDTH-1:0]       dqa_src_c;
    reg  [ADDR_WIDTH-1:0]       dqa_src_h;
    reg  [ADDR_WIDTH-1:0]       dqa_src_w;
    reg  [ADDR_WIDTH-1:0]       dqa_scale_addr;
    reg  [ADDR_WIDTH-1:0]       dqa_bias_addr;
    reg  [ADDR_WIDTH-1:0]       dqa_dst_addr;

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

    // FP MAC array interface
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
    // Weight BRAM (for scale/bias)
    //==========================================================================
    reg [WB_BANDWIDTH-1:0] wb_mem [0:1023];
    reg [WB_BANDWIDTH-1:0] wb_doutb_reg;
    assign wb_doutb = wb_doutb_reg;

    always @(posedge clk) begin
        if (wb_enb)
            wb_doutb_reg <= wb_mem[wb_addrb[9:0]];
    end

    //==========================================================================
    // Real FP MAC Array (a*b+c)
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
    // DUT: dqa_unit (uses real int32_2_fp32_array internally)
    //==========================================================================
    dqa_unit #(
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
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .dqa_unit_start(dqa_unit_start),
        .dqa_unit_ready(dqa_unit_ready),
        .dqa_src_addr(dqa_src_addr),
        .dqa_src_c(dqa_src_c),
        .dqa_src_h(dqa_src_h),
        .dqa_src_w(dqa_src_w),
        .dqa_scale_addr(dqa_scale_addr),
        .dqa_bias_addr(dqa_bias_addr),
        .dqa_dst_addr(dqa_dst_addr),
        .fp_array_tready(fp_array_tready),
        .fp_array_tvalid(fp_array_tvalid),
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
    // Helper
    //==========================================================================
    function [FP_WIDTH-1:0] real_to_fp32;
        input real rval;
        begin
            real_to_fp32 = $shortrealtobits(shortreal'(rval));
        end
    endfunction

    function real fp32_to_real;
        input [FP_WIDTH-1:0] bits;
        begin
            fp32_to_real = $bitstoshortreal(bits);
        end
    endfunction

    //==========================================================================
    // Monitoring
    //==========================================================================
    int mon_iter = 0;
    always @(posedge clk) begin
        if (gb_enb && gb_web == 0 && dut.c_state == dut.DQA_LOAD_X)
            $display("  [DQA RD] iter=%0d: addr=%0d (SRC)", mon_iter, gb_addrb);
        if (gb_enb && gb_web != 0 && dut.c_state == dut.DQA_SAVE) begin
            $display("  [DQA WR] iter=%0d: addr=%0d (DST), save_cnt=%0d",
                mon_iter, gb_addrb, dut.dqa_save_cnt);
            mon_iter++;
        end
        if (dut.c_state == dut.IDLE && dut.dqa_unit_start)
            mon_iter = 0;
    end

    //==========================================================================
    // Test Task
    //==========================================================================
    task automatic run_dqa_test(
        input string test_name,
        input int num_c, num_h, num_w,
        input [ADDR_WIDTH-1:0] src_byte_addr,
        input [ADDR_WIDTH-1:0] scale_byte_addr,
        input [ADDR_WIDTH-1:0] bias_byte_addr,
        input [ADDR_WIDTH-1:0] dst_byte_addr,
        input real scale_val, bias_val,
        output int test_errors
    );
        int num_elements, num_src_words, num_dst_words;
        int src_word, dst_word;
        int cycle_count, timeout;

        num_elements = num_c * num_h * num_w;
        num_src_words = (num_elements * C_INT_WIDTH_IN + GB_BANDWIDTH - 1) / GB_BANDWIDTH;
        num_dst_words = (num_elements * FP_WIDTH + GB_BANDWIDTH - 1) / GB_BANDWIDTH;
        src_word = src_byte_addr >> 5;
        dst_word = dst_byte_addr >> 5;
        test_errors = 0;

        $display("\n" + "="*70);
        $display("Test: %s", test_name);
        $display("  Config: C=%0d, H=%0d, W=%0d, scale=%.4f, bias=%.4f",
            num_c, num_h, num_w, scale_val, bias_val);
        $display("  Elements: %0d INT32 (%0d words) -> %0d FP32 (%0d words)",
            num_elements, num_src_words, num_elements, num_dst_words);
        $display("  Address: SRC=word %0d, DST=word %0d", src_word, dst_word);
        $display("="*70);

        // Init INT32 source data
        for (int w = 0; w < num_src_words; w++) begin
            for (int lane = 0; lane < INT_LANES; lane++) begin
                int elem_idx = w * INT_LANES + lane;
                if (elem_idx < num_elements)
                    u_bram.BRAM[src_word + w][lane*C_INT_WIDTH_IN +: C_INT_WIDTH_IN] = elem_idx + 1;
                else
                    u_bram.BRAM[src_word + w][lane*C_INT_WIDTH_IN +: C_INT_WIDTH_IN] = 0;
            end
        end

        // Init scale/bias (per-channel, stored in WB)
        for (int ch = 0; ch < num_c; ch++) begin
            int word_idx = (ch * FP_WIDTH) / WB_BANDWIDTH;
            int bit_offset = (ch * FP_WIDTH) % WB_BANDWIDTH;
            wb_mem[(scale_byte_addr >> 5) + word_idx][bit_offset +: FP_WIDTH] = real_to_fp32(scale_val);
            wb_mem[(bias_byte_addr >> 5) + word_idx][bit_offset +: FP_WIDTH] = real_to_fp32(bias_val);
        end

        // Clear DST
        for (int i = 0; i < num_dst_words; i++)
            u_bram.BRAM[dst_word + i] = '0;

        // Configure
        dqa_src_addr   = src_byte_addr;
        dqa_scale_addr = scale_byte_addr;
        dqa_bias_addr  = bias_byte_addr;
        dqa_dst_addr   = dst_byte_addr;
        dqa_src_c      = num_c;
        dqa_src_h      = num_h;
        dqa_src_w      = num_w;

        wait(dqa_unit_ready);
        @(posedge clk);

        $display("  Starting dqa_unit...");
        dqa_unit_start = 1'b1;
        @(posedge clk);
        dqa_unit_start = 1'b0;

        wait(!dqa_unit_ready);

        cycle_count = 0;
        timeout = 500000;
        while (!dqa_unit_ready && cycle_count < timeout) begin
            @(posedge clk);
            cycle_count++;
        end

        if (cycle_count >= timeout) begin
            $display("  TIMEOUT after %0d cycles!", timeout);
            test_errors = num_elements;
        end else begin
            $display("  Done! Took %0d cycles", cycle_count);
            repeat(5) @(posedge clk);

            // Verify: expected = int_val * scale + bias
            begin
                int error_count = 0;
                for (int w = 0; w < num_dst_words; w++) begin
                    for (int lane = 0; lane < FP_LANES; lane++) begin
                        int elem_idx = w * FP_LANES + lane;
                        if (elem_idx < num_elements) begin
                            automatic reg [FP_WIDTH-1:0] actual_bits;
                            automatic real actual_val, expected_val, diff;
                            actual_bits = u_bram.BRAM[dst_word + w][lane*FP_WIDTH +: FP_WIDTH];
                            actual_val = fp32_to_real(actual_bits);
                            expected_val = (elem_idx + 1) * scale_val + bias_val;
                            diff = actual_val - expected_val;
                            if (diff < 0) diff = -diff;
                            if (diff > 0.01 * (expected_val > 0 ? expected_val : -expected_val) + 0.5) begin
                                error_count++;
                                if (error_count <= 5)
                                    $display("    X [%0d] exp=%.2f, act=%.2f", elem_idx, expected_val, actual_val);
                            end else if (elem_idx < 8) begin
                                $display("    V [%0d] val=%.2f (exp=%.2f)", elem_idx, actual_val, expected_val);
                            end
                        end
                    end
                end
                if (error_count == 0) begin
                    $display("  OK: All %0d elements verified!", num_elements);
                end else begin
                    $display("  FAIL: %0d/%0d elements incorrect!", error_count, num_elements);
                    test_errors = error_count;
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
        $display("       dqa_unit Testbench - Real IP, FP32 Mode");
        $display("======================================================================\n");

        rst_n = 0; dqa_unit_start = 0;
        dqa_src_addr = 0; dqa_src_c = 0; dqa_src_h = 0; dqa_src_w = 0;
        dqa_scale_addr = 0; dqa_bias_addr = 0; dqa_dst_addr = 0;
        for (int i = 0; i < 1024; i++) wb_mem[i] = '0;

        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        // Test 1: C=8, H=1, W=1
        run_dqa_test("DQA_Test1: C=8,H=1,W=1", .num_c(8), .num_h(1), .num_w(1),
            .src_byte_addr(32'h0000_0000), .scale_byte_addr(32'h0000_0000),
            .bias_byte_addr(32'h0000_0100), .dst_byte_addr(32'h0000_0400),
            .scale_val(2.0), .bias_val(1.0), .test_errors(test_errors));
        total_tests++; total_errors += test_errors;
        repeat(30) @(posedge clk);

        // Test 2: C=8, H=1, W=2
        run_dqa_test("DQA_Test2: C=8,H=1,W=2", .num_c(8), .num_h(1), .num_w(2),
            .src_byte_addr(32'h0000_0800), .scale_byte_addr(32'h0000_0200),
            .bias_byte_addr(32'h0000_0300), .dst_byte_addr(32'h0000_0C00),
            .scale_val(0.5), .bias_val(10.0), .test_errors(test_errors));
        total_tests++; total_errors += test_errors;
        repeat(30) @(posedge clk);

        // Test 3: C=8, H=2, W=2
        run_dqa_test("DQA_Test3: C=8,H=2,W=2 (2D)", .num_c(8), .num_h(2), .num_w(2),
            .src_byte_addr(32'h0000_1000), .scale_byte_addr(32'h0000_0400),
            .bias_byte_addr(32'h0000_0500), .dst_byte_addr(32'h0000_1800),
            .scale_val(1.5), .bias_val(-2.0), .test_errors(test_errors));
        total_tests++; total_errors += test_errors;
        repeat(30) @(posedge clk);

        // Test 4: C=8, H=4, W=4
        run_dqa_test("DQA_Test4: C=8,H=4,W=4 (3D)", .num_c(8), .num_h(4), .num_w(4),
            .src_byte_addr(32'h0000_2000), .scale_byte_addr(32'h0000_0600),
            .bias_byte_addr(32'h0000_0700), .dst_byte_addr(32'h0000_3000),
            .scale_val(0.1), .bias_val(5.0), .test_errors(test_errors));
        total_tests++; total_errors += test_errors;

        $display("\n======================================================================");
        $display("                   dqa_unit Test Summary");
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
