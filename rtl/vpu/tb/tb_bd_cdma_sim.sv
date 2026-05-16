`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// tb_bd_cdma_sim - Block Design 级仿真
// 
// 使用 AXI VIP (通过 Xilinx VIP package) 驱动 BD
// 验证: global_bram -> VPU GB 的 CDMA 数据搬运
////////////////////////////////////////////////////////////////////////////////

import axi_vip_pkg::*;
import sim_bd_axi_vip_master_0_pkg::*;

module tb_bd_cdma_sim;

    localparam CLK_PERIOD = 4;  // 250 MHz
    
    // 地址映射
    localparam GLOBAL_BRAM_BASE = 32'h10000000;
    localparam INST_BRAM_BASE   = 32'h10200000;
    localparam VPU_GB_BASE      = 32'h10400000;
    localparam VPU_REGS_BASE    = 32'h10440000;
    
    localparam REG_DECODER_CTRL   = 8'h38;
    localparam REG_INST_COUNT     = 8'h3C;
    localparam REG_DECODER_STATUS = 8'h40;
    
    localparam [3:0] OP_CDMA_COPY = 4'h1;

    // 时钟/复位
    reg aclk = 0;
    reg aresetn = 0;
    always #(CLK_PERIOD/2) aclk = ~aclk;

    // DUT: BD wrapper
    sim_bd_wrapper dut (
        .aclk(aclk),
        .aresetn(aresetn)
    );

    // AXI VIP Agent
    sim_bd_axi_vip_master_0_mst_t mst_agent;

    initial begin
        mst_agent = new("mst_agent", dut.sim_bd_i.axi_vip_master.inst.IF);
        mst_agent.start_master();
        
        aresetn = 0;
        repeat(100) @(posedge aclk);
        aresetn = 1;
        repeat(100) @(posedge aclk);

        $display("\n================================================================");
        $display("  BD 仿真: 真实 Xilinx AXI CDMA + SmartConnect + BRAM Ctrl");
        $display("  CDMA_BASE_ADDR = 0 (地址段手动设为 0x0)");
        $display("================================================================\n");

        run_cdma_test();
        
        repeat(200) @(posedge aclk);
        $finish;
    end

    // AXI4-Lite 单次写
    task automatic axi_lite_write(input bit [31:0] addr, input bit [31:0] data);
        axi_transaction wr_tx;
        xil_axi_resp_t resp;
        wr_tx = mst_agent.wr_driver.create_transaction("wr");
        wr_tx.set_write_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 0, XIL_AXI_SIZE_4BYTE);
        wr_tx.set_data_beat(0, data);
        mst_agent.wr_driver.send(wr_tx);
        mst_agent.wr_driver.wait_rsp(wr_tx);
    endtask

    // AXI4-Lite 单次读
    task automatic axi_lite_read(input bit [31:0] addr, output bit [31:0] data);
        axi_transaction rd_tx;
        rd_tx = mst_agent.rd_driver.create_transaction("rd");
        rd_tx.set_read_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 0, XIL_AXI_SIZE_4BYTE);
        mst_agent.rd_driver.send(rd_tx);
        mst_agent.rd_driver.wait_rsp(rd_tx);
        data = rd_tx.get_data_beat(0);
    endtask

    task run_cdma_test();
        bit [31:0] rdata;
        integer i, errors;

        // ===== 步骤 1: 写测试数据到 global_bram =====
        $display("[1] 写入 16 个 word 到 global_bram (0x%08X)", GLOBAL_BRAM_BASE);
        for (i = 0; i < 16; i++) 
            axi_lite_write(GLOBAL_BRAM_BASE + i*4, 32'hCAFE_0000 + i);
        
        // ===== 步骤 2: 读回验证 =====
        $display("[2] 读回验证...");
        errors = 0;
        for (i = 0; i < 16; i++) begin
            axi_lite_read(GLOBAL_BRAM_BASE + i*4, rdata);
            if (rdata !== (32'hCAFE_0000 + i)) begin
                $display("    ERROR [%0d]: exp=0x%08X got=0x%08X", i, 32'hCAFE_0000+i, rdata);
                errors++;
            end
        end
        $display("    %s global_bram 验证 (%0d errors)", errors==0?"✓":"✗", errors);
        if (errors > 0) return;

        // ===== 步骤 3: 清空 VPU GB =====
        $display("[3] 清空 VPU GB...");
        for (i = 0; i < 16; i++)
            axi_lite_write(VPU_GB_BASE + i*4, 32'h0);

        // ===== 步骤 4: 写 CDMA 指令到 inst_bram =====
        $display("[4] 写入 CDMA 搬运指令 (0x%08X -> 0x%08X, 64B)", GLOBAL_BRAM_BASE, VPU_GB_BASE);
        axi_lite_write(INST_BRAM_BASE + 0,  {OP_CDMA_COPY, 4'h0, 24'd12});
        axi_lite_write(INST_BRAM_BASE + 4,  GLOBAL_BRAM_BASE);
        axi_lite_write(INST_BRAM_BASE + 8,  VPU_GB_BASE);
        axi_lite_write(INST_BRAM_BASE + 12, 32'd64);

        // ===== 步骤 5: 启动解码器 =====
        $display("[5] 启动解码器 (inst_count=4)...");
        axi_lite_write(VPU_REGS_BASE + REG_DECODER_CTRL, 32'h0);
        repeat(10) @(posedge aclk);
        axi_lite_write(VPU_REGS_BASE + REG_INST_COUNT, 32'd4);
        repeat(10) @(posedge aclk);
        axi_lite_write(VPU_REGS_BASE + REG_DECODER_CTRL, 32'h1);

        // ===== 步骤 6: 等待完成 =====
        $display("[6] 等待解码器完成...");
        for (i = 0; i < 2000; i++) begin
            repeat(50) @(posedge aclk);
            axi_lite_read(VPU_REGS_BASE + REG_DECODER_STATUS, rdata);
            if (!(rdata & 32'h1)) begin
                $display("    完成! status=0x%08X (约 %0d ns)", rdata, i*50*CLK_PERIOD);
                break;
            end
        end
        if (i == 2000) begin
            $display("    ✗ 超时! decoder stuck busy");
            return;
        end

        // ===== 步骤 7: 验证 VPU GB 数据 =====
        $display("[7] 验证 VPU GB 数据...");
        errors = 0;
        for (i = 0; i < 16; i++) begin
            axi_lite_read(VPU_GB_BASE + i*4, rdata);
            if (rdata !== (32'hCAFE_0000 + i)) begin
                $display("    ERROR [%0d]: exp=0x%08X got=0x%08X", i, 32'hCAFE_0000+i, rdata);
                errors++;
            end
        end

        $display("\n================================================================");
        if (errors == 0)
            $display("  ✓✓✓ CDMA 数据搬运完全正确! (global_bram -> VPU GB)");
        else
            $display("  ✗ 验证失败: %0d / 16 errors", errors);
        $display("================================================================\n");
    endtask

    // 超时
    initial begin
        #2000000;  // 2ms
        $display("[FATAL] 全局超时!");
        $finish;
    end

endmodule
