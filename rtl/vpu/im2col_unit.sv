`timescale 1ns/1ps
`include "chip_defines.vh"

// ============================================================================
// im2col_unit - 硬件 im2col 引擎
// ============================================================================
// 功能：把 NHWC 排列的 feature map 重排为 im2col 矩阵（每个输出像素对应一行
// kH*kW*CH_IN 元素），存回 OBUF 给 DCIM 计算用。
//
// 数据布局：
//   输入 feature: shape [H, W, CH_IN]，每像素 ceil(CH_IN*ELEM_BYTES/16)*16 字节
//     地址 = src_addr + (ih*W+iw)*in_col_stride + c_chunk*16
//   输出 im2col:  shape [OH*OW, acc_depth*16]，每行前 kH*kW*CH_IN*ELEM_BYTES 字节有效
//     row_stride = ceil(kH*kW*CH_IN*ELEM_BYTES/16)*16
//
// ELEM_BYTES=1 → INT8（默认），ELEM_BYTES=2 → INT16（DCIM w16a16 模式）。
// 同一 im2col_unit 实例两者兼容，通过 im2col_elem_bytes 端口选择。
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
//   - CH_IN ≤ 16（一次 128-bit 操作）
//   - kH = kW (对称 kernel)
//   - strideH = strideW
//   - padH = padW
//   - ELEM_BYTES=1: INT8（1 byte/element），ELEM_BYTES=2: INT16（2 bytes/element）
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
    input  wire [1:0]                    im2col_elem_bytes, // 1=INT8, 2=INT16

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
    input  wire [GB_BANDWIDTH-1:0]       gb_doutb,
    input  wire                          gb_doutb_valid   // OBUF 读数据有效（与 gb_doutb 同拍）
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
    reg [1:0]             elem_bytes_r;  // 1=INT8, 2=INT16，锁存后不变
    reg [7:0]             kH_r, kW_r;
    reg signed [4:0]      strideH_r, strideW_r;  // 留 1 bit 符号
    reg signed [4:0]      padH_r, padW_r;

    // =========================================================================
    // 状态机
    // =========================================================================
    localparam S_IDLE       = 4'd0;
    localparam S_INIT       = 4'd1;
    localparam S_PRECOMPUTE = 4'd9;  // 预算二级乘法（S_INIT 结果 → 最终常量）
    localparam S_READ_REQ   = 4'd2;  // 发出读请求（单周期 pulse）
    localparam S_READ_WAIT  = 4'd3;  // 等待 douta_valid
    localparam S_READ_LATCH = 4'd4;  // 释放总线
    localparam S_WRITE      = 4'd5;  // 发出写请求
    localparam S_NEXT_C     = 4'd6;  // 推进 c_chunk
    localparam S_NEXT       = 4'd7;  // 推进 kw/kh/ow/oh
    localparam S_DONE       = 4'd8;
    localparam S_WRITE_TAIL       = 4'd10; // 跨 OBUF 字边界时的第二拍写
    localparam S_READ_TAIL_REQ      = 4'd11; // 输入数据跨读字边界时补读下一字
    localparam S_READ_TAIL_WAIT     = 4'd12;
    localparam S_READ_TAIL_LATCH    = 4'd13;

    reg [3:0] state;

    // 循环索引（c_chunk 在最内层，处理 CH_IN > 16 的情况）
    reg signed [15:0] oh, ow;
    reg signed [7:0]  kh, kw;
    reg signed [15:0] ih, iw;       // 输入坐标（可能为负，因 pad）
    reg [15:0]        c_chunk;       // c-块索引（每块 16 channel = 128-bit）
    reg [15:0]        c_chunk_max;   // = ceil(CH_IN / 16)
    reg [31:0]        c_chunk_byte_offset_r;  // c_chunk * 16，提前寄存以切断写数据路径
    reg [4:0]         write_chunk_nbyte_r;
    reg               in_bound;      // 当前 (ih, iw) 是否在 feature 范围内

    // 读延迟：使用 obuf.v douta_valid（NBPIPE=3 时 Port A 端到端 8 拍）
    // 保留 rd_wait_cnt 仅作仿真超时保护
    localparam READ_TIMEOUT = 17;  // 16+1 margin（用于强制重编译 VCS 缓存）
    reg [4:0] rd_wait_cnt;

    // 锁存的读数据 + 读地址在 128-bit 字内的字节偏移
    reg [GB_BANDWIDTH-1:0] rd_data_reg;
    reg [GB_BANDWIDTH-1:0] rd_tail_data_reg;  // 跨读字边界时下一 OBUF 字
    reg [3:0]              in_byte_in_word_r;

    // =========================================================================
    // 地址计算（完全流水线化：所有乘法在 S_INIT 预算，运行时只有加减法）
    // =========================================================================
    localparam C_CHUNK_BYTES = 16;
    localparam WORD_BYTES    = GB_BANDWIDTH / 8;  // OBUF 物理字宽（lite=16B, chip=32B）
    // ELEM_BYTES 运行时值（已锁存）
    wire [ADDR_WIDTH-1:0] elem_bytes_w = {{(ADDR_WIDTH-2){1'b0}}, elem_bytes_r};
    wire [31:0] c_chunk_byte_offset = c_chunk_byte_offset_r;

    // 预算常量（S_INIT 算一级，S_PRECOMPUTE 算二级）
    reg [31:0] row_stride_r;         // = ceil(kH*kW*CH_IN/16)*16，与 DCIM acc_depth 行对齐
    reg [31:0] in_col_stride_r;      // feature map 像素间距：ceil(CH_IN/16)*16（16B channel-group 对齐）
    reg [31:0] w_times_c_r;          // = W * CH_IN（一级，S_INIT）
    reg [31:0] stride_h_wc_r;        // = strideH * W * CH_IN（二级，S_PRECOMPUTE）
    reg [31:0] stride_w_c_r;         // = strideW * CH_IN（一级，S_INIT）
    reg [31:0] kw_times_c_r;         // = kW * CH_IN（一级，供 row_stride 自然字节数）
    reg signed [31:0] in_base_r;  // = src_addr - padH*W*C - padW*C（二级）

    // 增量累加寄存器（有符号，确保与 in_base_r 相加时不溢出）
    reg signed [31:0] in_oh_acc_r;   // = oh * stride_h_wc_r
    reg signed [31:0] in_kh_acc_r;   // = kh * w_times_c_r
    reg signed [31:0] in_ow_acc_r;   // = ow * stride_w_c_r
    reg signed [31:0] in_kw_acc_r;   // = kw * in_col_stride_r
    // 组合：全有符号加法，地址截断到 GB_ADDR_WIDTH
    wire signed [31:0] in_pixel_byte_addr_s =
        $signed(in_base_r) + $signed(in_oh_acc_r) + $signed(in_kh_acc_r)
        + $signed(in_ow_acc_r) + $signed(in_kw_acc_r) + $signed(c_chunk_byte_offset);
    wire [GB_ADDR_WIDTH-1:0] in_pixel_byte_addr = in_pixel_byte_addr_s[GB_ADDR_WIDTH-1:0];

    // 输出地址：同样只加法
    reg [31:0] out_row_offset_r;  // = (oh*OW + ow) * row_stride
    reg [31:0] out_col_offset_r;  // = (kh*kW + kw) * CH_IN
    wire [GB_ADDR_WIDTH-1:0] out_byte_addr =
        dst_addr_r + out_row_offset_r + out_col_offset_r + c_chunk_byte_offset;

    // 写使能/数据：按字内偏移放置 CH_IN×ELEM_BYTES 字节
    //   LOOP_BITS：限制循环变量位宽，防止综合器静态展开时产生越界 part-select
    localparam LOOP_BITS = $clog2(WORD_BYTES + 1);  // ≥ log2(16+1) = 5 bits
    wire [3:0] out_byte_in_word = out_byte_addr[3:0];
    wire [4:0] write_chunk_nbyte = write_chunk_nbyte_r;
    // 必须用 6-bit 相加，避免 4-bit out_byte_in_word 截断导致 write_need_tail 恒为 0
    wire [5:0] write_end_pos = {2'b0, out_byte_in_word} + {1'b0, write_chunk_nbyte};
    wire [5:0] write_split_at = (WORD_BYTES > C_CHUNK_BYTES) ? {2'b0, C_CHUNK_BYTES[4:0]}
                                                             : {1'b0, WORD_BYTES[4:0]};
    wire [4:0] write_first_nbyte = (write_end_pos > write_split_at) ?
                                   (write_split_at[4:0] - out_byte_in_word) : write_chunk_nbyte;
    wire [4:0] write_tail_nbyte = (write_end_pos > write_split_at) ?
                                  (write_end_pos[4:0] - write_split_at[4:0]) : 5'd0;
    wire       write_need_tail = (write_tail_nbyte != 5'd0);
    wire [5:0] rd_tail_span_end = {2'b0, in_byte_in_word_r} + {1'b0, write_first_nbyte}
                                + {1'b0, write_tail_nbyte};
    wire       need_rd_tail = write_need_tail && in_bound && (rd_tail_span_end > WORD_BYTES);
    wire [GB_ADDR_WIDTH-1:0] write_byte_addr_aligned = out_byte_addr & ~32'd15;
    wire [GB_ADDR_WIDTH-1:0] in_rd_word_base = in_pixel_byte_addr & ~32'd15;
    wire                    write_is_tail = (state == S_WRITE_TAIL);
    reg [GB_BANDWIDTH/8-1:0] write_mask;
    reg [GB_BANDWIDTH-1:0] write_din_aligned;
    // 循环变量用 LOOP_BITS 位，防止综合器 integer(32-bit) 展开时产生越界 part-select
    reg [LOOP_BITS-1:0] write_mask_i, write_byte_pos, rd_byte_idx;
    always_comb begin
        write_mask = {GB_BANDWIDTH/8{1'b0}};
        write_din_aligned = {GB_BANDWIDTH{1'b0}};
        if (!write_is_tail) begin
            for (write_mask_i = 0; write_mask_i < write_first_nbyte; write_mask_i = write_mask_i + 1'b1) begin
                write_byte_pos = out_byte_in_word + write_mask_i;
                rd_byte_idx    = in_byte_in_word_r + write_mask_i;
                if (write_byte_pos < WORD_BYTES) begin
                    write_mask[write_byte_pos] = 1'b1;
                    if (in_bound && (rd_byte_idx < WORD_BYTES))
                        write_din_aligned[write_byte_pos*8 +: 8] =
                            rd_data_reg[rd_byte_idx * 8 +: 8];
                end
            end
        end else begin
            for (write_mask_i = 0; write_mask_i < write_tail_nbyte; write_mask_i = write_mask_i + 1'b1) begin
                write_byte_pos = write_mask_i;
                rd_byte_idx    = in_byte_in_word_r + write_first_nbyte + write_mask_i;
                if (write_byte_pos < WORD_BYTES) begin
                    write_mask[write_byte_pos] = 1'b1;
                    if (in_bound) begin
                        if (rd_byte_idx < WORD_BYTES)
                            write_din_aligned[write_byte_pos*8 +: 8] =
                                rd_data_reg[rd_byte_idx * 8 +: 8];
                        else
                            write_din_aligned[write_byte_pos*8 +: 8] =
                                rd_tail_data_reg[(rd_byte_idx - WORD_BYTES[LOOP_BITS-1:0]) * 8 +: 8];
                    end
                end
            end
        end
    end

    // 输入坐标组合计算（S_READ_REQ 同拍 in_bound 判定）
    wire signed [15:0] ih_calc = $signed(oh) * strideH_r - padH_r + $signed({8'd0, kh});
    wire signed [15:0] iw_calc = $signed(ow) * strideW_r - padW_r + $signed({8'd0, kw});
    wire ih_calc_ok = (ih_calc >= 0) && (ih_calc < $signed(src_h_r));
    wire iw_calc_ok = (iw_calc >= 0) && (iw_calc < $signed(src_w_r));

    // 输入是否在范围内（寄存 ih/iw 版本）
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
            c_chunk_byte_offset_r <= '0;
            write_chunk_nbyte_r <= '0;
            in_bound          <= 1'b0;
            rd_wait_cnt       <= 0;
            rd_data_reg       <= 0;
            rd_tail_data_reg  <= 0;
            in_byte_in_word_r <= 0;
            src_addr_r <= 0; dst_addr_r <= 0; src_c_r <= 0; src_h_r <= 0; src_w_r <= 0;
            oh_max_r <= 0; ow_max_r <= 0; elem_bytes_r <= 2'd1;
            kH_r <= 0; kW_r <= 0;
            strideH_r <= 0; strideW_r <= 0;
            padH_r <= 0; padW_r <= 0;
            row_stride_r <= 0; in_col_stride_r <= 0; w_times_c_r <= 0;
            stride_h_wc_r <= 0; stride_w_c_r <= 0; kw_times_c_r <= 0;
            in_base_r <= 0;
        end else begin
            // 默认信号
            gb_enb <= 1'b0;
            gb_web <= '0;

            case (state)
                S_IDLE: begin
                    if (im2col_unit_start) begin
`ifdef SIMULATION
                        $display("[%0t] im2col_unit: START src=0x%0h dst=0x%0h C/H/W=%0d/%0d/%0d OH/OW=%0d/%0d",
                                 $time, im2col_src_addr, im2col_dst_addr,
                                 im2col_src_c, im2col_src_h, im2col_src_w,
                                 im2col_addr_s, im2col_addr_t);
`endif
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
                        elem_bytes_r <= (im2col_elem_bytes == 2'd2) ? 2'd2 : 2'd1;
                        // c_chunk_max = ceil(CH_IN / 16)（INT8 或 INT16 均以 16 字节为一 chunk）
                        c_chunk_max <= (im2col_src_c + 15) >> 4;
                        im2col_unit_ready <= 1'b0;
                        state      <= S_INIT;
                    end
                end

                S_INIT: begin
                    oh <= 0; ow <= 0; kh <= 0; kw <= 0; c_chunk <= 0;
                    c_chunk_byte_offset_r <= '0;
                    write_chunk_nbyte_r <= (src_c_r > C_CHUNK_BYTES) ? 5'd16 : src_c_r[4:0];
                    // 一级乘法：像素间距按 ELEM_BYTES 缩放，输出行步长按实际字节计
                    // in_col_stride  = ceil(CH_IN * ELEM_BYTES / 16) * 16
                    // kw_times_c     = kW * CH_IN * ELEM_BYTES  (输出自然字节间隔)
                    in_col_stride_r  <= ((src_c_r * elem_bytes_w + 15) >> 4) << 4;
                    w_times_c_r      <= src_w_r * (((src_c_r * elem_bytes_w + 15) >> 4) << 4);
                    stride_w_c_r     <= strideW_r * (((src_c_r * elem_bytes_w + 15) >> 4) << 4);
                    kw_times_c_r     <= kW_r * src_c_r * elem_bytes_w;
                    // 增量累加器初始为 0
                    in_oh_acc_r <= 0; in_kh_acc_r <= 0;
                    in_ow_acc_r <= 0; in_kw_acc_r <= 0;
                    out_row_offset_r <= 0; out_col_offset_r <= 0;
                    state <= S_PRECOMPUTE;
                end

                S_PRECOMPUTE: begin
                    // 二级乘法：使用 S_INIT 已寄存的中间结果（< 2ns 每路）
                    stride_h_wc_r <= strideH_r * w_times_c_r;   // strideH * W * ceil(CH_IN/16)*16
                    // 每行按 acc_depth*16 字节对齐（与 golden_module_tb / DCIM 一致）
                    row_stride_r  <= ((kH_r * kw_times_c_r) + 15) & ~32'd15;
                    // in_base = src_addr - padH*(W*CH_IN) - padW*CH_IN
                    in_base_r     <= $signed(src_addr_r)
                                   - $signed(padH_r) * $signed(w_times_c_r)
                                   - $signed(padW_r) * $signed(in_col_stride_r);
                    state <= S_READ_REQ;
                end

                S_READ_REQ: begin
                    ih <= ih_calc;
                    iw <= iw_calc;
                    rd_wait_cnt <= 0;
                    if (ih_calc_ok && iw_calc_ok) begin
                        in_bound          <= 1'b1;
                        // 像素数据在 16B 对齐槽位内的偏移 = (align - CH_IN) + c_chunk*0（c_chunk已含在in_pixel_byte_addr）
                        // 像素数据从对齐槽位的 byte0 开始（hex 小端格式）
                        in_byte_in_word_r <= in_pixel_byte_addr[3:0];
                        gb_addrb          <= in_pixel_byte_addr;
                        gb_enb            <= 1'b1;
                        gb_web            <= '0;
                    end else begin
                        in_bound <= 1'b0;
                        gb_enb   <= 1'b0;
                    end
                    state <= (ih_calc_ok && iw_calc_ok) ? S_READ_WAIT : S_WRITE;
                end

                S_READ_WAIT: begin
                    // 保持 gb_enb=1 直到收到 valid（obuf 读流水线需要持续使能）
                    // 收到 valid 时立即清除 enb，避免流水线残留触发下一拍 valid
                    if (gb_doutb_valid) begin
                        gb_addrb <= in_pixel_byte_addr;
                        gb_enb   <= 1'b0;   // 清除使能，截断流水
                        gb_web   <= '0;
`ifdef PROBE_IM2COL
                        $display("[im2col] LATCH_DATA oh=%0d ow=%0d kh=%0d kw=%0d addr=0x%h data=0x%h wait=%0d",
                                 oh, ow, kh, kw, in_pixel_byte_addr, gb_doutb, rd_wait_cnt);
`endif
                        rd_data_reg <= gb_doutb;
                        state       <= S_READ_LATCH;
                    end else if (rd_wait_cnt == READ_TIMEOUT) begin
                        $display("[im2col] READ TIMEOUT at byte addr 0x%08h", in_pixel_byte_addr);
                        state <= S_READ_LATCH;
                    end else begin
                        // 未收到 valid，继续保持读使能
                        gb_addrb <= in_pixel_byte_addr;
                        gb_enb   <= 1'b1;
                        gb_web   <= '0;
                        rd_wait_cnt <= rd_wait_cnt + 1;
                    end
                end

                S_READ_LATCH: begin
                    // 等待流水线残留 valid 消失，防止下一次读操作在 S_READ_WAIT 收到旧数据
                    if (gb_doutb_valid) begin
                        // 流水线仍有残留脉冲，在此等待（丢弃残留 valid）
                        gb_enb <= 1'b0;
                    end else begin
                        state <= S_WRITE;
                    end
                end

                S_WRITE: begin
                    gb_addrb <= write_byte_addr_aligned;
                    gb_enb   <= 1'b1;
                    gb_web   <= write_mask;
                    gb_dinb  <= write_din_aligned;
                    if (write_need_tail && need_rd_tail)
                        state <= S_READ_TAIL_REQ;
                    else if (write_need_tail)
                        state <= S_WRITE_TAIL;
                    else
                        state <= S_NEXT_C;
                end

                S_READ_TAIL_REQ: begin
                    gb_addrb <= in_rd_word_base + WORD_BYTES;
                    gb_enb   <= 1'b1;
                    gb_web   <= '0;
                    rd_wait_cnt <= 0;
                    state    <= S_READ_TAIL_WAIT;
                end

                S_READ_TAIL_WAIT: begin
                    if (gb_doutb_valid) begin
                        gb_enb   <= 1'b0;
                        rd_tail_data_reg <= gb_doutb;
                        state    <= S_READ_TAIL_LATCH;
                    end else if (rd_wait_cnt == READ_TIMEOUT) begin
                        $display("[im2col] TAIL READ TIMEOUT at byte addr 0x%08h",
                                 in_rd_word_base + WORD_BYTES);
                        state <= S_READ_TAIL_LATCH;
                    end else begin
                        gb_addrb <= in_rd_word_base + WORD_BYTES;
                        gb_enb   <= 1'b1;
                        rd_wait_cnt <= rd_wait_cnt + 1;
                    end
                end

                S_READ_TAIL_LATCH: begin
                    if (gb_doutb_valid)
                        gb_enb <= 1'b0;
                    else
                        state <= S_WRITE_TAIL;
                end

                S_WRITE_TAIL: begin
                    gb_addrb <= write_byte_addr_aligned + WORD_BYTES;
                    gb_enb   <= 1'b1;
                    gb_web   <= write_mask;
                    gb_dinb  <= write_din_aligned;
                    state    <= S_NEXT_C;
                end

                S_NEXT_C: begin
                    // 推进 c_chunk
                    if (c_chunk + 1 < c_chunk_max) begin
                        c_chunk <= c_chunk + 1;
                        c_chunk_byte_offset_r <= c_chunk_byte_offset_r + C_CHUNK_BYTES;
                        if ((src_c_r - (c_chunk_byte_offset_r + C_CHUNK_BYTES)) > C_CHUNK_BYTES)
                            write_chunk_nbyte_r <= 5'd16;
                        else
                            write_chunk_nbyte_r <= src_c_r - (c_chunk_byte_offset_r + C_CHUNK_BYTES);
                        state <= S_READ_REQ;
                    end else begin
                        c_chunk <= 0;
                        c_chunk_byte_offset_r <= '0;
                        write_chunk_nbyte_r <= (src_c_r > C_CHUNK_BYTES) ? 5'd16 : src_c_r[4:0];
                        state <= S_NEXT;
                    end
                end

                S_NEXT: begin
                    // 递增循环计数器 + 增量更新偏移（无乘法）
                    if (kw + 1 < $signed({1'b0, kW_r})) begin
                        kw <= kw + 1;
                        in_kw_acc_r      <= in_kw_acc_r + in_col_stride_r;
                        out_col_offset_r <= out_col_offset_r + src_c_r * elem_bytes_w;
                        state <= S_READ_REQ;
                        end else begin
                            kw <= 0;
                            in_kw_acc_r      <= 0;
                            if (kh + 1 < $signed({1'b0, kH_r})) begin
                                kh <= kh + 1;
                                in_kh_acc_r      <= in_kh_acc_r + w_times_c_r;
                                // kw 末尾切换到下一 kh 时，补加最后一步 kw 未加的 src_c_r * elem
                                out_col_offset_r <= out_col_offset_r + src_c_r * elem_bytes_w;
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
`ifdef PROBE_IM2COL_DONE
                    $display("[im2col] ALL DONE oh=%0d ow=%0d", oh, ow);
`endif
                    im2col_unit_ready <= 1'b1;
                    state             <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
