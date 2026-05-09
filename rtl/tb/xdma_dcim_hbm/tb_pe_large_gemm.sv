`timescale 1ns / 1ps
`include "dcim_defs.vh"

module tb_pe_large_gemm;
    localparam int BRAM_BYTES  = `DCIM_BRAM_BYTES;
    localparam int BRAM_WIDTH  = `DCIM_BRAM_DATA_WIDTH;
    localparam int WD3         = `DCIM_WD3;
    localparam int CH_OUT      = `DCIM_CH_OUT;
    localparam int MODE_INT8   = `DCIM_MODE_INT8;
    localparam int INT8_COLS   = (`DCIM_CH_OUT / 2);
    localparam int INT8_PACK_W = 2 * WD3;
    // Merge output width: WD_TEMP = WD_PS1 + WD1 + 1 = (WD2 + WD1 + 1) + WD1 + 1 = WD2 + 2*WD1 + 2
    // Then sign-extended to 2*WD2 in merge, then to 2*WD3 in accumulate
    localparam int WD2 = `DCIM_WD2;
    localparam int WD1 = `DCIM_WD1;

    // "Large" matrix by row count and K-tiling passes.
    localparam int M_ROWS      = 128;
    localparam int K_TILES     = 8;

    localparam int W_BASE_BYTE = 32'h0000;
    localparam int A_BASE_BYTE = 32'h1000;
    localparam int DST_ACC     = 32'h0000;
    localparam int DST_REF0    = 32'h2000;
    localparam int DST_STRIDE  = 32'h1000;

    localparam int OUT_WORDS   = M_ROWS;

    logic clk;
    logic rst_n;

    logic dcim_start;
    logic dcim_config_valid;
    logic dcim_config_ready;
    logic dcim_busy;
    logic dcim_done;
    logic dcim_error;
    logic [31:0] dcim_error_code;
    logic [`DCIM_ADDR_WIDTH-1:0] dcim_wsrc_base_addr;
    logic [`DCIM_ADDR_WIDTH-1:0] dcim_asrc_base_addr;
    logic [`DCIM_ADDR_WIDTH-1:0] dcim_dst_addr;
    logic [31:0] dcim_raw_rows;
    logic [2:0] dcim_mode;
    logic [4:0] dcim_acc;
    logic [1:0] dcim_accumulate_type;

    logic ibuf_ena;
    logic [BRAM_BYTES-1:0] ibuf_wea;
    logic [`DCIM_ADDR_WIDTH-1:0] ibuf_addra;
    logic [BRAM_WIDTH-1:0] ibuf_dina;
    logic [BRAM_WIDTH-1:0] ibuf_douta;

    logic obuf_ena;
    logic [BRAM_BYTES-1:0] obuf_wea;
    logic [`DCIM_ADDR_WIDTH-1:0] obuf_addra;
    logic [BRAM_WIDTH-1:0] obuf_dina;
    logic [BRAM_WIDTH-1:0] obuf_douta;

    logic [BRAM_WIDTH-1:0] ref_words [0:K_TILES-1][0:OUT_WORDS-1];
    logic [BRAM_WIDTH-1:0] accum_words [0:OUT_WORDS-1];
    logic [BRAM_WIDTH-1:0] expected_words [0:OUT_WORDS-1];
    logic [BRAM_WIDTH-1:0] golden_words [0:K_TILES-1][0:OUT_WORDS-1];

    PE dut (
        .clk(clk),
        .rst_n(rst_n),
        .dcim_start(dcim_start),
        .dcim_config_valid(dcim_config_valid),
        .dcim_config_ready(dcim_config_ready),
        .dcim_busy(dcim_busy),
        .dcim_done(dcim_done),
        .dcim_error(dcim_error),
        .dcim_error_code(dcim_error_code),
        .dcim_wsrc_base_addr(dcim_wsrc_base_addr),
        .dcim_asrc_base_addr(dcim_asrc_base_addr),
        .dcim_dst_addr(dcim_dst_addr),
        .dcim_raw_rows(dcim_raw_rows),
        .dcim_mode(dcim_mode),
        .dcim_acc(dcim_acc),
        .dcim_accumulate_type(dcim_accumulate_type),
        .ibuf_ena(ibuf_ena),
        .ibuf_wea(ibuf_wea),
        .ibuf_addra(ibuf_addra),
        .ibuf_dina(ibuf_dina),
        .ibuf_douta(ibuf_douta),
        .obuf_ena(obuf_ena),
        .obuf_wea(obuf_wea),
        .obuf_addra(obuf_addra),
        .obuf_dina(obuf_dina),
        .obuf_douta(obuf_douta)
    );

    always #5 clk = ~clk;

    function automatic [7:0] gen_weight_byte(input int kt, input int r, input int c);
        int v;
        begin
            v = (kt * 37 + r * 11 + c * 7 + 19) & 8'hFF;
            gen_weight_byte = v[7:0];
        end
    endfunction

    function automatic [7:0] gen_act_byte(input int kt, input int r, input int c);
        int v;
        begin
            v = (kt * 53 + r * 5 + c * 13 + 3) & 8'hFF;
            gen_act_byte = v[7:0];
        end
    endfunction

    function automatic integer signed signext_bits(input longint signed value, input int width);
        longint signed mask;
        longint signed tmp;
        begin
            mask = (64'sd1 << width) - 1;
            tmp = value & mask;
            if (tmp[width-1]) begin
                tmp = tmp - (64'sd1 << width);
            end
            signext_bits = tmp;
        end
    endfunction

    // The INT8 datapath ultimately produces one signed result per original
    // 8-bit output column. The hardware splits 8-bit values into 4-bit nibbles,
    // computes partial products, and merges them. The final result is sign-extended
    // to 2*WD3 bits per output column.
    //
    // Hardware computation for INT8:
    // 1. Split activation byte into hi (signed) and lo (unsigned) nibbles
    // 2. Split weight byte into hi (signed) and lo (unsigned) nibbles  
    // 3. Compute 4 partial products per channel, sum across 16 channels
    // 4. Merge: result = (hi_result << 4) + lo_result for each nibble pair
    // 5. Final merge combines weight hi/lo results
    //
    // The mathematical result equals: sum(act[ch] * weight[ch][col]) for ch=0..15
    // but with specific bit-width handling through the pipeline.
    function automatic [BRAM_WIDTH-1:0] golden_int8_row_word(input int kt, input int row);
        logic [BRAM_WIDTH-1:0] out_word;
        longint signed dot;
        integer signed act_v;
        integer signed w_v;
        logic signed [INT8_PACK_W-1:0] packed_col;
        begin
            out_word = '0;
            for (int col = 0; col < INT8_COLS; col++) begin
                dot = 0;
                for (int ch = 0; ch < 16; ch++) begin
                    // Standard signed 8-bit multiplication
                    act_v = $signed(8'(gen_act_byte(kt, row, ch)));
                    w_v = $signed(8'(gen_weight_byte(kt, ch, col)));
                    dot += act_v * w_v;
                end
                // The hardware pipeline preserves the full precision through merge,
                // then sign-extends to 2*WD3 bits. We truncate to INT8_PACK_W bits.
                packed_col = dot[INT8_PACK_W-1:0];
                out_word[col*INT8_PACK_W +: INT8_PACK_W] = packed_col;
            end
            golden_int8_row_word = out_word;
        end
    endfunction

    function automatic [BRAM_WIDTH-1:0] lane_merge_add(
        input [BRAM_WIDTH-1:0] lhs_word,
        input [BRAM_WIDTH-1:0] rhs_word
    );
        logic [BRAM_WIDTH-1:0] out_word;
        logic signed [WD3-1:0] lhs_lane;
        logic signed [WD3-1:0] rhs_lane;
        logic signed [WD3:0] sum_lane_ext;
        begin
            out_word = '0;
            for (int ch = 0; ch < CH_OUT; ch++) begin
                lhs_lane = lhs_word[ch*WD3 +: WD3];
                rhs_lane = rhs_word[ch*WD3 +: WD3];
                sum_lane_ext = lhs_lane + rhs_lane;
                out_word[ch*WD3 +: WD3] = sum_lane_ext[WD3-1:0];
            end
            lane_merge_add = out_word;
        end
    endfunction

    task automatic clear_host_ports;
        begin
            ibuf_ena   = 1'b0;
            ibuf_wea   = '0;
            ibuf_addra = '0;
            ibuf_dina  = '0;
            obuf_ena   = 1'b0;
            obuf_wea   = '0;
            obuf_addra = '0;
            obuf_dina  = '0;
        end
    endtask

    task automatic ibuf_write_word(input int word_index, input [BRAM_WIDTH-1:0] data_word);
        begin
            @(posedge clk);
            ibuf_ena   <= 1'b1;
            ibuf_wea   <= {BRAM_BYTES{1'b1}};
            ibuf_addra <= word_index * BRAM_BYTES;
            ibuf_dina  <= data_word;
            @(posedge clk);
            ibuf_ena   <= 1'b0;
            ibuf_wea   <= '0;
            ibuf_addra <= '0;
            ibuf_dina  <= '0;
        end
    endtask

    task automatic obuf_write_word(input int word_index, input [BRAM_WIDTH-1:0] data_word);
        begin
            @(posedge clk);
            obuf_ena   <= 1'b1;
            obuf_wea   <= {BRAM_BYTES{1'b1}};
            obuf_addra <= word_index * BRAM_BYTES;
            obuf_dina  <= data_word;
            @(posedge clk);
            obuf_ena   <= 1'b0;
            obuf_wea   <= '0;
            obuf_addra <= '0;
            obuf_dina  <= '0;
        end
    endtask

    task automatic obuf_read_word(input int word_index, output [BRAM_WIDTH-1:0] data_word);
        begin
            @(posedge clk);
            obuf_ena   <= 1'b1;
            obuf_wea   <= '0;
            obuf_addra <= word_index * BRAM_BYTES;
            @(posedge clk);
            @(posedge clk);
            data_word = obuf_douta;
            obuf_ena   <= 1'b0;
            obuf_addra <= '0;
        end
    endtask

    task automatic load_weight_tile(input int kt);
        logic [BRAM_WIDTH-1:0] wword;
        int idx;
        int r;
        int c;
        int write_addr;
        int byte_in_word;
        begin
            wword = '0;
            idx = 0;
            for (r = 0; r < 16; r++) begin
                for (c = 0; c < 8; c++) begin
                    byte_in_word = idx % BRAM_BYTES;
                    wword[8*byte_in_word +: 8] = gen_weight_byte(kt, r, c);
                    idx++;
                    if ((idx % BRAM_BYTES) == 0) begin
                        write_addr = (W_BASE_BYTE / BRAM_BYTES) + (idx / BRAM_BYTES) - 1;
                        ibuf_write_word(write_addr, wword);
                        wword = '0;
                    end
                end
            end
        end
    endtask

    task automatic load_activation_tile(input int kt);
        logic [BRAM_WIDTH-1:0] aword;
        int row;
        int col;
        int base_word;
        begin
            base_word = A_BASE_BYTE / BRAM_BYTES;
            for (row = 0; row < M_ROWS; row += 2) begin
                aword = '0;
                for (col = 0; col < 16; col++) begin
                    aword[8*col +: 8] = gen_act_byte(kt, row, col);
                end
                for (col = 0; col < 16; col++) begin
                    if (row + 1 < M_ROWS) begin
                        aword[128 + 8*col +: 8] = gen_act_byte(kt, row + 1, col);
                    end
                end
                ibuf_write_word(base_word + (row / 2), aword);
            end
        end
    endtask

    task automatic clear_obuf_region(input int dst_byte, input int words);
        int base_word;
        begin
            base_word = dst_byte / BRAM_BYTES;
            for (int i = 0; i < words; i++) begin
                obuf_write_word(base_word + i, '0);
            end
        end
    endtask

    task automatic run_one_tile(input int dst_byte, input [1:0] accum_type, input string tag);
        int timeout;
        begin
            @(posedge clk);
            dcim_wsrc_base_addr  <= W_BASE_BYTE;
            dcim_asrc_base_addr  <= A_BASE_BYTE;
            dcim_dst_addr        <= dst_byte;
            dcim_raw_rows        <= M_ROWS;
            dcim_mode            <= MODE_INT8[2:0];
            dcim_acc             <= 5'd0;
            dcim_accumulate_type <= accum_type;
            dcim_config_valid    <= 1'b1;
            @(posedge clk);
            dcim_config_valid    <= 1'b0;

            @(posedge clk);
            dcim_start <= 1'b1;
            @(posedge clk);
            dcim_start <= 1'b0;

            timeout = 0;
            while (!dcim_done) begin
                @(posedge clk);
                timeout++;
                if (dcim_error) begin
                    $fatal(1, "[%0s] dcim_error asserted, code=0x%08x", tag, dcim_error_code);
                end
                if (timeout > 200000) begin
                    $fatal(1, "[%0s] timeout waiting dcim_done", tag);
                end
            end

            // Clear done by issuing a new start pulse in DONE state.
            @(posedge clk);
            dcim_start <= 1'b1;
            @(posedge clk);
            dcim_start <= 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        dcim_start = 1'b0;
        dcim_config_valid = 1'b0;
        dcim_wsrc_base_addr = '0;
        dcim_asrc_base_addr = '0;
        dcim_dst_addr = '0;
        dcim_raw_rows = '0;
        dcim_mode = MODE_INT8[2:0];
        dcim_acc = 5'd0;
        dcim_accumulate_type = 2'd0;
        clear_host_ports();

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        $display("[TB] Step-1: collect per-K reference outputs");
        for (int kt = 0; kt < K_TILES; kt++) begin
            int ref_dst;
            ref_dst = DST_REF0 + kt * DST_STRIDE;
            clear_obuf_region(ref_dst, OUT_WORDS);
            load_weight_tile(kt);
            load_activation_tile(kt);
            run_one_tile(ref_dst, 2'd0, $sformatf("ref_k%0d", kt));
            for (int row = 0; row < OUT_WORDS; row++) begin
                obuf_read_word((ref_dst / BRAM_BYTES) + row, ref_words[kt][row]);
            end

            for (int row = 0; row < OUT_WORDS; row++) begin
                golden_words[kt][row] = golden_int8_row_word(kt, row);
                if (ref_words[kt][row] !== golden_words[kt][row]) begin
                    $display("[TB][ERR] single-tile mismatch kt=%0d row=%0d", kt, row);
                    $display("          got=%h", ref_words[kt][row]);
                    $display("          exp=%h", golden_words[kt][row]);
                    $fatal(1, "independent INT8 golden mismatch");
                end
            end
        end

        $display("[TB] Step-2: run K-tiling accumulation on a single C tile");
        clear_obuf_region(DST_ACC, OUT_WORDS);
        for (int kt = 0; kt < K_TILES; kt++) begin
            load_weight_tile(kt);
            load_activation_tile(kt);
            run_one_tile(DST_ACC, (kt == 0) ? 2'd0 : 2'd1, $sformatf("acc_k%0d", kt));
        end
        for (int row = 0; row < OUT_WORDS; row++) begin
            obuf_read_word((DST_ACC / BRAM_BYTES) + row, accum_words[row]);
        end

        $display("[TB] Step-3: compare against lane-wise sum of references");
        for (int row = 0; row < OUT_WORDS; row++) begin
            logic [BRAM_WIDTH-1:0] row_sum;
            row_sum = '0;
            for (int kt = 0; kt < K_TILES; kt++) begin
                row_sum = lane_merge_add(row_sum, golden_words[kt][row]);
            end
            expected_words[row] = row_sum;
            if (accum_words[row] !== expected_words[row]) begin
                $display("[TB][ERR] accumulate mismatch row=%0d", row);
                $display("          got=%h", accum_words[row]);
                $display("          exp=%h", expected_words[row]);
                $fatal(1, "large-GEMM accumulate test failed");
            end
        end

        $display("[TB][PASS] PE supports multi-pass accumulation for large tiled GEMM.");
        #100;
        $finish;
    end
endmodule
