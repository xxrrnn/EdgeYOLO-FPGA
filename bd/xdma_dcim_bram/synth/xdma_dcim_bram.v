//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2.2 (lin64) Build 6060944 Thu Mar 06 19:10:09 MST 2025
//Date        : Wed Apr 29 20:20:07 2026
//Host        : DESKTOP-5NNBJ0V running 64-bit Ubuntu 22.04.1 LTS
//Command     : generate_target xdma_dcim_bram.bd
//Design      : xdma_dcim_bram
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "xdma_dcim_bram,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=xdma_dcim_bram,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=12,numReposBlks=12,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=1,numPkgbdBlks=0,bdsource=USER,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "xdma_dcim_bram.hwdef" *) 
module xdma_dcim_bram
   (cpu_reset,
    pci_express_x8_rxn,
    pci_express_x8_rxp,
    pci_express_x8_txn,
    pci_express_x8_txp,
    pcie_refclk_clk_n,
    pcie_refclk_clk_p,
    user_lnk_up_0);
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.CPU_RESET RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.CPU_RESET, INSERT_VIP 0, POLARITY ACTIVE_HIGH" *) input cpu_reset;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 rxn" *) (* X_INTERFACE_MODE = "Master" *) input [7:0]pci_express_x8_rxn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 rxp" *) input [7:0]pci_express_x8_rxp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 txn" *) output [7:0]pci_express_x8_txn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:pcie_7x_mgt:1.0 pci_express_x8 txp" *) output [7:0]pci_express_x8_txp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 pcie_refclk CLK_N" *) (* X_INTERFACE_MODE = "Slave" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME pcie_refclk, CAN_DEBUG false, FREQ_HZ 100000000" *) input pcie_refclk_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:diff_clock:1.0 pcie_refclk CLK_P" *) input pcie_refclk_clk_p;
  output user_lnk_up_0;

  wire [31:0]axi_cdma_0_M_AXI_ARADDR;
  wire [1:0]axi_cdma_0_M_AXI_ARBURST;
  wire [3:0]axi_cdma_0_M_AXI_ARCACHE;
  wire [7:0]axi_cdma_0_M_AXI_ARLEN;
  wire [2:0]axi_cdma_0_M_AXI_ARPROT;
  wire axi_cdma_0_M_AXI_ARREADY;
  wire [2:0]axi_cdma_0_M_AXI_ARSIZE;
  wire axi_cdma_0_M_AXI_ARVALID;
  wire [31:0]axi_cdma_0_M_AXI_AWADDR;
  wire [1:0]axi_cdma_0_M_AXI_AWBURST;
  wire [3:0]axi_cdma_0_M_AXI_AWCACHE;
  wire [7:0]axi_cdma_0_M_AXI_AWLEN;
  wire [2:0]axi_cdma_0_M_AXI_AWPROT;
  wire axi_cdma_0_M_AXI_AWREADY;
  wire [2:0]axi_cdma_0_M_AXI_AWSIZE;
  wire axi_cdma_0_M_AXI_AWVALID;
  wire axi_cdma_0_M_AXI_BREADY;
  wire [1:0]axi_cdma_0_M_AXI_BRESP;
  wire axi_cdma_0_M_AXI_BVALID;
  wire [255:0]axi_cdma_0_M_AXI_RDATA;
  wire axi_cdma_0_M_AXI_RLAST;
  wire axi_cdma_0_M_AXI_RREADY;
  wire [1:0]axi_cdma_0_M_AXI_RRESP;
  wire axi_cdma_0_M_AXI_RVALID;
  wire [255:0]axi_cdma_0_M_AXI_WDATA;
  wire axi_cdma_0_M_AXI_WLAST;
  wire axi_cdma_0_M_AXI_WREADY;
  wire [31:0]axi_cdma_0_M_AXI_WSTRB;
  wire axi_cdma_0_M_AXI_WVALID;
  wire [15:0]axi_mem_smc_M00_AXI_ARADDR;
  wire [1:0]axi_mem_smc_M00_AXI_ARBURST;
  wire [3:0]axi_mem_smc_M00_AXI_ARCACHE;
  wire [7:0]axi_mem_smc_M00_AXI_ARLEN;
  wire [0:0]axi_mem_smc_M00_AXI_ARLOCK;
  wire [2:0]axi_mem_smc_M00_AXI_ARPROT;
  wire axi_mem_smc_M00_AXI_ARREADY;
  wire [2:0]axi_mem_smc_M00_AXI_ARSIZE;
  wire axi_mem_smc_M00_AXI_ARVALID;
  wire [15:0]axi_mem_smc_M00_AXI_AWADDR;
  wire [1:0]axi_mem_smc_M00_AXI_AWBURST;
  wire [3:0]axi_mem_smc_M00_AXI_AWCACHE;
  wire [7:0]axi_mem_smc_M00_AXI_AWLEN;
  wire [0:0]axi_mem_smc_M00_AXI_AWLOCK;
  wire [2:0]axi_mem_smc_M00_AXI_AWPROT;
  wire axi_mem_smc_M00_AXI_AWREADY;
  wire [2:0]axi_mem_smc_M00_AXI_AWSIZE;
  wire axi_mem_smc_M00_AXI_AWVALID;
  wire axi_mem_smc_M00_AXI_BREADY;
  wire [1:0]axi_mem_smc_M00_AXI_BRESP;
  wire axi_mem_smc_M00_AXI_BVALID;
  wire [255:0]axi_mem_smc_M00_AXI_RDATA;
  wire axi_mem_smc_M00_AXI_RLAST;
  wire axi_mem_smc_M00_AXI_RREADY;
  wire [1:0]axi_mem_smc_M00_AXI_RRESP;
  wire axi_mem_smc_M00_AXI_RVALID;
  wire [255:0]axi_mem_smc_M00_AXI_WDATA;
  wire axi_mem_smc_M00_AXI_WLAST;
  wire axi_mem_smc_M00_AXI_WREADY;
  wire [31:0]axi_mem_smc_M00_AXI_WSTRB;
  wire axi_mem_smc_M00_AXI_WVALID;
  wire [15:0]axi_mem_smc_M01_AXI_ARADDR;
  wire [1:0]axi_mem_smc_M01_AXI_ARBURST;
  wire [3:0]axi_mem_smc_M01_AXI_ARCACHE;
  wire [7:0]axi_mem_smc_M01_AXI_ARLEN;
  wire [0:0]axi_mem_smc_M01_AXI_ARLOCK;
  wire [2:0]axi_mem_smc_M01_AXI_ARPROT;
  wire axi_mem_smc_M01_AXI_ARREADY;
  wire [2:0]axi_mem_smc_M01_AXI_ARSIZE;
  wire axi_mem_smc_M01_AXI_ARVALID;
  wire [15:0]axi_mem_smc_M01_AXI_AWADDR;
  wire [1:0]axi_mem_smc_M01_AXI_AWBURST;
  wire [3:0]axi_mem_smc_M01_AXI_AWCACHE;
  wire [7:0]axi_mem_smc_M01_AXI_AWLEN;
  wire [0:0]axi_mem_smc_M01_AXI_AWLOCK;
  wire [2:0]axi_mem_smc_M01_AXI_AWPROT;
  wire axi_mem_smc_M01_AXI_AWREADY;
  wire [2:0]axi_mem_smc_M01_AXI_AWSIZE;
  wire axi_mem_smc_M01_AXI_AWVALID;
  wire axi_mem_smc_M01_AXI_BREADY;
  wire [1:0]axi_mem_smc_M01_AXI_BRESP;
  wire axi_mem_smc_M01_AXI_BVALID;
  wire [255:0]axi_mem_smc_M01_AXI_RDATA;
  wire axi_mem_smc_M01_AXI_RLAST;
  wire axi_mem_smc_M01_AXI_RREADY;
  wire [1:0]axi_mem_smc_M01_AXI_RRESP;
  wire axi_mem_smc_M01_AXI_RVALID;
  wire [255:0]axi_mem_smc_M01_AXI_WDATA;
  wire axi_mem_smc_M01_AXI_WLAST;
  wire axi_mem_smc_M01_AXI_WREADY;
  wire [31:0]axi_mem_smc_M01_AXI_WSTRB;
  wire axi_mem_smc_M01_AXI_WVALID;
  wire [11:0]axi_mem_smc_M02_AXI_ARADDR;
  wire axi_mem_smc_M02_AXI_ARREADY;
  wire axi_mem_smc_M02_AXI_ARVALID;
  wire [11:0]axi_mem_smc_M02_AXI_AWADDR;
  wire axi_mem_smc_M02_AXI_AWREADY;
  wire axi_mem_smc_M02_AXI_AWVALID;
  wire axi_mem_smc_M02_AXI_BREADY;
  wire [1:0]axi_mem_smc_M02_AXI_BRESP;
  wire axi_mem_smc_M02_AXI_BVALID;
  wire [31:0]axi_mem_smc_M02_AXI_RDATA;
  wire axi_mem_smc_M02_AXI_RREADY;
  wire [1:0]axi_mem_smc_M02_AXI_RRESP;
  wire axi_mem_smc_M02_AXI_RVALID;
  wire [31:0]axi_mem_smc_M02_AXI_WDATA;
  wire axi_mem_smc_M02_AXI_WREADY;
  wire [3:0]axi_mem_smc_M02_AXI_WSTRB;
  wire axi_mem_smc_M02_AXI_WVALID;
  wire [0:0]bram_inv_Res;
  wire cpu_reset;
  wire [15:0]global_bram_ctrl_BRAM_PORTA_ADDR;
  wire global_bram_ctrl_BRAM_PORTA_CLK;
  wire [255:0]global_bram_ctrl_BRAM_PORTA_DIN;
  wire [255:0]global_bram_ctrl_BRAM_PORTA_DOUT;
  wire global_bram_ctrl_BRAM_PORTA_EN;
  wire global_bram_ctrl_BRAM_PORTA_RST;
  wire [31:0]global_bram_ctrl_BRAM_PORTA_WE;
  wire [15:0]local_bram_ctrl_BRAM_PORTA_ADDR;
  wire local_bram_ctrl_BRAM_PORTA_CLK;
  wire [255:0]local_bram_ctrl_BRAM_PORTA_DIN;
  wire [255:0]local_bram_ctrl_BRAM_PORTA_DOUT;
  wire local_bram_ctrl_BRAM_PORTA_EN;
  wire local_bram_ctrl_BRAM_PORTA_RST;
  wire [31:0]local_bram_ctrl_BRAM_PORTA_WE;
  wire [255:0]local_bram_doutb;
  wire [7:0]pci_express_x8_rxn;
  wire [7:0]pci_express_x8_rxp;
  wire [7:0]pci_express_x8_txn;
  wire [7:0]pci_express_x8_txp;
  wire pcie_refclk_clk_n;
  wire pcie_refclk_clk_p;
  wire user_lnk_up_0;
  wire [0:0]util_ds_buf_IBUF_DS_ODIV2;
  wire [0:0]util_ds_buf_IBUF_OUT;
  wire [63:0]xdma_0_M_AXI_ARADDR;
  wire [1:0]xdma_0_M_AXI_ARBURST;
  wire [3:0]xdma_0_M_AXI_ARCACHE;
  wire [3:0]xdma_0_M_AXI_ARID;
  wire [7:0]xdma_0_M_AXI_ARLEN;
  wire xdma_0_M_AXI_ARLOCK;
  wire [2:0]xdma_0_M_AXI_ARPROT;
  wire xdma_0_M_AXI_ARREADY;
  wire [2:0]xdma_0_M_AXI_ARSIZE;
  wire xdma_0_M_AXI_ARVALID;
  wire [63:0]xdma_0_M_AXI_AWADDR;
  wire [1:0]xdma_0_M_AXI_AWBURST;
  wire [3:0]xdma_0_M_AXI_AWCACHE;
  wire [3:0]xdma_0_M_AXI_AWID;
  wire [7:0]xdma_0_M_AXI_AWLEN;
  wire xdma_0_M_AXI_AWLOCK;
  wire [2:0]xdma_0_M_AXI_AWPROT;
  wire xdma_0_M_AXI_AWREADY;
  wire [2:0]xdma_0_M_AXI_AWSIZE;
  wire xdma_0_M_AXI_AWVALID;
  wire [3:0]xdma_0_M_AXI_BID;
  wire xdma_0_M_AXI_BREADY;
  wire [1:0]xdma_0_M_AXI_BRESP;
  wire xdma_0_M_AXI_BVALID;
  wire [255:0]xdma_0_M_AXI_RDATA;
  wire [3:0]xdma_0_M_AXI_RID;
  wire xdma_0_M_AXI_RLAST;
  wire xdma_0_M_AXI_RREADY;
  wire [1:0]xdma_0_M_AXI_RRESP;
  wire xdma_0_M_AXI_RVALID;
  wire [255:0]xdma_0_M_AXI_WDATA;
  wire xdma_0_M_AXI_WLAST;
  wire xdma_0_M_AXI_WREADY;
  wire [31:0]xdma_0_M_AXI_WSTRB;
  wire xdma_0_M_AXI_WVALID;
  wire xdma_0_axi_aclk;
  wire xdma_0_axi_aresetn;
  wire [0:0]xdma_constant_dout;
  wire [31:0]xdma_dcim_bram_ctrl_0_local_bram_addr;
  wire [255:0]xdma_dcim_bram_ctrl_0_local_bram_din;
  wire xdma_dcim_bram_ctrl_0_local_bram_en;
  wire [31:0]xdma_dcim_bram_ctrl_0_local_bram_we;
  wire [31:0]xdma_dcim_bram_ctrl_0_m_axil_cdma_ARADDR;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_ARREADY;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_ARVALID;
  wire [31:0]xdma_dcim_bram_ctrl_0_m_axil_cdma_AWADDR;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_AWREADY;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_AWVALID;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_BREADY;
  wire [1:0]xdma_dcim_bram_ctrl_0_m_axil_cdma_BRESP;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_BVALID;
  wire [31:0]xdma_dcim_bram_ctrl_0_m_axil_cdma_RDATA;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_RREADY;
  wire [1:0]xdma_dcim_bram_ctrl_0_m_axil_cdma_RRESP;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_RVALID;
  wire [31:0]xdma_dcim_bram_ctrl_0_m_axil_cdma_WDATA;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_WREADY;
  wire xdma_dcim_bram_ctrl_0_m_axil_cdma_WVALID;
  wire [0:0]xdma_inv_Res;

  xdma_dcim_bram_axi_cdma_0_0 axi_cdma_0
       (.m_axi_aclk(xdma_0_axi_aclk),
        .m_axi_araddr(axi_cdma_0_M_AXI_ARADDR),
        .m_axi_arburst(axi_cdma_0_M_AXI_ARBURST),
        .m_axi_arcache(axi_cdma_0_M_AXI_ARCACHE),
        .m_axi_arlen(axi_cdma_0_M_AXI_ARLEN),
        .m_axi_arprot(axi_cdma_0_M_AXI_ARPROT),
        .m_axi_arready(axi_cdma_0_M_AXI_ARREADY),
        .m_axi_arsize(axi_cdma_0_M_AXI_ARSIZE),
        .m_axi_arvalid(axi_cdma_0_M_AXI_ARVALID),
        .m_axi_awaddr(axi_cdma_0_M_AXI_AWADDR),
        .m_axi_awburst(axi_cdma_0_M_AXI_AWBURST),
        .m_axi_awcache(axi_cdma_0_M_AXI_AWCACHE),
        .m_axi_awlen(axi_cdma_0_M_AXI_AWLEN),
        .m_axi_awprot(axi_cdma_0_M_AXI_AWPROT),
        .m_axi_awready(axi_cdma_0_M_AXI_AWREADY),
        .m_axi_awsize(axi_cdma_0_M_AXI_AWSIZE),
        .m_axi_awvalid(axi_cdma_0_M_AXI_AWVALID),
        .m_axi_bready(axi_cdma_0_M_AXI_BREADY),
        .m_axi_bresp(axi_cdma_0_M_AXI_BRESP),
        .m_axi_bvalid(axi_cdma_0_M_AXI_BVALID),
        .m_axi_rdata(axi_cdma_0_M_AXI_RDATA),
        .m_axi_rlast(axi_cdma_0_M_AXI_RLAST),
        .m_axi_rready(axi_cdma_0_M_AXI_RREADY),
        .m_axi_rresp(axi_cdma_0_M_AXI_RRESP),
        .m_axi_rvalid(axi_cdma_0_M_AXI_RVALID),
        .m_axi_wdata(axi_cdma_0_M_AXI_WDATA),
        .m_axi_wlast(axi_cdma_0_M_AXI_WLAST),
        .m_axi_wready(axi_cdma_0_M_AXI_WREADY),
        .m_axi_wstrb(axi_cdma_0_M_AXI_WSTRB),
        .m_axi_wvalid(axi_cdma_0_M_AXI_WVALID),
        .s_axi_lite_aclk(xdma_0_axi_aclk),
        .s_axi_lite_araddr(xdma_dcim_bram_ctrl_0_m_axil_cdma_ARADDR[5:0]),
        .s_axi_lite_aresetn(xdma_0_axi_aresetn),
        .s_axi_lite_arready(xdma_dcim_bram_ctrl_0_m_axil_cdma_ARREADY),
        .s_axi_lite_arvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_ARVALID),
        .s_axi_lite_awaddr(xdma_dcim_bram_ctrl_0_m_axil_cdma_AWADDR[5:0]),
        .s_axi_lite_awready(xdma_dcim_bram_ctrl_0_m_axil_cdma_AWREADY),
        .s_axi_lite_awvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_AWVALID),
        .s_axi_lite_bready(xdma_dcim_bram_ctrl_0_m_axil_cdma_BREADY),
        .s_axi_lite_bresp(xdma_dcim_bram_ctrl_0_m_axil_cdma_BRESP),
        .s_axi_lite_bvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_BVALID),
        .s_axi_lite_rdata(xdma_dcim_bram_ctrl_0_m_axil_cdma_RDATA),
        .s_axi_lite_rready(xdma_dcim_bram_ctrl_0_m_axil_cdma_RREADY),
        .s_axi_lite_rresp(xdma_dcim_bram_ctrl_0_m_axil_cdma_RRESP),
        .s_axi_lite_rvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_RVALID),
        .s_axi_lite_wdata(xdma_dcim_bram_ctrl_0_m_axil_cdma_WDATA),
        .s_axi_lite_wready(xdma_dcim_bram_ctrl_0_m_axil_cdma_WREADY),
        .s_axi_lite_wvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_WVALID));
  xdma_dcim_bram_axi_mem_smc_0 axi_mem_smc
       (.M00_AXI_araddr(axi_mem_smc_M00_AXI_ARADDR),
        .M00_AXI_arburst(axi_mem_smc_M00_AXI_ARBURST),
        .M00_AXI_arcache(axi_mem_smc_M00_AXI_ARCACHE),
        .M00_AXI_arlen(axi_mem_smc_M00_AXI_ARLEN),
        .M00_AXI_arlock(axi_mem_smc_M00_AXI_ARLOCK),
        .M00_AXI_arprot(axi_mem_smc_M00_AXI_ARPROT),
        .M00_AXI_arready(axi_mem_smc_M00_AXI_ARREADY),
        .M00_AXI_arsize(axi_mem_smc_M00_AXI_ARSIZE),
        .M00_AXI_arvalid(axi_mem_smc_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_mem_smc_M00_AXI_AWADDR),
        .M00_AXI_awburst(axi_mem_smc_M00_AXI_AWBURST),
        .M00_AXI_awcache(axi_mem_smc_M00_AXI_AWCACHE),
        .M00_AXI_awlen(axi_mem_smc_M00_AXI_AWLEN),
        .M00_AXI_awlock(axi_mem_smc_M00_AXI_AWLOCK),
        .M00_AXI_awprot(axi_mem_smc_M00_AXI_AWPROT),
        .M00_AXI_awready(axi_mem_smc_M00_AXI_AWREADY),
        .M00_AXI_awsize(axi_mem_smc_M00_AXI_AWSIZE),
        .M00_AXI_awvalid(axi_mem_smc_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_mem_smc_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_mem_smc_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_mem_smc_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_mem_smc_M00_AXI_RDATA),
        .M00_AXI_rlast(axi_mem_smc_M00_AXI_RLAST),
        .M00_AXI_rready(axi_mem_smc_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_mem_smc_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_mem_smc_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_mem_smc_M00_AXI_WDATA),
        .M00_AXI_wlast(axi_mem_smc_M00_AXI_WLAST),
        .M00_AXI_wready(axi_mem_smc_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_mem_smc_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_mem_smc_M00_AXI_WVALID),
        .M01_AXI_araddr(axi_mem_smc_M01_AXI_ARADDR),
        .M01_AXI_arburst(axi_mem_smc_M01_AXI_ARBURST),
        .M01_AXI_arcache(axi_mem_smc_M01_AXI_ARCACHE),
        .M01_AXI_arlen(axi_mem_smc_M01_AXI_ARLEN),
        .M01_AXI_arlock(axi_mem_smc_M01_AXI_ARLOCK),
        .M01_AXI_arprot(axi_mem_smc_M01_AXI_ARPROT),
        .M01_AXI_arready(axi_mem_smc_M01_AXI_ARREADY),
        .M01_AXI_arsize(axi_mem_smc_M01_AXI_ARSIZE),
        .M01_AXI_arvalid(axi_mem_smc_M01_AXI_ARVALID),
        .M01_AXI_awaddr(axi_mem_smc_M01_AXI_AWADDR),
        .M01_AXI_awburst(axi_mem_smc_M01_AXI_AWBURST),
        .M01_AXI_awcache(axi_mem_smc_M01_AXI_AWCACHE),
        .M01_AXI_awlen(axi_mem_smc_M01_AXI_AWLEN),
        .M01_AXI_awlock(axi_mem_smc_M01_AXI_AWLOCK),
        .M01_AXI_awprot(axi_mem_smc_M01_AXI_AWPROT),
        .M01_AXI_awready(axi_mem_smc_M01_AXI_AWREADY),
        .M01_AXI_awsize(axi_mem_smc_M01_AXI_AWSIZE),
        .M01_AXI_awvalid(axi_mem_smc_M01_AXI_AWVALID),
        .M01_AXI_bready(axi_mem_smc_M01_AXI_BREADY),
        .M01_AXI_bresp(axi_mem_smc_M01_AXI_BRESP),
        .M01_AXI_bvalid(axi_mem_smc_M01_AXI_BVALID),
        .M01_AXI_rdata(axi_mem_smc_M01_AXI_RDATA),
        .M01_AXI_rlast(axi_mem_smc_M01_AXI_RLAST),
        .M01_AXI_rready(axi_mem_smc_M01_AXI_RREADY),
        .M01_AXI_rresp(axi_mem_smc_M01_AXI_RRESP),
        .M01_AXI_rvalid(axi_mem_smc_M01_AXI_RVALID),
        .M01_AXI_wdata(axi_mem_smc_M01_AXI_WDATA),
        .M01_AXI_wlast(axi_mem_smc_M01_AXI_WLAST),
        .M01_AXI_wready(axi_mem_smc_M01_AXI_WREADY),
        .M01_AXI_wstrb(axi_mem_smc_M01_AXI_WSTRB),
        .M01_AXI_wvalid(axi_mem_smc_M01_AXI_WVALID),
        .M02_AXI_araddr(axi_mem_smc_M02_AXI_ARADDR),
        .M02_AXI_arready(axi_mem_smc_M02_AXI_ARREADY),
        .M02_AXI_arvalid(axi_mem_smc_M02_AXI_ARVALID),
        .M02_AXI_awaddr(axi_mem_smc_M02_AXI_AWADDR),
        .M02_AXI_awready(axi_mem_smc_M02_AXI_AWREADY),
        .M02_AXI_awvalid(axi_mem_smc_M02_AXI_AWVALID),
        .M02_AXI_bready(axi_mem_smc_M02_AXI_BREADY),
        .M02_AXI_bresp(axi_mem_smc_M02_AXI_BRESP),
        .M02_AXI_bvalid(axi_mem_smc_M02_AXI_BVALID),
        .M02_AXI_rdata(axi_mem_smc_M02_AXI_RDATA),
        .M02_AXI_rready(axi_mem_smc_M02_AXI_RREADY),
        .M02_AXI_rresp(axi_mem_smc_M02_AXI_RRESP),
        .M02_AXI_rvalid(axi_mem_smc_M02_AXI_RVALID),
        .M02_AXI_wdata(axi_mem_smc_M02_AXI_WDATA),
        .M02_AXI_wready(axi_mem_smc_M02_AXI_WREADY),
        .M02_AXI_wstrb(axi_mem_smc_M02_AXI_WSTRB),
        .M02_AXI_wvalid(axi_mem_smc_M02_AXI_WVALID),
        .S00_AXI_araddr(xdma_0_M_AXI_ARADDR),
        .S00_AXI_arburst(xdma_0_M_AXI_ARBURST),
        .S00_AXI_arcache(xdma_0_M_AXI_ARCACHE),
        .S00_AXI_arid(xdma_0_M_AXI_ARID),
        .S00_AXI_arlen(xdma_0_M_AXI_ARLEN),
        .S00_AXI_arlock(xdma_0_M_AXI_ARLOCK),
        .S00_AXI_arprot(xdma_0_M_AXI_ARPROT),
        .S00_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S00_AXI_arready(xdma_0_M_AXI_ARREADY),
        .S00_AXI_arsize(xdma_0_M_AXI_ARSIZE),
        .S00_AXI_arvalid(xdma_0_M_AXI_ARVALID),
        .S00_AXI_awaddr(xdma_0_M_AXI_AWADDR),
        .S00_AXI_awburst(xdma_0_M_AXI_AWBURST),
        .S00_AXI_awcache(xdma_0_M_AXI_AWCACHE),
        .S00_AXI_awid(xdma_0_M_AXI_AWID),
        .S00_AXI_awlen(xdma_0_M_AXI_AWLEN),
        .S00_AXI_awlock(xdma_0_M_AXI_AWLOCK),
        .S00_AXI_awprot(xdma_0_M_AXI_AWPROT),
        .S00_AXI_awqos({1'b0,1'b0,1'b0,1'b0}),
        .S00_AXI_awready(xdma_0_M_AXI_AWREADY),
        .S00_AXI_awsize(xdma_0_M_AXI_AWSIZE),
        .S00_AXI_awvalid(xdma_0_M_AXI_AWVALID),
        .S00_AXI_bid(xdma_0_M_AXI_BID),
        .S00_AXI_bready(xdma_0_M_AXI_BREADY),
        .S00_AXI_bresp(xdma_0_M_AXI_BRESP),
        .S00_AXI_bvalid(xdma_0_M_AXI_BVALID),
        .S00_AXI_rdata(xdma_0_M_AXI_RDATA),
        .S00_AXI_rid(xdma_0_M_AXI_RID),
        .S00_AXI_rlast(xdma_0_M_AXI_RLAST),
        .S00_AXI_rready(xdma_0_M_AXI_RREADY),
        .S00_AXI_rresp(xdma_0_M_AXI_RRESP),
        .S00_AXI_rvalid(xdma_0_M_AXI_RVALID),
        .S00_AXI_wdata(xdma_0_M_AXI_WDATA),
        .S00_AXI_wlast(xdma_0_M_AXI_WLAST),
        .S00_AXI_wready(xdma_0_M_AXI_WREADY),
        .S00_AXI_wstrb(xdma_0_M_AXI_WSTRB),
        .S00_AXI_wvalid(xdma_0_M_AXI_WVALID),
        .S01_AXI_araddr(axi_cdma_0_M_AXI_ARADDR),
        .S01_AXI_arburst(axi_cdma_0_M_AXI_ARBURST),
        .S01_AXI_arcache(axi_cdma_0_M_AXI_ARCACHE),
        .S01_AXI_arlen(axi_cdma_0_M_AXI_ARLEN),
        .S01_AXI_arlock(1'b0),
        .S01_AXI_arprot(axi_cdma_0_M_AXI_ARPROT),
        .S01_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_arready(axi_cdma_0_M_AXI_ARREADY),
        .S01_AXI_arsize(axi_cdma_0_M_AXI_ARSIZE),
        .S01_AXI_arvalid(axi_cdma_0_M_AXI_ARVALID),
        .S01_AXI_awaddr(axi_cdma_0_M_AXI_AWADDR),
        .S01_AXI_awburst(axi_cdma_0_M_AXI_AWBURST),
        .S01_AXI_awcache(axi_cdma_0_M_AXI_AWCACHE),
        .S01_AXI_awlen(axi_cdma_0_M_AXI_AWLEN),
        .S01_AXI_awlock(1'b0),
        .S01_AXI_awprot(axi_cdma_0_M_AXI_AWPROT),
        .S01_AXI_awqos({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_awready(axi_cdma_0_M_AXI_AWREADY),
        .S01_AXI_awsize(axi_cdma_0_M_AXI_AWSIZE),
        .S01_AXI_awvalid(axi_cdma_0_M_AXI_AWVALID),
        .S01_AXI_bready(axi_cdma_0_M_AXI_BREADY),
        .S01_AXI_bresp(axi_cdma_0_M_AXI_BRESP),
        .S01_AXI_bvalid(axi_cdma_0_M_AXI_BVALID),
        .S01_AXI_rdata(axi_cdma_0_M_AXI_RDATA),
        .S01_AXI_rlast(axi_cdma_0_M_AXI_RLAST),
        .S01_AXI_rready(axi_cdma_0_M_AXI_RREADY),
        .S01_AXI_rresp(axi_cdma_0_M_AXI_RRESP),
        .S01_AXI_rvalid(axi_cdma_0_M_AXI_RVALID),
        .S01_AXI_wdata(axi_cdma_0_M_AXI_WDATA),
        .S01_AXI_wlast(axi_cdma_0_M_AXI_WLAST),
        .S01_AXI_wready(axi_cdma_0_M_AXI_WREADY),
        .S01_AXI_wstrb(axi_cdma_0_M_AXI_WSTRB),
        .S01_AXI_wvalid(axi_cdma_0_M_AXI_WVALID),
        .aclk(xdma_0_axi_aclk),
        .aresetn(xdma_0_axi_aresetn));
  xdma_dcim_bram_bram_inv_0 bram_inv
       (.Op1(xdma_0_axi_aresetn),
        .Res(bram_inv_Res));
  xdma_dcim_bram_global_bram_0 global_bram
       (.addra({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,global_bram_ctrl_BRAM_PORTA_ADDR}),
        .clka(global_bram_ctrl_BRAM_PORTA_CLK),
        .dina(global_bram_ctrl_BRAM_PORTA_DIN),
        .douta(global_bram_ctrl_BRAM_PORTA_DOUT),
        .ena(global_bram_ctrl_BRAM_PORTA_EN),
        .rsta(global_bram_ctrl_BRAM_PORTA_RST),
        .wea(global_bram_ctrl_BRAM_PORTA_WE));
  xdma_dcim_bram_global_bram_ctrl_0 global_bram_ctrl
       (.bram_addr_a(global_bram_ctrl_BRAM_PORTA_ADDR),
        .bram_clk_a(global_bram_ctrl_BRAM_PORTA_CLK),
        .bram_en_a(global_bram_ctrl_BRAM_PORTA_EN),
        .bram_rddata_a(global_bram_ctrl_BRAM_PORTA_DOUT),
        .bram_rst_a(global_bram_ctrl_BRAM_PORTA_RST),
        .bram_we_a(global_bram_ctrl_BRAM_PORTA_WE),
        .bram_wrdata_a(global_bram_ctrl_BRAM_PORTA_DIN),
        .s_axi_aclk(xdma_0_axi_aclk),
        .s_axi_araddr(axi_mem_smc_M00_AXI_ARADDR),
        .s_axi_arburst(axi_mem_smc_M00_AXI_ARBURST),
        .s_axi_arcache(axi_mem_smc_M00_AXI_ARCACHE),
        .s_axi_aresetn(xdma_0_axi_aresetn),
        .s_axi_arlen(axi_mem_smc_M00_AXI_ARLEN),
        .s_axi_arlock(axi_mem_smc_M00_AXI_ARLOCK),
        .s_axi_arprot(axi_mem_smc_M00_AXI_ARPROT),
        .s_axi_arready(axi_mem_smc_M00_AXI_ARREADY),
        .s_axi_arsize(axi_mem_smc_M00_AXI_ARSIZE),
        .s_axi_arvalid(axi_mem_smc_M00_AXI_ARVALID),
        .s_axi_awaddr(axi_mem_smc_M00_AXI_AWADDR),
        .s_axi_awburst(axi_mem_smc_M00_AXI_AWBURST),
        .s_axi_awcache(axi_mem_smc_M00_AXI_AWCACHE),
        .s_axi_awlen(axi_mem_smc_M00_AXI_AWLEN),
        .s_axi_awlock(axi_mem_smc_M00_AXI_AWLOCK),
        .s_axi_awprot(axi_mem_smc_M00_AXI_AWPROT),
        .s_axi_awready(axi_mem_smc_M00_AXI_AWREADY),
        .s_axi_awsize(axi_mem_smc_M00_AXI_AWSIZE),
        .s_axi_awvalid(axi_mem_smc_M00_AXI_AWVALID),
        .s_axi_bready(axi_mem_smc_M00_AXI_BREADY),
        .s_axi_bresp(axi_mem_smc_M00_AXI_BRESP),
        .s_axi_bvalid(axi_mem_smc_M00_AXI_BVALID),
        .s_axi_rdata(axi_mem_smc_M00_AXI_RDATA),
        .s_axi_rlast(axi_mem_smc_M00_AXI_RLAST),
        .s_axi_rready(axi_mem_smc_M00_AXI_RREADY),
        .s_axi_rresp(axi_mem_smc_M00_AXI_RRESP),
        .s_axi_rvalid(axi_mem_smc_M00_AXI_RVALID),
        .s_axi_wdata(axi_mem_smc_M00_AXI_WDATA),
        .s_axi_wlast(axi_mem_smc_M00_AXI_WLAST),
        .s_axi_wready(axi_mem_smc_M00_AXI_WREADY),
        .s_axi_wstrb(axi_mem_smc_M00_AXI_WSTRB),
        .s_axi_wvalid(axi_mem_smc_M00_AXI_WVALID));
  xdma_dcim_bram_local_bram_0 local_bram
       (.addra({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,local_bram_ctrl_BRAM_PORTA_ADDR}),
        .addrb(xdma_dcim_bram_ctrl_0_local_bram_addr),
        .clka(local_bram_ctrl_BRAM_PORTA_CLK),
        .clkb(xdma_0_axi_aclk),
        .dina(local_bram_ctrl_BRAM_PORTA_DIN),
        .dinb(xdma_dcim_bram_ctrl_0_local_bram_din),
        .douta(local_bram_ctrl_BRAM_PORTA_DOUT),
        .doutb(local_bram_doutb),
        .ena(local_bram_ctrl_BRAM_PORTA_EN),
        .enb(xdma_dcim_bram_ctrl_0_local_bram_en),
        .rsta(local_bram_ctrl_BRAM_PORTA_RST),
        .rstb(bram_inv_Res),
        .wea(local_bram_ctrl_BRAM_PORTA_WE),
        .web(xdma_dcim_bram_ctrl_0_local_bram_we));
  xdma_dcim_bram_local_bram_ctrl_0 local_bram_ctrl
       (.bram_addr_a(local_bram_ctrl_BRAM_PORTA_ADDR),
        .bram_clk_a(local_bram_ctrl_BRAM_PORTA_CLK),
        .bram_en_a(local_bram_ctrl_BRAM_PORTA_EN),
        .bram_rddata_a(local_bram_ctrl_BRAM_PORTA_DOUT),
        .bram_rst_a(local_bram_ctrl_BRAM_PORTA_RST),
        .bram_we_a(local_bram_ctrl_BRAM_PORTA_WE),
        .bram_wrdata_a(local_bram_ctrl_BRAM_PORTA_DIN),
        .s_axi_aclk(xdma_0_axi_aclk),
        .s_axi_araddr(axi_mem_smc_M01_AXI_ARADDR),
        .s_axi_arburst(axi_mem_smc_M01_AXI_ARBURST),
        .s_axi_arcache(axi_mem_smc_M01_AXI_ARCACHE),
        .s_axi_aresetn(xdma_0_axi_aresetn),
        .s_axi_arlen(axi_mem_smc_M01_AXI_ARLEN),
        .s_axi_arlock(axi_mem_smc_M01_AXI_ARLOCK),
        .s_axi_arprot(axi_mem_smc_M01_AXI_ARPROT),
        .s_axi_arready(axi_mem_smc_M01_AXI_ARREADY),
        .s_axi_arsize(axi_mem_smc_M01_AXI_ARSIZE),
        .s_axi_arvalid(axi_mem_smc_M01_AXI_ARVALID),
        .s_axi_awaddr(axi_mem_smc_M01_AXI_AWADDR),
        .s_axi_awburst(axi_mem_smc_M01_AXI_AWBURST),
        .s_axi_awcache(axi_mem_smc_M01_AXI_AWCACHE),
        .s_axi_awlen(axi_mem_smc_M01_AXI_AWLEN),
        .s_axi_awlock(axi_mem_smc_M01_AXI_AWLOCK),
        .s_axi_awprot(axi_mem_smc_M01_AXI_AWPROT),
        .s_axi_awready(axi_mem_smc_M01_AXI_AWREADY),
        .s_axi_awsize(axi_mem_smc_M01_AXI_AWSIZE),
        .s_axi_awvalid(axi_mem_smc_M01_AXI_AWVALID),
        .s_axi_bready(axi_mem_smc_M01_AXI_BREADY),
        .s_axi_bresp(axi_mem_smc_M01_AXI_BRESP),
        .s_axi_bvalid(axi_mem_smc_M01_AXI_BVALID),
        .s_axi_rdata(axi_mem_smc_M01_AXI_RDATA),
        .s_axi_rlast(axi_mem_smc_M01_AXI_RLAST),
        .s_axi_rready(axi_mem_smc_M01_AXI_RREADY),
        .s_axi_rresp(axi_mem_smc_M01_AXI_RRESP),
        .s_axi_rvalid(axi_mem_smc_M01_AXI_RVALID),
        .s_axi_wdata(axi_mem_smc_M01_AXI_WDATA),
        .s_axi_wlast(axi_mem_smc_M01_AXI_WLAST),
        .s_axi_wready(axi_mem_smc_M01_AXI_WREADY),
        .s_axi_wstrb(axi_mem_smc_M01_AXI_WSTRB),
        .s_axi_wvalid(axi_mem_smc_M01_AXI_WVALID));
  xdma_dcim_bram_util_ds_buf_0 util_ds_buf
       (.IBUF_DS_N(pcie_refclk_clk_n),
        .IBUF_DS_ODIV2(util_ds_buf_IBUF_DS_ODIV2),
        .IBUF_DS_P(pcie_refclk_clk_p),
        .IBUF_OUT(util_ds_buf_IBUF_OUT));
  xdma_dcim_bram_xdma_0_0 xdma_0
       (.axi_aclk(xdma_0_axi_aclk),
        .axi_aresetn(xdma_0_axi_aresetn),
        .m_axi_araddr(xdma_0_M_AXI_ARADDR),
        .m_axi_arburst(xdma_0_M_AXI_ARBURST),
        .m_axi_arcache(xdma_0_M_AXI_ARCACHE),
        .m_axi_arid(xdma_0_M_AXI_ARID),
        .m_axi_arlen(xdma_0_M_AXI_ARLEN),
        .m_axi_arlock(xdma_0_M_AXI_ARLOCK),
        .m_axi_arprot(xdma_0_M_AXI_ARPROT),
        .m_axi_arready(xdma_0_M_AXI_ARREADY),
        .m_axi_arsize(xdma_0_M_AXI_ARSIZE),
        .m_axi_arvalid(xdma_0_M_AXI_ARVALID),
        .m_axi_awaddr(xdma_0_M_AXI_AWADDR),
        .m_axi_awburst(xdma_0_M_AXI_AWBURST),
        .m_axi_awcache(xdma_0_M_AXI_AWCACHE),
        .m_axi_awid(xdma_0_M_AXI_AWID),
        .m_axi_awlen(xdma_0_M_AXI_AWLEN),
        .m_axi_awlock(xdma_0_M_AXI_AWLOCK),
        .m_axi_awprot(xdma_0_M_AXI_AWPROT),
        .m_axi_awready(xdma_0_M_AXI_AWREADY),
        .m_axi_awsize(xdma_0_M_AXI_AWSIZE),
        .m_axi_awvalid(xdma_0_M_AXI_AWVALID),
        .m_axi_bid(xdma_0_M_AXI_BID),
        .m_axi_bready(xdma_0_M_AXI_BREADY),
        .m_axi_bresp(xdma_0_M_AXI_BRESP),
        .m_axi_bvalid(xdma_0_M_AXI_BVALID),
        .m_axi_rdata(xdma_0_M_AXI_RDATA),
        .m_axi_rid(xdma_0_M_AXI_RID),
        .m_axi_rlast(xdma_0_M_AXI_RLAST),
        .m_axi_rready(xdma_0_M_AXI_RREADY),
        .m_axi_rresp(xdma_0_M_AXI_RRESP),
        .m_axi_rvalid(xdma_0_M_AXI_RVALID),
        .m_axi_wdata(xdma_0_M_AXI_WDATA),
        .m_axi_wlast(xdma_0_M_AXI_WLAST),
        .m_axi_wready(xdma_0_M_AXI_WREADY),
        .m_axi_wstrb(xdma_0_M_AXI_WSTRB),
        .m_axi_wvalid(xdma_0_M_AXI_WVALID),
        .pci_exp_rxn(pci_express_x8_rxn),
        .pci_exp_rxp(pci_express_x8_rxp),
        .pci_exp_txn(pci_express_x8_txn),
        .pci_exp_txp(pci_express_x8_txp),
        .sys_clk(util_ds_buf_IBUF_DS_ODIV2),
        .sys_clk_gt(util_ds_buf_IBUF_OUT),
        .sys_rst_n(xdma_inv_Res),
        .user_lnk_up(user_lnk_up_0),
        .usr_irq_req(xdma_constant_dout));
  xdma_dcim_bram_xdma_constant_0 xdma_constant
       (.dout(xdma_constant_dout));
  xdma_dcim_bram_xdma_dcim_bram_ctrl_0_0 xdma_dcim_bram_ctrl_0
       (.aclk(xdma_0_axi_aclk),
        .aresetn(xdma_0_axi_aresetn),
        .local_bram_addr(xdma_dcim_bram_ctrl_0_local_bram_addr),
        .local_bram_din(xdma_dcim_bram_ctrl_0_local_bram_din),
        .local_bram_dout(local_bram_doutb),
        .local_bram_en(xdma_dcim_bram_ctrl_0_local_bram_en),
        .local_bram_we(xdma_dcim_bram_ctrl_0_local_bram_we),
        .m_axil_cdma_araddr(xdma_dcim_bram_ctrl_0_m_axil_cdma_ARADDR),
        .m_axil_cdma_arready(xdma_dcim_bram_ctrl_0_m_axil_cdma_ARREADY),
        .m_axil_cdma_arvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_ARVALID),
        .m_axil_cdma_awaddr(xdma_dcim_bram_ctrl_0_m_axil_cdma_AWADDR),
        .m_axil_cdma_awready(xdma_dcim_bram_ctrl_0_m_axil_cdma_AWREADY),
        .m_axil_cdma_awvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_AWVALID),
        .m_axil_cdma_bready(xdma_dcim_bram_ctrl_0_m_axil_cdma_BREADY),
        .m_axil_cdma_bresp(xdma_dcim_bram_ctrl_0_m_axil_cdma_BRESP),
        .m_axil_cdma_bvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_BVALID),
        .m_axil_cdma_rdata(xdma_dcim_bram_ctrl_0_m_axil_cdma_RDATA),
        .m_axil_cdma_rready(xdma_dcim_bram_ctrl_0_m_axil_cdma_RREADY),
        .m_axil_cdma_rresp(xdma_dcim_bram_ctrl_0_m_axil_cdma_RRESP),
        .m_axil_cdma_rvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_RVALID),
        .m_axil_cdma_wdata(xdma_dcim_bram_ctrl_0_m_axil_cdma_WDATA),
        .m_axil_cdma_wready(xdma_dcim_bram_ctrl_0_m_axil_cdma_WREADY),
        .m_axil_cdma_wvalid(xdma_dcim_bram_ctrl_0_m_axil_cdma_WVALID),
        .s_axil_araddr(axi_mem_smc_M02_AXI_ARADDR),
        .s_axil_arready(axi_mem_smc_M02_AXI_ARREADY),
        .s_axil_arvalid(axi_mem_smc_M02_AXI_ARVALID),
        .s_axil_awaddr(axi_mem_smc_M02_AXI_AWADDR),
        .s_axil_awready(axi_mem_smc_M02_AXI_AWREADY),
        .s_axil_awvalid(axi_mem_smc_M02_AXI_AWVALID),
        .s_axil_bready(axi_mem_smc_M02_AXI_BREADY),
        .s_axil_bresp(axi_mem_smc_M02_AXI_BRESP),
        .s_axil_bvalid(axi_mem_smc_M02_AXI_BVALID),
        .s_axil_rdata(axi_mem_smc_M02_AXI_RDATA),
        .s_axil_rready(axi_mem_smc_M02_AXI_RREADY),
        .s_axil_rresp(axi_mem_smc_M02_AXI_RRESP),
        .s_axil_rvalid(axi_mem_smc_M02_AXI_RVALID),
        .s_axil_wdata(axi_mem_smc_M02_AXI_WDATA),
        .s_axil_wready(axi_mem_smc_M02_AXI_WREADY),
        .s_axil_wstrb(axi_mem_smc_M02_AXI_WSTRB),
        .s_axil_wvalid(axi_mem_smc_M02_AXI_WVALID));
  xdma_dcim_bram_xdma_inv_0 xdma_inv
       (.Op1(cpu_reset),
        .Res(xdma_inv_Res));
endmodule
