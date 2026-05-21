`timescale 1ns/1ps
// int8_pack_writer - 将多次 INT8 输出打包为完整 BRAM word 后写入
// 每次接收 PACK_WIDTH 位 INT8 数据，累积 PACKS_PER_WORD 次后写出 GB_BANDWIDTH 位
module int8_pack_writer #(
    parameter GB_BANDWIDTH  = 256,
    parameter GB_ADDR_WIDTH = 16,
    parameter PACK_WIDTH    = 64   // FP_CORE_NUM * 8
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // 来自上游的 INT8 数据
    input  wire                          pack_valid,   // 有新的 PACK_WIDTH 位数据
    input  wire [PACK_WIDTH-1:0]         pack_data,    // INT8 数据
    input  wire [GB_ADDR_WIDTH-1:0]      pack_base_addr, // 输出基地址 (word)
    input  wire                          pack_last,    // 最后一包（flush）
    input  wire                          pack_reset,   // 复位计数器（新操作开始时）

    // BRAM 写接口
    output reg  [GB_ADDR_WIDTH-1:0]      bram_addr,
    output reg  [GB_BANDWIDTH-1:0]       bram_din,
    output reg  [GB_BANDWIDTH/8-1:0]     bram_we,
    output reg                           bram_en,

    // 反压（正在写 BRAM 时不接收新数据）
    output wire                          pack_ready
);

    localparam PACKS_PER_WORD = GB_BANDWIDTH / PACK_WIDTH;  // 4
    localparam PACK_CNT_W = $clog2(PACKS_PER_WORD);

    reg [GB_BANDWIDTH-1:0]   buffer;
    reg [PACK_CNT_W-1:0]     pack_cnt;
    reg [GB_ADDR_WIDTH-1:0]  word_cnt;

    wire pack_full = (pack_cnt == PACKS_PER_WORD - 1);

    assign pack_ready = 1'b1;  // 单周期打包，无反压

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer   <= '0;
            pack_cnt <= '0;
            word_cnt <= '0;
            bram_addr <= '0;
            bram_din  <= '0;
            bram_we   <= '0;
            bram_en   <= 1'b0;
        end else begin
            bram_en <= 1'b0;
            bram_we <= '0;

            if (pack_reset) begin
                buffer   <= '0;
                pack_cnt <= '0;
                word_cnt <= '0;
            end else if (pack_valid) begin
                // 写入 buffer 对应位置
                buffer[pack_cnt * PACK_WIDTH +: PACK_WIDTH] <= pack_data;

                if (pack_full || pack_last) begin
                    // 输出完整 word 到 BRAM
                    bram_en   <= 1'b1;
                    bram_we   <= {(GB_BANDWIDTH/8){1'b1}};
                    bram_addr <= pack_base_addr + word_cnt;
                    bram_din  <= buffer;
                    bram_din[pack_cnt * PACK_WIDTH +: PACK_WIDTH] <= pack_data;
                    pack_cnt  <= '0;
                    word_cnt  <= word_cnt + 1;
                    buffer    <= '0;
                end else begin
                    pack_cnt <= pack_cnt + 1;
                end
            end
        end
    end

endmodule
