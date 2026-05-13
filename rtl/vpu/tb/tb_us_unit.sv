`timescale 1ns/1ps
`include "mem_defines_auto.vh"

module tb_us_unit;



/* mem */

    localparam US_ACT_CHANNEL_NUM = 64;
    localparam US_ACT_HEIGHT = 8;
    localparam US_ACT_BLOCKS = 128;
    localparam US_ACT_BYTES  = 128 * 32;

    reg [255:0] us_act [0:127];

    initial begin
        $display("Loading us_act_data.mem ...");
        $readmemh(`MEM_US_ACT, us_act);
        $display("Loaded %0d blocks into us_act", US_ACT_BLOCKS);
    end



    localparam US_EXPECTED_CHANNEL_NUM = 64;
localparam US_EXPECTED_HEIGHT = 16;
localparam US_EXPECTED_BLOCKS = 512;
localparam US_EXPECTED_BYTES  = 512 * 32;

reg [255:0] us_expected [0:511];

    initial begin
        $display("Loading us_expected_data.mem ...");
        $readmemh(`MEM_US_EXP, us_expected);
        $display("Loaded %0d blocks into us_expected", US_EXPECTED_BLOCKS);
    end

    /* mem */


    reg [255:0]  us_expected_data;
    reg [US_EXPECTED_BLOCKS - 1 : 0] us_expected_true;
    wire us_all_true = &us_expected_true;
    wire us_unit_ready;


    localparam NB_COL = (256/8); // 256 bits -> 32 bytes
    localparam COL_WIDTH = 8;
    localparam RAM_DEPTH = US_EXPECTED_BYTES * 2;
    localparam RAM_PERFORMANCE = "LOW_LATENCY";
  // =======================
  // 参数定义（与 DUT 一致）
  // =======================
    localparam ADDR_WIDTH = 32;
    localparam GB_ADDR_WIDTH = $clog2(RAM_DEPTH);
    localparam GB_BANDWIDTH = 256;
    localparam FP_WIDTH  = 8;
    localparam VPU_NUM = 4;
    localparam FP_NUM = 16;
    localparam MAX_MP_CHANNEL_NUM = 1024;


  // -----------------------
  // helper function: clogb2
  // -----------------------
    function integer clogb2;
        input integer value;
        integer i;
        begin
            clogb2 = 0;
            for (i = value; i > 0; i = i >> 1)
                clogb2 = clogb2 + 1;
        end
    endfunction

  // =======================
  // 信号定义
  // =======================
    reg clk;
    reg rst_n;
    reg us_unit_start;

    // config inputs
    reg [ADDR_WIDTH-1:0] us_src_addr;
    reg [ADDR_WIDTH-1:0] us_src_h;
    reg [ADDR_WIDTH-1:0] us_src_w;
    reg [ADDR_WIDTH-1:0] us_src_c;
    reg [ADDR_WIDTH-1:0] us_dst_addr;


    // global buffer interface (connected to DUT)
    wire [GB_ADDR_WIDTH-1:0] gb_addrb;
    wire [GB_BANDWIDTH-1:0]  gb_dinb;
    wire [GB_BANDWIDTH/8-1:0] gb_web;
    wire gb_enb;
    wire [GB_BANDWIDTH-1:0]  gb_doutb; // now wire, driven by BRAM

  // =======================
  // 实例化 DUT
  // =======================
    us_unit #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .GB_BANDWIDTH(GB_BANDWIDTH),
        .FP_WIDTH(FP_WIDTH),
        .MAX_MP_CHANNEL_NUM(MAX_MP_CHANNEL_NUM)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .us_unit_start(us_unit_start),
        .us_unit_ready(us_unit_ready),

        .us_src_addr(us_src_addr),
        .us_src_h(us_src_h),
        .us_src_w(us_src_w),
        .us_src_c(us_src_c),
        .us_dst_addr(us_dst_addr),

        .gb_addrb(gb_addrb),
        .gb_dinb(gb_dinb),
        .gb_web(gb_web),
        .gb_enb(gb_enb),
        .gb_doutb(gb_doutb)
    );

  // =======================
  // BRAM 信号（Port A 用于初始化写入，Port B 给 VPU 使用）
  // =======================
    reg [clogb2(RAM_DEPTH-1)-1:0] bram_addra;
    wire [clogb2(RAM_DEPTH-1)-1:0] bram_addrb;
    reg [(NB_COL*COL_WIDTH)-1:0] bram_dina;
    wire [(NB_COL*COL_WIDTH)-1:0] bram_doutb;
    wire [GB_BANDWIDTH - 1 : 0] bram_douta;
    reg clka;
    reg [NB_COL-1:0] bram_wea;
    wire [NB_COL-1:0] bram_web;
    reg bram_ena;
    wire bram_enb;
    reg rsta; 
    reg rstb;
    reg regcea;
    reg regceb;

integer err_cnt;
integer j;


  // 连接 DUT 的 B 端到 BRAM B 端
  assign bram_addrb = gb_addrb;

  // =======================
  // BRAM 实例化
  // =======================
  global_buffer_bram #(
    .NB_COL(NB_COL),
    .COL_WIDTH(COL_WIDTH),
    .RAM_DEPTH(RAM_DEPTH),
    .RAM_PERFORMANCE(RAM_PERFORMANCE),
    .INIT_FILE("") 
  ) u_global_bram (
    .addra(bram_addra),
    .addrb(gb_addrb),            // Port B address -> connected to DUT addrb
    .dina(bram_dina),                       // Port A data in (we drive during init)
    .dinb(gb_dinb),              // Port B data in -> driven by DUT when writing back
    .clka(clk),                             // same clock
    .wea(bram_wea),
    .web(gb_web),                // Port B write enable (driven by DUT)
    .ena(bram_ena),
    .enb(gb_enb),
    .rsta(1'b1),
    .rstb(1'b1),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(bram_douta),                               // we don't read port A's dout in this TB
    .doutb(gb_doutb)             // Port B dout -> fed into DUT
  );


  // =======================
  // 时钟产生
  // =======================
  initial clk = 0;
  always #5 clk = ~clk;  // 100MHz

  integer i;
  // =======================
  // 初始状态
  // =======================
  initial begin

    
    // US test
    j = 0;
    // default TB signals
    rst_n = 0;
    us_unit_start = 0;
    us_src_addr = 32'h100;
    us_src_c = US_ACT_CHANNEL_NUM;
    // us_src_stride_col = US_ACT_CHANNEL_NUM;
    // us_src_stride_row = US_ACT_CHANNEL_NUM * US_ACT_HEIGHT;
    us_src_h = US_ACT_HEIGHT;
    us_src_w = US_ACT_HEIGHT;
    
    us_dst_addr = US_ACT_BYTES + 32'h200;

    // BRAM port A default
    bram_addra = {clogb2(RAM_DEPTH-1){1'b0}};
    bram_dina = { (NB_COL*COL_WIDTH) {1'b0} };
    bram_wea = {NB_COL{1'b0}};
    bram_ena = 1'b0;

    #20;
    // release reset
    @(posedge clk);
    rst_n = 1;
    #10;

    // -------------------------
    // 初始化写入：用 Port A 把 act[0..80] 写入 BRAM 的地址 0..80
    // -------------------------
    $display("[%0t] Start BRAM init (Port A writes)...", $time);
    bram_ena = 1'b1;
    for (i = 0; i < US_ACT_BLOCKS; i = i + 1) begin
        @(posedge clk);
        bram_addra <= i[clogb2(RAM_DEPTH-1)-1:0] + (us_src_addr >> 5);
        bram_dina  <= us_act[i];
        bram_wea   <= {NB_COL{1'b1}}; // write all bytes
    end

    // 完成写入，清除使能
    @(posedge clk);
    bram_wea <= {NB_COL{1'b0}};
    bram_ena <= 1'b0;
    $display("[%0t] BRAM init done.", $time);

    // -------------------------
    // 等待 DUT ready，发起 config/start
    // -------------------------

    repeat(10) @(posedge clk);
    us_unit_start = 1'b1;
    @(posedge clk);
    us_unit_start = 1'b0;
    $display("[%0t] VPU start asserted", $time);

    // 观察一段时间
    repeat (200) begin
        @(posedge clk);
        $display("[%0t] enb=%b web=%h addrb=%h", $time, gb_enb, gb_web, gb_addrb);
    end

    $display("[%0t] Testbench finished.", $time);

    wait(us_unit_ready == 1);
    
    
    for (j = 0; j < US_EXPECTED_BLOCKS; j = j + 1) begin
        @(posedge clk);
        bram_ena = 1'b1;
        bram_wea = {NB_COL{1'b0}};  // 只读
        bram_addra = (us_dst_addr >> 5 )+ j;
        repeat(2) @(posedge clk);
        us_expected_data = us_expected[j];
        @(posedge clk);
        us_expected_true[j] = bram_douta == us_expected_data;
        @(posedge clk);
        bram_ena = 1'b0;
    end

end

endmodule
