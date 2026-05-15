`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// INST_Decoder 完整测试 - CDMA + VPU 集成测试
//////////////////////////////////////////////////////////////////////////////////

module tb_inst_decoder_full();

    // 时钟和复位
    reg clk;
    reg rst_n;
    
    // 控制信号
    reg         decoder_start;
    reg  [31:0] inst_count;
    wire        decoder_busy;
    wire        decoder_done;
    wire [31:0] decoder_status;
    
    // inst_bram 接口
    wire [17:0] inst_rd_addr;
    reg  [31:0] inst_rd_data;
    
    // CDMA_Controller 接口（模拟）
    wire        cdma_start;
    wire        cdma_config_valid;
    reg         cdma_config_ready;
    wire [31:0] cdma_src_addr_msb;
    wire [31:0] cdma_src_addr_lsb;
    wire [31:0] cdma_dst_addr_msb;
    wire [31:0] cdma_dst_addr_lsb;
    wire [31:0] cdma_length;
    
    // VPU 接口（模拟）
    wire        vpu_start;
    reg         vpu_ready;
    wire [31:0] vpu_unit_choose;
    wire [31:0] vpu_src_addr;
    wire [31:0] vpu_src2_addr;
    wire [31:0] vpu_src_c;
    wire [31:0] vpu_src_h;
    wire [31:0] vpu_src_w;
    wire [31:0] vpu_bias_addr;
    wire [31:0] vpu_scale_addr;
    wire [31:0] vpu_dst_addr;
    wire [31:0] vpu_addr_break;
    wire [31:0] vpu_addr_s;
    wire [31:0] vpu_addr_t;
    
    // 指令存储（模拟 inst_bram）
    reg [31:0] inst_mem [0:255];
    
    // DUT 实例化
    INST_Decoder #(
        .INST_BRAM_DEPTH(262144),
        .INST_ADDR_WIDTH(18)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .decoder_start(decoder_start),
        .inst_count(inst_count),
        .decoder_busy(decoder_busy),
        .decoder_done(decoder_done),
        .decoder_status(decoder_status),
        .inst_rd_addr(inst_rd_addr),
        .inst_rd_data(inst_rd_data),
        .cdma_start(cdma_start),
        .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(cdma_config_ready),
        .cdma_src_addr_msb(cdma_src_addr_msb),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(cdma_dst_addr_msb),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length(cdma_length),
        .vpu_start(vpu_start),
        .vpu_ready(vpu_ready),
        .vpu_unit_choose(vpu_unit_choose),
        .vpu_src_addr(vpu_src_addr),
        .vpu_src2_addr(vpu_src2_addr),
        .vpu_src_c(vpu_src_c),
        .vpu_src_h(vpu_src_h),
        .vpu_src_w(vpu_src_w),
        .vpu_bias_addr(vpu_bias_addr),
        .vpu_scale_addr(vpu_scale_addr),
        .vpu_dst_addr(vpu_dst_addr),
        .vpu_addr_break(vpu_addr_break),
        .vpu_addr_s(vpu_addr_s),
        .vpu_addr_t(vpu_addr_t)
    );
    
    // 时钟生成 (250MHz)
    initial clk = 0;
    always #2 clk = ~clk;
    
    // inst_bram 读取模拟 (1 周期延迟)
    always @(posedge clk) begin
        if (inst_rd_addr < 256)
            inst_rd_data <= inst_mem[inst_rd_addr];
        else
            inst_rd_data <= 32'h0;
    end
    
    // CDMA_Controller 行为模拟
    reg cdma_busy;
    integer cdma_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cdma_config_ready <= 1'b1;
            cdma_busy <= 1'b0;
            cdma_count <= 0;
        end else begin
            if (cdma_start && cdma_config_valid && cdma_config_ready) begin
                // 接受配置
                $display("[%0t] CDMA#%0d: 0x%08X -> 0x%08X (%0dB)", 
                         $time, cdma_count, cdma_src_addr_lsb, cdma_dst_addr_lsb, cdma_length);
                cdma_config_ready <= 1'b0;
                cdma_busy <= 1'b1;
                cdma_count <= cdma_count + 1;
                // 模拟 CDMA 传输延迟（根据长度调整）
                #(cdma_length / 4);  // 每 4 字节 1ns
                cdma_busy <= 1'b0;
                cdma_config_ready <= 1'b1;
                $display("[%0t] CDMA#%0d: 完成", $time, cdma_count);
            end
        end
    end
    
    // VPU 行为模拟
    reg vpu_busy;
    integer vpu_count;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vpu_ready <= 1'b1;
            vpu_busy <= 1'b0;
            vpu_count <= 0;
        end else begin
            if (vpu_start && vpu_ready) begin
                // VPU 开始执行
                $display("[%0t] VPU#%0d: unit=%0d, src=0x%08X, dst=0x%08X, [C,H,W]=[%0d,%0d,%0d]", 
                         $time, vpu_count, vpu_unit_choose, vpu_src_addr, vpu_dst_addr,
                         vpu_src_c, vpu_src_h, vpu_src_w);
                vpu_ready <= 1'b0;
                vpu_busy <= 1'b1;
                vpu_count <= vpu_count + 1;
                // 模拟 VPU 计算延迟
                #200;
                vpu_busy <= 1'b0;
                vpu_ready <= 1'b1;
                $display("[%0t] VPU#%0d: 完成", $time, vpu_count);
            end
        end
    end
    
    // 辅助函数：生成指令头
    function [31:0] make_header;
        input [3:0] opcode;
        input [23:0] body_length;
        begin
            make_header = {opcode, 4'h0, body_length};
        end
    endfunction
    
    // 测试任务
    reg done_flag;
    reg [31:0] done_status;
    task wait_decoder_done;
        input integer timeout_cycles;
        integer cnt;
        begin
            cnt = 0;
            done_flag = 0;
            done_status = 32'h0;
            while (!done_flag && cnt < timeout_cycles) begin
                @(posedge clk);
                if (decoder_done) begin
                    done_flag = 1;
                    done_status = decoder_status;  // 立即捕获状态
                end
                cnt = cnt + 1;
            end
            if (done_flag)
                $display("[%0t] ✓ 解码器完成执行", $time);
            else
                $display("[%0t] ✗ 解码器超时 (status=0x%08X)", $time, decoder_status);
        end
    endtask
    
    // 测试用例计数
    integer test_passed = 0;
    integer test_failed = 0;
    
    task run_test;
        input [255:0] test_name;
        input integer expected_inst_count;
        begin
            $display("\n========================================");
            $display("测试: %0s", test_name);
            $display("========================================");
            
            // 重置统计
            cdma_count = 0;
            vpu_count = 0;
            
            // 启动解码器
            inst_count = expected_inst_count;
            decoder_start = 1;
            @(posedge clk);
            decoder_start = 0;
            
            // 等待完成
            wait_decoder_done(5000);
            
            // 检查结果
            #100;
            if (done_flag && !decoder_busy && (done_status == 32'h00000002 || decoder_status == 32'h00000000)) begin
                $display("✓ 测试通过");
                test_passed = test_passed + 1;
            end else begin
                $display("✗ 测试失败: busy=%b, done_flag=%b, done_status=0x%08X, current_status=0x%08X", 
                         decoder_busy, done_flag, done_status, decoder_status);
                test_failed = test_failed + 1;
            end
        end
    endtask
    
    // 主测试流程
    initial begin
        $display("========================================");
        $display("INST_Decoder 完整功能测试");
        $display("========================================");
        
        // 初始化
        rst_n = 0;
        decoder_start = 0;
        inst_count = 0;
        
        // 初始化指令存储
        for (integer i = 0; i < 256; i = i + 1)
            inst_mem[i] = 32'h0;
        
        // 复位
        #20;
        rst_n = 1;
        #20;
        
        // ========================================
        // 测试 1: 单个 CDMA 指令
        // ========================================
        inst_mem[0] = make_header(4'h1, 24'd12);  // CDMA_COPY
        inst_mem[1] = 32'h10000000;  // src
        inst_mem[2] = 32'h20000000;  // dst
        inst_mem[3] = 32'h00000100;  // len=256
        inst_mem[4] = make_header(4'h3, 24'd0);   // WAIT_CDMA
        inst_mem[5] = make_header(4'hF, 24'd0);   // END
        run_test("单个CDMA指令", 6);
        
        // ========================================
        // 测试 2: 单个 VPU 指令
        // ========================================
        inst_mem[0] = make_header(4'h2, 24'd48);  // VPU_EXEC
        inst_mem[1] = 32'h00000001;  // unit_choose
        inst_mem[2] = 32'h10000000;  // src_addr
        inst_mem[3] = 32'h10001000;  // src2_addr
        inst_mem[4] = 32'h00000008;  // src_c
        inst_mem[5] = 32'h00000010;  // src_h
        inst_mem[6] = 32'h00000010;  // src_w
        inst_mem[7] = 32'h10002000;  // bias_addr
        inst_mem[8] = 32'h10003000;  // scale_addr
        inst_mem[9] = 32'h10004000;  // dst_addr
        inst_mem[10] = 32'h00000000; // addr_break
        inst_mem[11] = 32'h00000000; // addr_s
        inst_mem[12] = 32'h00000000; // addr_t
        inst_mem[13] = make_header(4'h4, 24'd0);  // WAIT_VPU
        inst_mem[14] = make_header(4'hF, 24'd0);  // END
        run_test("单个VPU指令", 15);
        
        // ========================================
        // 测试 3: CDMA + VPU 完整流程
        // ========================================
        inst_mem[0] = make_header(4'h1, 24'd12);  // CDMA: global_bram -> VPU GB
        inst_mem[1] = 32'h10000000;
        inst_mem[2] = 32'h10400000;  // VPU GB
        inst_mem[3] = 32'h00001000;
        
        inst_mem[4] = make_header(4'h3, 24'd0);   // WAIT_CDMA
        
        inst_mem[5] = make_header(4'h2, 24'd48);  // VPU_EXEC
        inst_mem[6] = 32'h00000002;
        inst_mem[7] = 32'h10400000;  // VPU GB
        inst_mem[8] = 32'h10400800;
        inst_mem[9] = 32'h00000010;
        inst_mem[10] = 32'h00000020;
        inst_mem[11] = 32'h00000020;
        inst_mem[12] = 32'h10420000; // VPU WB
        inst_mem[13] = 32'h10420100;
        inst_mem[14] = 32'h10400000; // dst in VPU GB
        inst_mem[15] = 32'h00000000;
        inst_mem[16] = 32'h00000000;
        inst_mem[17] = 32'h00000000;
        
        inst_mem[18] = make_header(4'h4, 24'd0);  // WAIT_VPU
        
        inst_mem[19] = make_header(4'h1, 24'd12); // CDMA: VPU GB -> global_bram
        inst_mem[20] = 32'h10400000;
        inst_mem[21] = 32'h10010000;
        inst_mem[22] = 32'h00001000;
        
        inst_mem[23] = make_header(4'h3, 24'd0);  // WAIT_CDMA
        inst_mem[24] = make_header(4'hF, 24'd0);  // END
        run_test("CDMA+VPU完整流程", 25);
        
        // ========================================
        // 测试 4: 多指令混合
        // ========================================
        inst_mem[0] = make_header(4'h0, 24'd0);   // NOP
        inst_mem[1] = make_header(4'h1, 24'd12);  // CDMA
        inst_mem[2] = 32'h10000000;
        inst_mem[3] = 32'h20000000;
        inst_mem[4] = 32'h00000200;
        inst_mem[5] = make_header(4'h1, 24'd12);  // CDMA
        inst_mem[6] = 32'h20000000;
        inst_mem[7] = 32'h30000000;
        inst_mem[8] = 32'h00000200;
        inst_mem[9] = make_header(4'h5, 24'd0);   // SYNC
        inst_mem[10] = make_header(4'hF, 24'd0);  // END
        run_test("多指令混合", 11);
        
        // 最终总结
        #100;
        $display("\n========================================");
        $display("测试总结");
        $display("========================================");
        $display("通过: %0d", test_passed);
        $display("失败: %0d", test_failed);
        if (test_failed == 0) begin
            $display("========================================");
            $display("✓ 所有测试通过！");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("✗ 有测试失败");
            $display("========================================");
        end
        
        #100;
        $finish;
    end
    
    // 超时保护
    initial begin
        #200000;
        $display("[%0t] ✗ 仿真总超时", $time);
        $finish;
    end

endmodule
