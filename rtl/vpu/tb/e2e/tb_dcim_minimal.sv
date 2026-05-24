`timescale 1ns / 1ps
`include "chip_defines.vh"

// Minimal DCIM test: 1 pixel, acc_depth=1, 1 tile, known weight + act
module tb_dcim_minimal;
    localparam CLK_PERIOD = 4.0;
    localparam BUF_DATA_WIDTH = `DCIM_BUF_DATA_WIDTH;
    localparam IBUF_ADDR_WIDTH = `DCIM_IBUF_ADDR_WIDTH;
    localparam OBUF_ADDR_WIDTH = `DCIM_OBUF_ADDR_WIDTH;
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8;
    localparam NUM_TILES = `DCIM_TILES_PER_GROUP;

    reg clk, rst_n;
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // DCIM cfg
    reg         cfg_wr_en;
    reg  [11:0] cfg_wr_addr;
    reg  [31:0] cfg_wr_data;
    wire        dcim_done, dcim_ready;

    // OBUF/IBUF ext
    reg  [STRB_WIDTH-1:0]      obuf_ext_wea;
    reg                        obuf_ext_ena;
    reg  [OBUF_ADDR_WIDTH+3:0] obuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]  obuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]  obuf_ext_douta;
    reg  [STRB_WIDTH-1:0]      ibuf_ext_wea;
    reg                        ibuf_ext_ena;
    reg  [`DCIM_AXI_BRAM_ADDR_WIDTH-1:0] ibuf_ext_addra;
    reg  [BUF_DATA_WIDTH-1:0]  ibuf_ext_dina;
    wire [BUF_DATA_WIDTH-1:0]  ibuf_ext_douta;

    // VPU stub (not used, tie off)
    wire [OBUF_ADDR_WIDTH-1:0] vpu_obuf_addr = 0;
    wire vpu_obuf_en = 0;
    wire [STRB_WIDTH-1:0] vpu_obuf_we = 0;
    wire [BUF_DATA_WIDTH-1:0] vpu_obuf_din = 0;
    wire [BUF_DATA_WIDTH-1:0] vpu_obuf_dout;

    DCIM_Array_bd #(
        .NUM_GROUPS(`DCIM_NUM_GROUPS), .TILES_PER_GROUP(`DCIM_TILES_PER_GROUP),
        .NUM_TILES(NUM_TILES), .IBUF_ADDR_WIDTH(IBUF_ADDR_WIDTH),
        .OBUF_ADDR_WIDTH(OBUF_ADDR_WIDTH), .BUF_DATA_WIDTH(BUF_DATA_WIDTH)
    ) u_dcim_bd (
        .clk(clk), .rst_n(rst_n),
        .cfg_wr_en(cfg_wr_en), .cfg_wr_addr(cfg_wr_addr), .cfg_wr_data(cfg_wr_data),
        .ibuf_ext_wea(ibuf_ext_wea), .ibuf_ext_ena(ibuf_ext_ena),
        .ibuf_ext_addra(ibuf_ext_addra), .ibuf_ext_dina(ibuf_ext_dina), .ibuf_ext_douta(ibuf_ext_douta),
        .obuf_ext_wea(obuf_ext_wea), .obuf_ext_ena(obuf_ext_ena),
        .obuf_ext_addra(obuf_ext_addra), .obuf_ext_dina(obuf_ext_dina), .obuf_ext_douta(obuf_ext_douta),
        .vpu_obuf_addr(vpu_obuf_addr), .vpu_obuf_en(vpu_obuf_en),
        .vpu_obuf_we(vpu_obuf_we), .vpu_obuf_din(vpu_obuf_din), .vpu_obuf_dout(vpu_obuf_dout),
        .done(dcim_done), .ready(dcim_ready)
    );

    task ibuf_write(input [IBUF_ADDR_WIDTH-1:0] waddr, input [BUF_DATA_WIDTH-1:0] data);
        @(posedge clk); ibuf_ext_ena <= 1; ibuf_ext_wea <= {STRB_WIDTH{1'b1}};
        ibuf_ext_addra <= {waddr, 4'b0}; ibuf_ext_dina <= data;
        @(posedge clk); ibuf_ext_ena <= 0; ibuf_ext_wea <= 0;
    endtask

    task obuf_read(input [OBUF_ADDR_WIDTH-1:0] waddr, output [BUF_DATA_WIDTH-1:0] data);
        @(posedge clk); obuf_ext_ena <= 1; obuf_ext_wea <= 0;
        obuf_ext_addra <= {waddr, 4'b0};
        @(posedge clk); obuf_ext_ena <= 0;
        repeat(14) @(posedge clk);
        data = obuf_ext_douta;
    endtask

    task dcim_cfg_write(input [11:0] addr, input [31:0] data);
        @(posedge clk); cfg_wr_en <= 1; cfg_wr_addr <= addr; cfg_wr_data <= data;
        @(posedge clk); cfg_wr_en <= 0;
    endtask

    reg [127:0] rd_word;
    reg [127:0] wei_mem [0:7];
    integer i;

    initial begin
        $display("=== tb_dcim_minimal: 1 pixel, acc_depth=1, known data ===");
        rst_n = 0; cfg_wr_en = 0; obuf_ext_ena = 0; obuf_ext_wea = 0;
        ibuf_ext_ena = 0; ibuf_ext_wea = 0;
        repeat(10) @(posedge clk); rst_n = 1; repeat(10) @(posedge clk);

        // Load weight (8 entries at IBUF word 0..7)
        $readmemh("min_weight.hex", wei_mem);
        for (i = 0; i < 8; i = i + 1) ibuf_write(i, wei_mem[i]);

        // Load activation (1 word at IBUF word 1000 = 0x3E8)
        ibuf_write(17'h1000, 128'h100f0e0d0c0b0a09_0807060504030201);

        $display("[%0t] Data loaded. Configuring DCIM...", $time);

        // Configure: acc_depth=1, mode=INT8, act_base=0x1000, wei_base[0]=0
        dcim_cfg_write(`DCIM_REG_MODE, {16'h0, 8'd1, 5'h0, `MODE_INT8}); // acc=1
        dcim_cfg_write(`DCIM_REG_ACT_BASE, 32'h1000);
        dcim_cfg_write(`DCIM_REG_WEI_BASE, 32'h0);  // tile0
        for (i = 1; i < NUM_TILES; i = i + 1)
            dcim_cfg_write(`DCIM_REG_WEI_BASE + i*4, 32'h0); // other tiles same (don't care)
        dcim_cfg_write(`DCIM_REG_OUT_BASE, 32'h20000); // tile0 output at OBUF word 0x2000
        for (i = 1; i < NUM_TILES; i = i + 1)
            dcim_cfg_write(`DCIM_REG_OUT_BASE + i*4, 32'h8000); // others to scratch

        // Start DCIM
        dcim_cfg_write(`DCIM_REG_CTRL, 32'h1);
        wait(dcim_ready == 0);
        $display("[%0t] DCIM started (ready fell)", $time);
        wait(dcim_ready == 1);
        $display("[%0t] DCIM done (ready rose)", $time);
        repeat(20) @(posedge clk);

        // Read result
        obuf_read(20'h20000, rd_word);
        $display("  OBUF[0x20000] = 0x%032h (word_lo: ch0-3)", rd_word);
        obuf_read(20'h20001, rd_word);
        $display("  OBUF[0x20001] = 0x%032h (word_hi: ch4-7)", rd_word);

        // Expected: ch0=136, ch1=272, ch2=408, ch3=544, ch4=680, ch5=816, ch6=952, ch7=1088
        $display("  Expected lo: 0x00000220000001980000011000000088");
        $display("  Expected hi: 0x00000440000003b800000330000002a8");
        $display("=== DONE ===");
        $finish;
    end

    initial begin #(CLK_PERIOD * 100000); $display("TIMEOUT"); $finish(1); end
endmodule
