`timescale 1ns / 1ns
`include "chip_defines.vh"

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
//   0x6 - DCIM_EXEC  : 触发 DCIM 启动 (写 CTRL 寄存器, 无 body)
//   0x7 - WAIT_DCIM  : 等待 DCIM Array 完成
//   0x8 - DCIM_CFG   : 批量寄存器写入 DCIM (N pairs of addr/data)
//   0x9 - DCIM_LAYER : DCIM layer-level loop (mode/weights once, per-pixel act/out update)
//   0xF - END        : 指令序列结束
//////////////////////////////////////////////////////////////////////////////////

module INST_Decoder #(
    parameter INST_BRAM_DEPTH = `INST_DEPTH,
    parameter INST_ADDR_WIDTH = `INST_ADDR_WIDTH
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
    output reg  [31:0] vpu_addr_t,
    output reg  [3:0]  vpu_flags,        // OP_VPU_EXEC header[27:24]，flags[0]=relu_en
    
    // DCIM direct register write interface
    output reg         dcim_cfg_wr_en,
    output reg  [11:0] dcim_cfg_wr_addr,
    output reg  [31:0] dcim_cfg_wr_data,
    input  wire        dcim_ready
);

    // 操作码定义
    localparam [3:0] OP_NOP       = 4'h0;
    localparam [3:0] OP_CDMA_COPY = 4'h1;
    localparam [3:0] OP_VPU_EXEC  = 4'h2;
    localparam [3:0] OP_WAIT_CDMA = 4'h3;
    localparam [3:0] OP_WAIT_VPU  = 4'h4;
    localparam [3:0] OP_SYNC      = 4'h5;
    localparam [3:0] OP_DCIM_EXEC = 4'h6;
    localparam [3:0] OP_WAIT_DCIM = 4'h7;
    localparam [3:0] OP_DCIM_CFG  = 4'h8;
    localparam [3:0] OP_DCIM_LAYER = 4'h9;
    localparam [3:0] OP_CDMA_STRIDE = 4'hA;
    localparam [3:0] OP_END       = 4'hF;
    
    // 状态码定义
    localparam [31:0] STATUS_IDLE    = 32'h0000_0000;
    localparam [31:0] STATUS_BUSY    = 32'h0000_0001;
    localparam [31:0] STATUS_DONE    = 32'h0000_0002;
    localparam [31:0] STATUS_ERROR   = 32'h8000_0000;
    
    // 状态机定义
    typedef enum logic [5:0] {
        S_IDLE            = 6'd0,
        S_FETCH_HEADER    = 6'd1,
        S_WAIT_HEADER     = 6'd2,
        S_WAIT_HEADER_P1  = 6'd3,
        S_WAIT_HEADER_P2  = 6'd4,
        S_WAIT_HEADER_P3  = 6'd5,
        S_PARSE_HEADER    = 6'd6,
        S_FETCH_BODY      = 6'd7,
        S_WAIT_BODY       = 6'd8,
        S_WAIT_BODY_P1    = 6'd9,
        S_WAIT_BODY_P2    = 6'd10,
        S_WAIT_BODY_P3    = 6'd11,
        S_STORE_BODY      = 6'd12,
        S_EXEC_NOP        = 6'd13,
        S_EXEC_CDMA       = 6'd14,
        S_WAIT_CDMA_CFG   = 6'd15,
        S_WAIT_CDMA_DONE  = 6'd16,
        S_EXEC_VPU        = 6'd17,
        S_WAIT_VPU_START  = 6'd18,
        S_WAIT_VPU_DONE   = 6'd19,
        S_EXEC_WAIT_CDMA  = 6'd20,
        S_EXEC_WAIT_VPU   = 6'd21,
        S_EXEC_SYNC       = 6'd22,
        S_NEXT_INST       = 6'd23,
        S_DONE            = 6'd24,
        S_ERROR           = 6'd25,
        S_EXEC_DCIM       = 6'd26,
        S_WAIT_DCIM_DONE  = 6'd28,
        S_EXEC_WAIT_DCIM  = 6'd29,
        S_DCIM_CFG_INIT      = 6'd30,
        S_DCIM_CFG_APPLY     = 6'd43,
        S_DCIM_LAYER_INIT     = 6'd44,
        S_DCIM_LAYER_CFG_MODE = 6'd45,
        S_DCIM_LAYER_CFG_TILE = 6'd46,
        S_DCIM_LAYER_CFG_WEI  = 6'd47,
        S_DCIM_LAYER_CFG_ACT  = 6'd48,
        S_DCIM_LAYER_CFG_OUT  = 6'd49,
        S_DCIM_LAYER_START    = 6'd50,
        S_DCIM_LAYER_WAIT     = 6'd51,
        S_DCIM_LAYER_NEXT     = 6'd52,
        S_DCIM_LAYER_CFG_TILE_HI = 6'd53,
        S_CDMA_STRIDE_INIT       = 6'd54,
        S_CDMA_STRIDE_ISSUE      = 6'd55,
        S_CDMA_STRIDE_WAIT       = 6'd56,
        S_CDMA_STRIDE_NEXT       = 6'd57
    } state_t;

    localparam int DCIM_NUM_TILES_L = `DCIM_NUM_TILES;
    localparam int DCIM_TILE_IDX_W   = (DCIM_NUM_TILES_L <= 1) ? 1 : $clog2(DCIM_NUM_TILES_L);
    localparam int DCIM_CFG_MAX_BODY_WORDS = 32;  // max 16 (addr,data) pairs per OP_DCIM_CFG
    localparam int DCIM_LAYER_BODY_WORDS = 8 + (2 * DCIM_NUM_TILES_L);
    
    state_t state, next_state;
    
    // 内部寄存器
    reg [INST_ADDR_WIDTH-1:0] current_word_idx;  // 当前指令字索引
    reg [31:0] words_remaining;                   // 剩余字数
    reg [3:0]  current_opcode;                    // 当前操作码
    reg [3:0]  current_flags;                     // 当前标志位
    reg [23:0] body_length;                       // 指令体长度（字节）
    reg [31:0] inst_header;                       // 指令头缓存
    
    // 指令体缓存（OP_DCIM_LAYER 最大支持 64 Tile: 8 + 2*64 个 32 位字）
    reg [31:0] body_buffer [0:DCIM_LAYER_BODY_WORDS-1];
    reg [7:0]  body_word_count;
    reg [7:0]  body_word_idx;
    
    // DCIM_CFG 内部寄存器
    reg [23:0] dcim_cfg_total_pairs;
    reg [23:0] dcim_cfg_pair_count;
    reg        dcim_cfg_load;
    reg [31:0] dcim_cfg_body [0:DCIM_CFG_MAX_BODY_WORDS-1];

    // OP_DCIM_LAYER loop state
    reg [31:0] dcim_layer_num_pixels;
    reg [31:0] dcim_layer_pixel_idx;
    reg [31:0] dcim_layer_mode_reg;
    reg [63:0] dcim_layer_tile_mask;
    reg [31:0] dcim_layer_act_base;
    reg [31:0] dcim_layer_act_stride;
    reg [31:0] dcim_layer_out_stride;

    // OP_CDMA_STRIDE internal registers
    reg [31:0] cstride_src_cur;
    reg [31:0] cstride_dst_cur;
    reg [31:0] cstride_copy_bytes;
    reg [31:0] cstride_src_stride;
    reg [31:0] cstride_dst_stride;
    reg [31:0] cstride_count;
    reg [31:0] cstride_idx;
    reg [31:0] dcim_layer_act_current;
    reg [31:0] dcim_layer_out_offset;
    reg [31:0] dcim_layer_wei_base [0:DCIM_NUM_TILES_L-1];
    reg [31:0] dcim_layer_out_base [0:DCIM_NUM_TILES_L-1];
    reg [31:0] dcim_layer_out_current;
    reg [DCIM_TILE_IDX_W-1:0] dcim_layer_tile_idx;
    reg        dcim_layer_seen_busy;
    
    // 流水线寄存器（BRAM已经内部实现3级流水，这里直接使用输出）
    // BRAM内部流水线: addr -> s0 -> s1 -> inst_rd_data (总共4周期延迟)
    wire [31:0] inst_rd_data_pipe = inst_rd_data;
    
    // 启动边沿检测（修复：使用寄存器锁存pulse）
    reg decoder_start_d;
    reg decoder_start_pulse_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decoder_start_d <= 1'b0;
            decoder_start_pulse_reg <= 1'b0;
        end else begin
            decoder_start_d <= decoder_start;
            // 检测上升沿并锁存pulse，直到状态机离开IDLE状态
            if (decoder_start && !decoder_start_d) begin
                decoder_start_pulse_reg <= 1'b1;
            end else if (state != S_IDLE) begin
                decoder_start_pulse_reg <= 1'b0;
            end
        end
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
                if (decoder_start_pulse_reg && inst_count > 0)
                    next_state = S_FETCH_HEADER;
            end
            
            S_FETCH_HEADER: begin
                // 发出读地址，等待 BRAM 流水线延迟 (4周期)
                next_state = S_WAIT_HEADER;
            end
            
            S_WAIT_HEADER: begin
                // BRAM 内部 stage 0: mem[addr]
                next_state = S_WAIT_HEADER_P1;
            end
            
            S_WAIT_HEADER_P1: begin
                // BRAM 内部 stage 1: s0 register
                next_state = S_WAIT_HEADER_P2;
            end
            
            S_WAIT_HEADER_P2: begin
                // BRAM 内部 stage 2: s1 register
                next_state = S_WAIT_HEADER_P3;
            end
            
            S_WAIT_HEADER_P3: begin
                // BRAM 输出 stage: inst_rd_data
                next_state = S_PARSE_HEADER;
            end
            
            S_PARSE_HEADER: begin
                // 使用流水线寄存器数据
                case (inst_rd_data_pipe[31:28])
                    OP_NOP:       next_state = S_EXEC_NOP;
                    OP_CDMA_COPY: next_state = (inst_rd_data_pipe[23:0] > 0) ? S_FETCH_BODY : S_ERROR;
                    OP_VPU_EXEC:  next_state = (inst_rd_data_pipe[23:0] > 0) ? S_FETCH_BODY : S_ERROR;
                    OP_DCIM_EXEC: next_state = S_EXEC_DCIM;
                    OP_DCIM_CFG:  next_state = S_DCIM_CFG_INIT;
                    OP_DCIM_LAYER: next_state = (inst_rd_data_pipe[23:0] == (DCIM_LAYER_BODY_WORDS << 2)) ? S_FETCH_BODY : S_ERROR;
                    OP_CDMA_STRIDE: next_state = (inst_rd_data_pipe[23:0] > 0) ? S_FETCH_BODY : S_ERROR;
                    OP_WAIT_CDMA: next_state = S_EXEC_WAIT_CDMA;
                    OP_WAIT_VPU:  next_state = S_EXEC_WAIT_VPU;
                    OP_WAIT_DCIM: next_state = S_EXEC_WAIT_DCIM;
                    OP_SYNC:      next_state = S_EXEC_SYNC;
                    OP_END:       next_state = S_DONE;
                    default:      next_state = S_ERROR;
                endcase
            end
            
            S_FETCH_BODY: begin
                // 发出读地址，等待 BRAM 流水线延迟 (4周期)
                next_state = S_WAIT_BODY;
            end
            
            S_WAIT_BODY: begin
                // BRAM 内部 stage 0: mem[addr]
                next_state = S_WAIT_BODY_P1;
            end
            
            S_WAIT_BODY_P1: begin
                // BRAM 内部 stage 1: s0 register
                next_state = S_WAIT_BODY_P2;
            end
            
            S_WAIT_BODY_P2: begin
                // BRAM 内部 stage 2: s1 register
                next_state = S_WAIT_BODY_P3;
            end
            
            S_WAIT_BODY_P3: begin
                // BRAM 输出 stage: inst_rd_data
                next_state = S_STORE_BODY;
            end
            
            S_STORE_BODY: begin
                if (body_word_idx >= body_word_count - 1) begin
                    case (current_opcode)
                        OP_CDMA_COPY: next_state = S_EXEC_CDMA;
                        OP_VPU_EXEC:  next_state = S_EXEC_VPU;
                        OP_DCIM_CFG:  next_state = S_DCIM_CFG_APPLY;
                        OP_DCIM_LAYER: next_state = S_DCIM_LAYER_INIT;
                        OP_CDMA_STRIDE: next_state = S_CDMA_STRIDE_INIT;
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
                if (cdma_config_ready && vpu_ready && dcim_ready)
                    next_state = S_NEXT_INST;
            end
            
            S_EXEC_DCIM: begin
                next_state = S_NEXT_INST;
            end
            
            S_WAIT_DCIM_DONE: begin
                if (dcim_ready)
                    next_state = S_NEXT_INST;
            end
            
            S_EXEC_WAIT_DCIM: begin
                if (dcim_ready)
                    next_state = S_NEXT_INST;
            end
            
            // ---- OP_CDMA_STRIDE: loop-driven strided CDMA for Concat ----
            S_CDMA_STRIDE_INIT: begin
                next_state = S_CDMA_STRIDE_ISSUE;
            end

            S_CDMA_STRIDE_ISSUE: begin
                next_state = S_CDMA_STRIDE_WAIT;
            end

            S_CDMA_STRIDE_WAIT: begin
                if (cdma_config_ready)
                    next_state = S_CDMA_STRIDE_NEXT;
            end

            S_CDMA_STRIDE_NEXT: begin
                if (cstride_idx + 1 >= cstride_count)
                    next_state = S_NEXT_INST;
                else
                    next_state = S_CDMA_STRIDE_ISSUE;
            end

            S_DCIM_CFG_INIT: begin
                next_state = S_FETCH_BODY;
            end
            
            S_DCIM_CFG_APPLY: begin
                if (dcim_cfg_pair_count + 1 >= dcim_cfg_total_pairs)
                    next_state = S_NEXT_INST;
                else
                    next_state = S_DCIM_CFG_APPLY;
            end

            S_DCIM_LAYER_INIT: begin
                next_state = S_DCIM_LAYER_CFG_MODE;
            end

            S_DCIM_LAYER_CFG_MODE: begin
                next_state = S_DCIM_LAYER_CFG_TILE;
            end

            S_DCIM_LAYER_CFG_TILE: begin
                next_state = S_DCIM_LAYER_CFG_TILE_HI;
            end

            S_DCIM_LAYER_CFG_TILE_HI: begin
                next_state = S_DCIM_LAYER_CFG_WEI;
            end

            S_DCIM_LAYER_CFG_WEI: begin
                if (dcim_layer_tile_idx >= DCIM_NUM_TILES_L[DCIM_TILE_IDX_W-1:0] - 1'b1)
                    next_state = S_DCIM_LAYER_CFG_ACT;
                else
                    next_state = S_DCIM_LAYER_CFG_WEI;
            end

            S_DCIM_LAYER_CFG_ACT: begin
                next_state = S_DCIM_LAYER_CFG_OUT;
            end

            S_DCIM_LAYER_CFG_OUT: begin
                if (dcim_layer_tile_idx >= DCIM_NUM_TILES_L[DCIM_TILE_IDX_W-1:0] - 1'b1)
                    next_state = S_DCIM_LAYER_START;
                else
                    next_state = S_DCIM_LAYER_CFG_OUT;
            end

            S_DCIM_LAYER_START: begin
                next_state = S_DCIM_LAYER_WAIT;
            end

            S_DCIM_LAYER_WAIT: begin
                if (dcim_layer_seen_busy && dcim_ready)
                    next_state = S_DCIM_LAYER_NEXT;
            end

            S_DCIM_LAYER_NEXT: begin
                if (dcim_layer_pixel_idx + 1 >= dcim_layer_num_pixels)
                    next_state = S_NEXT_INST;
                else
                    next_state = S_DCIM_LAYER_CFG_ACT;
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
            vpu_flags  <= '0;
            dcim_cfg_wr_addr <= '0;
            dcim_cfg_wr_data <= '0;
            
            dcim_cfg_total_pairs <= '0;
            dcim_cfg_pair_count <= '0;
            dcim_cfg_load <= 1'b0;
            
            current_word_idx <= '0;
            words_remaining <= '0;
            current_opcode <= '0;
            current_flags <= '0;
            body_length <= '0;
            inst_header <= '0;
            body_word_count <= '0;
            body_word_idx <= '0;
            
            for (int i = 0; i < DCIM_LAYER_BODY_WORDS; i++)
                body_buffer[i] <= '0;
            for (int i = 0; i < DCIM_NUM_TILES_L; i++) begin
                dcim_layer_wei_base[i] <= '0;
                dcim_layer_out_base[i] <= '0;
            end
            dcim_layer_out_current <= '0;
            dcim_layer_num_pixels <= '0;
            dcim_layer_pixel_idx <= '0;
            dcim_layer_mode_reg <= '0;
            dcim_layer_tile_mask <= '0;
            dcim_layer_act_base <= '0;
            dcim_layer_act_stride <= '0;
            dcim_layer_act_current <= '0;
            cstride_src_cur <= '0;
            cstride_dst_cur <= '0;
            cstride_copy_bytes <= '0;
            cstride_src_stride <= '0;
            cstride_dst_stride <= '0;
            cstride_count <= '0;
            cstride_idx <= '0;
            dcim_layer_out_offset <= '0;
            dcim_layer_out_stride <= '0;
            dcim_layer_tile_idx <= '0;
            dcim_layer_seen_busy <= 1'b0;
                
        end else begin
            // 默认清除脉冲信号
            decoder_done <= 1'b0;
            vpu_start <= 1'b0;
            cdma_start <= 1'b0;
            dcim_cfg_wr_en <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    decoder_busy <= 1'b0;
                    cdma_config_valid <= 1'b0;
                    
                    if (decoder_start_pulse_reg && inst_count > 0) begin
                        decoder_busy <= 1'b1;
                        decoder_status <= STATUS_BUSY;
                        current_word_idx <= '0;
                        words_remaining <= inst_count;
                        body_word_idx <= '0;
                    end
                    // 注意：不在这里清除 decoder_status，以保持 DONE/ERROR 状态
                    // decoder_status 只在启动时被设置为 BUSY，或在 DONE/ERROR 时被设置
                end
                
                S_FETCH_HEADER: begin
                    // 发出读地址
                    inst_rd_addr <= current_word_idx;
                end
                
                S_WAIT_HEADER: begin
                    // 等待 BRAM 内部流水线 stage 0
                end
                
                S_WAIT_HEADER_P1: begin
                    // 等待 BRAM 内部流水线 stage 1
                end
                
                S_WAIT_HEADER_P2: begin
                    // 等待 BRAM 内部流水线 stage 2
                end
                
                S_WAIT_HEADER_P3: begin
                    // 等待 BRAM 输出就绪
                end
                
                S_PARSE_HEADER: begin
                    // 读取数据已就绪（使用流水线寄存器）
                    inst_header <= inst_rd_data_pipe;
                    current_opcode <= inst_rd_data_pipe[31:28];
                    current_flags <= inst_rd_data_pipe[27:24];
                    body_length <= inst_rd_data_pipe[23:0];
                    body_word_count <= (inst_rd_data_pipe[23:0] + 3) >> 2;  // 向上取整到字数
                    body_word_idx <= '0;
                    current_word_idx <= current_word_idx + 1;
                    words_remaining <= words_remaining - 1;
                end
                
                S_FETCH_BODY: begin
                    // 发出读地址
                    inst_rd_addr <= current_word_idx;
                end
                
                S_WAIT_BODY: begin
                    // 等待 BRAM 内部流水线 stage 0
                end
                
                S_WAIT_BODY_P1: begin
                    // 等待 BRAM 内部流水线 stage 1
                end
                
                S_WAIT_BODY_P2: begin
                    // 等待 BRAM 内部流水线 stage 2
                end
                
                S_WAIT_BODY_P3: begin
                    // 等待 BRAM 输出就绪
                end
                
                S_STORE_BODY: begin
                    if (dcim_cfg_load)
                        dcim_cfg_body[body_word_idx] <= inst_rd_data_pipe;
                    else
                        body_buffer[body_word_idx] <= inst_rd_data_pipe;
                    body_word_idx <= body_word_idx + 1;
                    current_word_idx <= current_word_idx + 1;
                    words_remaining <= words_remaining - 1;
                end
                
                S_EXEC_NOP: begin
                    // 空操作，直接进入下一条指令
                end
                
                S_EXEC_CDMA: begin
                    // CDMA_COPY: 12B {src_lsb,dst_lsb,len} or 20B {src_msb,src_lsb,dst_msb,dst_lsb,len}
                    if (body_word_count == 5) begin
                        cdma_src_addr_msb <= body_buffer[0];
                        cdma_src_addr_lsb <= body_buffer[1];
                        cdma_dst_addr_msb <= body_buffer[2];
                        cdma_dst_addr_lsb <= body_buffer[3];
                        cdma_length       <= body_buffer[4];
                    end else begin
                        cdma_src_addr_msb <= 32'h0;
                        cdma_src_addr_lsb <= body_buffer[0];
                        cdma_dst_addr_msb <= 32'h0;
                        cdma_dst_addr_lsb <= body_buffer[1];
                        cdma_length       <= body_buffer[2];
                    end
                    cdma_config_valid <= 1'b1;
                    cdma_start <= 1'b1;  // 保持高电平
                end
                
                S_WAIT_CDMA_CFG: begin
                    // 保持 cdma_start 和 cdma_config_valid 直到 ready
                    cdma_start <= 1'b1;
                    if (cdma_config_ready) begin
                        cdma_config_valid <= 1'b0;
                        cdma_start <= 1'b0;  // 握手完成后清零
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
                    vpu_flags       <= current_flags;
                end
                
                S_WAIT_VPU_START: begin
                    vpu_start <= 1'b1;
`ifdef SIMULATION
                    $display("[%0t] INST_Decoder: VPU_START unit=%0d dst=0x%08h c/h/w=%0d/%0d/%0d state=%0d",
                             $time, vpu_unit_choose, vpu_dst_addr, vpu_src_c, vpu_src_h, vpu_src_w, state);
`endif
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
                    // 等待 CDMA、VPU 和 DCIM 都空闲
                end
                
                S_EXEC_DCIM: begin
                    // DCIM_EXEC: 写 CTRL 寄存器触发启动
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= 12'h000;
                    dcim_cfg_wr_data <= 32'h1;
`ifdef SIMULATION
                    $display("[%0t] DCIM_EXEC start (pixel fired)", $time);
`endif
                end
                
                S_WAIT_DCIM_DONE: begin
                    // 等待 DCIM 完成
`ifdef SIMULATION
                    if (dcim_ready)
                        $display("[%0t] DCIM_WAIT_DONE: dcim_ready asserted → pixel done", $time);
`endif
                end
                
                S_EXEC_WAIT_DCIM: begin
                    // 等待 DCIM 空闲
                end
                
                S_DCIM_CFG_INIT: begin
                    dcim_cfg_load <= 1'b1;
                    dcim_cfg_total_pairs <= body_length[23:0];
                    dcim_cfg_pair_count <= '0;
                    body_word_count <= body_length[23:0] << 1;
                    body_word_idx <= '0;
                end
                
                S_DCIM_CFG_APPLY: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= dcim_cfg_body[dcim_cfg_pair_count * 2][11:0];
                    dcim_cfg_wr_data <= dcim_cfg_body[dcim_cfg_pair_count * 2 + 1];
                    dcim_cfg_pair_count <= dcim_cfg_pair_count + 1;
                    if (dcim_cfg_pair_count + 1 >= dcim_cfg_total_pairs)
                        dcim_cfg_load <= 1'b0;
`ifdef SIMULATION
                    $display("[%0t] DCIM_CFG_WR addr=0x%03h data=0x%08h pair=%0d/%0d",
                             $time, dcim_cfg_body[dcim_cfg_pair_count * 2][11:0],
                             dcim_cfg_body[dcim_cfg_pair_count * 2 + 1],
                             dcim_cfg_pair_count, dcim_cfg_total_pairs);
`endif
                end

                S_DCIM_LAYER_INIT: begin
                    dcim_layer_num_pixels <= body_buffer[0];
                    dcim_layer_mode_reg <= body_buffer[1];
                    dcim_layer_tile_mask <= {body_buffer[3], body_buffer[2]};
                    dcim_layer_act_base <= body_buffer[4];
                    dcim_layer_act_stride <= body_buffer[5];
                    dcim_layer_out_stride <= body_buffer[6];
                    for (int i = 0; i < DCIM_NUM_TILES_L; i++) begin
                        dcim_layer_wei_base[i] <= body_buffer[8 + i];
                        dcim_layer_out_base[i] <= body_buffer[8 + DCIM_NUM_TILES_L + i];
                    end
                    dcim_layer_out_current <= body_buffer[8 + DCIM_NUM_TILES_L];
                    dcim_layer_act_current <= body_buffer[4];
                    dcim_layer_out_offset <= '0;
                    dcim_layer_pixel_idx <= '0;
                    dcim_layer_tile_idx <= '0;
                    dcim_layer_seen_busy <= 1'b0;
                end

                S_DCIM_LAYER_CFG_MODE: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= `DCIM_REG_MODE;
                    dcim_cfg_wr_data <= dcim_layer_mode_reg;
                end

                S_DCIM_LAYER_CFG_TILE: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= `DCIM_REG_TILE_MASK;
                    dcim_cfg_wr_data <= dcim_layer_tile_mask[31:0];
                    dcim_layer_tile_idx <= '0;
                end

                S_DCIM_LAYER_CFG_TILE_HI: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= `DCIM_REG_TILE_MASK_HI;
                    dcim_cfg_wr_data <= dcim_layer_tile_mask[63:32];
                    dcim_layer_tile_idx <= '0;
                end

                S_DCIM_LAYER_CFG_WEI: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= `DCIM_REG_WEI_BASE + {dcim_layer_tile_idx, 2'b00};
                    dcim_cfg_wr_data <= dcim_layer_wei_base[dcim_layer_tile_idx];
                    dcim_layer_tile_idx <= dcim_layer_tile_idx + 1'b1;
                end

                S_DCIM_LAYER_CFG_ACT: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= `DCIM_REG_ACT_BASE;
                    dcim_cfg_wr_data <= dcim_layer_act_current;
                    dcim_layer_tile_idx <= '0;
                    dcim_layer_out_current <= dcim_layer_out_base[0] + dcim_layer_out_offset;
                end

                S_DCIM_LAYER_CFG_OUT: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= `DCIM_REG_OUT_BASE + {dcim_layer_tile_idx, 2'b00};
                    dcim_cfg_wr_data <= dcim_layer_out_current;
                    dcim_layer_tile_idx <= dcim_layer_tile_idx + 1'b1;
                    if (dcim_layer_tile_idx < DCIM_NUM_TILES_L[DCIM_TILE_IDX_W-1:0] - 1'b1)
                        dcim_layer_out_current <= dcim_layer_out_base[dcim_layer_tile_idx + 1'b1] + dcim_layer_out_offset;
                end

                S_DCIM_LAYER_START: begin
                    dcim_cfg_wr_en <= 1'b1;
                    dcim_cfg_wr_addr <= `DCIM_REG_CTRL;
                    dcim_cfg_wr_data <= 32'h1;
                    dcim_layer_seen_busy <= 1'b0;
`ifdef PROBE_DCIM_LAYER
                    $display("[%0t] DCIM_LAYER start pixel=%0d/%0d", $time, dcim_layer_pixel_idx, dcim_layer_num_pixels);
`endif
                end

                S_DCIM_LAYER_WAIT: begin
                    if (!dcim_ready)
                        dcim_layer_seen_busy <= 1'b1;
`ifdef PROBE_DCIM_LAYER
                    if (dcim_layer_seen_busy && dcim_ready)
                        $display("[%0t] DCIM_LAYER pixel done pixel=%0d", $time, dcim_layer_pixel_idx);
`endif
                end

                S_DCIM_LAYER_NEXT: begin
                    dcim_layer_pixel_idx <= dcim_layer_pixel_idx + 1'b1;
                    dcim_layer_act_current <= dcim_layer_act_current + dcim_layer_act_stride;
                    dcim_layer_out_offset <= dcim_layer_out_offset + dcim_layer_out_stride;
                end

                // ---- OP_CDMA_STRIDE sequential logic ----
                S_CDMA_STRIDE_INIT: begin
                    cstride_src_cur    <= body_buffer[0];
                    cstride_dst_cur    <= body_buffer[1];
                    cstride_copy_bytes <= body_buffer[2];
                    cstride_src_stride <= body_buffer[3];
                    cstride_dst_stride <= body_buffer[4];
                    cstride_count      <= body_buffer[5];
                    cstride_idx        <= '0;
                end

                S_CDMA_STRIDE_ISSUE: begin
                    cdma_src_addr_msb <= 32'h0;
                    cdma_src_addr_lsb <= cstride_src_cur;
                    cdma_dst_addr_msb <= 32'h0;
                    cdma_dst_addr_lsb <= cstride_dst_cur;
                    cdma_length       <= cstride_copy_bytes;
                    cdma_config_valid <= 1'b1;
                    cdma_start        <= 1'b1;
                end

                S_CDMA_STRIDE_WAIT: begin
                    cdma_start <= 1'b1;
                    if (cdma_config_ready) begin
                        cdma_config_valid <= 1'b0;
                        cdma_start <= 1'b0;
                    end
                end

                S_CDMA_STRIDE_NEXT: begin
                    cstride_idx     <= cstride_idx + 1'b1;
                    cstride_src_cur <= cstride_src_cur + cstride_src_stride;
                    cstride_dst_cur <= cstride_dst_cur + cstride_dst_stride;
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
