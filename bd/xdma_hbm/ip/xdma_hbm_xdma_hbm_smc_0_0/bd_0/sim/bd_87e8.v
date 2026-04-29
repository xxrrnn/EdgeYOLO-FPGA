//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Command: generate_target bd_87e8.bd
//Design : bd_87e8
//Purpose: IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "bd_87e8,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=bd_87e8,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=164,numReposBlks=128,numNonXlnxBlks=0,numHierBlks=36,maxHierDepth=1,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=SBD,synth_mode=None}" *) (* HW_HANDOFF = "xdma_hbm_xdma_hbm_smc_0_0.hwdef" *) 
module bd_87e8
   (M00_AXI_araddr,
    M00_AXI_arburst,
    M00_AXI_arcache,
    M00_AXI_arlen,
    M00_AXI_arlock,
    M00_AXI_arprot,
    M00_AXI_arqos,
    M00_AXI_arready,
    M00_AXI_arsize,
    M00_AXI_arvalid,
    M00_AXI_awaddr,
    M00_AXI_awburst,
    M00_AXI_awcache,
    M00_AXI_awlen,
    M00_AXI_awlock,
    M00_AXI_awprot,
    M00_AXI_awqos,
    M00_AXI_awready,
    M00_AXI_awsize,
    M00_AXI_awvalid,
    M00_AXI_bready,
    M00_AXI_bresp,
    M00_AXI_bvalid,
    M00_AXI_rdata,
    M00_AXI_rlast,
    M00_AXI_rready,
    M00_AXI_rresp,
    M00_AXI_rvalid,
    M00_AXI_wdata,
    M00_AXI_wlast,
    M00_AXI_wready,
    M00_AXI_wstrb,
    M00_AXI_wvalid,
    M01_AXI_araddr,
    M01_AXI_arburst,
    M01_AXI_arcache,
    M01_AXI_arlen,
    M01_AXI_arlock,
    M01_AXI_arprot,
    M01_AXI_arqos,
    M01_AXI_arready,
    M01_AXI_arsize,
    M01_AXI_arvalid,
    M01_AXI_awaddr,
    M01_AXI_awburst,
    M01_AXI_awcache,
    M01_AXI_awlen,
    M01_AXI_awlock,
    M01_AXI_awprot,
    M01_AXI_awqos,
    M01_AXI_awready,
    M01_AXI_awsize,
    M01_AXI_awvalid,
    M01_AXI_bready,
    M01_AXI_bresp,
    M01_AXI_bvalid,
    M01_AXI_rdata,
    M01_AXI_rlast,
    M01_AXI_rready,
    M01_AXI_rresp,
    M01_AXI_rvalid,
    M01_AXI_wdata,
    M01_AXI_wlast,
    M01_AXI_wready,
    M01_AXI_wstrb,
    M01_AXI_wvalid,
    M02_AXI_araddr,
    M02_AXI_arburst,
    M02_AXI_arcache,
    M02_AXI_arlen,
    M02_AXI_arlock,
    M02_AXI_arprot,
    M02_AXI_arqos,
    M02_AXI_arready,
    M02_AXI_arsize,
    M02_AXI_arvalid,
    M02_AXI_awaddr,
    M02_AXI_awburst,
    M02_AXI_awcache,
    M02_AXI_awlen,
    M02_AXI_awlock,
    M02_AXI_awprot,
    M02_AXI_awqos,
    M02_AXI_awready,
    M02_AXI_awsize,
    M02_AXI_awvalid,
    M02_AXI_bready,
    M02_AXI_bresp,
    M02_AXI_bvalid,
    M02_AXI_rdata,
    M02_AXI_rlast,
    M02_AXI_rready,
    M02_AXI_rresp,
    M02_AXI_rvalid,
    M02_AXI_wdata,
    M02_AXI_wlast,
    M02_AXI_wready,
    M02_AXI_wstrb,
    M02_AXI_wvalid,
    M03_AXI_araddr,
    M03_AXI_arburst,
    M03_AXI_arcache,
    M03_AXI_arlen,
    M03_AXI_arlock,
    M03_AXI_arprot,
    M03_AXI_arqos,
    M03_AXI_arready,
    M03_AXI_arsize,
    M03_AXI_arvalid,
    M03_AXI_awaddr,
    M03_AXI_awburst,
    M03_AXI_awcache,
    M03_AXI_awlen,
    M03_AXI_awlock,
    M03_AXI_awprot,
    M03_AXI_awqos,
    M03_AXI_awready,
    M03_AXI_awsize,
    M03_AXI_awvalid,
    M03_AXI_bready,
    M03_AXI_bresp,
    M03_AXI_bvalid,
    M03_AXI_rdata,
    M03_AXI_rlast,
    M03_AXI_rready,
    M03_AXI_rresp,
    M03_AXI_rvalid,
    M03_AXI_wdata,
    M03_AXI_wlast,
    M03_AXI_wready,
    M03_AXI_wstrb,
    M03_AXI_wvalid,
    M04_AXI_araddr,
    M04_AXI_arburst,
    M04_AXI_arcache,
    M04_AXI_arlen,
    M04_AXI_arlock,
    M04_AXI_arprot,
    M04_AXI_arqos,
    M04_AXI_arready,
    M04_AXI_arsize,
    M04_AXI_arvalid,
    M04_AXI_awaddr,
    M04_AXI_awburst,
    M04_AXI_awcache,
    M04_AXI_awlen,
    M04_AXI_awlock,
    M04_AXI_awprot,
    M04_AXI_awqos,
    M04_AXI_awready,
    M04_AXI_awsize,
    M04_AXI_awvalid,
    M04_AXI_bready,
    M04_AXI_bresp,
    M04_AXI_bvalid,
    M04_AXI_rdata,
    M04_AXI_rlast,
    M04_AXI_rready,
    M04_AXI_rresp,
    M04_AXI_rvalid,
    M04_AXI_wdata,
    M04_AXI_wlast,
    M04_AXI_wready,
    M04_AXI_wstrb,
    M04_AXI_wvalid,
    M05_AXI_araddr,
    M05_AXI_arburst,
    M05_AXI_arcache,
    M05_AXI_arlen,
    M05_AXI_arlock,
    M05_AXI_arprot,
    M05_AXI_arqos,
    M05_AXI_arready,
    M05_AXI_arsize,
    M05_AXI_arvalid,
    M05_AXI_awaddr,
    M05_AXI_awburst,
    M05_AXI_awcache,
    M05_AXI_awlen,
    M05_AXI_awlock,
    M05_AXI_awprot,
    M05_AXI_awqos,
    M05_AXI_awready,
    M05_AXI_awsize,
    M05_AXI_awvalid,
    M05_AXI_bready,
    M05_AXI_bresp,
    M05_AXI_bvalid,
    M05_AXI_rdata,
    M05_AXI_rlast,
    M05_AXI_rready,
    M05_AXI_rresp,
    M05_AXI_rvalid,
    M05_AXI_wdata,
    M05_AXI_wlast,
    M05_AXI_wready,
    M05_AXI_wstrb,
    M05_AXI_wvalid,
    M06_AXI_araddr,
    M06_AXI_arburst,
    M06_AXI_arcache,
    M06_AXI_arlen,
    M06_AXI_arlock,
    M06_AXI_arprot,
    M06_AXI_arqos,
    M06_AXI_arready,
    M06_AXI_arsize,
    M06_AXI_arvalid,
    M06_AXI_awaddr,
    M06_AXI_awburst,
    M06_AXI_awcache,
    M06_AXI_awlen,
    M06_AXI_awlock,
    M06_AXI_awprot,
    M06_AXI_awqos,
    M06_AXI_awready,
    M06_AXI_awsize,
    M06_AXI_awvalid,
    M06_AXI_bready,
    M06_AXI_bresp,
    M06_AXI_bvalid,
    M06_AXI_rdata,
    M06_AXI_rlast,
    M06_AXI_rready,
    M06_AXI_rresp,
    M06_AXI_rvalid,
    M06_AXI_wdata,
    M06_AXI_wlast,
    M06_AXI_wready,
    M06_AXI_wstrb,
    M06_AXI_wvalid,
    M07_AXI_araddr,
    M07_AXI_arburst,
    M07_AXI_arcache,
    M07_AXI_arlen,
    M07_AXI_arlock,
    M07_AXI_arprot,
    M07_AXI_arqos,
    M07_AXI_arready,
    M07_AXI_arsize,
    M07_AXI_arvalid,
    M07_AXI_awaddr,
    M07_AXI_awburst,
    M07_AXI_awcache,
    M07_AXI_awlen,
    M07_AXI_awlock,
    M07_AXI_awprot,
    M07_AXI_awqos,
    M07_AXI_awready,
    M07_AXI_awsize,
    M07_AXI_awvalid,
    M07_AXI_bready,
    M07_AXI_bresp,
    M07_AXI_bvalid,
    M07_AXI_rdata,
    M07_AXI_rlast,
    M07_AXI_rready,
    M07_AXI_rresp,
    M07_AXI_rvalid,
    M07_AXI_wdata,
    M07_AXI_wlast,
    M07_AXI_wready,
    M07_AXI_wstrb,
    M07_AXI_wvalid,
    M08_AXI_araddr,
    M08_AXI_arburst,
    M08_AXI_arcache,
    M08_AXI_arlen,
    M08_AXI_arlock,
    M08_AXI_arprot,
    M08_AXI_arqos,
    M08_AXI_arready,
    M08_AXI_arsize,
    M08_AXI_arvalid,
    M08_AXI_awaddr,
    M08_AXI_awburst,
    M08_AXI_awcache,
    M08_AXI_awlen,
    M08_AXI_awlock,
    M08_AXI_awprot,
    M08_AXI_awqos,
    M08_AXI_awready,
    M08_AXI_awsize,
    M08_AXI_awvalid,
    M08_AXI_bready,
    M08_AXI_bresp,
    M08_AXI_bvalid,
    M08_AXI_rdata,
    M08_AXI_rlast,
    M08_AXI_rready,
    M08_AXI_rresp,
    M08_AXI_rvalid,
    M08_AXI_wdata,
    M08_AXI_wlast,
    M08_AXI_wready,
    M08_AXI_wstrb,
    M08_AXI_wvalid,
    M09_AXI_araddr,
    M09_AXI_arburst,
    M09_AXI_arcache,
    M09_AXI_arlen,
    M09_AXI_arlock,
    M09_AXI_arprot,
    M09_AXI_arqos,
    M09_AXI_arready,
    M09_AXI_arsize,
    M09_AXI_arvalid,
    M09_AXI_awaddr,
    M09_AXI_awburst,
    M09_AXI_awcache,
    M09_AXI_awlen,
    M09_AXI_awlock,
    M09_AXI_awprot,
    M09_AXI_awqos,
    M09_AXI_awready,
    M09_AXI_awsize,
    M09_AXI_awvalid,
    M09_AXI_bready,
    M09_AXI_bresp,
    M09_AXI_bvalid,
    M09_AXI_rdata,
    M09_AXI_rlast,
    M09_AXI_rready,
    M09_AXI_rresp,
    M09_AXI_rvalid,
    M09_AXI_wdata,
    M09_AXI_wlast,
    M09_AXI_wready,
    M09_AXI_wstrb,
    M09_AXI_wvalid,
    M10_AXI_araddr,
    M10_AXI_arburst,
    M10_AXI_arcache,
    M10_AXI_arlen,
    M10_AXI_arlock,
    M10_AXI_arprot,
    M10_AXI_arqos,
    M10_AXI_arready,
    M10_AXI_arsize,
    M10_AXI_arvalid,
    M10_AXI_awaddr,
    M10_AXI_awburst,
    M10_AXI_awcache,
    M10_AXI_awlen,
    M10_AXI_awlock,
    M10_AXI_awprot,
    M10_AXI_awqos,
    M10_AXI_awready,
    M10_AXI_awsize,
    M10_AXI_awvalid,
    M10_AXI_bready,
    M10_AXI_bresp,
    M10_AXI_bvalid,
    M10_AXI_rdata,
    M10_AXI_rlast,
    M10_AXI_rready,
    M10_AXI_rresp,
    M10_AXI_rvalid,
    M10_AXI_wdata,
    M10_AXI_wlast,
    M10_AXI_wready,
    M10_AXI_wstrb,
    M10_AXI_wvalid,
    M11_AXI_araddr,
    M11_AXI_arburst,
    M11_AXI_arcache,
    M11_AXI_arlen,
    M11_AXI_arlock,
    M11_AXI_arprot,
    M11_AXI_arqos,
    M11_AXI_arready,
    M11_AXI_arsize,
    M11_AXI_arvalid,
    M11_AXI_awaddr,
    M11_AXI_awburst,
    M11_AXI_awcache,
    M11_AXI_awlen,
    M11_AXI_awlock,
    M11_AXI_awprot,
    M11_AXI_awqos,
    M11_AXI_awready,
    M11_AXI_awsize,
    M11_AXI_awvalid,
    M11_AXI_bready,
    M11_AXI_bresp,
    M11_AXI_bvalid,
    M11_AXI_rdata,
    M11_AXI_rlast,
    M11_AXI_rready,
    M11_AXI_rresp,
    M11_AXI_rvalid,
    M11_AXI_wdata,
    M11_AXI_wlast,
    M11_AXI_wready,
    M11_AXI_wstrb,
    M11_AXI_wvalid,
    M12_AXI_araddr,
    M12_AXI_arburst,
    M12_AXI_arcache,
    M12_AXI_arlen,
    M12_AXI_arlock,
    M12_AXI_arprot,
    M12_AXI_arqos,
    M12_AXI_arready,
    M12_AXI_arsize,
    M12_AXI_arvalid,
    M12_AXI_awaddr,
    M12_AXI_awburst,
    M12_AXI_awcache,
    M12_AXI_awlen,
    M12_AXI_awlock,
    M12_AXI_awprot,
    M12_AXI_awqos,
    M12_AXI_awready,
    M12_AXI_awsize,
    M12_AXI_awvalid,
    M12_AXI_bready,
    M12_AXI_bresp,
    M12_AXI_bvalid,
    M12_AXI_rdata,
    M12_AXI_rlast,
    M12_AXI_rready,
    M12_AXI_rresp,
    M12_AXI_rvalid,
    M12_AXI_wdata,
    M12_AXI_wlast,
    M12_AXI_wready,
    M12_AXI_wstrb,
    M12_AXI_wvalid,
    M13_AXI_araddr,
    M13_AXI_arburst,
    M13_AXI_arcache,
    M13_AXI_arlen,
    M13_AXI_arlock,
    M13_AXI_arprot,
    M13_AXI_arqos,
    M13_AXI_arready,
    M13_AXI_arsize,
    M13_AXI_arvalid,
    M13_AXI_awaddr,
    M13_AXI_awburst,
    M13_AXI_awcache,
    M13_AXI_awlen,
    M13_AXI_awlock,
    M13_AXI_awprot,
    M13_AXI_awqos,
    M13_AXI_awready,
    M13_AXI_awsize,
    M13_AXI_awvalid,
    M13_AXI_bready,
    M13_AXI_bresp,
    M13_AXI_bvalid,
    M13_AXI_rdata,
    M13_AXI_rlast,
    M13_AXI_rready,
    M13_AXI_rresp,
    M13_AXI_rvalid,
    M13_AXI_wdata,
    M13_AXI_wlast,
    M13_AXI_wready,
    M13_AXI_wstrb,
    M13_AXI_wvalid,
    M14_AXI_araddr,
    M14_AXI_arburst,
    M14_AXI_arcache,
    M14_AXI_arlen,
    M14_AXI_arlock,
    M14_AXI_arprot,
    M14_AXI_arqos,
    M14_AXI_arready,
    M14_AXI_arsize,
    M14_AXI_arvalid,
    M14_AXI_awaddr,
    M14_AXI_awburst,
    M14_AXI_awcache,
    M14_AXI_awlen,
    M14_AXI_awlock,
    M14_AXI_awprot,
    M14_AXI_awqos,
    M14_AXI_awready,
    M14_AXI_awsize,
    M14_AXI_awvalid,
    M14_AXI_bready,
    M14_AXI_bresp,
    M14_AXI_bvalid,
    M14_AXI_rdata,
    M14_AXI_rlast,
    M14_AXI_rready,
    M14_AXI_rresp,
    M14_AXI_rvalid,
    M14_AXI_wdata,
    M14_AXI_wlast,
    M14_AXI_wready,
    M14_AXI_wstrb,
    M14_AXI_wvalid,
    M15_AXI_araddr,
    M15_AXI_arburst,
    M15_AXI_arcache,
    M15_AXI_arlen,
    M15_AXI_arlock,
    M15_AXI_arprot,
    M15_AXI_arqos,
    M15_AXI_arready,
    M15_AXI_arsize,
    M15_AXI_arvalid,
    M15_AXI_awaddr,
    M15_AXI_awburst,
    M15_AXI_awcache,
    M15_AXI_awlen,
    M15_AXI_awlock,
    M15_AXI_awprot,
    M15_AXI_awqos,
    M15_AXI_awready,
    M15_AXI_awsize,
    M15_AXI_awvalid,
    M15_AXI_bready,
    M15_AXI_bresp,
    M15_AXI_bvalid,
    M15_AXI_rdata,
    M15_AXI_rlast,
    M15_AXI_rready,
    M15_AXI_rresp,
    M15_AXI_rvalid,
    M15_AXI_wdata,
    M15_AXI_wlast,
    M15_AXI_wready,
    M15_AXI_wstrb,
    M15_AXI_wvalid,
    S00_AXI_araddr,
    S00_AXI_arburst,
    S00_AXI_arcache,
    S00_AXI_arid,
    S00_AXI_arlen,
    S00_AXI_arlock,
    S00_AXI_arprot,
    S00_AXI_arqos,
    S00_AXI_arready,
    S00_AXI_arsize,
    S00_AXI_aruser,
    S00_AXI_arvalid,
    S00_AXI_awaddr,
    S00_AXI_awburst,
    S00_AXI_awcache,
    S00_AXI_awid,
    S00_AXI_awlen,
    S00_AXI_awlock,
    S00_AXI_awprot,
    S00_AXI_awqos,
    S00_AXI_awready,
    S00_AXI_awsize,
    S00_AXI_awuser,
    S00_AXI_awvalid,
    S00_AXI_bid,
    S00_AXI_bready,
    S00_AXI_bresp,
    S00_AXI_buser,
    S00_AXI_bvalid,
    S00_AXI_rdata,
    S00_AXI_rid,
    S00_AXI_rlast,
    S00_AXI_rready,
    S00_AXI_rresp,
    S00_AXI_ruser,
    S00_AXI_rvalid,
    S00_AXI_wdata,
    S00_AXI_wlast,
    S00_AXI_wready,
    S00_AXI_wstrb,
    S00_AXI_wuser,
    S00_AXI_wvalid,
    aclk,
    aresetn);
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M00_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M00_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARBURST" *) output [1:0]M00_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARCACHE" *) output [3:0]M00_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARLEN" *) output [3:0]M00_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARLOCK" *) output [1:0]M00_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARPROT" *) output [2:0]M00_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARQOS" *) output [3:0]M00_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARREADY" *) input M00_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARSIZE" *) output [2:0]M00_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI ARVALID" *) output M00_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWADDR" *) output [32:0]M00_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWBURST" *) output [1:0]M00_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWCACHE" *) output [3:0]M00_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWLEN" *) output [3:0]M00_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWLOCK" *) output [1:0]M00_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWPROT" *) output [2:0]M00_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWQOS" *) output [3:0]M00_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWREADY" *) input M00_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWSIZE" *) output [2:0]M00_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI AWVALID" *) output M00_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI BREADY" *) output M00_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI BRESP" *) input [1:0]M00_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI BVALID" *) input M00_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI RDATA" *) input [255:0]M00_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI RLAST" *) input M00_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI RREADY" *) output M00_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI RRESP" *) input [1:0]M00_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI RVALID" *) input M00_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI WDATA" *) output [255:0]M00_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI WLAST" *) output M00_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI WREADY" *) input M00_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI WSTRB" *) output [31:0]M00_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M00_AXI WVALID" *) output M00_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M01_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M01_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARBURST" *) output [1:0]M01_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARCACHE" *) output [3:0]M01_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARLEN" *) output [3:0]M01_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARLOCK" *) output [1:0]M01_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARPROT" *) output [2:0]M01_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARQOS" *) output [3:0]M01_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARREADY" *) input M01_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARSIZE" *) output [2:0]M01_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI ARVALID" *) output M01_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWADDR" *) output [32:0]M01_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWBURST" *) output [1:0]M01_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWCACHE" *) output [3:0]M01_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWLEN" *) output [3:0]M01_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWLOCK" *) output [1:0]M01_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWPROT" *) output [2:0]M01_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWQOS" *) output [3:0]M01_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWREADY" *) input M01_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWSIZE" *) output [2:0]M01_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI AWVALID" *) output M01_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI BREADY" *) output M01_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI BRESP" *) input [1:0]M01_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI BVALID" *) input M01_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI RDATA" *) input [255:0]M01_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI RLAST" *) input M01_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI RREADY" *) output M01_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI RRESP" *) input [1:0]M01_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI RVALID" *) input M01_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI WDATA" *) output [255:0]M01_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI WLAST" *) output M01_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI WREADY" *) input M01_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI WSTRB" *) output [31:0]M01_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M01_AXI WVALID" *) output M01_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M02_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M02_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARBURST" *) output [1:0]M02_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARCACHE" *) output [3:0]M02_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARLEN" *) output [3:0]M02_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARLOCK" *) output [1:0]M02_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARPROT" *) output [2:0]M02_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARQOS" *) output [3:0]M02_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARREADY" *) input M02_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARSIZE" *) output [2:0]M02_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI ARVALID" *) output M02_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWADDR" *) output [32:0]M02_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWBURST" *) output [1:0]M02_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWCACHE" *) output [3:0]M02_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWLEN" *) output [3:0]M02_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWLOCK" *) output [1:0]M02_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWPROT" *) output [2:0]M02_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWQOS" *) output [3:0]M02_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWREADY" *) input M02_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWSIZE" *) output [2:0]M02_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI AWVALID" *) output M02_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI BREADY" *) output M02_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI BRESP" *) input [1:0]M02_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI BVALID" *) input M02_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI RDATA" *) input [255:0]M02_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI RLAST" *) input M02_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI RREADY" *) output M02_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI RRESP" *) input [1:0]M02_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI RVALID" *) input M02_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI WDATA" *) output [255:0]M02_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI WLAST" *) output M02_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI WREADY" *) input M02_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI WSTRB" *) output [31:0]M02_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M02_AXI WVALID" *) output M02_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M03_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M03_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARBURST" *) output [1:0]M03_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARCACHE" *) output [3:0]M03_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARLEN" *) output [3:0]M03_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARLOCK" *) output [1:0]M03_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARPROT" *) output [2:0]M03_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARQOS" *) output [3:0]M03_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARREADY" *) input M03_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARSIZE" *) output [2:0]M03_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI ARVALID" *) output M03_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWADDR" *) output [32:0]M03_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWBURST" *) output [1:0]M03_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWCACHE" *) output [3:0]M03_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWLEN" *) output [3:0]M03_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWLOCK" *) output [1:0]M03_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWPROT" *) output [2:0]M03_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWQOS" *) output [3:0]M03_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWREADY" *) input M03_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWSIZE" *) output [2:0]M03_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI AWVALID" *) output M03_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI BREADY" *) output M03_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI BRESP" *) input [1:0]M03_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI BVALID" *) input M03_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI RDATA" *) input [255:0]M03_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI RLAST" *) input M03_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI RREADY" *) output M03_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI RRESP" *) input [1:0]M03_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI RVALID" *) input M03_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI WDATA" *) output [255:0]M03_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI WLAST" *) output M03_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI WREADY" *) input M03_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI WSTRB" *) output [31:0]M03_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M03_AXI WVALID" *) output M03_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M04_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M04_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARBURST" *) output [1:0]M04_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARCACHE" *) output [3:0]M04_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARLEN" *) output [3:0]M04_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARLOCK" *) output [1:0]M04_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARPROT" *) output [2:0]M04_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARQOS" *) output [3:0]M04_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARREADY" *) input M04_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARSIZE" *) output [2:0]M04_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI ARVALID" *) output M04_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWADDR" *) output [32:0]M04_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWBURST" *) output [1:0]M04_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWCACHE" *) output [3:0]M04_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWLEN" *) output [3:0]M04_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWLOCK" *) output [1:0]M04_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWPROT" *) output [2:0]M04_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWQOS" *) output [3:0]M04_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWREADY" *) input M04_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWSIZE" *) output [2:0]M04_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI AWVALID" *) output M04_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI BREADY" *) output M04_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI BRESP" *) input [1:0]M04_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI BVALID" *) input M04_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI RDATA" *) input [255:0]M04_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI RLAST" *) input M04_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI RREADY" *) output M04_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI RRESP" *) input [1:0]M04_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI RVALID" *) input M04_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI WDATA" *) output [255:0]M04_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI WLAST" *) output M04_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI WREADY" *) input M04_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI WSTRB" *) output [31:0]M04_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M04_AXI WVALID" *) output M04_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M05_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M05_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARBURST" *) output [1:0]M05_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARCACHE" *) output [3:0]M05_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARLEN" *) output [3:0]M05_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARLOCK" *) output [1:0]M05_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARPROT" *) output [2:0]M05_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARQOS" *) output [3:0]M05_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARREADY" *) input M05_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARSIZE" *) output [2:0]M05_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI ARVALID" *) output M05_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWADDR" *) output [32:0]M05_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWBURST" *) output [1:0]M05_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWCACHE" *) output [3:0]M05_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWLEN" *) output [3:0]M05_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWLOCK" *) output [1:0]M05_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWPROT" *) output [2:0]M05_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWQOS" *) output [3:0]M05_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWREADY" *) input M05_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWSIZE" *) output [2:0]M05_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI AWVALID" *) output M05_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI BREADY" *) output M05_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI BRESP" *) input [1:0]M05_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI BVALID" *) input M05_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI RDATA" *) input [255:0]M05_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI RLAST" *) input M05_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI RREADY" *) output M05_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI RRESP" *) input [1:0]M05_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI RVALID" *) input M05_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI WDATA" *) output [255:0]M05_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI WLAST" *) output M05_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI WREADY" *) input M05_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI WSTRB" *) output [31:0]M05_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M05_AXI WVALID" *) output M05_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M06_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M06_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARBURST" *) output [1:0]M06_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARCACHE" *) output [3:0]M06_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARLEN" *) output [3:0]M06_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARLOCK" *) output [1:0]M06_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARPROT" *) output [2:0]M06_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARQOS" *) output [3:0]M06_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARREADY" *) input M06_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARSIZE" *) output [2:0]M06_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI ARVALID" *) output M06_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWADDR" *) output [32:0]M06_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWBURST" *) output [1:0]M06_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWCACHE" *) output [3:0]M06_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWLEN" *) output [3:0]M06_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWLOCK" *) output [1:0]M06_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWPROT" *) output [2:0]M06_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWQOS" *) output [3:0]M06_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWREADY" *) input M06_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWSIZE" *) output [2:0]M06_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI AWVALID" *) output M06_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI BREADY" *) output M06_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI BRESP" *) input [1:0]M06_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI BVALID" *) input M06_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI RDATA" *) input [255:0]M06_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI RLAST" *) input M06_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI RREADY" *) output M06_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI RRESP" *) input [1:0]M06_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI RVALID" *) input M06_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI WDATA" *) output [255:0]M06_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI WLAST" *) output M06_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI WREADY" *) input M06_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI WSTRB" *) output [31:0]M06_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M06_AXI WVALID" *) output M06_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M07_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M07_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARBURST" *) output [1:0]M07_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARCACHE" *) output [3:0]M07_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARLEN" *) output [3:0]M07_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARLOCK" *) output [1:0]M07_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARPROT" *) output [2:0]M07_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARQOS" *) output [3:0]M07_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARREADY" *) input M07_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARSIZE" *) output [2:0]M07_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI ARVALID" *) output M07_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWADDR" *) output [32:0]M07_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWBURST" *) output [1:0]M07_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWCACHE" *) output [3:0]M07_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWLEN" *) output [3:0]M07_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWLOCK" *) output [1:0]M07_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWPROT" *) output [2:0]M07_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWQOS" *) output [3:0]M07_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWREADY" *) input M07_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWSIZE" *) output [2:0]M07_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI AWVALID" *) output M07_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI BREADY" *) output M07_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI BRESP" *) input [1:0]M07_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI BVALID" *) input M07_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI RDATA" *) input [255:0]M07_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI RLAST" *) input M07_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI RREADY" *) output M07_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI RRESP" *) input [1:0]M07_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI RVALID" *) input M07_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI WDATA" *) output [255:0]M07_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI WLAST" *) output M07_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI WREADY" *) input M07_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI WSTRB" *) output [31:0]M07_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M07_AXI WVALID" *) output M07_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M08_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M08_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARBURST" *) output [1:0]M08_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARCACHE" *) output [3:0]M08_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARLEN" *) output [3:0]M08_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARLOCK" *) output [1:0]M08_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARPROT" *) output [2:0]M08_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARQOS" *) output [3:0]M08_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARREADY" *) input M08_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARSIZE" *) output [2:0]M08_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI ARVALID" *) output M08_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWADDR" *) output [32:0]M08_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWBURST" *) output [1:0]M08_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWCACHE" *) output [3:0]M08_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWLEN" *) output [3:0]M08_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWLOCK" *) output [1:0]M08_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWPROT" *) output [2:0]M08_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWQOS" *) output [3:0]M08_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWREADY" *) input M08_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWSIZE" *) output [2:0]M08_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI AWVALID" *) output M08_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI BREADY" *) output M08_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI BRESP" *) input [1:0]M08_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI BVALID" *) input M08_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI RDATA" *) input [255:0]M08_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI RLAST" *) input M08_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI RREADY" *) output M08_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI RRESP" *) input [1:0]M08_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI RVALID" *) input M08_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI WDATA" *) output [255:0]M08_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI WLAST" *) output M08_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI WREADY" *) input M08_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI WSTRB" *) output [31:0]M08_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M08_AXI WVALID" *) output M08_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M09_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M09_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARBURST" *) output [1:0]M09_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARCACHE" *) output [3:0]M09_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARLEN" *) output [3:0]M09_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARLOCK" *) output [1:0]M09_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARPROT" *) output [2:0]M09_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARQOS" *) output [3:0]M09_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARREADY" *) input M09_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARSIZE" *) output [2:0]M09_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI ARVALID" *) output M09_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWADDR" *) output [32:0]M09_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWBURST" *) output [1:0]M09_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWCACHE" *) output [3:0]M09_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWLEN" *) output [3:0]M09_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWLOCK" *) output [1:0]M09_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWPROT" *) output [2:0]M09_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWQOS" *) output [3:0]M09_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWREADY" *) input M09_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWSIZE" *) output [2:0]M09_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI AWVALID" *) output M09_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI BREADY" *) output M09_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI BRESP" *) input [1:0]M09_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI BVALID" *) input M09_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI RDATA" *) input [255:0]M09_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI RLAST" *) input M09_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI RREADY" *) output M09_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI RRESP" *) input [1:0]M09_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI RVALID" *) input M09_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI WDATA" *) output [255:0]M09_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI WLAST" *) output M09_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI WREADY" *) input M09_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI WSTRB" *) output [31:0]M09_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M09_AXI WVALID" *) output M09_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M10_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M10_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARBURST" *) output [1:0]M10_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARCACHE" *) output [3:0]M10_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARLEN" *) output [3:0]M10_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARLOCK" *) output [1:0]M10_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARPROT" *) output [2:0]M10_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARQOS" *) output [3:0]M10_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARREADY" *) input M10_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARSIZE" *) output [2:0]M10_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI ARVALID" *) output M10_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWADDR" *) output [32:0]M10_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWBURST" *) output [1:0]M10_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWCACHE" *) output [3:0]M10_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWLEN" *) output [3:0]M10_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWLOCK" *) output [1:0]M10_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWPROT" *) output [2:0]M10_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWQOS" *) output [3:0]M10_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWREADY" *) input M10_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWSIZE" *) output [2:0]M10_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI AWVALID" *) output M10_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI BREADY" *) output M10_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI BRESP" *) input [1:0]M10_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI BVALID" *) input M10_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI RDATA" *) input [255:0]M10_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI RLAST" *) input M10_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI RREADY" *) output M10_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI RRESP" *) input [1:0]M10_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI RVALID" *) input M10_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI WDATA" *) output [255:0]M10_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI WLAST" *) output M10_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI WREADY" *) input M10_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI WSTRB" *) output [31:0]M10_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M10_AXI WVALID" *) output M10_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M11_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M11_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARBURST" *) output [1:0]M11_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARCACHE" *) output [3:0]M11_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARLEN" *) output [3:0]M11_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARLOCK" *) output [1:0]M11_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARPROT" *) output [2:0]M11_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARQOS" *) output [3:0]M11_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARREADY" *) input M11_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARSIZE" *) output [2:0]M11_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI ARVALID" *) output M11_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWADDR" *) output [32:0]M11_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWBURST" *) output [1:0]M11_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWCACHE" *) output [3:0]M11_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWLEN" *) output [3:0]M11_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWLOCK" *) output [1:0]M11_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWPROT" *) output [2:0]M11_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWQOS" *) output [3:0]M11_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWREADY" *) input M11_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWSIZE" *) output [2:0]M11_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI AWVALID" *) output M11_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI BREADY" *) output M11_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI BRESP" *) input [1:0]M11_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI BVALID" *) input M11_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI RDATA" *) input [255:0]M11_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI RLAST" *) input M11_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI RREADY" *) output M11_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI RRESP" *) input [1:0]M11_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI RVALID" *) input M11_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI WDATA" *) output [255:0]M11_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI WLAST" *) output M11_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI WREADY" *) input M11_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI WSTRB" *) output [31:0]M11_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M11_AXI WVALID" *) output M11_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M12_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M12_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARBURST" *) output [1:0]M12_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARCACHE" *) output [3:0]M12_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARLEN" *) output [3:0]M12_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARLOCK" *) output [1:0]M12_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARPROT" *) output [2:0]M12_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARQOS" *) output [3:0]M12_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARREADY" *) input M12_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARSIZE" *) output [2:0]M12_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI ARVALID" *) output M12_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWADDR" *) output [32:0]M12_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWBURST" *) output [1:0]M12_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWCACHE" *) output [3:0]M12_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWLEN" *) output [3:0]M12_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWLOCK" *) output [1:0]M12_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWPROT" *) output [2:0]M12_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWQOS" *) output [3:0]M12_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWREADY" *) input M12_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWSIZE" *) output [2:0]M12_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI AWVALID" *) output M12_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI BREADY" *) output M12_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI BRESP" *) input [1:0]M12_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI BVALID" *) input M12_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI RDATA" *) input [255:0]M12_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI RLAST" *) input M12_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI RREADY" *) output M12_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI RRESP" *) input [1:0]M12_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI RVALID" *) input M12_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI WDATA" *) output [255:0]M12_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI WLAST" *) output M12_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI WREADY" *) input M12_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI WSTRB" *) output [31:0]M12_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M12_AXI WVALID" *) output M12_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M13_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M13_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARBURST" *) output [1:0]M13_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARCACHE" *) output [3:0]M13_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARLEN" *) output [3:0]M13_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARLOCK" *) output [1:0]M13_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARPROT" *) output [2:0]M13_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARQOS" *) output [3:0]M13_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARREADY" *) input M13_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARSIZE" *) output [2:0]M13_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI ARVALID" *) output M13_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWADDR" *) output [32:0]M13_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWBURST" *) output [1:0]M13_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWCACHE" *) output [3:0]M13_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWLEN" *) output [3:0]M13_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWLOCK" *) output [1:0]M13_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWPROT" *) output [2:0]M13_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWQOS" *) output [3:0]M13_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWREADY" *) input M13_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWSIZE" *) output [2:0]M13_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI AWVALID" *) output M13_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI BREADY" *) output M13_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI BRESP" *) input [1:0]M13_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI BVALID" *) input M13_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI RDATA" *) input [255:0]M13_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI RLAST" *) input M13_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI RREADY" *) output M13_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI RRESP" *) input [1:0]M13_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI RVALID" *) input M13_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI WDATA" *) output [255:0]M13_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI WLAST" *) output M13_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI WREADY" *) input M13_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI WSTRB" *) output [31:0]M13_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M13_AXI WVALID" *) output M13_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M14_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M14_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARBURST" *) output [1:0]M14_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARCACHE" *) output [3:0]M14_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARLEN" *) output [3:0]M14_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARLOCK" *) output [1:0]M14_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARPROT" *) output [2:0]M14_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARQOS" *) output [3:0]M14_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARREADY" *) input M14_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARSIZE" *) output [2:0]M14_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI ARVALID" *) output M14_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWADDR" *) output [32:0]M14_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWBURST" *) output [1:0]M14_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWCACHE" *) output [3:0]M14_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWLEN" *) output [3:0]M14_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWLOCK" *) output [1:0]M14_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWPROT" *) output [2:0]M14_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWQOS" *) output [3:0]M14_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWREADY" *) input M14_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWSIZE" *) output [2:0]M14_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI AWVALID" *) output M14_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI BREADY" *) output M14_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI BRESP" *) input [1:0]M14_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI BVALID" *) input M14_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI RDATA" *) input [255:0]M14_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI RLAST" *) input M14_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI RREADY" *) output M14_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI RRESP" *) input [1:0]M14_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI RVALID" *) input M14_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI WDATA" *) output [255:0]M14_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI WLAST" *) output M14_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI WREADY" *) input M14_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI WSTRB" *) output [31:0]M14_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M14_AXI WVALID" *) output M14_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARADDR" *) (* X_INTERFACE_MODE = "Master" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M15_AXI, ADDR_WIDTH 33, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI3, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [32:0]M15_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARBURST" *) output [1:0]M15_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARCACHE" *) output [3:0]M15_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARLEN" *) output [3:0]M15_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARLOCK" *) output [1:0]M15_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARPROT" *) output [2:0]M15_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARQOS" *) output [3:0]M15_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARREADY" *) input M15_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARSIZE" *) output [2:0]M15_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI ARVALID" *) output M15_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWADDR" *) output [32:0]M15_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWBURST" *) output [1:0]M15_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWCACHE" *) output [3:0]M15_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWLEN" *) output [3:0]M15_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWLOCK" *) output [1:0]M15_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWPROT" *) output [2:0]M15_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWQOS" *) output [3:0]M15_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWREADY" *) input M15_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWSIZE" *) output [2:0]M15_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI AWVALID" *) output M15_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI BREADY" *) output M15_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI BRESP" *) input [1:0]M15_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI BVALID" *) input M15_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI RDATA" *) input [255:0]M15_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI RLAST" *) input M15_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI RREADY" *) output M15_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI RRESP" *) input [1:0]M15_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI RVALID" *) input M15_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI WDATA" *) output [255:0]M15_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI WLAST" *) output M15_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI WREADY" *) input M15_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI WSTRB" *) output [31:0]M15_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M15_AXI WVALID" *) output M15_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARADDR" *) (* X_INTERFACE_MODE = "Slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S00_AXI, ADDR_WIDTH 64, ARUSER_WIDTH 114, AWUSER_WIDTH 114, BUSER_WIDTH 114, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, DATA_WIDTH 256, FREQ_HZ 250000000, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 1, HAS_LOCK 1, HAS_PROT 1, HAS_QOS 1, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 3, INSERT_VIP 0, MAX_BURST_LENGTH 256, NUM_READ_OUTSTANDING 32, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 16, NUM_WRITE_THREADS 1, PHASE 0.0, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 14, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 14" *) input [63:0]S00_AXI_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARBURST" *) input [1:0]S00_AXI_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARCACHE" *) input [3:0]S00_AXI_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARID" *) input [2:0]S00_AXI_arid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARLEN" *) input [7:0]S00_AXI_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARLOCK" *) input [0:0]S00_AXI_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARPROT" *) input [2:0]S00_AXI_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARQOS" *) input [3:0]S00_AXI_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARREADY" *) output S00_AXI_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARSIZE" *) input [2:0]S00_AXI_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARUSER" *) input [113:0]S00_AXI_aruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARVALID" *) input S00_AXI_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWADDR" *) input [63:0]S00_AXI_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWBURST" *) input [1:0]S00_AXI_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWCACHE" *) input [3:0]S00_AXI_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWID" *) input [2:0]S00_AXI_awid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWLEN" *) input [7:0]S00_AXI_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWLOCK" *) input [0:0]S00_AXI_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWPROT" *) input [2:0]S00_AXI_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWQOS" *) input [3:0]S00_AXI_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWREADY" *) output S00_AXI_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWSIZE" *) input [2:0]S00_AXI_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWUSER" *) input [113:0]S00_AXI_awuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWVALID" *) input S00_AXI_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BID" *) output [2:0]S00_AXI_bid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BREADY" *) input S00_AXI_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BRESP" *) output [1:0]S00_AXI_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BUSER" *) output [113:0]S00_AXI_buser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BVALID" *) output S00_AXI_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RDATA" *) output [255:0]S00_AXI_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RID" *) output [2:0]S00_AXI_rid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RLAST" *) output S00_AXI_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RREADY" *) input S00_AXI_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RRESP" *) output [1:0]S00_AXI_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RUSER" *) output [13:0]S00_AXI_ruser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RVALID" *) output S00_AXI_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WDATA" *) input [255:0]S00_AXI_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WLAST" *) input S00_AXI_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WREADY" *) output S00_AXI_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WSTRB" *) input [31:0]S00_AXI_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WUSER" *) input [13:0]S00_AXI_wuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WVALID" *) input S00_AXI_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.ACLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.ACLK, ASSOCIATED_BUSIF M00_AXI:M01_AXI:M02_AXI:M03_AXI:M04_AXI:M05_AXI:M06_AXI:M07_AXI:M08_AXI:M09_AXI:M10_AXI:M11_AXI:M12_AXI:M13_AXI:M14_AXI:M15_AXI:S00_AXI, ASSOCIATED_CLKEN m_sc_aclken, CLK_DOMAIN xdma_hbm_xdma_0_0_axi_aclk, FREQ_HZ 250000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input aclk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.ARESETN RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.ARESETN, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) input aresetn;

  wire [32:0]M00_AXI_araddr;
  wire [1:0]M00_AXI_arburst;
  wire [3:0]M00_AXI_arcache;
  wire [3:0]M00_AXI_arlen;
  wire [1:0]M00_AXI_arlock;
  wire [2:0]M00_AXI_arprot;
  wire [3:0]M00_AXI_arqos;
  wire M00_AXI_arready;
  wire [2:0]M00_AXI_arsize;
  wire M00_AXI_arvalid;
  wire [32:0]M00_AXI_awaddr;
  wire [1:0]M00_AXI_awburst;
  wire [3:0]M00_AXI_awcache;
  wire [3:0]M00_AXI_awlen;
  wire [1:0]M00_AXI_awlock;
  wire [2:0]M00_AXI_awprot;
  wire [3:0]M00_AXI_awqos;
  wire M00_AXI_awready;
  wire [2:0]M00_AXI_awsize;
  wire M00_AXI_awvalid;
  wire M00_AXI_bready;
  wire [1:0]M00_AXI_bresp;
  wire M00_AXI_bvalid;
  wire [255:0]M00_AXI_rdata;
  wire M00_AXI_rlast;
  wire M00_AXI_rready;
  wire [1:0]M00_AXI_rresp;
  wire M00_AXI_rvalid;
  wire [255:0]M00_AXI_wdata;
  wire M00_AXI_wlast;
  wire M00_AXI_wready;
  wire [31:0]M00_AXI_wstrb;
  wire M00_AXI_wvalid;
  wire [32:0]M01_AXI_araddr;
  wire [1:0]M01_AXI_arburst;
  wire [3:0]M01_AXI_arcache;
  wire [3:0]M01_AXI_arlen;
  wire [1:0]M01_AXI_arlock;
  wire [2:0]M01_AXI_arprot;
  wire [3:0]M01_AXI_arqos;
  wire M01_AXI_arready;
  wire [2:0]M01_AXI_arsize;
  wire M01_AXI_arvalid;
  wire [32:0]M01_AXI_awaddr;
  wire [1:0]M01_AXI_awburst;
  wire [3:0]M01_AXI_awcache;
  wire [3:0]M01_AXI_awlen;
  wire [1:0]M01_AXI_awlock;
  wire [2:0]M01_AXI_awprot;
  wire [3:0]M01_AXI_awqos;
  wire M01_AXI_awready;
  wire [2:0]M01_AXI_awsize;
  wire M01_AXI_awvalid;
  wire M01_AXI_bready;
  wire [1:0]M01_AXI_bresp;
  wire M01_AXI_bvalid;
  wire [255:0]M01_AXI_rdata;
  wire M01_AXI_rlast;
  wire M01_AXI_rready;
  wire [1:0]M01_AXI_rresp;
  wire M01_AXI_rvalid;
  wire [255:0]M01_AXI_wdata;
  wire M01_AXI_wlast;
  wire M01_AXI_wready;
  wire [31:0]M01_AXI_wstrb;
  wire M01_AXI_wvalid;
  wire [32:0]M02_AXI_araddr;
  wire [1:0]M02_AXI_arburst;
  wire [3:0]M02_AXI_arcache;
  wire [3:0]M02_AXI_arlen;
  wire [1:0]M02_AXI_arlock;
  wire [2:0]M02_AXI_arprot;
  wire [3:0]M02_AXI_arqos;
  wire M02_AXI_arready;
  wire [2:0]M02_AXI_arsize;
  wire M02_AXI_arvalid;
  wire [32:0]M02_AXI_awaddr;
  wire [1:0]M02_AXI_awburst;
  wire [3:0]M02_AXI_awcache;
  wire [3:0]M02_AXI_awlen;
  wire [1:0]M02_AXI_awlock;
  wire [2:0]M02_AXI_awprot;
  wire [3:0]M02_AXI_awqos;
  wire M02_AXI_awready;
  wire [2:0]M02_AXI_awsize;
  wire M02_AXI_awvalid;
  wire M02_AXI_bready;
  wire [1:0]M02_AXI_bresp;
  wire M02_AXI_bvalid;
  wire [255:0]M02_AXI_rdata;
  wire M02_AXI_rlast;
  wire M02_AXI_rready;
  wire [1:0]M02_AXI_rresp;
  wire M02_AXI_rvalid;
  wire [255:0]M02_AXI_wdata;
  wire M02_AXI_wlast;
  wire M02_AXI_wready;
  wire [31:0]M02_AXI_wstrb;
  wire M02_AXI_wvalid;
  wire [32:0]M03_AXI_araddr;
  wire [1:0]M03_AXI_arburst;
  wire [3:0]M03_AXI_arcache;
  wire [3:0]M03_AXI_arlen;
  wire [1:0]M03_AXI_arlock;
  wire [2:0]M03_AXI_arprot;
  wire [3:0]M03_AXI_arqos;
  wire M03_AXI_arready;
  wire [2:0]M03_AXI_arsize;
  wire M03_AXI_arvalid;
  wire [32:0]M03_AXI_awaddr;
  wire [1:0]M03_AXI_awburst;
  wire [3:0]M03_AXI_awcache;
  wire [3:0]M03_AXI_awlen;
  wire [1:0]M03_AXI_awlock;
  wire [2:0]M03_AXI_awprot;
  wire [3:0]M03_AXI_awqos;
  wire M03_AXI_awready;
  wire [2:0]M03_AXI_awsize;
  wire M03_AXI_awvalid;
  wire M03_AXI_bready;
  wire [1:0]M03_AXI_bresp;
  wire M03_AXI_bvalid;
  wire [255:0]M03_AXI_rdata;
  wire M03_AXI_rlast;
  wire M03_AXI_rready;
  wire [1:0]M03_AXI_rresp;
  wire M03_AXI_rvalid;
  wire [255:0]M03_AXI_wdata;
  wire M03_AXI_wlast;
  wire M03_AXI_wready;
  wire [31:0]M03_AXI_wstrb;
  wire M03_AXI_wvalid;
  wire [32:0]M04_AXI_araddr;
  wire [1:0]M04_AXI_arburst;
  wire [3:0]M04_AXI_arcache;
  wire [3:0]M04_AXI_arlen;
  wire [1:0]M04_AXI_arlock;
  wire [2:0]M04_AXI_arprot;
  wire [3:0]M04_AXI_arqos;
  wire M04_AXI_arready;
  wire [2:0]M04_AXI_arsize;
  wire M04_AXI_arvalid;
  wire [32:0]M04_AXI_awaddr;
  wire [1:0]M04_AXI_awburst;
  wire [3:0]M04_AXI_awcache;
  wire [3:0]M04_AXI_awlen;
  wire [1:0]M04_AXI_awlock;
  wire [2:0]M04_AXI_awprot;
  wire [3:0]M04_AXI_awqos;
  wire M04_AXI_awready;
  wire [2:0]M04_AXI_awsize;
  wire M04_AXI_awvalid;
  wire M04_AXI_bready;
  wire [1:0]M04_AXI_bresp;
  wire M04_AXI_bvalid;
  wire [255:0]M04_AXI_rdata;
  wire M04_AXI_rlast;
  wire M04_AXI_rready;
  wire [1:0]M04_AXI_rresp;
  wire M04_AXI_rvalid;
  wire [255:0]M04_AXI_wdata;
  wire M04_AXI_wlast;
  wire M04_AXI_wready;
  wire [31:0]M04_AXI_wstrb;
  wire M04_AXI_wvalid;
  wire [32:0]M05_AXI_araddr;
  wire [1:0]M05_AXI_arburst;
  wire [3:0]M05_AXI_arcache;
  wire [3:0]M05_AXI_arlen;
  wire [1:0]M05_AXI_arlock;
  wire [2:0]M05_AXI_arprot;
  wire [3:0]M05_AXI_arqos;
  wire M05_AXI_arready;
  wire [2:0]M05_AXI_arsize;
  wire M05_AXI_arvalid;
  wire [32:0]M05_AXI_awaddr;
  wire [1:0]M05_AXI_awburst;
  wire [3:0]M05_AXI_awcache;
  wire [3:0]M05_AXI_awlen;
  wire [1:0]M05_AXI_awlock;
  wire [2:0]M05_AXI_awprot;
  wire [3:0]M05_AXI_awqos;
  wire M05_AXI_awready;
  wire [2:0]M05_AXI_awsize;
  wire M05_AXI_awvalid;
  wire M05_AXI_bready;
  wire [1:0]M05_AXI_bresp;
  wire M05_AXI_bvalid;
  wire [255:0]M05_AXI_rdata;
  wire M05_AXI_rlast;
  wire M05_AXI_rready;
  wire [1:0]M05_AXI_rresp;
  wire M05_AXI_rvalid;
  wire [255:0]M05_AXI_wdata;
  wire M05_AXI_wlast;
  wire M05_AXI_wready;
  wire [31:0]M05_AXI_wstrb;
  wire M05_AXI_wvalid;
  wire [32:0]M06_AXI_araddr;
  wire [1:0]M06_AXI_arburst;
  wire [3:0]M06_AXI_arcache;
  wire [3:0]M06_AXI_arlen;
  wire [1:0]M06_AXI_arlock;
  wire [2:0]M06_AXI_arprot;
  wire [3:0]M06_AXI_arqos;
  wire M06_AXI_arready;
  wire [2:0]M06_AXI_arsize;
  wire M06_AXI_arvalid;
  wire [32:0]M06_AXI_awaddr;
  wire [1:0]M06_AXI_awburst;
  wire [3:0]M06_AXI_awcache;
  wire [3:0]M06_AXI_awlen;
  wire [1:0]M06_AXI_awlock;
  wire [2:0]M06_AXI_awprot;
  wire [3:0]M06_AXI_awqos;
  wire M06_AXI_awready;
  wire [2:0]M06_AXI_awsize;
  wire M06_AXI_awvalid;
  wire M06_AXI_bready;
  wire [1:0]M06_AXI_bresp;
  wire M06_AXI_bvalid;
  wire [255:0]M06_AXI_rdata;
  wire M06_AXI_rlast;
  wire M06_AXI_rready;
  wire [1:0]M06_AXI_rresp;
  wire M06_AXI_rvalid;
  wire [255:0]M06_AXI_wdata;
  wire M06_AXI_wlast;
  wire M06_AXI_wready;
  wire [31:0]M06_AXI_wstrb;
  wire M06_AXI_wvalid;
  wire [32:0]M07_AXI_araddr;
  wire [1:0]M07_AXI_arburst;
  wire [3:0]M07_AXI_arcache;
  wire [3:0]M07_AXI_arlen;
  wire [1:0]M07_AXI_arlock;
  wire [2:0]M07_AXI_arprot;
  wire [3:0]M07_AXI_arqos;
  wire M07_AXI_arready;
  wire [2:0]M07_AXI_arsize;
  wire M07_AXI_arvalid;
  wire [32:0]M07_AXI_awaddr;
  wire [1:0]M07_AXI_awburst;
  wire [3:0]M07_AXI_awcache;
  wire [3:0]M07_AXI_awlen;
  wire [1:0]M07_AXI_awlock;
  wire [2:0]M07_AXI_awprot;
  wire [3:0]M07_AXI_awqos;
  wire M07_AXI_awready;
  wire [2:0]M07_AXI_awsize;
  wire M07_AXI_awvalid;
  wire M07_AXI_bready;
  wire [1:0]M07_AXI_bresp;
  wire M07_AXI_bvalid;
  wire [255:0]M07_AXI_rdata;
  wire M07_AXI_rlast;
  wire M07_AXI_rready;
  wire [1:0]M07_AXI_rresp;
  wire M07_AXI_rvalid;
  wire [255:0]M07_AXI_wdata;
  wire M07_AXI_wlast;
  wire M07_AXI_wready;
  wire [31:0]M07_AXI_wstrb;
  wire M07_AXI_wvalid;
  wire [32:0]M08_AXI_araddr;
  wire [1:0]M08_AXI_arburst;
  wire [3:0]M08_AXI_arcache;
  wire [3:0]M08_AXI_arlen;
  wire [1:0]M08_AXI_arlock;
  wire [2:0]M08_AXI_arprot;
  wire [3:0]M08_AXI_arqos;
  wire M08_AXI_arready;
  wire [2:0]M08_AXI_arsize;
  wire M08_AXI_arvalid;
  wire [32:0]M08_AXI_awaddr;
  wire [1:0]M08_AXI_awburst;
  wire [3:0]M08_AXI_awcache;
  wire [3:0]M08_AXI_awlen;
  wire [1:0]M08_AXI_awlock;
  wire [2:0]M08_AXI_awprot;
  wire [3:0]M08_AXI_awqos;
  wire M08_AXI_awready;
  wire [2:0]M08_AXI_awsize;
  wire M08_AXI_awvalid;
  wire M08_AXI_bready;
  wire [1:0]M08_AXI_bresp;
  wire M08_AXI_bvalid;
  wire [255:0]M08_AXI_rdata;
  wire M08_AXI_rlast;
  wire M08_AXI_rready;
  wire [1:0]M08_AXI_rresp;
  wire M08_AXI_rvalid;
  wire [255:0]M08_AXI_wdata;
  wire M08_AXI_wlast;
  wire M08_AXI_wready;
  wire [31:0]M08_AXI_wstrb;
  wire M08_AXI_wvalid;
  wire [32:0]M09_AXI_araddr;
  wire [1:0]M09_AXI_arburst;
  wire [3:0]M09_AXI_arcache;
  wire [3:0]M09_AXI_arlen;
  wire [1:0]M09_AXI_arlock;
  wire [2:0]M09_AXI_arprot;
  wire [3:0]M09_AXI_arqos;
  wire M09_AXI_arready;
  wire [2:0]M09_AXI_arsize;
  wire M09_AXI_arvalid;
  wire [32:0]M09_AXI_awaddr;
  wire [1:0]M09_AXI_awburst;
  wire [3:0]M09_AXI_awcache;
  wire [3:0]M09_AXI_awlen;
  wire [1:0]M09_AXI_awlock;
  wire [2:0]M09_AXI_awprot;
  wire [3:0]M09_AXI_awqos;
  wire M09_AXI_awready;
  wire [2:0]M09_AXI_awsize;
  wire M09_AXI_awvalid;
  wire M09_AXI_bready;
  wire [1:0]M09_AXI_bresp;
  wire M09_AXI_bvalid;
  wire [255:0]M09_AXI_rdata;
  wire M09_AXI_rlast;
  wire M09_AXI_rready;
  wire [1:0]M09_AXI_rresp;
  wire M09_AXI_rvalid;
  wire [255:0]M09_AXI_wdata;
  wire M09_AXI_wlast;
  wire M09_AXI_wready;
  wire [31:0]M09_AXI_wstrb;
  wire M09_AXI_wvalid;
  wire [32:0]M10_AXI_araddr;
  wire [1:0]M10_AXI_arburst;
  wire [3:0]M10_AXI_arcache;
  wire [3:0]M10_AXI_arlen;
  wire [1:0]M10_AXI_arlock;
  wire [2:0]M10_AXI_arprot;
  wire [3:0]M10_AXI_arqos;
  wire M10_AXI_arready;
  wire [2:0]M10_AXI_arsize;
  wire M10_AXI_arvalid;
  wire [32:0]M10_AXI_awaddr;
  wire [1:0]M10_AXI_awburst;
  wire [3:0]M10_AXI_awcache;
  wire [3:0]M10_AXI_awlen;
  wire [1:0]M10_AXI_awlock;
  wire [2:0]M10_AXI_awprot;
  wire [3:0]M10_AXI_awqos;
  wire M10_AXI_awready;
  wire [2:0]M10_AXI_awsize;
  wire M10_AXI_awvalid;
  wire M10_AXI_bready;
  wire [1:0]M10_AXI_bresp;
  wire M10_AXI_bvalid;
  wire [255:0]M10_AXI_rdata;
  wire M10_AXI_rlast;
  wire M10_AXI_rready;
  wire [1:0]M10_AXI_rresp;
  wire M10_AXI_rvalid;
  wire [255:0]M10_AXI_wdata;
  wire M10_AXI_wlast;
  wire M10_AXI_wready;
  wire [31:0]M10_AXI_wstrb;
  wire M10_AXI_wvalid;
  wire [32:0]M11_AXI_araddr;
  wire [1:0]M11_AXI_arburst;
  wire [3:0]M11_AXI_arcache;
  wire [3:0]M11_AXI_arlen;
  wire [1:0]M11_AXI_arlock;
  wire [2:0]M11_AXI_arprot;
  wire [3:0]M11_AXI_arqos;
  wire M11_AXI_arready;
  wire [2:0]M11_AXI_arsize;
  wire M11_AXI_arvalid;
  wire [32:0]M11_AXI_awaddr;
  wire [1:0]M11_AXI_awburst;
  wire [3:0]M11_AXI_awcache;
  wire [3:0]M11_AXI_awlen;
  wire [1:0]M11_AXI_awlock;
  wire [2:0]M11_AXI_awprot;
  wire [3:0]M11_AXI_awqos;
  wire M11_AXI_awready;
  wire [2:0]M11_AXI_awsize;
  wire M11_AXI_awvalid;
  wire M11_AXI_bready;
  wire [1:0]M11_AXI_bresp;
  wire M11_AXI_bvalid;
  wire [255:0]M11_AXI_rdata;
  wire M11_AXI_rlast;
  wire M11_AXI_rready;
  wire [1:0]M11_AXI_rresp;
  wire M11_AXI_rvalid;
  wire [255:0]M11_AXI_wdata;
  wire M11_AXI_wlast;
  wire M11_AXI_wready;
  wire [31:0]M11_AXI_wstrb;
  wire M11_AXI_wvalid;
  wire [32:0]M12_AXI_araddr;
  wire [1:0]M12_AXI_arburst;
  wire [3:0]M12_AXI_arcache;
  wire [3:0]M12_AXI_arlen;
  wire [1:0]M12_AXI_arlock;
  wire [2:0]M12_AXI_arprot;
  wire [3:0]M12_AXI_arqos;
  wire M12_AXI_arready;
  wire [2:0]M12_AXI_arsize;
  wire M12_AXI_arvalid;
  wire [32:0]M12_AXI_awaddr;
  wire [1:0]M12_AXI_awburst;
  wire [3:0]M12_AXI_awcache;
  wire [3:0]M12_AXI_awlen;
  wire [1:0]M12_AXI_awlock;
  wire [2:0]M12_AXI_awprot;
  wire [3:0]M12_AXI_awqos;
  wire M12_AXI_awready;
  wire [2:0]M12_AXI_awsize;
  wire M12_AXI_awvalid;
  wire M12_AXI_bready;
  wire [1:0]M12_AXI_bresp;
  wire M12_AXI_bvalid;
  wire [255:0]M12_AXI_rdata;
  wire M12_AXI_rlast;
  wire M12_AXI_rready;
  wire [1:0]M12_AXI_rresp;
  wire M12_AXI_rvalid;
  wire [255:0]M12_AXI_wdata;
  wire M12_AXI_wlast;
  wire M12_AXI_wready;
  wire [31:0]M12_AXI_wstrb;
  wire M12_AXI_wvalid;
  wire [32:0]M13_AXI_araddr;
  wire [1:0]M13_AXI_arburst;
  wire [3:0]M13_AXI_arcache;
  wire [3:0]M13_AXI_arlen;
  wire [1:0]M13_AXI_arlock;
  wire [2:0]M13_AXI_arprot;
  wire [3:0]M13_AXI_arqos;
  wire M13_AXI_arready;
  wire [2:0]M13_AXI_arsize;
  wire M13_AXI_arvalid;
  wire [32:0]M13_AXI_awaddr;
  wire [1:0]M13_AXI_awburst;
  wire [3:0]M13_AXI_awcache;
  wire [3:0]M13_AXI_awlen;
  wire [1:0]M13_AXI_awlock;
  wire [2:0]M13_AXI_awprot;
  wire [3:0]M13_AXI_awqos;
  wire M13_AXI_awready;
  wire [2:0]M13_AXI_awsize;
  wire M13_AXI_awvalid;
  wire M13_AXI_bready;
  wire [1:0]M13_AXI_bresp;
  wire M13_AXI_bvalid;
  wire [255:0]M13_AXI_rdata;
  wire M13_AXI_rlast;
  wire M13_AXI_rready;
  wire [1:0]M13_AXI_rresp;
  wire M13_AXI_rvalid;
  wire [255:0]M13_AXI_wdata;
  wire M13_AXI_wlast;
  wire M13_AXI_wready;
  wire [31:0]M13_AXI_wstrb;
  wire M13_AXI_wvalid;
  wire [32:0]M14_AXI_araddr;
  wire [1:0]M14_AXI_arburst;
  wire [3:0]M14_AXI_arcache;
  wire [3:0]M14_AXI_arlen;
  wire [1:0]M14_AXI_arlock;
  wire [2:0]M14_AXI_arprot;
  wire [3:0]M14_AXI_arqos;
  wire M14_AXI_arready;
  wire [2:0]M14_AXI_arsize;
  wire M14_AXI_arvalid;
  wire [32:0]M14_AXI_awaddr;
  wire [1:0]M14_AXI_awburst;
  wire [3:0]M14_AXI_awcache;
  wire [3:0]M14_AXI_awlen;
  wire [1:0]M14_AXI_awlock;
  wire [2:0]M14_AXI_awprot;
  wire [3:0]M14_AXI_awqos;
  wire M14_AXI_awready;
  wire [2:0]M14_AXI_awsize;
  wire M14_AXI_awvalid;
  wire M14_AXI_bready;
  wire [1:0]M14_AXI_bresp;
  wire M14_AXI_bvalid;
  wire [255:0]M14_AXI_rdata;
  wire M14_AXI_rlast;
  wire M14_AXI_rready;
  wire [1:0]M14_AXI_rresp;
  wire M14_AXI_rvalid;
  wire [255:0]M14_AXI_wdata;
  wire M14_AXI_wlast;
  wire M14_AXI_wready;
  wire [31:0]M14_AXI_wstrb;
  wire M14_AXI_wvalid;
  wire [32:0]M15_AXI_araddr;
  wire [1:0]M15_AXI_arburst;
  wire [3:0]M15_AXI_arcache;
  wire [3:0]M15_AXI_arlen;
  wire [1:0]M15_AXI_arlock;
  wire [2:0]M15_AXI_arprot;
  wire [3:0]M15_AXI_arqos;
  wire M15_AXI_arready;
  wire [2:0]M15_AXI_arsize;
  wire M15_AXI_arvalid;
  wire [32:0]M15_AXI_awaddr;
  wire [1:0]M15_AXI_awburst;
  wire [3:0]M15_AXI_awcache;
  wire [3:0]M15_AXI_awlen;
  wire [1:0]M15_AXI_awlock;
  wire [2:0]M15_AXI_awprot;
  wire [3:0]M15_AXI_awqos;
  wire M15_AXI_awready;
  wire [2:0]M15_AXI_awsize;
  wire M15_AXI_awvalid;
  wire M15_AXI_bready;
  wire [1:0]M15_AXI_bresp;
  wire M15_AXI_bvalid;
  wire [255:0]M15_AXI_rdata;
  wire M15_AXI_rlast;
  wire M15_AXI_rready;
  wire [1:0]M15_AXI_rresp;
  wire M15_AXI_rvalid;
  wire [255:0]M15_AXI_wdata;
  wire M15_AXI_wlast;
  wire M15_AXI_wready;
  wire [31:0]M15_AXI_wstrb;
  wire M15_AXI_wvalid;
  wire [63:0]S00_AXI_araddr;
  wire [1:0]S00_AXI_arburst;
  wire [3:0]S00_AXI_arcache;
  wire [2:0]S00_AXI_arid;
  wire [7:0]S00_AXI_arlen;
  wire [0:0]S00_AXI_arlock;
  wire [2:0]S00_AXI_arprot;
  wire [3:0]S00_AXI_arqos;
  wire S00_AXI_arready;
  wire [2:0]S00_AXI_arsize;
  wire [113:0]S00_AXI_aruser;
  wire S00_AXI_arvalid;
  wire [63:0]S00_AXI_awaddr;
  wire [1:0]S00_AXI_awburst;
  wire [3:0]S00_AXI_awcache;
  wire [2:0]S00_AXI_awid;
  wire [7:0]S00_AXI_awlen;
  wire [0:0]S00_AXI_awlock;
  wire [2:0]S00_AXI_awprot;
  wire [3:0]S00_AXI_awqos;
  wire S00_AXI_awready;
  wire [2:0]S00_AXI_awsize;
  wire [113:0]S00_AXI_awuser;
  wire S00_AXI_awvalid;
  wire [2:0]S00_AXI_bid;
  wire S00_AXI_bready;
  wire [1:0]S00_AXI_bresp;
  wire [113:0]S00_AXI_buser;
  wire S00_AXI_bvalid;
  wire [255:0]S00_AXI_rdata;
  wire [2:0]S00_AXI_rid;
  wire S00_AXI_rlast;
  wire S00_AXI_rready;
  wire [1:0]S00_AXI_rresp;
  wire [13:0]S00_AXI_ruser;
  wire S00_AXI_rvalid;
  wire [255:0]S00_AXI_wdata;
  wire S00_AXI_wlast;
  wire S00_AXI_wready;
  wire [31:0]S00_AXI_wstrb;
  wire [13:0]S00_AXI_wuser;
  wire S00_AXI_wvalid;
  wire [0:0]S_SC_AR_10_INFO;
  wire [301:0]S_SC_AR_10_PAYLD;
  wire [0:0]S_SC_AR_10_RECV;
  wire [0:0]S_SC_AR_10_REQ;
  wire [0:0]S_SC_AR_10_SEND;
  wire [0:0]S_SC_AR_11_INFO;
  wire [301:0]S_SC_AR_11_PAYLD;
  wire [0:0]S_SC_AR_11_RECV;
  wire [0:0]S_SC_AR_11_REQ;
  wire [0:0]S_SC_AR_11_SEND;
  wire [0:0]S_SC_AR_12_INFO;
  wire [301:0]S_SC_AR_12_PAYLD;
  wire [0:0]S_SC_AR_12_RECV;
  wire [0:0]S_SC_AR_12_REQ;
  wire [0:0]S_SC_AR_12_SEND;
  wire [0:0]S_SC_AR_13_INFO;
  wire [301:0]S_SC_AR_13_PAYLD;
  wire [0:0]S_SC_AR_13_RECV;
  wire [0:0]S_SC_AR_13_REQ;
  wire [0:0]S_SC_AR_13_SEND;
  wire [0:0]S_SC_AR_14_INFO;
  wire [301:0]S_SC_AR_14_PAYLD;
  wire [0:0]S_SC_AR_14_RECV;
  wire [0:0]S_SC_AR_14_REQ;
  wire [0:0]S_SC_AR_14_SEND;
  wire [0:0]S_SC_AR_15_INFO;
  wire [301:0]S_SC_AR_15_PAYLD;
  wire [0:0]S_SC_AR_15_RECV;
  wire [0:0]S_SC_AR_15_REQ;
  wire [0:0]S_SC_AR_15_SEND;
  wire [0:0]S_SC_AR_16_INFO;
  wire [301:0]S_SC_AR_16_PAYLD;
  wire [0:0]S_SC_AR_16_RECV;
  wire [0:0]S_SC_AR_16_REQ;
  wire [0:0]S_SC_AR_16_SEND;
  wire [0:0]S_SC_AR_17_INFO;
  wire [301:0]S_SC_AR_17_PAYLD;
  wire [0:0]S_SC_AR_17_RECV;
  wire [0:0]S_SC_AR_17_REQ;
  wire [0:0]S_SC_AR_17_SEND;
  wire [0:0]S_SC_AR_1_INFO;
  wire [301:0]S_SC_AR_1_PAYLD;
  wire [0:0]S_SC_AR_1_RECV;
  wire S_SC_AR_1_REQ;
  wire S_SC_AR_1_SEND;
  wire [0:0]S_SC_AR_2_INFO;
  wire [301:0]S_SC_AR_2_PAYLD;
  wire [0:0]S_SC_AR_2_RECV;
  wire [0:0]S_SC_AR_2_REQ;
  wire [0:0]S_SC_AR_2_SEND;
  wire [0:0]S_SC_AR_3_INFO;
  wire [301:0]S_SC_AR_3_PAYLD;
  wire [0:0]S_SC_AR_3_RECV;
  wire [0:0]S_SC_AR_3_REQ;
  wire [0:0]S_SC_AR_3_SEND;
  wire [0:0]S_SC_AR_4_INFO;
  wire [301:0]S_SC_AR_4_PAYLD;
  wire [0:0]S_SC_AR_4_RECV;
  wire [0:0]S_SC_AR_4_REQ;
  wire [0:0]S_SC_AR_4_SEND;
  wire [0:0]S_SC_AR_5_INFO;
  wire [301:0]S_SC_AR_5_PAYLD;
  wire [0:0]S_SC_AR_5_RECV;
  wire [0:0]S_SC_AR_5_REQ;
  wire [0:0]S_SC_AR_5_SEND;
  wire [0:0]S_SC_AR_6_INFO;
  wire [301:0]S_SC_AR_6_PAYLD;
  wire [0:0]S_SC_AR_6_RECV;
  wire [0:0]S_SC_AR_6_REQ;
  wire [0:0]S_SC_AR_6_SEND;
  wire [0:0]S_SC_AR_7_INFO;
  wire [301:0]S_SC_AR_7_PAYLD;
  wire [0:0]S_SC_AR_7_RECV;
  wire [0:0]S_SC_AR_7_REQ;
  wire [0:0]S_SC_AR_7_SEND;
  wire [0:0]S_SC_AR_8_INFO;
  wire [301:0]S_SC_AR_8_PAYLD;
  wire [0:0]S_SC_AR_8_RECV;
  wire [0:0]S_SC_AR_8_REQ;
  wire [0:0]S_SC_AR_8_SEND;
  wire [0:0]S_SC_AR_9_INFO;
  wire [301:0]S_SC_AR_9_PAYLD;
  wire [0:0]S_SC_AR_9_RECV;
  wire [0:0]S_SC_AR_9_REQ;
  wire [0:0]S_SC_AR_9_SEND;
  wire [0:0]S_SC_AW_10_INFO;
  wire [301:0]S_SC_AW_10_PAYLD;
  wire [0:0]S_SC_AW_10_RECV;
  wire [0:0]S_SC_AW_10_REQ;
  wire [0:0]S_SC_AW_10_SEND;
  wire [0:0]S_SC_AW_11_INFO;
  wire [301:0]S_SC_AW_11_PAYLD;
  wire [0:0]S_SC_AW_11_RECV;
  wire [0:0]S_SC_AW_11_REQ;
  wire [0:0]S_SC_AW_11_SEND;
  wire [0:0]S_SC_AW_12_INFO;
  wire [301:0]S_SC_AW_12_PAYLD;
  wire [0:0]S_SC_AW_12_RECV;
  wire [0:0]S_SC_AW_12_REQ;
  wire [0:0]S_SC_AW_12_SEND;
  wire [0:0]S_SC_AW_13_INFO;
  wire [301:0]S_SC_AW_13_PAYLD;
  wire [0:0]S_SC_AW_13_RECV;
  wire [0:0]S_SC_AW_13_REQ;
  wire [0:0]S_SC_AW_13_SEND;
  wire [0:0]S_SC_AW_14_INFO;
  wire [301:0]S_SC_AW_14_PAYLD;
  wire [0:0]S_SC_AW_14_RECV;
  wire [0:0]S_SC_AW_14_REQ;
  wire [0:0]S_SC_AW_14_SEND;
  wire [0:0]S_SC_AW_15_INFO;
  wire [301:0]S_SC_AW_15_PAYLD;
  wire [0:0]S_SC_AW_15_RECV;
  wire [0:0]S_SC_AW_15_REQ;
  wire [0:0]S_SC_AW_15_SEND;
  wire [0:0]S_SC_AW_16_INFO;
  wire [301:0]S_SC_AW_16_PAYLD;
  wire [0:0]S_SC_AW_16_RECV;
  wire [0:0]S_SC_AW_16_REQ;
  wire [0:0]S_SC_AW_16_SEND;
  wire [0:0]S_SC_AW_17_INFO;
  wire [301:0]S_SC_AW_17_PAYLD;
  wire [0:0]S_SC_AW_17_RECV;
  wire [0:0]S_SC_AW_17_REQ;
  wire [0:0]S_SC_AW_17_SEND;
  wire [0:0]S_SC_AW_1_INFO;
  wire [301:0]S_SC_AW_1_PAYLD;
  wire [0:0]S_SC_AW_1_RECV;
  wire S_SC_AW_1_REQ;
  wire S_SC_AW_1_SEND;
  wire [0:0]S_SC_AW_2_INFO;
  wire [301:0]S_SC_AW_2_PAYLD;
  wire [0:0]S_SC_AW_2_RECV;
  wire [0:0]S_SC_AW_2_REQ;
  wire [0:0]S_SC_AW_2_SEND;
  wire [0:0]S_SC_AW_3_INFO;
  wire [301:0]S_SC_AW_3_PAYLD;
  wire [0:0]S_SC_AW_3_RECV;
  wire [0:0]S_SC_AW_3_REQ;
  wire [0:0]S_SC_AW_3_SEND;
  wire [0:0]S_SC_AW_4_INFO;
  wire [301:0]S_SC_AW_4_PAYLD;
  wire [0:0]S_SC_AW_4_RECV;
  wire [0:0]S_SC_AW_4_REQ;
  wire [0:0]S_SC_AW_4_SEND;
  wire [0:0]S_SC_AW_5_INFO;
  wire [301:0]S_SC_AW_5_PAYLD;
  wire [0:0]S_SC_AW_5_RECV;
  wire [0:0]S_SC_AW_5_REQ;
  wire [0:0]S_SC_AW_5_SEND;
  wire [0:0]S_SC_AW_6_INFO;
  wire [301:0]S_SC_AW_6_PAYLD;
  wire [0:0]S_SC_AW_6_RECV;
  wire [0:0]S_SC_AW_6_REQ;
  wire [0:0]S_SC_AW_6_SEND;
  wire [0:0]S_SC_AW_7_INFO;
  wire [301:0]S_SC_AW_7_PAYLD;
  wire [0:0]S_SC_AW_7_RECV;
  wire [0:0]S_SC_AW_7_REQ;
  wire [0:0]S_SC_AW_7_SEND;
  wire [0:0]S_SC_AW_8_INFO;
  wire [301:0]S_SC_AW_8_PAYLD;
  wire [0:0]S_SC_AW_8_RECV;
  wire [0:0]S_SC_AW_8_REQ;
  wire [0:0]S_SC_AW_8_SEND;
  wire [0:0]S_SC_AW_9_INFO;
  wire [301:0]S_SC_AW_9_PAYLD;
  wire [0:0]S_SC_AW_9_RECV;
  wire [0:0]S_SC_AW_9_REQ;
  wire [0:0]S_SC_AW_9_SEND;
  wire [0:0]S_SC_B_10_INFO;
  wire [119:0]S_SC_B_10_PAYLD;
  wire [0:0]S_SC_B_10_RECV;
  wire S_SC_B_10_REQ;
  wire S_SC_B_10_SEND;
  wire [0:0]S_SC_B_11_INFO;
  wire [119:0]S_SC_B_11_PAYLD;
  wire [0:0]S_SC_B_11_RECV;
  wire S_SC_B_11_REQ;
  wire S_SC_B_11_SEND;
  wire [0:0]S_SC_B_12_INFO;
  wire [119:0]S_SC_B_12_PAYLD;
  wire [0:0]S_SC_B_12_RECV;
  wire S_SC_B_12_REQ;
  wire S_SC_B_12_SEND;
  wire [0:0]S_SC_B_13_INFO;
  wire [119:0]S_SC_B_13_PAYLD;
  wire [0:0]S_SC_B_13_RECV;
  wire S_SC_B_13_REQ;
  wire S_SC_B_13_SEND;
  wire [0:0]S_SC_B_14_INFO;
  wire [119:0]S_SC_B_14_PAYLD;
  wire [0:0]S_SC_B_14_RECV;
  wire S_SC_B_14_REQ;
  wire S_SC_B_14_SEND;
  wire [0:0]S_SC_B_15_INFO;
  wire [119:0]S_SC_B_15_PAYLD;
  wire [0:0]S_SC_B_15_RECV;
  wire S_SC_B_15_REQ;
  wire S_SC_B_15_SEND;
  wire [0:0]S_SC_B_16_INFO;
  wire [119:0]S_SC_B_16_PAYLD;
  wire [0:0]S_SC_B_16_RECV;
  wire S_SC_B_16_REQ;
  wire S_SC_B_16_SEND;
  wire [0:0]S_SC_B_17_INFO;
  wire [119:0]S_SC_B_17_PAYLD;
  wire [0:0]S_SC_B_17_RECV;
  wire S_SC_B_17_REQ;
  wire S_SC_B_17_SEND;
  wire [15:0]S_SC_B_1_INFO;
  wire [119:0]S_SC_B_1_PAYLD;
  wire [15:0]S_SC_B_1_RECV;
  wire [15:0]S_SC_B_1_REQ;
  wire [15:0]S_SC_B_1_SEND;
  wire [0:0]S_SC_B_2_INFO;
  wire [119:0]S_SC_B_2_PAYLD;
  wire [0:0]S_SC_B_2_RECV;
  wire S_SC_B_2_REQ;
  wire S_SC_B_2_SEND;
  wire [0:0]S_SC_B_3_INFO;
  wire [119:0]S_SC_B_3_PAYLD;
  wire [0:0]S_SC_B_3_RECV;
  wire S_SC_B_3_REQ;
  wire S_SC_B_3_SEND;
  wire [0:0]S_SC_B_4_INFO;
  wire [119:0]S_SC_B_4_PAYLD;
  wire [0:0]S_SC_B_4_RECV;
  wire S_SC_B_4_REQ;
  wire S_SC_B_4_SEND;
  wire [0:0]S_SC_B_5_INFO;
  wire [119:0]S_SC_B_5_PAYLD;
  wire [0:0]S_SC_B_5_RECV;
  wire S_SC_B_5_REQ;
  wire S_SC_B_5_SEND;
  wire [0:0]S_SC_B_6_INFO;
  wire [119:0]S_SC_B_6_PAYLD;
  wire [0:0]S_SC_B_6_RECV;
  wire S_SC_B_6_REQ;
  wire S_SC_B_6_SEND;
  wire [0:0]S_SC_B_7_INFO;
  wire [119:0]S_SC_B_7_PAYLD;
  wire [0:0]S_SC_B_7_RECV;
  wire S_SC_B_7_REQ;
  wire S_SC_B_7_SEND;
  wire [0:0]S_SC_B_8_INFO;
  wire [119:0]S_SC_B_8_PAYLD;
  wire [0:0]S_SC_B_8_RECV;
  wire S_SC_B_8_REQ;
  wire S_SC_B_8_SEND;
  wire [0:0]S_SC_B_9_INFO;
  wire [119:0]S_SC_B_9_PAYLD;
  wire [0:0]S_SC_B_9_RECV;
  wire S_SC_B_9_REQ;
  wire S_SC_B_9_SEND;
  wire [0:0]S_SC_R_10_INFO;
  wire [276:0]S_SC_R_10_PAYLD;
  wire [0:0]S_SC_R_10_RECV;
  wire S_SC_R_10_REQ;
  wire S_SC_R_10_SEND;
  wire [0:0]S_SC_R_11_INFO;
  wire [276:0]S_SC_R_11_PAYLD;
  wire [0:0]S_SC_R_11_RECV;
  wire S_SC_R_11_REQ;
  wire S_SC_R_11_SEND;
  wire [0:0]S_SC_R_12_INFO;
  wire [276:0]S_SC_R_12_PAYLD;
  wire [0:0]S_SC_R_12_RECV;
  wire S_SC_R_12_REQ;
  wire S_SC_R_12_SEND;
  wire [0:0]S_SC_R_13_INFO;
  wire [276:0]S_SC_R_13_PAYLD;
  wire [0:0]S_SC_R_13_RECV;
  wire S_SC_R_13_REQ;
  wire S_SC_R_13_SEND;
  wire [0:0]S_SC_R_14_INFO;
  wire [276:0]S_SC_R_14_PAYLD;
  wire [0:0]S_SC_R_14_RECV;
  wire S_SC_R_14_REQ;
  wire S_SC_R_14_SEND;
  wire [0:0]S_SC_R_15_INFO;
  wire [276:0]S_SC_R_15_PAYLD;
  wire [0:0]S_SC_R_15_RECV;
  wire S_SC_R_15_REQ;
  wire S_SC_R_15_SEND;
  wire [0:0]S_SC_R_16_INFO;
  wire [276:0]S_SC_R_16_PAYLD;
  wire [0:0]S_SC_R_16_RECV;
  wire S_SC_R_16_REQ;
  wire S_SC_R_16_SEND;
  wire [0:0]S_SC_R_17_INFO;
  wire [276:0]S_SC_R_17_PAYLD;
  wire [0:0]S_SC_R_17_RECV;
  wire S_SC_R_17_REQ;
  wire S_SC_R_17_SEND;
  wire [15:0]S_SC_R_1_INFO;
  wire [276:0]S_SC_R_1_PAYLD;
  wire [15:0]S_SC_R_1_RECV;
  wire [15:0]S_SC_R_1_REQ;
  wire [15:0]S_SC_R_1_SEND;
  wire [0:0]S_SC_R_2_INFO;
  wire [276:0]S_SC_R_2_PAYLD;
  wire [0:0]S_SC_R_2_RECV;
  wire S_SC_R_2_REQ;
  wire S_SC_R_2_SEND;
  wire [0:0]S_SC_R_3_INFO;
  wire [276:0]S_SC_R_3_PAYLD;
  wire [0:0]S_SC_R_3_RECV;
  wire S_SC_R_3_REQ;
  wire S_SC_R_3_SEND;
  wire [0:0]S_SC_R_4_INFO;
  wire [276:0]S_SC_R_4_PAYLD;
  wire [0:0]S_SC_R_4_RECV;
  wire S_SC_R_4_REQ;
  wire S_SC_R_4_SEND;
  wire [0:0]S_SC_R_5_INFO;
  wire [276:0]S_SC_R_5_PAYLD;
  wire [0:0]S_SC_R_5_RECV;
  wire S_SC_R_5_REQ;
  wire S_SC_R_5_SEND;
  wire [0:0]S_SC_R_6_INFO;
  wire [276:0]S_SC_R_6_PAYLD;
  wire [0:0]S_SC_R_6_RECV;
  wire S_SC_R_6_REQ;
  wire S_SC_R_6_SEND;
  wire [0:0]S_SC_R_7_INFO;
  wire [276:0]S_SC_R_7_PAYLD;
  wire [0:0]S_SC_R_7_RECV;
  wire S_SC_R_7_REQ;
  wire S_SC_R_7_SEND;
  wire [0:0]S_SC_R_8_INFO;
  wire [276:0]S_SC_R_8_PAYLD;
  wire [0:0]S_SC_R_8_RECV;
  wire S_SC_R_8_REQ;
  wire S_SC_R_8_SEND;
  wire [0:0]S_SC_R_9_INFO;
  wire [276:0]S_SC_R_9_PAYLD;
  wire [0:0]S_SC_R_9_RECV;
  wire S_SC_R_9_REQ;
  wire S_SC_R_9_SEND;
  wire [0:0]S_SC_W_10_INFO;
  wire [318:0]S_SC_W_10_PAYLD;
  wire [0:0]S_SC_W_10_RECV;
  wire [0:0]S_SC_W_10_REQ;
  wire [0:0]S_SC_W_10_SEND;
  wire [0:0]S_SC_W_11_INFO;
  wire [318:0]S_SC_W_11_PAYLD;
  wire [0:0]S_SC_W_11_RECV;
  wire [0:0]S_SC_W_11_REQ;
  wire [0:0]S_SC_W_11_SEND;
  wire [0:0]S_SC_W_12_INFO;
  wire [318:0]S_SC_W_12_PAYLD;
  wire [0:0]S_SC_W_12_RECV;
  wire [0:0]S_SC_W_12_REQ;
  wire [0:0]S_SC_W_12_SEND;
  wire [0:0]S_SC_W_13_INFO;
  wire [318:0]S_SC_W_13_PAYLD;
  wire [0:0]S_SC_W_13_RECV;
  wire [0:0]S_SC_W_13_REQ;
  wire [0:0]S_SC_W_13_SEND;
  wire [0:0]S_SC_W_14_INFO;
  wire [318:0]S_SC_W_14_PAYLD;
  wire [0:0]S_SC_W_14_RECV;
  wire [0:0]S_SC_W_14_REQ;
  wire [0:0]S_SC_W_14_SEND;
  wire [0:0]S_SC_W_15_INFO;
  wire [318:0]S_SC_W_15_PAYLD;
  wire [0:0]S_SC_W_15_RECV;
  wire [0:0]S_SC_W_15_REQ;
  wire [0:0]S_SC_W_15_SEND;
  wire [0:0]S_SC_W_16_INFO;
  wire [318:0]S_SC_W_16_PAYLD;
  wire [0:0]S_SC_W_16_RECV;
  wire [0:0]S_SC_W_16_REQ;
  wire [0:0]S_SC_W_16_SEND;
  wire [0:0]S_SC_W_17_INFO;
  wire [318:0]S_SC_W_17_PAYLD;
  wire [0:0]S_SC_W_17_RECV;
  wire [0:0]S_SC_W_17_REQ;
  wire [0:0]S_SC_W_17_SEND;
  wire [0:0]S_SC_W_1_INFO;
  wire [318:0]S_SC_W_1_PAYLD;
  wire [0:0]S_SC_W_1_RECV;
  wire S_SC_W_1_REQ;
  wire S_SC_W_1_SEND;
  wire [0:0]S_SC_W_2_INFO;
  wire [318:0]S_SC_W_2_PAYLD;
  wire [0:0]S_SC_W_2_RECV;
  wire [0:0]S_SC_W_2_REQ;
  wire [0:0]S_SC_W_2_SEND;
  wire [0:0]S_SC_W_3_INFO;
  wire [318:0]S_SC_W_3_PAYLD;
  wire [0:0]S_SC_W_3_RECV;
  wire [0:0]S_SC_W_3_REQ;
  wire [0:0]S_SC_W_3_SEND;
  wire [0:0]S_SC_W_4_INFO;
  wire [318:0]S_SC_W_4_PAYLD;
  wire [0:0]S_SC_W_4_RECV;
  wire [0:0]S_SC_W_4_REQ;
  wire [0:0]S_SC_W_4_SEND;
  wire [0:0]S_SC_W_5_INFO;
  wire [318:0]S_SC_W_5_PAYLD;
  wire [0:0]S_SC_W_5_RECV;
  wire [0:0]S_SC_W_5_REQ;
  wire [0:0]S_SC_W_5_SEND;
  wire [0:0]S_SC_W_6_INFO;
  wire [318:0]S_SC_W_6_PAYLD;
  wire [0:0]S_SC_W_6_RECV;
  wire [0:0]S_SC_W_6_REQ;
  wire [0:0]S_SC_W_6_SEND;
  wire [0:0]S_SC_W_7_INFO;
  wire [318:0]S_SC_W_7_PAYLD;
  wire [0:0]S_SC_W_7_RECV;
  wire [0:0]S_SC_W_7_REQ;
  wire [0:0]S_SC_W_7_SEND;
  wire [0:0]S_SC_W_8_INFO;
  wire [318:0]S_SC_W_8_PAYLD;
  wire [0:0]S_SC_W_8_RECV;
  wire [0:0]S_SC_W_8_REQ;
  wire [0:0]S_SC_W_8_SEND;
  wire [0:0]S_SC_W_9_INFO;
  wire [318:0]S_SC_W_9_PAYLD;
  wire [0:0]S_SC_W_9_RECV;
  wire [0:0]S_SC_W_9_REQ;
  wire [0:0]S_SC_W_9_SEND;
  wire aclk;
  wire aclk_1;
  wire aresetn;
  wire [0:0]aresetn_2;
  wire aresetn_net;
  wire clk_map_M00_ACLK;
  wire clk_map_M01_ACLK;
  wire clk_map_M02_ACLK;
  wire clk_map_M03_ACLK;
  wire clk_map_M04_ACLK;
  wire clk_map_M05_ACLK;
  wire clk_map_M06_ACLK;
  wire clk_map_M07_ACLK;
  wire clk_map_M08_ACLK;
  wire clk_map_M09_ACLK;
  wire clk_map_M10_ACLK;
  wire clk_map_M11_ACLK;
  wire clk_map_M12_ACLK;
  wire clk_map_M13_ACLK;
  wire clk_map_M14_ACLK;
  wire clk_map_M15_ACLK;
  wire [0:0]m00_nodes_M_SC_AR_INFO;
  wire [301:0]m00_nodes_M_SC_AR_PAYLD;
  wire m00_nodes_M_SC_AR_RECV;
  wire [0:0]m00_nodes_M_SC_AR_REQ;
  wire [0:0]m00_nodes_M_SC_AR_SEND;
  wire [0:0]m00_nodes_M_SC_AW_INFO;
  wire [301:0]m00_nodes_M_SC_AW_PAYLD;
  wire m00_nodes_M_SC_AW_RECV;
  wire [0:0]m00_nodes_M_SC_AW_REQ;
  wire [0:0]m00_nodes_M_SC_AW_SEND;
  wire [0:0]m00_nodes_M_SC_B_INFO;
  wire [119:0]m00_nodes_M_SC_B_PAYLD;
  wire [0:0]m00_nodes_M_SC_B_RECV;
  wire [0:0]m00_nodes_M_SC_B_REQ;
  wire [0:0]m00_nodes_M_SC_B_SEND;
  wire [0:0]m00_nodes_M_SC_R_INFO;
  wire [276:0]m00_nodes_M_SC_R_PAYLD;
  wire [0:0]m00_nodes_M_SC_R_RECV;
  wire [0:0]m00_nodes_M_SC_R_REQ;
  wire [0:0]m00_nodes_M_SC_R_SEND;
  wire [0:0]m00_nodes_M_SC_W_INFO;
  wire [318:0]m00_nodes_M_SC_W_PAYLD;
  wire m00_nodes_M_SC_W_RECV;
  wire [0:0]m00_nodes_M_SC_W_REQ;
  wire [0:0]m00_nodes_M_SC_W_SEND;
  wire [32:0]m00_sc2axi_M_AXI_ARADDR;
  wire [3:0]m00_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m00_sc2axi_M_AXI_ARID;
  wire [7:0]m00_sc2axi_M_AXI_ARLEN;
  wire [0:0]m00_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m00_sc2axi_M_AXI_ARPROT;
  wire [3:0]m00_sc2axi_M_AXI_ARQOS;
  wire m00_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m00_sc2axi_M_AXI_ARUSER;
  wire m00_sc2axi_M_AXI_ARVALID;
  wire [32:0]m00_sc2axi_M_AXI_AWADDR;
  wire [3:0]m00_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m00_sc2axi_M_AXI_AWID;
  wire [7:0]m00_sc2axi_M_AXI_AWLEN;
  wire [0:0]m00_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m00_sc2axi_M_AXI_AWPROT;
  wire [3:0]m00_sc2axi_M_AXI_AWQOS;
  wire m00_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m00_sc2axi_M_AXI_AWUSER;
  wire m00_sc2axi_M_AXI_AWVALID;
  wire [2:0]m00_sc2axi_M_AXI_BID;
  wire m00_sc2axi_M_AXI_BREADY;
  wire [1:0]m00_sc2axi_M_AXI_BRESP;
  wire [1023:0]m00_sc2axi_M_AXI_BUSER;
  wire m00_sc2axi_M_AXI_BVALID;
  wire [255:0]m00_sc2axi_M_AXI_RDATA;
  wire [2:0]m00_sc2axi_M_AXI_RID;
  wire m00_sc2axi_M_AXI_RLAST;
  wire m00_sc2axi_M_AXI_RREADY;
  wire [1:0]m00_sc2axi_M_AXI_RRESP;
  wire [1023:0]m00_sc2axi_M_AXI_RUSER;
  wire m00_sc2axi_M_AXI_RVALID;
  wire [255:0]m00_sc2axi_M_AXI_WDATA;
  wire m00_sc2axi_M_AXI_WLAST;
  wire m00_sc2axi_M_AXI_WREADY;
  wire [31:0]m00_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m00_sc2axi_M_AXI_WUSER;
  wire m00_sc2axi_M_AXI_WVALID;
  wire [0:0]m01_nodes_M_SC_AR_INFO;
  wire [301:0]m01_nodes_M_SC_AR_PAYLD;
  wire m01_nodes_M_SC_AR_RECV;
  wire [0:0]m01_nodes_M_SC_AR_REQ;
  wire [0:0]m01_nodes_M_SC_AR_SEND;
  wire [0:0]m01_nodes_M_SC_AW_INFO;
  wire [301:0]m01_nodes_M_SC_AW_PAYLD;
  wire m01_nodes_M_SC_AW_RECV;
  wire [0:0]m01_nodes_M_SC_AW_REQ;
  wire [0:0]m01_nodes_M_SC_AW_SEND;
  wire [0:0]m01_nodes_M_SC_B_INFO;
  wire [119:0]m01_nodes_M_SC_B_PAYLD;
  wire [0:0]m01_nodes_M_SC_B_RECV;
  wire [0:0]m01_nodes_M_SC_B_REQ;
  wire [0:0]m01_nodes_M_SC_B_SEND;
  wire [0:0]m01_nodes_M_SC_R_INFO;
  wire [276:0]m01_nodes_M_SC_R_PAYLD;
  wire [0:0]m01_nodes_M_SC_R_RECV;
  wire [0:0]m01_nodes_M_SC_R_REQ;
  wire [0:0]m01_nodes_M_SC_R_SEND;
  wire [0:0]m01_nodes_M_SC_W_INFO;
  wire [318:0]m01_nodes_M_SC_W_PAYLD;
  wire m01_nodes_M_SC_W_RECV;
  wire [0:0]m01_nodes_M_SC_W_REQ;
  wire [0:0]m01_nodes_M_SC_W_SEND;
  wire [32:0]m01_sc2axi_M_AXI_ARADDR;
  wire [3:0]m01_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m01_sc2axi_M_AXI_ARID;
  wire [7:0]m01_sc2axi_M_AXI_ARLEN;
  wire [0:0]m01_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m01_sc2axi_M_AXI_ARPROT;
  wire [3:0]m01_sc2axi_M_AXI_ARQOS;
  wire m01_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m01_sc2axi_M_AXI_ARUSER;
  wire m01_sc2axi_M_AXI_ARVALID;
  wire [32:0]m01_sc2axi_M_AXI_AWADDR;
  wire [3:0]m01_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m01_sc2axi_M_AXI_AWID;
  wire [7:0]m01_sc2axi_M_AXI_AWLEN;
  wire [0:0]m01_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m01_sc2axi_M_AXI_AWPROT;
  wire [3:0]m01_sc2axi_M_AXI_AWQOS;
  wire m01_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m01_sc2axi_M_AXI_AWUSER;
  wire m01_sc2axi_M_AXI_AWVALID;
  wire [2:0]m01_sc2axi_M_AXI_BID;
  wire m01_sc2axi_M_AXI_BREADY;
  wire [1:0]m01_sc2axi_M_AXI_BRESP;
  wire [1023:0]m01_sc2axi_M_AXI_BUSER;
  wire m01_sc2axi_M_AXI_BVALID;
  wire [255:0]m01_sc2axi_M_AXI_RDATA;
  wire [2:0]m01_sc2axi_M_AXI_RID;
  wire m01_sc2axi_M_AXI_RLAST;
  wire m01_sc2axi_M_AXI_RREADY;
  wire [1:0]m01_sc2axi_M_AXI_RRESP;
  wire [1023:0]m01_sc2axi_M_AXI_RUSER;
  wire m01_sc2axi_M_AXI_RVALID;
  wire [255:0]m01_sc2axi_M_AXI_WDATA;
  wire m01_sc2axi_M_AXI_WLAST;
  wire m01_sc2axi_M_AXI_WREADY;
  wire [31:0]m01_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m01_sc2axi_M_AXI_WUSER;
  wire m01_sc2axi_M_AXI_WVALID;
  wire [0:0]m02_nodes_M_SC_AR_INFO;
  wire [301:0]m02_nodes_M_SC_AR_PAYLD;
  wire m02_nodes_M_SC_AR_RECV;
  wire [0:0]m02_nodes_M_SC_AR_REQ;
  wire [0:0]m02_nodes_M_SC_AR_SEND;
  wire [0:0]m02_nodes_M_SC_AW_INFO;
  wire [301:0]m02_nodes_M_SC_AW_PAYLD;
  wire m02_nodes_M_SC_AW_RECV;
  wire [0:0]m02_nodes_M_SC_AW_REQ;
  wire [0:0]m02_nodes_M_SC_AW_SEND;
  wire [0:0]m02_nodes_M_SC_B_INFO;
  wire [119:0]m02_nodes_M_SC_B_PAYLD;
  wire [0:0]m02_nodes_M_SC_B_RECV;
  wire [0:0]m02_nodes_M_SC_B_REQ;
  wire [0:0]m02_nodes_M_SC_B_SEND;
  wire [0:0]m02_nodes_M_SC_R_INFO;
  wire [276:0]m02_nodes_M_SC_R_PAYLD;
  wire [0:0]m02_nodes_M_SC_R_RECV;
  wire [0:0]m02_nodes_M_SC_R_REQ;
  wire [0:0]m02_nodes_M_SC_R_SEND;
  wire [0:0]m02_nodes_M_SC_W_INFO;
  wire [318:0]m02_nodes_M_SC_W_PAYLD;
  wire m02_nodes_M_SC_W_RECV;
  wire [0:0]m02_nodes_M_SC_W_REQ;
  wire [0:0]m02_nodes_M_SC_W_SEND;
  wire [32:0]m02_sc2axi_M_AXI_ARADDR;
  wire [3:0]m02_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m02_sc2axi_M_AXI_ARID;
  wire [7:0]m02_sc2axi_M_AXI_ARLEN;
  wire [0:0]m02_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m02_sc2axi_M_AXI_ARPROT;
  wire [3:0]m02_sc2axi_M_AXI_ARQOS;
  wire m02_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m02_sc2axi_M_AXI_ARUSER;
  wire m02_sc2axi_M_AXI_ARVALID;
  wire [32:0]m02_sc2axi_M_AXI_AWADDR;
  wire [3:0]m02_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m02_sc2axi_M_AXI_AWID;
  wire [7:0]m02_sc2axi_M_AXI_AWLEN;
  wire [0:0]m02_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m02_sc2axi_M_AXI_AWPROT;
  wire [3:0]m02_sc2axi_M_AXI_AWQOS;
  wire m02_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m02_sc2axi_M_AXI_AWUSER;
  wire m02_sc2axi_M_AXI_AWVALID;
  wire [2:0]m02_sc2axi_M_AXI_BID;
  wire m02_sc2axi_M_AXI_BREADY;
  wire [1:0]m02_sc2axi_M_AXI_BRESP;
  wire [1023:0]m02_sc2axi_M_AXI_BUSER;
  wire m02_sc2axi_M_AXI_BVALID;
  wire [255:0]m02_sc2axi_M_AXI_RDATA;
  wire [2:0]m02_sc2axi_M_AXI_RID;
  wire m02_sc2axi_M_AXI_RLAST;
  wire m02_sc2axi_M_AXI_RREADY;
  wire [1:0]m02_sc2axi_M_AXI_RRESP;
  wire [1023:0]m02_sc2axi_M_AXI_RUSER;
  wire m02_sc2axi_M_AXI_RVALID;
  wire [255:0]m02_sc2axi_M_AXI_WDATA;
  wire m02_sc2axi_M_AXI_WLAST;
  wire m02_sc2axi_M_AXI_WREADY;
  wire [31:0]m02_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m02_sc2axi_M_AXI_WUSER;
  wire m02_sc2axi_M_AXI_WVALID;
  wire [0:0]m03_nodes_M_SC_AR_INFO;
  wire [301:0]m03_nodes_M_SC_AR_PAYLD;
  wire m03_nodes_M_SC_AR_RECV;
  wire [0:0]m03_nodes_M_SC_AR_REQ;
  wire [0:0]m03_nodes_M_SC_AR_SEND;
  wire [0:0]m03_nodes_M_SC_AW_INFO;
  wire [301:0]m03_nodes_M_SC_AW_PAYLD;
  wire m03_nodes_M_SC_AW_RECV;
  wire [0:0]m03_nodes_M_SC_AW_REQ;
  wire [0:0]m03_nodes_M_SC_AW_SEND;
  wire [0:0]m03_nodes_M_SC_B_INFO;
  wire [119:0]m03_nodes_M_SC_B_PAYLD;
  wire [0:0]m03_nodes_M_SC_B_RECV;
  wire [0:0]m03_nodes_M_SC_B_REQ;
  wire [0:0]m03_nodes_M_SC_B_SEND;
  wire [0:0]m03_nodes_M_SC_R_INFO;
  wire [276:0]m03_nodes_M_SC_R_PAYLD;
  wire [0:0]m03_nodes_M_SC_R_RECV;
  wire [0:0]m03_nodes_M_SC_R_REQ;
  wire [0:0]m03_nodes_M_SC_R_SEND;
  wire [0:0]m03_nodes_M_SC_W_INFO;
  wire [318:0]m03_nodes_M_SC_W_PAYLD;
  wire m03_nodes_M_SC_W_RECV;
  wire [0:0]m03_nodes_M_SC_W_REQ;
  wire [0:0]m03_nodes_M_SC_W_SEND;
  wire [32:0]m03_sc2axi_M_AXI_ARADDR;
  wire [3:0]m03_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m03_sc2axi_M_AXI_ARID;
  wire [7:0]m03_sc2axi_M_AXI_ARLEN;
  wire [0:0]m03_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m03_sc2axi_M_AXI_ARPROT;
  wire [3:0]m03_sc2axi_M_AXI_ARQOS;
  wire m03_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m03_sc2axi_M_AXI_ARUSER;
  wire m03_sc2axi_M_AXI_ARVALID;
  wire [32:0]m03_sc2axi_M_AXI_AWADDR;
  wire [3:0]m03_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m03_sc2axi_M_AXI_AWID;
  wire [7:0]m03_sc2axi_M_AXI_AWLEN;
  wire [0:0]m03_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m03_sc2axi_M_AXI_AWPROT;
  wire [3:0]m03_sc2axi_M_AXI_AWQOS;
  wire m03_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m03_sc2axi_M_AXI_AWUSER;
  wire m03_sc2axi_M_AXI_AWVALID;
  wire [2:0]m03_sc2axi_M_AXI_BID;
  wire m03_sc2axi_M_AXI_BREADY;
  wire [1:0]m03_sc2axi_M_AXI_BRESP;
  wire [1023:0]m03_sc2axi_M_AXI_BUSER;
  wire m03_sc2axi_M_AXI_BVALID;
  wire [255:0]m03_sc2axi_M_AXI_RDATA;
  wire [2:0]m03_sc2axi_M_AXI_RID;
  wire m03_sc2axi_M_AXI_RLAST;
  wire m03_sc2axi_M_AXI_RREADY;
  wire [1:0]m03_sc2axi_M_AXI_RRESP;
  wire [1023:0]m03_sc2axi_M_AXI_RUSER;
  wire m03_sc2axi_M_AXI_RVALID;
  wire [255:0]m03_sc2axi_M_AXI_WDATA;
  wire m03_sc2axi_M_AXI_WLAST;
  wire m03_sc2axi_M_AXI_WREADY;
  wire [31:0]m03_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m03_sc2axi_M_AXI_WUSER;
  wire m03_sc2axi_M_AXI_WVALID;
  wire [0:0]m04_nodes_M_SC_AR_INFO;
  wire [301:0]m04_nodes_M_SC_AR_PAYLD;
  wire m04_nodes_M_SC_AR_RECV;
  wire [0:0]m04_nodes_M_SC_AR_REQ;
  wire [0:0]m04_nodes_M_SC_AR_SEND;
  wire [0:0]m04_nodes_M_SC_AW_INFO;
  wire [301:0]m04_nodes_M_SC_AW_PAYLD;
  wire m04_nodes_M_SC_AW_RECV;
  wire [0:0]m04_nodes_M_SC_AW_REQ;
  wire [0:0]m04_nodes_M_SC_AW_SEND;
  wire [0:0]m04_nodes_M_SC_B_INFO;
  wire [119:0]m04_nodes_M_SC_B_PAYLD;
  wire [0:0]m04_nodes_M_SC_B_RECV;
  wire [0:0]m04_nodes_M_SC_B_REQ;
  wire [0:0]m04_nodes_M_SC_B_SEND;
  wire [0:0]m04_nodes_M_SC_R_INFO;
  wire [276:0]m04_nodes_M_SC_R_PAYLD;
  wire [0:0]m04_nodes_M_SC_R_RECV;
  wire [0:0]m04_nodes_M_SC_R_REQ;
  wire [0:0]m04_nodes_M_SC_R_SEND;
  wire [0:0]m04_nodes_M_SC_W_INFO;
  wire [318:0]m04_nodes_M_SC_W_PAYLD;
  wire m04_nodes_M_SC_W_RECV;
  wire [0:0]m04_nodes_M_SC_W_REQ;
  wire [0:0]m04_nodes_M_SC_W_SEND;
  wire [32:0]m04_sc2axi_M_AXI_ARADDR;
  wire [3:0]m04_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m04_sc2axi_M_AXI_ARID;
  wire [7:0]m04_sc2axi_M_AXI_ARLEN;
  wire [0:0]m04_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m04_sc2axi_M_AXI_ARPROT;
  wire [3:0]m04_sc2axi_M_AXI_ARQOS;
  wire m04_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m04_sc2axi_M_AXI_ARUSER;
  wire m04_sc2axi_M_AXI_ARVALID;
  wire [32:0]m04_sc2axi_M_AXI_AWADDR;
  wire [3:0]m04_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m04_sc2axi_M_AXI_AWID;
  wire [7:0]m04_sc2axi_M_AXI_AWLEN;
  wire [0:0]m04_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m04_sc2axi_M_AXI_AWPROT;
  wire [3:0]m04_sc2axi_M_AXI_AWQOS;
  wire m04_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m04_sc2axi_M_AXI_AWUSER;
  wire m04_sc2axi_M_AXI_AWVALID;
  wire [2:0]m04_sc2axi_M_AXI_BID;
  wire m04_sc2axi_M_AXI_BREADY;
  wire [1:0]m04_sc2axi_M_AXI_BRESP;
  wire [1023:0]m04_sc2axi_M_AXI_BUSER;
  wire m04_sc2axi_M_AXI_BVALID;
  wire [255:0]m04_sc2axi_M_AXI_RDATA;
  wire [2:0]m04_sc2axi_M_AXI_RID;
  wire m04_sc2axi_M_AXI_RLAST;
  wire m04_sc2axi_M_AXI_RREADY;
  wire [1:0]m04_sc2axi_M_AXI_RRESP;
  wire [1023:0]m04_sc2axi_M_AXI_RUSER;
  wire m04_sc2axi_M_AXI_RVALID;
  wire [255:0]m04_sc2axi_M_AXI_WDATA;
  wire m04_sc2axi_M_AXI_WLAST;
  wire m04_sc2axi_M_AXI_WREADY;
  wire [31:0]m04_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m04_sc2axi_M_AXI_WUSER;
  wire m04_sc2axi_M_AXI_WVALID;
  wire [0:0]m05_nodes_M_SC_AR_INFO;
  wire [301:0]m05_nodes_M_SC_AR_PAYLD;
  wire m05_nodes_M_SC_AR_RECV;
  wire [0:0]m05_nodes_M_SC_AR_REQ;
  wire [0:0]m05_nodes_M_SC_AR_SEND;
  wire [0:0]m05_nodes_M_SC_AW_INFO;
  wire [301:0]m05_nodes_M_SC_AW_PAYLD;
  wire m05_nodes_M_SC_AW_RECV;
  wire [0:0]m05_nodes_M_SC_AW_REQ;
  wire [0:0]m05_nodes_M_SC_AW_SEND;
  wire [0:0]m05_nodes_M_SC_B_INFO;
  wire [119:0]m05_nodes_M_SC_B_PAYLD;
  wire [0:0]m05_nodes_M_SC_B_RECV;
  wire [0:0]m05_nodes_M_SC_B_REQ;
  wire [0:0]m05_nodes_M_SC_B_SEND;
  wire [0:0]m05_nodes_M_SC_R_INFO;
  wire [276:0]m05_nodes_M_SC_R_PAYLD;
  wire [0:0]m05_nodes_M_SC_R_RECV;
  wire [0:0]m05_nodes_M_SC_R_REQ;
  wire [0:0]m05_nodes_M_SC_R_SEND;
  wire [0:0]m05_nodes_M_SC_W_INFO;
  wire [318:0]m05_nodes_M_SC_W_PAYLD;
  wire m05_nodes_M_SC_W_RECV;
  wire [0:0]m05_nodes_M_SC_W_REQ;
  wire [0:0]m05_nodes_M_SC_W_SEND;
  wire [32:0]m05_sc2axi_M_AXI_ARADDR;
  wire [3:0]m05_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m05_sc2axi_M_AXI_ARID;
  wire [7:0]m05_sc2axi_M_AXI_ARLEN;
  wire [0:0]m05_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m05_sc2axi_M_AXI_ARPROT;
  wire [3:0]m05_sc2axi_M_AXI_ARQOS;
  wire m05_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m05_sc2axi_M_AXI_ARUSER;
  wire m05_sc2axi_M_AXI_ARVALID;
  wire [32:0]m05_sc2axi_M_AXI_AWADDR;
  wire [3:0]m05_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m05_sc2axi_M_AXI_AWID;
  wire [7:0]m05_sc2axi_M_AXI_AWLEN;
  wire [0:0]m05_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m05_sc2axi_M_AXI_AWPROT;
  wire [3:0]m05_sc2axi_M_AXI_AWQOS;
  wire m05_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m05_sc2axi_M_AXI_AWUSER;
  wire m05_sc2axi_M_AXI_AWVALID;
  wire [2:0]m05_sc2axi_M_AXI_BID;
  wire m05_sc2axi_M_AXI_BREADY;
  wire [1:0]m05_sc2axi_M_AXI_BRESP;
  wire [1023:0]m05_sc2axi_M_AXI_BUSER;
  wire m05_sc2axi_M_AXI_BVALID;
  wire [255:0]m05_sc2axi_M_AXI_RDATA;
  wire [2:0]m05_sc2axi_M_AXI_RID;
  wire m05_sc2axi_M_AXI_RLAST;
  wire m05_sc2axi_M_AXI_RREADY;
  wire [1:0]m05_sc2axi_M_AXI_RRESP;
  wire [1023:0]m05_sc2axi_M_AXI_RUSER;
  wire m05_sc2axi_M_AXI_RVALID;
  wire [255:0]m05_sc2axi_M_AXI_WDATA;
  wire m05_sc2axi_M_AXI_WLAST;
  wire m05_sc2axi_M_AXI_WREADY;
  wire [31:0]m05_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m05_sc2axi_M_AXI_WUSER;
  wire m05_sc2axi_M_AXI_WVALID;
  wire [0:0]m06_nodes_M_SC_AR_INFO;
  wire [301:0]m06_nodes_M_SC_AR_PAYLD;
  wire m06_nodes_M_SC_AR_RECV;
  wire [0:0]m06_nodes_M_SC_AR_REQ;
  wire [0:0]m06_nodes_M_SC_AR_SEND;
  wire [0:0]m06_nodes_M_SC_AW_INFO;
  wire [301:0]m06_nodes_M_SC_AW_PAYLD;
  wire m06_nodes_M_SC_AW_RECV;
  wire [0:0]m06_nodes_M_SC_AW_REQ;
  wire [0:0]m06_nodes_M_SC_AW_SEND;
  wire [0:0]m06_nodes_M_SC_B_INFO;
  wire [119:0]m06_nodes_M_SC_B_PAYLD;
  wire [0:0]m06_nodes_M_SC_B_RECV;
  wire [0:0]m06_nodes_M_SC_B_REQ;
  wire [0:0]m06_nodes_M_SC_B_SEND;
  wire [0:0]m06_nodes_M_SC_R_INFO;
  wire [276:0]m06_nodes_M_SC_R_PAYLD;
  wire [0:0]m06_nodes_M_SC_R_RECV;
  wire [0:0]m06_nodes_M_SC_R_REQ;
  wire [0:0]m06_nodes_M_SC_R_SEND;
  wire [0:0]m06_nodes_M_SC_W_INFO;
  wire [318:0]m06_nodes_M_SC_W_PAYLD;
  wire m06_nodes_M_SC_W_RECV;
  wire [0:0]m06_nodes_M_SC_W_REQ;
  wire [0:0]m06_nodes_M_SC_W_SEND;
  wire [32:0]m06_sc2axi_M_AXI_ARADDR;
  wire [3:0]m06_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m06_sc2axi_M_AXI_ARID;
  wire [7:0]m06_sc2axi_M_AXI_ARLEN;
  wire [0:0]m06_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m06_sc2axi_M_AXI_ARPROT;
  wire [3:0]m06_sc2axi_M_AXI_ARQOS;
  wire m06_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m06_sc2axi_M_AXI_ARUSER;
  wire m06_sc2axi_M_AXI_ARVALID;
  wire [32:0]m06_sc2axi_M_AXI_AWADDR;
  wire [3:0]m06_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m06_sc2axi_M_AXI_AWID;
  wire [7:0]m06_sc2axi_M_AXI_AWLEN;
  wire [0:0]m06_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m06_sc2axi_M_AXI_AWPROT;
  wire [3:0]m06_sc2axi_M_AXI_AWQOS;
  wire m06_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m06_sc2axi_M_AXI_AWUSER;
  wire m06_sc2axi_M_AXI_AWVALID;
  wire [2:0]m06_sc2axi_M_AXI_BID;
  wire m06_sc2axi_M_AXI_BREADY;
  wire [1:0]m06_sc2axi_M_AXI_BRESP;
  wire [1023:0]m06_sc2axi_M_AXI_BUSER;
  wire m06_sc2axi_M_AXI_BVALID;
  wire [255:0]m06_sc2axi_M_AXI_RDATA;
  wire [2:0]m06_sc2axi_M_AXI_RID;
  wire m06_sc2axi_M_AXI_RLAST;
  wire m06_sc2axi_M_AXI_RREADY;
  wire [1:0]m06_sc2axi_M_AXI_RRESP;
  wire [1023:0]m06_sc2axi_M_AXI_RUSER;
  wire m06_sc2axi_M_AXI_RVALID;
  wire [255:0]m06_sc2axi_M_AXI_WDATA;
  wire m06_sc2axi_M_AXI_WLAST;
  wire m06_sc2axi_M_AXI_WREADY;
  wire [31:0]m06_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m06_sc2axi_M_AXI_WUSER;
  wire m06_sc2axi_M_AXI_WVALID;
  wire [0:0]m07_nodes_M_SC_AR_INFO;
  wire [301:0]m07_nodes_M_SC_AR_PAYLD;
  wire m07_nodes_M_SC_AR_RECV;
  wire [0:0]m07_nodes_M_SC_AR_REQ;
  wire [0:0]m07_nodes_M_SC_AR_SEND;
  wire [0:0]m07_nodes_M_SC_AW_INFO;
  wire [301:0]m07_nodes_M_SC_AW_PAYLD;
  wire m07_nodes_M_SC_AW_RECV;
  wire [0:0]m07_nodes_M_SC_AW_REQ;
  wire [0:0]m07_nodes_M_SC_AW_SEND;
  wire [0:0]m07_nodes_M_SC_B_INFO;
  wire [119:0]m07_nodes_M_SC_B_PAYLD;
  wire [0:0]m07_nodes_M_SC_B_RECV;
  wire [0:0]m07_nodes_M_SC_B_REQ;
  wire [0:0]m07_nodes_M_SC_B_SEND;
  wire [0:0]m07_nodes_M_SC_R_INFO;
  wire [276:0]m07_nodes_M_SC_R_PAYLD;
  wire [0:0]m07_nodes_M_SC_R_RECV;
  wire [0:0]m07_nodes_M_SC_R_REQ;
  wire [0:0]m07_nodes_M_SC_R_SEND;
  wire [0:0]m07_nodes_M_SC_W_INFO;
  wire [318:0]m07_nodes_M_SC_W_PAYLD;
  wire m07_nodes_M_SC_W_RECV;
  wire [0:0]m07_nodes_M_SC_W_REQ;
  wire [0:0]m07_nodes_M_SC_W_SEND;
  wire [32:0]m07_sc2axi_M_AXI_ARADDR;
  wire [3:0]m07_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m07_sc2axi_M_AXI_ARID;
  wire [7:0]m07_sc2axi_M_AXI_ARLEN;
  wire [0:0]m07_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m07_sc2axi_M_AXI_ARPROT;
  wire [3:0]m07_sc2axi_M_AXI_ARQOS;
  wire m07_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m07_sc2axi_M_AXI_ARUSER;
  wire m07_sc2axi_M_AXI_ARVALID;
  wire [32:0]m07_sc2axi_M_AXI_AWADDR;
  wire [3:0]m07_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m07_sc2axi_M_AXI_AWID;
  wire [7:0]m07_sc2axi_M_AXI_AWLEN;
  wire [0:0]m07_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m07_sc2axi_M_AXI_AWPROT;
  wire [3:0]m07_sc2axi_M_AXI_AWQOS;
  wire m07_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m07_sc2axi_M_AXI_AWUSER;
  wire m07_sc2axi_M_AXI_AWVALID;
  wire [2:0]m07_sc2axi_M_AXI_BID;
  wire m07_sc2axi_M_AXI_BREADY;
  wire [1:0]m07_sc2axi_M_AXI_BRESP;
  wire [1023:0]m07_sc2axi_M_AXI_BUSER;
  wire m07_sc2axi_M_AXI_BVALID;
  wire [255:0]m07_sc2axi_M_AXI_RDATA;
  wire [2:0]m07_sc2axi_M_AXI_RID;
  wire m07_sc2axi_M_AXI_RLAST;
  wire m07_sc2axi_M_AXI_RREADY;
  wire [1:0]m07_sc2axi_M_AXI_RRESP;
  wire [1023:0]m07_sc2axi_M_AXI_RUSER;
  wire m07_sc2axi_M_AXI_RVALID;
  wire [255:0]m07_sc2axi_M_AXI_WDATA;
  wire m07_sc2axi_M_AXI_WLAST;
  wire m07_sc2axi_M_AXI_WREADY;
  wire [31:0]m07_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m07_sc2axi_M_AXI_WUSER;
  wire m07_sc2axi_M_AXI_WVALID;
  wire [0:0]m08_nodes_M_SC_AR_INFO;
  wire [301:0]m08_nodes_M_SC_AR_PAYLD;
  wire m08_nodes_M_SC_AR_RECV;
  wire [0:0]m08_nodes_M_SC_AR_REQ;
  wire [0:0]m08_nodes_M_SC_AR_SEND;
  wire [0:0]m08_nodes_M_SC_AW_INFO;
  wire [301:0]m08_nodes_M_SC_AW_PAYLD;
  wire m08_nodes_M_SC_AW_RECV;
  wire [0:0]m08_nodes_M_SC_AW_REQ;
  wire [0:0]m08_nodes_M_SC_AW_SEND;
  wire [0:0]m08_nodes_M_SC_B_INFO;
  wire [119:0]m08_nodes_M_SC_B_PAYLD;
  wire [0:0]m08_nodes_M_SC_B_RECV;
  wire [0:0]m08_nodes_M_SC_B_REQ;
  wire [0:0]m08_nodes_M_SC_B_SEND;
  wire [0:0]m08_nodes_M_SC_R_INFO;
  wire [276:0]m08_nodes_M_SC_R_PAYLD;
  wire [0:0]m08_nodes_M_SC_R_RECV;
  wire [0:0]m08_nodes_M_SC_R_REQ;
  wire [0:0]m08_nodes_M_SC_R_SEND;
  wire [0:0]m08_nodes_M_SC_W_INFO;
  wire [318:0]m08_nodes_M_SC_W_PAYLD;
  wire m08_nodes_M_SC_W_RECV;
  wire [0:0]m08_nodes_M_SC_W_REQ;
  wire [0:0]m08_nodes_M_SC_W_SEND;
  wire [32:0]m08_sc2axi_M_AXI_ARADDR;
  wire [3:0]m08_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m08_sc2axi_M_AXI_ARID;
  wire [7:0]m08_sc2axi_M_AXI_ARLEN;
  wire [0:0]m08_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m08_sc2axi_M_AXI_ARPROT;
  wire [3:0]m08_sc2axi_M_AXI_ARQOS;
  wire m08_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m08_sc2axi_M_AXI_ARUSER;
  wire m08_sc2axi_M_AXI_ARVALID;
  wire [32:0]m08_sc2axi_M_AXI_AWADDR;
  wire [3:0]m08_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m08_sc2axi_M_AXI_AWID;
  wire [7:0]m08_sc2axi_M_AXI_AWLEN;
  wire [0:0]m08_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m08_sc2axi_M_AXI_AWPROT;
  wire [3:0]m08_sc2axi_M_AXI_AWQOS;
  wire m08_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m08_sc2axi_M_AXI_AWUSER;
  wire m08_sc2axi_M_AXI_AWVALID;
  wire [2:0]m08_sc2axi_M_AXI_BID;
  wire m08_sc2axi_M_AXI_BREADY;
  wire [1:0]m08_sc2axi_M_AXI_BRESP;
  wire [1023:0]m08_sc2axi_M_AXI_BUSER;
  wire m08_sc2axi_M_AXI_BVALID;
  wire [255:0]m08_sc2axi_M_AXI_RDATA;
  wire [2:0]m08_sc2axi_M_AXI_RID;
  wire m08_sc2axi_M_AXI_RLAST;
  wire m08_sc2axi_M_AXI_RREADY;
  wire [1:0]m08_sc2axi_M_AXI_RRESP;
  wire [1023:0]m08_sc2axi_M_AXI_RUSER;
  wire m08_sc2axi_M_AXI_RVALID;
  wire [255:0]m08_sc2axi_M_AXI_WDATA;
  wire m08_sc2axi_M_AXI_WLAST;
  wire m08_sc2axi_M_AXI_WREADY;
  wire [31:0]m08_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m08_sc2axi_M_AXI_WUSER;
  wire m08_sc2axi_M_AXI_WVALID;
  wire [0:0]m09_nodes_M_SC_AR_INFO;
  wire [301:0]m09_nodes_M_SC_AR_PAYLD;
  wire m09_nodes_M_SC_AR_RECV;
  wire [0:0]m09_nodes_M_SC_AR_REQ;
  wire [0:0]m09_nodes_M_SC_AR_SEND;
  wire [0:0]m09_nodes_M_SC_AW_INFO;
  wire [301:0]m09_nodes_M_SC_AW_PAYLD;
  wire m09_nodes_M_SC_AW_RECV;
  wire [0:0]m09_nodes_M_SC_AW_REQ;
  wire [0:0]m09_nodes_M_SC_AW_SEND;
  wire [0:0]m09_nodes_M_SC_B_INFO;
  wire [119:0]m09_nodes_M_SC_B_PAYLD;
  wire [0:0]m09_nodes_M_SC_B_RECV;
  wire [0:0]m09_nodes_M_SC_B_REQ;
  wire [0:0]m09_nodes_M_SC_B_SEND;
  wire [0:0]m09_nodes_M_SC_R_INFO;
  wire [276:0]m09_nodes_M_SC_R_PAYLD;
  wire [0:0]m09_nodes_M_SC_R_RECV;
  wire [0:0]m09_nodes_M_SC_R_REQ;
  wire [0:0]m09_nodes_M_SC_R_SEND;
  wire [0:0]m09_nodes_M_SC_W_INFO;
  wire [318:0]m09_nodes_M_SC_W_PAYLD;
  wire m09_nodes_M_SC_W_RECV;
  wire [0:0]m09_nodes_M_SC_W_REQ;
  wire [0:0]m09_nodes_M_SC_W_SEND;
  wire [32:0]m09_sc2axi_M_AXI_ARADDR;
  wire [3:0]m09_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m09_sc2axi_M_AXI_ARID;
  wire [7:0]m09_sc2axi_M_AXI_ARLEN;
  wire [0:0]m09_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m09_sc2axi_M_AXI_ARPROT;
  wire [3:0]m09_sc2axi_M_AXI_ARQOS;
  wire m09_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m09_sc2axi_M_AXI_ARUSER;
  wire m09_sc2axi_M_AXI_ARVALID;
  wire [32:0]m09_sc2axi_M_AXI_AWADDR;
  wire [3:0]m09_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m09_sc2axi_M_AXI_AWID;
  wire [7:0]m09_sc2axi_M_AXI_AWLEN;
  wire [0:0]m09_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m09_sc2axi_M_AXI_AWPROT;
  wire [3:0]m09_sc2axi_M_AXI_AWQOS;
  wire m09_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m09_sc2axi_M_AXI_AWUSER;
  wire m09_sc2axi_M_AXI_AWVALID;
  wire [2:0]m09_sc2axi_M_AXI_BID;
  wire m09_sc2axi_M_AXI_BREADY;
  wire [1:0]m09_sc2axi_M_AXI_BRESP;
  wire [1023:0]m09_sc2axi_M_AXI_BUSER;
  wire m09_sc2axi_M_AXI_BVALID;
  wire [255:0]m09_sc2axi_M_AXI_RDATA;
  wire [2:0]m09_sc2axi_M_AXI_RID;
  wire m09_sc2axi_M_AXI_RLAST;
  wire m09_sc2axi_M_AXI_RREADY;
  wire [1:0]m09_sc2axi_M_AXI_RRESP;
  wire [1023:0]m09_sc2axi_M_AXI_RUSER;
  wire m09_sc2axi_M_AXI_RVALID;
  wire [255:0]m09_sc2axi_M_AXI_WDATA;
  wire m09_sc2axi_M_AXI_WLAST;
  wire m09_sc2axi_M_AXI_WREADY;
  wire [31:0]m09_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m09_sc2axi_M_AXI_WUSER;
  wire m09_sc2axi_M_AXI_WVALID;
  wire [0:0]m10_nodes_M_SC_AR_INFO;
  wire [301:0]m10_nodes_M_SC_AR_PAYLD;
  wire m10_nodes_M_SC_AR_RECV;
  wire [0:0]m10_nodes_M_SC_AR_REQ;
  wire [0:0]m10_nodes_M_SC_AR_SEND;
  wire [0:0]m10_nodes_M_SC_AW_INFO;
  wire [301:0]m10_nodes_M_SC_AW_PAYLD;
  wire m10_nodes_M_SC_AW_RECV;
  wire [0:0]m10_nodes_M_SC_AW_REQ;
  wire [0:0]m10_nodes_M_SC_AW_SEND;
  wire [0:0]m10_nodes_M_SC_B_INFO;
  wire [119:0]m10_nodes_M_SC_B_PAYLD;
  wire [0:0]m10_nodes_M_SC_B_RECV;
  wire [0:0]m10_nodes_M_SC_B_REQ;
  wire [0:0]m10_nodes_M_SC_B_SEND;
  wire [0:0]m10_nodes_M_SC_R_INFO;
  wire [276:0]m10_nodes_M_SC_R_PAYLD;
  wire [0:0]m10_nodes_M_SC_R_RECV;
  wire [0:0]m10_nodes_M_SC_R_REQ;
  wire [0:0]m10_nodes_M_SC_R_SEND;
  wire [0:0]m10_nodes_M_SC_W_INFO;
  wire [318:0]m10_nodes_M_SC_W_PAYLD;
  wire m10_nodes_M_SC_W_RECV;
  wire [0:0]m10_nodes_M_SC_W_REQ;
  wire [0:0]m10_nodes_M_SC_W_SEND;
  wire [32:0]m10_sc2axi_M_AXI_ARADDR;
  wire [3:0]m10_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m10_sc2axi_M_AXI_ARID;
  wire [7:0]m10_sc2axi_M_AXI_ARLEN;
  wire [0:0]m10_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m10_sc2axi_M_AXI_ARPROT;
  wire [3:0]m10_sc2axi_M_AXI_ARQOS;
  wire m10_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m10_sc2axi_M_AXI_ARUSER;
  wire m10_sc2axi_M_AXI_ARVALID;
  wire [32:0]m10_sc2axi_M_AXI_AWADDR;
  wire [3:0]m10_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m10_sc2axi_M_AXI_AWID;
  wire [7:0]m10_sc2axi_M_AXI_AWLEN;
  wire [0:0]m10_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m10_sc2axi_M_AXI_AWPROT;
  wire [3:0]m10_sc2axi_M_AXI_AWQOS;
  wire m10_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m10_sc2axi_M_AXI_AWUSER;
  wire m10_sc2axi_M_AXI_AWVALID;
  wire [2:0]m10_sc2axi_M_AXI_BID;
  wire m10_sc2axi_M_AXI_BREADY;
  wire [1:0]m10_sc2axi_M_AXI_BRESP;
  wire [1023:0]m10_sc2axi_M_AXI_BUSER;
  wire m10_sc2axi_M_AXI_BVALID;
  wire [255:0]m10_sc2axi_M_AXI_RDATA;
  wire [2:0]m10_sc2axi_M_AXI_RID;
  wire m10_sc2axi_M_AXI_RLAST;
  wire m10_sc2axi_M_AXI_RREADY;
  wire [1:0]m10_sc2axi_M_AXI_RRESP;
  wire [1023:0]m10_sc2axi_M_AXI_RUSER;
  wire m10_sc2axi_M_AXI_RVALID;
  wire [255:0]m10_sc2axi_M_AXI_WDATA;
  wire m10_sc2axi_M_AXI_WLAST;
  wire m10_sc2axi_M_AXI_WREADY;
  wire [31:0]m10_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m10_sc2axi_M_AXI_WUSER;
  wire m10_sc2axi_M_AXI_WVALID;
  wire [0:0]m11_nodes_M_SC_AR_INFO;
  wire [301:0]m11_nodes_M_SC_AR_PAYLD;
  wire m11_nodes_M_SC_AR_RECV;
  wire [0:0]m11_nodes_M_SC_AR_REQ;
  wire [0:0]m11_nodes_M_SC_AR_SEND;
  wire [0:0]m11_nodes_M_SC_AW_INFO;
  wire [301:0]m11_nodes_M_SC_AW_PAYLD;
  wire m11_nodes_M_SC_AW_RECV;
  wire [0:0]m11_nodes_M_SC_AW_REQ;
  wire [0:0]m11_nodes_M_SC_AW_SEND;
  wire [0:0]m11_nodes_M_SC_B_INFO;
  wire [119:0]m11_nodes_M_SC_B_PAYLD;
  wire [0:0]m11_nodes_M_SC_B_RECV;
  wire [0:0]m11_nodes_M_SC_B_REQ;
  wire [0:0]m11_nodes_M_SC_B_SEND;
  wire [0:0]m11_nodes_M_SC_R_INFO;
  wire [276:0]m11_nodes_M_SC_R_PAYLD;
  wire [0:0]m11_nodes_M_SC_R_RECV;
  wire [0:0]m11_nodes_M_SC_R_REQ;
  wire [0:0]m11_nodes_M_SC_R_SEND;
  wire [0:0]m11_nodes_M_SC_W_INFO;
  wire [318:0]m11_nodes_M_SC_W_PAYLD;
  wire m11_nodes_M_SC_W_RECV;
  wire [0:0]m11_nodes_M_SC_W_REQ;
  wire [0:0]m11_nodes_M_SC_W_SEND;
  wire [32:0]m11_sc2axi_M_AXI_ARADDR;
  wire [3:0]m11_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m11_sc2axi_M_AXI_ARID;
  wire [7:0]m11_sc2axi_M_AXI_ARLEN;
  wire [0:0]m11_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m11_sc2axi_M_AXI_ARPROT;
  wire [3:0]m11_sc2axi_M_AXI_ARQOS;
  wire m11_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m11_sc2axi_M_AXI_ARUSER;
  wire m11_sc2axi_M_AXI_ARVALID;
  wire [32:0]m11_sc2axi_M_AXI_AWADDR;
  wire [3:0]m11_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m11_sc2axi_M_AXI_AWID;
  wire [7:0]m11_sc2axi_M_AXI_AWLEN;
  wire [0:0]m11_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m11_sc2axi_M_AXI_AWPROT;
  wire [3:0]m11_sc2axi_M_AXI_AWQOS;
  wire m11_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m11_sc2axi_M_AXI_AWUSER;
  wire m11_sc2axi_M_AXI_AWVALID;
  wire [2:0]m11_sc2axi_M_AXI_BID;
  wire m11_sc2axi_M_AXI_BREADY;
  wire [1:0]m11_sc2axi_M_AXI_BRESP;
  wire [1023:0]m11_sc2axi_M_AXI_BUSER;
  wire m11_sc2axi_M_AXI_BVALID;
  wire [255:0]m11_sc2axi_M_AXI_RDATA;
  wire [2:0]m11_sc2axi_M_AXI_RID;
  wire m11_sc2axi_M_AXI_RLAST;
  wire m11_sc2axi_M_AXI_RREADY;
  wire [1:0]m11_sc2axi_M_AXI_RRESP;
  wire [1023:0]m11_sc2axi_M_AXI_RUSER;
  wire m11_sc2axi_M_AXI_RVALID;
  wire [255:0]m11_sc2axi_M_AXI_WDATA;
  wire m11_sc2axi_M_AXI_WLAST;
  wire m11_sc2axi_M_AXI_WREADY;
  wire [31:0]m11_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m11_sc2axi_M_AXI_WUSER;
  wire m11_sc2axi_M_AXI_WVALID;
  wire [0:0]m12_nodes_M_SC_AR_INFO;
  wire [301:0]m12_nodes_M_SC_AR_PAYLD;
  wire m12_nodes_M_SC_AR_RECV;
  wire [0:0]m12_nodes_M_SC_AR_REQ;
  wire [0:0]m12_nodes_M_SC_AR_SEND;
  wire [0:0]m12_nodes_M_SC_AW_INFO;
  wire [301:0]m12_nodes_M_SC_AW_PAYLD;
  wire m12_nodes_M_SC_AW_RECV;
  wire [0:0]m12_nodes_M_SC_AW_REQ;
  wire [0:0]m12_nodes_M_SC_AW_SEND;
  wire [0:0]m12_nodes_M_SC_B_INFO;
  wire [119:0]m12_nodes_M_SC_B_PAYLD;
  wire [0:0]m12_nodes_M_SC_B_RECV;
  wire [0:0]m12_nodes_M_SC_B_REQ;
  wire [0:0]m12_nodes_M_SC_B_SEND;
  wire [0:0]m12_nodes_M_SC_R_INFO;
  wire [276:0]m12_nodes_M_SC_R_PAYLD;
  wire [0:0]m12_nodes_M_SC_R_RECV;
  wire [0:0]m12_nodes_M_SC_R_REQ;
  wire [0:0]m12_nodes_M_SC_R_SEND;
  wire [0:0]m12_nodes_M_SC_W_INFO;
  wire [318:0]m12_nodes_M_SC_W_PAYLD;
  wire m12_nodes_M_SC_W_RECV;
  wire [0:0]m12_nodes_M_SC_W_REQ;
  wire [0:0]m12_nodes_M_SC_W_SEND;
  wire [32:0]m12_sc2axi_M_AXI_ARADDR;
  wire [3:0]m12_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m12_sc2axi_M_AXI_ARID;
  wire [7:0]m12_sc2axi_M_AXI_ARLEN;
  wire [0:0]m12_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m12_sc2axi_M_AXI_ARPROT;
  wire [3:0]m12_sc2axi_M_AXI_ARQOS;
  wire m12_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m12_sc2axi_M_AXI_ARUSER;
  wire m12_sc2axi_M_AXI_ARVALID;
  wire [32:0]m12_sc2axi_M_AXI_AWADDR;
  wire [3:0]m12_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m12_sc2axi_M_AXI_AWID;
  wire [7:0]m12_sc2axi_M_AXI_AWLEN;
  wire [0:0]m12_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m12_sc2axi_M_AXI_AWPROT;
  wire [3:0]m12_sc2axi_M_AXI_AWQOS;
  wire m12_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m12_sc2axi_M_AXI_AWUSER;
  wire m12_sc2axi_M_AXI_AWVALID;
  wire [2:0]m12_sc2axi_M_AXI_BID;
  wire m12_sc2axi_M_AXI_BREADY;
  wire [1:0]m12_sc2axi_M_AXI_BRESP;
  wire [1023:0]m12_sc2axi_M_AXI_BUSER;
  wire m12_sc2axi_M_AXI_BVALID;
  wire [255:0]m12_sc2axi_M_AXI_RDATA;
  wire [2:0]m12_sc2axi_M_AXI_RID;
  wire m12_sc2axi_M_AXI_RLAST;
  wire m12_sc2axi_M_AXI_RREADY;
  wire [1:0]m12_sc2axi_M_AXI_RRESP;
  wire [1023:0]m12_sc2axi_M_AXI_RUSER;
  wire m12_sc2axi_M_AXI_RVALID;
  wire [255:0]m12_sc2axi_M_AXI_WDATA;
  wire m12_sc2axi_M_AXI_WLAST;
  wire m12_sc2axi_M_AXI_WREADY;
  wire [31:0]m12_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m12_sc2axi_M_AXI_WUSER;
  wire m12_sc2axi_M_AXI_WVALID;
  wire [0:0]m13_nodes_M_SC_AR_INFO;
  wire [301:0]m13_nodes_M_SC_AR_PAYLD;
  wire m13_nodes_M_SC_AR_RECV;
  wire [0:0]m13_nodes_M_SC_AR_REQ;
  wire [0:0]m13_nodes_M_SC_AR_SEND;
  wire [0:0]m13_nodes_M_SC_AW_INFO;
  wire [301:0]m13_nodes_M_SC_AW_PAYLD;
  wire m13_nodes_M_SC_AW_RECV;
  wire [0:0]m13_nodes_M_SC_AW_REQ;
  wire [0:0]m13_nodes_M_SC_AW_SEND;
  wire [0:0]m13_nodes_M_SC_B_INFO;
  wire [119:0]m13_nodes_M_SC_B_PAYLD;
  wire [0:0]m13_nodes_M_SC_B_RECV;
  wire [0:0]m13_nodes_M_SC_B_REQ;
  wire [0:0]m13_nodes_M_SC_B_SEND;
  wire [0:0]m13_nodes_M_SC_R_INFO;
  wire [276:0]m13_nodes_M_SC_R_PAYLD;
  wire [0:0]m13_nodes_M_SC_R_RECV;
  wire [0:0]m13_nodes_M_SC_R_REQ;
  wire [0:0]m13_nodes_M_SC_R_SEND;
  wire [0:0]m13_nodes_M_SC_W_INFO;
  wire [318:0]m13_nodes_M_SC_W_PAYLD;
  wire m13_nodes_M_SC_W_RECV;
  wire [0:0]m13_nodes_M_SC_W_REQ;
  wire [0:0]m13_nodes_M_SC_W_SEND;
  wire [32:0]m13_sc2axi_M_AXI_ARADDR;
  wire [3:0]m13_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m13_sc2axi_M_AXI_ARID;
  wire [7:0]m13_sc2axi_M_AXI_ARLEN;
  wire [0:0]m13_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m13_sc2axi_M_AXI_ARPROT;
  wire [3:0]m13_sc2axi_M_AXI_ARQOS;
  wire m13_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m13_sc2axi_M_AXI_ARUSER;
  wire m13_sc2axi_M_AXI_ARVALID;
  wire [32:0]m13_sc2axi_M_AXI_AWADDR;
  wire [3:0]m13_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m13_sc2axi_M_AXI_AWID;
  wire [7:0]m13_sc2axi_M_AXI_AWLEN;
  wire [0:0]m13_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m13_sc2axi_M_AXI_AWPROT;
  wire [3:0]m13_sc2axi_M_AXI_AWQOS;
  wire m13_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m13_sc2axi_M_AXI_AWUSER;
  wire m13_sc2axi_M_AXI_AWVALID;
  wire [2:0]m13_sc2axi_M_AXI_BID;
  wire m13_sc2axi_M_AXI_BREADY;
  wire [1:0]m13_sc2axi_M_AXI_BRESP;
  wire [1023:0]m13_sc2axi_M_AXI_BUSER;
  wire m13_sc2axi_M_AXI_BVALID;
  wire [255:0]m13_sc2axi_M_AXI_RDATA;
  wire [2:0]m13_sc2axi_M_AXI_RID;
  wire m13_sc2axi_M_AXI_RLAST;
  wire m13_sc2axi_M_AXI_RREADY;
  wire [1:0]m13_sc2axi_M_AXI_RRESP;
  wire [1023:0]m13_sc2axi_M_AXI_RUSER;
  wire m13_sc2axi_M_AXI_RVALID;
  wire [255:0]m13_sc2axi_M_AXI_WDATA;
  wire m13_sc2axi_M_AXI_WLAST;
  wire m13_sc2axi_M_AXI_WREADY;
  wire [31:0]m13_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m13_sc2axi_M_AXI_WUSER;
  wire m13_sc2axi_M_AXI_WVALID;
  wire [0:0]m14_nodes_M_SC_AR_INFO;
  wire [301:0]m14_nodes_M_SC_AR_PAYLD;
  wire m14_nodes_M_SC_AR_RECV;
  wire [0:0]m14_nodes_M_SC_AR_REQ;
  wire [0:0]m14_nodes_M_SC_AR_SEND;
  wire [0:0]m14_nodes_M_SC_AW_INFO;
  wire [301:0]m14_nodes_M_SC_AW_PAYLD;
  wire m14_nodes_M_SC_AW_RECV;
  wire [0:0]m14_nodes_M_SC_AW_REQ;
  wire [0:0]m14_nodes_M_SC_AW_SEND;
  wire [0:0]m14_nodes_M_SC_B_INFO;
  wire [119:0]m14_nodes_M_SC_B_PAYLD;
  wire [0:0]m14_nodes_M_SC_B_RECV;
  wire [0:0]m14_nodes_M_SC_B_REQ;
  wire [0:0]m14_nodes_M_SC_B_SEND;
  wire [0:0]m14_nodes_M_SC_R_INFO;
  wire [276:0]m14_nodes_M_SC_R_PAYLD;
  wire [0:0]m14_nodes_M_SC_R_RECV;
  wire [0:0]m14_nodes_M_SC_R_REQ;
  wire [0:0]m14_nodes_M_SC_R_SEND;
  wire [0:0]m14_nodes_M_SC_W_INFO;
  wire [318:0]m14_nodes_M_SC_W_PAYLD;
  wire m14_nodes_M_SC_W_RECV;
  wire [0:0]m14_nodes_M_SC_W_REQ;
  wire [0:0]m14_nodes_M_SC_W_SEND;
  wire [32:0]m14_sc2axi_M_AXI_ARADDR;
  wire [3:0]m14_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m14_sc2axi_M_AXI_ARID;
  wire [7:0]m14_sc2axi_M_AXI_ARLEN;
  wire [0:0]m14_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m14_sc2axi_M_AXI_ARPROT;
  wire [3:0]m14_sc2axi_M_AXI_ARQOS;
  wire m14_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m14_sc2axi_M_AXI_ARUSER;
  wire m14_sc2axi_M_AXI_ARVALID;
  wire [32:0]m14_sc2axi_M_AXI_AWADDR;
  wire [3:0]m14_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m14_sc2axi_M_AXI_AWID;
  wire [7:0]m14_sc2axi_M_AXI_AWLEN;
  wire [0:0]m14_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m14_sc2axi_M_AXI_AWPROT;
  wire [3:0]m14_sc2axi_M_AXI_AWQOS;
  wire m14_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m14_sc2axi_M_AXI_AWUSER;
  wire m14_sc2axi_M_AXI_AWVALID;
  wire [2:0]m14_sc2axi_M_AXI_BID;
  wire m14_sc2axi_M_AXI_BREADY;
  wire [1:0]m14_sc2axi_M_AXI_BRESP;
  wire [1023:0]m14_sc2axi_M_AXI_BUSER;
  wire m14_sc2axi_M_AXI_BVALID;
  wire [255:0]m14_sc2axi_M_AXI_RDATA;
  wire [2:0]m14_sc2axi_M_AXI_RID;
  wire m14_sc2axi_M_AXI_RLAST;
  wire m14_sc2axi_M_AXI_RREADY;
  wire [1:0]m14_sc2axi_M_AXI_RRESP;
  wire [1023:0]m14_sc2axi_M_AXI_RUSER;
  wire m14_sc2axi_M_AXI_RVALID;
  wire [255:0]m14_sc2axi_M_AXI_WDATA;
  wire m14_sc2axi_M_AXI_WLAST;
  wire m14_sc2axi_M_AXI_WREADY;
  wire [31:0]m14_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m14_sc2axi_M_AXI_WUSER;
  wire m14_sc2axi_M_AXI_WVALID;
  wire [0:0]m15_nodes_M_SC_AR_INFO;
  wire [301:0]m15_nodes_M_SC_AR_PAYLD;
  wire m15_nodes_M_SC_AR_RECV;
  wire [0:0]m15_nodes_M_SC_AR_REQ;
  wire [0:0]m15_nodes_M_SC_AR_SEND;
  wire [0:0]m15_nodes_M_SC_AW_INFO;
  wire [301:0]m15_nodes_M_SC_AW_PAYLD;
  wire m15_nodes_M_SC_AW_RECV;
  wire [0:0]m15_nodes_M_SC_AW_REQ;
  wire [0:0]m15_nodes_M_SC_AW_SEND;
  wire [0:0]m15_nodes_M_SC_B_INFO;
  wire [119:0]m15_nodes_M_SC_B_PAYLD;
  wire [0:0]m15_nodes_M_SC_B_RECV;
  wire [0:0]m15_nodes_M_SC_B_REQ;
  wire [0:0]m15_nodes_M_SC_B_SEND;
  wire [0:0]m15_nodes_M_SC_R_INFO;
  wire [276:0]m15_nodes_M_SC_R_PAYLD;
  wire [0:0]m15_nodes_M_SC_R_RECV;
  wire [0:0]m15_nodes_M_SC_R_REQ;
  wire [0:0]m15_nodes_M_SC_R_SEND;
  wire [0:0]m15_nodes_M_SC_W_INFO;
  wire [318:0]m15_nodes_M_SC_W_PAYLD;
  wire m15_nodes_M_SC_W_RECV;
  wire [0:0]m15_nodes_M_SC_W_REQ;
  wire [0:0]m15_nodes_M_SC_W_SEND;
  wire [32:0]m15_sc2axi_M_AXI_ARADDR;
  wire [3:0]m15_sc2axi_M_AXI_ARCACHE;
  wire [2:0]m15_sc2axi_M_AXI_ARID;
  wire [7:0]m15_sc2axi_M_AXI_ARLEN;
  wire [0:0]m15_sc2axi_M_AXI_ARLOCK;
  wire [2:0]m15_sc2axi_M_AXI_ARPROT;
  wire [3:0]m15_sc2axi_M_AXI_ARQOS;
  wire m15_sc2axi_M_AXI_ARREADY;
  wire [1023:0]m15_sc2axi_M_AXI_ARUSER;
  wire m15_sc2axi_M_AXI_ARVALID;
  wire [32:0]m15_sc2axi_M_AXI_AWADDR;
  wire [3:0]m15_sc2axi_M_AXI_AWCACHE;
  wire [2:0]m15_sc2axi_M_AXI_AWID;
  wire [7:0]m15_sc2axi_M_AXI_AWLEN;
  wire [0:0]m15_sc2axi_M_AXI_AWLOCK;
  wire [2:0]m15_sc2axi_M_AXI_AWPROT;
  wire [3:0]m15_sc2axi_M_AXI_AWQOS;
  wire m15_sc2axi_M_AXI_AWREADY;
  wire [1023:0]m15_sc2axi_M_AXI_AWUSER;
  wire m15_sc2axi_M_AXI_AWVALID;
  wire [2:0]m15_sc2axi_M_AXI_BID;
  wire m15_sc2axi_M_AXI_BREADY;
  wire [1:0]m15_sc2axi_M_AXI_BRESP;
  wire [1023:0]m15_sc2axi_M_AXI_BUSER;
  wire m15_sc2axi_M_AXI_BVALID;
  wire [255:0]m15_sc2axi_M_AXI_RDATA;
  wire [2:0]m15_sc2axi_M_AXI_RID;
  wire m15_sc2axi_M_AXI_RLAST;
  wire m15_sc2axi_M_AXI_RREADY;
  wire [1:0]m15_sc2axi_M_AXI_RRESP;
  wire [1023:0]m15_sc2axi_M_AXI_RUSER;
  wire m15_sc2axi_M_AXI_RVALID;
  wire [255:0]m15_sc2axi_M_AXI_WDATA;
  wire m15_sc2axi_M_AXI_WLAST;
  wire m15_sc2axi_M_AXI_WREADY;
  wire [31:0]m15_sc2axi_M_AXI_WSTRB;
  wire [1023:0]m15_sc2axi_M_AXI_WUSER;
  wire m15_sc2axi_M_AXI_WVALID;
  wire [0:0]m_axi_aresetn_1;
  wire [0:0]m_axi_aresetn_10;
  wire [0:0]m_axi_aresetn_11;
  wire [0:0]m_axi_aresetn_12;
  wire [0:0]m_axi_aresetn_13;
  wire [0:0]m_axi_aresetn_14;
  wire [0:0]m_axi_aresetn_15;
  wire [0:0]m_axi_aresetn_16;
  wire [0:0]m_axi_aresetn_2;
  wire [0:0]m_axi_aresetn_3;
  wire [0:0]m_axi_aresetn_4;
  wire [0:0]m_axi_aresetn_5;
  wire [0:0]m_axi_aresetn_6;
  wire [0:0]m_axi_aresetn_7;
  wire [0:0]m_axi_aresetn_8;
  wire [0:0]m_axi_aresetn_9;
  wire [63:0]s00_entry_pipeline_m_axi_ARADDR;
  wire [3:0]s00_entry_pipeline_m_axi_ARCACHE;
  wire [2:0]s00_entry_pipeline_m_axi_ARID;
  wire [7:0]s00_entry_pipeline_m_axi_ARLEN;
  wire [0:0]s00_entry_pipeline_m_axi_ARLOCK;
  wire [2:0]s00_entry_pipeline_m_axi_ARPROT;
  wire [3:0]s00_entry_pipeline_m_axi_ARQOS;
  wire s00_entry_pipeline_m_axi_ARREADY;
  wire [1023:0]s00_entry_pipeline_m_axi_ARUSER;
  wire s00_entry_pipeline_m_axi_ARVALID;
  wire [63:0]s00_entry_pipeline_m_axi_AWADDR;
  wire [3:0]s00_entry_pipeline_m_axi_AWCACHE;
  wire [2:0]s00_entry_pipeline_m_axi_AWID;
  wire [7:0]s00_entry_pipeline_m_axi_AWLEN;
  wire [0:0]s00_entry_pipeline_m_axi_AWLOCK;
  wire [2:0]s00_entry_pipeline_m_axi_AWPROT;
  wire [3:0]s00_entry_pipeline_m_axi_AWQOS;
  wire s00_entry_pipeline_m_axi_AWREADY;
  wire [1023:0]s00_entry_pipeline_m_axi_AWUSER;
  wire s00_entry_pipeline_m_axi_AWVALID;
  wire [2:0]s00_entry_pipeline_m_axi_BID;
  wire s00_entry_pipeline_m_axi_BREADY;
  wire [1:0]s00_entry_pipeline_m_axi_BRESP;
  wire [1023:0]s00_entry_pipeline_m_axi_BUSER;
  wire s00_entry_pipeline_m_axi_BVALID;
  wire [255:0]s00_entry_pipeline_m_axi_RDATA;
  wire [2:0]s00_entry_pipeline_m_axi_RID;
  wire s00_entry_pipeline_m_axi_RLAST;
  wire s00_entry_pipeline_m_axi_RREADY;
  wire [1:0]s00_entry_pipeline_m_axi_RRESP;
  wire [1023:0]s00_entry_pipeline_m_axi_RUSER;
  wire s00_entry_pipeline_m_axi_RVALID;
  wire [255:0]s00_entry_pipeline_m_axi_WDATA;
  wire s00_entry_pipeline_m_axi_WLAST;
  wire s00_entry_pipeline_m_axi_WREADY;
  wire [31:0]s00_entry_pipeline_m_axi_WSTRB;
  wire [1023:0]s00_entry_pipeline_m_axi_WUSER;
  wire s00_entry_pipeline_m_axi_WVALID;
  wire [15:0]s00_nodes_M_SC_AR_INFO;
  wire [301:0]s00_nodes_M_SC_AR_PAYLD;
  wire [15:0]s00_nodes_M_SC_AR_RECV;
  wire [15:0]s00_nodes_M_SC_AR_REQ;
  wire [15:0]s00_nodes_M_SC_AR_SEND;
  wire [15:0]s00_nodes_M_SC_AW_INFO;
  wire [301:0]s00_nodes_M_SC_AW_PAYLD;
  wire [15:0]s00_nodes_M_SC_AW_RECV;
  wire [15:0]s00_nodes_M_SC_AW_REQ;
  wire [15:0]s00_nodes_M_SC_AW_SEND;
  wire [0:0]s00_nodes_M_SC_B_INFO;
  wire [119:0]s00_nodes_M_SC_B_PAYLD;
  wire s00_nodes_M_SC_B_RECV;
  wire [0:0]s00_nodes_M_SC_B_REQ;
  wire [0:0]s00_nodes_M_SC_B_SEND;
  wire [0:0]s00_nodes_M_SC_R_INFO;
  wire [276:0]s00_nodes_M_SC_R_PAYLD;
  wire s00_nodes_M_SC_R_RECV;
  wire [0:0]s00_nodes_M_SC_R_REQ;
  wire [0:0]s00_nodes_M_SC_R_SEND;
  wire [15:0]s00_nodes_M_SC_W_INFO;
  wire [318:0]s00_nodes_M_SC_W_PAYLD;
  wire [15:0]s00_nodes_M_SC_W_RECV;
  wire [15:0]s00_nodes_M_SC_W_REQ;
  wire [15:0]s00_nodes_M_SC_W_SEND;
  wire swbd_aclk_net;
  wire [0:0]swbd_aresetn_net;

  clk_map_imp_4ATSV1 clk_map
       (.M00_ACLK(clk_map_M00_ACLK),
        .M00_ARESETN(m_axi_aresetn_1),
        .M01_ACLK(clk_map_M01_ACLK),
        .M01_ARESETN(m_axi_aresetn_2),
        .M02_ACLK(clk_map_M02_ACLK),
        .M02_ARESETN(m_axi_aresetn_3),
        .M03_ACLK(clk_map_M03_ACLK),
        .M03_ARESETN(m_axi_aresetn_4),
        .M04_ACLK(clk_map_M04_ACLK),
        .M04_ARESETN(m_axi_aresetn_5),
        .M05_ACLK(clk_map_M05_ACLK),
        .M05_ARESETN(m_axi_aresetn_6),
        .M06_ACLK(clk_map_M06_ACLK),
        .M06_ARESETN(m_axi_aresetn_7),
        .M07_ACLK(clk_map_M07_ACLK),
        .M07_ARESETN(m_axi_aresetn_8),
        .M08_ACLK(clk_map_M08_ACLK),
        .M08_ARESETN(m_axi_aresetn_9),
        .M09_ACLK(clk_map_M09_ACLK),
        .M09_ARESETN(m_axi_aresetn_10),
        .M10_ACLK(clk_map_M10_ACLK),
        .M10_ARESETN(m_axi_aresetn_11),
        .M11_ACLK(clk_map_M11_ACLK),
        .M11_ARESETN(m_axi_aresetn_12),
        .M12_ACLK(clk_map_M12_ACLK),
        .M12_ARESETN(m_axi_aresetn_13),
        .M13_ACLK(clk_map_M13_ACLK),
        .M13_ARESETN(m_axi_aresetn_14),
        .M14_ACLK(clk_map_M14_ACLK),
        .M14_ARESETN(m_axi_aresetn_15),
        .M15_ACLK(clk_map_M15_ACLK),
        .M15_ARESETN(m_axi_aresetn_16),
        .S00_ACLK(aclk_1),
        .S00_ARESETN(aresetn_2),
        .aclk(aclk),
        .aresetn(aresetn),
        .aresetn_out(aresetn_net),
        .swbd_aclk(swbd_aclk_net),
        .swbd_aresetn(swbd_aresetn_net));
  m00_exit_pipeline_imp_1WL21S6 m00_exit_pipeline
       (.aclk(clk_map_M00_ACLK),
        .aresetn(m_axi_aresetn_1),
        .m_axi_araddr(M00_AXI_araddr),
        .m_axi_arburst(M00_AXI_arburst),
        .m_axi_arcache(M00_AXI_arcache),
        .m_axi_arlen(M00_AXI_arlen),
        .m_axi_arlock(M00_AXI_arlock),
        .m_axi_arprot(M00_AXI_arprot),
        .m_axi_arqos(M00_AXI_arqos),
        .m_axi_arready(M00_AXI_arready),
        .m_axi_arsize(M00_AXI_arsize),
        .m_axi_arvalid(M00_AXI_arvalid),
        .m_axi_awaddr(M00_AXI_awaddr),
        .m_axi_awburst(M00_AXI_awburst),
        .m_axi_awcache(M00_AXI_awcache),
        .m_axi_awlen(M00_AXI_awlen),
        .m_axi_awlock(M00_AXI_awlock),
        .m_axi_awprot(M00_AXI_awprot),
        .m_axi_awqos(M00_AXI_awqos),
        .m_axi_awready(M00_AXI_awready),
        .m_axi_awsize(M00_AXI_awsize),
        .m_axi_awvalid(M00_AXI_awvalid),
        .m_axi_bready(M00_AXI_bready),
        .m_axi_bresp(M00_AXI_bresp),
        .m_axi_bvalid(M00_AXI_bvalid),
        .m_axi_rdata(M00_AXI_rdata),
        .m_axi_rlast(M00_AXI_rlast),
        .m_axi_rready(M00_AXI_rready),
        .m_axi_rresp(M00_AXI_rresp),
        .m_axi_rvalid(M00_AXI_rvalid),
        .m_axi_wdata(M00_AXI_wdata),
        .m_axi_wlast(M00_AXI_wlast),
        .m_axi_wready(M00_AXI_wready),
        .m_axi_wstrb(M00_AXI_wstrb),
        .m_axi_wvalid(M00_AXI_wvalid),
        .s_axi_araddr(m00_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m00_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m00_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m00_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m00_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m00_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m00_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m00_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m00_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m00_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m00_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m00_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m00_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m00_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m00_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m00_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m00_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m00_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m00_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m00_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m00_sc2axi_M_AXI_BID),
        .s_axi_bready(m00_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m00_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m00_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m00_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m00_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m00_sc2axi_M_AXI_RID),
        .s_axi_rlast(m00_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m00_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m00_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m00_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m00_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m00_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m00_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m00_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m00_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m00_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m00_sc2axi_M_AXI_WVALID));
  m00_nodes_imp_1AD58KQ m00_nodes
       (.M_SC_AR_info(m00_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m00_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m00_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m00_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m00_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m00_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m00_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m00_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m00_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m00_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m00_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m00_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m00_nodes_M_SC_B_RECV),
        .M_SC_B_req(m00_nodes_M_SC_B_REQ),
        .M_SC_B_send(m00_nodes_M_SC_B_SEND),
        .M_SC_R_info(m00_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m00_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m00_nodes_M_SC_R_RECV),
        .M_SC_R_req(m00_nodes_M_SC_R_REQ),
        .M_SC_R_send(m00_nodes_M_SC_R_SEND),
        .M_SC_W_info(m00_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m00_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m00_nodes_M_SC_W_RECV),
        .M_SC_W_req(m00_nodes_M_SC_W_REQ),
        .M_SC_W_send(m00_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_2_INFO),
        .S_SC_AR_payld(S_SC_AR_2_PAYLD),
        .S_SC_AR_recv(S_SC_AR_2_RECV),
        .S_SC_AR_req(S_SC_AR_2_REQ),
        .S_SC_AR_send(S_SC_AR_2_SEND),
        .S_SC_AW_info(S_SC_AW_2_INFO),
        .S_SC_AW_payld(S_SC_AW_2_PAYLD),
        .S_SC_AW_recv(S_SC_AW_2_RECV),
        .S_SC_AW_req(S_SC_AW_2_REQ),
        .S_SC_AW_send(S_SC_AW_2_SEND),
        .S_SC_B_info(S_SC_B_2_INFO),
        .S_SC_B_payld(S_SC_B_2_PAYLD),
        .S_SC_B_recv(S_SC_B_2_RECV),
        .S_SC_B_req(S_SC_B_2_REQ),
        .S_SC_B_send(S_SC_B_2_SEND),
        .S_SC_R_info(S_SC_R_2_INFO),
        .S_SC_R_payld(S_SC_R_2_PAYLD),
        .S_SC_R_recv(S_SC_R_2_RECV),
        .S_SC_R_req(S_SC_R_2_REQ),
        .S_SC_R_send(S_SC_R_2_SEND),
        .S_SC_W_info(S_SC_W_2_INFO),
        .S_SC_W_payld(S_SC_W_2_PAYLD),
        .S_SC_W_recv(S_SC_W_2_RECV),
        .S_SC_W_req(S_SC_W_2_REQ),
        .S_SC_W_send(S_SC_W_2_SEND),
        .m_axi_aclk(clk_map_M00_ACLK),
        .m_axi_aresetn(m_axi_aresetn_1),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m00s2a_0 m00_sc2axi
       (.aclk(clk_map_M00_ACLK),
        .m_axi_araddr(m00_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m00_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m00_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m00_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m00_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m00_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m00_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m00_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m00_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m00_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m00_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m00_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m00_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m00_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m00_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m00_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m00_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m00_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m00_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m00_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m00_sc2axi_M_AXI_BID),
        .m_axi_bready(m00_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m00_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m00_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m00_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m00_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m00_sc2axi_M_AXI_RID),
        .m_axi_rlast(m00_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m00_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m00_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m00_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m00_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m00_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m00_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m00_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m00_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m00_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m00_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_2_INFO),
        .m_sc_b_payld(S_SC_B_2_PAYLD),
        .m_sc_b_recv(S_SC_B_2_RECV),
        .m_sc_b_req(S_SC_B_2_REQ),
        .m_sc_b_send(S_SC_B_2_SEND),
        .m_sc_r_info(S_SC_R_2_INFO),
        .m_sc_r_payld(S_SC_R_2_PAYLD),
        .m_sc_r_recv(S_SC_R_2_RECV),
        .m_sc_r_req(S_SC_R_2_REQ),
        .m_sc_r_send(S_SC_R_2_SEND),
        .s_sc_ar_info(m00_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m00_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m00_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m00_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m00_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m00_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m00_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m00_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m00_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m00_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m00_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m00_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m00_nodes_M_SC_W_RECV),
        .s_sc_w_req(m00_nodes_M_SC_W_REQ),
        .s_sc_w_send(m00_nodes_M_SC_W_SEND));
  m01_exit_pipeline_imp_1Q5REBQ m01_exit_pipeline
       (.aclk(clk_map_M01_ACLK),
        .aresetn(m_axi_aresetn_2),
        .m_axi_araddr(M01_AXI_araddr),
        .m_axi_arburst(M01_AXI_arburst),
        .m_axi_arcache(M01_AXI_arcache),
        .m_axi_arlen(M01_AXI_arlen),
        .m_axi_arlock(M01_AXI_arlock),
        .m_axi_arprot(M01_AXI_arprot),
        .m_axi_arqos(M01_AXI_arqos),
        .m_axi_arready(M01_AXI_arready),
        .m_axi_arsize(M01_AXI_arsize),
        .m_axi_arvalid(M01_AXI_arvalid),
        .m_axi_awaddr(M01_AXI_awaddr),
        .m_axi_awburst(M01_AXI_awburst),
        .m_axi_awcache(M01_AXI_awcache),
        .m_axi_awlen(M01_AXI_awlen),
        .m_axi_awlock(M01_AXI_awlock),
        .m_axi_awprot(M01_AXI_awprot),
        .m_axi_awqos(M01_AXI_awqos),
        .m_axi_awready(M01_AXI_awready),
        .m_axi_awsize(M01_AXI_awsize),
        .m_axi_awvalid(M01_AXI_awvalid),
        .m_axi_bready(M01_AXI_bready),
        .m_axi_bresp(M01_AXI_bresp),
        .m_axi_bvalid(M01_AXI_bvalid),
        .m_axi_rdata(M01_AXI_rdata),
        .m_axi_rlast(M01_AXI_rlast),
        .m_axi_rready(M01_AXI_rready),
        .m_axi_rresp(M01_AXI_rresp),
        .m_axi_rvalid(M01_AXI_rvalid),
        .m_axi_wdata(M01_AXI_wdata),
        .m_axi_wlast(M01_AXI_wlast),
        .m_axi_wready(M01_AXI_wready),
        .m_axi_wstrb(M01_AXI_wstrb),
        .m_axi_wvalid(M01_AXI_wvalid),
        .s_axi_araddr(m01_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m01_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m01_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m01_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m01_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m01_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m01_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m01_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m01_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m01_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m01_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m01_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m01_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m01_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m01_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m01_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m01_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m01_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m01_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m01_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m01_sc2axi_M_AXI_BID),
        .s_axi_bready(m01_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m01_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m01_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m01_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m01_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m01_sc2axi_M_AXI_RID),
        .s_axi_rlast(m01_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m01_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m01_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m01_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m01_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m01_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m01_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m01_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m01_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m01_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m01_sc2axi_M_AXI_WVALID));
  m01_nodes_imp_G46ZTO m01_nodes
       (.M_SC_AR_info(m01_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m01_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m01_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m01_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m01_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m01_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m01_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m01_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m01_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m01_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m01_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m01_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m01_nodes_M_SC_B_RECV),
        .M_SC_B_req(m01_nodes_M_SC_B_REQ),
        .M_SC_B_send(m01_nodes_M_SC_B_SEND),
        .M_SC_R_info(m01_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m01_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m01_nodes_M_SC_R_RECV),
        .M_SC_R_req(m01_nodes_M_SC_R_REQ),
        .M_SC_R_send(m01_nodes_M_SC_R_SEND),
        .M_SC_W_info(m01_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m01_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m01_nodes_M_SC_W_RECV),
        .M_SC_W_req(m01_nodes_M_SC_W_REQ),
        .M_SC_W_send(m01_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_3_INFO),
        .S_SC_AR_payld(S_SC_AR_3_PAYLD),
        .S_SC_AR_recv(S_SC_AR_3_RECV),
        .S_SC_AR_req(S_SC_AR_3_REQ),
        .S_SC_AR_send(S_SC_AR_3_SEND),
        .S_SC_AW_info(S_SC_AW_3_INFO),
        .S_SC_AW_payld(S_SC_AW_3_PAYLD),
        .S_SC_AW_recv(S_SC_AW_3_RECV),
        .S_SC_AW_req(S_SC_AW_3_REQ),
        .S_SC_AW_send(S_SC_AW_3_SEND),
        .S_SC_B_info(S_SC_B_3_INFO),
        .S_SC_B_payld(S_SC_B_3_PAYLD),
        .S_SC_B_recv(S_SC_B_3_RECV),
        .S_SC_B_req(S_SC_B_3_REQ),
        .S_SC_B_send(S_SC_B_3_SEND),
        .S_SC_R_info(S_SC_R_3_INFO),
        .S_SC_R_payld(S_SC_R_3_PAYLD),
        .S_SC_R_recv(S_SC_R_3_RECV),
        .S_SC_R_req(S_SC_R_3_REQ),
        .S_SC_R_send(S_SC_R_3_SEND),
        .S_SC_W_info(S_SC_W_3_INFO),
        .S_SC_W_payld(S_SC_W_3_PAYLD),
        .S_SC_W_recv(S_SC_W_3_RECV),
        .S_SC_W_req(S_SC_W_3_REQ),
        .S_SC_W_send(S_SC_W_3_SEND),
        .m_axi_aclk(clk_map_M01_ACLK),
        .m_axi_aresetn(m_axi_aresetn_2),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m01s2a_0 m01_sc2axi
       (.aclk(clk_map_M01_ACLK),
        .m_axi_araddr(m01_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m01_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m01_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m01_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m01_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m01_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m01_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m01_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m01_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m01_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m01_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m01_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m01_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m01_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m01_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m01_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m01_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m01_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m01_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m01_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m01_sc2axi_M_AXI_BID),
        .m_axi_bready(m01_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m01_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m01_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m01_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m01_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m01_sc2axi_M_AXI_RID),
        .m_axi_rlast(m01_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m01_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m01_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m01_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m01_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m01_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m01_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m01_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m01_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m01_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m01_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_3_INFO),
        .m_sc_b_payld(S_SC_B_3_PAYLD),
        .m_sc_b_recv(S_SC_B_3_RECV),
        .m_sc_b_req(S_SC_B_3_REQ),
        .m_sc_b_send(S_SC_B_3_SEND),
        .m_sc_r_info(S_SC_R_3_INFO),
        .m_sc_r_payld(S_SC_R_3_PAYLD),
        .m_sc_r_recv(S_SC_R_3_RECV),
        .m_sc_r_req(S_SC_R_3_REQ),
        .m_sc_r_send(S_SC_R_3_SEND),
        .s_sc_ar_info(m01_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m01_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m01_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m01_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m01_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m01_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m01_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m01_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m01_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m01_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m01_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m01_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m01_nodes_M_SC_W_RECV),
        .s_sc_w_req(m01_nodes_M_SC_W_REQ),
        .s_sc_w_send(m01_nodes_M_SC_W_SEND));
  m02_exit_pipeline_imp_1OCJM6E m02_exit_pipeline
       (.aclk(clk_map_M02_ACLK),
        .aresetn(m_axi_aresetn_3),
        .m_axi_araddr(M02_AXI_araddr),
        .m_axi_arburst(M02_AXI_arburst),
        .m_axi_arcache(M02_AXI_arcache),
        .m_axi_arlen(M02_AXI_arlen),
        .m_axi_arlock(M02_AXI_arlock),
        .m_axi_arprot(M02_AXI_arprot),
        .m_axi_arqos(M02_AXI_arqos),
        .m_axi_arready(M02_AXI_arready),
        .m_axi_arsize(M02_AXI_arsize),
        .m_axi_arvalid(M02_AXI_arvalid),
        .m_axi_awaddr(M02_AXI_awaddr),
        .m_axi_awburst(M02_AXI_awburst),
        .m_axi_awcache(M02_AXI_awcache),
        .m_axi_awlen(M02_AXI_awlen),
        .m_axi_awlock(M02_AXI_awlock),
        .m_axi_awprot(M02_AXI_awprot),
        .m_axi_awqos(M02_AXI_awqos),
        .m_axi_awready(M02_AXI_awready),
        .m_axi_awsize(M02_AXI_awsize),
        .m_axi_awvalid(M02_AXI_awvalid),
        .m_axi_bready(M02_AXI_bready),
        .m_axi_bresp(M02_AXI_bresp),
        .m_axi_bvalid(M02_AXI_bvalid),
        .m_axi_rdata(M02_AXI_rdata),
        .m_axi_rlast(M02_AXI_rlast),
        .m_axi_rready(M02_AXI_rready),
        .m_axi_rresp(M02_AXI_rresp),
        .m_axi_rvalid(M02_AXI_rvalid),
        .m_axi_wdata(M02_AXI_wdata),
        .m_axi_wlast(M02_AXI_wlast),
        .m_axi_wready(M02_AXI_wready),
        .m_axi_wstrb(M02_AXI_wstrb),
        .m_axi_wvalid(M02_AXI_wvalid),
        .s_axi_araddr(m02_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m02_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m02_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m02_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m02_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m02_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m02_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m02_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m02_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m02_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m02_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m02_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m02_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m02_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m02_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m02_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m02_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m02_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m02_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m02_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m02_sc2axi_M_AXI_BID),
        .s_axi_bready(m02_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m02_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m02_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m02_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m02_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m02_sc2axi_M_AXI_RID),
        .s_axi_rlast(m02_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m02_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m02_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m02_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m02_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m02_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m02_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m02_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m02_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m02_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m02_sc2axi_M_AXI_WVALID));
  m02_nodes_imp_JJRDAF m02_nodes
       (.M_SC_AR_info(m02_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m02_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m02_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m02_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m02_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m02_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m02_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m02_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m02_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m02_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m02_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m02_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m02_nodes_M_SC_B_RECV),
        .M_SC_B_req(m02_nodes_M_SC_B_REQ),
        .M_SC_B_send(m02_nodes_M_SC_B_SEND),
        .M_SC_R_info(m02_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m02_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m02_nodes_M_SC_R_RECV),
        .M_SC_R_req(m02_nodes_M_SC_R_REQ),
        .M_SC_R_send(m02_nodes_M_SC_R_SEND),
        .M_SC_W_info(m02_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m02_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m02_nodes_M_SC_W_RECV),
        .M_SC_W_req(m02_nodes_M_SC_W_REQ),
        .M_SC_W_send(m02_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_4_INFO),
        .S_SC_AR_payld(S_SC_AR_4_PAYLD),
        .S_SC_AR_recv(S_SC_AR_4_RECV),
        .S_SC_AR_req(S_SC_AR_4_REQ),
        .S_SC_AR_send(S_SC_AR_4_SEND),
        .S_SC_AW_info(S_SC_AW_4_INFO),
        .S_SC_AW_payld(S_SC_AW_4_PAYLD),
        .S_SC_AW_recv(S_SC_AW_4_RECV),
        .S_SC_AW_req(S_SC_AW_4_REQ),
        .S_SC_AW_send(S_SC_AW_4_SEND),
        .S_SC_B_info(S_SC_B_4_INFO),
        .S_SC_B_payld(S_SC_B_4_PAYLD),
        .S_SC_B_recv(S_SC_B_4_RECV),
        .S_SC_B_req(S_SC_B_4_REQ),
        .S_SC_B_send(S_SC_B_4_SEND),
        .S_SC_R_info(S_SC_R_4_INFO),
        .S_SC_R_payld(S_SC_R_4_PAYLD),
        .S_SC_R_recv(S_SC_R_4_RECV),
        .S_SC_R_req(S_SC_R_4_REQ),
        .S_SC_R_send(S_SC_R_4_SEND),
        .S_SC_W_info(S_SC_W_4_INFO),
        .S_SC_W_payld(S_SC_W_4_PAYLD),
        .S_SC_W_recv(S_SC_W_4_RECV),
        .S_SC_W_req(S_SC_W_4_REQ),
        .S_SC_W_send(S_SC_W_4_SEND),
        .m_axi_aclk(clk_map_M02_ACLK),
        .m_axi_aresetn(m_axi_aresetn_3),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m02s2a_0 m02_sc2axi
       (.aclk(clk_map_M02_ACLK),
        .m_axi_araddr(m02_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m02_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m02_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m02_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m02_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m02_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m02_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m02_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m02_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m02_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m02_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m02_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m02_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m02_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m02_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m02_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m02_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m02_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m02_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m02_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m02_sc2axi_M_AXI_BID),
        .m_axi_bready(m02_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m02_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m02_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m02_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m02_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m02_sc2axi_M_AXI_RID),
        .m_axi_rlast(m02_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m02_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m02_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m02_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m02_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m02_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m02_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m02_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m02_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m02_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m02_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_4_INFO),
        .m_sc_b_payld(S_SC_B_4_PAYLD),
        .m_sc_b_recv(S_SC_B_4_RECV),
        .m_sc_b_req(S_SC_B_4_REQ),
        .m_sc_b_send(S_SC_B_4_SEND),
        .m_sc_r_info(S_SC_R_4_INFO),
        .m_sc_r_payld(S_SC_R_4_PAYLD),
        .m_sc_r_recv(S_SC_R_4_RECV),
        .m_sc_r_req(S_SC_R_4_REQ),
        .m_sc_r_send(S_SC_R_4_SEND),
        .s_sc_ar_info(m02_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m02_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m02_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m02_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m02_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m02_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m02_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m02_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m02_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m02_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m02_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m02_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m02_nodes_M_SC_W_RECV),
        .s_sc_w_req(m02_nodes_M_SC_W_REQ),
        .s_sc_w_send(m02_nodes_M_SC_W_SEND));
  m03_exit_pipeline_imp_1L93E86 m03_exit_pipeline
       (.aclk(clk_map_M03_ACLK),
        .aresetn(m_axi_aresetn_4),
        .m_axi_araddr(M03_AXI_araddr),
        .m_axi_arburst(M03_AXI_arburst),
        .m_axi_arcache(M03_AXI_arcache),
        .m_axi_arlen(M03_AXI_arlen),
        .m_axi_arlock(M03_AXI_arlock),
        .m_axi_arprot(M03_AXI_arprot),
        .m_axi_arqos(M03_AXI_arqos),
        .m_axi_arready(M03_AXI_arready),
        .m_axi_arsize(M03_AXI_arsize),
        .m_axi_arvalid(M03_AXI_arvalid),
        .m_axi_awaddr(M03_AXI_awaddr),
        .m_axi_awburst(M03_AXI_awburst),
        .m_axi_awcache(M03_AXI_awcache),
        .m_axi_awlen(M03_AXI_awlen),
        .m_axi_awlock(M03_AXI_awlock),
        .m_axi_awprot(M03_AXI_awprot),
        .m_axi_awqos(M03_AXI_awqos),
        .m_axi_awready(M03_AXI_awready),
        .m_axi_awsize(M03_AXI_awsize),
        .m_axi_awvalid(M03_AXI_awvalid),
        .m_axi_bready(M03_AXI_bready),
        .m_axi_bresp(M03_AXI_bresp),
        .m_axi_bvalid(M03_AXI_bvalid),
        .m_axi_rdata(M03_AXI_rdata),
        .m_axi_rlast(M03_AXI_rlast),
        .m_axi_rready(M03_AXI_rready),
        .m_axi_rresp(M03_AXI_rresp),
        .m_axi_rvalid(M03_AXI_rvalid),
        .m_axi_wdata(M03_AXI_wdata),
        .m_axi_wlast(M03_AXI_wlast),
        .m_axi_wready(M03_AXI_wready),
        .m_axi_wstrb(M03_AXI_wstrb),
        .m_axi_wvalid(M03_AXI_wvalid),
        .s_axi_araddr(m03_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m03_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m03_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m03_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m03_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m03_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m03_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m03_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m03_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m03_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m03_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m03_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m03_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m03_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m03_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m03_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m03_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m03_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m03_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m03_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m03_sc2axi_M_AXI_BID),
        .s_axi_bready(m03_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m03_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m03_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m03_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m03_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m03_sc2axi_M_AXI_RID),
        .s_axi_rlast(m03_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m03_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m03_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m03_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m03_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m03_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m03_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m03_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m03_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m03_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m03_sc2axi_M_AXI_WVALID));
  m03_nodes_imp_1OWCIUP m03_nodes
       (.M_SC_AR_info(m03_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m03_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m03_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m03_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m03_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m03_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m03_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m03_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m03_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m03_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m03_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m03_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m03_nodes_M_SC_B_RECV),
        .M_SC_B_req(m03_nodes_M_SC_B_REQ),
        .M_SC_B_send(m03_nodes_M_SC_B_SEND),
        .M_SC_R_info(m03_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m03_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m03_nodes_M_SC_R_RECV),
        .M_SC_R_req(m03_nodes_M_SC_R_REQ),
        .M_SC_R_send(m03_nodes_M_SC_R_SEND),
        .M_SC_W_info(m03_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m03_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m03_nodes_M_SC_W_RECV),
        .M_SC_W_req(m03_nodes_M_SC_W_REQ),
        .M_SC_W_send(m03_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_5_INFO),
        .S_SC_AR_payld(S_SC_AR_5_PAYLD),
        .S_SC_AR_recv(S_SC_AR_5_RECV),
        .S_SC_AR_req(S_SC_AR_5_REQ),
        .S_SC_AR_send(S_SC_AR_5_SEND),
        .S_SC_AW_info(S_SC_AW_5_INFO),
        .S_SC_AW_payld(S_SC_AW_5_PAYLD),
        .S_SC_AW_recv(S_SC_AW_5_RECV),
        .S_SC_AW_req(S_SC_AW_5_REQ),
        .S_SC_AW_send(S_SC_AW_5_SEND),
        .S_SC_B_info(S_SC_B_5_INFO),
        .S_SC_B_payld(S_SC_B_5_PAYLD),
        .S_SC_B_recv(S_SC_B_5_RECV),
        .S_SC_B_req(S_SC_B_5_REQ),
        .S_SC_B_send(S_SC_B_5_SEND),
        .S_SC_R_info(S_SC_R_5_INFO),
        .S_SC_R_payld(S_SC_R_5_PAYLD),
        .S_SC_R_recv(S_SC_R_5_RECV),
        .S_SC_R_req(S_SC_R_5_REQ),
        .S_SC_R_send(S_SC_R_5_SEND),
        .S_SC_W_info(S_SC_W_5_INFO),
        .S_SC_W_payld(S_SC_W_5_PAYLD),
        .S_SC_W_recv(S_SC_W_5_RECV),
        .S_SC_W_req(S_SC_W_5_REQ),
        .S_SC_W_send(S_SC_W_5_SEND),
        .m_axi_aclk(clk_map_M03_ACLK),
        .m_axi_aresetn(m_axi_aresetn_4),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m03s2a_0 m03_sc2axi
       (.aclk(clk_map_M03_ACLK),
        .m_axi_araddr(m03_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m03_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m03_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m03_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m03_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m03_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m03_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m03_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m03_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m03_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m03_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m03_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m03_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m03_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m03_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m03_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m03_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m03_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m03_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m03_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m03_sc2axi_M_AXI_BID),
        .m_axi_bready(m03_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m03_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m03_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m03_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m03_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m03_sc2axi_M_AXI_RID),
        .m_axi_rlast(m03_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m03_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m03_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m03_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m03_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m03_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m03_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m03_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m03_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m03_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m03_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_5_INFO),
        .m_sc_b_payld(S_SC_B_5_PAYLD),
        .m_sc_b_recv(S_SC_B_5_RECV),
        .m_sc_b_req(S_SC_B_5_REQ),
        .m_sc_b_send(S_SC_B_5_SEND),
        .m_sc_r_info(S_SC_R_5_INFO),
        .m_sc_r_payld(S_SC_R_5_PAYLD),
        .m_sc_r_recv(S_SC_R_5_RECV),
        .m_sc_r_req(S_SC_R_5_REQ),
        .m_sc_r_send(S_SC_R_5_SEND),
        .s_sc_ar_info(m03_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m03_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m03_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m03_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m03_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m03_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m03_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m03_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m03_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m03_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m03_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m03_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m03_nodes_M_SC_W_RECV),
        .s_sc_w_req(m03_nodes_M_SC_W_REQ),
        .s_sc_w_send(m03_nodes_M_SC_W_SEND));
  m04_exit_pipeline_imp_1BLMYKM m04_exit_pipeline
       (.aclk(clk_map_M04_ACLK),
        .aresetn(m_axi_aresetn_5),
        .m_axi_araddr(M04_AXI_araddr),
        .m_axi_arburst(M04_AXI_arburst),
        .m_axi_arcache(M04_AXI_arcache),
        .m_axi_arlen(M04_AXI_arlen),
        .m_axi_arlock(M04_AXI_arlock),
        .m_axi_arprot(M04_AXI_arprot),
        .m_axi_arqos(M04_AXI_arqos),
        .m_axi_arready(M04_AXI_arready),
        .m_axi_arsize(M04_AXI_arsize),
        .m_axi_arvalid(M04_AXI_arvalid),
        .m_axi_awaddr(M04_AXI_awaddr),
        .m_axi_awburst(M04_AXI_awburst),
        .m_axi_awcache(M04_AXI_awcache),
        .m_axi_awlen(M04_AXI_awlen),
        .m_axi_awlock(M04_AXI_awlock),
        .m_axi_awprot(M04_AXI_awprot),
        .m_axi_awqos(M04_AXI_awqos),
        .m_axi_awready(M04_AXI_awready),
        .m_axi_awsize(M04_AXI_awsize),
        .m_axi_awvalid(M04_AXI_awvalid),
        .m_axi_bready(M04_AXI_bready),
        .m_axi_bresp(M04_AXI_bresp),
        .m_axi_bvalid(M04_AXI_bvalid),
        .m_axi_rdata(M04_AXI_rdata),
        .m_axi_rlast(M04_AXI_rlast),
        .m_axi_rready(M04_AXI_rready),
        .m_axi_rresp(M04_AXI_rresp),
        .m_axi_rvalid(M04_AXI_rvalid),
        .m_axi_wdata(M04_AXI_wdata),
        .m_axi_wlast(M04_AXI_wlast),
        .m_axi_wready(M04_AXI_wready),
        .m_axi_wstrb(M04_AXI_wstrb),
        .m_axi_wvalid(M04_AXI_wvalid),
        .s_axi_araddr(m04_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m04_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m04_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m04_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m04_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m04_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m04_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m04_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m04_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m04_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m04_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m04_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m04_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m04_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m04_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m04_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m04_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m04_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m04_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m04_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m04_sc2axi_M_AXI_BID),
        .s_axi_bready(m04_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m04_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m04_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m04_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m04_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m04_sc2axi_M_AXI_RID),
        .s_axi_rlast(m04_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m04_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m04_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m04_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m04_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m04_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m04_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m04_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m04_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m04_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m04_sc2axi_M_AXI_WVALID));
  m04_nodes_imp_1GWZNAP m04_nodes
       (.M_SC_AR_info(m04_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m04_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m04_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m04_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m04_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m04_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m04_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m04_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m04_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m04_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m04_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m04_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m04_nodes_M_SC_B_RECV),
        .M_SC_B_req(m04_nodes_M_SC_B_REQ),
        .M_SC_B_send(m04_nodes_M_SC_B_SEND),
        .M_SC_R_info(m04_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m04_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m04_nodes_M_SC_R_RECV),
        .M_SC_R_req(m04_nodes_M_SC_R_REQ),
        .M_SC_R_send(m04_nodes_M_SC_R_SEND),
        .M_SC_W_info(m04_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m04_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m04_nodes_M_SC_W_RECV),
        .M_SC_W_req(m04_nodes_M_SC_W_REQ),
        .M_SC_W_send(m04_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_6_INFO),
        .S_SC_AR_payld(S_SC_AR_6_PAYLD),
        .S_SC_AR_recv(S_SC_AR_6_RECV),
        .S_SC_AR_req(S_SC_AR_6_REQ),
        .S_SC_AR_send(S_SC_AR_6_SEND),
        .S_SC_AW_info(S_SC_AW_6_INFO),
        .S_SC_AW_payld(S_SC_AW_6_PAYLD),
        .S_SC_AW_recv(S_SC_AW_6_RECV),
        .S_SC_AW_req(S_SC_AW_6_REQ),
        .S_SC_AW_send(S_SC_AW_6_SEND),
        .S_SC_B_info(S_SC_B_6_INFO),
        .S_SC_B_payld(S_SC_B_6_PAYLD),
        .S_SC_B_recv(S_SC_B_6_RECV),
        .S_SC_B_req(S_SC_B_6_REQ),
        .S_SC_B_send(S_SC_B_6_SEND),
        .S_SC_R_info(S_SC_R_6_INFO),
        .S_SC_R_payld(S_SC_R_6_PAYLD),
        .S_SC_R_recv(S_SC_R_6_RECV),
        .S_SC_R_req(S_SC_R_6_REQ),
        .S_SC_R_send(S_SC_R_6_SEND),
        .S_SC_W_info(S_SC_W_6_INFO),
        .S_SC_W_payld(S_SC_W_6_PAYLD),
        .S_SC_W_recv(S_SC_W_6_RECV),
        .S_SC_W_req(S_SC_W_6_REQ),
        .S_SC_W_send(S_SC_W_6_SEND),
        .m_axi_aclk(clk_map_M04_ACLK),
        .m_axi_aresetn(m_axi_aresetn_5),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m04s2a_0 m04_sc2axi
       (.aclk(clk_map_M04_ACLK),
        .m_axi_araddr(m04_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m04_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m04_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m04_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m04_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m04_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m04_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m04_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m04_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m04_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m04_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m04_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m04_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m04_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m04_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m04_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m04_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m04_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m04_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m04_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m04_sc2axi_M_AXI_BID),
        .m_axi_bready(m04_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m04_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m04_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m04_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m04_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m04_sc2axi_M_AXI_RID),
        .m_axi_rlast(m04_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m04_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m04_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m04_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m04_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m04_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m04_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m04_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m04_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m04_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m04_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_6_INFO),
        .m_sc_b_payld(S_SC_B_6_PAYLD),
        .m_sc_b_recv(S_SC_B_6_RECV),
        .m_sc_b_req(S_SC_B_6_REQ),
        .m_sc_b_send(S_SC_B_6_SEND),
        .m_sc_r_info(S_SC_R_6_INFO),
        .m_sc_r_payld(S_SC_R_6_PAYLD),
        .m_sc_r_recv(S_SC_R_6_RECV),
        .m_sc_r_req(S_SC_R_6_REQ),
        .m_sc_r_send(S_SC_R_6_SEND),
        .s_sc_ar_info(m04_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m04_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m04_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m04_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m04_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m04_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m04_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m04_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m04_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m04_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m04_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m04_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m04_nodes_M_SC_W_RECV),
        .s_sc_w_req(m04_nodes_M_SC_W_REQ),
        .s_sc_w_send(m04_nodes_M_SC_W_SEND));
  m05_exit_pipeline_imp_1GCDYRQ m05_exit_pipeline
       (.aclk(clk_map_M05_ACLK),
        .aresetn(m_axi_aresetn_6),
        .m_axi_araddr(M05_AXI_araddr),
        .m_axi_arburst(M05_AXI_arburst),
        .m_axi_arcache(M05_AXI_arcache),
        .m_axi_arlen(M05_AXI_arlen),
        .m_axi_arlock(M05_AXI_arlock),
        .m_axi_arprot(M05_AXI_arprot),
        .m_axi_arqos(M05_AXI_arqos),
        .m_axi_arready(M05_AXI_arready),
        .m_axi_arsize(M05_AXI_arsize),
        .m_axi_arvalid(M05_AXI_arvalid),
        .m_axi_awaddr(M05_AXI_awaddr),
        .m_axi_awburst(M05_AXI_awburst),
        .m_axi_awcache(M05_AXI_awcache),
        .m_axi_awlen(M05_AXI_awlen),
        .m_axi_awlock(M05_AXI_awlock),
        .m_axi_awprot(M05_AXI_awprot),
        .m_axi_awqos(M05_AXI_awqos),
        .m_axi_awready(M05_AXI_awready),
        .m_axi_awsize(M05_AXI_awsize),
        .m_axi_awvalid(M05_AXI_awvalid),
        .m_axi_bready(M05_AXI_bready),
        .m_axi_bresp(M05_AXI_bresp),
        .m_axi_bvalid(M05_AXI_bvalid),
        .m_axi_rdata(M05_AXI_rdata),
        .m_axi_rlast(M05_AXI_rlast),
        .m_axi_rready(M05_AXI_rready),
        .m_axi_rresp(M05_AXI_rresp),
        .m_axi_rvalid(M05_AXI_rvalid),
        .m_axi_wdata(M05_AXI_wdata),
        .m_axi_wlast(M05_AXI_wlast),
        .m_axi_wready(M05_AXI_wready),
        .m_axi_wstrb(M05_AXI_wstrb),
        .m_axi_wvalid(M05_AXI_wvalid),
        .s_axi_araddr(m05_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m05_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m05_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m05_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m05_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m05_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m05_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m05_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m05_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m05_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m05_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m05_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m05_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m05_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m05_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m05_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m05_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m05_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m05_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m05_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m05_sc2axi_M_AXI_BID),
        .s_axi_bready(m05_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m05_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m05_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m05_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m05_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m05_sc2axi_M_AXI_RID),
        .s_axi_rlast(m05_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m05_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m05_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m05_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m05_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m05_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m05_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m05_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m05_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m05_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m05_sc2axi_M_AXI_WVALID));
  m05_nodes_imp_9WTXAF m05_nodes
       (.M_SC_AR_info(m05_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m05_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m05_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m05_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m05_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m05_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m05_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m05_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m05_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m05_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m05_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m05_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m05_nodes_M_SC_B_RECV),
        .M_SC_B_req(m05_nodes_M_SC_B_REQ),
        .M_SC_B_send(m05_nodes_M_SC_B_SEND),
        .M_SC_R_info(m05_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m05_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m05_nodes_M_SC_R_RECV),
        .M_SC_R_req(m05_nodes_M_SC_R_REQ),
        .M_SC_R_send(m05_nodes_M_SC_R_SEND),
        .M_SC_W_info(m05_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m05_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m05_nodes_M_SC_W_RECV),
        .M_SC_W_req(m05_nodes_M_SC_W_REQ),
        .M_SC_W_send(m05_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_7_INFO),
        .S_SC_AR_payld(S_SC_AR_7_PAYLD),
        .S_SC_AR_recv(S_SC_AR_7_RECV),
        .S_SC_AR_req(S_SC_AR_7_REQ),
        .S_SC_AR_send(S_SC_AR_7_SEND),
        .S_SC_AW_info(S_SC_AW_7_INFO),
        .S_SC_AW_payld(S_SC_AW_7_PAYLD),
        .S_SC_AW_recv(S_SC_AW_7_RECV),
        .S_SC_AW_req(S_SC_AW_7_REQ),
        .S_SC_AW_send(S_SC_AW_7_SEND),
        .S_SC_B_info(S_SC_B_7_INFO),
        .S_SC_B_payld(S_SC_B_7_PAYLD),
        .S_SC_B_recv(S_SC_B_7_RECV),
        .S_SC_B_req(S_SC_B_7_REQ),
        .S_SC_B_send(S_SC_B_7_SEND),
        .S_SC_R_info(S_SC_R_7_INFO),
        .S_SC_R_payld(S_SC_R_7_PAYLD),
        .S_SC_R_recv(S_SC_R_7_RECV),
        .S_SC_R_req(S_SC_R_7_REQ),
        .S_SC_R_send(S_SC_R_7_SEND),
        .S_SC_W_info(S_SC_W_7_INFO),
        .S_SC_W_payld(S_SC_W_7_PAYLD),
        .S_SC_W_recv(S_SC_W_7_RECV),
        .S_SC_W_req(S_SC_W_7_REQ),
        .S_SC_W_send(S_SC_W_7_SEND),
        .m_axi_aclk(clk_map_M05_ACLK),
        .m_axi_aresetn(m_axi_aresetn_6),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m05s2a_0 m05_sc2axi
       (.aclk(clk_map_M05_ACLK),
        .m_axi_araddr(m05_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m05_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m05_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m05_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m05_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m05_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m05_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m05_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m05_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m05_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m05_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m05_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m05_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m05_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m05_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m05_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m05_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m05_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m05_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m05_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m05_sc2axi_M_AXI_BID),
        .m_axi_bready(m05_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m05_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m05_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m05_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m05_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m05_sc2axi_M_AXI_RID),
        .m_axi_rlast(m05_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m05_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m05_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m05_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m05_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m05_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m05_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m05_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m05_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m05_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m05_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_7_INFO),
        .m_sc_b_payld(S_SC_B_7_PAYLD),
        .m_sc_b_recv(S_SC_B_7_RECV),
        .m_sc_b_req(S_SC_B_7_REQ),
        .m_sc_b_send(S_SC_B_7_SEND),
        .m_sc_r_info(S_SC_R_7_INFO),
        .m_sc_r_payld(S_SC_R_7_PAYLD),
        .m_sc_r_recv(S_SC_R_7_RECV),
        .m_sc_r_req(S_SC_R_7_REQ),
        .m_sc_r_send(S_SC_R_7_SEND),
        .s_sc_ar_info(m05_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m05_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m05_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m05_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m05_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m05_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m05_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m05_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m05_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m05_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m05_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m05_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m05_nodes_M_SC_W_RECV),
        .s_sc_w_req(m05_nodes_M_SC_W_REQ),
        .s_sc_w_send(m05_nodes_M_SC_W_SEND));
  m06_exit_pipeline_imp_1156CXY m06_exit_pipeline
       (.aclk(clk_map_M06_ACLK),
        .aresetn(m_axi_aresetn_7),
        .m_axi_araddr(M06_AXI_araddr),
        .m_axi_arburst(M06_AXI_arburst),
        .m_axi_arcache(M06_AXI_arcache),
        .m_axi_arlen(M06_AXI_arlen),
        .m_axi_arlock(M06_AXI_arlock),
        .m_axi_arprot(M06_AXI_arprot),
        .m_axi_arqos(M06_AXI_arqos),
        .m_axi_arready(M06_AXI_arready),
        .m_axi_arsize(M06_AXI_arsize),
        .m_axi_arvalid(M06_AXI_arvalid),
        .m_axi_awaddr(M06_AXI_awaddr),
        .m_axi_awburst(M06_AXI_awburst),
        .m_axi_awcache(M06_AXI_awcache),
        .m_axi_awlen(M06_AXI_awlen),
        .m_axi_awlock(M06_AXI_awlock),
        .m_axi_awprot(M06_AXI_awprot),
        .m_axi_awqos(M06_AXI_awqos),
        .m_axi_awready(M06_AXI_awready),
        .m_axi_awsize(M06_AXI_awsize),
        .m_axi_awvalid(M06_AXI_awvalid),
        .m_axi_bready(M06_AXI_bready),
        .m_axi_bresp(M06_AXI_bresp),
        .m_axi_bvalid(M06_AXI_bvalid),
        .m_axi_rdata(M06_AXI_rdata),
        .m_axi_rlast(M06_AXI_rlast),
        .m_axi_rready(M06_AXI_rready),
        .m_axi_rresp(M06_AXI_rresp),
        .m_axi_rvalid(M06_AXI_rvalid),
        .m_axi_wdata(M06_AXI_wdata),
        .m_axi_wlast(M06_AXI_wlast),
        .m_axi_wready(M06_AXI_wready),
        .m_axi_wstrb(M06_AXI_wstrb),
        .m_axi_wvalid(M06_AXI_wvalid),
        .s_axi_araddr(m06_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m06_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m06_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m06_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m06_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m06_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m06_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m06_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m06_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m06_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m06_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m06_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m06_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m06_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m06_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m06_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m06_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m06_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m06_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m06_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m06_sc2axi_M_AXI_BID),
        .s_axi_bready(m06_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m06_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m06_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m06_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m06_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m06_sc2axi_M_AXI_RID),
        .s_axi_rlast(m06_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m06_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m06_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m06_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m06_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m06_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m06_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m06_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m06_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m06_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m06_sc2axi_M_AXI_WVALID));
  m06_nodes_imp_QLCXZW m06_nodes
       (.M_SC_AR_info(m06_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m06_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m06_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m06_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m06_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m06_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m06_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m06_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m06_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m06_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m06_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m06_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m06_nodes_M_SC_B_RECV),
        .M_SC_B_req(m06_nodes_M_SC_B_REQ),
        .M_SC_B_send(m06_nodes_M_SC_B_SEND),
        .M_SC_R_info(m06_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m06_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m06_nodes_M_SC_R_RECV),
        .M_SC_R_req(m06_nodes_M_SC_R_REQ),
        .M_SC_R_send(m06_nodes_M_SC_R_SEND),
        .M_SC_W_info(m06_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m06_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m06_nodes_M_SC_W_RECV),
        .M_SC_W_req(m06_nodes_M_SC_W_REQ),
        .M_SC_W_send(m06_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_8_INFO),
        .S_SC_AR_payld(S_SC_AR_8_PAYLD),
        .S_SC_AR_recv(S_SC_AR_8_RECV),
        .S_SC_AR_req(S_SC_AR_8_REQ),
        .S_SC_AR_send(S_SC_AR_8_SEND),
        .S_SC_AW_info(S_SC_AW_8_INFO),
        .S_SC_AW_payld(S_SC_AW_8_PAYLD),
        .S_SC_AW_recv(S_SC_AW_8_RECV),
        .S_SC_AW_req(S_SC_AW_8_REQ),
        .S_SC_AW_send(S_SC_AW_8_SEND),
        .S_SC_B_info(S_SC_B_8_INFO),
        .S_SC_B_payld(S_SC_B_8_PAYLD),
        .S_SC_B_recv(S_SC_B_8_RECV),
        .S_SC_B_req(S_SC_B_8_REQ),
        .S_SC_B_send(S_SC_B_8_SEND),
        .S_SC_R_info(S_SC_R_8_INFO),
        .S_SC_R_payld(S_SC_R_8_PAYLD),
        .S_SC_R_recv(S_SC_R_8_RECV),
        .S_SC_R_req(S_SC_R_8_REQ),
        .S_SC_R_send(S_SC_R_8_SEND),
        .S_SC_W_info(S_SC_W_8_INFO),
        .S_SC_W_payld(S_SC_W_8_PAYLD),
        .S_SC_W_recv(S_SC_W_8_RECV),
        .S_SC_W_req(S_SC_W_8_REQ),
        .S_SC_W_send(S_SC_W_8_SEND),
        .m_axi_aclk(clk_map_M06_ACLK),
        .m_axi_aresetn(m_axi_aresetn_7),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m06s2a_0 m06_sc2axi
       (.aclk(clk_map_M06_ACLK),
        .m_axi_araddr(m06_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m06_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m06_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m06_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m06_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m06_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m06_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m06_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m06_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m06_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m06_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m06_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m06_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m06_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m06_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m06_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m06_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m06_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m06_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m06_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m06_sc2axi_M_AXI_BID),
        .m_axi_bready(m06_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m06_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m06_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m06_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m06_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m06_sc2axi_M_AXI_RID),
        .m_axi_rlast(m06_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m06_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m06_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m06_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m06_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m06_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m06_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m06_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m06_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m06_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m06_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_8_INFO),
        .m_sc_b_payld(S_SC_B_8_PAYLD),
        .m_sc_b_recv(S_SC_B_8_RECV),
        .m_sc_b_req(S_SC_B_8_REQ),
        .m_sc_b_send(S_SC_B_8_SEND),
        .m_sc_r_info(S_SC_R_8_INFO),
        .m_sc_r_payld(S_SC_R_8_PAYLD),
        .m_sc_r_recv(S_SC_R_8_RECV),
        .m_sc_r_req(S_SC_R_8_REQ),
        .m_sc_r_send(S_SC_R_8_SEND),
        .s_sc_ar_info(m06_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m06_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m06_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m06_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m06_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m06_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m06_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m06_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m06_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m06_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m06_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m06_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m06_nodes_M_SC_W_RECV),
        .s_sc_w_req(m06_nodes_M_SC_W_REQ),
        .s_sc_w_send(m06_nodes_M_SC_W_SEND));
  m07_exit_pipeline_imp_14RYAIU m07_exit_pipeline
       (.aclk(clk_map_M07_ACLK),
        .aresetn(m_axi_aresetn_8),
        .m_axi_araddr(M07_AXI_araddr),
        .m_axi_arburst(M07_AXI_arburst),
        .m_axi_arcache(M07_AXI_arcache),
        .m_axi_arlen(M07_AXI_arlen),
        .m_axi_arlock(M07_AXI_arlock),
        .m_axi_arprot(M07_AXI_arprot),
        .m_axi_arqos(M07_AXI_arqos),
        .m_axi_arready(M07_AXI_arready),
        .m_axi_arsize(M07_AXI_arsize),
        .m_axi_arvalid(M07_AXI_arvalid),
        .m_axi_awaddr(M07_AXI_awaddr),
        .m_axi_awburst(M07_AXI_awburst),
        .m_axi_awcache(M07_AXI_awcache),
        .m_axi_awlen(M07_AXI_awlen),
        .m_axi_awlock(M07_AXI_awlock),
        .m_axi_awprot(M07_AXI_awprot),
        .m_axi_awqos(M07_AXI_awqos),
        .m_axi_awready(M07_AXI_awready),
        .m_axi_awsize(M07_AXI_awsize),
        .m_axi_awvalid(M07_AXI_awvalid),
        .m_axi_bready(M07_AXI_bready),
        .m_axi_bresp(M07_AXI_bresp),
        .m_axi_bvalid(M07_AXI_bvalid),
        .m_axi_rdata(M07_AXI_rdata),
        .m_axi_rlast(M07_AXI_rlast),
        .m_axi_rready(M07_AXI_rready),
        .m_axi_rresp(M07_AXI_rresp),
        .m_axi_rvalid(M07_AXI_rvalid),
        .m_axi_wdata(M07_AXI_wdata),
        .m_axi_wlast(M07_AXI_wlast),
        .m_axi_wready(M07_AXI_wready),
        .m_axi_wstrb(M07_AXI_wstrb),
        .m_axi_wvalid(M07_AXI_wvalid),
        .s_axi_araddr(m07_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m07_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m07_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m07_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m07_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m07_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m07_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m07_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m07_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m07_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m07_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m07_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m07_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m07_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m07_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m07_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m07_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m07_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m07_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m07_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m07_sc2axi_M_AXI_BID),
        .s_axi_bready(m07_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m07_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m07_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m07_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m07_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m07_sc2axi_M_AXI_RID),
        .s_axi_rlast(m07_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m07_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m07_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m07_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m07_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m07_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m07_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m07_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m07_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m07_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m07_sc2axi_M_AXI_WVALID));
  m07_nodes_imp_1I28KTM m07_nodes
       (.M_SC_AR_info(m07_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m07_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m07_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m07_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m07_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m07_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m07_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m07_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m07_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m07_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m07_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m07_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m07_nodes_M_SC_B_RECV),
        .M_SC_B_req(m07_nodes_M_SC_B_REQ),
        .M_SC_B_send(m07_nodes_M_SC_B_SEND),
        .M_SC_R_info(m07_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m07_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m07_nodes_M_SC_R_RECV),
        .M_SC_R_req(m07_nodes_M_SC_R_REQ),
        .M_SC_R_send(m07_nodes_M_SC_R_SEND),
        .M_SC_W_info(m07_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m07_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m07_nodes_M_SC_W_RECV),
        .M_SC_W_req(m07_nodes_M_SC_W_REQ),
        .M_SC_W_send(m07_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_9_INFO),
        .S_SC_AR_payld(S_SC_AR_9_PAYLD),
        .S_SC_AR_recv(S_SC_AR_9_RECV),
        .S_SC_AR_req(S_SC_AR_9_REQ),
        .S_SC_AR_send(S_SC_AR_9_SEND),
        .S_SC_AW_info(S_SC_AW_9_INFO),
        .S_SC_AW_payld(S_SC_AW_9_PAYLD),
        .S_SC_AW_recv(S_SC_AW_9_RECV),
        .S_SC_AW_req(S_SC_AW_9_REQ),
        .S_SC_AW_send(S_SC_AW_9_SEND),
        .S_SC_B_info(S_SC_B_9_INFO),
        .S_SC_B_payld(S_SC_B_9_PAYLD),
        .S_SC_B_recv(S_SC_B_9_RECV),
        .S_SC_B_req(S_SC_B_9_REQ),
        .S_SC_B_send(S_SC_B_9_SEND),
        .S_SC_R_info(S_SC_R_9_INFO),
        .S_SC_R_payld(S_SC_R_9_PAYLD),
        .S_SC_R_recv(S_SC_R_9_RECV),
        .S_SC_R_req(S_SC_R_9_REQ),
        .S_SC_R_send(S_SC_R_9_SEND),
        .S_SC_W_info(S_SC_W_9_INFO),
        .S_SC_W_payld(S_SC_W_9_PAYLD),
        .S_SC_W_recv(S_SC_W_9_RECV),
        .S_SC_W_req(S_SC_W_9_REQ),
        .S_SC_W_send(S_SC_W_9_SEND),
        .m_axi_aclk(clk_map_M07_ACLK),
        .m_axi_aresetn(m_axi_aresetn_8),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m07s2a_0 m07_sc2axi
       (.aclk(clk_map_M07_ACLK),
        .m_axi_araddr(m07_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m07_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m07_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m07_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m07_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m07_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m07_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m07_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m07_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m07_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m07_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m07_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m07_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m07_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m07_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m07_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m07_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m07_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m07_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m07_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m07_sc2axi_M_AXI_BID),
        .m_axi_bready(m07_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m07_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m07_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m07_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m07_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m07_sc2axi_M_AXI_RID),
        .m_axi_rlast(m07_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m07_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m07_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m07_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m07_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m07_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m07_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m07_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m07_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m07_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m07_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_9_INFO),
        .m_sc_b_payld(S_SC_B_9_PAYLD),
        .m_sc_b_recv(S_SC_B_9_RECV),
        .m_sc_b_req(S_SC_B_9_REQ),
        .m_sc_b_send(S_SC_B_9_SEND),
        .m_sc_r_info(S_SC_R_9_INFO),
        .m_sc_r_payld(S_SC_R_9_PAYLD),
        .m_sc_r_recv(S_SC_R_9_RECV),
        .m_sc_r_req(S_SC_R_9_REQ),
        .m_sc_r_send(S_SC_R_9_SEND),
        .s_sc_ar_info(m07_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m07_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m07_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m07_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m07_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m07_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m07_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m07_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m07_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m07_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m07_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m07_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m07_nodes_M_SC_W_RECV),
        .s_sc_w_req(m07_nodes_M_SC_W_REQ),
        .s_sc_w_send(m07_nodes_M_SC_W_SEND));
  m08_exit_pipeline_imp_LRC6TI m08_exit_pipeline
       (.aclk(clk_map_M08_ACLK),
        .aresetn(m_axi_aresetn_9),
        .m_axi_araddr(M08_AXI_araddr),
        .m_axi_arburst(M08_AXI_arburst),
        .m_axi_arcache(M08_AXI_arcache),
        .m_axi_arlen(M08_AXI_arlen),
        .m_axi_arlock(M08_AXI_arlock),
        .m_axi_arprot(M08_AXI_arprot),
        .m_axi_arqos(M08_AXI_arqos),
        .m_axi_arready(M08_AXI_arready),
        .m_axi_arsize(M08_AXI_arsize),
        .m_axi_arvalid(M08_AXI_arvalid),
        .m_axi_awaddr(M08_AXI_awaddr),
        .m_axi_awburst(M08_AXI_awburst),
        .m_axi_awcache(M08_AXI_awcache),
        .m_axi_awlen(M08_AXI_awlen),
        .m_axi_awlock(M08_AXI_awlock),
        .m_axi_awprot(M08_AXI_awprot),
        .m_axi_awqos(M08_AXI_awqos),
        .m_axi_awready(M08_AXI_awready),
        .m_axi_awsize(M08_AXI_awsize),
        .m_axi_awvalid(M08_AXI_awvalid),
        .m_axi_bready(M08_AXI_bready),
        .m_axi_bresp(M08_AXI_bresp),
        .m_axi_bvalid(M08_AXI_bvalid),
        .m_axi_rdata(M08_AXI_rdata),
        .m_axi_rlast(M08_AXI_rlast),
        .m_axi_rready(M08_AXI_rready),
        .m_axi_rresp(M08_AXI_rresp),
        .m_axi_rvalid(M08_AXI_rvalid),
        .m_axi_wdata(M08_AXI_wdata),
        .m_axi_wlast(M08_AXI_wlast),
        .m_axi_wready(M08_AXI_wready),
        .m_axi_wstrb(M08_AXI_wstrb),
        .m_axi_wvalid(M08_AXI_wvalid),
        .s_axi_araddr(m08_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m08_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m08_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m08_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m08_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m08_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m08_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m08_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m08_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m08_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m08_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m08_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m08_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m08_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m08_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m08_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m08_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m08_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m08_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m08_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m08_sc2axi_M_AXI_BID),
        .s_axi_bready(m08_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m08_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m08_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m08_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m08_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m08_sc2axi_M_AXI_RID),
        .s_axi_rlast(m08_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m08_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m08_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m08_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m08_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m08_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m08_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m08_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m08_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m08_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m08_sc2axi_M_AXI_WVALID));
  m08_nodes_imp_154YDNG m08_nodes
       (.M_SC_AR_info(m08_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m08_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m08_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m08_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m08_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m08_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m08_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m08_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m08_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m08_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m08_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m08_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m08_nodes_M_SC_B_RECV),
        .M_SC_B_req(m08_nodes_M_SC_B_REQ),
        .M_SC_B_send(m08_nodes_M_SC_B_SEND),
        .M_SC_R_info(m08_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m08_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m08_nodes_M_SC_R_RECV),
        .M_SC_R_req(m08_nodes_M_SC_R_REQ),
        .M_SC_R_send(m08_nodes_M_SC_R_SEND),
        .M_SC_W_info(m08_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m08_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m08_nodes_M_SC_W_RECV),
        .M_SC_W_req(m08_nodes_M_SC_W_REQ),
        .M_SC_W_send(m08_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_10_INFO),
        .S_SC_AR_payld(S_SC_AR_10_PAYLD),
        .S_SC_AR_recv(S_SC_AR_10_RECV),
        .S_SC_AR_req(S_SC_AR_10_REQ),
        .S_SC_AR_send(S_SC_AR_10_SEND),
        .S_SC_AW_info(S_SC_AW_10_INFO),
        .S_SC_AW_payld(S_SC_AW_10_PAYLD),
        .S_SC_AW_recv(S_SC_AW_10_RECV),
        .S_SC_AW_req(S_SC_AW_10_REQ),
        .S_SC_AW_send(S_SC_AW_10_SEND),
        .S_SC_B_info(S_SC_B_10_INFO),
        .S_SC_B_payld(S_SC_B_10_PAYLD),
        .S_SC_B_recv(S_SC_B_10_RECV),
        .S_SC_B_req(S_SC_B_10_REQ),
        .S_SC_B_send(S_SC_B_10_SEND),
        .S_SC_R_info(S_SC_R_10_INFO),
        .S_SC_R_payld(S_SC_R_10_PAYLD),
        .S_SC_R_recv(S_SC_R_10_RECV),
        .S_SC_R_req(S_SC_R_10_REQ),
        .S_SC_R_send(S_SC_R_10_SEND),
        .S_SC_W_info(S_SC_W_10_INFO),
        .S_SC_W_payld(S_SC_W_10_PAYLD),
        .S_SC_W_recv(S_SC_W_10_RECV),
        .S_SC_W_req(S_SC_W_10_REQ),
        .S_SC_W_send(S_SC_W_10_SEND),
        .m_axi_aclk(clk_map_M08_ACLK),
        .m_axi_aresetn(m_axi_aresetn_9),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m08s2a_0 m08_sc2axi
       (.aclk(clk_map_M08_ACLK),
        .m_axi_araddr(m08_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m08_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m08_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m08_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m08_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m08_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m08_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m08_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m08_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m08_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m08_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m08_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m08_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m08_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m08_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m08_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m08_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m08_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m08_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m08_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m08_sc2axi_M_AXI_BID),
        .m_axi_bready(m08_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m08_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m08_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m08_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m08_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m08_sc2axi_M_AXI_RID),
        .m_axi_rlast(m08_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m08_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m08_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m08_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m08_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m08_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m08_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m08_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m08_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m08_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m08_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_10_INFO),
        .m_sc_b_payld(S_SC_B_10_PAYLD),
        .m_sc_b_recv(S_SC_B_10_RECV),
        .m_sc_b_req(S_SC_B_10_REQ),
        .m_sc_b_send(S_SC_B_10_SEND),
        .m_sc_r_info(S_SC_R_10_INFO),
        .m_sc_r_payld(S_SC_R_10_PAYLD),
        .m_sc_r_recv(S_SC_R_10_RECV),
        .m_sc_r_req(S_SC_R_10_REQ),
        .m_sc_r_send(S_SC_R_10_SEND),
        .s_sc_ar_info(m08_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m08_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m08_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m08_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m08_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m08_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m08_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m08_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m08_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m08_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m08_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m08_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m08_nodes_M_SC_W_RECV),
        .s_sc_w_req(m08_nodes_M_SC_W_REQ),
        .s_sc_w_send(m08_nodes_M_SC_W_SEND));
  m09_exit_pipeline_imp_ORO1FQ m09_exit_pipeline
       (.aclk(clk_map_M09_ACLK),
        .aresetn(m_axi_aresetn_10),
        .m_axi_araddr(M09_AXI_araddr),
        .m_axi_arburst(M09_AXI_arburst),
        .m_axi_arcache(M09_AXI_arcache),
        .m_axi_arlen(M09_AXI_arlen),
        .m_axi_arlock(M09_AXI_arlock),
        .m_axi_arprot(M09_AXI_arprot),
        .m_axi_arqos(M09_AXI_arqos),
        .m_axi_arready(M09_AXI_arready),
        .m_axi_arsize(M09_AXI_arsize),
        .m_axi_arvalid(M09_AXI_arvalid),
        .m_axi_awaddr(M09_AXI_awaddr),
        .m_axi_awburst(M09_AXI_awburst),
        .m_axi_awcache(M09_AXI_awcache),
        .m_axi_awlen(M09_AXI_awlen),
        .m_axi_awlock(M09_AXI_awlock),
        .m_axi_awprot(M09_AXI_awprot),
        .m_axi_awqos(M09_AXI_awqos),
        .m_axi_awready(M09_AXI_awready),
        .m_axi_awsize(M09_AXI_awsize),
        .m_axi_awvalid(M09_AXI_awvalid),
        .m_axi_bready(M09_AXI_bready),
        .m_axi_bresp(M09_AXI_bresp),
        .m_axi_bvalid(M09_AXI_bvalid),
        .m_axi_rdata(M09_AXI_rdata),
        .m_axi_rlast(M09_AXI_rlast),
        .m_axi_rready(M09_AXI_rready),
        .m_axi_rresp(M09_AXI_rresp),
        .m_axi_rvalid(M09_AXI_rvalid),
        .m_axi_wdata(M09_AXI_wdata),
        .m_axi_wlast(M09_AXI_wlast),
        .m_axi_wready(M09_AXI_wready),
        .m_axi_wstrb(M09_AXI_wstrb),
        .m_axi_wvalid(M09_AXI_wvalid),
        .s_axi_araddr(m09_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m09_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m09_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m09_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m09_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m09_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m09_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m09_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m09_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m09_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m09_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m09_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m09_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m09_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m09_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m09_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m09_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m09_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m09_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m09_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m09_sc2axi_M_AXI_BID),
        .s_axi_bready(m09_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m09_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m09_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m09_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m09_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m09_sc2axi_M_AXI_RID),
        .s_axi_rlast(m09_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m09_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m09_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m09_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m09_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m09_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m09_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m09_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m09_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m09_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m09_sc2axi_M_AXI_WVALID));
  m09_nodes_imp_2KVZE2 m09_nodes
       (.M_SC_AR_info(m09_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m09_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m09_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m09_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m09_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m09_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m09_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m09_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m09_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m09_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m09_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m09_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m09_nodes_M_SC_B_RECV),
        .M_SC_B_req(m09_nodes_M_SC_B_REQ),
        .M_SC_B_send(m09_nodes_M_SC_B_SEND),
        .M_SC_R_info(m09_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m09_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m09_nodes_M_SC_R_RECV),
        .M_SC_R_req(m09_nodes_M_SC_R_REQ),
        .M_SC_R_send(m09_nodes_M_SC_R_SEND),
        .M_SC_W_info(m09_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m09_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m09_nodes_M_SC_W_RECV),
        .M_SC_W_req(m09_nodes_M_SC_W_REQ),
        .M_SC_W_send(m09_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_11_INFO),
        .S_SC_AR_payld(S_SC_AR_11_PAYLD),
        .S_SC_AR_recv(S_SC_AR_11_RECV),
        .S_SC_AR_req(S_SC_AR_11_REQ),
        .S_SC_AR_send(S_SC_AR_11_SEND),
        .S_SC_AW_info(S_SC_AW_11_INFO),
        .S_SC_AW_payld(S_SC_AW_11_PAYLD),
        .S_SC_AW_recv(S_SC_AW_11_RECV),
        .S_SC_AW_req(S_SC_AW_11_REQ),
        .S_SC_AW_send(S_SC_AW_11_SEND),
        .S_SC_B_info(S_SC_B_11_INFO),
        .S_SC_B_payld(S_SC_B_11_PAYLD),
        .S_SC_B_recv(S_SC_B_11_RECV),
        .S_SC_B_req(S_SC_B_11_REQ),
        .S_SC_B_send(S_SC_B_11_SEND),
        .S_SC_R_info(S_SC_R_11_INFO),
        .S_SC_R_payld(S_SC_R_11_PAYLD),
        .S_SC_R_recv(S_SC_R_11_RECV),
        .S_SC_R_req(S_SC_R_11_REQ),
        .S_SC_R_send(S_SC_R_11_SEND),
        .S_SC_W_info(S_SC_W_11_INFO),
        .S_SC_W_payld(S_SC_W_11_PAYLD),
        .S_SC_W_recv(S_SC_W_11_RECV),
        .S_SC_W_req(S_SC_W_11_REQ),
        .S_SC_W_send(S_SC_W_11_SEND),
        .m_axi_aclk(clk_map_M09_ACLK),
        .m_axi_aresetn(m_axi_aresetn_10),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m09s2a_0 m09_sc2axi
       (.aclk(clk_map_M09_ACLK),
        .m_axi_araddr(m09_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m09_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m09_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m09_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m09_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m09_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m09_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m09_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m09_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m09_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m09_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m09_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m09_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m09_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m09_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m09_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m09_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m09_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m09_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m09_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m09_sc2axi_M_AXI_BID),
        .m_axi_bready(m09_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m09_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m09_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m09_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m09_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m09_sc2axi_M_AXI_RID),
        .m_axi_rlast(m09_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m09_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m09_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m09_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m09_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m09_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m09_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m09_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m09_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m09_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m09_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_11_INFO),
        .m_sc_b_payld(S_SC_B_11_PAYLD),
        .m_sc_b_recv(S_SC_B_11_RECV),
        .m_sc_b_req(S_SC_B_11_REQ),
        .m_sc_b_send(S_SC_B_11_SEND),
        .m_sc_r_info(S_SC_R_11_INFO),
        .m_sc_r_payld(S_SC_R_11_PAYLD),
        .m_sc_r_recv(S_SC_R_11_RECV),
        .m_sc_r_req(S_SC_R_11_REQ),
        .m_sc_r_send(S_SC_R_11_SEND),
        .s_sc_ar_info(m09_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m09_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m09_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m09_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m09_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m09_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m09_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m09_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m09_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m09_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m09_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m09_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m09_nodes_M_SC_W_RECV),
        .s_sc_w_req(m09_nodes_M_SC_W_REQ),
        .s_sc_w_send(m09_nodes_M_SC_W_SEND));
  m10_exit_pipeline_imp_U2EIQA m10_exit_pipeline
       (.aclk(clk_map_M10_ACLK),
        .aresetn(m_axi_aresetn_11),
        .m_axi_araddr(M10_AXI_araddr),
        .m_axi_arburst(M10_AXI_arburst),
        .m_axi_arcache(M10_AXI_arcache),
        .m_axi_arlen(M10_AXI_arlen),
        .m_axi_arlock(M10_AXI_arlock),
        .m_axi_arprot(M10_AXI_arprot),
        .m_axi_arqos(M10_AXI_arqos),
        .m_axi_arready(M10_AXI_arready),
        .m_axi_arsize(M10_AXI_arsize),
        .m_axi_arvalid(M10_AXI_arvalid),
        .m_axi_awaddr(M10_AXI_awaddr),
        .m_axi_awburst(M10_AXI_awburst),
        .m_axi_awcache(M10_AXI_awcache),
        .m_axi_awlen(M10_AXI_awlen),
        .m_axi_awlock(M10_AXI_awlock),
        .m_axi_awprot(M10_AXI_awprot),
        .m_axi_awqos(M10_AXI_awqos),
        .m_axi_awready(M10_AXI_awready),
        .m_axi_awsize(M10_AXI_awsize),
        .m_axi_awvalid(M10_AXI_awvalid),
        .m_axi_bready(M10_AXI_bready),
        .m_axi_bresp(M10_AXI_bresp),
        .m_axi_bvalid(M10_AXI_bvalid),
        .m_axi_rdata(M10_AXI_rdata),
        .m_axi_rlast(M10_AXI_rlast),
        .m_axi_rready(M10_AXI_rready),
        .m_axi_rresp(M10_AXI_rresp),
        .m_axi_rvalid(M10_AXI_rvalid),
        .m_axi_wdata(M10_AXI_wdata),
        .m_axi_wlast(M10_AXI_wlast),
        .m_axi_wready(M10_AXI_wready),
        .m_axi_wstrb(M10_AXI_wstrb),
        .m_axi_wvalid(M10_AXI_wvalid),
        .s_axi_araddr(m10_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m10_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m10_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m10_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m10_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m10_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m10_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m10_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m10_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m10_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m10_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m10_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m10_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m10_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m10_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m10_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m10_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m10_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m10_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m10_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m10_sc2axi_M_AXI_BID),
        .s_axi_bready(m10_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m10_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m10_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m10_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m10_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m10_sc2axi_M_AXI_RID),
        .s_axi_rlast(m10_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m10_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m10_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m10_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m10_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m10_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m10_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m10_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m10_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m10_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m10_sc2axi_M_AXI_WVALID));
  m10_nodes_imp_8KGLDU m10_nodes
       (.M_SC_AR_info(m10_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m10_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m10_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m10_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m10_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m10_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m10_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m10_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m10_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m10_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m10_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m10_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m10_nodes_M_SC_B_RECV),
        .M_SC_B_req(m10_nodes_M_SC_B_REQ),
        .M_SC_B_send(m10_nodes_M_SC_B_SEND),
        .M_SC_R_info(m10_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m10_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m10_nodes_M_SC_R_RECV),
        .M_SC_R_req(m10_nodes_M_SC_R_REQ),
        .M_SC_R_send(m10_nodes_M_SC_R_SEND),
        .M_SC_W_info(m10_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m10_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m10_nodes_M_SC_W_RECV),
        .M_SC_W_req(m10_nodes_M_SC_W_REQ),
        .M_SC_W_send(m10_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_12_INFO),
        .S_SC_AR_payld(S_SC_AR_12_PAYLD),
        .S_SC_AR_recv(S_SC_AR_12_RECV),
        .S_SC_AR_req(S_SC_AR_12_REQ),
        .S_SC_AR_send(S_SC_AR_12_SEND),
        .S_SC_AW_info(S_SC_AW_12_INFO),
        .S_SC_AW_payld(S_SC_AW_12_PAYLD),
        .S_SC_AW_recv(S_SC_AW_12_RECV),
        .S_SC_AW_req(S_SC_AW_12_REQ),
        .S_SC_AW_send(S_SC_AW_12_SEND),
        .S_SC_B_info(S_SC_B_12_INFO),
        .S_SC_B_payld(S_SC_B_12_PAYLD),
        .S_SC_B_recv(S_SC_B_12_RECV),
        .S_SC_B_req(S_SC_B_12_REQ),
        .S_SC_B_send(S_SC_B_12_SEND),
        .S_SC_R_info(S_SC_R_12_INFO),
        .S_SC_R_payld(S_SC_R_12_PAYLD),
        .S_SC_R_recv(S_SC_R_12_RECV),
        .S_SC_R_req(S_SC_R_12_REQ),
        .S_SC_R_send(S_SC_R_12_SEND),
        .S_SC_W_info(S_SC_W_12_INFO),
        .S_SC_W_payld(S_SC_W_12_PAYLD),
        .S_SC_W_recv(S_SC_W_12_RECV),
        .S_SC_W_req(S_SC_W_12_REQ),
        .S_SC_W_send(S_SC_W_12_SEND),
        .m_axi_aclk(clk_map_M10_ACLK),
        .m_axi_aresetn(m_axi_aresetn_11),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m10s2a_0 m10_sc2axi
       (.aclk(clk_map_M10_ACLK),
        .m_axi_araddr(m10_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m10_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m10_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m10_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m10_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m10_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m10_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m10_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m10_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m10_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m10_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m10_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m10_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m10_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m10_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m10_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m10_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m10_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m10_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m10_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m10_sc2axi_M_AXI_BID),
        .m_axi_bready(m10_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m10_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m10_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m10_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m10_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m10_sc2axi_M_AXI_RID),
        .m_axi_rlast(m10_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m10_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m10_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m10_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m10_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m10_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m10_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m10_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m10_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m10_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m10_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_12_INFO),
        .m_sc_b_payld(S_SC_B_12_PAYLD),
        .m_sc_b_recv(S_SC_B_12_RECV),
        .m_sc_b_req(S_SC_B_12_REQ),
        .m_sc_b_send(S_SC_B_12_SEND),
        .m_sc_r_info(S_SC_R_12_INFO),
        .m_sc_r_payld(S_SC_R_12_PAYLD),
        .m_sc_r_recv(S_SC_R_12_RECV),
        .m_sc_r_req(S_SC_R_12_REQ),
        .m_sc_r_send(S_SC_R_12_SEND),
        .s_sc_ar_info(m10_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m10_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m10_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m10_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m10_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m10_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m10_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m10_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m10_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m10_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m10_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m10_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m10_nodes_M_SC_W_RECV),
        .s_sc_w_req(m10_nodes_M_SC_W_REQ),
        .s_sc_w_send(m10_nodes_M_SC_W_SEND));
  m11_exit_pipeline_imp_Y95ZMA m11_exit_pipeline
       (.aclk(clk_map_M11_ACLK),
        .aresetn(m_axi_aresetn_12),
        .m_axi_araddr(M11_AXI_araddr),
        .m_axi_arburst(M11_AXI_arburst),
        .m_axi_arcache(M11_AXI_arcache),
        .m_axi_arlen(M11_AXI_arlen),
        .m_axi_arlock(M11_AXI_arlock),
        .m_axi_arprot(M11_AXI_arprot),
        .m_axi_arqos(M11_AXI_arqos),
        .m_axi_arready(M11_AXI_arready),
        .m_axi_arsize(M11_AXI_arsize),
        .m_axi_arvalid(M11_AXI_arvalid),
        .m_axi_awaddr(M11_AXI_awaddr),
        .m_axi_awburst(M11_AXI_awburst),
        .m_axi_awcache(M11_AXI_awcache),
        .m_axi_awlen(M11_AXI_awlen),
        .m_axi_awlock(M11_AXI_awlock),
        .m_axi_awprot(M11_AXI_awprot),
        .m_axi_awqos(M11_AXI_awqos),
        .m_axi_awready(M11_AXI_awready),
        .m_axi_awsize(M11_AXI_awsize),
        .m_axi_awvalid(M11_AXI_awvalid),
        .m_axi_bready(M11_AXI_bready),
        .m_axi_bresp(M11_AXI_bresp),
        .m_axi_bvalid(M11_AXI_bvalid),
        .m_axi_rdata(M11_AXI_rdata),
        .m_axi_rlast(M11_AXI_rlast),
        .m_axi_rready(M11_AXI_rready),
        .m_axi_rresp(M11_AXI_rresp),
        .m_axi_rvalid(M11_AXI_rvalid),
        .m_axi_wdata(M11_AXI_wdata),
        .m_axi_wlast(M11_AXI_wlast),
        .m_axi_wready(M11_AXI_wready),
        .m_axi_wstrb(M11_AXI_wstrb),
        .m_axi_wvalid(M11_AXI_wvalid),
        .s_axi_araddr(m11_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m11_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m11_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m11_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m11_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m11_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m11_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m11_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m11_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m11_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m11_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m11_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m11_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m11_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m11_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m11_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m11_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m11_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m11_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m11_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m11_sc2axi_M_AXI_BID),
        .s_axi_bready(m11_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m11_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m11_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m11_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m11_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m11_sc2axi_M_AXI_RID),
        .s_axi_rlast(m11_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m11_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m11_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m11_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m11_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m11_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m11_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m11_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m11_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m11_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m11_sc2axi_M_AXI_WVALID));
  m11_nodes_imp_10LTOAC m11_nodes
       (.M_SC_AR_info(m11_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m11_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m11_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m11_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m11_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m11_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m11_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m11_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m11_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m11_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m11_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m11_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m11_nodes_M_SC_B_RECV),
        .M_SC_B_req(m11_nodes_M_SC_B_REQ),
        .M_SC_B_send(m11_nodes_M_SC_B_SEND),
        .M_SC_R_info(m11_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m11_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m11_nodes_M_SC_R_RECV),
        .M_SC_R_req(m11_nodes_M_SC_R_REQ),
        .M_SC_R_send(m11_nodes_M_SC_R_SEND),
        .M_SC_W_info(m11_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m11_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m11_nodes_M_SC_W_RECV),
        .M_SC_W_req(m11_nodes_M_SC_W_REQ),
        .M_SC_W_send(m11_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_13_INFO),
        .S_SC_AR_payld(S_SC_AR_13_PAYLD),
        .S_SC_AR_recv(S_SC_AR_13_RECV),
        .S_SC_AR_req(S_SC_AR_13_REQ),
        .S_SC_AR_send(S_SC_AR_13_SEND),
        .S_SC_AW_info(S_SC_AW_13_INFO),
        .S_SC_AW_payld(S_SC_AW_13_PAYLD),
        .S_SC_AW_recv(S_SC_AW_13_RECV),
        .S_SC_AW_req(S_SC_AW_13_REQ),
        .S_SC_AW_send(S_SC_AW_13_SEND),
        .S_SC_B_info(S_SC_B_13_INFO),
        .S_SC_B_payld(S_SC_B_13_PAYLD),
        .S_SC_B_recv(S_SC_B_13_RECV),
        .S_SC_B_req(S_SC_B_13_REQ),
        .S_SC_B_send(S_SC_B_13_SEND),
        .S_SC_R_info(S_SC_R_13_INFO),
        .S_SC_R_payld(S_SC_R_13_PAYLD),
        .S_SC_R_recv(S_SC_R_13_RECV),
        .S_SC_R_req(S_SC_R_13_REQ),
        .S_SC_R_send(S_SC_R_13_SEND),
        .S_SC_W_info(S_SC_W_13_INFO),
        .S_SC_W_payld(S_SC_W_13_PAYLD),
        .S_SC_W_recv(S_SC_W_13_RECV),
        .S_SC_W_req(S_SC_W_13_REQ),
        .S_SC_W_send(S_SC_W_13_SEND),
        .m_axi_aclk(clk_map_M11_ACLK),
        .m_axi_aresetn(m_axi_aresetn_12),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m11s2a_0 m11_sc2axi
       (.aclk(clk_map_M11_ACLK),
        .m_axi_araddr(m11_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m11_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m11_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m11_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m11_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m11_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m11_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m11_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m11_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m11_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m11_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m11_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m11_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m11_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m11_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m11_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m11_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m11_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m11_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m11_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m11_sc2axi_M_AXI_BID),
        .m_axi_bready(m11_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m11_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m11_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m11_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m11_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m11_sc2axi_M_AXI_RID),
        .m_axi_rlast(m11_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m11_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m11_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m11_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m11_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m11_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m11_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m11_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m11_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m11_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m11_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_13_INFO),
        .m_sc_b_payld(S_SC_B_13_PAYLD),
        .m_sc_b_recv(S_SC_B_13_RECV),
        .m_sc_b_req(S_SC_B_13_REQ),
        .m_sc_b_send(S_SC_B_13_SEND),
        .m_sc_r_info(S_SC_R_13_INFO),
        .m_sc_r_payld(S_SC_R_13_PAYLD),
        .m_sc_r_recv(S_SC_R_13_RECV),
        .m_sc_r_req(S_SC_R_13_REQ),
        .m_sc_r_send(S_SC_R_13_SEND),
        .s_sc_ar_info(m11_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m11_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m11_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m11_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m11_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m11_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m11_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m11_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m11_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m11_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m11_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m11_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m11_nodes_M_SC_W_RECV),
        .s_sc_w_req(m11_nodes_M_SC_W_REQ),
        .s_sc_w_send(m11_nodes_M_SC_W_SEND));
  m12_exit_pipeline_imp_IBQ76A m12_exit_pipeline
       (.aclk(clk_map_M12_ACLK),
        .aresetn(m_axi_aresetn_13),
        .m_axi_araddr(M12_AXI_araddr),
        .m_axi_arburst(M12_AXI_arburst),
        .m_axi_arcache(M12_AXI_arcache),
        .m_axi_arlen(M12_AXI_arlen),
        .m_axi_arlock(M12_AXI_arlock),
        .m_axi_arprot(M12_AXI_arprot),
        .m_axi_arqos(M12_AXI_arqos),
        .m_axi_arready(M12_AXI_arready),
        .m_axi_arsize(M12_AXI_arsize),
        .m_axi_arvalid(M12_AXI_arvalid),
        .m_axi_awaddr(M12_AXI_awaddr),
        .m_axi_awburst(M12_AXI_awburst),
        .m_axi_awcache(M12_AXI_awcache),
        .m_axi_awlen(M12_AXI_awlen),
        .m_axi_awlock(M12_AXI_awlock),
        .m_axi_awprot(M12_AXI_awprot),
        .m_axi_awqos(M12_AXI_awqos),
        .m_axi_awready(M12_AXI_awready),
        .m_axi_awsize(M12_AXI_awsize),
        .m_axi_awvalid(M12_AXI_awvalid),
        .m_axi_bready(M12_AXI_bready),
        .m_axi_bresp(M12_AXI_bresp),
        .m_axi_bvalid(M12_AXI_bvalid),
        .m_axi_rdata(M12_AXI_rdata),
        .m_axi_rlast(M12_AXI_rlast),
        .m_axi_rready(M12_AXI_rready),
        .m_axi_rresp(M12_AXI_rresp),
        .m_axi_rvalid(M12_AXI_rvalid),
        .m_axi_wdata(M12_AXI_wdata),
        .m_axi_wlast(M12_AXI_wlast),
        .m_axi_wready(M12_AXI_wready),
        .m_axi_wstrb(M12_AXI_wstrb),
        .m_axi_wvalid(M12_AXI_wvalid),
        .s_axi_araddr(m12_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m12_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m12_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m12_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m12_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m12_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m12_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m12_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m12_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m12_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m12_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m12_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m12_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m12_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m12_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m12_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m12_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m12_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m12_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m12_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m12_sc2axi_M_AXI_BID),
        .s_axi_bready(m12_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m12_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m12_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m12_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m12_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m12_sc2axi_M_AXI_RID),
        .s_axi_rlast(m12_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m12_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m12_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m12_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m12_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m12_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m12_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m12_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m12_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m12_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m12_sc2axi_M_AXI_WVALID));
  m12_nodes_imp_1YWPOMN m12_nodes
       (.M_SC_AR_info(m12_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m12_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m12_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m12_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m12_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m12_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m12_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m12_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m12_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m12_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m12_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m12_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m12_nodes_M_SC_B_RECV),
        .M_SC_B_req(m12_nodes_M_SC_B_REQ),
        .M_SC_B_send(m12_nodes_M_SC_B_SEND),
        .M_SC_R_info(m12_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m12_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m12_nodes_M_SC_R_RECV),
        .M_SC_R_req(m12_nodes_M_SC_R_REQ),
        .M_SC_R_send(m12_nodes_M_SC_R_SEND),
        .M_SC_W_info(m12_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m12_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m12_nodes_M_SC_W_RECV),
        .M_SC_W_req(m12_nodes_M_SC_W_REQ),
        .M_SC_W_send(m12_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_14_INFO),
        .S_SC_AR_payld(S_SC_AR_14_PAYLD),
        .S_SC_AR_recv(S_SC_AR_14_RECV),
        .S_SC_AR_req(S_SC_AR_14_REQ),
        .S_SC_AR_send(S_SC_AR_14_SEND),
        .S_SC_AW_info(S_SC_AW_14_INFO),
        .S_SC_AW_payld(S_SC_AW_14_PAYLD),
        .S_SC_AW_recv(S_SC_AW_14_RECV),
        .S_SC_AW_req(S_SC_AW_14_REQ),
        .S_SC_AW_send(S_SC_AW_14_SEND),
        .S_SC_B_info(S_SC_B_14_INFO),
        .S_SC_B_payld(S_SC_B_14_PAYLD),
        .S_SC_B_recv(S_SC_B_14_RECV),
        .S_SC_B_req(S_SC_B_14_REQ),
        .S_SC_B_send(S_SC_B_14_SEND),
        .S_SC_R_info(S_SC_R_14_INFO),
        .S_SC_R_payld(S_SC_R_14_PAYLD),
        .S_SC_R_recv(S_SC_R_14_RECV),
        .S_SC_R_req(S_SC_R_14_REQ),
        .S_SC_R_send(S_SC_R_14_SEND),
        .S_SC_W_info(S_SC_W_14_INFO),
        .S_SC_W_payld(S_SC_W_14_PAYLD),
        .S_SC_W_recv(S_SC_W_14_RECV),
        .S_SC_W_req(S_SC_W_14_REQ),
        .S_SC_W_send(S_SC_W_14_SEND),
        .m_axi_aclk(clk_map_M12_ACLK),
        .m_axi_aresetn(m_axi_aresetn_13),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m12s2a_0 m12_sc2axi
       (.aclk(clk_map_M12_ACLK),
        .m_axi_araddr(m12_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m12_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m12_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m12_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m12_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m12_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m12_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m12_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m12_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m12_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m12_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m12_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m12_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m12_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m12_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m12_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m12_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m12_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m12_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m12_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m12_sc2axi_M_AXI_BID),
        .m_axi_bready(m12_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m12_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m12_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m12_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m12_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m12_sc2axi_M_AXI_RID),
        .m_axi_rlast(m12_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m12_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m12_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m12_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m12_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m12_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m12_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m12_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m12_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m12_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m12_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_14_INFO),
        .m_sc_b_payld(S_SC_B_14_PAYLD),
        .m_sc_b_recv(S_SC_B_14_RECV),
        .m_sc_b_req(S_SC_B_14_REQ),
        .m_sc_b_send(S_SC_B_14_SEND),
        .m_sc_r_info(S_SC_R_14_INFO),
        .m_sc_r_payld(S_SC_R_14_PAYLD),
        .m_sc_r_recv(S_SC_R_14_RECV),
        .m_sc_r_req(S_SC_R_14_REQ),
        .m_sc_r_send(S_SC_R_14_SEND),
        .s_sc_ar_info(m12_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m12_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m12_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m12_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m12_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m12_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m12_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m12_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m12_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m12_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m12_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m12_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m12_nodes_M_SC_W_RECV),
        .s_sc_w_req(m12_nodes_M_SC_W_REQ),
        .s_sc_w_send(m12_nodes_M_SC_W_SEND));
  m13_exit_pipeline_imp_NMGQOI m13_exit_pipeline
       (.aclk(clk_map_M13_ACLK),
        .aresetn(m_axi_aresetn_14),
        .m_axi_araddr(M13_AXI_araddr),
        .m_axi_arburst(M13_AXI_arburst),
        .m_axi_arcache(M13_AXI_arcache),
        .m_axi_arlen(M13_AXI_arlen),
        .m_axi_arlock(M13_AXI_arlock),
        .m_axi_arprot(M13_AXI_arprot),
        .m_axi_arqos(M13_AXI_arqos),
        .m_axi_arready(M13_AXI_arready),
        .m_axi_arsize(M13_AXI_arsize),
        .m_axi_arvalid(M13_AXI_arvalid),
        .m_axi_awaddr(M13_AXI_awaddr),
        .m_axi_awburst(M13_AXI_awburst),
        .m_axi_awcache(M13_AXI_awcache),
        .m_axi_awlen(M13_AXI_awlen),
        .m_axi_awlock(M13_AXI_awlock),
        .m_axi_awprot(M13_AXI_awprot),
        .m_axi_awqos(M13_AXI_awqos),
        .m_axi_awready(M13_AXI_awready),
        .m_axi_awsize(M13_AXI_awsize),
        .m_axi_awvalid(M13_AXI_awvalid),
        .m_axi_bready(M13_AXI_bready),
        .m_axi_bresp(M13_AXI_bresp),
        .m_axi_bvalid(M13_AXI_bvalid),
        .m_axi_rdata(M13_AXI_rdata),
        .m_axi_rlast(M13_AXI_rlast),
        .m_axi_rready(M13_AXI_rready),
        .m_axi_rresp(M13_AXI_rresp),
        .m_axi_rvalid(M13_AXI_rvalid),
        .m_axi_wdata(M13_AXI_wdata),
        .m_axi_wlast(M13_AXI_wlast),
        .m_axi_wready(M13_AXI_wready),
        .m_axi_wstrb(M13_AXI_wstrb),
        .m_axi_wvalid(M13_AXI_wvalid),
        .s_axi_araddr(m13_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m13_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m13_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m13_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m13_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m13_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m13_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m13_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m13_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m13_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m13_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m13_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m13_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m13_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m13_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m13_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m13_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m13_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m13_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m13_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m13_sc2axi_M_AXI_BID),
        .s_axi_bready(m13_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m13_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m13_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m13_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m13_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m13_sc2axi_M_AXI_RID),
        .s_axi_rlast(m13_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m13_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m13_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m13_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m13_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m13_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m13_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m13_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m13_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m13_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m13_sc2axi_M_AXI_WVALID));
  m13_nodes_imp_RBWW49 m13_nodes
       (.M_SC_AR_info(m13_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m13_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m13_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m13_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m13_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m13_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m13_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m13_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m13_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m13_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m13_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m13_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m13_nodes_M_SC_B_RECV),
        .M_SC_B_req(m13_nodes_M_SC_B_REQ),
        .M_SC_B_send(m13_nodes_M_SC_B_SEND),
        .M_SC_R_info(m13_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m13_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m13_nodes_M_SC_R_RECV),
        .M_SC_R_req(m13_nodes_M_SC_R_REQ),
        .M_SC_R_send(m13_nodes_M_SC_R_SEND),
        .M_SC_W_info(m13_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m13_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m13_nodes_M_SC_W_RECV),
        .M_SC_W_req(m13_nodes_M_SC_W_REQ),
        .M_SC_W_send(m13_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_15_INFO),
        .S_SC_AR_payld(S_SC_AR_15_PAYLD),
        .S_SC_AR_recv(S_SC_AR_15_RECV),
        .S_SC_AR_req(S_SC_AR_15_REQ),
        .S_SC_AR_send(S_SC_AR_15_SEND),
        .S_SC_AW_info(S_SC_AW_15_INFO),
        .S_SC_AW_payld(S_SC_AW_15_PAYLD),
        .S_SC_AW_recv(S_SC_AW_15_RECV),
        .S_SC_AW_req(S_SC_AW_15_REQ),
        .S_SC_AW_send(S_SC_AW_15_SEND),
        .S_SC_B_info(S_SC_B_15_INFO),
        .S_SC_B_payld(S_SC_B_15_PAYLD),
        .S_SC_B_recv(S_SC_B_15_RECV),
        .S_SC_B_req(S_SC_B_15_REQ),
        .S_SC_B_send(S_SC_B_15_SEND),
        .S_SC_R_info(S_SC_R_15_INFO),
        .S_SC_R_payld(S_SC_R_15_PAYLD),
        .S_SC_R_recv(S_SC_R_15_RECV),
        .S_SC_R_req(S_SC_R_15_REQ),
        .S_SC_R_send(S_SC_R_15_SEND),
        .S_SC_W_info(S_SC_W_15_INFO),
        .S_SC_W_payld(S_SC_W_15_PAYLD),
        .S_SC_W_recv(S_SC_W_15_RECV),
        .S_SC_W_req(S_SC_W_15_REQ),
        .S_SC_W_send(S_SC_W_15_SEND),
        .m_axi_aclk(clk_map_M13_ACLK),
        .m_axi_aresetn(m_axi_aresetn_14),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m13s2a_0 m13_sc2axi
       (.aclk(clk_map_M13_ACLK),
        .m_axi_araddr(m13_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m13_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m13_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m13_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m13_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m13_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m13_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m13_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m13_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m13_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m13_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m13_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m13_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m13_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m13_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m13_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m13_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m13_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m13_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m13_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m13_sc2axi_M_AXI_BID),
        .m_axi_bready(m13_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m13_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m13_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m13_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m13_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m13_sc2axi_M_AXI_RID),
        .m_axi_rlast(m13_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m13_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m13_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m13_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m13_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m13_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m13_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m13_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m13_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m13_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m13_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_15_INFO),
        .m_sc_b_payld(S_SC_B_15_PAYLD),
        .m_sc_b_recv(S_SC_B_15_RECV),
        .m_sc_b_req(S_SC_B_15_REQ),
        .m_sc_b_send(S_SC_B_15_SEND),
        .m_sc_r_info(S_SC_R_15_INFO),
        .m_sc_r_payld(S_SC_R_15_PAYLD),
        .m_sc_r_recv(S_SC_R_15_RECV),
        .m_sc_r_req(S_SC_R_15_REQ),
        .m_sc_r_send(S_SC_R_15_SEND),
        .s_sc_ar_info(m13_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m13_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m13_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m13_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m13_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m13_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m13_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m13_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m13_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m13_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m13_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m13_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m13_nodes_M_SC_W_RECV),
        .s_sc_w_req(m13_nodes_M_SC_W_REQ),
        .s_sc_w_send(m13_nodes_M_SC_W_SEND));
  m14_exit_pipeline_imp_DLC9CI m14_exit_pipeline
       (.aclk(clk_map_M14_ACLK),
        .aresetn(m_axi_aresetn_15),
        .m_axi_araddr(M14_AXI_araddr),
        .m_axi_arburst(M14_AXI_arburst),
        .m_axi_arcache(M14_AXI_arcache),
        .m_axi_arlen(M14_AXI_arlen),
        .m_axi_arlock(M14_AXI_arlock),
        .m_axi_arprot(M14_AXI_arprot),
        .m_axi_arqos(M14_AXI_arqos),
        .m_axi_arready(M14_AXI_arready),
        .m_axi_arsize(M14_AXI_arsize),
        .m_axi_arvalid(M14_AXI_arvalid),
        .m_axi_awaddr(M14_AXI_awaddr),
        .m_axi_awburst(M14_AXI_awburst),
        .m_axi_awcache(M14_AXI_awcache),
        .m_axi_awlen(M14_AXI_awlen),
        .m_axi_awlock(M14_AXI_awlock),
        .m_axi_awprot(M14_AXI_awprot),
        .m_axi_awqos(M14_AXI_awqos),
        .m_axi_awready(M14_AXI_awready),
        .m_axi_awsize(M14_AXI_awsize),
        .m_axi_awvalid(M14_AXI_awvalid),
        .m_axi_bready(M14_AXI_bready),
        .m_axi_bresp(M14_AXI_bresp),
        .m_axi_bvalid(M14_AXI_bvalid),
        .m_axi_rdata(M14_AXI_rdata),
        .m_axi_rlast(M14_AXI_rlast),
        .m_axi_rready(M14_AXI_rready),
        .m_axi_rresp(M14_AXI_rresp),
        .m_axi_rvalid(M14_AXI_rvalid),
        .m_axi_wdata(M14_AXI_wdata),
        .m_axi_wlast(M14_AXI_wlast),
        .m_axi_wready(M14_AXI_wready),
        .m_axi_wstrb(M14_AXI_wstrb),
        .m_axi_wvalid(M14_AXI_wvalid),
        .s_axi_araddr(m14_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m14_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m14_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m14_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m14_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m14_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m14_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m14_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m14_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m14_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m14_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m14_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m14_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m14_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m14_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m14_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m14_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m14_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m14_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m14_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m14_sc2axi_M_AXI_BID),
        .s_axi_bready(m14_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m14_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m14_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m14_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m14_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m14_sc2axi_M_AXI_RID),
        .s_axi_rlast(m14_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m14_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m14_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m14_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m14_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m14_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m14_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m14_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m14_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m14_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m14_sc2axi_M_AXI_WVALID));
  m14_nodes_imp_20XDND m14_nodes
       (.M_SC_AR_info(m14_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m14_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m14_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m14_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m14_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m14_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m14_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m14_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m14_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m14_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m14_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m14_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m14_nodes_M_SC_B_RECV),
        .M_SC_B_req(m14_nodes_M_SC_B_REQ),
        .M_SC_B_send(m14_nodes_M_SC_B_SEND),
        .M_SC_R_info(m14_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m14_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m14_nodes_M_SC_R_RECV),
        .M_SC_R_req(m14_nodes_M_SC_R_REQ),
        .M_SC_R_send(m14_nodes_M_SC_R_SEND),
        .M_SC_W_info(m14_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m14_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m14_nodes_M_SC_W_RECV),
        .M_SC_W_req(m14_nodes_M_SC_W_REQ),
        .M_SC_W_send(m14_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_16_INFO),
        .S_SC_AR_payld(S_SC_AR_16_PAYLD),
        .S_SC_AR_recv(S_SC_AR_16_RECV),
        .S_SC_AR_req(S_SC_AR_16_REQ),
        .S_SC_AR_send(S_SC_AR_16_SEND),
        .S_SC_AW_info(S_SC_AW_16_INFO),
        .S_SC_AW_payld(S_SC_AW_16_PAYLD),
        .S_SC_AW_recv(S_SC_AW_16_RECV),
        .S_SC_AW_req(S_SC_AW_16_REQ),
        .S_SC_AW_send(S_SC_AW_16_SEND),
        .S_SC_B_info(S_SC_B_16_INFO),
        .S_SC_B_payld(S_SC_B_16_PAYLD),
        .S_SC_B_recv(S_SC_B_16_RECV),
        .S_SC_B_req(S_SC_B_16_REQ),
        .S_SC_B_send(S_SC_B_16_SEND),
        .S_SC_R_info(S_SC_R_16_INFO),
        .S_SC_R_payld(S_SC_R_16_PAYLD),
        .S_SC_R_recv(S_SC_R_16_RECV),
        .S_SC_R_req(S_SC_R_16_REQ),
        .S_SC_R_send(S_SC_R_16_SEND),
        .S_SC_W_info(S_SC_W_16_INFO),
        .S_SC_W_payld(S_SC_W_16_PAYLD),
        .S_SC_W_recv(S_SC_W_16_RECV),
        .S_SC_W_req(S_SC_W_16_REQ),
        .S_SC_W_send(S_SC_W_16_SEND),
        .m_axi_aclk(clk_map_M14_ACLK),
        .m_axi_aresetn(m_axi_aresetn_15),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m14s2a_0 m14_sc2axi
       (.aclk(clk_map_M14_ACLK),
        .m_axi_araddr(m14_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m14_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m14_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m14_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m14_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m14_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m14_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m14_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m14_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m14_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m14_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m14_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m14_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m14_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m14_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m14_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m14_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m14_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m14_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m14_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m14_sc2axi_M_AXI_BID),
        .m_axi_bready(m14_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m14_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m14_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m14_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m14_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m14_sc2axi_M_AXI_RID),
        .m_axi_rlast(m14_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m14_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m14_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m14_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m14_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m14_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m14_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m14_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m14_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m14_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m14_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_16_INFO),
        .m_sc_b_payld(S_SC_B_16_PAYLD),
        .m_sc_b_recv(S_SC_B_16_RECV),
        .m_sc_b_req(S_SC_B_16_REQ),
        .m_sc_b_send(S_SC_B_16_SEND),
        .m_sc_r_info(S_SC_R_16_INFO),
        .m_sc_r_payld(S_SC_R_16_PAYLD),
        .m_sc_r_recv(S_SC_R_16_RECV),
        .m_sc_r_req(S_SC_R_16_REQ),
        .m_sc_r_send(S_SC_R_16_SEND),
        .s_sc_ar_info(m14_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m14_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m14_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m14_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m14_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m14_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m14_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m14_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m14_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m14_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m14_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m14_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m14_nodes_M_SC_W_RECV),
        .s_sc_w_req(m14_nodes_M_SC_W_REQ),
        .s_sc_w_send(m14_nodes_M_SC_W_SEND));
  m15_exit_pipeline_imp_B1VKPE m15_exit_pipeline
       (.aclk(clk_map_M15_ACLK),
        .aresetn(m_axi_aresetn_16),
        .m_axi_araddr(M15_AXI_araddr),
        .m_axi_arburst(M15_AXI_arburst),
        .m_axi_arcache(M15_AXI_arcache),
        .m_axi_arlen(M15_AXI_arlen),
        .m_axi_arlock(M15_AXI_arlock),
        .m_axi_arprot(M15_AXI_arprot),
        .m_axi_arqos(M15_AXI_arqos),
        .m_axi_arready(M15_AXI_arready),
        .m_axi_arsize(M15_AXI_arsize),
        .m_axi_arvalid(M15_AXI_arvalid),
        .m_axi_awaddr(M15_AXI_awaddr),
        .m_axi_awburst(M15_AXI_awburst),
        .m_axi_awcache(M15_AXI_awcache),
        .m_axi_awlen(M15_AXI_awlen),
        .m_axi_awlock(M15_AXI_awlock),
        .m_axi_awprot(M15_AXI_awprot),
        .m_axi_awqos(M15_AXI_awqos),
        .m_axi_awready(M15_AXI_awready),
        .m_axi_awsize(M15_AXI_awsize),
        .m_axi_awvalid(M15_AXI_awvalid),
        .m_axi_bready(M15_AXI_bready),
        .m_axi_bresp(M15_AXI_bresp),
        .m_axi_bvalid(M15_AXI_bvalid),
        .m_axi_rdata(M15_AXI_rdata),
        .m_axi_rlast(M15_AXI_rlast),
        .m_axi_rready(M15_AXI_rready),
        .m_axi_rresp(M15_AXI_rresp),
        .m_axi_rvalid(M15_AXI_rvalid),
        .m_axi_wdata(M15_AXI_wdata),
        .m_axi_wlast(M15_AXI_wlast),
        .m_axi_wready(M15_AXI_wready),
        .m_axi_wstrb(M15_AXI_wstrb),
        .m_axi_wvalid(M15_AXI_wvalid),
        .s_axi_araddr(m15_sc2axi_M_AXI_ARADDR),
        .s_axi_arcache(m15_sc2axi_M_AXI_ARCACHE),
        .s_axi_arid(m15_sc2axi_M_AXI_ARID),
        .s_axi_arlen(m15_sc2axi_M_AXI_ARLEN),
        .s_axi_arlock(m15_sc2axi_M_AXI_ARLOCK),
        .s_axi_arprot(m15_sc2axi_M_AXI_ARPROT),
        .s_axi_arqos(m15_sc2axi_M_AXI_ARQOS),
        .s_axi_arready(m15_sc2axi_M_AXI_ARREADY),
        .s_axi_aruser(m15_sc2axi_M_AXI_ARUSER),
        .s_axi_arvalid(m15_sc2axi_M_AXI_ARVALID),
        .s_axi_awaddr(m15_sc2axi_M_AXI_AWADDR),
        .s_axi_awcache(m15_sc2axi_M_AXI_AWCACHE),
        .s_axi_awid(m15_sc2axi_M_AXI_AWID),
        .s_axi_awlen(m15_sc2axi_M_AXI_AWLEN),
        .s_axi_awlock(m15_sc2axi_M_AXI_AWLOCK),
        .s_axi_awprot(m15_sc2axi_M_AXI_AWPROT),
        .s_axi_awqos(m15_sc2axi_M_AXI_AWQOS),
        .s_axi_awready(m15_sc2axi_M_AXI_AWREADY),
        .s_axi_awuser(m15_sc2axi_M_AXI_AWUSER),
        .s_axi_awvalid(m15_sc2axi_M_AXI_AWVALID),
        .s_axi_bid(m15_sc2axi_M_AXI_BID),
        .s_axi_bready(m15_sc2axi_M_AXI_BREADY),
        .s_axi_bresp(m15_sc2axi_M_AXI_BRESP),
        .s_axi_buser(m15_sc2axi_M_AXI_BUSER),
        .s_axi_bvalid(m15_sc2axi_M_AXI_BVALID),
        .s_axi_rdata(m15_sc2axi_M_AXI_RDATA),
        .s_axi_rid(m15_sc2axi_M_AXI_RID),
        .s_axi_rlast(m15_sc2axi_M_AXI_RLAST),
        .s_axi_rready(m15_sc2axi_M_AXI_RREADY),
        .s_axi_rresp(m15_sc2axi_M_AXI_RRESP),
        .s_axi_ruser(m15_sc2axi_M_AXI_RUSER),
        .s_axi_rvalid(m15_sc2axi_M_AXI_RVALID),
        .s_axi_wdata(m15_sc2axi_M_AXI_WDATA),
        .s_axi_wlast(m15_sc2axi_M_AXI_WLAST),
        .s_axi_wready(m15_sc2axi_M_AXI_WREADY),
        .s_axi_wstrb(m15_sc2axi_M_AXI_WSTRB),
        .s_axi_wuser(m15_sc2axi_M_AXI_WUSER),
        .s_axi_wvalid(m15_sc2axi_M_AXI_WVALID));
  m15_nodes_imp_16SVGOF m15_nodes
       (.M_SC_AR_info(m15_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(m15_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(m15_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(m15_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(m15_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(m15_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(m15_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(m15_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(m15_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(m15_nodes_M_SC_AW_SEND),
        .M_SC_B_info(m15_nodes_M_SC_B_INFO),
        .M_SC_B_payld(m15_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(m15_nodes_M_SC_B_RECV),
        .M_SC_B_req(m15_nodes_M_SC_B_REQ),
        .M_SC_B_send(m15_nodes_M_SC_B_SEND),
        .M_SC_R_info(m15_nodes_M_SC_R_INFO),
        .M_SC_R_payld(m15_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(m15_nodes_M_SC_R_RECV),
        .M_SC_R_req(m15_nodes_M_SC_R_REQ),
        .M_SC_R_send(m15_nodes_M_SC_R_SEND),
        .M_SC_W_info(m15_nodes_M_SC_W_INFO),
        .M_SC_W_payld(m15_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(m15_nodes_M_SC_W_RECV),
        .M_SC_W_req(m15_nodes_M_SC_W_REQ),
        .M_SC_W_send(m15_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_17_INFO),
        .S_SC_AR_payld(S_SC_AR_17_PAYLD),
        .S_SC_AR_recv(S_SC_AR_17_RECV),
        .S_SC_AR_req(S_SC_AR_17_REQ),
        .S_SC_AR_send(S_SC_AR_17_SEND),
        .S_SC_AW_info(S_SC_AW_17_INFO),
        .S_SC_AW_payld(S_SC_AW_17_PAYLD),
        .S_SC_AW_recv(S_SC_AW_17_RECV),
        .S_SC_AW_req(S_SC_AW_17_REQ),
        .S_SC_AW_send(S_SC_AW_17_SEND),
        .S_SC_B_info(S_SC_B_17_INFO),
        .S_SC_B_payld(S_SC_B_17_PAYLD),
        .S_SC_B_recv(S_SC_B_17_RECV),
        .S_SC_B_req(S_SC_B_17_REQ),
        .S_SC_B_send(S_SC_B_17_SEND),
        .S_SC_R_info(S_SC_R_17_INFO),
        .S_SC_R_payld(S_SC_R_17_PAYLD),
        .S_SC_R_recv(S_SC_R_17_RECV),
        .S_SC_R_req(S_SC_R_17_REQ),
        .S_SC_R_send(S_SC_R_17_SEND),
        .S_SC_W_info(S_SC_W_17_INFO),
        .S_SC_W_payld(S_SC_W_17_PAYLD),
        .S_SC_W_recv(S_SC_W_17_RECV),
        .S_SC_W_req(S_SC_W_17_REQ),
        .S_SC_W_send(S_SC_W_17_SEND),
        .m_axi_aclk(clk_map_M15_ACLK),
        .m_axi_aresetn(m_axi_aresetn_16),
        .s_axi_aclk(swbd_aclk_net),
        .s_axi_aresetn(swbd_aresetn_net));
  bd_87e8_m15s2a_0 m15_sc2axi
       (.aclk(clk_map_M15_ACLK),
        .m_axi_araddr(m15_sc2axi_M_AXI_ARADDR),
        .m_axi_arcache(m15_sc2axi_M_AXI_ARCACHE),
        .m_axi_arid(m15_sc2axi_M_AXI_ARID),
        .m_axi_arlen(m15_sc2axi_M_AXI_ARLEN),
        .m_axi_arlock(m15_sc2axi_M_AXI_ARLOCK),
        .m_axi_arprot(m15_sc2axi_M_AXI_ARPROT),
        .m_axi_arqos(m15_sc2axi_M_AXI_ARQOS),
        .m_axi_arready(m15_sc2axi_M_AXI_ARREADY),
        .m_axi_aruser(m15_sc2axi_M_AXI_ARUSER),
        .m_axi_arvalid(m15_sc2axi_M_AXI_ARVALID),
        .m_axi_awaddr(m15_sc2axi_M_AXI_AWADDR),
        .m_axi_awcache(m15_sc2axi_M_AXI_AWCACHE),
        .m_axi_awid(m15_sc2axi_M_AXI_AWID),
        .m_axi_awlen(m15_sc2axi_M_AXI_AWLEN),
        .m_axi_awlock(m15_sc2axi_M_AXI_AWLOCK),
        .m_axi_awprot(m15_sc2axi_M_AXI_AWPROT),
        .m_axi_awqos(m15_sc2axi_M_AXI_AWQOS),
        .m_axi_awready(m15_sc2axi_M_AXI_AWREADY),
        .m_axi_awuser(m15_sc2axi_M_AXI_AWUSER),
        .m_axi_awvalid(m15_sc2axi_M_AXI_AWVALID),
        .m_axi_bid(m15_sc2axi_M_AXI_BID),
        .m_axi_bready(m15_sc2axi_M_AXI_BREADY),
        .m_axi_bresp(m15_sc2axi_M_AXI_BRESP),
        .m_axi_buser(m15_sc2axi_M_AXI_BUSER),
        .m_axi_bvalid(m15_sc2axi_M_AXI_BVALID),
        .m_axi_rdata(m15_sc2axi_M_AXI_RDATA),
        .m_axi_rid(m15_sc2axi_M_AXI_RID),
        .m_axi_rlast(m15_sc2axi_M_AXI_RLAST),
        .m_axi_rready(m15_sc2axi_M_AXI_RREADY),
        .m_axi_rresp(m15_sc2axi_M_AXI_RRESP),
        .m_axi_ruser(m15_sc2axi_M_AXI_RUSER),
        .m_axi_rvalid(m15_sc2axi_M_AXI_RVALID),
        .m_axi_wdata(m15_sc2axi_M_AXI_WDATA),
        .m_axi_wlast(m15_sc2axi_M_AXI_WLAST),
        .m_axi_wready(m15_sc2axi_M_AXI_WREADY),
        .m_axi_wstrb(m15_sc2axi_M_AXI_WSTRB),
        .m_axi_wuser(m15_sc2axi_M_AXI_WUSER),
        .m_axi_wvalid(m15_sc2axi_M_AXI_WVALID),
        .m_sc_b_info(S_SC_B_17_INFO),
        .m_sc_b_payld(S_SC_B_17_PAYLD),
        .m_sc_b_recv(S_SC_B_17_RECV),
        .m_sc_b_req(S_SC_B_17_REQ),
        .m_sc_b_send(S_SC_B_17_SEND),
        .m_sc_r_info(S_SC_R_17_INFO),
        .m_sc_r_payld(S_SC_R_17_PAYLD),
        .m_sc_r_recv(S_SC_R_17_RECV),
        .m_sc_r_req(S_SC_R_17_REQ),
        .m_sc_r_send(S_SC_R_17_SEND),
        .s_sc_ar_info(m15_nodes_M_SC_AR_INFO),
        .s_sc_ar_payld(m15_nodes_M_SC_AR_PAYLD),
        .s_sc_ar_recv(m15_nodes_M_SC_AR_RECV),
        .s_sc_ar_req(m15_nodes_M_SC_AR_REQ),
        .s_sc_ar_send(m15_nodes_M_SC_AR_SEND),
        .s_sc_aw_info(m15_nodes_M_SC_AW_INFO),
        .s_sc_aw_payld(m15_nodes_M_SC_AW_PAYLD),
        .s_sc_aw_recv(m15_nodes_M_SC_AW_RECV),
        .s_sc_aw_req(m15_nodes_M_SC_AW_REQ),
        .s_sc_aw_send(m15_nodes_M_SC_AW_SEND),
        .s_sc_w_info(m15_nodes_M_SC_W_INFO),
        .s_sc_w_payld(m15_nodes_M_SC_W_PAYLD),
        .s_sc_w_recv(m15_nodes_M_SC_W_RECV),
        .s_sc_w_req(m15_nodes_M_SC_W_REQ),
        .s_sc_w_send(m15_nodes_M_SC_W_SEND));
  bd_87e8_s00a2s_0 s00_axi2sc
       (.aclk(aclk_1),
        .m_sc_ar_info(S_SC_AR_1_INFO),
        .m_sc_ar_payld(S_SC_AR_1_PAYLD),
        .m_sc_ar_recv(S_SC_AR_1_RECV),
        .m_sc_ar_req(S_SC_AR_1_REQ),
        .m_sc_ar_send(S_SC_AR_1_SEND),
        .m_sc_aw_info(S_SC_AW_1_INFO),
        .m_sc_aw_payld(S_SC_AW_1_PAYLD),
        .m_sc_aw_recv(S_SC_AW_1_RECV),
        .m_sc_aw_req(S_SC_AW_1_REQ),
        .m_sc_aw_send(S_SC_AW_1_SEND),
        .m_sc_w_info(S_SC_W_1_INFO),
        .m_sc_w_payld(S_SC_W_1_PAYLD),
        .m_sc_w_recv(S_SC_W_1_RECV),
        .m_sc_w_req(S_SC_W_1_REQ),
        .m_sc_w_send(S_SC_W_1_SEND),
        .s_axi_araddr(s00_entry_pipeline_m_axi_ARADDR),
        .s_axi_arcache(s00_entry_pipeline_m_axi_ARCACHE),
        .s_axi_arid(s00_entry_pipeline_m_axi_ARID),
        .s_axi_arlen(s00_entry_pipeline_m_axi_ARLEN),
        .s_axi_arlock(s00_entry_pipeline_m_axi_ARLOCK),
        .s_axi_arprot(s00_entry_pipeline_m_axi_ARPROT),
        .s_axi_arqos(s00_entry_pipeline_m_axi_ARQOS),
        .s_axi_arready(s00_entry_pipeline_m_axi_ARREADY),
        .s_axi_aruser(s00_entry_pipeline_m_axi_ARUSER),
        .s_axi_arvalid(s00_entry_pipeline_m_axi_ARVALID),
        .s_axi_awaddr(s00_entry_pipeline_m_axi_AWADDR),
        .s_axi_awcache(s00_entry_pipeline_m_axi_AWCACHE),
        .s_axi_awid(s00_entry_pipeline_m_axi_AWID),
        .s_axi_awlen(s00_entry_pipeline_m_axi_AWLEN),
        .s_axi_awlock(s00_entry_pipeline_m_axi_AWLOCK),
        .s_axi_awprot(s00_entry_pipeline_m_axi_AWPROT),
        .s_axi_awqos(s00_entry_pipeline_m_axi_AWQOS),
        .s_axi_awready(s00_entry_pipeline_m_axi_AWREADY),
        .s_axi_awuser(s00_entry_pipeline_m_axi_AWUSER),
        .s_axi_awvalid(s00_entry_pipeline_m_axi_AWVALID),
        .s_axi_bid(s00_entry_pipeline_m_axi_BID),
        .s_axi_bready(s00_entry_pipeline_m_axi_BREADY),
        .s_axi_bresp(s00_entry_pipeline_m_axi_BRESP),
        .s_axi_buser(s00_entry_pipeline_m_axi_BUSER),
        .s_axi_bvalid(s00_entry_pipeline_m_axi_BVALID),
        .s_axi_rdata(s00_entry_pipeline_m_axi_RDATA),
        .s_axi_rid(s00_entry_pipeline_m_axi_RID),
        .s_axi_rlast(s00_entry_pipeline_m_axi_RLAST),
        .s_axi_rready(s00_entry_pipeline_m_axi_RREADY),
        .s_axi_rresp(s00_entry_pipeline_m_axi_RRESP),
        .s_axi_ruser(s00_entry_pipeline_m_axi_RUSER),
        .s_axi_rvalid(s00_entry_pipeline_m_axi_RVALID),
        .s_axi_wdata(s00_entry_pipeline_m_axi_WDATA),
        .s_axi_wlast(s00_entry_pipeline_m_axi_WLAST),
        .s_axi_wready(s00_entry_pipeline_m_axi_WREADY),
        .s_axi_wstrb(s00_entry_pipeline_m_axi_WSTRB),
        .s_axi_wuser(s00_entry_pipeline_m_axi_WUSER),
        .s_axi_wvalid(s00_entry_pipeline_m_axi_WVALID),
        .s_sc_b_info(s00_nodes_M_SC_B_INFO),
        .s_sc_b_payld(s00_nodes_M_SC_B_PAYLD),
        .s_sc_b_recv(s00_nodes_M_SC_B_RECV),
        .s_sc_b_req(s00_nodes_M_SC_B_REQ),
        .s_sc_b_send(s00_nodes_M_SC_B_SEND),
        .s_sc_r_info(s00_nodes_M_SC_R_INFO),
        .s_sc_r_payld(s00_nodes_M_SC_R_PAYLD),
        .s_sc_r_recv(s00_nodes_M_SC_R_RECV),
        .s_sc_r_req(s00_nodes_M_SC_R_REQ),
        .s_sc_r_send(s00_nodes_M_SC_R_SEND));
  s00_entry_pipeline_imp_W6YIYT s00_entry_pipeline
       (.aclk(aclk_1),
        .aresetn(aresetn_2),
        .m_axi_araddr(s00_entry_pipeline_m_axi_ARADDR),
        .m_axi_arcache(s00_entry_pipeline_m_axi_ARCACHE),
        .m_axi_arid(s00_entry_pipeline_m_axi_ARID),
        .m_axi_arlen(s00_entry_pipeline_m_axi_ARLEN),
        .m_axi_arlock(s00_entry_pipeline_m_axi_ARLOCK),
        .m_axi_arprot(s00_entry_pipeline_m_axi_ARPROT),
        .m_axi_arqos(s00_entry_pipeline_m_axi_ARQOS),
        .m_axi_arready(s00_entry_pipeline_m_axi_ARREADY),
        .m_axi_aruser(s00_entry_pipeline_m_axi_ARUSER),
        .m_axi_arvalid(s00_entry_pipeline_m_axi_ARVALID),
        .m_axi_awaddr(s00_entry_pipeline_m_axi_AWADDR),
        .m_axi_awcache(s00_entry_pipeline_m_axi_AWCACHE),
        .m_axi_awid(s00_entry_pipeline_m_axi_AWID),
        .m_axi_awlen(s00_entry_pipeline_m_axi_AWLEN),
        .m_axi_awlock(s00_entry_pipeline_m_axi_AWLOCK),
        .m_axi_awprot(s00_entry_pipeline_m_axi_AWPROT),
        .m_axi_awqos(s00_entry_pipeline_m_axi_AWQOS),
        .m_axi_awready(s00_entry_pipeline_m_axi_AWREADY),
        .m_axi_awuser(s00_entry_pipeline_m_axi_AWUSER),
        .m_axi_awvalid(s00_entry_pipeline_m_axi_AWVALID),
        .m_axi_bid(s00_entry_pipeline_m_axi_BID),
        .m_axi_bready(s00_entry_pipeline_m_axi_BREADY),
        .m_axi_bresp(s00_entry_pipeline_m_axi_BRESP),
        .m_axi_buser(s00_entry_pipeline_m_axi_BUSER),
        .m_axi_bvalid(s00_entry_pipeline_m_axi_BVALID),
        .m_axi_rdata(s00_entry_pipeline_m_axi_RDATA),
        .m_axi_rid(s00_entry_pipeline_m_axi_RID),
        .m_axi_rlast(s00_entry_pipeline_m_axi_RLAST),
        .m_axi_rready(s00_entry_pipeline_m_axi_RREADY),
        .m_axi_rresp(s00_entry_pipeline_m_axi_RRESP),
        .m_axi_ruser(s00_entry_pipeline_m_axi_RUSER),
        .m_axi_rvalid(s00_entry_pipeline_m_axi_RVALID),
        .m_axi_wdata(s00_entry_pipeline_m_axi_WDATA),
        .m_axi_wlast(s00_entry_pipeline_m_axi_WLAST),
        .m_axi_wready(s00_entry_pipeline_m_axi_WREADY),
        .m_axi_wstrb(s00_entry_pipeline_m_axi_WSTRB),
        .m_axi_wuser(s00_entry_pipeline_m_axi_WUSER),
        .m_axi_wvalid(s00_entry_pipeline_m_axi_WVALID),
        .s_axi_araddr(S00_AXI_araddr),
        .s_axi_arburst(S00_AXI_arburst),
        .s_axi_arcache(S00_AXI_arcache),
        .s_axi_arid(S00_AXI_arid),
        .s_axi_arlen(S00_AXI_arlen),
        .s_axi_arlock(S00_AXI_arlock),
        .s_axi_arprot(S00_AXI_arprot),
        .s_axi_arqos(S00_AXI_arqos),
        .s_axi_arready(S00_AXI_arready),
        .s_axi_arsize(S00_AXI_arsize),
        .s_axi_aruser(S00_AXI_aruser),
        .s_axi_arvalid(S00_AXI_arvalid),
        .s_axi_awaddr(S00_AXI_awaddr),
        .s_axi_awburst(S00_AXI_awburst),
        .s_axi_awcache(S00_AXI_awcache),
        .s_axi_awid(S00_AXI_awid),
        .s_axi_awlen(S00_AXI_awlen),
        .s_axi_awlock(S00_AXI_awlock),
        .s_axi_awprot(S00_AXI_awprot),
        .s_axi_awqos(S00_AXI_awqos),
        .s_axi_awready(S00_AXI_awready),
        .s_axi_awsize(S00_AXI_awsize),
        .s_axi_awuser(S00_AXI_awuser),
        .s_axi_awvalid(S00_AXI_awvalid),
        .s_axi_bid(S00_AXI_bid),
        .s_axi_bready(S00_AXI_bready),
        .s_axi_bresp(S00_AXI_bresp),
        .s_axi_buser(S00_AXI_buser),
        .s_axi_bvalid(S00_AXI_bvalid),
        .s_axi_rdata(S00_AXI_rdata),
        .s_axi_rid(S00_AXI_rid),
        .s_axi_rlast(S00_AXI_rlast),
        .s_axi_rready(S00_AXI_rready),
        .s_axi_rresp(S00_AXI_rresp),
        .s_axi_ruser(S00_AXI_ruser),
        .s_axi_rvalid(S00_AXI_rvalid),
        .s_axi_wdata(S00_AXI_wdata),
        .s_axi_wlast(S00_AXI_wlast),
        .s_axi_wready(S00_AXI_wready),
        .s_axi_wstrb(S00_AXI_wstrb),
        .s_axi_wuser(S00_AXI_wuser),
        .s_axi_wvalid(S00_AXI_wvalid));
  s00_nodes_imp_R4DQJJ s00_nodes
       (.M_SC_AR_info(s00_nodes_M_SC_AR_INFO),
        .M_SC_AR_payld(s00_nodes_M_SC_AR_PAYLD),
        .M_SC_AR_recv(s00_nodes_M_SC_AR_RECV),
        .M_SC_AR_req(s00_nodes_M_SC_AR_REQ),
        .M_SC_AR_send(s00_nodes_M_SC_AR_SEND),
        .M_SC_AW_info(s00_nodes_M_SC_AW_INFO),
        .M_SC_AW_payld(s00_nodes_M_SC_AW_PAYLD),
        .M_SC_AW_recv(s00_nodes_M_SC_AW_RECV),
        .M_SC_AW_req(s00_nodes_M_SC_AW_REQ),
        .M_SC_AW_send(s00_nodes_M_SC_AW_SEND),
        .M_SC_B_info(s00_nodes_M_SC_B_INFO),
        .M_SC_B_payld(s00_nodes_M_SC_B_PAYLD),
        .M_SC_B_recv(s00_nodes_M_SC_B_RECV),
        .M_SC_B_req(s00_nodes_M_SC_B_REQ),
        .M_SC_B_send(s00_nodes_M_SC_B_SEND),
        .M_SC_R_info(s00_nodes_M_SC_R_INFO),
        .M_SC_R_payld(s00_nodes_M_SC_R_PAYLD),
        .M_SC_R_recv(s00_nodes_M_SC_R_RECV),
        .M_SC_R_req(s00_nodes_M_SC_R_REQ),
        .M_SC_R_send(s00_nodes_M_SC_R_SEND),
        .M_SC_W_info(s00_nodes_M_SC_W_INFO),
        .M_SC_W_payld(s00_nodes_M_SC_W_PAYLD),
        .M_SC_W_recv(s00_nodes_M_SC_W_RECV),
        .M_SC_W_req(s00_nodes_M_SC_W_REQ),
        .M_SC_W_send(s00_nodes_M_SC_W_SEND),
        .S_SC_AR_info(S_SC_AR_1_INFO),
        .S_SC_AR_payld(S_SC_AR_1_PAYLD),
        .S_SC_AR_recv(S_SC_AR_1_RECV),
        .S_SC_AR_req(S_SC_AR_1_REQ),
        .S_SC_AR_send(S_SC_AR_1_SEND),
        .S_SC_AW_info(S_SC_AW_1_INFO),
        .S_SC_AW_payld(S_SC_AW_1_PAYLD),
        .S_SC_AW_recv(S_SC_AW_1_RECV),
        .S_SC_AW_req(S_SC_AW_1_REQ),
        .S_SC_AW_send(S_SC_AW_1_SEND),
        .S_SC_B_info(S_SC_B_1_INFO),
        .S_SC_B_payld(S_SC_B_1_PAYLD),
        .S_SC_B_recv(S_SC_B_1_RECV),
        .S_SC_B_req(S_SC_B_1_REQ),
        .S_SC_B_send(S_SC_B_1_SEND),
        .S_SC_R_info(S_SC_R_1_INFO),
        .S_SC_R_payld(S_SC_R_1_PAYLD),
        .S_SC_R_recv(S_SC_R_1_RECV),
        .S_SC_R_req(S_SC_R_1_REQ),
        .S_SC_R_send(S_SC_R_1_SEND),
        .S_SC_W_info(S_SC_W_1_INFO),
        .S_SC_W_payld(S_SC_W_1_PAYLD),
        .S_SC_W_recv(S_SC_W_1_RECV),
        .S_SC_W_req(S_SC_W_1_REQ),
        .S_SC_W_send(S_SC_W_1_SEND),
        .m_sc_clk(swbd_aclk_net),
        .m_sc_resetn(swbd_aresetn_net),
        .s_sc_clk(aclk_1),
        .s_sc_resetn(aresetn_2));
  switchboards_imp_2UP7YJ switchboards
       (.M00_SC_AR_info(S_SC_AR_2_INFO),
        .M00_SC_AR_payld(S_SC_AR_2_PAYLD),
        .M00_SC_AR_recv(S_SC_AR_2_RECV),
        .M00_SC_AR_req(S_SC_AR_2_REQ),
        .M00_SC_AR_send(S_SC_AR_2_SEND),
        .M00_SC_AW_info(S_SC_AW_2_INFO),
        .M00_SC_AW_payld(S_SC_AW_2_PAYLD),
        .M00_SC_AW_recv(S_SC_AW_2_RECV),
        .M00_SC_AW_req(S_SC_AW_2_REQ),
        .M00_SC_AW_send(S_SC_AW_2_SEND),
        .M00_SC_B_info(S_SC_B_1_INFO),
        .M00_SC_B_payld(S_SC_B_1_PAYLD),
        .M00_SC_B_recv(S_SC_B_1_RECV),
        .M00_SC_B_req(S_SC_B_1_REQ),
        .M00_SC_B_send(S_SC_B_1_SEND),
        .M00_SC_R_info(S_SC_R_1_INFO),
        .M00_SC_R_payld(S_SC_R_1_PAYLD),
        .M00_SC_R_recv(S_SC_R_1_RECV),
        .M00_SC_R_req(S_SC_R_1_REQ),
        .M00_SC_R_send(S_SC_R_1_SEND),
        .M00_SC_W_info(S_SC_W_2_INFO),
        .M00_SC_W_payld(S_SC_W_2_PAYLD),
        .M00_SC_W_recv(S_SC_W_2_RECV),
        .M00_SC_W_req(S_SC_W_2_REQ),
        .M00_SC_W_send(S_SC_W_2_SEND),
        .M01_SC_AR_info(S_SC_AR_3_INFO),
        .M01_SC_AR_payld(S_SC_AR_3_PAYLD),
        .M01_SC_AR_recv(S_SC_AR_3_RECV),
        .M01_SC_AR_req(S_SC_AR_3_REQ),
        .M01_SC_AR_send(S_SC_AR_3_SEND),
        .M01_SC_AW_info(S_SC_AW_3_INFO),
        .M01_SC_AW_payld(S_SC_AW_3_PAYLD),
        .M01_SC_AW_recv(S_SC_AW_3_RECV),
        .M01_SC_AW_req(S_SC_AW_3_REQ),
        .M01_SC_AW_send(S_SC_AW_3_SEND),
        .M01_SC_W_info(S_SC_W_3_INFO),
        .M01_SC_W_payld(S_SC_W_3_PAYLD),
        .M01_SC_W_recv(S_SC_W_3_RECV),
        .M01_SC_W_req(S_SC_W_3_REQ),
        .M01_SC_W_send(S_SC_W_3_SEND),
        .M02_SC_AR_info(S_SC_AR_4_INFO),
        .M02_SC_AR_payld(S_SC_AR_4_PAYLD),
        .M02_SC_AR_recv(S_SC_AR_4_RECV),
        .M02_SC_AR_req(S_SC_AR_4_REQ),
        .M02_SC_AR_send(S_SC_AR_4_SEND),
        .M02_SC_AW_info(S_SC_AW_4_INFO),
        .M02_SC_AW_payld(S_SC_AW_4_PAYLD),
        .M02_SC_AW_recv(S_SC_AW_4_RECV),
        .M02_SC_AW_req(S_SC_AW_4_REQ),
        .M02_SC_AW_send(S_SC_AW_4_SEND),
        .M02_SC_W_info(S_SC_W_4_INFO),
        .M02_SC_W_payld(S_SC_W_4_PAYLD),
        .M02_SC_W_recv(S_SC_W_4_RECV),
        .M02_SC_W_req(S_SC_W_4_REQ),
        .M02_SC_W_send(S_SC_W_4_SEND),
        .M03_SC_AR_info(S_SC_AR_5_INFO),
        .M03_SC_AR_payld(S_SC_AR_5_PAYLD),
        .M03_SC_AR_recv(S_SC_AR_5_RECV),
        .M03_SC_AR_req(S_SC_AR_5_REQ),
        .M03_SC_AR_send(S_SC_AR_5_SEND),
        .M03_SC_AW_info(S_SC_AW_5_INFO),
        .M03_SC_AW_payld(S_SC_AW_5_PAYLD),
        .M03_SC_AW_recv(S_SC_AW_5_RECV),
        .M03_SC_AW_req(S_SC_AW_5_REQ),
        .M03_SC_AW_send(S_SC_AW_5_SEND),
        .M03_SC_W_info(S_SC_W_5_INFO),
        .M03_SC_W_payld(S_SC_W_5_PAYLD),
        .M03_SC_W_recv(S_SC_W_5_RECV),
        .M03_SC_W_req(S_SC_W_5_REQ),
        .M03_SC_W_send(S_SC_W_5_SEND),
        .M04_SC_AR_info(S_SC_AR_6_INFO),
        .M04_SC_AR_payld(S_SC_AR_6_PAYLD),
        .M04_SC_AR_recv(S_SC_AR_6_RECV),
        .M04_SC_AR_req(S_SC_AR_6_REQ),
        .M04_SC_AR_send(S_SC_AR_6_SEND),
        .M04_SC_AW_info(S_SC_AW_6_INFO),
        .M04_SC_AW_payld(S_SC_AW_6_PAYLD),
        .M04_SC_AW_recv(S_SC_AW_6_RECV),
        .M04_SC_AW_req(S_SC_AW_6_REQ),
        .M04_SC_AW_send(S_SC_AW_6_SEND),
        .M04_SC_W_info(S_SC_W_6_INFO),
        .M04_SC_W_payld(S_SC_W_6_PAYLD),
        .M04_SC_W_recv(S_SC_W_6_RECV),
        .M04_SC_W_req(S_SC_W_6_REQ),
        .M04_SC_W_send(S_SC_W_6_SEND),
        .M05_SC_AR_info(S_SC_AR_7_INFO),
        .M05_SC_AR_payld(S_SC_AR_7_PAYLD),
        .M05_SC_AR_recv(S_SC_AR_7_RECV),
        .M05_SC_AR_req(S_SC_AR_7_REQ),
        .M05_SC_AR_send(S_SC_AR_7_SEND),
        .M05_SC_AW_info(S_SC_AW_7_INFO),
        .M05_SC_AW_payld(S_SC_AW_7_PAYLD),
        .M05_SC_AW_recv(S_SC_AW_7_RECV),
        .M05_SC_AW_req(S_SC_AW_7_REQ),
        .M05_SC_AW_send(S_SC_AW_7_SEND),
        .M05_SC_W_info(S_SC_W_7_INFO),
        .M05_SC_W_payld(S_SC_W_7_PAYLD),
        .M05_SC_W_recv(S_SC_W_7_RECV),
        .M05_SC_W_req(S_SC_W_7_REQ),
        .M05_SC_W_send(S_SC_W_7_SEND),
        .M06_SC_AR_info(S_SC_AR_8_INFO),
        .M06_SC_AR_payld(S_SC_AR_8_PAYLD),
        .M06_SC_AR_recv(S_SC_AR_8_RECV),
        .M06_SC_AR_req(S_SC_AR_8_REQ),
        .M06_SC_AR_send(S_SC_AR_8_SEND),
        .M06_SC_AW_info(S_SC_AW_8_INFO),
        .M06_SC_AW_payld(S_SC_AW_8_PAYLD),
        .M06_SC_AW_recv(S_SC_AW_8_RECV),
        .M06_SC_AW_req(S_SC_AW_8_REQ),
        .M06_SC_AW_send(S_SC_AW_8_SEND),
        .M06_SC_W_info(S_SC_W_8_INFO),
        .M06_SC_W_payld(S_SC_W_8_PAYLD),
        .M06_SC_W_recv(S_SC_W_8_RECV),
        .M06_SC_W_req(S_SC_W_8_REQ),
        .M06_SC_W_send(S_SC_W_8_SEND),
        .M07_SC_AR_info(S_SC_AR_9_INFO),
        .M07_SC_AR_payld(S_SC_AR_9_PAYLD),
        .M07_SC_AR_recv(S_SC_AR_9_RECV),
        .M07_SC_AR_req(S_SC_AR_9_REQ),
        .M07_SC_AR_send(S_SC_AR_9_SEND),
        .M07_SC_AW_info(S_SC_AW_9_INFO),
        .M07_SC_AW_payld(S_SC_AW_9_PAYLD),
        .M07_SC_AW_recv(S_SC_AW_9_RECV),
        .M07_SC_AW_req(S_SC_AW_9_REQ),
        .M07_SC_AW_send(S_SC_AW_9_SEND),
        .M07_SC_W_info(S_SC_W_9_INFO),
        .M07_SC_W_payld(S_SC_W_9_PAYLD),
        .M07_SC_W_recv(S_SC_W_9_RECV),
        .M07_SC_W_req(S_SC_W_9_REQ),
        .M07_SC_W_send(S_SC_W_9_SEND),
        .M08_SC_AR_info(S_SC_AR_10_INFO),
        .M08_SC_AR_payld(S_SC_AR_10_PAYLD),
        .M08_SC_AR_recv(S_SC_AR_10_RECV),
        .M08_SC_AR_req(S_SC_AR_10_REQ),
        .M08_SC_AR_send(S_SC_AR_10_SEND),
        .M08_SC_AW_info(S_SC_AW_10_INFO),
        .M08_SC_AW_payld(S_SC_AW_10_PAYLD),
        .M08_SC_AW_recv(S_SC_AW_10_RECV),
        .M08_SC_AW_req(S_SC_AW_10_REQ),
        .M08_SC_AW_send(S_SC_AW_10_SEND),
        .M08_SC_W_info(S_SC_W_10_INFO),
        .M08_SC_W_payld(S_SC_W_10_PAYLD),
        .M08_SC_W_recv(S_SC_W_10_RECV),
        .M08_SC_W_req(S_SC_W_10_REQ),
        .M08_SC_W_send(S_SC_W_10_SEND),
        .M09_SC_AR_info(S_SC_AR_11_INFO),
        .M09_SC_AR_payld(S_SC_AR_11_PAYLD),
        .M09_SC_AR_recv(S_SC_AR_11_RECV),
        .M09_SC_AR_req(S_SC_AR_11_REQ),
        .M09_SC_AR_send(S_SC_AR_11_SEND),
        .M09_SC_AW_info(S_SC_AW_11_INFO),
        .M09_SC_AW_payld(S_SC_AW_11_PAYLD),
        .M09_SC_AW_recv(S_SC_AW_11_RECV),
        .M09_SC_AW_req(S_SC_AW_11_REQ),
        .M09_SC_AW_send(S_SC_AW_11_SEND),
        .M09_SC_W_info(S_SC_W_11_INFO),
        .M09_SC_W_payld(S_SC_W_11_PAYLD),
        .M09_SC_W_recv(S_SC_W_11_RECV),
        .M09_SC_W_req(S_SC_W_11_REQ),
        .M09_SC_W_send(S_SC_W_11_SEND),
        .M10_SC_AR_info(S_SC_AR_12_INFO),
        .M10_SC_AR_payld(S_SC_AR_12_PAYLD),
        .M10_SC_AR_recv(S_SC_AR_12_RECV),
        .M10_SC_AR_req(S_SC_AR_12_REQ),
        .M10_SC_AR_send(S_SC_AR_12_SEND),
        .M10_SC_AW_info(S_SC_AW_12_INFO),
        .M10_SC_AW_payld(S_SC_AW_12_PAYLD),
        .M10_SC_AW_recv(S_SC_AW_12_RECV),
        .M10_SC_AW_req(S_SC_AW_12_REQ),
        .M10_SC_AW_send(S_SC_AW_12_SEND),
        .M10_SC_W_info(S_SC_W_12_INFO),
        .M10_SC_W_payld(S_SC_W_12_PAYLD),
        .M10_SC_W_recv(S_SC_W_12_RECV),
        .M10_SC_W_req(S_SC_W_12_REQ),
        .M10_SC_W_send(S_SC_W_12_SEND),
        .M11_SC_AR_info(S_SC_AR_13_INFO),
        .M11_SC_AR_payld(S_SC_AR_13_PAYLD),
        .M11_SC_AR_recv(S_SC_AR_13_RECV),
        .M11_SC_AR_req(S_SC_AR_13_REQ),
        .M11_SC_AR_send(S_SC_AR_13_SEND),
        .M11_SC_AW_info(S_SC_AW_13_INFO),
        .M11_SC_AW_payld(S_SC_AW_13_PAYLD),
        .M11_SC_AW_recv(S_SC_AW_13_RECV),
        .M11_SC_AW_req(S_SC_AW_13_REQ),
        .M11_SC_AW_send(S_SC_AW_13_SEND),
        .M11_SC_W_info(S_SC_W_13_INFO),
        .M11_SC_W_payld(S_SC_W_13_PAYLD),
        .M11_SC_W_recv(S_SC_W_13_RECV),
        .M11_SC_W_req(S_SC_W_13_REQ),
        .M11_SC_W_send(S_SC_W_13_SEND),
        .M12_SC_AR_info(S_SC_AR_14_INFO),
        .M12_SC_AR_payld(S_SC_AR_14_PAYLD),
        .M12_SC_AR_recv(S_SC_AR_14_RECV),
        .M12_SC_AR_req(S_SC_AR_14_REQ),
        .M12_SC_AR_send(S_SC_AR_14_SEND),
        .M12_SC_AW_info(S_SC_AW_14_INFO),
        .M12_SC_AW_payld(S_SC_AW_14_PAYLD),
        .M12_SC_AW_recv(S_SC_AW_14_RECV),
        .M12_SC_AW_req(S_SC_AW_14_REQ),
        .M12_SC_AW_send(S_SC_AW_14_SEND),
        .M12_SC_W_info(S_SC_W_14_INFO),
        .M12_SC_W_payld(S_SC_W_14_PAYLD),
        .M12_SC_W_recv(S_SC_W_14_RECV),
        .M12_SC_W_req(S_SC_W_14_REQ),
        .M12_SC_W_send(S_SC_W_14_SEND),
        .M13_SC_AR_info(S_SC_AR_15_INFO),
        .M13_SC_AR_payld(S_SC_AR_15_PAYLD),
        .M13_SC_AR_recv(S_SC_AR_15_RECV),
        .M13_SC_AR_req(S_SC_AR_15_REQ),
        .M13_SC_AR_send(S_SC_AR_15_SEND),
        .M13_SC_AW_info(S_SC_AW_15_INFO),
        .M13_SC_AW_payld(S_SC_AW_15_PAYLD),
        .M13_SC_AW_recv(S_SC_AW_15_RECV),
        .M13_SC_AW_req(S_SC_AW_15_REQ),
        .M13_SC_AW_send(S_SC_AW_15_SEND),
        .M13_SC_W_info(S_SC_W_15_INFO),
        .M13_SC_W_payld(S_SC_W_15_PAYLD),
        .M13_SC_W_recv(S_SC_W_15_RECV),
        .M13_SC_W_req(S_SC_W_15_REQ),
        .M13_SC_W_send(S_SC_W_15_SEND),
        .M14_SC_AR_info(S_SC_AR_16_INFO),
        .M14_SC_AR_payld(S_SC_AR_16_PAYLD),
        .M14_SC_AR_recv(S_SC_AR_16_RECV),
        .M14_SC_AR_req(S_SC_AR_16_REQ),
        .M14_SC_AR_send(S_SC_AR_16_SEND),
        .M14_SC_AW_info(S_SC_AW_16_INFO),
        .M14_SC_AW_payld(S_SC_AW_16_PAYLD),
        .M14_SC_AW_recv(S_SC_AW_16_RECV),
        .M14_SC_AW_req(S_SC_AW_16_REQ),
        .M14_SC_AW_send(S_SC_AW_16_SEND),
        .M14_SC_W_info(S_SC_W_16_INFO),
        .M14_SC_W_payld(S_SC_W_16_PAYLD),
        .M14_SC_W_recv(S_SC_W_16_RECV),
        .M14_SC_W_req(S_SC_W_16_REQ),
        .M14_SC_W_send(S_SC_W_16_SEND),
        .M15_SC_AR_info(S_SC_AR_17_INFO),
        .M15_SC_AR_payld(S_SC_AR_17_PAYLD),
        .M15_SC_AR_recv(S_SC_AR_17_RECV),
        .M15_SC_AR_req(S_SC_AR_17_REQ),
        .M15_SC_AR_send(S_SC_AR_17_SEND),
        .M15_SC_AW_info(S_SC_AW_17_INFO),
        .M15_SC_AW_payld(S_SC_AW_17_PAYLD),
        .M15_SC_AW_recv(S_SC_AW_17_RECV),
        .M15_SC_AW_req(S_SC_AW_17_REQ),
        .M15_SC_AW_send(S_SC_AW_17_SEND),
        .M15_SC_W_info(S_SC_W_17_INFO),
        .M15_SC_W_payld(S_SC_W_17_PAYLD),
        .M15_SC_W_recv(S_SC_W_17_RECV),
        .M15_SC_W_req(S_SC_W_17_REQ),
        .M15_SC_W_send(S_SC_W_17_SEND),
        .S00_SC_AR_info(s00_nodes_M_SC_AR_INFO),
        .S00_SC_AR_payld(s00_nodes_M_SC_AR_PAYLD),
        .S00_SC_AR_recv(s00_nodes_M_SC_AR_RECV),
        .S00_SC_AR_req(s00_nodes_M_SC_AR_REQ),
        .S00_SC_AR_send(s00_nodes_M_SC_AR_SEND),
        .S00_SC_AW_info(s00_nodes_M_SC_AW_INFO),
        .S00_SC_AW_payld(s00_nodes_M_SC_AW_PAYLD),
        .S00_SC_AW_recv(s00_nodes_M_SC_AW_RECV),
        .S00_SC_AW_req(s00_nodes_M_SC_AW_REQ),
        .S00_SC_AW_send(s00_nodes_M_SC_AW_SEND),
        .S00_SC_B_info(m00_nodes_M_SC_B_INFO),
        .S00_SC_B_payld(m00_nodes_M_SC_B_PAYLD),
        .S00_SC_B_recv(m00_nodes_M_SC_B_RECV),
        .S00_SC_B_req(m00_nodes_M_SC_B_REQ),
        .S00_SC_B_send(m00_nodes_M_SC_B_SEND),
        .S00_SC_R_info(m00_nodes_M_SC_R_INFO),
        .S00_SC_R_payld(m00_nodes_M_SC_R_PAYLD),
        .S00_SC_R_recv(m00_nodes_M_SC_R_RECV),
        .S00_SC_R_req(m00_nodes_M_SC_R_REQ),
        .S00_SC_R_send(m00_nodes_M_SC_R_SEND),
        .S00_SC_W_info(s00_nodes_M_SC_W_INFO),
        .S00_SC_W_payld(s00_nodes_M_SC_W_PAYLD),
        .S00_SC_W_recv(s00_nodes_M_SC_W_RECV),
        .S00_SC_W_req(s00_nodes_M_SC_W_REQ),
        .S00_SC_W_send(s00_nodes_M_SC_W_SEND),
        .S01_SC_B_info(m01_nodes_M_SC_B_INFO),
        .S01_SC_B_payld(m01_nodes_M_SC_B_PAYLD),
        .S01_SC_B_recv(m01_nodes_M_SC_B_RECV),
        .S01_SC_B_req(m01_nodes_M_SC_B_REQ),
        .S01_SC_B_send(m01_nodes_M_SC_B_SEND),
        .S01_SC_R_info(m01_nodes_M_SC_R_INFO),
        .S01_SC_R_payld(m01_nodes_M_SC_R_PAYLD),
        .S01_SC_R_recv(m01_nodes_M_SC_R_RECV),
        .S01_SC_R_req(m01_nodes_M_SC_R_REQ),
        .S01_SC_R_send(m01_nodes_M_SC_R_SEND),
        .S02_SC_B_info(m02_nodes_M_SC_B_INFO),
        .S02_SC_B_payld(m02_nodes_M_SC_B_PAYLD),
        .S02_SC_B_recv(m02_nodes_M_SC_B_RECV),
        .S02_SC_B_req(m02_nodes_M_SC_B_REQ),
        .S02_SC_B_send(m02_nodes_M_SC_B_SEND),
        .S02_SC_R_info(m02_nodes_M_SC_R_INFO),
        .S02_SC_R_payld(m02_nodes_M_SC_R_PAYLD),
        .S02_SC_R_recv(m02_nodes_M_SC_R_RECV),
        .S02_SC_R_req(m02_nodes_M_SC_R_REQ),
        .S02_SC_R_send(m02_nodes_M_SC_R_SEND),
        .S03_SC_B_info(m03_nodes_M_SC_B_INFO),
        .S03_SC_B_payld(m03_nodes_M_SC_B_PAYLD),
        .S03_SC_B_recv(m03_nodes_M_SC_B_RECV),
        .S03_SC_B_req(m03_nodes_M_SC_B_REQ),
        .S03_SC_B_send(m03_nodes_M_SC_B_SEND),
        .S03_SC_R_info(m03_nodes_M_SC_R_INFO),
        .S03_SC_R_payld(m03_nodes_M_SC_R_PAYLD),
        .S03_SC_R_recv(m03_nodes_M_SC_R_RECV),
        .S03_SC_R_req(m03_nodes_M_SC_R_REQ),
        .S03_SC_R_send(m03_nodes_M_SC_R_SEND),
        .S04_SC_B_info(m04_nodes_M_SC_B_INFO),
        .S04_SC_B_payld(m04_nodes_M_SC_B_PAYLD),
        .S04_SC_B_recv(m04_nodes_M_SC_B_RECV),
        .S04_SC_B_req(m04_nodes_M_SC_B_REQ),
        .S04_SC_B_send(m04_nodes_M_SC_B_SEND),
        .S04_SC_R_info(m04_nodes_M_SC_R_INFO),
        .S04_SC_R_payld(m04_nodes_M_SC_R_PAYLD),
        .S04_SC_R_recv(m04_nodes_M_SC_R_RECV),
        .S04_SC_R_req(m04_nodes_M_SC_R_REQ),
        .S04_SC_R_send(m04_nodes_M_SC_R_SEND),
        .S05_SC_B_info(m05_nodes_M_SC_B_INFO),
        .S05_SC_B_payld(m05_nodes_M_SC_B_PAYLD),
        .S05_SC_B_recv(m05_nodes_M_SC_B_RECV),
        .S05_SC_B_req(m05_nodes_M_SC_B_REQ),
        .S05_SC_B_send(m05_nodes_M_SC_B_SEND),
        .S05_SC_R_info(m05_nodes_M_SC_R_INFO),
        .S05_SC_R_payld(m05_nodes_M_SC_R_PAYLD),
        .S05_SC_R_recv(m05_nodes_M_SC_R_RECV),
        .S05_SC_R_req(m05_nodes_M_SC_R_REQ),
        .S05_SC_R_send(m05_nodes_M_SC_R_SEND),
        .S06_SC_B_info(m06_nodes_M_SC_B_INFO),
        .S06_SC_B_payld(m06_nodes_M_SC_B_PAYLD),
        .S06_SC_B_recv(m06_nodes_M_SC_B_RECV),
        .S06_SC_B_req(m06_nodes_M_SC_B_REQ),
        .S06_SC_B_send(m06_nodes_M_SC_B_SEND),
        .S06_SC_R_info(m06_nodes_M_SC_R_INFO),
        .S06_SC_R_payld(m06_nodes_M_SC_R_PAYLD),
        .S06_SC_R_recv(m06_nodes_M_SC_R_RECV),
        .S06_SC_R_req(m06_nodes_M_SC_R_REQ),
        .S06_SC_R_send(m06_nodes_M_SC_R_SEND),
        .S07_SC_B_info(m07_nodes_M_SC_B_INFO),
        .S07_SC_B_payld(m07_nodes_M_SC_B_PAYLD),
        .S07_SC_B_recv(m07_nodes_M_SC_B_RECV),
        .S07_SC_B_req(m07_nodes_M_SC_B_REQ),
        .S07_SC_B_send(m07_nodes_M_SC_B_SEND),
        .S07_SC_R_info(m07_nodes_M_SC_R_INFO),
        .S07_SC_R_payld(m07_nodes_M_SC_R_PAYLD),
        .S07_SC_R_recv(m07_nodes_M_SC_R_RECV),
        .S07_SC_R_req(m07_nodes_M_SC_R_REQ),
        .S07_SC_R_send(m07_nodes_M_SC_R_SEND),
        .S08_SC_B_info(m08_nodes_M_SC_B_INFO),
        .S08_SC_B_payld(m08_nodes_M_SC_B_PAYLD),
        .S08_SC_B_recv(m08_nodes_M_SC_B_RECV),
        .S08_SC_B_req(m08_nodes_M_SC_B_REQ),
        .S08_SC_B_send(m08_nodes_M_SC_B_SEND),
        .S08_SC_R_info(m08_nodes_M_SC_R_INFO),
        .S08_SC_R_payld(m08_nodes_M_SC_R_PAYLD),
        .S08_SC_R_recv(m08_nodes_M_SC_R_RECV),
        .S08_SC_R_req(m08_nodes_M_SC_R_REQ),
        .S08_SC_R_send(m08_nodes_M_SC_R_SEND),
        .S09_SC_B_info(m09_nodes_M_SC_B_INFO),
        .S09_SC_B_payld(m09_nodes_M_SC_B_PAYLD),
        .S09_SC_B_recv(m09_nodes_M_SC_B_RECV),
        .S09_SC_B_req(m09_nodes_M_SC_B_REQ),
        .S09_SC_B_send(m09_nodes_M_SC_B_SEND),
        .S09_SC_R_info(m09_nodes_M_SC_R_INFO),
        .S09_SC_R_payld(m09_nodes_M_SC_R_PAYLD),
        .S09_SC_R_recv(m09_nodes_M_SC_R_RECV),
        .S09_SC_R_req(m09_nodes_M_SC_R_REQ),
        .S09_SC_R_send(m09_nodes_M_SC_R_SEND),
        .S10_SC_B_info(m10_nodes_M_SC_B_INFO),
        .S10_SC_B_payld(m10_nodes_M_SC_B_PAYLD),
        .S10_SC_B_recv(m10_nodes_M_SC_B_RECV),
        .S10_SC_B_req(m10_nodes_M_SC_B_REQ),
        .S10_SC_B_send(m10_nodes_M_SC_B_SEND),
        .S10_SC_R_info(m10_nodes_M_SC_R_INFO),
        .S10_SC_R_payld(m10_nodes_M_SC_R_PAYLD),
        .S10_SC_R_recv(m10_nodes_M_SC_R_RECV),
        .S10_SC_R_req(m10_nodes_M_SC_R_REQ),
        .S10_SC_R_send(m10_nodes_M_SC_R_SEND),
        .S11_SC_B_info(m11_nodes_M_SC_B_INFO),
        .S11_SC_B_payld(m11_nodes_M_SC_B_PAYLD),
        .S11_SC_B_recv(m11_nodes_M_SC_B_RECV),
        .S11_SC_B_req(m11_nodes_M_SC_B_REQ),
        .S11_SC_B_send(m11_nodes_M_SC_B_SEND),
        .S11_SC_R_info(m11_nodes_M_SC_R_INFO),
        .S11_SC_R_payld(m11_nodes_M_SC_R_PAYLD),
        .S11_SC_R_recv(m11_nodes_M_SC_R_RECV),
        .S11_SC_R_req(m11_nodes_M_SC_R_REQ),
        .S11_SC_R_send(m11_nodes_M_SC_R_SEND),
        .S12_SC_B_info(m12_nodes_M_SC_B_INFO),
        .S12_SC_B_payld(m12_nodes_M_SC_B_PAYLD),
        .S12_SC_B_recv(m12_nodes_M_SC_B_RECV),
        .S12_SC_B_req(m12_nodes_M_SC_B_REQ),
        .S12_SC_B_send(m12_nodes_M_SC_B_SEND),
        .S12_SC_R_info(m12_nodes_M_SC_R_INFO),
        .S12_SC_R_payld(m12_nodes_M_SC_R_PAYLD),
        .S12_SC_R_recv(m12_nodes_M_SC_R_RECV),
        .S12_SC_R_req(m12_nodes_M_SC_R_REQ),
        .S12_SC_R_send(m12_nodes_M_SC_R_SEND),
        .S13_SC_B_info(m13_nodes_M_SC_B_INFO),
        .S13_SC_B_payld(m13_nodes_M_SC_B_PAYLD),
        .S13_SC_B_recv(m13_nodes_M_SC_B_RECV),
        .S13_SC_B_req(m13_nodes_M_SC_B_REQ),
        .S13_SC_B_send(m13_nodes_M_SC_B_SEND),
        .S13_SC_R_info(m13_nodes_M_SC_R_INFO),
        .S13_SC_R_payld(m13_nodes_M_SC_R_PAYLD),
        .S13_SC_R_recv(m13_nodes_M_SC_R_RECV),
        .S13_SC_R_req(m13_nodes_M_SC_R_REQ),
        .S13_SC_R_send(m13_nodes_M_SC_R_SEND),
        .S14_SC_B_info(m14_nodes_M_SC_B_INFO),
        .S14_SC_B_payld(m14_nodes_M_SC_B_PAYLD),
        .S14_SC_B_recv(m14_nodes_M_SC_B_RECV),
        .S14_SC_B_req(m14_nodes_M_SC_B_REQ),
        .S14_SC_B_send(m14_nodes_M_SC_B_SEND),
        .S14_SC_R_info(m14_nodes_M_SC_R_INFO),
        .S14_SC_R_payld(m14_nodes_M_SC_R_PAYLD),
        .S14_SC_R_recv(m14_nodes_M_SC_R_RECV),
        .S14_SC_R_req(m14_nodes_M_SC_R_REQ),
        .S14_SC_R_send(m14_nodes_M_SC_R_SEND),
        .S15_SC_B_info(m15_nodes_M_SC_B_INFO),
        .S15_SC_B_payld(m15_nodes_M_SC_B_PAYLD),
        .S15_SC_B_recv(m15_nodes_M_SC_B_RECV),
        .S15_SC_B_req(m15_nodes_M_SC_B_REQ),
        .S15_SC_B_send(m15_nodes_M_SC_B_SEND),
        .S15_SC_R_info(m15_nodes_M_SC_R_INFO),
        .S15_SC_R_payld(m15_nodes_M_SC_R_PAYLD),
        .S15_SC_R_recv(m15_nodes_M_SC_R_RECV),
        .S15_SC_R_req(m15_nodes_M_SC_R_REQ),
        .S15_SC_R_send(m15_nodes_M_SC_R_SEND),
        .aclk(swbd_aclk_net),
        .aresetn(swbd_aresetn_net));
endmodule

module clk_map_imp_4ATSV1
   (M00_ACLK,
    M00_ARESETN,
    M01_ACLK,
    M01_ARESETN,
    M02_ACLK,
    M02_ARESETN,
    M03_ACLK,
    M03_ARESETN,
    M04_ACLK,
    M04_ARESETN,
    M05_ACLK,
    M05_ARESETN,
    M06_ACLK,
    M06_ARESETN,
    M07_ACLK,
    M07_ARESETN,
    M08_ACLK,
    M08_ARESETN,
    M09_ACLK,
    M09_ARESETN,
    M10_ACLK,
    M10_ARESETN,
    M11_ACLK,
    M11_ARESETN,
    M12_ACLK,
    M12_ARESETN,
    M13_ACLK,
    M13_ARESETN,
    M14_ACLK,
    M14_ARESETN,
    M15_ACLK,
    M15_ARESETN,
    S00_ACLK,
    S00_ARESETN,
    aclk,
    aresetn,
    aresetn_out,
    swbd_aclk,
    swbd_aresetn);
  output M00_ACLK;
  output [0:0]M00_ARESETN;
  output M01_ACLK;
  output [0:0]M01_ARESETN;
  output M02_ACLK;
  output [0:0]M02_ARESETN;
  output M03_ACLK;
  output [0:0]M03_ARESETN;
  output M04_ACLK;
  output [0:0]M04_ARESETN;
  output M05_ACLK;
  output [0:0]M05_ARESETN;
  output M06_ACLK;
  output [0:0]M06_ARESETN;
  output M07_ACLK;
  output [0:0]M07_ARESETN;
  output M08_ACLK;
  output [0:0]M08_ARESETN;
  output M09_ACLK;
  output [0:0]M09_ARESETN;
  output M10_ACLK;
  output [0:0]M10_ARESETN;
  output M11_ACLK;
  output [0:0]M11_ARESETN;
  output M12_ACLK;
  output [0:0]M12_ARESETN;
  output M13_ACLK;
  output [0:0]M13_ARESETN;
  output M14_ACLK;
  output [0:0]M14_ARESETN;
  output M15_ACLK;
  output [0:0]M15_ARESETN;
  output S00_ACLK;
  output [0:0]S00_ARESETN;
  input aclk;
  input aresetn;
  output aresetn_out;
  output swbd_aclk;
  output [0:0]swbd_aresetn;

  wire aresetn;
  wire [0:0]one_dout;
  wire swbd_aclk;
  wire [0:0]swbd_aresetn;

  assign M00_ACLK = swbd_aclk;
  assign M00_ARESETN[0] = swbd_aresetn;
  assign M01_ACLK = swbd_aclk;
  assign M01_ARESETN[0] = swbd_aresetn;
  assign M02_ACLK = swbd_aclk;
  assign M02_ARESETN[0] = swbd_aresetn;
  assign M03_ACLK = swbd_aclk;
  assign M03_ARESETN[0] = swbd_aresetn;
  assign M04_ACLK = swbd_aclk;
  assign M04_ARESETN[0] = swbd_aresetn;
  assign M05_ACLK = swbd_aclk;
  assign M05_ARESETN[0] = swbd_aresetn;
  assign M06_ACLK = swbd_aclk;
  assign M06_ARESETN[0] = swbd_aresetn;
  assign M07_ACLK = swbd_aclk;
  assign M07_ARESETN[0] = swbd_aresetn;
  assign M08_ACLK = swbd_aclk;
  assign M08_ARESETN[0] = swbd_aresetn;
  assign M09_ACLK = swbd_aclk;
  assign M09_ARESETN[0] = swbd_aresetn;
  assign M10_ACLK = swbd_aclk;
  assign M10_ARESETN[0] = swbd_aresetn;
  assign M11_ACLK = swbd_aclk;
  assign M11_ARESETN[0] = swbd_aresetn;
  assign M12_ACLK = swbd_aclk;
  assign M12_ARESETN[0] = swbd_aresetn;
  assign M13_ACLK = swbd_aclk;
  assign M13_ARESETN[0] = swbd_aresetn;
  assign M14_ACLK = swbd_aclk;
  assign M14_ARESETN[0] = swbd_aresetn;
  assign M15_ACLK = swbd_aclk;
  assign M15_ARESETN[0] = swbd_aresetn;
  assign S00_ACLK = swbd_aclk;
  assign S00_ARESETN[0] = swbd_aresetn;
  assign swbd_aclk = aclk;
  bd_87e8_one_0 one
       (.dout(one_dout));
  bd_87e8_psr_aclk_0 psr_aclk
       (.aux_reset_in(aresetn),
        .dcm_locked(1'b1),
        .ext_reset_in(one_dout),
        .interconnect_aresetn(swbd_aresetn),
        .mb_debug_sys_rst(1'b0),
        .slowest_sync_clk(swbd_aclk));
endmodule

module m00_exit_pipeline_imp_1WL21S6
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m00e_0 m00_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m00_nodes_imp_1AD58KQ
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m00arn_0 m00_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m00awn_0 m00_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m00bn_0 m00_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m00rn_0 m00_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m00wn_0 m00_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m01_exit_pipeline_imp_1Q5REBQ
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m01e_0 m01_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m01_nodes_imp_G46ZTO
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m01arn_0 m01_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m01awn_0 m01_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m01bn_0 m01_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m01rn_0 m01_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m01wn_0 m01_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m02_exit_pipeline_imp_1OCJM6E
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m02e_0 m02_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m02_nodes_imp_JJRDAF
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m02arn_0 m02_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m02awn_0 m02_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m02bn_0 m02_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m02rn_0 m02_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m02wn_0 m02_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m03_exit_pipeline_imp_1L93E86
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m03e_0 m03_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m03_nodes_imp_1OWCIUP
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m03arn_0 m03_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m03awn_0 m03_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m03bn_0 m03_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m03rn_0 m03_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m03wn_0 m03_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m04_exit_pipeline_imp_1BLMYKM
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m04e_0 m04_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m04_nodes_imp_1GWZNAP
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m04arn_0 m04_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m04awn_0 m04_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m04bn_0 m04_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m04rn_0 m04_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m04wn_0 m04_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m05_exit_pipeline_imp_1GCDYRQ
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m05e_0 m05_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m05_nodes_imp_9WTXAF
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m05arn_0 m05_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m05awn_0 m05_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m05bn_0 m05_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m05rn_0 m05_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m05wn_0 m05_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m06_exit_pipeline_imp_1156CXY
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m06e_0 m06_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m06_nodes_imp_QLCXZW
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m06arn_0 m06_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m06awn_0 m06_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m06bn_0 m06_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m06rn_0 m06_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m06wn_0 m06_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m07_exit_pipeline_imp_14RYAIU
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m07e_0 m07_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m07_nodes_imp_1I28KTM
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m07arn_0 m07_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m07awn_0 m07_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m07bn_0 m07_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m07rn_0 m07_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m07wn_0 m07_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m08_exit_pipeline_imp_LRC6TI
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m08e_0 m08_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m08_nodes_imp_154YDNG
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m08arn_0 m08_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m08awn_0 m08_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m08bn_0 m08_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m08rn_0 m08_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m08wn_0 m08_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m09_exit_pipeline_imp_ORO1FQ
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m09e_0 m09_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m09_nodes_imp_2KVZE2
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m09arn_0 m09_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m09awn_0 m09_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m09bn_0 m09_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m09rn_0 m09_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m09wn_0 m09_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m10_exit_pipeline_imp_U2EIQA
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m10e_0 m10_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m10_nodes_imp_8KGLDU
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m10arn_0 m10_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m10awn_0 m10_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m10bn_0 m10_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m10rn_0 m10_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m10wn_0 m10_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m11_exit_pipeline_imp_Y95ZMA
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m11e_0 m11_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m11_nodes_imp_10LTOAC
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m11arn_0 m11_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m11awn_0 m11_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m11bn_0 m11_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m11rn_0 m11_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m11wn_0 m11_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m12_exit_pipeline_imp_IBQ76A
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m12e_0 m12_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m12_nodes_imp_1YWPOMN
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m12arn_0 m12_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m12awn_0 m12_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m12bn_0 m12_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m12rn_0 m12_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m12wn_0 m12_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m13_exit_pipeline_imp_NMGQOI
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m13e_0 m13_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m13_nodes_imp_RBWW49
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m13arn_0 m13_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m13awn_0 m13_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m13bn_0 m13_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m13rn_0 m13_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m13wn_0 m13_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m14_exit_pipeline_imp_DLC9CI
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m14e_0 m14_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m14_nodes_imp_20XDND
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m14arn_0 m14_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m14awn_0 m14_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m14bn_0 m14_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m14rn_0 m14_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m14wn_0 m14_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module m15_exit_pipeline_imp_B1VKPE
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arburst,
    m_axi_arcache,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_arsize,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awburst,
    m_axi_awcache,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awsize,
    m_axi_awvalid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [32:0]m_axi_araddr;
  output [1:0]m_axi_arburst;
  output [3:0]m_axi_arcache;
  output [3:0]m_axi_arlen;
  output [1:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [2:0]m_axi_arsize;
  output m_axi_arvalid;
  output [32:0]m_axi_awaddr;
  output [1:0]m_axi_awburst;
  output [3:0]m_axi_awcache;
  output [3:0]m_axi_awlen;
  output [1:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [2:0]m_axi_awsize;
  output m_axi_awvalid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output m_axi_wvalid;
  input [32:0]s_axi_araddr;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [1023:0]s_axi_aruser;
  input s_axi_arvalid;
  input [32:0]s_axi_awaddr;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [1023:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [1023:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [1023:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [1023:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [32:0]m_axi_araddr;
  wire [1:0]m_axi_arburst;
  wire [3:0]m_axi_arcache;
  wire [3:0]m_axi_arlen;
  wire [1:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [2:0]m_axi_arsize;
  wire m_axi_arvalid;
  wire [32:0]m_axi_awaddr;
  wire [1:0]m_axi_awburst;
  wire [3:0]m_axi_awcache;
  wire [3:0]m_axi_awlen;
  wire [1:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [2:0]m_axi_awsize;
  wire m_axi_awvalid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire m_axi_wvalid;
  wire [32:0]s_axi_araddr;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [1023:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [32:0]s_axi_awaddr;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [1023:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [1023:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [1023:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [1023:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_m15e_0 m15_exit
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
endmodule

module m15_nodes_imp_16SVGOF
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_axi_aclk,
    m_axi_aresetn,
    s_axi_aclk,
    s_axi_aresetn);
  output [0:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [0:0]M_SC_AR_recv;
  output [0:0]M_SC_AR_req;
  output [0:0]M_SC_AR_send;
  output [0:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [0:0]M_SC_AW_recv;
  output [0:0]M_SC_AW_req;
  output [0:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [0:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [0:0]M_SC_W_recv;
  output [0:0]M_SC_W_req;
  output [0:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [0:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [0:0]S_SC_B_recv;
  input [0:0]S_SC_B_req;
  input [0:0]S_SC_B_send;
  input [0:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [0:0]S_SC_R_recv;
  input [0:0]S_SC_R_req;
  input [0:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_axi_aclk;
  input m_axi_aresetn;
  input s_axi_aclk;
  input s_axi_aresetn;

  wire [0:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [0:0]M_SC_AR_recv;
  wire [0:0]M_SC_AR_req;
  wire [0:0]M_SC_AR_send;
  wire [0:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [0:0]M_SC_AW_recv;
  wire [0:0]M_SC_AW_req;
  wire [0:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [0:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [0:0]M_SC_W_recv;
  wire [0:0]M_SC_W_req;
  wire [0:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [0:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [0:0]S_SC_B_recv;
  wire [0:0]S_SC_B_req;
  wire [0:0]S_SC_B_send;
  wire [0:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [0:0]S_SC_R_recv;
  wire [0:0]S_SC_R_req;
  wire [0:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_axi_aclk;
  wire m_axi_aresetn;
  wire s_axi_aclk;
  wire s_axi_aresetn;

  bd_87e8_m15arn_0 m15_ar_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_m15awn_0 m15_aw_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_m15bn_0 m15_b_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_m15rn_0 m15_r_node
       (.m_sc_aclk(s_axi_aclk),
        .m_sc_aresetn(s_axi_aresetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_axi_aclk),
        .s_sc_aresetn(m_axi_aresetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_m15wn_0 m15_w_node
       (.m_sc_aclk(m_axi_aclk),
        .m_sc_aresetn(m_axi_aresetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_axi_aclk),
        .s_sc_aresetn(s_axi_aresetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module s00_entry_pipeline_imp_W6YIYT
   (aclk,
    aresetn,
    m_axi_araddr,
    m_axi_arcache,
    m_axi_arid,
    m_axi_arlen,
    m_axi_arlock,
    m_axi_arprot,
    m_axi_arqos,
    m_axi_arready,
    m_axi_aruser,
    m_axi_arvalid,
    m_axi_awaddr,
    m_axi_awcache,
    m_axi_awid,
    m_axi_awlen,
    m_axi_awlock,
    m_axi_awprot,
    m_axi_awqos,
    m_axi_awready,
    m_axi_awuser,
    m_axi_awvalid,
    m_axi_bid,
    m_axi_bready,
    m_axi_bresp,
    m_axi_buser,
    m_axi_bvalid,
    m_axi_rdata,
    m_axi_rid,
    m_axi_rlast,
    m_axi_rready,
    m_axi_rresp,
    m_axi_ruser,
    m_axi_rvalid,
    m_axi_wdata,
    m_axi_wlast,
    m_axi_wready,
    m_axi_wstrb,
    m_axi_wuser,
    m_axi_wvalid,
    s_axi_araddr,
    s_axi_arburst,
    s_axi_arcache,
    s_axi_arid,
    s_axi_arlen,
    s_axi_arlock,
    s_axi_arprot,
    s_axi_arqos,
    s_axi_arready,
    s_axi_arsize,
    s_axi_aruser,
    s_axi_arvalid,
    s_axi_awaddr,
    s_axi_awburst,
    s_axi_awcache,
    s_axi_awid,
    s_axi_awlen,
    s_axi_awlock,
    s_axi_awprot,
    s_axi_awqos,
    s_axi_awready,
    s_axi_awsize,
    s_axi_awuser,
    s_axi_awvalid,
    s_axi_bid,
    s_axi_bready,
    s_axi_bresp,
    s_axi_buser,
    s_axi_bvalid,
    s_axi_rdata,
    s_axi_rid,
    s_axi_rlast,
    s_axi_rready,
    s_axi_rresp,
    s_axi_ruser,
    s_axi_rvalid,
    s_axi_wdata,
    s_axi_wlast,
    s_axi_wready,
    s_axi_wstrb,
    s_axi_wuser,
    s_axi_wvalid);
  input aclk;
  input aresetn;
  output [63:0]m_axi_araddr;
  output [3:0]m_axi_arcache;
  output [2:0]m_axi_arid;
  output [7:0]m_axi_arlen;
  output [0:0]m_axi_arlock;
  output [2:0]m_axi_arprot;
  output [3:0]m_axi_arqos;
  input m_axi_arready;
  output [1023:0]m_axi_aruser;
  output m_axi_arvalid;
  output [63:0]m_axi_awaddr;
  output [3:0]m_axi_awcache;
  output [2:0]m_axi_awid;
  output [7:0]m_axi_awlen;
  output [0:0]m_axi_awlock;
  output [2:0]m_axi_awprot;
  output [3:0]m_axi_awqos;
  input m_axi_awready;
  output [1023:0]m_axi_awuser;
  output m_axi_awvalid;
  input [2:0]m_axi_bid;
  output m_axi_bready;
  input [1:0]m_axi_bresp;
  input [1023:0]m_axi_buser;
  input m_axi_bvalid;
  input [255:0]m_axi_rdata;
  input [2:0]m_axi_rid;
  input m_axi_rlast;
  output m_axi_rready;
  input [1:0]m_axi_rresp;
  input [1023:0]m_axi_ruser;
  input m_axi_rvalid;
  output [255:0]m_axi_wdata;
  output m_axi_wlast;
  input m_axi_wready;
  output [31:0]m_axi_wstrb;
  output [1023:0]m_axi_wuser;
  output m_axi_wvalid;
  input [63:0]s_axi_araddr;
  input [1:0]s_axi_arburst;
  input [3:0]s_axi_arcache;
  input [2:0]s_axi_arid;
  input [7:0]s_axi_arlen;
  input [0:0]s_axi_arlock;
  input [2:0]s_axi_arprot;
  input [3:0]s_axi_arqos;
  output s_axi_arready;
  input [2:0]s_axi_arsize;
  input [113:0]s_axi_aruser;
  input s_axi_arvalid;
  input [63:0]s_axi_awaddr;
  input [1:0]s_axi_awburst;
  input [3:0]s_axi_awcache;
  input [2:0]s_axi_awid;
  input [7:0]s_axi_awlen;
  input [0:0]s_axi_awlock;
  input [2:0]s_axi_awprot;
  input [3:0]s_axi_awqos;
  output s_axi_awready;
  input [2:0]s_axi_awsize;
  input [113:0]s_axi_awuser;
  input s_axi_awvalid;
  output [2:0]s_axi_bid;
  input s_axi_bready;
  output [1:0]s_axi_bresp;
  output [113:0]s_axi_buser;
  output s_axi_bvalid;
  output [255:0]s_axi_rdata;
  output [2:0]s_axi_rid;
  output s_axi_rlast;
  input s_axi_rready;
  output [1:0]s_axi_rresp;
  output [13:0]s_axi_ruser;
  output s_axi_rvalid;
  input [255:0]s_axi_wdata;
  input s_axi_wlast;
  output s_axi_wready;
  input [31:0]s_axi_wstrb;
  input [13:0]s_axi_wuser;
  input s_axi_wvalid;

  wire aclk;
  wire aresetn;
  wire [63:0]m_axi_araddr;
  wire [3:0]m_axi_arcache;
  wire [2:0]m_axi_arid;
  wire [7:0]m_axi_arlen;
  wire [0:0]m_axi_arlock;
  wire [2:0]m_axi_arprot;
  wire [3:0]m_axi_arqos;
  wire m_axi_arready;
  wire [1023:0]m_axi_aruser;
  wire m_axi_arvalid;
  wire [63:0]m_axi_awaddr;
  wire [3:0]m_axi_awcache;
  wire [2:0]m_axi_awid;
  wire [7:0]m_axi_awlen;
  wire [0:0]m_axi_awlock;
  wire [2:0]m_axi_awprot;
  wire [3:0]m_axi_awqos;
  wire m_axi_awready;
  wire [1023:0]m_axi_awuser;
  wire m_axi_awvalid;
  wire [2:0]m_axi_bid;
  wire m_axi_bready;
  wire [1:0]m_axi_bresp;
  wire [1023:0]m_axi_buser;
  wire m_axi_bvalid;
  wire [255:0]m_axi_rdata;
  wire [2:0]m_axi_rid;
  wire m_axi_rlast;
  wire m_axi_rready;
  wire [1:0]m_axi_rresp;
  wire [1023:0]m_axi_ruser;
  wire m_axi_rvalid;
  wire [255:0]m_axi_wdata;
  wire m_axi_wlast;
  wire m_axi_wready;
  wire [31:0]m_axi_wstrb;
  wire [1023:0]m_axi_wuser;
  wire m_axi_wvalid;
  wire [63:0]s00_mmu_M_AXI_ARADDR;
  wire [1:0]s00_mmu_M_AXI_ARBURST;
  wire [3:0]s00_mmu_M_AXI_ARCACHE;
  wire [2:0]s00_mmu_M_AXI_ARID;
  wire [7:0]s00_mmu_M_AXI_ARLEN;
  wire [0:0]s00_mmu_M_AXI_ARLOCK;
  wire [2:0]s00_mmu_M_AXI_ARPROT;
  wire [3:0]s00_mmu_M_AXI_ARQOS;
  wire s00_mmu_M_AXI_ARREADY;
  wire [2:0]s00_mmu_M_AXI_ARSIZE;
  wire [1023:0]s00_mmu_M_AXI_ARUSER;
  wire s00_mmu_M_AXI_ARVALID;
  wire [63:0]s00_mmu_M_AXI_AWADDR;
  wire [1:0]s00_mmu_M_AXI_AWBURST;
  wire [3:0]s00_mmu_M_AXI_AWCACHE;
  wire [2:0]s00_mmu_M_AXI_AWID;
  wire [7:0]s00_mmu_M_AXI_AWLEN;
  wire [0:0]s00_mmu_M_AXI_AWLOCK;
  wire [2:0]s00_mmu_M_AXI_AWPROT;
  wire [3:0]s00_mmu_M_AXI_AWQOS;
  wire s00_mmu_M_AXI_AWREADY;
  wire [2:0]s00_mmu_M_AXI_AWSIZE;
  wire [1023:0]s00_mmu_M_AXI_AWUSER;
  wire s00_mmu_M_AXI_AWVALID;
  wire [2:0]s00_mmu_M_AXI_BID;
  wire s00_mmu_M_AXI_BREADY;
  wire [1:0]s00_mmu_M_AXI_BRESP;
  wire [1023:0]s00_mmu_M_AXI_BUSER;
  wire s00_mmu_M_AXI_BVALID;
  wire [255:0]s00_mmu_M_AXI_RDATA;
  wire [2:0]s00_mmu_M_AXI_RID;
  wire s00_mmu_M_AXI_RLAST;
  wire s00_mmu_M_AXI_RREADY;
  wire [1:0]s00_mmu_M_AXI_RRESP;
  wire [1023:0]s00_mmu_M_AXI_RUSER;
  wire s00_mmu_M_AXI_RVALID;
  wire [255:0]s00_mmu_M_AXI_WDATA;
  wire s00_mmu_M_AXI_WLAST;
  wire s00_mmu_M_AXI_WREADY;
  wire [31:0]s00_mmu_M_AXI_WSTRB;
  wire [1023:0]s00_mmu_M_AXI_WUSER;
  wire s00_mmu_M_AXI_WVALID;
  wire [63:0]s00_transaction_regulator_M_AXI_ARADDR;
  wire [3:0]s00_transaction_regulator_M_AXI_ARCACHE;
  wire [2:0]s00_transaction_regulator_M_AXI_ARID;
  wire [7:0]s00_transaction_regulator_M_AXI_ARLEN;
  wire [0:0]s00_transaction_regulator_M_AXI_ARLOCK;
  wire [2:0]s00_transaction_regulator_M_AXI_ARPROT;
  wire [3:0]s00_transaction_regulator_M_AXI_ARQOS;
  wire s00_transaction_regulator_M_AXI_ARREADY;
  wire [2:0]s00_transaction_regulator_M_AXI_ARSIZE;
  wire [1023:0]s00_transaction_regulator_M_AXI_ARUSER;
  wire s00_transaction_regulator_M_AXI_ARVALID;
  wire [63:0]s00_transaction_regulator_M_AXI_AWADDR;
  wire [3:0]s00_transaction_regulator_M_AXI_AWCACHE;
  wire [2:0]s00_transaction_regulator_M_AXI_AWID;
  wire [7:0]s00_transaction_regulator_M_AXI_AWLEN;
  wire [0:0]s00_transaction_regulator_M_AXI_AWLOCK;
  wire [2:0]s00_transaction_regulator_M_AXI_AWPROT;
  wire [3:0]s00_transaction_regulator_M_AXI_AWQOS;
  wire s00_transaction_regulator_M_AXI_AWREADY;
  wire [2:0]s00_transaction_regulator_M_AXI_AWSIZE;
  wire [1023:0]s00_transaction_regulator_M_AXI_AWUSER;
  wire s00_transaction_regulator_M_AXI_AWVALID;
  wire [2:0]s00_transaction_regulator_M_AXI_BID;
  wire s00_transaction_regulator_M_AXI_BREADY;
  wire [1:0]s00_transaction_regulator_M_AXI_BRESP;
  wire [1023:0]s00_transaction_regulator_M_AXI_BUSER;
  wire s00_transaction_regulator_M_AXI_BVALID;
  wire [255:0]s00_transaction_regulator_M_AXI_RDATA;
  wire [2:0]s00_transaction_regulator_M_AXI_RID;
  wire s00_transaction_regulator_M_AXI_RLAST;
  wire s00_transaction_regulator_M_AXI_RREADY;
  wire [1:0]s00_transaction_regulator_M_AXI_RRESP;
  wire [1023:0]s00_transaction_regulator_M_AXI_RUSER;
  wire s00_transaction_regulator_M_AXI_RVALID;
  wire [255:0]s00_transaction_regulator_M_AXI_WDATA;
  wire s00_transaction_regulator_M_AXI_WLAST;
  wire s00_transaction_regulator_M_AXI_WREADY;
  wire [31:0]s00_transaction_regulator_M_AXI_WSTRB;
  wire [1023:0]s00_transaction_regulator_M_AXI_WUSER;
  wire s00_transaction_regulator_M_AXI_WVALID;
  wire [63:0]s_axi_araddr;
  wire [1:0]s_axi_arburst;
  wire [3:0]s_axi_arcache;
  wire [2:0]s_axi_arid;
  wire [7:0]s_axi_arlen;
  wire [0:0]s_axi_arlock;
  wire [2:0]s_axi_arprot;
  wire [3:0]s_axi_arqos;
  wire s_axi_arready;
  wire [2:0]s_axi_arsize;
  wire [113:0]s_axi_aruser;
  wire s_axi_arvalid;
  wire [63:0]s_axi_awaddr;
  wire [1:0]s_axi_awburst;
  wire [3:0]s_axi_awcache;
  wire [2:0]s_axi_awid;
  wire [7:0]s_axi_awlen;
  wire [0:0]s_axi_awlock;
  wire [2:0]s_axi_awprot;
  wire [3:0]s_axi_awqos;
  wire s_axi_awready;
  wire [2:0]s_axi_awsize;
  wire [113:0]s_axi_awuser;
  wire s_axi_awvalid;
  wire [2:0]s_axi_bid;
  wire s_axi_bready;
  wire [1:0]s_axi_bresp;
  wire [113:0]s_axi_buser;
  wire s_axi_bvalid;
  wire [255:0]s_axi_rdata;
  wire [2:0]s_axi_rid;
  wire s_axi_rlast;
  wire s_axi_rready;
  wire [1:0]s_axi_rresp;
  wire [13:0]s_axi_ruser;
  wire s_axi_rvalid;
  wire [255:0]s_axi_wdata;
  wire s_axi_wlast;
  wire s_axi_wready;
  wire [31:0]s_axi_wstrb;
  wire [13:0]s_axi_wuser;
  wire s_axi_wvalid;

  bd_87e8_s00mmu_0 s00_mmu
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(s00_mmu_M_AXI_ARADDR),
        .m_axi_arburst(s00_mmu_M_AXI_ARBURST),
        .m_axi_arcache(s00_mmu_M_AXI_ARCACHE),
        .m_axi_arid(s00_mmu_M_AXI_ARID),
        .m_axi_arlen(s00_mmu_M_AXI_ARLEN),
        .m_axi_arlock(s00_mmu_M_AXI_ARLOCK),
        .m_axi_arprot(s00_mmu_M_AXI_ARPROT),
        .m_axi_arqos(s00_mmu_M_AXI_ARQOS),
        .m_axi_arready(s00_mmu_M_AXI_ARREADY),
        .m_axi_arsize(s00_mmu_M_AXI_ARSIZE),
        .m_axi_aruser(s00_mmu_M_AXI_ARUSER),
        .m_axi_arvalid(s00_mmu_M_AXI_ARVALID),
        .m_axi_awaddr(s00_mmu_M_AXI_AWADDR),
        .m_axi_awburst(s00_mmu_M_AXI_AWBURST),
        .m_axi_awcache(s00_mmu_M_AXI_AWCACHE),
        .m_axi_awid(s00_mmu_M_AXI_AWID),
        .m_axi_awlen(s00_mmu_M_AXI_AWLEN),
        .m_axi_awlock(s00_mmu_M_AXI_AWLOCK),
        .m_axi_awprot(s00_mmu_M_AXI_AWPROT),
        .m_axi_awqos(s00_mmu_M_AXI_AWQOS),
        .m_axi_awready(s00_mmu_M_AXI_AWREADY),
        .m_axi_awsize(s00_mmu_M_AXI_AWSIZE),
        .m_axi_awuser(s00_mmu_M_AXI_AWUSER),
        .m_axi_awvalid(s00_mmu_M_AXI_AWVALID),
        .m_axi_bid(s00_mmu_M_AXI_BID),
        .m_axi_bready(s00_mmu_M_AXI_BREADY),
        .m_axi_bresp(s00_mmu_M_AXI_BRESP),
        .m_axi_buser(s00_mmu_M_AXI_BUSER),
        .m_axi_bvalid(s00_mmu_M_AXI_BVALID),
        .m_axi_rdata(s00_mmu_M_AXI_RDATA),
        .m_axi_rid(s00_mmu_M_AXI_RID),
        .m_axi_rlast(s00_mmu_M_AXI_RLAST),
        .m_axi_rready(s00_mmu_M_AXI_RREADY),
        .m_axi_rresp(s00_mmu_M_AXI_RRESP),
        .m_axi_ruser(s00_mmu_M_AXI_RUSER),
        .m_axi_rvalid(s00_mmu_M_AXI_RVALID),
        .m_axi_wdata(s00_mmu_M_AXI_WDATA),
        .m_axi_wlast(s00_mmu_M_AXI_WLAST),
        .m_axi_wready(s00_mmu_M_AXI_WREADY),
        .m_axi_wstrb(s00_mmu_M_AXI_WSTRB),
        .m_axi_wuser(s00_mmu_M_AXI_WUSER),
        .m_axi_wvalid(s00_mmu_M_AXI_WVALID),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arcache(s_axi_arcache),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arlock(s_axi_arlock),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arqos(s_axi_arqos),
        .s_axi_arready(s_axi_arready),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_aruser(s_axi_aruser),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awcache(s_axi_awcache),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awlock(s_axi_awlock),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awqos(s_axi_awqos),
        .s_axi_awready(s_axi_awready),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awuser(s_axi_awuser),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_bid(s_axi_bid),
        .s_axi_bready(s_axi_bready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_buser(s_axi_buser),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rready(s_axi_rready),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_ruser(s_axi_ruser),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wready(s_axi_wready),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wuser(s_axi_wuser),
        .s_axi_wvalid(s_axi_wvalid));
  bd_87e8_s00sic_0 s00_si_converter
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arcache(m_axi_arcache),
        .m_axi_arid(m_axi_arid),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arlock(m_axi_arlock),
        .m_axi_arprot(m_axi_arprot),
        .m_axi_arqos(m_axi_arqos),
        .m_axi_arready(m_axi_arready),
        .m_axi_aruser(m_axi_aruser),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awcache(m_axi_awcache),
        .m_axi_awid(m_axi_awid),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awlock(m_axi_awlock),
        .m_axi_awprot(m_axi_awprot),
        .m_axi_awqos(m_axi_awqos),
        .m_axi_awready(m_axi_awready),
        .m_axi_awuser(m_axi_awuser),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_bid(m_axi_bid),
        .m_axi_bready(m_axi_bready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_buser(m_axi_buser),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rid(m_axi_rid),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_ruser(m_axi_ruser),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wuser(m_axi_wuser),
        .m_axi_wvalid(m_axi_wvalid),
        .s_axi_araddr(s00_transaction_regulator_M_AXI_ARADDR),
        .s_axi_arcache(s00_transaction_regulator_M_AXI_ARCACHE),
        .s_axi_arid(s00_transaction_regulator_M_AXI_ARID),
        .s_axi_arlen(s00_transaction_regulator_M_AXI_ARLEN),
        .s_axi_arlock(s00_transaction_regulator_M_AXI_ARLOCK),
        .s_axi_arprot(s00_transaction_regulator_M_AXI_ARPROT),
        .s_axi_arqos(s00_transaction_regulator_M_AXI_ARQOS),
        .s_axi_arready(s00_transaction_regulator_M_AXI_ARREADY),
        .s_axi_arsize(s00_transaction_regulator_M_AXI_ARSIZE),
        .s_axi_aruser(s00_transaction_regulator_M_AXI_ARUSER),
        .s_axi_arvalid(s00_transaction_regulator_M_AXI_ARVALID),
        .s_axi_awaddr(s00_transaction_regulator_M_AXI_AWADDR),
        .s_axi_awcache(s00_transaction_regulator_M_AXI_AWCACHE),
        .s_axi_awid(s00_transaction_regulator_M_AXI_AWID),
        .s_axi_awlen(s00_transaction_regulator_M_AXI_AWLEN),
        .s_axi_awlock(s00_transaction_regulator_M_AXI_AWLOCK),
        .s_axi_awprot(s00_transaction_regulator_M_AXI_AWPROT),
        .s_axi_awqos(s00_transaction_regulator_M_AXI_AWQOS),
        .s_axi_awready(s00_transaction_regulator_M_AXI_AWREADY),
        .s_axi_awsize(s00_transaction_regulator_M_AXI_AWSIZE),
        .s_axi_awuser(s00_transaction_regulator_M_AXI_AWUSER),
        .s_axi_awvalid(s00_transaction_regulator_M_AXI_AWVALID),
        .s_axi_bid(s00_transaction_regulator_M_AXI_BID),
        .s_axi_bready(s00_transaction_regulator_M_AXI_BREADY),
        .s_axi_bresp(s00_transaction_regulator_M_AXI_BRESP),
        .s_axi_buser(s00_transaction_regulator_M_AXI_BUSER),
        .s_axi_bvalid(s00_transaction_regulator_M_AXI_BVALID),
        .s_axi_rdata(s00_transaction_regulator_M_AXI_RDATA),
        .s_axi_rid(s00_transaction_regulator_M_AXI_RID),
        .s_axi_rlast(s00_transaction_regulator_M_AXI_RLAST),
        .s_axi_rready(s00_transaction_regulator_M_AXI_RREADY),
        .s_axi_rresp(s00_transaction_regulator_M_AXI_RRESP),
        .s_axi_ruser(s00_transaction_regulator_M_AXI_RUSER),
        .s_axi_rvalid(s00_transaction_regulator_M_AXI_RVALID),
        .s_axi_wdata(s00_transaction_regulator_M_AXI_WDATA),
        .s_axi_wlast(s00_transaction_regulator_M_AXI_WLAST),
        .s_axi_wready(s00_transaction_regulator_M_AXI_WREADY),
        .s_axi_wstrb(s00_transaction_regulator_M_AXI_WSTRB),
        .s_axi_wuser(s00_transaction_regulator_M_AXI_WUSER),
        .s_axi_wvalid(s00_transaction_regulator_M_AXI_WVALID));
  bd_87e8_s00tr_0 s00_transaction_regulator
       (.aclk(aclk),
        .aresetn(aresetn),
        .m_axi_araddr(s00_transaction_regulator_M_AXI_ARADDR),
        .m_axi_arcache(s00_transaction_regulator_M_AXI_ARCACHE),
        .m_axi_arid(s00_transaction_regulator_M_AXI_ARID),
        .m_axi_arlen(s00_transaction_regulator_M_AXI_ARLEN),
        .m_axi_arlock(s00_transaction_regulator_M_AXI_ARLOCK),
        .m_axi_arprot(s00_transaction_regulator_M_AXI_ARPROT),
        .m_axi_arqos(s00_transaction_regulator_M_AXI_ARQOS),
        .m_axi_arready(s00_transaction_regulator_M_AXI_ARREADY),
        .m_axi_arsize(s00_transaction_regulator_M_AXI_ARSIZE),
        .m_axi_aruser(s00_transaction_regulator_M_AXI_ARUSER),
        .m_axi_arvalid(s00_transaction_regulator_M_AXI_ARVALID),
        .m_axi_awaddr(s00_transaction_regulator_M_AXI_AWADDR),
        .m_axi_awcache(s00_transaction_regulator_M_AXI_AWCACHE),
        .m_axi_awid(s00_transaction_regulator_M_AXI_AWID),
        .m_axi_awlen(s00_transaction_regulator_M_AXI_AWLEN),
        .m_axi_awlock(s00_transaction_regulator_M_AXI_AWLOCK),
        .m_axi_awprot(s00_transaction_regulator_M_AXI_AWPROT),
        .m_axi_awqos(s00_transaction_regulator_M_AXI_AWQOS),
        .m_axi_awready(s00_transaction_regulator_M_AXI_AWREADY),
        .m_axi_awsize(s00_transaction_regulator_M_AXI_AWSIZE),
        .m_axi_awuser(s00_transaction_regulator_M_AXI_AWUSER),
        .m_axi_awvalid(s00_transaction_regulator_M_AXI_AWVALID),
        .m_axi_bid(s00_transaction_regulator_M_AXI_BID),
        .m_axi_bready(s00_transaction_regulator_M_AXI_BREADY),
        .m_axi_bresp(s00_transaction_regulator_M_AXI_BRESP),
        .m_axi_buser(s00_transaction_regulator_M_AXI_BUSER),
        .m_axi_bvalid(s00_transaction_regulator_M_AXI_BVALID),
        .m_axi_rdata(s00_transaction_regulator_M_AXI_RDATA),
        .m_axi_rid(s00_transaction_regulator_M_AXI_RID),
        .m_axi_rlast(s00_transaction_regulator_M_AXI_RLAST),
        .m_axi_rready(s00_transaction_regulator_M_AXI_RREADY),
        .m_axi_rresp(s00_transaction_regulator_M_AXI_RRESP),
        .m_axi_ruser(s00_transaction_regulator_M_AXI_RUSER),
        .m_axi_rvalid(s00_transaction_regulator_M_AXI_RVALID),
        .m_axi_wdata(s00_transaction_regulator_M_AXI_WDATA),
        .m_axi_wlast(s00_transaction_regulator_M_AXI_WLAST),
        .m_axi_wready(s00_transaction_regulator_M_AXI_WREADY),
        .m_axi_wstrb(s00_transaction_regulator_M_AXI_WSTRB),
        .m_axi_wuser(s00_transaction_regulator_M_AXI_WUSER),
        .m_axi_wvalid(s00_transaction_regulator_M_AXI_WVALID),
        .s_axi_araddr(s00_mmu_M_AXI_ARADDR),
        .s_axi_arburst(s00_mmu_M_AXI_ARBURST),
        .s_axi_arcache(s00_mmu_M_AXI_ARCACHE),
        .s_axi_arid(s00_mmu_M_AXI_ARID),
        .s_axi_arlen(s00_mmu_M_AXI_ARLEN),
        .s_axi_arlock(s00_mmu_M_AXI_ARLOCK),
        .s_axi_arprot(s00_mmu_M_AXI_ARPROT),
        .s_axi_arqos(s00_mmu_M_AXI_ARQOS),
        .s_axi_arready(s00_mmu_M_AXI_ARREADY),
        .s_axi_arsize(s00_mmu_M_AXI_ARSIZE),
        .s_axi_aruser(s00_mmu_M_AXI_ARUSER),
        .s_axi_arvalid(s00_mmu_M_AXI_ARVALID),
        .s_axi_awaddr(s00_mmu_M_AXI_AWADDR),
        .s_axi_awburst(s00_mmu_M_AXI_AWBURST),
        .s_axi_awcache(s00_mmu_M_AXI_AWCACHE),
        .s_axi_awid(s00_mmu_M_AXI_AWID),
        .s_axi_awlen(s00_mmu_M_AXI_AWLEN),
        .s_axi_awlock(s00_mmu_M_AXI_AWLOCK),
        .s_axi_awprot(s00_mmu_M_AXI_AWPROT),
        .s_axi_awqos(s00_mmu_M_AXI_AWQOS),
        .s_axi_awready(s00_mmu_M_AXI_AWREADY),
        .s_axi_awsize(s00_mmu_M_AXI_AWSIZE),
        .s_axi_awuser(s00_mmu_M_AXI_AWUSER),
        .s_axi_awvalid(s00_mmu_M_AXI_AWVALID),
        .s_axi_bid(s00_mmu_M_AXI_BID),
        .s_axi_bready(s00_mmu_M_AXI_BREADY),
        .s_axi_bresp(s00_mmu_M_AXI_BRESP),
        .s_axi_buser(s00_mmu_M_AXI_BUSER),
        .s_axi_bvalid(s00_mmu_M_AXI_BVALID),
        .s_axi_rdata(s00_mmu_M_AXI_RDATA),
        .s_axi_rid(s00_mmu_M_AXI_RID),
        .s_axi_rlast(s00_mmu_M_AXI_RLAST),
        .s_axi_rready(s00_mmu_M_AXI_RREADY),
        .s_axi_rresp(s00_mmu_M_AXI_RRESP),
        .s_axi_ruser(s00_mmu_M_AXI_RUSER),
        .s_axi_rvalid(s00_mmu_M_AXI_RVALID),
        .s_axi_wdata(s00_mmu_M_AXI_WDATA),
        .s_axi_wlast(s00_mmu_M_AXI_WLAST),
        .s_axi_wready(s00_mmu_M_AXI_WREADY),
        .s_axi_wstrb(s00_mmu_M_AXI_WSTRB),
        .s_axi_wuser(s00_mmu_M_AXI_WUSER),
        .s_axi_wvalid(s00_mmu_M_AXI_WVALID));
endmodule

module s00_nodes_imp_R4DQJJ
   (M_SC_AR_info,
    M_SC_AR_payld,
    M_SC_AR_recv,
    M_SC_AR_req,
    M_SC_AR_send,
    M_SC_AW_info,
    M_SC_AW_payld,
    M_SC_AW_recv,
    M_SC_AW_req,
    M_SC_AW_send,
    M_SC_B_info,
    M_SC_B_payld,
    M_SC_B_recv,
    M_SC_B_req,
    M_SC_B_send,
    M_SC_R_info,
    M_SC_R_payld,
    M_SC_R_recv,
    M_SC_R_req,
    M_SC_R_send,
    M_SC_W_info,
    M_SC_W_payld,
    M_SC_W_recv,
    M_SC_W_req,
    M_SC_W_send,
    S_SC_AR_info,
    S_SC_AR_payld,
    S_SC_AR_recv,
    S_SC_AR_req,
    S_SC_AR_send,
    S_SC_AW_info,
    S_SC_AW_payld,
    S_SC_AW_recv,
    S_SC_AW_req,
    S_SC_AW_send,
    S_SC_B_info,
    S_SC_B_payld,
    S_SC_B_recv,
    S_SC_B_req,
    S_SC_B_send,
    S_SC_R_info,
    S_SC_R_payld,
    S_SC_R_recv,
    S_SC_R_req,
    S_SC_R_send,
    S_SC_W_info,
    S_SC_W_payld,
    S_SC_W_recv,
    S_SC_W_req,
    S_SC_W_send,
    m_sc_clk,
    m_sc_resetn,
    s_sc_clk,
    s_sc_resetn);
  output [15:0]M_SC_AR_info;
  output [301:0]M_SC_AR_payld;
  input [15:0]M_SC_AR_recv;
  output [15:0]M_SC_AR_req;
  output [15:0]M_SC_AR_send;
  output [15:0]M_SC_AW_info;
  output [301:0]M_SC_AW_payld;
  input [15:0]M_SC_AW_recv;
  output [15:0]M_SC_AW_req;
  output [15:0]M_SC_AW_send;
  output [0:0]M_SC_B_info;
  output [119:0]M_SC_B_payld;
  input [0:0]M_SC_B_recv;
  output [0:0]M_SC_B_req;
  output [0:0]M_SC_B_send;
  output [0:0]M_SC_R_info;
  output [276:0]M_SC_R_payld;
  input [0:0]M_SC_R_recv;
  output [0:0]M_SC_R_req;
  output [0:0]M_SC_R_send;
  output [15:0]M_SC_W_info;
  output [318:0]M_SC_W_payld;
  input [15:0]M_SC_W_recv;
  output [15:0]M_SC_W_req;
  output [15:0]M_SC_W_send;
  input [0:0]S_SC_AR_info;
  input [301:0]S_SC_AR_payld;
  output [0:0]S_SC_AR_recv;
  input [0:0]S_SC_AR_req;
  input [0:0]S_SC_AR_send;
  input [0:0]S_SC_AW_info;
  input [301:0]S_SC_AW_payld;
  output [0:0]S_SC_AW_recv;
  input [0:0]S_SC_AW_req;
  input [0:0]S_SC_AW_send;
  input [15:0]S_SC_B_info;
  input [119:0]S_SC_B_payld;
  output [15:0]S_SC_B_recv;
  input [15:0]S_SC_B_req;
  input [15:0]S_SC_B_send;
  input [15:0]S_SC_R_info;
  input [276:0]S_SC_R_payld;
  output [15:0]S_SC_R_recv;
  input [15:0]S_SC_R_req;
  input [15:0]S_SC_R_send;
  input [0:0]S_SC_W_info;
  input [318:0]S_SC_W_payld;
  output [0:0]S_SC_W_recv;
  input [0:0]S_SC_W_req;
  input [0:0]S_SC_W_send;
  input m_sc_clk;
  input m_sc_resetn;
  input s_sc_clk;
  input s_sc_resetn;

  wire [15:0]M_SC_AR_info;
  wire [301:0]M_SC_AR_payld;
  wire [15:0]M_SC_AR_recv;
  wire [15:0]M_SC_AR_req;
  wire [15:0]M_SC_AR_send;
  wire [15:0]M_SC_AW_info;
  wire [301:0]M_SC_AW_payld;
  wire [15:0]M_SC_AW_recv;
  wire [15:0]M_SC_AW_req;
  wire [15:0]M_SC_AW_send;
  wire [0:0]M_SC_B_info;
  wire [119:0]M_SC_B_payld;
  wire [0:0]M_SC_B_recv;
  wire [0:0]M_SC_B_req;
  wire [0:0]M_SC_B_send;
  wire [0:0]M_SC_R_info;
  wire [276:0]M_SC_R_payld;
  wire [0:0]M_SC_R_recv;
  wire [0:0]M_SC_R_req;
  wire [0:0]M_SC_R_send;
  wire [15:0]M_SC_W_info;
  wire [318:0]M_SC_W_payld;
  wire [15:0]M_SC_W_recv;
  wire [15:0]M_SC_W_req;
  wire [15:0]M_SC_W_send;
  wire [0:0]S_SC_AR_info;
  wire [301:0]S_SC_AR_payld;
  wire [0:0]S_SC_AR_recv;
  wire [0:0]S_SC_AR_req;
  wire [0:0]S_SC_AR_send;
  wire [0:0]S_SC_AW_info;
  wire [301:0]S_SC_AW_payld;
  wire [0:0]S_SC_AW_recv;
  wire [0:0]S_SC_AW_req;
  wire [0:0]S_SC_AW_send;
  wire [15:0]S_SC_B_info;
  wire [119:0]S_SC_B_payld;
  wire [15:0]S_SC_B_recv;
  wire [15:0]S_SC_B_req;
  wire [15:0]S_SC_B_send;
  wire [15:0]S_SC_R_info;
  wire [276:0]S_SC_R_payld;
  wire [15:0]S_SC_R_recv;
  wire [15:0]S_SC_R_req;
  wire [15:0]S_SC_R_send;
  wire [0:0]S_SC_W_info;
  wire [318:0]S_SC_W_payld;
  wire [0:0]S_SC_W_recv;
  wire [0:0]S_SC_W_req;
  wire [0:0]S_SC_W_send;
  wire m_sc_clk;
  wire m_sc_resetn;
  wire s_sc_clk;
  wire s_sc_resetn;

  bd_87e8_sarn_0 s00_ar_node
       (.m_sc_aclk(m_sc_clk),
        .m_sc_aresetn(m_sc_resetn),
        .m_sc_info(M_SC_AR_info),
        .m_sc_payld(M_SC_AR_payld),
        .m_sc_recv(M_SC_AR_recv),
        .m_sc_req(M_SC_AR_req),
        .m_sc_send(M_SC_AR_send),
        .s_sc_aclk(s_sc_clk),
        .s_sc_aresetn(s_sc_resetn),
        .s_sc_info(S_SC_AR_info),
        .s_sc_payld(S_SC_AR_payld),
        .s_sc_recv(S_SC_AR_recv),
        .s_sc_req(S_SC_AR_req),
        .s_sc_send(S_SC_AR_send));
  bd_87e8_sawn_0 s00_aw_node
       (.m_sc_aclk(m_sc_clk),
        .m_sc_aresetn(m_sc_resetn),
        .m_sc_info(M_SC_AW_info),
        .m_sc_payld(M_SC_AW_payld),
        .m_sc_recv(M_SC_AW_recv),
        .m_sc_req(M_SC_AW_req),
        .m_sc_send(M_SC_AW_send),
        .s_sc_aclk(s_sc_clk),
        .s_sc_aresetn(s_sc_resetn),
        .s_sc_info(S_SC_AW_info),
        .s_sc_payld(S_SC_AW_payld),
        .s_sc_recv(S_SC_AW_recv),
        .s_sc_req(S_SC_AW_req),
        .s_sc_send(S_SC_AW_send));
  bd_87e8_sbn_0 s00_b_node
       (.m_sc_aclk(s_sc_clk),
        .m_sc_aresetn(s_sc_resetn),
        .m_sc_info(M_SC_B_info),
        .m_sc_payld(M_SC_B_payld),
        .m_sc_recv(M_SC_B_recv),
        .m_sc_req(M_SC_B_req),
        .m_sc_send(M_SC_B_send),
        .s_sc_aclk(m_sc_clk),
        .s_sc_aresetn(m_sc_resetn),
        .s_sc_info(S_SC_B_info),
        .s_sc_payld(S_SC_B_payld),
        .s_sc_recv(S_SC_B_recv),
        .s_sc_req(S_SC_B_req),
        .s_sc_send(S_SC_B_send));
  bd_87e8_srn_0 s00_r_node
       (.m_sc_aclk(s_sc_clk),
        .m_sc_aresetn(s_sc_resetn),
        .m_sc_info(M_SC_R_info),
        .m_sc_payld(M_SC_R_payld),
        .m_sc_recv(M_SC_R_recv),
        .m_sc_req(M_SC_R_req),
        .m_sc_send(M_SC_R_send),
        .s_sc_aclk(m_sc_clk),
        .s_sc_aresetn(m_sc_resetn),
        .s_sc_info(S_SC_R_info),
        .s_sc_payld(S_SC_R_payld),
        .s_sc_recv(S_SC_R_recv),
        .s_sc_req(S_SC_R_req),
        .s_sc_send(S_SC_R_send));
  bd_87e8_swn_0 s00_w_node
       (.m_sc_aclk(m_sc_clk),
        .m_sc_aresetn(m_sc_resetn),
        .m_sc_info(M_SC_W_info),
        .m_sc_payld(M_SC_W_payld),
        .m_sc_recv(M_SC_W_recv),
        .m_sc_req(M_SC_W_req),
        .m_sc_send(M_SC_W_send),
        .s_sc_aclk(s_sc_clk),
        .s_sc_aresetn(s_sc_resetn),
        .s_sc_info(S_SC_W_info),
        .s_sc_payld(S_SC_W_payld),
        .s_sc_recv(S_SC_W_recv),
        .s_sc_req(S_SC_W_req),
        .s_sc_send(S_SC_W_send));
endmodule

module switchboards_imp_2UP7YJ
   (M00_SC_AR_info,
    M00_SC_AR_payld,
    M00_SC_AR_recv,
    M00_SC_AR_req,
    M00_SC_AR_send,
    M00_SC_AW_info,
    M00_SC_AW_payld,
    M00_SC_AW_recv,
    M00_SC_AW_req,
    M00_SC_AW_send,
    M00_SC_B_info,
    M00_SC_B_payld,
    M00_SC_B_recv,
    M00_SC_B_req,
    M00_SC_B_send,
    M00_SC_R_info,
    M00_SC_R_payld,
    M00_SC_R_recv,
    M00_SC_R_req,
    M00_SC_R_send,
    M00_SC_W_info,
    M00_SC_W_payld,
    M00_SC_W_recv,
    M00_SC_W_req,
    M00_SC_W_send,
    M01_SC_AR_info,
    M01_SC_AR_payld,
    M01_SC_AR_recv,
    M01_SC_AR_req,
    M01_SC_AR_send,
    M01_SC_AW_info,
    M01_SC_AW_payld,
    M01_SC_AW_recv,
    M01_SC_AW_req,
    M01_SC_AW_send,
    M01_SC_W_info,
    M01_SC_W_payld,
    M01_SC_W_recv,
    M01_SC_W_req,
    M01_SC_W_send,
    M02_SC_AR_info,
    M02_SC_AR_payld,
    M02_SC_AR_recv,
    M02_SC_AR_req,
    M02_SC_AR_send,
    M02_SC_AW_info,
    M02_SC_AW_payld,
    M02_SC_AW_recv,
    M02_SC_AW_req,
    M02_SC_AW_send,
    M02_SC_W_info,
    M02_SC_W_payld,
    M02_SC_W_recv,
    M02_SC_W_req,
    M02_SC_W_send,
    M03_SC_AR_info,
    M03_SC_AR_payld,
    M03_SC_AR_recv,
    M03_SC_AR_req,
    M03_SC_AR_send,
    M03_SC_AW_info,
    M03_SC_AW_payld,
    M03_SC_AW_recv,
    M03_SC_AW_req,
    M03_SC_AW_send,
    M03_SC_W_info,
    M03_SC_W_payld,
    M03_SC_W_recv,
    M03_SC_W_req,
    M03_SC_W_send,
    M04_SC_AR_info,
    M04_SC_AR_payld,
    M04_SC_AR_recv,
    M04_SC_AR_req,
    M04_SC_AR_send,
    M04_SC_AW_info,
    M04_SC_AW_payld,
    M04_SC_AW_recv,
    M04_SC_AW_req,
    M04_SC_AW_send,
    M04_SC_W_info,
    M04_SC_W_payld,
    M04_SC_W_recv,
    M04_SC_W_req,
    M04_SC_W_send,
    M05_SC_AR_info,
    M05_SC_AR_payld,
    M05_SC_AR_recv,
    M05_SC_AR_req,
    M05_SC_AR_send,
    M05_SC_AW_info,
    M05_SC_AW_payld,
    M05_SC_AW_recv,
    M05_SC_AW_req,
    M05_SC_AW_send,
    M05_SC_W_info,
    M05_SC_W_payld,
    M05_SC_W_recv,
    M05_SC_W_req,
    M05_SC_W_send,
    M06_SC_AR_info,
    M06_SC_AR_payld,
    M06_SC_AR_recv,
    M06_SC_AR_req,
    M06_SC_AR_send,
    M06_SC_AW_info,
    M06_SC_AW_payld,
    M06_SC_AW_recv,
    M06_SC_AW_req,
    M06_SC_AW_send,
    M06_SC_W_info,
    M06_SC_W_payld,
    M06_SC_W_recv,
    M06_SC_W_req,
    M06_SC_W_send,
    M07_SC_AR_info,
    M07_SC_AR_payld,
    M07_SC_AR_recv,
    M07_SC_AR_req,
    M07_SC_AR_send,
    M07_SC_AW_info,
    M07_SC_AW_payld,
    M07_SC_AW_recv,
    M07_SC_AW_req,
    M07_SC_AW_send,
    M07_SC_W_info,
    M07_SC_W_payld,
    M07_SC_W_recv,
    M07_SC_W_req,
    M07_SC_W_send,
    M08_SC_AR_info,
    M08_SC_AR_payld,
    M08_SC_AR_recv,
    M08_SC_AR_req,
    M08_SC_AR_send,
    M08_SC_AW_info,
    M08_SC_AW_payld,
    M08_SC_AW_recv,
    M08_SC_AW_req,
    M08_SC_AW_send,
    M08_SC_W_info,
    M08_SC_W_payld,
    M08_SC_W_recv,
    M08_SC_W_req,
    M08_SC_W_send,
    M09_SC_AR_info,
    M09_SC_AR_payld,
    M09_SC_AR_recv,
    M09_SC_AR_req,
    M09_SC_AR_send,
    M09_SC_AW_info,
    M09_SC_AW_payld,
    M09_SC_AW_recv,
    M09_SC_AW_req,
    M09_SC_AW_send,
    M09_SC_W_info,
    M09_SC_W_payld,
    M09_SC_W_recv,
    M09_SC_W_req,
    M09_SC_W_send,
    M10_SC_AR_info,
    M10_SC_AR_payld,
    M10_SC_AR_recv,
    M10_SC_AR_req,
    M10_SC_AR_send,
    M10_SC_AW_info,
    M10_SC_AW_payld,
    M10_SC_AW_recv,
    M10_SC_AW_req,
    M10_SC_AW_send,
    M10_SC_W_info,
    M10_SC_W_payld,
    M10_SC_W_recv,
    M10_SC_W_req,
    M10_SC_W_send,
    M11_SC_AR_info,
    M11_SC_AR_payld,
    M11_SC_AR_recv,
    M11_SC_AR_req,
    M11_SC_AR_send,
    M11_SC_AW_info,
    M11_SC_AW_payld,
    M11_SC_AW_recv,
    M11_SC_AW_req,
    M11_SC_AW_send,
    M11_SC_W_info,
    M11_SC_W_payld,
    M11_SC_W_recv,
    M11_SC_W_req,
    M11_SC_W_send,
    M12_SC_AR_info,
    M12_SC_AR_payld,
    M12_SC_AR_recv,
    M12_SC_AR_req,
    M12_SC_AR_send,
    M12_SC_AW_info,
    M12_SC_AW_payld,
    M12_SC_AW_recv,
    M12_SC_AW_req,
    M12_SC_AW_send,
    M12_SC_W_info,
    M12_SC_W_payld,
    M12_SC_W_recv,
    M12_SC_W_req,
    M12_SC_W_send,
    M13_SC_AR_info,
    M13_SC_AR_payld,
    M13_SC_AR_recv,
    M13_SC_AR_req,
    M13_SC_AR_send,
    M13_SC_AW_info,
    M13_SC_AW_payld,
    M13_SC_AW_recv,
    M13_SC_AW_req,
    M13_SC_AW_send,
    M13_SC_W_info,
    M13_SC_W_payld,
    M13_SC_W_recv,
    M13_SC_W_req,
    M13_SC_W_send,
    M14_SC_AR_info,
    M14_SC_AR_payld,
    M14_SC_AR_recv,
    M14_SC_AR_req,
    M14_SC_AR_send,
    M14_SC_AW_info,
    M14_SC_AW_payld,
    M14_SC_AW_recv,
    M14_SC_AW_req,
    M14_SC_AW_send,
    M14_SC_W_info,
    M14_SC_W_payld,
    M14_SC_W_recv,
    M14_SC_W_req,
    M14_SC_W_send,
    M15_SC_AR_info,
    M15_SC_AR_payld,
    M15_SC_AR_recv,
    M15_SC_AR_req,
    M15_SC_AR_send,
    M15_SC_AW_info,
    M15_SC_AW_payld,
    M15_SC_AW_recv,
    M15_SC_AW_req,
    M15_SC_AW_send,
    M15_SC_W_info,
    M15_SC_W_payld,
    M15_SC_W_recv,
    M15_SC_W_req,
    M15_SC_W_send,
    S00_SC_AR_info,
    S00_SC_AR_payld,
    S00_SC_AR_recv,
    S00_SC_AR_req,
    S00_SC_AR_send,
    S00_SC_AW_info,
    S00_SC_AW_payld,
    S00_SC_AW_recv,
    S00_SC_AW_req,
    S00_SC_AW_send,
    S00_SC_B_info,
    S00_SC_B_payld,
    S00_SC_B_recv,
    S00_SC_B_req,
    S00_SC_B_send,
    S00_SC_R_info,
    S00_SC_R_payld,
    S00_SC_R_recv,
    S00_SC_R_req,
    S00_SC_R_send,
    S00_SC_W_info,
    S00_SC_W_payld,
    S00_SC_W_recv,
    S00_SC_W_req,
    S00_SC_W_send,
    S01_SC_B_info,
    S01_SC_B_payld,
    S01_SC_B_recv,
    S01_SC_B_req,
    S01_SC_B_send,
    S01_SC_R_info,
    S01_SC_R_payld,
    S01_SC_R_recv,
    S01_SC_R_req,
    S01_SC_R_send,
    S02_SC_B_info,
    S02_SC_B_payld,
    S02_SC_B_recv,
    S02_SC_B_req,
    S02_SC_B_send,
    S02_SC_R_info,
    S02_SC_R_payld,
    S02_SC_R_recv,
    S02_SC_R_req,
    S02_SC_R_send,
    S03_SC_B_info,
    S03_SC_B_payld,
    S03_SC_B_recv,
    S03_SC_B_req,
    S03_SC_B_send,
    S03_SC_R_info,
    S03_SC_R_payld,
    S03_SC_R_recv,
    S03_SC_R_req,
    S03_SC_R_send,
    S04_SC_B_info,
    S04_SC_B_payld,
    S04_SC_B_recv,
    S04_SC_B_req,
    S04_SC_B_send,
    S04_SC_R_info,
    S04_SC_R_payld,
    S04_SC_R_recv,
    S04_SC_R_req,
    S04_SC_R_send,
    S05_SC_B_info,
    S05_SC_B_payld,
    S05_SC_B_recv,
    S05_SC_B_req,
    S05_SC_B_send,
    S05_SC_R_info,
    S05_SC_R_payld,
    S05_SC_R_recv,
    S05_SC_R_req,
    S05_SC_R_send,
    S06_SC_B_info,
    S06_SC_B_payld,
    S06_SC_B_recv,
    S06_SC_B_req,
    S06_SC_B_send,
    S06_SC_R_info,
    S06_SC_R_payld,
    S06_SC_R_recv,
    S06_SC_R_req,
    S06_SC_R_send,
    S07_SC_B_info,
    S07_SC_B_payld,
    S07_SC_B_recv,
    S07_SC_B_req,
    S07_SC_B_send,
    S07_SC_R_info,
    S07_SC_R_payld,
    S07_SC_R_recv,
    S07_SC_R_req,
    S07_SC_R_send,
    S08_SC_B_info,
    S08_SC_B_payld,
    S08_SC_B_recv,
    S08_SC_B_req,
    S08_SC_B_send,
    S08_SC_R_info,
    S08_SC_R_payld,
    S08_SC_R_recv,
    S08_SC_R_req,
    S08_SC_R_send,
    S09_SC_B_info,
    S09_SC_B_payld,
    S09_SC_B_recv,
    S09_SC_B_req,
    S09_SC_B_send,
    S09_SC_R_info,
    S09_SC_R_payld,
    S09_SC_R_recv,
    S09_SC_R_req,
    S09_SC_R_send,
    S10_SC_B_info,
    S10_SC_B_payld,
    S10_SC_B_recv,
    S10_SC_B_req,
    S10_SC_B_send,
    S10_SC_R_info,
    S10_SC_R_payld,
    S10_SC_R_recv,
    S10_SC_R_req,
    S10_SC_R_send,
    S11_SC_B_info,
    S11_SC_B_payld,
    S11_SC_B_recv,
    S11_SC_B_req,
    S11_SC_B_send,
    S11_SC_R_info,
    S11_SC_R_payld,
    S11_SC_R_recv,
    S11_SC_R_req,
    S11_SC_R_send,
    S12_SC_B_info,
    S12_SC_B_payld,
    S12_SC_B_recv,
    S12_SC_B_req,
    S12_SC_B_send,
    S12_SC_R_info,
    S12_SC_R_payld,
    S12_SC_R_recv,
    S12_SC_R_req,
    S12_SC_R_send,
    S13_SC_B_info,
    S13_SC_B_payld,
    S13_SC_B_recv,
    S13_SC_B_req,
    S13_SC_B_send,
    S13_SC_R_info,
    S13_SC_R_payld,
    S13_SC_R_recv,
    S13_SC_R_req,
    S13_SC_R_send,
    S14_SC_B_info,
    S14_SC_B_payld,
    S14_SC_B_recv,
    S14_SC_B_req,
    S14_SC_B_send,
    S14_SC_R_info,
    S14_SC_R_payld,
    S14_SC_R_recv,
    S14_SC_R_req,
    S14_SC_R_send,
    S15_SC_B_info,
    S15_SC_B_payld,
    S15_SC_B_recv,
    S15_SC_B_req,
    S15_SC_B_send,
    S15_SC_R_info,
    S15_SC_R_payld,
    S15_SC_R_recv,
    S15_SC_R_req,
    S15_SC_R_send,
    aclk,
    aresetn);
  output [0:0]M00_SC_AR_info;
  output [301:0]M00_SC_AR_payld;
  input [0:0]M00_SC_AR_recv;
  output [0:0]M00_SC_AR_req;
  output [0:0]M00_SC_AR_send;
  output [0:0]M00_SC_AW_info;
  output [301:0]M00_SC_AW_payld;
  input [0:0]M00_SC_AW_recv;
  output [0:0]M00_SC_AW_req;
  output [0:0]M00_SC_AW_send;
  output [15:0]M00_SC_B_info;
  output [119:0]M00_SC_B_payld;
  input [15:0]M00_SC_B_recv;
  output [15:0]M00_SC_B_req;
  output [15:0]M00_SC_B_send;
  output [15:0]M00_SC_R_info;
  output [276:0]M00_SC_R_payld;
  input [15:0]M00_SC_R_recv;
  output [15:0]M00_SC_R_req;
  output [15:0]M00_SC_R_send;
  output [0:0]M00_SC_W_info;
  output [318:0]M00_SC_W_payld;
  input [0:0]M00_SC_W_recv;
  output [0:0]M00_SC_W_req;
  output [0:0]M00_SC_W_send;
  output [0:0]M01_SC_AR_info;
  output [301:0]M01_SC_AR_payld;
  input [0:0]M01_SC_AR_recv;
  output [0:0]M01_SC_AR_req;
  output [0:0]M01_SC_AR_send;
  output [0:0]M01_SC_AW_info;
  output [301:0]M01_SC_AW_payld;
  input [0:0]M01_SC_AW_recv;
  output [0:0]M01_SC_AW_req;
  output [0:0]M01_SC_AW_send;
  output [0:0]M01_SC_W_info;
  output [318:0]M01_SC_W_payld;
  input [0:0]M01_SC_W_recv;
  output [0:0]M01_SC_W_req;
  output [0:0]M01_SC_W_send;
  output [0:0]M02_SC_AR_info;
  output [301:0]M02_SC_AR_payld;
  input [0:0]M02_SC_AR_recv;
  output [0:0]M02_SC_AR_req;
  output [0:0]M02_SC_AR_send;
  output [0:0]M02_SC_AW_info;
  output [301:0]M02_SC_AW_payld;
  input [0:0]M02_SC_AW_recv;
  output [0:0]M02_SC_AW_req;
  output [0:0]M02_SC_AW_send;
  output [0:0]M02_SC_W_info;
  output [318:0]M02_SC_W_payld;
  input [0:0]M02_SC_W_recv;
  output [0:0]M02_SC_W_req;
  output [0:0]M02_SC_W_send;
  output [0:0]M03_SC_AR_info;
  output [301:0]M03_SC_AR_payld;
  input [0:0]M03_SC_AR_recv;
  output [0:0]M03_SC_AR_req;
  output [0:0]M03_SC_AR_send;
  output [0:0]M03_SC_AW_info;
  output [301:0]M03_SC_AW_payld;
  input [0:0]M03_SC_AW_recv;
  output [0:0]M03_SC_AW_req;
  output [0:0]M03_SC_AW_send;
  output [0:0]M03_SC_W_info;
  output [318:0]M03_SC_W_payld;
  input [0:0]M03_SC_W_recv;
  output [0:0]M03_SC_W_req;
  output [0:0]M03_SC_W_send;
  output [0:0]M04_SC_AR_info;
  output [301:0]M04_SC_AR_payld;
  input [0:0]M04_SC_AR_recv;
  output [0:0]M04_SC_AR_req;
  output [0:0]M04_SC_AR_send;
  output [0:0]M04_SC_AW_info;
  output [301:0]M04_SC_AW_payld;
  input [0:0]M04_SC_AW_recv;
  output [0:0]M04_SC_AW_req;
  output [0:0]M04_SC_AW_send;
  output [0:0]M04_SC_W_info;
  output [318:0]M04_SC_W_payld;
  input [0:0]M04_SC_W_recv;
  output [0:0]M04_SC_W_req;
  output [0:0]M04_SC_W_send;
  output [0:0]M05_SC_AR_info;
  output [301:0]M05_SC_AR_payld;
  input [0:0]M05_SC_AR_recv;
  output [0:0]M05_SC_AR_req;
  output [0:0]M05_SC_AR_send;
  output [0:0]M05_SC_AW_info;
  output [301:0]M05_SC_AW_payld;
  input [0:0]M05_SC_AW_recv;
  output [0:0]M05_SC_AW_req;
  output [0:0]M05_SC_AW_send;
  output [0:0]M05_SC_W_info;
  output [318:0]M05_SC_W_payld;
  input [0:0]M05_SC_W_recv;
  output [0:0]M05_SC_W_req;
  output [0:0]M05_SC_W_send;
  output [0:0]M06_SC_AR_info;
  output [301:0]M06_SC_AR_payld;
  input [0:0]M06_SC_AR_recv;
  output [0:0]M06_SC_AR_req;
  output [0:0]M06_SC_AR_send;
  output [0:0]M06_SC_AW_info;
  output [301:0]M06_SC_AW_payld;
  input [0:0]M06_SC_AW_recv;
  output [0:0]M06_SC_AW_req;
  output [0:0]M06_SC_AW_send;
  output [0:0]M06_SC_W_info;
  output [318:0]M06_SC_W_payld;
  input [0:0]M06_SC_W_recv;
  output [0:0]M06_SC_W_req;
  output [0:0]M06_SC_W_send;
  output [0:0]M07_SC_AR_info;
  output [301:0]M07_SC_AR_payld;
  input [0:0]M07_SC_AR_recv;
  output [0:0]M07_SC_AR_req;
  output [0:0]M07_SC_AR_send;
  output [0:0]M07_SC_AW_info;
  output [301:0]M07_SC_AW_payld;
  input [0:0]M07_SC_AW_recv;
  output [0:0]M07_SC_AW_req;
  output [0:0]M07_SC_AW_send;
  output [0:0]M07_SC_W_info;
  output [318:0]M07_SC_W_payld;
  input [0:0]M07_SC_W_recv;
  output [0:0]M07_SC_W_req;
  output [0:0]M07_SC_W_send;
  output [0:0]M08_SC_AR_info;
  output [301:0]M08_SC_AR_payld;
  input [0:0]M08_SC_AR_recv;
  output [0:0]M08_SC_AR_req;
  output [0:0]M08_SC_AR_send;
  output [0:0]M08_SC_AW_info;
  output [301:0]M08_SC_AW_payld;
  input [0:0]M08_SC_AW_recv;
  output [0:0]M08_SC_AW_req;
  output [0:0]M08_SC_AW_send;
  output [0:0]M08_SC_W_info;
  output [318:0]M08_SC_W_payld;
  input [0:0]M08_SC_W_recv;
  output [0:0]M08_SC_W_req;
  output [0:0]M08_SC_W_send;
  output [0:0]M09_SC_AR_info;
  output [301:0]M09_SC_AR_payld;
  input [0:0]M09_SC_AR_recv;
  output [0:0]M09_SC_AR_req;
  output [0:0]M09_SC_AR_send;
  output [0:0]M09_SC_AW_info;
  output [301:0]M09_SC_AW_payld;
  input [0:0]M09_SC_AW_recv;
  output [0:0]M09_SC_AW_req;
  output [0:0]M09_SC_AW_send;
  output [0:0]M09_SC_W_info;
  output [318:0]M09_SC_W_payld;
  input [0:0]M09_SC_W_recv;
  output [0:0]M09_SC_W_req;
  output [0:0]M09_SC_W_send;
  output [0:0]M10_SC_AR_info;
  output [301:0]M10_SC_AR_payld;
  input [0:0]M10_SC_AR_recv;
  output [0:0]M10_SC_AR_req;
  output [0:0]M10_SC_AR_send;
  output [0:0]M10_SC_AW_info;
  output [301:0]M10_SC_AW_payld;
  input [0:0]M10_SC_AW_recv;
  output [0:0]M10_SC_AW_req;
  output [0:0]M10_SC_AW_send;
  output [0:0]M10_SC_W_info;
  output [318:0]M10_SC_W_payld;
  input [0:0]M10_SC_W_recv;
  output [0:0]M10_SC_W_req;
  output [0:0]M10_SC_W_send;
  output [0:0]M11_SC_AR_info;
  output [301:0]M11_SC_AR_payld;
  input [0:0]M11_SC_AR_recv;
  output [0:0]M11_SC_AR_req;
  output [0:0]M11_SC_AR_send;
  output [0:0]M11_SC_AW_info;
  output [301:0]M11_SC_AW_payld;
  input [0:0]M11_SC_AW_recv;
  output [0:0]M11_SC_AW_req;
  output [0:0]M11_SC_AW_send;
  output [0:0]M11_SC_W_info;
  output [318:0]M11_SC_W_payld;
  input [0:0]M11_SC_W_recv;
  output [0:0]M11_SC_W_req;
  output [0:0]M11_SC_W_send;
  output [0:0]M12_SC_AR_info;
  output [301:0]M12_SC_AR_payld;
  input [0:0]M12_SC_AR_recv;
  output [0:0]M12_SC_AR_req;
  output [0:0]M12_SC_AR_send;
  output [0:0]M12_SC_AW_info;
  output [301:0]M12_SC_AW_payld;
  input [0:0]M12_SC_AW_recv;
  output [0:0]M12_SC_AW_req;
  output [0:0]M12_SC_AW_send;
  output [0:0]M12_SC_W_info;
  output [318:0]M12_SC_W_payld;
  input [0:0]M12_SC_W_recv;
  output [0:0]M12_SC_W_req;
  output [0:0]M12_SC_W_send;
  output [0:0]M13_SC_AR_info;
  output [301:0]M13_SC_AR_payld;
  input [0:0]M13_SC_AR_recv;
  output [0:0]M13_SC_AR_req;
  output [0:0]M13_SC_AR_send;
  output [0:0]M13_SC_AW_info;
  output [301:0]M13_SC_AW_payld;
  input [0:0]M13_SC_AW_recv;
  output [0:0]M13_SC_AW_req;
  output [0:0]M13_SC_AW_send;
  output [0:0]M13_SC_W_info;
  output [318:0]M13_SC_W_payld;
  input [0:0]M13_SC_W_recv;
  output [0:0]M13_SC_W_req;
  output [0:0]M13_SC_W_send;
  output [0:0]M14_SC_AR_info;
  output [301:0]M14_SC_AR_payld;
  input [0:0]M14_SC_AR_recv;
  output [0:0]M14_SC_AR_req;
  output [0:0]M14_SC_AR_send;
  output [0:0]M14_SC_AW_info;
  output [301:0]M14_SC_AW_payld;
  input [0:0]M14_SC_AW_recv;
  output [0:0]M14_SC_AW_req;
  output [0:0]M14_SC_AW_send;
  output [0:0]M14_SC_W_info;
  output [318:0]M14_SC_W_payld;
  input [0:0]M14_SC_W_recv;
  output [0:0]M14_SC_W_req;
  output [0:0]M14_SC_W_send;
  output [0:0]M15_SC_AR_info;
  output [301:0]M15_SC_AR_payld;
  input [0:0]M15_SC_AR_recv;
  output [0:0]M15_SC_AR_req;
  output [0:0]M15_SC_AR_send;
  output [0:0]M15_SC_AW_info;
  output [301:0]M15_SC_AW_payld;
  input [0:0]M15_SC_AW_recv;
  output [0:0]M15_SC_AW_req;
  output [0:0]M15_SC_AW_send;
  output [0:0]M15_SC_W_info;
  output [318:0]M15_SC_W_payld;
  input [0:0]M15_SC_W_recv;
  output [0:0]M15_SC_W_req;
  output [0:0]M15_SC_W_send;
  input [15:0]S00_SC_AR_info;
  input [301:0]S00_SC_AR_payld;
  output [15:0]S00_SC_AR_recv;
  input [15:0]S00_SC_AR_req;
  input [15:0]S00_SC_AR_send;
  input [15:0]S00_SC_AW_info;
  input [301:0]S00_SC_AW_payld;
  output [15:0]S00_SC_AW_recv;
  input [15:0]S00_SC_AW_req;
  input [15:0]S00_SC_AW_send;
  input [0:0]S00_SC_B_info;
  input [119:0]S00_SC_B_payld;
  output [0:0]S00_SC_B_recv;
  input [0:0]S00_SC_B_req;
  input [0:0]S00_SC_B_send;
  input [0:0]S00_SC_R_info;
  input [276:0]S00_SC_R_payld;
  output [0:0]S00_SC_R_recv;
  input [0:0]S00_SC_R_req;
  input [0:0]S00_SC_R_send;
  input [15:0]S00_SC_W_info;
  input [318:0]S00_SC_W_payld;
  output [15:0]S00_SC_W_recv;
  input [15:0]S00_SC_W_req;
  input [15:0]S00_SC_W_send;
  input [0:0]S01_SC_B_info;
  input [119:0]S01_SC_B_payld;
  output [0:0]S01_SC_B_recv;
  input [0:0]S01_SC_B_req;
  input [0:0]S01_SC_B_send;
  input [0:0]S01_SC_R_info;
  input [276:0]S01_SC_R_payld;
  output [0:0]S01_SC_R_recv;
  input [0:0]S01_SC_R_req;
  input [0:0]S01_SC_R_send;
  input [0:0]S02_SC_B_info;
  input [119:0]S02_SC_B_payld;
  output [0:0]S02_SC_B_recv;
  input [0:0]S02_SC_B_req;
  input [0:0]S02_SC_B_send;
  input [0:0]S02_SC_R_info;
  input [276:0]S02_SC_R_payld;
  output [0:0]S02_SC_R_recv;
  input [0:0]S02_SC_R_req;
  input [0:0]S02_SC_R_send;
  input [0:0]S03_SC_B_info;
  input [119:0]S03_SC_B_payld;
  output [0:0]S03_SC_B_recv;
  input [0:0]S03_SC_B_req;
  input [0:0]S03_SC_B_send;
  input [0:0]S03_SC_R_info;
  input [276:0]S03_SC_R_payld;
  output [0:0]S03_SC_R_recv;
  input [0:0]S03_SC_R_req;
  input [0:0]S03_SC_R_send;
  input [0:0]S04_SC_B_info;
  input [119:0]S04_SC_B_payld;
  output [0:0]S04_SC_B_recv;
  input [0:0]S04_SC_B_req;
  input [0:0]S04_SC_B_send;
  input [0:0]S04_SC_R_info;
  input [276:0]S04_SC_R_payld;
  output [0:0]S04_SC_R_recv;
  input [0:0]S04_SC_R_req;
  input [0:0]S04_SC_R_send;
  input [0:0]S05_SC_B_info;
  input [119:0]S05_SC_B_payld;
  output [0:0]S05_SC_B_recv;
  input [0:0]S05_SC_B_req;
  input [0:0]S05_SC_B_send;
  input [0:0]S05_SC_R_info;
  input [276:0]S05_SC_R_payld;
  output [0:0]S05_SC_R_recv;
  input [0:0]S05_SC_R_req;
  input [0:0]S05_SC_R_send;
  input [0:0]S06_SC_B_info;
  input [119:0]S06_SC_B_payld;
  output [0:0]S06_SC_B_recv;
  input [0:0]S06_SC_B_req;
  input [0:0]S06_SC_B_send;
  input [0:0]S06_SC_R_info;
  input [276:0]S06_SC_R_payld;
  output [0:0]S06_SC_R_recv;
  input [0:0]S06_SC_R_req;
  input [0:0]S06_SC_R_send;
  input [0:0]S07_SC_B_info;
  input [119:0]S07_SC_B_payld;
  output [0:0]S07_SC_B_recv;
  input [0:0]S07_SC_B_req;
  input [0:0]S07_SC_B_send;
  input [0:0]S07_SC_R_info;
  input [276:0]S07_SC_R_payld;
  output [0:0]S07_SC_R_recv;
  input [0:0]S07_SC_R_req;
  input [0:0]S07_SC_R_send;
  input [0:0]S08_SC_B_info;
  input [119:0]S08_SC_B_payld;
  output [0:0]S08_SC_B_recv;
  input [0:0]S08_SC_B_req;
  input [0:0]S08_SC_B_send;
  input [0:0]S08_SC_R_info;
  input [276:0]S08_SC_R_payld;
  output [0:0]S08_SC_R_recv;
  input [0:0]S08_SC_R_req;
  input [0:0]S08_SC_R_send;
  input [0:0]S09_SC_B_info;
  input [119:0]S09_SC_B_payld;
  output [0:0]S09_SC_B_recv;
  input [0:0]S09_SC_B_req;
  input [0:0]S09_SC_B_send;
  input [0:0]S09_SC_R_info;
  input [276:0]S09_SC_R_payld;
  output [0:0]S09_SC_R_recv;
  input [0:0]S09_SC_R_req;
  input [0:0]S09_SC_R_send;
  input [0:0]S10_SC_B_info;
  input [119:0]S10_SC_B_payld;
  output [0:0]S10_SC_B_recv;
  input [0:0]S10_SC_B_req;
  input [0:0]S10_SC_B_send;
  input [0:0]S10_SC_R_info;
  input [276:0]S10_SC_R_payld;
  output [0:0]S10_SC_R_recv;
  input [0:0]S10_SC_R_req;
  input [0:0]S10_SC_R_send;
  input [0:0]S11_SC_B_info;
  input [119:0]S11_SC_B_payld;
  output [0:0]S11_SC_B_recv;
  input [0:0]S11_SC_B_req;
  input [0:0]S11_SC_B_send;
  input [0:0]S11_SC_R_info;
  input [276:0]S11_SC_R_payld;
  output [0:0]S11_SC_R_recv;
  input [0:0]S11_SC_R_req;
  input [0:0]S11_SC_R_send;
  input [0:0]S12_SC_B_info;
  input [119:0]S12_SC_B_payld;
  output [0:0]S12_SC_B_recv;
  input [0:0]S12_SC_B_req;
  input [0:0]S12_SC_B_send;
  input [0:0]S12_SC_R_info;
  input [276:0]S12_SC_R_payld;
  output [0:0]S12_SC_R_recv;
  input [0:0]S12_SC_R_req;
  input [0:0]S12_SC_R_send;
  input [0:0]S13_SC_B_info;
  input [119:0]S13_SC_B_payld;
  output [0:0]S13_SC_B_recv;
  input [0:0]S13_SC_B_req;
  input [0:0]S13_SC_B_send;
  input [0:0]S13_SC_R_info;
  input [276:0]S13_SC_R_payld;
  output [0:0]S13_SC_R_recv;
  input [0:0]S13_SC_R_req;
  input [0:0]S13_SC_R_send;
  input [0:0]S14_SC_B_info;
  input [119:0]S14_SC_B_payld;
  output [0:0]S14_SC_B_recv;
  input [0:0]S14_SC_B_req;
  input [0:0]S14_SC_B_send;
  input [0:0]S14_SC_R_info;
  input [276:0]S14_SC_R_payld;
  output [0:0]S14_SC_R_recv;
  input [0:0]S14_SC_R_req;
  input [0:0]S14_SC_R_send;
  input [0:0]S15_SC_B_info;
  input [119:0]S15_SC_B_payld;
  output [0:0]S15_SC_B_recv;
  input [0:0]S15_SC_B_req;
  input [0:0]S15_SC_B_send;
  input [0:0]S15_SC_R_info;
  input [276:0]S15_SC_R_payld;
  output [0:0]S15_SC_R_recv;
  input [0:0]S15_SC_R_req;
  input [0:0]S15_SC_R_send;
  input aclk;
  input aresetn;

  wire [0:0]M00_SC_AR_info;
  wire [301:0]M00_SC_AR_payld;
  wire [0:0]M00_SC_AR_recv;
  wire [0:0]M00_SC_AR_req;
  wire [0:0]M00_SC_AR_send;
  wire [0:0]M00_SC_AW_info;
  wire [301:0]M00_SC_AW_payld;
  wire [0:0]M00_SC_AW_recv;
  wire [0:0]M00_SC_AW_req;
  wire [0:0]M00_SC_AW_send;
  wire [15:0]M00_SC_B_info;
  wire [119:0]M00_SC_B_payld;
  wire [15:0]M00_SC_B_recv;
  wire [15:0]M00_SC_B_req;
  wire [15:0]M00_SC_B_send;
  wire [15:0]M00_SC_R_info;
  wire [276:0]M00_SC_R_payld;
  wire [15:0]M00_SC_R_recv;
  wire [15:0]M00_SC_R_req;
  wire [15:0]M00_SC_R_send;
  wire [0:0]M00_SC_W_info;
  wire [318:0]M00_SC_W_payld;
  wire [0:0]M00_SC_W_recv;
  wire [0:0]M00_SC_W_req;
  wire [0:0]M00_SC_W_send;
  wire [1:1]\^M01_SC_AR_info ;
  wire [603:302]\^M01_SC_AR_payld ;
  wire [0:0]M01_SC_AR_recv;
  wire [1:1]\^M01_SC_AR_req ;
  wire [1:1]\^M01_SC_AR_send ;
  wire [1:1]\^M01_SC_AW_info ;
  wire [603:302]\^M01_SC_AW_payld ;
  wire [0:0]M01_SC_AW_recv;
  wire [1:1]\^M01_SC_AW_req ;
  wire [1:1]\^M01_SC_AW_send ;
  wire [1:1]\^M01_SC_W_info ;
  wire [637:319]\^M01_SC_W_payld ;
  wire [0:0]M01_SC_W_recv;
  wire [1:1]\^M01_SC_W_req ;
  wire [1:1]\^M01_SC_W_send ;
  wire [2:2]\^M02_SC_AR_info ;
  wire [905:604]\^M02_SC_AR_payld ;
  wire [0:0]M02_SC_AR_recv;
  wire [2:2]\^M02_SC_AR_req ;
  wire [2:2]\^M02_SC_AR_send ;
  wire [2:2]\^M02_SC_AW_info ;
  wire [905:604]\^M02_SC_AW_payld ;
  wire [0:0]M02_SC_AW_recv;
  wire [2:2]\^M02_SC_AW_req ;
  wire [2:2]\^M02_SC_AW_send ;
  wire [2:2]\^M02_SC_W_info ;
  wire [956:638]\^M02_SC_W_payld ;
  wire [0:0]M02_SC_W_recv;
  wire [2:2]\^M02_SC_W_req ;
  wire [2:2]\^M02_SC_W_send ;
  wire [3:3]\^M03_SC_AR_info ;
  wire [1207:906]\^M03_SC_AR_payld ;
  wire [0:0]M03_SC_AR_recv;
  wire [3:3]\^M03_SC_AR_req ;
  wire [3:3]\^M03_SC_AR_send ;
  wire [3:3]\^M03_SC_AW_info ;
  wire [1207:906]\^M03_SC_AW_payld ;
  wire [0:0]M03_SC_AW_recv;
  wire [3:3]\^M03_SC_AW_req ;
  wire [3:3]\^M03_SC_AW_send ;
  wire [3:3]\^M03_SC_W_info ;
  wire [1275:957]\^M03_SC_W_payld ;
  wire [0:0]M03_SC_W_recv;
  wire [3:3]\^M03_SC_W_req ;
  wire [3:3]\^M03_SC_W_send ;
  wire [4:4]\^M04_SC_AR_info ;
  wire [1509:1208]\^M04_SC_AR_payld ;
  wire [0:0]M04_SC_AR_recv;
  wire [4:4]\^M04_SC_AR_req ;
  wire [4:4]\^M04_SC_AR_send ;
  wire [4:4]\^M04_SC_AW_info ;
  wire [1509:1208]\^M04_SC_AW_payld ;
  wire [0:0]M04_SC_AW_recv;
  wire [4:4]\^M04_SC_AW_req ;
  wire [4:4]\^M04_SC_AW_send ;
  wire [4:4]\^M04_SC_W_info ;
  wire [1594:1276]\^M04_SC_W_payld ;
  wire [0:0]M04_SC_W_recv;
  wire [4:4]\^M04_SC_W_req ;
  wire [4:4]\^M04_SC_W_send ;
  wire [5:5]\^M05_SC_AR_info ;
  wire [1811:1510]\^M05_SC_AR_payld ;
  wire [0:0]M05_SC_AR_recv;
  wire [5:5]\^M05_SC_AR_req ;
  wire [5:5]\^M05_SC_AR_send ;
  wire [5:5]\^M05_SC_AW_info ;
  wire [1811:1510]\^M05_SC_AW_payld ;
  wire [0:0]M05_SC_AW_recv;
  wire [5:5]\^M05_SC_AW_req ;
  wire [5:5]\^M05_SC_AW_send ;
  wire [5:5]\^M05_SC_W_info ;
  wire [1913:1595]\^M05_SC_W_payld ;
  wire [0:0]M05_SC_W_recv;
  wire [5:5]\^M05_SC_W_req ;
  wire [5:5]\^M05_SC_W_send ;
  wire [6:6]\^M06_SC_AR_info ;
  wire [2113:1812]\^M06_SC_AR_payld ;
  wire [0:0]M06_SC_AR_recv;
  wire [6:6]\^M06_SC_AR_req ;
  wire [6:6]\^M06_SC_AR_send ;
  wire [6:6]\^M06_SC_AW_info ;
  wire [2113:1812]\^M06_SC_AW_payld ;
  wire [0:0]M06_SC_AW_recv;
  wire [6:6]\^M06_SC_AW_req ;
  wire [6:6]\^M06_SC_AW_send ;
  wire [6:6]\^M06_SC_W_info ;
  wire [2232:1914]\^M06_SC_W_payld ;
  wire [0:0]M06_SC_W_recv;
  wire [6:6]\^M06_SC_W_req ;
  wire [6:6]\^M06_SC_W_send ;
  wire [7:7]\^M07_SC_AR_info ;
  wire [2415:2114]\^M07_SC_AR_payld ;
  wire [0:0]M07_SC_AR_recv;
  wire [7:7]\^M07_SC_AR_req ;
  wire [7:7]\^M07_SC_AR_send ;
  wire [7:7]\^M07_SC_AW_info ;
  wire [2415:2114]\^M07_SC_AW_payld ;
  wire [0:0]M07_SC_AW_recv;
  wire [7:7]\^M07_SC_AW_req ;
  wire [7:7]\^M07_SC_AW_send ;
  wire [7:7]\^M07_SC_W_info ;
  wire [2551:2233]\^M07_SC_W_payld ;
  wire [0:0]M07_SC_W_recv;
  wire [7:7]\^M07_SC_W_req ;
  wire [7:7]\^M07_SC_W_send ;
  wire [8:8]\^M08_SC_AR_info ;
  wire [2717:2416]\^M08_SC_AR_payld ;
  wire [0:0]M08_SC_AR_recv;
  wire [8:8]\^M08_SC_AR_req ;
  wire [8:8]\^M08_SC_AR_send ;
  wire [8:8]\^M08_SC_AW_info ;
  wire [2717:2416]\^M08_SC_AW_payld ;
  wire [0:0]M08_SC_AW_recv;
  wire [8:8]\^M08_SC_AW_req ;
  wire [8:8]\^M08_SC_AW_send ;
  wire [8:8]\^M08_SC_W_info ;
  wire [2870:2552]\^M08_SC_W_payld ;
  wire [0:0]M08_SC_W_recv;
  wire [8:8]\^M08_SC_W_req ;
  wire [8:8]\^M08_SC_W_send ;
  wire [9:9]\^M09_SC_AR_info ;
  wire [3019:2718]\^M09_SC_AR_payld ;
  wire [0:0]M09_SC_AR_recv;
  wire [9:9]\^M09_SC_AR_req ;
  wire [9:9]\^M09_SC_AR_send ;
  wire [9:9]\^M09_SC_AW_info ;
  wire [3019:2718]\^M09_SC_AW_payld ;
  wire [0:0]M09_SC_AW_recv;
  wire [9:9]\^M09_SC_AW_req ;
  wire [9:9]\^M09_SC_AW_send ;
  wire [9:9]\^M09_SC_W_info ;
  wire [3189:2871]\^M09_SC_W_payld ;
  wire [0:0]M09_SC_W_recv;
  wire [9:9]\^M09_SC_W_req ;
  wire [9:9]\^M09_SC_W_send ;
  wire [10:10]\^M10_SC_AR_info ;
  wire [3321:3020]\^M10_SC_AR_payld ;
  wire [0:0]M10_SC_AR_recv;
  wire [10:10]\^M10_SC_AR_req ;
  wire [10:10]\^M10_SC_AR_send ;
  wire [10:10]\^M10_SC_AW_info ;
  wire [3321:3020]\^M10_SC_AW_payld ;
  wire [0:0]M10_SC_AW_recv;
  wire [10:10]\^M10_SC_AW_req ;
  wire [10:10]\^M10_SC_AW_send ;
  wire [10:10]\^M10_SC_W_info ;
  wire [3508:3190]\^M10_SC_W_payld ;
  wire [0:0]M10_SC_W_recv;
  wire [10:10]\^M10_SC_W_req ;
  wire [10:10]\^M10_SC_W_send ;
  wire [11:11]\^M11_SC_AR_info ;
  wire [3623:3322]\^M11_SC_AR_payld ;
  wire [0:0]M11_SC_AR_recv;
  wire [11:11]\^M11_SC_AR_req ;
  wire [11:11]\^M11_SC_AR_send ;
  wire [11:11]\^M11_SC_AW_info ;
  wire [3623:3322]\^M11_SC_AW_payld ;
  wire [0:0]M11_SC_AW_recv;
  wire [11:11]\^M11_SC_AW_req ;
  wire [11:11]\^M11_SC_AW_send ;
  wire [11:11]\^M11_SC_W_info ;
  wire [3827:3509]\^M11_SC_W_payld ;
  wire [0:0]M11_SC_W_recv;
  wire [11:11]\^M11_SC_W_req ;
  wire [11:11]\^M11_SC_W_send ;
  wire [12:12]\^M12_SC_AR_info ;
  wire [3925:3624]\^M12_SC_AR_payld ;
  wire [0:0]M12_SC_AR_recv;
  wire [12:12]\^M12_SC_AR_req ;
  wire [12:12]\^M12_SC_AR_send ;
  wire [12:12]\^M12_SC_AW_info ;
  wire [3925:3624]\^M12_SC_AW_payld ;
  wire [0:0]M12_SC_AW_recv;
  wire [12:12]\^M12_SC_AW_req ;
  wire [12:12]\^M12_SC_AW_send ;
  wire [12:12]\^M12_SC_W_info ;
  wire [4146:3828]\^M12_SC_W_payld ;
  wire [0:0]M12_SC_W_recv;
  wire [12:12]\^M12_SC_W_req ;
  wire [12:12]\^M12_SC_W_send ;
  wire [13:13]\^M13_SC_AR_info ;
  wire [4227:3926]\^M13_SC_AR_payld ;
  wire [0:0]M13_SC_AR_recv;
  wire [13:13]\^M13_SC_AR_req ;
  wire [13:13]\^M13_SC_AR_send ;
  wire [13:13]\^M13_SC_AW_info ;
  wire [4227:3926]\^M13_SC_AW_payld ;
  wire [0:0]M13_SC_AW_recv;
  wire [13:13]\^M13_SC_AW_req ;
  wire [13:13]\^M13_SC_AW_send ;
  wire [13:13]\^M13_SC_W_info ;
  wire [4465:4147]\^M13_SC_W_payld ;
  wire [0:0]M13_SC_W_recv;
  wire [13:13]\^M13_SC_W_req ;
  wire [13:13]\^M13_SC_W_send ;
  wire [14:14]\^M14_SC_AR_info ;
  wire [4529:4228]\^M14_SC_AR_payld ;
  wire [0:0]M14_SC_AR_recv;
  wire [14:14]\^M14_SC_AR_req ;
  wire [14:14]\^M14_SC_AR_send ;
  wire [14:14]\^M14_SC_AW_info ;
  wire [4529:4228]\^M14_SC_AW_payld ;
  wire [0:0]M14_SC_AW_recv;
  wire [14:14]\^M14_SC_AW_req ;
  wire [14:14]\^M14_SC_AW_send ;
  wire [14:14]\^M14_SC_W_info ;
  wire [4784:4466]\^M14_SC_W_payld ;
  wire [0:0]M14_SC_W_recv;
  wire [14:14]\^M14_SC_W_req ;
  wire [14:14]\^M14_SC_W_send ;
  wire [15:15]\^M15_SC_AR_info ;
  wire [4831:4530]\^M15_SC_AR_payld ;
  wire [0:0]M15_SC_AR_recv;
  wire [15:15]\^M15_SC_AR_req ;
  wire [15:15]\^M15_SC_AR_send ;
  wire [15:15]\^M15_SC_AW_info ;
  wire [4831:4530]\^M15_SC_AW_payld ;
  wire [0:0]M15_SC_AW_recv;
  wire [15:15]\^M15_SC_AW_req ;
  wire [15:15]\^M15_SC_AW_send ;
  wire [15:15]\^M15_SC_W_info ;
  wire [5103:4785]\^M15_SC_W_payld ;
  wire [0:0]M15_SC_W_recv;
  wire [15:15]\^M15_SC_W_req ;
  wire [15:15]\^M15_SC_W_send ;
  wire [15:0]S00_SC_AR_info;
  wire [301:0]S00_SC_AR_payld;
  wire [15:0]S00_SC_AR_recv;
  wire [15:0]S00_SC_AR_req;
  wire [15:0]S00_SC_AR_send;
  wire [15:0]S00_SC_AW_info;
  wire [301:0]S00_SC_AW_payld;
  wire [15:0]S00_SC_AW_recv;
  wire [15:0]S00_SC_AW_req;
  wire [15:0]S00_SC_AW_send;
  wire [0:0]S00_SC_B_info;
  wire [119:0]S00_SC_B_payld;
  wire [0:0]S00_SC_B_recv;
  wire [0:0]S00_SC_B_req;
  wire [0:0]S00_SC_B_send;
  wire [0:0]S00_SC_R_info;
  wire [276:0]S00_SC_R_payld;
  wire [0:0]S00_SC_R_recv;
  wire [0:0]S00_SC_R_req;
  wire [0:0]S00_SC_R_send;
  wire [15:0]S00_SC_W_info;
  wire [318:0]S00_SC_W_payld;
  wire [15:0]S00_SC_W_recv;
  wire [15:0]S00_SC_W_req;
  wire [15:0]S00_SC_W_send;
  wire [0:0]S01_SC_B_info;
  wire [119:0]S01_SC_B_payld;
  wire [1:1]\^S01_SC_B_recv ;
  wire [0:0]S01_SC_B_req;
  wire [0:0]S01_SC_B_send;
  wire [0:0]S01_SC_R_info;
  wire [276:0]S01_SC_R_payld;
  wire [1:1]\^S01_SC_R_recv ;
  wire [0:0]S01_SC_R_req;
  wire [0:0]S01_SC_R_send;
  wire [0:0]S02_SC_B_info;
  wire [119:0]S02_SC_B_payld;
  wire [2:2]\^S02_SC_B_recv ;
  wire [0:0]S02_SC_B_req;
  wire [0:0]S02_SC_B_send;
  wire [0:0]S02_SC_R_info;
  wire [276:0]S02_SC_R_payld;
  wire [2:2]\^S02_SC_R_recv ;
  wire [0:0]S02_SC_R_req;
  wire [0:0]S02_SC_R_send;
  wire [0:0]S03_SC_B_info;
  wire [119:0]S03_SC_B_payld;
  wire [3:3]\^S03_SC_B_recv ;
  wire [0:0]S03_SC_B_req;
  wire [0:0]S03_SC_B_send;
  wire [0:0]S03_SC_R_info;
  wire [276:0]S03_SC_R_payld;
  wire [3:3]\^S03_SC_R_recv ;
  wire [0:0]S03_SC_R_req;
  wire [0:0]S03_SC_R_send;
  wire [0:0]S04_SC_B_info;
  wire [119:0]S04_SC_B_payld;
  wire [4:4]\^S04_SC_B_recv ;
  wire [0:0]S04_SC_B_req;
  wire [0:0]S04_SC_B_send;
  wire [0:0]S04_SC_R_info;
  wire [276:0]S04_SC_R_payld;
  wire [4:4]\^S04_SC_R_recv ;
  wire [0:0]S04_SC_R_req;
  wire [0:0]S04_SC_R_send;
  wire [0:0]S05_SC_B_info;
  wire [119:0]S05_SC_B_payld;
  wire [5:5]\^S05_SC_B_recv ;
  wire [0:0]S05_SC_B_req;
  wire [0:0]S05_SC_B_send;
  wire [0:0]S05_SC_R_info;
  wire [276:0]S05_SC_R_payld;
  wire [5:5]\^S05_SC_R_recv ;
  wire [0:0]S05_SC_R_req;
  wire [0:0]S05_SC_R_send;
  wire [0:0]S06_SC_B_info;
  wire [119:0]S06_SC_B_payld;
  wire [6:6]\^S06_SC_B_recv ;
  wire [0:0]S06_SC_B_req;
  wire [0:0]S06_SC_B_send;
  wire [0:0]S06_SC_R_info;
  wire [276:0]S06_SC_R_payld;
  wire [6:6]\^S06_SC_R_recv ;
  wire [0:0]S06_SC_R_req;
  wire [0:0]S06_SC_R_send;
  wire [0:0]S07_SC_B_info;
  wire [119:0]S07_SC_B_payld;
  wire [7:7]\^S07_SC_B_recv ;
  wire [0:0]S07_SC_B_req;
  wire [0:0]S07_SC_B_send;
  wire [0:0]S07_SC_R_info;
  wire [276:0]S07_SC_R_payld;
  wire [7:7]\^S07_SC_R_recv ;
  wire [0:0]S07_SC_R_req;
  wire [0:0]S07_SC_R_send;
  wire [0:0]S08_SC_B_info;
  wire [119:0]S08_SC_B_payld;
  wire [8:8]\^S08_SC_B_recv ;
  wire [0:0]S08_SC_B_req;
  wire [0:0]S08_SC_B_send;
  wire [0:0]S08_SC_R_info;
  wire [276:0]S08_SC_R_payld;
  wire [8:8]\^S08_SC_R_recv ;
  wire [0:0]S08_SC_R_req;
  wire [0:0]S08_SC_R_send;
  wire [0:0]S09_SC_B_info;
  wire [119:0]S09_SC_B_payld;
  wire [9:9]\^S09_SC_B_recv ;
  wire [0:0]S09_SC_B_req;
  wire [0:0]S09_SC_B_send;
  wire [0:0]S09_SC_R_info;
  wire [276:0]S09_SC_R_payld;
  wire [9:9]\^S09_SC_R_recv ;
  wire [0:0]S09_SC_R_req;
  wire [0:0]S09_SC_R_send;
  wire [0:0]S10_SC_B_info;
  wire [119:0]S10_SC_B_payld;
  wire [10:10]\^S10_SC_B_recv ;
  wire [0:0]S10_SC_B_req;
  wire [0:0]S10_SC_B_send;
  wire [0:0]S10_SC_R_info;
  wire [276:0]S10_SC_R_payld;
  wire [10:10]\^S10_SC_R_recv ;
  wire [0:0]S10_SC_R_req;
  wire [0:0]S10_SC_R_send;
  wire [0:0]S11_SC_B_info;
  wire [119:0]S11_SC_B_payld;
  wire [11:11]\^S11_SC_B_recv ;
  wire [0:0]S11_SC_B_req;
  wire [0:0]S11_SC_B_send;
  wire [0:0]S11_SC_R_info;
  wire [276:0]S11_SC_R_payld;
  wire [11:11]\^S11_SC_R_recv ;
  wire [0:0]S11_SC_R_req;
  wire [0:0]S11_SC_R_send;
  wire [0:0]S12_SC_B_info;
  wire [119:0]S12_SC_B_payld;
  wire [12:12]\^S12_SC_B_recv ;
  wire [0:0]S12_SC_B_req;
  wire [0:0]S12_SC_B_send;
  wire [0:0]S12_SC_R_info;
  wire [276:0]S12_SC_R_payld;
  wire [12:12]\^S12_SC_R_recv ;
  wire [0:0]S12_SC_R_req;
  wire [0:0]S12_SC_R_send;
  wire [0:0]S13_SC_B_info;
  wire [119:0]S13_SC_B_payld;
  wire [13:13]\^S13_SC_B_recv ;
  wire [0:0]S13_SC_B_req;
  wire [0:0]S13_SC_B_send;
  wire [0:0]S13_SC_R_info;
  wire [276:0]S13_SC_R_payld;
  wire [13:13]\^S13_SC_R_recv ;
  wire [0:0]S13_SC_R_req;
  wire [0:0]S13_SC_R_send;
  wire [0:0]S14_SC_B_info;
  wire [119:0]S14_SC_B_payld;
  wire [14:14]\^S14_SC_B_recv ;
  wire [0:0]S14_SC_B_req;
  wire [0:0]S14_SC_B_send;
  wire [0:0]S14_SC_R_info;
  wire [276:0]S14_SC_R_payld;
  wire [14:14]\^S14_SC_R_recv ;
  wire [0:0]S14_SC_R_req;
  wire [0:0]S14_SC_R_send;
  wire [0:0]S15_SC_B_info;
  wire [119:0]S15_SC_B_payld;
  wire [15:15]\^S15_SC_B_recv ;
  wire [0:0]S15_SC_B_req;
  wire [0:0]S15_SC_B_send;
  wire [0:0]S15_SC_R_info;
  wire [276:0]S15_SC_R_payld;
  wire [15:15]\^S15_SC_R_recv ;
  wire [0:0]S15_SC_R_req;
  wire [0:0]S15_SC_R_send;
  wire aclk;

  assign M01_SC_AR_info[0] = \^M01_SC_AR_info [1];
  assign M01_SC_AR_payld[301:0] = \^M01_SC_AR_payld [603:302];
  assign M01_SC_AR_req[0] = \^M01_SC_AR_req [1];
  assign M01_SC_AR_send[0] = \^M01_SC_AR_send [1];
  assign M01_SC_AW_info[0] = \^M01_SC_AW_info [1];
  assign M01_SC_AW_payld[301:0] = \^M01_SC_AW_payld [603:302];
  assign M01_SC_AW_req[0] = \^M01_SC_AW_req [1];
  assign M01_SC_AW_send[0] = \^M01_SC_AW_send [1];
  assign M01_SC_W_info[0] = \^M01_SC_W_info [1];
  assign M01_SC_W_payld[318:0] = \^M01_SC_W_payld [637:319];
  assign M01_SC_W_req[0] = \^M01_SC_W_req [1];
  assign M01_SC_W_send[0] = \^M01_SC_W_send [1];
  assign M02_SC_AR_info[0] = \^M02_SC_AR_info [2];
  assign M02_SC_AR_payld[301:0] = \^M02_SC_AR_payld [905:604];
  assign M02_SC_AR_req[0] = \^M02_SC_AR_req [2];
  assign M02_SC_AR_send[0] = \^M02_SC_AR_send [2];
  assign M02_SC_AW_info[0] = \^M02_SC_AW_info [2];
  assign M02_SC_AW_payld[301:0] = \^M02_SC_AW_payld [905:604];
  assign M02_SC_AW_req[0] = \^M02_SC_AW_req [2];
  assign M02_SC_AW_send[0] = \^M02_SC_AW_send [2];
  assign M02_SC_W_info[0] = \^M02_SC_W_info [2];
  assign M02_SC_W_payld[318:0] = \^M02_SC_W_payld [956:638];
  assign M02_SC_W_req[0] = \^M02_SC_W_req [2];
  assign M02_SC_W_send[0] = \^M02_SC_W_send [2];
  assign M03_SC_AR_info[0] = \^M03_SC_AR_info [3];
  assign M03_SC_AR_payld[301:0] = \^M03_SC_AR_payld [1207:906];
  assign M03_SC_AR_req[0] = \^M03_SC_AR_req [3];
  assign M03_SC_AR_send[0] = \^M03_SC_AR_send [3];
  assign M03_SC_AW_info[0] = \^M03_SC_AW_info [3];
  assign M03_SC_AW_payld[301:0] = \^M03_SC_AW_payld [1207:906];
  assign M03_SC_AW_req[0] = \^M03_SC_AW_req [3];
  assign M03_SC_AW_send[0] = \^M03_SC_AW_send [3];
  assign M03_SC_W_info[0] = \^M03_SC_W_info [3];
  assign M03_SC_W_payld[318:0] = \^M03_SC_W_payld [1275:957];
  assign M03_SC_W_req[0] = \^M03_SC_W_req [3];
  assign M03_SC_W_send[0] = \^M03_SC_W_send [3];
  assign M04_SC_AR_info[0] = \^M04_SC_AR_info [4];
  assign M04_SC_AR_payld[301:0] = \^M04_SC_AR_payld [1509:1208];
  assign M04_SC_AR_req[0] = \^M04_SC_AR_req [4];
  assign M04_SC_AR_send[0] = \^M04_SC_AR_send [4];
  assign M04_SC_AW_info[0] = \^M04_SC_AW_info [4];
  assign M04_SC_AW_payld[301:0] = \^M04_SC_AW_payld [1509:1208];
  assign M04_SC_AW_req[0] = \^M04_SC_AW_req [4];
  assign M04_SC_AW_send[0] = \^M04_SC_AW_send [4];
  assign M04_SC_W_info[0] = \^M04_SC_W_info [4];
  assign M04_SC_W_payld[318:0] = \^M04_SC_W_payld [1594:1276];
  assign M04_SC_W_req[0] = \^M04_SC_W_req [4];
  assign M04_SC_W_send[0] = \^M04_SC_W_send [4];
  assign M05_SC_AR_info[0] = \^M05_SC_AR_info [5];
  assign M05_SC_AR_payld[301:0] = \^M05_SC_AR_payld [1811:1510];
  assign M05_SC_AR_req[0] = \^M05_SC_AR_req [5];
  assign M05_SC_AR_send[0] = \^M05_SC_AR_send [5];
  assign M05_SC_AW_info[0] = \^M05_SC_AW_info [5];
  assign M05_SC_AW_payld[301:0] = \^M05_SC_AW_payld [1811:1510];
  assign M05_SC_AW_req[0] = \^M05_SC_AW_req [5];
  assign M05_SC_AW_send[0] = \^M05_SC_AW_send [5];
  assign M05_SC_W_info[0] = \^M05_SC_W_info [5];
  assign M05_SC_W_payld[318:0] = \^M05_SC_W_payld [1913:1595];
  assign M05_SC_W_req[0] = \^M05_SC_W_req [5];
  assign M05_SC_W_send[0] = \^M05_SC_W_send [5];
  assign M06_SC_AR_info[0] = \^M06_SC_AR_info [6];
  assign M06_SC_AR_payld[301:0] = \^M06_SC_AR_payld [2113:1812];
  assign M06_SC_AR_req[0] = \^M06_SC_AR_req [6];
  assign M06_SC_AR_send[0] = \^M06_SC_AR_send [6];
  assign M06_SC_AW_info[0] = \^M06_SC_AW_info [6];
  assign M06_SC_AW_payld[301:0] = \^M06_SC_AW_payld [2113:1812];
  assign M06_SC_AW_req[0] = \^M06_SC_AW_req [6];
  assign M06_SC_AW_send[0] = \^M06_SC_AW_send [6];
  assign M06_SC_W_info[0] = \^M06_SC_W_info [6];
  assign M06_SC_W_payld[318:0] = \^M06_SC_W_payld [2232:1914];
  assign M06_SC_W_req[0] = \^M06_SC_W_req [6];
  assign M06_SC_W_send[0] = \^M06_SC_W_send [6];
  assign M07_SC_AR_info[0] = \^M07_SC_AR_info [7];
  assign M07_SC_AR_payld[301:0] = \^M07_SC_AR_payld [2415:2114];
  assign M07_SC_AR_req[0] = \^M07_SC_AR_req [7];
  assign M07_SC_AR_send[0] = \^M07_SC_AR_send [7];
  assign M07_SC_AW_info[0] = \^M07_SC_AW_info [7];
  assign M07_SC_AW_payld[301:0] = \^M07_SC_AW_payld [2415:2114];
  assign M07_SC_AW_req[0] = \^M07_SC_AW_req [7];
  assign M07_SC_AW_send[0] = \^M07_SC_AW_send [7];
  assign M07_SC_W_info[0] = \^M07_SC_W_info [7];
  assign M07_SC_W_payld[318:0] = \^M07_SC_W_payld [2551:2233];
  assign M07_SC_W_req[0] = \^M07_SC_W_req [7];
  assign M07_SC_W_send[0] = \^M07_SC_W_send [7];
  assign M08_SC_AR_info[0] = \^M08_SC_AR_info [8];
  assign M08_SC_AR_payld[301:0] = \^M08_SC_AR_payld [2717:2416];
  assign M08_SC_AR_req[0] = \^M08_SC_AR_req [8];
  assign M08_SC_AR_send[0] = \^M08_SC_AR_send [8];
  assign M08_SC_AW_info[0] = \^M08_SC_AW_info [8];
  assign M08_SC_AW_payld[301:0] = \^M08_SC_AW_payld [2717:2416];
  assign M08_SC_AW_req[0] = \^M08_SC_AW_req [8];
  assign M08_SC_AW_send[0] = \^M08_SC_AW_send [8];
  assign M08_SC_W_info[0] = \^M08_SC_W_info [8];
  assign M08_SC_W_payld[318:0] = \^M08_SC_W_payld [2870:2552];
  assign M08_SC_W_req[0] = \^M08_SC_W_req [8];
  assign M08_SC_W_send[0] = \^M08_SC_W_send [8];
  assign M09_SC_AR_info[0] = \^M09_SC_AR_info [9];
  assign M09_SC_AR_payld[301:0] = \^M09_SC_AR_payld [3019:2718];
  assign M09_SC_AR_req[0] = \^M09_SC_AR_req [9];
  assign M09_SC_AR_send[0] = \^M09_SC_AR_send [9];
  assign M09_SC_AW_info[0] = \^M09_SC_AW_info [9];
  assign M09_SC_AW_payld[301:0] = \^M09_SC_AW_payld [3019:2718];
  assign M09_SC_AW_req[0] = \^M09_SC_AW_req [9];
  assign M09_SC_AW_send[0] = \^M09_SC_AW_send [9];
  assign M09_SC_W_info[0] = \^M09_SC_W_info [9];
  assign M09_SC_W_payld[318:0] = \^M09_SC_W_payld [3189:2871];
  assign M09_SC_W_req[0] = \^M09_SC_W_req [9];
  assign M09_SC_W_send[0] = \^M09_SC_W_send [9];
  assign M10_SC_AR_info[0] = \^M10_SC_AR_info [10];
  assign M10_SC_AR_payld[301:0] = \^M10_SC_AR_payld [3321:3020];
  assign M10_SC_AR_req[0] = \^M10_SC_AR_req [10];
  assign M10_SC_AR_send[0] = \^M10_SC_AR_send [10];
  assign M10_SC_AW_info[0] = \^M10_SC_AW_info [10];
  assign M10_SC_AW_payld[301:0] = \^M10_SC_AW_payld [3321:3020];
  assign M10_SC_AW_req[0] = \^M10_SC_AW_req [10];
  assign M10_SC_AW_send[0] = \^M10_SC_AW_send [10];
  assign M10_SC_W_info[0] = \^M10_SC_W_info [10];
  assign M10_SC_W_payld[318:0] = \^M10_SC_W_payld [3508:3190];
  assign M10_SC_W_req[0] = \^M10_SC_W_req [10];
  assign M10_SC_W_send[0] = \^M10_SC_W_send [10];
  assign M11_SC_AR_info[0] = \^M11_SC_AR_info [11];
  assign M11_SC_AR_payld[301:0] = \^M11_SC_AR_payld [3623:3322];
  assign M11_SC_AR_req[0] = \^M11_SC_AR_req [11];
  assign M11_SC_AR_send[0] = \^M11_SC_AR_send [11];
  assign M11_SC_AW_info[0] = \^M11_SC_AW_info [11];
  assign M11_SC_AW_payld[301:0] = \^M11_SC_AW_payld [3623:3322];
  assign M11_SC_AW_req[0] = \^M11_SC_AW_req [11];
  assign M11_SC_AW_send[0] = \^M11_SC_AW_send [11];
  assign M11_SC_W_info[0] = \^M11_SC_W_info [11];
  assign M11_SC_W_payld[318:0] = \^M11_SC_W_payld [3827:3509];
  assign M11_SC_W_req[0] = \^M11_SC_W_req [11];
  assign M11_SC_W_send[0] = \^M11_SC_W_send [11];
  assign M12_SC_AR_info[0] = \^M12_SC_AR_info [12];
  assign M12_SC_AR_payld[301:0] = \^M12_SC_AR_payld [3925:3624];
  assign M12_SC_AR_req[0] = \^M12_SC_AR_req [12];
  assign M12_SC_AR_send[0] = \^M12_SC_AR_send [12];
  assign M12_SC_AW_info[0] = \^M12_SC_AW_info [12];
  assign M12_SC_AW_payld[301:0] = \^M12_SC_AW_payld [3925:3624];
  assign M12_SC_AW_req[0] = \^M12_SC_AW_req [12];
  assign M12_SC_AW_send[0] = \^M12_SC_AW_send [12];
  assign M12_SC_W_info[0] = \^M12_SC_W_info [12];
  assign M12_SC_W_payld[318:0] = \^M12_SC_W_payld [4146:3828];
  assign M12_SC_W_req[0] = \^M12_SC_W_req [12];
  assign M12_SC_W_send[0] = \^M12_SC_W_send [12];
  assign M13_SC_AR_info[0] = \^M13_SC_AR_info [13];
  assign M13_SC_AR_payld[301:0] = \^M13_SC_AR_payld [4227:3926];
  assign M13_SC_AR_req[0] = \^M13_SC_AR_req [13];
  assign M13_SC_AR_send[0] = \^M13_SC_AR_send [13];
  assign M13_SC_AW_info[0] = \^M13_SC_AW_info [13];
  assign M13_SC_AW_payld[301:0] = \^M13_SC_AW_payld [4227:3926];
  assign M13_SC_AW_req[0] = \^M13_SC_AW_req [13];
  assign M13_SC_AW_send[0] = \^M13_SC_AW_send [13];
  assign M13_SC_W_info[0] = \^M13_SC_W_info [13];
  assign M13_SC_W_payld[318:0] = \^M13_SC_W_payld [4465:4147];
  assign M13_SC_W_req[0] = \^M13_SC_W_req [13];
  assign M13_SC_W_send[0] = \^M13_SC_W_send [13];
  assign M14_SC_AR_info[0] = \^M14_SC_AR_info [14];
  assign M14_SC_AR_payld[301:0] = \^M14_SC_AR_payld [4529:4228];
  assign M14_SC_AR_req[0] = \^M14_SC_AR_req [14];
  assign M14_SC_AR_send[0] = \^M14_SC_AR_send [14];
  assign M14_SC_AW_info[0] = \^M14_SC_AW_info [14];
  assign M14_SC_AW_payld[301:0] = \^M14_SC_AW_payld [4529:4228];
  assign M14_SC_AW_req[0] = \^M14_SC_AW_req [14];
  assign M14_SC_AW_send[0] = \^M14_SC_AW_send [14];
  assign M14_SC_W_info[0] = \^M14_SC_W_info [14];
  assign M14_SC_W_payld[318:0] = \^M14_SC_W_payld [4784:4466];
  assign M14_SC_W_req[0] = \^M14_SC_W_req [14];
  assign M14_SC_W_send[0] = \^M14_SC_W_send [14];
  assign M15_SC_AR_info[0] = \^M15_SC_AR_info [15];
  assign M15_SC_AR_payld[301:0] = \^M15_SC_AR_payld [4831:4530];
  assign M15_SC_AR_req[0] = \^M15_SC_AR_req [15];
  assign M15_SC_AR_send[0] = \^M15_SC_AR_send [15];
  assign M15_SC_AW_info[0] = \^M15_SC_AW_info [15];
  assign M15_SC_AW_payld[301:0] = \^M15_SC_AW_payld [4831:4530];
  assign M15_SC_AW_req[0] = \^M15_SC_AW_req [15];
  assign M15_SC_AW_send[0] = \^M15_SC_AW_send [15];
  assign M15_SC_W_info[0] = \^M15_SC_W_info [15];
  assign M15_SC_W_payld[318:0] = \^M15_SC_W_payld [5103:4785];
  assign M15_SC_W_req[0] = \^M15_SC_W_req [15];
  assign M15_SC_W_send[0] = \^M15_SC_W_send [15];
  assign S01_SC_B_recv[0] = \^S01_SC_B_recv [1];
  assign S01_SC_R_recv[0] = \^S01_SC_R_recv [1];
  assign S02_SC_B_recv[0] = \^S02_SC_B_recv [2];
  assign S02_SC_R_recv[0] = \^S02_SC_R_recv [2];
  assign S03_SC_B_recv[0] = \^S03_SC_B_recv [3];
  assign S03_SC_R_recv[0] = \^S03_SC_R_recv [3];
  assign S04_SC_B_recv[0] = \^S04_SC_B_recv [4];
  assign S04_SC_R_recv[0] = \^S04_SC_R_recv [4];
  assign S05_SC_B_recv[0] = \^S05_SC_B_recv [5];
  assign S05_SC_R_recv[0] = \^S05_SC_R_recv [5];
  assign S06_SC_B_recv[0] = \^S06_SC_B_recv [6];
  assign S06_SC_R_recv[0] = \^S06_SC_R_recv [6];
  assign S07_SC_B_recv[0] = \^S07_SC_B_recv [7];
  assign S07_SC_R_recv[0] = \^S07_SC_R_recv [7];
  assign S08_SC_B_recv[0] = \^S08_SC_B_recv [8];
  assign S08_SC_R_recv[0] = \^S08_SC_R_recv [8];
  assign S09_SC_B_recv[0] = \^S09_SC_B_recv [9];
  assign S09_SC_R_recv[0] = \^S09_SC_R_recv [9];
  assign S10_SC_B_recv[0] = \^S10_SC_B_recv [10];
  assign S10_SC_R_recv[0] = \^S10_SC_R_recv [10];
  assign S11_SC_B_recv[0] = \^S11_SC_B_recv [11];
  assign S11_SC_R_recv[0] = \^S11_SC_R_recv [11];
  assign S12_SC_B_recv[0] = \^S12_SC_B_recv [12];
  assign S12_SC_R_recv[0] = \^S12_SC_R_recv [12];
  assign S13_SC_B_recv[0] = \^S13_SC_B_recv [13];
  assign S13_SC_R_recv[0] = \^S13_SC_R_recv [13];
  assign S14_SC_B_recv[0] = \^S14_SC_B_recv [14];
  assign S14_SC_R_recv[0] = \^S14_SC_R_recv [14];
  assign S15_SC_B_recv[0] = \^S15_SC_B_recv [15];
  assign S15_SC_R_recv[0] = \^S15_SC_R_recv [15];
  bd_87e8_arsw_0 ar_switchboard
       (.aclk(aclk),
        .aclken(1'b1),
        .m_sc_info({\^M15_SC_AR_info ,\^M14_SC_AR_info ,\^M13_SC_AR_info ,\^M12_SC_AR_info ,\^M11_SC_AR_info ,\^M10_SC_AR_info ,\^M09_SC_AR_info ,\^M08_SC_AR_info ,\^M07_SC_AR_info ,\^M06_SC_AR_info ,\^M05_SC_AR_info ,\^M04_SC_AR_info ,\^M03_SC_AR_info ,\^M02_SC_AR_info ,\^M01_SC_AR_info ,M00_SC_AR_info}),
        .m_sc_payld({\^M15_SC_AR_payld ,\^M14_SC_AR_payld ,\^M13_SC_AR_payld ,\^M12_SC_AR_payld ,\^M11_SC_AR_payld ,\^M10_SC_AR_payld ,\^M09_SC_AR_payld ,\^M08_SC_AR_payld ,\^M07_SC_AR_payld ,\^M06_SC_AR_payld ,\^M05_SC_AR_payld ,\^M04_SC_AR_payld ,\^M03_SC_AR_payld ,\^M02_SC_AR_payld ,\^M01_SC_AR_payld ,M00_SC_AR_payld}),
        .m_sc_recv({M15_SC_AR_recv,M14_SC_AR_recv,M13_SC_AR_recv,M12_SC_AR_recv,M11_SC_AR_recv,M10_SC_AR_recv,M09_SC_AR_recv,M08_SC_AR_recv,M07_SC_AR_recv,M06_SC_AR_recv,M05_SC_AR_recv,M04_SC_AR_recv,M03_SC_AR_recv,M02_SC_AR_recv,M01_SC_AR_recv,M00_SC_AR_recv}),
        .m_sc_req({\^M15_SC_AR_req ,\^M14_SC_AR_req ,\^M13_SC_AR_req ,\^M12_SC_AR_req ,\^M11_SC_AR_req ,\^M10_SC_AR_req ,\^M09_SC_AR_req ,\^M08_SC_AR_req ,\^M07_SC_AR_req ,\^M06_SC_AR_req ,\^M05_SC_AR_req ,\^M04_SC_AR_req ,\^M03_SC_AR_req ,\^M02_SC_AR_req ,\^M01_SC_AR_req ,M00_SC_AR_req}),
        .m_sc_send({\^M15_SC_AR_send ,\^M14_SC_AR_send ,\^M13_SC_AR_send ,\^M12_SC_AR_send ,\^M11_SC_AR_send ,\^M10_SC_AR_send ,\^M09_SC_AR_send ,\^M08_SC_AR_send ,\^M07_SC_AR_send ,\^M06_SC_AR_send ,\^M05_SC_AR_send ,\^M04_SC_AR_send ,\^M03_SC_AR_send ,\^M02_SC_AR_send ,\^M01_SC_AR_send ,M00_SC_AR_send}),
        .s_sc_info(S00_SC_AR_info),
        .s_sc_payld(S00_SC_AR_payld),
        .s_sc_recv(S00_SC_AR_recv),
        .s_sc_req(S00_SC_AR_req),
        .s_sc_send(S00_SC_AR_send));
  bd_87e8_awsw_0 aw_switchboard
       (.aclk(aclk),
        .aclken(1'b1),
        .m_sc_info({\^M15_SC_AW_info ,\^M14_SC_AW_info ,\^M13_SC_AW_info ,\^M12_SC_AW_info ,\^M11_SC_AW_info ,\^M10_SC_AW_info ,\^M09_SC_AW_info ,\^M08_SC_AW_info ,\^M07_SC_AW_info ,\^M06_SC_AW_info ,\^M05_SC_AW_info ,\^M04_SC_AW_info ,\^M03_SC_AW_info ,\^M02_SC_AW_info ,\^M01_SC_AW_info ,M00_SC_AW_info}),
        .m_sc_payld({\^M15_SC_AW_payld ,\^M14_SC_AW_payld ,\^M13_SC_AW_payld ,\^M12_SC_AW_payld ,\^M11_SC_AW_payld ,\^M10_SC_AW_payld ,\^M09_SC_AW_payld ,\^M08_SC_AW_payld ,\^M07_SC_AW_payld ,\^M06_SC_AW_payld ,\^M05_SC_AW_payld ,\^M04_SC_AW_payld ,\^M03_SC_AW_payld ,\^M02_SC_AW_payld ,\^M01_SC_AW_payld ,M00_SC_AW_payld}),
        .m_sc_recv({M15_SC_AW_recv,M14_SC_AW_recv,M13_SC_AW_recv,M12_SC_AW_recv,M11_SC_AW_recv,M10_SC_AW_recv,M09_SC_AW_recv,M08_SC_AW_recv,M07_SC_AW_recv,M06_SC_AW_recv,M05_SC_AW_recv,M04_SC_AW_recv,M03_SC_AW_recv,M02_SC_AW_recv,M01_SC_AW_recv,M00_SC_AW_recv}),
        .m_sc_req({\^M15_SC_AW_req ,\^M14_SC_AW_req ,\^M13_SC_AW_req ,\^M12_SC_AW_req ,\^M11_SC_AW_req ,\^M10_SC_AW_req ,\^M09_SC_AW_req ,\^M08_SC_AW_req ,\^M07_SC_AW_req ,\^M06_SC_AW_req ,\^M05_SC_AW_req ,\^M04_SC_AW_req ,\^M03_SC_AW_req ,\^M02_SC_AW_req ,\^M01_SC_AW_req ,M00_SC_AW_req}),
        .m_sc_send({\^M15_SC_AW_send ,\^M14_SC_AW_send ,\^M13_SC_AW_send ,\^M12_SC_AW_send ,\^M11_SC_AW_send ,\^M10_SC_AW_send ,\^M09_SC_AW_send ,\^M08_SC_AW_send ,\^M07_SC_AW_send ,\^M06_SC_AW_send ,\^M05_SC_AW_send ,\^M04_SC_AW_send ,\^M03_SC_AW_send ,\^M02_SC_AW_send ,\^M01_SC_AW_send ,M00_SC_AW_send}),
        .s_sc_info(S00_SC_AW_info),
        .s_sc_payld(S00_SC_AW_payld),
        .s_sc_recv(S00_SC_AW_recv),
        .s_sc_req(S00_SC_AW_req),
        .s_sc_send(S00_SC_AW_send));
  bd_87e8_bsw_0 b_switchboard
       (.aclk(aclk),
        .aclken(1'b1),
        .m_sc_info(M00_SC_B_info),
        .m_sc_payld(M00_SC_B_payld),
        .m_sc_recv(M00_SC_B_recv),
        .m_sc_req(M00_SC_B_req),
        .m_sc_send(M00_SC_B_send),
        .s_sc_info({S15_SC_B_info,S14_SC_B_info,S13_SC_B_info,S12_SC_B_info,S11_SC_B_info,S10_SC_B_info,S09_SC_B_info,S08_SC_B_info,S07_SC_B_info,S06_SC_B_info,S05_SC_B_info,S04_SC_B_info,S03_SC_B_info,S02_SC_B_info,S01_SC_B_info,S00_SC_B_info}),
        .s_sc_payld({S15_SC_B_payld,S14_SC_B_payld,S13_SC_B_payld,S12_SC_B_payld,S11_SC_B_payld,S10_SC_B_payld,S09_SC_B_payld,S08_SC_B_payld,S07_SC_B_payld,S06_SC_B_payld,S05_SC_B_payld,S04_SC_B_payld,S03_SC_B_payld,S02_SC_B_payld,S01_SC_B_payld,S00_SC_B_payld}),
        .s_sc_recv({\^S15_SC_B_recv ,\^S14_SC_B_recv ,\^S13_SC_B_recv ,\^S12_SC_B_recv ,\^S11_SC_B_recv ,\^S10_SC_B_recv ,\^S09_SC_B_recv ,\^S08_SC_B_recv ,\^S07_SC_B_recv ,\^S06_SC_B_recv ,\^S05_SC_B_recv ,\^S04_SC_B_recv ,\^S03_SC_B_recv ,\^S02_SC_B_recv ,\^S01_SC_B_recv ,S00_SC_B_recv}),
        .s_sc_req({S15_SC_B_req,S14_SC_B_req,S13_SC_B_req,S12_SC_B_req,S11_SC_B_req,S10_SC_B_req,S09_SC_B_req,S08_SC_B_req,S07_SC_B_req,S06_SC_B_req,S05_SC_B_req,S04_SC_B_req,S03_SC_B_req,S02_SC_B_req,S01_SC_B_req,S00_SC_B_req}),
        .s_sc_send({S15_SC_B_send,S14_SC_B_send,S13_SC_B_send,S12_SC_B_send,S11_SC_B_send,S10_SC_B_send,S09_SC_B_send,S08_SC_B_send,S07_SC_B_send,S06_SC_B_send,S05_SC_B_send,S04_SC_B_send,S03_SC_B_send,S02_SC_B_send,S01_SC_B_send,S00_SC_B_send}));
  bd_87e8_rsw_0 r_switchboard
       (.aclk(aclk),
        .aclken(1'b1),
        .m_sc_info(M00_SC_R_info),
        .m_sc_payld(M00_SC_R_payld),
        .m_sc_recv(M00_SC_R_recv),
        .m_sc_req(M00_SC_R_req),
        .m_sc_send(M00_SC_R_send),
        .s_sc_info({S15_SC_R_info,S14_SC_R_info,S13_SC_R_info,S12_SC_R_info,S11_SC_R_info,S10_SC_R_info,S09_SC_R_info,S08_SC_R_info,S07_SC_R_info,S06_SC_R_info,S05_SC_R_info,S04_SC_R_info,S03_SC_R_info,S02_SC_R_info,S01_SC_R_info,S00_SC_R_info}),
        .s_sc_payld({S15_SC_R_payld,S14_SC_R_payld,S13_SC_R_payld,S12_SC_R_payld,S11_SC_R_payld,S10_SC_R_payld,S09_SC_R_payld,S08_SC_R_payld,S07_SC_R_payld,S06_SC_R_payld,S05_SC_R_payld,S04_SC_R_payld,S03_SC_R_payld,S02_SC_R_payld,S01_SC_R_payld,S00_SC_R_payld}),
        .s_sc_recv({\^S15_SC_R_recv ,\^S14_SC_R_recv ,\^S13_SC_R_recv ,\^S12_SC_R_recv ,\^S11_SC_R_recv ,\^S10_SC_R_recv ,\^S09_SC_R_recv ,\^S08_SC_R_recv ,\^S07_SC_R_recv ,\^S06_SC_R_recv ,\^S05_SC_R_recv ,\^S04_SC_R_recv ,\^S03_SC_R_recv ,\^S02_SC_R_recv ,\^S01_SC_R_recv ,S00_SC_R_recv}),
        .s_sc_req({S15_SC_R_req,S14_SC_R_req,S13_SC_R_req,S12_SC_R_req,S11_SC_R_req,S10_SC_R_req,S09_SC_R_req,S08_SC_R_req,S07_SC_R_req,S06_SC_R_req,S05_SC_R_req,S04_SC_R_req,S03_SC_R_req,S02_SC_R_req,S01_SC_R_req,S00_SC_R_req}),
        .s_sc_send({S15_SC_R_send,S14_SC_R_send,S13_SC_R_send,S12_SC_R_send,S11_SC_R_send,S10_SC_R_send,S09_SC_R_send,S08_SC_R_send,S07_SC_R_send,S06_SC_R_send,S05_SC_R_send,S04_SC_R_send,S03_SC_R_send,S02_SC_R_send,S01_SC_R_send,S00_SC_R_send}));
  bd_87e8_wsw_0 w_switchboard
       (.aclk(aclk),
        .aclken(1'b1),
        .m_sc_info({\^M15_SC_W_info ,\^M14_SC_W_info ,\^M13_SC_W_info ,\^M12_SC_W_info ,\^M11_SC_W_info ,\^M10_SC_W_info ,\^M09_SC_W_info ,\^M08_SC_W_info ,\^M07_SC_W_info ,\^M06_SC_W_info ,\^M05_SC_W_info ,\^M04_SC_W_info ,\^M03_SC_W_info ,\^M02_SC_W_info ,\^M01_SC_W_info ,M00_SC_W_info}),
        .m_sc_payld({\^M15_SC_W_payld ,\^M14_SC_W_payld ,\^M13_SC_W_payld ,\^M12_SC_W_payld ,\^M11_SC_W_payld ,\^M10_SC_W_payld ,\^M09_SC_W_payld ,\^M08_SC_W_payld ,\^M07_SC_W_payld ,\^M06_SC_W_payld ,\^M05_SC_W_payld ,\^M04_SC_W_payld ,\^M03_SC_W_payld ,\^M02_SC_W_payld ,\^M01_SC_W_payld ,M00_SC_W_payld}),
        .m_sc_recv({M15_SC_W_recv,M14_SC_W_recv,M13_SC_W_recv,M12_SC_W_recv,M11_SC_W_recv,M10_SC_W_recv,M09_SC_W_recv,M08_SC_W_recv,M07_SC_W_recv,M06_SC_W_recv,M05_SC_W_recv,M04_SC_W_recv,M03_SC_W_recv,M02_SC_W_recv,M01_SC_W_recv,M00_SC_W_recv}),
        .m_sc_req({\^M15_SC_W_req ,\^M14_SC_W_req ,\^M13_SC_W_req ,\^M12_SC_W_req ,\^M11_SC_W_req ,\^M10_SC_W_req ,\^M09_SC_W_req ,\^M08_SC_W_req ,\^M07_SC_W_req ,\^M06_SC_W_req ,\^M05_SC_W_req ,\^M04_SC_W_req ,\^M03_SC_W_req ,\^M02_SC_W_req ,\^M01_SC_W_req ,M00_SC_W_req}),
        .m_sc_send({\^M15_SC_W_send ,\^M14_SC_W_send ,\^M13_SC_W_send ,\^M12_SC_W_send ,\^M11_SC_W_send ,\^M10_SC_W_send ,\^M09_SC_W_send ,\^M08_SC_W_send ,\^M07_SC_W_send ,\^M06_SC_W_send ,\^M05_SC_W_send ,\^M04_SC_W_send ,\^M03_SC_W_send ,\^M02_SC_W_send ,\^M01_SC_W_send ,M00_SC_W_send}),
        .s_sc_info(S00_SC_W_info),
        .s_sc_payld(S00_SC_W_payld),
        .s_sc_recv(S00_SC_W_recv),
        .s_sc_req(S00_SC_W_req),
        .s_sc_send(S00_SC_W_send));
endmodule
