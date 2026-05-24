`timescale 1ns / 1ps
`include "chip_defines.vh"

// Test: acc_depth=2, 2 pixels, real matmul with different weights per acc_word
module tb_dcim_acc2;
    localparam CLK_PERIOD = 4.0;
    localparam BUF_DATA_WIDTH = `DCIM_BUF_DATA_WIDTH;
    localparam IBUF_ADDR_WIDTH = `DCIM_IBUF_ADDR_WIDTH;
    localparam OBUF_ADDR_WIDTH = `DCIM_OBUF_ADDR_WIDTH;
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8;
    localparam NUM_TILES = `DCIM_TILES_PER_GROUP;

    reg clk, rst_n;
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg cfg_wr_en; reg [11:0] cfg_wr_addr; reg [31:0] cfg_wr_data;
    wire dcim_done, dcim_ready;
    reg [STRB_WIDTH-1:0] obuf_ext_wea; reg obuf_ext_ena;
    reg [OBUF_ADDR_WIDTH+3:0] obuf_ext_addra; reg [BUF_DATA_WIDTH-1:0] obuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0] obuf_ext_douta;
    reg [STRB_WIDTH-1:0] ibuf_ext_wea; reg ibuf_ext_ena;
    reg [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] ibuf_ext_addra; reg [BUF_DATA_WIDTH-1:0] ibuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0] ibuf_ext_douta;
    wire [OBUF_ADDR_WIDTH-1:0] vpu_obuf_addr; assign vpu_obuf_addr = 0;
    wire vpu_obuf_en; assign vpu_obuf_en = 0;
    wire [STRB_WIDTH-1:0] vpu_obuf_we; assign vpu_obuf_we = 0;
    wire [BUF_DATA_WIDTH-1:0] vpu_obuf_din, vpu_obuf_dout; assign vpu_obuf_din = 0;

    DCIM_Array_bd #(.NUM_GROUPS(`DCIM_NUM_GROUPS), .TILES_PER_GROUP(`DCIM_TILES_PER_GROUP),
        .NUM_TILES(NUM_TILES), .IBUF_ADDR_WIDTH(IBUF_ADDR_WIDTH),
        .OBUF_ADDR_WIDTH(OBUF_ADDR_WIDTH), .BUF_DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_dcim_bd (
        .clk(clk), .rst_n(rst_n), .cfg_wr_en(cfg_wr_en), .cfg_wr_addr(cfg_wr_addr), .cfg_wr_data(cfg_wr_data),
        .ibuf_ext_wea(ibuf_ext_wea), .ibuf_ext_ena(ibuf_ext_ena),
        .ibuf_ext_addra(ibuf_ext_addra), .ibuf_ext_dina(ibuf_ext_dina), .ibuf_ext_douta(ibuf_ext_douta),
        .obuf_ext_wea(obuf_ext_wea), .obuf_ext_ena(obuf_ext_ena),
        .obuf_ext_addra(obuf_ext_addra), .obuf_ext_dina(obuf_ext_dina), .obuf_ext_douta(obuf_ext_douta),
        .vpu_obuf_addr(vpu_obuf_addr), .vpu_obuf_en(vpu_obuf_en),
        .vpu_obuf_we(vpu_obuf_we), .vpu_obuf_din(vpu_obuf_din), .vpu_obuf_dout(vpu_obuf_dout),
        .done(dcim_done), .ready(dcim_ready)
    );

    task ibuf_write(input [IBUF_ADDR_WIDTH-1:0] waddr, input [BUF_DATA_WIDTH-1:0] data);
        @(posedge clk); ibuf_ext_ena<=1; ibuf_ext_wea<={STRB_WIDTH{1'b1}};
        ibuf_ext_addra<={waddr,4'b0}; ibuf_ext_dina<=data;
        @(posedge clk); ibuf_ext_ena<=0; ibuf_ext_wea<=0;
    endtask
    task obuf_read(input [OBUF_ADDR_WIDTH-1:0] waddr, output [BUF_DATA_WIDTH-1:0] data);
        @(posedge clk); obuf_ext_ena<=1; obuf_ext_wea<=0; obuf_ext_addra<={waddr,4'b0};
        @(posedge clk); obuf_ext_ena<=0; repeat(14) @(posedge clk); data=obuf_ext_douta;
    endtask
    task dcim_cfg_write(input [11:0] addr, input [31:0] data);
        @(posedge clk); cfg_wr_en<=1; cfg_wr_addr<=addr; cfg_wr_data<=data;
        @(posedge clk); cfg_wr_en<=0;
    endtask

    reg [127:0] rd_word;
    integer i, pass_cnt, fail_cnt;

    initial begin
        $display("=== tb_dcim_acc2: acc_depth=2, 2 pixels, real matmul ===");
        rst_n=0; cfg_wr_en=0; obuf_ext_ena=0; obuf_ext_wea=0; ibuf_ext_ena=0; ibuf_ext_wea=0;
        pass_cnt=0; fail_cnt=0;
        repeat(10) @(posedge clk); rst_n=1; repeat(10) @(posedge clk);

        // Weight: acc_depth=2, so 16 entries (8 per acc_word)
        // acc_word 0: all ch_out weight = +1 (entry={0, 0x1111...})
        // acc_word 1: all ch_out weight = +2 (entry={0, 0x2222...})
        for (i=0; i<8; i=i+1) ibuf_write(i, 128'h00000000000000001111111111111111);       // acc_word 0
        for (i=0; i<8; i=i+1) ibuf_write(8+i, 128'h00000000000000002222222222222222); // acc_word 1

        // Activation: 2 pixels, each with 2 words (acc_depth=2)
        // px0 word0: [1..16], word1: [17..32]
        // px1 word0: [33..48], word1: [49..64]
        ibuf_write(17'h100, 128'h100f0e0d0c0b0a090807060504030201); // px0 w0: 1..16
        ibuf_write(17'h101, 128'h201f1e1d1c1b1a191817161514131211); // px0 w1: 17..32
        ibuf_write(17'h102, 128'h302f2e2d2c2b2a292827262524232221); // px1 w0: 33..48
        ibuf_write(17'h103, 128'h403f3e3d3c3b3a393837363534333231); // px1 w1: 49..64

        // Expected: accum[px, ch] = sum_word0(act[c]*w0[c]) + sum_word1(act[c]*w1[c])
        // w0=+1, w1=+2: accum = sum(px_w0)*1 + sum(px_w1)*2
        // px0: sum(1..16)*1 + sum(17..32)*2 = 136*1 + 392*2 = 136 + 784 = 920
        // px1: sum(33..48)*1 + sum(49..64)*2 = 648*1 + 904*2 = 648 + 1808 = 2456
        $display("  Expected px0 accum (all ch): 920 = 0x00000398");
        $display("  Expected px1 accum (all ch): 2456 = 0x00000998");

        // --- Pixel 0 ---
        dcim_cfg_write(`DCIM_REG_MODE, {16'h0, 8'd2, 5'h0, `MODE_INT8}); // acc_depth=2
        dcim_cfg_write(`DCIM_REG_ACT_BASE, 32'h0100);
        dcim_cfg_write(`DCIM_REG_WEI_BASE, 32'h0000);
        for (i=1;i<NUM_TILES;i=i+1) dcim_cfg_write(`DCIM_REG_WEI_BASE+i*4, 32'h0);
        dcim_cfg_write(`DCIM_REG_OUT_BASE, 32'h2000);
        for (i=1;i<NUM_TILES;i=i+1) dcim_cfg_write(`DCIM_REG_OUT_BASE+i*4, 32'h8000);
        dcim_cfg_write(`DCIM_REG_CTRL, 32'h1);
        wait(dcim_ready==0); wait(dcim_ready==1);
        $display("[%0t] Pixel 0 done", $time);
        repeat(10) @(posedge clk);

        // --- Pixel 1 ---
        dcim_cfg_write(`DCIM_REG_ACT_BASE, 32'h0102); // px1 starts at word 0x102 (= px0_base + acc_depth)
        dcim_cfg_write(`DCIM_REG_OUT_BASE, 32'h2002);
        for (i=1;i<NUM_TILES;i=i+1) dcim_cfg_write(`DCIM_REG_OUT_BASE+i*4, 32'h8000);
        dcim_cfg_write(`DCIM_REG_CTRL, 32'h1);
        wait(dcim_ready==0); wait(dcim_ready==1);
        $display("[%0t] Pixel 1 done", $time);
        repeat(10) @(posedge clk);

        // --- Verify ---
        obuf_read(20'h2000, rd_word);
        $display("  px0 lo = 0x%032h", rd_word);
        if (rd_word == 128'h00000398000003980000039800000398) pass_cnt=pass_cnt+1;
        else begin fail_cnt=fail_cnt+1; $display("    FAIL! exp=0x00000398×4"); end

        obuf_read(20'h2001, rd_word);
        $display("  px0 hi = 0x%032h", rd_word);
        if (rd_word == 128'h00000398000003980000039800000398) pass_cnt=pass_cnt+1;
        else begin fail_cnt=fail_cnt+1; $display("    FAIL! exp=0x00000398×4"); end

        obuf_read(20'h2002, rd_word);
        $display("  px1 lo = 0x%032h", rd_word);
        if (rd_word == 128'h00000998000009980000099800000998) pass_cnt=pass_cnt+1;
        else begin fail_cnt=fail_cnt+1; $display("    FAIL! exp=0x00000998×4"); end

        obuf_read(20'h2003, rd_word);
        $display("  px1 hi = 0x%032h", rd_word);
        if (rd_word == 128'h00000998000009980000099800000998) pass_cnt=pass_cnt+1;
        else begin fail_cnt=fail_cnt+1; $display("    FAIL! exp=0x00000998×4"); end

        $display(""); $display("Results: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt==0) $display("ALL PASSED - acc_depth=2 weight reload WORKS!");
        else $display("FAILED");
        $finish;
    end

    // Debug: show state transitions
    reg [3:0] prev_state;
    always @(posedge clk) begin
        prev_state <= u_dcim_bd.u_dcim_array.gen_groups[0].u_group.gen_tiles[0].u_tile.state;
        if (u_dcim_bd.u_dcim_array.gen_groups[0].u_group.gen_tiles[0].u_tile.state != prev_state)
            $display("[%0t] Tile0 state: %0d -> %0d  row_cnt=%0d wei_cnt=%0d pp_cnt=%0d",
                $time, prev_state,
                u_dcim_bd.u_dcim_array.gen_groups[0].u_group.gen_tiles[0].u_tile.state,
                u_dcim_bd.u_dcim_array.gen_groups[0].u_group.gen_tiles[0].u_tile.row_cnt,
                u_dcim_bd.u_dcim_array.gen_groups[0].u_group.gen_tiles[0].u_tile.wei_load_cnt,
                u_dcim_bd.u_dcim_array.gen_groups[0].u_group.gen_tiles[0].u_tile.ppcache_cnt);
    end
    initial begin #(CLK_PERIOD*500000); $display("TIMEOUT"); $finish(1); end
endmodule
