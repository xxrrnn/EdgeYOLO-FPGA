`timescale 1ns/1ps
//-----------------------------------------------------------------------------
// fp_mac_array：多 lane FP32 向量运算核（res ≈ a*b + c）
// 说明：本文件为纯 RTL 行为模型，便于 xsim/Verilator 无 Xilinx IP 时仿真。
//       上板综合请替换为 scripts/ip/floating_point_fp32.tcl 生成的 IP 版本。
// 端口：与 Global_VPU.v 中例化一致（无 rst_n）。
//-----------------------------------------------------------------------------
module fp_mac_array #(
    parameter int unsigned FP_CORE_NUM = 8,
    parameter int unsigned FP_WIDTH      = 32
)(
    input  logic                               clk,
    input  logic                               fp_array_tvalid,
    output logic                               fp_array_tready,
    input  logic [FP_CORE_NUM*FP_WIDTH-1:0]    a_tdata,
    input  logic [FP_CORE_NUM*FP_WIDTH-1:0]    b_tdata,
    input  logic [FP_CORE_NUM*FP_WIDTH-1:0]    c_tdata,
    output logic [FP_CORE_NUM*FP_WIDTH-1:0]    res,
    output logic                               res_tvalid
);
    assign fp_array_tready = 1'b1;

    generate
        if (FP_WIDTH == 32) begin : GEN_FP32_MAC
            genvar gi;
            for (gi = 0; gi < FP_CORE_NUM; gi++) begin : gen_lane
                logic [31:0] rl;
                always_ff @(posedge clk) begin
                    if (fp_array_tvalid) begin
                        automatic shortreal ax = $bitstoshortreal(a_tdata[gi*32 +: 32]);
                        automatic shortreal bx = $bitstoshortreal(b_tdata[gi*32 +: 32]);
                        automatic shortreal cx = $bitstoshortreal(c_tdata[gi*32 +: 32]);
                        rl <= $shortrealtobits(ax * bx + cx);
                    end
                end
                assign res[gi*32 +: 32] = rl;
            end
        end else begin : GEN_FP16_MAC
            genvar gi;
            for (gi = 0; gi < FP_CORE_NUM; gi++) begin : gen_lane
                logic [15:0] rl;
                always_ff @(posedge clk) begin
                    if (fp_array_tvalid) begin
                        rl <= 16'b0;
                    end
                end
                assign res[gi*16 +: 16] = rl;
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        res_tvalid <= fp_array_tvalid;
    end
endmodule
