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
`define INST_BRAM_NPIPE         2       // Port B pipeline stages (after 1-cycle BRAM read)
`define INST_BRAM_RD_PIPE_A     1       // Port A output pipeline stages (after 1-cycle BRAM read)
`define INST_BRAM_READ_LATENCY  (`INST_BRAM_RD_PIPE_A + 1)  // axi_bram_ctrl: 1(BRAM read) + RD_PIPE_A = 2

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

// ── 阵列拓扑（Array–Tile，无 Group 层）────────────────────────────────────
`define DCIM_NUM_TILES          4       // DCIM_Tile 数量；64×64 @250MHz INT8 峰值约 2.048 TOPS

// ── DSP 映射控制（Per-Tile 部分 DSP 方案）─────────────────────────────────
// 每 Tile 有 16 列 × 4 subcol × 64 ch = 4096 个 4-bit 乘法器。
// 细粒度双参数方案：
//   DSP_COL_NUM        : 前 N 列全部 4 subcol 使用 DSP48E2
//   DSP_PARTIAL_SUBCOL : 第 N+1 列仅前 M 个 subcol 使用 DSP48E2（0=禁用）
//
// 每 Tile DSP 数 = (DSP_COL_NUM × 4 + DSP_PARTIAL_SUBCOL) × 64(ch)
// xcvu37p: 9024 DSP total, 3 SLR (SLR0/1/2), 约 3008/SLR
//
// 布局方案 1+2+1:
//   SLR0: Tile 0 (独占) + VPU/XDMA/IBUF (~60 DSP)  → Tile 可用 ~2940
//   SLR1: Tile 1 + Tile 2 (共享) + arb              → 每 Tile 可用 ~1536
//   SLR2: Tile 3 (独占)                              → Tile 可用 ~3000
//
// ┌───────────────────────────────────────────────────────────────────────────────┐
// │ DSP 用量四档方案（复制对应行替换下方 define 即可）                             │
// │ 公式: 每 Tile DSP = (COL×4 + PARTIAL) × 64                                   │
// │ xcvu37p: 9024 DSP, SLR cap ~3008/SLR, VPU/XDMA 固定 ~57 DSP                  │
// │ 布局 1+2+1: SLR0=Tile0(solo), SLR1=Tile1+2(shared), SLR2=Tile3(solo)         │
// ├───────┬───────────┬─────────┬──────────┬──────────┬────────┬──────────────────┤
// │ 档位  │ SOLO_COL  │ SOLO_P  │ SHARE_COL│ SHARE_P  │ 总 DSP │ 芯片利用率       │
// ├───────┼───────────┼─────────┼──────────┼──────────┼────────┼──────────────────┤
// │ 少    │    5      │   0     │    3     │   0      │  4153  │  46%             │
// │ 中    │    7      │   0     │    4     │   0      │  5689  │  63%             │
// │ 多    │    9      │   0     │    5     │   2      │  7481  │  83%             │
// │ 极多  │   11      │   2     │    5     │   3      │  8889  │  98.5%           │
// ├───────┴───────────┴─────────┴──────────┴──────────┴────────┴──────────────────┤
// │                                                                                │
// │ 【少】route 友好，留足余量，适合初期验证                                       │
// │   `define DCIM_DSP_COL_SOLO       5                                            │
// │   `define DCIM_DSP_PARTIAL_SOLO   0                                            │
// │   `define DCIM_DSP_COL_SHARED     3                                            │
// │   `define DCIM_DSP_PARTIAL_SHARED 0                                            │
// │   // Solo: 5×4×64=1280/tile, Shared: 3×4×64=768/tile                          │
// │   // Total: 1280×2+768×2+57 = 4153 DSP                                        │
// │                                                                                │
// │ 【中】均衡方案，SLR 约 60% 填充                                                │
// │   `define DCIM_DSP_COL_SOLO       7                                            │
// │   `define DCIM_DSP_PARTIAL_SOLO   0                                            │
// │   `define DCIM_DSP_COL_SHARED     4                                            │
// │   `define DCIM_DSP_PARTIAL_SHARED 0                                            │
// │   // Solo: 7×4×64=1792/tile, Shared: 4×4×64=1024/tile                          │
// │   // Total: 1792×2+1024×2+57 = 5689 DSP                                       │
// │                                                                                │
// │ 【多】高性能方案，P&R 需关注拥塞                                               │
// │   `define DCIM_DSP_COL_SOLO       9                                            │
// │   `define DCIM_DSP_PARTIAL_SOLO   0                                            │
// │   `define DCIM_DSP_COL_SHARED     5                                            │
// │   `define DCIM_DSP_PARTIAL_SHARED 2                                            │
// │   // Solo: 9×4×64=2304/tile, Shared: (5×4+2)×64=1408/tile                     │
// │   // Total: 2304×2+1408×2+57 = 7481 DSP                                       │
// │                                                                                │
// │ 【极多】压满芯片，P&R 有挑战，可能需 directive 调优                            │
// │   `define DCIM_DSP_COL_SOLO       11                                           │
// │   `define DCIM_DSP_PARTIAL_SOLO   2                                            │
// │   `define DCIM_DSP_COL_SHARED     5                                            │
// │   `define DCIM_DSP_PARTIAL_SHARED 3                                            │
// │   // Solo: (11×4+2)×64=2944/tile, Shared: (5×4+3)×64=1472/tile                │
// │   // Total: 2944×2+1472×2+57 = 8889 DSP                                       │
// │                                                                                │
// └────────────────────────────────────────────────────────────────────────────────┘
//
`define DCIM_DSP_TILES          4
`define DCIM_DSP_COL_SOLO       7       // ← 替换为上方对应档位的值
`define DCIM_DSP_PARTIAL_SOLO   0
`define DCIM_DSP_COL_SHARED     4       // ← 替换为上方对应档位的值
`define DCIM_DSP_PARTIAL_SHARED 0

// ── Tile 计算参数 ─────────────────────────────────────────────────────────
`define DCIM_WD1                4       // 权重位宽（INT4）
`define DCIM_CH_IN              64      // 每 Tile 每 acc step 输入通道数
`define DCIM_CH_OUT             64      // 每 Tile physical output lane 数；INT8 有效输出 CH_OUT/2
`define DCIM_SRAM_DP            128     // DCIM SRAM 深度（固定 128 entries；acc_depth>1 时由 DCIM_Tile 分块加载权重）
`define DCIM_CYCLE              128     // 64×64×4bit / 128bit = 128 个 128-bit weight word/acc step
`define DCIM_ACC_MAX            80      // 最大累加深度（num_rows / acc_depth 上界）

// ── Buffer 容量 / 数据宽度（主旋钮）────────────────────────────────────────
// 字地址位宽决定容量：SIZE_BYTES = (1<<ADDR_WIDTH) * BYTES_PER_WORD
`define DCIM_BUF_DATA_WIDTH     128     // IBUF/tile_obuf/VPU_BUF 128-bit 字宽

// ── chip-v3 XPM: IBUF 拆分为 per-tile tile_ibuf ──────────────────────────
// tile_ibuf: 每 Tile 本地读 buffer (weight+activation)，与 Tile 同 SLR，零跨越。
// XPM xpm_memory_tdpram, CASCADE_HEIGHT=2, READ_LATENCY=10
`define DCIM_TILE_IBUF_ADDR_WIDTH  15   // 512KB per tile (32K × 16B words)
`define DCIM_TILE_IBUF_RD_LATENCY  10   // XPM READ_LATENCY (无 timing 风险)

// 向后兼容: IBUF_ADDR_WIDTH 指向 tile_ibuf（Tile 内部寻址用）
`define DCIM_IBUF_ADDR_WIDTH    `DCIM_TILE_IBUF_ADDR_WIDTH

// ── chip-v3 XPM: tile_obuf per-tile 输出 buffer ─────────────────────────
// tile_obuf: 每 Tile 本地写 buffer，CDMA 可读。XPM CASCADE_HEIGHT=2, READ_LATENCY=10
`define DCIM_TILE_OBUF_ADDR_WIDTH  14   // 256KB per tile (16K × 16B words)
`define DCIM_TILE_OBUF_RD_LATENCY  10   // XPM READ_LATENCY (无 timing 风险)

// VPU_BUF: VPU 本地 R/W buffer，与 VPU 同在 SLR0，零跨越。
// chip-v3 XPM: 8MB，CASCADE_HEIGHT=2，READ_LATENCY=10
`define VPU_BUF_ADDR_WIDTH         19   // 8MB (512K × 16B words)
`define VPU_BUF_RD_LATENCY         10   // XPM READ_LATENCY (无 timing 风险)

// tile_obuf 写流水排空周期（Tile FSM ST_DONE 等待写入完成）
// tile_obuf 输入寄存 1 级 + 安全余量 1 = 2 周期
`define DCIM_OBUF_WR_DRAIN      2

// 向后兼容: OBUF 地址宽度别名（用于 DCIM out_base_addr 字段宽度）
// DCIM Tile 写 tile_obuf 时使用 tile_obuf 内部地址
`define DCIM_OBUF_ADDR_WIDTH    `DCIM_TILE_OBUF_ADDR_WIDTH

`define DCIM_BUF_COL_WIDTH      `CHIP_BYTE_WIDTH                        // 每列 8 bit = 1 byte
`define DCIM_BUF_NUM_COL        (`DCIM_BUF_DATA_WIDTH / `DCIM_BUF_COL_WIDTH)  // 16 列 byte-enable
`define DCIM_BUF_BYTES_PER_WORD (`DCIM_BUF_DATA_WIDTH / `CHIP_BYTE_WIDTH)    // 128b → 16B（勿用 NUM_COL*COL_WIDTH）
`define DCIM_TILE_IBUF_SIZE_BYTES ((1 << `DCIM_TILE_IBUF_ADDR_WIDTH) * `DCIM_BUF_BYTES_PER_WORD)
`define DCIM_IBUF_SIZE_BYTES    `DCIM_TILE_IBUF_SIZE_BYTES
`define DCIM_TILE_OBUF_SIZE_BYTES ((1 << `DCIM_TILE_OBUF_ADDR_WIDTH) * `DCIM_BUF_BYTES_PER_WORD)
`define VPU_BUF_SIZE_BYTES      ((1 << `VPU_BUF_ADDR_WIDTH) * `DCIM_BUF_BYTES_PER_WORD)

// 向后兼容：BUF_ADDR_WIDTH 默认指向 tile_ibuf（Tile 内部寻址用）
`define DCIM_BUF_ADDR_WIDTH     `DCIM_TILE_IBUF_ADDR_WIDTH

// AXI BRAM 字节地址 = 字地址左移 BYTE_ADDR_SHIFT
`define DCIM_BYTE_ADDR_SHIFT    `CHIP_BYTE_ADDR_SHIFT
// tile_ibuf 的 AXI 地址宽度
`define DCIM_TILE_IBUF_AXI_ADDR_WIDTH (`DCIM_TILE_IBUF_ADDR_WIDTH + `DCIM_BYTE_ADDR_SHIFT)
// tile_obuf 的 AXI 地址宽度
`define DCIM_TILE_OBUF_AXI_ADDR_WIDTH (`DCIM_TILE_OBUF_ADDR_WIDTH + `DCIM_BYTE_ADDR_SHIFT)
// VPU_BUF 的 AXI 地址宽度
`define VPU_BUF_AXI_ADDR_WIDTH (`VPU_BUF_ADDR_WIDTH + `DCIM_BYTE_ADDR_SHIFT)
// 向后兼容: DCIM_AXI_BRAM_ADDR_WIDTH 现指向 tile_obuf
`define DCIM_AXI_BRAM_ADDR_WIDTH `DCIM_TILE_OBUF_AXI_ADDR_WIDTH

// ============================================================================
// XPM Buffer 统一参数（chip-v3: 所有 URAM buffer 使用 xpm_memory_tdpram）
// CASCADE_HEIGHT=2, READ_LATENCY=10, 彻底消除 URAM timing 风险
// ============================================================================

// ── AXI BRAM Controller READ_LATENCY（与 XPM READ_LATENCY 匹配）─────────
`define DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY 10
`define DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY 10
`define VPU_BUF_AXI_BRAM_READ_LATENCY        10

// 向后兼容别名
`define DCIM_IBUF_RD_LATENCY        `DCIM_TILE_IBUF_RD_LATENCY
`define DCIM_IBUF_AXI_BRAM_READ_LATENCY `DCIM_TILE_IBUF_AXI_BRAM_READ_LATENCY
`define DCIM_OBUF_AXI_BRAM_READ_LATENCY `DCIM_TILE_OBUF_AXI_BRAM_READ_LATENCY

// ── tile_obuf 外部字节地址：字地址即 tile 内部地址 ──────────────────────────
`define DCIM_OBUF_EXT_ADDR_BITS `DCIM_TILE_OBUF_ADDR_WIDTH  // = 14 bits

// ── DCIM 配置寄存器地址（与 INST_Decoder OP_DCIM_CFG 一致）─────────────────
`define DCIM_REG_CTRL           12'h000  // [0] start (W1S, 自清)
`define DCIM_REG_MODE           12'h008  // [15:8] acc_depth | [2:0] mode
`define DCIM_REG_ACT_BASE       12'h010  // 全局激活基址（广播到所有 Tile）
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
`define CHIP_WD2     (2 * `CHIP_WD1 + $clog2(`CHIP_CH_IN))
`define CHIP_WD3     (`CHIP_WD2 + $clog2(`CHIP_ACC_MAX))
`define CHIP_RES_WIDTH  (`CHIP_CH_OUT * `CHIP_WD3)

// 旧寄存器地址别名（向后兼容 chip_defs.vh）
`define CHIP_REG_CTRL       `DCIM_REG_CTRL
`define CHIP_REG_STATUS     12'h004
`define CHIP_REG_MODE       `DCIM_REG_MODE
`define CHIP_REG_NUM_ROWS   12'h00C     // 已废弃，保留占位
`define CHIP_REG_ACT_BASE   `DCIM_REG_ACT_BASE
`define CHIP_REG_WEI_BASE   `DCIM_REG_WEI_BASE
`define CHIP_REG_OUT_BASE   `DCIM_REG_OUT_BASE

`endif // CHIP_DEFINES_VH
