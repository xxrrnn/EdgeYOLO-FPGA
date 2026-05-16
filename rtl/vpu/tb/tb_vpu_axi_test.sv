`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////
// tb_vpu_axi_test - 通过AXI-Lite配置VPU_AXI_Regs测试INST_Decoder
//
// 完整测试路径：
//   1. 通过AXI-Lite写入 inst_bram (指令序列)
//   2. 通过AXI-Lite写入 VPU_AXI_Regs (配置INST_Decoder)
//   3. 等待 decoder_done
//   4. 验证结果
////////////////////////////////////////////////////////////////////////////////

module tb_vpu_axi_test;

    localparam CLK_PERIOD = 4;  // 250 MHz
    
    // AXI-Lite参数
    localparam AXI_ADDR_WIDTH = 32;
    localparam AXI_DATA_WIDTH = 32;
    
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
    
    // 强制内部时钟
    initial begin
        force dut.vpu_i.xdma_0.inst.axi_aclk = aclk;
        force dut.vpu_i.xdma_0.inst.axi_aresetn = aresetn;
        
        // 初始化AXI Master信号 (SmartConnect S00_AXI - 连接XDMA)
        force dut.vpu_i.axi_mem_smc.S00_AXI_awvalid = 1'b0;
        force dut.vpu_i.axi_mem_smc.S00_AXI_wvalid = 1'b0;
        force dut.vpu_i.axi_mem_smc.S00_AXI_bready = 1'b0;
        force dut.vpu_i.axi_mem_smc.S00_AXI_arvalid = 1'b0;
        force dut.vpu_i.axi_mem_smc.S00_AXI_rready = 1'b0;
    end
    
    // 测试变量
    integer i, errors;
    reg [31:0] read_data;
    
    // =========================================================================
    // 主测试流程
    // =========================================================================
    initial begin
        $display("\n================================================================");
        $display("  VPU AXI-Lite 配置测试");
        $display("================================================================\n");
        
        // 复位
        aresetn = 0;
        cpu_reset = 1;
        repeat(100) @(posedge aclk);
        aresetn = 1;
        cpu_reset = 0;
        repeat(100) @(posedge aclk);
        
        // ===== 步骤 1: 通过AXI预装载 global_bram =====
        $display("[1] 通过AXI预装载 global_bram 测试数据...");
        for (i = 0; i < 16; i = i + 1) begin
            axi_write(GLOBAL_BRAM_BASE + (i*4), 32'hDEAD_0000 + i);
        end
        $display("    ✓ 数据已写入");
        
        // ===== 步骤 2: 通过AXI写入 inst_bram =====
        $display("[2] 通过AXI写入 inst_bram 指令序列...");
        
        // CDMA_COPY指令: global_bram -> VPU_GB, 64B
        axi_write(INST_BRAM_BASE + 0,  32'h1000_000C);         // Header
        axi_write(INST_BRAM_BASE + 4,  GLOBAL_BRAM_BASE);      // src
        axi_write(INST_BRAM_BASE + 8,  VPU_GB_BASE);           // dst
        axi_write(INST_BRAM_BASE + 12, 32'd64);                // length
        
        $display("    ✓ 指令已写入");
        
        // ===== 步骤 3: 通过AXI配置 VPU_AXI_Regs =====
        $display("[3] 通过AXI配置 INST_Decoder...");
        
        // 清零 DECODER_CTRL
        axi_write(VPU_REGS_BASE + REG_DECODER_CTRL, 32'h0);
        repeat(10) @(posedge aclk);
        
        // 写入 inst_count
        axi_write(VPU_REGS_BASE + REG_INST_COUNT, 32'd4);
        repeat(10) @(posedge aclk);
        
        // 产生上升沿 (0→1)
        axi_write(VPU_REGS_BASE + REG_DECODER_CTRL, 32'h1);
        repeat(10) @(posedge aclk);
        
        $display("    ✓ 解码器已启动");
        
        // ===== 步骤 4: 轮询 DECODER_STATUS =====
        $display("[4] 轮询等待解码器完成...");
        
        for (i = 0; i < 10000; i = i + 1) begin
            axi_read(VPU_REGS_BASE + REG_DECODER_STATUS, read_data);
            
            if (i % 100 == 0) begin
                $display("    [%0d] status=0x%08X busy=%b done=%b", 
                         i, read_data, read_data[0], read_data[1]);
            end
            
            if (read_data[1]) begin // done=1
                $display("    ✓ 解码器完成! (轮询 %0d 次)", i);
                i = 99999;
            end
            
            repeat(10) @(posedge aclk);
        end
        
        if (i != 100000) begin
            $display("    ✗ 超时!");
            $finish;
        end
        
        // ===== 步骤 5: 通过AXI验证 VPU GB =====
        $display("[5] 通过AXI验证 VPU GB 数据...");
        errors = 0;
        for (i = 0; i < 16; i = i + 1) begin
            axi_read(VPU_GB_BASE + (i*4), read_data);
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
    // AXI-Lite Master驱动器 - 完整的AXI事务
    // =========================================================================
    
    // AXI-Lite写事务
    task axi_lite_write(input [31:0] addr, input [31:0] data);
        begin
            $display("    [AXI-W] addr=0x%08X data=0x%08X", addr, data);
            
            fork
                // 写地址通道
                begin
                    force dut.vpu_i.axi_mem_smc.S00_AXI_awaddr = addr;
                    force dut.vpu_i.axi_mem_smc.S00_AXI_awvalid = 1'b1;
                    force dut.vpu_i.axi_mem_smc.S00_AXI_awprot = 3'b000;
                    @(posedge aclk);
                    wait(dut.vpu_i.axi_mem_smc.S00_AXI_awready);
                    @(posedge aclk);
                    release dut.vpu_i.axi_mem_smc.S00_AXI_awaddr;
                    release dut.vpu_i.axi_mem_smc.S00_AXI_awvalid;
                    release dut.vpu_i.axi_mem_smc.S00_AXI_awprot;
                end
                
                // 写数据通道
                begin
                    force dut.vpu_i.axi_mem_smc.S00_AXI_wdata = data;
                    force dut.vpu_i.axi_mem_smc.S00_AXI_wvalid = 1'b1;
                    force dut.vpu_i.axi_mem_smc.S00_AXI_wstrb = 4'hF;
                    @(posedge aclk);
                    wait(dut.vpu_i.axi_mem_smc.S00_AXI_wready);
                    @(posedge aclk);
                    release dut.vpu_i.axi_mem_smc.S00_AXI_wdata;
                    release dut.vpu_i.axi_mem_smc.S00_AXI_wvalid;
                    release dut.vpu_i.axi_mem_smc.S00_AXI_wstrb;
                end
            join
            
            // 写响应通道
            force dut.vpu_i.axi_mem_smc.S00_AXI_bready = 1'b1;
            @(posedge aclk);
            wait(dut.vpu_i.axi_mem_smc.S00_AXI_bvalid);
            @(posedge aclk);
            release dut.vpu_i.axi_mem_smc.S00_AXI_bready;
            
            repeat(2) @(posedge aclk);
        end
    endtask
    
    // AXI-Lite读事务
    task axi_lite_read(input [31:0] addr, output [31:0] data);
        begin
            // 读地址通道
            force dut.vpu_i.axi_mem_smc.S00_AXI_araddr = addr;
            force dut.vpu_i.axi_mem_smc.S00_AXI_arvalid = 1'b1;
            force dut.vpu_i.axi_mem_smc.S00_AXI_arprot = 3'b000;
            @(posedge aclk);
            wait(dut.vpu_i.axi_mem_smc.S00_AXI_arready);
            @(posedge aclk);
            release dut.vpu_i.axi_mem_smc.S00_AXI_araddr;
            release dut.vpu_i.axi_mem_smc.S00_AXI_arvalid;
            release dut.vpu_i.axi_mem_smc.S00_AXI_arprot;
            
            // 读数据通道
            force dut.vpu_i.axi_mem_smc.S00_AXI_rready = 1'b1;
            @(posedge aclk);
            wait(dut.vpu_i.axi_mem_smc.S00_AXI_rvalid);
            data = dut.vpu_i.axi_mem_smc.S00_AXI_rdata;
            @(posedge aclk);
            release dut.vpu_i.axi_mem_smc.S00_AXI_rready;
            
            $display("    [AXI-R] addr=0x%08X data=0x%08X", addr, data);
            repeat(2) @(posedge aclk);
        end
    endtask
    
    // 便捷封装
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            if (addr >= INST_BRAM_BASE && addr < INST_BRAM_BASE + 32'h100000) begin
                // inst_bram通过AXI写入
                axi_lite_write(addr, data);
            end else if (addr >= VPU_REGS_BASE && addr < VPU_REGS_BASE + 32'h1000) begin
                // VPU_AXI_Regs通过AXI写入
                axi_lite_write(addr, data);
            end else if (addr >= GLOBAL_BRAM_BASE && addr < GLOBAL_BRAM_BASE + 32'h100000) begin
                // global_bram通过AXI写入
                axi_lite_write(addr, data);
            end
        end
    endtask
    
    task axi_read(input [31:0] addr, output [31:0] data);
        begin
            axi_lite_read(addr, data);
        end
    endtask
    
    // BRAM访问任务
    task write_global_bram(input integer word_addr, input [31:0] data);
        integer mem_addr, byte_offset;
        begin
            mem_addr = word_addr / 8;
            byte_offset = (word_addr % 8) * 4;
            dut.vpu_i.global_bram.inst.native_mem_mapped_module.blk_mem_gen_v8_4_10_inst.memory[mem_addr][byte_offset*8 +: 32] = data;
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
        $display("[FATAL] 超时!");
        $finish;
    end

endmodule
