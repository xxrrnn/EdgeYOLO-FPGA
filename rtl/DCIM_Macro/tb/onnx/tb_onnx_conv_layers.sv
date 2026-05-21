`timescale 1ns / 1ps
`include "para.v"

// ============================================================================
// tb_onnx_conv_layers - best.onnx 模型卷积层 im2col 维度测试
// ============================================================================
// 测试覆盖 best.onnx 中所有卷积层的 im2col 矩阵乘法维度：
//   - 输入: 1×3×320×320
//   - 40 个卷积层，最大 K=1152, 最大 C_out=256
//   - 测试 DCIM_Macro 对各种 K 维度的支持能力
// ============================================================================

module tb_onnx_conv_layers;

    // 参数定义（与 DCIM_Macro 一致）
    localparam WD1 = 4, CH_IN = 16, CH_OUT = 16, SRAM_DP = 128, CYCLE = 8, ACC = 80;
    localparam BUF_ADDR_WIDTH = 12, BUF_DATA_WIDTH = 128;
    localparam WD2 = 2*WD1 + $clog2(CH_IN);
    localparam WD3 = WD2 + $clog2(ACC);
    localparam T = 10;  // 时钟周期
    
    // DUT 接口信号
    reg clk, rst_n, start;
    wire done, ready;
    reg [2:0] mode;
    reg [6:0] acc_depth;
    reg [15:0] num_rows;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_addr, act_base_addr, out_base_addr;
    
    reg  [BUF_DATA_WIDTH/8-1:0] ibuf_wea, obuf_wea;
    reg  [BUF_ADDR_WIDTH-1:0] ibuf_addra, obuf_addra;
    reg  [BUF_DATA_WIDTH-1:0] ibuf_dina, obuf_dina;
    reg  ibuf_ena, obuf_ena;
    wire [BUF_DATA_WIDTH-1:0] ibuf_douta, obuf_douta;
    
    // DUT 实例化
    DCIM_Macro #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT), 
        .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH), .BUF_DATA_WIDTH(BUF_DATA_WIDTH)
    ) dut (.*);
    
    // 时钟生成
    initial clk = 0;
    always #(T/2) clk = ~clk;
    
    // ========================================================================
    // ONNX 模型卷积层配置（从 best.onnx 提取）
    // 格式: {C_out, C_in, K_h, K_w, K_dim, ACC_needed}
    // K_dim = C_in * K_h * K_w (im2col 后的内积维度)
    // ACC_needed = ceil(K_dim / CH_IN)
    // ========================================================================
    typedef struct {
        int c_out;
        int c_in;
        int k_h;
        int k_w;
        int k_dim;      // im2col 后的 K 维度
        int acc_needed; // 需要的 ACC 值
        string name;
    } conv_config_t;
    
    // 选取代表性的卷积层进行测试
    conv_config_t conv_layers[20];
    
    initial begin
        // Layer 1: Conv [16, 3, 6, 6] -> K=108
        conv_layers[0] = '{16, 3, 6, 6, 108, 7, "Conv0_16x3x6x6"};
        // Layer 2: Conv [32, 16, 3, 3] -> K=144
        conv_layers[1] = '{32, 16, 3, 3, 144, 9, "Conv1_32x16x3x3"};
        // Layer 8: Conv [64, 32, 3, 3] -> K=288
        conv_layers[2] = '{64, 32, 3, 3, 288, 18, "Conv8_64x32x3x3"};
        // Layer 16: Conv [128, 64, 3, 3] -> K=576
        conv_layers[3] = '{128, 64, 3, 3, 576, 36, "Conv16_128x64x3x3"};
        // Layer 26: Conv [256, 128, 3, 3] -> K=1152 (最大)
        conv_layers[4] = '{256, 128, 3, 3, 1152, 72, "Conv26_256x128x3x3"};
        // 1x1 卷积测试
        conv_layers[5] = '{16, 32, 1, 1, 32, 2, "Conv_16x32x1x1"};
        conv_layers[6] = '{32, 64, 1, 1, 64, 4, "Conv_32x64x1x1"};
        conv_layers[7] = '{64, 128, 1, 1, 128, 8, "Conv_64x128x1x1"};
        conv_layers[8] = '{128, 256, 1, 1, 256, 16, "Conv_128x256x1x1"};
        conv_layers[9] = '{256, 512, 1, 1, 512, 32, "Conv_256x512x1x1"};
        // 边界情况
        conv_layers[10] = '{16, 16, 1, 1, 16, 1, "Conv_16x16x1x1_min"};
        conv_layers[11] = '{64, 64, 3, 3, 576, 36, "Conv_64x64x3x3"};
        conv_layers[12] = '{128, 128, 3, 3, 1152, 72, "Conv_128x128x3x3_max"};
        // 小 K 值测试
        conv_layers[13] = '{32, 16, 1, 1, 16, 1, "Conv_32x16x1x1"};
        conv_layers[14] = '{64, 32, 1, 1, 32, 2, "Conv_64x32x1x1"};
        // 中等 K 值
        conv_layers[15] = '{64, 64, 1, 1, 64, 4, "Conv_64x64x1x1"};
        conv_layers[16] = '{128, 64, 1, 1, 64, 4, "Conv_128x64x1x1"};
        conv_layers[17] = '{64, 128, 1, 1, 128, 8, "Conv_64x128x1x1_2"};
        conv_layers[18] = '{128, 128, 1, 1, 128, 8, "Conv_128x128x1x1"};
        conv_layers[19] = '{256, 256, 1, 1, 256, 16, "Conv_256x256x1x1"};
    end
    
    // ========================================================================
    // 测试数据存储
    // ========================================================================
    localparam MAX_ROWS = 80;
    reg signed [3:0] weight_nibble [0:CH_IN-1][0:CH_OUT-1];
    reg signed [7:0] activation [0:MAX_ROWS-1][0:CH_IN-1];
    reg signed [31:0] golden [0:MAX_ROWS-1][0:7];
    reg signed [31:0] dut_int32 [0:MAX_ROWS-1][0:7];
    
    integer seed;
    integer total_tests, passed_tests, total_errors;
    
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
    // 数据生成任务
    // ========================================================================
    task generate_random_weights();
        integer i, j;
        begin
            for (i = 0; i < CH_IN; i++)
                for (j = 0; j < CH_OUT; j++)
                    weight_nibble[i][j] = $random(seed) % 15 - 7;
        end
    endtask
    
    task generate_random_activations(input integer rows);
        integer row, ch;
        begin
            for (row = 0; row < rows; row++)
                for (ch = 0; ch < CH_IN; ch++)
                    activation[row][ch] = $random(seed) % 256 - 128;
        end
    endtask
    
    task load_weights(input [BUF_ADDR_WIDTH-1:0] base);
        integer addr, bit_idx, nibble_idx, in_ch, out_ch;
        reg [BUF_DATA_WIDTH-1:0] sram_word;
        begin
            for (addr = 0; addr < CYCLE; addr++) begin
                sram_word = 0;
                for (bit_idx = 0; bit_idx < BUF_DATA_WIDTH; bit_idx = bit_idx + WD1) begin
                    nibble_idx = addr * (BUF_DATA_WIDTH/WD1) + bit_idx/WD1;
                    out_ch = nibble_idx / CH_IN;
                    in_ch = nibble_idx % CH_IN;
                    if (in_ch < CH_IN && out_ch < CH_OUT)
                        sram_word[bit_idx +: WD1] = weight_nibble[in_ch][out_ch];
                end
                write_ibuf(base + addr, sram_word);
            end
        end
    endtask
    
    task load_activations(input [BUF_ADDR_WIDTH-1:0] base, input integer rows);
        integer row, ch;
        reg [BUF_DATA_WIDTH-1:0] act_word;
        begin
            for (row = 0; row < rows; row++) begin
                act_word = 0;
                for (ch = 0; ch < CH_IN; ch++)
                    act_word[ch*8 +: 8] = activation[row][ch];
                write_ibuf(base + row, act_word);
            end
        end
    endtask
    
    // ========================================================================
    // Golden Model 计算
    // ========================================================================
    task compute_golden(input integer rows, input integer acc_val);
        integer row, out_ch, in_ch, acc_group, row_in_group;
        integer phys_ch_lo, phys_ch_hi, num_acc_groups;
        reg signed [63:0] sum;
        reg signed [7:0] w8, a8;
        reg signed [WD3-1:0] wd3_result;
        begin
            num_acc_groups = rows / acc_val;
            
            for (row = 0; row < MAX_ROWS; row++)
                for (out_ch = 0; out_ch < 8; out_ch++)
                    golden[row][out_ch] = 0;
            
            for (acc_group = 0; acc_group < num_acc_groups; acc_group++) begin
                for (out_ch = 0; out_ch < 8; out_ch++) begin
                    sum = 0;
                    for (row_in_group = 0; row_in_group < acc_val; row_in_group++) begin
                        row = acc_group * acc_val + row_in_group;
                        for (in_ch = 0; in_ch < CH_IN; in_ch++) begin
                            phys_ch_lo = out_ch * 2 + 2;
                            phys_ch_hi = out_ch * 2 + 3;
                            if (phys_ch_lo >= CH_OUT) phys_ch_lo = CH_OUT - 2;
                            if (phys_ch_hi >= CH_OUT) phys_ch_hi = CH_OUT - 1;
                            w8 = {weight_nibble[in_ch][phys_ch_hi], weight_nibble[in_ch][phys_ch_lo]};
                            a8 = activation[row][in_ch];
                            sum = sum + ($signed(a8) * $signed(w8));
                        end
                    end
                    wd3_result = sum[WD3-1:0];
                    golden[acc_group][out_ch] = {{(32-WD3){wd3_result[WD3-1]}}, wd3_result};
                end
            end
        end
    endtask
    
    // ========================================================================
    // 结果读取和验证
    // ========================================================================
    task read_results(input [BUF_ADDR_WIDTH-1:0] base, input integer rows, input integer acc_val);
        integer row, ch, num_outputs;
        reg [BUF_DATA_WIDTH-1:0] result_lo, result_hi;
        begin
            num_outputs = rows / acc_val;
            for (row = 0; row < num_outputs; row++) begin
                read_obuf(base + row * 2, result_lo);
                read_obuf(base + row * 2 + 1, result_hi);
                for (ch = 0; ch < 4; ch++) begin
                    dut_int32[row][ch] = $signed(result_lo[ch*32 +: 32]);
                    dut_int32[row][ch+4] = $signed(result_hi[ch*32 +: 32]);
                end
            end
        end
    endtask
    
    function integer verify_results(input integer rows, input integer acc_val);
        integer row, ch, errors, num_outputs;
        begin
            errors = 0;
            num_outputs = rows / acc_val;
            for (row = 0; row < num_outputs; row++) begin
                for (ch = 0; ch < 8; ch++) begin
                    if (dut_int32[row][ch] !== golden[row][ch]) begin
                        errors = errors + 1;
                        if (errors <= 3)
                            $display("    [ERR] Row %0d Ch %0d: DUT=%0d, Golden=%0d", 
                                     row, ch, dut_int32[row][ch], golden[row][ch]);
                    end
                end
            end
            verify_results = errors;
        end
    endfunction
    
    // ========================================================================
    // 单层卷积测试任务
    // ========================================================================
    task test_conv_layer(input int layer_idx);
        integer k_dim, acc_val, num_rows_test, errors;
        string layer_name;
        begin
            k_dim = conv_layers[layer_idx].k_dim;
            acc_val = conv_layers[layer_idx].acc_needed;
            layer_name = conv_layers[layer_idx].name;
            
            // 计算测试行数（确保能被 acc_val 整除）
            num_rows_test = acc_val;
            if (num_rows_test > MAX_ROWS) num_rows_test = MAX_ROWS;
            
            total_tests = total_tests + 1;
            $display("");
            $display("─────────────────────────────────────────────────────────────");
            $display("  Test %0d: %s", total_tests, layer_name);
            $display("  C_out=%0d, C_in=%0d, K=%0dx%0d, K_dim=%0d, ACC=%0d",
                     conv_layers[layer_idx].c_out, conv_layers[layer_idx].c_in,
                     conv_layers[layer_idx].k_h, conv_layers[layer_idx].k_w,
                     k_dim, acc_val);
            $display("─────────────────────────────────────────────────────────────");
            
            // 等待就绪
            wait(ready);
            repeat(5) @(posedge clk);
            
            // 配置
            mode = `MODE_INT8;
            acc_depth = acc_val;
            num_rows = num_rows_test;
            wei_base_addr = 0;
            act_base_addr = CYCLE;
            out_base_addr = 0;
            
            // 生成和加载数据
            generate_random_weights();
            load_weights(0);
            generate_random_activations(num_rows_test);
            load_activations(CYCLE, num_rows_test);
            compute_golden(num_rows_test, acc_val);
            
            // 运行
            wait(ready); repeat(5) @(posedge clk);
            @(posedge clk); start <= 1'b1; @(posedge clk); start <= 1'b0;
            
            // 等待完成
            fork
                begin wait(done); end
                begin repeat(200000) @(posedge clk); $display("  [TIMEOUT]"); end
            join_any
            disable fork;
            
            repeat(10) @(posedge clk);
            
            // 验证
            read_results(0, num_rows_test, acc_val);
            errors = verify_results(num_rows_test, acc_val);
            
            if (errors == 0) begin
                $display("  >>> PASSED <<<");
                passed_tests = passed_tests + 1;
            end else begin
                $display("  >>> FAILED: %0d errors <<<", errors);
                total_errors = total_errors + errors;
            end
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
        total_tests = 0; passed_tests = 0; total_errors = 0;
        seed = 42;
        
        repeat(10) @(posedge clk); rst_n = 1; repeat(10) @(posedge clk);
        
        $display("");
        $display("╔═══════════════════════════════════════════════════════════════╗");
        $display("║     best.onnx Conv Layer im2col Dimension Test Suite         ║");
        $display("║     Testing DCIM_Macro with ACC=%0d (max K=%0d)               ║", ACC, ACC*CH_IN);
        $display("╚═══════════════════════════════════════════════════════════════╝");
        
        // 测试所有配置的卷积层
        for (int i = 0; i < 20; i++) begin
            seed = 1000 + i * 111;
            test_conv_layer(i);
        end
        
        // 结果汇总
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
        
        repeat(100) @(posedge clk);
        $finish;
    end
    
    initial begin #100000000; $display("GLOBAL TIMEOUT!"); $finish; end
    
    initial begin
        $fsdbDumpfile("tb_onnx_conv_layers.fsdb");
        $fsdbDumpvars(0, tb_onnx_conv_layers, "+all");
    end

endmodule
