// Physical AXI address map — must match scripts/ip/bd/lite/address.tcl (chip-v3)
// IBUF: 0x1_0000_0000 + t*0x80000 (512KB/tile)
// OBUF: 0x1_0100_0000 + t*0x40000 (256KB/tile)
`ifndef E2E_LITE_ADDRMAP_SVH
`define E2E_LITE_ADDRMAP_SVH

localparam int E2E_NUM_TILES = `DCIM_NUM_TILES;

localparam logic [63:0] E2E_IBUF_BASE         = 64'h0000_0001_0000_0000;
localparam logic [63:0] E2E_IBUF_TILE_SIZE    = 64'h0008_0000;            // 512KB per tile
localparam logic [63:0] E2E_IBUF_SIZE         = E2E_IBUF_TILE_SIZE * E2E_NUM_TILES;

localparam logic [63:0] E2E_IBUF_TILE0_BASE   = E2E_IBUF_BASE + 0 * E2E_IBUF_TILE_SIZE;
localparam logic [63:0] E2E_IBUF_TILE1_BASE   = E2E_IBUF_BASE + 1 * E2E_IBUF_TILE_SIZE;
localparam logic [63:0] E2E_IBUF_TILE2_BASE   = E2E_IBUF_BASE + 2 * E2E_IBUF_TILE_SIZE;
localparam logic [63:0] E2E_IBUF_TILE3_BASE   = E2E_IBUF_BASE + 3 * E2E_IBUF_TILE_SIZE;
localparam logic [63:0] E2E_IBUF_TILE4_BASE   = E2E_IBUF_BASE + 4 * E2E_IBUF_TILE_SIZE;
localparam logic [63:0] E2E_IBUF_TILE5_BASE   = E2E_IBUF_BASE + 5 * E2E_IBUF_TILE_SIZE;
localparam logic [63:0] E2E_IBUF_TILE6_BASE   = E2E_IBUF_BASE + 6 * E2E_IBUF_TILE_SIZE;
localparam logic [63:0] E2E_IBUF_TILE7_BASE   = E2E_IBUF_BASE + 7 * E2E_IBUF_TILE_SIZE;

localparam logic [63:0] E2E_TILE_OBUF_BASE    = 64'h0000_0001_0100_0000;
localparam logic [63:0] E2E_TILE_OBUF_SIZE    = 64'h0004_0000;            // 256KB per tile

localparam logic [63:0] E2E_TILE_OBUF0_BASE   = E2E_TILE_OBUF_BASE + 0 * E2E_TILE_OBUF_SIZE;
localparam logic [63:0] E2E_TILE_OBUF1_BASE   = E2E_TILE_OBUF_BASE + 1 * E2E_TILE_OBUF_SIZE;
localparam logic [63:0] E2E_TILE_OBUF2_BASE   = E2E_TILE_OBUF_BASE + 2 * E2E_TILE_OBUF_SIZE;
localparam logic [63:0] E2E_TILE_OBUF3_BASE   = E2E_TILE_OBUF_BASE + 3 * E2E_TILE_OBUF_SIZE;
localparam logic [63:0] E2E_TILE_OBUF4_BASE   = E2E_TILE_OBUF_BASE + 4 * E2E_TILE_OBUF_SIZE;
localparam logic [63:0] E2E_TILE_OBUF5_BASE   = E2E_TILE_OBUF_BASE + 5 * E2E_TILE_OBUF_SIZE;
localparam logic [63:0] E2E_TILE_OBUF6_BASE   = E2E_TILE_OBUF_BASE + 6 * E2E_TILE_OBUF_SIZE;
localparam logic [63:0] E2E_TILE_OBUF7_BASE   = E2E_TILE_OBUF_BASE + 7 * E2E_TILE_OBUF_SIZE;

localparam logic [63:0] E2E_VPU_BUF_BASE      = 64'h0000_0001_0200_0000;  // 8MB
localparam logic [63:0] E2E_VPU_BUF_SIZE      = 64'h0080_0000;            // 8MB
localparam logic [63:0] E2E_WB_BASE           = 64'h0000_0001_0300_0000;  // 32KB
localparam logic [63:0] E2E_WB_SIZE           = 64'h0000_8000;            // 32KB
localparam logic [63:0] E2E_INST_BASE         = 64'h0000_0001_0400_0000;  // 128KB
localparam logic [63:0] E2E_REGS_BASE         = 64'h0000_0001_0500_0000;  // 4KB

// Backward compat: E2E_OBUF_BASE/SIZE alias to VPU_BUF (VPU tests use OBUF semantics)
localparam logic [63:0] E2E_OBUF_BASE         = E2E_VPU_BUF_BASE;
localparam logic [63:0] E2E_OBUF_SIZE         = E2E_VPU_BUF_SIZE;

// CDMA AXI-Lite window (SEG_axi_cdma_0_Reg @ 0 in address.tcl)
localparam logic [31:0] E2E_CDMA_LITE_BASE    = 32'h0000_0000;

`endif
