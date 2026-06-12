`timescale 1ns/1ps
`include "chip_defines.vh"

module Global_VPU #(
    parameter ADDR_WIDTH = `VPU_DATA_WIDTH,
    
    parameter GB_ADDR_WIDTH = `GB_ADDR_WIDTH,
    parameter C_INT_WIDTH_IN = `C_INT_WIDTH_IN,
    parameter BANDWIDTH = `VPU_BANDWIDTH,

    parameter FP_CORE_NUM = `FP_CORE_NUM,
    parameter FP_TRAN_NUM = `FP_TRAN_NUM,
    parameter FP_WIDTH    = `FP_WIDTH,
    
    parameter WB_ADDR_WIDTH = `WB_ADDR_WIDTH,
    parameter MAX_CHANNEL_NUM = `MAX_CHANNEL_NUM,

    parameter INTERVAL_NUM = `INTERVAL_NUM,
    parameter RAM_DEPTH_GB    = `RAM_DEPTH_GB,
    parameter RAM_DEPTH_WB    = `RAM_DEPTH_WB,
    parameter Q_INT_WIDTH_OUT = `Q_INT_WIDTH_OUT,

    parameter NB_COL = `NB_COL,
    parameter COL_WIDTH = `COL_WIDTH

)(
    input   wire                     clk,
    input   wire                     rst_n,
    output   wire                    config_ready,
    input   wire                     config_valid,
    input   wire                     start,
      
    input   wire[ADDR_WIDTH - 1:0]   unit_choose,
    input   wire [3:0]               vpu_flags,    // flags[0]=relu_en（DQA 用），其余保留

    input   wire[ADDR_WIDTH - 1:0]          src_addr,
    input   wire[ADDR_WIDTH - 1:0]          src2_addr,
    input   wire[ADDR_WIDTH - 1:0]          src_c,
    input   wire[ADDR_WIDTH - 1:0]          src_h,
    input   wire[ADDR_WIDTH - 1:0]          src_w,
    input   wire[ADDR_WIDTH - 1:0]          scale_addr,
    input   wire[ADDR_WIDTH - 1:0]          bias_addr,
    input   wire[ADDR_WIDTH - 1:0]          dst_addr,

    input wire [ADDR_WIDTH-1:0]             addr_break,
    input wire [ADDR_WIDTH-1:0]             addr_s,
    input wire [ADDR_WIDTH-1:0]             addr_t,

    // chip-v3: VPU 通过 vpu_buf 本地 buffer 读写（VPU_BUF_ADDR_WIDTH=19, 128-bit 字地址）
    output wire [`VPU_BUF_ADDR_WIDTH-1:0]   obuf_addr,        // 19 (128-bit 字地址, 8MB)
    output wire                              obuf_en,
    output wire [`DCIM_BUF_DATA_WIDTH/8-1:0] obuf_we,          // 16-byte strb
    output wire [`DCIM_BUF_DATA_WIDTH-1:0]   obuf_din,         // 128-bit
    input  wire [`DCIM_BUF_DATA_WIDTH-1:0]   obuf_dout,        // 128-bit
    input  wire                              obuf_rd_valid,    // VPU_BUF 读数据有效

    // WB 端口保留
    input wire [WB_ADDR_WIDTH-1:0]          wb_addra,
    input wire [(NB_COL*COL_WIDTH)-1:0]     wb_dina,
    input wire [NB_COL-1:0]                 wb_wea,
    input wire                              wb_ena,
    output wire [(NB_COL*COL_WIDTH)-1:0]    wb_douta
);
  localparam RAM_PERFORMANCE = "LOW_LATENCY";
  // localparam NB_COL = 32;
  // localparam COL_WIDTH = 8;
  
  localparam BREAK_WIDTH = FP_WIDTH;
  localparam WEIGHT_WIDTH = FP_WIDTH;
  localparam BIAS_WIDTH = FP_WIDTH;

  localparam GB_BANDWIDTH = BANDWIDTH;
  localparam WB_BANDWIDTH = BANDWIDTH;
  // -------------------------------
  // Local parameters
  // -------------------------------
  localparam UNIT_DQA = 32'd01;
  localparam UNIT_NN  = 32'd02;
  localparam UNIT_QA  = 32'd03;
  localparam UNIT_MP  = 32'd04;
  localparam UNIT_US  = 32'd05;
  localparam UNIT_AD  = 32'd06;
  localparam UNIT_IM2COL = 32'd07;  // lite: im2col_unit
  localparam VPU_FLAG_RELU_EN = 0;
  localparam VPU_FLAG_INT16   = 1;


    wire   rst_n_local;
    rst_n_sync rst_n_sync_inst(
        .clk(clk),
        .rst_n_i(rst_n),
        .rst_n_o(rst_n_local)
    );

  // -------------------------------
  // Internal registers
  // -------------------------------
    reg [ADDR_WIDTH - 1:0]          unit_choose_reg;
    reg [ADDR_WIDTH - 1:0]          src_addr_reg;
    reg [ADDR_WIDTH - 1:0]          src2_addr_reg;
    reg [ADDR_WIDTH - 1:0]          src_c_reg;
    reg [ADDR_WIDTH - 1:0]          src_h_reg;
    reg [ADDR_WIDTH - 1:0]          src_w_reg;
    reg [ADDR_WIDTH - 1:0]          scale_addr_reg;
    reg [ADDR_WIDTH - 1:0]          bias_addr_reg;
    reg [ADDR_WIDTH - 1:0]          dst_addr_reg;

    reg [ADDR_WIDTH-1:0]            addr_break_reg;
    reg [ADDR_WIDTH-1:0]            addr_s_reg;
    reg [ADDR_WIDTH-1:0]            addr_t_reg;

    // 正在执行的 unit（start 后保持到 config_ready 再次变高）
    reg [ADDR_WIDTH-1:0]            unit_running_reg;
    reg [3:0]                       vpu_flags_reg;
    reg                             vpu_running;

  always @(posedge clk or negedge rst_n_local) begin
    if(!rst_n_local) begin
      unit_choose_reg <= 0;
      src_addr_reg    <= 0;
      src2_addr_reg   <= 0;
      src_c_reg   <= 0;
      src_h_reg   <= 0;
      src_w_reg   <= 0;
      scale_addr_reg    <= 0;
      bias_addr_reg   <= 0;
      dst_addr_reg    <= 0;
      addr_break_reg    <= 0;
      addr_s_reg    <= 0;
      addr_t_reg    <= 0;
      unit_running_reg <= 0;
      vpu_flags_reg    <= 4'b0;
      vpu_running      <= 1'b0;
    end else begin
      // S_EXEC_VPU 更新端口；S_WAIT_VPU_START 拉高 start（晚一拍）。
      // 地址类参数：在 config_ready 时稳定，可在 config_ready&&config_valid 时锁存。
      // vpu_flags：在 S_EXEC_VPU 周期才写入寄存器，需等到 start（S_WAIT_VPU_START 拍）才稳定，
      //            仅在 start=1 时锁存，避免 config_ready&&config_valid 抢先锁存旧值。
      if ((config_ready && config_valid) || start) begin
        unit_choose_reg <= unit_choose;
        src_addr_reg    <= src_addr;
        src2_addr_reg   <= src2_addr;
        src_c_reg       <= src_c;
        src_h_reg       <= src_h;
        src_w_reg       <= src_w;
        scale_addr_reg  <= scale_addr;
        bias_addr_reg   <= bias_addr;
        dst_addr_reg    <= dst_addr;
        addr_break_reg  <= addr_break;
        addr_s_reg      <= addr_s;
        addr_t_reg      <= addr_t;
      end
      if (start) begin
        vpu_flags_reg    <= vpu_flags;   // 仅在 start 拍锁存，此时 vpu_flags 已稳定
        unit_running_reg <= unit_choose;
        vpu_running      <= 1'b1;
      end else if (vpu_running && config_ready) begin
        vpu_running <= 1'b0;
      end
    end
    
  end

  // start 拍用端口；运行期间用 unit_running_reg（防止 body 抓取阶段把 _reg 清成 0）
  wire [ADDR_WIDTH-1:0] unit_active     = start ? unit_choose :
                                          vpu_running ? unit_running_reg : unit_choose_reg;
  wire [ADDR_WIDTH-1:0] active_src_addr  = start ? src_addr      : src_addr_reg;
  wire [ADDR_WIDTH-1:0] active_src2_addr = start ? src2_addr     : src2_addr_reg;
  wire [ADDR_WIDTH-1:0] active_src_c      = start ? src_c         : src_c_reg;
  wire [ADDR_WIDTH-1:0] active_src_h      = start ? src_h         : src_h_reg;
  wire [ADDR_WIDTH-1:0] active_src_w      = start ? src_w         : src_w_reg;
  wire [ADDR_WIDTH-1:0] active_scale_addr  = start ? scale_addr    : scale_addr_reg;
  wire [ADDR_WIDTH-1:0] active_bias_addr   = start ? bias_addr     : bias_addr_reg;
  wire [ADDR_WIDTH-1:0] active_dst_addr    = start ? dst_addr      : dst_addr_reg;
  wire [ADDR_WIDTH-1:0] active_addr_break  = start ? addr_break    : addr_break_reg;
  wire [ADDR_WIDTH-1:0] active_addr_s      = start ? addr_s        : addr_s_reg;
  wire [ADDR_WIDTH-1:0] active_addr_t      = start ? addr_t        : addr_t_reg;
  wire [3:0]            active_vpu_flags   = start ? vpu_flags     : vpu_flags_reg;
  wire                  active_int16_mode  = active_vpu_flags[VPU_FLAG_INT16];


    wire [GB_ADDR_WIDTH-1:0]    gb_addrb, dqa_gb_addrb, nn_gb_addrb, qa_gb_addrb, mp_gb_addrb, us_gb_addrb, ad_gb_addrb, im2col_gb_addrb;
    wire [GB_BANDWIDTH-1:0]     gb_dinb, dqa_gb_dinb, nn_gb_dinb, qa_gb_dinb, mp_gb_dinb, us_gb_dinb, ad_gb_dinb, im2col_gb_dinb;
    wire [GB_BANDWIDTH/8-1:0]   gb_web, dqa_gb_web, nn_gb_web, qa_gb_web, mp_gb_web, us_gb_web, ad_gb_web, im2col_gb_web;
    wire                        gb_enb, dqa_gb_enb, nn_gb_enb, qa_gb_enb, mp_gb_enb, us_gb_enb, ad_gb_enb, im2col_gb_enb;
    wire [GB_BANDWIDTH-1:0]     gb_doutb;
    
    wire [WB_ADDR_WIDTH-1:0]    wb_addrb, dqa_wb_addrb, nn_wb_addrb, qa_wb_addrb;
    wire [WB_BANDWIDTH-1:0]     wb_dinb, dqa_wb_dinb, nn_wb_dinb, qa_wb_dinb;
    wire [WB_BANDWIDTH/8-1:0]   wb_web, dqa_wb_web, nn_wb_web, qa_wb_web;
    wire                        wb_enb, dqa_wb_enb, nn_wb_enb, qa_wb_enb;
    wire [WB_BANDWIDTH-1:0]     wb_doutb;

    wire  dqa_fp_array_tvalid, nn_fp_array_tvalid, qa_fp_array_tvalid;
    wire mp_unit_start, us_unit_start, nn_unit_start, qa_unit_start, dqa_unit_start, ad_unit_start, im2col_unit_start;
    wire mp_unit_ready, us_unit_ready, nn_unit_ready, qa_unit_ready, dqa_unit_ready, ad_unit_ready, im2col_unit_ready;

    wire [FP_CORE_NUM*FP_WIDTH-1:0] fp_res;
    wire fp_res_tvalid;

    wire [FP_CORE_NUM*FP_WIDTH-1:0] dqa_fp_a_tdata, nn_fp_a_tdata, qa_fp_a_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] dqa_fp_b_tdata, nn_fp_b_tdata, qa_fp_b_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] dqa_fp_c_tdata, nn_fp_c_tdata, qa_fp_c_tdata;
    wire [FP_CORE_NUM*FP_WIDTH-1:0] fp_a_tdata, fp_b_tdata, fp_c_tdata;
    wire fp_array_tvalid,fp_array_tready;



  // -------------------------------
  // Wire Declarations
  // -------------------------------



    // mp_unit_fixed: 可配置 MaxPool/GAP (MODE 由 mp_cfg = addr_break[1:0] 选择)
    mp_unit_fixed #(
      .ADDR_WIDTH         (ADDR_WIDTH),
      .GB_BANDWIDTH       (GB_BANDWIDTH),
      .GB_ADDR_WIDTH      (GB_ADDR_WIDTH),
      .FP_WIDTH           (FP_WIDTH)
  ) i_mp_unit (
      .clk                (clk),
      .rst_n              (rst_n_local),
      .mp_unit_start      (mp_unit_start),
      .mp_unit_ready      (mp_unit_ready),
      
      .mp_src_addr        (active_src_addr),
      .mp_dst_addr        (active_dst_addr),
      .mp_src_c           (active_src_c),
      .mp_src_h           (active_src_h),
      .mp_src_w           (active_src_w),
      .mp_cfg             (active_addr_break),  // [1:0] = MODE

      .gb_addrb           (mp_gb_addrb), 
      .gb_dinb            (mp_gb_dinb), 
      .gb_web             (mp_gb_web),
      .gb_enb             (mp_gb_enb),
      .gb_doutb           (gb_doutb),
      .gb_doutb_valid     (obuf_rd_valid)
  );


    // us_unit_fixed: Nearest Neighbor Upsample ×2
    us_unit_fixed #(
      .ADDR_WIDTH         (ADDR_WIDTH),
      .GB_BANDWIDTH       (GB_BANDWIDTH),
      .GB_ADDR_WIDTH      (GB_ADDR_WIDTH),
      .FP_WIDTH           (FP_WIDTH)
  ) i_us_unit (
      .clk                (clk),
      .rst_n              (rst_n_local),
      .us_unit_start      (us_unit_start),
      .us_unit_ready      (us_unit_ready),
      
      .us_src_addr        (active_src_addr),
      .us_src_h           (active_src_h),
      .us_src_w           (active_src_w),
      .us_src_c           (active_src_c),
      .us_dst_addr        (active_dst_addr),
      
      .gb_addrb           (us_gb_addrb), 
      .gb_dinb            (us_gb_dinb), 
      .gb_web             (us_gb_web),
      .gb_enb             (us_gb_enb),
      .gb_doutb           (gb_doutb),
      .gb_doutb_valid     (obuf_rd_valid)
  );

// nn_lut_unit 未经测试，暂时注释掉，nn_unit_ready 由 tie-off 拉高，不阻塞 config_ready
// nn_lut_unit #(
//     .ADDR_WIDTH(ADDR_WIDTH),
//     .INTERVAL_NUM(INTERVAL_NUM),
//     .BREAK_WIDTH(BREAK_WIDTH),
//     .WEIGHT_WIDTH(WEIGHT_WIDTH),
//     .BIAS_WIDTH(BIAS_WIDTH),
//     .FP_CORE_NUM(FP_CORE_NUM),
//     .FP_WIDTH(FP_WIDTH),
//     .WB_BANDWIDTH(WB_BANDWIDTH),
//     .RAM_DEPTH_WB(RAM_DEPTH_WB),
//     .GB_BANDWIDTH(GB_BANDWIDTH),
//     .GB_ADDR_WIDTH(GB_ADDR_WIDTH)
// )nn_lut_inst(
//     .clk(clk),
//     .rst_n(rst_n_local),
//     .nn_unit_start(nn_unit_start),
//     .nn_unit_ready(nn_unit_ready),
//     .nn_addr_break(active_addr_break),
//     .nn_addr_s(active_addr_s),
//     .nn_addr_t(active_addr_t),
//     .nn_src_addr(active_src_addr),
//     .nn_src_c(active_src_c),
//     .nn_src_h(active_src_h),
//     .nn_src_w(active_src_w),
//     .nn_dst_addr(active_dst_addr),
//     .fp_array_tready(fp_array_tready),
//     .fp_array_tvalid(nn_fp_array_tvalid),
//     .fp_a_tdata(nn_fp_a_tdata),
//     .fp_b_tdata(nn_fp_b_tdata),
//     .fp_c_tdata(nn_fp_c_tdata),
//     .fp_res(fp_res),
//     .fp_res_tvalid(fp_res_tvalid),
//     .gb_addrb(nn_gb_addrb),
//     .gb_dinb(nn_gb_dinb),
//     .gb_web(nn_gb_web),
//     .gb_enb(nn_gb_enb),
//     .gb_doutb(gb_doutb),
//     .gb_doutb_valid(obuf_rd_valid),
//     .wb_addrb(nn_wb_addrb),
//     .wb_dinb(nn_wb_dinb),
//     .wb_web(nn_wb_web),
//     .wb_enb(nn_wb_enb),
//     .wb_doutb(wb_doutb)
// );

// nn_lut_unit 输出信号 tie-off（避免 undriven wire warning）
assign nn_unit_ready      = 1'b1;
assign nn_unit_start      = 1'b0;
assign nn_gb_addrb        = {GB_ADDR_WIDTH{1'b0}};
assign nn_gb_dinb         = {GB_BANDWIDTH{1'b0}};
assign nn_gb_web          = {GB_BANDWIDTH/8{1'b0}};
assign nn_gb_enb          = 1'b0;
assign nn_wb_addrb        = {WB_ADDR_WIDTH{1'b0}};
assign nn_wb_dinb         = {WB_BANDWIDTH{1'b0}};
assign nn_wb_web          = {WB_BANDWIDTH/8{1'b0}};
assign nn_wb_enb          = 1'b0;
assign nn_fp_array_tvalid = 1'b0;
assign nn_fp_a_tdata      = {FP_CORE_NUM*FP_WIDTH{1'b0}};
assign nn_fp_b_tdata      = {FP_CORE_NUM*FP_WIDTH{1'b0}};
assign nn_fp_c_tdata      = {FP_CORE_NUM*FP_WIDTH{1'b0}};



// Instantiate the qa_unit module
  qa_unit #(
      // --- Parameter Overrides ---
      .ADDR_WIDTH(ADDR_WIDTH),
      .GB_BANDWIDTH(GB_BANDWIDTH),
      .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
      .WB_BANDWIDTH(WB_BANDWIDTH),
      .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
      .FP_CORE_NUM(FP_CORE_NUM),
      .FP_TRAN_NUM(FP_TRAN_NUM),
      .FP_WIDTH(FP_WIDTH),
      .Q_INT_WIDTH_OUT(Q_INT_WIDTH_OUT),
      .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM)
  ) u_qa_unit (
      // --- Control/Status Ports ---
      .clk(clk),
      .rst_n(rst_n_local),
      .qa_unit_start(qa_unit_start),
      .qa_unit_ready(qa_unit_ready),
      
      // --- Configuration/Address Ports ---
      .qa_src_addr(active_src_addr),
      .qa_src_c(active_src_c),
      .qa_src_h(active_src_h),
      .qa_src_w(active_src_w),
      .qa_scale_addr(active_scale_addr),
      .qa_dst_addr(active_dst_addr),
      .qa_int16_mode(active_int16_mode),

      // --- Floating Point Array Ports (AXI Stream-like interfaces) ---
      .fp_array_tready(fp_array_tready),
      .fp_array_tvalid(qa_fp_array_tvalid),
      .fp_a_tdata(qa_fp_a_tdata), 
      .fp_b_tdata(qa_fp_b_tdata),
      .fp_c_tdata(qa_fp_c_tdata),
      .fp_res(fp_res),
      .fp_res_tvalid(fp_res_tvalid),

      // --- Global Buffer (GB) Ports (Simple Dual-Port BRAM-like interface) ---
      .gb_addrb(qa_gb_addrb), 
      .gb_dinb(qa_gb_dinb),  
      .gb_web(qa_gb_web),   
      .gb_enb(qa_gb_enb),    
      .gb_doutb(gb_doutb),
      .gb_doutb_valid(obuf_rd_valid),  // ready/valid: OBUF 读数据有效（替代硬延迟）

      // --- Weight Buffer (WB) Ports (Simple Dual-Port BRAM-like interface) ---
      .wb_addrb(qa_wb_addrb),
      .wb_dinb(qa_wb_dinb),
      .wb_web(qa_wb_web),
      .wb_enb(qa_wb_enb),
      .wb_doutb(wb_doutb)
  );


    ad_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .GB_BANDWIDTH(GB_BANDWIDTH),
      .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
      .FP_CORE_NUM(FP_CORE_NUM),
      .FP_WIDTH(FP_WIDTH)
    ) ad_unit_inst (
        .clk(clk),
        .rst_n(rst_n_local),
        .ad_unit_start(ad_unit_start),
        .ad_unit_ready(ad_unit_ready),

        .ad_src_addr(active_src_addr),
        .ad_src2_addr(active_src2_addr),
        .ad_src_c(active_src_c),
        .ad_src_h(active_src_h),
        .ad_src_w(active_src_w),
        .ad_dst_addr(active_dst_addr),

        .gb_addrb( ad_gb_addrb),
        .gb_dinb( ad_gb_dinb),
        .gb_web( ad_gb_web),
        .gb_enb( ad_gb_enb),
        .gb_doutb(gb_doutb),
        .gb_doutb_valid(obuf_rd_valid)

    );

    // lite 新增: im2col_unit - 硬件 im2col 引擎
    im2col_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .GB_BANDWIDTH(GB_BANDWIDTH),
      .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
      .FP_WIDTH(FP_WIDTH)
    ) im2col_inst (
        .clk(clk),
        .rst_n(rst_n_local),
        .im2col_unit_start(im2col_unit_start),
        .im2col_unit_ready(im2col_unit_ready),
        .im2col_elem_bytes(active_int16_mode ? 2'd2 : 2'd1),

        .im2col_src_addr  (active_src_addr),
        .im2col_dst_addr  (active_dst_addr),
        .im2col_src_c     (active_src_c),
        .im2col_src_h     (active_src_h),
        .im2col_src_w     (active_src_w),
        .im2col_addr_break(active_addr_break),
        .im2col_addr_s    (active_addr_s),
        .im2col_addr_t    (active_addr_t),

        .gb_addrb (im2col_gb_addrb),
        .gb_dinb  (im2col_gb_dinb),
        .gb_web   (im2col_gb_web),
        .gb_enb   (im2col_gb_enb),
        .gb_doutb (gb_doutb),
        .gb_doutb_valid(obuf_rd_valid)
    );











    dqa_relu_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .GB_BANDWIDTH(GB_BANDWIDTH),
      .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
      .C_INT_WIDTH_IN(C_INT_WIDTH_IN),
      .FP_CORE_NUM(FP_CORE_NUM),
      .FP_TRAN_NUM(FP_TRAN_NUM),
      .FP_WIDTH(FP_WIDTH),
      .WB_BANDWIDTH(WB_BANDWIDTH),
      .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
      .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM)
    ) dqa_inst (
        .clk(clk),
        .rst_n(rst_n_local),
        .dqa_unit_start(dqa_unit_start),
        .dqa_unit_ready(dqa_unit_ready),
        .dqa_relu_en(active_vpu_flags[VPU_FLAG_RELU_EN]),
        .dqa_int16_mode(active_int16_mode),
        .dqa_src_addr(active_src_addr),
        .dqa_src_c(active_src_c),
        .dqa_src_h(active_src_h),
        .dqa_src_w(active_src_w),
        .dqa_scale_addr(active_scale_addr),
        .dqa_bias_addr(active_bias_addr),
        .dqa_dst_addr(active_dst_addr),

        .fp_array_tready(fp_array_tready),
        .fp_array_tvalid(dqa_fp_array_tvalid),
        .fp_a_tdata(dqa_fp_a_tdata),
        .fp_b_tdata(dqa_fp_b_tdata),
        .fp_c_tdata(dqa_fp_c_tdata),
        .fp_res(fp_res),
        .fp_res_tvalid(fp_res_tvalid),

        .gb_addrb( dqa_gb_addrb),
        .gb_dinb( dqa_gb_dinb),
        .gb_web( dqa_gb_web),
        .gb_enb( dqa_gb_enb),
        .gb_doutb(gb_doutb),
        .gb_doutb_valid(obuf_rd_valid),  // ready/valid: OBUF 读数据有效（替代硬延迟）

        .wb_addrb( dqa_wb_addrb),
        .wb_dinb( dqa_wb_dinb),
        .wb_web( dqa_wb_web),
        .wb_enb( dqa_wb_enb),
        .wb_doutb(wb_doutb)
    );

    assign config_ready = 1'b1/*nn_unit_ready*/ & us_unit_ready & mp_unit_ready & qa_unit_ready & dqa_unit_ready& ad_unit_ready & im2col_unit_ready;
    // unit_active：start 同拍用 decoder 端口，运行中用 _reg
    assign dqa_unit_start = (unit_active == UNIT_DQA) ? start : 1'b0;
    assign qa_unit_start  = (unit_active == UNIT_QA ) ? start : 1'b0;
    // assign nn_unit_start  = (unit_active == UNIT_NN ) ? start : 1'b0;  // nn_lut_unit 未启用
    assign mp_unit_start  = (unit_active == UNIT_MP ) ? start : 1'b0;
    assign us_unit_start  = (unit_active == UNIT_US ) ? start : 1'b0;
    assign ad_unit_start  = (unit_active == UNIT_AD ) ? start : 1'b0;
    assign im2col_unit_start = (unit_active == UNIT_IM2COL) ? start : 1'b0;


 // GB Address (Output from Unit to BRAM) → 通过 obuf_addr 输出到 OBUF
assign gb_addrb = (unit_active == UNIT_DQA) ? dqa_gb_addrb : 
                  // (unit_active == UNIT_NN) ? nn_gb_addrb :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_gb_addrb :
                  (unit_active == UNIT_MP) ? mp_gb_addrb : 
                  (unit_active == UNIT_US) ? us_gb_addrb : 
                  (unit_active == UNIT_AD) ? ad_gb_addrb : 
                  (unit_active == UNIT_IM2COL) ? im2col_gb_addrb :
                                                  {GB_ADDR_WIDTH{1'b0}};

// GB Data Input (Output from Unit to BRAM write port)
assign gb_dinb = (unit_active == UNIT_DQA) ? dqa_gb_dinb : 
                  // (unit_active == UNIT_NN) ? nn_gb_dinb  :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_gb_dinb  :
                  (unit_active == UNIT_MP) ? mp_gb_dinb  : 
                  (unit_active == UNIT_US) ? us_gb_dinb  : 
                  (unit_active == UNIT_AD) ? ad_gb_dinb  : 
                  (unit_active == UNIT_IM2COL) ? im2col_gb_dinb :
                                                  {GB_BANDWIDTH{1'b0}};

// GB Write Enable (Output from Unit to BRAM)
assign gb_web  = (unit_active == UNIT_DQA) ? dqa_gb_web  : 
                  // (unit_active == UNIT_NN) ? nn_gb_web  :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_gb_web  :
                  (unit_active == UNIT_MP) ? mp_gb_web  : 
                  (unit_active == UNIT_US) ? us_gb_web  : 
                  (unit_active == UNIT_AD) ? ad_gb_web  : 
                  (unit_active == UNIT_IM2COL) ? im2col_gb_web :
                                                  {GB_BANDWIDTH/8{1'b0}};

// GB Enable (Output from Unit to BRAM)
assign gb_enb  = (unit_active == UNIT_DQA) ? dqa_gb_enb  : 
                  // (unit_active == UNIT_NN) ? nn_gb_enb  :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_gb_enb  :
                  (unit_active == UNIT_MP) ? mp_gb_enb  : 
                  (unit_active == UNIT_US) ? us_gb_enb  : 
                  (unit_active == UNIT_AD) ? ad_gb_enb  : 
                  (unit_active == UNIT_IM2COL) ? im2col_gb_enb :
                                                  1'b0;


// GB Data Output (Input from BRAM to Unit - No Muxing needed for input to Unit)
// assign dqa_gb_doutb = gb_doutb; 
// assign nn_gb_doutb = gb_doutb; 
// assign qa_gb_doutb = gb_doutb; 
// assign mp_gb_doutb = gb_doutb; 
// Note: This assumes all units read from the same BRAM output wire `gb_doutb`.


// ----------------------------------------------------------------------
// 3. Weight Buffer (WB) B-Port Muxing Logic
//    - WB 信号接入 DQA, NN, QA。SU 不接入。
// ----------------------------------------------------------------------

// WB Address (Output from Unit to BRAM)
assign wb_addrb = (unit_active == UNIT_DQA) ? dqa_wb_addrb : 
                  // (unit_active == UNIT_NN) ? nn_wb_addrb :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_wb_addrb :
                                                  {WB_ADDR_WIDTH{1'b0}};

assign wb_dinb = (unit_active == UNIT_DQA) ? dqa_wb_dinb : 
                  // (unit_active == UNIT_NN) ? nn_wb_dinb  :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_wb_dinb  :
                                                  {WB_BANDWIDTH{1'b0}};

assign wb_web  = (unit_active == UNIT_DQA) ? dqa_wb_web  : 
                  // (unit_active == UNIT_NN) ? nn_wb_web  :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_wb_web  :
                                                  {WB_BANDWIDTH/8{1'b0}};

assign wb_enb  = (unit_active == UNIT_DQA) ? dqa_wb_enb  : 
                  // (unit_active == UNIT_NN) ? nn_wb_enb  :  // nn_lut_unit 未启用
                  (unit_active == UNIT_QA) ? qa_wb_enb  :
                                                  1'b0;


// ----------------------------------------------------------------------
// 4. Floating Point (FP) MAC Array Muxing Logic (AXI-Stream like interface)
//    - FP 信号接入 DQA, NN, QA。SU 不接入。
// ----------------------------------------------------------------------

// FP Array Valid (Output from Unit to MAC Array)
assign fp_array_tvalid = (unit_active == UNIT_DQA) ? dqa_fp_array_tvalid : 
                         // (unit_active == UNIT_NN) ? nn_fp_array_tvalid :  // nn_lut_unit 未启用
                         (unit_active == UNIT_QA) ? qa_fp_array_tvalid :
                                                         1'b0;

// FP Array Data A (Operand A)
assign fp_a_tdata   = (unit_active == UNIT_DQA) ? dqa_fp_a_tdata  : 
                         // (unit_active == UNIT_NN) ? nn_fp_a_tdata   :  // nn_lut_unit 未启用
                         (unit_active == UNIT_QA) ? qa_fp_a_tdata   :
                                                         {FP_CORE_NUM*FP_WIDTH{1'b0}};
                         
assign fp_b_tdata   = (unit_active == UNIT_DQA) ? dqa_fp_b_tdata  : 
                         // (unit_active == UNIT_NN) ? nn_fp_b_tdata   :  // nn_lut_unit 未启用
                         (unit_active == UNIT_QA) ? qa_fp_b_tdata   :
                                                         {FP_CORE_NUM*FP_WIDTH{1'b0}};
                         
assign fp_c_tdata   = (unit_active == UNIT_DQA) ? dqa_fp_c_tdata  : 
                         // (unit_active == UNIT_NN) ? nn_fp_c_tdata   :  // nn_lut_unit 未启用
                         (unit_active == UNIT_QA) ? qa_fp_c_tdata   :
                                                         {FP_CORE_NUM*FP_WIDTH{1'b0}};

  fp_mac_array #(
    .FP_CORE_NUM(FP_CORE_NUM)
  ) fp_mac_array_inst(
    .clk(clk),
    .fp_array_tvalid(fp_array_tvalid),
    .fp_array_tready(fp_array_tready),
    .a_tdata(fp_a_tdata),        // packed: core0 LSB .. coreN MSB
    .b_tdata(fp_b_tdata),
    .c_tdata(fp_c_tdata),        // bias inputs
    .res(fp_res),      // each core's 16-bit result
    .res_tvalid(fp_res_tvalid)
);

  // --------------------------------------------------
  // chip-v3: VPU 内部 gb_* 信号经 1 级 pipeline 输出到 vpu_buf（8MB, ADDR_WIDTH=19）
  //   - 加 pipeline 是为了打断 addr 计算 + MUX → URAM 的组合路径，消除 setup violation
  //   - gb_addrb 是 GB_ADDR_WIDTH (24) 位字节地址 → obuf_addr 是 VPU_BUF_ADDR_WIDTH (19) 位 128-bit 字地址
  //   - gb_dinb/gb_doutb 128-bit 直通 obuf_din/obuf_dout
  //   - gb_web (NB_COL=16 bit byte enable) 直通 obuf_we
  //   - gb_enb 直通 obuf_en
  //   - 总读延迟: 1 (此 pipeline) + READ_LATENCY (XPM) = 11 cycles
  // --------------------------------------------------
  reg [`VPU_BUF_ADDR_WIDTH-1:0]    obuf_addr_r;
  reg                               obuf_en_r;
  reg [`DCIM_BUF_DATA_WIDTH/8-1:0]  obuf_we_r;
  reg [`DCIM_BUF_DATA_WIDTH-1:0]    obuf_din_r;

  always @(posedge clk) begin
      obuf_addr_r <= (unit_active == UNIT_IM2COL) ?
                     gb_addrb[GB_ADDR_WIDTH-1 : 4] :  // im2col: 字节地址 >> 4
                     gb_addrb[`VPU_BUF_ADDR_WIDTH-1 : 0];  // 其他 unit: 已是 word 地址
      obuf_en_r   <= gb_enb;
      obuf_we_r   <= gb_web;
      obuf_din_r  <= gb_dinb;
  end

  assign obuf_addr = obuf_addr_r;
  assign obuf_en   = obuf_en_r;
  assign obuf_we   = obuf_we_r;
  assign obuf_din  = obuf_din_r;
  assign gb_doutb  = obuf_dout;

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
    .rsta(1'b0),
    .rstb(1'b0),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(wb_douta),
    .doutb(wb_doutb)
  );


endmodule
