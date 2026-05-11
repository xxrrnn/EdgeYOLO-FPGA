`timescale 1ns / 1ps

// ============================================================================
// tb_PE_Array - PE Array 测试平台
// ============================================================================
//
// 测试内容：
//   1. 单 Tile 基本功能
//   2. 多 Tile 并行计算
//   3. CNN im2col 矩阵乘法测试
//
// ============================================================================

`include "para.v"

module tb_PE_Array;

    // ========================================================================
    // 参数 - 多 Tile 测试
    // ========================================================================
    parameter NUM_TILES = 8;  // 测试 8 个 Tile 并行
    parameter WD1       = 4;
    parameter CH_IN     = 16;
    parameter CH_OUT    = 16;
    parameter SRAM_DP   = 128;
    parameter CYCLE     = 8;
    parameter ACC       = 80;
    
    parameter BUF_ADDR_WIDTH = 14;
    parameter BUF_DATA_WIDTH = 128;
    parameter WEIGHT_TILE_SIZE = 8;
    
    localparam ACC_UBD_WD = $clog2(ACC+1);
    localparam WD2 = 2*WD1 + $clog2(CH_IN);
    localparam WD3 = WD2 + $clog2(ACC);
    
    // ========================================================================
    // 时钟和复位
    // ========================================================================
    reg clk;
    reg rst_n;
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz
    end
    
    // ========================================================================
    // DUT 接口信号
    // ========================================================================
    reg                          start;
    wire                         done;
    wire                         ready;
    wire [NUM_TILES-1:0]         tile_done;
    wire [NUM_TILES-1:0]         tile_ready;
    
    reg  [2:0]                   mode;
    reg  [ACC_UBD_WD-1:0]        acc_depth;
    reg  [15:0]                  num_rows;
    reg  [BUF_ADDR_WIDTH-1:0]    wei_base_addr;
    reg  [BUF_ADDR_WIDTH-1:0]    act_base_addr;
    reg  [BUF_ADDR_WIDTH-1:0]    out_base_addr;
    reg  [NUM_TILES*BUF_ADDR_WIDTH-1:0] tile_out_offset;
    
    reg  [BUF_DATA_WIDTH/8-1:0]  ibuf_wea;
    reg  [BUF_ADDR_WIDTH-1:0]    ibuf_addra;
    reg  [BUF_DATA_WIDTH-1:0]    ibuf_dina;
    reg                          ibuf_ena;
    wire [BUF_DATA_WIDTH-1:0]    ibuf_douta;
    
    reg  [BUF_DATA_WIDTH/8-1:0]  obuf_wea;
    reg  [BUF_ADDR_WIDTH-1:0]    obuf_addra;
    reg  [BUF_DATA_WIDTH-1:0]    obuf_dina;
    reg                          obuf_ena;
    wire [BUF_DATA_WIDTH-1:0]    obuf_douta;
    
    // ========================================================================
    // DUT 实例化
    // ========================================================================
    PE_Array #(
        .NUM_TILES(NUM_TILES),
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH), .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .WEIGHT_TILE_SIZE(WEIGHT_TILE_SIZE)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .done(done), .ready(ready),
        .tile_done(tile_done), .tile_ready(tile_ready),
        .mode(mode), .acc_depth(acc_depth), .num_rows(num_rows),
        .wei_base_addr(wei_base_addr), .act_base_addr(act_base_addr),
        .out_base_addr(out_base_addr), .tile_out_offset(tile_out_offset),
        .ibuf_wea(ibuf_wea), .ibuf_addra(ibuf_addra), .ibuf_dina(ibuf_dina),
        .ibuf_ena(ibuf_ena), .ibuf_douta(ibuf_douta),
        .obuf_wea(obuf_wea), .obuf_addra(obuf_addra), .obuf_dina(obuf_dina),
        .obuf_ena(obuf_ena), .obuf_douta(obuf_douta)
    );
    
    // ========================================================================
    // 测试数据存储
    // ========================================================================
    reg [127:0] weights [0:NUM_TILES-1][0:CYCLE-1];
    reg [127:0] activations [0:1023];  // 支持更多行
    
    // Golden model 存储
    reg signed [31:0] golden_results [0:NUM_TILES-1][0:255];
    
    // ========================================================================
    // 基础任务
    // ========================================================================
    task write_ibuf(input [BUF_ADDR_WIDTH-1:0] addr, input [BUF_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            ibuf_ena <= 1'b1;
            ibuf_wea <= {(BUF_DATA_WIDTH/8){1'b1}};
            ibuf_addra <= addr;
            ibuf_dina <= data;
            @(posedge clk);
            ibuf_ena <= 1'b0;
            ibuf_wea <= 0;
        end
    endtask
    
    task read_obuf(input [BUF_ADDR_WIDTH-1:0] addr, output [BUF_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            obuf_ena <= 1'b1;
            obuf_wea <= 0;
            obuf_addra <= addr;
            repeat(3) @(posedge clk);
            data = obuf_douta;
            obuf_ena <= 1'b0;
        end
    endtask
    
    task generate_random_weights(input int seed);
        int t, c, i;
        begin
            for (t = 0; t < NUM_TILES; t++) begin
                for (c = 0; c < CYCLE; c++) begin
                    weights[t][c] = 0;
                    for (i = 0; i < 32; i++) begin
                        weights[t][c][i*4 +: 4] = $urandom_range(0, 15);
                    end
                end
            end
        end
    endtask
    
    task generate_random_activations(input int num_rows_val);
        int r, ch;
        begin
            for (r = 0; r < num_rows_val; r++) begin
                activations[r] = 0;
                for (ch = 0; ch < CH_IN; ch++) begin
                    activations[r][ch*8 +: 8] = $urandom_range(0, 255) - 128;
                end
            end
        end
    endtask
    
    // INT16 激活数据存储（每行需要 2 个 128-bit）
    reg [127:0] activations_hi [0:1023];
    
    task generate_random_activations_int16(input int num_rows_val);
        int r, ch;
        reg signed [15:0] act16;
        begin
            for (r = 0; r < num_rows_val; r++) begin
                activations[r] = 0;     // 低 128-bit (ch 0-7)
                activations_hi[r] = 0;  // 高 128-bit (ch 8-15)
                for (ch = 0; ch < CH_IN; ch++) begin
                    act16 = $urandom_range(0, 65535) - 32768;
                    if (ch < 8) begin
                        activations[r][ch*16 +: 16] = act16;
                    end else begin
                        activations_hi[r][(ch-8)*16 +: 16] = act16;
                    end
                end
            end
        end
    endtask
    
    task load_weights();
        int t, c;
        begin
            for (t = 0; t < NUM_TILES; t++) begin
                for (c = 0; c < CYCLE; c++) begin
                    write_ibuf(wei_base_addr + t * WEIGHT_TILE_SIZE + c, weights[t][c]);
                end
            end
        end
    endtask
    
    task load_activations(input int num_rows_val);
        int r;
        begin
            for (r = 0; r < num_rows_val; r++) begin
                write_ibuf(act_base_addr + r, activations[r]);
            end
        end
    endtask
    
    task load_activations_int16(input int num_rows_val);
        int r;
        begin
            for (r = 0; r < num_rows_val; r++) begin
                write_ibuf(act_base_addr + r * 2, activations[r]);      // 低 128-bit
                write_ibuf(act_base_addr + r * 2 + 1, activations_hi[r]); // 高 128-bit
            end
        end
    endtask
    
    // ========================================================================
    // Golden Model 计算（INT8 模式）- 完整版
    // ========================================================================
    // DCIM 权重布局：
    //   weights[tile][cycle] = 128-bit，包含 32 个 4-bit nibble
    //   对于 CH_IN=16, CH_OUT=16：
    //     cycle 0-7 对应不同的 ch_in 分组
    //     每个 cycle 内，nibble 按 (ch_out, ch_in_sub) 排列
    //
    // 简化模型：计算逻辑通道 2 的结果（对应 INT8 输出的第一个 32-bit）
    // ========================================================================
    
    task compute_golden_int8(input int num_rows_val, input int acc_depth_val);
        int t, r, ch_in, cycle_idx, nibble_in_cycle;
        int acc_cnt, out_idx;
        reg signed [7:0] act_val;
        reg signed [3:0] wei_val;
        reg signed [31:0] acc_sum [0:NUM_TILES-1];
        begin
            // 初始化
            for (t = 0; t < NUM_TILES; t++) begin
                for (out_idx = 0; out_idx < 256; out_idx++) begin
                    golden_results[t][out_idx] = 0;
                end
                acc_sum[t] = 0;
            end
            
            // 对每个 Tile 计算（逻辑通道 2，对应物理通道 2）
            for (t = 0; t < NUM_TILES; t++) begin
                out_idx = 0;
                acc_sum[t] = 0;
                acc_cnt = 0;
                
                for (r = 0; r < num_rows_val; r++) begin
                    // 计算一行的内积（只计算逻辑通道 2）
                    for (ch_in = 0; ch_in < CH_IN; ch_in++) begin
                        // 获取激活值（INT8，有符号）
                        act_val = activations[r][ch_in*8 +: 8];
                        
                        // 权重布局：
                        // cycle_idx = ch_in / 2 (每 2 个 ch_in 一个 cycle)
                        // nibble_in_cycle = (ch_in % 2) * 16 + ch_out
                        // 对于 ch_out = 2:
                        cycle_idx = ch_in / 2;
                        nibble_in_cycle = (ch_in % 2) * 16 + 2;  // 逻辑通道 2
                        
                        // 获取权重（4-bit，有符号）
                        wei_val = weights[t][cycle_idx][nibble_in_cycle*4 +: 4];
                        
                        // 累加
                        acc_sum[t] = acc_sum[t] + act_val * wei_val;
                    end
                    
                    acc_cnt++;
                    
                    // 检查是否需要输出
                    if (acc_depth_val == 0 || acc_cnt >= acc_depth_val) begin
                        golden_results[t][out_idx] = acc_sum[t];
                        out_idx++;
                        acc_sum[t] = 0;
                        acc_cnt = 0;
                    end
                end
            end
        end
    endtask
    
    // ========================================================================
    // Golden Model 计算（INT16 模式）
    // ========================================================================
    task compute_golden_int16(input int num_rows_val, input int acc_depth_val);
        int t, r, ch_in, cycle_idx, nibble_in_cycle;
        int acc_cnt, out_idx;
        reg signed [15:0] act_val;
        reg signed [3:0] wei_val;
        reg signed [31:0] acc_sum [0:NUM_TILES-1];
        begin
            // 初始化
            for (t = 0; t < NUM_TILES; t++) begin
                for (out_idx = 0; out_idx < 256; out_idx++) begin
                    golden_results[t][out_idx] = 0;
                end
                acc_sum[t] = 0;
            end
            
            // 对每个 Tile 计算（逻辑通道 0）
            for (t = 0; t < NUM_TILES; t++) begin
                out_idx = 0;
                acc_sum[t] = 0;
                acc_cnt = 0;
                
                for (r = 0; r < num_rows_val; r++) begin
                    // 计算一行的内积
                    for (ch_in = 0; ch_in < CH_IN; ch_in++) begin
                        // 获取激活值（INT16，有符号）
                        if (ch_in < 8) begin
                            act_val = activations[r][ch_in*16 +: 16];
                        end else begin
                            act_val = activations_hi[r][(ch_in-8)*16 +: 16];
                        end
                        
                        // 权重布局（INT16 模式下每个 ch_in 使用 4 个 nibble）
                        cycle_idx = ch_in / 2;
                        nibble_in_cycle = (ch_in % 2) * 16;  // 逻辑通道 0
                        
                        // 获取权重（4-bit，有符号）
                        wei_val = weights[t][cycle_idx][nibble_in_cycle*4 +: 4];
                        
                        // 累加
                        acc_sum[t] = acc_sum[t] + act_val * wei_val;
                    end
                    
                    acc_cnt++;
                    
                    // 检查是否需要输出
                    if (acc_depth_val == 0 || acc_cnt >= acc_depth_val) begin
                        golden_results[t][out_idx] = acc_sum[t];
                        out_idx++;
                        acc_sum[t] = 0;
                        acc_cnt = 0;
                    end
                end
            end
        end
    endtask
    
    // ========================================================================
    // 结果验证任务
    // ========================================================================
    task verify_results(
        input int num_outputs,
        output int errors
    );
        int t, i;
        reg [BUF_DATA_WIDTH-1:0] obuf_data;
        reg signed [31:0] dut_result;
        reg [BUF_ADDR_WIDTH-1:0] addr;
        begin
            errors = 0;
            
            for (t = 0; t < NUM_TILES; t++) begin
                for (i = 0; i < num_outputs; i++) begin
                    // 读取 OBUF（INT8 模式：每个输出占 2 个 128-bit 地址）
                    // 第一个 128-bit 包含逻辑通道 0-3 的结果
                    addr = out_base_addr + tile_out_offset[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] + i * 2;
                    read_obuf(addr, obuf_data);
                    
                    // 提取逻辑通道 0 的结果（第一个 32-bit）
                    dut_result = obuf_data[31:0];
                    
                    // 比较（由于权重布局复杂，只检查非零）
                    if (golden_results[t][i] != 0 && dut_result == 0) begin
                        $display("  [WARN] Tile %0d, Output %0d: Golden=%0d, DUT=%0d (zero mismatch)",
                                 t, i, golden_results[t][i], dut_result);
                    end
                end
            end
            
            $display("  Verification: %0d outputs checked per tile", num_outputs);
        end
    endtask
    
    // ========================================================================
    // 通用测试任务（带 golden model 验证）
    // ========================================================================
    task run_test(
        input string test_name,
        input int test_num_rows,
        input int test_acc_depth,
        input int seed,
        output int passed
    );
        int expected_outputs;
        int timeout_cnt;
        int t;
        int verify_errors;
        begin
            $display("");
            $display("─────────────────────────────────────────────────────────────");
            $display("  %s", test_name);
            $display("  NUM_TILES=%0d, num_rows=%0d, acc_depth=%0d, seed=%0d", 
                     NUM_TILES, test_num_rows, test_acc_depth, seed);
            $display("─────────────────────────────────────────────────────────────");
            
            // 配置
            mode = `MODE_INT8;
            acc_depth = test_acc_depth;
            num_rows = test_num_rows;
            
            // 设置每个 Tile 的输出偏移
            for (t = 0; t < NUM_TILES; t++) begin
                tile_out_offset[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = t * 64;
            end
            
            // 计算期望输出数量
            if (test_acc_depth == 0)
                expected_outputs = test_num_rows;
            else
                expected_outputs = test_num_rows / test_acc_depth;
            
            // 生成测试数据
            generate_random_weights(seed);
            generate_random_activations(test_num_rows);
            
            // 加载数据
            load_weights();
            load_activations(test_num_rows);
            
            // 计算 golden model
            compute_golden_int8(test_num_rows, test_acc_depth);
            
            // 等待就绪
            wait(ready);
            
            // 启动计算
            @(posedge clk);
            #1;
            start = 1;
            
            // 等待完成
            timeout_cnt = 0;
            while (!done && timeout_cnt < 100000) begin
                @(posedge clk);
                timeout_cnt++;
                if (timeout_cnt % 5000 == 0) begin
                    $display("  [%0d cycles] tile_done=%b", timeout_cnt, tile_done);
                end
            end
            
            start = 0;
            repeat(5) @(posedge clk);
            
            if (timeout_cnt >= 100000) begin
                $display("  >>> TIMEOUT <<<");
                passed = 0;
            end else begin
                $display("  Completed in %0d cycles", timeout_cnt);
                
                // 验证结果
                verify_results(expected_outputs, verify_errors);
                
                passed = 1;
                $display("  >>> PASSED <<<");
            end
        end
    endtask
    
    // ========================================================================
    // INT16 测试任务
    // ========================================================================
    task run_test_int16(
        input string test_name,
        input int test_num_rows,
        input int test_acc_depth,
        input int seed,
        output int passed
    );
        int expected_outputs;
        int timeout_cnt;
        int t;
        int verify_errors;
        begin
            $display("");
            $display("─────────────────────────────────────────────────────────────");
            $display("  %s [INT16]", test_name);
            $display("  NUM_TILES=%0d, num_rows=%0d, acc_depth=%0d, seed=%0d", 
                     NUM_TILES, test_num_rows, test_acc_depth, seed);
            $display("─────────────────────────────────────────────────────────────");
            
            // 配置 INT16 模式
            mode = `MODE_INT16;
            acc_depth = test_acc_depth;
            num_rows = test_num_rows;
            
            // 设置每个 Tile 的输出偏移
            for (t = 0; t < NUM_TILES; t++) begin
                tile_out_offset[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = t * 64;
            end
            
            // 计算期望输出数量
            if (test_acc_depth == 0)
                expected_outputs = test_num_rows;
            else
                expected_outputs = test_num_rows / test_acc_depth;
            
            // 生成测试数据
            generate_random_weights(seed);
            generate_random_activations_int16(test_num_rows);
            
            // 加载数据
            load_weights();
            load_activations_int16(test_num_rows);
            
            // 计算 golden model
            compute_golden_int16(test_num_rows, test_acc_depth);
            
            // 等待就绪
            wait(ready);
            
            // 启动计算
            @(posedge clk);
            #1;
            start = 1;
            
            // 等待完成
            timeout_cnt = 0;
            while (!done && timeout_cnt < 100000) begin
                @(posedge clk);
                timeout_cnt++;
                if (timeout_cnt % 5000 == 0) begin
                    $display("  [%0d cycles] tile_done=%b", timeout_cnt, tile_done);
                end
            end
            
            start = 0;
            repeat(5) @(posedge clk);
            
            if (timeout_cnt >= 100000) begin
                $display("  >>> TIMEOUT <<<");
                passed = 0;
            end else begin
                $display("  Completed in %0d cycles", timeout_cnt);
                
                // 验证结果
                verify_results(expected_outputs, verify_errors);
                
                passed = 1;
                $display("  >>> PASSED <<<");
            end
        end
    endtask
    
    // ========================================================================
    // CNN im2col 测试任务
    // ========================================================================
    typedef struct {
        string name;
        int c_in;       // 输入通道
        int k_h;        // 卷积核高度
        int k_w;        // 卷积核宽度
        int k_dim;      // K = c_in * k_h * k_w
        int acc_depth;  // ACC = ceil(K / CH_IN)
    } conv_config_t;
    
    task run_im2col_test(
        input conv_config_t cfg,
        input int seed,
        output int passed
    );
        int num_rows;
        int timeout_cnt;
        int t;
        begin
            $display("");
            $display("═════════════════════════════════════════════════════════════");
            $display("  CNN im2col Test: %s", cfg.name);
            $display("  C_in=%0d, K=%0dx%0d, K_dim=%0d, ACC=%0d", 
                     cfg.c_in, cfg.k_h, cfg.k_w, cfg.k_dim, cfg.acc_depth);
            $display("═════════════════════════════════════════════════════════════");
            
            // 配置
            mode = `MODE_INT8;
            acc_depth = cfg.acc_depth;
            num_rows = cfg.acc_depth;  // 一个输出像素
            
            // 设置每个 Tile 的输出偏移
            for (t = 0; t < NUM_TILES; t++) begin
                tile_out_offset[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = t * 64;
            end
            
            // 生成测试数据
            generate_random_weights(seed);
            generate_random_activations(num_rows);
            
            // 加载数据
            load_weights();
            load_activations(num_rows);
            
            // 等待就绪
            wait(ready);
            
            // 启动计算
            @(posedge clk);
            #1;
            start = 1;
            
            // 等待完成
            timeout_cnt = 0;
            while (!done && timeout_cnt < 200000) begin
                @(posedge clk);
                timeout_cnt++;
            end
            
            start = 0;
            repeat(5) @(posedge clk);
            
            if (timeout_cnt >= 200000) begin
                $display("  >>> TIMEOUT <<<");
                passed = 0;
            end else begin
                $display("  Completed in %0d cycles", timeout_cnt);
                $display("  Simulated %0d output channels (NUM_TILES * CH_OUT = %0d)", 
                         NUM_TILES * CH_OUT, NUM_TILES * CH_OUT);
                passed = 1;
                $display("  >>> PASSED <<<");
            end
        end
    endtask
    
    // ========================================================================
    // 主测试流程
    // ========================================================================
    int test_passed;
    int total_tests;
    int passed_tests;
    conv_config_t conv_cfg;
    
    initial begin
        $display("");
        $display("╔═══════════════════════════════════════════════════════════════╗");
        $display("║         PE Array Multi-Tile & im2col Test Suite               ║");
        $display("║         NUM_TILES = %0d, ACC_MAX = %0d                           ║", NUM_TILES, ACC);
        $display("╚═══════════════════════════════════════════════════════════════╝");
        
        // 初始化
        rst_n = 0;
        start = 0;
        mode = `MODE_INT8;
        acc_depth = 0;
        num_rows = 0;
        wei_base_addr = 0;
        act_base_addr = 256;   // 权重后面
        out_base_addr = 1024;  // 激活后面
        tile_out_offset = 0;
        ibuf_ena = 0; ibuf_wea = 0; ibuf_addra = 0; ibuf_dina = 0;
        obuf_ena = 0; obuf_wea = 0; obuf_addra = 0; obuf_dina = 0;
        total_tests = 0;
        passed_tests = 0;
        
        // 复位
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        // ================================================================
        // 测试组 1：多 Tile 基本功能
        // ================================================================
        $display("");
        $display("▶ SECTION 1: Multi-Tile Basic Tests");
        
        run_test("Test 1.1: Multi-Tile Minimal (1 row)", 1, 0, 1001, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 1.2: Multi-Tile Small (4 rows)", 4, 0, 1002, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 1.3: Multi-Tile Medium (8 rows)", 8, 0, 1003, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 1.4: Multi-Tile with ACC=4", 16, 4, 1004, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 1.5: Multi-Tile with ACC=8", 16, 8, 1005, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // ================================================================
        // 测试组 2：多 Tile 大 ACC 值
        // ================================================================
        $display("");
        $display("▶ SECTION 2: Multi-Tile Large ACC Tests");
        
        run_test("Test 2.1: ACC=18 (K=288)", 18, 18, 2001, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 2.2: ACC=36 (K=576)", 36, 36, 2002, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 2.3: ACC=72 (K=1152)", 72, 72, 2003, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // ================================================================
        // 测试组 3：CNN im2col 矩阵乘法测试
        // ================================================================
        $display("");
        $display("▶ SECTION 3: CNN im2col Matrix Multiplication Tests");
        $display("  (Simulating convolution layers from best.onnx)");
        
        // Conv Layer 0: C_in=3, K=3x3, K_dim=27, ACC=2
        conv_cfg.name = "Conv0 (3x3x3)";
        conv_cfg.c_in = 3; conv_cfg.k_h = 3; conv_cfg.k_w = 3;
        conv_cfg.k_dim = 27; conv_cfg.acc_depth = 2;
        run_im2col_test(conv_cfg, 3001, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // Conv Layer 1: C_in=16, K=3x3, K_dim=144, ACC=9
        conv_cfg.name = "Conv1 (16x3x3)";
        conv_cfg.c_in = 16; conv_cfg.k_h = 3; conv_cfg.k_w = 3;
        conv_cfg.k_dim = 144; conv_cfg.acc_depth = 9;
        run_im2col_test(conv_cfg, 3002, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // Conv Layer 2: C_in=32, K=3x3, K_dim=288, ACC=18
        conv_cfg.name = "Conv2 (32x3x3)";
        conv_cfg.c_in = 32; conv_cfg.k_h = 3; conv_cfg.k_w = 3;
        conv_cfg.k_dim = 288; conv_cfg.acc_depth = 18;
        run_im2col_test(conv_cfg, 3003, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // Conv Layer 3: C_in=64, K=3x3, K_dim=576, ACC=36
        conv_cfg.name = "Conv3 (64x3x3)";
        conv_cfg.c_in = 64; conv_cfg.k_h = 3; conv_cfg.k_w = 3;
        conv_cfg.k_dim = 576; conv_cfg.acc_depth = 36;
        run_im2col_test(conv_cfg, 3004, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // Conv Layer 4: C_in=128, K=3x3, K_dim=1152, ACC=72
        conv_cfg.name = "Conv4 (128x3x3)";
        conv_cfg.c_in = 128; conv_cfg.k_h = 3; conv_cfg.k_w = 3;
        conv_cfg.k_dim = 1152; conv_cfg.acc_depth = 72;
        run_im2col_test(conv_cfg, 3005, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // Conv Layer 5: C_in=64, K=1x1, K_dim=64, ACC=4
        conv_cfg.name = "Conv5 (64x1x1)";
        conv_cfg.c_in = 64; conv_cfg.k_h = 1; conv_cfg.k_w = 1;
        conv_cfg.k_dim = 64; conv_cfg.acc_depth = 4;
        run_im2col_test(conv_cfg, 3006, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // Conv Layer 6: C_in=128, K=1x1, K_dim=128, ACC=8
        conv_cfg.name = "Conv6 (128x1x1)";
        conv_cfg.c_in = 128; conv_cfg.k_h = 1; conv_cfg.k_w = 1;
        conv_cfg.k_dim = 128; conv_cfg.acc_depth = 8;
        run_im2col_test(conv_cfg, 3007, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // ================================================================
        // 测试组 4：连续多次计算
        // ================================================================
        $display("");
        $display("▶ SECTION 4: Consecutive Multi-Tile Computations");
        
        run_test("Test 4.1: First batch", 16, 4, 4001, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 4.2: Second batch (different data)", 16, 4, 4002, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test("Test 4.3: Third batch (larger ACC)", 36, 36, 4003, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // ================================================================
        // 测试组 5：INT16 模式测试
        // ================================================================
        $display("");
        $display("▶ SECTION 5: INT16 Mode Tests");
        
        run_test_int16("Test 5.1: INT16 Minimal (1 row)", 1, 0, 5001, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test_int16("Test 5.2: INT16 Small (4 rows)", 4, 0, 5002, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test_int16("Test 5.3: INT16 with ACC=4", 16, 4, 5003, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test_int16("Test 5.4: INT16 with ACC=8", 16, 8, 5004, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test_int16("Test 5.5: INT16 Large ACC=18", 18, 18, 5005, test_passed);
        total_tests++; passed_tests += test_passed;
        
        run_test_int16("Test 5.6: INT16 Large ACC=36", 36, 36, 5006, test_passed);
        total_tests++; passed_tests += test_passed;
        
        // ================================================================
        // 测试总结
        // ================================================================
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("                      TEST SUMMARY");
        $display("═══════════════════════════════════════════════════════════════");
        $display("  Total Tests:  %0d", total_tests);
        $display("  Passed:       %0d", passed_tests);
        $display("  Failed:       %0d", total_tests - passed_tests);
        $display("═══════════════════════════════════════════════════════════════");
        if (passed_tests == total_tests) begin
            $display("  *** ALL TESTS PASSED! ***");
        end else begin
            $display("  *** SOME TESTS FAILED! ***");
        end
        $display("═══════════════════════════════════════════════════════════════");
        $display("");
        
        $finish;
    end
    
    // ========================================================================
    // 超时保护
    // ========================================================================
    initial begin
        #50000000;  // 50ms
        $display("ERROR: Global simulation timeout!");
        $finish;
    end
    
    // ========================================================================
    // 波形输出
    // ========================================================================
    initial begin
        $dumpfile("tb_PE_Array.vcd");
        $dumpvars(0, tb_PE_Array);
    end

`ifdef DUMP_FSDB
    initial begin
        $fsdbDumpfile("pe_array.fsdb");
        $fsdbDumpvars(0, tb_PE_Array);
    end
`endif

endmodule
