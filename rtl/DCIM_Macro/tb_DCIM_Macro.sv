`timescale 1ns / 1ps
`include "../../ref/DCIM/src/inc/para.v"

// ============================================================================
// tb_DCIM_Macro - 完整测试平台
// ============================================================================
// 测试覆盖：
//   1. INT8/INT16 基本功能
//   2. 累加功能 (ACC=0,2,4,8)
//   3. 边界值测试（最大/最小值）
//   4. 全零/全一权重
//   5. 随机数据测试
//   6. 连续多次计算
//   7. 不同基地址测试
// ============================================================================

module tb_DCIM_Macro;

    localparam WD1 = 4, CH_IN = 16, CH_OUT = 16, SRAM_DP = 128, CYCLE = 8, ACC = 16;
    localparam BUF_ADDR_WIDTH = 12, BUF_DATA_WIDTH = 128;
    localparam SRAM_WD = CH_IN * CH_OUT * WD1 / CYCLE;  // 128
    localparam WD2 = 2*WD1 + $clog2(CH_IN);              // 12
    localparam WD3 = WD2 + $clog2(ACC);                  // 16
    localparam MAX_TEST_ROWS = 16;
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
    // 测试数据存储
    // ========================================================================
    reg signed [3:0] weight_nibble [0:CH_IN-1][0:CH_OUT-1];
    reg signed [15:0] activation [0:MAX_TEST_ROWS-1][0:CH_IN-1];
    reg signed [31:0] golden [0:MAX_TEST_ROWS-1][0:7];
    reg signed [WD3-1:0] dut_out [0:MAX_TEST_ROWS-1][0:CH_OUT-1];
    
    integer num_logical_ch;
    integer test_mode;
    integer test_acc;
    integer test_rows;
    integer total_errors;
    integer total_tests;
    integer passed_tests;
    
    // 随机种子
    integer seed;
    
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
    // 权重生成任务
    // ========================================================================
    task generate_weights_pattern(input integer pattern);
        integer i, j;
        begin
            for (i = 0; i < CH_IN; i++) begin
                for (j = 0; j < CH_OUT; j++) begin
                    case (pattern)
                        0: weight_nibble[i][j] = 4'sd1;                          // 全1
                        1: weight_nibble[i][j] = 4'sd0;                          // 全0
                        2: weight_nibble[i][j] = 4'sd7;                          // 最大正值
                        3: weight_nibble[i][j] = -4'sd8;                         // 最小负值
                        4: weight_nibble[i][j] = ((i + j) % 15) - 7;             // 递增模式
                        5: weight_nibble[i][j] = ((i * j) % 15) - 7;             // 乘积模式
                        6: weight_nibble[i][j] = (i == j) ? 4'sd1 : 4'sd0;       // 单位矩阵
                        7: weight_nibble[i][j] = $random(seed) % 15 - 7;         // 真随机
                        default: weight_nibble[i][j] = 4'sd1;
                    endcase
                end
            end
        end
    endtask
    
    task load_weights_at(input [BUF_ADDR_WIDTH-1:0] base);
        integer addr, bit_idx, nibble_idx, in_ch, out_ch;
        reg [SRAM_WD-1:0] sram_word;
        begin
            for (addr = 0; addr < CYCLE; addr++) begin
                sram_word = 0;
                for (bit_idx = 0; bit_idx < SRAM_WD; bit_idx = bit_idx + WD1) begin
                    nibble_idx = addr * (SRAM_WD/WD1) + bit_idx/WD1;
                    out_ch = nibble_idx / CH_IN;
                    in_ch = nibble_idx % CH_IN;
                    if (in_ch < CH_IN && out_ch < CH_OUT)
                        sram_word[bit_idx +: WD1] = weight_nibble[in_ch][out_ch];
                end
                write_ibuf(base + addr, sram_word);
            end
        end
    endtask
    
    // ========================================================================
    // 激活数据生成任务
    // ========================================================================
    task generate_activations_pattern(input integer pattern, input integer rows);
        integer row, ch;
        begin
            for (row = 0; row < rows; row++) begin
                for (ch = 0; ch < CH_IN; ch++) begin
                    case (pattern)
                        0: begin  // 简单递增
                            if (test_mode == 0)
                                activation[row][ch] = row + 1;
                            else
                                activation[row][ch] = row + 1;
                        end
                        1: begin  // 全1
                            activation[row][ch] = 1;
                        end
                        2: begin  // 全0
                            activation[row][ch] = 0;
                        end
                        3: begin  // 最大值
                            if (test_mode == 0)
                                activation[row][ch] = 127;
                            else
                                activation[row][ch] = 32767;
                        end
                        4: begin  // 最小值
                            if (test_mode == 0)
                                activation[row][ch] = -128;
                            else
                                activation[row][ch] = -32768;
                        end
                        5: begin  // 交替正负
                            if (test_mode == 0)
                                activation[row][ch] = ((row + ch) % 2 == 0) ? 100 : -100;
                            else
                                activation[row][ch] = ((row + ch) % 2 == 0) ? 10000 : -10000;
                        end
                        6: begin  // 固定模式
                            if (test_mode == 0)
                                activation[row][ch] = ((row * CH_IN + ch) % 255) - 127;
                            else
                                activation[row][ch] = ((row * CH_IN + ch) % 65535) - 32767;
                        end
                        7: begin  // 真随机
                            if (test_mode == 0)
                                activation[row][ch] = $random(seed) % 256 - 128;
                            else
                                activation[row][ch] = $random(seed) % 65536 - 32768;
                        end
                        default: activation[row][ch] = row + 1;
                    endcase
                end
            end
        end
    endtask
    
    task load_activations_at(input [BUF_ADDR_WIDTH-1:0] base, input integer rows);
        integer row, ch;
        reg [BUF_DATA_WIDTH-1:0] act_word_lo, act_word_hi;
        begin
            for (row = 0; row < rows; row++) begin
                if (test_mode == 0) begin
                    act_word_lo = 0;
                    for (ch = 0; ch < CH_IN; ch++)
                        act_word_lo[ch*8 +: 8] = activation[row][ch][7:0];
                    write_ibuf(base + row, act_word_lo);
                end else begin
                    act_word_lo = 0;
                    act_word_hi = 0;
                    for (ch = 0; ch < 8; ch++) begin
                        act_word_lo[ch*16 +: 16] = activation[row][ch];
                        act_word_hi[ch*16 +: 16] = activation[row][ch+8];
                    end
                    write_ibuf(base + row*2, act_word_lo);
                    write_ibuf(base + row*2 + 1, act_word_hi);
                end
            end
        end
    endtask
    
    // ========================================================================
    // Golden Model 计算
    // ========================================================================
    task compute_golden(input integer rows);
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
            num_acc_groups = rows / acc_val;
            
            for (row = 0; row < MAX_TEST_ROWS; row++)
                for (out_ch = 0; out_ch < 8; out_ch++)
                    golden[row][out_ch] = 0;
            
            for (acc_group = 0; acc_group < num_acc_groups; acc_group++) begin
                for (out_ch = 0; out_ch < num_logical_ch; out_ch++) begin
                    sum = 0;
                    
                    for (row_in_group = 0; row_in_group < acc_val; row_in_group++) begin
                        row = acc_group * acc_val + row_in_group;
                        
                        for (in_ch = 0; in_ch < CH_IN; in_ch++) begin
                            if (test_mode == 0) begin
                                phys_ch_lo = out_ch * 2 + 2;
                                phys_ch_hi = out_ch * 2 + 3;
                                if (phys_ch_lo >= CH_OUT) phys_ch_lo = CH_OUT - 2;
                                if (phys_ch_hi >= CH_OUT) phys_ch_hi = CH_OUT - 1;
                                w8 = {weight_nibble[in_ch][phys_ch_hi], weight_nibble[in_ch][phys_ch_lo]};
                                a8 = activation[row][in_ch][7:0];
                                sum = sum + ($signed(a8) * $signed(w8));
                            end else begin
                                integer base_ch, ch0, ch1, ch2, ch3;
                                base_ch = out_ch * 4;
                                ch0 = base_ch;
                                ch1 = base_ch + 1;
                                ch2 = base_ch + 2;
                                ch3 = base_ch + 3;
                                if (ch3 >= CH_OUT) begin
                                    ch0 = CH_OUT - 4; ch1 = CH_OUT - 3;
                                    ch2 = CH_OUT - 2; ch3 = CH_OUT - 1;
                                end
                                w16 = {weight_nibble[in_ch][ch3], weight_nibble[in_ch][ch2],
                                       weight_nibble[in_ch][ch1], weight_nibble[in_ch][ch0]};
                                a16 = activation[row][in_ch];
                                sum = sum + ($signed(a16) * $signed(w16));
                            end
                        end
                    end
                    
                    if (test_mode == 0)
                        golden[acc_group][out_ch] = $signed(sum[WD3-1:0]);
                    else
                        golden[acc_group][out_ch] = sum;
                end
            end
        end
    endtask
    
    // ========================================================================
    // 结果读取和验证
    // ========================================================================
    task read_results_at(input [BUF_ADDR_WIDTH-1:0] base, input integer rows);
        integer row, ch, num_outputs, acc_val;
        reg [BUF_DATA_WIDTH-1:0] result_lo, result_hi;
        reg [255:0] result_full;
        begin
            acc_val = (test_acc == 0) ? 1 : test_acc;
            num_outputs = rows / acc_val;
            
            for (row = 0; row < num_outputs; row++) begin
                read_obuf(base + row * 2, result_lo);
                read_obuf(base + row * 2 + 1, result_hi);
                result_full = {result_hi, result_lo};
                
                for (ch = 0; ch < CH_OUT; ch++) begin
                    dut_out[row][ch] = $signed(result_full[ch*16 +: 16]);
                end
            end
        end
    endtask
    
    function integer verify_results_func(input integer rows);
        integer row, ch, errors, num_outputs, acc_val, phys_ch_idx;
        reg signed [31:0] dut_val, exp_val;
        begin
            errors = 0;
            acc_val = (test_acc == 0) ? 1 : test_acc;
            num_outputs = rows / acc_val;
            
            for (row = 0; row < num_outputs; row++) begin
                for (ch = 0; ch < num_logical_ch; ch++) begin
                    if (test_mode == 0) begin
                        phys_ch_idx = ch * 2 + 2;
                        if (phys_ch_idx >= CH_OUT) phys_ch_idx = CH_OUT - 2;
                        dut_val = dut_out[row][phys_ch_idx];
                    end else begin
                        phys_ch_idx = ch * 4;
                        dut_val = {dut_out[row][phys_ch_idx+1], dut_out[row][phys_ch_idx]};
                    end
                    exp_val = golden[row][ch];
                    
                    if (dut_val !== exp_val) begin
                        errors = errors + 1;
                        if (errors <= 3)
                            $display("    [ERR] Row %0d Ch %0d: DUT=%0d, Golden=%0d", row, ch, dut_val, exp_val);
                    end
                end
            end
            verify_results_func = errors;
        end
    endfunction
    
    // ========================================================================
    // 单次测试运行
    // ========================================================================
    task run_test(
        input [127:0] test_name,
        input integer t_mode,
        input integer t_acc,
        input integer t_rows,
        input integer wei_pattern,
        input integer act_pattern,
        input [BUF_ADDR_WIDTH-1:0] wei_base,
        input [BUF_ADDR_WIDTH-1:0] act_base,
        input [BUF_ADDR_WIDTH-1:0] out_base
    );
        integer errors;
        begin
            test_mode = t_mode;
            test_acc = t_acc;
            test_rows = t_rows;
            num_logical_ch = (t_mode == 0) ? 8 : 4;
            
            total_tests = total_tests + 1;
            $display("");
            $display("─────────────────────────────────────────────────────────────");
            $display("  Test %0d: %s", total_tests, test_name);
            $display("  Mode=%s, ACC=%0d, Rows=%0d, WeiPat=%0d, ActPat=%0d",
                     (t_mode == 0) ? "INT8" : "INT16", t_acc, t_rows, wei_pattern, act_pattern);
            $display("─────────────────────────────────────────────────────────────");
            
            // 等待 DUT 就绪（IDLE 状态会自动清除累加器）
            wait(ready);
            repeat(5) @(posedge clk);
            
            // 配置
            mode = (t_mode == 0) ? `MODE_INT8 : `MODE_INT16;
            acc_depth = t_acc;
            num_rows = t_rows;
            wei_base_addr = wei_base;
            act_base_addr = act_base;
            out_base_addr = out_base;
            
            // 生成和加载数据
            generate_weights_pattern(wei_pattern);
            load_weights_at(wei_base);
            generate_activations_pattern(act_pattern, t_rows);
            load_activations_at(act_base, t_rows);
            compute_golden(t_rows);
            
            // 运行 DUT
            wait(ready); repeat(5) @(posedge clk);
            @(posedge clk); start <= 1'b1; @(posedge clk); start <= 1'b0;
            
            // 等待完成，带超时
            fork
                begin
                    wait(done);
                end
                begin
                    repeat(100000) @(posedge clk);
                    $display("  [TIMEOUT] Test did not complete in time!");
                    $display("  State=%0d, row_cnt=%0d, result_cnt=%0d", 
                             dut.state, dut.row_cnt, dut.result_cnt);
                end
            join_any
            disable fork;
            
            repeat(10) @(posedge clk);
            
            // 验证
            read_results_at(out_base, t_rows);
            errors = verify_results_func(t_rows);
            
            if (errors == 0) begin
                $display("  >>> PASSED <<<");
                passed_tests = passed_tests + 1;
            end else begin
                $display("  >>> FAILED: %0d errors <<<", errors);
                total_errors = total_errors + errors;
            end
            
            repeat(10) @(posedge clk);
        end
    endtask
    
    // ========================================================================
    // 主测试流程
    // ========================================================================
    initial begin
        rst_n = 0; start = 0;
        mode = `MODE_INT8; acc_depth = 0; num_rows = 8;
        wei_base_addr = 0; act_base_addr = CYCLE; out_base_addr = 0;
        ibuf_ena = 0; ibuf_wea = 0; ibuf_addra = 0; ibuf_dina = 0;
        obuf_ena = 0; obuf_wea = 0; obuf_addra = 0; obuf_dina = 0;
        total_errors = 0;
        total_tests = 0;
        passed_tests = 0;
        seed = 12345;
        
        repeat(10) @(posedge clk); rst_n = 1; repeat(10) @(posedge clk);
        
        $display("");
        $display("╔═══════════════════════════════════════════════════════════════╗");
        $display("║         DCIM_Macro Comprehensive Test Suite v2.0             ║");
        $display("╚═══════════════════════════════════════════════════════════════╝");
        
        // ====================================================================
        // 基本功能测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 1: Basic Functionality Tests");
        
        run_test("INT8 Basic (all-1 weights)", 0, 0, 8, 0, 0, 0, 8, 0);
        run_test("INT16 Basic (all-1 weights)", 1, 0, 8, 0, 0, 0, 8, 0);
        
        // ====================================================================
        // 累加功能测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 2: Accumulation Tests");
        
        run_test("INT8 ACC=2", 0, 2, 8, 4, 6, 0, 8, 0);
        run_test("INT8 ACC=4", 0, 4, 8, 4, 6, 0, 8, 0);
        run_test("INT8 ACC=8", 0, 8, 8, 4, 6, 0, 8, 0);
        run_test("INT16 ACC=2", 1, 2, 8, 4, 6, 0, 8, 0);
        run_test("INT16 ACC=4", 1, 4, 8, 4, 6, 0, 8, 0);
        
        // ====================================================================
        // 边界值测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 3: Boundary Value Tests");
        
        run_test("INT8 Max Weight (+7)", 0, 0, 8, 2, 0, 0, 8, 0);
        run_test("INT8 Min Weight (-8)", 0, 0, 8, 3, 0, 0, 8, 0);
        run_test("INT8 Max Activation (+127)", 0, 0, 8, 0, 3, 0, 8, 0);
        run_test("INT8 Min Activation (-128)", 0, 0, 8, 0, 4, 0, 8, 0);
        run_test("INT16 Max Activation (+32767)", 1, 0, 8, 0, 3, 0, 8, 0);
        run_test("INT16 Min Activation (-32768)", 1, 0, 8, 0, 4, 0, 8, 0);
        
        // ====================================================================
        // 特殊模式测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 4: Special Pattern Tests");
        
        run_test("INT8 Zero Weights", 0, 0, 8, 1, 6, 0, 8, 0);
        run_test("INT8 Zero Activations", 0, 0, 8, 4, 2, 0, 8, 0);
        run_test("INT8 Identity-like Weights", 0, 0, 8, 6, 0, 0, 8, 0);
        run_test("INT8 Alternating Signs", 0, 0, 8, 4, 5, 0, 8, 0);
        run_test("INT16 Alternating Signs", 1, 0, 8, 4, 5, 0, 8, 0);
        
        // ====================================================================
        // 随机数据测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 5: Random Data Tests");
        
        seed = 11111;
        run_test("INT8 Random #1", 0, 0, 8, 7, 7, 0, 8, 0);
        seed = 22222;
        run_test("INT8 Random #2", 0, 0, 8, 7, 7, 0, 8, 0);
        seed = 33333;
        run_test("INT8 Random ACC=2", 0, 2, 8, 7, 7, 0, 8, 0);
        seed = 44444;
        run_test("INT16 Random #1", 1, 0, 8, 7, 7, 0, 8, 0);
        seed = 55555;
        run_test("INT16 Random ACC=2", 1, 2, 8, 7, 7, 0, 8, 0);
        
        // ====================================================================
        // 不同行数测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 6: Variable Row Count Tests");
        
        run_test("INT8 4 Rows", 0, 0, 4, 4, 6, 0, 8, 0);
        run_test("INT8 16 Rows", 0, 0, 16, 4, 6, 0, 8, 0);
        run_test("INT8 16 Rows ACC=8", 0, 8, 16, 4, 6, 0, 8, 0);
        run_test("INT16 4 Rows", 1, 0, 4, 4, 6, 0, 8, 0);
        
        // ====================================================================
        // 不同基地址测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 7: Different Base Address Tests");
        
        run_test("INT8 Wei@100 Act@200 Out@300", 0, 0, 8, 4, 6, 100, 200, 300);
        run_test("INT16 Wei@50 Act@100 Out@200", 1, 0, 8, 4, 6, 50, 100, 200);
        
        // ====================================================================
        // 连续计算测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 8: Consecutive Computation Tests");
        
        run_test("INT8 Consecutive #1", 0, 0, 8, 4, 6, 0, 8, 0);
        run_test("INT8 Consecutive #2", 0, 0, 8, 5, 7, 0, 8, 100);
        run_test("INT8 Consecutive #3", 0, 2, 8, 7, 7, 0, 8, 200);
        
        // ====================================================================
        // 极端值组合测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 9: Extreme Value Combination Tests");
        
        run_test("INT8 Max*Max (+7*+127)", 0, 0, 8, 2, 3, 0, 8, 0);
        run_test("INT8 Min*Min (-8*-128)", 0, 0, 8, 3, 4, 0, 8, 0);
        run_test("INT8 Max*Min (+7*-128)", 0, 0, 8, 2, 4, 0, 8, 0);
        run_test("INT8 Min*Max (-8*+127)", 0, 0, 8, 3, 3, 0, 8, 0);
        run_test("INT16 Max*Max", 1, 0, 8, 2, 3, 0, 8, 0);
        run_test("INT16 Min*Min", 1, 0, 8, 3, 4, 0, 8, 0);
        
        // ====================================================================
        // 累加深度边界测试
        // ====================================================================
        $display("");
        $display("▶ SECTION 10: Accumulation Depth Boundary Tests");
        
        run_test("INT8 ACC=1 (8 rows)", 0, 1, 8, 4, 6, 0, 8, 0);
        run_test("INT8 ACC=16 (16 rows)", 0, 16, 16, 4, 6, 0, 8, 0);
        run_test("INT16 ACC=8 (8 rows)", 1, 8, 8, 4, 6, 0, 8, 0);
        
        // ====================================================================
        // 更多随机测试（不同种子）
        // ====================================================================
        $display("");
        $display("▶ SECTION 11: Additional Random Tests");
        
        seed = 66666;
        run_test("INT8 Random #3", 0, 0, 8, 7, 7, 0, 8, 0);
        seed = 77777;
        run_test("INT8 Random ACC=4", 0, 4, 8, 7, 7, 0, 8, 0);
        seed = 88888;
        run_test("INT16 Random #2", 1, 0, 8, 7, 7, 0, 8, 0);
        seed = 99999;
        run_test("INT16 Random ACC=4", 1, 4, 8, 7, 7, 0, 8, 0);
        
        // ====================================================================
        // 混合模式测试（INT8 和 INT16 交替）
        // ====================================================================
        $display("");
        $display("▶ SECTION 12: Mixed Mode Tests");
        
        run_test("INT8 after INT16", 0, 0, 8, 4, 6, 0, 8, 0);
        run_test("INT16 after INT8", 1, 0, 8, 4, 6, 0, 8, 0);
        run_test("INT8 ACC after INT16", 0, 2, 8, 4, 6, 0, 8, 0);
        run_test("INT16 ACC after INT8", 1, 2, 8, 4, 6, 0, 8, 0);
        
        // ====================================================================
        // 最终结果
        // ====================================================================
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("                      TEST SUMMARY");
        $display("═══════════════════════════════════════════════════════════════");
        $display("  Total Tests:  %0d", total_tests);
        $display("  Passed:       %0d", passed_tests);
        $display("  Failed:       %0d", total_tests - passed_tests);
        $display("  Total Errors: %0d", total_errors);
        $display("═══════════════════════════════════════════════════════════════");
        
        if (total_errors == 0) begin
            $display("");
            $display("  ╔═══════════════════════════════════════╗");
            $display("  ║     ✓ ALL %0d TESTS PASSED            ║", total_tests);
            $display("  ╚═══════════════════════════════════════╝");
        end else begin
            $display("");
            $display("  ╔═══════════════════════════════════════╗");
            $display("  ║     ✗ SOME TESTS FAILED               ║");
            $display("  ╚═══════════════════════════════════════╝");
        end
        $display("");
        
        repeat(100) @(posedge clk);
        $finish;
    end
    
    initial begin #50000000; $display("TIMEOUT!"); $finish; end
    
    initial begin
        $fsdbDumpfile("dcim_macro.fsdb");
        $fsdbDumpvars(0, tb_DCIM_Macro, "+all");
        $fsdbDumpMDA();
    end

endmodule
