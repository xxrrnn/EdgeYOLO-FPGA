`timescale 1ns/1ps

// Global Buffer AXI 控制器 - 这是对 Xilinx axi_bram_ctrl IP 的封装
// 该模块会在综合时被 IP 核替换
module gb_axi_controller (
    // AXI Slave 接口
    input wire        s_axi_aclk,
    input wire        s_axi_aresetn,
    
    // Write Address Channel
    input wire [21:0] s_axi_awaddr,
    input wire [7:0]  s_axi_awlen,
    input wire [2:0]  s_axi_awsize,
    input wire [1:0]  s_axi_awburst,
    input wire        s_axi_awlock,
    input wire [3:0]  s_axi_awcache,
    input wire [2:0]  s_axi_awprot,
    input wire        s_axi_awvalid,
    output wire       s_axi_awready,
    
    // Write Data Channel
    input wire [255:0] s_axi_wdata,
    input wire [31:0]  s_axi_wstrb,
    input wire         s_axi_wlast,
    input wire         s_axi_wvalid,
    output wire        s_axi_wready,
    
    // Write Response Channel
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input wire         s_axi_bready,
    
    // Read Address Channel
    input wire [21:0]  s_axi_araddr,
    input wire [7:0]   s_axi_arlen,
    input wire [2:0]   s_axi_arsize,
    input wire [1:0]   s_axi_arburst,
    input wire         s_axi_arlock,
    input wire [3:0]   s_axi_arcache,
    input wire [2:0]   s_axi_arprot,
    input wire         s_axi_arvalid,
    output wire        s_axi_arready,
    
    // Read Data Channel
    output wire [255:0] s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rlast,
    output wire         s_axi_rvalid,
    input wire          s_axi_rready,
    
    // BRAM 接口
    output wire         bram_rst_a,
    output wire         bram_clk_a,
    output wire         bram_en_a,
    output wire [31:0]  bram_we_a,
    output wire [21:0]  bram_addr_a,
    output wire [255:0] bram_wrdata_a,
    input wire  [255:0] bram_rddata_a
);

    // 此模块将由 TCL 脚本在 BD 中实例化为 axi_bram_ctrl IP
    // 这里提供占位符实现以便于 RTL 仿真
    
    assign bram_rst_a = 1'b0;
    assign bram_clk_a = s_axi_aclk;
    assign bram_en_a = 1'b0;
    assign bram_we_a = 32'd0;
    assign bram_addr_a = 22'd0;
    assign bram_wrdata_a = 256'd0;
    
    assign s_axi_awready = 1'b0;
    assign s_axi_wready = 1'b0;
    assign s_axi_bresp = 2'b00;
    assign s_axi_bvalid = 1'b0;
    assign s_axi_arready = 1'b0;
    assign s_axi_rdata = 256'd0;
    assign s_axi_rresp = 2'b00;
    assign s_axi_rlast = 1'b0;
    assign s_axi_rvalid = 1'b0;

endmodule
