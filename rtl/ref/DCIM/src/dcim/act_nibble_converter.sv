`timescale 1ns / 1ps

// ============================================================================
// act_nibble_converter — 激活数据 INT8/INT16 → INT4（nibble）拆分器
// ============================================================================
//
// 功能：将完整的 INT8 或 INT16 激活数据自动拆分成 4bit nibble 流，
//       以符合 dcim 模块的输入要求（WD1=4）
//
// 时序行为：
//   - INT8 模式：接收 1 次 raw_act_valid → 输出 2 次 dcim_act_valid（低/高nibble）
//   - INT16 模式：接收 1 次 raw_act_valid → 输出 4 次 dcim_act_valid（4个nibble）
//
// ============================================================================

module act_nibble_converter #(
    parameter CH_IN = 16,                    // 输入通道数
    parameter MODE_INT8  = 3'b110,           // INT8 模式
    parameter MODE_INT16 = 3'b111            // INT16 模式
)(
    input  logic                    clk,
    input  logic                    rst_n,
    
    // 模式选择
    input  logic [2:0]              mode,            // 当前计算模式
    
    // 上游接口：原始 INT8/INT16 激活数据
    input  logic                    raw_act_valid,   // 上游数据有效
    output logic                    raw_act_ready,   // 本模块准备接收
    input  logic [CH_IN*16-1:0]     raw_act_data,    // 最大支持 INT16，INT8 时用低8bit
    
    // 下游接口：拆分后的 4bit nibble 流（送入 dcim）
    output logic                    dcim_act_valid,  // 输出数据有效
    input  logic                    dcim_act_ready,  // dcim 准备接收
    output logic [CH_IN*4-1:0]      dcim_act_data    // 每拍 CH_IN 个 4bit nibble
);

    // ========== 内部信号 ==========
    typedef enum logic [1:0] {
        ST_IDLE,        // 空闲，等待上游数据
        ST_SEND         // 发送 nibble 数据
    } state_t;
    
    state_t state, state_next;
    
    logic [CH_IN*16-1:0] raw_data_reg;      // 锁存的原始数据
    (* max_fanout = 32 *) logic [1:0] nibble_cnt;         // nibble 相位计数器（0~3）
    logic [1:0]          nibble_cnt_next;
    logic [1:0]          nibble_ubd;         // 上界：INT8=2, INT16=4
    logic                fire_dcim;          // dcim 握手成功
    logic                fire_raw;           // raw 握手成功
    
    // 时序优化：预计算所有 nibble 相位的数据，减少组合逻辑深度
    (* max_fanout = 32 *) logic [CH_IN*4-1:0] nibble_data [0:3];  // 4 个相位的预计算结果
    
    // 时序优化：输出流水线寄存器，打断 nibble_cnt 到 DSP 的关键路径
    logic [CH_IN*4-1:0] dcim_act_data_pipe;
    logic               dcim_act_valid_pipe;
    logic               pipe_ready;          // 流水线级是否可以接收新数据
    
    // ========== 模式相关配置 ==========
    always_comb begin
        case (mode)
            MODE_INT8:   nibble_ubd = 2'd1;  // 2拍：nibble_cnt = 0, 1
            MODE_INT16:  nibble_ubd = 2'd3;  // 4拍：nibble_cnt = 0, 1, 2, 3
            default:     nibble_ubd = 2'd0;  // INT4 不支持，旁路
        endcase
    end
    
    // ========== 握手信号 ==========
    // pipe_ready: 流水线级可以接收新数据的条件
    // - 如果流水线级无效数据，直接可以接收
    // - 如果流水线级有有效数据，需要等下游接收
    assign pipe_ready = !dcim_act_valid_pipe || dcim_act_ready;
    
    // fire_dcim: 状态机推进的条件 = 在 SEND 状态 && 流水线级可以接收
    assign fire_dcim = (state == ST_SEND) && pipe_ready;
    assign fire_raw  = raw_act_valid && raw_act_ready;
    
    // ========== 状态机：主控制逻辑 ==========
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            nibble_cnt <= 2'd0;
        end else begin
            state <= state_next;
            nibble_cnt <= nibble_cnt_next;
        end
    end
    
    always_comb begin
        state_next = state;
        nibble_cnt_next = nibble_cnt;
        
        case (state)
            ST_IDLE: begin
                if (fire_raw) begin
                    // 接收到上游数据，开始发送
                    state_next = ST_SEND;
                    nibble_cnt_next = 2'd0;
                end
            end
            
            ST_SEND: begin
                if (fire_dcim) begin
                    if (nibble_cnt == nibble_ubd) begin
                        // 最后一拍发送完毕，回到 IDLE
                        state_next = ST_IDLE;
                        nibble_cnt_next = 2'd0;
                    end else begin
                        // 继续发送下一拍
                        nibble_cnt_next = nibble_cnt + 1'b1;
                    end
                end
            end
            
            default: begin
                state_next = ST_IDLE;
                nibble_cnt_next = 2'd0;
            end
        endcase
    end
    
    // ========== 数据锁存 + 预计算 nibble ==========
    // 时序优化：在接收数据时立即预计算所有 nibble 相位，避免后续组合逻辑深度
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raw_data_reg <= '0;
            for (int i = 0; i < 4; i++) begin
                nibble_data[i] <= '0;
            end
        end else if (fire_raw) begin
            raw_data_reg <= raw_act_data;
            
            // 预计算所有 4 个 nibble 相位的数据
            for (int ch = 0; ch < CH_IN; ch++) begin
                case (mode)
                    MODE_INT8: begin
                        // INT8: 只使用相位 0, 1
                        nibble_data[0][ch*4 +: 4] <= raw_act_data[ch*16 + 4 +: 4]; // bit[7:4] 高 nibble 先发
                        nibble_data[1][ch*4 +: 4] <= raw_act_data[ch*16 + 0 +: 4]; // bit[3:0] 低 nibble 后发
                        nibble_data[2][ch*4 +: 4] <= 4'd0;  // 未使用
                        nibble_data[3][ch*4 +: 4] <= 4'd0;  // 未使用
                    end
                    MODE_INT16: begin
                        // INT16: 使用所有 4 个相位
                        nibble_data[0][ch*4 +: 4] <= raw_act_data[ch*16 + 12 +: 4]; // bit[15:12] 最高 nibble
                        nibble_data[1][ch*4 +: 4] <= raw_act_data[ch*16 +  8 +: 4]; // bit[11:8]
                        nibble_data[2][ch*4 +: 4] <= raw_act_data[ch*16 +  4 +: 4]; // bit[7:4]
                        nibble_data[3][ch*4 +: 4] <= raw_act_data[ch*16 +  0 +: 4]; // bit[3:0] 最低 nibble
                    end
                    default: begin
                        // 默认：直接传递低 4bit
                        nibble_data[0][ch*4 +: 4] <= raw_act_data[ch*16 +: 4];
                        nibble_data[1][ch*4 +: 4] <= 4'd0;
                        nibble_data[2][ch*4 +: 4] <= 4'd0;
                        nibble_data[3][ch*4 +: 4] <= 4'd0;
                    end
                endcase
            end
        end
    end
    
    // ========== 输出流水线寄存器 ==========
    // 时序优化：在输出端插入流水线级，打断关键路径
    // 实现 skid buffer 风格的流水线
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcim_act_data_pipe <= '0;
            dcim_act_valid_pipe <= 1'b0;
        end else begin
            // 当流水线级可以接收新数据时，更新数据和 valid
            if (pipe_ready) begin
                dcim_act_data_pipe <= nibble_data[nibble_cnt];
                dcim_act_valid_pipe <= (state == ST_SEND);
            end
            // 否则保持当前值（阻塞状态）
        end
    end
    
    // ========== 输出控制 ==========
    always_comb begin
        // 上游 ready：仅在 IDLE 状态接收新数据
        raw_act_ready = (state == ST_IDLE);
        
        // 下游 valid：使用流水线后的 valid（已在流水线寄存器中赋值）
        dcim_act_valid = dcim_act_valid_pipe;
    end
    
    // ========== Nibble 提取逻辑 ==========
    // 时序优化：直接使用流水线寄存器的输出
    always_comb begin
        dcim_act_data = dcim_act_data_pipe;
    end

endmodule
