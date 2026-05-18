//==============================================================================
// VPU Global Parameter Definitions
// 
// 本文件定义 VPU 项目的所有核心参数，作为单一数据源。
// RTL 模块通过 `include 引用，Tcl 脚本通过 parse_vpu_defines.tcl 解析。
//
// 设计原则：
//   1. 只定义基础参数，派生参数通过计算得出
//   2. 所有容量参数以字节为单位定义，深度自动计算
//   3. 地址位宽从容量自动派生
//
// 命名规范：
//   VPU_xxx          - VPU 核心参数
//   GB_xxx           - Global Buffer 相关
//   WB_xxx           - Weight Buffer 相关
//   INST_xxx         - Instruction BRAM 相关
//   HBM_BRAM_xxx     - HBM BRAM 相关（暂时替代HBM）
//   ADDR_xxx         - 地址映射相关
//==============================================================================

`ifndef VPU_DEFINES_VH
`define VPU_DEFINES_VH

//==============================================================================
// 基础数据位宽参数（核心配置）
//==============================================================================
`define VPU_DATA_WIDTH          32      // 通用数据/地址寄存器位宽
`define VPU_BANDWIDTH           256     // BRAM 数据位宽 (bits)
`define VPU_BYTE_WIDTH          8       // 字节位宽

//==============================================================================
// 派生参数：字节/word 转换
//==============================================================================
`define VPU_BYTES_PER_WORD      (`VPU_BANDWIDTH / `VPU_BYTE_WIDTH)  // 32 bytes
`define VPU_BYTE_ADDR_SHIFT     5       // $clog2(32) = 5

//==============================================================================
// 浮点运算参数（核心配置）
//==============================================================================
`define FP_WIDTH                32      // FP32 位宽
`define FP_CORE_NUM             8       // 并行 FP 核心数
`define FP_TRAN_NUM             8       // FP 传输数量
`define C_INT_WIDTH_IN          32      // 输入整数位宽
`define Q_INT_WIDTH_OUT         8       // 量化输出整数位宽

//==============================================================================
// 其他 VPU 参数
//==============================================================================
`define MAX_CHANNEL_NUM         1024    // 最大通道数
`define INTERVAL_NUM            16      // NN LUT 间隔数

//==============================================================================
// BRAM 列参数 (用于 byte write enable)
//==============================================================================
`define NB_COL                  (`VPU_BANDWIDTH / `VPU_BYTE_WIDTH)  // 32
`define COL_WIDTH               `VPU_BYTE_WIDTH                     // 8

//==============================================================================
// Global Buffer (GB) 参数
// 容量：128KB
// 
// ⚠️  IMPORTANT: 修改 GB_SIZE_BYTES 时，必须同步更新：
//     - Global_VPU_top.v 第65行: X_INTERFACE_PARAMETER MEM_SIZE 值
//==============================================================================
`define GB_SIZE_BYTES           131072                              // 128KB
`define GB_BANDWIDTH            `VPU_BANDWIDTH                      // 256 bits
`define GB_DEPTH                (`GB_SIZE_BYTES / `VPU_BYTES_PER_WORD)  // 4096 words
`define GB_WORD_ADDR_WIDTH      12                                  // $clog2(4096) = 12
`define GB_ADDR_WIDTH           17                                  // 字节地址位宽 = $clog2(128KB) = 17

//==============================================================================
// Weight Buffer (WB) 参数
// 容量：32KB（修改自 128KB）
// 
// ⚠️  IMPORTANT: 修改 WB_SIZE_BYTES 时，必须同步更新：
//     - Global_VPU_top.v 第86行: X_INTERFACE_PARAMETER MEM_SIZE 值
//==============================================================================
`define WB_SIZE_BYTES           32768                               // 32KB
`define WB_BANDWIDTH            `VPU_BANDWIDTH                      // 256 bits
`define WB_DEPTH                (`WB_SIZE_BYTES / `VPU_BYTES_PER_WORD)  // 1024 words
`define WB_WORD_ADDR_WIDTH      10                                  // $clog2(1024) = 10
`define WB_ADDR_WIDTH           15                                  // 字节地址位宽 = $clog2(32KB) = 15

//==============================================================================
// Instruction BRAM 参数
// 容量：128KB（修改自 1MB）
// 数据宽度：32 bits（指令宽度）
//==============================================================================
`define INST_SIZE_BYTES         131072                              // 128KB
`define INST_DATA_WIDTH         32                                  // 指令位宽
`define INST_DEPTH              (`INST_SIZE_BYTES / 4)              // 32768 words (128KB / 4B)
`define INST_ADDR_WIDTH         15                                  // $clog2(32768) = 15
`define INST_AXI_ADDR_WIDTH     17                                  // AXI 字节地址位宽 = $clog2(128KB) = 17

//==============================================================================
// HBM BRAM 参数 (暂时替代 HBM 的外部数据暂存区)
// 容量：1MB
//==============================================================================
`define HBM_BRAM_SIZE_BYTES     1048576                             // 1MB
`define HBM_BRAM_BANDWIDTH      `VPU_BANDWIDTH                      // 256 bits
`define HBM_BRAM_DEPTH          (`HBM_BRAM_SIZE_BYTES / `VPU_BYTES_PER_WORD)  // 32768 words

//==============================================================================
// RAM 深度参数（用于 Global_VPU 等模块）
//==============================================================================
`define RAM_DEPTH_GB            `GB_DEPTH                           // 4096
`define RAM_DEPTH_WB            `WB_DEPTH                           // 1024

//==============================================================================
// 地址映射 (用于 Block Design)
// 所有地址为字节地址
//==============================================================================
`define ADDR_BASE               32'h1000_0000

`define ADDR_HBM_BRAM           32'h1000_0000       // HBM BRAM base (1MB, 暂时替代HBM)
`define ADDR_INST_BRAM          32'h1010_0000       // Instruction BRAM base (128KB)
`define ADDR_VPU_GB             32'h1012_0000       // VPU Global Buffer base (128KB)
`define ADDR_VPU_WB             32'h1014_0000       // VPU Weight Buffer base (32KB)
`define ADDR_VPU_REGS           32'h1014_8000       // VPU AXI Registers base (4KB)

//==============================================================================
// 辅助宏：字节地址转 word 地址
//==============================================================================
`define BYTE_TO_WORD_ADDR(byte_addr)  ((byte_addr) >> `VPU_BYTE_ADDR_SHIFT)
`define WORD_TO_BYTE_ADDR(word_addr)  ((word_addr) << `VPU_BYTE_ADDR_SHIFT)

`endif // VPU_DEFINES_VH
