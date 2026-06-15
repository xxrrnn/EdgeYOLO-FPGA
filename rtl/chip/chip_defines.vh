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

// VPU ready 延迟：VPU 子单元 assert ready 后，config_ready 需延迟若干拍再
// 允许下一条指令（通常是 drain CDMA）执行。确保最后一笔写操作经过 1 级 pipeline
// + URAM 写入后，数据对 Port B（CDMA/XDMA）可见。
// 保守值：1(pipeline) + 1(URAM write) + 10(margin) = 12
`define VPU_READY_DELAY_CYCLES  12

// 辅助宏
`define BYTE_TO_WORD_ADDR(byte_addr)  ((byte_addr) >> `VPU_BYTE_ADDR_SHIFT)
`define WORD_TO_BYTE_ADDR(word_addr)  ((word_addr) << `VPU_BYTE_ADDR_SHIFT)

// ============================================================================
// 4. DCIM 阵列参数
// ============================================================================

// ── 阵列拓扑（Array–Tile，无 Group 层）────────────────────────────────────
`define DCIM_NUM_TILES          8       // DCIM_Tile 数量；8×(64×32) @250MHz INT8 同等算力

// ── DSP 映射控制（统一分配，所有 Tile 参数一致）──────────────────────────────
// CH_OUT=32 时每 Tile 有 8 列 × 4 subcol × 64 ch_in = 2048 个 4-bit 乘法器。
// 公式: 每 Tile DSP = (DSP_COL_NUM × 4 + DSP_PARTIAL_SUBCOL) × CH_IN
// CH_OUT=32 → 最大列数 = CH_OUT/4 = 8
//
// xcvu37p: 9024 DSP total, 3 SLR (SLR0/1/2), 约 3008/SLR
// 布局方案 2+3+3:
//   SLR0: Tile 0,1 + VPU/XDMA (~57 DSP)   → per-tile DSP budget ~1475
//   SLR1: Tile 2,3,4                       → per-tile DSP budget ~1002
//   SLR2: Tile 5,6,7                       → per-tile DSP budget ~1002
//
// ┌───────────────────────────────────────────────────────────────────────────────┐
// │ DSP 用量方案（8 Tiles 统一配置，CH_OUT=32）                                   │
// │ 公式: 每 Tile DSP = (COL×4 + PARTIAL) × 64(CH_IN)                            │
// │ 总 DSP = 8 × per_tile + 57(VPU)                                              │
// ├───────┬─────────┬─────────┬────────────┬────────┬─────────────────────────────┤
// │ 档位  │ COL_NUM │ PARTIAL │ DSP/tile   │ 总 DSP │ 利用率 (SLR1/2 max)         │
// ├───────┼─────────┼─────────┼────────────┼────────┼─────────────────────────────┤
// │ 少    │    2    │   0     │  512       │  4153  │  46% (1536/3008=51%)        │
// │ 中    │    3    │   0     │  768       │  6201  │  69% (2304/3008=77%)        │
// │ 多    │    3    │   3     │  960       │  7737  │  86% (2880/3008=96%)        │
// │ 满配  │    8    │   0     │ 2048       │ 16441  │  N/A (超限)                 │
// ├───────┴─────────┴─────────┴────────────┴────────┴─────────────────────────────┤
// │ 推荐: COL=3, PARTIAL=3（960 DSP/tile, 86%利用率, SLR1/2=96%）                 │
// └────────────────────────────────────────────────────────────────────────────────┘
//
`define DCIM_DSP_COL_NUM        3       // 所有 Tile 统一: 前 3 列全 DSP
`define DCIM_DSP_PARTIAL_SUBCOL 3       // 第 4 列前 3 个 subcol 用 DSP
// 向后兼容别名（DCIM_Array.sv 仍引用这些宏）
`define DCIM_DSP_COL_SOLO       `DCIM_DSP_COL_NUM
`define DCIM_DSP_PARTIAL_SOLO   `DCIM_DSP_PARTIAL_SUBCOL
`define DCIM_DSP_COL_SHARED     `DCIM_DSP_COL_NUM
`define DCIM_DSP_PARTIAL_SHARED `DCIM_DSP_PARTIAL_SUBCOL

// ── Tile 计算参数 ─────────────────────────────────────────────────────────
`define DCIM_WD1                4       // 权重位宽（INT4）
`define DCIM_CH_IN              64      // 每 Tile 每 acc step 输入通道数
`define DCIM_CH_OUT             32      // 每 Tile physical output lane 数；INT8 有效输出 CH_OUT/2
`define DCIM_SRAM_DP            128     // DCIM SRAM 深度（固定 128 entries；acc_depth>1 时由 DCIM_Tile 分块加载权重）
`define DCIM_CYCLE              64      // 64×32×4bit / 128bit = 64 个 128-bit weight word/acc step
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

// tile_obuf bank 参数（obuf_bank.v default parameter 引用）
// 8-bank 结构：256KB / 8 = 32KB/bank = 2048×16B words → BANK_ADDR_WIDTH=11
// NBPIPE = READ_LATENCY - 1（URAM 1 cycle read + NBPIPE pipeline stages = 10 total）
`define DCIM_TILE_OBUF_BANK_ADDR_WIDTH  11
`define DCIM_TILE_OBUF_NBPIPE           9

// tile_obuf 总读延迟（= 1 URAM read + NBPIPE = 10；tb standalone 引用）
`define DCIM_OBUF_RD_TOTAL_PIPE         `DCIM_TILE_OBUF_RD_LATENCY

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
