`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// INST_Decoder - 硬件指令解码器
// 
// 功能：从 inst_bram 读取指令序列，直接配置 VPU 和 CDMA_Controller
// 解决软件访问 CDMA 寄存器导致的 AXI 总线死锁问题
//
// 设计特点：
//   - inst_bram 通过 wire 直接连接，无需 AXI 接口
//   - XDMA 可以通过 AXI 写入 inst_bram
//   - INST_Decoder 直接读取 inst_bram 内容
//
// 指令格式：
//   Header (4 bytes): [31:28] OPCODE | [27:24] FLAGS | [23:0] LENGTH
//   Body: 根据 OPCODE 不同，长度不同
//
// 操作码：
//   0x0 - NOP        : 空操作
//   0x1 - CDMA_COPY  : CDMA 数据搬运 (12 bytes body)
//   0x2 - VPU_EXEC   : VPU 计算 (48 bytes body)
//   0x3 - WAIT_CDMA  : 等待 CDMA 完成
//   0x4 - WAIT_VPU   : 等待 VPU 完成
//   0x5 - SYNC       : 同步屏障
//   0xF - END        : 指令序列结束
//////////////////////////////////////////////////////////////////////////////////

module INST_Decoder #(
    parameter INST_BRAM_DEPTH = 262144,  // inst_bram 深度（32位字数）= 1MB
    parameter INST_ADDR_WIDTH = 18       // log2(INST_BRAM_DEPTH)
) (
    input  wire        clk,
    input  wire        rst_n,
    
    // 控制接口（来自 VPU_AXI_Regs）
    input  wire        decoder_start,       // 启动解码（上升沿触发）
    input  wire [31:0] inst_count,          // 指令总数（32位字数）
    output reg         decoder_busy,        // 解码器忙
    output reg         decoder_done,        // 解码完成（脉冲）
    output reg  [31:0] decoder_status,      // 状态/错误码
    
    // inst_bram 直接读取接口（wire 连接）
    output reg  [INST_ADDR_WIDTH-1:0] inst_rd_addr,  // 读地址
    input  wire [31:0]                inst_rd_data,  // 读数据（1 周期延迟）
    
    // 到 CDMA_Controller 的直接连接
    output reg         cdma_start,
    output reg         cdma_config_valid,
    input  wire        cdma_config_ready,
    output reg  [31:0] cdma_src_addr_msb,
    output reg  [31:0] cdma_src_addr_lsb,
    output reg  [31:0] cdma_dst_addr_msb,
    output reg  [31:0] cdma_dst_addr_lsb,
    output reg  [31:0] cdma_length,
    
    // 到 VPU 的直接连接
    output reg         vpu_start,
    input  wire        vpu_ready,
    output reg  [31:0] vpu_unit_choose,
    output reg  [31:0] vpu_src_addr,
    output reg  [31:0] vpu_src2_addr,
    output reg  [31:0] vpu_src_c,
    output reg  [31:0] vpu_src_h,
    output reg  [31:0] vpu_src_w,
    output reg  [31:0] vpu_bias_addr,
    output reg  [31:0] vpu_scale_addr,
    output reg  [31:0] vpu_dst_addr,
    output reg  [31:0] vpu_addr_break,
    output reg  [31:0] vpu_addr_s,
    output reg  [31:0] vpu_addr_t
);

    // 操作码定义
    localparam [3:0] OP_NOP       = 4'h0;
    localparam [3:0] OP_CDMA_COPY = 4'h1;
    localparam [3:0] OP_VPU_EXEC  = 4'h2;
    localparam [3:0] OP_WAIT_CDMA = 4'h3;
    localparam [3:0] OP_WAIT_VPU  = 4'h4;
    localparam [3:0] OP_SYNC      = 4'h5;
    localparam [3:0] OP_END       = 4'hF;
    
    // 状态码定义
    localparam [31:0] STATUS_IDLE    = 32'h0000_0000;
    localparam [31:0] STATUS_BUSY    = 32'h0000_0001;
    localparam [31:0] STATUS_DONE    = 32'h0000_0002;
    localparam [31:0] STATUS_ERROR   = 32'h8000_0000;
    
    // 状态机定义
    typedef enum logic [4:0] {
        S_IDLE           = 5'd0,
        S_FETCH_HEADER   = 5'd1,
        S_WAIT_HEADER    = 5'd2,
        S_PARSE_HEADER   = 5'd3,
        S_FETCH_BODY     = 5'd4,
        S_WAIT_BODY      = 5'd5,
        S_STORE_BODY     = 5'd6,
        S_EXEC_NOP       = 5'd7,
        S_EXEC_CDMA      = 5'd8,
        S_WAIT_CDMA_CFG  = 5'd9,
        S_WAIT_CDMA_DONE = 5'd10,
        S_EXEC_VPU       = 5'd11,
        S_WAIT_VPU_START = 5'd12,
        S_WAIT_VPU_DONE  = 5'd13,
        S_EXEC_WAIT_CDMA = 5'd14,
        S_EXEC_WAIT_VPU  = 5'd15,
        S_EXEC_SYNC      = 5'd16,
        S_NEXT_INST      = 5'd17,
        S_DONE           = 5'd18,
        S_ERROR          = 5'd19
    } state_t;
    
    state_t state, next_state;
    
    // 内部寄存器
    reg [INST_ADDR_WIDTH-1:0] current_word_idx;  // 当前指令字索引
    reg [31:0] words_remaining;                   // 剩余字数
    reg [3:0]  current_opcode;                    // 当前操作码
    reg [3:0]  current_flags;                     // 当前标志位
    reg [23:0] body_length;                       // 指令体长度（字节）
    reg [31:0] inst_header;                       // 指令头缓存
    
    // 指令体缓存（最大 48 字节 = 12 个 32 位字）
    reg [31:0] body_buffer [0:11];
    reg [3:0]  body_word_count;     // 需要读取的字数
    reg [3:0]  body_word_idx;       // 当前读取的字索引
    
    // 启动边沿检测
    reg decoder_start_d;
    wire decoder_start_pulse = decoder_start && !decoder_start_d;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            decoder_start_d <= 1'b0;
        else
            decoder_start_d <= decoder_start;
    end
    
    // 状态机：状态转移
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end
    
    // 状态机：下一状态逻辑
    always_comb begin
        next_state = state;
        
        case (state)
            S_IDLE: begin
                if (decoder_start_pulse && inst_count > 0)
                    next_state = S_FETCH_HEADER;
            end
            
            S_FETCH_HEADER: begin
                // 发出读地址，等待 1 周期
                next_state = S_WAIT_HEADER;
            end
            
            S_WAIT_HEADER: begin
                // BRAM 读取延迟 1 周期
                next_state = S_PARSE_HEADER;
            end
            
            S_PARSE_HEADER: begin
                case (current_opcode)
                    OP_NOP:       next_state = S_EXEC_NOP;
                    OP_CDMA_COPY: next_state = (body_length > 0) ? S_FETCH_BODY : S_ERROR;
                    OP_VPU_EXEC:  next_state = (body_length > 0) ? S_FETCH_BODY : S_ERROR;
                    OP_WAIT_CDMA: next_state = S_EXEC_WAIT_CDMA;
                    OP_WAIT_VPU:  next_state = S_EXEC_WAIT_VPU;
                    OP_SYNC:      next_state = S_EXEC_SYNC;
                    OP_END:       next_state = S_DONE;
                    default:      next_state = S_ERROR;
                endcase
            end
            
            S_FETCH_BODY: begin
                // 发出读地址
                next_state = S_WAIT_BODY;
            end
            
            S_WAIT_BODY: begin
                // BRAM 读取延迟 1 周期
                next_state = S_STORE_BODY;
            end
            
            S_STORE_BODY: begin
                if (body_word_idx >= body_word_count - 1) begin
                    case (current_opcode)
                        OP_CDMA_COPY: next_state = S_EXEC_CDMA;
                        OP_VPU_EXEC:  next_state = S_EXEC_VPU;
                        default:      next_state = S_ERROR;
                    endcase
                end else begin
                    next_state = S_FETCH_BODY;
                end
            end
            
            S_EXEC_NOP: begin
                next_state = S_NEXT_INST;
            end
            
            S_EXEC_CDMA: begin
                next_state = S_WAIT_CDMA_CFG;
            end
            
            S_WAIT_CDMA_CFG: begin
                if (cdma_config_ready)
                    next_state = S_WAIT_CDMA_DONE;
            end
            
            S_WAIT_CDMA_DONE: begin
                if (cdma_config_ready)
                    next_state = S_NEXT_INST;
            end
            
            S_EXEC_VPU: begin
                next_state = S_WAIT_VPU_START;
            end
            
            S_WAIT_VPU_START: begin
                next_state = S_WAIT_VPU_DONE;
            end
            
            S_WAIT_VPU_DONE: begin
                if (vpu_ready)
                    next_state = S_NEXT_INST;
            end
            
            S_EXEC_WAIT_CDMA: begin
                if (cdma_config_ready)
                    next_state = S_NEXT_INST;
            end
            
            S_EXEC_WAIT_VPU: begin
                if (vpu_ready)
                    next_state = S_NEXT_INST;
            end
            
            S_EXEC_SYNC: begin
                if (cdma_config_ready && vpu_ready)
                    next_state = S_NEXT_INST;
            end
            
            S_NEXT_INST: begin
                if (words_remaining > 0)
                    next_state = S_FETCH_HEADER;
                else
                    next_state = S_DONE;
            end
            
            S_DONE: begin
                next_state = S_IDLE;
            end
            
            S_ERROR: begin
                next_state = S_IDLE;
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    // 状态机：输出逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decoder_busy <= 1'b0;
            decoder_done <= 1'b0;
            decoder_status <= STATUS_IDLE;
            
            inst_rd_addr <= '0;
            
            cdma_start <= 1'b0;
            cdma_config_valid <= 1'b0;
            cdma_src_addr_msb <= '0;
            cdma_src_addr_lsb <= '0;
            cdma_dst_addr_msb <= '0;
            cdma_dst_addr_lsb <= '0;
            cdma_length <= '0;
            
            vpu_start <= 1'b0;
            vpu_unit_choose <= '0;
            vpu_src_addr <= '0;
            vpu_src2_addr <= '0;
            vpu_src_c <= '0;
            vpu_src_h <= '0;
            vpu_src_w <= '0;
            vpu_bias_addr <= '0;
            vpu_scale_addr <= '0;
            vpu_dst_addr <= '0;
            vpu_addr_break <= '0;
            vpu_addr_s <= '0;
            vpu_addr_t <= '0;
            
            current_word_idx <= '0;
            words_remaining <= '0;
            current_opcode <= '0;
            current_flags <= '0;
            body_length <= '0;
            inst_header <= '0;
            body_word_count <= '0;
            body_word_idx <= '0;
            
            for (int i = 0; i < 12; i++)
                body_buffer[i] <= '0;
                
        end else begin
            // 默认清除脉冲信号
            decoder_done <= 1'b0;
            vpu_start <= 1'b0;
            cdma_start <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    decoder_busy <= 1'b0;
                    decoder_status <= STATUS_IDLE;
                    cdma_config_valid <= 1'b0;
                    
                    if (decoder_start_pulse && inst_count > 0) begin
                        decoder_busy <= 1'b1;
                        decoder_status <= STATUS_BUSY;
                        current_word_idx <= '0;
                        words_remaining <= inst_count;
                        body_word_idx <= '0;
                    end
                end
                
                S_FETCH_HEADER: begin
                    // 发出读地址
                    inst_rd_addr <= current_word_idx;
                end
                
                S_WAIT_HEADER: begin
                    // 等待 BRAM 读取（1 周期延迟）
                end
                
                S_PARSE_HEADER: begin
                    // 读取数据已就绪
                    inst_header <= inst_rd_data;
                    current_opcode <= inst_rd_data[31:28];
                    current_flags <= inst_rd_data[27:24];
                    body_length <= inst_rd_data[23:0];
                    body_word_count <= (inst_rd_data[23:0] + 3) >> 2;  // 向上取整到字数
                    body_word_idx <= '0;
                    current_word_idx <= current_word_idx + 1;
                    words_remaining <= words_remaining - 1;
                end
                
                S_FETCH_BODY: begin
                    // 发出读地址
                    inst_rd_addr <= current_word_idx;
                end
                
                S_WAIT_BODY: begin
                    // 等待 BRAM 读取
                end
                
                S_STORE_BODY: begin
                    // 存储读取的数据
                    body_buffer[body_word_idx] <= inst_rd_data;
                    body_word_idx <= body_word_idx + 1;
                    current_word_idx <= current_word_idx + 1;
                    words_remaining <= words_remaining - 1;
                end
                
                S_EXEC_NOP: begin
                    // 空操作，直接进入下一条指令
                end
                
                S_EXEC_CDMA: begin
                    // CDMA_COPY 指令体：src_addr(4B), dst_addr(4B), length(4B)
                    cdma_src_addr_msb <= 32'h0;
                    cdma_src_addr_lsb <= body_buffer[0];
                    cdma_dst_addr_msb <= 32'h0;
                    cdma_dst_addr_lsb <= body_buffer[1];
                    cdma_length <= body_buffer[2];
                    cdma_config_valid <= 1'b1;
                    cdma_start <= 1'b1;
                end
                
                S_WAIT_CDMA_CFG: begin
                    // 等待 CDMA_Controller 接受配置
                    if (cdma_config_ready) begin
                        cdma_config_valid <= 1'b0;
                    end
                end
                
                S_WAIT_CDMA_DONE: begin
                    // 等待 CDMA 传输完成
                end
                
                S_EXEC_VPU: begin
                    // VPU_EXEC 指令体：12 个 32 位字
                    vpu_unit_choose <= body_buffer[0];
                    vpu_src_addr    <= body_buffer[1];
                    vpu_src2_addr   <= body_buffer[2];
                    vpu_src_c       <= body_buffer[3];
                    vpu_src_h       <= body_buffer[4];
                    vpu_src_w       <= body_buffer[5];
                    vpu_bias_addr   <= body_buffer[6];
                    vpu_scale_addr  <= body_buffer[7];
                    vpu_dst_addr    <= body_buffer[8];
                    vpu_addr_break  <= body_buffer[9];
                    vpu_addr_s      <= body_buffer[10];
                    vpu_addr_t      <= body_buffer[11];
                end
                
                S_WAIT_VPU_START: begin
                    vpu_start <= 1'b1;
                end
                
                S_WAIT_VPU_DONE: begin
                    // 等待 VPU 完成
                end
                
                S_EXEC_WAIT_CDMA: begin
                    // 等待 CDMA 空闲
                end
                
                S_EXEC_WAIT_VPU: begin
                    // 等待 VPU 空闲
                end
                
                S_EXEC_SYNC: begin
                    // 等待 CDMA 和 VPU 都空闲
                end
                
                S_NEXT_INST: begin
                    // 准备下一条指令
                    body_word_idx <= '0;
                end
                
                S_DONE: begin
                    decoder_busy <= 1'b0;
                    decoder_done <= 1'b1;
                    decoder_status <= STATUS_DONE;
                end
                
                S_ERROR: begin
                    decoder_busy <= 1'b0;
                    decoder_status <= STATUS_ERROR | {24'b0, current_opcode, current_flags};
                end
            endcase
        end
    end

endmodule
