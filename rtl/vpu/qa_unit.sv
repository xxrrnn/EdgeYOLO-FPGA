`timescale 1ns/1ps
`include "chip_defines.vh"

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
    input   wire                     qa_int16_mode,

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

    localparam QA_FP_BITS        = FP_CORE_NUM * FP_WIDTH;
    localparam FP32_PER_READ     = GB_BANDWIDTH / FP_WIDTH;
    localparam SAVE_DATA_BITS8   = FP_CORE_NUM * 8;
    localparam SAVE_DATA_BITS16  = FP_CORE_NUM * 16;
    localparam SAVES_PER_WORD8   = GB_BANDWIDTH / SAVE_DATA_BITS8;
    localparam SAVES_PER_WORD16  = GB_BANDWIDTH / SAVE_DATA_BITS16;
    localparam MAX_SAVES_PER_WORD = (SAVES_PER_WORD8 > SAVES_PER_WORD16) ? SAVES_PER_WORD8 : SAVES_PER_WORD16;
    localparam SLOT_IDX_BITS     = (MAX_SAVES_PER_WORD <= 1) ? 1 : $clog2(MAX_SAVES_PER_WORD);
    localparam FP_WIDTH_SHIFT    = $clog2(FP_WIDTH);
    localparam GB_BW_SHIFT       = $clog2(GB_BANDWIDTH);
    localparam BYTE_ADDR_SHIFT   = $clog2(GB_BANDWIDTH / 8);

    // 对齐约束：一次 OBUF 读 = FP_CORE_NUM 个 FP32；INT8/INT16 运行时选择打包密度。
    initial begin
        if (GB_BANDWIDTH % SAVE_DATA_BITS8 != 0)
            $error("qa_unit: GB_BANDWIDTH must be multiple of FP_CORE_NUM*8");
        if (GB_BANDWIDTH % SAVE_DATA_BITS16 != 0)
            $error("qa_unit: GB_BANDWIDTH must be multiple of FP_CORE_NUM*16");
        if (FP32_PER_READ != FP_CORE_NUM)
            $error("qa_unit: one OBUF read must carry FP_CORE_NUM FP32 values");
        if (Q_INT_WIDTH_OUT != 8)
            $error("qa_unit: Q_INT_WIDTH_OUT should remain 8; INT16 is selected by qa_int16_mode");
    end

    typedef enum logic [4:0] {
        IDLE,
        QA_PRECOMPUTE_1,
        QA_PRECOMPUTE_2,
        QA_LOAD_SCALE,
        QA_WAIT_SCALE,
        QA_LOAD_X,
        QA_WAIT_X,
        QA_COMPUTE,
        QA_COMPUTE_WAIT,
        QA_INT,
        QA_INT_WAIT,
        QA_SAVE,
        QA_SAVE_HOLD
    } state_t;
    state_t c_state, n_state;

    assign qa_unit_ready = (c_state == IDLE);

    reg [FP_WIDTH - 1 : 0]                            qa_scale_reg;
    localparam QA_OBUF_READ_TIMEOUT = 16;
    reg [4:0]                                           qa_rd_wait_cnt;
    reg [FP_CORE_NUM * FP_WIDTH - 1 : 0]                qa_fp_in_reg;
    reg [FP_CORE_NUM * FP_WIDTH - 1 : 0]                qa_out_q_reg;
    reg [FP_TRAN_NUM*16-1:0]                            qa_quant_pack_data_reg;
    reg [GB_BANDWIDTH-1:0]                              qa_word_buf;

    reg [ADDR_WIDTH - 1 : 0]                            qa_src_addr_reg;
    reg [ADDR_WIDTH - 1 : 0]                            qa_dst_addr_reg;
    reg [ADDR_WIDTH - 1 : 0]                            qa_scale_addr_reg;
    reg [ADDR_WIDTH - 1 : 0]                            qa_src_c_reg;
    reg [ADDR_WIDTH - 1 : 0]                            qa_src_h_reg;
    reg [ADDR_WIDTH - 1 : 0]                            qa_src_w_reg;

    reg [2*ADDR_WIDTH - 1 : 0]                          precompute_ch;
    reg [ADDR_WIDTH - 1 : 0]                            qa_total_iters_reg;
    reg [ADDR_WIDTH - 1 : 0]                            qa_iter_cnt;
    reg [ADDR_WIDTH - 1 : 0]                            qa_x_tran_cnt;
    reg [3:0]                                           qa_int_wait_cnt;

    wire [ADDR_WIDTH - 1 : 0]                           qa_x_load_addr;
    wire [SLOT_IDX_BITS-1:0]                            pack_slot;
    wire [ADDR_WIDTH - 1 : 0]                           qa_out_word_idx;
    wire                                                pack_word_done;
    wire                                                qa_x_tran_done;
    wire                                                qa_done;
    wire [GB_ADDR_WIDTH-1:0]                            qa_obuf_write_addr;
    wire [SLOT_IDX_BITS-1:0]                            saves_per_word_active;
    wire [6:0]                                          save_data_bits_active;

    assign saves_per_word_active = qa_int16_mode ? SAVES_PER_WORD16[SLOT_IDX_BITS-1:0] : SAVES_PER_WORD8[SLOT_IDX_BITS-1:0];
    assign save_data_bits_active = qa_int16_mode ? 7'd64 : 7'd32;
    assign pack_slot        = qa_int16_mode ? {{(SLOT_IDX_BITS-1){1'b0}}, qa_iter_cnt[0]}
                                            : qa_iter_cnt[1:0];
    assign qa_out_word_idx  = qa_int16_mode ? (qa_iter_cnt >> 1) : (qa_iter_cnt >> 2);
    assign pack_word_done   = (pack_slot == saves_per_word_active - 1'b1);
    assign qa_x_tran_done   = (qa_x_tran_cnt == (FP_CORE_NUM / FP_TRAN_NUM) - 1);
    assign qa_done          = (c_state == QA_SAVE_HOLD) && (qa_iter_cnt == qa_total_iters_reg - 1);
    assign qa_x_load_addr   = (qa_src_addr_reg >> BYTE_ADDR_SHIFT) + qa_iter_cnt;
    assign qa_obuf_write_addr = (qa_dst_addr_reg >> BYTE_ADDR_SHIFT) + qa_out_word_idx;

    logic                               s_axis_tvalid;
    wire                                m_axis_int8_tvalid;
    wire                                m_axis_int16_tvalid;
    wire                                m_axis_int_tvalid;
    wire [FP_TRAN_NUM*FP_WIDTH-1:0]     s_axis_tdata;
    wire [FP_TRAN_NUM*8-1:0]            m_axis_int8_tdata;
    wire [FP_TRAN_NUM*16-1:0]           m_axis_int16_tdata;
    wire [FP_TRAN_NUM*16-1:0]           m_axis_int_tdata;

    assign m_axis_int_tvalid = qa_int16_mode ? m_axis_int16_tvalid : m_axis_int8_tvalid;
    assign m_axis_int_tdata  = qa_int16_mode ? m_axis_int16_tdata : {{(FP_TRAN_NUM*8){1'b0}}, m_axis_int8_tdata};

    assign wb_addrb = (c_state == QA_LOAD_SCALE) ? (qa_scale_addr_reg >> BYTE_ADDR_SHIFT) : '0;
    assign wb_enb   = (c_state == QA_LOAD_SCALE) ? 1'b1 : 1'b0;
    assign wb_web   = '0;
    assign wb_dinb  = '0;

    wire [ADDR_WIDTH-1:0] qa_scale_block_index;
    assign qa_scale_block_index = qa_scale_addr_reg[BYTE_ADDR_SHIFT-1:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            qa_scale_reg <= '0;
        else if (c_state == QA_WAIT_SCALE)
            qa_scale_reg <= wb_doutb[qa_scale_block_index * FP_WIDTH +: FP_WIDTH];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qa_iter_cnt            <= '0;
            qa_total_iters_reg     <= '0;
            precompute_ch          <= '0;
        end else if (c_state == IDLE && qa_unit_start) begin
            qa_iter_cnt <= '0;
        end else if (c_state == QA_PRECOMPUTE_1) begin
            precompute_ch <= qa_src_c_reg * qa_src_h_reg;
        end else if (c_state == QA_PRECOMPUTE_2) begin
            precompute_ch <= precompute_ch * qa_src_w_reg;
        end else if (c_state == QA_LOAD_SCALE) begin
            qa_total_iters_reg <= (precompute_ch + FP_CORE_NUM - 1) / FP_CORE_NUM;
        end else if (c_state == QA_INT_WAIT && m_axis_int_tvalid && !pack_word_done) begin
            qa_iter_cnt <= qa_iter_cnt + 1'b1;
        end else if (c_state == QA_SAVE_HOLD) begin
            qa_iter_cnt <= qa_iter_cnt + 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qa_fp_in_reg     <= '0;
            qa_rd_wait_cnt   <= '0;
            qa_word_buf      <= '0;
        end else begin
            case (c_state)
                IDLE: begin
                    qa_rd_wait_cnt <= '0;
                    qa_word_buf    <= '0;
                end
                QA_WAIT_X: begin
                    if (gb_doutb_valid) begin
                        qa_rd_wait_cnt <= '0;
                        if (FP_CORE_NUM * FP_WIDTH > GB_BANDWIDTH)
                            qa_fp_in_reg <= {gb_doutb, qa_fp_in_reg[FP_CORE_NUM * FP_WIDTH - 1 : GB_BANDWIDTH]};
                        else
                            qa_fp_in_reg <= gb_doutb[FP_CORE_NUM * FP_WIDTH - 1 : 0];
                    end else if (qa_rd_wait_cnt == QA_OBUF_READ_TIMEOUT) begin
                        $display("[qa] OBUF READ TIMEOUT word_addr=0x%0h iter=%0d valid=%0b",
                                 qa_x_load_addr, qa_iter_cnt, gb_doutb_valid);
                        qa_rd_wait_cnt <= '0;
                    end else begin
                        qa_rd_wait_cnt <= qa_rd_wait_cnt + 1'b1;
                    end
                end
                QA_INT_WAIT: begin
                    if (m_axis_int_tvalid) begin
                        qa_quant_pack_data_reg <= m_axis_int_tdata;
                        if (qa_int16_mode)
                            qa_word_buf[pack_slot * 64 +: 64] <= m_axis_int_tdata[63:0];
                        else
                            qa_word_buf[pack_slot * 32 +: 32] <= m_axis_int_tdata[31:0];
                    end
                end
                default: ;
            endcase
        end
    end

    always_comb begin
        gb_addrb = '0;
        gb_enb   = '0;
        gb_web   = '0;
        gb_dinb  = '0;

        unique case (c_state)
            QA_LOAD_X: begin
                gb_addrb = qa_x_load_addr;
                gb_enb   = 1'b1;
                gb_web   = '0;
            end
            QA_SAVE, QA_SAVE_HOLD: begin
                gb_addrb = qa_obuf_write_addr;
                gb_enb   = 1'b1;
                gb_web   = {GB_BANDWIDTH/8{1'b1}};
                gb_dinb  = qa_word_buf;
            end
            default: ;
        endcase
    end

    assign fp_array_tvalid = (c_state == QA_COMPUTE);
    assign fp_a_tdata      = (c_state == QA_COMPUTE) ? qa_fp_in_reg : '0;
    assign fp_b_tdata      = (c_state == QA_COMPUTE) ? {FP_CORE_NUM{qa_scale_reg}} : '0;
    assign fp_c_tdata      = '0;

    assign s_axis_tvalid = (c_state == QA_INT);
    assign s_axis_tdata  = qa_out_q_reg[qa_x_tran_cnt * FP_TRAN_NUM * FP_WIDTH +: FP_TRAN_NUM * FP_WIDTH];

    fp32_2_int8_array #(
        .FP_TRAN_NUM(FP_TRAN_NUM)
    ) fp32_2_int8_array_inst (
        .clk(clk),
        .s_axis_a_tvalid(s_axis_tvalid && !qa_int16_mode),
        .s_axis_a_tdata(s_axis_tdata),
        .m_axis_result_tdata(m_axis_int8_tdata),
        .m_axis_result_tvalid(m_axis_int8_tvalid)
    );

    fp32_2_int16_array #(
        .FP_TRAN_NUM(FP_TRAN_NUM)
    ) fp32_2_int16_array_inst (
        .clk(clk),
        .s_axis_a_tvalid(s_axis_tvalid && qa_int16_mode),
        .s_axis_a_tdata(s_axis_tdata),
        .m_axis_result_tdata(m_axis_int16_tdata),
        .m_axis_result_tvalid(m_axis_int16_tvalid)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            qa_out_q_reg <= '0;
        else if (c_state == IDLE)
            qa_out_q_reg <= '0;
        else if (c_state == QA_COMPUTE_WAIT && fp_res_tvalid)
            qa_out_q_reg <= fp_res;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            qa_x_tran_cnt   <= '0;
            qa_int_wait_cnt <= '0;
        end else if (c_state == IDLE) begin
            qa_x_tran_cnt   <= '0;
            qa_int_wait_cnt <= '0;
        end else if (c_state == QA_INT) begin
            qa_int_wait_cnt <= '0;
        end else if (c_state == QA_INT_WAIT) begin
            qa_int_wait_cnt <= qa_int_wait_cnt + 1'b1;
            if (m_axis_int_tvalid)
                qa_x_tran_cnt <= qa_x_tran_done ? '0 : qa_x_tran_cnt + 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            c_state <= IDLE;
        else
            c_state <= n_state;
    end

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
`ifdef PROBE_QA
            $display("[qa] START src=0x%08h dst=0x%08h scale=0x%08h c=%0d h=%0d w=%0d int16=%0d saves_per_word=%0d",
                     qa_src_addr, qa_dst_addr, qa_scale_addr, qa_src_c, qa_src_h, qa_src_w, qa_int16_mode, saves_per_word_active);
`endif
        end
    end

    reg [15:0] qa_dbg_cycle_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            qa_dbg_cycle_cnt <= '0;
        else if (c_state == IDLE)
            qa_dbg_cycle_cnt <= '0;
        else begin
            qa_dbg_cycle_cnt <= qa_dbg_cycle_cnt + 1'b1;
            if (c_state == QA_SAVE_HOLD && qa_done) begin
`ifdef PROBE_QA
                $display("[qa] DONE iter=%0d/%0d out_words=%0d",
                         qa_iter_cnt, qa_total_iters_reg, qa_out_word_idx);
`endif
            end else if (c_state == QA_WAIT_X && qa_rd_wait_cnt[3:0] == 4'h0) begin
`ifdef PROBE_QA
                $display("[qa] WAIT_X in_word=0x%0h slot=%0d/%0d valid=%0b",
                         qa_x_load_addr, pack_slot, saves_per_word_active, gb_doutb_valid);
`endif
            end
        end
    end

    always @(*) begin
        n_state = c_state;
        unique case (c_state)
            IDLE: begin
                if (qa_unit_start)
                    n_state = QA_PRECOMPUTE_1;
            end
            QA_PRECOMPUTE_1: n_state = QA_PRECOMPUTE_2;
            QA_PRECOMPUTE_2: n_state = QA_LOAD_SCALE;
            QA_LOAD_SCALE:   n_state = QA_WAIT_SCALE;
            QA_WAIT_SCALE:   n_state = QA_LOAD_X;
            QA_LOAD_X:       n_state = QA_WAIT_X;
            QA_WAIT_X:       n_state = gb_doutb_valid ? QA_COMPUTE : QA_WAIT_X;
            QA_COMPUTE:      n_state = fp_array_tready ? QA_COMPUTE_WAIT : QA_COMPUTE;
            QA_COMPUTE_WAIT: n_state = fp_res_tvalid ? QA_INT : QA_COMPUTE_WAIT;
            QA_INT:          n_state = QA_INT_WAIT;
            QA_INT_WAIT:     n_state = m_axis_int_tvalid
                                ? (pack_word_done ? QA_SAVE : QA_LOAD_X)
                                : QA_INT_WAIT;
            QA_SAVE:         n_state = QA_SAVE_HOLD;
            QA_SAVE_HOLD:    n_state = qa_done ? IDLE : QA_LOAD_X;
            default:         n_state = IDLE;
        endcase
    end

endmodule
