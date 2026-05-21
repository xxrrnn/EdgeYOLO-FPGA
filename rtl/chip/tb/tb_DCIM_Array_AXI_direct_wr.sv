`timescale 1ns / 1ps
`include "../../ref/DCIM/src/inc/para.v"

//////////////////////////////////////////////////////////////////////////////////
// tb_DCIM_Array_bd_cfg_mini - 4-tile 配置接口快速验证
//
// 只测 cfg_wr_* → 内部寄存器 → DCIM_Array 控制信号，
// 用 NUM_TILES=4 (1组×4Tile) 大幅缩短仿真时间
//////////////////////////////////////////////////////////////////////////////////

module tb_DCIM_Array_AXI_direct_wr;

    localparam CLK_PERIOD     = 10;
    localparam NUM_GROUPS_T   = 1;   // 1 组
    localparam TILES_PER_GRP  = 4;   // 每组 4 Tile
    localparam NUM_TILES_T    = 4;
    localparam BUF_AW         = 14;
    localparam ACC            = 80;

    localparam [11:0] ADDR_CTRL     = 12'h000;
    localparam [11:0] ADDR_MODE     = 12'h008;
    localparam [11:0] ADDR_ACT_BASE = 12'h010;
    localparam [11:0] ADDR_WEI_BASE = 12'h040;
    localparam [11:0] ADDR_OUT_BASE = 12'h140;

    reg  clk, rst_n;
    reg         cfg_wr_en;
    reg  [11:0] cfg_wr_addr;
    reg  [31:0] cfg_wr_data;
    wire        done, ready;

    integer pass_cnt, fail_cnt;

    task check;
        input [511:0] label;
        input [63:0]  got;
        input [63:0]  exp;
        begin
            if (got === exp) begin
                $display("  PASS: %s = 0x%0h", label, got);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("  FAIL: %s got=0x%0h exp=0x%0h", label, got, exp);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task direct_write;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            cfg_wr_en   = 1;
            cfg_wr_addr = addr;
            cfg_wr_data = data;
            @(posedge clk);
            cfg_wr_en   = 0;
        end
    endtask

    // 4-tile DUT（最小配置）
    DCIM_Array_bd #(
        .NUM_GROUPS      (NUM_GROUPS_T),
        .TILES_PER_GROUP (TILES_PER_GRP),
        .NUM_TILES       (NUM_TILES_T),
        .WD1(4), .CH_IN(16), .CH_OUT(16), .SRAM_DP(128),
        .CYCLE(8), .ACC(ACC),
        .BUF_ADDR_WIDTH  (BUF_AW),
        .BUF_DATA_WIDTH  (128),
        .AXI_BRAM_ADDR_WIDTH(18),
        .IBUF_RD_LATENCY (8)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .cfg_wr_en(cfg_wr_en), .cfg_wr_addr(cfg_wr_addr), .cfg_wr_data(cfg_wr_data),
        // Group 0 IBUF/OBUF (only 1 group)
        .ibuf_ext_wea_0(0), .ibuf_ext_ena_0(0), .ibuf_ext_addra_0(0),
        .ibuf_ext_dina_0(0), .ibuf_ext_douta_0(),
        .ibuf_ext_wea_1(0), .ibuf_ext_ena_1(0), .ibuf_ext_addra_1(0),
        .ibuf_ext_dina_1(0), .ibuf_ext_douta_1(),
        .ibuf_ext_wea_2(0), .ibuf_ext_ena_2(0), .ibuf_ext_addra_2(0),
        .ibuf_ext_dina_2(0), .ibuf_ext_douta_2(),
        .ibuf_ext_wea_3(0), .ibuf_ext_ena_3(0), .ibuf_ext_addra_3(0),
        .ibuf_ext_dina_3(0), .ibuf_ext_douta_3(),
        .ibuf_ext_wea_4(0), .ibuf_ext_ena_4(0), .ibuf_ext_addra_4(0),
        .ibuf_ext_dina_4(0), .ibuf_ext_douta_4(),
        .ibuf_ext_wea_5(0), .ibuf_ext_ena_5(0), .ibuf_ext_addra_5(0),
        .ibuf_ext_dina_5(0), .ibuf_ext_douta_5(),
        .ibuf_ext_wea_6(0), .ibuf_ext_ena_6(0), .ibuf_ext_addra_6(0),
        .ibuf_ext_dina_6(0), .ibuf_ext_douta_6(),
        .ibuf_ext_wea_7(0), .ibuf_ext_ena_7(0), .ibuf_ext_addra_7(0),
        .ibuf_ext_dina_7(0), .ibuf_ext_douta_7(),
        .obuf_ext_wea_0(0), .obuf_ext_ena_0(0), .obuf_ext_addra_0(0),
        .obuf_ext_dina_0(0), .obuf_ext_douta_0(),
        .obuf_ext_wea_1(0), .obuf_ext_ena_1(0), .obuf_ext_addra_1(0),
        .obuf_ext_dina_1(0), .obuf_ext_douta_1(),
        .obuf_ext_wea_2(0), .obuf_ext_ena_2(0), .obuf_ext_addra_2(0),
        .obuf_ext_dina_2(0), .obuf_ext_douta_2(),
        .obuf_ext_wea_3(0), .obuf_ext_ena_3(0), .obuf_ext_addra_3(0),
        .obuf_ext_dina_3(0), .obuf_ext_douta_3(),
        .obuf_ext_wea_4(0), .obuf_ext_ena_4(0), .obuf_ext_addra_4(0),
        .obuf_ext_dina_4(0), .obuf_ext_douta_4(),
        .obuf_ext_wea_5(0), .obuf_ext_ena_5(0), .obuf_ext_addra_5(0),
        .obuf_ext_dina_5(0), .obuf_ext_douta_5(),
        .obuf_ext_wea_6(0), .obuf_ext_ena_6(0), .obuf_ext_addra_6(0),
        .obuf_ext_dina_6(0), .obuf_ext_douta_6(),
        .obuf_ext_wea_7(0), .obuf_ext_ena_7(0), .obuf_ext_addra_7(0),
        .obuf_ext_dina_7(0), .obuf_ext_douta_7(),
        .done(done), .ready(ready)
    );

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg cfg_start_seen;
    always @(posedge clk)
        if (!rst_n) cfg_start_seen <= 0;
        else if (dut.cfg_start) cfg_start_seen <= 1;

    initial begin
        $display("====================================================");
        $display("  DCIM_Array_bd cfg_wr interface test (4-Tile mini)");
        $display("====================================================");
        pass_cnt = 0; fail_cnt = 0;
        cfg_wr_en = 0;
        rst_n = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(3) @(posedge clk);

        $display("\n[T1] MODE=0x6, acc_depth=8");
        direct_write(ADDR_MODE, 32'h00000806);
        @(posedge clk);
        check("cfg_mode",      dut.cfg_mode,      3'h6);
        check("cfg_acc_depth", dut.cfg_acc_depth, 7'd8);

        $display("\n[T2] ACT_BASE[0]=0x0100");
        direct_write(ADDR_ACT_BASE, 32'h00000100);
        @(posedge clk);
        check("cfg_act_base_addrs[0]",
              dut.cfg_act_base_addrs[BUF_AW-1:0], 14'h0100);

        $display("\n[T3] WEI_BASE[0]=0x0200, WEI_BASE[3]=0x0300");
        direct_write(ADDR_WEI_BASE,        32'h00000200);
        direct_write(ADDR_WEI_BASE + 12,   32'h00000300); // tile 3
        @(posedge clk);
        check("cfg_wei_base_addrs[0]",
              dut.cfg_wei_base_addrs[BUF_AW-1:0], 14'h0200);
        check("cfg_wei_base_addrs[3]",
              dut.cfg_wei_base_addrs[3*BUF_AW +: BUF_AW], 14'h0300);

        $display("\n[T4] OUT_BASE[0]=0x0400");
        direct_write(ADDR_OUT_BASE, 32'h00000400);
        @(posedge clk);
        check("cfg_out_base_addrs[0]",
              dut.cfg_out_base_addrs[BUF_AW-1:0], 14'h0400);

        $display("\n[T5] CTRL[0]=1 → cfg_start pulse");
        cfg_start_seen = 0;
        direct_write(ADDR_CTRL, 32'h00000001);
        repeat(3) @(posedge clk);
        check("cfg_start pulsed",  cfg_start_seen, 1'b1);
        check("cfg_start cleared", dut.cfg_start,  1'b0);

        $display("\n[T6] ready=1 at startup");
        check("ready", ready, 1'b1);

        $display("\n====================================================");
        $display("  Results: %0d PASS, %0d FAIL", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("  ALL TESTS PASSED");
        else               $display("  SOME TESTS FAILED");
        $display("====================================================");
        $finish(fail_cnt == 0 ? 0 : 1);
    end

    initial begin #500000; $display("TIMEOUT"); $finish(1); end
endmodule
