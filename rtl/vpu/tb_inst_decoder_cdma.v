`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// INST_Decoder Testbench - 测试 CDMA 数据搬运指令
//////////////////////////////////////////////////////////////////////////////////

module tb_inst_decoder_cdma();

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
    
    // VPU 接口（未使用，但需要连接）
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
    reg [31:0] inst_mem [0:63];
    
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
        if (inst_rd_addr < 64)
            inst_rd_data <= inst_mem[inst_rd_addr];
        else
            inst_rd_data <= 32'h0;
    end
    
    // CDMA_Controller 行为模拟
    reg cdma_busy;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cdma_config_ready <= 1'b1;
            cdma_busy <= 1'b0;
        end else begin
            if (cdma_start && cdma_config_valid && cdma_config_ready) begin
                // 接受配置
                $display("[%0t] CDMA 接收配置: src=0x%08X, dst=0x%08X, len=%0d", 
                         $time, cdma_src_addr_lsb, cdma_dst_addr_lsb, cdma_length);
                cdma_config_ready <= 1'b0;
                cdma_busy <= 1'b1;
                // 模拟 CDMA 传输延迟
                #100;
                cdma_busy <= 1'b0;
                cdma_config_ready <= 1'b1;
                $display("[%0t] CDMA 传输完成", $time);
            end
        end
    end
    
    // 测试任务
    reg done_flag;
    task wait_decoder_done;
        input integer timeout_cycles;
        integer cnt;
        begin
            cnt = 0;
            done_flag = 0;
            while (!done_flag && cnt < timeout_cycles) begin
                @(posedge clk);
                if (decoder_done)
                    done_flag = 1;
                cnt = cnt + 1;
            end
            if (done_flag)
                $display("[%0t] ✓ 解码器完成执行", $time);
            else
                $display("[%0t] ✗ 解码器超时 (status=0x%08X)", $time, decoder_status);
        end
    endtask
    
    // 主测试流程
    initial begin
        $display("========================================");
        $display("INST_Decoder CDMA 测试");
        $display("========================================");
        
        // 初始化
        rst_n = 0;
        decoder_start = 0;
        inst_count = 0;
        vpu_ready = 1;
        
        // 初始化指令存储
        for (integer i = 0; i < 64; i = i + 1)
            inst_mem[i] = 32'h0;
        
        // 准备测试指令序列
        // 指令格式：[31:28] OPCODE | [27:24] FLAGS | [23:0] BODY_LENGTH
        
        // Instruction 0: CDMA_COPY (opcode=0x1, body_length=12)
        inst_mem[0] = 32'h1000000C;  // Header
        inst_mem[1] = 32'h10000000;  // src_addr
        inst_mem[2] = 32'h20000000;  // dst_addr
        inst_mem[3] = 32'h00000100;  // length = 256 bytes
        
        // Instruction 1: WAIT_CDMA (opcode=0x3)
        inst_mem[4] = 32'h30000000;  // Header
        
        // Instruction 2: END (opcode=0xF)
        inst_mem[5] = 32'hF0000000;  // Header
        
        $display("[%0t] 指令序列已准备:", $time);
        $display("  [0] CDMA_COPY: 0x10000000 -> 0x20000000, 256B");
        $display("  [4] WAIT_CDMA");
        $display("  [5] END");
        
        // 复位
        #20;
        rst_n = 1;
        #20;
        
        // 启动解码器
        $display("[%0t] 启动解码器 (inst_count=6)", $time);
        inst_count = 6;
        decoder_start = 1;
        @(posedge clk);
        decoder_start = 0;
        
        // 等待完成
        wait_decoder_done(1000);
        
        // 检查结果
        #100;
        if (done_flag && !decoder_busy) begin
            $display("========================================");
            $display("✓ 测试通过");
            $display("========================================");
        end else begin
            $display("========================================");
            $display("✗ 测试失败");
            $display("  decoder_busy=%b, done_flag=%b", decoder_busy, done_flag);
            $display("  decoder_status=0x%08X", decoder_status);
            $display("========================================");
        end
        
        #100;
        $finish;
    end
    
    // 超时保护
    initial begin
        #50000;
        $display("[%0t] ✗ 仿真超时", $time);
        $finish;
    end
    
    // 监控关键信号
    always @(posedge clk) begin
        if (decoder_busy && !decoder_done) begin
            if (cdma_start)
                $display("[%0t] cdma_start=1, cdma_config_valid=%b, cdma_config_ready=%b", 
                         $time, cdma_config_valid, cdma_config_ready);
        end
    end
    
    // 监控状态机状态
    always @(posedge clk) begin
        if (dut.state != dut.next_state) begin
            $display("[%0t] State: %0d -> %0d (body_word_idx=%0d, body_word_count=%0d, opcode=0x%X)", 
                     $time, dut.state, dut.next_state, 
                     dut.body_word_idx, dut.body_word_count, dut.current_opcode);
        end
        if (dut.state == 3) begin  // S_PARSE_HEADER
            $display("[%0t]   inst_rd_data=0x%08X, body_length=%0d", 
                     $time, inst_rd_data, inst_rd_data[23:0]);
        end
    end

endmodule
