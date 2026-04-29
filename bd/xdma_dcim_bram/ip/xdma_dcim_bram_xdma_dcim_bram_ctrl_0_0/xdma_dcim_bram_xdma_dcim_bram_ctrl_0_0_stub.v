// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2024.2.2 (lin64) Build 6060944 Thu Mar 06 19:10:09 MST 2025
// Date        : Wed Apr 29 20:22:28 2026
// Host        : DESKTOP-5NNBJ0V running 64-bit Ubuntu 22.04.1 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/triton/task/YOLO_on_FPGA/fpga/EdgeYOLO-FPGA/bd/xdma_dcim_bram/ip/xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0/xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0_stub.v
// Design      : xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xcvu37p-fsvh2892-2L-e
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* CHECK_LICENSE_TYPE = "xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0,xdma_dcim_bram_ctrl_top,{}" *) (* CORE_GENERATION_INFO = "xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0,xdma_dcim_bram_ctrl_top,{x_ipProduct=Vivado 2024.2.2,x_ipVendor=xilinx.com,x_ipLibrary=module_ref,x_ipName=xdma_dcim_bram_ctrl_top,x_ipVersion=1.0,x_ipCoreRevision=1,x_ipLanguage=VERILOG,x_ipSimLanguage=MIXED,AXIL_ADDR_WIDTH=12,AXIL_DATA_WIDTH=32,BRAM_ADDR_WIDTH=32,BRAM_DATA_WIDTH=256,GLOBAL_BASE_ADDR=0x10000000,LOCAL_BASE_ADDR=0x10010000,DCIM_WD1=4,DCIM_CH_IN=16,DCIM_CH_OUT=16,DCIM_ACC_MAX=16}" *) (* DowngradeIPIdentifiedWarnings = "yes" *) 
(* IP_DEFINITION_SOURCE = "module_ref" *) (* X_CORE_INFO = "xdma_dcim_bram_ctrl_top,Vivado 2024.2.2" *) 
module xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0(aclk, aresetn, s_axil_awaddr, s_axil_awvalid, 
  s_axil_awready, s_axil_wdata, s_axil_wstrb, s_axil_wvalid, s_axil_wready, s_axil_bresp, 
  s_axil_bvalid, s_axil_bready, s_axil_araddr, s_axil_arvalid, s_axil_arready, s_axil_rdata, 
  s_axil_rresp, s_axil_rvalid, s_axil_rready, m_axil_cdma_awaddr, m_axil_cdma_awvalid, 
  m_axil_cdma_awready, m_axil_cdma_wdata, m_axil_cdma_wstrb, m_axil_cdma_wvalid, 
  m_axil_cdma_wready, m_axil_cdma_bresp, m_axil_cdma_bvalid, m_axil_cdma_bready, 
  m_axil_cdma_araddr, m_axil_cdma_arvalid, m_axil_cdma_arready, m_axil_cdma_rdata, 
  m_axil_cdma_rresp, m_axil_cdma_rvalid, m_axil_cdma_rready, local_bram_en, local_bram_we, 
  local_bram_addr, local_bram_din, local_bram_dout)
/* synthesis syn_black_box black_box_pad_pin="aresetn,s_axil_awaddr[11:0],s_axil_awvalid,s_axil_awready,s_axil_wdata[31:0],s_axil_wstrb[3:0],s_axil_wvalid,s_axil_wready,s_axil_bresp[1:0],s_axil_bvalid,s_axil_bready,s_axil_araddr[11:0],s_axil_arvalid,s_axil_arready,s_axil_rdata[31:0],s_axil_rresp[1:0],s_axil_rvalid,s_axil_rready,m_axil_cdma_awaddr[31:0],m_axil_cdma_awvalid,m_axil_cdma_awready,m_axil_cdma_wdata[31:0],m_axil_cdma_wstrb[3:0],m_axil_cdma_wvalid,m_axil_cdma_wready,m_axil_cdma_bresp[1:0],m_axil_cdma_bvalid,m_axil_cdma_bready,m_axil_cdma_araddr[31:0],m_axil_cdma_arvalid,m_axil_cdma_arready,m_axil_cdma_rdata[31:0],m_axil_cdma_rresp[1:0],m_axil_cdma_rvalid,m_axil_cdma_rready,local_bram_en,local_bram_we[31:0],local_bram_addr[31:0],local_bram_din[255:0],local_bram_dout[255:0]" */
/* synthesis syn_force_seq_prim="aclk" */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aclk, ASSOCIATED_BUSIF s_axil:m_axil_cdma, ASSOCIATED_RESET aresetn, FREQ_HZ 250000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN xdma_dcim_bram_xdma_0_0_axi_aclk, INSERT_VIP 0" *) input aclk /* synthesis syn_isclock = 1 */;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) input aresetn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *) (* X_INTERFACE_MODE = "slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME s_axil, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 250000000, ID_WIDTH 0, ADDR_WIDTH 12, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN xdma_dcim_bram_xdma_0_0_axi_aclk, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input [11:0]s_axil_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *) input s_axil_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *) output s_axil_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *) input [31:0]s_axil_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *) input [3:0]s_axil_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *) input s_axil_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *) output s_axil_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *) output [1:0]s_axil_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *) output s_axil_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *) input s_axil_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *) input [11:0]s_axil_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *) input s_axil_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *) output s_axil_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *) output [31:0]s_axil_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *) output [1:0]s_axil_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *) output s_axil_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *) input s_axil_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWADDR" *) (* X_INTERFACE_MODE = "master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME m_axil_cdma, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 250000000, ID_WIDTH 0, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 0, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN xdma_dcim_bram_xdma_0_0_axi_aclk, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) output [31:0]m_axil_cdma_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWVALID" *) output m_axil_cdma_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma AWREADY" *) input m_axil_cdma_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WDATA" *) output [31:0]m_axil_cdma_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WSTRB" *) output [3:0]m_axil_cdma_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WVALID" *) output m_axil_cdma_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma WREADY" *) input m_axil_cdma_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BRESP" *) input [1:0]m_axil_cdma_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BVALID" *) input m_axil_cdma_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma BREADY" *) output m_axil_cdma_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARADDR" *) output [31:0]m_axil_cdma_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARVALID" *) output m_axil_cdma_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma ARREADY" *) input m_axil_cdma_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RDATA" *) input [31:0]m_axil_cdma_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RRESP" *) input [1:0]m_axil_cdma_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RVALID" *) input m_axil_cdma_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 m_axil_cdma RREADY" *) output m_axil_cdma_rready;
  output local_bram_en;
  output [31:0]local_bram_we;
  output [31:0]local_bram_addr;
  output [255:0]local_bram_din;
  input [255:0]local_bram_dout;
endmodule
