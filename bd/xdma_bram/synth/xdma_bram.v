//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.2.2 (lin64) Build 6060944 Thu Mar 06 19:10:09 MST 2025
//Date        : Tue Apr 28 04:54:12 2026
//Host        : DESKTOP-5NNBJ0V running 64-bit Ubuntu 22.04.1 LTS
//Command     : generate_target xdma_bram.bd
//Design      : xdma_bram
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "xdma_bram,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=xdma_bram,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=6,numReposBlks=6,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=USER,synth_mode=Hierarchical}" *) (* HW_HANDOFF = "xdma_bram.hwdef" *) 
module xdma_bram
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

  wire [14:0]axi_bram_ctrl_0_BRAM_PORTA_ADDR;
  wire axi_bram_ctrl_0_BRAM_PORTA_CLK;
  wire [255:0]axi_bram_ctrl_0_BRAM_PORTA_DIN;
  wire [255:0]axi_bram_ctrl_0_BRAM_PORTA_DOUT;
  wire axi_bram_ctrl_0_BRAM_PORTA_EN;
  wire axi_bram_ctrl_0_BRAM_PORTA_RST;
  wire [31:0]axi_bram_ctrl_0_BRAM_PORTA_WE;
  wire cpu_reset;
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
  wire [0:0]xdma_inv_Res;

  xdma_bram_axi_bram_ctrl_0_0 axi_bram_ctrl_0
       (.bram_addr_a(axi_bram_ctrl_0_BRAM_PORTA_ADDR),
        .bram_clk_a(axi_bram_ctrl_0_BRAM_PORTA_CLK),
        .bram_en_a(axi_bram_ctrl_0_BRAM_PORTA_EN),
        .bram_rddata_a(axi_bram_ctrl_0_BRAM_PORTA_DOUT),
        .bram_rst_a(axi_bram_ctrl_0_BRAM_PORTA_RST),
        .bram_we_a(axi_bram_ctrl_0_BRAM_PORTA_WE),
        .bram_wrdata_a(axi_bram_ctrl_0_BRAM_PORTA_DIN),
        .s_axi_aclk(xdma_0_axi_aclk),
        .s_axi_araddr(xdma_0_M_AXI_ARADDR[14:0]),
        .s_axi_arburst(xdma_0_M_AXI_ARBURST),
        .s_axi_arcache(xdma_0_M_AXI_ARCACHE),
        .s_axi_aresetn(xdma_0_axi_aresetn),
        .s_axi_arid(xdma_0_M_AXI_ARID),
        .s_axi_arlen(xdma_0_M_AXI_ARLEN),
        .s_axi_arlock(xdma_0_M_AXI_ARLOCK),
        .s_axi_arprot(xdma_0_M_AXI_ARPROT),
        .s_axi_arready(xdma_0_M_AXI_ARREADY),
        .s_axi_arsize(xdma_0_M_AXI_ARSIZE),
        .s_axi_arvalid(xdma_0_M_AXI_ARVALID),
        .s_axi_awaddr(xdma_0_M_AXI_AWADDR[14:0]),
        .s_axi_awburst(xdma_0_M_AXI_AWBURST),
        .s_axi_awcache(xdma_0_M_AXI_AWCACHE),
        .s_axi_awid(xdma_0_M_AXI_AWID),
        .s_axi_awlen(xdma_0_M_AXI_AWLEN),
        .s_axi_awlock(xdma_0_M_AXI_AWLOCK),
        .s_axi_awprot(xdma_0_M_AXI_AWPROT),
        .s_axi_awready(xdma_0_M_AXI_AWREADY),
        .s_axi_awsize(xdma_0_M_AXI_AWSIZE),
        .s_axi_awvalid(xdma_0_M_AXI_AWVALID),
        .s_axi_bid(xdma_0_M_AXI_BID),
        .s_axi_bready(xdma_0_M_AXI_BREADY),
        .s_axi_bresp(xdma_0_M_AXI_BRESP),
        .s_axi_bvalid(xdma_0_M_AXI_BVALID),
        .s_axi_rdata(xdma_0_M_AXI_RDATA),
        .s_axi_rid(xdma_0_M_AXI_RID),
        .s_axi_rlast(xdma_0_M_AXI_RLAST),
        .s_axi_rready(xdma_0_M_AXI_RREADY),
        .s_axi_rresp(xdma_0_M_AXI_RRESP),
        .s_axi_rvalid(xdma_0_M_AXI_RVALID),
        .s_axi_wdata(xdma_0_M_AXI_WDATA),
        .s_axi_wlast(xdma_0_M_AXI_WLAST),
        .s_axi_wready(xdma_0_M_AXI_WREADY),
        .s_axi_wstrb(xdma_0_M_AXI_WSTRB),
        .s_axi_wvalid(xdma_0_M_AXI_WVALID));
  xdma_bram_axi_bram_ctrl_0_bram_0 axi_bram_ctrl_0_bram
       (.addra({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,axi_bram_ctrl_0_BRAM_PORTA_ADDR}),
        .clka(axi_bram_ctrl_0_BRAM_PORTA_CLK),
        .dina(axi_bram_ctrl_0_BRAM_PORTA_DIN),
        .douta(axi_bram_ctrl_0_BRAM_PORTA_DOUT),
        .ena(axi_bram_ctrl_0_BRAM_PORTA_EN),
        .rsta(axi_bram_ctrl_0_BRAM_PORTA_RST),
        .wea(axi_bram_ctrl_0_BRAM_PORTA_WE));
  xdma_bram_util_ds_buf_0 util_ds_buf
       (.IBUF_DS_N(pcie_refclk_clk_n),
        .IBUF_DS_ODIV2(util_ds_buf_IBUF_DS_ODIV2),
        .IBUF_DS_P(pcie_refclk_clk_p),
        .IBUF_OUT(util_ds_buf_IBUF_OUT));
  xdma_bram_xdma_0_0 xdma_0
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
  xdma_bram_xdma_constant_0 xdma_constant
       (.dout(xdma_constant_dout));
  xdma_bram_xdma_inv_0 xdma_inv
       (.Op1(cpu_reset),
        .Res(xdma_inv_Res));
endmodule
