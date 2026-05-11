`timescale 1ns / 1ps

// ============================================================================
// DCIM_Tile - 单个计算 Tile（无内部 OBUF，用于 PE Array）
// ============================================================================
//
// 功能：封装 DCIM 核心，提供 OBUF 写请求接口（而非内部 OBUF）
//       用于 PE Array 中多 Tile 共享 OBUF 的场景
//
// 与 DCIM_Macro 的区别：
//   - 移除内部 OBUF 实例
//   - 暴露 OBUF 写请求接口（req/grant 握手）
//   - 保留内部 IBUF 用于权重和激活读取
//
// ============================================================================

`include "para.v"

module DCIM_Tile #(
    parameter TILE_ID   = 0,          // Tile 编号（用于调试）
    parameter WD1       = 4,          // 权重位宽（nibble）
    parameter CH_IN     = 16,         // 输入通道数
    parameter CH_OUT    = 16,         // 输出通道数
    parameter SRAM_DP   = 128,        // SRAM 深度
    parameter CYCLE     = 8,          // 权重加载周期数
    parameter ACC       = 80,         // 最大累加深度
    
    parameter BUF_ADDR_WIDTH = 12,    // IBUF 地址位宽
    parameter BUF_DATA_WIDTH = 128,   // IBUF 数据位宽
    
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
    input  wire                          start,        // 电平信号，内部做上升沿检测
    output wire                          done,         // 完成信号
    output wire                          ready,        // 就绪信号
    
    // 配置接口（全局配置）
    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [15:0]                   num_rows,
    
    // 地址配置（每个 Tile 独立）
    input  wire [BUF_ADDR_WIDTH-1:0]     wei_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     out_base_addr,
    
    // 共享 IBUF 读接口（连接到共享 IBUF 的端口 B）
    output wire [BUF_ADDR_WIDTH-1:0]     ibuf_rd_addr,
    output wire                          ibuf_rd_en,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_rd_data,
    input  wire                          ibuf_rd_grant,  // 新增：IBUF 读取授权
    
    // OBUF 写请求接口（连接到仲裁器）
    output wire                          obuf_wr_req,
    output wire [BUF_ADDR_WIDTH-1:0]     obuf_wr_addr,
    output wire [BUF_DATA_WIDTH-1:0]     obuf_wr_data,
    output wire [BUF_DATA_WIDTH/8-1:0]   obuf_wr_be,
    input  wire                          obuf_wr_grant
);

    // ========================================================================
    // 状态机定义
    // ========================================================================
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_LOAD_WEI_ADDR,
        ST_LOAD_WEI_WAIT,
        ST_LOAD_WEI,
        ST_PREP_PPCACHE,
        ST_LOAD_PPCACHE,
        ST_SWAP_PPCACHE,
        ST_LOAD_ACT_ADDR,
        ST_LOAD_ACT_WAIT,
        ST_LOAD_ACT,
        ST_LOAD_ACT2_ADDR,
        ST_LOAD_ACT2_WAIT,
        ST_LOAD_ACT2,
        ST_COMPUTE,
        ST_WAIT_RESULT,
        ST_DONE
    } state_t;
    
    state_t state, next_state;
    
    // start 上升沿检测
    reg  start_d;
    wire start_pulse;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_d <= 1'b0;
        else        start_d <= start;
    end
    assign start_pulse = start & ~start_d;
    
    // ========================================================================
    // DCIM 核心接口信号
    // ========================================================================
    wire                     dcim_clr;
    wire                     dcim_ena = 1'b1;
    reg                      dcim_wr_wei;
    reg                      dcim_load_wei;
    reg                      dcim_swap_wei;
    wire                     dcim_ready_wei;
    reg  [ADDR_WD-1:0]       dcim_addr_wei;
    reg  [SRAM_WD-1:0]       dcim_data_wei;
    
    assign dcim_clr = (state == ST_IDLE);
    
    wire                     dcim_valid_out;
    wire                     dcim_ready_out = 1'b1;
    wire [OUT_WIDTH-1:0]     dcim_data_out;
    
    // ========================================================================
    // 激活预处理接口信号
    // ========================================================================
    reg                      conv_valid;
    wire                     conv_ready;
    reg  [CH_IN*16-1:0]      conv_data;
    wire                     dcim_valid_act;
    wire                     dcim_ready_act;
    wire [CH_IN*WD1-1:0]     dcim_data_act;
    
    // ========================================================================
    // IBUF 读接口
    // ========================================================================
    reg  [BUF_ADDR_WIDTH-1:0]    ibuf_addrb;
    reg                          ibuf_enb;
    
    assign ibuf_rd_addr = ibuf_addrb;
    assign ibuf_rd_en   = ibuf_enb;
    
    // ========================================================================
    // 计数器和配置寄存器
    // ========================================================================
    reg [15:0]               row_cnt;
    reg [3:0]                wei_load_cnt;
    reg [3:0]                ppcache_cnt;
    reg [15:0]               result_cnt;
    reg [2:0]                wait_cnt;
    reg [BUF_DATA_WIDTH-1:0] act_buf_lo;
    
    (* max_fanout = 32 *) reg [2:0]                mode_reg;
    reg [ACC_UBD_WD-1:0]     acc_reg;
    reg [15:0]               num_rows_reg;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] act_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] out_base_addr_reg;
    
    wire [15:0] expected_outputs = (acc_reg == 0) ? num_rows_reg : (num_rows_reg / acc_reg);
    
    (* max_fanout = 16 *) reg is_int16_reg;
    wire is_int16 = is_int16_reg;
    
    assign ready = (state == ST_IDLE);
    assign done  = (state == ST_DONE);
    
    // ========================================================================
    // 状态机：状态转换
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_IDLE;
        else state <= next_state;
    end
    
    // 记录是否已获得授权并等待数据
    reg grant_received;
    
    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE:          if (start_pulse) next_state = ST_LOAD_WEI_ADDR;
            ST_LOAD_WEI_ADDR: next_state = ST_LOAD_WEI_WAIT;
            // 等待授权 + 数据延迟
            ST_LOAD_WEI_WAIT: if (grant_received && wait_cnt >= 3) next_state = ST_LOAD_WEI;
            ST_LOAD_WEI: begin
                if (wei_load_cnt >= CYCLE - 1) next_state = ST_PREP_PPCACHE;
                else next_state = ST_LOAD_WEI_ADDR;
            end
            ST_PREP_PPCACHE:  next_state = ST_LOAD_PPCACHE;
            ST_LOAD_PPCACHE:  if (ppcache_cnt >= CYCLE + 2) next_state = ST_SWAP_PPCACHE;
            ST_SWAP_PPCACHE:  next_state = ST_LOAD_ACT_ADDR;
            ST_LOAD_ACT_ADDR: next_state = ST_LOAD_ACT_WAIT;
            ST_LOAD_ACT_WAIT: if (grant_received && wait_cnt >= 3) next_state = ST_LOAD_ACT;
            ST_LOAD_ACT:      next_state = is_int16 ? ST_LOAD_ACT2_ADDR : ST_COMPUTE;
            ST_LOAD_ACT2_ADDR: next_state = ST_LOAD_ACT2_WAIT;
            ST_LOAD_ACT2_WAIT: if (grant_received && wait_cnt >= 3) next_state = ST_LOAD_ACT2;
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
    // 配置寄存器
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
        end else if (state == ST_IDLE && start_pulse) begin
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
            ibuf_addrb <= 0; ibuf_enb <= 0;
            act_buf_lo <= 0;
            grant_received <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    wei_load_cnt <= 0; ppcache_cnt <= 0; row_cnt <= 0; wait_cnt <= 0;
                    dcim_wr_wei <= 0; dcim_load_wei <= 0; dcim_swap_wei <= 0;
                    conv_valid <= 0; ibuf_enb <= 0;
                    grant_received <= 0;
                end
                
                ST_LOAD_WEI_ADDR: begin
                    ibuf_addrb <= wei_base_addr_reg + wei_load_cnt;
                    ibuf_enb <= 1'b1;
                    dcim_wr_wei <= 0;
                    wait_cnt <= 0;
                    grant_received <= 0;
                end
                
                ST_LOAD_WEI_WAIT: begin
                    ibuf_enb <= 1'b1;
                    // 收到授权后开始计数
                    if (ibuf_rd_grant) begin
                        grant_received <= 1'b1;
                    end
                    if (grant_received) begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end
                
                ST_LOAD_WEI: begin
                    dcim_wr_wei <= 1'b1;
                    dcim_addr_wei <= wei_load_cnt;
                    dcim_data_wei <= ibuf_rd_data;
                    if (dcim_ready_wei) wei_load_cnt <= wei_load_cnt + 1;
                end
                
                ST_PREP_PPCACHE: begin
                    dcim_wr_wei <= 0;
                    dcim_addr_wei <= 0;
                    dcim_load_wei <= 0;
                end
                
                ST_LOAD_PPCACHE: begin
                    dcim_wr_wei <= 0;
                    dcim_load_wei <= (ppcache_cnt == 0);
                    ppcache_cnt <= ppcache_cnt + 1;
                end
                
                ST_SWAP_PPCACHE: begin
                    dcim_load_wei <= 0;
                    dcim_swap_wei <= 1'b1;
                end
                
                ST_LOAD_ACT_ADDR: begin
                    dcim_swap_wei <= 0;
                    dcim_load_wei <= 0;
                    ibuf_addrb <= is_int16 ? (act_base_addr_reg + row_cnt * 2) 
                                           : (act_base_addr_reg + row_cnt);
                    ibuf_enb <= 1'b1;
                    conv_valid <= 0;
                    wait_cnt <= 0;
                    grant_received <= 0;
                end
                
                ST_LOAD_ACT_WAIT: begin
                    ibuf_enb <= 1'b1;
                    if (ibuf_rd_grant) begin
                        grant_received <= 1'b1;
                    end
                    if (grant_received) begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end
                
                ST_LOAD_ACT: begin
                    if (is_int16) begin
                        act_buf_lo <= ibuf_rd_data;
                    end else begin
                        for (int ch = 0; ch < CH_IN; ch++) begin
                            conv_data[ch*16 +: 16] <= {{8{ibuf_rd_data[ch*8 + 7]}}, ibuf_rd_data[ch*8 +: 8]};
                        end
                    end
                end
                
                ST_LOAD_ACT2_ADDR: begin
                    ibuf_addrb <= act_base_addr_reg + row_cnt * 2 + 1;
                    ibuf_enb <= 1'b1;
                    wait_cnt <= 0;
                    grant_received <= 0;
                end
                
                ST_LOAD_ACT2_WAIT: begin
                    ibuf_enb <= 1'b1;
                    if (ibuf_rd_grant) begin
                        grant_received <= 1'b1;
                    end
                    if (grant_received) begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end
                
                ST_LOAD_ACT2: begin
                    conv_data <= {ibuf_rd_data, act_buf_lo};
                end
                
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
                    conv_valid <= 0; ibuf_enb <= 0;
                end
            endcase
        end
    end
    
    // ========================================================================
    // 结果保存：OBUF 写请求接口
    // ========================================================================
    
    reg [2:0] save_phase;
    (* keep = "true" *) reg [OUT_WIDTH-1:0] dcim_data_latch;
    (* keep = "true" *) reg signed [WD3-1:0] phys_ch_reg [0:CH_OUT-1];
    (* keep = "true" *) reg [255:0] int8_packed_reg;
    (* keep = "true" *) reg [127:0] int16_packed_reg;
    
    // OBUF 写请求信号
    reg                          obuf_wr_req_reg;
    reg  [BUF_ADDR_WIDTH-1:0]    obuf_wr_addr_reg;
    reg  [BUF_DATA_WIDTH-1:0]    obuf_wr_data_reg;
    reg  [BUF_DATA_WIDTH/8-1:0]  obuf_wr_be_reg;
    
    assign obuf_wr_req  = obuf_wr_req_reg;
    assign obuf_wr_addr = obuf_wr_addr_reg;
    assign obuf_wr_data = obuf_wr_data_reg;
    assign obuf_wr_be   = obuf_wr_be_reg;
    
    // INT8/INT16 结果提取
    wire signed [31:0] int8_result [0:7];
    wire signed [31:0] int16_result [0:3];
    
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
    
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : int16_extract
            localparam PHYS_BASE = gi * 4;
            wire [4*WD3-1:0] int16_full = {phys_ch_reg[PHYS_BASE+3], phys_ch_reg[PHYS_BASE+2], 
                                            phys_ch_reg[PHYS_BASE+1], phys_ch_reg[PHYS_BASE]};
            assign int16_result[gi] = int16_full[31:0];
        end
    endgenerate
    
    wire [255:0] int8_packed_comb = {int8_result[7], int8_result[6], int8_result[5], int8_result[4],
                                      int8_result[3], int8_result[2], int8_result[1], int8_result[0]};
    wire [127:0] int16_packed_comb = {int16_result[3], int16_result[2], int16_result[1], int16_result[0]};
    
    // ========================================================================
    // OBUF 写请求状态机（带仲裁握手）
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_cnt <= 0;
            obuf_wr_req_reg <= 0;
            obuf_wr_addr_reg <= 0;
            obuf_wr_data_reg <= 0;
            obuf_wr_be_reg <= 0;
            save_phase <= 0;
            dcim_data_latch <= 0;
            int8_packed_reg <= 0;
            int16_packed_reg <= 0;
            for (int i = 0; i < CH_OUT; i++) phys_ch_reg[i] <= 0;
        end else begin
            if (state == ST_IDLE) begin
                result_cnt <= 0;
                obuf_wr_req_reg <= 0;
                save_phase <= 0;
            end else begin
                case (save_phase)
                    3'd0: begin
                        // 等待 DCIM 输出
                        obuf_wr_req_reg <= 0;
                        if (dcim_valid_out && dcim_ready_out) begin
                            dcim_data_latch <= dcim_data_out;
                            save_phase <= 3'd1;
                        end
                    end
                    
                    3'd1: begin
                        // 解包物理通道
                        for (int i = 0; i < CH_OUT; i++) begin
                            phys_ch_reg[i] <= dcim_data_latch[i*WD3 +: WD3];
                        end
                        save_phase <= 3'd2;
                    end
                    
                    3'd2: begin
                        // 打包
                        int8_packed_reg <= int8_packed_comb;
                        int16_packed_reg <= int16_packed_comb;
                        save_phase <= 3'd3;
                    end
                    
                    3'd3: begin
                        // 发起写请求（第一块）
                        obuf_wr_req_reg <= 1'b1;
                        obuf_wr_be_reg <= {(BUF_DATA_WIDTH/8){1'b1}};
                        
                        if (is_int16_reg) begin
                            obuf_wr_addr_reg <= out_base_addr_reg + result_cnt;
                            obuf_wr_data_reg <= int16_packed_reg;
                        end else begin
                            obuf_wr_addr_reg <= out_base_addr_reg + result_cnt * 2;
                            obuf_wr_data_reg <= int8_packed_reg[127:0];
                        end
                        
                        // 等待授权
                        if (obuf_wr_grant) begin
                            obuf_wr_req_reg <= 0;
                            if (is_int16_reg) begin
                                save_phase <= 3'd0;
                                result_cnt <= result_cnt + 1;
                            end else begin
                                save_phase <= 3'd4;
                            end
                        end
                    end
                    
                    3'd4: begin
                        // INT8：发起第二块写请求
                        obuf_wr_req_reg <= 1'b1;
                        obuf_wr_addr_reg <= out_base_addr_reg + result_cnt * 2 + 1;
                        obuf_wr_data_reg <= int8_packed_reg[255:128];
                        obuf_wr_be_reg <= {(BUF_DATA_WIDTH/8){1'b1}};
                        
                        if (obuf_wr_grant) begin
                            obuf_wr_req_reg <= 0;
                            save_phase <= 3'd0;
                            result_cnt <= result_cnt + 1;
                        end
                    end
                    
                    default: begin
                        obuf_wr_req_reg <= 0;
                        save_phase <= 3'd0;
                    end
                endcase
            end
        end
    end
    
    // ========================================================================
    // 模块实例化
    // ========================================================================
    
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
    
    act_nibble_converter #(
        .CH_IN(CH_IN), .MODE_INT8(`MODE_INT8), .MODE_INT16(`MODE_INT16)
    ) u_converter (
        .clk(clk), .rst_n(rst_n), .mode(mode_reg),
        .raw_act_valid(conv_valid), .raw_act_ready(conv_ready), .raw_act_data(conv_data),
        .dcim_act_valid(dcim_valid_act), .dcim_act_ready(dcim_ready_act), .dcim_act_data(dcim_data_act)
    );

endmodule
