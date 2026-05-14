`timescale 1ns/1ps

module Global_VPU_top #(
    parameter ADDR_WIDTH = 32,
    
    parameter GB_ADDR_WIDTH = 22,
    parameter C_INT_WIDTH_IN = 32,
    parameter BANDWIDTH = 32,

    parameter FP_CORE_NUM = 8,
    parameter FP_TRAN_NUM = 4,
    parameter FP_WIDTH    = 32,
    
    parameter WB_ADDR_WIDTH = 20,
    parameter MAX_CHANNEL_NUM = 256,

    parameter INTERVAL_NUM = 16,
    parameter RAM_DEPTH_GB    = 1024,
    parameter RAM_DEPTH_WB    = 1024,
    parameter Q_INT_WIDTH_OUT = 8
)(
    // **端口定义**
    // 控制和状态信号
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.CLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.CLK, ASSOCIATED_BUSIF wb_axis:gb_axis, ASSOCIATED_RESET rst_n, FREQ_HZ 250000000, PHASE 0.0, INSERT_VIP 0" *)
    input   wire                     clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RST_N RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RST_N, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
    input   wire                     rst_n,
    output  wire                     ready,        // 状态：VPU 准备好
    input   wire                     vpu_start,   // 控制：VPU 开始运行
      
    // 配置/地址输入
    input   wire[ADDR_WIDTH - 1:0]   unit_choose,
    input   wire[ADDR_WIDTH - 1:0]   src_addr,
    input   wire[ADDR_WIDTH - 1:0]   src2_addr,
    input   wire[ADDR_WIDTH - 1:0]   src_c,
    input   wire[ADDR_WIDTH - 1:0]   src_h,
    input   wire[ADDR_WIDTH - 1:0]   src_w,
    input   wire[ADDR_WIDTH - 1:0]   bias_addr,
    input   wire[ADDR_WIDTH - 1:0]   scale_addr,
    input   wire[ADDR_WIDTH - 1:0]   dst_addr,
    input   wire [ADDR_WIDTH-1:0]    addr_break,
    input   wire [ADDR_WIDTH-1:0]    addr_s,
    input   wire [ADDR_WIDTH-1:0]    addr_t,

    // input wire wb_axis_aclk,
    // input wire wb_axis_aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWADDR" *)
    (* X_INTERFACE_MODE = "Slave" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME wb_axis, PROTOCOL AXI4, ADDR_WIDTH 15, DATA_WIDTH 256, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, FREQ_HZ 250000000, INSERT_VIP 0" *)
    input wire [14 : 0] wb_axis_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWLEN" *)
    input wire [7 : 0] wb_axis_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWSIZE" *)
    input wire [2 : 0] wb_axis_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWBURST" *)
    input wire [1 : 0] wb_axis_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWLOCK" *)
    input wire wb_axis_awlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWCACHE" *)
    input wire [3 : 0] wb_axis_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWPROT" *)
    input wire [2 : 0] wb_axis_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWVALID" *)
    input wire wb_axis_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis AWREADY" *)
    output wire wb_axis_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis WDATA" *)
    input wire [255 : 0] wb_axis_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis WSTRB" *)
    input wire [31 : 0] wb_axis_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis WLAST" *)
    input wire wb_axis_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis WVALID" *)
    input wire wb_axis_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis WREADY" *)
    output wire wb_axis_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis BRESP" *)
    output wire [1 : 0] wb_axis_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis BVALID" *)
    output wire wb_axis_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis BREADY" *)
    input wire wb_axis_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARADDR" *)
    input wire [14 : 0] wb_axis_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARLEN" *)
    input wire [7 : 0] wb_axis_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARSIZE" *)
    input wire [2 : 0] wb_axis_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARBURST" *)
    input wire [1 : 0] wb_axis_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARLOCK" *)
    input wire wb_axis_arlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARCACHE" *)
    input wire [3 : 0] wb_axis_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARPROT" *)
    input wire [2 : 0] wb_axis_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARVALID" *)
    input wire wb_axis_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis ARREADY" *)
    output wire wb_axis_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis RDATA" *)
    output wire [255 : 0] wb_axis_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis RRESP" *)
    output wire [1 : 0] wb_axis_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis RLAST" *)
    output wire wb_axis_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis RVALID" *)
    output wire wb_axis_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 wb_axis RREADY" *)
    input wire wb_axis_rready,

    // input wire gb_axis_aclk,
    // input wire gb_axis_aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWADDR" *)
    (* X_INTERFACE_MODE = "Slave" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME gb_axis, PROTOCOL AXI4, ADDR_WIDTH 22, DATA_WIDTH 256, ID_WIDTH 0, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, FREQ_HZ 250000000, INSERT_VIP 0" *)
    input wire [21 : 0] gb_axis_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWLEN" *)
    input wire [7 : 0] gb_axis_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWSIZE" *)
    input wire [2 : 0] gb_axis_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWBURST" *)
    input wire [1 : 0] gb_axis_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWLOCK" *)
    input wire gb_axis_awlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWCACHE" *)
    input wire [3 : 0] gb_axis_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWPROT" *)
    input wire [2 : 0] gb_axis_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWVALID" *)
    input wire gb_axis_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis AWREADY" *)
    output wire gb_axis_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis WDATA" *)
    input wire [255 : 0] gb_axis_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis WSTRB" *)
    input wire [31 : 0] gb_axis_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis WLAST" *)
    input wire gb_axis_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis WVALID" *)
    input wire gb_axis_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis WREADY" *)
    output wire gb_axis_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis BRESP" *)
    output wire [1 : 0] gb_axis_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis BVALID" *)
    output wire gb_axis_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis BREADY" *)
    input wire gb_axis_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARADDR" *)
    input wire [21 : 0] gb_axis_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARLEN" *)
    input wire [7 : 0] gb_axis_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARSIZE" *)
    input wire [2 : 0] gb_axis_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARBURST" *)
    input wire [1 : 0] gb_axis_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARLOCK" *)
    input wire gb_axis_arlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARCACHE" *)
    input wire [3 : 0] gb_axis_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARPROT" *)
    input wire [2 : 0] gb_axis_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARVALID" *)
    input wire gb_axis_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis ARREADY" *)
    output wire gb_axis_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis RDATA" *)
    output wire [255 : 0] gb_axis_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis RRESP" *)
    output wire [1 : 0] gb_axis_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis RLAST" *)
    output wire gb_axis_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis RVALID" *)
    output wire gb_axis_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 gb_axis RREADY" *)
    input wire gb_axis_rready
);

    wire rst_n_axis;
    wire gb_axis_aclk;
    wire wb_axis_aclk;
    wire gb_axis_aresetn;
    wire wb_axis_aresetn;

    rst_n_sync rst_n_sync_axis_inst(
        .clk(clk),
        .rst_n_i(rst_n),
        .rst_n_o(rst_n_axis)
    );

    assign gb_axis_aclk = clk;
    assign wb_axis_aclk = clk;

    assign gb_axis_aresetn = rst_n_axis;
    assign wb_axis_aresetn = rst_n_axis;

    localparam RAM_PERFORMANCE = "LOW_LATENCY";
    localparam NB_COL = 32;
    localparam COL_WIDTH = 8;

    localparam BREAK_WIDTH = FP_WIDTH;
    localparam WEIGHT_WIDTH = FP_WIDTH;
    localparam BIAS_WIDTH = FP_WIDTH;

    localparam GB_BANDWIDTH = BANDWIDTH;
    localparam WB_BANDWIDTH = BANDWIDTH;

    // Global Buffer (GB) 接口 - 外部 RAM 接口
    wire [GB_ADDR_WIDTH-1:0]          gb_addra;
    wire [(NB_COL*COL_WIDTH)-1:0]     gb_dina;
    wire [NB_COL-1:0]                 gb_wea;
    wire                              gb_ena;
    wire [(NB_COL*COL_WIDTH)-1:0]     gb_douta;

    // Weight Buffer (WB) 接口 - 外部 RAM 接口
    wire [WB_ADDR_WIDTH-1:0]          wb_addra;
    wire [(NB_COL*COL_WIDTH)-1:0]     wb_dina;
    wire [NB_COL-1:0]                 wb_wea;
    wire                              wb_ena;
    wire [(NB_COL*COL_WIDTH)-1:0]    wb_douta;


    wb_axi_controller wb_control_inst (
        .s_axi_aclk(wb_axis_aclk),        // input wire s_axi_aclk
        .s_axi_aresetn(wb_axis_aresetn),  // input wire s_axi_aresetn
        .s_axi_awaddr(wb_axis_awaddr[14 : 0]),    // input wire [14 : 0] s_axi_awaddr
        .s_axi_awlen(wb_axis_awlen),      // input wire [7 : 0] s_axi_awlen
        .s_axi_awsize(wb_axis_awsize),    // input wire [2 : 0] s_axi_awsize
        .s_axi_awburst(wb_axis_awburst),  // input wire [1 : 0] s_axi_awburst
        .s_axi_awlock(wb_axis_awlock),    // input wire s_axi_awlock
        .s_axi_awcache(wb_axis_awcache),  // input wire [3 : 0] s_axi_awcache
        .s_axi_awprot(wb_axis_awprot),    // input wire [2 : 0] s_axi_awprot
        .s_axi_awvalid(wb_axis_awvalid),  // input wire s_axi_awvalid
        .s_axi_awready(wb_axis_awready),  // output wire s_axi_awready
        .s_axi_wdata(wb_axis_wdata),      // input wire [255 : 0] s_axi_wdata
        .s_axi_wstrb(wb_axis_wstrb),      // input wire [31 : 0] s_axi_wstrb
        .s_axi_wlast(wb_axis_wlast),      // input wire s_axi_wlast
        .s_axi_wvalid(wb_axis_wvalid),    // input wire s_axi_wvalid
        .s_axi_wready(wb_axis_wready),    // output wire s_axi_wready
        .s_axi_bresp(wb_axis_bresp),      // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid(wb_axis_bvalid),    // output wire s_axi_bvalid
        .s_axi_bready(wb_axis_bready),    // input wire s_axi_bready
        .s_axi_araddr(wb_axis_araddr[14 : 0]),    // input wire [14 : 0] s_axi_araddr
        .s_axi_arlen(wb_axis_arlen),      // input wire [7 : 0] s_axi_arlen
        .s_axi_arsize(wb_axis_arsize),    // input wire [2 : 0] s_axi_arsize
        .s_axi_arburst(wb_axis_arburst),  // input wire [1 : 0] s_axi_arburst
        .s_axi_arlock(wb_axis_arlock),    // input wire s_axi_arlock
        .s_axi_arcache(wb_axis_arcache),  // input wire [3 : 0] s_axi_arcache
        .s_axi_arprot(wb_axis_arprot),    // input wire [2 : 0] s_axi_arprot
        .s_axi_arvalid(wb_axis_arvalid),  // input wire s_axi_arvalid
        .s_axi_arready(wb_axis_arready),  // output wire s_axi_arready
        .s_axi_rdata(wb_axis_rdata),      // output wire [255 : 0] s_axi_rdata
        .s_axi_rresp(wb_axis_rresp),      // output wire [1 : 0] s_axi_rresp
        .s_axi_rlast(wb_axis_rlast),      // output wire s_axi_rlast
        .s_axi_rvalid(wb_axis_rvalid),    // output wire s_axi_rvalid
        .s_axi_rready(wb_axis_rready),    // input wire s_axi_rready
        .bram_rst_a(),        // output wire bram_rst_a
        .bram_clk_a(),        // output wire bram_clk_a
        .bram_en_a(wb_ena),          // output wire bram_en_a
        .bram_we_a(wb_wea),          // output wire [31 : 0] bram_we_a
        .bram_addr_a(wb_addra[14 : 0]),      // output wire [14 : 0] bram_addr_a
        .bram_wrdata_a(wb_dina),  // output wire [255 : 0] bram_wrdata_a
        .bram_rddata_a(wb_douta)  // input wire [255 : 0] bram_rddata_a
    );


    gb_axi_controller gb_axi_control_inst (
  .s_axi_aclk(gb_axis_aclk),        // input wire s_axi_aclk,
  .s_axi_aresetn(gb_axis_aresetn),  // input wire s_axi_aresetn,
  .s_axi_awaddr(gb_axis_awaddr[21 : 0]),    // input wire [21 : 0] s_axi_awaddr,
  .s_axi_awlen(gb_axis_awlen),      // input wire [7 : 0] s_axi_awlen,
  .s_axi_awsize(gb_axis_awsize),    // input wire [2 : 0] s_axi_awsize,
  .s_axi_awburst(gb_axis_awburst),  // input wire [1 : 0] s_axi_awburst,
  .s_axi_awlock(gb_axis_awlock),    // input wire s_axi_awlock,
  .s_axi_awcache(gb_axis_awcache),  // input wire [3 : 0] s_axi_awcache,
  .s_axi_awprot(gb_axis_awprot),    // input wire [2 : 0] s_axi_awprot,
  .s_axi_awvalid(gb_axis_awvalid),  // input wire s_axi_awvalid,
  .s_axi_awready(gb_axis_awready),  // output wire s_axi_awready,
  .s_axi_wdata(gb_axis_wdata),      // input wire [255 : 0] s_axi_wdata,
  .s_axi_wstrb(gb_axis_wstrb),      // input wire [31 : 0] s_axi_wstrb,
  .s_axi_wlast(gb_axis_wlast),      // input wire s_axi_wlast,
  .s_axi_wvalid(gb_axis_wvalid),    // input wire s_axi_wvalid,
  .s_axi_wready(gb_axis_wready),    // output wire s_axi_wready,
  .s_axi_bresp(gb_axis_bresp),      // output wire [1 : 0] s_axi_bresp,
  .s_axi_bvalid(gb_axis_bvalid),    // output wire s_axi_bvalid,
  .s_axi_bready(gb_axis_bready),    // input wire s_axi_bready,
  .s_axi_araddr(gb_axis_araddr[21 : 0]),    // input wire [21 : 0] s_axi_araddr,
  .s_axi_arlen(gb_axis_arlen),      // input wire [7 : 0] s_axi_arlen,
  .s_axi_arsize(gb_axis_arsize),    // input wire [2 : 0] s_axi_arsize,
  .s_axi_arburst(gb_axis_arburst),  // input wire [1 : 0] s_axi_arburst,
  .s_axi_arlock(gb_axis_arlock),    // input wire s_axi_arlock,
  .s_axi_arcache(gb_axis_arcache),  // input wire [3 : 0] s_axi_arcache,
  .s_axi_arprot(gb_axis_arprot),    // input wire [2 : 0] s_axi_arprot,
  .s_axi_arvalid(gb_axis_arvalid),  // input wire s_axi_arvalid,
  .s_axi_arready(gb_axis_arready),  // output wire s_axi_arready,
  .s_axi_rdata(gb_axis_rdata),      // output wire [255 : 0] s_axi_rdata,
  .s_axi_rresp(gb_axis_rresp),      // output wire [1 : 0] s_axi_rresp,
  .s_axi_rlast(gb_axis_rlast),      // output wire s_axi_rlast,
  .s_axi_rvalid(gb_axis_rvalid),    // output wire s_axi_rvalid,
  .s_axi_rready(gb_axis_rready),    // input wire s_axi_rready,
  .bram_rst_a(),        // output wire bram_rst_a
  .bram_clk_a(),        // output wire bram_clk_a
  .bram_en_a(gb_ena),          // output wire bram_en_a
  .bram_we_a(gb_wea),          // output wire [31 : 0] bram_we_a
  .bram_addr_a(gb_addra[21 : 0]),      // output wire [21 : 0] bram_addr_a
  .bram_wrdata_a(gb_dina),  // output wire [255 : 0] bram_wrdata_a
  .bram_rddata_a(gb_douta)  // input wire [255 : 0] bram_rddata_a
);


    // 实例化 Global_VPU 模块
    // 将顶层模块的参数传递给底层模块
    Global_VPU #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .C_INT_WIDTH_IN(C_INT_WIDTH_IN),
        .BANDWIDTH(BANDWIDTH),
        .FP_CORE_NUM(FP_CORE_NUM),
        .FP_TRAN_NUM(FP_TRAN_NUM),
        .FP_WIDTH(FP_WIDTH),
        .WB_ADDR_WIDTH(WB_ADDR_WIDTH),
        .MAX_CHANNEL_NUM(MAX_CHANNEL_NUM),
        .INTERVAL_NUM(INTERVAL_NUM),
        .RAM_DEPTH_GB(RAM_DEPTH_GB),
        .RAM_DEPTH_WB(RAM_DEPTH_WB),
        .Q_INT_WIDTH_OUT(Q_INT_WIDTH_OUT)
    )
    // 实例化名
    u_global_vpu (
        // 按名称连接端口，确保准确性
        .clk(clk),
        .rst_n(rst_n),
        .config_ready(ready),
        .config_valid(1'b1),      // 始终有效
        .start(vpu_start),
        .unit_choose(unit_choose),
        .src_addr(src_addr),
        .src2_addr(src2_addr),
        .src_c(src_c),
        .src_h(src_h),
        .src_w(src_w),
        .scale_addr(scale_addr),
        .bias_addr(bias_addr),
        .dst_addr(dst_addr),
        .addr_break(addr_break),
        .addr_s(addr_s),
        .addr_t(addr_t),
        .gb_addra(gb_addra),
        .gb_dina(gb_dina),
        .gb_wea(gb_wea),
        .gb_ena(gb_ena),
        .gb_douta(gb_douta),
        .wb_addra(wb_addra),
        .wb_dina(wb_dina),
        .wb_wea(wb_wea),
        .wb_ena(wb_ena),
        .wb_douta(wb_douta)
    );

endmodule
