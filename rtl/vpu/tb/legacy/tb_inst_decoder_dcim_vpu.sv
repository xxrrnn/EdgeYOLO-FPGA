`timescale 1ns / 1ps
`include "chip_defines.vh"

//////////////////////////////////////////////////////////////////////////////////
// tb_inst_decoder_dcim_vpu - 验证 INST_Decoder 配置 DCIM 和 VPU
//
// 测试场景：
//   1. OP_DCIM_CFG:  写入 DCIM 寄存器 (MODE, ACT_BASE, WEI_BASE, OUT_BASE 等)
//   2. OP_DCIM_EXEC: 触发 DCIM 计算（写 CTRL 寄存器 bit[0]=1）
//   3. OP_WAIT_DCIM: 等待 dcim_ready
//   4. OP_VPU_EXEC:  配置并启动 VPU
//   5. OP_WAIT_VPU:  等待 vpu_ready
//   6. OP_END:       结束
//////////////////////////////////////////////////////////////////////////////////

module tb_inst_decoder_dcim_vpu;

    // ===========================================================================
    // 操作码
    // ===========================================================================
    localparam [3:0] OP_NOP       = 4'h0;
    localparam [3:0] OP_CDMA_COPY = 4'h1;
    localparam [3:0] OP_VPU_EXEC  = 4'h2;
    localparam [3:0] OP_WAIT_CDMA = 4'h3;
    localparam [3:0] OP_WAIT_VPU  = 4'h4;
    localparam [3:0] OP_SYNC      = 4'h5;
    localparam [3:0] OP_DCIM_EXEC = 4'h6;
    localparam [3:0] OP_WAIT_DCIM = 4'h7;
    localparam [3:0] OP_DCIM_CFG  = 4'h8;
    localparam [3:0] OP_END       = 4'hF;

    // DCIM 寄存器地址（与 DCIM_Array_AXI.sv 一致）
    localparam [11:0] DCIM_ADDR_CTRL     = 12'h000;
    localparam [11:0] DCIM_ADDR_STATUS   = 12'h004;
    localparam [11:0] DCIM_ADDR_MODE     = 12'h008;
    localparam [11:0] DCIM_ADDR_ACT_BASE = 12'h010;  // Group 0
    localparam [11:0] DCIM_ADDR_WEI_BASE = 12'h040;  // Tile 0
    localparam [11:0] DCIM_ADDR_OUT_BASE = 12'h140;  // Tile 0

    // VPU Unit codes
    localparam [31:0] VPU_UNIT_AD = 32'd6;

    // ===========================================================================
    // 参数
    // ===========================================================================
    localparam CLK_PERIOD      = 4.0;
    localparam INST_BRAM_DEPTH = 1024;
    localparam INST_ADDR_WIDTH = 10;

    // ===========================================================================
    // 信号声明
    // ===========================================================================
    reg  clk, rst_n;

    // VPU_AXI_Regs → INST_Decoder 控制接口（简化为直接驱动）
    reg  decoder_start;
    reg  [31:0] inst_count;
    wire decoder_busy, decoder_done;
    wire [31:0] decoder_status;

    // INST_BRAM 读接口
    wire [INST_ADDR_WIDTH-1:0] inst_rd_addr;
    reg  [31:0] inst_rd_data;

    // CDMA 接口（接受即就绪）
    wire        cdma_start;
    wire        cdma_config_valid;
    wire [31:0] cdma_src_addr_msb, cdma_src_addr_lsb;
    wire [31:0] cdma_dst_addr_msb, cdma_dst_addr_lsb;
    wire [31:0] cdma_length;

    // VPU 接口（2拍后 ready）
    wire        vpu_start;
    reg         vpu_ready;
    wire [31:0] vpu_unit_choose, vpu_src_addr, vpu_src2_addr;
    wire [31:0] vpu_src_c, vpu_src_h, vpu_src_w;
    wire [31:0] vpu_bias_addr, vpu_scale_addr, vpu_dst_addr;
    wire [31:0] vpu_addr_break, vpu_addr_s, vpu_addr_t;

    // DCIM 寄存器写接口
    wire        dcim_cfg_wr_en;
    wire [11:0] dcim_cfg_wr_addr;
    wire [31:0] dcim_cfg_wr_data;
    reg         dcim_ready;

    // ===========================================================================
    // INST_BRAM 模型（1拍延迟）
    // ===========================================================================
    reg [31:0] inst_bram_mem [0:INST_BRAM_DEPTH-1];
    always @(posedge clk)
        inst_rd_data <= inst_bram_mem[inst_rd_addr];

    // ===========================================================================
    // DCIM 寄存器模型（记录写入的值用于验证）
    // ===========================================================================
    reg [31:0] dcim_reg_ctrl;
    reg [31:0] dcim_reg_mode;
    reg [31:0] dcim_reg_act_base [0:7];
    reg [31:0] dcim_reg_wei_base [0:63];
    reg [31:0] dcim_reg_out_base [0:63];

    integer dcim_write_count;

    always @(posedge clk) begin
        if (!rst_n) begin
            dcim_reg_ctrl <= 0;
            dcim_reg_mode <= 0;
            dcim_write_count <= 0;
        end else if (dcim_cfg_wr_en) begin
            dcim_write_count <= dcim_write_count + 1;
            if (dcim_cfg_wr_addr == DCIM_ADDR_CTRL) begin
                dcim_reg_ctrl <= dcim_cfg_wr_data;
                if (dcim_cfg_wr_data[0])
                    $display("[%0t ns] DCIM CTRL: start pulse asserted!", $time);
            end else if (dcim_cfg_wr_addr == DCIM_ADDR_MODE) begin
                dcim_reg_mode <= dcim_cfg_wr_data;
                $display("[%0t ns] DCIM MODE = 0x%08X", $time, dcim_cfg_wr_data);
            end else if (dcim_cfg_wr_addr >= DCIM_ADDR_ACT_BASE &&
                         dcim_cfg_wr_addr < DCIM_ADDR_WEI_BASE) begin
                $display("[%0t ns] DCIM ACT_BASE[%0d] = 0x%08X", $time,
                    (dcim_cfg_wr_addr - DCIM_ADDR_ACT_BASE) >> 2, dcim_cfg_wr_data);
            end else if (dcim_cfg_wr_addr >= DCIM_ADDR_WEI_BASE &&
                         dcim_cfg_wr_addr < DCIM_ADDR_OUT_BASE) begin
                $display("[%0t ns] DCIM WEI_BASE[%0d] = 0x%08X", $time,
                    (dcim_cfg_wr_addr - DCIM_ADDR_WEI_BASE) >> 2, dcim_cfg_wr_data);
            end else if (dcim_cfg_wr_addr >= DCIM_ADDR_OUT_BASE) begin
                $display("[%0t ns] DCIM OUT_BASE[%0d] = 0x%08X", $time,
                    (dcim_cfg_wr_addr - DCIM_ADDR_OUT_BASE) >> 2, dcim_cfg_wr_data);
            end
        end
    end

    // VPU 模型：收到 vpu_start 后 4 拍返回 ready
    reg [2:0] vpu_delay_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vpu_ready <= 1'b1;
            vpu_delay_cnt <= 0;
        end else if (vpu_start && vpu_ready) begin
            vpu_ready <= 1'b0;
            vpu_delay_cnt <= 0;
            $display("[%0t ns] VPU started: unit_choose=%0d src=0x%08X dst=0x%08X",
                $time, vpu_unit_choose, vpu_src_addr, vpu_dst_addr);
        end else if (!vpu_ready) begin
            vpu_delay_cnt <= vpu_delay_cnt + 1;
            if (vpu_delay_cnt == 3) begin
                vpu_ready <= 1'b1;
                $display("[%0t ns] VPU done", $time);
            end
        end
    end

    // DCIM 模型：收到 CTRL start 后 6 拍返回 ready
    reg [2:0] dcim_delay_cnt;
    reg dcim_started;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcim_ready <= 1'b1;
            dcim_delay_cnt <= 0;
            dcim_started <= 0;
        end else if (dcim_cfg_wr_en && dcim_cfg_wr_addr == DCIM_ADDR_CTRL && dcim_cfg_wr_data[0]) begin
            dcim_ready <= 1'b0;
            dcim_delay_cnt <= 0;
            dcim_started <= 1;
        end else if (!dcim_ready && dcim_started) begin
            dcim_delay_cnt <= dcim_delay_cnt + 1;
            if (dcim_delay_cnt == 5) begin
                dcim_ready <= 1'b1;
                dcim_started <= 0;
                $display("[%0t ns] DCIM done", $time);
            end
        end
    end

    // ===========================================================================
    // INST_Decoder DUT
    // ===========================================================================
    INST_Decoder #(
        .INST_BRAM_DEPTH(INST_BRAM_DEPTH),
        .INST_ADDR_WIDTH(INST_ADDR_WIDTH)
    ) u_decoder (
        .clk              (clk),
        .rst_n            (rst_n),
        .decoder_start    (decoder_start),
        .inst_count       (inst_count),
        .decoder_busy     (decoder_busy),
        .decoder_done     (decoder_done),
        .decoder_status   (decoder_status),
        .inst_rd_addr     (inst_rd_addr),
        .inst_rd_data     (inst_rd_data),
        .cdma_start       (cdma_start),
        .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(1'b1),
        .cdma_src_addr_msb(cdma_src_addr_msb),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(cdma_dst_addr_msb),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length      (cdma_length),
        .vpu_start        (vpu_start),
        .vpu_ready        (vpu_ready),
        .vpu_unit_choose  (vpu_unit_choose),
        .vpu_src_addr     (vpu_src_addr),
        .vpu_src2_addr    (vpu_src2_addr),
        .vpu_src_c        (vpu_src_c),
        .vpu_src_h        (vpu_src_h),
        .vpu_src_w        (vpu_src_w),
        .vpu_bias_addr    (vpu_bias_addr),
        .vpu_scale_addr   (vpu_scale_addr),
        .vpu_dst_addr     (vpu_dst_addr),
        .vpu_addr_break   (vpu_addr_break),
        .vpu_addr_s       (vpu_addr_s),
        .vpu_addr_t       (vpu_addr_t),
        .dcim_cfg_wr_en   (dcim_cfg_wr_en),
        .dcim_cfg_wr_addr (dcim_cfg_wr_addr),
        .dcim_cfg_wr_data (dcim_cfg_wr_data),
        .dcim_ready       (dcim_ready)
    );

    // ===========================================================================
    // 时钟
    // ===========================================================================
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ===========================================================================
    // 指令序列写入任务
    // ===========================================================================
    integer word_idx;

    task write_word;
        input [9:0]  addr;
        input [31:0] data;
        begin
            inst_bram_mem[addr] = data;
        end
    endtask

    // 写一条指令 Header
    task write_header;
        input [3:0]  opcode;
        input [3:0]  flags;
        input [23:0] length;
        begin
            write_word(word_idx, {opcode, flags, length});
            word_idx = word_idx + 1;
        end
    endtask

    // 写一个 32-bit body word
    task write_body;
        input [31:0] data;
        begin
            write_word(word_idx, data);
            word_idx = word_idx + 1;
        end
    endtask

    // ===========================================================================
    // 测试主体
    // ===========================================================================
    integer i;
    integer pass_count, fail_count;

    initial begin
        $display("=================================================");
        $display("  INST_Decoder DCIM+VPU Configuration Test");
        $display("=================================================");

        // 初始化
        rst_n         = 0;
        decoder_start = 0;
        inst_count    = 0;
        pass_count    = 0;
        fail_count    = 0;
        word_idx      = 0;

        // 清零 bram
        for (i = 0; i < INST_BRAM_DEPTH; i = i + 1)
            inst_bram_mem[i] = 32'h0;

        // -----------------------------------------------------------------------
        // 构建指令序列
        // -----------------------------------------------------------------------

        // === 指令 1: OP_DCIM_CFG — 配置 DCIM 基础参数 ===
        // 写入 5 个寄存器: MODE, ACT_BASE[0], WEI_BASE[0], OUT_BASE[0], OUT_BASE[1]
        write_header(OP_DCIM_CFG, 4'h0, 24'd5);   // 5 个 (addr, data) 对 = 10 words body
        write_body(32'h00000008); write_body(32'h00000004); // MODE = 4 (INT8)
        write_body(32'h00000010); write_body(32'h00000100); // ACT_BASE[0] = 0x100
        write_body(32'h00000040); write_body(32'h00000200); // WEI_BASE[0] = 0x200
        write_body(32'h00000140); write_body(32'h00000300); // OUT_BASE[0] = 0x300
        write_body(32'h00000144); write_body(32'h00000400); // OUT_BASE[1] = 0x400

        // === 指令 2: OP_DCIM_EXEC — 启动 DCIM ===
        write_header(OP_DCIM_EXEC, 4'h0, 24'd0);  // 无 body，写 CTRL[0]=1 触发

        // === 指令 3: OP_WAIT_DCIM — 等待 DCIM 完成 ===
        write_header(OP_WAIT_DCIM, 4'h0, 24'd0);

        // === 指令 4: OP_VPU_EXEC — 配置并启动 VPU (AD unit) ===
        write_header(OP_VPU_EXEC, 4'h0, 24'd14);  // 14 words body (VPU 12个参数)
        write_body(VPU_UNIT_AD);   // vpu_unit_choose = AD unit
        write_body(32'h00001000);  // vpu_src_addr
        write_body(32'h00002000);  // vpu_src2_addr
        write_body(32'd64);        // vpu_src_c
        write_body(32'd8);         // vpu_src_h
        write_body(32'd8);         // vpu_src_w
        write_body(32'h00000000);  // vpu_bias_addr
        write_body(32'h00000000);  // vpu_scale_addr
        write_body(32'h00003000);  // vpu_dst_addr
        write_body(32'h00000000);  // vpu_addr_break
        write_body(32'h00000000);  // vpu_addr_s
        write_body(32'h00000000);  // vpu_addr_t
        write_body(32'h00000000);  // reserved
        write_body(32'h00000000);  // reserved

        // === 指令 5: OP_WAIT_VPU — 等待 VPU 完成 ===
        write_header(OP_WAIT_VPU, 4'h0, 24'd0);

        // === 指令 6: OP_END ===
        write_header(OP_END, 4'h0, 24'd0);

        // 总字数
        inst_count = word_idx;
        $display("Instruction sequence: %0d words", inst_count);

        // -----------------------------------------------------------------------
        // 复位
        // -----------------------------------------------------------------------
        repeat(4) @(posedge clk);
        rst_n = 1;
        repeat(4) @(posedge clk);

        // -----------------------------------------------------------------------
        // 启动解码器
        // -----------------------------------------------------------------------
        $display("[%0t ns] Starting decoder...", $time);
        @(posedge clk);
        decoder_start = 1;
        @(posedge clk);
        decoder_start = 0;

        // -----------------------------------------------------------------------
        // 等待解码完成：等 decoder_status[1] 置位（超时 10000 cycles）
        // -----------------------------------------------------------------------
        fork
            begin : wait_done
                while (!decoder_status[1]) @(posedge clk);
            end
            begin : timeout
                repeat(10000) @(posedge clk);
                $display("[%0t ns] TIMEOUT!", $time);
                fail_count = fail_count + 1;
                disable wait_done;
            end
        join

        repeat(4) @(posedge clk);

        // -----------------------------------------------------------------------
        // 验证结果
        // -----------------------------------------------------------------------
        $display("");
        $display("--- Verification ---");

        // 检查 DCIM 寄存器写次数 (应为 5 + 1 = 6: cfg 5次 + exec 1次)
        if (dcim_write_count == 6) begin
            $display("PASS: DCIM write count = %0d (expected 6)", dcim_write_count);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: DCIM write count = %0d (expected 6)", dcim_write_count);
            fail_count = fail_count + 1;
        end

        // 检查 DCIM MODE
        if (dcim_reg_mode == 32'h4) begin
            $display("PASS: DCIM MODE = 0x%08X (INT8)", dcim_reg_mode);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: DCIM MODE = 0x%08X (expected 0x00000004)", dcim_reg_mode);
            fail_count = fail_count + 1;
        end

        // 检查 DCIM CTRL（start 脉冲后应回到 0，只看写入值）
        if (dcim_reg_ctrl == 32'h1) begin
            $display("PASS: DCIM CTRL start was asserted");
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: DCIM CTRL = 0x%08X (expected 0x1 at start)", dcim_reg_ctrl);
            fail_count = fail_count + 1;
        end

        // 检查 VPU 参数（通过 $display 可见，这里验证 decoder 已完成）
        if (!decoder_busy && decoder_status[1]) begin
            $display("PASS: decoder completed (status=0x%08X)", decoder_status);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: decoder not completed (busy=%0b status=0x%08X)", decoder_busy, decoder_status);
            fail_count = fail_count + 1;
        end

        // 检查 decoder_status 无错误
        if (decoder_status[31] == 0) begin
            $display("PASS: decoder_status no error (0x%08X)", decoder_status);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL: decoder_status error bit set (0x%08X)", decoder_status);
            fail_count = fail_count + 1;
        end

        // -----------------------------------------------------------------------
        // 结果汇总
        // -----------------------------------------------------------------------
        $display("");
        $display("=================================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        if (fail_count == 0) begin
            $display("  ALL TESTS PASSED");
            $display("=================================================");
            $finish(0);
        end else begin
            $display("  SOME TESTS FAILED");
            $display("=================================================");
            $finish(1);
        end
    end

    // 超时保护
    initial begin
        #(CLK_PERIOD * 20000);
        $display("FATAL: Global timeout");
        $finish(1);
    end

endmodule
