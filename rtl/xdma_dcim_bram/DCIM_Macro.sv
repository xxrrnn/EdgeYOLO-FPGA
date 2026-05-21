`timescale 1ns / 1ps
`include "dcim_defs.vh"

// ============================================================================
// DCIM_Macro — 面向片上 BRAM（IBUF/OBUF）的一块矩阵乘 tile 控制器
// ============================================================================
//
// 【做什么】
//   从 IBUF 读出权重块与激活行，经 xdma_dcim_preprocess 转成阵列所需的 WD1=4 比特流，
//   送入 rtl/DCIM 里的 calculate_core（乘加阵列）和 postProcess（merge + 累加），
//   结果累加到本地 psum 寄存器；仅当 save_to_obuf 配置为 1 时才写入 OBUF 并清零 psum。
//
// 【信号约定】
//   所有输入信号均为**电平信号**：
//   - dcim_start：内部做上升沿检测，0→1 跳变触发一次计算
//   - dcim_config_valid/ready：电平握手，valid && ready 时锁存配置
//   - save_to_obuf：电平配置，决定本次计算完成后是否写 OBUF
//   输出信号：
//   - dcim_done：电平，完成后保持高直到下次 start 上升沿
//   - dcim_busy：电平，计算进行中为高
//
// 【psum 累加机制】
//   大部分负载的内积维度远大于 16（CH_IN），需要多次 tile 计算后累加。
//   - 默认（save_to_obuf=0）：postProcess 输出累加到本地 psum 寄存器（int32 × CH_OUT）
//   - 最后一次（save_to_obuf=1）：psum + 当前结果 写入 OBUF，然后清零 psum
//   psum_out 端口可供外部读取当前累加值。
//
// 【为何要多拍激活】
//   阵列底层 PE 按 WD1=4（半字节）并行计算。INT8 每个通道 8bit → 高/低两个半字节，故每行激活 2 拍；
//   INT16 每个通道 16bit → 四个半字节，故每行激活 4 拍（与 maArray 内计数器 ubd 一致）。
//   权重侧 INT16 在 BRAM 里已展开成四个 CH_OUT 方向的半字节槽位；激活侧由相位递变换半字节。
//
// 【数据路径】
//   raw_weight_reg（BRAM 原始字拼接）→ preprocess → preprocessed_weight ──┐
//   raw_act_word_reg（当前 256bit 激活字）→ preprocess → dcim_act_data ──┼→ calculate_core
//                                                                          └→ postProcess → dcim_res_data
//                                                                                              ↓
//                                                                          psum_reg ←──(累加)──┘
//                                                                              ↓ (save_to_obuf=1)
//                                                                          写 OBUF，清零 psum
//
// 【背压】
//   postProcess 下游 dn_ready 由 dcim_res_ready 组合产生：仅在「本 tile 仍在消费激活 / 排空」且
//   还有待写出的结果行时拉高，避免流水线在无 OBUF 空间时堆积。
//
// 【校验 ST_VALIDATE】
//   只做定点对齐（32 字节边界）、模式（INT8/INT16）、非零行数、acc 与 raw_rows 的可整除关系，
//   以及权重/激活/输出三段地址窗口是否落在 BRAM 深度内；输出行列数用移位代替除法以满足时序。
//
// 【BRAM 布局（主机侧约定）】
//   * 权重 wsrc_base_addr：固定读 4×256bit = 1024bit = DCIM_TILE_WIDTH。
//     INT8：按 CH_IN × (CH_OUT/2) 字节配对；INT16：按 CH_IN × (CH_OUT/4) 个 int16，每个 int16
//     在阵列入口展开到四个相邻 CH_OUT 半字节（与 rtl/DCIM/tb/dcim_tb.sv 一致）。
//   * 激活 asrc_base_addr：
//     INT8：两行 int8 拼在一个 256bit 字内 [127:0]、[255:128]；行索引用 rows_sent[0] 选半幅。
//     INT16：一行 = CH_IN×16bit = 256bit，一字一行；字地址 = rows_sent（不再「两行一字」）。
//   * 输出 dst_addr：psum + dcim_res 写入 256bit obuf 字（仅 save_to_obuf=1 时）。
//
// 【时序设计注意】
//   地址与校验路径避免可变除法/取模；acc 仅允许 2 的幂，输出行数与对齐用移位与掩码检查。
// ============================================================================

module DCIM_Macro (
    // ========== 时钟与复位 ==========
    input  logic                         clk,      // 全局时钟
    input  logic                         rst_n,    // 异步低电平复位

    // ========== 控制信号（均为电平信号，start 内部做上升沿检测）==========
    input  logic                         dcim_start,        // [电平输入] 计算启动信号，内部检测 0→1 跳变触发一次计算
    input  logic                         dcim_config_valid, // [电平输入] 配置有效，与 config_ready 握手锁存配置参数
    output logic                         dcim_config_ready, // [电平输出] 配置就绪，在 IDLE/DONE/ERROR 状态时为高
    output logic                         dcim_busy,         // [电平输出] 计算忙，处于工作状态时为高
    output logic                         dcim_done,         // [电平输出] 计算完成，保持高直到下次 start 上升沿
    output logic                         dcim_error,        // [电平输出] 错误标志，校验失败时为高
    output logic [31:0]                  dcim_error_code,   // 错误码（见下方说明）
                                                            // 0x0001: mode 非 INT8/INT16
                                                            // 0x0002: raw_rows = 0
                                                            // 0x0003: 地址未 32 字节对齐
                                                            // 0x0004: raw_rows 与 acc 不可整除（非 2 的幂对齐）
                                                            // 0x0005: acc 非法（非 0,1,2,4,8,16）
                                                            // 0x0006: 地址窗口超出 IBUF/OBUF 深度

    // ========== 配置参数（config_valid && config_ready 时锁存）==========
    // --- 地址参数（片内字节地址，必须 32 字节对齐，即低 5 位必须为 0）---
    input  logic [`DCIM_ADDR_WIDTH-1:0]        wsrc_base_addr,  // 权重块起始地址（IBUF 内，固定占 4×256bit = 128 字节）
    input  logic [`DCIM_ADDR_WIDTH-1:0]        asrc_base_addr,  // 激活行起始地址（IBUF 内，INT8: 两行/字，INT16: 一行/字）
    input  logic [`DCIM_ADDR_WIDTH-1:0]        dst_addr,        // 输出起始地址（OBUF 内，每行 256bit，仅 save_to_obuf=1 时使用）

    // --- 计算参数 ---
    input  logic [31:0]                  raw_rows,       // 激活逻辑行数（INT8: int8 行数；INT16: int16 行数）
                                                         // 决定读取多少行激活（INT8 每行 16 字节，INT16 每行 32 字节）
    input  logic [2:0]                   mode,           // 计算模式（仅支持 DCIM_MODE_INT8=3'b110 / DCIM_MODE_INT16=3'b111）
    input  logic [4:0]                   acc,            // K 维折叠累加深度（仅允许 0,1,2,4,8,16）
                                                         // 0/1: 输出行数 = raw_rows（不折叠或单次累加）
                                                         // 2/4/8/16: 输出行数 = raw_rows >> log2(acc)，要求 raw_rows 对齐
    input  logic                         save_to_obuf,   // [电平配置] 本次计算完成后是否写 OBUF
                                                         // 0: 仅累加到本地 psum 寄存器（用于跨 tile 累加大内积维度）
                                                         // 1: psum + 当前结果 写入 OBUF，然后清零 psum

    // ========== IBUF 读口 B（本宏只读，用于读权重与激活）==========
    output logic                         ibuf_enb,       // IBUF 使能（读取权重/激活时拉高一拍）
    output logic [`DCIM_IBUF_ADDR_WIDTH-1:0]   ibuf_addrb,    // IBUF 字地址（256bit 字边界，BRAM 字地址）
    input  logic [`DCIM_BRAM_DATA_WIDTH-1:0]   ibuf_doutb,    // IBUF 读出数据（256bit）

    // ========== OBUF 写口 B（本宏只写，用于写结果行）==========
    output logic                         obuf_enb,       // OBUF 使能（写结果时拉高一拍，仅 save_to_obuf=1 时有效）
    output logic [`DCIM_BRAM_BYTES-1:0]        obuf_web,      // OBUF 字节写使能（全 1 表示写整字）
    output logic [`DCIM_OBUF_ADDR_WIDTH-1:0]   obuf_addrb,    // OBUF 字地址（256bit 字边界）
    output logic [`DCIM_BRAM_DATA_WIDTH-1:0]   obuf_dinb,     // OBUF 写入数据（CH_OUT × 32bit int32，高位补零到 256bit）

    // ========== psum 寄存器输出（可选，供外部读取当前累加值）==========
    output logic [`DCIM_CH_OUT*32-1:0]         psum_out       // 16 个 int32 通道的累加值（512 bit）
                                                               // 每次 save_to_obuf=0 时累加，save_to_obuf=1 时清零
);
    localparam logic [2:0] MODE_INT8  = `DCIM_MODE_INT8;
    localparam logic [2:0] MODE_INT16 = `DCIM_MODE_INT16;
    localparam int BRAM_BYTES        = `DCIM_BRAM_BYTES;
    localparam int BRAM_ADDR_SHIFT   = $clog2(BRAM_BYTES);
    localparam int WD2               = `DCIM_WD2;
    localparam int WD3               = `DCIM_WD3;
    localparam int DCIM_ACT_WIDTH    = `DCIM_ACT_WIDTH;
    localparam int DCIM_TILE_WIDTH   = `DCIM_TILE_WIDTH;
    localparam int DCIM_RES_WIDTH    = `DCIM_RES_WIDTH;
    localparam logic [32:0] IBUF_DEPTH_WORDS = (33'd1 << `DCIM_IBUF_ADDR_WIDTH);
    localparam logic [32:0] OBUF_DEPTH_WORDS = (33'd1 << `DCIM_OBUF_ADDR_WIDTH);
    localparam int PSUM_WIDTH = 32;  // 本地累加寄存器每通道位宽（int32）

    // --- dcim_start 上升沿检测 ---
    // 所有输入信号均为电平，start 需检测 0→1 跳变才触发一次计算
    logic dcim_start_d;
    wire  dcim_start_posedge = dcim_start && !dcim_start_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            dcim_start_d <= 1'b0;
        else
            dcim_start_d <= dcim_start;
    end

    initial begin
        if (`DCIM_BRAM_DATA_WIDTH != 256) begin
            $fatal(1, "DCIM_Macro currently expects 256-bit ibuf/obuf words");
        end
        if (`DCIM_CH_IN != 16 || `DCIM_WD1 != 4) begin
            $fatal(1, "DCIM_Macro packing expects WD1=4, CH_IN=16");
        end
        // 注释掉这个检查，因为现在支持CH_OUT=64，使用多拍写入
        // if (DCIM_RES_WIDTH > `DCIM_BRAM_DATA_WIDTH) begin
        //     $fatal(1, "DCIM result row width (%0d) exceeds BRAM word width (%0d)",
        //            DCIM_RES_WIDTH, `DCIM_BRAM_DATA_WIDTH);
        // end
    end

    // --- 主状态机（单事务：VALIDATE → 读 4 字权重 → 逐行读激活并多拍握手 → DRAIN 等结果写完）---
    typedef enum logic [4:0] {
        ST_IDLE,
        ST_VALIDATE,
        ST_LOAD_W_REQ,    // 发起读权重 BRAM
        ST_LOAD_W_WAIT0,  // IBUF 读延迟对齐（流水线按拍取样 dout）
        ST_LOAD_W_WAIT1,  // 锁存当前字到 raw_weight_reg
        ST_PREP_W,        // 占位节拍（权重已寄存，preprocess 组合即可）
        ST_CLEAR,         // 脉冲 clr，清空阵列内部累加/流水线寄存
        ST_ACT_NEXT,      // 是否还有未发送的激活行
        ST_ACT_REQ,
        ST_ACT_WAIT0,
        ST_ACT_WAIT1,     // raw_act_word_reg 更新完毕
        ST_ACT_LAUNCH,    // act_phase_reg<=0，拉高 calculate_core 侧 valid
        ST_ACT_PIPE,      // 与 up_ready 握手，INT8 共 2 次 fire，INT16 共 4 次 fire
        ST_DRAIN,         // 不再送激活，仅消费 postProcess 直到输出行数凑齐
        ST_DONE,
        ST_ERROR
    } state_t;

    (* fsm_encoding = "auto" *) state_t state;

    logic [`DCIM_ADDR_WIDTH-1:0] wsrc_base_addr_reg;
    logic [`DCIM_ADDR_WIDTH-1:0] asrc_base_addr_reg;
    logic [`DCIM_ADDR_WIDTH-1:0] dst_addr_reg;
    logic [31:0]           raw_rows_reg;
    logic [2:0]            mode_reg;
    logic [4:0]            acc_reg;
    logic                  save_to_obuf_reg;  // 锁存的 save_to_obuf 配置

    // --- 本地 psum 寄存器：CH_OUT 个 int32 通道，用于跨多次 tile 累加 ---
    // 当 save_to_obuf_reg==0 时，postProcess 输出累加到 psum 而不写 OBUF；
    // 当 save_to_obuf_reg==1 时，psum + dcim_res 写入 OBUF，然后清零 psum。
    logic [PSUM_WIDTH*`DCIM_CH_OUT-1:0] psum_reg;
    assign psum_out = psum_reg;

    localparam int WEIGHT_WORDS = DCIM_TILE_WIDTH / `DCIM_BRAM_DATA_WIDTH;  // CH_OUT=64 时为 16
    localparam int WEIGHT_IDX_WIDTH = $clog2(WEIGHT_WORDS);
    localparam int PSUM_TOTAL_WIDTH = PSUM_WIDTH * `DCIM_CH_OUT;  // 64×32=2048 bit
    localparam int OBUF_WORDS_PER_ROW = (PSUM_TOTAL_WIDTH + `DCIM_BRAM_DATA_WIDTH - 1) / `DCIM_BRAM_DATA_WIDTH;  // 8
    localparam int OBUF_WORD_IDX_WIDTH = $clog2(OBUF_WORDS_PER_ROW);

    logic [31:0] expected_out_rows_reg;
    logic [31:0] rows_sent_reg;
    logic [31:0] rows_out_reg;
    logic [WEIGHT_IDX_WIDTH-1:0]  w_word_idx;   // 权重字索引，CH_OUT=64 时为 0..15
    logic        act_row_sel;    // INT8：当前逻辑行对应 ibuf 字中的低/高 128bit（rows_sent[0]）
    logic [1:0]  act_phase_reg;  // 当前激活半字节相位：INT8 用 0..1，INT16 用 0..3
    logic [OBUF_WORD_IDX_WIDTH-1:0] obuf_word_idx;  // 输出字索引，CH_OUT=64 时为 0..7
    logic        obuf_writing;   // 正在多拍写 OBUF
    logic [`DCIM_BRAM_DATA_WIDTH-1:0] raw_act_word_reg;
    logic [DCIM_TILE_WIDTH-1:0] raw_weight_reg;

    logic validate_error;
    logic [31:0] validate_error_code;
    logic [31:0] validate_out_rows;
    logic [32:0] validate_w_word_base;
    logic [32:0] validate_a_word_base;
    logic [32:0] validate_dst_word_base;
    logic [32:0] validate_act_words;
    logic [32:0] validate_weight_end_words;
    logic [32:0] validate_act_end_words;
    logic [32:0] validate_out_end_words;

    // acc：沿 K 维折叠时的累加深度（仅 0,1,2,4,8,16）。0/1 表示行数不变；更大则输出行为 raw_rows 右移，
    // 且要求 raw_rows 低若干位为 0（否则报错），避免 RTL 里做 rows%acc。
    always_comb begin
        validate_error      = 1'b0;
        validate_error_code = 32'd0;
        validate_out_rows   = 32'd0;
        validate_w_word_base = ({1'b0, wsrc_base_addr_reg} >> BRAM_ADDR_SHIFT);
        validate_a_word_base = ({1'b0, asrc_base_addr_reg} >> BRAM_ADDR_SHIFT);
        validate_dst_word_base = ({1'b0, dst_addr_reg} >> BRAM_ADDR_SHIFT);
        validate_act_words = (mode_reg == MODE_INT16) ? {1'b0, raw_rows_reg}
                                                      : (({1'b0, raw_rows_reg} + 33'd1) >> 1);
        validate_weight_end_words = validate_w_word_base + WEIGHT_WORDS;
        validate_act_end_words = validate_a_word_base + validate_act_words;
        validate_out_end_words = validate_dst_word_base;

        if (mode_reg != MODE_INT8 && mode_reg != MODE_INT16) begin
            validate_error      = 1'b1;
            validate_error_code = 32'h0000_0001;
        end else if (raw_rows_reg == 32'd0) begin
            validate_error      = 1'b1;
            validate_error_code = 32'h0000_0002;
        end else if (|wsrc_base_addr_reg[BRAM_ADDR_SHIFT-1:0] ||
                     |asrc_base_addr_reg[BRAM_ADDR_SHIFT-1:0] ||
                     |dst_addr_reg[BRAM_ADDR_SHIFT-1:0]) begin
            validate_error      = 1'b1;
            validate_error_code = 32'h0000_0003;
        end else begin
            unique case (acc_reg)
                5'd0, 5'd1: begin
                    validate_out_rows = raw_rows_reg;
                end
                5'd2: begin
                    validate_out_rows = raw_rows_reg >> 1;
                    if (raw_rows_reg[0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                5'd4: begin
                    validate_out_rows = raw_rows_reg >> 2;
                    if (|raw_rows_reg[1:0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                5'd8: begin
                    validate_out_rows = raw_rows_reg >> 3;
                    if (|raw_rows_reg[2:0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                5'd16: begin
                    validate_out_rows = raw_rows_reg >> 4;
                    if (|raw_rows_reg[3:0]) begin
                        validate_error      = 1'b1;
                        validate_error_code = 32'h0000_0004;
                    end
                end
                default: begin
                    validate_error      = 1'b1;
                    validate_error_code = 32'h0000_0005;
                end
            endcase

            validate_out_end_words = validate_dst_word_base +
                         ({1'b0, validate_out_rows} * 33'(OBUF_WORDS_PER_ROW));
            if (!validate_error &&
                ((validate_weight_end_words > IBUF_DEPTH_WORDS) ||
                 (validate_act_end_words > IBUF_DEPTH_WORDS) ||
                 (validate_out_end_words > OBUF_DEPTH_WORDS))) begin
                validate_error      = 1'b1;
                validate_error_code = 32'h0000_0006;
            end
        end
    end

    // preprocess：同一拍内根据 mode / act_phase 产生阵列入口宽度；权重 INT16 拍间不变，INT8 亦不变
    logic [DCIM_TILE_WIDTH-1:0] preprocessed_weight;
    logic [DCIM_ACT_WIDTH-1:0]   preprocessed_act;

    xdma_dcim_preprocess #(
        .CH_IN(`DCIM_CH_IN),
        .CH_OUT(`DCIM_CH_OUT),
        .RAW_ACT_WORD_WIDTH(`DCIM_BRAM_DATA_WIDTH),
        .RAW_WEIGHT_WIDTH(DCIM_TILE_WIDTH),
        .DCIM_ACT_WIDTH(DCIM_ACT_WIDTH),
        .DCIM_WEIGHT_WIDTH(DCIM_TILE_WIDTH)
    ) u_preprocess (
        .mode_i(mode_reg),
        .nibble_phase_i(act_phase_reg),
        .raw_weight_i(raw_weight_reg),
        .dcim_weight_o(preprocessed_weight),
        .raw_act_word_i(raw_act_word_reg),
        .raw_act_row_sel_i(act_row_sel),
        .dcim_act_o(preprocessed_act)
    );

    wire [DCIM_ACT_WIDTH-1:0] dcim_act_data;
    assign dcim_act_data = preprocessed_act; // 组合跟随 raw_act_word_reg 与 act_phase_reg

    logic dcim_clr;
    logic dcim_act_valid;
    logic dcim_act_ready;
    logic dcim_mid_valid;
    logic dcim_mid_ready;
    logic [`DCIM_CH_OUT*WD2-1:0] dcim_mid_data;
    logic dcim_res_valid;
    logic dcim_res_ready;
    logic [DCIM_RES_WIDTH-1:0] dcim_res_data;

    calculate_core #(
        .WD1(`DCIM_WD1),
        .CH_IN(`DCIM_CH_IN),
        .CH_OUT(`DCIM_CH_OUT)
    ) u_calculate_core (
        .clk(clk),
        .rstn(rst_n),
        .clr(dcim_clr),
        .ena(1'b1),
        .mode(mode_reg),
        .up_valid(dcim_act_valid),
        .up_ready(dcim_act_ready),
        .dn_valid(dcim_mid_valid),
        .dn_ready(dcim_mid_ready),
        .up_data1(dcim_act_data),
        .up_data2(preprocessed_weight),
        .dn_data(dcim_mid_data)
    );

    postProcess #(
        .WD1(`DCIM_WD1),
        .CH_IN(`DCIM_CH_IN),
        .CH_OUT(`DCIM_CH_OUT),
        .ACC(`DCIM_ACC_MAX)
    ) u_post_process (
        .clk(clk),
        .rstn(rst_n),
        .clr(dcim_clr),
        .ena(1'b1),
        .mode(mode_reg),
        .acc(acc_reg),
        .up_valid(dcim_mid_valid),
        .up_ready(dcim_mid_ready),
        .dn_valid(dcim_res_valid),
        .dn_ready(dcim_res_ready),
        .up_data(dcim_mid_data),
        .dn_data(dcim_res_data)
    );

    assign dcim_busy = (state != ST_IDLE) && (state != ST_DONE) && (state != ST_ERROR);
    assign dcim_config_ready = (state == ST_IDLE) || (state == ST_DONE) || (state == ST_ERROR);
    assign dcim_error = (state == ST_ERROR);
    // 在送激活与排空阶段允许 postProcess 向下游吐结果；LAUNCH 拍需 ready，否则首拍会堵死流水线
    // 多拍写 OBUF 时暂停接收新结果
    assign dcim_res_ready = ((state == ST_ACT_NEXT) ||
                             (state == ST_ACT_PIPE) ||
                             (state == ST_ACT_LAUNCH) ||
                             (state == ST_DRAIN)) &&
                            (rows_out_reg < expected_out_rows_reg) &&
                            !obuf_writing;

    wire dcim_act_fire = dcim_act_valid && dcim_act_ready;
    wire dcim_res_fire = dcim_res_valid && dcim_res_ready;

    wire [`DCIM_IBUF_ADDR_WIDTH-1:0] wsrc_word_addr =
        wsrc_base_addr_reg[BRAM_ADDR_SHIFT +: `DCIM_IBUF_ADDR_WIDTH];
    wire [`DCIM_IBUF_ADDR_WIDTH-1:0] asrc_word_addr =
        asrc_base_addr_reg[BRAM_ADDR_SHIFT +: `DCIM_IBUF_ADDR_WIDTH];
    wire [`DCIM_OBUF_ADDR_WIDTH-1:0] dst_word_addr =
        dst_addr_reg[BRAM_ADDR_SHIFT +: `DCIM_OBUF_ADDR_WIDTH];

    // --- psum 累加组合逻辑：计算 psum + dcim_res 各通道的和 ---
    wire [PSUM_WIDTH*`DCIM_CH_OUT-1:0] psum_plus_res;
    generate
        for (genvar ch = 0; ch < `DCIM_CH_OUT; ch++) begin : GenPsumAdd
            wire signed [WD3-1:0] res_ch = dcim_res_data[ch*WD3 +: WD3];
            wire signed [PSUM_WIDTH-1:0] psum_ch = psum_reg[ch*PSUM_WIDTH +: PSUM_WIDTH];
            wire signed [PSUM_WIDTH-1:0] sum_ch = psum_ch + PSUM_WIDTH'(res_ch);
            assign psum_plus_res[ch*PSUM_WIDTH +: PSUM_WIDTH] = sum_ch;
        end
    endgenerate

    // --- 主 FSM：LOAD_W 固定 4 字；ACT 段 INT8 字偏移为 rows_sent>>1，INT16 为 rows_sent ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            dcim_done <= 1'b0;
            dcim_error_code <= 32'd0;
            wsrc_base_addr_reg <= '0;
            asrc_base_addr_reg <= '0;
            dst_addr_reg <= '0;
            raw_rows_reg <= 32'd0;
            mode_reg <= MODE_INT8;
            acc_reg <= 5'd0;
            save_to_obuf_reg <= 1'b0;
            psum_reg <= '0;
            expected_out_rows_reg <= 32'd0;
            rows_sent_reg <= 32'd0;
            rows_out_reg <= 32'd0;
            w_word_idx <= '0;
            act_row_sel <= 1'b0;
            raw_act_word_reg <= '0;
            raw_weight_reg <= '0;
            dcim_clr <= 1'b0;
            dcim_act_valid <= 1'b0;
            act_phase_reg <= 2'd0;
            obuf_word_idx <= '0;
            obuf_writing <= 1'b0;
            ibuf_enb <= 1'b0;
            ibuf_addrb <= '0;
            obuf_enb <= 1'b0;
            obuf_web <= '0;
            obuf_addrb <= '0;
            obuf_dinb <= '0;
        end else begin
            ibuf_enb <= 1'b0;
            obuf_enb <= 1'b0;
            obuf_web <= '0;
            obuf_dinb <= '0;
            dcim_clr <= 1'b0;

            // --- 多拍写 OBUF 逻辑（CH_OUT=64 时每行需要 8 个 256bit 字）---
            if (obuf_writing) begin
                obuf_enb <= 1'b1;
                obuf_web <= {BRAM_BYTES{1'b1}};
                obuf_addrb <= dst_word_addr + 
                              rows_out_reg[`DCIM_OBUF_ADDR_WIDTH-1:0] * OBUF_WORDS_PER_ROW +
                              {{(`DCIM_OBUF_ADDR_WIDTH-OBUF_WORD_IDX_WIDTH){1'b0}}, obuf_word_idx};
                obuf_dinb <= psum_reg[obuf_word_idx * `DCIM_BRAM_DATA_WIDTH +: `DCIM_BRAM_DATA_WIDTH];
                
                if (obuf_word_idx == OBUF_WORDS_PER_ROW - 1) begin
                    obuf_writing <= 1'b0;
                    obuf_word_idx <= '0;
                    psum_reg <= '0;  // 写完后清零 psum
                    rows_out_reg <= rows_out_reg + 1'b1;
                end else begin
                    obuf_word_idx <= obuf_word_idx + 1'b1;
                end
            end

            // --- postProcess 出一行结果时的处理逻辑 ---
            // 默认：累加到本地 psum 寄存器（用于跨多个 tile 的内积维度累加）
            // 若 save_to_obuf_reg==1：启动多拍写 OBUF 流程
            if (dcim_res_fire && !obuf_writing) begin
                psum_reg <= psum_plus_res;  // 先累加
                if (save_to_obuf_reg) begin
                    // 启动多拍写 OBUF
                    obuf_writing <= 1'b1;
                    obuf_word_idx <= '0;
                end else begin
                    // 仅累加，不写 OBUF，直接计数
                    rows_out_reg <= rows_out_reg + 1'b1;
                end
            end

            case (state)
                ST_IDLE: begin
                    dcim_done <= 1'b0;
                    dcim_act_valid <= 1'b0;
                    if (dcim_config_valid && dcim_config_ready) begin
                        wsrc_base_addr_reg <= wsrc_base_addr;
                        asrc_base_addr_reg <= asrc_base_addr;
                        dst_addr_reg <= dst_addr;
                        raw_rows_reg <= raw_rows;
                        mode_reg <= mode;
                        acc_reg <= acc;
                        save_to_obuf_reg <= save_to_obuf;
                    end
                    if (dcim_start_posedge) begin
                        dcim_error_code <= 32'd0;
                        rows_sent_reg <= 32'd0;
                        rows_out_reg <= 32'd0;
                        w_word_idx <= '0;
                        dcim_clr <= 1'b1;
                        state <= ST_VALIDATE;
                    end
                end

                ST_VALIDATE: begin
                    if (validate_error) begin
                        dcim_error_code <= validate_error_code;
                        state <= ST_ERROR;
                    end else begin
                        expected_out_rows_reg <= validate_out_rows;
                        state <= ST_LOAD_W_REQ;
                    end
                end

                ST_LOAD_W_REQ: begin
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= wsrc_word_addr + {{(`DCIM_IBUF_ADDR_WIDTH-WEIGHT_IDX_WIDTH){1'b0}}, w_word_idx};
                    state <= ST_LOAD_W_WAIT0;
                end

                ST_LOAD_W_WAIT0: begin
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= wsrc_word_addr + {{(`DCIM_IBUF_ADDR_WIDTH-WEIGHT_IDX_WIDTH){1'b0}}, w_word_idx};
                    state <= ST_LOAD_W_WAIT1;
                end

                ST_LOAD_W_WAIT1: begin
                    raw_weight_reg[w_word_idx*`DCIM_BRAM_DATA_WIDTH +: `DCIM_BRAM_DATA_WIDTH] <= ibuf_doutb;
                    if (w_word_idx == WEIGHT_WORDS - 1) begin
                        state <= ST_PREP_W;
                    end else begin
                        w_word_idx <= w_word_idx + 1'b1;
                        state <= ST_LOAD_W_REQ;
                    end
                end

                ST_PREP_W: begin
                    state <= ST_CLEAR;
                end

                ST_CLEAR: begin
                    dcim_clr <= 1'b1;
                    rows_sent_reg <= 32'd0;
                    rows_out_reg <= 32'd0;
                    state <= ST_ACT_NEXT;
                end

                ST_ACT_NEXT: begin
                    if (rows_sent_reg < raw_rows_reg) begin
                        act_row_sel <= rows_sent_reg[0];
                        state <= ST_ACT_REQ;
                    end else begin
                        state <= ST_DRAIN;
                    end
                end

                ST_ACT_REQ: begin
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= asrc_word_addr +
                        ((mode_reg == MODE_INT16) ? rows_sent_reg[`DCIM_IBUF_ADDR_WIDTH-1:0]
                                                  : rows_sent_reg[`DCIM_IBUF_ADDR_WIDTH:1]);
                    state <= ST_ACT_WAIT0;
                end

                ST_ACT_WAIT0: begin
                    ibuf_enb <= 1'b1;
                    ibuf_addrb <= asrc_word_addr +
                        ((mode_reg == MODE_INT16) ? rows_sent_reg[`DCIM_IBUF_ADDR_WIDTH-1:0]
                                                  : rows_sent_reg[`DCIM_IBUF_ADDR_WIDTH:1]);
                    state <= ST_ACT_WAIT1;
                end

                ST_ACT_WAIT1: begin
                    raw_act_word_reg <= ibuf_doutb;
                    state <= ST_ACT_LAUNCH;
                end

                ST_ACT_LAUNCH: begin
                    act_phase_reg <= 2'd0;
                    dcim_act_valid <= 1'b1;
                    state <= ST_ACT_PIPE;
                end

                ST_ACT_PIPE: begin
                    if (dcim_act_fire) begin
                        if ((mode_reg == MODE_INT16 && act_phase_reg == 2'd3) ||
                            (mode_reg == MODE_INT8 && act_phase_reg == 2'd1)) begin
                            dcim_act_valid <= 1'b0;
                            rows_sent_reg <= rows_sent_reg + 1'b1;
                            state <= ST_ACT_NEXT;
                        end else begin
                            act_phase_reg <= act_phase_reg + 1'b1;
                        end
                    end
                end

                ST_DRAIN: begin
                    dcim_act_valid <= 1'b0;
                    if (rows_out_reg >= expected_out_rows_reg && !obuf_writing) begin
                        dcim_done <= 1'b1;
                        state <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    dcim_act_valid <= 1'b0;
                    if (dcim_start_posedge) begin
                        dcim_done <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                ST_ERROR: begin
                    dcim_act_valid <= 1'b0;
                    dcim_done <= 1'b1;
                    if (dcim_start_posedge) begin
                        dcim_done <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
