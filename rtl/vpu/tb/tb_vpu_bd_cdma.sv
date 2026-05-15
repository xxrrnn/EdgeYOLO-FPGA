`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// tb_vpu_bd_cdma - 基于真实 VPU Block Design 的 CDMA 仿真
//
// 策略：
//   - 实例化完整的 vpu_wrapper (含真实 CDMA IP、SmartConnect、BRAM Ctrl)
//   - 通过层次化路径直接：
//     1. 预装载 global_bram 测试数据
//     2. 预装载 inst_bram 指令
//     3. 直接驱动 decoder_start / inst_count
//     4. 等待 decoder_done
//     5. 读取 VPU GB 验证数据搬运
//   - 不需要 AXI VIP，不需要模拟 XDMA
////////////////////////////////////////////////////////////////////////////////

module tb_vpu_bd_cdma;

    localparam CLK_PERIOD = 4;  // 250 MHz
    localparam TIMEOUT_US = 200;

    // 地址 (用于 CDMA 指令中的地址，与 address.tcl 一致)
    localparam GLOBAL_BRAM_BASE = 32'h10000000;
    localparam VPU_GB_BASE      = 32'h10400000;
    
    localparam [3:0] OP_CDMA_COPY = 4'h1;

    // =========================================================================
    // 时钟 / 复位 / PCIe 占位
    // =========================================================================
    reg aclk = 0;
    reg aresetn = 0;
    always #(CLK_PERIOD/2) aclk = ~aclk;

    // PCIe 接口占位 (不连接，仅满足端口要求)
    wire [7:0] pci_express_x8_rxn, pci_express_x8_rxp;
    wire [7:0] pci_express_x8_txn, pci_express_x8_txp;
    reg pcie_refclk_clk_p = 0;
    reg pcie_refclk_clk_n = 1;
    reg cpu_reset = 0;
    always #5 begin pcie_refclk_clk_p = ~pcie_refclk_clk_p; pcie_refclk_clk_n = ~pcie_refclk_clk_n; end

    // =========================================================================
    // DUT: vpu_wrapper
    // =========================================================================
    vpu_wrapper dut (
        .pci_express_x8_rxn(8'b0),
        .pci_express_x8_rxp(8'b0),
        .pci_express_x8_txn(pci_express_x8_txn),
        .pci_express_x8_txp(pci_express_x8_txp),
        .pcie_refclk_clk_p(pcie_refclk_clk_p),
        .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .cpu_reset(cpu_reset)
    );

    // =========================================================================
    // 层次化路径定义
    // 根据 BD 中的实例名确定路径
    // =========================================================================
    // 内部时钟（由 XDMA 产生，仿真中可能不会启动，需要 force）
    // BD 中的时钟源是 xdma_0/axi_aclk，但 PCIe 无法仿真
    // 所以我们 force 内部时钟和复位

    initial begin
        // 强制内部时钟和复位（绕过 PCIe/XDMA）
        force dut.vpu_i.xdma_0.inst.axi_aclk = aclk;
        force dut.vpu_i.xdma_0.inst.axi_aresetn = aresetn;
    end

    // =========================================================================
    // 测试逻辑
    // =========================================================================
    integer i, errors;
    reg [31:0] read_data;
    
    initial begin
        $display("\n================================================================");
        $display("  VPU Block Design CDMA 仿真 (真实 IP)");
        $display("================================================================\n");
        
        // 复位
        aresetn = 0;
        cpu_reset = 1;
        repeat(100) @(posedge aclk);
        aresetn = 1;
        cpu_reset = 0;
        repeat(100) @(posedge aclk);

        // ===== 步骤 1: 通过层次化路径预装载 global_bram =====
        $display("[1] 预装载 global_bram 测试数据 (16 words)...");
        for (i = 0; i < 16; i = i + 1) begin
            // global_bram 是 blk_mem_gen，通过层次化路径写入
            // 路径: dut.vpu_i.global_bram.inst...
            // blk_mem_gen 的 memory array 通常在 inst.native_mem_module.blk_mem_gen_v8_4_X_inst.memory[addr]
            write_global_bram(i, 32'hDEAD_0000 + i);
        end
        $display("    写入完成");

        // ===== 步骤 2: 验证预装载 =====
        $display("[2] 验证预装载数据...");
        errors = 0;
        for (i = 0; i < 16; i = i + 1) begin
            read_data = read_global_bram(i);
            if (read_data !== (32'hDEAD_0000 + i)) begin
                $display("    ERR [%0d] exp=0x%08X got=0x%08X", i, 32'hDEAD_0000+i, read_data);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("    ✓ 数据预装载正确");
        else begin $display("    ✗ %0d errors", errors); $finish; end

        // ===== 步骤 3: 预装载 inst_bram (CDMA 搬运指令) =====
        $display("[3] 预装载 inst_bram (CDMA: global_bram -> VPU_GB, 64B)...");
        write_inst_bram(0, {OP_CDMA_COPY, 4'h0, 24'd12});  // header
        write_inst_bram(1, GLOBAL_BRAM_BASE);                 // src
        write_inst_bram(2, VPU_GB_BASE);                      // dst
        write_inst_bram(3, 32'd64);                           // 64 bytes = 16 words
        $display("    ✓ 指令已写入");

        // ===== 步骤 4: 直接驱动解码器 =====
        $display("[4] 启动解码器 (inst_count=4)...");
        // 设置 inst_count
        force dut.vpu_i.inst_decoder.inst.inst_count = 32'd4;
        repeat(5) @(posedge aclk);
        // 产生 decoder_start 脉冲
        force dut.vpu_i.inst_decoder.inst.decoder_start = 1'b0;
        repeat(5) @(posedge aclk);
        force dut.vpu_i.inst_decoder.inst.decoder_start = 1'b1;
        repeat(5) @(posedge aclk);
        force dut.vpu_i.inst_decoder.inst.decoder_start = 1'b0;
        // 释放 force（让 BD 内部信号自由运行）
        repeat(2) @(posedge aclk);
        release dut.vpu_i.inst_decoder.inst.decoder_start;
        release dut.vpu_i.inst_decoder.inst.inst_count;
        $display("    ✓ 解码器已启动");

        // ===== 步骤 5: 等待完成 =====
        $display("[5] 等待解码器完成...");
        for (i = 0; i < (TIMEOUT_US * 1000 / CLK_PERIOD); i = i + 1) begin
            @(posedge aclk);
            if (dut.vpu_i.inst_decoder.inst.decoder_done) begin
                $display("    ✓ 解码器完成! (耗时 %0d ns)", i * CLK_PERIOD);
                i = 99999999;
            end
        end
        if (i != 100000000) begin
            $display("    ✗ 超时! decoder_busy=%b status=0x%08X",
                     dut.vpu_i.inst_decoder.inst.decoder_busy,
                     dut.vpu_i.inst_decoder.inst.decoder_status);
            // 打印调试信息
            $display("    CDMA_Controller state = %0d", dut.vpu_i.cdma_ctrl.inst.cdma_controller_sv.c_state);
            $finish;
        end

        repeat(50) @(posedge aclk);

        // ===== 步骤 6: 验证 VPU GB =====
        $display("[6] 验证 VPU GB 数据...");
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
            $display("  ✓✓✓ CDMA 数据搬运验证通过! (global_bram -> VPU GB)");
        else
            $display("  ✗ 验证失败: %0d / 16 errors", errors);
        $display("================================================================\n");

        $finish;
    end

    // =========================================================================
    // BRAM 访问任务 (通过层次化路径)
    // 
    // 注意: 具体路径取决于 BD 中 blk_mem_gen 的实例化层次
    // 对于 AXI BRAM Controller 管理的 BRAM，memory array 在:
    //   <bram_inst>.inst.native_mem_mapped_module.blk_mem_gen_v8_4_X_inst.memory[addr]
    // 
    // 对于我们自定义的 INST_BRAM 和 VPU 内部 BRAM，路径不同
    // 这些路径在 elaborate 后通过波形确认
    // =========================================================================
    
    task write_global_bram(input integer word_addr, input [31:0] data);
        // global_bram 是 256-bit 宽，每个地址存 8 个 32-bit word
        // word_addr 0-7 在 memory[0]，8-15 在 memory[1]
        integer mem_addr;
        integer byte_offset;
        mem_addr = word_addr / 8;
        byte_offset = (word_addr % 8) * 4;
        // 直接写入 blk_mem_gen 的 memory array
        dut.vpu_i.global_bram.inst.native_mem_mapped_module.blk_mem_gen_v8_4_10_inst.memory[mem_addr][byte_offset*8 +: 32] = data;
    endtask

    function [31:0] read_global_bram(input integer word_addr);
        integer mem_addr;
        integer byte_offset;
        mem_addr = word_addr / 8;
        byte_offset = (word_addr % 8) * 4;
        read_global_bram = dut.vpu_i.global_bram.inst.native_mem_mapped_module.blk_mem_gen_v8_4_10_inst.memory[mem_addr][byte_offset*8 +: 32];
    endfunction

    task write_inst_bram(input integer word_addr, input [31:0] data);
        dut.vpu_i.inst_bram.inst.mem[word_addr] = data;
    endtask

    function [31:0] read_vpu_gb(input integer word_addr);
        // VPU GB: Global_VPU_top -> u_global_vpu -> gb_bram -> BRAM
        // BRAM 是 256-bit 宽
        integer mem_addr;
        integer byte_offset;
        mem_addr = word_addr / 8;
        byte_offset = (word_addr % 8) * 4;
        read_vpu_gb = dut.vpu_i.vpu_0.inst.u_global_vpu.gb_bram.BRAM[mem_addr][byte_offset*8 +: 32];
    endfunction

    // 超时
    initial begin
        #(TIMEOUT_US * 1000);
        $display("[FATAL] 全局超时 %0d us!", TIMEOUT_US);
        $display("  decoder_busy = %b", dut.vpu_i.inst_decoder.inst.decoder_busy);
        $display("  decoder_status = 0x%08X", dut.vpu_i.inst_decoder.inst.decoder_status);
        $display("  CDMA_Controller c_state = %0d", dut.vpu_i.cdma_ctrl.inst.cdma_controller_sv.c_state);
        $finish;
    end

endmodule
