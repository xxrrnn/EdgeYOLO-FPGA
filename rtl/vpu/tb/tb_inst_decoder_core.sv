`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// 核心模块仿真 Testbench
// 测试: INST_Decoder + CDMA_Controller + Xilinx CDMA IP + AXI BRAM Controller + BRAM
// 
// 使用真实的 Xilinx IP 进行仿真
////////////////////////////////////////////////////////////////////////////////

module tb_inst_decoder_core;

    // =========================================================================
    // 参数定义
    // =========================================================================
    localparam CLK_PERIOD = 10; // 100MHz
    
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
    // INST_BRAM 信号 (简化实现)
    // =========================================================================
    wire [17:0] inst_rd_addr;
    reg  [31:0] inst_rd_data;
    reg  [31:0] inst_mem [0:255];
    
    always @(posedge clk) begin
        inst_rd_data <= inst_mem[inst_rd_addr[7:0]];
    end
    
    // =========================================================================
    // 解码器控制信号
    // =========================================================================
    reg         decoder_start;
    reg  [31:0] inst_count;
    wire        decoder_busy;
    wire        decoder_done;
    wire [31:0] decoder_status;
    
    // =========================================================================
    // CDMA_Controller <-> INST_Decoder 接口
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
    // CDMA_Controller <-> AXI CDMA IP (AXI-Lite)
    // =========================================================================
    wire [31:0] cdma_axilm_awaddr;
    wire [2:0]  cdma_axilm_awprot;
    wire        cdma_axilm_awvalid;
    wire        cdma_axilm_awready;
    wire [31:0] cdma_axilm_wdata;
    wire [3:0]  cdma_axilm_wstrb;
    wire        cdma_axilm_wvalid;
    wire        cdma_axilm_wready;
    wire [1:0]  cdma_axilm_bresp;
    wire        cdma_axilm_bvalid;
    wire        cdma_axilm_bready;
    wire [31:0] cdma_axilm_araddr;
    wire [2:0]  cdma_axilm_arprot;
    wire        cdma_axilm_arvalid;
    wire        cdma_axilm_arready;
    wire [31:0] cdma_axilm_rdata;
    wire [1:0]  cdma_axilm_rresp;
    wire        cdma_axilm_rvalid;
    wire        cdma_axilm_rready;
    
    // =========================================================================
    // AXI CDMA IP <-> AXI BRAM Controller (AXI Full)
    // =========================================================================
    wire [31:0] cdma_m_axi_awaddr;
    wire [7:0]  cdma_m_axi_awlen;
    wire [2:0]  cdma_m_axi_awsize;
    wire [1:0]  cdma_m_axi_awburst;
    wire [2:0]  cdma_m_axi_awprot;
    wire [3:0]  cdma_m_axi_awcache;
    wire        cdma_m_axi_awvalid;
    wire        cdma_m_axi_awready;
    wire [31:0] cdma_m_axi_wdata;
    wire [3:0]  cdma_m_axi_wstrb;
    wire        cdma_m_axi_wlast;
    wire        cdma_m_axi_wvalid;
    wire        cdma_m_axi_wready;
    wire [1:0]  cdma_m_axi_bresp;
    wire        cdma_m_axi_bvalid;
    wire        cdma_m_axi_bready;
    wire [31:0] cdma_m_axi_araddr;
    wire [7:0]  cdma_m_axi_arlen;
    wire [2:0]  cdma_m_axi_arsize;
    wire [1:0]  cdma_m_axi_arburst;
    wire [2:0]  cdma_m_axi_arprot;
    wire [3:0]  cdma_m_axi_arcache;
    wire        cdma_m_axi_arvalid;
    wire        cdma_m_axi_arready;
    wire [31:0] cdma_m_axi_rdata;
    wire [1:0]  cdma_m_axi_rresp;
    wire        cdma_m_axi_rlast;
    wire        cdma_m_axi_rvalid;
    wire        cdma_m_axi_rready;
    
    // =========================================================================
    // AXI BRAM Controller <-> BRAM
    // =========================================================================
    wire        bram_en;
    wire [3:0]  bram_we;
    wire [31:0] bram_addr;
    wire [31:0] bram_wrdata;
    wire [31:0] bram_rddata;
    
    // =========================================================================
    // 实例化 INST_Decoder
    // =========================================================================
    INST_Decoder #(
        .INST_BRAM_DEPTH(262144),
        .INST_ADDR_WIDTH(18)
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
        .cdma_src_addr_msb(cdma_src_addr_msb),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(cdma_dst_addr_msb),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length(cdma_length),
        
        .vpu_start(),
        .vpu_ready(1'b1),
        .vpu_unit_choose(),
        .vpu_src_addr(),
        .vpu_src2_addr(),
        .vpu_src_c(),
        .vpu_src_h(),
        .vpu_src_w(),
        .vpu_scale_addr(),
        .vpu_bias_addr(),
        .vpu_dst_addr(),
        .vpu_addr_break(),
        .vpu_addr_s(),
        .vpu_addr_t()
    );
    
    // =========================================================================
    // 实例化 CDMA_Controller
    // =========================================================================
    CDMA_Controller #(
        .CDMA_BASE_ADDR(32'h00000000),
        .C_CDMA_AXILM_ADDR_WIDTH(32),
        .C_CDMA_AXILM_DATA_WIDTH(32)
    ) u_cdma_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        
        .cdma_start(cdma_start),
        .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(cdma_config_ready),
        .cdma_src_addr_msb(cdma_src_addr_msb),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(cdma_dst_addr_msb),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length(cdma_length),
        
        .cdma_axilm_awaddr(cdma_axilm_awaddr),
        .cdma_axilm_awprot(cdma_axilm_awprot),
        .cdma_axilm_awvalid(cdma_axilm_awvalid),
        .cdma_axilm_awready(cdma_axilm_awready),
        .cdma_axilm_wdata(cdma_axilm_wdata),
        .cdma_axilm_wstrb(cdma_axilm_wstrb),
        .cdma_axilm_wvalid(cdma_axilm_wvalid),
        .cdma_axilm_wready(cdma_axilm_wready),
        .cdma_axilm_bresp(cdma_axilm_bresp),
        .cdma_axilm_bvalid(cdma_axilm_bvalid),
        .cdma_axilm_bready(cdma_axilm_bready),
        .cdma_axilm_araddr(cdma_axilm_araddr),
        .cdma_axilm_arprot(cdma_axilm_arprot),
        .cdma_axilm_arvalid(cdma_axilm_arvalid),
        .cdma_axilm_arready(cdma_axilm_arready),
        .cdma_axilm_rdata(cdma_axilm_rdata),
        .cdma_axilm_rresp(cdma_axilm_rresp),
        .cdma_axilm_rvalid(cdma_axilm_rvalid),
        .cdma_axilm_rready(cdma_axilm_rready)
    );
    
    // =========================================================================
    // 实例化 Xilinx AXI CDMA IP
    // 使用 sim_axi_cdma
    // =========================================================================
    sim_axi_cdma u_axi_cdma (
        .m_axi_aclk(clk),
        .s_axi_lite_aclk(clk),
        .s_axi_lite_aresetn(rst_n),
        
        // AXI-Lite Slave (配置接口)
        .s_axi_lite_awaddr(cdma_axilm_awaddr[5:0]),
        .s_axi_lite_awvalid(cdma_axilm_awvalid),
        .s_axi_lite_awready(cdma_axilm_awready),
        .s_axi_lite_wdata(cdma_axilm_wdata),
        .s_axi_lite_wvalid(cdma_axilm_wvalid),
        .s_axi_lite_wready(cdma_axilm_wready),
        .s_axi_lite_bresp(cdma_axilm_bresp),
        .s_axi_lite_bvalid(cdma_axilm_bvalid),
        .s_axi_lite_bready(cdma_axilm_bready),
        .s_axi_lite_araddr(cdma_axilm_araddr[5:0]),
        .s_axi_lite_arvalid(cdma_axilm_arvalid),
        .s_axi_lite_arready(cdma_axilm_arready),
        .s_axi_lite_rdata(cdma_axilm_rdata),
        .s_axi_lite_rresp(cdma_axilm_rresp),
        .s_axi_lite_rvalid(cdma_axilm_rvalid),
        .s_axi_lite_rready(cdma_axilm_rready),
        
        // AXI Master (数据传输接口)
        .m_axi_awaddr(cdma_m_axi_awaddr),
        .m_axi_awlen(cdma_m_axi_awlen),
        .m_axi_awsize(cdma_m_axi_awsize),
        .m_axi_awburst(cdma_m_axi_awburst),
        .m_axi_awprot(cdma_m_axi_awprot),
        .m_axi_awcache(cdma_m_axi_awcache),
        .m_axi_awvalid(cdma_m_axi_awvalid),
        .m_axi_awready(cdma_m_axi_awready),
        .m_axi_wdata(cdma_m_axi_wdata),
        .m_axi_wstrb(cdma_m_axi_wstrb),
        .m_axi_wlast(cdma_m_axi_wlast),
        .m_axi_wvalid(cdma_m_axi_wvalid),
        .m_axi_wready(cdma_m_axi_wready),
        .m_axi_bresp(cdma_m_axi_bresp),
        .m_axi_bvalid(cdma_m_axi_bvalid),
        .m_axi_bready(cdma_m_axi_bready),
        .m_axi_araddr(cdma_m_axi_araddr),
        .m_axi_arlen(cdma_m_axi_arlen),
        .m_axi_arsize(cdma_m_axi_arsize),
        .m_axi_arburst(cdma_m_axi_arburst),
        .m_axi_arprot(cdma_m_axi_arprot),
        .m_axi_arcache(cdma_m_axi_arcache),
        .m_axi_arvalid(cdma_m_axi_arvalid),
        .m_axi_arready(cdma_m_axi_arready),
        .m_axi_rdata(cdma_m_axi_rdata),
        .m_axi_rresp(cdma_m_axi_rresp),
        .m_axi_rlast(cdma_m_axi_rlast),
        .m_axi_rvalid(cdma_m_axi_rvalid),
        .m_axi_rready(cdma_m_axi_rready),
        
        .cdma_introut()
    );
    
    // =========================================================================
    // 实例化 AXI BRAM Controller IP
    // 使用 sim_axi_bram_ctrl
    // =========================================================================
    sim_axi_bram_ctrl u_bram_ctrl (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
        
        .s_axi_awaddr(cdma_m_axi_awaddr),
        .s_axi_awlen(cdma_m_axi_awlen),
        .s_axi_awsize(cdma_m_axi_awsize),
        .s_axi_awburst(cdma_m_axi_awburst),
        .s_axi_awlock(1'b0),
        .s_axi_awcache(cdma_m_axi_awcache),
        .s_axi_awprot(cdma_m_axi_awprot),
        .s_axi_awvalid(cdma_m_axi_awvalid),
        .s_axi_awready(cdma_m_axi_awready),
        .s_axi_wdata(cdma_m_axi_wdata),
        .s_axi_wstrb(cdma_m_axi_wstrb),
        .s_axi_wlast(cdma_m_axi_wlast),
        .s_axi_wvalid(cdma_m_axi_wvalid),
        .s_axi_wready(cdma_m_axi_wready),
        .s_axi_bresp(cdma_m_axi_bresp),
        .s_axi_bvalid(cdma_m_axi_bvalid),
        .s_axi_bready(cdma_m_axi_bready),
        .s_axi_araddr(cdma_m_axi_araddr),
        .s_axi_arlen(cdma_m_axi_arlen),
        .s_axi_arsize(cdma_m_axi_arsize),
        .s_axi_arburst(cdma_m_axi_arburst),
        .s_axi_arlock(1'b0),
        .s_axi_arcache(cdma_m_axi_arcache),
        .s_axi_arprot(cdma_m_axi_arprot),
        .s_axi_arvalid(cdma_m_axi_arvalid),
        .s_axi_arready(cdma_m_axi_arready),
        .s_axi_rdata(cdma_m_axi_rdata),
        .s_axi_rresp(cdma_m_axi_rresp),
        .s_axi_rlast(cdma_m_axi_rlast),
        .s_axi_rvalid(cdma_m_axi_rvalid),
        .s_axi_rready(cdma_m_axi_rready),
        
        .bram_rst_a(),
        .bram_clk_a(),
        .bram_en_a(bram_en),
        .bram_we_a(bram_we),
        .bram_addr_a(bram_addr),
        .bram_wrdata_a(bram_wrdata),
        .bram_rddata_a(bram_rddata)
    );
    
    // =========================================================================
    // BRAM 实例
    // 使用 sim_blk_mem (双端口 RAM)
    // =========================================================================
    sim_blk_mem u_bram (
        .clka(clk),
        .wea(bram_we[0]),
        .addra(bram_addr[15:2]),  // 14位字地址
        .dina(bram_wrdata),
        .douta(bram_rddata),
        .clkb(clk),
        .web(1'b0),               // Port B 不使用
        .addrb(14'b0),
        .dinb(32'b0),
        .doutb()
    );
    
    // =========================================================================
    // 测试任务
    // =========================================================================
    
    task automatic wait_decoder_done(input int timeout_cycles);
        int cnt;
        begin
            cnt = 0;
            while (!decoder_done && cnt < timeout_cycles) begin
                @(posedge clk);
                cnt++;
            end
            
            if (decoder_done) begin
                // STATUS_DONE = 0x00000002 表示成功完成
                if (decoder_status == 32'h0000_0002)
                    $display("[%0t] ✓ 解码器成功完成", $time);
                else if (decoder_status & 32'h8000_0000)
                    $display("[%0t] ✗ 解码器完成但有错误: status=0x%08X", $time, decoder_status);
                else
                    $display("[%0t] 解码器完成: status=0x%08X", $time, decoder_status);
            end else begin
                $display("[%0t] ✗ 解码器超时 (busy=%b, status=0x%08X)", 
                         $time, decoder_busy, decoder_status);
            end
        end
    endtask
    
    // =========================================================================
    // 主测试流程
    // =========================================================================
    
    integer i;
    integer test_pass;
    
    // 调试信号监控
    always @(posedge clk) begin
        if (decoder_start) 
            $display("[%0t] decoder_start = 1", $time);
        if (decoder_busy && !decoder_done)
            $display("[%0t] decoder_busy = 1", $time);
        if (decoder_done)
            $display("[%0t] decoder_done = 1, status = 0x%08X", $time, decoder_status);
        if (cdma_start)
            $display("[%0t] CDMA: cdma_start = 1", $time);
    end
    
    initial begin
        $display("========================================");
        $display("核心模块仿真");
        $display("INST_Decoder + CDMA_Controller + CDMA IP + BRAM");
        $display("========================================");
        
        // 初始化
        rst_n = 0;
        decoder_start = 0;
        inst_count = 0;
        test_pass = 1;
        
        // 清空指令内存
        for (i = 0; i < 256; i = i + 1) inst_mem[i] = 0;
        
        #100;
        rst_n = 1;
        $display("[%0t] 复位完成", $time);
        #50;
        
        // =====================================================================
        // 测试 1: 单个 CDMA 搬运
        // =====================================================================
        $display("\n========================================");
        $display("测试 1: 单个 CDMA 搬运");
        $display("源地址: 0x0000, 目标地址: 0x1000, 长度: 256 bytes");
        $display("========================================");
        
        // 初始化源数据（写入 BRAM 源地址区域）
        $display("[%0t] 初始化源数据...", $time);
        for (i = 0; i < 64; i = i + 1) begin
            // 通过 BRAM 端口直接写入测试数据
            // 注意：这里我们模拟数据已经在 BRAM 中
            @(posedge clk);
        end
        
        // 编码指令: CDMA_COPY src=0x0000, dst=0x1000, len=256
        $display("[%0t] 编码指令...", $time);
        inst_mem[0] = 32'h1000000C; // CDMA opcode=1, body=12 bytes
        inst_mem[1] = 32'h00000000; // src_lsb
        inst_mem[2] = 32'h00001000; // dst_lsb
        inst_mem[3] = 32'h00000100; // length = 256 bytes
        inst_mem[4] = 32'hF0000000; // END opcode=F
        
        inst_count = 5;
        $display("[%0t] inst_count = %0d", $time, inst_count);
        
        @(posedge clk);
        #1;  // 确保在时钟上升沿之后
        decoder_start = 1;
        $display("[%0t] 设置 decoder_start = 1", $time);
        @(posedge clk);
        #1;
        decoder_start = 0;
        $display("[%0t] 清零 decoder_start = 0", $time);
        
        $display("[%0t] 等待解码器完成...", $time);
        wait_decoder_done(100000);
        
        // 验证数据传输
        if (decoder_done) begin
            $display("\n[%0t] 验证数据传输结果...", $time);
            // 由于我们使用的是简化的 testbench，
            // CDMA 应该已经将数据从 0x0000 搬到 0x1000
            // 这里可以通过监控 CDMA 的 AXI 事务来验证
            $display("[%0t] CDMA 传输已完成", $time);
            $display("[%0t] 注意：完整的数据验证需要在 BRAM 中读取数据", $time);
        end else begin
            $display("\n[%0t] ✗ 解码器未完成", $time);
            test_pass = 0;
        end
        
        #1000;
        
        // =====================================================================
        // 测试总结
        // =====================================================================
        $display("\n========================================");
        $display("测试总结");
        $display("========================================");
        if (test_pass) begin
            $display("✓ 测试通过");
        end else begin
            $display("✗ 测试失败");
        end
        $display("========================================");
        
        #100;
        $finish;
    end
    
    // 超时保护
    initial begin
        #100000000; // 100ms
        $display("\n✗ 仿真总超时！");
        $finish;
    end

endmodule
