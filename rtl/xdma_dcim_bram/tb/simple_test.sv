`timescale 1ns/1ps
`include "../dcim_defs.vh"

module simple_test;
    localparam CLK_PERIOD = 10;
    localparam CH_IN = `DCIM_CH_IN;   // 16
    localparam CH_OUT = `DCIM_CH_OUT; // 64
    
    logic clk, rst_n;
    logic [255:0] ibuf_mem[8192];
    logic [255:0] obuf_mem[8192];
    
    // 时钟
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // 简单测试：[1, 16] × [16, 64]，所有权重和激活都是1
    initial begin
        $display("Simple Test: All ones");
        
        // 清零
        for (int i = 0; i < 8192; i++) begin
            ibuf_mem[i] = '0;
            obuf_mem[i] = '0;
        end
        
        // 权重：16×64 = 1024 字节，每个字节=1
        for (int i = 0; i < 32; i++)  // 32 words * 32 bytes = 1024 bytes
            ibuf_mem[i] = {32{8'h01}};
        
        // 激活：1行，16字节，每个=1 (存在低128bit)
        ibuf_mem[100] = {128'h0, 16{8'h01}};
        
        // 期望输出：每个通道 = sum(1*1, 16次) = 16
        $display("Expected: all outputs = 16");
        $display("Weight packed in words 0-31");
        $display("Act packed in word 100");
        
        $finish;
    end
endmodule
