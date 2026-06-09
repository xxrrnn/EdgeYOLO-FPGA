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
//   DSP_PARTIAL_SUBCOL : 第 N 列仅前 M 个 subcol 使用 DSP48E2（0=不启用第 N 列部分 DSP）
//
// 每 Tile DSP 数 = (DSP_COL_NUM × 4 + DSP_PARTIAL_SUBCOL) × 64(ch)
// xcvu37p: 9024 DSP total, ~3008/SLR; 1 Tile/SLR 布局（SLR0~SLR3 各 1 Tile）。
//
//   DSP_COL_NUM  DSP_PARTIAL_SUBCOL  DSP/Tile  4Tile总DSP  +VPU(57)  1Tile/SLR  SLR安全?
//   5            0                   1280      5120        5177      1280       ✓ (43%)
//   8            0                   2048      8192        8249      2048       ✓ (68%)
//   8            2                   2176      8704        8761      2176       ✓ (72%)  ← 推荐
//   8            4(=9列全DSP)         2304      9216        —         —          ✗ 超芯片总量
//
// 推荐值 DSP_COL_NUM=8, DSP_PARTIAL_SUBCOL=2：
//   总 DSP 8761，占 xcvu37p 97%；每 SLR 仅 2176/3008 = 72%，安全余量充足。
//   需配合 XDC 改为 1 Tile/SLR（SLR0=Tile0, SLR1=Tile1, SLR2=Tile2, SLR3=Tile3）。
`define DCIM_DSP_TILES          4       // 所有 Tile 均使用 DSP+LUT 混合
`define DCIM_DSP_COL_NUM        8       // 每 Tile 前 8 列全部 4 subcol 使用 DSP
`define DCIM_DSP_PARTIAL_SUBCOL 2       // 第 8 列（第9列）中前 2 个 subcol 使用 DSP（共 2×64=128 额外 DSP/Tile）

// ── Tile 计算参数 ─────────────────────────────────────────────────────────
`define DCIM_WD1                4       // 权重位宽（INT4）
`define DCIM_CH_IN              64      // 每 Tile 每 acc step 输入通道数
`define DCIM_CH_OUT             64      // 每 Tile physical output lane 数；INT8 有效输出 CH_OUT/2
`define DCIM_SRAM_DP            128     // DCIM SRAM 深度（固定 128 entries；acc_depth>1 时由 DCIM_Tile 分块加载权重）
`define DCIM_CYCLE              128     // 64×64×4bit / 128bit = 128 个 128-bit weight word/acc step
`define DCIM_ACC_MAX            80      // 最大累加深度（num_rows / acc_depth 上界）

// ── Buffer 容量 / 数据宽度（主旋钮）────────────────────────────────────────
// 字地址位宽决定容量：SIZE_BYTES = (1<<ADDR_WIDTH) * BYTES_PER_WORD
`define DCIM_IBUF_ADDR_WIDTH    17      // 2MB  IBUF（128K × 16B words）
`define DCIM_OBUF_ADDR_WIDTH    20      // 16MB OBUF（1M  × 16B words）
`define DCIM_BUF_DATA_WIDTH     128     // IBUF/OBUF 128-bit 字宽

`define DCIM_BUF_COL_WIDTH      `CHIP_BYTE_WIDTH                        // 每列 8 bit = 1 byte
`define DCIM_BUF_NUM_COL        (`DCIM_BUF_DATA_WIDTH / `DCIM_BUF_COL_WIDTH)  // 16 列 byte-enable
`define DCIM_BUF_BYTES_PER_WORD (`DCIM_BUF_DATA_WIDTH / `CHIP_BYTE_WIDTH)    // 128b → 16B（勿用 NUM_COL*COL_WIDTH）
`define DCIM_IBUF_SIZE_BYTES    ((1 << `DCIM_IBUF_ADDR_WIDTH) * `DCIM_BUF_BYTES_PER_WORD)
`define DCIM_OBUF_SIZE_BYTES    ((1 << `DCIM_OBUF_ADDR_WIDTH) * `DCIM_BUF_BYTES_PER_WORD)

// 向后兼容：BUF_ADDR_WIDTH 默认指向 IBUF（旧代码可能用到）
`define DCIM_BUF_ADDR_WIDTH     `DCIM_IBUF_ADDR_WIDTH

// AXI BRAM 字节地址 = 字地址左移 BYTE_ADDR_SHIFT
`define DCIM_BYTE_ADDR_SHIFT    `CHIP_BYTE_ADDR_SHIFT
`define DCIM_AXI_BRAM_ADDR_WIDTH (`DCIM_OBUF_ADDR_WIDTH + `DCIM_BYTE_ADDR_SHIFT)

// ============================================================================
// IBUF / OBUF 流水线与多 bank — 仅改「主旋钮」，其余由表达式推导
// （与 rtl/DCIM_Macro/ibuf.v、obuf.v、ibuf_rd_arbiter.sv 结构一一对应）
// ============================================================================

// ── IBUF 主旋钮 ───────────────────────────────────────────────────────────
// 250MHz：更多 bank 缩短每 bank URAM 级联深度；URAM_RD_STAGES 将读拆为 addr→data 两拍
`define DCIM_IBUF_NUM_BANKS          4       // 须为 2 的幂（2→4：单 bank 地址少 1bit，减 URAM 链长）
`define DCIM_IBUF_URAM_RD_STAGES     1       // ibuf_bank：单拍 mem[addra]→寄存（Vivado URAM 可推断）；勿用 addr 锁存再读
`define DCIM_IBUF_NBPIPE             6       // ibuf_bank：URAM 输出之后到 dout 的流水级数
`define DCIM_IBUF_IN_REG             1       // Port A/B 输入寄存（0=旁路）
`define DCIM_IBUF_BANK_SEL_PIPE_EXTRA 3      // ibuf.v bank_sel_*_pipe：NBPIPE 之后再打 3 拍

// ── IBUF 推导 ─────────────────────────────────────────────────────────────
`define DCIM_IBUF_BANK_BITS          ($clog2(`DCIM_IBUF_NUM_BANKS))
`define DCIM_IBUF_BANK_ADDR_WIDTH    (`DCIM_IBUF_ADDR_WIDTH - `DCIM_IBUF_BANK_BITS)
`define DCIM_IBUF_BANK_RD_EN_DEPTH   (`DCIM_IBUF_NBPIPE + 1)
`define DCIM_IBUF_BANK_MUX_PIPE      (`DCIM_IBUF_NBPIPE + `DCIM_IBUF_BANK_SEL_PIPE_EXTRA)
`define DCIM_IBUF_ARB_LATENCY_EXTRA  1       // ibuf_rd_arbiter grant/计数余量
`define DCIM_IBUF_RD_LATENCY         (`DCIM_IBUF_IN_REG + `DCIM_IBUF_BANK_MUX_PIPE + `DCIM_IBUF_ARB_LATENCY_EXTRA)

// ── OBUF 主旋钮 ───────────────────────────────────────────────────────────
`define DCIM_OBUF_NUM_BANKS          4       // 2→4：减 URAM 级联；8 bank 过小会致 Synth 8-2914/8-6849
`define DCIM_OBUF_URAM_RD_STAGES     1       // obuf_bank：单拍 mem[addra]→memreg（与 ibuf 同模板）；时序靠 XDC MCP
`define DCIM_OBUF_NBPIPE             6       // obuf_bank：mem_rstage 之后到 dout 的流水级数
`define DCIM_OBUF_IN_REG_STAGES      3       // obuf.v：中心 reg1 + per-bank reg2/reg3
`define DCIM_OBUF_POST_URAM_PIPE     (`DCIM_OBUF_URAM_RD_STAGES + 1)  // URAM 读流水 + mem_rstage
`define DCIM_OBUF_WR_URAM_DRAIN_EXTRA 5     // Tile 写：IN_REG 之后 URAM 写级联排空余量

// ── OBUF 推导 ─────────────────────────────────────────────────────────────
`define DCIM_OBUF_BANK_BITS          ($clog2(`DCIM_OBUF_NUM_BANKS))
`define DCIM_OBUF_BANK_ADDR_WIDTH    (`DCIM_OBUF_ADDR_WIDTH - `DCIM_OBUF_BANK_BITS)
`define DCIM_OBUF_BANK_RD_EN_DEPTH   (`DCIM_OBUF_NBPIPE + 1)
`define DCIM_OBUF_BANK_MUX_PIPE      (`DCIM_OBUF_NBPIPE + `DCIM_OBUF_IN_REG_STAGES + `DCIM_OBUF_POST_URAM_PIPE)
`define DCIM_OBUF_RD_TOTAL_PIPE      `DCIM_OBUF_BANK_MUX_PIPE
`define DCIM_OBUF_WR_DRAIN           (`DCIM_OBUF_IN_REG_STAGES + `DCIM_OBUF_WR_URAM_DRAIN_EXTRA)

// AXI BRAM Controller READ_LATENCY（CDMA/XDMA 经 Port A 读 obuf/ibuf）
// IBUF 公式：IN_REG(1) + BANK_MUX_PIPE(9) + FINAL_MUX_REG(1) = 11
//   FINAL_MUX_REG=1：ibuf.v 的 always @posedge douta<=bank_douta[sel_pipe[末尾]] 最终寄存拍
// OBUF 公式：RD_TOTAL_PIPE(11) + EXTRA(2) = 13（concat 标定 EXTRA=2，通过仿真验证正确）
`define DCIM_IBUF_AXI_BRAM_READ_LATENCY_FINAL_REG 1
`define DCIM_OBUF_AXI_BRAM_READ_LATENCY_EXTRA 2
`define DCIM_IBUF_AXI_BRAM_READ_LATENCY (`DCIM_IBUF_IN_REG + `DCIM_IBUF_BANK_MUX_PIPE + `DCIM_IBUF_AXI_BRAM_READ_LATENCY_FINAL_REG)
`define DCIM_OBUF_AXI_BRAM_READ_LATENCY (`DCIM_OBUF_RD_TOTAL_PIPE + `DCIM_OBUF_AXI_BRAM_READ_LATENCY_EXTRA)

// ── OBUF 外部字节地址：无 group 选择位，字地址即 OBUF 内部地址 ───────────
`define DCIM_OBUF_EXT_ADDR_BITS `DCIM_OBUF_ADDR_WIDTH  // = 20 bits

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
