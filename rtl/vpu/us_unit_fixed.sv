`timescale 1ns / 1ps
//==============================================================================
// us_unit_fixed - 硬编码 Nearest Neighbor Upsample ×2 单元
//==============================================================================
// 固定配置（来自 EdgeYOLO best.onnx 中的 Resize 节点）：
//   mode = nearest
//   nearest_mode = floor
//   scale_factor = 2 (H和W各放大2倍)
//
// 支持的两种输入维度（通过 src_c/src_h/src_w 参数选择）：
//   Case 1: [128, 10, 10] → [128, 20, 20]  (/model.11/Resize)
//   Case 2: [64,  20, 20] → [64,  40, 40]  (/model.15/Resize)
//
// BRAM 数据布局（HWC，channel 在最低维度，256-bit 对齐）：
//   地址 = (h * W + w) * C_BLOCKS + cb
//   每个 BRAM word = 256 bits = 8 × FP32
//
// Nearest ×2 逻辑：
//   output[oh][ow] = input[oh/2][ow/2]  (floor division)
//   等价于：每个输入像素复制到 2×2 的输出块
//
// 实现策略（高效写法）：
//   遍历每个输入位置 (ih, iw)，读取该像素的每个 channel block，
//   然后写入输出的 4 个位置：
//     (2*ih,   2*iw  )
//     (2*ih,   2*iw+1)
//     (2*ih+1, 2*iw  )
//     (2*ih+1, 2*iw+1)
//==============================================================================

module us_unit_fixed #(
    parameter ADDR_WIDTH    = 32,
    parameter GB_BANDWIDTH  = 256,   // bits per BRAM word
    parameter GB_ADDR_WIDTH = 32,
    parameter FP_WIDTH      = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          us_unit_start,
    output wire                          us_unit_ready,

    // 配置（由 INST_Decoder 提供）
    input  wire [ADDR_WIDTH-1:0]         us_src_addr,   // 输入基地址（字节）
    input  wire [ADDR_WIDTH-1:0]         us_src_h,      // 输入高度
    input  wire [ADDR_WIDTH-1:0]         us_src_w,      // 输入宽度
    input  wire [ADDR_WIDTH-1:0]         us_src_c,      // 输入通道数
    input  wire [ADDR_WIDTH-1:0]         us_dst_addr,   // 输出基地址（字节）

    // GB BRAM Port B 接口
    output logic [GB_ADDR_WIDTH-1:0]     gb_addrb,
    output logic [GB_BANDWIDTH-1:0]      gb_dinb,
    output logic [GB_BANDWIDTH/8-1:0]    gb_web,
    output logic                         gb_enb,
    input  wire  [GB_BANDWIDTH-1:0]      gb_doutb
);

    // =========================================================================
    // 固定参数
    // =========================================================================
    localparam SCALE      = 2;
    localparam LANES      = GB_BANDWIDTH / FP_WIDTH;  // 8 FP32 per word

    // =========================================================================
    // 状态机
    // =========================================================================
    typedef enum logic [3:0] {
        S_IDLE,
        S_INIT,
        S_LOAD_REQ,      // 发出 BRAM 读请求
        S_LOAD_WAIT,     // 等待 BRAM 读延迟
        S_LOAD_DONE,     // 锁存读取数据
        S_SAVE_0,        // 写入输出位置 0: (2*ih, 2*iw)
        S_SAVE_1,        // 写入输出位置 1: (2*ih, 2*iw+1)
        S_SAVE_2,        // 写入输出位置 2: (2*ih+1, 2*iw)
        S_SAVE_3,        // 写入输出位置 3: (2*ih+1, 2*iw+1)
        S_NEXT,          // 推进到下一个位置
        S_DONE
    } state_t;

    state_t state;

    assign us_unit_ready = (state == S_IDLE);

    // =========================================================================
    // 运行时计算的参数（锁存输入配置）
    // =========================================================================
    reg [ADDR_WIDTH-1:0] in_h, in_w, c_blocks;
    reg [ADDR_WIDTH-1:0] out_w;  // = in_w * 2
    reg [GB_ADDR_WIDTH-1:0] src_base_word;
    reg [GB_ADDR_WIDTH-1:0] dst_base_word;

    // =========================================================================
    // 循环计数器
    // =========================================================================
    reg [ADDR_WIDTH-1:0] ih_cnt;    // 输入行
    reg [ADDR_WIDTH-1:0] iw_cnt;    // 输入列
    reg [ADDR_WIDTH-1:0] cb_cnt;    // channel block

    // 像素缓冲
    reg [GB_BANDWIDTH-1:0] pixel_buf;

    // =========================================================================
    // 地址计算
    // =========================================================================
    // 输入地址: src_base + (ih * in_w + iw) * c_blocks + cb
    wire [GB_ADDR_WIDTH-1:0] load_addr = src_base_word
        + (ih_cnt * in_w + iw_cnt) * c_blocks
        + cb_cnt;

    // 输出地址: dst_base + (oh * out_w + ow) * c_blocks + cb
    // 4 个输出位置
    wire [ADDR_WIDTH-1:0] oh_0 = ih_cnt * SCALE;      // 2*ih
    wire [ADDR_WIDTH-1:0] oh_1 = ih_cnt * SCALE + 1;  // 2*ih + 1
    wire [ADDR_WIDTH-1:0] ow_0 = iw_cnt * SCALE;      // 2*iw
    wire [ADDR_WIDTH-1:0] ow_1 = iw_cnt * SCALE + 1;  // 2*iw + 1

    wire [GB_ADDR_WIDTH-1:0] save_addr_0 = dst_base_word + (oh_0 * out_w + ow_0) * c_blocks + cb_cnt;
    wire [GB_ADDR_WIDTH-1:0] save_addr_1 = dst_base_word + (oh_0 * out_w + ow_1) * c_blocks + cb_cnt;
    wire [GB_ADDR_WIDTH-1:0] save_addr_2 = dst_base_word + (oh_1 * out_w + ow_0) * c_blocks + cb_cnt;
    wire [GB_ADDR_WIDTH-1:0] save_addr_3 = dst_base_word + (oh_1 * out_w + ow_1) * c_blocks + cb_cnt;

    // =========================================================================
    // 状态机主逻辑
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            ih_cnt      <= '0;
            iw_cnt      <= '0;
            cb_cnt      <= '0;
            in_h        <= '0;
            in_w        <= '0;
            out_w       <= '0;
            c_blocks    <= '0;
            src_base_word <= '0;
            dst_base_word <= '0;
            pixel_buf   <= '0;
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
                    if (us_unit_start) begin
                        in_h          <= us_src_h;
                        in_w          <= us_src_w;
                        out_w         <= us_src_w * SCALE;
                        c_blocks      <= us_src_c / LANES;
                        src_base_word <= us_src_addr[ADDR_WIDTH-1:5];
                        dst_base_word <= us_dst_addr[ADDR_WIDTH-1:5];
                        ih_cnt        <= '0;
                        iw_cnt        <= '0;
                        cb_cnt        <= '0;
                        state         <= S_LOAD_REQ;
                    end
                end

                // ---------------------------------------------------------
                S_LOAD_REQ: begin
                    gb_addrb <= load_addr;
                    gb_enb   <= 1'b1;
                    state    <= S_LOAD_WAIT;
                end

                // ---------------------------------------------------------
                S_LOAD_WAIT: begin
                    state <= S_LOAD_DONE;
                end

                // ---------------------------------------------------------
                S_LOAD_DONE: begin
                    pixel_buf <= gb_doutb;
                    state     <= S_SAVE_0;
                end

                // ---------------------------------------------------------
                S_SAVE_0: begin
                    gb_addrb <= save_addr_0;
                    gb_dinb  <= pixel_buf;
                    gb_web   <= {(GB_BANDWIDTH/8){1'b1}};
                    gb_enb   <= 1'b1;
                    state    <= S_SAVE_1;
                end

                // ---------------------------------------------------------
                S_SAVE_1: begin
                    gb_addrb <= save_addr_1;
                    gb_dinb  <= pixel_buf;
                    gb_web   <= {(GB_BANDWIDTH/8){1'b1}};
                    gb_enb   <= 1'b1;
                    state    <= S_SAVE_2;
                end

                // ---------------------------------------------------------
                S_SAVE_2: begin
                    gb_addrb <= save_addr_2;
                    gb_dinb  <= pixel_buf;
                    gb_web   <= {(GB_BANDWIDTH/8){1'b1}};
                    gb_enb   <= 1'b1;
                    state    <= S_SAVE_3;
                end

                // ---------------------------------------------------------
                S_SAVE_3: begin
                    gb_addrb <= save_addr_3;
                    gb_dinb  <= pixel_buf;
                    gb_web   <= {(GB_BANDWIDTH/8){1'b1}};
                    gb_enb   <= 1'b1;
                    state    <= S_NEXT;
                end

                // ---------------------------------------------------------
                S_NEXT: begin
                    if (cb_cnt == c_blocks - 1) begin
                        cb_cnt <= '0;
                        if (iw_cnt == in_w - 1) begin
                            iw_cnt <= '0;
                            if (ih_cnt == in_h - 1) begin
                                state <= S_DONE;
                            end else begin
                                ih_cnt <= ih_cnt + 1;
                                state  <= S_LOAD_REQ;
                            end
                        end else begin
                            iw_cnt <= iw_cnt + 1;
                            state  <= S_LOAD_REQ;
                        end
                    end else begin
                        cb_cnt <= cb_cnt + 1;
                        state  <= S_LOAD_REQ;
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
