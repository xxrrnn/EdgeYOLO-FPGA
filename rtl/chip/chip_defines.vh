`ifndef CHIP_DEFINES_VH
`define CHIP_DEFINES_VH

// ============================================================================
// chip_defines.vh - 全芯片统一参数定义
// ============================================================================
// 适用于 VPU、DCIM_Array 及顶层 Block Design。
// 所有模块通过 `include "chip_defines.vh" 引入。
//
// 命名规范：
//   VPU_xxx    - VPU 专用参数
//   DCIM_xxx   - DCIM 阵列专用参数
//   CHIP_xxx   - 全芯片共用参数（原 CHIP_ 前缀保留，兼容旧代码）
//   MODE_xxx   - 计算模式定义（VPU 和 DCIM 共用）
// ============================================================================

// ============================================================================
// 1. 计算模式定义（VPU 与 DCIM 共用）
// ============================================================================
`define MODE_INT4       3'b100
`define MODE_INT8       3'b110
`define MODE_INT16      3'b111
`define MODE_UINT4      3'b000
`define MODE_UINT8      3'b010
`define MODE_UINT16     3'b011

// ============================================================================
// 2. 全芯片通用参数
// ============================================================================
`define CHIP_DATA_WIDTH         32      // 通用数据/地址寄存器位宽
`define CHIP_BANDWIDTH          128     // 通用 BRAM 数据位宽 (bits) - lite: 256→128
`define CHIP_BYTE_WIDTH         8       // 字节位宽
`define CHIP_BYTES_PER_WORD     (`CHIP_BANDWIDTH / `CHIP_BYTE_WIDTH)   // 16 bytes
`define CHIP_BYTE_ADDR_SHIFT    4       // $clog2(16) = 4  (lite: 5→4)

// ============================================================================
// 3. VPU 参数
// ============================================================================
`define VPU_DATA_WIDTH          `CHIP_DATA_WIDTH
`define VPU_BANDWIDTH           `CHIP_BANDWIDTH
`define VPU_BYTE_WIDTH          `CHIP_BYTE_WIDTH
`define VPU_BYTES_PER_WORD      `CHIP_BYTES_PER_WORD
`define VPU_BYTE_ADDR_SHIFT     `CHIP_BYTE_ADDR_SHIFT

// 浮点运算参数
`define FP_WIDTH                32      // FP32 位宽
`define FP_CORE_NUM             4       // 并行 FP 核心数 (lite: 8→4, 128-bit/32-bit=4)
`define FP_TRAN_NUM             4       // FP 传输数量 (lite: 8→4)
`define C_INT_WIDTH_IN          32      // 输入整数位宽
`define Q_INT_WIDTH_OUT         8       // 量化输出整数位宽

// 其他 VPU 参数
`define MAX_CHANNEL_NUM         512     // 最大通道数
`define INTERVAL_NUM            16      // NN LUT 间隔数（已废弃，保留兼容）

// BRAM 列参数
`define NB_COL                  (`VPU_BANDWIDTH / `VPU_BYTE_WIDTH)     // 16 (lite: 32→16)
`define COL_WIDTH               `VPU_BYTE_WIDTH                        // 8

// Global Buffer (GB)
// lite: GB 已删除，VPU 通过 128-bit OBUF 端口访问 OBUF。
// 但保留 GB_ADDR_WIDTH/GB_BANDWIDTH 参数（VPU unit 内部仍用 gb_* 信号名）
// GB_ADDR_WIDTH 扩展到 24，让 unit 可寻址全 16MB OBUF（24-bit 字节地址 = 20-bit 128-bit 字地址）
`define GB_SIZE_BYTES           16777216  // 16MB（对齐 OBUF 容量）
`define GB_BANDWIDTH            `VPU_BANDWIDTH
`define GB_DEPTH                (`GB_SIZE_BYTES / `VPU_BYTES_PER_WORD) // 1048576
`define GB_WORD_ADDR_WIDTH      20      // lite: 128-bit word, 16MB = 1M words
`define GB_ADDR_WIDTH           24      // 字节地址位宽（lite: 16MB → 24-bit）

// Weight Buffer (WB)
`define WB_SIZE_BYTES           32768   // 32KB
`define WB_BANDWIDTH            `VPU_BANDWIDTH
`define WB_DEPTH                (`WB_SIZE_BYTES / `VPU_BYTES_PER_WORD) // 1024
`define WB_WORD_ADDR_WIDTH      10
`define WB_ADDR_WIDTH           15      // 字节地址位宽

// Instruction BRAM
`define INST_SIZE_BYTES         131072  // 128KB
`define INST_DATA_WIDTH         32
`define INST_DEPTH              (`INST_SIZE_BYTES / 4)                 // 32768
`define INST_ADDR_WIDTH         15
`define INST_AXI_ADDR_WIDTH     17

// HBM BRAM
`define HBM_BRAM_SIZE_BYTES     1048576 // 1MB
`define HBM_BRAM_BANDWIDTH      `VPU_BANDWIDTH
`define HBM_BRAM_DEPTH          (`HBM_BRAM_SIZE_BYTES / `VPU_BYTES_PER_WORD)

// RAM 深度（全局别名）
`define RAM_DEPTH_GB            `GB_DEPTH
`define RAM_DEPTH_WB            `WB_DEPTH

// VPU 地址映射
`define ADDR_BASE               32'h1000_0000
`define ADDR_HBM_BRAM           32'h1000_0000
`define ADDR_INST_BRAM          32'h1010_0000
`define ADDR_VPU_GB             32'h1018_0000
`define ADDR_VPU_WB             32'h1020_0000
`define ADDR_VPU_REGS           32'h1020_8000

// CDMA cooldown
`define CDMA_COOLDOWN_CYCLES    2000

// 辅助宏
`define BYTE_TO_WORD_ADDR(byte_addr)  ((byte_addr) >> `VPU_BYTE_ADDR_SHIFT)
`define WORD_TO_BYTE_ADDR(word_addr)  ((word_addr) << `VPU_BYTE_ADDR_SHIFT)

// ============================================================================
// 4. DCIM 阵列参数
// ============================================================================

// ── 阵列拓扑 ──────────────────────────────────────────────────────────────
`define DCIM_NUM_GROUPS         1       // 单组共享 IBUF/OBUF，避免复制大容量 URAM
`define DCIM_TILES_PER_GROUP    64      // 单组内 64 Tile，等效 64 个 DCIM
`define DCIM_NUM_TILES          64      // 总 Tile 数 = NUM_GROUPS × TILES_PER_GROUP

// ── Tile 计算参数 ─────────────────────────────────────────────────────────
`define DCIM_WD1                4       // 权重位宽（INT4）
`define DCIM_CH_IN              16      // 每 Tile 输入通道数
`define DCIM_CH_OUT             16      // 每 Tile 输出通道数
`define DCIM_SRAM_DP            128     // DCIM SRAM 深度（固定 128 entries；acc_depth>16 时由 DCIM_Tile 分块加载权重）
`define DCIM_CYCLE              8       // 权重 SRAM 加载周期数
`define DCIM_ACC_MAX            80      // 最大累加深度（num_rows / acc_depth 上界）

// ── Buffer 参数（lite: 拆分 IBUF/OBUF 地址宽度）──────────────────────────
`define DCIM_IBUF_ADDR_WIDTH    17      // IBUF 字地址位宽（2MB / 16B = 128K words）
`define DCIM_OBUF_ADDR_WIDTH    20      // OBUF 字地址位宽（16MB / 16B = 1M words）
`define DCIM_BUF_DATA_WIDTH     128     // IBUF/OBUF 数据位宽

// 向后兼容：BUF_ADDR_WIDTH 默认指向 IBUF（旧代码可能用到）
`define DCIM_BUF_ADDR_WIDTH     `DCIM_IBUF_ADDR_WIDTH

// AXI BRAM 接口字节地址位宽（连接 AXI BRAM Controller）
`define DCIM_AXI_BRAM_ADDR_WIDTH  24    // OBUF: 20+4=24 bits

// IBUF 物理参数（ibuf.v 参数）
`define DCIM_IBUF_NBPIPE        2       // URAM 输出流水线级数
`define DCIM_IBUF_NUM_BANKS     2       // 每组 IBUF 的 bank 数
`define DCIM_IBUF_IN_REG        1       // 输入寄存器级数
// 总 IBUF 读延迟 = NBPIPE + IN_REG + bank_pipe + mux_reg + SLR_crossing_reg = 2+1+1+1+1 = 6
// 仲裁器设为 9 留余量（含 arbiter 状态机开销）
`define DCIM_IBUF_RD_LATENCY    9

// OBUF 物理参数（obuf.v 参数）
`define DCIM_OBUF_NBPIPE        2
`define DCIM_OBUF_NUM_BANKS     2
// OBUF 读延迟 = IN_REG1(1) + IN_REG2(1) + IN_REG3(1) + memrega(1) + NBPIPE(2) + douta(1) = 7
// VPU 单元 rd_wait_cnt >= 10 (等 11 拍含 LOAD_X 发地址那拍)

// ── 统一 OBUF 外部地址扩展（lite: NUM_GROUPS=1，无 group select）─────────
// 当 NUM_GROUPS=1 时，extended_addr 直接等于 OBUF 字地址，GROUP_BITS=0
`define DCIM_OBUF_GROUP_BITS    0       // $clog2(DCIM_NUM_GROUPS) = $clog2(1) = 0
`define DCIM_OBUF_EXT_ADDR_BITS `DCIM_OBUF_ADDR_WIDTH  // = 20 bits (1 group only)

// ── DCIM 配置寄存器地址（与 INST_Decoder OP_DCIM_CFG 一致）─────────────────
`define DCIM_REG_CTRL           12'h000  // [0] start (W1S, 自清)
`define DCIM_REG_MODE           12'h008  // [15:8] acc_depth | [2:0] mode
`define DCIM_REG_ACT_BASE       12'h010  // 全局激活基址（1 个，广播到所有 Group）
`define DCIM_REG_WEI_BASE       12'h040  // WEI_BASE[0..63]: 每 Tile 权重基址 (+4 per tile)
`define DCIM_REG_OUT_BASE       12'h140  // OUT_BASE[0..63]: 每 Tile 输出基址 (+4 per tile)
`define DCIM_REG_TILE_MASK      12'h240  // TILE_MASK[31:0]: 低 32 个 Tile 使能
`define DCIM_REG_TILE_MASK_HI   12'h244  // TILE_MASK[63:32]: 高 32 个 Tile 使能

// ── 向后兼容：CHIP_ 前缀别名（对应旧 chip_defs.vh）────────────────────────
`define CHIP_BUF_ADDR_WIDTH     `DCIM_BUF_ADDR_WIDTH
`define CHIP_BRAM_DATA_WIDTH    `DCIM_BUF_DATA_WIDTH
`define CHIP_BRAM_BYTES         (`DCIM_BUF_DATA_WIDTH / 8)
`define CHIP_NUM_TILES          `DCIM_NUM_TILES
`define CHIP_WD1                `DCIM_WD1
`define CHIP_CH_IN              `DCIM_CH_IN
`define CHIP_CH_OUT             `DCIM_CH_OUT
`define CHIP_ACC_MAX            `DCIM_ACC_MAX
`define CHIP_WEIGHT_TILE_SIZE   `DCIM_CYCLE

// AXI-Lite 接口
`define CHIP_AXI_LITE_ADDR_WIDTH  12
`define CHIP_AXI_LITE_DATA_WIDTH  32

// 计算派生宏（需要非 `define 场景时用 localparam 代替）
`define CHIP_WD2     (2 * `CHIP_WD1 + 4)           // 2*4 + $clog2(16)=4 = 12
`define CHIP_WD3     (`CHIP_WD2 + 7)               // 12 + $clog2(80)≈7 = 19
`define CHIP_RES_WIDTH  (`CHIP_CH_OUT * `CHIP_WD3) // 16 * 19 = 304

// 旧寄存器地址别名（向后兼容 chip_defs.vh）
`define CHIP_REG_CTRL       `DCIM_REG_CTRL
`define CHIP_REG_STATUS     12'h004
`define CHIP_REG_MODE       `DCIM_REG_MODE
`define CHIP_REG_NUM_ROWS   12'h00C     // 已废弃，保留占位
`define CHIP_REG_ACT_BASE   `DCIM_REG_ACT_BASE
`define CHIP_REG_WEI_BASE   `DCIM_REG_WEI_BASE
`define CHIP_REG_OUT_BASE   `DCIM_REG_OUT_BASE

`endif // CHIP_DEFINES_VH
