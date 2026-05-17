`timescale 1ns / 1ps
//==============================================================================
// tb_ad_unit.sv - ad_unit (ADD 单元) 测试平台
//==============================================================================
// 
// 使用方法 (Vivado):
// ------------------
// 方法 1: 在 Vivado 工程中运行
//   1. 打开 VPU Vivado 工程
//   2. 确保已生成 fp32_add IP (运行 scripts/ip/floating_point_fp32.tcl)
//   3. 添加 testbench 到仿真源:
//      add_files -fileset sim_1 rtl/vpu/tb/tb_ad_unit.sv
//   4. 设置顶层仿真模块:
//      set_property top tb_ad_unit [get_filesets sim_1]
//   5. 运行仿真:
//      launch_simulation
//
// 方法 2: 使用 TCL 脚本
//   cd scripts/vpu
//   vivado -mode batch -source tb_ad_unit_run.tcl
//
// 测试内容:
// ---------
// 1. 最小测试: 8 个 FP32 元素的加法 (1 个 BRAM word)
// 2. 中等测试: 64 个 FP32 元素的加法 (8 个 BRAM words)
// 3. 多维测试: 8x8x8 = 512 个 FP32 元素
// 4. 验证: 逐元素比较 golden model 与 RTL 输出 (bit-exact)
//
// 依赖:
// -----
// - rtl/vpu/ad_unit.sv
// - rtl/vpu/fp array/fp_add_array.sv
// - rtl/vpu/global_buffer_bram.v
// - Xilinx IP: fp32_add (通过 scripts/ip/floating_point_fp32.tcl 生成)
//
// 注意事项:
// ---------
// - BRAM 使用 LOW_LATENCY 模式，读延迟 1 周期
// - fp32_add IP 延迟约 11 周期 (NonBlocking 模式)
// - 数据格式: HWC (Height-Width-Channel)，每 word 8 个 FP32
//
//==============================================================================

module tb_ad_unit;

    //==========================================================================
    // 参数定义
    //==========================================================================
    localparam ADDR_WIDTH    = 32;
    localparam GB_BANDWIDTH  = 256;      // 256 bits = 8 FP32
    localparam GB_ADDR_WIDTH = 16;
    localparam FP_CORE_NUM   = 8;        // 每次处理 8 个 FP32
    localparam FP_WIDTH      = 32;
    
    localparam BRAM_DEPTH    = 4096;     // BRAM 深度 (words)
    localparam LANES         = GB_BANDWIDTH / FP_WIDTH;  // 8
    localparam NB_COL        = GB_BANDWIDTH / 8;         // 32 bytes
    localparam COL_WIDTH     = 8;
    
    localparam CLK_PERIOD    = 4.0;      // 250 MHz
    
    //==========================================================================
    // 时钟和复位
    //==========================================================================
    reg clk;
    reg rst_n;
    
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    //==========================================================================
    // DUT 接口信号
    //==========================================================================
    reg                         ad_unit_start;
    wire                        ad_unit_ready;
    
    reg  [ADDR_WIDTH-1:0]       ad_src_addr;
    reg  [ADDR_WIDTH-1:0]       ad_src2_addr;
    reg  [ADDR_WIDTH-1:0]       ad_src_c;
    reg  [ADDR_WIDTH-1:0]       ad_src_h;
    reg  [ADDR_WIDTH-1:0]       ad_src_w;
    reg  [ADDR_WIDTH-1:0]       ad_dst_addr;
    
    wire [GB_ADDR_WIDTH-1:0]    gb_addrb;
    wire [GB_BANDWIDTH-1:0]     gb_dinb;
    wire [GB_BANDWIDTH/8-1:0]   gb_web;
    wire                        gb_enb;
    wire [GB_BANDWIDTH-1:0]     gb_doutb;
    
    //==========================================================================
    // 真实 BRAM 实例化 (global_buffer_bram)
    //==========================================================================
    global_buffer_bram #(
        .NB_COL(NB_COL),
        .COL_WIDTH(COL_WIDTH),
        .RAM_DEPTH(BRAM_DEPTH),
        .RAM_PERFORMANCE("LOW_LATENCY"),
        .INIT_FILE("")
    ) u_bram (
        .clka(clk),
        // Port A - 未使用，接地
        .addra({GB_ADDR_WIDTH{1'b0}}),
        .dina({GB_BANDWIDTH{1'b0}}),
        .wea({NB_COL{1'b0}}),
        .ena(1'b0),
        .rsta(1'b0),
        .regcea(1'b0),
        .douta(),
        // Port B - 连接到 DUT
        .addrb(gb_addrb),
        .dinb(gb_dinb),
        .web(gb_web),
        .enb(gb_enb),
        .rstb(~rst_n),
        .regceb(1'b1),
        .doutb(gb_doutb)
    );
    
    //==========================================================================
    // DUT 实例化
    //==========================================================================
    ad_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BANDWIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_WIDTH(FP_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ad_unit_start(ad_unit_start),
        .ad_unit_ready(ad_unit_ready),
        .ad_src_addr(ad_src_addr),
        .ad_src2_addr(ad_src2_addr),
        .ad_src_c(ad_src_c),
        .ad_src_h(ad_src_h),
        .ad_src_w(ad_src_w),
        .ad_dst_addr(ad_dst_addr),
        .gb_addrb(gb_addrb),
        .gb_dinb(gb_dinb),
        .gb_web(gb_web),
        .gb_enb(gb_enb),
        .gb_doutb(gb_doutb)
    );
    
    //==========================================================================
    // BRAM Read/Write Monitoring and Verification
    //==========================================================================
    // Monitor each BRAM operation and verify data correctness
    
    // Store expected operands and results
    real expected_a [0:7];
    real expected_b [0:7];
    real expected_sum [0:7];
    int current_iteration = 0;
    
    // Monitor BRAM read operations
    always @(posedge clk) begin
        // Debug: Print latched registers when entering AD_LOAD_X for first time in test
        if (dut.c_state == dut.IDLE && dut.ad_unit_start) begin
            $display("  [DEBUG] Latching inputs: src=0x%h, src2=0x%h, dst=0x%h",
                ad_src_addr, ad_src2_addr, ad_dst_addr);
        end
        if (dut.c_state == dut.AD_LOAD_X && dut.ad_x_load_block_cnt == 0 && dut.ad_x_load_cnt == 0) begin
            $display("  [DEBUG] Latched regs: src_reg=0x%h, src2_reg=0x%h, dst_reg=0x%h",
                dut.ad_src_addr_reg, dut.ad_src2_addr_reg, dut.ad_dst_addr_reg);
        end
        
        if (gb_enb && gb_web == 0) begin
            // BRAM read operation
            if (dut.c_state == dut.AD_LOAD_X) begin
                // Read SRC1
                $display("  [BRAM RD] iter=%0d: addr=%0d (SRC1)", current_iteration, gb_addrb);
                #1; // Wait 1 time unit for doutb to stabilize
            end else if (dut.c_state == dut.AD_LOAD_X_2) begin
                // Read SRC2
                $display("  [BRAM RD] iter=%0d: addr=%0d (SRC2)", current_iteration, gb_addrb);
            end
        end
        
        // Monitor data loading into registers
        // Wait until next state after AD_WAIT_X_2 to ensure data is loaded
        if (dut.c_state == dut.AD_COMPUTE) begin
            // At this point, both SRC1 and SRC2 are fully loaded
            for (int i = 0; i < LANES; i++) begin
                expected_a[i] = fp32_to_real(dut.ad_fp_in_reg[i*FP_WIDTH +: FP_WIDTH]);
                expected_b[i] = fp32_to_real(dut.ad_fp_in2_reg[i*FP_WIDTH +: FP_WIDTH]);
                expected_sum[i] = expected_a[i] + expected_b[i];
            end
            
            // Print data being computed
            $display("  [DATA LD] iter=%0d:", current_iteration);
            $display("    SRC1: %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f",
                expected_a[0], expected_a[1], expected_a[2], expected_a[3],
                expected_a[4], expected_a[5], expected_a[6], expected_a[7]);
            $display("    SRC2: %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f",
                expected_b[0], expected_b[1], expected_b[2], expected_b[3],
                expected_b[4], expected_b[5], expected_b[6], expected_b[7]);
            $display("    EXP : %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f",
                expected_sum[0], expected_sum[1], expected_sum[2], expected_sum[3],
                expected_sum[4], expected_sum[5], expected_sum[6], expected_sum[7]);
        end
        
        // Monitor BRAM write operations
        // Read directly from ad_out_reg instead of gb_dinb to avoid timing issues
        if (dut.c_state == dut.AD_SAVE && gb_enb && gb_web != 0) begin
            automatic real actual_results [0:7];
            automatic int errors_in_write = 0;
            
            // Extract written data from ad_out_reg (the source of gb_dinb)
            // Use ad_save_cnt to index into ad_out_reg
            for (int i = 0; i < LANES; i++) begin
                automatic int bit_offset = dut.ad_save_cnt * GB_BANDWIDTH + i * FP_WIDTH;
                actual_results[i] = fp32_to_real(dut.ad_out_reg[bit_offset +: FP_WIDTH]);
            end
            
            $display("  [BRAM WR] iter=%0d: addr=%0d (DST), save_cnt=%0d", 
                current_iteration, gb_addrb, dut.ad_save_cnt);
            $display("    DST : %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f",
                actual_results[0], actual_results[1], actual_results[2], actual_results[3],
                actual_results[4], actual_results[5], actual_results[6], actual_results[7]);
            
            // Verify results
            for (int i = 0; i < LANES; i++) begin
                if (abs_real(actual_results[i] - expected_sum[i]) > 0.01) begin
                    $display("    X lane%0d: exp=%6.2f, act=%6.2f, diff=%6.2f",
                        i, expected_sum[i], actual_results[i], 
                        actual_results[i] - expected_sum[i]);
                    errors_in_write++;
                end
            end
            
            if (errors_in_write == 0) begin
                $display("    OK: All 8 values correct");
            end else begin
                $display("    FAIL: %0d values incorrect", errors_in_write);
            end
            
            current_iteration++;
        end
        
        // Reset iteration counter
        if (dut.c_state == dut.IDLE && dut.ad_unit_start) begin
            current_iteration = 0;
        end
    end
    
    //==========================================================================
    // Golden Model 存储
    //==========================================================================
    reg [FP_WIDTH-1:0] golden_result [0:4095];  // 最多 4096 个 FP32 结果
    
    //==========================================================================
    // FP32 辅助函数
    //==========================================================================
    function [FP_WIDTH-1:0] real_to_fp32;
        input real rval;
        shortreal sr;
        begin
            sr = shortreal'(rval);
            real_to_fp32 = $shortrealtobits(sr);
        end
    endfunction
    
    function real fp32_to_real;
        input [FP_WIDTH-1:0] bits;
        begin
            fp32_to_real = $bitstoshortreal(bits);
        end
    endfunction
    
    // 绝对值函数
    function real abs_real;
        input real val;
        begin
            abs_real = (val < 0) ? -val : val;
        end
    endfunction
    
    //==========================================================================
    // 测试任务
    //==========================================================================
    
    // 初始化 BRAM 中的测试数据
    task automatic init_test_data(
        input int src1_word_addr,
        input int src2_word_addr,
        input int num_elements
    );
        int num_words;
        real src1_val, src2_val;
        reg [FP_WIDTH-1:0] fp_src1, fp_src2;
        
        num_words = (num_elements + LANES - 1) / LANES;
        
        $display("  Initializing test data: %0d elements, %0d BRAM words", num_elements, num_words);
        $display("    SRC1 base addr: word %0d (byte 0x%08h)", src1_word_addr, src1_word_addr * 32);
        $display("    SRC2 base addr: word %0d (byte 0x%08h)", src2_word_addr, src2_word_addr * 32);
        
        for (int w = 0; w < num_words; w++) begin
            for (int lane = 0; lane < LANES; lane++) begin
                int elem_idx = w * LANES + lane;
                if (elem_idx < num_elements) begin
                    // SRC1: 1.0, 2.0, 3.0, ...
                    src1_val = elem_idx + 1.0;
                    // SRC2: 10.0, 20.0, 30.0, ...
                    src2_val = (elem_idx + 1) * 10.0;
                    
                    fp_src1 = real_to_fp32(src1_val);
                    fp_src2 = real_to_fp32(src2_val);
                    
                    // 写入 BRAM (直接访问内部存储)
                    u_bram.BRAM[src1_word_addr + w][lane*FP_WIDTH +: FP_WIDTH] = fp_src1;
                    u_bram.BRAM[src2_word_addr + w][lane*FP_WIDTH +: FP_WIDTH] = fp_src2;
                    
                    // 计算 golden result
                    golden_result[elem_idx] = real_to_fp32(src1_val + src2_val);
                end else begin
                    // 填充 0
                    u_bram.BRAM[src1_word_addr + w][lane*FP_WIDTH +: FP_WIDTH] = 32'h0;
                    u_bram.BRAM[src2_word_addr + w][lane*FP_WIDTH +: FP_WIDTH] = 32'h0;
                end
            end
        end
        
        // Display first few values
        $display("    SRC1 first 8: %.1f, %.1f, %.1f, %.1f, %.1f, %.1f, %.1f, %.1f",
            1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
        $display("    SRC2 first 8: %.1f, %.1f, %.1f, %.1f, %.1f, %.1f, %.1f, %.1f",
            10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0);
        $display("    Expected sum: %.1f, %.1f, %.1f, %.1f, %.1f, %.1f, %.1f, %.1f",
            11.0, 22.0, 33.0, 44.0, 55.0, 66.0, 77.0, 88.0);
    endtask
    
    // 验证结果
    task automatic verify_result(
        input int dst_word_addr,
        input int num_elements,
        output int error_count
    );
        int num_words;
        real actual_val, expected_val, diff;
        reg [FP_WIDTH-1:0] actual_bits, expected_bits;
        
        num_words = (num_elements + LANES - 1) / LANES;
        error_count = 0;
        
        $display("  Verifying results:");
        $display("    DST base addr: word %0d (byte 0x%08h)", dst_word_addr, dst_word_addr * 32);
        
        for (int w = 0; w < num_words; w++) begin
            for (int lane = 0; lane < LANES; lane++) begin
                int elem_idx = w * LANES + lane;
                if (elem_idx < num_elements) begin
                    actual_bits = u_bram.BRAM[dst_word_addr + w][lane*FP_WIDTH +: FP_WIDTH];
                    expected_bits = golden_result[elem_idx];
                    
                    actual_val = fp32_to_real(actual_bits);
                    expected_val = fp32_to_real(expected_bits);
                    diff = actual_val - expected_val;
                    if (diff < 0) diff = -diff;
                    
                    // Bit-exact 比较
                    if (actual_bits !== expected_bits) begin
                        error_count++;
                        if (error_count <= 10) begin
                            $display("    ✗ [%0d] 期望=0x%08h (%.2f), 实际=0x%08h (%.2f)",
                                elem_idx, expected_bits, expected_val, actual_bits, actual_val);
                        end
                    end else if (elem_idx < 16) begin
                        $display("    ✓ [%0d] 值=0x%08h (%.2f)", 
                            elem_idx, actual_bits, actual_val);
                    end
                end
            end
        end
        
        if (error_count == 0) begin
            $display("    OK: All %0d elements verified!", num_elements);
        end else begin
            $display("    FAIL: %0d/%0d elements failed!", error_count, num_elements);
        end
    endtask
    
    // 清空 BRAM 区域
    task automatic clear_bram_region(
        input int start_word,
        input int num_words
    );
        for (int i = 0; i < num_words; i++) begin
            u_bram.BRAM[start_word + i] = {GB_BANDWIDTH{1'b0}};
        end
    endtask
    
    // 运行单次 ADD 测试
    task automatic run_add_test(
        input string test_name,
        input int num_c,
        input int num_h,
        input int num_w,
        input int src1_byte_addr,
        input int src2_byte_addr,
        input int dst_byte_addr,
        output int test_errors
    );
        int num_elements;
        int src1_word, src2_word, dst_word;
        int timeout;
        int cycle_count;
        int expected_loops;
        
        num_elements = num_c * num_h * num_w;
        src1_word = src1_byte_addr >> 5;  // 除以 32
        src2_word = src2_byte_addr >> 5;
        dst_word = dst_byte_addr >> 5;
        
        // Calculate expected loop count
        // ad_x_total_blocks = (num_elements * 32 + 255) / 256
        expected_loops = (num_elements * FP_WIDTH + GB_BANDWIDTH - 1) / GB_BANDWIDTH;
        
        $display("\n" + "="*70);
        $display("Test: %s", test_name);
        $display("  Config: C=%0d, H=%0d, W=%0d", num_c, num_h, num_w);
        $display("  Total elements: %0d FP32", num_elements);
        $display("  BRAM words: %0d (8 FP32 per word)", expected_loops);
        $display("  Expected loops: %0d", expected_loops);
        $display("  Address: SRC1=word %0d, SRC2=word %0d, DST=word %0d", 
            src1_word, src2_word, dst_word);
        $display("="*70);
        
        // 初始化数据
        init_test_data(src1_word, src2_word, num_elements);
        
        // 清空目标区域
        clear_bram_region(dst_word, (num_elements + LANES - 1) / LANES);
        
        // 配置 DUT
        ad_src_addr  = src1_byte_addr;
        ad_src2_addr = src2_byte_addr;
        ad_dst_addr  = dst_byte_addr;
        ad_src_c     = num_c;
        ad_src_h     = num_h;
        ad_src_w     = num_w;
        
        // 等待 ready
        wait(ad_unit_ready);
        @(posedge clk);
        
        // Start
        $display("  Starting ad_unit...");
        ad_unit_start = 1'b1;
        @(posedge clk);
        ad_unit_start = 1'b0;
        
        // Wait for start
        wait(!ad_unit_ready);
        $display("  ad_unit processing...");
        
        // Wait for completion
        cycle_count = 0;
        timeout = 100000;  // Max cycles
        while (!ad_unit_ready && cycle_count < timeout) begin
            @(posedge clk);
            cycle_count++;
        end
        
        if (cycle_count >= timeout) begin
            $display("  X Timeout! ad_unit didn't finish in %0d cycles", timeout);
            test_errors = num_elements;
        end else begin
            $display("  Done! Took %0d cycles", cycle_count);
            
            // Wait a few cycles for write completion
            repeat(5) @(posedge clk);
            
            // Verify results
            verify_result(dst_word, num_elements, test_errors);
        end
    endtask
    
    //==========================================================================
    // 主测试流程
    //==========================================================================
    integer total_tests;
    integer total_errors;
    integer test_errors;
    
    initial begin
        $display("\n");
        $display("======================================================================");
        $display("           ad_unit Testbench - FP32 ADD Unit Test");
        $display("           Using Real BRAM and Xilinx FP32 Add IP");
        $display("======================================================================");
        $display("Configuration:");
        $display("  FP_CORE_NUM   = %0d", FP_CORE_NUM);
        $display("  FP_WIDTH      = %0d bits", FP_WIDTH);
        $display("  GB_BANDWIDTH  = %0d bits", GB_BANDWIDTH);
        $display("  LANES         = %0d FP32/word", LANES);
        $display("  BRAM_DEPTH    = %0d words", BRAM_DEPTH);
        $display("");
        $display("Key design parameters:");
        $display("  ad_single_compute_blocks = FP_CORE_NUM * FP_WIDTH / GB_BANDWIDTH");
        $display("                           = %0d * %0d / %0d = %0d", 
            FP_CORE_NUM, FP_WIDTH, GB_BANDWIDTH, 
            (FP_CORE_NUM * FP_WIDTH) / GB_BANDWIDTH);
        $display("  This means each loop processes %0d BRAM word (%0d FP32)",
            (FP_CORE_NUM * FP_WIDTH) / GB_BANDWIDTH, FP_CORE_NUM);
        $display("======================================================================\n");
        
        // 初始化
        rst_n = 0;
        ad_unit_start = 0;
        ad_src_addr = 0;
        ad_src2_addr = 0;
        ad_src_c = 0;
        ad_src_h = 0;
        ad_src_w = 0;
        ad_dst_addr = 0;
        
        total_tests = 0;
        total_errors = 0;
        
        // 复位
        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        //======================================================================
        // Test Strategy: From simplest to complex, gradual verification
        //======================================================================
        // 
        // FP_CORE_NUM = 8 means processing 8 FP32 at a time
        // GB_BANDWIDTH = 256 bits = 8 FP32
        // Therefore ad_single_compute_blocks = 8*32/256 = 1
        // 
        // Test case design:
        // 1. H=1, W=1, C=8  : 1 data group, verify single processing
        // 2. H=1, W=1, C=16 : 2 data groups, verify loop once
        // 3. H=1, W=1, C=64 : 8 data groups, verify multiple loops
        // 4. H=1, W=8, C=8  : Multi-dimensional but same total, verify address calculation
        //======================================================================
        
        //----------------------------------------------------------------------
        // Test 1: Simplest - H=1, W=1, C=8 (8 FP32, 1 BRAM word)
        // Note: Exactly 1 data group, ad_x_total_blocks = 1
        //       Should execute 1 loop: LOAD → COMPUTE → SAVE → IDLE
        //----------------------------------------------------------------------
        run_add_test(
            "Test1: H=1,W=1,C=8 (8 FP32)",
            .num_c(8),
            .num_h(1),
            .num_w(1),
            .src1_byte_addr(32'h0000_0000),  // word 0
            .src2_byte_addr(32'h0000_0020),  // word 1
            .dst_byte_addr(32'h0000_0040),   // word 2
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 2: Simple loop - H=1, W=1, C=16 (16 FP32, 2 BRAM words)
        // Note: 2 data groups, ad_x_total_blocks = 2
        //       Should execute 2 loops, 8 FP32 each
        //       ad_x_load_cnt: 0 → 1
        // Address allocation: SRC1 needs 2 words, SRC2 needs 2 words, DST needs 2 words
        //----------------------------------------------------------------------
        run_add_test(
            "Test2: H=1,W=1,C=16 (16 FP32)",
            .num_c(16),
            .num_h(1),
            .num_w(1),
            .src1_byte_addr(32'h0000_0100),  // word 8-9   (2 words)
            .src2_byte_addr(32'h0000_0140),  // word 10-11 (2 words)
            .dst_byte_addr(32'h0000_0180),   // word 12-13 (2 words)
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 3: Multiple loops - H=1, W=1, C=64 (64 FP32, 8 BRAM words)
        // Note: 8 data groups, ad_x_total_blocks = 8
        //       Should execute 8 loops, 8 FP32 each
        //       ad_x_load_cnt: 0 → 1 → 2 → ... → 7
        //----------------------------------------------------------------------
        run_add_test(
            "Test3: H=1,W=1,C=64 (64 FP32)",
            .num_c(64),
            .num_h(1),
            .num_w(1),
            .src1_byte_addr(32'h0000_0200),  // word 16
            .src2_byte_addr(32'h0000_0400),  // word 32
            .dst_byte_addr(32'h0000_0600),   // word 48
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 4: Multi-dimensional - H=1, W=8, C=8 (64 FP32, 8 BRAM words)
        // Note: Although multi-dimensional, same total (1*8*8 = 64)
        //       Verify ad_x_total_blocks calculation is correct
        //       ad_x_total_blocks = (1*8*8*32 + 255) / 256 = 8
        //----------------------------------------------------------------------
        run_add_test(
            "Test4: H=1,W=8,C=8 (64 FP32, multi-dim)",
            .num_c(8),
            .num_h(1),
            .num_w(8),
            .src1_byte_addr(32'h0000_0800),  // word 64
            .src2_byte_addr(32'h0000_0A00),  // word 80
            .dst_byte_addr(32'h0000_0C00),   // word 96
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 5: Complex CHW - H=2, W=2, C=8 (32 FP32)
        // Note: Tests multi-dimensional indexing
        //       Total: 2*2*8 = 32 FP32 = 4 BRAM words
        //       Verify H*W*C calculation: ad_x_total_blocks = (32*32 + 255)/256 = 4
        //----------------------------------------------------------------------
        run_add_test(
            "Test5: H=2,W=2,C=8 (32 FP32, 2D)",
            .num_c(8),
            .num_h(2),
            .num_w(2),
            .src1_byte_addr(32'h0000_1000),  // word 128
            .src2_byte_addr(32'h0000_1200),  // word 144
            .dst_byte_addr(32'h0000_1400),   // word 160
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 6: Large CHW - H=4, W=4, C=16 (256 FP32)
        // Note: Larger multi-dimensional test
        //       Total: 4*4*16 = 256 FP32 = 32 BRAM words
        //       Verify address stride calculation across H and W dimensions
        //----------------------------------------------------------------------
        run_add_test(
            "Test6: H=4,W=4,C=16 (256 FP32, 3D)",
            .num_c(16),
            .num_h(4),
            .num_w(4),
            .src1_byte_addr(32'h0000_1800),  // word 192
            .src2_byte_addr(32'h0000_2000),  // word 256
            .dst_byte_addr(32'h0000_2800),   // word 320
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 7: Non-aligned CHW - H=3, W=5, C=7 (105 FP32)
        // Note: Non-power-of-2 dimensions to test edge cases
        //       Total: 3*5*7 = 105 FP32 = 14 BRAM words (last word partial)
        //       This tests handling of non-8-aligned element counts
        //----------------------------------------------------------------------
        run_add_test(
            "Test7: H=3,W=5,C=7 (105 FP32, odd)",
            .num_c(7),
            .num_h(3),
            .num_w(5),
            .src1_byte_addr(32'h0000_3000),  // word 384
            .src2_byte_addr(32'h0000_3400),  // word 416
            .dst_byte_addr(32'h0000_3800),   // word 448
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 8: Minimal non-trivial - H=2, W=1, C=4 (8 FP32)
        // Note: Smallest multi-H test (exactly 1 BRAM word)
        //       Ensures H dimension works correctly even for small values
        //----------------------------------------------------------------------
        run_add_test(
            "Test8: H=2,W=1,C=4 (8 FP32, min-H)",
            .num_c(4),
            .num_h(2),
            .num_w(1),
            .src1_byte_addr(32'h0000_3C00),  // word 480
            .src2_byte_addr(32'h0000_3C40),  // word 482
            .dst_byte_addr(32'h0000_3C80),   // word 484
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test 9: Stress test - H=8, W=8, C=32 (2048 FP32)
        // Note: Large tensor to stress test the module
        //       Total: 8*8*32 = 2048 FP32 = 256 BRAM words
        //       Tests sustained operation over many iterations
        //----------------------------------------------------------------------
        run_add_test(
            "Test9: H=8,W=8,C=32 (2048 FP32, stress)",
            .num_c(32),
            .num_h(8),
            .num_w(8),
            .src1_byte_addr(32'h0000_4000),  // word 512
            .src2_byte_addr(32'h0000_6000),  // word 768
            .dst_byte_addr(32'h0000_8000),   // word 1024
            .test_errors(test_errors)
        );
        total_tests++;
        total_errors += test_errors;
        
        repeat(20) @(posedge clk);
        
        //----------------------------------------------------------------------
        // Test Summary
        //----------------------------------------------------------------------
        $display("\n");
        $display("======================================================================");
        $display("                         Test Summary");
        $display("======================================================================");
        $display("  Total tests:     %0d", total_tests);
        $display("  Total errors:    %0d", total_errors);
        if (total_errors == 0) begin
            $display("  Status:          *** ALL PASSED ***");
        end else begin
            $display("  Status:          *** FAILURES EXIST ***");
        end
        $display("======================================================================\n");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    //==========================================================================
    // 波形转储
    //==========================================================================
    initial begin
        $dumpfile("tb_ad_unit.vcd");
        $dumpvars(0, tb_ad_unit);
    end
    
    //==========================================================================
    // 超时保护
    //==========================================================================
    initial begin
        #(CLK_PERIOD * 500000);  // 2ms
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
