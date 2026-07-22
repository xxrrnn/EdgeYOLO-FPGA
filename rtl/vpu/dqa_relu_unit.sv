`timescale 1ns/1ns
`include "chip_defines.vh"

module dqa_relu_unit #(
    parameter ADDR_WIDTH = 32,
    parameter VB_BANDWIDTH = `VB_BANDWIDTH,
    parameter VB_ADDR_WIDTH = `VB_ADDR_WIDTH,
    parameter C_INT_WIDTH_IN = 32,
    parameter FP_CORE_NUM = `FP_CORE_NUM,
    parameter FP_TRAN_NUM = `FP_TRAN_NUM,
    parameter FP_WIDTH    = 32,
    parameter WB_BANDWIDTH = `VB_BANDWIDTH,
    parameter WB_ADDR_WIDTH = 15,   // 字节地址位宽
    parameter MAX_CHANNEL_NUM = `MAX_CHANNEL_NUM

)(
    input   wire                                clk,
    input   wire                                rst_n,
    input   wire                                dqa_unit_start,
    output  wire                                dqa_unit_ready,
    input   wire                                dqa_relu_en,     // 1=ReLU（max(·,0)），0=线性直通
    input   wire                                dqa_int16_mode,  // 1=INT16 mode. DQA_ACT reads int16 packed; DCIM accum reads int64.
    input   wire                                dqa_act_mode,    // 1=输入为 QA packed activation，0=DCIM accumulator

    input   wire[ADDR_WIDTH - 1:0]              dqa_src_addr,
    input   wire[ADDR_WIDTH - 1:0]              dqa_src_c,
    input   wire[ADDR_WIDTH - 1:0]              dqa_src_h,
    input   wire[ADDR_WIDTH - 1:0]              dqa_src_w,
    input   wire[ADDR_WIDTH - 1:0]              dqa_scale_addr,
    input   wire[ADDR_WIDTH - 1:0]              dqa_bias_addr,
    input   wire[ADDR_WIDTH - 1:0]              dqa_dst_addr,
    // tile-sequential 支持：save stride 基于 total_c（全部输出通道数），load stride 基于 src_c（单 tile 通道数）
    // total_c = 0 表示向后兼容（save stride == load stride，等价于旧行为 total_c = src_c）
    input   wire[ADDR_WIDTH - 1:0]              dqa_total_c,

    input   wire                                fp_array_tready,
    output  reg                                 fp_array_tvalid,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_a_tdata, 
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_b_tdata,
    output  reg [FP_CORE_NUM*FP_WIDTH-1:0]      fp_c_tdata,
    input   wire [FP_CORE_NUM*FP_WIDTH-1:0]     fp_res,
    input   wire                                fp_res_tvalid,

    output  logic [VB_ADDR_WIDTH-1:0]           gb_addrb, 
    output  logic [VB_BANDWIDTH-1:0]            gb_dinb,  
    output  logic [VB_BANDWIDTH/8-1:0]          gb_web,   
    output  logic                               gb_enb,    
    input   wire [VB_BANDWIDTH-1:0]             gb_doutb,
    input   wire                                gb_doutb_valid,  // OBUF 读数据有效（与 gb_doutb 同拍）

    output  reg [WB_ADDR_WIDTH-1:0]             wb_addrb,
    output  reg [WB_BANDWIDTH-1:0]              wb_dinb,
    output  reg [WB_BANDWIDTH/8-1:0]            wb_web,
    output  reg                                 wb_enb,
    input   wire [WB_BANDWIDTH-1:0]             wb_doutb
);
    typedef enum logic [5:0] {
        IDLE,
        DQA_UPDATE,
        DQA_LOAD_SCALE,
        DQA_WAIT_SCALE,
        DQA_LOAD_BIAS,
        DQA_WAIT_BIAS,
        DQA_LAOD_ADDR_1,
        DQA_LAOD_ADDR_2,
        DQA_LAOD_ADDR_3,
        DQA_LAOD_ADDR_4,
        DQA_LOAD_X,
        DQA_WAIT_X,
        DQA_FP,
        DQA_FP_WAIT,
        DQA_COMPUTE,
        DQA_COMPUTE_WAIT,
        DQA_SAVE_ADDR_1,
        DQA_SAVE_ADDR_2,
        DQA_SAVE_ADDR_3,
        DQA_SAVE
    } state_t;
    (* fsm_encoding = "auto" *) state_t c_state, n_state;
    
    assign dqa_unit_ready  = (c_state == IDLE);

    // dqa signals
    reg     [MAX_CHANNEL_NUM * FP_WIDTH - 1 : 0]            dqa_scale_reg;
    reg     [MAX_CHANNEL_NUM * FP_WIDTH - 1 : 0]            dqa_bias_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_full_scale_wire;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_full_bias_wire;
    reg     [FP_CORE_NUM * C_INT_WIDTH_IN - 1 : 0]          dqa_int_in_reg;
    reg     [FP_CORE_NUM * 64 - 1 : 0]                      dqa_int64_in_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_fp_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]                dqa_out_reg;

    // Latched input parameters
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_dst_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_scale_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_bias_addr_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_c_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_h_reg;
    reg     [ADDR_WIDTH - 1 : 0]                            dqa_src_w_reg;
    // wire    [ADDR_WIDTH - 1 : 0]                            dqa_w_parallel  = FP_CORE_NUM / dqa_src_c;

    /* DQA ADDR GENERATE*/
    /*
    1. dqa_scale_load_cnt: 
        (dqa_src_c * FP_WIDTH / WB_BANDWIDTH) - 1
        而后根据w_para拼接到dqa_scale_reg长度

    2. dqa_x_load_block_cnt:  
        (FP_CORE_NUM * C_INT_WIDTH_IN / 8) >> 5 - 1
        +1
    3 dqa_x_load_c_cnt: 

    2. dqa_x_load_w_cnt:  
        dqa_src_w - 1
        + 1
    2. dqa_x_load_h_cnt: 
        dqa_src_h - 1
        + 1
    */
    localparam  MAX_CHANNEL_LENGTH = MAX_CHANNEL_NUM * FP_WIDTH;
    localparam  FP_CORE_LENGTH = FP_CORE_NUM* FP_WIDTH;
    localparam  BYTE_ADDR_SHIFT = $clog2(VB_BANDWIDTH / 8);  // 字节地址到 word 地址的移位量
    logic [ADDR_WIDTH - 1 : 0]                      dqa_x_load_addr_add, n_dqa_x_load_addr_add;
    // wire [ADDR_WIDTH - 1 : 0]                       DQA_SINGLE_COMPUTE_BYTES,DQA_SINGLE_COMPUTE_BLOCKS ;
    // wire [ADDR_WIDTH - 1 : 0]                       DQA_SINGLE_COMPUTE_SAVE_BLOCKS ;
    // localparam DQA_SINGLE_COMPUTE_BYTES        = (FP_CORE_NUM * C_INT_WIDTH_IN >> 3);
    localparam DQA_SINGLE_COMPUTE_BLOCKS32      = ((FP_CORE_NUM * 32 + VB_BANDWIDTH - 1) / VB_BANDWIDTH);
    localparam DQA_SINGLE_COMPUTE_BLOCKS64      = ((FP_CORE_NUM * 64 + VB_BANDWIDTH - 1) / VB_BANDWIDTH);
    localparam DQA_SINGLE_COMPUTE_BLOCKS16      = ((FP_CORE_NUM * 16 + VB_BANDWIDTH - 1) / VB_BANDWIDTH);
    localparam DQA_SINGLE_COMPUTE_BLOCKS        = ((FP_CORE_NUM * C_INT_WIDTH_IN + VB_BANDWIDTH - 1) / VB_BANDWIDTH);
    localparam DQA_SINGLE_COMPUTE_SAVE_BLOCKS   = ((FP_CORE_NUM * FP_WIDTH + VB_BANDWIDTH - 1) / VB_BANDWIDTH);
    localparam DQA_LOAD_WORDS_MAX_0 = (DQA_SINGLE_COMPUTE_BLOCKS32 > DQA_SINGLE_COMPUTE_BLOCKS16) ?
                                      DQA_SINGLE_COMPUTE_BLOCKS32 : DQA_SINGLE_COMPUTE_BLOCKS16;
    localparam DQA_LOAD_WORDS_MAX = (DQA_SINGLE_COMPUTE_BLOCKS64 > DQA_LOAD_WORDS_MAX_0) ?
                                    DQA_SINGLE_COMPUTE_BLOCKS64 : DQA_LOAD_WORDS_MAX_0;
    localparam DQA_LOAD_WORDS_BITS = (DQA_LOAD_WORDS_MAX <= 1) ? 1 : $clog2(DQA_LOAD_WORDS_MAX);
    localparam DQA_SAVE_WORDS_BITS = (DQA_SINGLE_COMPUTE_SAVE_BLOCKS <= 1) ? 1 : $clog2(DQA_SINGLE_COMPUTE_SAVE_BLOCKS);
    localparam INT64_LANES_PER_WORD = VB_BANDWIDTH / 64;

    initial begin
        if (VB_BANDWIDTH % 64 != 0)
            $error("dqa_relu_unit requires VB_BANDWIDTH divisible by 64 for native INT16 accumulators");
        if (FP_CORE_NUM % INT64_LANES_PER_WORD != 0)
            $error("dqa_relu_unit requires complete INT64 channel groups in each load transaction");
    end
    wire[ADDR_WIDTH - 1 : 0]   dqa_w_load_stride ;
    wire[ADDR_WIDTH - 1 : 0]   dqa_w_save_stride;
    logic [ADDR_WIDTH - 1 : 0]                       dqa_h_load_stride;
    logic [ADDR_WIDTH - 1 : 0]                       dqa_h_save_stride;

    // Precomputed strides (registered to break combinational multiply)
    reg [ADDR_WIDTH - 1 : 0] dqa_w_load_stride_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_w_save_stride_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_h_load_stride_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_h_save_stride_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_src_base_word_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_dst_base_word_reg;
    reg [ADDR_WIDTH - 1 : 0] dqa_load_word_stride_reg;

    assign dqa_w_load_stride = dqa_w_load_stride_reg;
    assign dqa_w_save_stride = dqa_w_save_stride_reg;
    assign dqa_h_load_stride = dqa_h_load_stride_reg;
    assign dqa_h_save_stride = dqa_h_save_stride_reg;

    reg [ADDR_WIDTH - 1 : 0]                       dqa_save_addr, dqa_save_cnt;

    // -------------------------------------------------------------------------
    // OBUF 读：用 ready/valid 替代硬编码延迟（与 qa_unit 同构）
    //   - DQA_LOAD_X 发地址（gb_enb=1）然后立即进 DQA_WAIT_X
    //   - DQA_WAIT_X 等 gb_doutb_valid，采样后视情况进 DQA_FP / DQA_UPDATE
    // -------------------------------------------------------------------------
    reg [ADDR_WIDTH - 1 : 0]                       dqa_scale_load_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_bias_load_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_block_cnt,  n_dqa_x_load_block_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_c_cnt,      n_dqa_x_load_c_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_w_cnt,      n_dqa_x_load_w_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_load_h_cnt,      n_dqa_x_load_h_cnt;
    reg [ADDR_WIDTH - 1 : 0]                       dqa_x_tran_cnt;

    wire                                             dqa_scale_load_done;
    wire                                             dqa_bias_load_done;
    wire                                             dqa_save_done;
    wire                                             dqa_x_load_block_done;
    wire                                             dqa_x_load_c_done;
    wire                                             dqa_x_load_w_done;
    wire                                             dqa_x_load_h_done;
    wire                                             dqa_x_tran_done;
    wire                                             dqa_done;
    localparam TRAN_NUM = (FP_CORE_NUM / FP_TRAN_NUM);
    assign  dqa_scale_load_done                      = (dqa_scale_load_cnt   == ((dqa_src_c_reg << $clog2(FP_WIDTH)) >> $clog2(WB_BANDWIDTH)) - 1);
    assign  dqa_bias_load_done                       = (dqa_bias_load_cnt    == ((dqa_src_c_reg << $clog2(FP_WIDTH)) >> $clog2(WB_BANDWIDTH)) - 1);
    assign  dqa_save_done                            = (dqa_save_cnt         == (DQA_SINGLE_COMPUTE_SAVE_BLOCKS - 1));
    assign  dqa_x_load_block_done                    = (dqa_x_load_block_cnt[DQA_LOAD_WORDS_BITS-1:0] == dqa_load_word_stride_reg[DQA_LOAD_WORDS_BITS-1:0] - 1'b1);
    assign  dqa_x_load_c_done                        = (dqa_x_load_c_cnt     == ((dqa_src_c_reg >> $clog2(FP_CORE_NUM)) - 1));
    assign  dqa_x_load_w_done                        = (dqa_x_load_w_cnt     == (dqa_src_w_reg - 1));
    assign  dqa_x_load_h_done                        = (dqa_x_load_h_cnt     == (dqa_src_h_reg - 1));
    assign  dqa_x_tran_done                          = (dqa_x_tran_cnt       == TRAN_NUM- 1);

    assign  dqa_done                                 = dqa_x_load_block_done && dqa_x_load_c_done && dqa_x_load_w_done &&dqa_x_load_h_done;

    // NHWC flat word addresses are maintained incrementally in dqa_x_load_addr_add.
    // Avoid cnt*stride combinational address paths in the active loop.

    always @* begin
        n_dqa_x_load_block_cnt           = dqa_x_load_block_cnt;
        n_dqa_x_load_c_cnt               = dqa_x_load_c_cnt;
        n_dqa_x_load_w_cnt               = dqa_x_load_w_cnt;
        n_dqa_x_load_h_cnt               = dqa_x_load_h_cnt;
        n_dqa_x_load_addr_add            = dqa_x_load_addr_add;
        if(dqa_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_w_cnt           = 0;
            n_dqa_x_load_h_cnt           = 0;
            n_dqa_x_load_addr_add        = 0;
        end else if(dqa_x_load_c_done && dqa_x_load_block_done && dqa_x_load_w_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_w_cnt           = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt + 1;
            n_dqa_x_load_addr_add        = dqa_x_load_addr_add + 1'b1;
        end else if(dqa_x_load_c_done && dqa_x_load_block_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = 0;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt + 1;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
            n_dqa_x_load_addr_add        = dqa_x_load_addr_add + 1'b1;
        end else if(dqa_x_load_block_done) begin
            n_dqa_x_load_block_cnt       = 0;
            n_dqa_x_load_c_cnt           = dqa_x_load_c_cnt + 1;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
            n_dqa_x_load_addr_add        = dqa_x_load_addr_add + 1'b1;
        end else begin
            n_dqa_x_load_block_cnt       = dqa_x_load_block_cnt + 1;
            n_dqa_x_load_w_cnt           = dqa_x_load_w_cnt;
            n_dqa_x_load_h_cnt           = dqa_x_load_h_cnt;
            n_dqa_x_load_c_cnt           = dqa_x_load_c_cnt;
            n_dqa_x_load_addr_add        = dqa_x_load_addr_add + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_x_load_block_cnt    <= '0;
            dqa_x_load_w_cnt        <= '0;
            dqa_x_load_h_cnt        <= '0;
            dqa_x_load_c_cnt        <= '0;
            dqa_x_load_addr_add     <= '0;
        end else if (c_state == DQA_UPDATE) begin
            dqa_x_load_block_cnt    <= n_dqa_x_load_block_cnt;
            dqa_x_load_c_cnt        <= n_dqa_x_load_c_cnt;
            dqa_x_load_w_cnt        <= n_dqa_x_load_w_cnt;
            dqa_x_load_h_cnt        <= n_dqa_x_load_h_cnt;
            dqa_x_load_addr_add         <= n_dqa_x_load_addr_add;
        end else if(c_state == IDLE) begin
            dqa_x_load_block_cnt    <= '0;
            dqa_x_load_w_cnt        <= '0;
            dqa_x_load_h_cnt        <= '0;
            dqa_x_load_c_cnt        <= '0;
            dqa_x_load_addr_add     <= '0;
        end
    end
    
    // assign dqa_x_load_addr    = (dqa_src_addr >> 5) + dqa_x_load_block_cnt + dqa_x_load_c_cnt * DQA_SINGLE_COMPUTE_BLOCKS + dqa_x_load_w_cnt *dqa_w_load_stride  + dqa_x_load_h_cnt * dqa_h_load_stride;
    // assign dqa_save_addr      = (dqa_dst_addr >> 5) + dqa_save_cnt + dqa_x_load_c_cnt * DQA_SINGLE_COMPUTE_SAVE_BLOCKS + dqa_x_load_w_cnt * dqa_w_save_stride + dqa_x_load_h_cnt * dqa_h_save_stride;

    // always_ff @( posedge clk or negedge rst_n ) begin
    //     if(!rst_n) begin
    //         dqa_x_load_addr <= '0;
    //     end else begin
    //         case(c_state)
    //         DQA_LAOD_ADDR_1: begin
    //             dqa_x_load_addr <= (dqa_src_addr >> 5) + dqa_x_load_block_cnt;
    //             dqa_x_load_addr_1 <= dqa_x_load_c_cnt << $clog2(DQA_SINGLE_COMPUTE_BLOCKS);
    //             dqa_x_load_addr_2 <= dqa_x_load_w_cnt * dqa_w_load_stride;
    //             dqa_x_load_addr_3 <= dqa_x_load_h_cnt * dqa_h_load_stride;
    //         end
    //         DQA_LAOD_ADDR_2:begin
    //             dqa_x_load_addr <= dqa_x_load_addr + dqa_x_load_addr_1;
    //         end
    //         DQA_LAOD_ADDR_3:begin
    //             dqa_x_load_addr <= dqa_x_load_addr + dqa_x_load_addr_2;
    //         end
    //         DQA_LAOD_ADDR_4: begin
    //             dqa_x_load_addr <= dqa_x_load_addr + dqa_x_load_addr_3;
    //         end

    //         endcase
    //     end
    // end
    


    assign wb_addrb = (c_state == DQA_LOAD_SCALE) ? (dqa_scale_addr_reg  >> BYTE_ADDR_SHIFT) + dqa_scale_load_cnt :(c_state == DQA_LOAD_BIAS) ?  (dqa_bias_addr_reg  >> BYTE_ADDR_SHIFT) + dqa_bias_load_cnt :'0;
    assign wb_enb   = ((c_state == DQA_LOAD_SCALE) || (c_state == DQA_LOAD_BIAS)) ? 1'b1 :1'b0;
    assign wb_web   = 1'b0;
    assign wb_dinb  = '0;

    always_ff @( posedge clk or negedge rst_n ) begin
        if(!rst_n) begin
            dqa_bias_load_cnt  <= '0;
            dqa_scale_load_cnt <= '0;
            dqa_scale_reg      <= '0;
            dqa_bias_reg      <= '0;
        end
        else begin
            if(c_state == DQA_WAIT_SCALE) begin
                dqa_scale_load_cnt <= dqa_scale_load_cnt + 1'b1;
                dqa_scale_reg <= {wb_doutb, dqa_scale_reg[MAX_CHANNEL_LENGTH - 1 : WB_BANDWIDTH]};
            end else if(c_state == DQA_WAIT_BIAS) begin
                dqa_bias_load_cnt  <= dqa_bias_load_cnt  + 1'b1;
                dqa_bias_reg  <= {wb_doutb, dqa_bias_reg[MAX_CHANNEL_LENGTH - 1 : WB_BANDWIDTH]};
            end else if(c_state == IDLE) begin
                dqa_scale_load_cnt <= '0;
                dqa_bias_load_cnt  <= '0;
            end
        end
            
    end

    /*  X LOAD  —— ready/valid 触发采样（DQA_WAIT_X 等 gb_doutb_valid）
     *  obuf.v 的 douta_valid 与 douta 同拍，等 valid 拉高直接采样。
     */
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_int_in_reg <= '0;
            dqa_int64_in_reg <= '0;
            dqa_save_cnt <= '0;
            dqa_save_addr <= '0;
        end else begin
            case (c_state)
                DQA_WAIT_X: begin
                    if (gb_doutb_valid) begin
                        if (dqa_act_mode && dqa_int16_mode) begin
                            for (int dqa_act16_i = 0; dqa_act16_i < FP_CORE_NUM; dqa_act16_i++) begin
                                dqa_int_in_reg[dqa_act16_i*C_INT_WIDTH_IN +: C_INT_WIDTH_IN]
                                    <= {{(C_INT_WIDTH_IN-16){gb_doutb[dqa_x_load_addr_add[0]*64 + dqa_act16_i*16 + 15]}},
                                        gb_doutb[dqa_x_load_addr_add[0]*64 + dqa_act16_i*16 +: 16]};
                            end
                        end else if (dqa_act_mode) begin
                            for (int dqa_act8_i = 0; dqa_act8_i < FP_CORE_NUM; dqa_act8_i++) begin
                                dqa_int_in_reg[dqa_act8_i*C_INT_WIDTH_IN +: C_INT_WIDTH_IN]
                                    <= {{(C_INT_WIDTH_IN-8){gb_doutb[dqa_x_load_addr_add[1:0]*32 + dqa_act8_i*8 + 7]}},
                                        gb_doutb[dqa_x_load_addr_add[1:0]*32 + dqa_act8_i*8 +: 8]};
                            end
                        end else begin
                            dqa_int_in_reg <= gb_doutb[FP_CORE_NUM * C_INT_WIDTH_IN - 1 : 0];
                            if (dqa_int16_mode) begin
                                for (int dqa_acc64_i = 0; dqa_acc64_i < INT64_LANES_PER_WORD; dqa_acc64_i++) begin
                                    dqa_int64_in_reg[(dqa_x_load_block_cnt[DQA_LOAD_WORDS_BITS-1:0] * INT64_LANES_PER_WORD + dqa_acc64_i) * 64 +: 64]
                                        <= gb_doutb[dqa_acc64_i*64 +: 64];
                                end
                            end
                        end
                    end
                end
                DQA_SAVE: begin
                    dqa_save_cnt <= dqa_save_cnt + 1'b1;
                end
                // save addr 独立于 load addr 计算，使用 save stride（支持 tile-sequential total_c != src_c）
                // SAVE_ADDR_1: base = dst_base + c_cnt * DQA_SINGLE_COMPUTE_SAVE_BLOCKS；同时清零 save_cnt
                // SAVE_ADDR_2: += w_cnt * w_save_stride
                // SAVE_ADDR_3: += h_cnt * h_save_stride
                // DQA_SAVE   : 写地址 = save_addr + save_cnt（save_cnt 从 0 递增）
                DQA_SAVE_ADDR_1: begin
                    dqa_save_cnt  <= '0;
                    dqa_save_addr <= dqa_dst_base_word_reg +
                                     dqa_x_load_c_cnt * DQA_SINGLE_COMPUTE_SAVE_BLOCKS;
                end
                DQA_SAVE_ADDR_2: begin
                    dqa_save_addr <= dqa_save_addr + dqa_x_load_w_cnt * dqa_w_save_stride_reg;
                end
                DQA_SAVE_ADDR_3: begin
                    dqa_save_addr <= dqa_save_addr + dqa_x_load_h_cnt * dqa_h_save_stride_reg;
                end
                IDLE: begin
                    dqa_save_cnt <= '0;
                end
                default: begin
                    dqa_save_cnt <= '0;
                end
            endcase
        end
    end
    always_comb begin
        gb_addrb = '0;
        gb_enb   = '0;
        gb_web   = '0;
        gb_dinb  = '0;
        if(c_state == DQA_LOAD_X) begin
            gb_addrb = dqa_src_base_word_reg +
                       (dqa_act_mode
                        ? (dqa_int16_mode ? (dqa_x_load_addr_add >> 1) : (dqa_x_load_addr_add >> 2))
                        : dqa_x_load_addr_add);
            gb_enb   = 1'b1;
            gb_web   = '0;
            gb_dinb  = '0;
        end else if(c_state == DQA_SAVE) begin
            gb_addrb = dqa_save_addr + dqa_save_cnt;
            gb_enb   = 1'b1;
            gb_web   = {(VB_BANDWIDTH / 8){1'b1}};
            gb_dinb  = dqa_out_reg[dqa_save_cnt * VB_BANDWIDTH +: VB_BANDWIDTH];
        end
    end

    /* FP2INT ARRAY*/
    localparam   FP_TRAN_LENGTH_IN =  FP_TRAN_NUM * C_INT_WIDTH_IN;
    localparam   FP_TRAN_LENGTH_IN64 = FP_TRAN_NUM * 64;
    localparam   FP_TRAN_LENGTH_FP = FP_TRAN_NUM*FP_WIDTH;
    logic  s_axis_tvalid, m_axis_result_tvalid;
    
    wire  [FP_TRAN_NUM*C_INT_WIDTH_IN-1:0]     s_axis_tdata;
    wire  [FP_TRAN_NUM*64-1:0]                 s_axis_tdata64;
    wire  [FP_TRAN_LENGTH_FP-1:0]         m_axis_result_tdata;
    wire  [FP_TRAN_LENGTH_FP-1:0]         m_axis_result_tdata32;
    wire  [FP_TRAN_LENGTH_FP-1:0]         m_axis_result_tdata64;
    wire                                  m_axis_result_tvalid32;
    wire                                  m_axis_result_tvalid64;
    wire                                  dqa_use_int64_accum = dqa_int16_mode && !dqa_act_mode;
    assign s_axis_tvalid = (c_state == DQA_FP); 
    assign s_axis_tdata = dqa_int_in_reg[dqa_x_tran_cnt << $clog2(FP_TRAN_LENGTH_IN) +:FP_TRAN_LENGTH_IN];
    assign s_axis_tdata64 = dqa_int64_in_reg[dqa_x_tran_cnt << $clog2(FP_TRAN_LENGTH_IN64) +:FP_TRAN_LENGTH_IN64];
    assign m_axis_result_tvalid = dqa_use_int64_accum ? m_axis_result_tvalid64 : m_axis_result_tvalid32;
    assign m_axis_result_tdata  = dqa_use_int64_accum ? m_axis_result_tdata64  : m_axis_result_tdata32;

    logic [FP_CORE_NUM*FP_WIDTH-1:0] dqa_relu_res;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dqa_x_tran_cnt  <= '0;
            dqa_fp_reg <= '0;
            dqa_out_reg <= '0;
        end else begin
            if(c_state == DQA_FP_WAIT && m_axis_result_tvalid) begin
                dqa_x_tran_cnt  <= dqa_x_tran_done ? '0: dqa_x_tran_cnt + 1'b1;
                dqa_fp_reg[dqa_x_tran_cnt << $clog2(FP_TRAN_LENGTH_FP) +: FP_TRAN_LENGTH_FP] <= m_axis_result_tdata;
            end else if(c_state == DQA_COMPUTE_WAIT && fp_res_tvalid) begin
                dqa_out_reg <= dqa_relu_res;
            end else if(c_state == IDLE)begin
                dqa_x_tran_cnt  <= '0;
                dqa_fp_reg <= '0;
                dqa_out_reg <= '0;
            end
        end 
    end


    generate
        if (FP_WIDTH == 16) begin : GEN_FP16
            int32_2_fp16_array #(
                .FP_TRAN_NUM(FP_TRAN_NUM)
            ) int32_2_fp16_array_inst (
                .clk(clk),
                .s_axis_tvalid(s_axis_tvalid && !dqa_use_int64_accum),
                .s_axis_tdata(s_axis_tdata),
                .m_axis_result_tvalid(m_axis_result_tvalid32),
                .m_axis_result_tdata(m_axis_result_tdata32)
            );
            assign m_axis_result_tvalid64 = 1'b0;
            assign m_axis_result_tdata64 = '0;
        end else begin : GEN_FP32
            int32_2_fp32_array #(
                .FP_TRAN_NUM(FP_TRAN_NUM)
            ) int32_2_fp32_array_inst (
                .clk(clk),
                .s_axis_a_tvalid(s_axis_tvalid && !dqa_use_int64_accum),
                .s_axis_a_tdata(s_axis_tdata),
                .m_axis_result_tvalid(m_axis_result_tvalid32),
                .m_axis_result_tdata(m_axis_result_tdata32)
            );
            int64_2_fp32_array #(
                .FP_TRAN_NUM(FP_TRAN_NUM)
            ) int64_2_fp32_array_inst (
                .clk(clk),
                .s_axis_a_tvalid(s_axis_tvalid && dqa_use_int64_accum),
                .s_axis_a_tdata(s_axis_tdata64),
                .m_axis_result_tvalid(m_axis_result_tvalid64),
                .m_axis_result_tdata(m_axis_result_tdata64)
            );
        end
    endgenerate


    wire [ADDR_WIDTH-1:0] dqa_channel_group_count = dqa_src_c_reg >> $clog2(FP_CORE_NUM);
    wire [ADDR_WIDTH-1:0] dqa_scale_bias_group_sel_nxt = dqa_channel_group_count - 1 - dqa_x_load_c_cnt;

    // 注册化 group_sel：打一拍降低 fan-out 路径延迟（fo=16384 → 250MHz timing closure）。
    // 安全性：dqa_x_load_c_cnt 在 DQA_UPDATE 更新，到 DQA_COMPUTE 使用至少相隔 4 个状态，
    // group_sel_r 延迟 1 拍不影响 DQA_COMPUTE 采样的值。
    (* MAX_FANOUT = 64, shreg_extract = "no" *)
    reg [ADDR_WIDTH-1:0] dqa_scale_bias_group_sel;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dqa_scale_bias_group_sel <= '0;
        else        dqa_scale_bias_group_sel <= dqa_scale_bias_group_sel_nxt;
    end

    genvar relu_i;
    generate
        for (relu_i = 0; relu_i < FP_CORE_NUM; relu_i = relu_i + 1) begin : gen_dqa_relu
            localparam int LSB = relu_i * FP_WIDTH;
            wire [FP_WIDTH-1:0] lane = fp_res[LSB +: FP_WIDTH];
            wire lane_negative = lane[FP_WIDTH-1];
            // relu_en=1: max(·,0)；relu_en=0: 线性直通（head 输出层无激活）
            assign dqa_relu_res[LSB +: FP_WIDTH] = (dqa_relu_en && lane_negative) ? {FP_WIDTH{1'b0}} : lane;
        end
    endgenerate

    assign dqa_full_scale_wire = dqa_scale_reg[MAX_CHANNEL_LENGTH - (dqa_scale_bias_group_sel << $clog2(FP_CORE_LENGTH)) - 1 -: FP_CORE_LENGTH];
    assign dqa_full_bias_wire  = dqa_bias_reg [MAX_CHANNEL_LENGTH - (dqa_scale_bias_group_sel << $clog2(FP_CORE_LENGTH)) - 1 -: FP_CORE_LENGTH];


    assign fp_array_tvalid  = (c_state == DQA_COMPUTE)? 1'b1 : 1'b0;
    assign fp_a_tdata       = (c_state == DQA_COMPUTE)? dqa_fp_reg : '0;
    assign fp_b_tdata       = (c_state == DQA_COMPUTE)? dqa_full_scale_wire : '0;
    assign fp_c_tdata       = (c_state == DQA_COMPUTE)? dqa_full_bias_wire : '0;



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
            dqa_src_addr_reg   <= '0;
            dqa_dst_addr_reg   <= '0;
            dqa_scale_addr_reg <= '0;
            dqa_bias_addr_reg  <= '0;
            dqa_src_c_reg      <= '0;
            dqa_src_h_reg      <= '0;
            dqa_src_w_reg      <= '0;
            dqa_w_load_stride_reg <= '0;
            dqa_w_save_stride_reg <= '0;
            dqa_h_load_stride_reg <= '0;
            dqa_h_save_stride_reg <= '0;
            dqa_src_base_word_reg <= '0;
            dqa_dst_base_word_reg <= '0;
            dqa_load_word_stride_reg <= '0;
        end else if (dqa_unit_start && dqa_unit_ready) begin
            dqa_src_addr_reg   <= dqa_src_addr;
            dqa_dst_addr_reg   <= dqa_dst_addr;
            dqa_scale_addr_reg <= dqa_scale_addr;
            dqa_bias_addr_reg  <= dqa_bias_addr;
            dqa_src_c_reg      <= dqa_src_c;
            dqa_src_h_reg      <= dqa_src_h;
            dqa_src_w_reg      <= dqa_src_w;
            // Use input ports (not _reg): NBAs in this block still see pre-latch values.
            dqa_w_load_stride_reg <= (dqa_int16_mode && !dqa_act_mode) ?
                                     ((dqa_src_c >> $clog2(FP_CORE_NUM)) * DQA_SINGLE_COMPUTE_BLOCKS64) :
                                     (dqa_src_c >> $clog2(FP_CORE_NUM));
            // save stride 基于 total_c（tile-sequential 时 > src_c），total_c=0 退化为旧行为
            dqa_w_save_stride_reg <= (dqa_total_c != '0) ?
                                     (dqa_total_c >> $clog2(FP_CORE_NUM)) :
                                     (dqa_src_c   >> $clog2(FP_CORE_NUM));
            dqa_h_load_stride_reg <= dqa_src_w * ((dqa_int16_mode && !dqa_act_mode) ?
                                     ((dqa_src_c >> $clog2(FP_CORE_NUM)) * DQA_SINGLE_COMPUTE_BLOCKS64) :
                                     (dqa_src_c >> $clog2(FP_CORE_NUM)));
            dqa_h_save_stride_reg <= dqa_src_w * ((dqa_total_c != '0) ?
                                     (dqa_total_c >> $clog2(FP_CORE_NUM)) :
                                     (dqa_src_c   >> $clog2(FP_CORE_NUM)));
            dqa_src_base_word_reg <= dqa_src_addr >> BYTE_ADDR_SHIFT;
            dqa_dst_base_word_reg <= dqa_dst_addr >> BYTE_ADDR_SHIFT;
            dqa_load_word_stride_reg <= dqa_act_mode ? 1 :
                                        (dqa_int16_mode ? DQA_SINGLE_COMPUTE_BLOCKS64 :
                                                          DQA_SINGLE_COMPUTE_BLOCKS32);
        end
    end

    always@(*) begin
        n_state = c_state;
        unique case(c_state)
            IDLE: begin
                if(dqa_unit_start) begin
                    n_state = DQA_LOAD_SCALE;
                end
            end
            DQA_LOAD_SCALE: n_state = DQA_WAIT_SCALE;
            DQA_WAIT_SCALE: n_state = dqa_scale_load_done ? DQA_LOAD_BIAS: DQA_LOAD_SCALE;
            DQA_LOAD_BIAS : n_state = DQA_WAIT_BIAS;
            DQA_WAIT_BIAS : n_state = dqa_bias_load_done  ? DQA_LOAD_X : DQA_LOAD_BIAS;
            DQA_UPDATE      : n_state = DQA_LOAD_X;
            DQA_LAOD_ADDR_1 : n_state = DQA_LAOD_ADDR_2;
            DQA_LAOD_ADDR_2 : n_state = DQA_LAOD_ADDR_3;
            DQA_LAOD_ADDR_3 : n_state = DQA_LAOD_ADDR_4;
            DQA_LAOD_ADDR_4 : n_state = DQA_LOAD_X;
            DQA_LOAD_X      : n_state = DQA_WAIT_X;
            DQA_WAIT_X      : n_state = gb_doutb_valid ? (dqa_x_load_block_done ? DQA_FP : DQA_UPDATE)
                                                       : DQA_WAIT_X;
            DQA_FP          : n_state = DQA_FP_WAIT;
            DQA_FP_WAIT     : begin
                if(m_axis_result_tvalid) begin
                    n_state = dqa_x_tran_done ?  DQA_COMPUTE : DQA_FP;
                end else begin
                    n_state = DQA_FP_WAIT;
                end
            end 
            DQA_COMPUTE     : n_state = fp_array_tready? DQA_COMPUTE_WAIT :DQA_COMPUTE;
            DQA_COMPUTE_WAIT        : n_state = fp_res_tvalid ? DQA_SAVE_ADDR_1 : DQA_COMPUTE_WAIT;
            DQA_SAVE_ADDR_1: n_state = DQA_SAVE_ADDR_2;
            DQA_SAVE_ADDR_2: n_state = DQA_SAVE_ADDR_3;
            DQA_SAVE_ADDR_3: n_state = DQA_SAVE;
            DQA_SAVE        : begin
                if(dqa_done && dqa_save_done) begin
                    n_state = IDLE;
                end else begin
                    n_state = dqa_save_done? DQA_UPDATE: DQA_SAVE_ADDR_1;
                end
            end
            default: n_state = IDLE;
            
        endcase

    end


endmodule // dqa_relu_unit
