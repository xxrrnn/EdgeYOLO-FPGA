`timescale 1ns/1ps

// 复位同步器模块 - 用于同步异步复位信号
module rst_n_sync (
    input  wire clk,
    input  wire rst_n_i,    // 输入异步复位
    output reg  rst_n_o     // 输出同步复位
);

    reg rst_n_meta;

    always @(posedge clk or negedge rst_n_i) begin
        if (!rst_n_i) begin
            rst_n_meta <= 1'b0;
            rst_n_o    <= 1'b0;
        end else begin
            rst_n_meta <= 1'b1;
            rst_n_o    <= rst_n_meta;
        end
    end

endmodule
