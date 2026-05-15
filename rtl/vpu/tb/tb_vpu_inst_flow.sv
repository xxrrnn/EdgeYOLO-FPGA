`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// VPU 指令解码器完整流程测试 Testbench
// 
// 测试流程:
// 1. 将指令序列写入 inst_bram
// 2. 配置 decoder 读取指令  
// 3. decoder 解码并控制 CDMA 执行数据搬运
// 4. 验证数据搬运结果
////////////////////////////////////////////////////////////////////////////////

module tb_vpu_inst_flow;

    // =========================================================================
    // 参数定义
    // =========================================================================
    localparam CLK_PERIOD = 10; // 100MHz
    
    // 指令操作码
    localparam OP_NOP       = 4'h0;
    localparam OP_CDMA_COPY = 4'h1;
    localparam OP_VPU_EXEC  = 4'h2;
    localparam OP_WAIT_CDMA = 4'h3;
    localparam OP_WAIT_VPU  = 4'h4;
    localparam OP_SYNC      = 4'h5;
    localparam OP_END       = 4'hF;
    
    // 地址定义
    localparam GLOBAL_BRAM_BASE = 32'h10000000;
    localparam VPU_GB_BASE      = 32'h10400000;
    
    // =========================================================================
    // 信号定义
    // =========================================================================
    reg clk;
    reg rst_n;
    
    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // =========================================================================
    // Inst BRAM (256 x 32-bit)
    // =========================================================================
    reg  [31:0] inst_bram [0:255];
    wire [17:0] inst_rd_addr;
    reg  [31:0] inst_rd_data;
    
    // Inst BRAM 读取（1周期延迟）
    always @(posedge clk) begin
        inst_rd_data <= inst_bram[inst_rd_addr[7:0]];
    end
    
    // =========================================================================
    // Global BRAM (4KB)
    // =========================================================================
    reg [31:0] global_bram [0:1023];
    
    // =========================================================================
    // Decoder 控制接口
    // =========================================================================
    reg         decoder_start;
    reg  [31:0] inst_count;
    wire        decoder_busy;
    wire        decoder_done;
    wire [31:0] decoder_status;
    
    // =========================================================================
    // CDMA Controller 接口
    // =========================================================================
    wire        cdma_start;
    wire        cdma_config_valid;
    wire        cdma_config_ready;
    wire [31:0] cdma_src_addr_msb;
    wire [31:0] cdma_src_addr_lsb;
    wire [31:0] cdma_dst_addr_msb;
    wire [31:0] cdma_dst_addr_lsb;
    wire [31:0] cdma_length;
    
    // =========================================================================
    // INST_Decoder 实例
    // =========================================================================
    INST_Decoder u_inst_decoder (
        .clk                (clk),
        .rst_n              (rst_n),
        
        // Inst BRAM 接口
        .inst_rd_addr       (inst_rd_addr),
        .inst_rd_data       (inst_rd_data),
        
        // 控制接口
        .decoder_start      (decoder_start),
        .inst_count         (inst_count),
        .decoder_busy       (decoder_busy),
        .decoder_done       (decoder_done),
        .decoder_status     (decoder_status),
        
        // CDMA 控制接口
        .cdma_start         (cdma_start),
        .cdma_config_valid  (cdma_config_valid),
        .cdma_config_ready  (cdma_config_ready),
        .cdma_src_addr_msb  (cdma_src_addr_msb),
        .cdma_src_addr_lsb  (cdma_src_addr_lsb),
        .cdma_dst_addr_msb  (cdma_dst_addr_msb),
        .cdma_dst_addr_lsb  (cdma_dst_addr_lsb),
        .cdma_length        (cdma_length),
        
        // VPU 控制接口（本测试不使用）
        .vpu_start          (),
        .vpu_ready          (1'b1),
        .vpu_unit_choose    (),
        .vpu_src_addr       (),
        .vpu_src2_addr      (),
        .vpu_src_c          (),
        .vpu_src_h          (),
        .vpu_src_w          (),
        .vpu_bias_addr      (),
        .vpu_scale_addr     (),
        .vpu_dst_addr       (),
        .vpu_addr_break     (),
        .vpu_addr_s         (),
        .vpu_addr_t         ()
    );
    
    // 调试输出已移除，生产版本不需要
    // 可根据需要重新添加调试语句

    
    // =========================================================================
    // 简化的 CDMA 模拟器
    // INST_Decoder期望的行为:
    // 1. ready=1时可以接受新配置
    // 2. 接受配置后ready拉低，表示CDMA忙
    // 3. 传输完成后ready拉高，表示CDMA空闲
    // =========================================================================
    reg  cdma_active;
    reg  [31:0] cdma_pending_src;
    reg  [31:0] cdma_pending_dst;
    reg  [31:0] cdma_pending_len;
    reg  [15:0] cdma_delay_counter;
    reg  cdma_config_ready_reg;
    
    assign cdma_config_ready = cdma_config_ready_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cdma_active <= 1'b0;
            cdma_delay_counter <= 16'd0;
            cdma_config_ready_reg <= 1'b1;  // 初始状态ready
        end else begin
            if (!cdma_active) begin
                // 空闲状态：等待新命令
                if (cdma_config_valid && cdma_config_ready_reg) begin
                    // 接受配置
                    cdma_active <= 1'b1;
                    cdma_config_ready_reg <= 1'b0;  // 拉低ready表示忙
                    cdma_pending_src <= cdma_src_addr_lsb;
                    cdma_pending_dst <= cdma_dst_addr_lsb;
                    cdma_pending_len <= cdma_length;
                    cdma_delay_counter <= (cdma_length >> 2) + 16'd10;
                    $display("[%0t] CDMA Start: 0x%08X → 0x%08X (%0d bytes)", 
                             $time, cdma_src_addr_lsb, cdma_dst_addr_lsb, cdma_length);
                end
            end else begin
                // 传输中
                if (cdma_delay_counter > 1) begin
                    cdma_delay_counter <= cdma_delay_counter - 1;
                end else if (cdma_delay_counter == 1) begin
                    // 传输完成
                    cdma_transfer(cdma_pending_src, cdma_pending_dst, cdma_pending_len);
                    cdma_delay_counter <= 16'd0;
                    cdma_active <= 1'b0;
                    cdma_config_ready_reg <= 1'b1;  // 拉高ready表示完成
                    $display("[%0t] CDMA Done", $time);
                end
            end
        end
    end
    
    // =========================================================================
    // CDMA 数据传输函数
    // =========================================================================
    task cdma_transfer;
        input [31:0] src_addr;
        input [31:0] dst_addr;
        input [31:0] length;
        integer i;
        reg [31:0] src_idx, dst_idx;
        reg [31:0] data;
    begin
        // 计算 global_bram 索引（地址 - 基地址）/ 4
        src_idx = (src_addr - GLOBAL_BRAM_BASE) >> 2;
        dst_idx = (dst_addr - GLOBAL_BRAM_BASE) >> 2;
        
        // 按字传输
        for (i = 0; i < (length >> 2); i = i + 1) begin
            data = global_bram[src_idx + i];
            global_bram[dst_idx + i] = data;
            if (i < 4) begin
                $display("  [%0d] 0x%08X: 0x%08X", i, dst_addr + (i*4), data);
            end
        end
    end
    endtask
    
    // =========================================================================
    // 辅助函数：构造指令头
    // =========================================================================
    function [31:0] make_header;
        input [3:0]  opcode;
        input [23:0] body_length;
        input [3:0]  flags;
    begin
        make_header = {opcode, flags, body_length};
    end
    endfunction
    
    // =========================================================================
    // 辅助函数：写入指令到 inst_bram
    // =========================================================================
    task write_inst;
        input [31:0] addr;  // Word 地址
        input [31:0] data;
    begin
        inst_bram[addr] = data;
    end
    endtask
    
    // =========================================================================
    // 辅助函数：写入数据到 global_bram
    // =========================================================================
    task write_global;
        input [31:0] addr;  // Word 地址
        input [31:0] data;
    begin
        global_bram[addr] = data;
    end
    endtask
    
    // =========================================================================
    // 辅助函数：读取 global_bram
    // =========================================================================
    function [31:0] read_global;
        input [31:0] addr;  // Word 地址
    begin
        read_global = global_bram[addr];
    end
    endfunction
    
    // =========================================================================
    // 测试用例 1: 单个 CDMA 搬运指令
    // =========================================================================
    task test_single_cdma;
        integer i;
        integer errors;
    begin
        $display("\n========================================");
        $display("测试 1: 单个 CDMA 搬运指令");
        $display("========================================");
        
        // 1. 准备源数据（64 words = 256 bytes）
        for (i = 0; i < 64; i = i + 1) begin
            write_global(i, 32'h1000 + i);
        end
        
        // 2. 清空目标区域
        for (i = 64; i < 128; i = i + 1) begin
            write_global(i, 32'hDEADBEEF);
        end
        
        // 3. 构建指令序列
        // Inst 0: CDMA_COPY(src=0x10000000, dst=0x10000100, len=256)
        write_inst(0, make_header(OP_CDMA_COPY, 24'd12, 4'h0));
        write_inst(1, GLOBAL_BRAM_BASE);                    // src_addr
        write_inst(2, GLOBAL_BRAM_BASE + 32'h100);          // dst_addr
        write_inst(3, 32'd256);                             // length
        
        // Inst 4: WAIT_CDMA
        write_inst(4, make_header(OP_WAIT_CDMA, 24'd0, 4'h0));
        
        // Inst 5: END
        write_inst(5, make_header(OP_END, 24'd0, 4'h0));
        
        // 4. 启动解码器
        inst_count = 32'd6;  
        repeat(2) @(posedge clk);  
        decoder_start = 1'b1;
        repeat(2) @(posedge clk);  
        decoder_start = 1'b0;
        
        // 5. 等待完成
        wait(decoder_done);
        repeat(5) @(posedge clk);
        
        // 6. 验证结果
        errors = 0;
        for (i = 0; i < 64; i = i + 1) begin
            if (read_global(64 + i) !== read_global(i)) begin
                $display("  [错误] Addr 0x%08X: expect 0x%08X, got 0x%08X",
                         GLOBAL_BRAM_BASE + (64+i)*4,
                         read_global(i),
                         read_global(64 + i));
                errors = errors + 1;
            end
        end
        
        if (errors == 0) begin
            $display("✓ 测试 1 通过: 256 字节数据搬运正确");
        end else begin
            $display("✗ 测试 1 失败: %0d 个错误", errors);
        end
    end
    endtask
    
    // =========================================================================
    // 测试用例 2: 多个 CDMA 搬运指令
    // =========================================================================
    task test_multiple_cdma;
        integer i;
        integer errors;
    begin
        $display("\n========================================");
        $display("测试 2: 多个 CDMA 搬运指令");
        $display("========================================");
        
        // 1. 准备源数据
        for (i = 0; i < 64; i = i + 1) begin
            write_global(i, 32'h2000 + i);
        end
        
        // 2. 清空中间和目标区域
        for (i = 64; i < 192; i = i + 1) begin
            write_global(i, 32'hAAAAAAAA);
        end
        
        // 3. 构建指令序列：两次搬运形成链式传输
        // Inst 0-3: CDMA_COPY(0x10000000 → 0x10000100, 256B)
        write_inst(0, make_header(OP_CDMA_COPY, 24'd12, 4'h0));
        write_inst(1, GLOBAL_BRAM_BASE);
        write_inst(2, GLOBAL_BRAM_BASE + 32'h100);
        write_inst(3, 32'd256);
        
        // Inst 4: WAIT_CDMA
        write_inst(4, make_header(OP_WAIT_CDMA, 24'd0, 4'h0));
        
        // Inst 5-8: CDMA_COPY(0x10000100 → 0x10000200, 256B)
        write_inst(5, make_header(OP_CDMA_COPY, 24'd12, 4'h0));
        write_inst(6, GLOBAL_BRAM_BASE + 32'h100);
        write_inst(7, GLOBAL_BRAM_BASE + 32'h200);
        write_inst(8, 32'd256);
        
        // Inst 9: WAIT_CDMA
        write_inst(9, make_header(OP_WAIT_CDMA, 24'd0, 4'h0));
        
        // Inst 10: END
        write_inst(10, make_header(OP_END, 24'd0, 4'h0));
        
        // 4. 启动解码器
        inst_count = 32'd11;
        @(posedge clk);
        decoder_start = 1'b1;
        @(posedge clk);
        decoder_start = 1'b0;
        
        // 5. 等待完成
        wait(decoder_done);
        repeat(5) @(posedge clk);
        
        // 6. 验证最终结果（0x200 处应该等于源数据）
        errors = 0;
        for (i = 0; i < 64; i = i + 1) begin
            if (read_global(128 + i) !== read_global(i)) begin
                $display("  [错误] Addr 0x%08X: expect 0x%08X, got 0x%08X",
                         GLOBAL_BRAM_BASE + (128+i)*4,
                         read_global(i),
                         read_global(128 + i));
                errors = errors + 1;
            end
        end
        
        if (errors == 0) begin
            $display("✓ 测试 2 通过: 链式搬运正确");
        end else begin
            $display("✗ 测试 2 失败: %0d 个错误", errors);
        end
    end
    endtask
    
    // =========================================================================
    // 主测试流程
    // =========================================================================
    initial begin
        $display("\n");
        $display("================================================================================");
        $display("  VPU 指令解码器完整流程测试");
        $display("================================================================================");
        
        // 初始化
        rst_n = 1'b0;
        decoder_start = 1'b0;
        inst_count = 32'd0;
        
        // 复位
        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);
        
        // 运行测试
        test_single_cdma();
        repeat(10) @(posedge clk);
        
        test_multiple_cdma();
        repeat(10) @(posedge clk);
        
        // 结束
        $display("\n================================================================================");
        $display("  所有测试完成");
        $display("================================================================================\n");
        $finish;
    end
    
    // 超时保护
    initial begin
        #1000000;  // 1ms 超时
        $display("\n[ERROR] 仿真超时!");
        $finish;
    end
    
    // 波形转储
    initial begin
        $dumpfile("tb_vpu_inst_flow.vcd");
        $dumpvars(0, tb_vpu_inst_flow);
    end

endmodule
