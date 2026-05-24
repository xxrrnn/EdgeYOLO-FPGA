`timescale 1ns/1ps
`include "vpu_defines.vh"

module qa_unit #(
    parameter ADDR_WIDTH =      32,
    parameter GB_BANDWIDTH =    256,
    parameter GB_ADDR_WIDTH =   16,
    parameter WB_BANDWIDTH =    256,
    parameter WB_ADDR_WIDTH =   15,   // 字节地址位宽

    parameter FP_CORE_NUM =     8,
    parameter FP_TRAN_NUM =     8,
    parameter FP_WIDTH    =     32,
    parameter Q_INT_WIDTH_OUT =   8,

    parameter MAX_CHANNEL_NUM = `MAX_CHANNEL_NUM

)(
    input   wire                     clk,
    input   wire                     rst_n,
    input   wire                     qa_unit_start,
    output  wire                     qa_unit_ready,
                
    input   wire[ADDR_WIDTH - 1:0]   qa_src_addr,
    input   wire[ADDR_WIDTH - 1:0]   qa_src_c,
    input   wire[ADDR_WIDTH - 1:0]   qa_src_h,
    input   wire[ADDR_WIDTH - 1:0]   qa_src_w,
    input   wire[ADDR_WIDTH - 1:0]   qa_scale_addr,
    input   wire[ADDR_WIDTH - 1:0]   qa_dst_addr,

    output  reg                                 fp_array_tvalid,
    input   wire                                 fp_array_tready,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_a_tdata, 
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_b_tdata,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_c_tdata,
    input   wire [FP_CORE_NUM*FP_WIDTH-1:0]     fp_res,
    input   wire                                fp_res_tvalid,

    output logic [GB_ADDR_WIDTH-1:0]    gb_addrb, 
    output logic [GB_BANDWIDTH-1:0]     gb_dinb,  
    output logic [GB_BANDWIDTH/8-1:0]   gb_web,   
    output logic                        gb_enb,    
    input  wire [GB_BANDWIDTH-1:0]      gb_doutb,
    input  wire                         gb_doutb_valid,  // OBUF 读数据有效（与 gb_doutb 同拍）

    output reg [WB_ADDR_WIDTH-1:0]      wb_addrb,
    output reg [WB_BANDWIDTH-1:0]       wb_dinb,
    output reg [WB_BANDWIDTH/8-1:0]     wb_web,
    output reg                          wb_enb,
    input wire [WB_BANDWIDTH-1:0]       wb_doutb
);

    localparam  QA_FP_BITS                    = FP_CORE_NUM * FP_WIDTH;
    // 至少 1 个 block：FP 数据能在一个 GB word 内装下时仍要跑一轮 LOAD/COMPUTE/SAVE
    localparam  qa_single_compute_blocks      = (QA_FP_BITS <= GB_BANDWIDTH) ? 1
                                                : (QA_FP_BITS / GB_BANDWIDTH);
    localparam  qa_single_compute_save_blocks = (FP_CORE_NUM * Q_INT_WIDTH_OUT + GB_BANDWIDTH - 1) / GB_BANDWIDTH;
    localparam  FP_WIDTH_SHIFT = $clog2(FP_WIDTH);
    localparam  GB_BW_SHIFT    = $clog2(GB_BANDWIDTH);
    localparam  BYTE_ADDR_SHIFT = $clog2(GB_BANDWIDTH / 8);  // 字节地址到 word 地址的移位量

    // =========================================================================
    // 参数化 byte-write 写回方案（替代旧 int8_pack_writer 子模块）
    // -------------------------------------------------------------------------
    // 每次 QA_SAVE 输出 FP_CORE_NUM 个量化整数，共 SAVE_DATA_BITS bit。
    // 通过 OBUF byte enable 一次只写一个 slot，SAVES_PER_WORD 次写满一个 word。
    //
    // 各种配置都被覆盖（只要 SAVES_PER_WORD 是 2 的幂）：
    //   INT8 + 4 core : 32 bit/save × 4 = 128 bit/word  (当前)
    //   INT8 + 8 core : 64 bit/save × 2 = 128 bit/word
    //   INT16 + 4 core: 64 bit/save × 2 = 128 bit/word
    //   INT16 + 8 core: 128 bit/save × 1 = 128 bit/word  (退化为整字写)
    //   INT4 + 4 core : 16 bit/save × 8 = 128 bit/word
    // =========================================================================
    localparam SAVE_DATA_BITS  = FP_CORE_NUM * Q_INT_WIDTH_OUT;       // 每次 SAVE 的有效位宽
    localparam SAVE_DATA_BYTES = SAVE_DATA_BITS / 8;                  // 对应字节数
    localparam SAVES_PER_WORD  = GB_BANDWIDTH / SAVE_DATA_BITS;       // 几次 SAVE 写满一个 word
    localparam SLOT_IDX_BITS   = (SAVES_PER_WORD <= 1) ? 1 : $clog2(SAVES_PER_WORD);
    // 注：当 SAVES_PER_WORD == 1 时 SLOT_IDX_BITS=1（占位，但 slot_idx 强制为 0）


    typedef enum logic [5:0] {
        IDLE,
        QA_PRECOMPUTE_1,
        QA_PRECOMPUTE_2,
        QA_LOAD_SCALE,
        QA_WAIT_SCALE,
        QA_UPDATE,
        QA_LOAD_X,
        QA_WAIT_X,
        QA_COMPUTE,
        QA_COMPUTE_WAIT,
        QA_INT,
        QA_INT_WAIT,
        QA_SAVE
    } state_t;
    state_t c_state, n_state;
    
    assign qa_unit_ready  = (c_state == IDLE);

    // dqa signals
    reg     [FP_WIDTH - 1 : 0]                            qa_scale_reg;

    // -------------------------------------------------------------------------
    // OBUF 读：用 ready/valid 替代硬编码延迟
    //   - QA_LOAD_X 发地址（gb_enb=1, gb_web=0）
    //   - QA_WAIT_X 等待 gb_doutb_valid 拉高，采样 gb_doutb，立刻进下一状态
    //   - obuf.v 内部 douta_valid 已与 douta 同拍，无需额外打拍
    // -------------------------------------------------------------------------
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              qa_fp_in_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              qa_out_q_reg;
    reg     [FP_CORE_NUM * Q_INT_WIDTH_OUT - 1 : 0]       qa_out_int_reg;
    // 量化后待写的 INT8 数据（前置声明，供 byte-write 写回路径使用）
    reg     [FP_TRAN_NUM*Q_INT_WIDTH_OUT-1:0]             qa_quant_pack_data_reg;
    
    // Latched input parameters
    reg     [ADDR_WIDTH - 1 : 0]                          qa_src_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          qa_dst_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          qa_scale_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          qa_src_c_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          qa_src_h_reg;
    reg     [ADDR_WIDTH - 1 : 0]                          qa_src_w_reg;
    /* QA ADDR GENERATE*/
    /*

    1. qa_x_load_block_cnt:  
        qa_single_compute_blocks
        +1

        
    2. qa_x_load_cnt:
        (qa_src_w * qa_src_h * qa_src_c * FP_WIDTH / GB_BANDWIDTH ) - qa_single_compute_blocks
        + qa_single_compute_blocks

    */
    wire [ADDR_WIDTH - 1 : 0]                       qa_x_load_addr;
    reg  [ADDR_WIDTH - 1 : 0]                       qa_x_total_blocks_reg;
    reg  [ADDR_WIDTH - 1 : 0]                       qa_x_load_done_threshold;
    reg  [ADDR_WIDTH - 1 : 0]                       qa_total_save_slots_reg;
    wire [ADDR_WIDTH - 1 : 0]                       qa_x_total_blocks;
    assign      qa_x_total_blocks             = qa_x_total_blocks_reg;

    // Precompute pipeline registers
    reg  [2*ADDR_WIDTH - 1 : 0]                     precompute_ch;

    

    logic [ADDR_WIDTH - 1 : 0]                       qa_save_addr, qa_save_cnt;
    logic [ADDR_WIDTH - 1 : 0]                       qa_x_load_block_cnt,  n_qa_x_load_block_cnt;
    logic [ADDR_WIDTH - 1 : 0]                       qa_x_load_cnt,  n_qa_x_load_cnt;
    reg   [ADDR_WIDTH - 1 : 0]                       qa_x_tran_cnt;
    reg   [3:0]                                      qa_int_wait_cnt;  // latency counter for fp32_to_int8
    wire  qa_x_load_block_done, qa_save_done, qa_x_load_done, qa_done, qa_x_tran_done;
    
    assign  qa_x_load_block_done                    = (qa_x_load_block_cnt == qa_single_compute_blocks - 1);
    wire    qa_save_is_last_overall;
    assign  qa_save_is_last_overall                  = (qa_total_save_slots_reg != '0)
                                                       && (qa_save_cnt == qa_total_save_slots_reg - 1);
    // qa_save_done: 写满当前 128-bit word，或已写完最后一个有效 slot（部分 word 收尾）
    assign  qa_save_done                            = (SAVES_PER_WORD == 1) ? 1'b1
                                                       : ((qa_save_cnt[SLOT_IDX_BITS-1:0] == SAVES_PER_WORD - 1)
                                                          | qa_save_is_last_overall);
    assign  qa_x_load_done                          = (qa_x_load_cnt == qa_x_load_done_threshold);
    assign  qa_x_tran_done                          = (qa_x_tran_cnt == (FP_CORE_NUM / FP_TRAN_NUM)- 1);
    // 必须在 QA_SAVE 状态才判 done，避免 IDLE 时 load_cnt/threshold 均为 0 误触发
    assign  qa_done                                 = (c_state == QA_SAVE) && qa_x_load_done && qa_save_done;

    always @* begin
        n_qa_x_load_block_cnt       =     qa_x_load_block_cnt;
        n_qa_x_load_cnt             =     qa_x_load_cnt;
        if(qa_done) begin
            n_qa_x_load_block_cnt       = 0;
            n_qa_x_load_cnt             = 0;
        end else if(qa_x_load_done) begin
            n_qa_x_load_cnt             =     0;
            n_qa_x_load_block_cnt       =     0;
        end else if(qa_x_load_block_done) begin
            n_qa_x_load_cnt             =     qa_x_load_cnt + qa_single_compute_blocks;
            n_qa_x_load_block_cnt       =     0;
        end else begin
            n_qa_x_load_block_cnt       =     qa_x_load_block_cnt;
            n_qa_x_load_cnt             =     qa_x_load_cnt;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            qa_x_load_block_cnt    <= '0;
            qa_x_load_cnt        <= '0;
            qa_x_total_blocks_reg      <= '0;
            qa_x_load_done_threshold   <= '0;
            qa_total_save_slots_reg    <= '0;
            precompute_ch              <= '0;
        end else if (c_state == IDLE && qa_unit_start) begin
            qa_x_load_block_cnt    <= '0;
            qa_x_load_cnt          <= '0;
        end else if (c_state == QA_PRECOMPUTE_1) begin
            precompute_ch          <= qa_src_c_reg * qa_src_h_reg;
        end else if (c_state == QA_PRECOMPUTE_2) begin
            precompute_ch          <= precompute_ch * qa_src_w_reg;
        end else if (c_state == QA_LOAD_SCALE) begin
            automatic logic [2*ADDR_WIDTH-1:0] total_bits;
            automatic logic [ADDR_WIDTH-1:0] total_blocks;
            total_bits = precompute_ch << FP_WIDTH_SHIFT;
            total_blocks = total_bits[ADDR_WIDTH-1:0] >> GB_BW_SHIFT;
            qa_x_total_blocks_reg <= total_blocks;
            // clamp 防止 total_blocks < qa_single_compute_blocks 时 underflow 成 0xFFFF_FFFF
            qa_x_load_done_threshold <= (total_blocks > qa_single_compute_blocks)
                                        ? (total_blocks - qa_single_compute_blocks)
                                        : '0;
            // 总 SAVE 次数 = ceil(total_fp32 / FP_CORE_NUM)
            qa_total_save_slots_reg <= (precompute_ch + FP_CORE_NUM - 1) / FP_CORE_NUM;
        end else if (c_state == QA_UPDATE) begin
            qa_x_load_block_cnt    <= n_qa_x_load_block_cnt;
            qa_x_load_cnt         <= n_qa_x_load_cnt;
        end
    end


    assign qa_x_load_addr    = (qa_src_addr_reg >> BYTE_ADDR_SHIFT) + qa_x_load_block_cnt + qa_x_load_cnt;
    assign qa_save_addr      = (qa_dst_addr_reg >> BYTE_ADDR_SHIFT) + qa_save_cnt + qa_x_load_cnt / qa_single_compute_blocks * qa_single_compute_save_blocks;

    wire [ADDR_WIDTH - 1 : 0]            qa_scale_block_addr, qa_scale_block_index;
    assign qa_scale_block_addr           = (qa_scale_addr_reg >> BYTE_ADDR_SHIFT);
    assign qa_scale_block_index          = qa_scale_addr_reg[BYTE_ADDR_SHIFT-1:0];
    assign wb_addrb = (c_state == QA_LOAD_SCALE) ? (qa_scale_addr_reg >> BYTE_ADDR_SHIFT) :'0;
    assign wb_enb   = (c_state == QA_LOAD_SCALE) ? 1'b1 :1'b0;
    assign wb_web   = 1'b0;
    assign wb_dinb  = '0;

    always_ff @( posedge clk or negedge rst_n ) begin
        if(!rst_n) begin
            qa_scale_reg      <= '0;
        end
        else begin
            if(c_state == QA_WAIT_SCALE) begin
                qa_scale_reg <= wb_doutb[qa_scale_block_index * FP_WIDTH +: FP_WIDTH];
            end
        end
    end

    /*  X LOAD —— ready/valid 触发采样（替代硬编码延迟）
     *  obuf.v 的 douta_valid 与 douta 同拍，所以这里只需要等 gb_doutb_valid 拉高即可。
     *
     *  qa_save_cnt 语义（重要）：
     *    - 每个 LOAD/COMPUTE/INT 周期产出 1 个 slot（FP_CORE_NUM 个 INT8）
     *    - 每次 QA_SAVE 写 1 个 slot 后递增
     *    - 跨 QA_UPDATE 等中间状态必须保持，不能清零
     *    - 只在 IDLE/qa_done 时清零（一次 QA 操作开始/结束）
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            qa_fp_in_reg <= '0;
            qa_save_cnt <= '0;
        end else begin
            case (c_state)
                IDLE: begin
                    qa_save_cnt <= '0;
                end
                QA_WAIT_X: begin
                    if (gb_doutb_valid) begin
                        if (FP_CORE_NUM * FP_WIDTH > GB_BANDWIDTH)
                            qa_fp_in_reg <= {gb_doutb, qa_fp_in_reg[FP_CORE_NUM * FP_WIDTH - 1 : GB_BANDWIDTH]};
                        else
                            qa_fp_in_reg <= gb_doutb[FP_CORE_NUM * FP_WIDTH - 1 : 0];
                    end
                end
                QA_SAVE: begin
                    qa_save_cnt <= qa_save_cnt + 1;
                end
                default: begin
                    // 中间状态保持 qa_save_cnt（不能清零，否则 slot_idx 重置导致写错位置）
                end
            endcase
        end
    end

    // =========================================================================
    // OBUF 端口分时控制（替代旧 int8_pack_writer + always_comb pack 优先级路径）
    // -------------------------------------------------------------------------
    // 设计原则：QA_LOAD_X 只读，QA_SAVE 只写，其他状态闲置，杜绝读写争用。
    //
    // 写策略（byte-write 直写）：
    //   - 每个 QA_SAVE 状态写 1 个 byte slot（SAVE_DATA_BYTES 字节）
    //   - slot_idx 由 qa_save_cnt 低位提供，决定写到 word 的哪个位置
    //   - SAVES_PER_WORD 个 slot 写满一个 128-bit word 后，qa_save_cnt 进位触发新 word
    // =========================================================================
    wire [SLOT_IDX_BITS-1:0]            slot_idx;
    wire [ADDR_WIDTH-1:0]               word_offset;
    wire [GB_BANDWIDTH-1:0]             qa_save_din_shifted;
    wire [GB_BANDWIDTH/8-1:0]           qa_save_we_shifted;

    assign slot_idx    = (SAVES_PER_WORD == 1) ? '0 : qa_save_cnt[SLOT_IDX_BITS-1:0];
    assign word_offset = (SAVES_PER_WORD == 1) ? qa_save_cnt
                                               : (qa_save_cnt >> SLOT_IDX_BITS);

    // 把 SAVE_DATA_BITS 的量化数据移位到目标 slot 位置
    assign qa_save_din_shifted = { {(GB_BANDWIDTH-SAVE_DATA_BITS){1'b0}}, qa_quant_pack_data_reg }
                                 << (slot_idx * SAVE_DATA_BITS);

    // byte enable: SAVE_DATA_BYTES 个 '1' 移位到目标 slot 位置
    assign qa_save_we_shifted  = { {(GB_BANDWIDTH/8-SAVE_DATA_BYTES){1'b0}}, {SAVE_DATA_BYTES{1'b1}} }
                                 << (slot_idx * SAVE_DATA_BYTES);

    always_comb begin
        gb_addrb = '0;
        gb_enb   = '0;
        gb_web   = '0;
        gb_dinb  = '0;

        unique case (c_state)
            QA_LOAD_X: begin
                // 只读
                gb_addrb = qa_x_load_addr;
                gb_enb   = 1'b1;
                gb_web   = '0;
                gb_dinb  = '0;
            end
            QA_SAVE: begin
                // 只写：byte-write 到 dst_addr + word_offset 的 slot_idx 位置
                gb_addrb = (qa_dst_addr_reg >> BYTE_ADDR_SHIFT) + word_offset;
                gb_enb   = 1'b1;
                gb_web   = qa_save_we_shifted;
                gb_dinb  = qa_save_din_shifted;
            end
            default: begin
                // 其余状态 OBUF 端口闲置（gb_enb=0）
            end
        endcase
    end

    assign fp_array_tvalid  = (c_state == QA_COMPUTE)? 1'b1 : 1'b0;
    assign fp_a_tdata       = (c_state == QA_COMPUTE)? qa_fp_in_reg: '0;
    assign fp_b_tdata       = (c_state == QA_COMPUTE)? {FP_CORE_NUM{qa_scale_reg}} : '0;
    // Symmetric INT8 quantization: q = clamp(round(dqa * qscale), -128, 127)
    // fp_mac computes a*b+c; set c=0 so output = dqa*qscale directly.
    // fp32_to_int8 IP (C_FIXED_DATA_UNSIGNED=0) clamps to signed INT8 — no offset needed.
    assign fp_c_tdata       = '0;


    /* FP2INT ARRAY*/
    logic  s_axis_tvalid, m_axis_int_tvalid;
    
    wire [FP_TRAN_NUM*FP_WIDTH-1:0]     s_axis_tdata;
    wire [FP_TRAN_NUM*Q_INT_WIDTH_OUT-1:0]         m_axis_int_tdata;
    assign  s_axis_tvalid = (c_state == QA_INT);
    assign  s_axis_tdata  = qa_out_q_reg[qa_x_tran_cnt * FP_TRAN_NUM * FP_WIDTH +: FP_TRAN_NUM * FP_WIDTH];

    fp32_2_int8_array # (
    .FP_TRAN_NUM(FP_TRAN_NUM)
    )fp32_2_int8_array_inst(
        .clk(clk),
        .s_axis_a_tvalid(s_axis_tvalid),
        .s_axis_a_tdata(s_axis_tdata),
        .m_axis_result_tdata(m_axis_int_tdata),
        .m_axis_result_tvalid(m_axis_int_tvalid)
    );

    // FP MAC result capture (independent)
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            qa_out_q_reg <= '0;
        end else if(c_state == IDLE) begin
            qa_out_q_reg <= '0;
        end else if(fp_res_tvalid) begin
            qa_out_q_reg <= fp_res;
        end
    end

    // =========================================================================
    // FP32→INT8: Vivado fp32_to_int8 IP (C_LATENCY=6) 直接产出对称 INT8。
    //   - QA_INT 状态向 IP 送入数据
    //   - QA_INT_WAIT 等 m_axis_int_tvalid（约 6 拍后）锁存到 qa_quant_pack_data_reg
    //   - qa_quant_pack_data_reg 由 byte-write 写回路径直接消费
    // =========================================================================

    // INT8 result capture + tran counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qa_x_tran_cnt        <= '0;
            qa_out_int_reg       <= '0;
            qa_int_wait_cnt      <= '0;
            qa_quant_pack_data_reg <= '0;
        end else if (c_state == IDLE) begin
            qa_x_tran_cnt        <= '0;
            qa_out_int_reg       <= '0;
            qa_int_wait_cnt      <= '0;
            qa_quant_pack_data_reg <= '0;
        end else if (c_state == QA_INT) begin
            qa_int_wait_cnt <= '0;
        end else if (c_state == QA_INT_WAIT) begin
            qa_int_wait_cnt <= qa_int_wait_cnt + 1'b1;
            if (m_axis_int_tvalid) begin
                // Symmetric INT8: IP output is signed INT8 [-128,127], use directly
                qa_quant_pack_data_reg <= m_axis_int_tdata;
                qa_x_tran_cnt  <= qa_x_tran_done ? '0 : qa_x_tran_cnt + 1'b1;
                qa_out_int_reg[qa_x_tran_cnt * FP_TRAN_NUM * Q_INT_WIDTH_OUT +:
                               FP_TRAN_NUM * Q_INT_WIDTH_OUT] <= m_axis_int_tdata;
            end
        end
    end




    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            c_state <= IDLE;   // 复位时清零
        end else begin
            c_state <= n_state; // 正常运行时更新
        end
    end

    // Latch input parameters when start is asserted
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qa_src_addr_reg   <= '0;
            qa_dst_addr_reg   <= '0;
            qa_scale_addr_reg <= '0;
            qa_src_c_reg      <= '0;
            qa_src_h_reg      <= '0;
            qa_src_w_reg      <= '0;
        end else if (qa_unit_start && qa_unit_ready) begin
            qa_src_addr_reg   <= qa_src_addr;
            qa_dst_addr_reg   <= qa_dst_addr;
            qa_scale_addr_reg <= qa_scale_addr;
            qa_src_c_reg      <= qa_src_c;
            qa_src_h_reg      <= qa_src_h;
            qa_src_w_reg      <= qa_src_w;
        end
    end

    always@(*) begin
        n_state = c_state;
        unique case(c_state)
            IDLE: begin
                if(qa_unit_start) begin
                    n_state = QA_PRECOMPUTE_1;
                end
            end
            QA_PRECOMPUTE_1 : n_state  = QA_PRECOMPUTE_2;
            QA_PRECOMPUTE_2 : n_state  = QA_LOAD_SCALE;
            QA_LOAD_SCALE   : n_state  = QA_WAIT_SCALE;
            QA_WAIT_SCALE   : n_state  = QA_LOAD_X;
            QA_UPDATE       : n_state  = QA_LOAD_X;
            QA_LOAD_X       : n_state  = QA_WAIT_X;
            // ready/valid：等 OBUF 读数据有效信号（gb_doutb_valid）拉高
            QA_WAIT_X       : n_state  = gb_doutb_valid ? (qa_x_load_block_done ? QA_COMPUTE : QA_UPDATE) : QA_WAIT_X;
            QA_COMPUTE      : n_state  = fp_array_tready? QA_COMPUTE_WAIT :QA_COMPUTE;
            QA_COMPUTE_WAIT : n_state  = fp_res_tvalid ? QA_INT : QA_COMPUTE_WAIT;
            QA_INT          : n_state  = QA_INT_WAIT;
            QA_INT_WAIT     : n_state  = m_axis_int_tvalid ? QA_SAVE : QA_INT_WAIT;
            QA_SAVE        : begin
                // 每轮 COMPUTE 只写 1 个 slot（1 cycle SAVE），然后 UPDATE 进入下一轮 LOAD
                if (qa_done)
                    n_state = IDLE;
                else
                    n_state = QA_UPDATE;
            end
            default: n_state = IDLE;
            
        endcase

    end

    // =========================================================================
    // 写回路径：使用 byte-write 直接驱动 OBUF Port A（见上方 always_comb）。
    // 旧 int8_pack_writer 子模块已删除：每次 QA_SAVE 直接发 1 个 slot 写请求，
    // SAVES_PER_WORD 拍写满一个 word；不再有 buffer/pack_cnt/X 传播路径。
    // =========================================================================


endmodule
