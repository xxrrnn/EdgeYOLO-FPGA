`timescale 1ns / 1ps

// ============================================================================
// DCIM_Tile - 单个 DCIM 计算 Tile，使用 ready/valid 握手协议访问外部 IBUF/OBUF
// ============================================================================
//
// 接口协议：
//   - IBUF 读：Tile 发出 (rd_valid, rd_addr)，等待 rd_ready 握手，
//              数据通过 (rd_data_valid, rd_data) 返回
//   - OBUF 写：Tile 发出 (wr_valid, wr_addr, wr_data, wr_strb)，等待 wr_ready 握手
//
// ============================================================================

`include "../ref/DCIM/src/inc/para.v"

module DCIM_Tile #(
    parameter WD1     = 4,
    parameter CH_IN   = 16,
    parameter CH_OUT  = 16,
    parameter SRAM_DP = 128,
    parameter CYCLE   = 8,
    parameter ACC     = 80,
    
    parameter BUF_ADDR_WIDTH = 14,
    parameter BUF_DATA_WIDTH = 128,
    
    localparam SRAM_WD     = CH_IN * CH_OUT * WD1 / CYCLE,
    localparam ADDR_WD     = $clog2(SRAM_DP),
    localparam ACC_UBD_WD  = $clog2(ACC+1),
    localparam WD2         = 2*WD1 + $clog2(CH_IN),
    localparam WD3         = WD2 + $clog2(ACC),
    localparam OUT_WIDTH   = CH_OUT * WD3
)(
    input  wire                          clk,
    input  wire                          rst_n,
    
    // 控制接口
    input  wire                          start,
    output wire                          done,
    output wire                          ready,
    
    // 配置接口
    input  wire [2:0]                    mode,
    input  wire [ACC_UBD_WD-1:0]         acc_depth,
    input  wire [31:0]                   num_rows,
    input  wire [BUF_ADDR_WIDTH-1:0]     wei_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     act_base_addr,
    input  wire [BUF_ADDR_WIDTH-1:0]     out_base_addr,
    
    // IBUF 读接口 (ready/valid)
    output reg                           ibuf_rd_valid,
    input  wire                          ibuf_rd_ready,
    output reg  [BUF_ADDR_WIDTH-1:0]     ibuf_rd_addr,
    input  wire                          ibuf_rd_data_valid,
    input  wire [BUF_DATA_WIDTH-1:0]     ibuf_rd_data,
    
    // OBUF 写接口 (ready/valid)
    output reg                           obuf_wr_valid,
    input  wire                          obuf_wr_ready,
    output reg  [BUF_ADDR_WIDTH-1:0]     obuf_wr_addr,
    output reg  [BUF_DATA_WIDTH-1:0]     obuf_wr_data,
    output reg  [BUF_DATA_WIDTH/8-1:0]   obuf_wr_strb
);

    // ========================================================================
    // 状态机定义
    // ========================================================================
    typedef enum logic [3:0] {
        ST_IDLE,
        ST_LOAD_WEI_REQ,    // 发出权重读请求，等待 ready 握手
        ST_LOAD_WEI_RESP,   // 等待 data_valid 返回
        ST_LOAD_WEI_DONE,   // 将数据写入 DCIM SRAM
        ST_PREP_PPCACHE,
        ST_LOAD_PPCACHE,
        ST_SWAP_PPCACHE,
        ST_LOAD_ACT_REQ,    // 发出激活读请求，等待 ready 握手
        ST_LOAD_ACT_RESP,   // 等待 data_valid 返回
        ST_LOAD_ACT2_REQ,   // INT16 第二次读请求
        ST_LOAD_ACT2_RESP,  // INT16 第二次等待返回
        ST_COMPUTE,
        ST_WAIT_RESULT,
        ST_DONE
    } state_t;
    
    state_t state, next_state;
    
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
    // 计数器和配置寄存器
    // ========================================================================
    reg [31:0]               row_cnt;
    reg [3:0]                wei_load_cnt;
    reg [3:0]                ppcache_cnt;
    reg [31:0]               result_cnt;
    reg [BUF_DATA_WIDTH-1:0] act_buf_lo;
    reg [BUF_DATA_WIDTH-1:0] ibuf_data_latch;  // 锁存从IBUF返回的数据
    
    // ========================================================================
    // start 上升沿检测（支持电平输入）
    // ========================================================================
    reg start_d;
    wire start_pulse = start && !start_d;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) start_d <= 0;
        else start_d <= start;
    end
    
    (* max_fanout = 32 *) reg [2:0] mode_reg;
    reg [ACC_UBD_WD-1:0]     acc_reg;
    reg [31:0]               num_rows_reg;
    reg [BUF_ADDR_WIDTH-1:0] wei_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] act_base_addr_reg;
    reg [BUF_ADDR_WIDTH-1:0] out_base_addr_reg;
    
    wire [31:0] expected_outputs = (acc_reg == 0) ? num_rows_reg : (num_rows_reg / acc_reg);
    
    (* max_fanout = 16 *) reg is_int16_reg;
    wire is_int16 = is_int16_reg;
    
    assign ready = (state == ST_IDLE);
    
    // done 信号：置位后保持，直到下次启动时清除
    reg done_reg;
    assign done = done_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) done_reg <= 0;
        else if (state == ST_DONE) done_reg <= 1'b1;
        else if (state == ST_IDLE && start_pulse) done_reg <= 1'b0;
    end
    
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
            ST_IDLE:           if (start_pulse) next_state = ST_LOAD_WEI_REQ;
            ST_LOAD_WEI_REQ:   if (ibuf_rd_valid && ibuf_rd_ready) next_state = ST_LOAD_WEI_RESP;
            ST_LOAD_WEI_RESP:  if (ibuf_rd_data_valid) next_state = ST_LOAD_WEI_DONE;
            ST_LOAD_WEI_DONE: begin
                if (wei_load_cnt >= CYCLE - 1) next_state = ST_PREP_PPCACHE;
                else next_state = ST_LOAD_WEI_REQ;
            end
            ST_PREP_PPCACHE:   next_state = ST_LOAD_PPCACHE;
            ST_LOAD_PPCACHE:   if (ppcache_cnt >= CYCLE + 2) next_state = ST_SWAP_PPCACHE;
            ST_SWAP_PPCACHE:   next_state = ST_LOAD_ACT_REQ;
            ST_LOAD_ACT_REQ:   if (ibuf_rd_valid && ibuf_rd_ready) next_state = ST_LOAD_ACT_RESP;
            ST_LOAD_ACT_RESP:  if (ibuf_rd_data_valid) begin
                if (is_int16) next_state = ST_LOAD_ACT2_REQ;
                else next_state = ST_COMPUTE;
            end
            ST_LOAD_ACT2_REQ:  if (ibuf_rd_valid && ibuf_rd_ready) next_state = ST_LOAD_ACT2_RESP;
            ST_LOAD_ACT2_RESP: if (ibuf_rd_data_valid) next_state = ST_COMPUTE;
            ST_COMPUTE: begin
                if (conv_valid && conv_ready) begin
                    if (row_cnt >= num_rows_reg - 1) next_state = ST_WAIT_RESULT;
                    else next_state = ST_LOAD_ACT_REQ;
                end
            end
            ST_WAIT_RESULT:    if (result_cnt >= expected_outputs) next_state = ST_DONE;
            ST_DONE:           next_state = ST_IDLE;
            default:           next_state = ST_IDLE;
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
            wei_load_cnt <= 0; ppcache_cnt <= 0; row_cnt <= 0;
            dcim_wr_wei <= 0; dcim_load_wei <= 0; dcim_swap_wei <= 0;
            dcim_addr_wei <= 0; dcim_data_wei <= 0;
            conv_valid <= 0; conv_data <= 0;
            ibuf_rd_valid <= 0; ibuf_rd_addr <= 0;
            ibuf_data_latch <= 0;
            act_buf_lo <= 0;
        end else begin
            case (state)
                ST_IDLE: begin
                    wei_load_cnt <= 0; ppcache_cnt <= 0; row_cnt <= 0;
                    dcim_wr_wei <= 0; dcim_load_wei <= 0; dcim_swap_wei <= 0;
                    conv_valid <= 0; ibuf_rd_valid <= 0;
                end
                
                // ==============================================================
                // 权重加载：发出读请求 → 等待数据 → 写入SRAM → 循环
                // ==============================================================
                ST_LOAD_WEI_REQ: begin
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= wei_base_addr_reg + wei_load_cnt;
                    dcim_wr_wei <= 0;
                    if (ibuf_rd_valid && ibuf_rd_ready)
                        ibuf_rd_valid <= 1'b0;
                end
                
                ST_LOAD_WEI_RESP: begin
                    ibuf_rd_valid <= 0;
                    if (ibuf_rd_data_valid)
                        ibuf_data_latch <= ibuf_rd_data;
                end
                
                ST_LOAD_WEI_DONE: begin
                    dcim_wr_wei <= 1'b1;
                    dcim_addr_wei <= wei_load_cnt;
                    dcim_data_wei <= ibuf_data_latch;
                    wei_load_cnt <= wei_load_cnt + 1;
                end
                
                // ==============================================================
                // ppCache 加载阶段
                // ==============================================================
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
                
                // ==============================================================
                // 激活加载：发出读请求 → 等待数据
                // ==============================================================
                ST_LOAD_ACT_REQ: begin
                    dcim_swap_wei <= 0;
                    dcim_load_wei <= 0;
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= is_int16 ? (act_base_addr_reg + row_cnt * 2)
                                             : (act_base_addr_reg + row_cnt);
                    conv_valid <= 0;
                    if (ibuf_rd_valid && ibuf_rd_ready)
                        ibuf_rd_valid <= 1'b0;
                end
                
                ST_LOAD_ACT_RESP: begin
                    ibuf_rd_valid <= 0;
                    if (ibuf_rd_data_valid) begin
                        if (is_int16) begin
                            act_buf_lo <= ibuf_rd_data;
                        end else begin
                            for (int ch = 0; ch < CH_IN; ch++) begin
                                conv_data[ch*16 +: 16] <= {{8{ibuf_rd_data[ch*8 + 7]}}, ibuf_rd_data[ch*8 +: 8]};
                            end
                        end
                    end
                end
                
                // INT16 第二次读取
                ST_LOAD_ACT2_REQ: begin
                    ibuf_rd_valid <= 1'b1;
                    ibuf_rd_addr <= act_base_addr_reg + row_cnt * 2 + 1;
                    if (ibuf_rd_valid && ibuf_rd_ready)
                        ibuf_rd_valid <= 1'b0;
                end
                
                ST_LOAD_ACT2_RESP: begin
                    ibuf_rd_valid <= 0;
                    if (ibuf_rd_data_valid) begin
                        conv_data <= {ibuf_rd_data, act_buf_lo};
                    end
                end
                
                // ==============================================================
                // 计算阶段
                // ==============================================================
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
                    conv_valid <= 0; ibuf_rd_valid <= 0;
                end
            endcase
        end
    end
    
    // ========================================================================
    // 结果保存：OBUF 写入（使用 ready/valid 握手）
    // ========================================================================
    reg [2:0] save_phase;
    (* keep = "true" *) reg [OUT_WIDTH-1:0] dcim_data_latch;
    (* keep = "true" *) reg signed [WD3-1:0] phys_ch_reg [0:CH_OUT-1];
    (* keep = "true" *) reg [255:0] int8_packed_reg;
    (* keep = "true" *) reg [127:0] int16_packed_reg;
    
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
    
    // save_phase:
    //   0: 等待 DCIM 输出
    //   1: 解包物理通道
    //   2: 打包为 INT32
    //   3: 发出第一次 OBUF 写请求，等待 wr_ready
    //   4: (INT8) 发出第二次 OBUF 写请求，等待 wr_ready
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_cnt <= 0;
            obuf_wr_valid <= 0; obuf_wr_addr <= 0; obuf_wr_data <= 0; obuf_wr_strb <= 0;
            save_phase <= 0;
            dcim_data_latch <= 0;
            int8_packed_reg <= 0;
            int16_packed_reg <= 0;
            for (int i = 0; i < CH_OUT; i++) phys_ch_reg[i] <= 0;
        end else begin
            if (state == ST_IDLE) begin
                result_cnt <= 0;
                obuf_wr_valid <= 0;
                save_phase <= 0;
            end else begin
                case (save_phase)
                    3'd0: begin
                        obuf_wr_valid <= 0;
                        if (dcim_valid_out && dcim_ready_out) begin
                            dcim_data_latch <= dcim_data_out;
                            save_phase <= 3'd1;
                        end
                    end
                    
                    3'd1: begin
                        for (int i = 0; i < CH_OUT; i++) begin
                            phys_ch_reg[i] <= dcim_data_latch[i*WD3 +: WD3];
                        end
                        save_phase <= 3'd2;
                    end
                    
                    3'd2: begin
                        int8_packed_reg <= int8_packed_comb;
                        int16_packed_reg <= int16_packed_comb;
                        save_phase <= 3'd3;
                    end
                    
                    3'd3: begin
                        obuf_wr_valid <= 1'b1;
                        obuf_wr_strb <= {(BUF_DATA_WIDTH/8){1'b1}};
                        
                        if (is_int16_reg) begin
                            obuf_wr_addr <= out_base_addr_reg + result_cnt;
                            obuf_wr_data <= int16_packed_reg;
                            if (obuf_wr_valid && obuf_wr_ready) begin
                                obuf_wr_valid <= 0;
                                save_phase <= 3'd0;
                                result_cnt <= result_cnt + 1;
                            end
                        end else begin
                            obuf_wr_addr <= out_base_addr_reg + result_cnt * 2;
                            obuf_wr_data <= int8_packed_reg[127:0];
                            if (obuf_wr_valid && obuf_wr_ready) begin
                                obuf_wr_valid <= 0;
                                save_phase <= 3'd4;
                            end
                        end
                    end
                    
                    3'd4: begin
                        obuf_wr_valid <= 1'b1;
                        obuf_wr_strb <= {(BUF_DATA_WIDTH/8){1'b1}};
                        obuf_wr_addr <= out_base_addr_reg + result_cnt * 2 + 1;
                        obuf_wr_data <= int8_packed_reg[255:128];
                        if (obuf_wr_valid && obuf_wr_ready) begin
                            obuf_wr_valid <= 0;
                            save_phase <= 3'd0;
                            result_cnt <= result_cnt + 1;
                        end
                    end
                    
                    default: begin
                        obuf_wr_valid <= 0;
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
