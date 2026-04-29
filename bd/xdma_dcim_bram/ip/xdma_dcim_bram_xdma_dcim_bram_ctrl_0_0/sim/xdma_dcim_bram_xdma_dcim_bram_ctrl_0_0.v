// (c) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// (c) Copyright 2022-2026 Advanced Micro Devices, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of AMD and is protected under U.S. and international copyright
// and other intellectual property laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// AMD, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) AMD shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or AMD had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// AMD products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of AMD products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:module_ref:xdma_dcim_bram_ctrl_top:1.0
// IP Revision: 1

`timescale 1ns/1ps

(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0 (
  aclk,
  aresetn,
  s_axil_awaddr,
  s_axil_awvalid,
  s_axil_awready,
  s_axil_wdata,
  s_axil_wstrb,
  s_axil_wvalid,
  s_axil_wready,
  s_axil_bresp,
  s_axil_bvalid,
  s_axil_bready,
  s_axil_araddr,
  s_axil_arvalid,
  s_axil_arready,
  s_axil_rdata,
  s_axil_rresp,
  s_axil_rvalid,
  s_axil_rready,
  m_axil_cdma_awaddr,
  m_axil_cdma_awvalid,
  m_axil_cdma_awready,
  m_axil_cdma_wdata,
  m_axil_cdma_wstrb,
  m_axil_cdma_wvalid,
  m_axil_cdma_wready,
  m_axil_cdma_bresp,
  m_axil_cdma_bvalid,
  m_axil_cdma_bready,
  m_axil_cdma_araddr,
  m_axil_cdma_arvalid,
  m_axil_cdma_arready,
  m_axil_cdma_rdata,
  m_axil_cdma_rresp,
  m_axil_cdma_rvalid,
  m_axil_cdma_rready,
  local_bram_en,
  local_bram_we,
  local_bram_addr,
  local_bram_din,
  local_bram_dout
);

(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s_axil:m_axil_cdma, ASSOCIATED_RESET aresetn, FREQ_HZ 250000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN xdma_dcim_bram_xdma_0_0_axi_aclk, INSERT_VIP 0" *)
input wire aclk;
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *)
input wire aresetn;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *)
(* X_INTERFACE_MODE = "slave" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 250000000, ID_WIDTH 0, ADDR_WIDTH 12, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN xdma_dcim_bram_xdma_0_0_axi_aclk, NUM_READ_THREADS 1, NUM_W\
RITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
input wire [11 : 0] s_axil_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *)
input wire s_axil_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *)
output wire s_axil_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *)
input wire [31 : 0] s_axil_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *)
input wire [3 : 0] s_axil_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *)
input wire s_axil_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *)
output wire s_axil_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *)
output wire [1 : 0] s_axil_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *)
output wire s_axil_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *)
input wire s_axil_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *)
input wire [11 : 0] s_axil_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *)
input wire s_axil_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *)
output wire s_axil_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *)
output wire [31 : 0] s_axil_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *)
output wire [1 : 0] s_axil_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *)
output wire s_axil_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *)
input wire s_axil_rready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWADDR" *)
(* X_INTERFACE_MODE = "master" *)
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axil_cdma, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 250000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN xdma_dcim_bram_xdma_0_0_axi_aclk, NUM_READ_THREADS 1, \
NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
output wire [31 : 0] m_axil_cdma_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWVALID" *)
output wire m_axil_cdma_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWREADY" *)
input wire m_axil_cdma_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WDATA" *)
output wire [31 : 0] m_axil_cdma_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WSTRB" *)
output wire [3 : 0] m_axil_cdma_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WVALID" *)
output wire m_axil_cdma_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WREADY" *)
input wire m_axil_cdma_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BRESP" *)
input wire [1 : 0] m_axil_cdma_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BVALID" *)
input wire m_axil_cdma_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BREADY" *)
output wire m_axil_cdma_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARADDR" *)
output wire [31 : 0] m_axil_cdma_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARVALID" *)
output wire m_axil_cdma_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARREADY" *)
input wire m_axil_cdma_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RDATA" *)
input wire [31 : 0] m_axil_cdma_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RRESP" *)
input wire [1 : 0] m_axil_cdma_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RVALID" *)
input wire m_axil_cdma_rvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RREADY" *)
output wire m_axil_cdma_rready;
output wire local_bram_en;
output wire [31 : 0] local_bram_we;
output wire [31 : 0] local_bram_addr;
output wire [255 : 0] local_bram_din;
input wire [255 : 0] local_bram_dout;

  xdma_dcim_bram_ctrl_top #(
    .AXIL_ADDR_WIDTH(12),
    .AXIL_DATA_WIDTH(32),
    .BRAM_ADDR_WIDTH(32),
    .BRAM_DATA_WIDTH(256),
    .GLOBAL_BASE_ADDR(32'H10000000),
    .LOCAL_BASE_ADDR(32'H10010000),
    .DCIM_WD1(4),
    .DCIM_CH_IN(16),
    .DCIM_CH_OUT(16),
    .DCIM_ACC_MAX(16)
  ) inst (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .m_axil_cdma_awaddr(m_axil_cdma_awaddr),
    .m_axil_cdma_awvalid(m_axil_cdma_awvalid),
    .m_axil_cdma_awready(m_axil_cdma_awready),
    .m_axil_cdma_wdata(m_axil_cdma_wdata),
    .m_axil_cdma_wstrb(m_axil_cdma_wstrb),
    .m_axil_cdma_wvalid(m_axil_cdma_wvalid),
    .m_axil_cdma_wready(m_axil_cdma_wready),
    .m_axil_cdma_bresp(m_axil_cdma_bresp),
    .m_axil_cdma_bvalid(m_axil_cdma_bvalid),
    .m_axil_cdma_bready(m_axil_cdma_bready),
    .m_axil_cdma_araddr(m_axil_cdma_araddr),
    .m_axil_cdma_arvalid(m_axil_cdma_arvalid),
    .m_axil_cdma_arready(m_axil_cdma_arready),
    .m_axil_cdma_rdata(m_axil_cdma_rdata),
    .m_axil_cdma_rresp(m_axil_cdma_rresp),
    .m_axil_cdma_rvalid(m_axil_cdma_rvalid),
    .m_axil_cdma_rready(m_axil_cdma_rready),
    .local_bram_en(local_bram_en),
    .local_bram_we(local_bram_we),
    .local_bram_addr(local_bram_addr),
    .local_bram_din(local_bram_din),
    .local_bram_dout(local_bram_dout)
  );
endmodule
