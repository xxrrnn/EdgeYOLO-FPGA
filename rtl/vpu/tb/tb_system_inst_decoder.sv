`timescale 1ns / 1ps
module tb_system_inst_decoder;

    localparam CLK_PERIOD    = 4.0;
    localparam ADDR_WIDTH    = 32;
    localparam GB_ADDR_WIDTH = 22;
    localparam WB_ADDR_WIDTH = 20;
    localparam GB_BW         = 256;
    localparam FP_W          = 32;
    localparam FP_CORE_NUM   = 8;
    localparam NB_COL        = 32;
    localparam COL_WIDTH     = 8;
    localparam RAM_DEPTH_GB  = 4096;
    localparam RAM_DEPTH_WB  = 4096;
    localparam LANES         = GB_BW / FP_W;

    localparam INST_BRAM_DEPTH = 1024;
    localparam INST_ADDR_WIDTH = 10;

    localparam [3:0] OP_VPU_EXEC = 4'h2;
    localparam [3:0] OP_WAIT_VPU = 4'h4;
    localparam [3:0] OP_END      = 4'hF;

    localparam [31:0] UNIT_AD = 32'd6;
    localparam [31:0] UNIT_MP = 32'd4;
    localparam [31:0] UNIT_US = 32'd5;

    // Signals
    reg clk, rst_n;
    reg decoder_start;
    reg [31:0] inst_count;
    wire decoder_busy, decoder_done;
    wire [31:0] decoder_status;

    wire [INST_ADDR_WIDTH-1:0] inst_rd_addr;
    reg  [31:0] inst_rd_data;

    wire vpu_start, vpu_ready;
    wire [31:0] vpu_unit_choose, vpu_src_addr, vpu_src2_addr;
    wire [31:0] vpu_src_c, vpu_src_h, vpu_src_w;
    wire [31:0] vpu_bias_addr, vpu_scale_addr, vpu_dst_addr;
    wire [31:0] vpu_addr_break, vpu_addr_s, vpu_addr_t;

    // GB port A signals (for TB writes)
    reg  [GB_ADDR_WIDTH-1:0] gb_addra;
    reg  [NB_COL*COL_WIDTH-1:0] gb_dina;
    reg  [NB_COL-1:0] gb_wea;
    reg  gb_ena;
    wire [NB_COL*COL_WIDTH-1:0] gb_douta;

    // WB port A signals
    reg  [WB_ADDR_WIDTH-1:0] wb_addra;
    reg  [NB_COL*COL_WIDTH-1:0] wb_dina;
    reg  [NB_COL-1:0] wb_wea;
    reg  wb_ena;
    wire [NB_COL*COL_WIDTH-1:0] wb_douta;

    // Inst BRAM model
    reg [31:0] inst_bram_mem [0:INST_BRAM_DEPTH-1];

    // 1-cycle read latency for inst_bram
    always @(posedge clk) begin
        inst_rd_data <= inst_bram_mem[inst_rd_addr];
    end

    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // INST_Decoder instance
    INST_Decoder #(
        .INST_BRAM_DEPTH(INST_BRAM_DEPTH),
        .INST_ADDR_WIDTH(INST_ADDR_WIDTH)
    ) u_decoder (
        .clk(clk),
        .rst_n(rst_n),
        .decoder_start(decoder_start),
        .inst_count(inst_count),
        .decoder_busy(decoder_busy),
        .decoder_done(decoder_done),
        .decoder_status(decoder_status),
        .inst_rd_addr(inst_rd_addr),
        .inst_rd_data(inst_rd_data),
        .cdma_start(),
        .cdma_config_valid(),
        .cdma_config_ready(1'b1),
        .cdma_src_addr_msb(),
        .cdma_src_addr_lsb(),
        .cdma_dst_addr_msb(),
        .cdma_dst_addr_lsb(),
        .cdma_length(),
        .vpu_start(vpu_start),
        .vpu_ready(vpu_ready),
        .vpu_unit_choose(vpu_unit_choose),
        .vpu_src_addr(vpu_src_addr),
        .vpu_src2_addr(vpu_src2_addr),
        .vpu_src_c(vpu_src_c),
        .vpu_src_h(vpu_src_h),
        .vpu_src_w(vpu_src_w),
        .vpu_bias_addr(vpu_bias_addr),
        .vpu_scale_addr(vpu_scale_addr),
        .vpu_dst_addr(vpu_dst_addr),
        .vpu_addr_break(vpu_addr_break),
        .vpu_addr_s(vpu_addr_s),
        .vpu_addr_t(vpu_addr_t)
    );

    // Global_VPU instance
    Global_VPU #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
        .BANDWIDTH(GB_BW),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_TRAN_NUM(8),
        .FP_WIDTH(FP_W),
        .NB_COL(NB_COL),
        .COL_WIDTH(COL_WIDTH),
        .RAM_DEPTH_GB(RAM_DEPTH_GB),
        .RAM_DEPTH_WB(RAM_DEPTH_WB),
        .MAX_CHANNEL_NUM(1024),
        .INTERVAL_NUM(16),
        .Q_INT_WIDTH_OUT(8),
        .C_INT_WIDTH_IN(32)
    ) u_vpu (
        .clk(clk),
        .rst_n(rst_n),
        .config_ready(vpu_ready),
        .config_valid(1'b1),
        .start(vpu_start),
        .unit_choose(vpu_unit_choose),
        .src_addr(vpu_src_addr),
        .src2_addr(vpu_src2_addr),
        .src_c(vpu_src_c),
        .src_h(vpu_src_h),
        .src_w(vpu_src_w),
        .scale_addr(vpu_scale_addr),
        .bias_addr(vpu_bias_addr),
        .dst_addr(vpu_dst_addr),
        .addr_break(vpu_addr_break),
        .addr_s(vpu_addr_s),
        .addr_t(vpu_addr_t),
        .gb_addra(gb_addra),
        .gb_dina(gb_dina),
        .gb_wea(gb_wea),
        .gb_ena(gb_ena),
        .gb_douta(gb_douta),
        .wb_addra(wb_addra),
        .wb_dina(wb_dina),
        .wb_wea(wb_wea),
        .wb_ena(wb_ena),
        .wb_douta(wb_douta)
    );

    // Helper: write one 256-bit word to GB via port A
    task write_gb_word(input [GB_ADDR_WIDTH-1:0] addr, input [GB_BW-1:0] data);
        begin
            @(posedge clk);
            gb_addra <= addr;
            gb_dina  <= data;
            gb_wea   <= {NB_COL{1'b1}};
            gb_ena   <= 1'b1;
            @(posedge clk);
            gb_wea   <= '0;
            gb_ena   <= 1'b0;
        end
    endtask

    // Helper: read one 256-bit word from GB via port A
    task read_gb_word(input [GB_ADDR_WIDTH-1:0] addr, output [GB_BW-1:0] data);
        begin
            @(posedge clk);
            gb_addra <= addr;
            gb_wea   <= '0;
            gb_ena   <= 1'b1;
            @(posedge clk);
            gb_ena   <= 1'b0;
            @(posedge clk);
            data = gb_douta;
        end
    endtask

    // Helper: write instruction word into inst_bram
    task write_inst(input integer idx, input [31:0] data);
        begin
            inst_bram_mem[idx] = data;
        end
    endtask

    // Helper: build VPU_EXEC header
    function [31:0] make_vpu_exec_header;
        begin
            make_vpu_exec_header = {OP_VPU_EXEC, 4'h0, 24'd48};
        end
    endfunction

    function [31:0] make_wait_vpu_header;
        begin
            make_wait_vpu_header = {OP_WAIT_VPU, 4'h0, 24'd0};
        end
    endfunction

    function [31:0] make_end_header;
        begin
            make_end_header = {OP_END, 4'h0, 24'd0};
        end
    endfunction

    // FP32 helpers
    function [FP_W-1:0] real_to_fp32(input real rval);
        shortreal sr;
        begin
            sr = shortreal'(rval);
            real_to_fp32 = $shortrealtobits(sr);
        end
    endfunction

    function real fp32_to_real(input [FP_W-1:0] bits);
        begin
            fp32_to_real = $bitstoshortreal(bits);
        end
    endfunction

    // Test variables
    integer i, j, errors, total_inst_words;
    reg [GB_BW-1:0] read_data;
    reg [FP_W-1:0] actual_fp, expected_fp;
    real a_val, b_val, sum_val;

    initial begin
        $display("============================================================");
        $display("  tb_system_inst_decoder: System-level VPU test via decoder");
        $display("============================================================");

        rst_n = 0;
        decoder_start = 0;
        inst_count = 0;
        gb_addra = 0; gb_dina = 0; gb_wea = 0; gb_ena = 0;
        wb_addra = 0; wb_dina = 0; wb_wea = 0; wb_ena = 0;

        for (i = 0; i < INST_BRAM_DEPTH; i++) inst_bram_mem[i] = 32'h0;

        repeat(20) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);

        // ============================================================
        // TEST 1: AD unit (element-wise add)
        // src1 at GB word 0, src2 at GB word 1, dst at GB word 2
        // src_c=8, src_h=1, src_w=1 => 1 BRAM word (8 FP32 lanes)
        // ============================================================
        $display("\n--- TEST 1: AD unit (element-wise add) ---");

        // Write SRC1 data to GB word 0
        begin
            reg [GB_BW-1:0] src1_data, src2_data;
            src1_data = '0;
            src2_data = '0;
            for (i = 0; i < LANES; i++) begin
                src1_data[i*FP_W +: FP_W] = real_to_fp32(1.0 + $itor(i));
                src2_data[i*FP_W +: FP_W] = real_to_fp32(10.0 + $itor(i));
            end
            write_gb_word(0, src1_data);
            write_gb_word(1, src2_data);
        end
        $display("  Wrote SRC1 and SRC2 to GB.");

        // Build instruction stream for AD unit test
        // src_addr=0*32=0, src2_addr=1*32=32, dst_addr=2*32=64
        // src_c=8, src_h=1, src_w=1
        total_inst_words = 0;
        write_inst(total_inst_words, make_vpu_exec_header()); total_inst_words++;
        write_inst(total_inst_words, UNIT_AD);                total_inst_words++; // body[0] unit_choose
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // body[1] src_addr (byte addr => word 0)
        write_inst(total_inst_words, 32'd32);                 total_inst_words++; // body[2] src2_addr (byte addr => word 1)
        write_inst(total_inst_words, 32'd8);                  total_inst_words++; // body[3] src_c
        write_inst(total_inst_words, 32'd1);                  total_inst_words++; // body[4] src_h
        write_inst(total_inst_words, 32'd1);                  total_inst_words++; // body[5] src_w
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // body[6] bias_addr
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // body[7] scale_addr
        write_inst(total_inst_words, 32'd64);                 total_inst_words++; // body[8] dst_addr (byte addr => word 2)
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // body[9] addr_break
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // body[10] addr_s
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // body[11] addr_t
        write_inst(total_inst_words, make_wait_vpu_header());  total_inst_words++;
        write_inst(total_inst_words, make_end_header());       total_inst_words++;

        // Start decoder
        inst_count = total_inst_words;
        @(posedge clk);
        decoder_start <= 1;
        @(posedge clk);
        decoder_start <= 0;

        // Wait for decoder_done
        wait(decoder_done == 1'b1);
        $display("  Decoder done. Status=0x%08h", decoder_status);
        repeat(5) @(posedge clk);

        // Read result from GB word 2 and verify
        read_gb_word(2, read_data);
        errors = 0;
        for (i = 0; i < LANES; i++) begin
            actual_fp = read_data[i*FP_W +: FP_W];
            a_val = 1.0 + $itor(i);
            b_val = 10.0 + $itor(i);
            sum_val = a_val + b_val;
            expected_fp = real_to_fp32(sum_val);
            if (actual_fp !== expected_fp) begin
                errors++;
                $display("  MISMATCH lane %0d: expected=0x%08h (%.4f) actual=0x%08h (%.4f)",
                    i, expected_fp, sum_val, actual_fp, fp32_to_real(actual_fp));
            end
        end
        if (errors == 0)
            $display("  TEST 1 AD unit: *** PASS *** (8/8 lanes correct)");
        else
            $display("  TEST 1 AD unit: *** FAIL *** (%0d/8 lanes wrong)", errors);

        repeat(20) @(posedge clk);

        // ============================================================
        // TEST 2: MP unit (MaxPool 5x5, H=10, W=10, C=128)
        // Input at GB word 0, output at GB word 1600
        // ============================================================
        $display("\n--- TEST 2: MP unit (MaxPool 5x5) ---");

        // Write known data to GB (simple pattern)
        begin
            reg [GB_BW-1:0] wd;
            integer h, w, c_blk;
            real fval;
            for (h = 0; h < 10; h++) begin
                for (w = 0; w < 10; w++) begin
                    for (c_blk = 0; c_blk < 16; c_blk++) begin
                        wd = '0;
                        for (j = 0; j < LANES; j++) begin
                            fval = $itor(h*100 + w*10 + c_blk*8 + j) / 10.0;
                            wd[j*FP_W +: FP_W] = real_to_fp32(fval);
                        end
                        write_gb_word((h*10 + w)*16 + c_blk, wd);
                    end
                end
            end
        end
        $display("  Wrote MP input data to GB (1600 words).");

        // Build instruction stream
        total_inst_words = 0;
        write_inst(total_inst_words, make_vpu_exec_header()); total_inst_words++;
        write_inst(total_inst_words, UNIT_MP);                total_inst_words++;
        write_inst(total_inst_words, 32'h0000_0000);          total_inst_words++; // src_addr
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // src2_addr
        write_inst(total_inst_words, 32'd128);                total_inst_words++; // src_c
        write_inst(total_inst_words, 32'd10);                 total_inst_words++; // src_h
        write_inst(total_inst_words, 32'd10);                 total_inst_words++; // src_w
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // bias_addr
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // scale_addr
        write_inst(total_inst_words, 32'h0000_C800);          total_inst_words++; // dst_addr (word 1600 * 32 = 0xC800)
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // addr_break
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // addr_s
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // addr_t
        write_inst(total_inst_words, make_wait_vpu_header());  total_inst_words++;
        write_inst(total_inst_words, make_end_header());       total_inst_words++;

        inst_count = total_inst_words;
        @(posedge clk);
        decoder_start <= 1;
        @(posedge clk);
        decoder_start <= 0;

        wait(decoder_done == 1'b1);
        $display("  Decoder done. Status=0x%08h", decoder_status);
        repeat(5) @(posedge clk);

        // Spot check: read output word 1600 (first output word)
        read_gb_word(1600, read_data);
        // Full golden model verification for MaxPool 5x5
        begin
            integer h, w, c_idx, kh, kw, ih, iw;
            integer mp_errors, mp_checked;
            reg [FP_W-1:0] cur_max, val, actual_v, expected_v;
            reg [GB_BW-1:0] out_word;
            mp_errors = 0;
            mp_checked = 0;
            for (h = 0; h < 10; h++) begin
                for (w = 0; w < 10; w++) begin
                    for (c_idx = 0; c_idx < 128; c_idx++) begin
                        // Compute golden max
                        cur_max = 32'hFF80_0000; // -inf
                        for (kh = 0; kh < 5; kh++) begin
                            for (kw = 0; kw < 5; kw++) begin
                                ih = h + kh - 2;
                                iw = w + kw - 2;
                                if (ih >= 0 && ih < 10 && iw >= 0 && iw < 10) begin
                                    reg [GB_BW-1:0] rd_w;
                                    read_gb_word((ih*10 + iw)*16 + c_idx/8, rd_w);
                                    val = rd_w[(c_idx%8)*FP_W +: FP_W];
                                    // FP32 max
                                    if ($bitstoshortreal(val) > $bitstoshortreal(cur_max))
                                        cur_max = val;
                                end
                            end
                        end
                        // Read actual
                        read_gb_word(1600 + (h*10 + w)*16 + c_idx/8, out_word);
                        actual_v = out_word[(c_idx%8)*FP_W +: FP_W];
                        expected_v = cur_max;
                        mp_checked++;
                        if (actual_v !== expected_v) begin
                            mp_errors++;
                            if (mp_errors <= 10)
                                $display("  MP MISMATCH [h=%0d w=%0d c=%0d]: exp=0x%08h act=0x%08h",
                                    h, w, c_idx, expected_v, actual_v);
                        end
                    end
                end
            end
            if (mp_errors == 0)
                $display("  TEST 2 MP unit: *** PASS *** (%0d elements bit-exact)", mp_checked);
            else
                $display("  TEST 2 MP unit: *** FAIL *** (%0d/%0d errors)", mp_errors, mp_checked);
        end

        repeat(20) @(posedge clk);

        // ============================================================
        // TEST 3: US unit (Upsample 2x, H=5, W=5, C=8)
        // Use small size for quick verification
        // Input at GB word 100, output at GB word 200
        // src_c=8, src_h=5, src_w=5
        // ============================================================
        $display("\n--- TEST 3: US unit (Nearest-neighbor upsample x2) ---");

        begin
            reg [GB_BW-1:0] wd;
            integer h, w;
            real fval;
            // Write 5x5x1_block = 25 words starting at word 100
            for (h = 0; h < 5; h++) begin
                for (w = 0; w < 5; w++) begin
                    wd = '0;
                    for (j = 0; j < LANES; j++) begin
                        fval = $itor((h+1)*10 + (w+1)) + $itor(j)*0.1;
                        wd[j*FP_W +: FP_W] = real_to_fp32(fval);
                    end
                    write_gb_word(100 + h*5 + w, wd);
                end
            end
        end
        $display("  Wrote US input data to GB (25 words at addr 100).");

        // Build instruction stream
        // src_addr = 100*32 = 3200 = 0xC80
        // dst_addr = 200*32 = 6400 = 0x1900
        total_inst_words = 0;
        write_inst(total_inst_words, make_vpu_exec_header()); total_inst_words++;
        write_inst(total_inst_words, UNIT_US);                total_inst_words++;
        write_inst(total_inst_words, 32'h0000_0C80);          total_inst_words++; // src_addr
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // src2_addr
        write_inst(total_inst_words, 32'd8);                  total_inst_words++; // src_c
        write_inst(total_inst_words, 32'd5);                  total_inst_words++; // src_h
        write_inst(total_inst_words, 32'd5);                  total_inst_words++; // src_w
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // bias_addr
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // scale_addr
        write_inst(total_inst_words, 32'h0000_1900);          total_inst_words++; // dst_addr
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // addr_break
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // addr_s
        write_inst(total_inst_words, 32'd0);                  total_inst_words++; // addr_t
        write_inst(total_inst_words, make_wait_vpu_header());  total_inst_words++;
        write_inst(total_inst_words, make_end_header());       total_inst_words++;

        inst_count = total_inst_words;
        @(posedge clk);
        decoder_start <= 1;
        @(posedge clk);
        decoder_start <= 0;

        wait(decoder_done == 1'b1);
        $display("  Decoder done. Status=0x%08h", decoder_status);
        repeat(5) @(posedge clk);

        // Full golden model verification for Upsample x2 (nearest neighbor)
        // Output: 10x10x1_block = 100 words starting at word 200
        begin
            integer oh, ow, ih_gold, iw_gold;
            integer us_errors, us_checked;
            reg [GB_BW-1:0] out_word, src_word;
            reg [FP_W-1:0] actual_v, expected_v;
            us_errors = 0;
            us_checked = 0;
            for (oh = 0; oh < 10; oh++) begin
                for (ow = 0; ow < 10; ow++) begin
                    ih_gold = oh / 2;
                    iw_gold = ow / 2;
                    read_gb_word(200 + oh*10 + ow, out_word);
                    read_gb_word(100 + ih_gold*5 + iw_gold, src_word);
                    for (j = 0; j < LANES; j++) begin
                        actual_v = out_word[j*FP_W +: FP_W];
                        expected_v = src_word[j*FP_W +: FP_W];
                        us_checked++;
                        if (actual_v !== expected_v) begin
                            us_errors++;
                            if (us_errors <= 10)
                                $display("  US MISMATCH [oh=%0d ow=%0d lane=%0d]: exp=0x%08h act=0x%08h",
                                    oh, ow, j, expected_v, actual_v);
                        end
                    end
                end
            end
            if (us_errors == 0)
                $display("  TEST 3 US unit: *** PASS *** (%0d elements bit-exact)", us_checked);
            else
                $display("  TEST 3 US unit: *** FAIL *** (%0d/%0d errors)", us_errors, us_checked);
        end

        // ============================================================
        // Final summary
        // ============================================================
        repeat(10) @(posedge clk);
        $display("\n============================================================");
        $display("  All system-level tests completed.");
        $display("============================================================\n");
        $finish;
    end

    // Timeout
    initial begin
        #(CLK_PERIOD * 5000000);
        $display("ERROR: Simulation timeout (5M cycles)!");
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_system_inst_decoder.vcd");
        $dumpvars(0, tb_system_inst_decoder);
    end

endmodule
