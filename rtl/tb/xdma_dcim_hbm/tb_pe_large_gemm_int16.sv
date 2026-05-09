`timescale 1ns / 1ps
`include "dcim_defs.vh"

module tb_pe_large_gemm_int16;
    localparam int BRAM_BYTES = `DCIM_BRAM_BYTES;
    localparam int BRAM_WIDTH = `DCIM_BRAM_DATA_WIDTH;
    localparam int WD3        = `DCIM_WD3;
    localparam int CH_OUT     = `DCIM_CH_OUT;
    localparam int MODE_INT16 = `DCIM_MODE_INT16;
    localparam int INT16_COLS = (`DCIM_CH_OUT / 4);
    localparam int INT16_PACK_W = 4 * WD3;
    localparam int WD2 = `DCIM_WD2;
    localparam int WD1 = `DCIM_WD1;
    localparam int M_ROWS     = 64;
    localparam int K_TILES    = 4;
    localparam int W_BASE_BYTE = 32'h0000;
    localparam int A_BASE_BYTE = 32'h1000;
    localparam int DST_ACC     = 32'h0000;
    localparam int DST_REF0    = 32'h2000;
    localparam int DST_STRIDE  = 32'h0800;
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

    logic [BRAM_WIDTH-1:0] ref_words [0:K_TILES-1][0:OUT_WORDS-1];
    logic [BRAM_WIDTH-1:0] accum_words [0:OUT_WORDS-1];
    logic [BRAM_WIDTH-1:0] expected_words [0:OUT_WORDS-1];
    logic [BRAM_WIDTH-1:0] golden_words [0:K_TILES-1][0:OUT_WORDS-1];

    function automatic [15:0] gen_weight_halfword(input int kt, input int r, input int c);
        int signed v;
        begin
            v = (kt*127 + r*53 + c*29 + 17) % 32768;
            if ((r + c + kt) & 1) v = -v;
            gen_weight_halfword = v[15:0];
        end
    endfunction

    function automatic [15:0] gen_act_halfword(input int kt, input int r, input int c);
        int signed v;
        begin
            v = (kt*211 + r*37 + c*13 + 5) % 32768;
            if ((r + c + kt) & 1) v = -v;
            gen_act_halfword = v[15:0];
        end
    endfunction

    function automatic longint signed signext_bits(input longint signed value, input int width);
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

    // The INT16 path reduces each original 16-bit output column into one signed
    // merged value, then sign-extends it into a 64-bit chunk in OBUF.
    // Hardware splits 16-bit values into 4 nibbles, computes across 4 cycles,
    // and merges the results. The final output is 4*WD3 = 64 bits per column.
    function automatic [BRAM_WIDTH-1:0] golden_int16_row_word(input int kt, input int row);
        logic [BRAM_WIDTH-1:0] out_word;
        longint signed dot;
        integer signed act_v;
        integer signed w_v;
        logic signed [INT16_PACK_W-1:0] packed_col;
        begin
            out_word = '0;
            for (int col = 0; col < INT16_COLS; col++) begin
                dot = 0;
                for (int ch = 0; ch < 16; ch++) begin
                    act_v = $signed(16'(gen_act_halfword(kt, row, ch)));
                    w_v = $signed(16'(gen_weight_halfword(kt, ch, col)));
                    dot += act_v * w_v;
                end
                // Truncate to INT16_PACK_W bits (64 bits)
                packed_col = dot[INT16_PACK_W-1:0];
                out_word[col*INT16_PACK_W +: INT16_PACK_W] = packed_col;
            end
            golden_int16_row_word = out_word;
        end
    endfunction

    function automatic [BRAM_WIDTH-1:0] lane_merge_add(input [BRAM_WIDTH-1:0] lhs_word, input [BRAM_WIDTH-1:0] rhs_word);
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
            ibuf_ena = 1'b0;
            ibuf_wea = '0;
            ibuf_addra = '0;
            ibuf_dina = '0;
            obuf_ena = 1'b0;
            obuf_wea = '0;
            obuf_addra = '0;
            obuf_dina = '0;
        end
    endtask

    task automatic ibuf_write_word(input int word_index, input [BRAM_WIDTH-1:0] data_word);
        begin
            @(posedge clk);
            ibuf_ena <= 1'b1;
            ibuf_wea <= {BRAM_BYTES{1'b1}};
            ibuf_addra <= word_index * BRAM_BYTES;
            ibuf_dina <= data_word;
            @(posedge clk);
            ibuf_ena <= 1'b0;
            ibuf_wea <= '0;
            ibuf_addra <= '0;
            ibuf_dina <= '0;
        end
    endtask

    task automatic obuf_write_word(input int word_index, input [BRAM_WIDTH-1:0] data_word);
        begin
            @(posedge clk);
            obuf_ena <= 1'b1;
            obuf_wea <= {BRAM_BYTES{1'b1}};
            obuf_addra <= word_index * BRAM_BYTES;
            obuf_dina <= data_word;
            @(posedge clk);
            obuf_ena <= 1'b0;
            obuf_wea <= '0;
            obuf_addra <= '0;
            obuf_dina <= '0;
        end
    endtask

    task automatic obuf_read_word(input int word_index, output [BRAM_WIDTH-1:0] data_word);
        begin
            @(posedge clk);
            obuf_ena <= 1'b1;
            obuf_wea <= '0;
            obuf_addra <= word_index * BRAM_BYTES;
            @(posedge clk);
            @(posedge clk);
            data_word = obuf_douta;
            obuf_ena <= 1'b0;
            obuf_addra <= '0;
        end
    endtask

    task automatic load_weight_tile(input int kt);
        logic [BRAM_WIDTH-1:0] wword;
        int idx;
        int r;
        int c;
        int halfword_in_word;
        begin
            wword = '0;
            idx = 0;
            for (r = 0; r < 16; r++) begin
                for (c = 0; c < 4; c++) begin
                    halfword_in_word = idx % (BRAM_BYTES/2);
                    wword[16*halfword_in_word +: 16] = gen_weight_halfword(kt, r, c);
                    idx++;
                    if ((idx % (BRAM_BYTES/2)) == 0) begin
                        ibuf_write_word((W_BASE_BYTE / BRAM_BYTES) + (idx / (BRAM_BYTES/2)) - 1, wword);
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
            for (row = 0; row < M_ROWS; row++) begin
                aword = '0;
                for (col = 0; col < 16; col++) begin
                    aword[16*col +: 16] = gen_act_halfword(kt, row, col);
                end
                ibuf_write_word(base_word + row, aword);
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
            dcim_wsrc_base_addr <= W_BASE_BYTE;
            dcim_asrc_base_addr <= A_BASE_BYTE;
            dcim_dst_addr <= dst_byte;
            dcim_raw_rows <= M_ROWS;
            dcim_mode <= MODE_INT16[2:0];
            dcim_acc <= 5'd0;
            dcim_accumulate_type <= accum_type;
            dcim_config_valid <= 1'b1;
            @(posedge clk);
            dcim_config_valid <= 1'b0;
            @(posedge clk);
            dcim_start <= 1'b1;
            @(posedge clk);
            dcim_start <= 1'b0;

            timeout = 0;
            while (!dcim_done) begin
                @(posedge clk);
                timeout++;
                if (dcim_error) begin
                    $fatal(1, "[%0s] dcim_error code=0x%08x", tag, dcim_error_code);
                end
                if (timeout > 400000) begin
                    $fatal(1, "[%0s] timeout waiting done", tag);
                end
            end
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
        dcim_mode = MODE_INT16[2:0];
        dcim_acc = 5'd0;
        dcim_accumulate_type = 2'd0;
        clear_host_ports();

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        $display("[TB-INT16] Step-1: collect per-K reference outputs");
        for (int kt = 0; kt < K_TILES; kt++) begin
            int ref_dst;
            ref_dst = DST_REF0 + kt * DST_STRIDE;
            clear_obuf_region(ref_dst, OUT_WORDS);
            load_weight_tile(kt);
            load_activation_tile(kt);
            run_one_tile(ref_dst, 2'd0, $sformatf("ref16_k%0d", kt));
            for (int row = 0; row < OUT_WORDS; row++) begin
                obuf_read_word((ref_dst / BRAM_BYTES) + row, ref_words[kt][row]);
            end

            for (int row = 0; row < OUT_WORDS; row++) begin
                golden_words[kt][row] = golden_int16_row_word(kt, row);
                if (ref_words[kt][row] !== golden_words[kt][row]) begin
                    $display("[TB-INT16][ERR] single-tile mismatch kt=%0d row=%0d", kt, row);
                    $display("                 got=%h", ref_words[kt][row]);
                    $display("                 exp=%h", golden_words[kt][row]);
                    $fatal(1, "independent INT16 golden mismatch");
                end
            end
        end

        $display("[TB-INT16] Step-2: run K-tiling accumulation");
        clear_obuf_region(DST_ACC, OUT_WORDS);
        for (int kt = 0; kt < K_TILES; kt++) begin
            load_weight_tile(kt);
            load_activation_tile(kt);
            run_one_tile(DST_ACC, (kt == 0) ? 2'd0 : 2'd1, $sformatf("acc16_k%0d", kt));
        end
        for (int row = 0; row < OUT_WORDS; row++) begin
            obuf_read_word((DST_ACC / BRAM_BYTES) + row, accum_words[row]);
        end

        $display("[TB-INT16] Step-3: compare with sum(ref tiles)");
        for (int row = 0; row < OUT_WORDS; row++) begin
            logic [BRAM_WIDTH-1:0] row_sum;
            row_sum = '0;
            for (int kt = 0; kt < K_TILES; kt++) begin
                row_sum = lane_merge_add(row_sum, golden_words[kt][row]);
            end
            expected_words[row] = row_sum;
            if (accum_words[row] !== expected_words[row]) begin
                $display("[TB-INT16][ERR] row=%0d got=%h exp=%h", row, accum_words[row], expected_words[row]);
                $fatal(1, "int16 accumulation consistency failed");
            end
        end
        $display("[TB-INT16][PASS] int16 tiled accumulation path works.");
        #100;
        $finish;
    end
endmodule
