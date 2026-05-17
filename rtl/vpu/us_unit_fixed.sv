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
    localparam SCALE_BITS = 1;  // log2(SCALE) = log2(2) = 1
    localparam LANES      = GB_BANDWIDTH / FP_WIDTH;  // 8 FP32 per word
    localparam LANES_BITS = 3;  // log2(LANES) = log2(8) = 3

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
    reg [GB_ADDR_WIDTH-1:0] src_base_word;
    reg [GB_ADDR_WIDTH-1:0] dst_base_word;
    
    // 预计算的步长（避免重复乘法）
    reg [GB_ADDR_WIDTH-1:0] src_row_stride;  // in_w * c_blocks
    reg [GB_ADDR_WIDTH-1:0] dst_row_stride;  // out_w * c_blocks = (in_w << 1) * c_blocks

    // =========================================================================
    // 循环计数器
    // =========================================================================
    reg [ADDR_WIDTH-1:0] ih_cnt;    // 输入行
    reg [ADDR_WIDTH-1:0] iw_cnt;    // 输入列
    reg [ADDR_WIDTH-1:0] cb_cnt;    // channel block

    // 像素缓冲
    reg [GB_BANDWIDTH-1:0] pixel_buf;

    // =========================================================================
    // 地址寄存器（基址 + 偏移分离，避免S_NEXT中的乘法）
    // =========================================================================
    // 行基址（每换行时更新）
    reg [GB_ADDR_WIDTH-1:0] src_row_base;        // ih * in_w * c_blocks
    reg [GB_ADDR_WIDTH-1:0] dst_row_base_even;   // (2*ih) * out_w * c_blocks
    reg [GB_ADDR_WIDTH-1:0] dst_row_base_odd;    // (2*ih+1) * out_w * c_blocks
    
    // 列偏移（每换列时更新，每换cb时微调）
    reg [GB_ADDR_WIDTH-1:0] src_col_base;        // iw * c_blocks
    reg [GB_ADDR_WIDTH-1:0] dst_col_base_even;   // (2*iw) * c_blocks
    reg [GB_ADDR_WIDTH-1:0] dst_col_base_odd;    // (2*iw+1) * c_blocks

    // =========================================================================
    // 地址计算（基址 + 偏移 + cb）
    // =========================================================================
    wire [GB_ADDR_WIDTH-1:0] load_addr   = src_row_base + src_col_base + cb_cnt;
    wire [GB_ADDR_WIDTH-1:0] save_addr_0 = dst_row_base_even + dst_col_base_even + cb_cnt;
    wire [GB_ADDR_WIDTH-1:0] save_addr_1 = dst_row_base_even + dst_col_base_odd + cb_cnt;
    wire [GB_ADDR_WIDTH-1:0] save_addr_2 = dst_row_base_odd + dst_col_base_even + cb_cnt;
    wire [GB_ADDR_WIDTH-1:0] save_addr_3 = dst_row_base_odd + dst_col_base_odd + cb_cnt;

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
            c_blocks    <= '0;
            src_base_word <= '0;
            dst_base_word <= '0;
            pixel_buf   <= '0;
            gb_addrb    <= '0;
            gb_dinb     <= '0;
            gb_web      <= '0;
            gb_enb      <= 1'b0;
            // 初始化步长和地址寄存器
            src_row_stride      <= '0;
            dst_row_stride      <= '0;
            src_row_base        <= '0;
            dst_row_base_even   <= '0;
            dst_row_base_odd    <= '0;
            src_col_base        <= '0;
            dst_col_base_even   <= '0;
            dst_col_base_odd    <= '0;
        end else begin
            // 默认清除 BRAM 控制信号
            gb_enb  <= 1'b0;
            gb_web  <= '0;

            case (state)
                // ---------------------------------------------------------
                S_IDLE: begin
                    if (us_unit_start) begin
                        // 锁存配置参数
                        in_h          <= us_src_h;
                        in_w          <= us_src_w;
                        c_blocks      <= us_src_c >> LANES_BITS;  // 除以8用移位
                        src_base_word <= us_src_addr[ADDR_WIDTH-1:5];
                        dst_base_word <= us_dst_addr[ADDR_WIDTH-1:5];
                        
                        // 预计算步长（只做一次乘法，后续全部增量更新）
                        src_row_stride <= us_src_w * (us_src_c >> LANES_BITS);
                        dst_row_stride <= (us_src_w << SCALE_BITS) * (us_src_c >> LANES_BITS);
                        
                        // 初始化循环计数器
                        ih_cnt <= '0;
                        iw_cnt <= '0;
                        cb_cnt <= '0;
                        
                        // 初始化基址（位置 (0,0)）
                        src_row_base      <= us_src_addr[ADDR_WIDTH-1:5];
                        dst_row_base_even <= us_dst_addr[ADDR_WIDTH-1:5];
                        dst_row_base_odd  <= us_dst_addr[ADDR_WIDTH-1:5] + (us_src_w << SCALE_BITS) * (us_src_c >> LANES_BITS);
                        
                        src_col_base      <= '0;
                        dst_col_base_even <= '0;
                        dst_col_base_odd  <= us_src_c >> LANES_BITS;  // c_blocks
                        
                        state <= S_LOAD_REQ;
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
                        // 完成了当前像素的所有channel blocks
                        cb_cnt <= '0;
                        
                        if (iw_cnt == in_w - 1) begin
                            // 完成了当前行
                            iw_cnt <= '0;
                            
                            if (ih_cnt == in_h - 1) begin
                                // 完成了所有行
                                state <= S_DONE;
                            end else begin
                                // 移动到下一行：ih++
                                ih_cnt <= ih_cnt + 1;
                                
                                // 行基址增量更新
                                src_row_base      <= src_row_base + src_row_stride;
                                dst_row_base_even <= dst_row_base_even + (dst_row_stride << SCALE_BITS);  // +2行
                                dst_row_base_odd  <= dst_row_base_odd + (dst_row_stride << SCALE_BITS);
                                
                                // 列偏移回到0
                                src_col_base      <= '0;
                                dst_col_base_even <= '0;
                                dst_col_base_odd  <= c_blocks;
                                
                                state <= S_LOAD_REQ;
                            end
                        end else begin
                            // 移动到下一列：iw++
                            iw_cnt <= iw_cnt + 1;
                            
                            // 列偏移增量更新
                            src_col_base      <= src_col_base + c_blocks;
                            dst_col_base_even <= dst_col_base_even + (c_blocks << SCALE_BITS);  // +2列
                            dst_col_base_odd  <= dst_col_base_odd + (c_blocks << SCALE_BITS);
                            
                            state <= S_LOAD_REQ;
                        end
                    end else begin
                        // 下一个channel block：cb++
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
