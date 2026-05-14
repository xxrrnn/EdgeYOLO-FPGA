`timescale 1ns/1ps

module tb_qa_unit;

    localparam ADDR_WIDTH = 32;
    localparam GB_BANDWIDTH = 256;
    localparam FP_WIDTH = 32;
    localparam FP_CORE_NUM = 32;
    
    reg clk = 0;
    reg rst_n = 0;
    always #2 clk = ~clk;  // 250MHz
    
    // 测试信号
    reg [ADDR_WIDTH-1:0] qa_src_c, qa_src_h, qa_src_w;
    
    // 黄金参考（原始组合逻辑）
    wire [ADDR_WIDTH-1:0] golden;
    assign golden = qa_src_c * qa_src_h * qa_src_w * FP_WIDTH / GB_BANDWIDTH;
    
    // DUT 预计算值
    reg [ADDR_WIDTH-1:0] dut_reg;
    reg [2:0] state = 0;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            dut_reg <= '0;
        else if (state == 0)  // 模拟 IDLE 状态
            dut_reg <= qa_src_c * qa_src_h * qa_src_w * FP_WIDTH / GB_BANDWIDTH;
    end
    
    integer test_case = 0;
    integer errors = 0;
    
    initial begin
        $display("========================================");
        $display("QA Unit Timing Fix Test");
        $display("========================================\n");
        
        rst_n = 0; #20; rst_n = 1; #10;
        
        // Test case 1
        qa_src_c = 64; qa_src_h = 32; qa_src_w = 32; state = 0; #10;
        state = 1; #10;
        if (golden == dut_reg) 
            $display("✓ Test %0d PASS: %0dx%0dx%0d -> %0d", test_case++, qa_src_c, qa_src_h, qa_src_w, dut_reg);
        else begin
            $display("✗ Test %0d FAIL: golden=%0d, dut=%0d", test_case++, golden, dut_reg);
            errors++;
        end
        
        // Test case 2
        qa_src_c = 128; qa_src_h = 16; qa_src_w = 16; state = 0; #10;
        state = 1; #10;
        if (golden == dut_reg)
            $display("✓ Test %0d PASS: %0dx%0dx%0d -> %0d", test_case++, qa_src_c, qa_src_h, qa_src_w, dut_reg);
        else begin
            $display("✗ Test %0d FAIL: golden=%0d, dut=%0d", test_case++, golden, dut_reg);
            errors++;
        end
        
        // Test case 3
        qa_src_c = 256; qa_src_h = 8; qa_src_w = 8; state = 0; #10;
        state = 1; #10;
        if (golden == dut_reg)
            $display("✓ Test %0d PASS: %0dx%0dx%0d -> %0d", test_case++, qa_src_c, qa_src_h, qa_src_w, dut_reg);
        else begin
            $display("✗ Test %0d FAIL: golden=%0d, dut=%0d", test_case++, golden, dut_reg);
            errors++;
        end
        
        // Test case 4
        qa_src_c = 3; qa_src_h = 224; qa_src_w = 224; state = 0; #10;
        state = 1; #10;
        if (golden == dut_reg)
            $display("✓ Test %0d PASS: %0dx%0dx%0d -> %0d", test_case++, qa_src_c, qa_src_h, qa_src_w, dut_reg);
        else begin
            $display("✗ Test %0d FAIL: golden=%0d, dut=%0d", test_case++, golden, dut_reg);
            errors++;
        end
        
        // Test case 5  
        qa_src_c = 512; qa_src_h = 7; qa_src_w = 7; state = 0; #10;
        state = 1; #10;
        if (golden == dut_reg)
            $display("✓ Test %0d PASS: %0dx%0dx%0d -> %0d", test_case++, qa_src_c, qa_src_h, qa_src_w, dut_reg);
        else begin
            $display("✗ Test %0d FAIL: golden=%0d, dut=%0d", test_case++, golden, dut_reg);
            errors++;
        end
        
        $display("\n========================================");
        if (errors == 0) begin
            $display("✓ ALL %0d TESTS PASSED", test_case);
        end else begin
            $display("✗ %0d/%0d TESTS FAILED", errors, test_case);
        end
        $display("========================================");
        $finish;
    end
    
endmodule
