`timescale 1ns / 1ps
`include "../../ref/DCIM/src/inc/para.v"

// ============================================================================
// tb_DCIM_Array - 多 Tile 测试平台
// ============================================================================
// NUM_TILES 可配置（默认 8）：各 Tile 独立权重基址与输出区，共享激活。
// Test 8–13：ONNX shape_inference 全分辨率 M×W×H；num_rows=M×acc(im2col)；RTL num_rows 已扩至 32 位，BUF 地址 19 位。
// ============================================================================

module tb_DCIM_Array;

    localparam NUM_TILES    = 8;
    localparam WD1          = 4;
    localparam CH_IN        = 16;
    localparam CH_OUT       = 16;
    localparam SRAM_DP      = 128;
    localparam CYCLE        = 8;
    localparam ACC          = 80;
    // 与 ONNX 全分辨率一致：最大 num_rows = 160×160×7 = 179200（model.0 im2col）
    localparam DUT_BUF_AW     = 19;
    localparam BUF_ADDR_WIDTH = DUT_BUF_AW;
    localparam BUF_DATA_WIDTH = 128;
    localparam SRAM_WD      = CH_IN * CH_OUT * WD1 / CYCLE;
    localparam WD2          = 2 * WD1 + $clog2(CH_IN);
    localparam WD3          = WD2 + $clog2(ACC);
    localparam ACC_UBD_WD   = $clog2(ACC + 1);
    localparam T            = 10;

    // IBUF：Tile t 权重占用 [t*CYCLE, (t+1)*CYCLE)；激活在 ACT_BASE 起
    localparam ACT_BASE     = NUM_TILES * CYCLE + 32;
    // OBUF：每 Tile 最大约 25600×2 字；65536 间隔避免 19 位地址重叠
    localparam [BUF_ADDR_WIDTH-1:0] OUT_STRIDE = BUF_ADDR_WIDTH'(19'h10000);

    reg clk, rst_n, start;
    wire done, ready;
    reg [2:0] mode;
    reg [ACC_UBD_WD-1:0] acc_depth;
    reg [31:0] num_rows;
    reg [BUF_ADDR_WIDTH-1:0] act_base_addr;
    reg [NUM_TILES*BUF_ADDR_WIDTH-1:0] wei_base_addrs;
    reg [NUM_TILES*BUF_ADDR_WIDTH-1:0] out_base_addrs;

    reg  [BUF_DATA_WIDTH/8-1:0] ibuf_ext_wea;
    reg                         ibuf_ext_ena;
    reg  [BUF_ADDR_WIDTH-1:0]   ibuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]   ibuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]   ibuf_ext_douta;

    reg  [BUF_DATA_WIDTH/8-1:0] obuf_ext_wea;
    reg                         obuf_ext_ena;
    reg  [BUF_ADDR_WIDTH-1:0]   obuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]   obuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]   obuf_ext_douta;

    localparam integer MAX_ACT_ROWS    = 200000;
    localparam integer MAX_OUT_GROUPS  = 28000;

    reg signed [15:0] activation[0:MAX_ACT_ROWS-1][0:CH_IN-1];
    reg signed [31:0] golden[0:NUM_TILES-1][0:MAX_OUT_GROUPS-1][0:7];
    reg signed [3:0] weight_nibble[0:NUM_TILES-1][0:CH_IN-1][0:CH_OUT-1];

    integer total_errors, total_tests, passed_tests;
    integer seed;

    initial clk = 0;
    always #(T / 2) clk = ~clk;

    DCIM_Array #(
        .NUM_TILES(NUM_TILES),
        .WD1(WD1),
        .CH_IN(CH_IN),
        .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP),
        .CYCLE(CYCLE),
        .ACC(ACC),
        .BUF_ADDR_WIDTH(BUF_ADDR_WIDTH),
        .BUF_DATA_WIDTH(BUF_DATA_WIDTH),
        .IBUF_RD_LATENCY(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .ready(ready),
        .mode(mode),
        .acc_depth(acc_depth),
        .num_rows(num_rows),
        .act_base_addr(act_base_addr),
        .wei_base_addrs(wei_base_addrs),
        .out_base_addrs(out_base_addrs),
        .ibuf_ext_wea(ibuf_ext_wea),
        .ibuf_ext_ena(ibuf_ext_ena),
        .ibuf_ext_addra(ibuf_ext_addra),
        .ibuf_ext_dina(ibuf_ext_dina),
        .ibuf_ext_douta(ibuf_ext_douta),
        .obuf_ext_wea(obuf_ext_wea),
        .obuf_ext_ena(obuf_ext_ena),
        .obuf_ext_addra(obuf_ext_addra),
        .obuf_ext_dina(obuf_ext_dina),
        .obuf_ext_douta(obuf_ext_douta)
    );

    task write_ibuf(input [BUF_ADDR_WIDTH-1:0] addr, input [BUF_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            ibuf_ext_ena   <= 1'b1;
            ibuf_ext_wea   <= {(BUF_DATA_WIDTH / 8) {1'b1}};
            ibuf_ext_addra <= addr;
            ibuf_ext_dina  <= data;
            @(posedge clk);
            ibuf_ext_ena <= 1'b0;
            ibuf_ext_wea <= '0;
        end
    endtask

    task read_obuf(input [BUF_ADDR_WIDTH-1:0] addr, output [BUF_DATA_WIDTH-1:0] data);
        begin
            @(posedge clk);
            obuf_ext_ena   <= 1'b1;
            obuf_ext_wea   <= '0;
            obuf_ext_addra <= addr;
            repeat (5) @(posedge clk);
            data = obuf_ext_douta;
            obuf_ext_ena <= 1'b0;
        end
    endtask

    task set_default_tile_bases;
        integer t;
        begin
            for (t = 0; t < NUM_TILES; t = t + 1) begin
                wei_base_addrs[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = BUF_ADDR_WIDTH'(CYCLE * t);
                out_base_addrs[t*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH] = BUF_ADDR_WIDTH'(OUT_STRIDE * t);
            end
        end
    endtask

    task generate_weights(input integer tile_id, input integer pattern);
        integer i, j;
        begin
            for (i = 0; i < CH_IN; i = i + 1) begin
                for (j = 0; j < CH_OUT; j = j + 1) begin
                    case (pattern)
                        0: weight_nibble[tile_id][i][j] = 4'sd1;
                        1: weight_nibble[tile_id][i][j] = ((i + j + tile_id) % 15) - 7;
                        2: weight_nibble[tile_id][i][j] = $random(seed) % 15 - 7;
                        3: weight_nibble[tile_id][i][j] = (tile_id + i + j) % 2 ? 4'sd3 : -4'sd4;
                        default: weight_nibble[tile_id][i][j] = 4'sd1;
                    endcase
                end
            end
        end
    endtask

    task load_weights(input integer tile_id, input [BUF_ADDR_WIDTH-1:0] base);
        integer addr, bit_idx, nibble_idx, in_ch, out_ch;
        reg [SRAM_WD-1:0] sram_word;
        begin
            for (addr = 0; addr < CYCLE; addr = addr + 1) begin
                sram_word = '0;
                for (bit_idx = 0; bit_idx < SRAM_WD; bit_idx = bit_idx + WD1) begin
                    nibble_idx = addr * (SRAM_WD / WD1) + bit_idx / WD1;
                    out_ch     = nibble_idx / CH_IN;
                    in_ch      = nibble_idx % CH_IN;
                    if (in_ch < CH_IN && out_ch < CH_OUT)
                        sram_word[bit_idx +: WD1] = weight_nibble[tile_id][in_ch][out_ch];
                end
                write_ibuf(base + addr, sram_word);
            end
        end
    endtask

    task generate_activations(input integer pattern, input integer rows);
        integer row, ch;
        begin
            for (row = 0; row < rows; row = row + 1) begin
                for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                    case (pattern)
                        0: activation[row][ch] = row + 1;
                        1: activation[row][ch] = $random(seed) % 256 - 128;
                        2: activation[row][ch] = ((row + ch) % 2) ? 100 : -100;
                        default: activation[row][ch] = row + 1;
                    endcase
                end
            end
        end
    endtask

    task load_activations(input [BUF_ADDR_WIDTH-1:0] base, input integer rows);
        integer row, ch;
        reg [BUF_DATA_WIDTH-1:0] act_word;
        begin
            for (row = 0; row < rows; row = row + 1) begin
                act_word = '0;
                for (ch = 0; ch < CH_IN; ch = ch + 1)
                    act_word[ch*8 +: 8] = activation[row][ch][7:0];
                write_ibuf(base + row, act_word);
            end
        end
    endtask

    // im2col：每个输出组占 t_acc 行激活；线性 K 下标 = (row % t_acc)*CH_IN + ch
    // 当 K_raw 不整除 16*t_acc 时，将 K_raw..ceil16-1 对应位置置 0（与硬件 acc_depth 对齐）
    task zero_pad_im2col_k(input integer rows, input integer t_acc, input integer k_raw);
        integer row, ch, row_in_g, linear_k, k_eff;
        begin
            if (t_acc > 0) begin
                k_eff = (k_raw <= 0) ? (t_acc * CH_IN) : k_raw;
                if (k_eff > t_acc * CH_IN) k_eff = t_acc * CH_IN;
                for (row = 0; row < rows; row = row + 1) begin
                    row_in_g = row % t_acc;
                    for (ch = 0; ch < CH_IN; ch = ch + 1) begin
                        linear_k = row_in_g * CH_IN + ch;
                        if (linear_k >= k_eff)
                            activation[row][ch] = 0;
                    end
                end
            end
        end
    endtask

    task compute_golden(input integer tile_id, input integer rows, input integer t_acc);
        integer row, out_ch, in_ch, acc_group, row_in_group;
        integer phys_ch_lo, phys_ch_hi;
        integer num_acc_groups, acc_val;
        reg signed [63:0] sum;
        reg signed [7:0] w8, a8;
        reg signed [WD3-1:0] wd3_result;
        begin
            acc_val         = (t_acc == 0) ? 1 : t_acc;
            num_acc_groups  = rows / acc_val;
            for (row = 0; row < MAX_OUT_GROUPS; row = row + 1)
                for (out_ch = 0; out_ch < 8; out_ch = out_ch + 1)
                    golden[tile_id][row][out_ch] = 0;

            for (acc_group = 0; acc_group < num_acc_groups; acc_group = acc_group + 1) begin
                for (out_ch = 0; out_ch < 8; out_ch = out_ch + 1) begin
                    sum = 0;
                    for (row_in_group = 0; row_in_group < acc_val; row_in_group = row_in_group + 1) begin
                        row = acc_group * acc_val + row_in_group;
                        for (in_ch = 0; in_ch < CH_IN; in_ch = in_ch + 1) begin
                            phys_ch_lo = out_ch * 2 + 2;
                            phys_ch_hi = out_ch * 2 + 3;
                            if (phys_ch_lo >= CH_OUT) phys_ch_lo = CH_OUT - 2;
                            if (phys_ch_hi >= CH_OUT) phys_ch_hi = CH_OUT - 1;
                            w8 = {weight_nibble[tile_id][in_ch][phys_ch_hi], weight_nibble[tile_id][in_ch][phys_ch_lo]};
                            a8 = activation[row][in_ch][7:0];
                            sum = sum + ($signed(a8) * $signed(w8));
                        end
                    end
                    wd3_result = sum[WD3-1:0];
                    golden[tile_id][acc_group][out_ch] = {{(32 - WD3) {wd3_result[WD3-1]}}, wd3_result};
                end
            end
        end
    endtask

    task verify_tile(input integer tile_id, input [BUF_ADDR_WIDTH-1:0] out_base,
                     input integer rows, input integer t_acc, output integer errors);
        integer row, ch, num_outputs, acc_val;
        reg [BUF_DATA_WIDTH-1:0] result_lo, result_hi;
        reg signed [31:0] dut_val, exp_val;
        begin
            errors     = 0;
            acc_val    = (t_acc == 0) ? 1 : t_acc;
            num_outputs = rows / acc_val;

            for (row = 0; row < num_outputs; row = row + 1) begin
                read_obuf(out_base + row * 2, result_lo);
                read_obuf(out_base + row * 2 + 1, result_hi);
                for (ch = 0; ch < 4; ch = ch + 1) begin
                    dut_val = $signed(result_lo[ch*32 +: 32]);
                    exp_val = golden[tile_id][row][ch];
                    if (dut_val !== exp_val) begin
                        errors = errors + 1;
                        if (errors <= 3)
                            $display("  [ERR] Tile%0d Row%0d Ch%0d: DUT=%0d, Golden=%0d",
                                     tile_id, row, ch, dut_val, exp_val);
                    end
                    dut_val = $signed(result_hi[ch*32 +: 32]);
                    exp_val = golden[tile_id][row][ch+4];
                    if (dut_val !== exp_val) begin
                        errors = errors + 1;
                        if (errors <= 3)
                            $display("  [ERR] Tile%0d Row%0d Ch%0d: DUT=%0d, Golden=%0d",
                                     tile_id, row, ch + 4, dut_val, exp_val);
                    end
                end
            end
        end
    endtask

    // 超时以「×100000 个时钟周期」计，避免 repeat 字面量超过 32 位有符号范围
    task pulse_start_and_wait_done(input integer loops_100k);
        integer idx;
        begin
            @(posedge clk);
            start <= 1'b1;
            @(posedge clk);
            start <= 1'b0;
            wait (!done);
            fork
                begin
                    wait (done);
                end
                begin
                    for (idx = 0; idx < loops_100k; idx = idx + 1)
                        repeat (100000) @(posedge clk);
                    $display("  [TIMEOUT] loops_100k=%0d (~%0d cycles)", loops_100k, loops_100k * 100000);
                end
            join_any
            disable fork;
            repeat (20) @(posedge clk);
        end
    endtask

    task verify_all_tiles(input integer rows, input integer t_acc, output integer sum_err);
        integer ti, e;
        begin
            sum_err = 0;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                verify_tile(ti, out_base_addrs[ti*BUF_ADDR_WIDTH +: BUF_ADDR_WIDTH], rows, t_acc, e);
                sum_err = sum_err + e;
                if (e == 0)
                    $display("  Tile %0d: PASSED", ti);
                else
                    $display("  Tile %0d: FAILED (%0d errors)", ti, e);
            end
        end
    endtask

    integer errors_per_tile;
    integer errs_before;

    initial begin
        rst_n = 0;
        start = 0;
        mode           = `MODE_INT8;
        acc_depth      = 0;
        num_rows       = 8;
        act_base_addr  = ACT_BASE;
        wei_base_addrs = '0;
        out_base_addrs = '0;
        ibuf_ext_ena   = 0;
        ibuf_ext_wea   = '0;
        ibuf_ext_addra = '0;
        ibuf_ext_dina  = '0;
        obuf_ext_ena   = 0;
        obuf_ext_wea   = '0;
        obuf_ext_addra = '0;
        obuf_ext_dina  = '0;
        total_errors   = 0;
        total_tests    = 0;
        passed_tests   = 0;
        seed           = 12345;

        repeat (10) @(posedge clk);
        rst_n = 1;
        repeat (10) @(posedge clk);

        $display("");
        $display("╔═══════════════════════════════════════════════════════════════╗");
        $display("║       DCIM_Array Multi-Tile Test (%0d Tiles)                  ║", NUM_TILES);
        $display("╚═══════════════════════════════════════════════════════════════╝");

        // ------------------------------------------------------------------
        // Test 1: INT8 ACC=0, 8 rows, 各 Tile 不同权重模板，共享激活
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 1: INT8 ACC=0, 8 rows, %0d tiles, distinct weight patterns", NUM_TILES);
        $display("─────────────────────────────────────────────────────────────");

        seed = 11111;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                generate_weights(ti, ti % 4);
        end
        generate_activations(0, 8);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 8);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 8, 0);
        end

        wait (ready);
        mode          = `MODE_INT8;
        acc_depth     = 0;
        num_rows      = 8;
        act_base_addr = ACT_BASE;
        pulse_start_and_wait_done(200);
        verify_all_tiles(8, 0, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 2: INT8 ACC=2, 随机
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 2: INT8 ACC=2, 8 rows, random weights / activations");
        $display("─────────────────────────────────────────────────────────────");

        seed = 22222;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 10000 * ti + 33333;
                generate_weights(ti, 2);
            end
        end
        seed = 44444;
        generate_activations(1, 8);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 8);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 8, 2);
        end

        wait (ready);
        mode      = `MODE_INT8;
        acc_depth = 2;
        num_rows  = 8;
        pulse_start_and_wait_done(200);
        verify_all_tiles(8, 2, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 3: INT8 ACC=4, 8 rows
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 3: INT8 ACC=4, 8 rows");
        $display("─────────────────────────────────────────────────────────────");

        seed = 55555;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 7777 * ti + 88888;
                generate_weights(ti, 2);
            end
        end
        seed = 99999;
        generate_activations(2, 8);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 8);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 8, 4);
        end

        wait (ready);
        acc_depth = 4;
        num_rows  = 8;
        pulse_start_and_wait_done(200);
        verify_all_tiles(8, 4, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 4: INT8 ACC=8, 8 rows（单行无累加输出 1 组）
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 4: INT8 ACC=8, 8 rows (1 output group per tile)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 121212;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 5000 * ti + 131313;
                generate_weights(ti, 1);
            end
        end
        generate_activations(0, 8);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 8);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 8, 8);
        end

        wait (ready);
        acc_depth = 8;
        num_rows  = 8;
        pulse_start_and_wait_done(200);
        verify_all_tiles(8, 8, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 5: INT8 ACC=4, 16 rows
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 5: INT8 ACC=4, 16 rows");
        $display("─────────────────────────────────────────────────────────────");

        seed = 202020;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 9000 * ti + 212121;
                generate_weights(ti, 2);
            end
        end
        seed = 303030;
        generate_activations(1, 16);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 16);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 16, 4);
        end

        wait (ready);
        acc_depth = 4;
        num_rows  = 16;
        pulse_start_and_wait_done(200);
        verify_all_tiles(16, 4, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 6: INT8 ACC=1, 8 rows（显式深度 1）
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 6: INT8 ACC=1, 8 rows");
        $display("─────────────────────────────────────────────────────────────");

        seed = 414141;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                generate_weights(ti, 3);
        end
        generate_activations(0, 8);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 8);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 8, 1);
        end

        wait (ready);
        acc_depth = 1;
        num_rows  = 8;
        pulse_start_and_wait_done(200);
        verify_all_tiles(8, 1, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 7: INT8 ACC=18, 72 rows（大累加深度，多仲裁轮次）
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 7: INT8 ACC=18, 72 rows (stress)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 616161;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 11000 * ti + 626262;
                generate_weights(ti, 2);
            end
        end
        seed = 636363;
        generate_activations(1, 72);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 72);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 72, 18);
        end

        wait (ready);
        acc_depth = 18;
        num_rows  = 72;
        pulse_start_and_wait_done(200);
        verify_all_tiles(72, 18, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 8: ONNX 全分辨率 — model.3 输出 [1,64,40,40] → M=1600, K=288, acc=18, num_rows=M×acc=28800
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 8: im2col acc=18, num_rows=28800 (M=40×40=1600, model.3)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 808080;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 9000 * ti + 818181;
                generate_weights(ti, 2);
            end
        end
        seed = 828282;
        generate_activations(1, 28800);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 28800);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 28800, 18);
        end

        wait (ready);
        acc_depth = 18;
        num_rows  = 28800;
        pulse_start_and_wait_done(120000);
        verify_all_tiles(28800, 18, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 9: ONNX 全分辨率 — model.5 输出 [1,128,20,20] → M=400, acc=36, num_rows=14400
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 9: im2col acc=36, num_rows=14400 (M=20×20=400, model.5)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 909090;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 12000 * ti + 919191;
                generate_weights(ti, 2);
            end
        end
        seed = 929292;
        generate_activations(1, 14400);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 14400);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 14400, 36);
        end

        wait (ready);
        acc_depth = 36;
        num_rows  = 14400;
        pulse_start_and_wait_done(80000);
        verify_all_tiles(14400, 36, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 10: ONNX 全分辨率 — model.7 / model.21 输出 [1,256,10,10] → M=100, acc=72, num_rows=7200
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 10: im2col acc=72, num_rows=7200 (M=10×10=100, model.7/21)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 1010101;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 15000 * ti + 1020202;
                generate_weights(ti, 2);
            end
        end
        seed = 1030303;
        generate_activations(1, 7200);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 7200);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 7200, 72);
        end

        wait (ready);
        acc_depth = 72;
        num_rows  = 7200;
        pulse_start_and_wait_done(40000);
        verify_all_tiles(7200, 72, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 11: ONNX 全分辨率 — model.9.cv2 输出 [1,256,10,10] → M=100, acc=32, num_rows=3200
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 11: im2col acc=32, num_rows=3200 (M=10×10=100, model.9.cv2)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 1111111;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 18000 * ti + 1121212;
                generate_weights(ti, 2);
            end
        end
        seed = 1131313;
        generate_activations(1, 3200);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 3200);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 3200, 32);
        end

        wait (ready);
        acc_depth = 32;
        num_rows  = 3200;
        pulse_start_and_wait_done(25000);
        verify_all_tiles(3200, 32, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 12: ONNX 全分辨率 — model.0 输出 [1,16,160,160] → M=25600, K=108 pad→acc=7, num_rows=179200
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 12: K=108→acc=7 pad, num_rows=179200 (M=160×160=25600, model.0)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 1212121;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                generate_weights(ti, 1);
        end
        seed = 1232323;
        generate_activations(1, 179200);
        zero_pad_im2col_k(179200, 7, 108);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 179200);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 179200, 7);
        end

        wait (ready);
        acc_depth = 7;
        num_rows  = 179200;
        pulse_start_and_wait_done(2000000);
        verify_all_tiles(179200, 7, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Test 13: ONNX 全分辨率 — model.1 输出 [1,32,80,80] → M=6400, acc=9, num_rows=57600
        // ------------------------------------------------------------------
        total_tests = total_tests + 1;
        errs_before = total_errors;
        $display("");
        $display("─────────────────────────────────────────────────────────────");
        $display("  Test 13: im2col acc=9, num_rows=57600 (M=80×80=6400, model.1)");
        $display("─────────────────────────────────────────────────────────────");

        seed = 1313131;
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1) begin
                seed = 20000 * ti + 1323232;
                generate_weights(ti, 2);
            end
        end
        seed = 1333333;
        generate_activations(0, 57600);
        set_default_tile_bases();
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                load_weights(ti, CYCLE * ti);
        end
        load_activations(ACT_BASE, 57600);
        begin
            integer ti;
            for (ti = 0; ti < NUM_TILES; ti = ti + 1)
                compute_golden(ti, 57600, 9);
        end

        wait (ready);
        acc_depth = 9;
        num_rows  = 57600;
        pulse_start_and_wait_done(250000);
        verify_all_tiles(57600, 9, errors_per_tile);
        total_errors = total_errors + errors_per_tile;
        if (total_errors == errs_before)
            passed_tests = passed_tests + 1;

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("");
        $display("═══════════════════════════════════════════════════════════════");
        $display("                      TEST SUMMARY");
        $display("═══════════════════════════════════════════════════════════════");
        $display("  Tiles:        %0d", NUM_TILES);
        $display("  Total Tests:  %0d", total_tests);
        $display("  Passed:       %0d", passed_tests);
        $display("  Failed:       %0d", total_tests - passed_tests);
        $display("  Total Errors: %0d", total_errors);
        $display("═══════════════════════════════════════════════════════════════");

        if (total_errors == 0)
            $display("  >>> ALL TESTS PASSED <<<");
        else
            $display("  >>> SOME TESTS FAILED <<<");

        $display("");
        repeat (100) @(posedge clk);
        $finish;
    end

    // Wall-clock style cap: 14400 * 1s sim time = 4h (timescale 1ns: #1_000_000_000 = 1s)
    initial begin
        repeat (14400) #1000000000;
        $display("GLOBAL TIMEOUT!");
        $finish;
    end

    initial begin
        $fsdbDumpfile("dcim_array.fsdb");
        $fsdbDumpvars(1, tb_DCIM_Array);
    end

endmodule
