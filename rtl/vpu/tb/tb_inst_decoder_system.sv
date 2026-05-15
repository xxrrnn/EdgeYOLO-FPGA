`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// 完整系统级仿真 Testbench
// 测试: INST_Decoder + CDMA_Controller + Xilinx AXI CDMA IP + AXI BRAM
// 
// 使用 Vivado Block Design 中的真实 IP，不模拟任何接口
////////////////////////////////////////////////////////////////////////////////

module tb_inst_decoder_system;

    // =========================================================================
    // 参数定义
    // =========================================================================
    localparam CLK_PERIOD = 10; // 100MHz
    localparam INST_BRAM_BASE = 32'h1020_0000;
    localparam DATA_BRAM_BASE = 32'h1000_0000;
    
    // =========================================================================
    // 信号定义
    // =========================================================================
    reg clk;
    reg rst_n;
    
    // Block Design 顶层接口
    // (这些信号连接到 BD wrapper)
    
    // =========================================================================
    // 时钟生成
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // =========================================================================
    // Block Design Wrapper 实例化
    // 使用 Vivado 生成的 BD wrapper，包含所有真实 IP
    // =========================================================================
    
    // VPU_AXI_Regs 控制信号
    wire        decoder_start;
    wire [31:0] inst_count;
    wire        decoder_busy;
    wire        decoder_done;
    wire [31:0] decoder_status;
    
    // 为了测试，我们需要通过 AXI 接口访问 VPU_AXI_Regs
    // 这需要一个 AXI Master 来模拟主机访问
    
    // AXI-Lite Master 接口 (模拟主机)
    reg  [31:0] m_axil_awaddr;
    reg         m_axil_awvalid;
    wire        m_axil_awready;
    reg  [31:0] m_axil_wdata;
    reg  [3:0]  m_axil_wstrb;
    reg         m_axil_wvalid;
    wire        m_axil_wready;
    wire [1:0]  m_axil_bresp;
    wire        m_axil_bvalid;
    reg         m_axil_bready;
    reg  [31:0] m_axil_araddr;
    reg         m_axil_arvalid;
    wire        m_axil_arready;
    wire [31:0] m_axil_rdata;
    wire [1:0]  m_axil_rresp;
    wire        m_axil_rvalid;
    reg         m_axil_rready;
    
    // =========================================================================
    // 实例化完整的 Block Design
    // 注意：这需要 Vivado 项目中已经生成了 BD wrapper
    // =========================================================================
    
    // 由于我们需要测试完整的 BD，这里实例化 BD wrapper
    // BD wrapper 名称通常是 <bd_name>_wrapper
    
    /*
    vpu_wrapper u_vpu_bd (
        .clk(clk),
        .rst_n(rst_n),
        // ... 其他接口
    );
    */
    
    // =========================================================================
    // 由于 BD 结构复杂，我们采用另一种方式：
    // 直接实例化需要测试的模块，并使用 Xilinx IP 的仿真模型
    // =========================================================================
    
    // INST_BRAM 信号
    wire [17:0] inst_rd_addr;
    wire [31:0] inst_rd_data;
    
    // CDMA_Controller <-> INST_Decoder 接口
    wire        cdma_start;
    wire        cdma_config_valid;
    wire        cdma_config_ready;
    wire [31:0] cdma_src_addr_msb;
    wire [31:0] cdma_src_addr_lsb;
    wire [31:0] cdma_dst_addr_msb;
    wire [31:0] cdma_dst_addr_lsb;
    wire [31:0] cdma_length;
    
    // CDMA_Controller <-> AXI CDMA IP (AXI-Lite)
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
    
    // AXI CDMA IP <-> AXI Interconnect (AXI Full)
    wire [31:0] cdma_m_axi_awaddr;
    wire [7:0]  cdma_m_axi_awlen;
    wire [2:0]  cdma_m_axi_awsize;
    wire [1:0]  cdma_m_axi_awburst;
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
    wire        cdma_m_axi_arvalid;
    wire        cdma_m_axi_arready;
    wire [31:0] cdma_m_axi_rdata;
    wire [1:0]  cdma_m_axi_rresp;
    wire        cdma_m_axi_rlast;
    wire        cdma_m_axi_rvalid;
    wire        cdma_m_axi_rready;
    
    // =========================================================================
    // 实例化 INST_Decoder
    // =========================================================================
    reg         tb_decoder_start;
    reg  [31:0] tb_inst_count;
    
    INST_Decoder #(
        .INST_BRAM_DEPTH(262144),
        .INST_ADDR_WIDTH(18)
    ) u_inst_decoder (
        .clk(clk),
        .rst_n(rst_n),
        
        .decoder_start(tb_decoder_start),
        .inst_count(tb_inst_count),
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
        .CDMA_BASE_ADDR(32'h00000000)
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
    // 注意：需要在 Vivado 项目中生成此 IP 的仿真模型
    // =========================================================================
    axi_cdma_0 u_axi_cdma (
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
        .m_axi_awprot(),
        .m_axi_awcache(),
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
        .m_axi_arprot(),
        .m_axi_arcache(),
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
    // 实例化 AXI BRAM Controller + BRAM (用于数据存储)
    // =========================================================================
    axi_bram_ctrl_0 u_data_bram_ctrl (
        .s_axi_aclk(clk),
        .s_axi_aresetn(rst_n),
        
        .s_axi_awaddr(cdma_m_axi_awaddr[15:0]),
        .s_axi_awlen(cdma_m_axi_awlen),
        .s_axi_awsize(cdma_m_axi_awsize),
        .s_axi_awburst(cdma_m_axi_awburst),
        .s_axi_awlock(1'b0),
        .s_axi_awcache(4'b0),
        .s_axi_awprot(3'b0),
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
        .s_axi_araddr(cdma_m_axi_araddr[15:0]),
        .s_axi_arlen(cdma_m_axi_arlen),
        .s_axi_arsize(cdma_m_axi_arsize),
        .s_axi_arburst(cdma_m_axi_arburst),
        .s_axi_arlock(1'b0),
        .s_axi_arcache(4'b0),
        .s_axi_arprot(3'b0),
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
    
    // BRAM 信号
    wire        bram_en;
    wire [3:0]  bram_we;
    wire [15:0] bram_addr;
    wire [31:0] bram_wrdata;
    wire [31:0] bram_rddata;
    
    // 实例化 Block Memory Generator
    blk_mem_gen_0 u_data_bram (
        .clka(clk),
        .ena(bram_en),
        .wea(bram_we),
        .addra(bram_addr[15:2]),
        .dina(bram_wrdata),
        .douta(bram_rddata)
    );
    
    // =========================================================================
    // 实例化 INST_BRAM (指令存储)
    // =========================================================================
    wire        inst_bram_en;
    wire [3:0]  inst_bram_we;
    wire [17:0] inst_bram_addr;
    wire [31:0] inst_bram_wrdata;
    wire [31:0] inst_bram_rddata;
    
    // 简化的指令 BRAM (用于测试)
    reg [31:0] inst_mem [0:255];
    assign inst_rd_data = inst_mem[inst_rd_addr[7:0]];
    
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
                if (decoder_status == 0)
                    $display("[%0t] ✓ 解码器完成执行", $time);
                else
                    $display("[%0t] ✗ 解码器完成但有错误: status=0x%08X", $time, decoder_status);
            end else begin
                $display("[%0t] ✗ 解码器超时 (busy=%b, status=0x%08X)", 
                         $time, decoder_busy, decoder_status);
            end
        end
    endtask
    
    // =========================================================================
    // 主测试流程
    // =========================================================================
    
    initial begin
        $display("========================================");
        $display("完整系统级仿真");
        $display("INST_Decoder + CDMA_Controller + Xilinx CDMA IP");
        $display("========================================");
        
        // 初始化
        rst_n = 0;
        tb_decoder_start = 0;
        tb_inst_count = 0;
        
        // 初始化指令内存
        for (int i = 0; i < 256; i++) inst_mem[i] = 0;
        
        #100;
        rst_n = 1;
        #50;
        
        // =====================================================================
        // 测试 1: 单个 CDMA 搬运
        // =====================================================================
        $display("\n========================================");
        $display("测试 1: 单个 CDMA 搬运");
        $display("========================================");
        
        // 编码指令: CDMA_COPY src=0x0000, dst=0x1000, len=256
        inst_mem[0] = 32'h1000000C; // CDMA opcode, body=12 bytes
        inst_mem[1] = 32'h00000000; // src_lsb
        inst_mem[2] = 32'h00001000; // dst_lsb
        inst_mem[3] = 32'h00000100; // length = 256 bytes
        inst_mem[4] = 32'hF0000000; // END
        
        tb_inst_count = 5;
        
        @(posedge clk);
        tb_decoder_start = 1;
        @(posedge clk);
        tb_decoder_start = 0;
        
        wait_decoder_done(50000);
        
        #1000;
        
        $display("\n========================================");
        $display("仿真完成");
        $display("========================================");
        
        $finish;
    end
    
    // 超时保护
    initial begin
        #5000000; // 5ms
        $display("\n✗ 仿真总超时！");
        $finish;
    end

endmodule
