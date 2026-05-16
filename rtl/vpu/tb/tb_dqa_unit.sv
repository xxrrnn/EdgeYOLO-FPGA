`timescale 1ns/1ps

module tb_dqa_unit;

  // --------------------------------------------------
  // 参数（与 DUT 保持一致 / 可根据需要调整）
  // --------------------------------------------------
    
    
    localparam DQA_ACT_CHANNEL_NUM = 64;
    localparam DQA_ACT_HEIGHT = 32;
    localparam DQA_ACT_BLOCKS = 8192;
    localparam DQA_ACT_BYTES  = 8192 * 32;

    reg [255:0] dqa_act [0:8191];

    initial begin
        $display("Loading .\dqa_act_data.mem ...");
        $readmemh("./dqa_act_data.mem", dqa_act);
        $display("Loaded %0d blocks into dqa_act", DQA_ACT_BLOCKS);
    end



    localparam DQA_SCALE_CHANNEL_NUM = 64;
    localparam DQA_SCALE_HEIGHT = 1;
    localparam DQA_SCALE_BLOCKS = 4;
    localparam DQA_SCALE_BYTES  = 4 * 32;

    reg [255:0] dqa_scale [0:3];

    initial begin
        $display("Loading .\dqa_scale_data.mem ...");
        $readmemh("./dqa_scale_data.mem", dqa_scale);
        $display("Loaded %0d blocks into dqa_scale", DQA_SCALE_BLOCKS);
    end



    localparam DQA_EXPECTED_CHANNEL_NUM = 64;
    localparam DQA_EXPECTED_HEIGHT = 32;
    localparam DQA_EXPECTED_BLOCKS = 4096;
    localparam DQA_EXPECTED_BYTES  = 4096 * 32;

    reg [255:0] dqa_expected [0:4095];

    initial begin
        $display("Loading .\dqa_expected_data.mem ...");
        $readmemh("./dqa_expected_data.mem", dqa_expected);
        $display("Loaded %0d blocks into dqa_expected", DQA_EXPECTED_BLOCKS);
    end





    // BRAM / GB 参数（与 dqa_unit 中使用的带宽一致）
    localparam NB_COL = 256/8;      // 256 bits -> 32 bytes -> NB_COL = 32
    localparam COL_WIDTH = 8;       // byte width
    localparam RAM_DEPTH_GB = DQA_ACT_BLOCKS;
    localparam RAM_DEPTH_WB = 256;  // WB depth (scale memory), 可按需调整
    localparam RAM_PERFORMANCE = "LOW_LATENCY";

    // DUT 参数
    localparam ADDR_WIDTH = 32;
    localparam GLOBAL_BUFFER_ADDR_WIDTH = $clog2(RAM_DEPTH_GB);
    localparam GLOBAL_BUFFER_BANDWIDTH = 256;
    localparam WB_BANDWIDTH = 256;
    localparam WB_DEPTH = RAM_DEPTH_WB;
    localparam FP_CORE_NUM = DQA_ACT_CHANNEL_NUM;
    localparam FP_WIDTH = 16;


  // --------------------------------------------------
  // 时钟 / 复位
  // --------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk; // 100MHz

    reg rst_n = 0;

  // --------------------------------------------------
  // DUT control/config signals
  // --------------------------------------------------
    reg                          dqa_unit_start;
    reg [ADDR_WIDTH-1:0]         dqa_src_addr;
    reg [ADDR_WIDTH-1:0]         dqa_src_c;
    reg [ADDR_WIDTH-1:0]         dqa_src_h;
    reg [ADDR_WIDTH-1:0]         dqa_src_w;
    reg [ADDR_WIDTH-1:0]         dqa_scale_addr;
    reg [ADDR_WIDTH-1:0]         dqa_scale_num;
    reg [ADDR_WIDTH-1:0]         dqa_dst_addr;

  // --------------------------------------------------
  // FP array side (DUT ports)
  // --------------------------------------------------
    wire                         dqa_fp_array_tvalid;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] dqa_a_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] dqa_b_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] dqa_c_tdata;
    reg  [FP_CORE_NUM*FP_WIDTH-1:0] dqa_fp_res;
    reg                           dqa_fp_res_valid;
    reg                           dqa_fp_array_tready; // external module may drive this; we keep as reg for TB if needed

  // --------------------------------------------------
  // GB port B <-> DUT (wires driven from DUT)
  // --------------------------------------------------
    wire [$clog2(RAM_DEPTH_GB-1)-1:0] gb_addrb;
    wire [GLOBAL_BUFFER_BANDWIDTH-1:0] gb_dinb;
    wire [GLOBAL_BUFFER_BANDWIDTH/8-1:0] gb_web;
    wire gb_enb;
    wire [GLOBAL_BUFFER_BANDWIDTH-1:0] gb_doutb;

    // --------------------------------------------------
    // WB port B <-> DUT (wires driven from DUT)
    // --------------------------------------------------
    wire [$clog2(WB_DEPTH)-1:0] wb_addrb;
    wire [WB_BANDWIDTH-1:0]     wb_dinb;
    wire [WB_BANDWIDTH/8-1:0]   wb_web;
    wire                        wb_enb;
    wire [WB_BANDWIDTH-1:0]     wb_doutb;

    // --------------------------------------------------
    // BRAM Port A signals used by TB (for initializing / readback)
    // --------------------------------------------------
    reg [$clog2(RAM_DEPTH_GB-1)-1:0]  gb_addra;
    reg [(NB_COL*COL_WIDTH)-1:0]      gb_dina;
    reg [NB_COL-1:0]                  gb_wea;
    reg                                gb_ena;
    wire [(NB_COL*COL_WIDTH)-1:0]     gb_douta;

    reg [$clog2(RAM_DEPTH_WB-1)-1:0]  wb_addra;
    reg [(NB_COL*COL_WIDTH)-1:0]      wb_dina;
    reg [NB_COL-1:0]                  wb_wea;
    reg                                wb_ena;
    wire [(NB_COL*COL_WIDTH)-1:0]     wb_douta;

    // flags for comparison
    reg [DQA_EXPECTED_BLOCKS-1:0] expected_true;
    wire all_true = &expected_true;

  // --------------------------------------------------
  // Instantiate DUT
  // --------------------------------------------------
  dqa_unit #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .GB_BANDWIDTH(GLOBAL_BUFFER_BANDWIDTH),
    .GB_ADDR_WIDTH(GLOBAL_BUFFER_ADDR_WIDTH),
    .INT_WIDTH_OUT(32),
    .INT_WIDTH_IN(32),
    .FP_CORE_NUM(FP_CORE_NUM),
    .FP_WIDTH(FP_WIDTH),
    .WB_BANDWIDTH(WB_BANDWIDTH),
    .WB_DEPTH(WB_DEPTH),
    .MAX_CHANNEL_NUM(512)
  ) dqa_inst (
    .clk(clk),
    .rst_n(rst_n),
    .dqa_unit_start(dqa_unit_start),
    .dqa_src_addr(dqa_src_addr),
    .dqa_src_c(dqa_src_c),
    .dqa_src_h(dqa_src_h),
    .dqa_src_w(dqa_src_w),
    .dqa_scale_addr(dqa_scale_addr),
    .dqa_scale_num(dqa_scale_num),
    .dqa_dst_addr(dqa_dst_addr),

    .fp_array_tvalid(dqa_fp_array_tvalid),
    .fp_array_tready(dqa_fp_array_tready),
    .a_tdata(dqa_a_tdata),
    .b_tdata(dqa_b_tdata),
    .c_tdata(dqa_c_tdata),
    .fp_res(dqa_fp_res),
    .fp_res_valid(dqa_fp_res_valid),

    .gb_addrb(gb_addrb),
    .gb_dinb(gb_dinb),
    .gb_web(gb_web),
    .gb_enb(gb_enb),
    .gb_doutb(gb_doutb),

    .wb_addrb(wb_addrb),
    .wb_dinb(wb_dinb),
    .wb_web(wb_web),
    .wb_enb(wb_enb),
    .wb_doutb(wb_doutb)
  );

  // --------------------------------------------------
  // Instantiate global_buffer_bram for GB (port B -> DUT)
  // Port A is used by TB (gb_addra, gb_dina, gb_wea, gb_ena)
  // --------------------------------------------------
  global_buffer_bram #(
    .NB_COL(NB_COL),
    .COL_WIDTH(COL_WIDTH),
    .RAM_DEPTH(RAM_DEPTH_GB),
    .RAM_PERFORMANCE(RAM_PERFORMANCE),
    .INIT_FILE("")
  ) gb_bram (
    .addra(gb_addra),
    .addrb(gb_addrb),
    .dina(gb_dina),
    .dinb(gb_dinb),
    .clka(clk),
    .wea(gb_wea),
    .web(gb_web),
    .ena(gb_ena),
    .enb(gb_enb),
    .rsta(1'b1),
    .rstb(1'b1),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(gb_douta),
    .doutb(gb_doutb)
  );

  // --------------------------------------------------
  // Instantiate global_buffer_bram for WB (port B -> DUT reads scales)
  // Port A used by TB to write scale data
  // --------------------------------------------------
  global_buffer_bram #(
    .NB_COL(NB_COL),
    .COL_WIDTH(COL_WIDTH),
    .RAM_DEPTH(RAM_DEPTH_WB),
    .RAM_PERFORMANCE(RAM_PERFORMANCE),
    .INIT_FILE("")
  ) wb_bram (
    .addra(wb_addra),
    .addrb(wb_addrb),
    .dina(wb_dina),
    .dinb(wb_dinb),
    .clka(clk),
    .wea(wb_wea),
    .web(wb_web),
    .ena(wb_ena),
    .enb(wb_enb),
    .rsta(1'b1),
    .rstb(1'b1),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(wb_douta),
    .doutb(wb_doutb)
  );

  // --------------------------------------------------
  // TB behavior: load mem files -> write Port A of GB & WB -> start DUT -> readback compare
  // --------------------------------------------------
  integer i;
  initial begin
    // reset sequence
    rst_n = 0;
    dqa_unit_start = 0;
    dqa_src_addr = 32'h100;      // example base address in GB (word address, >>5 in DUT)
    dqa_src_c = DQA_ACT_CHANNEL_NUM;
    dqa_src_w = DQA_ACT_HEIGHT;
    dqa_src_h = DQA_ACT_HEIGHT;
    dqa_scale_addr = 0;
    dqa_scale_num = DQA_ACT_CHANNEL_NUM;
    dqa_dst_addr = DQA_ACT_BYTES +  32'h200; 
    dqa_fp_res = {FP_CORE_NUM*FP_WIDTH{1'b0}};
    dqa_fp_res_valid = 1'b0;
    dqa_fp_array_tready = 1'b1;

    // default port a signals disabled
    gb_ena = 1'b0;
    gb_wea = {NB_COL{1'b0}};
    wb_ena = 1'b0;
    wb_wea = {NB_COL{1'b0}};
    gb_addra = {$clog2(RAM_DEPTH_GB-1){1'b0}};
    wb_addra = {$clog2(RAM_DEPTH_WB-1){1'b0}};
    gb_dina = { (NB_COL*COL_WIDTH) {1'b0} };
    wb_dina = { (NB_COL*COL_WIDTH) {1'b0} };

    #20;
    rst_n = 1;
    #10;

    // -------------------------
    // 1) 初始化 WB (Port A) -> 写入 scale 数据（假设每项 256-bit）
    // -------------------------
    $display("[%0t] Start WB init (Port A writes)...", $time);
    wb_ena = 1'b1;
    for (i = 0; i < DQA_SCALE_BLOCKS; i = i + 1) begin
        @(posedge clk);
        wb_addra <= i[$clog2(RAM_DEPTH_WB-1)-1:0];
        wb_dina <= dqa_scale[i];
        wb_wea  <= {NB_COL{1'b1}}; // write all bytes
    end
    @(posedge clk);
    wb_wea <= {NB_COL{1'b0}};
    wb_ena <= 1'b0;
    $display("[%0t] WB init done.", $time);

    // -------------------------
    // 2) 初始化 GB (Port A) -> 写入 input act 数据
    // -------------------------
    $display("[%0t] Start GB init (Port A writes)... total blocks = %0d", $time, DQA_ACT_BLOCKS);
    gb_ena = 1'b1;
    for (i = 0; i < DQA_ACT_BLOCKS; i = i + 1) begin
        @(posedge clk);
        gb_addra <= i[$clog2(RAM_DEPTH_GB-1)-1:0];
        gb_dina  <= dqa_act[i];
        gb_wea   <= {NB_COL{1'b1}}; // write all bytes
    end
    @(posedge clk);
    gb_wea <= {NB_COL{1'b0}};
    gb_ena <= 1'b0;
    $display("[%0t] GB init done.", $time);

    // -------------------------
    // 3) 启动 DUT
    // -------------------------
    #50;
    @(posedge clk);
    dqa_unit_start <= 1'b1;
    @(posedge clk);
    dqa_unit_start <= 1'b0;
    $display("[%0t] dqa_unit_start pulsed.", $time);

    // 运行一段时间以等待 DUT 完成（具体等待时间取决于 DUT 内部实现）
    // 这里我们简单观测若干时钟周期的 GB 写行为（Port B）
    repeat (1000) begin
      @(posedge clk);
      // 观察 DUT 驱动的 Port B 信号
      if (gb_enb && |gb_web) begin
        $display("[%0t] GB PortB write: addrb=%0d web=%h", $time, gb_addrb, gb_web);
      end
    end

    // -------------------------
    // 4) 读回 GB 的目标区域（Port A 读），与 expected 比对
    //    注意：DQA_EXPECTED_BLOCKS 是预期要比较的块数
    // -------------------------
    $display("[%0t] Start readback & compare ...", $time);
    for (i = 0; i < DQA_EXPECTED_BLOCKS; i = i + 1) begin
      @(posedge clk);
      gb_ena <= 1'b1;
      gb_wea <= {NB_COL{1'b0}};        // 读
      gb_addra <= (dqa_dst_addr >> 5) + i; // DUT 通常使用 >>5 换算到 256-bit word addr
      // 等待同步输出 (BRAM 的 douta 在同一周期可能可用或下一周期可用，取决于实现)
      @(posedge clk);
      // 读取 douta
      if (gb_douta !== dqa_expected[i]) begin
        $display("[%0t] MISMATCH at block %0d: got %h expected %h", $time, i, gb_douta, dqa_expected[i]);
        expected_true[i] = 1'b0;
      end else begin
        expected_true[i] = 1'b1;
      end
      @(posedge clk);
      gb_ena <= 1'b0;
    end

    if (all_true) $display("[%0t] ALL MATCH! test PASSED.", $time);
    else $display("[%0t] SOME MISMATCHES FOUND. test FAILED.", $time);

    #100;
    $finish;
  end

endmodule
