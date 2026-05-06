xdma_dcim_hbm bring-up design

Data path:
  XDMA/CDMA -> SmartConnect -> HBM
  XDMA/CDMA -> SmartConnect -> PE ibuf/obuf AXI BRAM controllers
  XDMA      -> SmartConnect -> CDMA registers and PE GPIO control/status

HBM keeps the previous xdma_hbm setup: 32 SAXI ports, 256 MB per port, 450 MHz
HBM AXI clock, and 100 MHz HBM ref/APB clocks.

The PE/DCIM clock is xdma_0/axi_aclk, currently 250 MHz.  A 500 MHz PE clock is
not used in this version because PE.sv infers single-clock ibuf/obuf RAMs whose
system-side port is driven by AXI BRAM controllers.
