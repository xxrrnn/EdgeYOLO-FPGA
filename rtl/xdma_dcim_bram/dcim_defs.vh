`ifndef XDMA_DCIM_BRAM_DEFS_VH
`define XDMA_DCIM_BRAM_DEFS_VH

// Global parameters for the xdma_dcim_bram compute block.
// Keep system-wide architectural choices here so PE/DCIM_Macro do not each
// carry their own parameter list.

`define DCIM_ADDR_WIDTH       32
`define DCIM_AXI_BRAM_ADDR_WIDTH 16
`define DCIM_IBUF_ADDR_WIDTH  11
`define DCIM_OBUF_ADDR_WIDTH  11
`define DCIM_BRAM_DATA_WIDTH  256
`define DCIM_BRAM_BYTES       (`DCIM_BRAM_DATA_WIDTH / 8)

`define DCIM_WD1              4
`define DCIM_CH_IN            16
`define DCIM_CH_OUT           16
`define DCIM_ACC_MAX          16

`define DCIM_WD2              (2 * `DCIM_WD1 + $clog2(`DCIM_CH_IN))
`define DCIM_WD3              (`DCIM_WD2 + $clog2(`DCIM_ACC_MAX))
`define DCIM_ACT_WIDTH        (`DCIM_CH_IN * `DCIM_WD1)
`define DCIM_TILE_WIDTH       (`DCIM_CH_IN * `DCIM_CH_OUT * `DCIM_WD1)
`define DCIM_RES_WIDTH        (`DCIM_CH_OUT * `DCIM_WD3)

`define DCIM_MODE_UINT4       3'b000
`define DCIM_MODE_UINT8       3'b010
`define DCIM_MODE_UINT16      3'b011
`define DCIM_MODE_INT4        3'b100
`define DCIM_MODE_INT8        3'b110
`define DCIM_MODE_INT16       3'b111

`endif
