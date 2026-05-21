`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// CDMA_Controller_wrapper - Verilog wrapper for SystemVerilog CDMA_Controller
//
// 用于在 Vivado Block Design 中实例化 SystemVerilog 模块
//////////////////////////////////////////////////////////////////////////////////

module CDMA_Controller_wrapper #(
    parameter CDMA_BASE_ADDR = 0,
    parameter C_CDMA_AXILM_ADDR_WIDTH = 32,
    parameter C_CDMA_AXILM_DATA_WIDTH = 32
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cdma_start,
    input  wire        cdma_config_valid,
    output wire        cdma_config_ready,
    input  wire [31:0] cdma_src_addr_msb,
    input  wire [31:0] cdma_src_addr_lsb,
    input  wire [31:0] cdma_dst_addr_msb,
    input  wire [31:0] cdma_dst_addr_lsb,
    input  wire [31:0] cdma_length,
    
    // CDMA AXI-Lite Master 接口
    output wire [C_CDMA_AXILM_ADDR_WIDTH-1:0] cdma_axilm_awaddr,
    output wire [2:0]                         cdma_axilm_awprot,
    output wire                               cdma_axilm_awvalid,
    input  wire                               cdma_axilm_awready,
    output wire [C_CDMA_AXILM_DATA_WIDTH-1:0] cdma_axilm_wdata,
    output wire [C_CDMA_AXILM_DATA_WIDTH/8-1:0] cdma_axilm_wstrb,
    output wire                               cdma_axilm_wvalid,
    input  wire                               cdma_axilm_wready,
    input  wire [1:0]                         cdma_axilm_bresp,
    input  wire                               cdma_axilm_bvalid,
    output wire                               cdma_axilm_bready,
    output wire [C_CDMA_AXILM_ADDR_WIDTH-1:0] cdma_axilm_araddr,
    output wire [2:0]                         cdma_axilm_arprot,
    output wire                               cdma_axilm_arvalid,
    input  wire                               cdma_axilm_arready,
    input  wire [C_CDMA_AXILM_DATA_WIDTH-1:0] cdma_axilm_rdata,
    input  wire [1:0]                         cdma_axilm_rresp,
    input  wire                               cdma_axilm_rvalid,
    output wire                               cdma_axilm_rready
);

    // 实例化 SystemVerilog 模块
    CDMA_Controller #(
        .CDMA_BASE_ADDR(CDMA_BASE_ADDR),
        .C_CDMA_AXILM_ADDR_WIDTH(C_CDMA_AXILM_ADDR_WIDTH),
        .C_CDMA_AXILM_DATA_WIDTH(C_CDMA_AXILM_DATA_WIDTH)
    ) cdma_controller_sv (
        .clk(clk),
        .rst_n(rst_n),
        .cdma_start(cdma_start),
        .cdma_config_valid(cdma_config_valid),
        .cdma_config_ready(cdma_config_ready),
        .cdma_src_addr_msb(cdma_src_addr_msb),
        .cdma_src_addr_lsb(cdma_src_addr_lsb),
        .cdma_dst_addr_msb(cdma_dst_addr_msb),
        .cdma_dst_addr_lsb(cdma_dst_addr_lsb),
        .cdma_length(cdma_length),
        
        .cdma_axilm_awaddr(cdma_axilm_awaddr),
        .cdma_axilm_awprot(cdma_axilm_awprot),
        .cdma_axilm_awvalid(cdma_axilm_awvalid),
        .cdma_axilm_awready(cdma_axilm_awready),
        .cdma_axilm_wdata(cdma_axilm_wdata),
        .cdma_axilm_wstrb(cdma_axilm_wstrb),
        .cdma_axilm_wvalid(cdma_axilm_wvalid),
        .cdma_axilm_wready(cdma_axilm_wready),
        .cdma_axilm_bresp(cdma_axilm_bresp),
        .cdma_axilm_bvalid(cdma_axilm_bvalid),
        .cdma_axilm_bready(cdma_axilm_bready),
        .cdma_axilm_araddr(cdma_axilm_araddr),
        .cdma_axilm_arprot(cdma_axilm_arprot),
        .cdma_axilm_arvalid(cdma_axilm_arvalid),
        .cdma_axilm_arready(cdma_axilm_arready),
        .cdma_axilm_rdata(cdma_axilm_rdata),
        .cdma_axilm_rresp(cdma_axilm_rresp),
        .cdma_axilm_rvalid(cdma_axilm_rvalid),
        .cdma_axilm_rready(cdma_axilm_rready)
    );

endmodule
