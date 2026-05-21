`timescale 1ns / 1ps
`include "../../chip/chip_defines.vh"

//////////////////////////////////////////////////////////////////////////////////
// DCIM_Array stub - 只检查控制信号，无内部逻辑，瞬间仿真
//////////////////////////////////////////////////////////////////////////////////
module DCIM_Array #(
    parameter NUM_GROUPS      = `DCIM_NUM_GROUPS,
    parameter TILES_PER_GROUP = `DCIM_TILES_PER_GROUP,
    parameter NUM_TILES       = `DCIM_NUM_TILES,
    parameter WD1             = `DCIM_WD1,
    parameter CH_IN           = `DCIM_CH_IN,
    parameter CH_OUT          = `DCIM_CH_OUT,
    parameter SRAM_DP         = `DCIM_SRAM_DP,
    parameter CYCLE           = `DCIM_CYCLE,
    parameter ACC             = `DCIM_ACC_MAX,
    parameter BUF_ADDR_WIDTH  = `DCIM_BUF_ADDR_WIDTH,
    parameter BUF_DATA_WIDTH  = `DCIM_BUF_DATA_WIDTH,
    parameter IBUF_RD_LATENCY = `DCIM_IBUF_RD_LATENCY,
    localparam ACC_UBD_WD = $clog2(ACC+1),
    localparam STRB_WIDTH = BUF_DATA_WIDTH / 8
)(
    input  wire clk, rst_n, start,
    output reg  done, ready,
    input  wire [2:0]                             mode,
    input  wire [ACC_UBD_WD-1:0]                  acc_depth,
    input  wire [BUF_ADDR_WIDTH-1:0]              act_base_addr,    // 全局统一激活基址
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]    wei_base_addrs,
    input  wire [NUM_TILES*BUF_ADDR_WIDTH-1:0]    out_base_addrs,
    input  wire [NUM_GROUPS*STRB_WIDTH-1:0]       ibuf_ext_wea,
    input  wire [NUM_GROUPS-1:0]                  ibuf_ext_ena,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]   ibuf_ext_addra,
    input  wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]   ibuf_ext_dina,
    output wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]   ibuf_ext_douta,
    input  wire [NUM_GROUPS*STRB_WIDTH-1:0]       obuf_ext_wea,
    input  wire [NUM_GROUPS-1:0]                  obuf_ext_ena,
    input  wire [NUM_GROUPS*BUF_ADDR_WIDTH-1:0]   obuf_ext_addra,
    input  wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]   obuf_ext_dina,
    output wire [NUM_GROUPS*BUF_DATA_WIDTH-1:0]   obuf_ext_douta
);
    assign ibuf_ext_douta = 0;
    assign obuf_ext_douta = 0;
    reg [2:0] cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin done <= 0; ready <= 1; cnt <= 0; end
        else if (start && ready) begin done <= 0; ready <= 0; cnt <= 0; end
        else if (!ready) begin
            cnt <= cnt + 1;
            if (cnt == 3) begin done <= 1; ready <= 1; end
            else done <= 0;
        end else done <= 0;
    end
endmodule
