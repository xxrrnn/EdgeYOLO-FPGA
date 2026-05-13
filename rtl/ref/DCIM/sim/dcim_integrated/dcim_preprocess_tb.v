`timescale 1ns / 1ps

// ============================================================================
// dcim_preprocess_tb - 集成测试：act_nibble_converter + DCIM
// ============================================================================
// 完全自包含的测试，不依赖 simToolUp/simToolDown
// 内嵌 Golden Model 验证
// ============================================================================

`include "para.v"

module dcim_preprocess_tb #(
    parameter WD1 = 4,
    parameter CH_IN = 16,
    parameter CH_OUT = 16,
    parameter SRAM_DP = 128,
    parameter CYCLE = 8,
    parameter ACC = 16,
    
    localparam SRAM_WD = CH_IN * CH_OUT * WD1 / CYCLE,  // 128 bits
    localparam ACC_UBD_WD = $clog2(ACC+1),
    localparam ADDR_WD = $clog2(SRAM_DP),
    localparam WD2 = 2*WD1 + $clog2(CH_IN),  // 12
    localparam WD3 = WD2 + $clog2(ACC),       // 16
    localparam T = 10,
    
    // 测试参数
    localparam TEST_ROWS = 8
);

    // ========================================================================
    // 信号声明
    // ========================================================================
    reg clk, rstn, clr, ena;
    reg [2:0] mode_cal;
    reg [ACC_UBD_WD-1:0] acc_reg;
    
    // 权重接口
    reg wr_wei;
    reg load_wei, swap_wei;
    wire up_ready_wei;
    reg [ADDR_WD-1:0] up_address_wei;
    reg [SRAM_WD-1:0] up_data_wei;
    reg [SRAM_WD-1:0] dcim_be_wei;
    
    // Converter 接口
    reg raw_act_valid;
    wire raw_act_ready;
    reg [CH_IN*16-1:0] raw_act_data;
    
    wire converter_valid;
    wire converter_ready;
    wire [CH_IN*WD1-1:0] converter_data;
    
    // 输出接口
    wire dn_valid;
    reg dn_ready;
    wire [CH_OUT*WD3-1:0] dn_data;
    
    // 测试控制
    integer nibble_phases;
    integer num_logical_ch;
    integer result_cnt;
    
    // Golden Model 存储
    reg signed [3:0] weight_nibble [0:CH_IN-1][0:CH_OUT-1];
    reg signed [15:0] activation [0:TEST_ROWS-1][0:CH_IN-1];
    reg signed [31:0] golden [0:TEST_ROWS-1][0:7];  // INT16 需要 32 位
    reg signed [WD3-1:0] dut_out [0:TEST_ROWS-1][0:CH_OUT-1];

    // ========================================================================
    // DCIM 核心
    // ========================================================================
    dcim #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC)
    ) u_dcim (
        .clk(clk), .rstn(rstn), .clr(clr), .ena(ena),
        .mode_cal(mode_cal), .acc(acc_reg),
        .wr_wei(wr_wei), .load_wei(load_wei), .swap_wei(swap_wei),
        .up_ready_wei(up_ready_wei),
        .up_address_wei(up_address_wei),
        .up_data_wei(up_data_wei),
        .up_be_wei(dcim_be_wei),
        .up_valid_cal(converter_valid),
        .up_ready_cal(converter_ready),
        .up_data_cal(converter_data),
        .dn_valid(dn_valid), .dn_ready(dn_ready), .dn_data(dn_data)
    );

    // ========================================================================
    // 激活预处理模块
    // ========================================================================
    act_nibble_converter #(
        .CH_IN(CH_IN),
        .MODE_INT8(`MODE_INT8),
        .MODE_INT16(`MODE_INT16)
    ) u_converter (
        .clk(clk), .rst_n(rstn), .mode(mode_cal),
        .raw_act_valid(raw_act_valid),
        .raw_act_ready(raw_act_ready),
        .raw_act_data(raw_act_data),
        .dcim_act_valid(converter_valid),
        .dcim_act_ready(converter_ready),
        .dcim_act_data(converter_data)
    );

    // ========================================================================
    // DUT 输出捕获
    // ========================================================================
    always @(posedge clk) begin
        if (dn_valid && dn_ready) begin
            for (integer ch = 0; ch < CH_OUT; ch = ch + 1) begin
                dut_out[result_cnt][ch] <= $signed(dn_data[ch*WD3 +: WD3]);
            end
            result_cnt <= result_cnt + 1;
            $display("[DUT] Output row %0d received", result_cnt);
        end
    end

    // ========================================================================
    // 权重生成和加载
    // ========================================================================
    task generate_weights;
        integer i, j;
        begin
            $display("[Task] Generating weights...");
            for (i = 0; i < CH_IN; i = i + 1) begin
                for (j = 0; j < CH_OUT; j = j + 1) begin
                    `ifdef TEST_INT16_SIMPLE
                        // 简单测试：所有权重 nibble 设为 1
                        weight_nibble[i][j] = 4'sd1;
                    `elsif TEST_INT16_CHANNEL
                        // 通道测试：权重 = 物理通道号 + 1
                        weight_nibble[i][j] = (j + 1) % 8;
                    `else
                        weight_nibble[i][j] = $random % 15 - 7;  // [-7, 7]
                    `endif
                end
            end
            $display("  Sample weight_nibble[0][0:7]: %d %d %d %d %d %d %d %d",
                     weight_nibble[0][0], weight_nibble[0][1],
                     weight_nibble[0][2], weight_nibble[0][3],
                     weight_nibble[0][4], weight_nibble[0][5],
                     weight_nibble[0][6], weight_nibble[0][7]);
        end
    endtask
    
    task load_weights_to_sram;
        integer addr, bit_idx, nibble_idx;
        integer in_ch, out_ch;
        reg [SRAM_WD-1:0] sram_word;
        begin
            $display("[Task] Loading weights to SRAM...");
            
            // 只加载前 CYCLE=8 个地址（一个完整的权重 tile）
            for (addr = 0; addr < CYCLE; addr = addr + 1) begin
                sram_word = 0;
                
                for (bit_idx = 0; bit_idx < SRAM_WD; bit_idx = bit_idx + WD1) begin
                    nibble_idx = addr * (SRAM_WD/WD1) + bit_idx/WD1;
                    
                    // DCIM 内部排布：nibble_idx = ch_out * CH_IN + ch_in
                    out_ch = nibble_idx / CH_IN;
                    in_ch = nibble_idx % CH_IN;
                    
                    if (in_ch < CH_IN && out_ch < CH_OUT) begin
                        sram_word[bit_idx +: WD1] = weight_nibble[in_ch][out_ch];
                    end else begin
                        sram_word[bit_idx +: WD1] = 4'd0;
                    end
                end
                
                @(posedge clk);
                wr_wei = 1'b1;
                up_address_wei = addr;
                up_data_wei = sram_word;
                @(posedge clk);
                while (!up_ready_wei) @(posedge clk);
            end
            
            @(posedge clk);
            wr_wei = 1'b0;
            $display("[Task] SRAM loaded (%0d addresses)", CYCLE);
        end
    endtask
    
    task load_to_ppcache;
        begin
            $display("[Task] Loading to ppCache...");
            up_address_wei = 0;
            // 只需要一次 load，等待 CYCLE 个周期完成加载
            // ppCache 状态: IDLE → PREPARE，此时 dn_valid=1，权重可用
            load_wei = 1; #(T); load_wei = 0;
            #((CYCLE+2)*T);
            // 不需要第二次 load 和 swap
            // swap 只在需要切换双缓冲时使用
            $display("[Task] ppCache loaded (single buffer mode)");
        end
    endtask

    // ========================================================================
    // 激活数据生成和发送
    // ========================================================================
    task generate_activations;
        integer row, ch;
        begin
            $display("[Task] Generating activations...");
            for (row = 0; row < TEST_ROWS; row = row + 1) begin
                for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                    `ifdef TEST_INT16_SIMPLE
                        // 简单测试：激活设为 1
                        activation[row][ch] = 16'sd1;
                    `elsif TEST_INT16_CHANNEL
                        // 通道测试：只有第一个输入通道激活为 1
                        activation[row][ch] = (ch == 0) ? 16'sd1 : 16'sd0;
                    `else
                        if (mode_cal == `MODE_INT8) begin
                            activation[row][ch] = $signed($random % 255 - 127);
                        end else begin
                            activation[row][ch] = $signed($random % 65535 - 32767);
                        end
                    `endif
                end
            end
            $display("  Sample activation[0][0:3]: %d %d %d %d",
                     activation[0][0], activation[0][1],
                     activation[0][2], activation[0][3]);
        end
    endtask
    
    task send_activations;
        integer row, ch;
        begin
            $display("[Task] Sending activations...");
            for (row = 0; row < TEST_ROWS; row = row + 1) begin
                for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                    raw_act_data[ch*16 +: 16] = activation[row][ch];
                end
                
                @(posedge clk);
                raw_act_valid = 1'b1;
                @(posedge clk);
                while (!raw_act_ready) @(posedge clk);
                @(posedge clk);
                raw_act_valid = 1'b0;
                
                repeat(nibble_phases * 3) @(posedge clk);
            end
            $display("[Task] All activations sent");
        end
    endtask

    // ========================================================================
    // Golden Model 计算
    // ========================================================================
    task compute_golden;
        integer row, out_ch, in_ch, acc_row;
        integer acc_group, row_in_group;
        reg signed [31:0] sum;
        reg signed [7:0] w8;
        reg signed [15:0] w16;
        reg signed [7:0] a8;
        reg signed [15:0] a16;
        integer phys_ch_lo, phys_ch_hi;
        integer num_acc_groups;
        integer acc_val;
        begin
            $display("[Task] Computing golden model...");
            
            // 确定累加组数
            acc_val = (acc_reg == 0) ? 1 : acc_reg;
            num_acc_groups = TEST_ROWS / acc_val;
            
            $display("  ACC=%0d, Groups=%0d, Rows per group=%0d", acc_reg, num_acc_groups, acc_val);
            
            // 初始化 golden 数组
            for (row = 0; row < TEST_ROWS; row = row + 1) begin
                for (out_ch = 0; out_ch < 8; out_ch = out_ch + 1) begin
                    golden[row][out_ch] = 0;
                end
            end
            
            // 按累加组计算
            for (acc_group = 0; acc_group < num_acc_groups; acc_group = acc_group + 1) begin
                for (out_ch = 0; out_ch < num_logical_ch; out_ch = out_ch + 1) begin
                    sum = 0;
                    
                    // 累加组内所有行
                    for (row_in_group = 0; row_in_group < acc_val; row_in_group = row_in_group + 1) begin
                        row = acc_group * acc_val + row_in_group;
                        
                        for (in_ch = 0; in_ch < CH_IN; in_ch = in_ch + 1) begin
                            if (mode_cal == `MODE_INT8) begin
                                // INT8: 逻辑通道 out_ch 使用物理通道 out_ch*2+2 和 out_ch*2+3
                                phys_ch_lo = out_ch * 2 + 2;
                                phys_ch_hi = out_ch * 2 + 3;
                                
                                if (phys_ch_lo >= CH_OUT) phys_ch_lo = CH_OUT - 2;
                                if (phys_ch_hi >= CH_OUT) phys_ch_hi = CH_OUT - 1;
                                
                                w8 = {weight_nibble[in_ch][phys_ch_hi], weight_nibble[in_ch][phys_ch_lo]};
                                a8 = activation[row][in_ch][7:0];
                                sum = sum + ($signed(a8) * $signed(w8));
                            end else begin
                                // INT16: 每 4 个物理通道产生 1 个逻辑通道
                                integer base_ch, ch0, ch1, ch2, ch3;
                                base_ch = out_ch * 4 + 2;
                                ch0 = base_ch;
                                ch1 = base_ch + 1;
                                ch2 = base_ch + 2;
                                ch3 = base_ch + 3;
                                if (ch0 >= CH_OUT) ch0 = CH_OUT - 2;
                                if (ch1 >= CH_OUT) ch1 = CH_OUT - 1;
                                if (ch2 >= CH_OUT) ch2 = CH_OUT - 2;
                                if (ch3 >= CH_OUT) ch3 = CH_OUT - 1;
                                w16 = {weight_nibble[in_ch][ch3],
                                       weight_nibble[in_ch][ch2],
                                       weight_nibble[in_ch][ch1],
                                       weight_nibble[in_ch][ch0]};
                                a16 = activation[row][in_ch];
                                sum = sum + ($signed(a16) * $signed(w16));
                            end
                        end
                    end
                    
                    // 存储累加结果到组的第一行位置
                    if (mode_cal == `MODE_INT8) begin
                        golden[acc_group][out_ch] = $signed(sum[WD3-1:0]);
                    end else begin
                        golden[acc_group][out_ch] = sum;
                    end
                end
            end
            $display("  Golden[0][0:7]: %d %d %d %d %d %d %d %d",
                     golden[0][0], golden[0][1], golden[0][2], golden[0][3],
                     golden[0][4], golden[0][5], golden[0][6], golden[0][7]);
        end
    endtask

    // ========================================================================
    // 验证
    // ========================================================================
    task verify;
        integer row, ch, errors, total;
        integer col, subcol;
        integer phys_ch_idx;
        reg signed [31:0] dut_val, exp_val;
        integer num_expected_outputs;
        integer acc_val;
        begin
            $display("");
            $display("═══════════════════════════════════════════════════════");
            $display("  VERIFICATION RESULTS");
            $display("═══════════════════════════════════════════════════════");
            $display("  Mode: %s", (mode_cal == `MODE_INT8) ? "INT8" : "INT16");
            $display("  ACC: %0d", acc_reg);
            
            // 计算期望的输出数量
            acc_val = (acc_reg == 0) ? 1 : acc_reg;
            num_expected_outputs = TEST_ROWS / acc_val;
            
            $display("  Test rows: %0d, Expected outputs: %0d", TEST_ROWS, num_expected_outputs);
            $display("  Logical channels: %0d", num_logical_ch);
            $display("  DUT results collected: %0d", result_cnt);
            $display("");
            
            errors = 0;
            total = 0;
            
            for (row = 0; row < result_cnt && row < num_expected_outputs; row = row + 1) begin
                for (ch = 0; ch < num_logical_ch; ch = ch + 1) begin
                    if (mode_cal == `MODE_INT8) begin
                        col = ch / 2;
                        subcol = ch % 2;
                        phys_ch_idx = col * 4 + subcol * 2;
                        dut_val = dut_out[row][phys_ch_idx];
                        exp_val = golden[row][ch];
                    end else begin
                        dut_val = {dut_out[row][ch*4+1], dut_out[row][ch*4]};
                        exp_val = golden[row][ch];
                    end
                    
                    total = total + 1;
                    if (dut_val !== exp_val) begin
                        errors = errors + 1;
                        if (errors <= 10) begin
                            $display("  [ERR] Row %0d Ch %0d: DUT=%0d, Golden=%0d, Diff=%0d",
                                     row, ch, dut_val, exp_val, dut_val - exp_val);
                        end
                    end else if (row < 2 && ch < 4) begin
                        $display("  [OK] Row %0d Ch %0d: %0d", row, ch, dut_val);
                    end
                end
            end
            
            // 打印所有物理通道的值用于调试
            $display("");
            $display("  Debug: Row 0 physical channels:");
            $display("    [0:7]: %d %d %d %d %d %d %d %d",
                     dut_out[0][0], dut_out[0][1], dut_out[0][2], dut_out[0][3],
                     dut_out[0][4], dut_out[0][5], dut_out[0][6], dut_out[0][7]);
            $display("    [8:15]: %d %d %d %d %d %d %d %d",
                     dut_out[0][8], dut_out[0][9], dut_out[0][10], dut_out[0][11],
                     dut_out[0][12], dut_out[0][13], dut_out[0][14], dut_out[0][15]);
            
            $display("");
            $display("───────────────────────────────────────────────────────");
            $display("  Total: %0d comparisons, %0d errors", total, errors);
            $display("───────────────────────────────────────────────────────");
            
            if (errors == 0 && total > 0) begin
                $display("");
                $display("  ╔═══════════════════════════════════════╗");
                $display("  ║  ✓ VERIFICATION PASSED                ║");
                $display("  ╚═══════════════════════════════════════╝");
            end else if (total == 0) begin
                $display("");
                $display("  ╔═══════════════════════════════════════╗");
                $display("  ║  ⚠ NO RESULTS TO VERIFY               ║");
                $display("  ╚═══════════════════════════════════════╝");
            end else begin
                $display("");
                $display("  ╔═══════════════════════════════════════╗");
                $display("  ║  ✗ VERIFICATION FAILED                ║");
                $display("  ╚═══════════════════════════════════════╝");
            end
            $display("");
        end
    endtask

    // ========================================================================
    // 主测试流程
    // ========================================================================
    always #(T/2) clk = ~clk;
    
    initial begin
        clk = 0; rstn = 0; clr = 0; ena = 1;
        wr_wei = 0; load_wei = 0; swap_wei = 0;
        dcim_be_wei = {SRAM_WD{1'b1}};
        up_address_wei = 0; up_data_wei = 0;
        raw_act_valid = 0; raw_act_data = 0;
        dn_ready = 1;
        mode_cal = `MODE_INT8;
        acc_reg = 0;
        nibble_phases = 2;
        num_logical_ch = 8;
        result_cnt = 0;
        
        // 模式配置
        `ifdef TEST_INT16
            mode_cal = `MODE_INT16;
            nibble_phases = 4;
            num_logical_ch = 4;
            $display("");
            $display("╔═══════════════════════════════════════════════════════╗");
            $display("║  INT16 Integration Test (Preprocess + DCIM)          ║");
            $display("╚═══════════════════════════════════════════════════════╝");
        `else
            mode_cal = `MODE_INT8;
            nibble_phases = 2;
            num_logical_ch = 8;
            $display("");
            $display("╔═══════════════════════════════════════════════════════╗");
            $display("║  INT8 Integration Test (Preprocess + DCIM)           ║");
            $display("╚═══════════════════════════════════════════════════════╝");
        `endif
        
        // 累加配置
        `ifdef TEST_ACC
            acc_reg = `TEST_ACC;
            $display("  ACC mode: accumulate %0d rows", acc_reg);
        `else
            acc_reg = 0;
            $display("  ACC mode: bypass (no accumulation)");
        `endif
        
        $display("  CH_IN=%0d, CH_OUT=%0d, WD1=%0d, WD3=%0d", CH_IN, CH_OUT, WD1, WD3);
        $display("  Logical channels=%0d, Nibble phases=%0d", num_logical_ch, nibble_phases);
        $display("");
        
        #(T*10); rstn = 1; #(T*10);
        
        $display("═══════════════════════════════════════════════════════");
        $display("[Phase 1/6] Generating weights...");
        $display("═══════════════════════════════════════════════════════");
        generate_weights();
        
        $display("");
        $display("═══════════════════════════════════════════════════════");
        $display("[Phase 2/6] Loading weights to SRAM...");
        $display("═══════════════════════════════════════════════════════");
        load_weights_to_sram();
        
        $display("");
        $display("═══════════════════════════════════════════════════════");
        $display("[Phase 3/6] Loading to ppCache...");
        $display("═══════════════════════════════════════════════════════");
        load_to_ppcache();
        
        $display("");
        $display("═══════════════════════════════════════════════════════");
        $display("[Phase 4/6] Generating activations...");
        $display("═══════════════════════════════════════════════════════");
        generate_activations();
        
        $display("");
        $display("═══════════════════════════════════════════════════════");
        $display("[Phase 5/6] Computing golden model...");
        $display("═══════════════════════════════════════════════════════");
        compute_golden();
        
        $display("");
        $display("═══════════════════════════════════════════════════════");
        $display("[Phase 6/6] Sending activations and collecting results...");
        $display("═══════════════════════════════════════════════════════");
        send_activations();
        
        $display("[Waiting] Collecting DUT results...");
        #(T*3000);
        
        verify();
        
        #(T*20);
        $finish;
    end
    
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, dcim_preprocess_tb);
    end
    
    initial begin
        #(T*100000);
        $display("TIMEOUT!");
        verify();
        $finish;
    end

endmodule
