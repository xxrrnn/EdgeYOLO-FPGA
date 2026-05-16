`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////
// tb_vpu_axi_vip - 使用AXI VIP驱动完整AXI路径测试
////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import vpu_axi_vip_master_0_pkg::*;

module tb_vpu_axi_vip;

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
    
    // 强制内部时钟
    initial begin
        force dut.vpu_i.xdma_0.inst.axi_aclk = aclk;
        force dut.vpu_i.xdma_0.inst.axi_aresetn = aresetn;
    end
    
    // AXI VIP Master Agent
    vpu_axi_vip_master_0_mst_t master_agent;
    
    // 测试变量
    integer i, errors;
    xil_axi_resp_t resp;
    bit [31:0] read_data;
    
    // =========================================================================
    // 主测试流程
    // =========================================================================
    initial begin
        $display("\n================================================================");
        $display("  VPU AXI VIP 测试");
        $display("================================================================\n");
        
        // 复位
        aresetn = 0;
        cpu_reset = 1;
        repeat(100) @(posedge aclk);
        aresetn = 1;
        cpu_reset = 0;
        repeat(100) @(posedge aclk);
        
        // 创建并启动AXI VIP Master Agent
        $display("[0] 初始化 AXI VIP Master...");
        master_agent = new("master vip agent", dut.vpu_i.axi_vip_master.inst.IF);
        master_agent.start_master();
        $display("    ✓ AXI VIP Master已启动\n");
        
        // ===== 步骤 1: 通过AXI预装载 global_bram =====
        $display("[1] 通过AXI预装载 global_bram 测试数据...");
        for (i = 0; i < 16; i = i + 1) begin
            axi_write(GLOBAL_BRAM_BASE + (i*4), 32'hDEAD_0000 + i, resp);
            if (resp != XIL_AXI_RESP_OKAY) begin
                $display("    ERR: Write failed with resp=%0d", resp);
                $finish;
            end
        end
        $display("    ✓ 数据已写入\n");
        
        // ===== 步骤 2: 通过AXI写入 inst_bram =====
        $display("[2] 通过AXI写入 inst_bram 指令序列...");
        
        // CDMA_COPY指令: global_bram -> VPU_GB, 64B
        axi_write(INST_BRAM_BASE + 0,  32'h1000_000C, resp);         // Header
        axi_write(INST_BRAM_BASE + 4,  GLOBAL_BRAM_BASE, resp);      // src
        axi_write(INST_BRAM_BASE + 8,  VPU_GB_BASE, resp);           // dst
        axi_write(INST_BRAM_BASE + 12, 32'd64, resp);                // length
        
        $display("    ✓ 指令已写入\n");
        
        // ===== 步骤 3: 通过AXI配置 VPU_AXI_Regs =====
        $display("[3] 通过AXI配置 INST_Decoder...");
        
        // 清零 DECODER_CTRL
        axi_write(VPU_REGS_BASE + REG_DECODER_CTRL, 32'h0, resp);
        repeat(10) @(posedge aclk);
        
        // 写入 inst_count
        axi_write(VPU_REGS_BASE + REG_INST_COUNT, 32'd4, resp);
        repeat(10) @(posedge aclk);
        
        // 产生上升沿 (0→1)
        axi_write(VPU_REGS_BASE + REG_DECODER_CTRL, 32'h1, resp);
        repeat(10) @(posedge aclk);
        
        $display("    ✓ 解码器已启动\n");
        
        // ===== 步骤 4: 轮询 DECODER_STATUS =====
        $display("[4] 轮询等待解码器完成...");
        
        for (i = 0; i < 10000; i = i + 1) begin
            axi_read(VPU_REGS_BASE + REG_DECODER_STATUS, read_data, resp);
            
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
        
        // ===== 步骤 5: 通过AXI验证 VPU GB =====
        $display("[5] 通过AXI验证 VPU GB 数据...");
        errors = 0;
        for (i = 0; i < 16; i = i + 1) begin
            axi_read(VPU_GB_BASE + (i*4), read_data, resp);
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
    // AXI VIP 事务任务
    // =========================================================================
    
    task axi_write(input [31:0] addr, input [31:0] data, output xil_axi_resp_t resp);
        axi_transaction wr_trans;
        begin
            wr_trans = master_agent.wr_driver.create_transaction("write");
            wr_trans.set_write_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2(32/8)));
            wr_trans.set_data_block(data);
            master_agent.wr_driver.send(wr_trans);
            master_agent.wr_driver.wait_rsp(wr_trans);
            wr_trans.get_bresp(resp);
            $display("    [AXI-W] addr=0x%08X data=0x%08X resp=%0d", addr, data, resp);
        end
    endtask
    
    task axi_read(input [31:0] addr, output [31:0] data, output xil_axi_resp_t resp);
        axi_transaction rd_trans;
        bit [31:0] rdata[];
        begin
            rd_trans = master_agent.rd_driver.create_transaction("read");
            rd_trans.set_read_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 0, xil_axi_size_t'(xil_clog2(32/8)));
            master_agent.rd_driver.send(rd_trans);
            master_agent.rd_driver.wait_rsp(rd_trans);
            rd_trans.get_rresp(resp);
            rd_trans.get_data(rdata);
            data = rdata[0];
            $display("    [AXI-R] addr=0x%08X data=0x%08X resp=%0d", addr, data, resp);
        end
    endtask
    
    // 超时
    initial begin
        #500000; // 500us
        $display("[FATAL] 超时!");
        $finish;
    end

endmodule
