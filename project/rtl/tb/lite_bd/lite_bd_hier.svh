// Hierarchy paths for force/release of xdma_0 M_AXI (BD export / bd/lite/sim/lite.v).
// Override at runtime: +LITE_BD_DUT=tb_lite_bd_e2e.dut +LITE_BD_XDMA_PREFIX=dut.lite_i
`ifndef LITE_BD_HIER_SVH
`define LITE_BD_HIER_SVH

// DUT root: override per-TB via `define LITE_BD_DUT before `include
`ifndef LITE_BD_DUT
  `define LITE_BD_DUT tb_lite_bd_e2e.dut
`endif

`ifndef LITE_BD_XDMA_PREFIX
  // M_AXI nets are on lite boundary (xdma_0_M_AXI_*), not inside xdma_0 IP
  `define LITE_BD_XDMA_PREFIX `LITE_BD_DUT.lite_i
`endif

`define LITE_BD_M_AXI_AWADDR  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWADDR
`define LITE_BD_M_AXI_AWLEN   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWLEN
`define LITE_BD_M_AXI_AWSIZE  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWSIZE
`define LITE_BD_M_AXI_AWBURST `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWBURST
`define LITE_BD_M_AXI_AWPROT  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWPROT
`define LITE_BD_M_AXI_AWVALID `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWVALID
`define LITE_BD_M_AXI_AWREADY `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWREADY
`define LITE_BD_M_AXI_AWID    `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWID
`define LITE_BD_M_AXI_AWLOCK  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWLOCK
`define LITE_BD_M_AXI_AWCACHE `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_AWCACHE

`define LITE_BD_M_AXI_WDATA   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_WDATA
`define LITE_BD_M_AXI_WSTRB   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_WSTRB
`define LITE_BD_M_AXI_WLAST   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_WLAST
`define LITE_BD_M_AXI_WVALID  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_WVALID
`define LITE_BD_M_AXI_WREADY  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_WREADY

`define LITE_BD_M_AXI_BID     `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_BID
`define LITE_BD_M_AXI_BRESP   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_BRESP
`define LITE_BD_M_AXI_BVALID  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_BVALID
`define LITE_BD_M_AXI_BREADY  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_BREADY

`define LITE_BD_M_AXI_ARADDR  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARADDR
`define LITE_BD_M_AXI_ARLEN   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARLEN
`define LITE_BD_M_AXI_ARSIZE  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARSIZE
`define LITE_BD_M_AXI_ARBURST `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARBURST
`define LITE_BD_M_AXI_ARPROT  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARPROT
`define LITE_BD_M_AXI_ARVALID `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARVALID
`define LITE_BD_M_AXI_ARREADY `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARREADY
`define LITE_BD_M_AXI_ARID    `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARID
`define LITE_BD_M_AXI_ARLOCK  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARLOCK
`define LITE_BD_M_AXI_ARCACHE `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_ARCACHE

`define LITE_BD_M_AXI_RDATA   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_RDATA
`define LITE_BD_M_AXI_RID     `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_RID
`define LITE_BD_M_AXI_RRESP   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_RRESP
`define LITE_BD_M_AXI_RLAST   `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_RLAST
`define LITE_BD_M_AXI_RVALID  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_RVALID
`define LITE_BD_M_AXI_RREADY  `LITE_BD_XDMA_PREFIX.xdma_0_M_AXI_RREADY

// XDMA instance inside lite (release internal M_AXI drivers after force)
`ifndef LITE_BD_XDMA_INST
  `define LITE_BD_XDMA_INST `LITE_BD_DUT.lite_i.xdma_0
`endif

// Main reset signals for force/release and preload timing gates
`define LITE_BD_MAIN_ARESETN       `LITE_BD_DUT.lite_i.main_rst_peripheral_aresetn
`define LITE_BD_HBM_ARESETN        `LITE_BD_DUT.lite_i.hbm_rst_peripheral_aresetn
// Use force/release on these instead of AXI writes to bypass SmartConnect/HBM
// initialisation dependencies in simulation.
`define LITE_BD_VPU_INST_COUNT     `LITE_BD_DUT.lite_i.vpu_regs_inst_count
`define LITE_BD_DECODER_START      `LITE_BD_DUT.lite_i.vpu_regs_decoder_start
`define LITE_BD_DECODER_DONE       `LITE_BD_DUT.lite_i.inst_decoder_decoder_done
// HBM clock PLL locked — both must be high before SmartConnect routes are ready
`define LITE_BD_HBM_REF_CLK_LOCKED `LITE_BD_DUT.lite_i.hbm_ref_clk_wiz_locked
`define LITE_BD_HBM_AXI_CLK_LOCKED `LITE_BD_DUT.lite_i.hbm_axi_clk_wiz_locked

`endif
