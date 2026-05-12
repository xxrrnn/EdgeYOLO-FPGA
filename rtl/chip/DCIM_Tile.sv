`timescale 1ns / 1ps

// ============================================================================
// DCIM_Macro - 基于 DCIM 核心的矩阵乘法加速器
// ============================================================================
//
// 功能：封装 DCIM 核心，提供简单的 BRAM 接口进行矩阵乘法计算
//       Y = X × W，其中 X 是激活矩阵，W 是权重矩阵
//
// 数据格式：
//   - IBUF/OBUF 位宽：128-bit
//   - 权重：4-bit nibble，存储在 IBUF[0:7]（共 8×128=1024 bit = 16×16×4 bit）
//   - INT8 激活：16×8=128-bit，每行 1 次 IBUF 读取
//   - INT16 激活：16×16=256-bit，每行 2 次 IBUF 读取
//
// 输出格式（统一为连续 INT32）：
//   - INT8：8 个逻辑通道，每个通道 WD3-bit 符号扩展到 32-bit
//           逻辑通道 i → 物理通道 (i*2+2)
//           输出：8 × 32-bit = 256-bit = 2 × 128-bit OBUF 写入
//   - INT16：4 个逻辑通道，每个通道 32-bit
//           逻辑通道 i → 物理通道 (i*4, i*4+1)，32-bit = {phys[i*4+1], phys[i*4]}
//           输出：4 × 32-bit = 128-bit = 1 × 128-bit OBUF 写入
//
// 时序优化：
//   - 输出数据路径采用 3 级流水线：锁存 → 提取/打包 → 写入 OBUF
//   - 高扇出信号添加 max_fanout 约束
//   - 关键寄存器添加 KEEP 属性防止优化
//
// ============================================================================

`include "../../ref/DCIM/src/inc/para.v"

module DCIM_Tile #(
    parameter WD1     = 4,          // 权重位宽（nibble）
    parameter CH_IN   = 16,         // 输入通道数
    parameter CH_OUT  = 16,         // 输出通道数
    parameter SRAM_DP = 128,        // SRAM 深度
    parameter CYCLE   = 8,          // 权重加载周期数
    parameter ACC     = 80,         // 最大累加深度（支持 K=1152 → 72 次累加）
    
    parameter BUF_ADDR_WIDTH = 12,  // IBUF/OBUF 地址位宽
    parameter BUF_DATA_WIDTH = 128, // IBUF/OBUF 数据位宽
    
    localparam SRAM_WD     = CH_IN * CH_OUT * WD1 / CYCLE,  // 128 bits
    localparam ADDR_WD     = $clog2(SRAM_DP),
    localparam ACC_UBD_WD  = $clog2(ACC+1),
    localparam WD2         = 2*WD1 + $clog2(CH_IN),         // 12 bits
    localparam WD3         = WD2 + $clog2(ACC),             // 19 bits (ACC=80)
    localparam OUT_WIDTH   = CH_OUT * WD3                   // 304 bits
)(
    input  wire                          clk,
    input  wire                          rst_n,
    
    // 控制接口
    input  wire                          start,      // 启动信号（单周期脉冲）
    output wire                          done,       // 完成信号
    output wire                          ready,      // 就绪信号（可接收新任务）
    
    // 配置接口
    input  wire [2:0]                    mode,       // 计算模式：MODE_INT8 或 MODE_INT16
    input  wire [ACC_UBD_WD-1:0]         acc_depth,  // 累加深度（0=不累加，N=每N行累加一次）
    input  wire [15:0]                   num_rows,   // 激活矩阵行数
    input  wire [BUF_ADDR_WIDTH-1:0]     wei_base_addr,  // 权重在 IBUF 中的起始地址
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,  // 激活在 IBUF 中的起始地址
    input  wire [BUF_ADDR_WIDTH-1:0]     out_base_addr,  // 输出在 OBUF 中的起始地址
    
    // 外部 IBUF 接口（读取权重和激活数据）
    output reg  [BUF_ADDR_WIDTH-1:0]     ibuf_addr,
    output reg                           ibuf_en,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_dout,
    
    // 外部 OBUF 接口（写入计算结果）
    output reg  [BUF_DATA_WIDTH/8-1:0]   obuf_we,
    output reg  [BUF_ADDR_WIDTH-1:0]     obuf_addr,
    output reg  [BUF_DATA_WIDTH-1:0]     obuf_din,
    output reg                           obuf_en
);

    // ========================================================================
    // 状态机定义
    // ========================================================================
    typedef enum logic [3:0] {
        ST_IDLE,            // 空闲，等待启动
        ST_LOAD_WEI_ADDR,   // 设置 IBUF 读地址（权重）
        ST_LOAD_WEI_WAIT,   // 等待 IBUF 读延迟
        ST_LOAD_WEI,        // 将权重写入 DCIM SRAM
        ST_PREP_PPCACHE,    // 准备 ppCache 加载（设置 base_addr=0）
        ST_LOAD_PPCACHE,    // 触发 ppCache 从 SRAM 加载权重
        ST_SWAP_PPCACHE,    // 触发 swap 切换双缓冲
        ST_LOAD_ACT_ADDR,   // 设置 IBUF 读地址（激活）
        ST_LOAD_ACT_WAIT,   // 等待 IBUF 读延迟
        ST_LOAD_ACT,        // 读取激活数据（INT8 完成，INT16 第一次）
        ST_LOAD_ACT2_ADDR,  // INT16：设置第二次读地址
        ST_LOAD_ACT2_WAIT,  // INT16：等待第二次读延迟
        ST_LOAD_ACT2,       // INT16：读取高 128-bit
        ST_COMPUTE,         // 发送激活数据到 DCIM
        ST_WAIT_RESULT,     // 等待所有结果写入 OBUF
        ST_DONE             // 完成
    } state_t;
    
    state_t state, next_state;
    
    // ========================================================================
    // DCIM 核心接口信号
    // ========================================================================
    wire                     dcim_clr;
    wire                     dcim_ena = 1'b1;
    reg                      dcim_wr_wei;        // 写权重到 SRAM
    reg                      dcim_load_wei;      // 触发 ppCache 加载
    reg                      dcim_swap_wei;      // 触发双缓冲切换
    wire                     dcim_ready_wei;     // SRAM 写就绪
    reg  [ADDR_WD-1:0]       dcim_addr_wei;      // SRAM 地址
    reg  [SRAM_WD-1:0]       dcim_data_wei;      // SRAM 写数据
    
    // clr 信号：在 IDLE 状态时清除累加器，确保每次新计算从零开始
    assign dcim_clr = (state == ST_IDLE);
    
    wire                     dcim_valid_out;     // 输出有效
    wire                     dcim_ready_out = 1'b1;  // 始终接收输出
    wire [OUT_WIDTH-1:0]     dcim_data_out;      // 256-bit 输出
    
    // ========================================================================
    // 激活预处理接口信号
    // ========================================================================
    reg                      conv_valid;         // 原始激活有效
    wire                     conv_ready;         // 预处理器就绪
    reg  [CH_IN*16-1:0]      conv_data;          // 256-bit 原始激活
    wire                     dcim_valid_act;     // nibble 流有效
    wire                     dcim_ready_act;     // DCIM 就绪
    wire [CH_IN*WD1-1:0]     dcim_data_act;      // 64-bit nibble 流
    
    // ========================================================================
    // 计数器和配置寄存器
    // ========================================================================
    reg [15:0]               row_cnt;            // 当前处理的行号
    reg [3:0]                wei_load_cnt;       // 权重加载计数（0-7）
    reg [3:0]                ppcache_cnt;        // ppCache 加载计数
    reg [15:0]               result_cnt;         // 已保存的结果数
    reg [2:0]                wait_cnt;           // BRAM 读延迟计数
    reg [BUF_DATA_WIDTH-1:0] act_buf_lo;         // INT16 低 128-bit 缓存
    
    // 配置寄存器 - 添加 max_fanout 约束减少扇出
    (* max_fanout = 32 *) reg [2:0]                mode_reg;
    reg [ACC_UBD_WD-1:0]     acc_reg;
    reg [15:0]               num_rows_reg;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] act_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] out_base_addr_reg;
    
    // 计算期望的输出数量
    wire [15:0] expected_outputs = (acc_reg == 0) ? num_rows_reg : (num_rows_reg / acc_reg);
    
    // is_int16 信号复制以减少扇出
    (* max_fanout = 16 *) reg is_int16_reg;
    wire is_int16 = is_int16_reg;
    
    // 状态输出
    assign ready = (state == ST_IDLE);
    assign done  = (state == ST_DONE);
    
    // ========================================================================
    // 状态机：状态转换
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else state <= next_state;
    end
    
    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:          if (start) next_state = ST_LOAD_WEI_ADDR;
            ST_LOAD_WEI_ADDR: next_state = ST_LOAD_WEI_WAIT;
            ST_LOAD_WEI_WAIT: if (wait_cnt >= 3) next_state = ST_LOAD_WEI;
            ST_LOAD_WEI: begin
                if (wei_load_cnt >= CYCLE - 1) next_state = ST_PREP_PPCACHE;
                else next_state = ST_LOAD_WEI_ADDR;
            end
            ST_PREP_PPCACHE:  next_state = ST_LOAD_PPCACHE;
            ST_LOAD_PPCACHE:  if (ppcache_cnt >= CYCLE + 2) next_state = ST_SWAP_PPCACHE;
            ST_SWAP_PPCACHE:  next_state = ST_LOAD_ACT_ADDR;
            ST_LOAD_ACT_ADDR: next_state = ST_LOAD_ACT_WAIT;
            ST_LOAD_ACT_WAIT: if (wait_cnt >= 3) next_state = ST_LOAD_ACT;
            ST_LOAD_ACT:      next_state = is_int16 ? ST_LOAD_ACT2_ADDR : ST_COMPUTE;
            ST_LOAD_ACT2_ADDR: next_state = ST_LOAD_ACT2_WAIT;
            ST_LOAD_ACT2_WAIT: if (wait_cnt >= 3) next_state = ST_LOAD_ACT2;
            ST_LOAD_ACT2:     next_state = ST_COMPUTE;
            ST_COMPUTE: begin
                if (conv_valid && conv_ready) begin
                    if (row_cnt >= num_rows_reg - 1) next_state = ST_WAIT_RESULT;
                    else next_state = ST_LOAD_ACT_ADDR;
                end
            end
            ST_WAIT_RESULT:   if (result_cnt >= expected_outputs) next_state = ST_DONE;
            ST_DONE:          next_state = ST_IDLE;
            default:          next_state = ST_IDLE;
        endcase
    end
    
    // ========================================================================
    // 配置寄存器：在启动时锁存配置
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg <= `MODE_INT8;
            acc_reg <= 0;
            num_rows_reg <= 0;
            wei_base_addr_reg <= 0;
            act_base_addr_reg <= 0;
            out_base_addr_reg <= 0;
            is_int16_reg <= 0;
        end else if (state == ST_IDLE && start) begin
            mode_reg <= mode;
            acc_reg <= acc_depth;
            num_rows_reg <= num_rows;
            wei_base_addr_reg <= wei_base_addr;
            act_base_addr_reg <= act_base_addr;
            out_base_addr_reg <= out_base_addr;
            is_int16_reg <= (mode == `MODE_INT16);
        end
    end
    
    // ========================================================================
    // 主控制逻辑
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wei_load_cnt <= 0; ppcache_cnt <= 0; row_cnt <= 0; wait_cnt <= 0;
            dcim_wr_wei <= 0; dcim_load_wei <= 0; dcim_swap_wei <= 0;
            dcim_addr_wei <= 0; dcim_data_wei <= 0;
            conv_valid <= 0; conv_data <= 0;
            ibuf_addr <= 0; ibuf_en <= 0;
            act_buf_lo <= 0;
        end else begin
            case (state)
                // ============================================================
                // 空闲状态：复位所有计数器
                // ============================================================
                ST_IDLE: begin
                    wei_load_cnt <= 0; ppcache_cnt <= 0; row_cnt <= 0; wait_cnt <= 0;
                    dcim_wr_wei <= 0; dcim_load_wei <= 0; dcim_swap_wei <= 0;
                    conv_valid <= 0; ibuf_en <= 0;
                end
                
                // ============================================================
                // 权重加载阶段：从 IBUF 读取权重，写入 DCIM SRAM
                // ============================================================
                ST_LOAD_WEI_ADDR: begin
                    ibuf_addr <= wei_base_addr_reg + wei_load_cnt;
                    ibuf_en <= 1'b1;
                    dcim_wr_wei <= 0;
                    wait_cnt <= 0;
                end
                
                ST_LOAD_WEI_WAIT: begin
                    ibuf_en <= 0;
                    wait_cnt <= wait_cnt + 1;
                end
                
                ST_LOAD_WEI: begin
                    dcim_wr_wei <= 1'b1;
                    dcim_addr_wei <= wei_load_cnt;
                    dcim_data_wei <= ibuf_dout;
                    if (dcim_ready_wei) wei_load_cnt <= wei_load_cnt + 1;
                end
                
                // ============================================================
                // ppCache 加载阶段：将 SRAM 中的权重加载到 ppCache
                // ============================================================
                ST_PREP_PPCACHE: begin
                    dcim_wr_wei <= 0;
                    dcim_addr_wei <= 0;  // 设置 base_addr = 0
                    dcim_load_wei <= 0;
                end
                
                ST_LOAD_PPCACHE: begin
                    dcim_wr_wei <= 0;
                    dcim_load_wei <= (ppcache_cnt == 0);  // 只在第一个周期触发
                    ppcache_cnt <= ppcache_cnt + 1;
                end
                
                ST_SWAP_PPCACHE: begin
                    dcim_load_wei <= 0;
                    dcim_swap_wei <= 1'b1;  // 切换双缓冲，使新权重生效
                end
                
                // ============================================================
                // 激活加载阶段：从 IBUF 读取激活数据
                // ============================================================
                ST_LOAD_ACT_ADDR: begin
                    dcim_swap_wei <= 0;
                    dcim_load_wei <= 0;
                    // INT8: 每行 1 次读取，INT16: 每行 2 次读取
                    ibuf_addr <= is_int16 ? (act_base_addr_reg + row_cnt * 2) 
                                           : (act_base_addr_reg + row_cnt);
                    ibuf_en <= 1'b1;
                    conv_valid <= 0;
                    wait_cnt <= 0;
                end
                
                ST_LOAD_ACT_WAIT: begin
                    ibuf_en <= 0;
                    wait_cnt <= wait_cnt + 1;
                end
                
                ST_LOAD_ACT: begin
                    if (is_int16) begin
                        // INT16: 缓存低 128-bit，等待高 128-bit
                        act_buf_lo <= ibuf_dout;
                    end else begin
                        // INT8: 将 8-bit 符号扩展到 16-bit
                        for (int ch = 0; ch < CH_IN; ch++) begin
                            conv_data[ch*16 +: 16] <= {{8{ibuf_dout[ch*8 + 7]}}, ibuf_dout[ch*8 +: 8]};
                        end
                    end
                end
                
                // INT16 第二次读取
                ST_LOAD_ACT2_ADDR: begin
                    ibuf_addr <= act_base_addr_reg + row_cnt * 2 + 1;
                    ibuf_en <= 1'b1;
                    wait_cnt <= 0;
                end
                
                ST_LOAD_ACT2_WAIT: begin
                    ibuf_en <= 0;
                    wait_cnt <= wait_cnt + 1;
                end
                
                ST_LOAD_ACT2: begin
                    // INT16: 组合 256-bit（高 128-bit 在高位）
                    conv_data <= {ibuf_dout, act_buf_lo};
                end
                
                // ============================================================
                // 计算阶段：发送激活数据到预处理器
                // ============================================================
                ST_COMPUTE: begin
                    conv_valid <= 1'b1;
                    if (conv_valid && conv_ready) begin
                        conv_valid <= 0;
                        row_cnt <= row_cnt + 1;
                    end
                end
                
                ST_WAIT_RESULT: begin
                    conv_valid <= 0;
                end
                
                default: begin
                    dcim_wr_wei <= 0; dcim_load_wei <= 0; dcim_swap_wei <= 0;
                    conv_valid <= 0; ibuf_en <= 0;
                end
            endcase
        end
    end
    
    // ========================================================================
    // 结果保存：提取逻辑通道数据，统一输出为连续 INT32 格式
    // ========================================================================
    // INT8：8 个逻辑通道 × 32-bit = 256-bit → 2 次 OBUF 写入
    // INT16：4 个逻辑通道 × 32-bit = 128-bit → 1 次 OBUF 写入
    // ========================================================================
    // 
    // 流水线结构（3 级）：
    //   Stage 0: 锁存 DCIM 输出 (dcim_data_latch)
    //   Stage 1: 提取逻辑通道并打包 (int8_packed_reg / int16_packed_reg)
    //   Stage 2: 写入 OBUF
    //
    // ========================================================================
    
    // 写入阶段状态机
    // 0: 等待 DCIM 输出
    // 1: 锁存完成，准备提取
    // 2: 提取完成，写第一块数据
    // 3: (仅 INT8) 写第二块数据
    reg [2:0] save_phase;
    
    // Stage 0: DCIM 输出锁存寄存器
    (* keep = "true" *) reg [OUT_WIDTH-1:0] dcim_data_latch;
    
    // 从物理通道提取逻辑通道数据并转换为 INT32
    // 使用寄存器版本的 phys_ch 以减少组合逻辑深度
    (* keep = "true" *) reg signed [WD3-1:0] phys_ch_reg [0:CH_OUT-1];
    
    // Stage 1: 打包后的输出数据寄存器
    (* keep = "true" *) reg [255:0] int8_packed_reg;
    (* keep = "true" *) reg [127:0] int16_packed_reg;
    
    // INT8 逻辑通道提取结果（组合逻辑）
    wire signed [31:0] int8_result [0:7];
    wire signed [31:0] int16_result [0:3];
    
    // INT8 逻辑通道提取：逻辑通道 i → 物理通道 (i*2+2)
    // 注意：逻辑通道 7 对应物理通道 16，超出范围，使用物理通道 14（与通道 6 相同）
    // WD3-bit 符号扩展到 32-bit（若 WD3 > 32 则截断高位）
    genvar gi;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : int8_extract
            localparam PHYS_IDX_RAW = gi * 2 + 2;
            localparam PHYS_IDX = (PHYS_IDX_RAW >= CH_OUT) ? (CH_OUT - 2) : PHYS_IDX_RAW;
            if (WD3 <= 32) begin : sign_extend
                assign int8_result[gi] = {{(32-WD3){phys_ch_reg[PHYS_IDX][WD3-1]}}, phys_ch_reg[PHYS_IDX]};
            end else begin : truncate
                assign int8_result[gi] = phys_ch_reg[PHYS_IDX][31:0];
            end
        end
    endgenerate
    
    // INT16 逻辑通道提取：逻辑通道 i → 物理通道 (i*4, i*4+1, i*4+2, i*4+3)
    // INT16 模式下，4 个物理通道组成一个 4*WD3 bit 的累加结果
    // 取低 32-bit 作为最终结果
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : int16_extract
            localparam PHYS_BASE = gi * 4;
            wire [4*WD3-1:0] int16_full = {phys_ch_reg[PHYS_BASE+3], phys_ch_reg[PHYS_BASE+2], 
                                            phys_ch_reg[PHYS_BASE+1], phys_ch_reg[PHYS_BASE]};
            assign int16_result[gi] = int16_full[31:0];
        end
    endgenerate
    
    // 组装输出数据（组合逻辑，用于下一级寄存器）
    wire [255:0] int8_packed_comb = {int8_result[7], int8_result[6], int8_result[5], int8_result[4],
                                      int8_result[3], int8_result[2], int8_result[1], int8_result[0]};
    wire [127:0] int16_packed_comb = {int16_result[3], int16_result[2], int16_result[1], int16_result[0]};
    
    // ========================================================================
    // 流水线状态机
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_cnt <= 0;
            obuf_we <= 0; obuf_en <= 0; obuf_addr <= 0; obuf_din <= 0;
            save_phase <= 0;
            dcim_data_latch <= 0;
            int8_packed_reg <= 0;
            int16_packed_reg <= 0;
            for (int i = 0; i < CH_OUT; i++) phys_ch_reg[i] <= 0;
        end else begin
            if (state == ST_IDLE) begin
                result_cnt <= 0;
                obuf_we <= 0; obuf_en <= 0;
                save_phase <= 0;
            end else begin
                case (save_phase)
                    3'd0: begin
                        // Stage 0: 等待并锁存 DCIM 输出
                        obuf_en <= 0;
                        obuf_we <= 0;
                        if (dcim_valid_out && dcim_ready_out) begin
                            dcim_data_latch <= dcim_data_out;
                            save_phase <= 3'd1;
                        end
                    end
                    
                    3'd1: begin
                        // Stage 1: 解包物理通道到寄存器
                        for (int i = 0; i < CH_OUT; i++) begin
                            phys_ch_reg[i] <= dcim_data_latch[i*WD3 +: WD3];
                        end
                        save_phase <= 3'd2;
                        obuf_en <= 0;
                        obuf_we <= 0;
                    end
                    
                    3'd2: begin
                        // Stage 2: 打包并准备写入
                        int8_packed_reg <= int8_packed_comb;
                        int16_packed_reg <= int16_packed_comb;
                        save_phase <= 3'd3;
                        obuf_en <= 0;
                        obuf_we <= 0;
                    end
                    
                    3'd3: begin
                        // Stage 3: 写第一块数据到 OBUF
                        obuf_en <= 1'b1;
                        obuf_we <= {(BUF_DATA_WIDTH/8){1'b1}};
                        
                        if (is_int16_reg) begin
                            // INT16：写 128-bit（4 个 INT32），完成
                            obuf_addr <= out_base_addr_reg + result_cnt;
                            obuf_din <= int16_packed_reg;
                            save_phase <= 3'd0;
                            result_cnt <= result_cnt + 1;
                        end else begin
                            // INT8：写低 128-bit（逻辑通道 0-3）
                            obuf_addr <= out_base_addr_reg + result_cnt * 2;
                            obuf_din <= int8_packed_reg[127:0];
                            save_phase <= 3'd4;  // 还需要写高 128-bit
                        end
                    end
                    
                    3'd4: begin
                        // Stage 4（仅 INT8）：写高 128-bit（逻辑通道 4-7）
                        obuf_en <= 1'b1;
                        obuf_we <= {(BUF_DATA_WIDTH/8){1'b1}};
                        obuf_addr <= out_base_addr_reg + result_cnt * 2 + 1;
                        obuf_din <= int8_packed_reg[255:128];
                        save_phase <= 3'd0;
                        result_cnt <= result_cnt + 1;
                    end
                    
                    default: begin
                        obuf_en <= 0;
                        obuf_we <= 0;
                        save_phase <= 3'd0;
                    end
                endcase
            end
        end
    end
    
    // ========================================================================
    // 模块实例化
    // ========================================================================
    
    // DCIM 核心
    dcim #(
        .WD1(WD1), .CH_IN(CH_IN), .CH_OUT(CH_OUT),
        .SRAM_DP(SRAM_DP), .CYCLE(CYCLE), .ACC(ACC)
    ) u_dcim (
        .clk(clk), .rstn(rst_n), .clr(dcim_clr), .ena(dcim_ena),
        .mode_cal(mode_reg), .acc(acc_reg),
        .wr_wei(dcim_wr_wei), .load_wei(dcim_load_wei), .swap_wei(dcim_swap_wei),
        .up_ready_wei(dcim_ready_wei), .up_address_wei(dcim_addr_wei),
        .up_data_wei(dcim_data_wei), .up_be_wei({SRAM_WD{1'b1}}),
        .up_valid_cal(dcim_valid_act), .up_ready_cal(dcim_ready_act), .up_data_cal(dcim_data_act),
        .dn_valid(dcim_valid_out), .dn_ready(dcim_ready_out), .dn_data(dcim_data_out)
    );
    
    // 激活预处理器：将 INT8/INT16 拆分为 4-bit nibble 流
    act_nibble_converter #(
        .CH_IN(CH_IN), .MODE_INT8(`MODE_INT8), .MODE_INT16(`MODE_INT16)
    ) u_converter (
        .clk(clk), .rst_n(rst_n), .mode(mode_reg),
        .raw_act_valid(conv_valid), .raw_act_ready(conv_ready), .raw_act_data(conv_data),
        .dcim_act_valid(dcim_valid_act), .dcim_act_ready(dcim_ready_act), .dcim_act_data(dcim_data_act)
    );
    


endmodule
