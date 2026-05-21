`timescale 1ns / 1ps
`include "vpu_defines.vh"
//==============================================================================
// mp_unit_fixed - 硬编码 5×5 MaxPooling 单元
//==============================================================================
// 固定配置（来自 EdgeYOLO best.onnx 中的 SPPF MaxPool）：
//   kernel_shape = [5, 5]
//   strides      = [1, 1]
//   pads         = [2, 2, 2, 2]
//   输入/输出    = [1, 128, 10, 10]  (NCHW in ONNX)
//
// BRAM 数据布局（HWC，channel 在最低维度，256-bit 对齐）：
//   地址 = (h * W + w) * C_BLOCKS + cb
//   每个 BRAM word = 256 bits = 8 × FP32
//   C=128 → C_BLOCKS = 128/8 = 16
//   总数据量 = H * W * C_BLOCKS = 10 * 10 * 16 = 1600 words
//
// 接口：
//   - 输入数据在 GB BRAM 的 src_addr 处
//   - 输出写入 GB BRAM 的 dst_addr 处
//   - 地址单位为 BRAM word (256-bit = 32 bytes)
//==============================================================================

module mp_unit_fixed #(
    parameter ADDR_WIDTH    = 32,
    parameter GB_BANDWIDTH  = 256,   // bits per BRAM word
    parameter GB_ADDR_WIDTH = 32,
    parameter FP_WIDTH      = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          mp_unit_start,
    output wire                          mp_unit_ready,

    // 配置（由 INST_Decoder 提供）
    input  wire [ADDR_WIDTH-1:0]         mp_src_addr,   // 输入基地址（字节）
    input  wire [ADDR_WIDTH-1:0]         mp_dst_addr,   // 输出基地址（字节）
    // mp_src_c, mp_src_h, mp_src_w 不使用（已硬编码）

    // GB BRAM Port B 接口
    output logic [GB_ADDR_WIDTH-1:0]     gb_addrb,
    output logic [GB_BANDWIDTH-1:0]      gb_dinb,
    output logic [GB_BANDWIDTH/8-1:0]    gb_web,
    output logic                         gb_enb,
    input  wire  [GB_BANDWIDTH-1:0]      gb_doutb
);

    // =========================================================================
    // 硬编码参数
    // =========================================================================
    localparam H          = 10;
    localparam W          = 10;
    localparam C          = 128;
    localparam KERNEL     = 5;
    localparam PAD        = 2;
    localparam STRIDE     = 1;
    // 输出尺寸 = 输入尺寸 (same padding with stride=1)
    localparam OH         = H;   // 10
    localparam OW         = W;   // 10

    localparam LANES      = GB_BANDWIDTH / FP_WIDTH;  // 8 FP32 per word
    localparam C_BLOCKS   = C / LANES;                // 16
    localparam BYTE_ADDR_SHIFT = $clog2(GB_BANDWIDTH / 8);  // 字节地址到 word 地址的移位量

    // FP32 负无穷 (用于 padding 区域)
    localparam [FP_WIDTH-1:0] FP32_NEG_INF = 32'hFF80_0000;

    // =========================================================================
    // 状态机
    // =========================================================================
    typedef enum logic [3:0] {
        S_IDLE,
        S_LOAD_REQ,      // 发出 BRAM 读请求
        S_LOAD_WAIT,     // 等待 BRAM 读延迟
        S_LOAD_CMP,      // 读取数据并与当前最大值比较
        S_SAVE,          // 写回结果
        S_NEXT_KER,      // 推进到下一个 kernel 位置
        S_NEXT_CB,       // 推进到下一个 channel block
        S_NEXT_POS,      // 推进到下一个输出位置
        S_DONE
    } state_t;

    state_t state;

    assign mp_unit_ready = (state == S_IDLE);

    // =========================================================================
    // 循环计数器
    // =========================================================================
    reg [3:0] oh_cnt;      // 输出行 0..9
    reg [3:0] ow_cnt;      // 输出列 0..9
    reg [4:0] cb_cnt;      // channel block 0..15
    reg [2:0] kh_cnt;      // kernel 行 0..4
    reg [2:0] kw_cnt;      // kernel 列 0..4

    // 基地址寄存器（word 地址）
    reg [GB_ADDR_WIDTH-1:0] src_base_word;
    reg [GB_ADDR_WIDTH-1:0] dst_base_word;

    // 当前最大值寄存器 (256 bits = 8 × FP32)
    reg [GB_BANDWIDTH-1:0] max_reg;

    // 第一个有效值标记（用于初始化 max_reg）
    reg first_valid;

    // =========================================================================
    // 地址计算
    // =========================================================================
    // 输入像素在 HWC 布局中的 BRAM word 地址:
    //   word_addr = src_base_word + (ih * W + iw) * C_BLOCKS + cb
    wire signed [5:0] ih = $signed({1'b0, oh_cnt}) + $signed({1'b0, kh_cnt}) - $signed(6'sd2);
    wire signed [5:0] iw = $signed({1'b0, ow_cnt}) + $signed({1'b0, kw_cnt}) - $signed(6'sd2);
    wire in_bounds = (ih >= 0) && (ih < H) && (iw >= 0) && (iw < W);

    // C_BLOCKS is power of 2, use shift
    localparam C_BLOCKS_SHIFT = $clog2(C_BLOCKS);  // 4
    localparam ROW_STRIDE = W * C_BLOCKS;  // 160, constant for synthesis

    wire [GB_ADDR_WIDTH-1:0] load_addr = src_base_word
        + ih[3:0] * ROW_STRIDE
        + (iw[3:0] << C_BLOCKS_SHIFT)
        + cb_cnt;

    wire [GB_ADDR_WIDTH-1:0] save_addr = dst_base_word
        + oh_cnt * (OW * C_BLOCKS)
        + (ow_cnt << C_BLOCKS_SHIFT)
        + cb_cnt;

    // =========================================================================
    // FP32 逐 lane 比较 (8 路并行)
    // =========================================================================
    wire [GB_BANDWIDTH-1:0] new_data;
    wire [GB_BANDWIDTH-1:0] max_result;

    // 对 padding 区域使用 -inf
    assign new_data = in_bounds ? gb_doutb : {LANES{FP32_NEG_INF}};

    genvar gi;
    generate
        for (gi = 0; gi < LANES; gi = gi + 1) begin : gen_cmp
            wire [FP_WIDTH-1:0] a = max_reg[gi*FP_WIDTH +: FP_WIDTH];
            wire [FP_WIDTH-1:0] b = new_data[gi*FP_WIDTH +: FP_WIDTH];

            // IEEE 754 FP32 比较：转换为可无符号比较的格式
            // 正数: 翻转符号位 → 0x8xxx_xxxx 范围
            // 负数: 全部取反   → 保持正确排序
            wire [FP_WIDTH-1:0] a_key = a[31] ? ~a : {1'b1, a[30:0]};
            wire [FP_WIDTH-1:0] b_key = b[31] ? ~b : {1'b1, b[30:0]};

            assign max_result[gi*FP_WIDTH +: FP_WIDTH] =
                (first_valid) ? b :
                (b_key > a_key) ? b : a;
        end
    endgenerate

    // =========================================================================
    // 状态机主逻辑
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            oh_cnt      <= '0;
            ow_cnt      <= '0;
            cb_cnt      <= '0;
            kh_cnt      <= '0;
            kw_cnt      <= '0;
            max_reg     <= '0;
            first_valid <= 1'b1;
            src_base_word <= '0;
            dst_base_word <= '0;
            gb_addrb    <= '0;
            gb_dinb     <= '0;
            gb_web      <= '0;
            gb_enb      <= 1'b0;
        end else begin
            // 默认清除 BRAM 控制信号
            gb_enb  <= 1'b0;
            gb_web  <= '0;

            case (state)
                // ---------------------------------------------------------
                S_IDLE: begin
                    if (mp_unit_start) begin
                        src_base_word <= mp_src_addr >> BYTE_ADDR_SHIFT; // byte_addr >> BYTE_ADDR_SHIFT = word_addr
                        dst_base_word <= mp_dst_addr >> BYTE_ADDR_SHIFT;
                        oh_cnt      <= '0;
                        ow_cnt      <= '0;
                        cb_cnt      <= '0;
                        kh_cnt      <= '0;
                        kw_cnt      <= '0;
                        first_valid <= 1'b1;
                        max_reg     <= {LANES{FP32_NEG_INF}};
                        state       <= S_LOAD_REQ;
                    end
                end

                // ---------------------------------------------------------
                S_LOAD_REQ: begin
                    if (in_bounds) begin
                        // 发出 BRAM 读请求
                        gb_addrb <= load_addr;
                        gb_enb   <= 1'b1;
                        state    <= S_LOAD_WAIT;
                    end else begin
                        // padding 区域，跳过读取，直接比较（用 -inf）
                        state <= S_LOAD_CMP;
                    end
                end

                // ---------------------------------------------------------
                S_LOAD_WAIT: begin
                    // BRAM 读取延迟 1 周期
                    state <= S_LOAD_CMP;
                end

                // ---------------------------------------------------------
                S_LOAD_CMP: begin
                    // 更新最大值
                    max_reg     <= max_result;
                    first_valid <= 1'b0;
                    state       <= S_NEXT_KER;
                end

                // ---------------------------------------------------------
                S_NEXT_KER: begin
                    if (kw_cnt == KERNEL - 1) begin
                        kw_cnt <= '0;
                        if (kh_cnt == KERNEL - 1) begin
                            // 5×5 kernel 遍历完成，保存结果
                            kh_cnt <= '0;
                            state  <= S_SAVE;
                        end else begin
                            kh_cnt <= kh_cnt + 1;
                            state  <= S_LOAD_REQ;
                        end
                    end else begin
                        kw_cnt <= kw_cnt + 1;
                        state  <= S_LOAD_REQ;
                    end
                end

                // ---------------------------------------------------------
                S_SAVE: begin
                    gb_addrb <= save_addr;
                    gb_dinb  <= max_reg;
                    gb_web   <= {(GB_BANDWIDTH/8){1'b1}};
                    gb_enb   <= 1'b1;
                    state    <= S_NEXT_CB;
                end

                // ---------------------------------------------------------
                S_NEXT_CB: begin
                    // 推进 channel block
                    if (cb_cnt == C_BLOCKS - 1) begin
                        cb_cnt <= '0;
                        state  <= S_NEXT_POS;
                    end else begin
                        cb_cnt      <= cb_cnt + 1;
                        first_valid <= 1'b1;
                        max_reg     <= {LANES{FP32_NEG_INF}};
                        state       <= S_LOAD_REQ;
                    end
                end

                // ---------------------------------------------------------
                S_NEXT_POS: begin
                    // 推进输出空间位置
                    if (ow_cnt == OW - 1) begin
                        ow_cnt <= '0;
                        if (oh_cnt == OH - 1) begin
                            state <= S_DONE;
                        end else begin
                            oh_cnt      <= oh_cnt + 1;
                            first_valid <= 1'b1;
                            max_reg     <= {LANES{FP32_NEG_INF}};
                            state       <= S_LOAD_REQ;
                        end
                    end else begin
                        ow_cnt      <= ow_cnt + 1;
                        first_valid <= 1'b1;
                        max_reg     <= {LANES{FP32_NEG_INF}};
                        state       <= S_LOAD_REQ;
                    end
                end

                // ---------------------------------------------------------
                S_DONE: begin
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
