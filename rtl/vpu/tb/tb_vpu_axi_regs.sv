`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////
// tb_vpu_axi_regs - 通过AXI-Lite接口读写VPU_AXI_Regs
////////////////////////////////////////////////////////////////////////////////

module tb_vpu_axi_regs;

    localparam CLK_PERIOD = 4;  // 250 MHz
    
    // 地址定义
    localparam GLOBAL_BRAM_BASE = 32'h10000000;
    localparam INST_BRAM_BASE   = 32'h10200000;
    localparam VPU_GB_BASE      = 32'h10400000;
    localparam VPU_REGS_BASE    = 32'h10440000;
    
    // VPU_AXI_Regs 寄存器偏移
    localparam REG_DECODER_CTRL   = 8'h38;
    localparam REG_INST_COUNT     = 8'h3C;
    localparam REG_DECODER_STATUS = 8'h40;
    
    // 时钟和复位
    reg aclk = 0;
    reg aresetn = 0;
    always #(CLK_PERIOD/2) aclk = ~aclk;
    
    // PCIe占位
    reg pcie_refclk_clk_p = 0;
    reg pcie_refclk_clk_n = 1;
    reg cpu_reset = 0;
    always #5 begin pcie_refclk_clk_p = ~pcie_refclk_clk_p; pcie_refclk_clk_n = ~pcie_refclk_clk_n; end
    
    wire [7:0] pci_express_x8_txn, pci_express_x8_txp;
    
    // DUT实例化
    vpu_wrapper dut (
        .pci_express_x8_rxn(8'b0),
        .pci_express_x8_rxp(8'b0),
        .pci_express_x8_txn(pci_express_x8_txn),
        .pci_express_x8_txp(pci_express_x8_txp),
        .pcie_refclk_clk_p(pcie_refclk_clk_p),
        .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .cpu_reset(cpu_reset)
    );
    
    // 强制所有相关模块的时钟和复位
    initial begin
        // XDMA内部时钟
        force dut.vpu_i.xdma_0.inst.axi_aclk = aclk;
        force dut.vpu_i.xdma_0.inst.axi_aresetn = aresetn;
        
        // VPU_AXI_Regs时钟
        force dut.vpu_i.vpu_regs.clk = aclk;
        force dut.vpu_i.vpu_regs.rst_n = aresetn;
        
        // INST_Decoder时钟
        force dut.vpu_i.inst_decoder.clk = aclk;
        force dut.vpu_i.inst_decoder.rst_n = aresetn;
        
        // CDMA_Controller时钟
        force dut.vpu_i.cdma_ctrl.clk = aclk;
        force dut.vpu_i.cdma_ctrl.rst_n = aresetn;
        
        // 注意：axi_cdma_0是VHDL IP，通过BD自动连接时钟
    end
    
    // 测试变量
    integer i, errors, timeout_cnt;
    reg [31:0] read_data;
    
    // =========================================================================
    // 主测试流程  
    // =========================================================================
    initial begin
        $display("\n================================================================");
        $display("  VPU AXI-Lite 接口测试");
        $display("  (直接驱动VPU_AXI_Regs的s_axi接口)");
        $display("================================================================\n");
        
        // 复位
        aresetn = 0;
        cpu_reset = 1;
        repeat(100) @(posedge aclk);
        aresetn = 1;
        cpu_reset = 0;
        repeat(100) @(posedge aclk);
        
        // ===== 步骤 1: 预装载测试数据 =====
        $display("[1] 预装载测试数据到 global_bram...");
        for (i = 0; i < 16; i = i + 1) begin
            write_global_bram(i, 32'hDEAD_0000 + i);
        end
        $display("    ✓ 数据已写入\n");
        
        // ===== 步骤 2: 写入指令到 inst_bram =====
        $display("[2] 写入 inst_bram 指令序列...");
        write_inst_bram(0,  32'h1000_000C);         // Header: CDMA_COPY
        write_inst_bram(1,  GLOBAL_BRAM_BASE);      // src
        write_inst_bram(2,  VPU_GB_BASE);           // dst
        write_inst_bram(3,  32'd64);                // length
        $display("    ✓ 指令已写入\n");
        
        // ===== 步骤 3: 通过AXI配置VPU_AXI_Regs =====
        $display("[3] 通过AXI-Lite配置 INST_Decoder...");
        
        // 写入 inst_count
        axi_write(REG_INST_COUNT, 32'd4);
        
        // 清零 DECODER_CTRL
        axi_write(REG_DECODER_CTRL, 32'h0);
        repeat(10) @(posedge aclk);
        
        // 产生上升沿 (0→1)
        axi_write(REG_DECODER_CTRL, 32'h1);
        
        $display("    ✓ 解码器已启动\n");
        
        // ===== 步骤 4: 轮询 DECODER_STATUS =====
        $display("[4] 通过AXI轮询等待解码器完成...");
        
        for (i = 0; i < 10000; i = i + 1) begin
            axi_read(REG_DECODER_STATUS, read_data);
            
            if (i % 100 == 0) begin
                $display("    [%0d] status=0x%08X busy=%b done=%b", 
                         i, read_data, read_data[0], read_data[1]);
            end
            
            if (read_data[1]) begin // done=1
                $display("    ✓ 解码器完成! (轮询 %0d 次)\n", i);
                i = 99999;
            end
            
            repeat(10) @(posedge aclk);
        end
        
        if (i != 100000) begin
            $display("    ✗ 超时!\n");
            $finish;
        end
        
        // ===== 步骤 5: 验证结果 =====
        $display("[5] 验证 VPU GB 数据...");
        errors = 0;
        for (i = 0; i < 16; i = i + 1) begin
            read_data = read_vpu_gb(i);
            if (read_data !== (32'hDEAD_0000 + i)) begin
                $display("    ERR [%0d] exp=0x%08X got=0x%08X", i, 32'hDEAD_0000+i, read_data);
                errors = errors + 1;
            end
        end
        
        // ===== 结果 =====
        $display("\n================================================================");
        if (errors == 0)
            $display("  ✓✓✓ 测试通过!");
        else
            $display("  ✗ 测试失败: %0d errors", errors);
        $display("================================================================\n");
        
        $finish;
    end
    
    // =========================================================================
    // AXI-Lite 写任务 - 直接驱动vpu_regs的s_axi接口
    // =========================================================================
    task axi_write(input [7:0] reg_offset, input [31:0] data);
        begin
            $display("    [AXI-W] offset=0x%02X data=0x%08X", reg_offset, data);
            
            // 同时发起写地址和写数据
            @(posedge aclk);
            force dut.vpu_i.vpu_regs.s_axi_awaddr = {24'h0, reg_offset};
            force dut.vpu_i.vpu_regs.s_axi_awvalid = 1'b1;
            force dut.vpu_i.vpu_regs.s_axi_awprot = 3'b000;
            force dut.vpu_i.vpu_regs.s_axi_wdata = data;
            force dut.vpu_i.vpu_regs.s_axi_wstrb = 4'hF;
            force dut.vpu_i.vpu_regs.s_axi_wvalid = 1'b1;
            force dut.vpu_i.vpu_regs.s_axi_bready = 1'b1;
            
            // 等待写地址握手（带超时）
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_awready && timeout_cnt < 100) begin
                @(posedge aclk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            // 等待写数据握手（带超时）
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_wready && timeout_cnt < 100) begin
                @(posedge aclk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            @(posedge aclk);
            
            // 释放写地址和写数据
            release dut.vpu_i.vpu_regs.s_axi_awaddr;
            release dut.vpu_i.vpu_regs.s_axi_awvalid;
            release dut.vpu_i.vpu_regs.s_axi_awprot;
            release dut.vpu_i.vpu_regs.s_axi_wdata;
            release dut.vpu_i.vpu_regs.s_axi_wstrb;
            release dut.vpu_i.vpu_regs.s_axi_wvalid;
            
            // 等待写响应（带超时）
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_bvalid && timeout_cnt < 100) begin
                @(posedge aclk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            @(posedge aclk);
            release dut.vpu_i.vpu_regs.s_axi_bready;
            
            repeat(2) @(posedge aclk);
        end
    endtask
    
    // =========================================================================
    // AXI-Lite 读任务 - 直接驱动vpu_regs的s_axi接口
    // =========================================================================
    task axi_read(input [7:0] reg_offset, output [31:0] data);
        begin
            // 发起读地址
            @(posedge aclk);
            force dut.vpu_i.vpu_regs.s_axi_araddr = {24'h0, reg_offset};
            force dut.vpu_i.vpu_regs.s_axi_arvalid = 1'b1;
            force dut.vpu_i.vpu_regs.s_axi_arprot = 3'b000;
            force dut.vpu_i.vpu_regs.s_axi_rready = 1'b1;
            
            // 等待读地址握手（带超时）
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_arready && timeout_cnt < 100) begin
                @(posedge aclk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            @(posedge aclk);
            
            // 释放读地址
            release dut.vpu_i.vpu_regs.s_axi_araddr;
            release dut.vpu_i.vpu_regs.s_axi_arvalid;
            release dut.vpu_i.vpu_regs.s_axi_arprot;
            
            // 等待读数据（带超时）
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_rvalid && timeout_cnt < 100) begin
                @(posedge aclk);
                timeout_cnt = timeout_cnt + 1;
            end
            
            data = dut.vpu_i.vpu_regs.s_axi_rdata;
            
            @(posedge aclk);
            release dut.vpu_i.vpu_regs.s_axi_rready;
            
            repeat(2) @(posedge aclk);
        end
    endtask
    
    // =========================================================================
    // BRAM直接访问（测试数据准备和验证）
    // =========================================================================
    task write_global_bram(input integer word_addr, input [31:0] data);
        integer mem_addr, byte_offset;
        begin
            mem_addr = word_addr / 8;
            byte_offset = (word_addr % 8) * 4;
            dut.vpu_i.global_bram.inst.native_mem_mapped_module.blk_mem_gen_v8_4_10_inst.memory[mem_addr][byte_offset*8 +: 32] = data;
        end
    endtask
    
    task write_inst_bram(input integer word_addr, input [31:0] data);
        begin
            dut.vpu_i.inst_bram.inst.mem[word_addr] = data;
        end
    endtask
    
    function [31:0] read_vpu_gb(input integer word_addr);
        integer mem_addr, byte_offset;
        begin
            mem_addr = word_addr / 8;
            byte_offset = (word_addr % 8) * 4;
            read_vpu_gb = dut.vpu_i.vpu_0.inst.u_global_vpu.gb_bram.BRAM[mem_addr][byte_offset*8 +: 32];
        end
    endfunction
    
    // 超时
    initial begin
        #500000; // 500us
        $display("[FATAL] 全局超时!");
        $finish;
    end

endmodule
