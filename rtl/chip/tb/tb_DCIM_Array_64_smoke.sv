`timescale 1ns / 1ps
`include "../../chip/chip_defines.vh"

module tb_DCIM_Array_64_smoke;
    localparam NUM_TILES = `DCIM_NUM_TILES;
    localparam CH_IN = `DCIM_CH_IN;
    localparam CH_OUT = `DCIM_CH_OUT;
    localparam CYCLE = `DCIM_CYCLE;
    localparam BUF_AW = `DCIM_OBUF_ADDR_WIDTH;
    localparam BUF_DW = `DCIM_BUF_DATA_WIDTH;
    localparam STRB_W = BUF_DW / 8;
    localparam ACC = `DCIM_ACC_MAX;
    localparam ACC_W = $clog2(ACC + 1);
    localparam INT8_OUT_CH = CH_OUT / 2;
    localparam OUT_WORDS = INT8_OUT_CH / 4;

    reg clk;
    reg rst_n;
    reg start;
    wire done;
    wire ready;

    reg [2:0] mode;
    reg [ACC_W-1:0] acc_depth;
    reg [BUF_AW-1:0] act_base_addr;
    reg [NUM_TILES*BUF_AW-1:0] wei_base_addrs;
    reg [NUM_TILES*BUF_AW-1:0] out_base_addrs;
    reg [NUM_TILES-1:0] tile_mask;

    reg [STRB_W-1:0] ibuf_ext_wea;
    reg ibuf_ext_ena;
    reg [BUF_AW-1:0] ibuf_ext_addra;
    reg [BUF_DW-1:0] ibuf_ext_dina;
    wire [BUF_DW-1:0] ibuf_ext_douta;

    reg [STRB_W-1:0] obuf_ext_wea;
    reg obuf_ext_ena;
    reg [BUF_AW-1:0] obuf_ext_addra;
    reg [BUF_DW-1:0] obuf_ext_dina;
    wire [BUF_DW-1:0] obuf_ext_douta;
    wire obuf_ext_douta_valid;

    integer errors;

    initial clk = 1'b0;
    always #2 clk = ~clk;

    DCIM_Array #(
        .NUM_TILES(NUM_TILES),
        .WD1(`DCIM_WD1),
        .CH_IN(CH_IN),
        .CH_OUT(CH_OUT),
        .SRAM_DP(`DCIM_SRAM_DP),
        .CYCLE(CYCLE),
        .ACC(ACC),
        .BUF_ADDR_WIDTH(BUF_AW),
        .BUF_DATA_WIDTH(BUF_DW),
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .ready(ready),
        .mode(mode),
        .acc_depth(acc_depth),
        .act_base_addr(act_base_addr),
        .wei_base_addrs(wei_base_addrs),
        .out_base_addrs(out_base_addrs),
        .tile_mask(tile_mask),
        .ibuf_ext_wea(ibuf_ext_wea),
        .ibuf_ext_ena(ibuf_ext_ena),
        .ibuf_ext_addra(ibuf_ext_addra),
        .ibuf_ext_dina(ibuf_ext_dina),
        .ibuf_ext_douta(ibuf_ext_douta),
        .obuf_ext_wea(obuf_ext_wea),
        .obuf_ext_ena(obuf_ext_ena),
        .obuf_ext_addra(obuf_ext_addra),
        .obuf_ext_dina(obuf_ext_dina),
        .obuf_ext_douta(obuf_ext_douta),
        .obuf_ext_douta_valid(obuf_ext_douta_valid)
    );

    task automatic write_ibuf_word(input [BUF_AW-1:0] addr, input [BUF_DW-1:0] data);
        begin
            @(posedge clk);
            ibuf_ext_ena <= 1'b1;
            ibuf_ext_wea <= {STRB_W{1'b1}};
            ibuf_ext_addra <= addr;
            ibuf_ext_dina <= data;
            @(posedge clk);
            ibuf_ext_ena <= 1'b0;
            ibuf_ext_wea <= '0;
            ibuf_ext_dina <= '0;
        end
    endtask

    task automatic read_obuf_word(input [BUF_AW-1:0] addr, output [BUF_DW-1:0] data);
        begin
            @(posedge clk);
            obuf_ext_ena <= 1'b1;
            obuf_ext_wea <= '0;
            obuf_ext_addra <= addr;
            wait (obuf_ext_douta_valid === 1'b1);
            data = obuf_ext_douta;
            @(posedge clk);
            obuf_ext_ena <= 1'b0;
        end
    endtask

    function automatic [BUF_DW-1:0] make_weight_word(input integer word_idx);
        integer nib;
        integer global_nib;
        integer phys_out;
        reg [BUF_DW-1:0] word;
        begin
            word = '0;
            for (nib = 0; nib < BUF_DW/4; nib = nib + 1) begin
                global_nib = word_idx * (BUF_DW/4) + nib;
                phys_out = global_nib / CH_IN;
                word[nib*4 +: 4] = (phys_out % 2 == 0) ? 4'h1 : 4'h0;
            end
            make_weight_word = word;
        end
    endfunction

    function automatic [BUF_DW-1:0] make_act_word;
        integer b;
        reg [BUF_DW-1:0] word;
        begin
            word = '0;
            for (b = 0; b < STRB_W; b = b + 1) begin
                word[b*8 +: 8] = 8'h01;
            end
            make_act_word = word;
        end
    endfunction

    task automatic check_word(input integer tile, input integer word_idx, input [BUF_DW-1:0] data);
        integer lane;
        reg signed [31:0] got;
        begin
            for (lane = 0; lane < 4; lane = lane + 1) begin
                got = data[lane*32 +: 32];
                if (got !== 32'sd64) begin
                    $display("ERROR tile=%0d word=%0d lane=%0d got=%0d expected=64 data=0x%032h",
                             tile, word_idx, lane, got, data);
                    errors = errors + 1;
                end
            end
        end
    endtask

    integer t;
    integer w;
    reg [BUF_DW-1:0] rd;

    initial begin
        errors = 0;
        rst_n = 1'b0;
        start = 1'b0;
        mode = `MODE_INT8;
        acc_depth = 1;
        act_base_addr = 20'h01000;
        wei_base_addrs = '0;
        out_base_addrs = '0;
        tile_mask = {NUM_TILES{1'b1}};
        ibuf_ext_wea = '0;
        ibuf_ext_ena = 1'b0;
        ibuf_ext_addra = '0;
        ibuf_ext_dina = '0;
        obuf_ext_wea = '0;
        obuf_ext_ena = 1'b0;
        obuf_ext_addra = '0;
        obuf_ext_dina = '0;

        repeat (20) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        for (t = 0; t < NUM_TILES; t = t + 1) begin
            wei_base_addrs[t*BUF_AW +: BUF_AW] = t * CYCLE;
            out_base_addrs[t*BUF_AW +: BUF_AW] = 20'h20000 + t * 20'h00100;
        end

        for (t = 0; t < NUM_TILES; t = t + 1) begin
            for (w = 0; w < CYCLE; w = w + 1) begin
                write_ibuf_word(t * CYCLE + w, make_weight_word(w));
            end
        end

        for (w = 0; w < CH_IN / STRB_W; w = w + 1) begin
            write_ibuf_word(act_base_addr + w, make_act_word());
        end

        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        wait (done === 1'b1);
        repeat (20) @(posedge clk);

        for (t = 0; t < NUM_TILES; t = t + 1) begin
            for (w = 0; w < OUT_WORDS; w = w + 1) begin
                read_obuf_word(20'h20000 + t * 20'h00100 + w, rd);
                check_word(t, w, rd);
            end
        end

        if (errors == 0) begin
            $display("PASS: tb_DCIM_Array_64_smoke NUM_TILES=%0d CH_IN=%0d CH_OUT=%0d CYCLE=%0d", NUM_TILES, CH_IN, CH_OUT, CYCLE);
        end else begin
            $display("FAIL: tb_DCIM_Array_64_smoke errors=%0d", errors);
            $finish(1);
        end
        $finish;
    end

    initial begin
        #20000000;
        $display("TIMEOUT: tb_DCIM_Array_64_smoke");
        $finish(1);
    end
endmodule
