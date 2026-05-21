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
// 握手协议：
//   - 上游（raw）: 标准 valid/ready 握手
//   - 下游（dcim）: 标准 valid/ready 握手
//   - 背压支持：dcim_act_ready 反压时，模块暂停输出并阻塞上游
//
// 使用示例：
//   mode = MODE_INT8  → 每次接收 CH_IN×8bit，分2拍输出 CH_IN×4bit
//   mode = MODE_INT16 → 每次接收 CH_IN×16bit，分4拍输出 CH_IN×4bit
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
    logic [1:0]          nibble_cnt;         // nibble 相位计数器（0~3）
    logic [1:0]          nibble_cnt_next;
    logic [1:0]          nibble_ubd;         // 上界：INT8=2, INT16=4
    logic                fire_dcim;          // dcim 握手成功
    logic                fire_raw;           // raw 握手成功
    
    // ========== 模式相关配置 ==========
    always_comb begin
        case (mode)
            MODE_INT8:   nibble_ubd = 2'd2;  // 2拍：低4bit, 高4bit
            MODE_INT16:  nibble_ubd = 2'd3;  // 4拍：[3:0], [7:4], [11:8], [15:12]
            default:     nibble_ubd = 2'd0;  // INT4 不支持，旁路
        endcase
    end
    
    // ========== 握手信号 ==========
    assign fire_dcim = dcim_act_valid && dcim_act_ready;
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
    
    // ========== 数据锁存 ==========
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raw_data_reg <= '0;
        end else if (fire_raw) begin
            raw_data_reg <= raw_act_data;
        end
    end
    
    // ========== 输出控制 ==========
    always_comb begin
        // 上游 ready：仅在 IDLE 状态接收新数据
        raw_act_ready = (state == ST_IDLE);
        
        // 下游 valid：在 SEND 状态输出
        dcim_act_valid = (state == ST_SEND);
    end
    
    // ========== Nibble 提取逻辑 ==========
    // 根据当前相位，从锁存的数据中提取对应的 nibble
    always_comb begin
        dcim_act_data = '0;
        
        for (int ch = 0; ch < CH_IN; ch++) begin
            case (nibble_cnt)
                2'd0: dcim_act_data[ch*4 +: 4] = raw_data_reg[ch*16 +  0 +: 4]; // bit[3:0]
                2'd1: dcim_act_data[ch*4 +: 4] = raw_data_reg[ch*16 +  4 +: 4]; // bit[7:4]
                2'd2: dcim_act_data[ch*4 +: 4] = raw_data_reg[ch*16 +  8 +: 4]; // bit[11:8]
                2'd3: dcim_act_data[ch*4 +: 4] = raw_data_reg[ch*16 + 12 +: 4]; // bit[15:12]
            endcase
        end
    end
    
    // ========== 断言检查（仿真用）==========
    `ifdef SIMULATION
    always_ff @(posedge clk) begin
        if (rst_n && raw_act_valid && raw_act_ready) begin
            // 检查 mode 是否合法
            assert (mode == MODE_INT8 || mode == MODE_INT16)
                else $error("act_nibble_converter: Unsupported mode=%b", mode);
        end
    end
    `endif

endmodule
