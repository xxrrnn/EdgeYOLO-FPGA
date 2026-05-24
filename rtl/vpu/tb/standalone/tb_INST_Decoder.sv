`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// tb_INST_Decoder - INST_Decoder + INST_BRAM 功能验证测试
// 
// 目的: 验证流水线优化后的INST_BRAM和INST_Decoder功能一致性
// 测试场景:
//   1. 写入指令序列到INST_BRAM
//   2. 启动INST_Decoder读取和执行指令
//   3. 验证每条指令的解码结果是否正确
//////////////////////////////////////////////////////////////////////////////////

module tb_INST_Decoder();

    // 时钟和复位
    reg clk;
    reg rst_n;
    
    // INST_BRAM AXI接口
    reg  [19:0] s_axi_awaddr;
    reg  [2:0]  s_axi_awprot;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;
    reg  [19:0] s_axi_araddr;
    reg  [2:0]  s_axi_arprot;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;
    
    // INST_Decoder接口
    reg         decoder_start;
    reg  [31:0] inst_count;
    wire        decoder_busy;
    wire        decoder_done;
    wire [31:0] decoder_status;
    
    // VPU/CDMA接口（简化）
    wire        cdma_start;
    wire        cdma_config_valid;
    reg         cdma_config_ready;
    wire [31:0] cdma_src_addr_lsb;
    wire [31:0] cdma_dst_addr_lsb;
    wire [31:0] cdma_length;
    
    wire        vpu_start;
    reg         vpu_ready;
    wire [31:0] vpu_unit_choose;
    wire [31:0] vpu_src_addr;
    wire [31:0] vpu_dst_addr;
    
    // INST_BRAM内部连接
    wire [17:0] inst_rd_addr;
    wire [31:0] inst_rd_data;
    
    // 时钟生成 (250MHz)
    initial begin
        clk = 0;
        forever #2 clk = ~clk;  // 4ns周期
    end
    
    // 实例化 INST_BRAM
    INST_BRAM #(
        .DEPTH(262144),
        .ADDR_WIDTH(18),
        .AXI_ADDR_WIDTH(20),
        .AXI_DATA_WIDTH(32),
        .ENABLE_PIPELINE(1)  // 启用流水线优化
    ) u_inst_bram (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .inst_rd_addr(inst_rd_addr),
        .inst_rd_data(inst_rd_data)
    );
    
    // 实例化 INST_Decoder
    INST_Decoder #(
        .INST_BRAM_DEPTH(32768),
        .INST_ADDR_WIDTH(15)
    ) u_inst_decoder (
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
        .cdma_src_addr_msb(),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length(cdma_length),
        .vpu_start(vpu_start),
        .vpu_ready(vpu_ready),
        .vpu_unit_choose(vpu_unit_choose),
        .vpu_src_addr(vpu_src_addr),
        .vpu_src2_addr(),
        .vpu_src_c(),
        .vpu_src_h(),
        .vpu_src_w(),
        .vpu_bias_addr(),
        .vpu_scale_addr(),
        .vpu_dst_addr(vpu_dst_addr),
        .vpu_addr_break(),
        .vpu_addr_s(),
        .vpu_addr_t()
    );
    
    // 测试任务：AXI写入（简化为同步阻塞模式）
    task axi_write(input [19:0] addr, input [31:0] data);
        begin
            s_axi_awaddr = addr;
            s_axi_awvalid = 1'b1;
            s_axi_wdata = data;
            s_axi_wstrb = 4'hF;
            s_axi_wvalid = 1'b1;
            
            // 等待写入地址和数据都被接受
            while (!(s_axi_awready && s_axi_wready)) begin
                @(posedge clk);
            end
            
            @(posedge clk);
            s_axi_awvalid = 1'b0;
            s_axi_wvalid = 1'b0;
            
            // 等待写响应
            s_axi_bready = 1'b1;
            while (!s_axi_bvalid) begin
                @(posedge clk);
            end
            
            @(posedge clk);
            s_axi_bready = 1'b0;
            
            // 额外等待一个周期确保事务完成
            @(posedge clk);
        end
    endtask
    
    // 测试序列
    integer pass_count, fail_count;
    
    initial begin
        // 初始化
        rst_n = 0;
        decoder_start = 0;
        inst_count = 0;
        cdma_config_ready = 1;
        vpu_ready = 1;
        s_axi_awvalid = 0;
        s_axi_wvalid = 0;
        s_axi_bready = 0;
        s_axi_arvalid = 0;
        s_axi_rready = 0;
        pass_count = 0;
        fail_count = 0;
        
        $display("========================================");
        $display("INST_Decoder + INST_BRAM 功能测试");
        $display("目标: 验证流水线优化后的功能一致性");
        $display("========================================");
        
        // 复位
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        // ========================================
        // 测试1: 写入简单指令序列
        // ========================================
        $display("\n[测试1] 写入指令序列到BRAM");
        
        // 指令0: NOP (Header: 0x0000_0000)
        axi_write(20'h0, 32'h0000_0000);
        
        // 指令1: CDMA_COPY (Header: 0x1000_000C, Body: src=0x1000, dst=0x2000, len=0x100)
        axi_write(20'h4, 32'h1000_000C);
        axi_write(20'h8, 32'h0000_1000);  // src_addr
        axi_write(20'hC, 32'h0000_2000);  // dst_addr
        axi_write(20'h10, 32'h0000_0100); // length
        
        // 指令2: VPU_EXEC (Header: 0x2000_0030, Body: 12个32位字)
        axi_write(20'h14, 32'h2000_0030);
        axi_write(20'h18, 32'h0000_0001); // unit_choose
        axi_write(20'h1C, 32'h0000_3000); // src_addr
        axi_write(20'h20, 32'h0000_3100); // src2_addr
        axi_write(20'h24, 32'h0000_0010); // src_c
        axi_write(20'h28, 32'h0000_0020); // src_h
        axi_write(20'h2C, 32'h0000_0020); // src_w
        axi_write(20'h30, 32'h0000_4000); // bias_addr
        axi_write(20'h34, 32'h0000_5000); // scale_addr
        axi_write(20'h38, 32'h0000_6000); // dst_addr
        axi_write(20'h3C, 32'h0000_0000); // addr_break
        axi_write(20'h40, 32'h0000_0000); // addr_s
        axi_write(20'h44, 32'h0000_0000); // addr_t
        
        // 指令3: END (Header: 0xF000_0000)
        axi_write(20'h48, 32'hF000_0000);
        
        $display("[测试1] 指令写入完成");
        repeat(10) @(posedge clk);
        
        // ========================================
        // 测试2: 启动Decoder并验证
        // ========================================
        $display("\n[测试2] 启动INST_Decoder");
        
        inst_count = 32'd19;  // 总共19个32位字 (1+4+13+1)
        decoder_start = 1;
        @(posedge clk);
        decoder_start = 0;
        
        // 等待decoder开始
        wait(decoder_busy);
        $display("[测试2] Decoder已启动, 状态=0x%08x", decoder_status);
        
        // 监控CDMA指令执行
        @(posedge cdma_start);
        $display("[测试2] 检测到CDMA_COPY指令:");
        $display("         src_addr=0x%08x", cdma_src_addr_lsb);
        $display("         dst_addr=0x%08x", cdma_dst_addr_lsb);
        $display("         length  =0x%08x", cdma_length);
        
        if (cdma_src_addr_lsb == 32'h0000_1000 &&
            cdma_dst_addr_lsb == 32'h0000_2000 &&
            cdma_length == 32'h0000_0100) begin
            $display("         [PASS] CDMA参数正确");
            pass_count = pass_count + 1;
        end else begin
            $display("         [FAIL] CDMA参数错误");
            fail_count = fail_count + 1;
        end
        
        // 监控VPU指令执行
        @(posedge vpu_start);
        $display("[测试2] 检测到VPU_EXEC指令:");
        $display("         unit_choose=0x%08x", vpu_unit_choose);
        $display("         src_addr   =0x%08x", vpu_src_addr);
        $display("         dst_addr   =0x%08x", vpu_dst_addr);
        
        if (vpu_unit_choose == 32'h0000_0001 &&
            vpu_src_addr == 32'h0000_3000 &&
            vpu_dst_addr == 32'h0000_6000) begin
            $display("         [PASS] VPU参数正确");
            pass_count = pass_count + 1;
        end else begin
            $display("         [FAIL] VPU参数错误");
            fail_count = fail_count + 1;
        end
        
        // 等待decoder完成
        wait(decoder_done);
        $display("[测试2] Decoder执行完成, 状态=0x%08x", decoder_status);
        
        if (decoder_status == 32'h0000_0002) begin  // STATUS_DONE
            $display("         [PASS] Decoder正常完成");
            pass_count = pass_count + 1;
        end else begin
            $display("         [FAIL] Decoder状态异常");
            fail_count = fail_count + 1;
        end
        
        repeat(20) @(posedge clk);
        
        // ========================================
        // 测试总结
        // ========================================
        $display("\n========================================");
        $display("测试总结:");
        $display("  通过: %0d", pass_count);
        $display("  失败: %0d", fail_count);
        if (fail_count == 0) begin
            $display("  结果: 全部测试通过! ✓");
        end else begin
            $display("  结果: 存在失败测试! ✗");
        end
        $display("========================================");
        
        $finish;
    end
    
    // 超时保护
    initial begin
        #10000000;  // 10ms timeout
        $display("\n[ERROR] 测试超时!");
        $finish;
    end
    
    // 波形输出
    initial begin
        $dumpfile("tb_INST_Decoder.vcd");
        $dumpvars(0, tb_INST_Decoder);
    end

endmodule
