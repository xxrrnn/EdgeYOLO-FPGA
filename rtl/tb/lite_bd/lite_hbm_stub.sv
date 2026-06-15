`timescale 1ns/1ns
// Module-TB 快速仿真 stub：替换 HBM 完整行为模型
// 输出：apb_complete_0=1（SmartConnect 认为 HBM ready），
//       AXI 响应均为零（module_tb 不通过 HBM 访问）
// 去除 HBM PHY calibration 仿真序列，消除 INFL_DELTA 事件风暴

module lite_hbm_0_0 (
    input  wire         HBM_REF_CLK_0,
    input  wire         AXI_00_ACLK,
    input  wire         AXI_00_ARESET_N,
    input  wire [32:0]  AXI_00_ARADDR,
    input  wire [1:0]   AXI_00_ARBURST,
    input  wire [5:0]   AXI_00_ARID,
    input  wire [3:0]   AXI_00_ARLEN,
    input  wire [2:0]   AXI_00_ARSIZE,
    input  wire         AXI_00_ARVALID,
    input  wire [32:0]  AXI_00_AWADDR,
    input  wire [1:0]   AXI_00_AWBURST,
    input  wire [5:0]   AXI_00_AWID,
    input  wire [3:0]   AXI_00_AWLEN,
    input  wire [2:0]   AXI_00_AWSIZE,
    input  wire         AXI_00_AWVALID,
    input  wire         AXI_00_RREADY,
    input  wire         AXI_00_BREADY,
    input  wire [255:0] AXI_00_WDATA,
    input  wire         AXI_00_WLAST,
    input  wire [31:0]  AXI_00_WSTRB,
    input  wire [31:0]  AXI_00_WDATA_PARITY,
    input  wire         AXI_00_WVALID,
    input  wire         APB_0_PCLK,
    input  wire         APB_0_PRESET_N,
    output wire         AXI_00_ARREADY,
    output wire         AXI_00_AWREADY,
    output wire [31:0]  AXI_00_RDATA_PARITY,
    output wire [255:0] AXI_00_RDATA,
    output wire [5:0]   AXI_00_RID,
    output wire         AXI_00_RLAST,
    output wire [1:0]   AXI_00_RRESP,
    output wire         AXI_00_RVALID,
    output wire         AXI_00_WREADY,
    output wire [5:0]   AXI_00_BID,
    output wire [1:0]   AXI_00_BRESP,
    output wire         AXI_00_BVALID,
    output wire         apb_complete_0,
    output wire         DRAM_0_STAT_CATTRIP,
    output wire [6:0]   DRAM_0_STAT_TEMP
);
    assign AXI_00_ARREADY      = 1'b0;
    assign AXI_00_AWREADY      = 1'b0;
    assign AXI_00_RDATA_PARITY = 32'b0;
    assign AXI_00_RDATA        = 256'b0;
    assign AXI_00_RID          = 6'b0;
    assign AXI_00_RLAST        = 1'b0;
    assign AXI_00_RRESP        = 2'b0;
    assign AXI_00_RVALID       = 1'b0;
    assign AXI_00_WREADY       = 1'b0;
    assign AXI_00_BID          = 6'b0;
    assign AXI_00_BRESP        = 2'b0;
    assign AXI_00_BVALID       = 1'b0;
    assign apb_complete_0      = 1'b1;   // HBM 校准立即完成
    assign DRAM_0_STAT_CATTRIP = 1'b0;
    assign DRAM_0_STAT_TEMP    = 7'b0;
endmodule
