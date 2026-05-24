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

    output reg [WB_ADDR_WIDTH-1:0]      wb_addrb,
    output reg [WB_BANDWIDTH-1:0]       wb_dinb,
    output reg [WB_BANDWIDTH/8-1:0]     wb_web,
    output reg                          wb_enb,
    input wire [WB_BANDWIDTH-1:0]       wb_doutb
);

    localparam  qa_single_compute_blocks      = (FP_CORE_NUM * FP_WIDTH / GB_BANDWIDTH) ;
    localparam  qa_single_compute_save_blocks = (FP_CORE_NUM * Q_INT_WIDTH_OUT + GB_BANDWIDTH - 1) / GB_BANDWIDTH;
    localparam  FP_WIDTH_SHIFT = $clog2(FP_WIDTH);
    localparam  GB_BW_SHIFT    = $clog2(GB_BANDWIDTH);
    localparam  BYTE_ADDR_SHIFT = $clog2(GB_BANDWIDTH / 8);  // 字节地址到 word 地址的移位量


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
    
    // OBUF read latency counter
    reg [4:0] qa_rd_wait_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) qa_rd_wait_cnt <= 0;
        else if (c_state == QA_LOAD_X) qa_rd_wait_cnt <= qa_rd_wait_cnt + 1;
        else qa_rd_wait_cnt <= 0;
    end
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              qa_fp_in_reg;
    reg     [FP_CORE_NUM * FP_WIDTH - 1 : 0]              qa_out_q_reg;
    reg     [FP_CORE_NUM * Q_INT_WIDTH_OUT - 1 : 0]       qa_out_int_reg;
    
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
    assign  qa_save_done                            = 1'b1;  // 每次 SAVE 只写 1 个 word，1 周期完成
    assign  qa_x_load_done                          = (qa_x_load_cnt == qa_x_load_done_threshold);
    assign  qa_x_tran_done                          = (qa_x_tran_cnt == (FP_CORE_NUM / FP_TRAN_NUM)- 1);
    assign  qa_done                                 =  qa_x_load_done & qa_save_done;

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
            qa_x_total_blocks_reg  <= '0;
            qa_x_load_done_threshold <= '0;
            precompute_ch          <= '0;
        end else if (c_state == IDLE && qa_unit_start) begin
            qa_x_load_block_cnt    <= '0;
            qa_x_load_cnt          <= '0;
        end else if (c_state == QA_PRECOMPUTE_1) begin
            precompute_ch          <= qa_src_c_reg * qa_src_h_reg;
        end else if (c_state == QA_PRECOMPUTE_2) begin
            precompute_ch          <= precompute_ch * qa_src_w_reg;
        end else if (c_state == QA_LOAD_SCALE) begin
            automatic logic [2*ADDR_WIDTH-1:0] total_bits;
            total_bits = precompute_ch << FP_WIDTH_SHIFT;
            qa_x_total_blocks_reg    <= total_bits[ADDR_WIDTH-1:0] >> GB_BW_SHIFT;
            qa_x_load_done_threshold <= (total_bits[ADDR_WIDTH-1:0] >> GB_BW_SHIFT) - qa_single_compute_blocks;
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

    /*  X LOAD   */
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
                    // 修复：当 FP_CORE_NUM*FP_WIDTH <= GB_BANDWIDTH 时，直接赋值
                    // 当 FP_CORE_NUM*FP_WIDTH > GB_BANDWIDTH 时，拼接并右移
                    if (FP_CORE_NUM * FP_WIDTH > GB_BANDWIDTH)
                        qa_fp_in_reg <= {gb_doutb, qa_fp_in_reg[FP_CORE_NUM * FP_WIDTH - 1 : GB_BANDWIDTH]};
                    else
                        qa_fp_in_reg <= gb_doutb[FP_CORE_NUM * FP_WIDTH - 1 : 0];
                end
                QA_SAVE: begin
                    qa_save_cnt <= qa_save_cnt + 1;
                end
                default: begin
                    qa_save_cnt <= '0;
                end
            endcase
        end
    end

    // Pack writer BRAM interface (forward declaration)
    wire                         pack_wr_en;
    wire [GB_ADDR_WIDTH-1:0]     pack_wr_addr;
    wire [GB_BANDWIDTH-1:0]      pack_wr_data;
    wire [GB_BANDWIDTH/8-1:0]    pack_wr_we;

    always_comb begin
        gb_addrb = '0;
        gb_enb   = '0;
        gb_web   = '0;
        gb_dinb  = '0;

        // Pack writer 最高优先级（可能在任何状态触发写入）
        if (pack_wr_en) begin
            gb_addrb = pack_wr_addr;
            gb_dinb  = pack_wr_data;
            gb_web   = pack_wr_we;
            gb_enb   = 1'b1;
        end else if(c_state == QA_LOAD_X) begin
            gb_addrb = qa_x_load_addr;
            gb_enb   = 1'b1;
            gb_web   = '0;
            gb_dinb  = '0;
        end
    end

    localparam [FP_WIDTH-1:0] QA_UINT8_ZERO_POINT_FP32 = 32'hc3000000;  // -128.0f

    assign fp_array_tvalid  = (c_state == QA_COMPUTE)? 1'b1 : 1'b0;
    assign fp_a_tdata       = (c_state == QA_COMPUTE)? qa_fp_in_reg: '0;
    assign fp_b_tdata       = (c_state == QA_COMPUTE)? {FP_CORE_NUM{qa_scale_reg}} : '0;
    // Convert unsigned clamp [0,255] using signed INT8 converter:
    //   signed_q = clamp(round(dqa*qscale - 128), -128, 127)
    //   uint8_q  = signed_q + 128 (applied below as XOR 0x80 per byte)
    assign fp_c_tdata       = (c_state == QA_COMPUTE)? {FP_CORE_NUM{QA_UINT8_ZERO_POINT_FP32}} : '0;


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

    function automatic [7:0] qa_uint8_round_fp32;
        input [31:0] signed_fp;
        reg sign;
        reg [7:0] exp;
        reg [23:0] mant;
        integer e;
        integer shift;
        integer rounded_abs;
        integer int_part;
        integer frac_part;
        integer threshold;
        begin
            sign = signed_fp[31];
            exp  = signed_fp[30:23];
            mant = {1'b1, signed_fp[22:0]};

            if (exp == 0) begin
                rounded_abs = 0;
            end else begin
                e = exp - 127;
                if (e < -1) begin
                    rounded_abs = 0;
                end else if (e < 0) begin
                    rounded_abs = 1;  // |x| >= 0.5
                end else if (e >= 8) begin
                    rounded_abs = 256;
                end else begin
                    shift = 23 - e;
                    int_part = mant >> shift;
                    frac_part = mant & ((1 << shift) - 1);
                    threshold = 1 << (shift - 1);
                    rounded_abs = int_part + ((frac_part >= threshold) ? 1 : 0);
                end
            end

            // signed_fp is (dqa*qscale - 128.0). Convert rounded signed value
            // back to UINT8 with clamp.
            if (sign) begin
                if (rounded_abs >= 128) qa_uint8_round_fp32 = 8'h00;
                else                    qa_uint8_round_fp32 = 8'((128 - rounded_abs) & 8'hff);
            end else begin
                if (rounded_abs >= 127) qa_uint8_round_fp32 = 8'hff;
                else                    qa_uint8_round_fp32 = 8'((128 + rounded_abs) & 8'hff);
            end
        end
    endfunction

    // Combinational UINT8 quantization for current tran slice.
    // qa_out_q_reg holds FP_CORE_NUM FP32 values; slice [qa_x_tran_cnt*FP_TRAN_NUM : +FP_TRAN_NUM]
    // and convert each lane to UINT8 using qa_uint8_round_fp32.
    reg [FP_TRAN_NUM*Q_INT_WIDTH_OUT-1:0] qa_quant_pack_data;
    always_comb begin
        integer qi;
        for (qi = 0; qi < FP_TRAN_NUM; qi = qi + 1) begin
            qa_quant_pack_data[qi*Q_INT_WIDTH_OUT +: Q_INT_WIDTH_OUT] =
                qa_uint8_round_fp32(qa_out_q_reg[
                    (qa_x_tran_cnt * FP_TRAN_NUM + qi) * FP_WIDTH +: FP_WIDTH]);
        end
    end

    // Pipeline register to break timing: QA_INT latches the combinational result,
    // QA_SAVE uses the registered value. This cuts the 23-level comb path in half.
    reg [FP_TRAN_NUM*Q_INT_WIDTH_OUT-1:0] qa_quant_pack_data_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            qa_quant_pack_data_reg <= '0;
        else if (c_state == QA_INT)
            qa_quant_pack_data_reg <= qa_quant_pack_data;
    end

    // INT8 conversion result capture (debug/legacy mirror; pack writer uses qa_quant_pack_data directly)
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            qa_x_tran_cnt <= '0;
            qa_out_int_reg <= '0;
            qa_int_wait_cnt <= '0;
        end else if(c_state == IDLE) begin
            qa_x_tran_cnt <= '0;
            qa_out_int_reg <= '0;
            qa_int_wait_cnt <= '0;
        end else if(c_state == QA_INT) begin
            qa_int_wait_cnt <= '0;
        end else if(c_state == QA_INT_WAIT) begin
            qa_int_wait_cnt <= qa_int_wait_cnt + 1'b1;
            if(m_axis_int_tvalid) begin
                qa_x_tran_cnt  <= qa_x_tran_done ? '0 : qa_x_tran_cnt + 1'b1;
                qa_out_int_reg[qa_x_tran_cnt * FP_TRAN_NUM * Q_INT_WIDTH_OUT +: FP_TRAN_NUM * Q_INT_WIDTH_OUT]
                    <= qa_quant_pack_data;
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
            QA_LOAD_X       : n_state  = (qa_rd_wait_cnt >= 9) ? QA_WAIT_X : QA_LOAD_X;
            QA_WAIT_X       : n_state  = qa_x_load_block_done ? QA_COMPUTE : QA_UPDATE;
            QA_COMPUTE      : n_state  = fp_array_tready? QA_COMPUTE_WAIT :QA_COMPUTE;
            QA_COMPUTE_WAIT : n_state  = fp_res_tvalid ? QA_INT : QA_COMPUTE_WAIT;
            QA_INT          : n_state = QA_SAVE;
            QA_INT_WAIT     : n_state = QA_SAVE;
            QA_SAVE        : begin
                if(qa_done) begin
                    n_state = IDLE;
                end else begin
                    n_state = qa_save_done? QA_UPDATE: QA_SAVE;
                end
            end
            default: n_state = IDLE;
            
        endcase

    end

    // =========================================================================
    // INT8 Pack Writer
    // =========================================================================

    int8_pack_writer #(
        .GB_BANDWIDTH(GB_BANDWIDTH),
        .GB_ADDR_WIDTH(GB_ADDR_WIDTH),
        .PACK_WIDTH(FP_CORE_NUM * Q_INT_WIDTH_OUT)
    ) u_pack_writer (
        .clk(clk),
        .rst_n(rst_n),
        .pack_valid(c_state == QA_SAVE),
        .pack_data(qa_quant_pack_data_reg),
        .pack_base_addr(qa_dst_addr_reg >> BYTE_ADDR_SHIFT),
        .pack_last(qa_done),
        .pack_reset(c_state == IDLE),
        .bram_addr(pack_wr_addr),
        .bram_din(pack_wr_data),
        .bram_we(pack_wr_we),
        .bram_en(pack_wr_en),
        .pack_ready()
    );


endmodule
