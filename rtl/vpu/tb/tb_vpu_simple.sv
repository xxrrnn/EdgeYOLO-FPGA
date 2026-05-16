`timescale 1ns/1ps
////////////////////////////////////////////////////////////////////////////////
// tb_vpu_simple - 简单测试：只测试END指令
////////////////////////////////////////////////////////////////////////////////

module tb_vpu_simple;

    localparam CLK_PERIOD = 4;  // 250 MHz
    localparam VPU_REGS_BASE = 32'h10440000;
    localparam REG_DECODER_CTRL   = 8'h38;
    localparam REG_INST_COUNT     = 8'h3C;
    localparam REG_DECODER_STATUS = 8'h40;
    
    // 时钟和复位
    reg aclk = 0;
    reg aresetn = 0;
    always #(CLK_PERIOD/2) aclk = ~aclk;
    
    // PCIe占位
    reg pcie_refclk_clk_p = 0, pcie_refclk_clk_n = 1, cpu_reset = 0;
    always #5 begin pcie_refclk_clk_p = ~pcie_refclk_clk_p; pcie_refclk_clk_n = ~pcie_refclk_clk_n; end
    wire [7:0] pci_express_x8_txn, pci_express_x8_txp;
    
    // DUT
    vpu_wrapper dut (
        .pci_express_x8_rxn(8'b0), .pci_express_x8_rxp(8'b0),
        .pci_express_x8_txn(pci_express_x8_txp), .pci_express_x8_txp(pci_express_x8_txp),
        .pcie_refclk_clk_p(pcie_refclk_clk_p), .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .cpu_reset(cpu_reset)
    );
    
    // 强制时钟
    initial begin
        force dut.vpu_i.xdma_0.inst.axi_aclk = aclk;
        force dut.vpu_i.xdma_0.inst.axi_aresetn = aresetn;
        force dut.vpu_i.vpu_regs.clk = aclk;
        force dut.vpu_i.vpu_regs.rst_n = aresetn;
        force dut.vpu_i.inst_decoder.clk = aclk;
        force dut.vpu_i.inst_decoder.rst_n = aresetn;
    end
    
    integer i, timeout_cnt;
    reg [31:0] read_data;
    
    initial begin
        $display("\n========== 简单测试：END指令 ==========\n");
        
        // 复位
        aresetn = 0; cpu_reset = 1;
        repeat(100) @(posedge aclk);
        aresetn = 1; cpu_reset = 0;
        repeat(100) @(posedge aclk);
        
        // 写入END指令到inst_bram
        $display("[1] 写入END指令...");
        dut.vpu_i.inst_bram.inst.mem[0] = 32'hF0000000;  // OP_END
        $display("    ✓ 指令已写入\n");
        
        // 配置INST_Decoder
        $display("[2] 配置INST_Decoder...");
        axi_write(REG_INST_COUNT, 32'd1);      // 1个word
        axi_write(REG_DECODER_CTRL, 32'h0);   // 清零
        repeat(10) @(posedge aclk);
        axi_write(REG_DECODER_CTRL, 32'h1);   // 启动
        $display("    ✓ 解码器已启动\n");
        
        // 轮询
        $display("[3] 轮询等待完成...");
        for (i = 0; i < 1000; i = i + 1) begin
            axi_read(REG_DECODER_STATUS, read_data);
            if (i % 10 == 0) begin
                $display("    [%0d] status=0x%08X busy=%b done=%b", 
                         i, read_data, read_data[0], read_data[1]);
            end
            if (read_data[1]) begin
                $display("    ✓✓✓ 测试通过! (轮询 %0d 次)\n", i);
                $finish;
            end
            repeat(10) @(posedge aclk);
        end
        
        $display("    ✗ 超时失败!\n");
        $finish;
    end
    
    // AXI写
    task axi_write(input [7:0] reg_offset, input [31:0] data);
        begin
            @(posedge aclk);
            force dut.vpu_i.vpu_regs.s_axi_awaddr = {24'h0, reg_offset};
            force dut.vpu_i.vpu_regs.s_axi_awvalid = 1'b1;
            force dut.vpu_i.vpu_regs.s_axi_awprot = 3'b000;
            force dut.vpu_i.vpu_regs.s_axi_wdata = data;
            force dut.vpu_i.vpu_regs.s_axi_wstrb = 4'hF;
            force dut.vpu_i.vpu_regs.s_axi_wvalid = 1'b1;
            force dut.vpu_i.vpu_regs.s_axi_bready = 1'b1;
            
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_awready && timeout_cnt < 100) begin
                @(posedge aclk); timeout_cnt = timeout_cnt + 1;
            end
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_wready && timeout_cnt < 100) begin
                @(posedge aclk); timeout_cnt = timeout_cnt + 1;
            end
            @(posedge aclk);
            release dut.vpu_i.vpu_regs.s_axi_awaddr;
            release dut.vpu_i.vpu_regs.s_axi_awvalid;
            release dut.vpu_i.vpu_regs.s_axi_awprot;
            release dut.vpu_i.vpu_regs.s_axi_wdata;
            release dut.vpu_i.vpu_regs.s_axi_wstrb;
            release dut.vpu_i.vpu_regs.s_axi_wvalid;
            
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_bvalid && timeout_cnt < 100) begin
                @(posedge aclk); timeout_cnt = timeout_cnt + 1;
            end
            @(posedge aclk);
            release dut.vpu_i.vpu_regs.s_axi_bready;
            repeat(2) @(posedge aclk);
        end
    endtask
    
    // AXI读
    task axi_read(input [7:0] reg_offset, output [31:0] data);
        begin
            @(posedge aclk);
            force dut.vpu_i.vpu_regs.s_axi_araddr = {24'h0, reg_offset};
            force dut.vpu_i.vpu_regs.s_axi_arvalid = 1'b1;
            force dut.vpu_i.vpu_regs.s_axi_arprot = 3'b000;
            force dut.vpu_i.vpu_regs.s_axi_rready = 1'b1;
            
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_arready && timeout_cnt < 100) begin
                @(posedge aclk); timeout_cnt = timeout_cnt + 1;
            end
            @(posedge aclk);
            release dut.vpu_i.vpu_regs.s_axi_araddr;
            release dut.vpu_i.vpu_regs.s_axi_arvalid;
            release dut.vpu_i.vpu_regs.s_axi_arprot;
            
            timeout_cnt = 0;
            while (!dut.vpu_i.vpu_regs.s_axi_rvalid && timeout_cnt < 100) begin
                @(posedge aclk); timeout_cnt = timeout_cnt + 1;
            end
            data = dut.vpu_i.vpu_regs.s_axi_rdata;
            @(posedge aclk);
            release dut.vpu_i.vpu_regs.s_axi_rready;
            repeat(2) @(posedge aclk);
        end
    endtask
    
    initial begin
        #100000; // 100us
        $display("[FATAL] 全局超时!");
        $finish;
    end

endmodule
