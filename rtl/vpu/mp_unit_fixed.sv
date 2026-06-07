`timescale 1ns / 1ps
`include "chip_defines.vh"
//==============================================================================
// mp_unit_fixed - 可配置 MaxPool / Global Average Pool 单元
//==============================================================================
// MODE 由 mp_cfg[1:0] 选择 (通过 VPU_EXEC addr_break[1:0] 传入):
//   MP_MODE_SPPF  (0): MaxPool 5×5 s1 p2  (YOLOv5n SPPF, 典型 10×10×128)
//   MP_MODE_MP3S2 (1): MaxPool 3×3 s2 p1  (ResNet18 stem, 典型 112×112×64)
//   MP_MODE_GAP   (2): Global Average Pool (ResNet18 final, 典型 7×7×512)
//
// GAP 输出 per-lane FP32 SUM，host 读回后 / H*W 得 MEAN。
// FP32 SUM 通过 fp32_add IP (LATENCY=3) 顺序累加完成。
//
// 接口：
//   mp_src_h/w/c  : 运行时输入尺寸（由指令传入）
//   mp_cfg        : addr_break[1:0] = MODE
//==============================================================================

module mp_unit_fixed #(
    parameter ADDR_WIDTH    = 32,
    parameter GB_BANDWIDTH  = 128,
    parameter GB_ADDR_WIDTH = 32,
    parameter FP_WIDTH      = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          mp_unit_start,
    output wire                          mp_unit_ready,

    input  wire [ADDR_WIDTH-1:0]         mp_src_addr,
    input  wire [ADDR_WIDTH-1:0]         mp_dst_addr,
    input  wire [ADDR_WIDTH-1:0]         mp_src_c,
    input  wire [ADDR_WIDTH-1:0]         mp_src_h,
    input  wire [ADDR_WIDTH-1:0]         mp_src_w,
    input  wire [ADDR_WIDTH-1:0]         mp_cfg,      // [1:0] = MODE

    output logic [GB_ADDR_WIDTH-1:0]     gb_addrb,
    output logic [GB_BANDWIDTH-1:0]      gb_dinb,
    output logic [GB_BANDWIDTH/8-1:0]    gb_web,
    output logic                         gb_enb,
    input  wire  [GB_BANDWIDTH-1:0]      gb_doutb,
    input  wire                          gb_doutb_valid
);

    // =========================================================================
    // 常量
    // =========================================================================
    localparam LANES           = GB_BANDWIDTH / FP_WIDTH;        // 4
    localparam BYTE_ADDR_SHIFT = $clog2(GB_BANDWIDTH / 8);       // 4
    localparam [FP_WIDTH-1:0] FP32_NEG_INF = 32'hFF80_0000;
    localparam FP32_ZERO       = 32'h0000_0000;

    localparam [1:0] MP_MODE_SPPF  = 2'd0;
    localparam [1:0] MP_MODE_MP3S2 = 2'd1;
    localparam [1:0] MP_MODE_GAP   = 2'd2;

    // fp32_add latency
    localparam FP32_ADD_LAT = 3;

    // =========================================================================
    // 运行时配置寄存器
    // =========================================================================
    reg [ADDR_WIDTH-1:0]  src_h_r, src_w_r, src_c_r;
    reg [ADDR_WIDTH-1:0]  out_h_r, out_w_r;
    reg [ADDR_WIDTH-1:0]  c_blocks_r;          // ceil(C / LANES)
    reg [ADDR_WIDTH-1:0]  gap_total_r;          // H * W (for GAP)
    reg [ADDR_WIDTH-1:0]  src_base_word, dst_base_word;
    reg [1:0]             mode_r;
    reg [3:0]             kernel_r;
    reg [1:0]             stride_r;
    (* max_fanout = 32 *) reg [2:0] pad_r;

    // =========================================================================
    // 状态机
    // =========================================================================
    typedef enum logic [4:0] {
        S_IDLE, S_INIT, S_PRECOMPUTE,
        S_LOAD_REQ,
        S_LOAD_WAIT,
        S_LOAD_CMP,
        S_GAP_ADD_WAIT,
        S_SAVE,
        S_NEXT_KER,
        S_NEXT_CB,
        S_NEXT_POS,
        S_DONE
    } state_t;
    state_t state;
    assign mp_unit_ready = (state == S_IDLE);

    // =========================================================================
    // 循环计数器
    // =========================================================================
    reg [6:0]  oh_cnt, ow_cnt;     // 最大 OH/OW = 56 (ResNet layer2 input)
    reg [9:0]  cb_cnt;              // ceil(512/4)=128
    reg [2:0]  kh_cnt, kw_cnt;     // max kernel = 5
    reg [13:0] gap_pos_cnt;         // max 112*112=12544

    // =========================================================================
    // 预算步长寄存器（S_INIT/S_PRECOMPUTE 计算，循环中纯加减）
    // =========================================================================
    // S_INIT
    reg [ADDR_WIDTH-1:0] row_stride_r;      // = src_w * c_blocks
    // gap_total_r 已在配置寄存器区（line 66）声明，此处不重复
    // S_PRECOMPUTE
    reg [ADDR_WIDTH-1:0] src_stride_row_r;  // = stride * row_stride
    reg [ADDR_WIDTH-1:0] src_stride_col_r;  // = stride * c_blocks
    reg [ADDR_WIDTH-1:0] pad_row_off_r;     // = pad * row_stride
    reg [ADDR_WIDTH-1:0] pad_col_off_r;     // = pad * c_blocks
    reg [ADDR_WIDTH-1:0] src_pad_total_r;   // = pad_row_off + pad_col_off
    reg [ADDR_WIDTH-1:0] dst_stride_row_r;  // = out_w * c_blocks

    // =========================================================================
    // 运行时加法增量寄存器（纯加减，无乘法路径）
    // =========================================================================
    reg [ADDR_WIDTH-1:0] src_oh_acc;   // = oh * stride * row_stride
    reg [ADDR_WIDTH-1:0] src_kh_acc;   // = kh * row_stride
    reg [ADDR_WIDTH-1:0] src_ow_acc;   // = ow * stride * c_blocks
    reg [ADDR_WIDTH-1:0] src_kw_acc;   // = kw * c_blocks
    reg [ADDR_WIDTH-1:0] dst_oh_acc;   // = oh * dst_stride_row
    reg [ADDR_WIDTH-1:0] dst_ow_acc;   // = ow * c_blocks
    reg [7:0]            ih_oh_base;   // = oh * stride  (bounds check)
    reg [7:0]            iw_ow_base;   // = ow * stride  (bounds check)
    reg [ADDR_WIDTH-1:0] gap_pos_acc;  // = gap_pos * c_blocks

    // =========================================================================
    // MaxPool bounds（纯加减，小整数）
    // =========================================================================
    wire signed [8:0] ih_r = $signed({1'b0, ih_oh_base}) + $signed({5'b0, kh_cnt}) - $signed({6'b0, pad_r});
    wire signed [8:0] iw_r = $signed({1'b0, iw_ow_base}) + $signed({5'b0, kw_cnt}) - $signed({6'b0, pad_r});
    wire in_bounds = (ih_r >= 0) && (ih_r < $signed({1'b0, src_h_r[7:0]}))
                  && (iw_r >= 0) && (iw_r < $signed({1'b0, src_w_r[7:0]}));

    // 组合地址（纯加减，无乘法）
    wire [ADDR_WIDTH-1:0] mp_load_addr = src_base_word
        + src_oh_acc + src_kh_acc + src_ow_acc + src_kw_acc
        - src_pad_total_r + cb_cnt;
    wire [ADDR_WIDTH-1:0] mp_save_addr  = dst_base_word + dst_oh_acc + dst_ow_acc + cb_cnt;
    wire [ADDR_WIDTH-1:0] gap_load_addr = src_base_word + gap_pos_acc + cb_cnt;
    wire [ADDR_WIDTH-1:0] gap_save_addr = dst_base_word + cb_cnt;

    reg  [GB_BANDWIDTH-1:0] max_reg;
    reg                      first_valid;

    wire [GB_BANDWIDTH-1:0] new_data = in_bounds ? gb_doutb : {LANES{FP32_NEG_INF}};
    wire [GB_BANDWIDTH-1:0] max_result;

    genvar gi;
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : gen_cmp
            wire [FP_WIDTH-1:0] a = max_reg[gi*FP_WIDTH +: FP_WIDTH];
            wire [FP_WIDTH-1:0] b = new_data[gi*FP_WIDTH +: FP_WIDTH];
            wire [FP_WIDTH-1:0] a_key = a[31] ? ~a : {1'b1, a[30:0]};
            wire [FP_WIDTH-1:0] b_key = b[31] ? ~b : {1'b1, b[30:0]};
            assign max_result[gi*FP_WIDTH +: FP_WIDTH] =
                first_valid ? b : (b_key > a_key) ? b : a;
        end
    endgenerate

    // =========================================================================
    // GAP FP32 累加（fp32_add IP，LANES 个并行实例）
    // =========================================================================
    wire                      fp_add_valid_in;
    wire [LANES*FP_WIDTH-1:0] fp_add_a, fp_add_b;
    wire [LANES*FP_WIDTH-1:0] fp_add_result;
    wire [LANES-1:0]          fp_add_valid_out;

    reg  [GB_BANDWIDTH-1:0]   acc_reg;
    reg  [3:0]                 gap_add_wait;  // latency counter

    assign fp_add_valid_in = (state == S_LOAD_CMP) && (mode_r == MP_MODE_GAP);
    assign fp_add_a        = acc_reg;
    assign fp_add_b        = gb_doutb;

    genvar gj;
    generate
        for (gj = 0; gj < LANES; gj = gj + 1) begin : gen_gap_add
            fp32_add fp_add_inst (
                .aclk                (clk),
                .s_axis_a_tvalid     (fp_add_valid_in),
                .s_axis_a_tdata      (fp_add_a[gj*FP_WIDTH +: FP_WIDTH]),
                .s_axis_b_tvalid     (fp_add_valid_in),
                .s_axis_b_tdata      (fp_add_b[gj*FP_WIDTH +: FP_WIDTH]),
                .m_axis_result_tvalid(fp_add_valid_out[gj]),
                .m_axis_result_tdata (fp_add_result[gj*FP_WIDTH +: FP_WIDTH])
            );
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) acc_reg <= '0;
        else if (state == S_IDLE && mp_unit_start) acc_reg <= '0;
        else if (state == S_NEXT_CB && (cb_cnt != c_blocks_r - 1)) acc_reg <= '0;
        else if (state == S_GAP_ADD_WAIT && fp_add_valid_out[0])
            acc_reg <= fp_add_result;
    end

    // =========================================================================
    // 状态机主逻辑
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            oh_cnt <= '0; ow_cnt <= '0; cb_cnt <= '0;
            kh_cnt <= '0; kw_cnt <= '0; gap_pos_cnt <= '0;
            max_reg <= '0; first_valid <= 1'b1;
            gap_add_wait <= '0;
            src_base_word <= '0; dst_base_word <= '0;
            src_h_r <= '0; src_w_r <= '0; src_c_r <= '0;
            out_h_r <= '0; out_w_r <= '0; c_blocks_r <= '0;
            kernel_r <= '0; stride_r <= '0; pad_r <= '0;
            gap_total_r <= '0; mode_r <= '0;
            row_stride_r <= '0; src_stride_row_r <= '0; src_stride_col_r <= '0;
            pad_row_off_r <= '0; pad_col_off_r <= '0; src_pad_total_r <= '0;
            dst_stride_row_r <= '0;
            src_oh_acc <= '0; src_kh_acc <= '0; src_ow_acc <= '0; src_kw_acc <= '0;
            dst_oh_acc <= '0; dst_ow_acc <= '0;
            ih_oh_base <= '0; iw_ow_base <= '0; gap_pos_acc <= '0;
            gb_addrb <= '0; gb_dinb <= '0; gb_web <= '0; gb_enb <= 1'b0;
        end else begin
            gb_enb <= 1'b0; gb_web <= '0;

            case (state)
                // ---------------------------------------------------------
                S_IDLE: begin
                    if (mp_unit_start) begin
                        src_base_word <= mp_src_addr >> BYTE_ADDR_SHIFT;
                        dst_base_word <= mp_dst_addr >> BYTE_ADDR_SHIFT;
                        src_h_r <= mp_src_h; src_w_r <= mp_src_w; src_c_r <= mp_src_c;
                        mode_r  <= mp_cfg[1:0];
                        c_blocks_r <= (mp_src_c + LANES - 1) / LANES;

                        case (mp_cfg[1:0])
                            MP_MODE_SPPF: begin
                                kernel_r <= 4'd5; stride_r <= 2'd1; pad_r <= 3'd2;
                                out_h_r  <= mp_src_h; out_w_r <= mp_src_w;
                            end
                            MP_MODE_MP3S2: begin
                                kernel_r <= 4'd3; stride_r <= 2'd2; pad_r <= 3'd1;
                                out_h_r  <= (mp_src_h + 2 - 3) / 2 + 1;
                                out_w_r  <= (mp_src_w + 2 - 3) / 2 + 1;
                            end
                            MP_MODE_GAP: begin
                                kernel_r <= '0; stride_r <= '0; pad_r <= '0;
                                out_h_r  <= 1; out_w_r <= 1;
                            end
                            default: begin
                                kernel_r <= 4'd5; stride_r <= 2'd1; pad_r <= 3'd2;
                                out_h_r  <= mp_src_h; out_w_r <= mp_src_w;
                            end
                        endcase

                        oh_cnt <= '0; ow_cnt <= '0; cb_cnt <= '0;
                        kh_cnt <= '0; kw_cnt <= '0; gap_pos_cnt <= '0;
                        src_oh_acc <= '0; src_kh_acc <= '0;
                        src_ow_acc <= '0; src_kw_acc <= '0;
                        dst_oh_acc <= '0; dst_ow_acc <= '0;
                        ih_oh_base <= '0; iw_ow_base <= '0;
                        gap_pos_acc <= '0;
                        first_valid <= 1'b1;
                        max_reg     <= {LANES{FP32_NEG_INF}};
                        state       <= S_INIT;
                    end
                end

                // ---------------------------------------------------------
                // S_INIT: 一级乘法 (独立 DSP, 不在关键路径上)
                S_INIT: begin
                    row_stride_r <= src_w_r * c_blocks_r;
                    gap_total_r  <= src_h_r * src_w_r;
                    state        <= S_PRECOMPUTE;
                end

                // ---------------------------------------------------------
                // S_PRECOMPUTE: 二级乘法 (使用 S_INIT 已寄存的中间结果)
                S_PRECOMPUTE: begin
                    src_stride_row_r <= stride_r * row_stride_r;
                    src_stride_col_r <= stride_r * c_blocks_r;
                    pad_row_off_r    <= pad_r * row_stride_r;
                    pad_col_off_r    <= pad_r * c_blocks_r;
                    dst_stride_row_r <= out_w_r * c_blocks_r;
                    // src_pad_total 直接从源值计算（row_stride_r/c_blocks_r 来自 S_INIT 已寄存）
                    // 不能在 S_LOAD_REQ 里从 pad_row_off_r+pad_col_off_r 加，因为它们 NBA 在下一拍才有效
                    src_pad_total_r  <= pad_r * row_stride_r + pad_r * c_blocks_r;
                    state            <= S_LOAD_REQ;
                end

                // ---------------------------------------------------------
                S_LOAD_REQ: begin
                    if (mode_r == MP_MODE_GAP) begin
                        gb_addrb <= gap_load_addr;
                        gb_enb   <= 1'b1;
                        state    <= S_LOAD_WAIT;
                    end else begin
                        if (in_bounds) begin
                            gb_addrb <= mp_load_addr;
                            gb_enb   <= 1'b1;
                            state    <= S_LOAD_WAIT;
                        end else begin
                            state <= S_LOAD_CMP;
                        end
                    end
                end

                // ---------------------------------------------------------
                S_LOAD_WAIT: begin
                    if (gb_doutb_valid) state <= S_LOAD_CMP;
                end

                // ---------------------------------------------------------
                S_LOAD_CMP: begin
                    if (mode_r == MP_MODE_GAP) begin
                        // 启动 fp32_add（fp_add_valid_in = 1 此拍）
                        gap_add_wait <= '0;
                        state <= S_GAP_ADD_WAIT;
                    end else begin
                        max_reg     <= max_result;
                        first_valid <= 1'b0;
                        state       <= S_NEXT_KER;
                    end
                end

                // ---------------------------------------------------------
                S_GAP_ADD_WAIT: begin
                    // 等 fp32_add 流水线完成（FP32_ADD_LAT 拍）
                    if (fp_add_valid_out[0]) begin
                        // acc_reg 已在 always_ff 更新
                        state <= S_NEXT_KER;
                    end else begin
                        gap_add_wait <= gap_add_wait + 1'b1;
                    end
                end

                // ---------------------------------------------------------
                S_NEXT_KER: begin
                    if (mode_r == MP_MODE_GAP) begin
                        if (gap_pos_cnt == gap_total_r - 1) begin
                            gap_pos_cnt <= '0; gap_pos_acc <= '0;
                            state <= S_SAVE;
                        end else begin
                            gap_pos_cnt <= gap_pos_cnt + 1'b1;
                            gap_pos_acc <= gap_pos_acc + c_blocks_r;
                            state <= S_LOAD_REQ;
                        end
                    end else begin
                        if (kw_cnt == kernel_r - 1) begin
                            kw_cnt     <= '0; src_kw_acc <= '0;
                            if (kh_cnt == kernel_r - 1) begin
                                kh_cnt <= '0; src_kh_acc <= '0;
                                state  <= S_SAVE;
                            end else begin
                                kh_cnt     <= kh_cnt + 1;
                                src_kh_acc <= src_kh_acc + row_stride_r;
                                state      <= S_LOAD_REQ;
                            end
                        end else begin
                            kw_cnt     <= kw_cnt + 1;
                            src_kw_acc <= src_kw_acc + c_blocks_r;
                            state      <= S_LOAD_REQ;
                        end
                    end
                end

                // ---------------------------------------------------------
                S_SAVE: begin
                    gb_addrb <= (mode_r == MP_MODE_GAP) ? gap_save_addr : mp_save_addr;
                    gb_dinb  <= (mode_r == MP_MODE_GAP) ? acc_reg : max_reg;
                    gb_web   <= {(GB_BANDWIDTH/8){1'b1}};
                    gb_enb   <= 1'b1;
                    state    <= S_NEXT_CB;
                end

                // ---------------------------------------------------------
                S_NEXT_CB: begin
                    kh_cnt <= '0; src_kh_acc <= '0;
                    kw_cnt <= '0; src_kw_acc <= '0;
                    if (cb_cnt == c_blocks_r - 1) begin
                        cb_cnt <= '0;
                        state  <= (mode_r == MP_MODE_GAP) ? S_DONE : S_NEXT_POS;
                    end else begin
                        cb_cnt      <= cb_cnt + 1;
                        first_valid <= 1'b1;
                        max_reg     <= {LANES{FP32_NEG_INF}};
                        gap_pos_acc <= '0; gap_pos_cnt <= '0;
                        state       <= S_LOAD_REQ;
                    end
                end

                // ---------------------------------------------------------
                S_NEXT_POS: begin
                    kh_cnt <= '0; src_kh_acc <= '0;
                    kw_cnt <= '0; src_kw_acc <= '0;
                    first_valid <= 1'b1;
                    max_reg     <= {LANES{FP32_NEG_INF}};

                    if (ow_cnt == out_w_r - 1) begin
                        ow_cnt     <= '0; src_ow_acc <= '0; dst_ow_acc <= '0; iw_ow_base <= '0;
                        if (oh_cnt == out_h_r - 1) begin
                            state <= S_DONE;
                        end else begin
                            oh_cnt     <= oh_cnt + 1;
                            src_oh_acc <= src_oh_acc + src_stride_row_r;
                            dst_oh_acc <= dst_oh_acc + dst_stride_row_r;
                            ih_oh_base <= ih_oh_base + {6'b0, stride_r};
                            state      <= S_LOAD_REQ;
                        end
                    end else begin
                        ow_cnt     <= ow_cnt + 1;
                        src_ow_acc <= src_ow_acc + src_stride_col_r;
                        dst_ow_acc <= dst_ow_acc + c_blocks_r;
                        iw_ow_base <= iw_ow_base + {6'b0, stride_r};
                        state      <= S_LOAD_REQ;
                    end
                end

                // ---------------------------------------------------------
                S_DONE: state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
