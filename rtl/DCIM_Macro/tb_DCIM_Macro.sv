`timescale 1ns / 1ps
`include "../../ref/DCIM/src/inc/para.v"

// ============================================================================
// tb_DCIM_Macro - 完整测试平台
// ============================================================================
// 与 dcim_preprocess_tb.v 完全一致的验证逻辑
// ============================================================================

module tb_DCIM_Macro;

    localparam WD1 = 4, CH_IN = 16, CH_OUT = 16, SRAM_DP = 128, CYCLE = 8, ACC = 16;
    localparam BUF_ADDR_WIDTH = 12, BUF_DATA_WIDTH = 128;
    localparam SRAM_WD = CH_IN * CH_OUT * WD1 / CYCLE;  // 128
    localparam WD2 = 2*WD1 + $clog2(CH_IN);              // 12
    localparam WD3 = WD2 + $clog2(ACC);                  // 16
    localparam TEST_ROWS = 8;
    localparam T = 10;
    
    reg clk, rst_n, start;
    wire done, ready;
    reg [2:0] mode;
    reg [4:0] acc_depth;
    reg [15:0] num_rows;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_addr, act_base_addr, out_base_addr;
    
    reg  [BUF_DATA_WIDTH/8-1:0] ibuf_wea, obuf_wea;
    reg  [BUF_ADDR_WIDTH-1:0] ibuf_addra, obuf_addra;
    reg  [BUF_DATA_WIDTH-1:0] ibuf_dina, obuf_dina;
    reg  ibuf_ena, obuf_ena;
    wire [BUF_DATA_WIDTH-1:0] ibuf_douta, obuf_douta;
    
    DCIM_Macro #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH), .BUF_DATA_WIDTH(BUF_DATA_WIDTH)
    ) dut (.*);
    
    initial clk = 0;
    always #(T/2) clk = ~clk;
    
    // ========================================================================
    // 测试数据存储 - 与 dcim_preprocess_tb.v 一致
    // ========================================================================
    reg signed [3:0] weight_nibble [0:CH_IN-1][0:CH_OUT-1];  // [in_ch][out_ch]
    reg signed [15:0] activation [0:TEST_ROWS-1][0:CH_IN-1]; // 统一用 16-bit
    reg signed [31:0] golden [0:TEST_ROWS-1][0:7];
    reg signed [WD3-1:0] dut_out [0:TEST_ROWS-1][0:CH_OUT-1];
    
    integer num_logical_ch;
    integer nibble_phases;
    integer test_mode;  // 0=INT8, 1=INT16
    integer test_acc;
    integer total_errors;
    
    // ========================================================================
    // IBUF/OBUF 访问任务
    // ========================================================================
    task write_ibuf(input [BUF_ADDR_WIDTH-1:0] addr, input [BUF_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            ibuf_ena <= 1'b1; ibuf_wea <= {(BUF_DATA_WIDTH/8){1'b1}};
            ibuf_addra <= addr; ibuf_dina <= data;
            @(posedge clk);
            ibuf_ena <= 1'b0; ibuf_wea <= 0;
        end
    endtask
    
    task read_obuf(input [BUF_ADDR_WIDTH-1:0] addr, output [BUF_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            obuf_ena <= 1'b1; obuf_wea <= 0; obuf_addra <= addr;
            repeat(5) @(posedge clk);
            data = obuf_douta;
            obuf_ena <= 1'b0;
        end
    endtask
    
    // ========================================================================
    // 权重生成和加载 - 与 dcim_preprocess_tb.v 一致
    // ========================================================================
    task generate_weights(input integer use_random);
        integer i, j;
        begin
            for (i = 0; i < CH_IN; i++) begin
                for (j = 0; j < CH_OUT; j++) begin
                    if (use_random)
                        weight_nibble[i][j] = ((i + j) % 15) - 7;  // 固定模式，范围 [-7, 7]
                    else
                        weight_nibble[i][j] = 4'sd1;
                end
            end
            $display("  Weight sample [0][0:7]: %d %d %d %d %d %d %d %d",
                     weight_nibble[0][0], weight_nibble[0][1],
                     weight_nibble[0][2], weight_nibble[0][3],
                     weight_nibble[0][4], weight_nibble[0][5],
                     weight_nibble[0][6], weight_nibble[0][7]);
        end
    endtask
    
    task load_weights;
        integer addr, bit_idx, nibble_idx, in_ch, out_ch;
        reg [SRAM_WD-1:0] sram_word;
        begin
            for (addr = 0; addr < CYCLE; addr++) begin
                sram_word = 0;
                for (bit_idx = 0; bit_idx < SRAM_WD; bit_idx = bit_idx + WD1) begin
                    nibble_idx = addr * (SRAM_WD/WD1) + bit_idx/WD1;
                    // DCIM 内部排布：nibble_idx = out_ch * CH_IN + in_ch
                    out_ch = nibble_idx / CH_IN;
                    in_ch = nibble_idx % CH_IN;
                    if (in_ch < CH_IN && out_ch < CH_OUT)
                        sram_word[bit_idx +: WD1] = weight_nibble[in_ch][out_ch];
                end
                write_ibuf(addr, sram_word);
            end
        end
    endtask
    
    // ========================================================================
    // 激活数据生成和加载
    // ========================================================================
    task generate_activations(input integer use_random);
        integer row, ch;
        begin
            for (row = 0; row < TEST_ROWS; row++) begin
                for (ch = 0; ch < CH_IN; ch++) begin
                    if (use_random) begin
                        if (test_mode == 0)  // INT8
                            activation[row][ch] = ((row * CH_IN + ch) % 255) - 127;  // 固定模式
                        else  // INT16
                            activation[row][ch] = ((row * CH_IN + ch) % 65535) - 32767;
                    end else begin
                        activation[row][ch] = row + 1;
                    end
                end
            end
            $display("  Act sample [0][0:3]: %d %d %d %d",
                     activation[0][0], activation[0][1], activation[0][2], activation[0][3]);
        end
    endtask
    
    task load_activations;
        integer row, ch;
        reg [BUF_DATA_WIDTH-1:0] act_word_lo, act_word_hi;
        begin
            for (row = 0; row < TEST_ROWS; row++) begin
                if (test_mode == 0) begin
                    // INT8: 16×8 = 128-bit, 1 次写入
                    act_word_lo = 0;
                    for (ch = 0; ch < CH_IN; ch++)
                        act_word_lo[ch*8 +: 8] = activation[row][ch][7:0];
                    write_ibuf(CYCLE + row, act_word_lo);
                end else begin
                    // INT16: 16×16 = 256-bit, 2 次写入
                    act_word_lo = 0;
                    act_word_hi = 0;
                    for (ch = 0; ch < 8; ch++) begin
                        act_word_lo[ch*16 +: 16] = activation[row][ch];
                        act_word_hi[ch*16 +: 16] = activation[row][ch+8];
                    end
                    write_ibuf(CYCLE + row*2, act_word_lo);
                    write_ibuf(CYCLE + row*2 + 1, act_word_hi);
                end
            end
        end
    endtask
    
    // ========================================================================
    // Golden Model 计算 - 与 dcim_preprocess_tb.v 完全一致
    // ========================================================================
    task compute_golden;
        integer row, out_ch, in_ch, acc_group, row_in_group;
        integer phys_ch_lo, phys_ch_hi;
        integer num_acc_groups, acc_val;
        reg signed [31:0] sum;
        reg signed [7:0] w8;
        reg signed [15:0] w16;
        reg signed [7:0] a8;
        reg signed [15:0] a16;
        begin
            acc_val = (test_acc == 0) ? 1 : test_acc;
            num_acc_groups = TEST_ROWS / acc_val;
            
            $display("  ACC=%0d, Groups=%0d, Rows per group=%0d", test_acc, num_acc_groups, acc_val);
            
            // 初始化
            for (row = 0; row < TEST_ROWS; row++)
                for (out_ch = 0; out_ch < 8; out_ch++)
                    golden[row][out_ch] = 0;
            
            // 按累加组计算
            for (acc_group = 0; acc_group < num_acc_groups; acc_group++) begin
                for (out_ch = 0; out_ch < num_logical_ch; out_ch++) begin
                    sum = 0;
                    
                    for (row_in_group = 0; row_in_group < acc_val; row_in_group++) begin
                        row = acc_group * acc_val + row_in_group;
                        
                        for (in_ch = 0; in_ch < CH_IN; in_ch++) begin
                            if (test_mode == 0) begin
                                // INT8: 逻辑通道 out_ch 使用物理通道 out_ch*2+2 和 out_ch*2+3
                                phys_ch_lo = out_ch * 2 + 2;
                                phys_ch_hi = out_ch * 2 + 3;
                                
                                if (phys_ch_lo >= CH_OUT) phys_ch_lo = CH_OUT - 2;
                                if (phys_ch_hi >= CH_OUT) phys_ch_hi = CH_OUT - 1;
                                
                                w8 = {weight_nibble[in_ch][phys_ch_hi], weight_nibble[in_ch][phys_ch_lo]};
                                a8 = activation[row][in_ch][7:0];
                                sum = sum + ($signed(a8) * $signed(w8));
                            end else begin
                                // INT16: 每 4 个物理通道产生 1 个逻辑通道
                                // 结果在 phys[0], phys[4], phys[8], phys[12]
                                integer base_ch, ch0, ch1, ch2, ch3;
                                base_ch = out_ch * 4;
                                ch0 = base_ch;
                                ch1 = base_ch + 1;
                                ch2 = base_ch + 2;
                                ch3 = base_ch + 3;
                                if (ch3 >= CH_OUT) begin
                                    ch0 = CH_OUT - 4;
                                    ch1 = CH_OUT - 3;
                                    ch2 = CH_OUT - 2;
                                    ch3 = CH_OUT - 1;
                                end
                                w16 = {weight_nibble[in_ch][ch3],
                                       weight_nibble[in_ch][ch2],
                                       weight_nibble[in_ch][ch1],
                                       weight_nibble[in_ch][ch0]};
                                a16 = activation[row][in_ch];
                                sum = sum + ($signed(a16) * $signed(w16));
                            end
                        end
                    end
                    
                    // 存储累加结果
                    if (test_mode == 0)
                        golden[acc_group][out_ch] = $signed(sum[WD3-1:0]);
                    else
                        golden[acc_group][out_ch] = sum;
                end
            end
            
            $display("  Golden[0][0:7]: %d %d %d %d %d %d %d %d",
                     golden[0][0], golden[0][1], golden[0][2], golden[0][3],
                     golden[0][4], golden[0][5], golden[0][6], golden[0][7]);
        end
    endtask
    
    // ========================================================================
    // 结果读取和验证 - 与 dcim_preprocess_tb.v 完全一致
    // ========================================================================
    task read_results;
        integer row, ch, num_outputs, acc_val;
        reg [BUF_DATA_WIDTH-1:0] result_lo, result_hi;
        reg [255:0] result_full;
        begin
            acc_val = (test_acc == 0) ? 1 : test_acc;
            num_outputs = TEST_ROWS / acc_val;
            
            for (row = 0; row < num_outputs; row++) begin
                read_obuf(row * 2, result_lo);
                read_obuf(row * 2 + 1, result_hi);
                result_full = {result_hi, result_lo};
                
                // 提取所有物理通道的 16-bit 值
                for (ch = 0; ch < CH_OUT; ch++) begin
                    dut_out[row][ch] = $signed(result_full[ch*16 +: 16]);
                end
            end
        end
    endtask
    
    task verify_results;
        integer row, ch, errors, total;
        integer col, subcol, phys_ch_idx;
        integer num_outputs, acc_val;
        reg signed [31:0] dut_val, exp_val;
        begin
            errors = 0;
            total = 0;
            acc_val = (test_acc == 0) ? 1 : test_acc;
            num_outputs = TEST_ROWS / acc_val;
            
            $display("");
            $display("  ─────────────────────────────────────────────────────");
            $display("  Verification: Mode=%s, ACC=%0d, Outputs=%0d",
                     (test_mode == 0) ? "INT8" : "INT16", test_acc, num_outputs);
            $display("  ─────────────────────────────────────────────────────");
            
            for (row = 0; row < num_outputs; row++) begin
                for (ch = 0; ch < num_logical_ch; ch++) begin
                    if (test_mode == 0) begin
                        // INT8: 物理通道映射 - 与 Golden Model 一致
                        // Golden 使用 phys_ch_lo = out_ch * 2 + 2
                        phys_ch_idx = ch * 2 + 2;
                        if (phys_ch_idx >= CH_OUT) phys_ch_idx = CH_OUT - 2;
                        dut_val = dut_out[row][phys_ch_idx];
                    end else begin
                        // INT16: 每 4 个物理通道产生 1 个逻辑通道
                        // 结果在 phys[0], phys[4], phys[8], phys[12]
                        phys_ch_idx = ch * 4;
                        dut_val = {dut_out[row][phys_ch_idx+1], dut_out[row][phys_ch_idx]};
                    end
                    exp_val = golden[row][ch];
                    
                    total++;
                    if (dut_val !== exp_val) begin
                        errors++;
                        if (errors <= 5)
                            $display("  [ERR] Row %0d Ch %0d (phys %0d): DUT=%0d, Golden=%0d",
                                     row, ch, phys_ch_idx, dut_val, exp_val);
                    end else if (row < 2 && ch < 4) begin
                        $display("  [OK] Row %0d Ch %0d: %0d", row, ch, dut_val);
                    end
                end
            end
            
            // 打印物理通道调试信息
            $display("");
            $display("  Debug Row 0 physical channels [0:7]: %d %d %d %d %d %d %d %d",
                     dut_out[0][0], dut_out[0][1], dut_out[0][2], dut_out[0][3],
                     dut_out[0][4], dut_out[0][5], dut_out[0][6], dut_out[0][7]);
            $display("  Debug Row 0 physical channels [8:15]: %d %d %d %d %d %d %d %d",
                     dut_out[0][8], dut_out[0][9], dut_out[0][10], dut_out[0][11],
                     dut_out[0][12], dut_out[0][13], dut_out[0][14], dut_out[0][15]);
            
            $display("");
            if (errors == 0) begin
                $display("  >>> PASSED: %0d comparisons, 0 errors <<<", total);
            end else begin
                $display("  >>> FAILED: %0d comparisons, %0d errors <<<", total, errors);
                total_errors = total_errors + errors;
            end
        end
    endtask
    
    // ========================================================================
    // 单次测试运行
    // ========================================================================
    task run_single_test(input integer t_mode, input integer t_acc, input integer use_random);
        begin
            test_mode = t_mode;
            test_acc = t_acc;
            num_logical_ch = (t_mode == 0) ? 8 : 4;
            nibble_phases = (t_mode == 0) ? 2 : 4;
            
            $display("");
            $display("═══════════════════════════════════════════════════════════");
            $display("  TEST: %s, ACC=%0d, %s data",
                     (t_mode == 0) ? "INT8" : "INT16",
                     t_acc,
                     use_random ? "RANDOM" : "SIMPLE");
            $display("═══════════════════════════════════════════════════════════");
            
            // 配置
            mode = (t_mode == 0) ? `MODE_INT8 : `MODE_INT16;
            acc_depth = t_acc;
            num_rows = TEST_ROWS;
            wei_base_addr = 0;
            act_base_addr = CYCLE;
            out_base_addr = 0;
            
            // 生成数据
            $display("[1] Generating weights...");
            generate_weights(use_random);
            
            $display("[2] Loading weights to IBUF...");
            load_weights();
            
            $display("[3] Generating activations...");
            generate_activations(use_random);
            
            $display("[4] Loading activations to IBUF...");
            load_activations();
            
            $display("[5] Computing golden model...");
            compute_golden();
            
            // 运行 DUT
            $display("[6] Running DUT...");
            wait(ready); repeat(5) @(posedge clk);
            @(posedge clk); start <= 1'b1; @(posedge clk); start <= 1'b0;
            wait(done); repeat(10) @(posedge clk);
            
            // 验证
            $display("[7] Reading and verifying results...");
            read_results();
            verify_results();
            
            repeat(20) @(posedge clk);
        end
    endtask
    
    // ========================================================================
    // 主测试流程
    // ========================================================================
    initial begin
        rst_n = 0; start = 0;
        mode = `MODE_INT8; acc_depth = 0; num_rows = TEST_ROWS;
        wei_base_addr = 0; act_base_addr = CYCLE; out_base_addr = 0;
        ibuf_ena = 0; ibuf_wea = 0; ibuf_addra = 0; ibuf_dina = 0;
        obuf_ena = 0; obuf_wea = 0; obuf_addra = 0; obuf_dina = 0;
        total_errors = 0;
        
        repeat(10) @(posedge clk); rst_n = 1; repeat(10) @(posedge clk);
        
        $display("");
        $display("╔═══════════════════════════════════════════════════════════╗");
        $display("║           DCIM_Macro Comprehensive Test Suite            ║");
        $display("╚═══════════════════════════════════════════════════════════╝");
        
        // ====================================================================
        // Test 1: INT8, 无累加, 简单数据
        // ====================================================================
        run_single_test(0, 0, 0);
        
        // ====================================================================
        // Test 2: INT8, 无累加, 随机数据
        // ====================================================================
        run_single_test(0, 0, 1);
        
        // ====================================================================
        // Test 3: INT8, ACC=2, 随机数据
        // ====================================================================
        run_single_test(0, 2, 1);
        
        // ====================================================================
        // Test 4: INT16, 无累加, 简单数据
        // ====================================================================
        run_single_test(1, 0, 0);
        
        // ====================================================================
        // Test 5: INT16, 无累加, 随机数据
        // ====================================================================
        run_single_test(1, 0, 1);
        
        // ====================================================================
        // Test 6: INT16, ACC=2, 随机数据
        // ====================================================================
        run_single_test(1, 2, 1);
        
        // ====================================================================
        // 最终结果
        // ====================================================================
        $display("");
        $display("╔═══════════════════════════════════════════════════════════╗");
        if (total_errors == 0) begin
            $display("║     ALL TESTS PASSED                                     ║");
        end else begin
            $display("║     TESTS FAILED: %0d total errors                        ║", total_errors);
        end
        $display("╚═══════════════════════════════════════════════════════════╝");
        $display("");
        
        repeat(100) @(posedge clk);
        $finish;
    end
    
    initial begin #5000000; $display("TIMEOUT!"); $finish; end
    
    initial begin
        $fsdbDumpfile("dcim_macro.fsdb");
        $fsdbDumpvars(0, tb_DCIM_Macro, "+all");
        $fsdbDumpMDA();
    end

endmodule
