`timescale 1ns/1ps
`include "vpu_defines.vh"
`include "chip_defines.vh"

// ============================================================================
// im2col_unit - 硬件 im2col 引擎
// ============================================================================
// 功能：把 NHWC 排列的 feature map 重排为 im2col 矩阵（每个输出像素对应一行
// kH*kW*CH_IN 元素），存回 OBUF 给 DCIM 计算用。
//
// 数据布局 (NHWC, INT8)：
//   输入 feature: shape [H, W, CH_IN]，每像素 CH_IN bytes
//     地址 = src_addr + (ih*W + iw)*CH_IN + c
//   输出 im2col:  shape [OH*OW, kH*kW*CH_IN]，每行 = kH*kW*CH_IN bytes
//     地址 = dst_addr + (oh*OW+ow)*(kH*kW*CH_IN) + (kh*kW+kw)*CH_IN + c
//
// OH = (H + 2*padH - kH)/strideH + 1，软件预算后通过 addr_s 传入
// OW = (W + 2*padW - kW)/strideW + 1，软件预算后通过 addr_t 传入
//
// 配置参数（复用 INST_Decoder vpu_* 寄存器）：
//   src_addr   : feature 在 OBUF 的字节起始地址
//   dst_addr   : im2col 输出在 OBUF 的字节起始地址
//   src_c      : CH_IN
//   src_h      : H
//   src_w      : W
//   addr_break : { kH[7:0], kW[7:0], strideH[3:0], strideW[3:0], padH[3:0], padW[3:0] }
//   addr_s     : OH (软件预算)
//   addr_t     : OW (软件预算)
//
// 状态机：嵌套循环 oh, ow, kh, kw
//   for (oh = 0; oh < OH; oh++)
//     for (ow = 0; ow < OW; ow++)
//       for (kh = 0; kh < kH; kh++)
//         for (kw = 0; kw < kW; kw++)
//           ih = oh*strideH - padH + kh
//           iw = ow*strideW - padW + kw
//           if (ih in [0,H) && iw in [0,W)):
//             读 OBUF[src_addr + (ih*W+iw)*CH_IN] (CH_IN bytes)
//             写 OBUF[dst_addr + (oh*OW+ow)*(kH*kW*CH_IN) + (kh*kW+kw)*CH_IN]
//           else:
//             写 OBUF[同上] = 0  (zero padding)
//
// 简化假设（与 network.json 一致）：
//   - CH_IN <= 16（一次 128-bit 操作）
//   - kH = kW (对称 kernel)
//   - strideH = strideW
//   - padH = padW
//   - 仅 INT8（CH_IN bytes）
//
// 与 mp_unit_fixed 一样的 GB 端口接口（仿真层面 = OBUF 接口）
// ============================================================================

module im2col_unit #(
    parameter ADDR_WIDTH    = 32,
    parameter GB_BANDWIDTH  = 256,
    parameter GB_ADDR_WIDTH = 24,
    parameter FP_WIDTH      = 32
)(
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          im2col_unit_start,
    output reg                           im2col_unit_ready,

    // 配置（从 Global_VPU 锁存的 reg 来）
    input  wire [ADDR_WIDTH-1:0]         im2col_src_addr,   // feature 字节起始
    input  wire [ADDR_WIDTH-1:0]         im2col_dst_addr,   // im2col 输出字节起始
    input  wire [ADDR_WIDTH-1:0]         im2col_src_c,      // CH_IN
    input  wire [ADDR_WIDTH-1:0]         im2col_src_h,      // H
    input  wire [ADDR_WIDTH-1:0]         im2col_src_w,      // W
    input  wire [ADDR_WIDTH-1:0]         im2col_addr_break, // 打包: kH/kW/strideH/strideW/padH/padW
    input  wire [ADDR_WIDTH-1:0]         im2col_addr_s,     // OH
    input  wire [ADDR_WIDTH-1:0]         im2col_addr_t,     // OW

    // GB (OBUF) 端口
    output reg  [GB_ADDR_WIDTH-1:0]      gb_addrb,
    output reg  [GB_BANDWIDTH-1:0]       gb_dinb,
    output reg  [GB_BANDWIDTH/8-1:0]     gb_web,
    output reg                           gb_enb,
    input  wire [GB_BANDWIDTH-1:0]       gb_doutb
);

    // =========================================================================
    // 参数解包
    // =========================================================================
    wire [7:0] kH_w      = im2col_addr_break[31:24];
    wire [7:0] kW_w      = im2col_addr_break[23:16];
    wire [3:0] strideH_w = im2col_addr_break[15:12];
    wire [3:0] strideW_w = im2col_addr_break[11:8];
    wire [3:0] padH_w    = im2col_addr_break[7:4];
    wire [3:0] padW_w    = im2col_addr_break[3:0];

    // 锁存配置（防止 start 后输入变化）
    reg [ADDR_WIDTH-1:0]  src_addr_r, dst_addr_r, src_c_r, src_h_r, src_w_r;
    reg [ADDR_WIDTH-1:0]  oh_max_r, ow_max_r;
    reg [7:0]             kH_r, kW_r;
    reg signed [4:0]      strideH_r, strideW_r;  // 留 1 bit 符号
    reg signed [4:0]      padH_r, padW_r;

    // =========================================================================
    // 状态机
    // =========================================================================
    localparam S_IDLE       = 4'd0;
    localparam S_INIT       = 4'd1;
    localparam S_READ_REQ   = 4'd2;  // 发出读请求
    localparam S_READ_WAIT  = 4'd3;  // 等待读延迟（OBUF 流水线）
    localparam S_READ_LATCH = 4'd4;  // 锁存读回数据
    localparam S_WRITE      = 4'd5;  // 发出写请求
    localparam S_NEXT_C     = 4'd6;  // 推进 c_chunk
    localparam S_NEXT       = 4'd7;  // 推进 kw/kh/ow/oh
    localparam S_DONE       = 4'd8;

    reg [3:0] state;

    // 循环索引（c_chunk 在最内层，处理 CH_IN > 16 的情况）
    reg signed [15:0] oh, ow;
    reg signed [7:0]  kh, kw;
    reg signed [15:0] ih, iw;       // 输入坐标（可能为负，因 pad）
    reg [15:0]        c_chunk;       // c-块索引（每块 16 channel = 128-bit）
    reg [15:0]        c_chunk_max;   // = ceil(CH_IN / 16)
    reg               in_bound;      // 当前 (ih, iw) 是否在 feature 范围内

    // 读延迟计数
    // OBUF 读延迟: DCIM_Array_bd mux(0) + obuf input_reg(1) + bank_sel/memreg(1)
    //   + NBPIPE(2) + bank_sel_pipe/output_mux(TOTAL_PIPE=4) + obuf output_mux(1) = 9
    localparam READ_LATENCY = 9;
    reg [3:0] rd_wait_cnt;

    // 锁存的读数据
    reg [GB_BANDWIDTH-1:0] rd_data_reg;

    // =========================================================================
    // 地址计算（完全流水线化：所有乘法在 S_INIT 预算，运行时只有加减法）
    // =========================================================================
    localparam C_CHUNK_BYTES = 16;
    wire [GB_ADDR_WIDTH-1:0] c_chunk_byte_offset = c_chunk * C_CHUNK_BYTES;

    // 预算常量（S_INIT 计算一次）
    reg [31:0] row_stride_r;         // = kH * kW * CH_IN
    reg [31:0] col_stride_r;         // = CH_IN
    reg [31:0] w_times_c_r;          // = W * CH_IN（行间距，字节）
    reg [31:0] stride_h_wc_r;        // = strideH * W * CH_IN
    reg [31:0] stride_w_c_r;         // = strideW * CH_IN
    reg signed [GB_ADDR_WIDTH-1:0] in_base_r;  // = src_addr - padH*W*C - padW*C

    // 增量累加寄存器（运行时只有加减）
    // in_pixel_byte_addr = in_base_r + oh*strideH*W*C + kh*W*C + ow*strideW*C + kw*C + c_chunk*16
    reg [GB_ADDR_WIDTH-1:0] in_oh_acc_r;   // = oh * stride_h_wc_r
    reg [GB_ADDR_WIDTH-1:0] in_kh_acc_r;   // = kh * w_times_c_r
    reg [GB_ADDR_WIDTH-1:0] in_ow_acc_r;   // = ow * stride_w_c_r
    reg [GB_ADDR_WIDTH-1:0] in_kw_acc_r;   // = kw * col_stride_r
    // 组合：只加法，0 乘法运行时
    wire [GB_ADDR_WIDTH-1:0] in_pixel_byte_addr =
        in_base_r + in_oh_acc_r + in_kh_acc_r + in_ow_acc_r + in_kw_acc_r + c_chunk_byte_offset;

    // 输出地址：同样只加法
    reg [31:0] out_row_offset_r;  // = (oh*OW + ow) * row_stride
    reg [31:0] out_col_offset_r;  // = (kh*kW + kw) * CH_IN
    wire [GB_ADDR_WIDTH-1:0] out_byte_addr =
        dst_addr_r + out_row_offset_r + out_col_offset_r + c_chunk_byte_offset;

    // 写使能 mask：写满 16 byte（一个 128-bit word），不管 CH_IN 是否对齐 16
    // (CH_IN 不是 16 倍数的情况由软件 padding 处理)
    wire [GB_BANDWIDTH/8-1:0] write_mask = {(GB_BANDWIDTH/8){1'b1}};

    // 输入是否在范围内
    wire ih_ok = (ih >= 0) && (ih < $signed(src_h_r));
    wire iw_ok = (iw >= 0) && (iw < $signed(src_w_r));

    // =========================================================================
    // 状态机主体
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state             <= S_IDLE;
            im2col_unit_ready <= 1'b1;
            gb_addrb          <= '0;
            gb_dinb           <= '0;
            gb_web            <= '0;
            gb_enb            <= 1'b0;
            oh <= 0; ow <= 0; kh <= 0; kw <= 0;
            ih <= 0; iw <= 0;
            c_chunk <= 0; c_chunk_max <= 0;
            in_bound          <= 1'b0;
            rd_wait_cnt       <= 0;
            rd_data_reg       <= 0;
            src_addr_r <= 0; dst_addr_r <= 0; src_c_r <= 0; src_h_r <= 0; src_w_r <= 0;
            oh_max_r <= 0; ow_max_r <= 0;
            kH_r <= 0; kW_r <= 0;
            strideH_r <= 0; strideW_r <= 0;
            padH_r <= 0; padW_r <= 0;
        end else begin
            // 默认信号
            gb_enb <= 1'b0;
            gb_web <= '0;

            case (state)
                S_IDLE: begin
                    if (im2col_unit_start) begin
                        // 锁存配置
                        src_addr_r <= im2col_src_addr;
                        dst_addr_r <= im2col_dst_addr;
                        src_c_r    <= im2col_src_c;
                        src_h_r    <= im2col_src_h;
                        src_w_r    <= im2col_src_w;
                        oh_max_r   <= im2col_addr_s;
                        ow_max_r   <= im2col_addr_t;
                        kH_r       <= kH_w;
                        kW_r       <= kW_w;
                        strideH_r  <= {1'b0, strideH_w};
                        strideW_r  <= {1'b0, strideW_w};
                        padH_r     <= {1'b0, padH_w};
                        padW_r     <= {1'b0, padW_w};
                        // c_chunk_max = ceil(CH_IN / 16) = (CH_IN + 15) / 16
                        c_chunk_max <= (im2col_src_c + 15) >> 4;
                        im2col_unit_ready <= 1'b0;
                        state      <= S_INIT;
                    end
                end

                S_INIT: begin
                    oh <= 0; ow <= 0; kh <= 0; kw <= 0; c_chunk <= 0;
                    // 预算所有运行时常量（只在 S_INIT 执行一次乘法）
                    row_stride_r  <= kH_r * kW_r * src_c_r;
                    col_stride_r  <= src_c_r;
                    w_times_c_r   <= src_w_r * src_c_r;
                    stride_h_wc_r <= strideH_r * src_w_r * src_c_r;
                    stride_w_c_r  <= strideW_r * src_c_r;
                    // 输入地址偏置（减去 padding 贡献）
                    in_base_r     <= src_addr_r
                                     - $signed(padH_r) * $signed(src_w_r * src_c_r)
                                     - $signed(padW_r) * $signed(src_c_r);
                    // 增量累加器初始为 0（oh=0, kh=0, ow=0, kw=0）
                    in_oh_acc_r <= 0;
                    in_kh_acc_r <= 0;
                    in_ow_acc_r <= 0;
                    in_kw_acc_r <= 0;
                    out_row_offset_r <= 0;
                    out_col_offset_r <= 0;
                    state <= S_READ_REQ;
                end

                S_READ_REQ: begin
                    // ih/iw 用于 in_bound 判断（仍需要计算）
                    ih <= $signed(oh) * strideH_r - padH_r + $signed({8'd0, kh});
                    iw <= $signed(ow) * strideW_r - padW_r + $signed({8'd0, kw});
                    rd_wait_cnt <= 0;
                    state <= S_READ_WAIT;
                end

                S_READ_WAIT: begin
                    if (ih_ok && iw_ok) begin
                        in_bound <= 1'b1;
                        if (rd_wait_cnt == 0) begin
                            // 发出 OBUF 读请求
                            gb_addrb <= in_pixel_byte_addr;
                            gb_enb   <= 1'b1;
                            gb_web   <= '0;  // 读
                        end
                        if (rd_wait_cnt == READ_LATENCY) begin
                            state <= S_READ_LATCH;
                        end else begin
                            rd_wait_cnt <= rd_wait_cnt + 1;
                        end
                    end else begin
                        // pad 区域，跳过读，直接写 0
                        in_bound <= 1'b0;
                        state <= S_WRITE;
                    end
                end

                S_READ_LATCH: begin
                    rd_data_reg <= gb_doutb;
                    state       <= S_WRITE;
                end

                S_WRITE: begin
                    gb_addrb <= out_byte_addr;
                    gb_enb   <= 1'b1;
                    gb_web   <= write_mask;
                    gb_dinb  <= in_bound ? rd_data_reg : '0;
                    state    <= S_NEXT_C;
                end

                S_NEXT_C: begin
                    // 推进 c_chunk
                    if (c_chunk + 1 < c_chunk_max) begin
                        c_chunk <= c_chunk + 1;
                        state <= S_READ_REQ;
                    end else begin
                        c_chunk <= 0;
                        state <= S_NEXT;
                    end
                end

                S_NEXT: begin
                    // 递增循环计数器 + 增量更新偏移（无乘法）
                    if (kw + 1 < $signed({1'b0, kW_r})) begin
                        kw <= kw + 1;
                        in_kw_acc_r      <= in_kw_acc_r + col_stride_r;
                        out_col_offset_r <= out_col_offset_r + col_stride_r;
                        state <= S_READ_REQ;
                    end else begin
                        kw <= 0;
                        in_kw_acc_r      <= 0;
                        if (kh + 1 < $signed({1'b0, kH_r})) begin
                            kh <= kh + 1;
                            in_kh_acc_r      <= in_kh_acc_r + w_times_c_r;
                            out_col_offset_r <= out_col_offset_r + col_stride_r; // = (kh+1)*kW*C
                            state <= S_READ_REQ;
                        end else begin
                            kh <= 0;
                            in_kh_acc_r      <= 0;
                            out_col_offset_r <= 0;
                            if (ow + 1 < $signed(ow_max_r)) begin
                                ow <= ow + 1;
                                in_ow_acc_r      <= in_ow_acc_r + stride_w_c_r;
                                out_row_offset_r <= out_row_offset_r + row_stride_r;
                                state <= S_READ_REQ;
                            end else begin
                                ow <= 0;
                                in_ow_acc_r      <= 0;
                                if (oh + 1 < $signed(oh_max_r)) begin
                                    oh <= oh + 1;
                                    in_oh_acc_r      <= in_oh_acc_r + stride_h_wc_r;
                                    out_row_offset_r <= out_row_offset_r + row_stride_r;
                                    state <= S_READ_REQ;
                                end else begin
                                    state <= S_DONE;
                                end
                            end
                        end
                    end
                end

                S_DONE: begin
                    im2col_unit_ready <= 1'b1;
                    state             <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
