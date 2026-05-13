`timescale 1ns/1ps
//==============================================================================
// Global_VPU：顶层封装各功能单元（ad/mp/us/qa/dqa/nn_lut）、FP MAC 阵列、
//             Global Buffer 与 Weight Buffer 互联；unit_choose 选择执行路径。
// 使用：vpu_start 启动任务；ready 为高时可下发；src/dst 等地址端口含义随所选
//      单元而定（与各 *_unit 端口一致）。参数需与 BRAM 深度、数据位宽一致。
//==============================================================================
module Global_VPU #(
    parameter ADDR_WIDTH = 32,
    
    parameter GB_ADDR_WIDTH = 20,
    parameter C_INT_WIDTH_IN = 32,
    parameter BANDWIDTH = 256,    // 修正：与 axi_bram_ctrl DATA_WIDTH 一致

    parameter FP_CORE_NUM = 32,
    parameter FP_TRAN_NUM = 8,
    parameter FP_WIDTH    = 32,
    
    parameter WB_ADDR_WIDTH = 20,
    parameter MAX_CHANNEL_NUM = 256,

    parameter INTERVAL_NUM = 16,
    parameter RAM_DEPTH_GB    = 1024,
    parameter RAM_DEPTH_WB    = 1024,
    parameter Q_INT_WIDTH_OUT = 8,
    
    parameter NB_COL = 32,
    parameter COL_WIDTH = 8
    
    


)(
    input   wire                     clk,
    input   wire                     rst_n,
    output   wire                    ready,
    input   wire                     vpu_start,
      
    input   wire[ADDR_WIDTH - 1:0]   unit_choose,

    input   wire[ADDR_WIDTH - 1:0]   src_addr,
    input   wire[ADDR_WIDTH - 1:0]   src2_addr,
    input   wire[ADDR_WIDTH - 1:0]   src_c,
    input   wire[ADDR_WIDTH - 1:0]   src_h,
    input   wire[ADDR_WIDTH - 1:0]   src_w,
    input   wire[ADDR_WIDTH - 1:0]   scale_addr,
    input   wire[ADDR_WIDTH - 1:0]   bias_addr,
    input   wire[ADDR_WIDTH - 1:0]   dst_addr,

    input wire [ADDR_WIDTH-1:0]      addr_break,
    input wire [ADDR_WIDTH-1:0]      addr_s,
    input wire [ADDR_WIDTH-1:0]      addr_t,

    input wire [GB_ADDR_WIDTH-1:0]          gb_addra,
    input wire [(NB_COL*COL_WIDTH)-1:0]     gb_dina,
    input wire [NB_COL-1:0]                 gb_wea,
    input wire                              gb_ena,
    output wire [(NB_COL*COL_WIDTH)-1:0]    gb_douta,

    input wire [WB_ADDR_WIDTH-1:0]          wb_addra,
    input wire [(NB_COL*COL_WIDTH)-1:0]     wb_dina,
    input wire [NB_COL-1:0]                 wb_wea,
    input wire                              wb_ena,
    output wire [(NB_COL*COL_WIDTH)-1:0]    wb_douta
);
  localparam RAM_PERFORMANCE = "LOW_LATENCY";

  
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

  // -------------------------------
  // Internal registers
  // -------------------------------
  // reg [ADDR_WIDTH - 1:0]   unit_choose;
  // reg [ADDR_WIDTH - 1:0]   src_addr;
  // reg [ADDR_WIDTH - 1:0]   src_c;
  // reg [ADDR_WIDTH - 1:0]   src_h;
  // reg [ADDR_WIDTH - 1:0]   src_w;
  // reg [ADDR_WIDTH - 1:0]   scale_addr;
  // reg [ADDR_WIDTH - 1:0]   dst_addr;
  // reg [ADDR_WIDTH - 1:0]   addr_break;
  // reg [ADDR_WIDTH - 1:0]   addr_s;
  // reg [ADDR_WIDTH - 1:0]   addr_t;

  // 假设存在 vpu_config_valid/config_ready（仅修复语法）
  


    wire [GB_ADDR_WIDTH-1:0]    gb_addrb, dqa_gb_addrb, nn_gb_addrb, qa_gb_addrb, mp_gb_addrb, us_gb_addrb, ad_gb_addrb;
    wire [GB_BANDWIDTH-1:0]     gb_dinb, dqa_gb_dinb, nn_gb_dinb, qa_gb_dinb, mp_gb_dinb, us_gb_dinb,ad_gb_dinb;
    wire [GB_BANDWIDTH/8-1:0]   gb_web, dqa_gb_web, nn_gb_web, qa_gb_web, mp_gb_web, us_gb_web, ad_gb_web;
    wire                        gb_enb, dqa_gb_enb, nn_gb_enb, qa_gb_enb, mp_gb_enb, us_gb_enb, ad_gb_enb; 
    wire [GB_BANDWIDTH-1:0]     gb_doutb;
    
    wire [WB_ADDR_WIDTH-1:0]    wb_addrb, dqa_wb_addrb, nn_wb_addrb, qa_wb_addrb;
    wire [WB_BANDWIDTH-1:0]     wb_dinb, dqa_wb_dinb, nn_wb_dinb, qa_wb_dinb;
    wire [WB_BANDWIDTH/8-1:0]   wb_web, dqa_wb_web, nn_wb_web, qa_wb_web;
    wire                        wb_enb, dqa_wb_enb, nn_wb_enb, qa_wb_enb;
    wire [WB_BANDWIDTH-1:0]     wb_doutb;

    wire  dqa_fp_array_tvalid, nn_fp_array_tvalid, qa_fp_array_tvalid;
    wire mp_unit_start, us_unit_start, nn_unit_start, qa_unit_start, dqa_unit_start, ad_unit_start;
    wire mp_unit_ready, us_unit_ready, nn_unit_ready, qa_unit_ready, dqa_unit_ready, ad_unit_ready;

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



    mp_unit #(
      .ADDR_WIDTH         (ADDR_WIDTH),
      .GB_BANDWIDTH       (GB_BANDWIDTH),
      .GB_ADDR_WIDTH      (GB_ADDR_WIDTH),
      .FP_WIDTH      (FP_WIDTH),
      .MAX_CHANNEL_NUM (MAX_CHANNEL_NUM)
  ) i_mp_unit (
      .clk                (clk),
      .rst_n              (rst_n),
      .mp_unit_start      (mp_unit_start),
      .mp_unit_ready      (mp_unit_ready),
      
      .mp_src_addr        (src_addr),
      .mp_src_h           (src_h),
      .mp_src_w           (src_w),
      .mp_src_c           (src_c),
      .mp_dst_addr        (dst_addr),
      
      // GB 接口输出 (需要 MUX 到顶层 top_gb_* 信号)
      .gb_addrb           (mp_gb_addrb), 
      .gb_dinb            (mp_gb_dinb), 
      .gb_web             (mp_gb_web),
      .gb_enb             (mp_gb_enb),
      .gb_doutb           (gb_doutb)   // 连接顶层 GB BRAM 的输出
  );


    us_unit #(
      .ADDR_WIDTH         (ADDR_WIDTH),
      .GB_BANDWIDTH       (GB_BANDWIDTH),
      .GB_ADDR_WIDTH      (GB_ADDR_WIDTH),
      .FP_WIDTH      (FP_WIDTH),
      .MAX_MP_CHANNEL_NUM (MAX_CHANNEL_NUM)
  ) i_us_unit (
      .clk                (clk),
      .rst_n              (rst_n),
      .us_unit_start      (us_unit_start),
      .us_unit_ready      (us_unit_ready),
      
      .us_src_addr        (src_addr),
      .us_src_h           (src_h),
      .us_src_w           (src_w),
      .us_src_c           (src_c),
      .us_dst_addr        (dst_addr),
      
      // GB 接口输出 (需要 MUX 到顶层 top_gb_* 信号)
      .gb_addrb           (us_gb_addrb), 
      .gb_dinb            (us_gb_dinb), 
      .gb_web             (us_gb_web),
      .gb_enb             (us_gb_enb),
      .gb_doutb           (gb_doutb)   // 连接顶层 GB BRAM 的输出
  );

/* 暂时注释 nn_lut_unit，简化上板调试
nn_lut_unit #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INTERVAL_NUM(INTERVAL_NUM),
    .BREAK_WIDTH(BREAK_WIDTH),
    .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .BIAS_WIDTH(BIAS_WIDTH),
    .FP_CORE_NUM(FP_CORE_NUM),
    .FP_WIDTH(FP_WIDTH),
    .WB_BANDWIDTH(WB_BANDWIDTH),
    .RAM_DEPTH_WB(RAM_DEPTH_WB),
    .GB_BANDWIDTH(GB_BANDWIDTH),
    .GB_ADDR_WIDTH(GB_ADDR_WIDTH)
)nn_lut_inst(
    // --- Control/Status Ports ---
    .clk(clk),
    .rst_n(rst_n),
    .nn_unit_start(nn_unit_start),
    .nn_unit_ready(nn_unit_ready),
    
    // --- Configuration/Address Ports ---
    .nn_addr_break(addr_break),
    .nn_addr_s(addr_s),
    .nn_addr_t(addr_t),
    .nn_src_addr(src_addr),
    .nn_src_c(src_c),
    .nn_src_h(src_h),
    .nn_src_w(src_w),
    .nn_dst_addr(dst_addr),

    // --- Floating Point Array Ports (AXI Stream-like interfaces) ---
    .fp_array_tready(fp_array_tready),
    .fp_array_tvalid(nn_fp_array_tvalid),
    .fp_a_tdata(nn_fp_a_tdata), 
    .fp_b_tdata(nn_fp_b_tdata),
    .fp_c_tdata(nn_fp_c_tdata),
    .fp_res(fp_res),
    .fp_res_tvalid(fp_res_tvalid),

    // --- Global Buffer (GB) Ports (Simple Dual-Port BRAM-like interface) ---
    .gb_addrb(nn_gb_addrb), 
    .gb_dinb(nn_gb_dinb),  
    .gb_web(nn_gb_web),   
    .gb_enb(nn_gb_enb),    
    .gb_doutb(gb_doutb),

    // --- Weight Buffer (WB) Ports (Simple Dual-Port BRAM-like interface) ---
    .wb_addrb(nn_wb_addrb),
    .wb_dinb(nn_wb_dinb),
    .wb_web(nn_wb_web),
    .wb_enb(nn_wb_enb),
    .wb_doutb(wb_doutb)
);
*/

// nn_lut_unit 暂时注释，所有输出置零
assign nn_unit_ready = 1'b1;
assign nn_fp_array_tvalid = 1'b0;
assign nn_fp_a_tdata = {FP_CORE_NUM*FP_WIDTH{1'b0}};
assign nn_fp_b_tdata = {FP_CORE_NUM*FP_WIDTH{1'b0}};
assign nn_fp_c_tdata = {FP_CORE_NUM*FP_WIDTH{1'b0}};
assign nn_gb_addrb = {GB_ADDR_WIDTH{1'b0}};
assign nn_gb_dinb = {GB_BANDWIDTH{1'b0}};
assign nn_gb_web = {(GB_BANDWIDTH/8){1'b0}};
assign nn_gb_enb = 1'b0;
assign nn_wb_addrb = {WB_ADDR_WIDTH{1'b0}};
assign nn_wb_dinb = {WB_BANDWIDTH{1'b0}};
assign nn_wb_web = {(WB_BANDWIDTH/8){1'b0}};
assign nn_wb_enb = 1'b0;



// Instantiate the qa_unit module
  qa_unit #(
      // --- Parameter Overrides ---
      .ADDR_WIDTH(ADDR_WIDTH),
      .GB_BANDWIDTH(GB_BANDWIDTH),
      .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
      .WB_BANDWIDTH(WB_BANDWIDTH),
      .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
      .FP_CORE_NUM(FP_CORE_NUM),
      .FP_WIDTH(FP_WIDTH),
      .Q_INT_WIDTH_OUT(Q_INT_WIDTH_OUT),
      .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM)
  ) u_qa_unit (
      // --- Control/Status Ports ---
      .clk(clk),
      .rst_n(rst_n),
      .qa_unit_start(qa_unit_start),
      .qa_unit_ready(qa_unit_ready),
      
      // --- Configuration/Address Ports ---
      .qa_src_addr(src_addr),
      .qa_src_c(src_c),
      .qa_src_h(src_h),
      .qa_src_w(src_w),
      .qa_scale_addr(scale_addr),
      .qa_dst_addr(dst_addr),

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
        .rst_n(rst_n),
        .ad_unit_start(ad_unit_start),
        .ad_unit_ready(ad_unit_ready),
        .ad_src_addr(src_addr),
        .ad_src2_addr(src2_addr),
        .ad_src_c(src_c),
        .ad_src_h(src_h),
        .ad_src_w(src_w),
        .ad_dst_addr(dst_addr),

        .gb_addrb( ad_gb_addrb),
        .gb_dinb( ad_gb_dinb),
        .gb_web( ad_gb_web),
        .gb_enb( ad_gb_enb),
        .gb_doutb(gb_doutb)

    );











    dqa_unit #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .GB_BANDWIDTH(GB_BANDWIDTH),
      .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
      .C_INT_WIDTH_IN(C_INT_WIDTH_IN),
      .FP_CORE_NUM(FP_CORE_NUM),
      .FP_TRAN_NUM(FP_TRAN_NUM),
      .FP_WIDTH(FP_WIDTH),
      .WB_BANDWIDTH(WB_BANDWIDTH),
      .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
      .MAX_CHANNEL_NUM(FP_CORE_NUM)
    ) dqa_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dqa_unit_start(dqa_unit_start),
        .dqa_unit_ready(dqa_unit_ready),
        .dqa_src_addr(src_addr),
        .dqa_src_c(src_c),
        .dqa_src_h(src_h),
        .dqa_src_w(src_w),
        .dqa_scale_addr(scale_addr),
        .dqa_bias_addr(bias_addr),
        .dqa_dst_addr(dst_addr),

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

        .wb_addrb( dqa_wb_addrb),
        .wb_dinb( dqa_wb_dinb),
        .wb_web( dqa_wb_web),
        .wb_enb( dqa_wb_enb),
        .wb_doutb(wb_doutb)
    );

    assign ready = nn_unit_ready & us_unit_ready & mp_unit_ready & qa_unit_ready & dqa_unit_ready & ad_unit_ready;
    assign dqa_unit_start = (unit_choose == UNIT_DQA) ? vpu_start : 1'b0;
    assign qa_unit_start  = (unit_choose == UNIT_QA ) ? vpu_start : 1'b0;
    assign nn_unit_start  = (unit_choose == UNIT_NN ) ? vpu_start : 1'b0;
    assign mp_unit_start  = (unit_choose == UNIT_MP ) ? vpu_start : 1'b0;
    assign us_unit_start  = (unit_choose == UNIT_US ) ? vpu_start : 1'b0;
    assign ad_unit_start  = (unit_choose == UNIT_AD ) ? vpu_start : 1'b0;


 // GB Address (Output from Unit to BRAM)
assign gb_addrb = (unit_choose == UNIT_DQA) ? dqa_gb_addrb : 
                  (unit_choose == UNIT_NN) ? nn_gb_addrb : 
                  (unit_choose == UNIT_QA) ? qa_gb_addrb : // Handles QA and SU due to 2'b11
                  (unit_choose == UNIT_MP) ? mp_gb_addrb : 
                  (unit_choose == UNIT_US) ? us_gb_addrb : 
                  (unit_choose == UNIT_AD) ? ad_gb_addrb : 
                                                  {GB_ADDR_WIDTH{1'b0}};

// GB Data Input (Output from Unit to BRAM write port)
assign gb_dinb = (unit_choose == UNIT_DQA) ? dqa_gb_dinb : 
                  (unit_choose == UNIT_NN) ? nn_gb_dinb  : 
                  (unit_choose == UNIT_QA) ? qa_gb_dinb  : // Handles QA and SU due to 2'b11
                  (unit_choose == UNIT_MP) ? mp_gb_dinb  : 
                  (unit_choose == UNIT_US) ? us_gb_dinb  : 
                  (unit_choose == UNIT_AD) ? ad_gb_dinb  : 
                                                  {GB_BANDWIDTH{1'b0}};

// GB Write Enable (Output from Unit to BRAM)
assign gb_web  = (unit_choose == UNIT_DQA) ? dqa_gb_web  : 
                  (unit_choose == UNIT_NN) ? nn_gb_web  : 
                  (unit_choose == UNIT_QA) ? qa_gb_web  : // Handles QA and SU due to 2'b11
                  (unit_choose == UNIT_MP) ? mp_gb_web  : 
                  (unit_choose == UNIT_US) ? us_gb_web  : 
                  (unit_choose == UNIT_AD) ? ad_gb_web  : 
                                                  {GB_BANDWIDTH/8{1'b0}};

// GB Enable (Output from Unit to BRAM)
assign gb_enb  = (unit_choose == UNIT_DQA) ? dqa_gb_enb  : 
                  (unit_choose == UNIT_NN) ? nn_gb_enb  : 
                  (unit_choose == UNIT_QA) ? qa_gb_enb  : // Handles QA and SU due to 2'b11
                  (unit_choose == UNIT_MP) ? mp_gb_enb  : 
                  (unit_choose == UNIT_US) ? us_gb_enb  : 
                  (unit_choose == UNIT_AD) ? ad_gb_enb  : 
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
assign wb_addrb = (unit_choose == UNIT_DQA) ? dqa_wb_addrb : 
                  (unit_choose == UNIT_NN) ? nn_wb_addrb : 
                  (unit_choose == UNIT_QA) ? qa_wb_addrb : // Handles QA and SU (but SU doesn't use it)
                                                  {WB_ADDR_WIDTH{1'b0}};

// WB Data Input (Output from Unit to BRAM write port)
assign wb_dinb = (unit_choose == UNIT_DQA) ? dqa_wb_dinb : 
                  (unit_choose == UNIT_NN) ? nn_wb_dinb  : 
                  (unit_choose == UNIT_QA) ? qa_wb_dinb  : // Handles QA and SU
                                                  {WB_BANDWIDTH{1'b0}};

// WB Write Enable (Output from Unit to BRAM)
assign wb_web  = (unit_choose == UNIT_DQA) ? dqa_wb_web  : 
                  (unit_choose == UNIT_NN) ? nn_wb_web  : 
                  (unit_choose == UNIT_QA) ? qa_wb_web  : // Handles QA and SU
                                                  {WB_BANDWIDTH/8{1'b0}};

// WB Enable (Output from Unit to BRAM)
assign wb_enb  = (unit_choose == UNIT_DQA) ? dqa_wb_enb  : 
                  (unit_choose == UNIT_NN) ? nn_wb_enb  : 
                  (unit_choose == UNIT_QA) ? qa_wb_enb  : // Handles QA and SU
                                                  1'b0;


// ----------------------------------------------------------------------
// 4. Floating Point (FP) MAC Array Muxing Logic (AXI-Stream like interface)
//    - FP 信号接入 DQA, NN, QA。SU 不接入。
// ----------------------------------------------------------------------

// FP Array Valid (Output from Unit to MAC Array)
assign fp_array_tvalid = (unit_choose == UNIT_DQA) ? dqa_fp_array_tvalid : 
                         (unit_choose == UNIT_NN) ? nn_fp_array_tvalid : 
                         (unit_choose == UNIT_QA) ? qa_fp_array_tvalid : // Handles QA and SU
                                                         1'b0;

// FP Array Data A (Operand A)
assign fp_a_tdata   = (unit_choose == UNIT_DQA) ? dqa_fp_a_tdata  : 
                         (unit_choose == UNIT_NN) ? nn_fp_a_tdata   : 
                         (unit_choose == UNIT_QA) ? qa_fp_a_tdata   : // Handles QA and SU
                                                         {FP_CORE_NUM*FP_WIDTH{1'b0}};
                         
// FP Array Data B (Operand B)
assign fp_b_tdata   = (unit_choose == UNIT_DQA) ? dqa_fp_b_tdata  : 
                         (unit_choose == UNIT_NN) ? nn_fp_b_tdata   : 
                         (unit_choose == UNIT_QA) ? qa_fp_b_tdata   : // Handles QA and SU
                                                         {FP_CORE_NUM*FP_WIDTH{1'b0}};
                         
// FP Array Data C (Bias/Accumulator)
assign fp_c_tdata   = (unit_choose == UNIT_DQA) ? dqa_fp_c_tdata  : 
                         (unit_choose == UNIT_NN) ? nn_fp_c_tdata   : 
                         (unit_choose == UNIT_QA) ? qa_fp_c_tdata   : // Handles QA and SU
                                                         {FP_CORE_NUM*FP_WIDTH{1'b0}};

// FP32 MAC 阵列：res = a*b + c（直接例化 IP，避免 BD 综合依赖问题）
assign fp_array_tready = 1'b1;

wire [FP_CORE_NUM-1:0] mult_tvalid_arr;
wire [FP_CORE_NUM*FP_WIDTH-1:0] mult_result;
wire [FP_CORE_NUM-1:0] add_tvalid_arr;

genvar mac_i;
generate
    for (mac_i = 0; mac_i < FP_CORE_NUM; mac_i = mac_i + 1) begin: FP32_MAC_LANE
        // 乘法：a * b
        fp32_mult_lane fp32_mult_inst (
            .aclk(clk),
            .aresetn(rst_n),
            .s_axis_a_tvalid(fp_array_tvalid),
            .s_axis_a_tdata(fp_a_tdata[mac_i*FP_WIDTH +: FP_WIDTH]),
            .s_axis_b_tvalid(fp_array_tvalid),
            .s_axis_b_tdata(fp_b_tdata[mac_i*FP_WIDTH +: FP_WIDTH]),
            .m_axis_result_tvalid(mult_tvalid_arr[mac_i]),
            .m_axis_result_tdata(mult_result[mac_i*FP_WIDTH +: FP_WIDTH])
        );

        // 加法：(a*b) + c
        fp32_add_lane fp32_add_inst (
            .aclk(clk),
            .aresetn(rst_n),
            .s_axis_a_tvalid(mult_tvalid_arr[mac_i]),
            .s_axis_a_tdata(mult_result[mac_i*FP_WIDTH +: FP_WIDTH]),
            .s_axis_b_tvalid(mult_tvalid_arr[mac_i]),
            .s_axis_b_tdata(fp_c_tdata[mac_i*FP_WIDTH +: FP_WIDTH]),
            .m_axis_result_tvalid(add_tvalid_arr[mac_i]),
            .m_axis_result_tdata(fp_res[mac_i*FP_WIDTH +: FP_WIDTH])
        );
    end
endgenerate

assign fp_res_tvalid = add_tvalid_arr[0];

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
    .rsta(~rst_n),
    .rstb(~rst_n),
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
    .rsta(~rst_n),
    .rstb(~rst_n),
    .regcea(1'b1),
    .regceb(1'b1),
    .douta(wb_douta),
    .doutb(wb_doutb)
  );


endmodule