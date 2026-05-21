`timescale 1ns / 1ps

// ============================================================================
// tb_act_nibble_converter - act_nibble_converter 单元测试
// ============================================================================
// 测试 INT8 和 INT16 模式下的 nibble 拆分是否正确

module tb_act_nibble_converter;

    localparam CH_IN = 16;
    localparam MODE_INT8  = 3'b110;
    localparam MODE_INT16 = 3'b111;
    localparam T = 10;  // 10ns 时钟周期 (100MHz)

    logic                   clk;
    logic                   rst_n;
    logic [2:0]             mode;
    
    logic                   raw_act_valid;
    logic                   raw_act_ready;
    logic [CH_IN*16-1:0]    raw_act_data;
    
    logic                   dcim_act_valid;
    logic                   dcim_act_ready;
    logic [CH_IN*4-1:0]     dcim_act_data;

    integer errors;
    integer test_count;

    // DUT 实例化
    act_nibble_converter #(
        .CH_IN(CH_IN),
        .MODE_INT8(MODE_INT8),
        .MODE_INT16(MODE_INT16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mode(mode),
        .raw_act_valid(raw_act_valid),
        .raw_act_ready(raw_act_ready),
        .raw_act_data(raw_act_data),
        .dcim_act_valid(dcim_act_valid),
        .dcim_act_ready(dcim_act_ready),
        .dcim_act_data(dcim_act_data)
    );

    // 时钟生成
    initial clk = 0;
    always #(T/2) clk = ~clk;

    // 测试任务：发送一个激活数据
    task send_raw_act(input [CH_IN*16-1:0] data);
        begin
            @(posedge clk);
            raw_act_valid <= 1'b1;
            raw_act_data <= data;
            wait (raw_act_ready);
            @(posedge clk);
            raw_act_valid <= 1'b0;
        end
    endtask

    // 测试任务：接收一个 nibble 数据
    task receive_dcim_act(output [CH_IN*4-1:0] data);
        begin
            dcim_act_ready <= 1'b1;
            wait (dcim_act_valid);
            @(posedge clk);
            data = dcim_act_data;
            dcim_act_ready <= 1'b0;
        end
    endtask

    // 测试任务：验证 INT8 模式
    task test_int8(input [CH_IN*16-1:0] input_data);
        logic [CH_IN*4-1:0] nibble0, nibble1;
        logic [CH_IN*4-1:0] expected_nibble0, expected_nibble1;
        integer ch;
        begin
            test_count = test_count + 1;
            $display("Test %0d: INT8 mode", test_count);
            
            // 计算期望值
            for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                expected_nibble0[ch*4 +: 4] = input_data[ch*16 + 4 +: 4];  // 高 nibble
                expected_nibble1[ch*4 +: 4] = input_data[ch*16 + 0 +: 4];  // 低 nibble
            end
            
            // 发送激活数据
            fork
                send_raw_act(input_data);
                begin
                    receive_dcim_act(nibble0);
                    receive_dcim_act(nibble1);
                end
            join
            
            // 验证
            if (nibble0 !== expected_nibble0) begin
                $display("  ERROR: nibble0 mismatch! Expected: %h, Got: %h", expected_nibble0, nibble0);
                errors = errors + 1;
            end else if (nibble1 !== expected_nibble1) begin
                $display("  ERROR: nibble1 mismatch! Expected: %h, Got: %h", expected_nibble1, nibble1);
                errors = errors + 1;
            end else begin
                $display("  PASS");
            end
        end
    endtask

    // 测试任务：验证 INT16 模式
    task test_int16(input [CH_IN*16-1:0] input_data);
        logic [CH_IN*4-1:0] nibble[0:3];
        logic [CH_IN*4-1:0] expected_nibble[0:3];
        integer ch, i;
        begin
            test_count = test_count + 1;
            $display("Test %0d: INT16 mode", test_count);
            
            // 计算期望值
            for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                expected_nibble[0][ch*4 +: 4] = input_data[ch*16 + 12 +: 4];  // bit[15:12]
                expected_nibble[1][ch*4 +: 4] = input_data[ch*16 +  8 +: 4];  // bit[11:8]
                expected_nibble[2][ch*4 +: 4] = input_data[ch*16 +  4 +: 4];  // bit[7:4]
                expected_nibble[3][ch*4 +: 4] = input_data[ch*16 +  0 +: 4];  // bit[3:0]
            end
            
            // 发送激活数据
            fork
                send_raw_act(input_data);
                begin
                    for (i = 0; i < 4; i = i + 1)
                        receive_dcim_act(nibble[i]);
                end
            join
            
            // 验证
            for (i = 0; i < 4; i = i + 1) begin
                if (nibble[i] !== expected_nibble[i]) begin
                    $display("  ERROR: nibble[%0d] mismatch! Expected: %h, Got: %h", i, expected_nibble[i], nibble[i]);
                    errors = errors + 1;
                end
            end
            
            if (errors == 0)
                $display("  PASS");
        end
    endtask

    // 主测试流程
    initial begin
        errors = 0;
        test_count = 0;
        
        // 初始化
        rst_n = 0;
        mode = MODE_INT8;
        raw_act_valid = 0;
        raw_act_data = '0;
        dcim_act_ready = 0;
        
        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);
        
        $display("");
        $display("╔════════════════════════════════════════════════════╗");
        $display("║   act_nibble_converter 单元测试                   ║");
        $display("╚════════════════════════════════════════════════════╝");
        $display("");
        
        // ========== INT8 模式测试 ==========
        mode = MODE_INT8;
        repeat (5) @(posedge clk);
        
        // 测试 1: 全 0
        test_int8(256'h0);
        repeat (5) @(posedge clk);
        
        // 测试 2: 每个通道递增模式
        begin
            logic [CH_IN*16-1:0] data;
            integer ch;
            for (ch = 0; ch < CH_IN; ch = ch + 1)
                data[ch*16 +: 16] = 16'h0000 + (ch << 8);  // 通道 0 = 0x00, 通道 1 = 0x01, ...
            test_int8(data);
        end
        repeat (5) @(posedge clk);
        
        // 测试 3: 随机数据
        begin
            logic [CH_IN*16-1:0] data;
            integer ch;
            for (ch = 0; ch < CH_IN; ch = ch + 1)
                data[ch*16 +: 16] = $random & 16'hFF;
            test_int8(data);
        end
        repeat (5) @(posedge clk);
        
        // 测试 4: 0xAB 模式（验证高低 nibble 提取）
        begin
            logic [CH_IN*16-1:0] data;
            integer ch;
            for (ch = 0; ch < CH_IN; ch = ch + 1)
                data[ch*16 +: 16] = 16'h00AB;  // 期望：nibble0=0xA, nibble1=0xB
            test_int8(data);
        end
        repeat (5) @(posedge clk);
        
        // ========== INT16 模式测试 ==========
        mode = MODE_INT16;
        repeat (5) @(posedge clk);
        
        // 测试 5: 全 0
        test_int16(256'h0);
        repeat (5) @(posedge clk);
        
        // 测试 6: 每个通道递增模式
        begin
            logic [CH_IN*16-1:0] data;
            integer ch;
            for (ch = 0; ch < CH_IN; ch = ch + 1)
                data[ch*16 +: 16] = 16'h1234 + ch;
            test_int16(data);
        end
        repeat (5) @(posedge clk);
        
        // 测试 7: 0x1234 模式（验证 4 个 nibble 提取）
        begin
            logic [CH_IN*16-1:0] data;
            integer ch;
            for (ch = 0; ch < CH_IN; ch = ch + 1)
                data[ch*16 +: 16] = 16'h1234;  // 期望：nibble[0]=0x1, [1]=0x2, [2]=0x3, [3]=0x4
            test_int16(data);
        end
        repeat (5) @(posedge clk);
        
        // 测试 8: 随机数据
        begin
            logic [CH_IN*16-1:0] data;
            integer ch;
            for (ch = 0; ch < CH_IN; ch = ch + 1)
                data[ch*16 +: 16] = $random & 16'hFFFF;
            test_int16(data);
        end
        repeat (5) @(posedge clk);
        
        // ========== 总结 ==========
        $display("");
        $display("════════════════════════════════════════════════════");
        $display("测试总结");
        $display("════════════════════════════════════════════════════");
        $display("总测试数: %0d", test_count);
        $display("错误数:   %0d", errors);
        $display("════════════════════════════════════════════════════");
        
        if (errors == 0)
            $display(">>> 所有测试通过 <<<");
        else
            $display(">>> 有测试失败 <<<");
        
        $display("");
        repeat (10) @(posedge clk);
        $finish;
    end
    
    // 超时保护
    initial begin
        repeat (50000) @(posedge clk);
        $display("ERROR: Timeout!");
        $finish;
    end

endmodule
